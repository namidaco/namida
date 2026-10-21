// by claude
import 'package:namida/class/sort_chain.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

/// saved named values, a null [activeIndex] means the default value is used.
class NamedPresets<T> {
  static const maxCount = 10;

  final List<NamedPreset<T>> presets;
  final int? activeIndex;

  const NamedPresets({
    required this.presets,
    required this.activeIndex,
  });

  const NamedPresets.empty() : presets = const [], activeIndex = null;

  bool get canAdd => presets.length < maxCount;

  NamedPreset<T>? get activePreset {
    final activeIndex = this.activeIndex;
    return activeIndex == null ? null : presets[activeIndex];
  }

  NamedPresets<T> withActive(int? index) => NamedPresets(presets: presets, activeIndex: index);

  NamedPresets<T> withAdded(NamedPreset<T> preset) {
    final newPresets = <NamedPreset<T>>[...presets, preset];
    return NamedPresets(presets: newPresets, activeIndex: newPresets.length - 1);
  }

  NamedPresets<T> withReplaced(int index, NamedPreset<T> preset) {
    final newPresets = List<NamedPreset<T>>.of(presets);
    newPresets[index] = preset;
    return NamedPresets(presets: newPresets, activeIndex: activeIndex);
  }

  /// unchanged when no preset is active.
  NamedPresets<T> withActiveValue(T value) {
    final activeIndex = this.activeIndex;
    if (activeIndex == null) return this;
    final newPreset = presets[activeIndex].copyWith(value: value);
    return withReplaced(activeIndex, newPreset);
  }

  NamedPresets<T> withRemoved(int index) {
    final newPresets = List<NamedPreset<T>>.of(presets);
    newPresets.removeAt(index);
    int? newActiveIndex = activeIndex;
    if (newActiveIndex == index) {
      newActiveIndex = null;
    } else if (newActiveIndex != null && newActiveIndex > index) {
      newActiveIndex--;
    }
    return NamedPresets(presets: newPresets, activeIndex: newActiveIndex);
  }
}

class NamedPreset<T> {
  final String name;
  final T value;

  const NamedPreset({
    required this.name,
    required this.value,
  });

  NamedPreset<T> copyWith({
    String? name,
    T? value,
  }) {
    return NamedPreset(
      name: name ?? this.name,
      value: value ?? this.value,
    );
  }
}

/// a preset's value is stored next to its name, inside the same json map.
class NamedPresetsCodec<T> {
  static final trackSorting = NamedPresetsCodec<SortChain<SortType>>(
    valueFromJson: (json) => SortChain.fromMap(json, SortType.values),
    valueToJson: (sorting) => sorting.toJson(),
  );

  static final trackSearchFilter = NamedPresetsCodec<List<TrackSearchFilter>>(
    valueFromJson: _searchFiltersFromJson,
    valueToJson: (filters) => {'filters': filters.map((e) => e.name).toFixedList()},
  );

  static List<TrackSearchFilter> _searchFiltersFromJson(Map<String, dynamic> json) {
    final List filtersJson = json['filters'];
    return filtersJson.map((e) => TrackSearchFilter.values.getEnum(e)).nonNulls.toFixedList();
  }

  final T Function(Map<String, dynamic> json) valueFromJson;
  final Map<String, dynamic> Function(T value) valueToJson;

  NamedPresetsCodec({
    required this.valueFromJson,
    required this.valueToJson,
  });

  NamedPresets<T> decode(Map<String, dynamic> json) {
    final List presetsJson = json['presets'];
    final presets = presetsJson.map((e) => _decodePreset(e)).toFixedList();
    final int? activeIndex = json['active'];
    final isActiveValid = activeIndex != null && activeIndex >= 0 && activeIndex < presets.length;
    return NamedPresets(
      presets: presets,
      activeIndex: isActiveValid ? activeIndex : null,
    );
  }

  NamedPreset<T> _decodePreset(Map<String, dynamic> json) {
    return NamedPreset(
      name: json['name'],
      value: valueFromJson(json),
    );
  }

  Map<String, dynamic> encode(NamedPresets<T> presets) => {
    'presets': presets.presets.map(_encodePreset).toFixedList(),
    'active': ?presets.activeIndex,
  };

  Map<String, dynamic> _encodePreset(NamedPreset<T> preset) => {
    'name': preset.name,
    ...valueToJson(preset.value),
  };
}

typedef TrackSortPresets = NamedPresets<SortChain<SortType>>;
typedef TrackSortPreset = NamedPreset<SortChain<SortType>>;

typedef TrackSearchFilterPresets = NamedPresets<List<TrackSearchFilter>>;
typedef TrackSearchFilterPreset = NamedPreset<List<TrackSearchFilter>>;
