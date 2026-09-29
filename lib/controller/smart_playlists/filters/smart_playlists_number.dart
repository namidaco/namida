part of '../smart_playlists_controller.dart';

final class SmartPlaylistRuleNumber extends SmartPlaylistRuleBase<int, int, SmartPlaylistRuleFilterNumber, SmartPlaylistRuleFilterNumberSource> {
  SmartPlaylistRuleNumber({
    required super.data,
    required super.data2,
    required super.filter,
    required super.source,
    required super.enableCleanup,
    this.scope = SmartPlaylistNumberScope.track,
    this.aggregate = SmartPlaylistNumberAggregate.sum,
  }) : super(type: SmartPlaylistFilterType.number, clockOnly: false, relativeDuration: null);

  final SmartPlaylistNumberScope scope;
  final SmartPlaylistNumberAggregate aggregate;

  bool Function(int? msse)? siblingDateFilter;

  static const _kMonthMS = 30 * Duration.millisecondsPerDay;

  @override
  SmartPlaylistRuleNumber copyWith({
    (int? data, int? data2)? datas,
    SmartPlaylistRuleFilterNumber? filter,
    bool? enableCleanup,
    bool? clockOnly,
    SmartPlaylistRelativeDuration? relativeDuration,
    SmartPlaylistNumberScope? scope,
    SmartPlaylistNumberAggregate? aggregate,
  }) => SmartPlaylistRuleNumber(
    data: datas != null ? datas.$1 : this.data,
    data2: datas != null ? datas.$2 : this.data2,
    filter: filter ?? this.filter,
    source: this.source,
    enableCleanup: enableCleanup ?? this.enableCleanup,
    scope: scope ?? this.scope,
    aggregate: aggregate ?? this.aggregate,
  );

  bool get isScoped => scope != SmartPlaylistNumberScope.track;

  @override
  String sourceDisplayText() {
    if (!isScoped) return source.toText();
    final perScopeText = lang.sourcePerScope(source: source.toText(), scope: scope.toText());
    return source.requiresScope ? perScopeText : '$perScopeText (${aggregate.toText()})';
  }

  @override
  String datasDisplayText() {
    return switch (filter) {
      SmartPlaylistRuleFilterNumber.isSame => '= ${data ?? '?'}',
      SmartPlaylistRuleFilterNumber.isNotSame => '≠ ${data ?? '?'}',
      SmartPlaylistRuleFilterNumber.isGreaterThan => '> ${data ?? '?'}',
      SmartPlaylistRuleFilterNumber.isSmallerThan => '< ${data ?? '?'}',
      SmartPlaylistRuleFilterNumber.isGreaterThanOrEq => '≥ ${data ?? '?'}',
      SmartPlaylistRuleFilterNumber.isSmallerThanOrEq => '≤ ${data ?? '?'}',
      SmartPlaylistRuleFilterNumber.isBetween => '${data ?? '?'} -> • <- ${data2 ?? '?'}',
      SmartPlaylistRuleFilterNumber.isOutside => '• <- ${data ?? '?'} - ${data2 ?? '?'} -> • ',
    };
  }

  @override
  int? textToData(String? value) {
    if (value == null || value.isEmpty) return null;

    return int.tryParse(value);
  }

  @override
  int? textToData2(String? value) => textToData(value);

  @override
  String? dataToText(int? data) => data?.toString();

  @override
  String? data2ToText(int? data2) => data2 == null ? null : dataToText(data2);

  @override
  String? toHintText() => switch (source) {
    SmartPlaylistRuleFilterNumberSource.totalListens => '0+',
    SmartPlaylistRuleFilterNumberSource.totalListensInRange => '0+',
    SmartPlaylistRuleFilterNumberSource.listenRate => '1, 2, 5...',
    SmartPlaylistRuleFilterNumberSource.rating => '0-100',
    SmartPlaylistRuleFilterNumberSource.lastPlayedPositionInMs => lang.seconds,
    SmartPlaylistRuleFilterNumberSource.playedPercentage => '0-100',
    SmartPlaylistRuleFilterNumberSource.durationMS => lang.seconds,
    SmartPlaylistRuleFilterNumberSource.sizeB => '1024, 512000... (bytes)',
    SmartPlaylistRuleFilterNumberSource.bitrate => '128, 256, 320...',
    SmartPlaylistRuleFilterNumberSource.sampleRate => '44100, 48000...',
    SmartPlaylistRuleFilterNumberSource.bits => '16, 24, 32...',
    SmartPlaylistRuleFilterNumberSource.bpm => '140, 180, 220...',
    SmartPlaylistRuleFilterNumberSource.trackNumber => '0+',
    SmartPlaylistRuleFilterNumberSource.trackTotal => '0+',
    SmartPlaylistRuleFilterNumberSource.discNumber => '0+',
    SmartPlaylistRuleFilterNumberSource.discTotal => '0+',
    SmartPlaylistRuleFilterNumberSource.playlistsCount => '0+',
    SmartPlaylistRuleFilterNumberSource.tracksCount => '1+',
  };

  @override
  String? dataValidator(String? value) {
    if (value == null || value.isEmpty) return lang.emptyValue;
    return null;
  }

  @override
  String? validate() {
    final data = this.data;
    final data2 = this.data2;
    if (filter.requiresDataField && (data == null || data < 0)) return '0+';
    if (!filter.requiresDataField && (data != null && data >= 0)) return lang.nameContainsBadCharacter;
    if (filter.requiresData2Field && (data2 == null || data2 < 0)) return '0+';
    if (!filter.requiresData2Field && (data2 != null && data2 >= 0)) return lang.nameContainsBadCharacter;
    return null;
  }

  late final (int?, int?) _sortedNumbers = data == null || data2 == null
      ? (data, data2)
      : data! <= data2!
      ? (data, data2)
      : (data2, data);

  late final _startNumber = _sortedNumbers.$1;
  late final _endNumber = _sortedNumbers.$2;

  late final bool Function(num? number) _numberFnRaw = switch (filter) {
    SmartPlaylistRuleFilterNumber.isSame => (number) => number == _startNumber,
    SmartPlaylistRuleFilterNumber.isNotSame => (number) => number != _startNumber,
    SmartPlaylistRuleFilterNumber.isGreaterThan => (number) => number != null && _startNumber != null && number > _startNumber,
    SmartPlaylistRuleFilterNumber.isSmallerThan => (number) => number != null && _startNumber != null && number < _startNumber,
    SmartPlaylistRuleFilterNumber.isGreaterThanOrEq => (number) => number != null && _startNumber != null && number >= _startNumber,
    SmartPlaylistRuleFilterNumber.isSmallerThanOrEq => (number) => number != null && _startNumber != null && number <= _startNumber,
    SmartPlaylistRuleFilterNumber.isBetween => (number) => number != null && _startNumber != null && _endNumber != null && (number >= _startNumber && number <= _endNumber),
    SmartPlaylistRuleFilterNumber.isOutside => (number) => number != null && _startNumber != null && _endNumber != null && (number < _startNumber || number > _endNumber),
  };
  bool _numberFn(num? numberNull) => _numberFnRaw(numberNull);

  @override
  bool _matches(Track track, _SmartPlaylistResolveContext context) {
    return switch (scope) {
      SmartPlaylistNumberScope.track => _numberFn(_trackValueOf(track, context)),
      SmartPlaylistNumberScope.album => _matchesScopeKeys(track.albumsIdentifiersModified, Indexer.inst.mainMapAlbums.value, context),
      SmartPlaylistNumberScope.artist => _matchesScopeKeys(track.artistsList, Indexer.inst.mainMapArtists.value, context),
      SmartPlaylistNumberScope.albumArtist => _matchesScopeKey(track.albumArtist, Indexer.inst.mainMapAlbumArtists.value, context),
      SmartPlaylistNumberScope.composer => _matchesScopeKeys(track.composersList, Indexer.inst.mainMapComposer.value, context),
      SmartPlaylistNumberScope.genre => _matchesScopeKeys(track.genresList, Indexer.inst.mainMapGenres.value, context),
      SmartPlaylistNumberScope.style => _matchesScopeKeys(track.stylesList, Indexer.inst.mainMapStyles.value, context),
      SmartPlaylistNumberScope.folder => _matchesScopeKey(track.folder, Indexer.inst.mainMapFoldersTracksAndVideos.value, context),
    };
  }

  num? _trackValueOf(Track track, _SmartPlaylistResolveContext context) => switch (source) {
    SmartPlaylistRuleFilterNumberSource.totalListens => SmartPlaylistRuleBase.topTracksMapListens[track]?.length ?? 0,
    SmartPlaylistRuleFilterNumberSource.totalListensInRange => _listensInRangeCount(track),
    SmartPlaylistRuleFilterNumberSource.listenRate => _listensPerMonth(track, context.nowMS),
    SmartPlaylistRuleFilterNumberSource.rating => track.effectiveRating,
    SmartPlaylistRuleFilterNumberSource.lastPlayedPositionInMs => (track.lastPlayedPositionInMs ?? 0) / 1000,
    SmartPlaylistRuleFilterNumberSource.playedPercentage => track.durationMS == 0 ? null : ((track.lastPlayedPositionInMs ?? 0) / track.durationMS) * 100,
    SmartPlaylistRuleFilterNumberSource.durationMS => track.durationMS / 1000,
    SmartPlaylistRuleFilterNumberSource.sizeB => track.size,
    SmartPlaylistRuleFilterNumberSource.bitrate => track.bitrate,
    SmartPlaylistRuleFilterNumberSource.sampleRate => track.sampleRate,
    SmartPlaylistRuleFilterNumberSource.bits => track.bits,
    SmartPlaylistRuleFilterNumberSource.bpm => track.bpm,
    SmartPlaylistRuleFilterNumberSource.trackNumber => track.trackNo,
    SmartPlaylistRuleFilterNumberSource.trackTotal => track.trackTo,
    SmartPlaylistRuleFilterNumberSource.discNumber => track.discNo,
    SmartPlaylistRuleFilterNumberSource.discTotal => track.discTo,
    SmartPlaylistRuleFilterNumberSource.playlistsCount => context.playlistsOf(track)?.length ?? 0,
    SmartPlaylistRuleFilterNumberSource.tracksCount => 1,
  };

  int _listensInRangeCount(Track track) {
    final listens = SmartPlaylistRuleBase.topTracksMapListens[track];
    if (listens == null) return 0;
    final siblingDateFilter = this.siblingDateFilter;
    if (siblingDateFilter == null) return listens.length;
    int count = 0;
    for (final msse in listens) {
      if (siblingDateFilter(msse)) count++;
    }
    return count;
  }

  /// tracks younger than a month are rated as a month old, otherwise a single listen on a new track would outrank everything.
  static double? _listensPerMonth(Track track, int nowMS) {
    final listens = SmartPlaylistRuleBase.topTracksMapListens[track];
    final firstListen = listens?.firstOrNull;
    final dateAdded = track.dateAdded;
    final startMS = firstListen != null && (dateAdded <= 0 || firstListen < dateAdded) ? firstListen : dateAdded;
    if (startMS <= 0) return null;
    final periodMS = (nowMS - startMS).withMinimum(_kMonthMS);
    final listensCount = listens?.length ?? 0;
    return listensCount * _kMonthMS / periodMS;
  }

  bool _matchesScopeKey<K>(K key, Map<K, List<Track>> scopeMap, _SmartPlaylistResolveContext context) {
    final scopeValues = context.scopeValuesOf(this);
    return _numberFn(_scopeValueOf(key, scopeMap, scopeValues, context));
  }

  /// negative filters match only when no key matches, same as text lists.
  bool _matchesScopeKeys<K>(List<K> keys, Map<K, List<Track>> scopeMap, _SmartPlaylistResolveContext context) {
    final scopeValues = context.scopeValuesOf(this);
    if (filter == SmartPlaylistRuleFilterNumber.isNotSame) {
      return !keys.any((key) => _scopeValueOf(key, scopeMap, scopeValues, context) == _startNumber);
    }
    return keys.any((key) => _numberFn(_scopeValueOf(key, scopeMap, scopeValues, context)));
  }

  num? _scopeValueOf<K>(K key, Map<K, List<Track>> scopeMap, Map<Object?, num?> scopeValues, _SmartPlaylistResolveContext context) {
    final cached = scopeValues[key];
    if (cached != null || scopeValues.containsKey(key)) return cached;
    final scopeTracks = scopeMap[key];
    final value = scopeTracks == null ? null : _aggregateOf(scopeTracks, context);
    scopeValues[key] = value;
    return value;
  }

  num? _aggregateOf(List<Track> tracks, _SmartPlaylistResolveContext context) {
    if (source.requiresScope) return tracks.length;
    final skipsZero = source.zeroMeansUnknown;
    num? result;
    int count = 0;
    for (final tr in tracks) {
      final value = _trackValueOf(tr, context);
      if (value == null || (skipsZero && value == 0)) continue;
      count++;
      if (result == null) {
        result = value;
        continue;
      }
      result = switch (aggregate) {
        SmartPlaylistNumberAggregate.sum || SmartPlaylistNumberAggregate.average => result + value,
        SmartPlaylistNumberAggregate.minimum => value < result ? value : result,
        SmartPlaylistNumberAggregate.maximum => value > result ? value : result,
      };
    }
    if (result == null) return null;
    return aggregate == SmartPlaylistNumberAggregate.average ? result / count : result;
  }

  factory SmartPlaylistRuleNumber.fromMap(Map map) {
    final dataJson = map['data'];
    final data2Json = map['data2'];
    final source = SmartPlaylistRuleFilterNumberSource.values.getEnum(map['source'])!;
    return SmartPlaylistRuleNumber(
      data: dataJson as int?,
      data2: data2Json as int?,
      filter: SmartPlaylistRuleFilterNumber.values.getEnum(map['filter'])!,
      source: source,
      enableCleanup: map['enableCleanup'] == true,
      scope: SmartPlaylistNumberScope.values.getEnum(map['scope']) ?? SmartPlaylistNumberScope.track,
      aggregate: SmartPlaylistNumberAggregate.values.getEnum(map['aggregate']) ?? source.defaultAggregate,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type.name,
      'filter': filter.name,
      'source': source.name,
      'data': data,
      'data2': ?data2,
      if (enableCleanup) 'enableCleanup': enableCleanup,
      if (isScoped) ...{
        'scope': scope.name,
        'aggregate': aggregate.name,
      },
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SmartPlaylistRuleNumber) return false;
    return other.filter == filter && //
        other.source == source &&
        other.data == data &&
        other.data2 == data2 &&
        other.enableCleanup == enableCleanup &&
        other.scope == scope &&
        other.aggregate == aggregate;
  }

  @override
  int get hashCode =>
      type.hashCode ^ //
      filter.hashCode ^
      source.hashCode ^
      data.hashCode ^
      data2.hashCode ^
      enableCleanup.hashCode ^
      scope.hashCode ^
      aggregate.hashCode;
}

enum SmartPlaylistRuleFilterNumber with SmartPlaylistRuleFilter {
  isSame,
  isNotSame,
  isGreaterThan,
  isSmallerThan,
  isGreaterThanOrEq,
  isSmallerThanOrEq,
  isBetween(requiresData2Field: true),
  isOutside(requiresData2Field: true),
  ;

  @override
  SmartPlaylistFilterType get type => SmartPlaylistFilterType.number;

  @override
  final bool requiresDataField;
  @override
  final bool requiresData2Field;

  // ignore: unused_element_parameter
  const SmartPlaylistRuleFilterNumber({this.requiresDataField = true, this.requiresData2Field = false});

  @override
  String toText() => switch (this) {
    SmartPlaylistRuleFilterNumber.isSame => lang.isSame,
    SmartPlaylistRuleFilterNumber.isNotSame => lang.isNotSame,
    SmartPlaylistRuleFilterNumber.isGreaterThan => lang.isGreaterThan,
    SmartPlaylistRuleFilterNumber.isSmallerThan => lang.isSmallerThan,
    SmartPlaylistRuleFilterNumber.isGreaterThanOrEq => "${lang.isGreaterThan} + ${lang.isSame}",
    SmartPlaylistRuleFilterNumber.isSmallerThanOrEq => "${lang.isSmallerThan} + ${lang.isSame}",
    SmartPlaylistRuleFilterNumber.isBetween => lang.isInBetween,
    SmartPlaylistRuleFilterNumber.isOutside => lang.isOutside,
  };

  @override
  IconData? toIcon() => null;

  @override
  String? toIconText() => switch (this) {
    SmartPlaylistRuleFilterNumber.isSame => '=',
    SmartPlaylistRuleFilterNumber.isNotSame => '≠',
    SmartPlaylistRuleFilterNumber.isGreaterThan => '>',
    SmartPlaylistRuleFilterNumber.isSmallerThan => '<',
    SmartPlaylistRuleFilterNumber.isGreaterThanOrEq => '≥',
    SmartPlaylistRuleFilterNumber.isSmallerThanOrEq => '≤',
    SmartPlaylistRuleFilterNumber.isBetween => '-><-',
    SmartPlaylistRuleFilterNumber.isOutside => '<-->',
  };
}

enum SmartPlaylistRuleFilterNumberSource with SmartPlaylistRuleFilterSource {
  totalListens,
  totalListensInRange,
  listenRate(defaultAggregate: SmartPlaylistNumberAggregate.average),
  rating(zeroMeansUnknown: true, defaultAggregate: SmartPlaylistNumberAggregate.average),
  lastPlayedPositionInMs(supportsScope: false),
  playedPercentage(supportsScope: false),

  durationMS(zeroMeansUnknown: true),
  sizeB(zeroMeansUnknown: true),
  bitrate(zeroMeansUnknown: true, defaultAggregate: SmartPlaylistNumberAggregate.average),
  sampleRate(zeroMeansUnknown: true, defaultAggregate: SmartPlaylistNumberAggregate.average),
  bits(zeroMeansUnknown: true, defaultAggregate: SmartPlaylistNumberAggregate.average),
  bpm(zeroMeansUnknown: true, defaultAggregate: SmartPlaylistNumberAggregate.average),

  trackNumber(supportsScope: false),
  trackTotal(supportsScope: false),
  discNumber(supportsScope: false),
  discTotal(supportsScope: false),

  playlistsCount,
  tracksCount,
  ;

  final bool zeroMeansUnknown;
  final bool supportsScope;
  final SmartPlaylistNumberAggregate defaultAggregate;

  const SmartPlaylistRuleFilterNumberSource({
    this.zeroMeansUnknown = false,
    this.supportsScope = true,
    this.defaultAggregate = SmartPlaylistNumberAggregate.sum,
  });

  bool get requiresScope => this == SmartPlaylistRuleFilterNumberSource.tracksCount;

  @override
  SmartPlaylistFilterType get type => SmartPlaylistFilterType.number;

  @override
  SmartPlaylistRuleFilter get recommendedFilter => SmartPlaylistRuleFilterNumber.isGreaterThan;

  @override
  SmartPlaylistRuleFilterSource? get customAutoSource => switch (this) {
    SmartPlaylistRuleFilterNumberSource.totalListensInRange => SmartPlaylistRuleFilterDateTimeSource.rangeOnly,
    _ => null,
  };

  @override
  bool get supportsCleanup => false;

  @override
  bool get supportsClockOnly => false;

  @override
  String toText() => switch (this) {
    SmartPlaylistRuleFilterNumberSource.totalListens => lang.totalListens,
    SmartPlaylistRuleFilterNumberSource.totalListensInRange => "${lang.totalListens} (${lang.betweenDates})",
    SmartPlaylistRuleFilterNumberSource.listenRate => lang.listensPerMonth,
    SmartPlaylistRuleFilterNumberSource.rating => lang.rating,
    SmartPlaylistRuleFilterNumberSource.lastPlayedPositionInMs => lang.lastPlayedPosition,
    SmartPlaylistRuleFilterNumberSource.playedPercentage => lang.playedPercentage,
    SmartPlaylistRuleFilterNumberSource.durationMS => lang.duration,
    SmartPlaylistRuleFilterNumberSource.sizeB => lang.size,
    SmartPlaylistRuleFilterNumberSource.bitrate => lang.bitrate,
    SmartPlaylistRuleFilterNumberSource.sampleRate => lang.sampleRate,
    SmartPlaylistRuleFilterNumberSource.bits => lang.bitDepth,
    SmartPlaylistRuleFilterNumberSource.bpm => 'BPM',
    SmartPlaylistRuleFilterNumberSource.trackNumber => lang.trackNumber,
    SmartPlaylistRuleFilterNumberSource.trackTotal => lang.trackNumberTotal,
    SmartPlaylistRuleFilterNumberSource.discNumber => lang.discNumber,
    SmartPlaylistRuleFilterNumberSource.discTotal => lang.discNumberTotal,
    SmartPlaylistRuleFilterNumberSource.playlistsCount => lang.playlistsCount,
    SmartPlaylistRuleFilterNumberSource.tracksCount => lang.totalTracks,
  };

  @override
  IconData? toIcon() => switch (this) {
    SmartPlaylistRuleFilterNumberSource.totalListens => Broken.award,
    SmartPlaylistRuleFilterNumberSource.totalListensInRange => Broken.award,
    SmartPlaylistRuleFilterNumberSource.listenRate => Broken.trend_up,
    SmartPlaylistRuleFilterNumberSource.rating => Broken.grammerly,
    SmartPlaylistRuleFilterNumberSource.lastPlayedPositionInMs => Broken.clock_1,
    SmartPlaylistRuleFilterNumberSource.playedPercentage => Broken.clock,
    SmartPlaylistRuleFilterNumberSource.durationMS => Broken.timer_1,
    SmartPlaylistRuleFilterNumberSource.sizeB => Broken.size,
    SmartPlaylistRuleFilterNumberSource.bitrate => Broken.voice_cricle,
    SmartPlaylistRuleFilterNumberSource.sampleRate => Broken.voice_cricle,
    SmartPlaylistRuleFilterNumberSource.bits => Broken.voice_cricle,
    SmartPlaylistRuleFilterNumberSource.bpm => Broken.alarm,
    SmartPlaylistRuleFilterNumberSource.trackNumber => Broken.hashtag,
    SmartPlaylistRuleFilterNumberSource.trackTotal => Broken.hashtag,
    SmartPlaylistRuleFilterNumberSource.discNumber => Broken.hashtag,
    SmartPlaylistRuleFilterNumberSource.discTotal => Broken.hashtag,
    SmartPlaylistRuleFilterNumberSource.playlistsCount => Broken.music_library_2,
    SmartPlaylistRuleFilterNumberSource.tracksCount => Broken.music_square,
  };

  NumberSliderConfig buildSliderConfig() => switch (this) {
    SmartPlaylistRuleFilterNumberSource.totalListens => NumberSliderConfig(min: 0, max: 9999, stepper: 1, formatter: (v) => '$v'),
    SmartPlaylistRuleFilterNumberSource.totalListensInRange => NumberSliderConfig(min: 0, max: 9999, stepper: 1, formatter: (v) => '$v'),
    SmartPlaylistRuleFilterNumberSource.listenRate => NumberSliderConfig(min: 0, max: 999, stepper: 1, formatter: (v) => '$v'),
    SmartPlaylistRuleFilterNumberSource.rating => NumberSliderConfig(min: 0, max: 100, stepper: 1, formatter: (v) => '$v%'),
    SmartPlaylistRuleFilterNumberSource.lastPlayedPositionInMs => NumberSliderConfig(min: 0, max: 3600, stepper: 1, formatter: (v) => v.secondsLabel),
    SmartPlaylistRuleFilterNumberSource.playedPercentage => NumberSliderConfig(min: 0, max: 100, stepper: 1, formatter: (v) => '$v%'),
    SmartPlaylistRuleFilterNumberSource.durationMS => NumberSliderConfig(min: 0, max: 3600, stepper: 1, formatter: (v) => v.secondsLabel),
    SmartPlaylistRuleFilterNumberSource.sizeB => NumberSliderConfig(min: 0, max: 10240, stepper: 1, formatter: (v) => (v * 1024 * 1024).fileSizeFormatted),
    SmartPlaylistRuleFilterNumberSource.bitrate => NumberSliderConfig(min: 0, max: 1411, stepper: 1, formatter: (v) => '$v kb/s'),
    SmartPlaylistRuleFilterNumberSource.sampleRate => NumberSliderConfig(min: 8000, max: 192000, stepper: 100, formatter: (v) => '${v}Hz'),
    SmartPlaylistRuleFilterNumberSource.bits => NumberSliderConfig(min: 8, max: 64, stepper: 8, formatter: (v) => '$v-bit'),
    SmartPlaylistRuleFilterNumberSource.bpm => NumberSliderConfig(min: 0, max: 999, stepper: 1, formatter: (v) => '$v-bpm'),
    SmartPlaylistRuleFilterNumberSource.trackNumber => NumberSliderConfig(min: 0, max: 999, stepper: 1, formatter: (v) => '$v'),
    SmartPlaylistRuleFilterNumberSource.trackTotal => NumberSliderConfig(min: 0, max: 999, stepper: 1, formatter: (v) => '$v'),
    SmartPlaylistRuleFilterNumberSource.discNumber => NumberSliderConfig(min: 0, max: 99, stepper: 1, formatter: (v) => '$v'),
    SmartPlaylistRuleFilterNumberSource.discTotal => NumberSliderConfig(min: 0, max: 99, stepper: 1, formatter: (v) => '$v'),
    SmartPlaylistRuleFilterNumberSource.playlistsCount => NumberSliderConfig(min: 0, max: 999, stepper: 1, formatter: (v) => '$v'),
    SmartPlaylistRuleFilterNumberSource.tracksCount => NumberSliderConfig(min: 0, max: 9999, stepper: 1, formatter: (v) => '$v'),
  };
}

enum SmartPlaylistNumberScope {
  track,
  album,
  artist,
  albumArtist,
  composer,
  genre,
  style,
  folder,
  ;

  String toText() => switch (this) {
    SmartPlaylistNumberScope.track => lang.track,
    SmartPlaylistNumberScope.album => lang.album,
    SmartPlaylistNumberScope.artist => lang.artist,
    SmartPlaylistNumberScope.albumArtist => lang.albumArtist,
    SmartPlaylistNumberScope.composer => lang.composer,
    SmartPlaylistNumberScope.genre => lang.genre,
    SmartPlaylistNumberScope.style => lang.style,
    SmartPlaylistNumberScope.folder => lang.folder,
  };

  IconData toIcon() => switch (this) {
    SmartPlaylistNumberScope.track => Broken.music,
    SmartPlaylistNumberScope.album => Broken.music_dashboard,
    SmartPlaylistNumberScope.artist => Broken.microphone,
    SmartPlaylistNumberScope.albumArtist => Broken.user,
    SmartPlaylistNumberScope.composer => Broken.profile_2user,
    SmartPlaylistNumberScope.genre => Broken.smileys,
    SmartPlaylistNumberScope.style => Broken.brush_1,
    SmartPlaylistNumberScope.folder => Broken.folder,
  };
}

enum SmartPlaylistNumberAggregate {
  sum,
  average,
  minimum,
  maximum,
  ;

  String toText() => switch (this) {
    SmartPlaylistNumberAggregate.sum => lang.sum,
    SmartPlaylistNumberAggregate.average => lang.average,
    SmartPlaylistNumberAggregate.minimum => lang.minimum,
    SmartPlaylistNumberAggregate.maximum => lang.maximum,
  };

  String toIconText() => switch (this) {
    SmartPlaylistNumberAggregate.sum => 'Σ',
    SmartPlaylistNumberAggregate.average => 'avg',
    SmartPlaylistNumberAggregate.minimum => 'min',
    SmartPlaylistNumberAggregate.maximum => 'max',
  };
}

class NumberSliderConfig {
  final int min;
  final int max;
  final int stepper;
  final String Function(int value) formatter;

  const NumberSliderConfig({
    required this.min,
    required this.max,
    required this.stepper,
    required this.formatter,
  });
}
