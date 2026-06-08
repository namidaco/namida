part of 'settings_controller.dart';

class EqualizerSettings with SettingsFileWriter {
  static final EqualizerSettings inst = EqualizerSettings._internal();
  EqualizerSettings._internal();

  final preset = Rxn<EqualizerPreset>();
  final equalizerEnabled = false.obs;
  final equalizer = <double, double>{}.obs;
  final loudnessEnhancerEnabled = false.obs;
  final loudnessEnhancer = 0.0.obs;

  final eqPresets = <EqualizerPreset>[...EqualizerPreset.allDefaults].obso;
  final uiTapToUpdate = true.obso;

  void save({
    EqualizerPreset? preset,
    bool resetPreset = false,
    bool? equalizerEnabled,
    MapEntry<double, double>? equalizerValue,
    bool? loudnessEnhancerEnabled,
    double? loudnessEnhancer,
    bool? uiTapToUpdate,
  }) {
    if (preset != null || resetPreset) this.preset.value = preset;
    if (equalizerEnabled != null) this.equalizerEnabled.value = equalizerEnabled;
    if (equalizerValue != null) {
      this.equalizer[equalizerValue.key] = equalizerValue.value;
    }
    if (loudnessEnhancerEnabled != null) this.loudnessEnhancerEnabled.value = loudnessEnhancerEnabled;
    if (loudnessEnhancer != null) this.loudnessEnhancer.value = loudnessEnhancer;
    if (uiTapToUpdate != null) this.uiTapToUpdate.value = uiTapToUpdate;
    _writeToStorage();
  }

  @override
  void applyKuruSettings() {
    uiTapToUpdate.value = false;
  }

  Future<void> prepareSettingsFile() async {
    final json = await prepareSettingsFile_();
    if (json is! Map) return;

    try {
      preset.value = EqualizerPreset.fromMap(json["preset_v2"]);
      equalizerEnabled.value = json["equalizerEnabled"] ?? equalizerEnabled.value;
      final eqMap = json['equalizer'];
      if (eqMap is Map) {
        equalizer.clear();
        final m = eqMap.cast<String, double>();
        equalizer.addAll(m.map((key, value) => MapEntry(double.parse(key), value)));
      }
      loudnessEnhancerEnabled.value = json["loudnessEnhancerEnabled"] ?? loudnessEnhancerEnabled.value;
      loudnessEnhancer.value = json["loudnessEnhancer"] ?? loudnessEnhancer.value;
      uiTapToUpdate.value = json["uiTapToUpdate"] ?? uiTapToUpdate.value;
      eqPresets.value = EqualizerPreset.fromListOrDefault(json["eqPresets"]);
    } catch (e, st) {
      printy(e, isError: true);
      logger.report(e, st);
    }
  }

  @override
  Object get jsonToWrite => <String, dynamic>{
    "preset_v2": preset.value?.toMap(),
    "equalizerEnabled": equalizerEnabled.value,
    "equalizer": equalizer.value.map((key, value) => MapEntry(key.toString(), value)),
    "loudnessEnhancerEnabled": loudnessEnhancerEnabled.value,
    "loudnessEnhancer": loudnessEnhancer.value,
    "uiTapToUpdate": uiTapToUpdate.value,
    "eqPresets": eqPresets.value.map((e) => e.toMap()).toFixedList(),
  };

  Future<void> _writeToStorage() async => await writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_EQUALIZER;
}
