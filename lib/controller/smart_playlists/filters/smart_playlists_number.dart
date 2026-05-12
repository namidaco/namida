part of '../smart_playlists_controller.dart';

final class SmartPlaylistRuleNumber extends SmartPlaylistRuleBase<int, int, SmartPlaylistRuleFilterNumber, SmartPlaylistRuleFilterNumberSource> {
  SmartPlaylistRuleNumber({
    required super.data,
    required super.data2,
    required super.filter,
    required super.source,
    required super.enableCleanup,
  }) : super(type: SmartPlaylistFilterType.number, clockOnly: false, relativeDuration: null);

  bool Function(int? msse)? siblingDateFilter;

  @override
  SmartPlaylistRuleNumber copyWith({
    (int? data, int? data2)? datas,
    SmartPlaylistRuleFilterNumber? filter,
    bool? enableCleanup,
    bool? clockOnly,
    SmartPlaylistRelativeDuration? relativeDuration,
  }) => SmartPlaylistRuleNumber(
    data: datas != null ? datas.$1 : this.data,
    data2: datas != null ? datas.$2 : this.data2,
    filter: filter ?? this.filter,
    source: this.source,
    enableCleanup: enableCleanup ?? this.enableCleanup,
  );

  @override
  String datasDisplayText() {
    return switch (filter) {
      SmartPlaylistRuleFilterNumber.isSame => '= ${data ?? '?'}',
      SmartPlaylistRuleFilterNumber.isNotSame => '≠ ${data ?? '?'}',
      SmartPlaylistRuleFilterNumber.isGreaterThan => '> ${data ?? '?'}',
      SmartPlaylistRuleFilterNumber.isSmallerThan => '< ${data ?? '?'}',
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
    SmartPlaylistRuleFilterNumberSource.rating => '0-100',
    SmartPlaylistRuleFilterNumberSource.lastPlayedPositionInMs => lang.seconds,
    SmartPlaylistRuleFilterNumberSource.playedPercentage => '0-100',
    SmartPlaylistRuleFilterNumberSource.durationMS => lang.seconds,
    SmartPlaylistRuleFilterNumberSource.sizeB => '1024, 512000... (bytes)',
    SmartPlaylistRuleFilterNumberSource.bitrate => '128000, 256000...',
    SmartPlaylistRuleFilterNumberSource.sampleRate => '44100, 48000...',
    SmartPlaylistRuleFilterNumberSource.bits => '16, 24, 32...',
    SmartPlaylistRuleFilterNumberSource.trackNumber => '0+',
    SmartPlaylistRuleFilterNumberSource.trackTotal => '0+',
    SmartPlaylistRuleFilterNumberSource.discNumber => '0+',
    SmartPlaylistRuleFilterNumberSource.discTotal => '0+',
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
    SmartPlaylistRuleFilterNumber.isBetween => (number) => number != null && _startNumber != null && _endNumber != null && (number >= _startNumber && number <= _endNumber),
    SmartPlaylistRuleFilterNumber.isOutside => (number) => number != null && _startNumber != null && _endNumber != null && (number < _startNumber || number > _endNumber),
  };
  bool _numberFn(num? numberNull) => _numberFnRaw(numberNull);

  @override
  bool isMatch(Track track) {
    return switch (source) {
      SmartPlaylistRuleFilterNumberSource.totalListens => _numberFn(SmartPlaylistRuleBase.topTracksMapListens[track]?.length),
      SmartPlaylistRuleFilterNumberSource.totalListensInRange => _numberFn(
        SmartPlaylistRuleBase.topTracksMapListens[track]?.where((msse) => siblingDateFilter?.call(msse) ?? true).length,
      ),
      SmartPlaylistRuleFilterNumberSource.rating => _numberFn(track.effectiveRating),
      SmartPlaylistRuleFilterNumberSource.lastPlayedPositionInMs => _numberFn((track.lastPlayedPositionInMs ?? 0) / 1000),
      SmartPlaylistRuleFilterNumberSource.playedPercentage => _numberFn(track.durationMS == 0 ? null : ((track.lastPlayedPositionInMs ?? 0) / track.durationMS) * 100),
      SmartPlaylistRuleFilterNumberSource.durationMS => _numberFn(track.durationMS / 1000),
      SmartPlaylistRuleFilterNumberSource.sizeB => _numberFn(track.size),
      SmartPlaylistRuleFilterNumberSource.bitrate => _numberFn(track.bitrate),
      SmartPlaylistRuleFilterNumberSource.sampleRate => _numberFn(track.sampleRate),
      SmartPlaylistRuleFilterNumberSource.bits => _numberFn(track.bits),
      SmartPlaylistRuleFilterNumberSource.trackNumber => _numberFn(track.trackNo),
      SmartPlaylistRuleFilterNumberSource.trackTotal => _numberFn(track.trackTo),
      SmartPlaylistRuleFilterNumberSource.discNumber => _numberFn(track.discNo),
      SmartPlaylistRuleFilterNumberSource.discTotal => _numberFn(track.discTo),
    };
  }

  factory SmartPlaylistRuleNumber.fromMap(Map map) {
    final dataJson = map['data'];
    final data2Json = map['data2'];
    return SmartPlaylistRuleNumber(
      data: dataJson as int?,
      data2: data2Json as int?,
      filter: SmartPlaylistRuleFilterNumber.values.getEnum(map['filter'])!,
      source: SmartPlaylistRuleFilterNumberSource.values.getEnum(map['source'])!,
      enableCleanup: map['enableCleanup'] == true,
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
    };
  }
}

enum SmartPlaylistRuleFilterNumber with SmartPlaylistRuleFilter {
  isSame,
  isNotSame,
  isGreaterThan,
  isSmallerThan,
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
    SmartPlaylistRuleFilterNumber.isBetween => '-><-',
    SmartPlaylistRuleFilterNumber.isOutside => '<-->',
  };
}

enum SmartPlaylistRuleFilterNumberSource with SmartPlaylistRuleFilterSource {
  totalListens,
  totalListensInRange,
  rating,
  lastPlayedPositionInMs,
  playedPercentage,

  durationMS,
  sizeB,
  bitrate,
  sampleRate,
  bits,

  trackNumber,
  trackTotal,
  discNumber,
  discTotal,
  ;

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
    SmartPlaylistRuleFilterNumberSource.rating => lang.rating,
    SmartPlaylistRuleFilterNumberSource.lastPlayedPositionInMs => lang.lastPlayedPosition,
    SmartPlaylistRuleFilterNumberSource.playedPercentage => lang.playedPercentage,
    SmartPlaylistRuleFilterNumberSource.durationMS => lang.duration,
    SmartPlaylistRuleFilterNumberSource.sizeB => lang.size,
    SmartPlaylistRuleFilterNumberSource.bitrate => lang.bitrate,
    SmartPlaylistRuleFilterNumberSource.sampleRate => lang.sampleRate,
    SmartPlaylistRuleFilterNumberSource.bits => lang.bits,
    SmartPlaylistRuleFilterNumberSource.trackNumber => lang.trackNumber,
    SmartPlaylistRuleFilterNumberSource.trackTotal => lang.trackNumberTotal,
    SmartPlaylistRuleFilterNumberSource.discNumber => lang.discNumber,
    SmartPlaylistRuleFilterNumberSource.discTotal => lang.discNumberTotal,
  };

  @override
  IconData? toIcon() => switch (this) {
    SmartPlaylistRuleFilterNumberSource.totalListens => Broken.award,
    SmartPlaylistRuleFilterNumberSource.totalListensInRange => Broken.award,
    SmartPlaylistRuleFilterNumberSource.rating => Broken.grammerly,
    SmartPlaylistRuleFilterNumberSource.lastPlayedPositionInMs => Broken.clock_1,
    SmartPlaylistRuleFilterNumberSource.playedPercentage => Broken.clock,
    SmartPlaylistRuleFilterNumberSource.durationMS => Broken.timer_1,
    SmartPlaylistRuleFilterNumberSource.sizeB => Broken.size,
    SmartPlaylistRuleFilterNumberSource.bitrate => Broken.voice_cricle,
    SmartPlaylistRuleFilterNumberSource.sampleRate => Broken.voice_cricle,
    SmartPlaylistRuleFilterNumberSource.bits => Broken.voice_cricle,
    SmartPlaylistRuleFilterNumberSource.trackNumber => Broken.hashtag,
    SmartPlaylistRuleFilterNumberSource.trackTotal => Broken.hashtag,
    SmartPlaylistRuleFilterNumberSource.discNumber => Broken.hashtag,
    SmartPlaylistRuleFilterNumberSource.discTotal => Broken.hashtag,
  };

  NumberSliderConfig buildSliderConfig() => switch (this) {
    SmartPlaylistRuleFilterNumberSource.totalListens => NumberSliderConfig(min: 0, max: 9999, stepper: 1, formatter: (v) => '$v'),
    SmartPlaylistRuleFilterNumberSource.totalListensInRange => NumberSliderConfig(min: 0, max: 9999, stepper: 1, formatter: (v) => '$v'),
    SmartPlaylistRuleFilterNumberSource.rating => NumberSliderConfig(min: 0, max: 100, stepper: 1, formatter: (v) => '$v%'),
    SmartPlaylistRuleFilterNumberSource.lastPlayedPositionInMs => NumberSliderConfig(min: 0, max: 3600, stepper: 1, formatter: (v) => v.secondsLabel),
    SmartPlaylistRuleFilterNumberSource.playedPercentage => NumberSliderConfig(min: 0, max: 100, stepper: 1, formatter: (v) => '$v%'),
    SmartPlaylistRuleFilterNumberSource.durationMS => NumberSliderConfig(min: 0, max: 3600, stepper: 1, formatter: (v) => v.secondsLabel),
    SmartPlaylistRuleFilterNumberSource.sizeB => NumberSliderConfig(min: 0, max: 10240, stepper: 1, formatter: (v) => (v * 1024 * 1024).fileSizeFormatted),
    SmartPlaylistRuleFilterNumberSource.bitrate => NumberSliderConfig(min: 0, max: 1411, stepper: 1, formatter: (v) => '$v kb/s'),
    SmartPlaylistRuleFilterNumberSource.sampleRate => NumberSliderConfig(min: 8000, max: 192000, stepper: 100, formatter: (v) => '${v}Hz'),
    SmartPlaylistRuleFilterNumberSource.bits => NumberSliderConfig(min: 8, max: 64, stepper: 8, formatter: (v) => '$v-bit'),
    SmartPlaylistRuleFilterNumberSource.trackNumber => NumberSliderConfig(min: 0, max: 999, stepper: 1, formatter: (v) => '$v'),
    SmartPlaylistRuleFilterNumberSource.trackTotal => NumberSliderConfig(min: 0, max: 999, stepper: 1, formatter: (v) => '$v'),
    SmartPlaylistRuleFilterNumberSource.discNumber => NumberSliderConfig(min: 0, max: 99, stepper: 1, formatter: (v) => '$v'),
    SmartPlaylistRuleFilterNumberSource.discTotal => NumberSliderConfig(min: 0, max: 99, stepper: 1, formatter: (v) => '$v'),
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
