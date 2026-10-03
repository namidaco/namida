import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

// rewritten by claude, new one holds multi sort, shuffle, minimum filter and count, and applies them to tracks or videos
class QueueInsertion {
  final int numberOfTracks;
  final bool insertNext;
  final int? sample;
  final int? sampleDays;
  final bool shuffle;
  final List<SortType> sorts;
  final bool sortReverse;
  final SortType? filterSort;
  final Map<SortType, int> filterMinimums;

  const QueueInsertion({
    required this.numberOfTracks,
    required this.insertNext,
    this.sample,
    this.sampleDays,
    this.shuffle = false,
    this.sorts = const [],
    this.sortReverse = false,
    this.filterSort,
    this.filterMinimums = const {},
  });

  int? get maxCount => numberOfTracks == 0 ? null : numberOfTracks;
  bool get isUnsorted => !shuffle && sorts.isEmpty;

  int filterValueOf(SortType sort, TrackMinimum minimum) => filterMinimums[sort] ?? minimum.defaultValue;

  QueueInsertion copyWith({
    int? numberOfTracks,
    bool? insertNext,
    int? sample,
    int? sampleDays,
    bool? shuffle,
    List<SortType>? sorts,
    bool? sortReverse,
    Map<SortType, int>? filterMinimums,
  }) {
    return QueueInsertion(
      numberOfTracks: numberOfTracks ?? this.numberOfTracks,
      insertNext: insertNext ?? this.insertNext,
      sample: sample ?? this.sample,
      sampleDays: sampleDays ?? this.sampleDays,
      shuffle: shuffle ?? this.shuffle,
      sorts: sorts ?? this.sorts,
      sortReverse: sortReverse ?? this.sortReverse,
      filterSort: filterSort,
      filterMinimums: filterMinimums ?? this.filterMinimums,
    );
  }

  QueueInsertion withFilterSort(SortType? filterSort) {
    return QueueInsertion(
      numberOfTracks: numberOfTracks,
      insertNext: insertNext,
      sample: sample,
      sampleDays: sampleDays,
      shuffle: shuffle,
      sorts: sorts,
      sortReverse: sortReverse,
      filterSort: filterSort,
      filterMinimums: filterMinimums,
    );
  }

  /// filters, orders then limits. [tracks] is modified and must be owned by the caller.
  List<Selectable> apply(List<Selectable> tracks) {
    tracks = filtered(tracks);
    if (shuffle) return _shuffled(tracks);
    if (sorts.isNotEmpty) {
      final comparables = sorts.map(_selectableSortingComparable).toFixedList();
      tracks.sortByAltsPrecomputed(comparables, reverse: sortReverse);
    }
    return _limited(tracks);
  }

  /// returns [tracks] itself when there is no active filter.
  List<Selectable> filtered(List<Selectable> tracks) {
    final filterSort = this.filterSort;
    if (filterSort == null) return tracks;
    final minimum = TrackMinimum.of(filterSort);
    if (minimum == null) return tracks;
    final value = filterValueOf(filterSort, minimum);
    return minimum.filter(tracks, value);
  }

  /// same as [apply] for videos, which only support shuffling and listens count ordering.
  List<YoutubeID> applyYoutube(List<YoutubeID> videos) {
    if (shuffle) return _shuffled(videos);
    if (sorts.contains(SortType.mostPlayed)) {
      final listensMap = YoutubeHistoryController.inst.topTracksMapListens.value;
      videos.sortByAltsPrecomputed([(e) => -(listensMap[e.id]?.length ?? 0)], reverse: sortReverse);
    }
    return _limited(videos);
  }

  List<T> _shuffled<T>(List<T> items) {
    final maxCount = this.maxCount;
    if (maxCount != null && maxCount < items.length) {
      final sample = items.getRandomSample(maxCount);
      sample.shuffle();
      return sample;
    }
    items.shuffle();
    return items;
  }

  List<T> _limited<T>(List<T> items) {
    final maxCount = this.maxCount;
    if (maxCount != null && maxCount < items.length) return items.sublist(0, maxCount);
    return items;
  }

  static Comparable Function(Selectable e) _selectableSortingComparable(SortType sort) {
    final trackComparable = SearchSortController.inst.getTracksSortingComparables(sort);
    return (e) => trackComparable(e.track);
  }

  factory QueueInsertion.fromJson(Map<String, dynamic> map) {
    final legacySortBy = map['sortBy'];
    final filterMinimumsJson = map['filterMinimums'];
    final filterMinimums = <SortType, int>{};
    if (filterMinimumsJson is Map) {
      for (final e in filterMinimumsJson.entries) {
        final sort = SortType.values.getEnum(e.key);
        final value = e.value;
        if (sort != null && value is int) filterMinimums[sort] = value;
      }
    }
    final sortsJson = map['sorts'];
    final sorts = sortsJson is List ? sortsJson.map((e) => SortType.values.getEnum(e)).nonNulls.toFixedList() : _legacySorts(legacySortBy);
    return QueueInsertion(
      numberOfTracks: map['numberOfTracks'],
      insertNext: map['insertNext'],
      sample: map['sample'],
      sampleDays: map['sampleDays'],
      shuffle: map['shuffle'] ?? legacySortBy == 'random',
      sorts: sorts,
      sortReverse: map['sortReverse'] ?? legacySortBy == 'rating',
      filterSort: SortType.values.getEnum(map['filterSort']),
      filterMinimums: filterMinimums,
    );
  }

  static List<SortType> _legacySorts(dynamic legacySortBy) => switch (legacySortBy) {
    'listenCount' => const [SortType.mostPlayed],
    'rating' => const [SortType.rating],
    _ => const [],
  };

  Map<String, dynamic> toJson() {
    final filterSort = this.filterSort;
    return {
      'numberOfTracks': numberOfTracks,
      'insertNext': insertNext,
      if (sample != null) 'sample': sample,
      if (sampleDays != null) 'sampleDays': sampleDays,
      'shuffle': shuffle,
      'sorts': [for (final sort in sorts) sort.name],
      'sortReverse': sortReverse,
      if (filterSort != null) 'filterSort': filterSort.name,
      'filterMinimums': {for (final e in filterMinimums.entries) e.key.name: e.value},
    };
  }
}

class TrackMinimum {
  final int min;
  final int max;
  final int stepper;
  final int defaultValue;
  final String Function(int value) formatter;
  final num? Function(Track tr) valueOf;

  const TrackMinimum({
    required this.min,
    required this.max,
    required this.stepper,
    required this.defaultValue,
    required this.formatter,
    required this.valueOf,
  });

  static const supportedSorts = [
    SortType.rating, SortType.mostPlayed, SortType.duration, SortType.bitrate, //
    SortType.bpm, SortType.size, SortType.year, //
  ];

  static TrackMinimum? of(SortType sort) => switch (sort) {
    SortType.rating => TrackMinimum(min: 0, max: 100, stepper: 5, defaultValue: 75, formatter: (v) => '$v%', valueOf: (tr) => tr.effectiveRating),
    SortType.mostPlayed => TrackMinimum(min: 0, max: 500, stepper: 1, defaultValue: 0, formatter: (v) => '$v', valueOf: _listensCountOf),
    SortType.duration => TrackMinimum(min: 0, max: 1200, stepper: 10, defaultValue: 0, formatter: (v) => v.secondsLabel, valueOf: (tr) => tr.durationMS / 1000),
    SortType.bitrate => TrackMinimum(min: 0, max: 1411, stepper: 1, defaultValue: 0, formatter: (v) => '$v kb/s', valueOf: (tr) => tr.bitrate),
    SortType.bpm => TrackMinimum(min: 0, max: 300, stepper: 1, defaultValue: 0, formatter: (v) => '$v BPM', valueOf: (tr) => tr.bpm),
    SortType.size => TrackMinimum(min: 0, max: 200, stepper: 1, defaultValue: 0, formatter: (v) => '$v MB', valueOf: (tr) => tr.size / (1024 * 1024)),
    SortType.year => TrackMinimum(min: 1900, max: DateTime.now().year, stepper: 1, defaultValue: 1900, formatter: (v) => '$v', valueOf: _yearOf),
    _ => null,
  };

  static int _listensCountOf(Track tr) => HistoryController.inst.topTracksMapListens.value[tr]?.length ?? 0;

  static int? _yearOf(Track tr) {
    final year = tr.year;
    if (year == 0) return null;
    return year < 10000 ? year : year ~/ 10000;
  }

  bool isActive(int value) => value > min;

  /// returns [tracks] itself when the minimum is inactive.
  List<Selectable> filter(List<Selectable> tracks, int value) {
    if (!isActive(value)) return tracks;
    return tracks.where((e) => (valueOf(e.track) ?? -1) >= value).toList();
  }
}
