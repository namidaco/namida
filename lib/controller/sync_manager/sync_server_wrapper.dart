part of 'sync_manager.dart';

class ServerWrapper {
  final MDNSServer broadcast;
  final ServerSocket serverSocket;
  final MDNSService info;

  const ServerWrapper({
    required this.broadcast,
    required this.serverSocket,
    required this.info,
  });

  static Future<ServerWrapper> startBroadcast(ServerSocket serverSocket) async {
    final preferredInterface = await SyncUtils.getPreferredInterface();
    final deviceName = await SyncUtils.currentDeviceName;
    final deviceId = await SyncUtils.currentDeviceId;
    final service = await MDNSService.create(
      instance: SyncUtils._createServiceName(deviceName: deviceName),
      service: SyncUtils.kDefaultServiceType,
      port: SyncUtils.kDefaultNamidaPort,
      domain: SyncUtils.kDefaultDomain,
      ips: preferredInterface?.addresses,
      txt: MDNSService.createTXTRecords({
        'device_name': deviceName,
        'device_id': deviceId,
      }),
    );

    final broadcast = MDNSServer(
      MDNSServerConfig(
        zone: service,
        networkInterface: preferredInterface,
      ),
    );
    await broadcast.start();

    return ServerWrapper(
      broadcast: broadcast,
      serverSocket: serverSocket,
      info: service,
    );
  }

  Future<void> stopAll() async {
    await broadcast.stop();
    await serverSocket.close();
  }

  String buildText({bool simple = true}) => info.buildText(simple: simple);
}

extension on MDNSService {
  String buildText({bool simple = true}) {
    final parts = <String>[];

    final hostNameCleaned = hostName.endsWith('.') ? hostName.substring(0, hostName.length - 1) : hostName;
    parts.add('Host: $hostNameCleaned');
    if (port > 0) parts.add('Port: $port');

    if (!simple) {
      parts.add('Domain: $domain');
      parts.add('Service: $service');
      parts.add(ips.map((e) => e.address).join(' | '));
    }

    return parts.join('\n');
  }
}
