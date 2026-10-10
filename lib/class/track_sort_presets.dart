// by claude
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

/// a media type's saved sort chains, a null [activeIndex] means the default chain is used.
class TrackSortPresets {
  static const maxCount = 10;

  final List<TrackSortPreset> presets;
  final int? activeIndex;

  const TrackSortPresets({
    required this.presets,
    required this.activeIndex,
  });

  const TrackSortPresets.empty() : presets = const [], activeIndex = null;

  bool get canAdd => presets.length < maxCount;

  TrackSortPreset? get activePreset {
    final activeIndex = this.activeIndex;
    return activeIndex == null ? null : presets[activeIndex];
  }

  TrackSortPresets withActive(int? index) => TrackSortPresets(presets: presets, activeIndex: index);

  TrackSortPresets withAdded(TrackSortPreset preset) {
    final newPresets = [...presets, preset];
    return TrackSortPresets(presets: newPresets, activeIndex: newPresets.length - 1);
  }

  TrackSortPresets withReplaced(int index, TrackSortPreset preset) {
    final newPresets = presets.toList();
    newPresets[index] = preset;
    return TrackSortPresets(presets: newPresets, activeIndex: activeIndex);
  }

  /// unchanged when no preset is active.
  TrackSortPresets withActiveChain({List<SortType>? sorts, bool? reverse}) {
    final activeIndex = this.activeIndex;
    if (activeIndex == null) return this;
    final newPreset = presets[activeIndex].copyWith(sorts: sorts, reverse: reverse);
    return withReplaced(activeIndex, newPreset);
  }

  TrackSortPresets withRemoved(int index) {
    final newPresets = presets.toList();
    newPresets.removeAt(index);
    int? newActiveIndex = activeIndex;
    if (newActiveIndex == index) {
      newActiveIndex = null;
    } else if (newActiveIndex != null && newActiveIndex > index) {
      newActiveIndex--;
    }
    return TrackSortPresets(presets: newPresets, activeIndex: newActiveIndex);
  }

  factory TrackSortPresets.fromJson(Map<String, dynamic> json) {
    final List presetsJson = json['presets'];
    final presets = presetsJson.map((e) => TrackSortPreset.fromJson(e)).toFixedList();
    final int? activeIndex = json['active'];
    final isActiveValid = activeIndex != null && activeIndex >= 0 && activeIndex < presets.length;
    return TrackSortPresets(
      presets: presets,
      activeIndex: isActiveValid ? activeIndex : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'presets': [for (final preset in presets) preset.toJson()],
    'active': ?activeIndex,
  };
}

class TrackSortPreset {
  final String name;
  final List<SortType> sorts;
  final bool reverse;

  const TrackSortPreset({
    required this.name,
    required this.sorts,
    required this.reverse,
  });

  TrackSortPreset copyWith({
    String? name,
    List<SortType>? sorts,
    bool? reverse,
  }) {
    return TrackSortPreset(
      name: name ?? this.name,
      sorts: sorts ?? this.sorts,
      reverse: reverse ?? this.reverse,
    );
  }

  factory TrackSortPreset.fromJson(Map<String, dynamic> json) {
    final List sortsJson = json['sorts'];
    final sorts = sortsJson.map((e) => SortType.values.getEnum(e)).nonNulls.toFixedList();
    return TrackSortPreset(
      name: json['name'],
      sorts: sorts,
      reverse: json['reverse'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'sorts': [for (final sort in sorts) sort.name],
    'reverse': reverse,
  };
}
