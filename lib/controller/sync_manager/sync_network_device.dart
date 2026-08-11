part of 'sync_manager.dart';

class NetworkDevice {
  final String name;
  final String address;
  final int port;
  final String deviceName;
  final String deviceId;

  const NetworkDevice({
    required this.name,
    required this.address,
    required this.port,
    required this.deviceName,
    required this.deviceId,
  });

  static NetworkDevice? fromService(ServiceEntry service) {
    final address = service.addrV4?.address;
    if (address == null) return null;

    final name = service.name;
    final port = service.port;
    final infoMap = MDNSService.parseTXTRecords(service.infoFields);
    final deviceName = infoMap['device_name'] ?? 'unknown';
    final deviceId = infoMap['device_id'] ?? 'unknown';

    return NetworkDevice(
      name: name,
      address: address,
      port: port,
      deviceName: deviceName,
      deviceId: deviceId,
    );
  }

  factory NetworkDevice.fromMap(Map<String, dynamic> map) {
    return NetworkDevice(
      name: map['name'] as String,
      address: map['address'] as String,
      port: map['port'] as int,
      deviceName: map['deviceName'] as String,
      deviceId: map['deviceId'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'port': port,
      'deviceName': deviceName,
      'deviceId': deviceId,
    };
  }

  String buildText() {
    const nameExtraTrailing = '.${SyncUtils.kDefaultServiceType}.${SyncUtils.kDefaultDomain}';
    final nameCleaned = name.endsWith(nameExtraTrailing) ? name.substring(0, name.length - nameExtraTrailing.length) : name;

    return <String>[
      deviceName,
      nameCleaned,
      if (port > 0) '${lang.port}: $port',
      'Address: $address',
    ].join('\n');
  }

  @override
  bool operator ==(Object other) {
    if (other is! NetworkDevice) return false;
    if (identical(this, other)) return true;

    return other.name == name && other.address == address && other.port == port && other.deviceId == deviceId;
  }

  @override
  int get hashCode {
    return name.hashCode ^ address.hashCode ^ port.hashCode ^ deviceId.hashCode;
  }
}

class SyncDeviceView {
  final String deviceId;

  /// known when we discovered & connected to their server. used for reconnecting.
  NetworkDevice? networkDevice;
  String? remoteAddress;

  bool asClient = false;

  bool asServer = false;

  SyncDeviceView(this.deviceId);

  bool get connectedAsClient => SyncDiscovery.client._connectedServers.containsKey(deviceId);
  bool get connectedAsServer => SyncDiscovery.server._clientsSockets.containsKey(deviceId);
  bool get isConnected => connectedAsClient || connectedAsServer;

  String get displayName => settings.sync.deviceIdNames[deviceId] ?? networkDevice?.deviceName ?? deviceId;
}
