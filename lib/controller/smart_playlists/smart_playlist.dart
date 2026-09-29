part of 'smart_playlists_controller.dart';

typedef SmartPlaylistKey = String;

class SmartPlaylistWrapper extends Rx<SmartPlaylist> {
  SmartPlaylistWrapper(super.value);

  List<Track> resolve() => value.resolve();
}

class SmartPlaylist {
  SmartPlaylistKey get key => name;

  final String name;
  final DateTime creationDate;
  final SmartJoiner joiner;
  final List<SortType> sorts;
  final bool sortReverse;
  final List<String> moods;
  final List<SmartPlaylistRuleGroup> ruleGroups;
  final SmartPlaylistLimit? limit;

  final int modifiedDate;

  const SmartPlaylist({
    required this.name,
    required this.creationDate,
    required this.joiner,
    required this.sorts,
    required this.sortReverse,
    required this.moods,
    required this.ruleGroups,
    required this.limit,
    this.modifiedDate = 0,
  });

  List<Track> resolve() {
    final allTracks = Indexer.inst.tracksInfoList.value;
    final limit = this.limit;
    if (limit == null && sorts.isEmpty) {
      final orderedTracks = sortReverse ? allTracks.reversed : allTracks;
      return resolveIterableUnSorted(orderedTracks).toList();
    }

    final matched = resolveIterableUnSorted(allTracks).toList();
    final list = limit == null ? matched : limit.select(matched);
    if (sorts.isNotEmpty) {
      final comparables = sorts.map(SearchSortController.inst.getTracksSortingComparables).toFixedList();
      list.sortByAltsPrecomputed(comparables, reverse: sortReverse);
      return list;
    }
    return sortReverse ? list.reversed.toList() : list;
  }

  int resolveCount() {
    final matched = resolveIterableUnSorted(Indexer.inst.tracksInfoList.value);
    final limit = this.limit;
    if (limit == null) return matched.length;
    final matchedList = matched.toList();
    return limit.selectCount(matchedList);
  }

  Set<int> resolveAsIndicesSetUnsorted() {
    final allTracks = Indexer.inst.tracksInfoList.value;
    return resolveIterableUnSortedAsIndices(allTracks).toSet();
  }

  Iterable<Track> resolveIterableUnSorted(Iterable<Track> allTracks) sync* {
    final effectiveGroups = _setupGroupsBeforeResolving();
    final context = _SmartPlaylistResolveContext();

    for (final track in allTracks) {
      final isMatch = _isMatch(effectiveGroups, track, context);
      if (isMatch) yield track;
    }
  }

  Iterable<int> resolveIterableUnSortedAsIndices(Iterable<Track> allTracks) sync* {
    final effectiveGroups = _setupGroupsBeforeResolving();
    final context = _SmartPlaylistResolveContext();

    int index = 0;
    for (final track in allTracks) {
      final isMatch = _isMatch(effectiveGroups, track, context);
      if (isMatch) yield index;
      index++;
    }
  }

  bool _isMatch(List<SmartPlaylistRuleGroup> effectiveGroups, Track track, _SmartPlaylistResolveContext context) {
    return switch (joiner) {
      SmartJoiner.and => effectiveGroups.every((group) => group._matches(track, context)),
      SmartJoiner.or => effectiveGroups.any((group) => group._matches(track, context)),
    };
  }

  List<SmartPlaylistRuleGroup> _setupGroupsBeforeResolving() {
    final effectiveGroups = ruleGroups.where((group) => group.rules.isNotEmpty).toFixedList();
    if (effectiveGroups.isEmpty) return effectiveGroups;

    // inject date filters into the number rules that require the date filters (eg: totalListensInRange)
    for (final g in ruleGroups) {
      final numberRulesNeedingDate = g.rules.whereType<SmartPlaylistRuleNumber>().where((r) => r.source == SmartPlaylistRuleFilterNumberSource.totalListensInRange);
      if (numberRulesNeedingDate.isEmpty) continue;

      final dateRules = g.rules.whereType<SmartPlaylistRuleDateTime>().where((r) => r.source == SmartPlaylistRuleFilterDateTimeSource.rangeOnly);
      if (dateRules.isNotEmpty) {
        final bool Function(int? msse) combinedFilter = switch (g.joiner) {
          SmartJoiner.and => (msse) => dateRules.every((dr) => dr.matchesTimestamp(msse)),
          SmartJoiner.or => (msse) => dateRules.any((dr) => dr.matchesTimestamp(msse)),
        };
        for (final rule in numberRulesNeedingDate) {
          rule.siblingDateFilter = combinedFilter;
        }
      }
    }

    return effectiveGroups;
  }

  factory SmartPlaylist.fromMap(Map<String, dynamic> map) {
    return SmartPlaylist(
      name: map['name'] as String,
      creationDate: DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
      joiner: SmartJoiner.values.getEnum(map['joiner']) ?? SmartJoiner.defaultForGroups,
      sorts: _parseSorts(map),
      sortReverse: map['sortReverse'] as bool,
      moods: (map['moods'] as List).cast<String>(),
      ruleGroups: (map['ruleGroups'] as List).map(SmartPlaylistRuleGroup.fromMap).toList(),
      limit: SmartPlaylistLimit.fromMapNullable(map['limit']),
      modifiedDate: map['_mt'] as int? ?? 0,
    );
  }

  static List<SortType> _parseSorts(Map<String, dynamic> map) {
    final sortsRaw = map['sorts'];
    if (sortsRaw != null) return SortType.sortListFromJsonList(sortsRaw) ?? const [];
    final legacySort = SortType.values.getEnum(map['sort']);
    return legacySort == null ? const [] : [legacySort];
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'creationDate': creationDate.millisecondsSinceEpoch,
      'joiner': joiner.name,
      'sorts': SortType.sortsToJson(sorts),
      'sortReverse': sortReverse,
      'moods': moods,
      'ruleGroups': ruleGroups.map((e) => e.toMap()).toFixedList(),
      'limit': ?limit?.toMap(),
      if (modifiedDate > 0) '_mt': modifiedDate,
    };
  }

  SmartPlaylist copyWith({
    String? name,
    DateTime? creationDate,
    SmartJoiner? joiner,
    List<SortType>? sorts,
    bool? sortReverse,
    List<String>? moods,
    List<SmartPlaylistRuleGroup>? ruleGroups,
    int? modifiedDate,
  }) => SmartPlaylist(
    name: name ?? this.name,
    creationDate: creationDate ?? this.creationDate,
    joiner: joiner ?? this.joiner,
    sorts: sorts ?? this.sorts,
    sortReverse: sortReverse ?? this.sortReverse,
    moods: moods ?? this.moods,
    ruleGroups: ruleGroups ?? this.ruleGroups,
    limit: this.limit,
    modifiedDate: modifiedDate ?? this.modifiedDate,
  );
}

class SmartPlaylistRuleGroup {
  final SmartJoiner joiner;
  final List<SmartPlaylistRuleBase> rules;

  const SmartPlaylistRuleGroup({
    required this.joiner,
    required this.rules,
  });

  factory SmartPlaylistRuleGroup.create({
    SmartJoiner joiner = SmartJoiner.defaultForRules,
    List<SmartPlaylistRuleBase>? rules,
  }) => SmartPlaylistRuleGroup(
    joiner: joiner,
    rules: rules ?? [],
  );

  SmartPlaylistRuleGroup copy() => SmartPlaylistRuleGroup(
    joiner: joiner,
    rules: rules.toList(),
  );

  bool _matches(Track track, _SmartPlaylistResolveContext context) {
    final effectiveRules = rules.where((r) => r.source != SmartPlaylistRuleFilterDateTimeSource.rangeOnly);
    return switch (joiner) {
      SmartJoiner.and => effectiveRules.every((element) => element._matches(track, context)),
      SmartJoiner.or => effectiveRules.any((element) => element._matches(track, context)),
    };
  }

  SmartPlaylistRuleGroup copyWith({
    SmartJoiner? joiner,
    List<SmartPlaylistRuleBase>? rules,
  }) => SmartPlaylistRuleGroup(
    joiner: joiner ?? this.joiner,
    rules: rules ?? this.rules,
  );

  factory SmartPlaylistRuleGroup.fromMap(dynamic map) {
    map as Map;
    return SmartPlaylistRuleGroup(
      joiner: SmartJoiner.values.getEnum(map['joiner']) ?? SmartJoiner.defaultForRules,
      rules: (map['rules'] as List).map(SmartPlaylistRuleBase.fromMap).whereType<SmartPlaylistRuleBase>().toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'joiner': joiner.name,
      'rules': rules.map((e) => e.toMap()).toFixedList(),
    };
  }
}

/// values shared by all rules during a single resolve, built lazily & dropped afterwards since listens/playlists keep changing.
///
/// by claude
class _SmartPlaylistResolveContext {
  final nowMS = currentTimeMS;

  Map<Track, List<String>>? _trackPlaylists;
  Map<Track, List<String>>? _trackPlaylistsTags;
  final _scopeValuesPerRule = Map<SmartPlaylistRuleNumber, Map<Object?, num?>>.identity();

  List<String>? playlistsOf(Track track) {
    final trackPlaylists = _trackPlaylists ??= _buildTrackPlaylists();
    return trackPlaylists[track];
  }

  /// a nested tag counts as each of its parents too.
  List<String>? playlistsTagsOf(Track track) {
    final trackPlaylistsTags = _trackPlaylistsTags ??= _buildTrackPlaylistsTags();
    return trackPlaylistsTags[track];
  }

  Map<Object?, num?> scopeValuesOf(SmartPlaylistRuleNumber rule) => _scopeValuesPerRule[rule] ??= <Object?, num?>{};

  static Map<Track, List<String>> _buildTrackPlaylists() {
    final trackPlaylists = <Track, List<String>>{};
    for (final pl in PlaylistController.inst.playlistsMap.value.values) {
      final plName = pl.name;
      for (final twd in pl.tracks) {
        final names = trackPlaylists[twd.track] ??= <String>[];
        // -- a playlist's tracks are all visited before the next one, so a duplicate can only follow its own name
        if (names.isEmpty || names.last != plName) names.add(plName);
      }
    }
    return trackPlaylists;
  }

  static Map<Track, List<String>> _buildTrackPlaylistsTags() {
    final trackPlaylistsTags = <Track, List<String>>{};
    for (final pl in PlaylistController.inst.playlistsMap.value.values) {
      if (pl.tags.isEmpty) continue;
      final paths = PlaylistTagsFilter.expandTags(pl.tags);
      for (final twd in pl.tracks) {
        final tags = trackPlaylistsTags[twd.track] ??= <String>[];
        for (final path in paths) {
          if (!tags.contains(path)) tags.add(path);
        }
      }
    }
    return trackPlaylistsTags;
  }
}

sealed class SmartPlaylistRuleBase<T, T2, F extends SmartPlaylistRuleFilter, S extends SmartPlaylistRuleFilterSource> {
  static ListensSortedMap get topTracksMapListens => HistoryController.inst.topTracksMapListens.value;
  static FavouritePlaylist<TrackWithDate, Track, SortType> get favouritesMap => PlaylistController.inst.favouritesPlaylist;

  final SmartPlaylistFilterType type;
  final F filter;
  final S source;
  final T? data;
  final T2? data2;
  final bool enableCleanup;
  final bool clockOnly;
  final SmartPlaylistRelativeDuration? relativeDuration;

  const SmartPlaylistRuleBase({
    required this.type,
    required this.filter,
    required this.source,
    required this.data,
    required this.data2,
    required this.enableCleanup,
    required this.clockOnly,
    required this.relativeDuration,
  });

  static SmartPlaylistRuleBase buildFrom({
    required final SmartPlaylistFilterType type,
    required final SmartPlaylistRuleFilter filter,
    required final SmartPlaylistRuleFilterSource source,
    required final bool enableCleanup,
    required final bool clockOnly,
    required final SmartPlaylistRelativeDuration? relativeDuration,
  }) => switch (type) {
    SmartPlaylistFilterType.text => SmartPlaylistRuleText(
      data: null,
      data2: null,
      filter: filter as SmartPlaylistRuleFilterText,
      source: source as SmartPlaylistRuleFilterTextSource,
      enableCleanup: enableCleanup,
    ),
    SmartPlaylistFilterType.number => SmartPlaylistRuleNumber(
      data: null,
      data2: null,
      filter: filter as SmartPlaylistRuleFilterNumber,
      source: source as SmartPlaylistRuleFilterNumberSource,
      enableCleanup: enableCleanup,
      scope: source.requiresScope ? SmartPlaylistNumberScope.artist : SmartPlaylistNumberScope.track,
      aggregate: source.defaultAggregate,
    ),
    SmartPlaylistFilterType.dateTime => SmartPlaylistRuleDateTime(
      data: null,
      data2: null,
      filter: filter as SmartPlaylistRuleFilterDateTime,
      source: source as SmartPlaylistRuleFilterDateTimeSource,
      enableCleanup: enableCleanup,
      clockOnly: clockOnly,
      relativeDuration: relativeDuration ?? (filter.isRelativeDate ? SmartPlaylistRelativeDuration.initial() : null),
    ),
    SmartPlaylistFilterType.boolean => SmartPlaylistRuleBoolean(
      filter: filter as SmartPlaylistRuleFilterBoolean,
      source: source as SmartPlaylistRuleFilterBooleanSource,
      enableCleanup: enableCleanup,
    ),
  };

  SmartPlaylistRuleBase<T, T2, F, S> copyWith({
    (T? data, T2? data2)? datas,
    F? filter,
    bool? enableCleanup,
    bool? clockOnly,
    SmartPlaylistRelativeDuration? relativeDuration,
  });

  String datasDisplayText();
  String sourceDisplayText() => source.toText();
  T? textToData(String? value);
  T2? textToData2(String? value);
  String? dataToText(T? data);
  String? data2ToText(T2? data2);
  String? toHintText();
  String? validate();
  String? dataValidator(String? value);
  bool _matches(Track track, _SmartPlaylistResolveContext context);

  static SmartPlaylistRuleBase? fromMap(dynamic map) {
    map as Map;
    final type = SmartPlaylistFilterType.values.getEnum(map['type']);
    if (type == null) return null;
    try {
      return switch (type) {
        SmartPlaylistFilterType.text => SmartPlaylistRuleText.fromMap(map),
        SmartPlaylistFilterType.number => SmartPlaylistRuleNumber.fromMap(map),
        SmartPlaylistFilterType.dateTime => SmartPlaylistRuleDateTime.fromMap(map),
        SmartPlaylistFilterType.boolean => SmartPlaylistRuleBoolean.fromMap(map),
      };
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> toMap();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SmartPlaylistRuleBase) return false;
    return other.type == type && //
        other.filter == filter &&
        other.source == source &&
        other.data == data &&
        other.data2 == data2 &&
        other.enableCleanup == enableCleanup &&
        other.clockOnly == clockOnly &&
        other.relativeDuration == relativeDuration;
  }

  @override
  int get hashCode =>
      type.hashCode ^ //
      filter.hashCode ^
      source.hashCode ^
      data.hashCode ^
      data2.hashCode ^
      enableCleanup.hashCode ^
      clockOnly.hashCode ^
      relativeDuration.hashCode;
}

enum SmartJoiner {
  and,
  or,
  ;

  static const defaultForGroups = and;
  static const defaultForRules = and;

  String toTitle() => switch (this) {
    SmartJoiner.and => lang.all,
    SmartJoiner.or => lang.any,
  };

  String toText() => switch (this) {
    SmartJoiner.and => lang.and,
    SmartJoiner.or => lang.or,
  };
}

enum SmartPlaylistFilterType {
  text,
  number,
  dateTime,
  boolean,
  ;

  List<SmartPlaylistRuleFilter> getRuleFilters() => resolveRuleFilters(
    (values) => values,
    (values) => values,
    (values) => values,
    (values) => values,
  );

  List<SmartPlaylistRuleFilterSource> getRuleSources({required bool withoutCustomSource}) => resolveRuleFiltersSources(
    (values) => values,
    (values) => values,
    (values) => withoutCustomSource ? values.where((e) => e != SmartPlaylistRuleFilterDateTimeSource.rangeOnly).toList() : values,
    (values) => values,
  );

  R resolveRuleFilters<R>(
    R Function(List<SmartPlaylistRuleFilterText> values) text,
    R Function(List<SmartPlaylistRuleFilterNumber> values) number,
    R Function(List<SmartPlaylistRuleFilterDateTime> values) dateTime,
    R Function(List<SmartPlaylistRuleFilterBoolean> values) boolean,
  ) => switch (this) {
    SmartPlaylistFilterType.text => text(SmartPlaylistRuleFilterText.values),
    SmartPlaylistFilterType.number => number(SmartPlaylistRuleFilterNumber.values),
    SmartPlaylistFilterType.dateTime => dateTime(SmartPlaylistRuleFilterDateTime.values),
    SmartPlaylistFilterType.boolean => boolean(SmartPlaylistRuleFilterBoolean.values),
  };

  R resolveRuleFiltersSources<R>(
    R Function(List<SmartPlaylistRuleFilterTextSource> values) text,
    R Function(List<SmartPlaylistRuleFilterNumberSource> values) number,
    R Function(List<SmartPlaylistRuleFilterDateTimeSource> values) dateTime,
    R Function(List<SmartPlaylistRuleFilterBooleanSource> values) boolean,
  ) => switch (this) {
    SmartPlaylistFilterType.text => text(SmartPlaylistRuleFilterTextSource.values),
    SmartPlaylistFilterType.number => number(SmartPlaylistRuleFilterNumberSource.values),
    SmartPlaylistFilterType.dateTime => dateTime(SmartPlaylistRuleFilterDateTimeSource.values),
    SmartPlaylistFilterType.boolean => boolean(SmartPlaylistRuleFilterBooleanSource.values),
  };

  String toText() => switch (this) {
    SmartPlaylistFilterType.text => lang.text,
    SmartPlaylistFilterType.number => lang.number,
    SmartPlaylistFilterType.dateTime => lang.date,
    SmartPlaylistFilterType.boolean => lang.condition,
  };

  IconData toIcon() => switch (this) {
    SmartPlaylistFilterType.text => Broken.message_text_1,
    SmartPlaylistFilterType.number => Broken.math,
    SmartPlaylistFilterType.dateTime => Broken.calendar_1,
    SmartPlaylistFilterType.boolean => Broken.message_question,
  };
}

mixin SmartPlaylistRuleFilter {
  SmartPlaylistFilterType get type;
  bool get requiresDataField;
  bool get requiresData2Field;

  bool get isRelativeDate => false;

  String toText();
  IconData? toIcon();
  String? toIconText();
}

mixin SmartPlaylistRuleFilterSource {
  SmartPlaylistFilterType get type;
  SmartPlaylistRuleFilter get recommendedFilter;
  SmartPlaylistRuleFilterSource? get customAutoSource => null;
  bool get isAutoSource => false;
  bool get supportsCleanup;
  bool get supportsClockOnly;

  String toText();
  IconData? toIcon();
}

/// keeps only the first tracks by [sorts] that fit in [amount] of [unit].
///
/// by claude
class SmartPlaylistLimit {
  final int amount;
  final SmartPlaylistLimitUnit unit;
  final List<SortType> sorts;
  final bool sortReverse;

  const SmartPlaylistLimit({
    required this.amount,
    required this.unit,
    required this.sorts,
    required this.sortReverse,
  });

  const SmartPlaylistLimit.initial() : amount = 25, unit = SmartPlaylistLimitUnit.tracks, sorts = const [SortType.mostPlayed], sortReverse = false;

  Iterable<Track> _ordered(List<Track> tracks) {
    final comparables = sorts.map(SearchSortController.inst.getTracksSortingComparables).toFixedList();
    return tracks.lazySortedByAltsPrecomputed(comparables, reverse: sortReverse);
  }

  List<Track> select(List<Track> tracks) {
    if (unit == SmartPlaylistLimitUnit.tracks) return _ordered(tracks).take(amount).toList();

    final costOf = unit.buildCostGetter();
    int minCost = -1;
    for (final tr in tracks) {
      final cost = costOf(tr);
      if (minCost < 0 || cost < minCost) minCost = cost;
    }

    int remaining = unit.toBaseUnits(amount);
    final selected = <Track>[];
    // -- a track exceeding what's left is skipped instead of stopping, so smaller ones still fill it
    for (final tr in _ordered(tracks)) {
      if (remaining < minCost) break;
      final cost = costOf(tr);
      if (cost > remaining) continue;
      selected.add(tr);
      remaining -= cost;
    }
    return selected;
  }

  int selectCount(List<Track> tracks) {
    if (unit == SmartPlaylistLimitUnit.tracks) return tracks.length.withMaximum(amount);
    return select(tracks).length;
  }

  String toText() {
    final amountText = unit.toAmountText(amount);
    final sortText = sorts.firstOrNull?.toText();
    return sortText == null ? amountText : '$amountText • $sortText';
  }

  static SmartPlaylistLimit? fromMapNullable(dynamic map) {
    if (map is! Map) return null;
    try {
      return SmartPlaylistLimit(
        amount: map['amount'] as int,
        unit: SmartPlaylistLimitUnit.values.getEnum(map['unit']) ?? SmartPlaylistLimitUnit.tracks,
        sorts: SortType.sortListFromJsonList(map['sorts']) ?? const [],
        sortReverse: map['sortReverse'] == true,
      );
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'amount': amount,
      'unit': unit.name,
      'sorts': SortType.sortsToJson(sorts),
      if (sortReverse) 'sortReverse': sortReverse,
    };
  }

  SmartPlaylistLimit copyWith({
    int? amount,
    SmartPlaylistLimitUnit? unit,
    List<SortType>? sorts,
    bool? sortReverse,
  }) => SmartPlaylistLimit(
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
    sorts: sorts ?? this.sorts,
    sortReverse: sortReverse ?? this.sortReverse,
  );
}

enum SmartPlaylistLimitUnit {
  tracks,
  minutes,
  hours,
  megabytes,
  gigabytes,
  ;

  int toBaseUnits(int amount) => switch (this) {
    SmartPlaylistLimitUnit.tracks => amount,
    SmartPlaylistLimitUnit.minutes => amount * Duration.millisecondsPerMinute,
    SmartPlaylistLimitUnit.hours => amount * Duration.millisecondsPerHour,
    SmartPlaylistLimitUnit.megabytes => amount * 1024 * 1024,
    SmartPlaylistLimitUnit.gigabytes => amount * 1024 * 1024 * 1024,
  };

  int Function(Track tr) buildCostGetter() => switch (this) {
    SmartPlaylistLimitUnit.tracks => (tr) => 1,
    SmartPlaylistLimitUnit.minutes || SmartPlaylistLimitUnit.hours => (tr) => tr.durationMS,
    SmartPlaylistLimitUnit.megabytes || SmartPlaylistLimitUnit.gigabytes => (tr) => tr.size,
  };

  String toText() => switch (this) {
    SmartPlaylistLimitUnit.tracks => lang.tracks,
    SmartPlaylistLimitUnit.minutes => lang.minutes,
    SmartPlaylistLimitUnit.hours => lang.hours,
    SmartPlaylistLimitUnit.megabytes => 'MB',
    SmartPlaylistLimitUnit.gigabytes => 'GB',
  };

  String toAmountText(int amount) => switch (this) {
    SmartPlaylistLimitUnit.tracks => amount.displayTrackKeyword,
    SmartPlaylistLimitUnit.minutes || SmartPlaylistLimitUnit.hours || SmartPlaylistLimitUnit.megabytes || SmartPlaylistLimitUnit.gigabytes => '$amount ${toText()}',
  };
}

extension SmartPlaylistRuleGroupUtils on List<SmartPlaylistRuleGroup> {
  bool isValid() => isNotEmpty && any((g) => g.rules.isNotEmpty);
}
