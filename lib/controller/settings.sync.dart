part of 'settings_controller.dart';

class _SyncSettings with SettingsFileWriter {
  _SyncSettings._internal();

  String? uniqueId;

  final customDeviceName = Rxn<String>();
  final allowedServerIds = <String>{};

  final allowedDeviceIds = <String>{};
  final blockedClientIds = <String>{};

  final deviceIdNames = <String, String>{};

  // null == all selected
  final syncItems = RxnF<Set<SyncDataItem>>(fallback: {...SyncDataItem.essentialsSet});

  final syncItemsAdvancedView = RxnF<bool>(fallback: false);
  final autoReconnect = RxnF<bool>(fallback: true);

  final autoSyncIntervalMinutes = RxnF<int>(fallback: -1);

  bool serverWasRunning = false;

  void modify(void Function(_SyncSettings syncSettings) callback) {
    callback(this);
    _writeToStorage();
  }

  void updateDeviceName(String id, String name) {
    if (deviceIdNames[id] != name) {
      deviceIdNames[id] = name;
      _writeToStorage();
    }
  }

  void save({
    String? uniqueId,
  }) {
    if (uniqueId != null) this.uniqueId = uniqueId;
    _writeToStorage();
  }

  @override
  void applyKuruSettings() {}

  Future<void> prepareSettingsFile() async {
    final json = await prepareSettingsFile_();
    if (json is! Map) return;

    try {
      uniqueId = json['id'];
      customDeviceName.value = json['customDeviceName'];
      allowedServerIds
        ..clear()
        ..addAll((json['allowedServerIds'] as List?)?.cast<String>() ?? <String>[]);
      allowedDeviceIds
        ..clear()
        ..addAll((json['allowedDeviceIds'] as List?)?.cast<String>() ?? <String>[]);
      blockedClientIds
        ..clear()
        ..addAll((json['blockedClientIds'] as List?)?.cast<String>() ?? <String>[]);
      deviceIdNames
        ..clear()
        ..addAll((json['deviceIdNames'] as Map?)?.cast<String, String>() ?? <String, String>{});
      final syncItemsInStorage = (json['selectedSyncItems'] as List?)?.map((e) => SyncDataItem.lookupMap[e]).whereType<SyncDataItem>();
      if (syncItemsInStorage != null && syncItemsInStorage.isNotEmpty) {
        (syncItems.value ??= <SyncDataItem>{})
          ..clear()
          ..addAll(syncItemsInStorage);
      }
      syncItemsAdvancedView.value = json['syncItemsAdvancedView'] as bool?;
      autoReconnect.value = json['autoReconnect'] as bool?;
      autoSyncIntervalMinutes.value = json['autoSyncIntervalMinutes'] as int?;
      serverWasRunning = json['serverWasRunning'] ?? false;
    } catch (e, st) {
      printy(e, isError: true);
      logger.report(e, st);
    }
  }

  @override
  Object get jsonToWrite => <String, dynamic>{
    'id': ?uniqueId,
    'customDeviceName': ?customDeviceName.value,
    'allowedServerIds': allowedServerIds.toFixedList(),
    'allowedDeviceIds': allowedDeviceIds.toFixedList(),
    'blockedClientIds': blockedClientIds.toFixedList(),
    'deviceIdNames': deviceIdNames,
    'selectedSyncItems': ?syncItems.value?.map((e) => e.name).toFixedList(),
    'syncItemsAdvancedView': ?syncItemsAdvancedView.value,
    'autoReconnect': autoReconnect.value,
    'autoSyncIntervalMinutes': ?autoSyncIntervalMinutes.value,
    'serverWasRunning': serverWasRunning,
  };

  Future<void> _writeToStorage() async => await writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_SYNC;
}
