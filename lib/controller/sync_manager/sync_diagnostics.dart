part of 'sync_manager.dart';

// by claude
class SyncDiagnostics {
  SyncDiagnostics._();

  static const _kMaxTraceLines = 200;
  static const _kNetworkResetHint = 'try disabling & re-enabling the network adapter, or restarting the device';

  static const _kWindowsNetworkScript = r'''
Get-NetConnectionProfile | ForEach-Object { "profile: $($_.InterfaceAlias) = $($_.NetworkCategory)" }
Get-NetFirewallApplicationFilter -Program '{exe}' -ErrorAction SilentlyContinue | Get-NetFirewallRule | ForEach-Object { "firewall rule: $($_.DisplayName) | $($_.Direction) $($_.Action) | profile: $($_.Profile) | enabled: $($_.Enabled)" }
''';

  static final _serverStartLog = <String>[];
  static bool _isServerStarting = false;
  static List<String>? _serverTrace;

  static void _onServerLog(String message) {
    if (_isServerStarting) _serverStartLog.add(message);
    final trace = _serverTrace;
    if (trace != null && trace.length < _kMaxTraceLines) trace.add(message);
  }

  static Future<String> run() async {
    final report = StringBuffer();
    final version = NamidaDeviceInfo.version?.prettyVersion ?? NamidaDeviceInfo.packageInfo?.version;
    report.writeln('namida $version | ${Platform.operatingSystem} ${Platform.operatingSystemVersion} | sync v${SyncUtils.kSyncVersion}');

    final preferredInterface = await SyncUtils.getPreferredInterface();
    await _writeInterfaces(report, preferredInterface);
    _writeServer(report);
    if (Platform.isWindows) await _writeWindowsNetwork(report);
    await _writeDiscovery(report, preferredInterface);

    return report.toString().trimRight();
  }

  static Future<void> _writeInterfaces(StringBuffer report, NetworkInterface? preferredInterface) async {
    report.writeln('\n== interfaces ==');
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: true);
    for (final iface in interfaces) {
      final name = iface.name.toLowerCase();
      final role = iface.index == preferredInterface?.index
          ? 'preferred'
          : SyncUtils._isVirtualOrCellularInterface(name)
          ? 'skipped, virtual/cellular'
          : SyncUtils._isLanInterface(name)
          ? 'lan'
          : 'other';
      report.writeln('${iface.name} #${iface.index}: ${iface.addresses.map((e) => e.address).join(', ')} ($role)');
    }
    if (preferredInterface == null) report.writeln('! no LAN interface picked, discovery binds to 0.0.0.0. $_kNetworkResetHint');
  }

  static void _writeServer(StringBuffer report) {
    report.writeln('\n== server ==');
    final wrapper = SyncDiscovery.server.serverWrapper;
    if (wrapper == null) {
      report.writeln('not running, other devices can only find this one while it runs');
      return;
    }
    final serverSocket = wrapper.serverSocket;
    final advertised = wrapper.info.ips.map((e) => e.address).join(', ');
    report.writeln('tcp ${serverSocket.address.address}:${serverSocket.port} | advertising: $advertised | clients: ${SyncDiscovery.server._clientsSockets.length}');
    _writeLog(report, _serverStartLog);
  }

  static Future<void> _writeWindowsNetwork(StringBuffer report) async {
    report.writeln('\n== windows network ==');
    final exePath = Platform.resolvedExecutable.replaceAll("'", "''");
    try {
      report.writeln(await _runPowershell(_kWindowsNetworkScript.replaceFirst('{exe}', exePath)));
    } catch (e) {
      report.writeln('failed: $e');
    }
  }

  static Future<void> _writeDiscovery(StringBuffer report, NetworkInterface? preferredInterface) async {
    report.writeln('\n== discovery ==');
    final lastError = SyncDiscovery.client.lastDiscoveryError;
    if (lastError != null) report.writeln('last scan error: $lastError');

    final clientLog = <String>[];
    _serverTrace = <String>[];
    final localAddresses = await SyncUtils.getLocalInterfaceAddresses();
    final foundAddresses = <String>{};
    try {
      final stream = await SyncUtils._queryServers(
        preferredInterface,
        logger: (message) {
          if (clientLog.length < _kMaxTraceLines) clientLog.add(message);
        },
      );
      await for (final service in stream) {
        final device = NetworkDevice.fromService(service);
        if (device == null) {
          report.writeln('found without ipv4: ${service.name}');
          continue;
        }
        final isSelf = localAddresses.contains(device.address);
        report.writeln('found: ${device.name} @ ${device.address}:${device.port}${isSelf ? ' (self)' : ''}');
        if (!isSelf) foundAddresses.add(device.address);
      }
    } catch (e) {
      report.writeln('scan error: $e');
      if (e is SocketException && e.message.startsWith('Send failed')) report.writeln('! sending the discovery query failed, $_kNetworkResetHint');
    }
    final serverTrace = _serverTrace ?? const <String>[];
    _serverTrace = null;

    if (foundAddresses.isEmpty) {
      report.writeln(
        '! no other namida server answered. make sure the server is started on the other device, and that the router does not isolate clients (guest networks usually do)',
      );
    }

    final probeAddresses = {...foundAddresses, ...settings.sync.manualServerAddresses.values};
    final probeResults = await Future.wait(probeAddresses.map(_probeTcp));
    var i = 0;
    for (final address in probeAddresses) {
      report.writeln('tcp $address:${SyncUtils.kDefaultNamidaPort}: ${probeResults[i++]}');
    }

    report.writeln('\n== scan log ==');
    _writeLog(report, clientLog);
    report.writeln('\n== server log during scan ==');
    _writeLog(report, serverTrace);
  }

  static void _writeLog(StringBuffer report, List<String> lines) {
    for (final line in lines) {
      report.writeln('  $line');
    }
  }

  static Future<String> _probeTcp(String address) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(address, SyncUtils.kDefaultNamidaPort, timeout: const Duration(seconds: 3));
      socket.destroy();
      return 'ok (${sw.elapsedMilliseconds}ms)';
    } catch (e) {
      return 'failed: $e';
    }
  }

  static Future<String> _runPowershell(String script) async {
    final encodedScript = base64.encode(Uint16List.fromList(script.codeUnits).buffer.asUint8List());
    final process = await Process.start('powershell', ['-NoProfile', '-NonInteractive', '-EncodedCommand', encodedScript]);
    final output = process.stdout.transform(systemEncoding.decoder).join();
    process.stderr.drain<void>();
    final exitCode = await process.exitCode.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
    if (exitCode == -1) return 'timed out';
    return (await output).trim();
  }
}
