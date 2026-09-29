part of 'settings_controller.dart';

class _EqualizerSettings extends _SettingsKeysWriter {
  _EqualizerSettings._internal();

  late final preset = _keyObject<EqualizerPreset?>('preset_v3', null, EqualizerPreset.fromMap, (v) => v?.toMap());
  late final equalizerEnabled = _key('equalizerEnabled', false);
  late final equalizer = _keyObject<ParametricEqualizer>('parametricEqualizer', ParametricEqualizer.flat, ParametricEqualizer.fromMap, (v) => v.toMap());
  late final loudnessEnhancerEnabled = _key('loudnessEnhancerEnabled', false);
  late final loudnessEnhancer = _key('loudnessEnhancer', 0.0);

  late final eqPresets = _keyList('eqPresets_v2', EqualizerPreset.allDefaults, item: _ObjectCodec(EqualizerPreset.fromMap, (v) => v.toMap()));

  /// [AudioOutputDevice.key] -> [EqualizerPreset.name], applied when that device becomes the output.
  late final devicePresets = _keyMap<String, String>('devicePresets', const {}, sync: false);
  late final uiTapToUpdate = _key('uiTapToUpdate', isKuru ? false : true);

  /// replaces the preset named [replacing], or [preset]'s own name, in place, appends it otherwise.
  void putPreset(EqualizerPreset preset, {String? replacing}) {
    final oldName = replacing ?? preset.name;
    transaction(() {
      eqPresets.update((presets) {
        final index = presets.indexWhere((p) => p.name == oldName);
        if (index < 0) {
          presets.add(preset);
        } else {
          presets[index] = preset;
        }
      });
      if (oldName != preset.name) _renameDevicePresets(oldName, preset.name);
    });
  }

  void removePreset(String name) {
    transaction(() {
      eqPresets.update((presets) => presets.removeWhere((p) => p.name == name));
      _renameDevicePresets(name, null);
    });
  }

  void _renameDevicePresets(String oldName, String? newName) {
    if (!devicePresets.value.containsValue(oldName)) return;
    devicePresets.update((map) {
      for (final deviceKey in map.keys.toList()) {
        if (map[deviceKey] != oldName) continue;
        if (newName == null) {
          map.remove(deviceKey);
        } else {
          map[deviceKey] = newName;
        }
      }
    });
  }

  @override
  void _migrateLegacy() {
    _dropKey('preset');
  }

  @override
  void _migrateKeys() {
    _migrateKey('equalizer', 'parametricEqualizer', (json) {
      if (json is! Map || json.isEmpty) return null;
      final gains = <double, double>{};
      for (final e in json.entries) {
        final frequency = double.tryParse('${e.key}');
        final gain = e.value;
        if (frequency != null && gain is num) gains[frequency] = gain.toDouble();
      }
      return gains.isEmpty ? null : ParametricEqualizer.fromLegacyGains(gains).toMap();
    });
    _migrateKey('preset_v2', 'preset_v3', (json) => json is Map ? EqualizerPreset.fromMap(json)?.toMap() : null);
    _migrateKey('eqPresets', 'eqPresets_v2', (json) {
      if (json is! List) return null;
      return [
        for (final item in json)
          if (item is Map) ?EqualizerPreset.fromMap(item)?.toMap(),
      ];
    });
  }

  @override
  String get filePath => AppPaths.SETTINGS_EQUALIZER;
}
