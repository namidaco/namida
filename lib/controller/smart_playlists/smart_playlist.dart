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
  final SortType? sort;
  final bool sortReverse;
  final List<String> moods;
  final List<SmartPlaylistRuleGroup> ruleGroups;

  const SmartPlaylist({
    required this.name,
    required this.creationDate,
    required this.joiner,
    required this.sort,
    required this.sortReverse,
    required this.moods,
    required this.ruleGroups,
  });

  List<Track> resolve() {
    final allTracks = Indexer.inst.tracksInfoList.value;
    if (sort != null) {
      final list = resolveIterableUnSorted(allTracks).toList();
      final comparable = SearchSortController.inst.getTracksSortingComparables(sort!);
      if (sortReverse) {
        list.sortByReverse(comparable);
      } else {
        list.sortBy(comparable);
      }
      return list;
    } else if (sortReverse) {
      return resolveIterableUnSorted(allTracks.reversed).toList();
    }

    return resolveIterableUnSorted(allTracks).toList();
  }

  Iterable<Track> resolveIterableUnSorted(Iterable<Track> allTracks) sync* {
    final effectiveGroups = ruleGroups.where((group) => group.rules.isNotEmpty).toList();
    if (effectiveGroups.isEmpty) return;

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

    for (final track in allTracks) {
      final isMatch = switch (joiner) {
        SmartJoiner.and => effectiveGroups.every((group) => group.isMatch(track)),
        SmartJoiner.or => effectiveGroups.any((group) => group.isMatch(track)),
      };
      if (isMatch) yield track;
    }
  }

  factory SmartPlaylist.fromMap(Map<String, dynamic> map) {
    return SmartPlaylist(
      name: map['name'] as String,
      creationDate: DateTime.fromMillisecondsSinceEpoch(map['creationDate'] as int),
      joiner: SmartJoiner.values.getEnum(map['joiner']) ?? SmartJoiner.defaultForGroups,
      sort: SortType.values.getEnum(map['sort']),
      sortReverse: map['sortReverse'] as bool,
      moods: (map['moods'] as List).cast<String>(),
      ruleGroups: (map['ruleGroups'] as List).map(SmartPlaylistRuleGroup.fromMap).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'creationDate': creationDate.millisecondsSinceEpoch,
      'joiner': joiner.name,
      'sort': sort?.name,
      'sortReverse': sortReverse,
      'moods': moods,
      'ruleGroups': ruleGroups.map((e) => e.toMap()).toList(),
    };
  }

  SmartPlaylist copyWith({
    String? name,
    DateTime? creationDate,
    SmartJoiner? joiner,
    SortType? sort,
    bool? sortReverse,
    List<String>? moods,
    List<SmartPlaylistRuleGroup>? ruleGroups,
  }) => SmartPlaylist(
    name: name ?? this.name,
    creationDate: creationDate ?? this.creationDate,
    joiner: joiner ?? this.joiner,
    sort: sort ?? this.sort,
    sortReverse: sortReverse ?? this.sortReverse,
    moods: moods ?? this.moods,
    ruleGroups: ruleGroups ?? this.ruleGroups,
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

  bool isMatch(Track track) {
    final effectiveRules = rules.where((r) => r.source != SmartPlaylistRuleFilterDateTimeSource.rangeOnly);
    return switch (joiner) {
      SmartJoiner.and => effectiveRules.every((element) => element.isMatch(track)),
      SmartJoiner.or => effectiveRules.any((element) => element.isMatch(track)),
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
      'rules': rules.map((e) => e.toMap()).toList(),
    };
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
  T? textToData(String? value);
  T2? textToData2(String? value);
  String? dataToText(T? data);
  String? data2ToText(T2? data2);
  String? toHintText();
  String? validate();
  String? dataValidator(String? value);
  bool isMatch(Track track);

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
