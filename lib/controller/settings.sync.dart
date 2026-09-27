part of 'settings_controller.dart';

class _SyncSettings extends _SettingsKeysWriter {
  _SyncSettings._internal();

  late final uniqueId = _key<String?>('id', null);
  late final customDeviceName = _key<String?>('customDeviceName', null);
  late final deviceIdNames = _keyMap<String, String>('deviceIdNames', const {});

  late final allowedServerIds = _keySet<String>('allowedServerIds', const {});
  late final allowedDeviceIds = _keySet<String>('allowedDeviceIds', const {});
  late final blockedClientIds = _keySet<String>('blockedClientIds', const {});
  late final manualServerAddresses = _keyMap<String, String>('manualServerAddresses', const {});

  late final autoReconnect = _key('autoReconnect', true);
  late final serverWasRunning = _key('serverWasRunning', false);
  late final autoSyncIntervalMinutes = _key('autoSyncIntervalMinutes', -1);
  late final syncItems = _keySet('selectedSyncItems', SyncDataItem.essentialsSet, item: SyncDataItem.values.asCodec());
  late final syncItemsAdvancedView = _key('syncItemsAdvancedView', false);

  void updateDeviceName(String id, String name) {
    if (deviceIdNames.value[id] == name) return;
    deviceIdNames.update((names) => names[id] = name);
  }

  void updateManualServerAddress(String id, String address) {
    final current = manualServerAddresses.value[id];
    if (current == null || current == address) return;
    manualServerAddresses.update((addresses) => addresses[id] = address);
  }

  @override
  Set<String> get sensitiveKeys => const {
    'id', 'customDeviceName', 'deviceIdNames', //
    'allowedDeviceIds', 'blockedClientIds', 'allowedServerIds', 'manualServerAddresses', //
  };

  @override
  String get filePath => AppPaths.SETTINGS_SYNC;
}
