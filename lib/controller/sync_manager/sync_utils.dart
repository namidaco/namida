part of 'sync_manager.dart';

class SyncUtils {
  static const kDefaultServiceType = '_namida-server._tcp';
  static const kDefaultDomain = 'local';
  static const kDefaultNamidaPort = 62310; // 2023-10, v1 of namida

  /// increment this only when introducing breaking changes
  static const kSyncVersion = 2;

  /// if enabled, will directly edit library on receiving valid data
  /// if disabled, will only display a snackbar with the received info
  static const kAllowModification = true;

  /// if enabled, db-backed items sync by diffing manifests & sending only the
  /// missing/newer entries, see [DbManifestRequestMessage]. otherwise the whole
  /// db file gets sent & merged on the receiver, see [DbFileMessage].
  static final kUseDbEntriesSync = true;

  static final fallbackDeviceName = _fetchDeviceName();

  /// custom name set by the user, falling back to the actual device name
  static Future<String> get currentDeviceName {
    final custom = settings.sync.customDeviceName.value;
    if (custom != null && custom.isNotEmpty) return Future.value(custom);
    return fallbackDeviceName;
  }

  static final currentDeviceId = _fetchDeviceId();

  static Future<BaseMessageInfo> createMessageInfo(MessageActionType action) async {
    return BaseMessageInfo(
      action: action,
      senderDeviceId: await currentDeviceId,
    );
  }

  static String _createServiceName({required String deviceName}) {
    return 'Namida - ${Platform.operatingSystem} - ${Platform.operatingSystemVersion}';
  }

  static Future<T?> _extractInfoFromDevice<T>({
    T Function(AndroidDeviceInfo info)? android,
    T Function(IosDeviceInfo info)? ios,
    T Function(LinuxDeviceInfo info)? linux,
    T Function(MacOsDeviceInfo info)? macos,
    T Function(WindowsDeviceInfo info)? windows,
  }) async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      return android?.call(await deviceInfo.androidInfo);
    } else if (Platform.isIOS) {
      return ios?.call(await deviceInfo.iosInfo);
    } else if (Platform.isLinux) {
      return linux?.call(await deviceInfo.linuxInfo);
    } else if (Platform.isMacOS) {
      return macos?.call(await deviceInfo.macOsInfo);
    } else if (Platform.isWindows) {
      return windows?.call(await deviceInfo.windowsInfo);
    }
    return null;
  }

  static Future<String> _fetchDeviceName() async {
    final name = await _extractInfoFromDevice<String>(
      android: (info) => info.name,
      ios: (info) => info.name,
      linux: (info) => info.name,
      macos: (info) => info.computerName,
      windows: (info) => info.computerName,
    );
    return name ?? 'Unknown';
  }

  static String _getUniqueIDSync() {
    var id = settings.sync.uniqueId;
    if (id == null) {
      id = Uuid().v4();
      settings.sync.save(uniqueId: id);
    }
    return id;
  }

  static Future<String> _fetchDeviceId() async {
    final id = await _extractInfoFromDevice<String?>(
      android: (info) => info.id,
      ios: (info) => info.identifierForVendor,
      linux: (info) => info.machineId,
      macos: (info) => info.systemGUID,
      windows: (info) => info.deviceId,
    );
    return id ?? '${Platform.operatingSystem}_${Platform.operatingSystemVersion}_${_getUniqueIDSync()}';
  }

  static bool _isPrivateIP(String address) {
    if (address.startsWith('192.168.')) return true; // wifi
    if (address.startsWith('10.')) return true; // general
    if (address.startsWith('100.')) return true; // hotspot/etc
    return false;
  }

  /// 172.16.0.0/12, commonly used by virtual adapters so only as a last resort
  static bool _isPrivateIP172(String address) {
    if (!address.startsWith('172.')) return false;
    final second = int.tryParse(address.substring(4, address.indexOf('.', 4)));
    return second != null && second >= 16 && second <= 31;
  }

  static bool _isVirtualOrCellularInterface(String name) {
    return name.contains('vethernet') ||
        name.contains('wsl') ||
        name.contains('vmware') ||
        name.contains('virtualbox') ||
        name.contains('vbox') ||
        name.contains('loopback') ||
        name.contains('docker') ||
        name.startsWith('br-') ||
        name.startsWith('veth') ||
        name.startsWith('tun') ||
        name.startsWith('tap') ||
        name.startsWith('rmnet') || // android cellular
        name.startsWith('ccmni') || // mediatek cellular
        name.startsWith('pdp') || // ios cellular
        name.startsWith('p2p'); // wifi direct
  }

  static bool _isLanInterface(String name) {
    return name.contains('wlan') ||
        name.contains('wi-fi') ||
        name.contains('wifi') ||
        name.contains('eth') ||
        name.startsWith('ap') || // android hotspot
        name.startsWith('swlan') || // samsung hotspot
        name.startsWith('en'); // macos/ios
  }

  static Future<NetworkInterface?> getPreferredInterface() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);

    NetworkInterface? fallback;
    NetworkInterface? fallback172;

    for (final iface in interfaces) {
      final name = iface.name.toLowerCase();
      if (_isVirtualOrCellularInterface(name)) continue;

      final isLan = _isLanInterface(name);

      for (final addr in iface.addresses) {
        if (addr.isLoopback) continue;
        final address = addr.address;
        if (_isPrivateIP(address)) {
          if (isLan) return iface;
          fallback ??= iface;
          break;
        }
        if (_isPrivateIP172(address)) {
          fallback172 ??= iface;
          break;
        }
      }
    }

    return fallback ?? fallback172;
  }

  /// addresses to advertise, all non-loopback ipv4 when no preferred interface is found.
  static Future<List<InternetAddress>> getAdvertisedAddresses(NetworkInterface? preferredInterface) async {
    if (preferredInterface != null) return preferredInterface.addresses;
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    return <InternetAddress>[
      for (final iface in interfaces)
        for (final addr in iface.addresses)
          if (!addr.isLoopback) addr,
    ];
  }

  static final _kHostNameInvalidCharsRegex = RegExp(r'[^a-z0-9]+');

  /// mdns host name in the form `namida-<id>.local`, `Platform.localHostname` is `localhost` on android.
  static String createMdnsHostName(String deviceId) {
    var id = deviceId.toLowerCase().replaceAll(_kHostNameInvalidCharsRegex, '-');
    if (id.length > 48) id = id.substring(0, 48);
    id = id.replaceAll(RegExp(r'^-+|-+$'), '');
    return id.isEmpty ? 'namida.$kDefaultDomain' : 'namida-$id.$kDefaultDomain';
  }

  static Future<Set<String>> getLocalInterfaceAddresses() async {
    final localeInterfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    final localeInterfacesSet = <String>{};

    for (final interface in localeInterfaces) {
      for (final adr in interface.addresses) {
        localeInterfacesSet.add(adr.address);
      }
    }

    return localeInterfacesSet;
  }
}
