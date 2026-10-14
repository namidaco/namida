// by claude
import 'package:namida/class/sort_chain.dart';
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
  TrackSortPresets withActiveSorting(SortChain<SortType> sorting) {
    final activeIndex = this.activeIndex;
    if (activeIndex == null) return this;
    final newPreset = presets[activeIndex].copyWith(sorting: sorting);
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
  final SortChain<SortType> sorting;

  const TrackSortPreset({
    required this.name,
    required this.sorting,
  });

  TrackSortPreset copyWith({
    String? name,
    SortChain<SortType>? sorting,
  }) {
    return TrackSortPreset(
      name: name ?? this.name,
      sorting: sorting ?? this.sorting,
    );
  }

  factory TrackSortPreset.fromJson(Map<String, dynamic> json) {
    return TrackSortPreset(
      name: json['name'],
      sorting: SortChain.fromMap(json, SortType.values),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    ...sorting.toJson(),
  };
}
