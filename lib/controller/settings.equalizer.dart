part of 'settings_controller.dart';

class _EqualizerSettings extends _SettingsKeysWriter {
  _EqualizerSettings._internal();

  late final preset = _keyObject<EqualizerPreset?>('preset_v2', null, EqualizerPreset.fromMap, (v) => v?.toMap());
  late final equalizerEnabled = _key('equalizerEnabled', false);
  late final equalizer = _keyMap<double, double>('equalizer', const {}, key: const _DoubleStringCodec());
  late final loudnessEnhancerEnabled = _key('loudnessEnhancerEnabled', false);
  late final loudnessEnhancer = _key('loudnessEnhancer', 0.0);

  late final eqPresets = _keyList('eqPresets', EqualizerPreset.allDefaults, item: _ObjectCodec(EqualizerPreset.fromMap, (v) => v.toMap()));
  late final uiTapToUpdate = _key('uiTapToUpdate', isKuru ? false : true);

  @override
  void _migrateLegacy() {
    _dropKey('preset');
  }

  @override
  String get filePath => AppPaths.SETTINGS_EQUALIZER;
}
