part of 'sync_manager.dart';

class ServerWrapper {
  final LanServiceAdvertisement? broadcast;
  final Object? broadcastStartError;
  final ServerSocket serverSocket;
  final MDNSService info;

  const ServerWrapper({
    required this.broadcast,
    required this.broadcastStartError,
    required this.serverSocket,
    required this.info,
  });

  /// why other devices can't find this server, they can still connect by its address.
  Object? get discoveryError => broadcastStartError ?? broadcast?.error.value;

  static Future<ServerWrapper> startBroadcast(ServerSocket serverSocket) async {
    final preferredInterface = await SyncUtils.getPreferredInterface();
    final deviceName = await SyncUtils.currentDeviceName;
    final deviceId = await SyncUtils.currentDeviceId;
    final service = await MDNSService.create(
      instance: SyncUtils._createServiceName(deviceName: deviceName),
      service: SyncUtils.kDefaultServiceType,
      port: SyncUtils.kDefaultNamidaPort,
      domain: SyncUtils.kDefaultDomain,
      hostName: SyncUtils.createMdnsHostName(deviceId),
      ips: await SyncUtils.getAdvertisedAddresses(preferredInterface),
      txt: MDNSService.createTXTRecords({
        'device_name': deviceName,
        'device_id': deviceId,
      }),
    );

    SyncDiagnostics._serverStartLog.clear();
    SyncDiagnostics._isServerStarting = true;
    LanServiceAdvertisement? broadcast;
    Object? broadcastStartError;
    try {
      broadcast = await LanServiceDiscovery.inst.advertise(
        service,
        networkInterface: preferredInterface,
        logger: SyncDiagnostics._onServerLog,
      );
    } catch (e) {
      // -- the tcp server works without it, devices connect by address
      broadcastStartError = e;
    } finally {
      SyncDiagnostics._isServerStarting = false;
    }

    return ServerWrapper(
      broadcast: broadcast,
      broadcastStartError: broadcastStartError,
      serverSocket: serverSocket,
      info: service,
    );
  }

  Future<void> stopAll() async {
    await broadcast?.stop();
    await serverSocket.close();
  }

  String buildText({required String? deviceName, bool simple = true}) {
    final text = info.buildText(deviceName: deviceName, simple: simple);
    final discoveryError = this.discoveryError;
    if (discoveryError == null) return text;
    return '$text\n${SyncUtils.discoveryFailedHint}\n$discoveryError';
  }
}

extension on MDNSService {
  String buildText({required String? deviceName, bool simple = true}) {
    final parts = <String>[];

    if (deviceName != null) parts.add('${lang.name}: $deviceName');
    final ipv4Text = ips.where((e) => e.type == InternetAddressType.IPv4).map((e) => e.address).join(' | ');
    if (ipv4Text.isNotEmpty) parts.add('${lang.address}: $ipv4Text');
    if (port > 0) parts.add('${lang.port}: $port');

    if (!simple) {
      final hostNameCleaned = hostName.endsWith('.') ? hostName.substring(0, hostName.length - 1) : hostName;
      parts.add('${lang.host}: $hostNameCleaned');
      parts.add('Domain: $domain');
      parts.add('Service: $service');
    }

    return parts.join('\n');
  }
}
