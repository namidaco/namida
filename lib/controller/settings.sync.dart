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

  /// base64 pair secret per client device id, issued by us as the server when approving it.
  late final issuedPairSecrets = _keyMap<String, String>('issuedPairSecrets', const {}, sync: false);

  /// base64 pair secret per server device id, issued to us by that server. one map per role, so two devices pairing each other both ways at once can't overwrite either secret.
  late final receivedPairSecrets = _keyMap<String, String>('receivedPairSecrets', const {}, sync: false);

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

  /// the server [id] is trusted at [address], it takes that address over from other ids saved there, they are not there anymore.
  /// one without a pair secret is forgotten as a server, it is left from before pairing existed (ex: android's old id, its Build.ID).
  /// a paired one keeps reconnecting when discovered, its address was likely handed to another device.
  void takeOverServerAddress(String id, String address) {
    final movedIds = <String>[];
    final unpairedIds = <String>[];
    final issuedSecrets = issuedPairSecrets.value;
    final receivedSecrets = receivedPairSecrets.value;
    for (final e in manualServerAddresses.value.entries) {
      final otherId = e.key;
      if (otherId == id || e.value != address) continue;
      movedIds.add(otherId);
      final isPaired = issuedSecrets.containsKey(otherId) || receivedSecrets.containsKey(otherId);
      if (!isPaired) unpairedIds.add(otherId);
    }
    if (movedIds.isEmpty) return;
    transaction(() {
      manualServerAddresses.update((addresses) {
        movedIds.loop(addresses.remove);
        addresses[id] = address;
      });
      if (unpairedIds.isEmpty) return;
      allowedServerIds.update((ids) => ids.removeAll(unpairedIds));
      deviceIdNames.update((names) => unpairedIds.loop(names.remove));
    });
  }

  /// [issuedSecret] & [receivedSecret] are new base64 pair secrets, see [issuedPairSecrets] & [receivedPairSecrets].
  void allowDevice(String id, {String? issuedSecret, String? receivedSecret}) {
    transaction(() {
      if (!allowedDeviceIds.value.contains(id)) allowedDeviceIds.update((ids) => ids.add(id));
      if (issuedSecret != null) issuedPairSecrets.update((secrets) => secrets[id] = issuedSecret);
      if (receivedSecret != null) receivedPairSecrets.update((secrets) => secrets[id] = receivedSecret);
    });
  }

  /// drops the trust and the pair secrets of [id] in both roles.
  void forgetDevice(String id) {
    transaction(() {
      if (allowedDeviceIds.value.contains(id)) allowedDeviceIds.update((ids) => ids.remove(id));
      if (issuedPairSecrets.value.containsKey(id)) issuedPairSecrets.update((secrets) => secrets.remove(id));
      if (receivedPairSecrets.value.containsKey(id)) receivedPairSecrets.update((secrets) => secrets.remove(id));
    });
  }

  /// this device's own id and pair secrets, never carried by a backup.
  late final _identityKeyNames = [uniqueId.name, issuedPairSecrets.name, receivedPairSecrets.name];

  /// the file's json without [_identityKeyNames].
  Map<String, dynamic> buildBackupJson() {
    final json = Map<String, dynamic>.of(_raw);
    for (final name in _identityKeyNames) {
      json.remove(name);
    }
    return json;
  }

  /// puts this device's id and pair secrets into [json], the sync settings of a backup that may come from another device.
  void keepIdentityIn(Map<String, dynamic> json) {
    for (final name in _identityKeyNames) {
      final ownJson = _raw[name];
      if (ownJson == null) {
        json.remove(name);
      } else {
        json[name] = ownJson;
      }
    }
  }

  @override
  void _migrateKeys() {
    final didDropOldSecrets = _dropKey('pairSecrets') != null; // -- both roles in one map, unreleased builds
    if (didDropOldSecrets) writeToStorage();
  }

  @override
  Set<String> get sensitiveKeys => const {
    'id', 'customDeviceName', 'deviceIdNames', //
    'allowedDeviceIds', 'blockedClientIds', 'allowedServerIds', 'manualServerAddresses', //
    'issuedPairSecrets', 'receivedPairSecrets', //
  };

  @override
  String get filePath => AppPaths.SETTINGS_SYNC;
}
