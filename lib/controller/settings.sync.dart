part of 'settings_controller.dart';

class _SyncSettings with SettingsFileWriter {
  _SyncSettings._internal();

  String? uniqueId;

  /// use to auto reconnect
  final allowedServerIds = <String>{};

  final allowedDeviceIds = <String>{};
  final blockedClientIds = <String>{};

  final deviceIdNames = <String, String>{};

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
    } catch (e, st) {
      printy(e, isError: true);
      logger.report(e, st);
    }
  }

  @override
  Object get jsonToWrite => <String, dynamic>{
    'id': ?uniqueId,
    'allowedServerIds': allowedServerIds.toFixedList(),
    'allowedDeviceIds': allowedDeviceIds.toFixedList(),
    'blockedClientIds': blockedClientIds.toFixedList(),
    'deviceIdNames': deviceIdNames,
  };

  Future<void> _writeToStorage() async => await writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_SYNC;
}
