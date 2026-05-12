part of '../smart_playlists_controller.dart';

final class SmartPlaylistRuleText extends SmartPlaylistRuleBase<String, String, SmartPlaylistRuleFilterText, SmartPlaylistRuleFilterTextSource> {
  SmartPlaylistRuleText({
    required super.data,
    required super.filter,
    required super.source,
    required super.enableCleanup,
  }) : super(type: SmartPlaylistFilterType.text, data2: null, clockOnly: false, relativeDuration: null);

  @override
  SmartPlaylistRuleText copyWith({
    (String? data, String? data2)? datas,
    SmartPlaylistRuleFilterText? filter,
    bool? enableCleanup,
    bool? clockOnly,
    SmartPlaylistRelativeDuration? relativeDuration,
  }) => SmartPlaylistRuleText(
    data: datas != null ? datas.$1 : this.data,
    filter: filter ?? this.filter,
    source: this.source,
    enableCleanup: enableCleanup ?? this.enableCleanup,
  );

  @override
  String datasDisplayText() => data ?? '';

  @override
  String? textToData(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }

  @override
  String? textToData2(String? value) => textToData(value);

  @override
  String? dataToText(String? data) => data;

  @override
  String? data2ToText(String? data2) => data2 == null ? null : dataToText(data2);

  @override
  String? toHintText() => null;

  @override
  String? dataValidator(String? value) {
    if (value == null || value.isEmpty) return lang.emptyValue;
    return switch (filter) {
      SmartPlaylistRuleFilterText.regexMatch || SmartPlaylistRuleFilterText.regexNotMatch => _validateRegexValidOrError(value),
      _ => null,
    };
  }

  String? _validateRegexValidOrError(String value) {
    try {
      RegExp(value);
    } on FormatException catch (e) {
      return 'Invalid regex:\n${e.message}';
    } catch (e) {
      return 'Invalid regex:\n$e';
    }
    return null;
  }

  @override
  String? validate() {
    final data = this.data;
    final data2 = this.data2;
    if (filter.requiresDataField && (data == null || data.isEmpty)) return lang.emptyValue;
    if (!filter.requiresDataField && (data != null && data.isNotEmpty)) return lang.nameContainsBadCharacter;
    if (filter.requiresData2Field && (data2 == null || data2.isEmpty)) return lang.emptyValue;
    if (!filter.requiresData2Field && (data2 != null && data2.isNotEmpty)) return lang.nameContainsBadCharacter;
    return null;
  }

  late final _dataOrCleaned = enableCleanup ? data?.cleanUpForComparison : data;
  late final _dataAsRegex = data == null ? null : RegExp(data!, caseSensitive: !enableCleanup, multiLine: true);

  late final bool Function(String trackText) _textFnRaw = switch (filter) {
    SmartPlaylistRuleFilterText.isSame => (trackText) => trackText == _dataOrCleaned,
    SmartPlaylistRuleFilterText.isNotSame => (trackText) => trackText != _dataOrCleaned,
    SmartPlaylistRuleFilterText.contains => (trackText) => _dataOrCleaned != null && trackText.contains(_dataOrCleaned),
    SmartPlaylistRuleFilterText.notContains => (trackText) => _dataOrCleaned != null && !trackText.contains(_dataOrCleaned),
    SmartPlaylistRuleFilterText.startsWith => (trackText) => _dataOrCleaned != null && trackText.startsWith(_dataOrCleaned),
    SmartPlaylistRuleFilterText.endsWith => (trackText) => _dataOrCleaned != null && trackText.endsWith(_dataOrCleaned),
    SmartPlaylistRuleFilterText.regexMatch => (trackText) => _dataAsRegex != null && _dataAsRegex.hasMatch(trackText),
    SmartPlaylistRuleFilterText.regexNotMatch => (trackText) => _dataAsRegex != null && !_dataAsRegex.hasMatch(trackText),
    SmartPlaylistRuleFilterText.exists => (trackText) => trackText.isNotEmpty,
    SmartPlaylistRuleFilterText.missing => (trackText) => trackText.isEmpty,
  };

  late final bool Function(Iterable<String> trackTextList) _textListFnRaw = switch (filter) {
    SmartPlaylistRuleFilterText.isSame => (trackTextList) => trackTextList.every((e) => e == _dataOrCleaned),
    SmartPlaylistRuleFilterText.isNotSame => (trackTextList) => trackTextList.every((e) => e != _dataOrCleaned),
    SmartPlaylistRuleFilterText.contains => (trackTextList) => _dataOrCleaned != null && trackTextList.any((e) => e.contains(_dataOrCleaned)),
    SmartPlaylistRuleFilterText.notContains => (trackTextList) => _dataOrCleaned != null && !trackTextList.any((e) => e.contains(_dataOrCleaned)),
    SmartPlaylistRuleFilterText.startsWith => (trackTextList) => _dataOrCleaned != null && trackTextList.any((e) => e.startsWith(_dataOrCleaned)),
    SmartPlaylistRuleFilterText.endsWith => (trackTextList) => _dataOrCleaned != null && trackTextList.any((e) => e.endsWith(_dataOrCleaned)),
    SmartPlaylistRuleFilterText.regexMatch => (trackTextList) => _dataAsRegex != null && trackTextList.any((e) => _dataAsRegex.hasMatch(e)),
    SmartPlaylistRuleFilterText.regexNotMatch => (trackTextList) => _dataAsRegex != null && !trackTextList.any((e) => _dataAsRegex.hasMatch(e)),
    SmartPlaylistRuleFilterText.exists => (trackTextList) => trackTextList.isNotEmpty,
    SmartPlaylistRuleFilterText.missing => (trackTextList) => trackTextList.isEmpty,
  };

  bool _textFn(String trackText) => enableCleanup ? _textFnRaw(trackText.cleanUpForComparison) : _textFnRaw(trackText);
  bool _textListFn(List<String> trackTextList) => enableCleanup ? _textListFnRaw(trackTextList.map((e) => e.cleanUpForComparison)) : _textListFnRaw(trackTextList);

  @override
  bool isMatch(Track track) {
    return switch (source) {
      SmartPlaylistRuleFilterTextSource.title => _textFn(track.title),
      SmartPlaylistRuleFilterTextSource.album => _textListFn(track.albumsList),
      SmartPlaylistRuleFilterTextSource.artist => _textListFn(track.artistsList),
      SmartPlaylistRuleFilterTextSource.albumArtist => _textFn(track.albumArtist),
      SmartPlaylistRuleFilterTextSource.composer => _textFn(track.composer),
      SmartPlaylistRuleFilterTextSource.genre => _textListFn(track.genresList),
      SmartPlaylistRuleFilterTextSource.comment => _textFn(track.comment),
      SmartPlaylistRuleFilterTextSource.description => _textFn(track.description),
      SmartPlaylistRuleFilterTextSource.synopsis => _textFn(track.synopsis),
      SmartPlaylistRuleFilterTextSource.language => _textFn(track.language),
      SmartPlaylistRuleFilterTextSource.label => _textFn(track.label),
      SmartPlaylistRuleFilterTextSource.format => _textFn(track.format),
      SmartPlaylistRuleFilterTextSource.channels => _textFn(track.channels),
      SmartPlaylistRuleFilterTextSource.lyrics => _textFn(track.lyrics),
      SmartPlaylistRuleFilterTextSource.moods => _textListFn(track.effectiveMoods),
      SmartPlaylistRuleFilterTextSource.tags => _textListFn(track.effectiveTags),
      SmartPlaylistRuleFilterTextSource.youtubeLink => _textFn(track.youtubeLink),
      SmartPlaylistRuleFilterTextSource.youtubeID => _textFn(track.youtubeID),
      SmartPlaylistRuleFilterTextSource.filename => _textFn(track.filename),
      SmartPlaylistRuleFilterTextSource.filenameWOExt => _textFn(track.filenameWOExt),
      SmartPlaylistRuleFilterTextSource.path => _textFn(track.path),
      SmartPlaylistRuleFilterTextSource.folderName => _textFn(track.folderName),
      SmartPlaylistRuleFilterTextSource.folderPath => _textFn(track.folderPath),
      SmartPlaylistRuleFilterTextSource.extension => _textFn(track.extension),
    };
  }

  factory SmartPlaylistRuleText.fromMap(Map map) {
    final dataJson = map['data'] as String? ?? '';
    return SmartPlaylistRuleText(
      data: dataJson,
      filter: SmartPlaylistRuleFilterText.values.getEnum(map['filter'])!,
      source: SmartPlaylistRuleFilterTextSource.values.getEnum(map['source'])!,
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
      if (enableCleanup) 'enableCleanup': enableCleanup,
    };
  }
}

enum SmartPlaylistRuleFilterText with SmartPlaylistRuleFilter {
  isSame,
  isNotSame,
  contains,
  notContains,
  startsWith,
  endsWith,
  regexMatch,
  regexNotMatch,
  exists(requiresDataField: false),
  missing(requiresDataField: false),
  ;

  @override
  SmartPlaylistFilterType get type => SmartPlaylistFilterType.text;

  @override
  final bool requiresDataField;
  @override
  final bool requiresData2Field;

  // ignore: unused_element_parameter
  const SmartPlaylistRuleFilterText({this.requiresDataField = true, this.requiresData2Field = false});

  @override
  String toText() => switch (this) {
    SmartPlaylistRuleFilterText.isSame => lang.isSame,
    SmartPlaylistRuleFilterText.isNotSame => lang.isNotSame,
    SmartPlaylistRuleFilterText.contains => lang.contains,
    SmartPlaylistRuleFilterText.notContains => lang.doesNotContain,
    SmartPlaylistRuleFilterText.startsWith => lang.startsWith,
    SmartPlaylistRuleFilterText.endsWith => lang.endsWith,
    SmartPlaylistRuleFilterText.regexMatch => "${lang.contains} (Regex)",
    SmartPlaylistRuleFilterText.regexNotMatch => "${lang.doesNotContain} (Regex)",
    SmartPlaylistRuleFilterText.exists => lang.exists,
    SmartPlaylistRuleFilterText.missing => lang.missing,
  };

  @override
  IconData? toIcon() => switch (this) {
    SmartPlaylistRuleFilterText.isSame => null,
    SmartPlaylistRuleFilterText.isNotSame => null,
    SmartPlaylistRuleFilterText.contains => Broken.search_normal_1,
    SmartPlaylistRuleFilterText.notContains => Broken.minus_cirlce,
    SmartPlaylistRuleFilterText.startsWith => null,
    SmartPlaylistRuleFilterText.endsWith => null,
    SmartPlaylistRuleFilterText.regexMatch => null,
    SmartPlaylistRuleFilterText.regexNotMatch => null,
    SmartPlaylistRuleFilterText.exists => Broken.tick_circle,
    SmartPlaylistRuleFilterText.missing => Broken.close_circle,
  };

  @override
  String? toIconText() => switch (this) {
    SmartPlaylistRuleFilterText.isSame => '=',
    SmartPlaylistRuleFilterText.isNotSame => '≠',
    SmartPlaylistRuleFilterText.contains => null,
    SmartPlaylistRuleFilterText.notContains => null,
    SmartPlaylistRuleFilterText.startsWith => '#...',
    SmartPlaylistRuleFilterText.endsWith => '...#',
    SmartPlaylistRuleFilterText.regexMatch => '.*',
    SmartPlaylistRuleFilterText.regexNotMatch => '^.*',
    SmartPlaylistRuleFilterText.exists => null,
    SmartPlaylistRuleFilterText.missing => null,
  };
}

enum SmartPlaylistRuleFilterTextSource with SmartPlaylistRuleFilterSource {
  title,
  album,
  artist,
  albumArtist,
  composer,
  genre,
  comment,
  description(canAffectPerformance: true),
  synopsis(canAffectPerformance: true),
  language,
  label,
  format,
  channels,
  lyrics(canAffectPerformance: true),
  moods,
  tags,
  youtubeLink,
  youtubeID,
  filename,
  filenameWOExt,
  path,
  folderName,
  folderPath,
  extension,
  ;

  final bool canAffectPerformance;
  const SmartPlaylistRuleFilterTextSource({this.canAffectPerformance = false});

  @override
  SmartPlaylistFilterType get type => SmartPlaylistFilterType.text;

  @override
  SmartPlaylistRuleFilter get recommendedFilter => SmartPlaylistRuleFilterText.contains;

  @override
  bool get supportsCleanup => true;

  @override
  bool get supportsClockOnly => false;

  @override
  String toText() => switch (this) {
    SmartPlaylistRuleFilterTextSource.title => lang.title,
    SmartPlaylistRuleFilterTextSource.album => lang.album,
    SmartPlaylistRuleFilterTextSource.artist => lang.artist,
    SmartPlaylistRuleFilterTextSource.albumArtist => lang.albumArtist,
    SmartPlaylistRuleFilterTextSource.composer => lang.composer,
    SmartPlaylistRuleFilterTextSource.genre => lang.genre,
    SmartPlaylistRuleFilterTextSource.comment => lang.comment,
    SmartPlaylistRuleFilterTextSource.description => lang.description,
    SmartPlaylistRuleFilterTextSource.synopsis => lang.synopsis,
    SmartPlaylistRuleFilterTextSource.language => lang.language,
    SmartPlaylistRuleFilterTextSource.label => lang.recordLabel,
    SmartPlaylistRuleFilterTextSource.format => lang.format,
    SmartPlaylistRuleFilterTextSource.channels => lang.channels,
    SmartPlaylistRuleFilterTextSource.lyrics => lang.lyrics,
    SmartPlaylistRuleFilterTextSource.moods => lang.moods,
    SmartPlaylistRuleFilterTextSource.tags => lang.tags,
    SmartPlaylistRuleFilterTextSource.youtubeLink => lang.youtubeLink,
    SmartPlaylistRuleFilterTextSource.youtubeID => lang.youtubeId,
    SmartPlaylistRuleFilterTextSource.filename => lang.fileName,
    SmartPlaylistRuleFilterTextSource.filenameWOExt => lang.fileNameWoExt,
    SmartPlaylistRuleFilterTextSource.path => lang.path,
    SmartPlaylistRuleFilterTextSource.folderName => lang.folderName,
    SmartPlaylistRuleFilterTextSource.folderPath => lang.folderPath,
    SmartPlaylistRuleFilterTextSource.extension => lang.extension,
  };

  @override
  IconData? toIcon() => switch (this) {
    SmartPlaylistRuleFilterTextSource.title => Broken.music,
    SmartPlaylistRuleFilterTextSource.album => Broken.music_dashboard,
    SmartPlaylistRuleFilterTextSource.artist => Broken.microphone,
    SmartPlaylistRuleFilterTextSource.albumArtist => Broken.user,
    SmartPlaylistRuleFilterTextSource.composer => Broken.profile_2user,
    SmartPlaylistRuleFilterTextSource.genre => Broken.smileys,
    SmartPlaylistRuleFilterTextSource.comment => Broken.message_text,
    SmartPlaylistRuleFilterTextSource.description => Broken.note_text,
    SmartPlaylistRuleFilterTextSource.synopsis => Broken.text,
    SmartPlaylistRuleFilterTextSource.language => Broken.language_circle,
    SmartPlaylistRuleFilterTextSource.label => Broken.ticket,
    SmartPlaylistRuleFilterTextSource.format => Broken.voice_cricle,
    SmartPlaylistRuleFilterTextSource.channels => Broken.airpods,
    SmartPlaylistRuleFilterTextSource.lyrics => Broken.message_text,
    SmartPlaylistRuleFilterTextSource.moods => Broken.smileys,
    SmartPlaylistRuleFilterTextSource.tags => Broken.tag,
    SmartPlaylistRuleFilterTextSource.youtubeLink => Broken.video_square,
    SmartPlaylistRuleFilterTextSource.youtubeID => Broken.video_square,
    SmartPlaylistRuleFilterTextSource.filename => Broken.quote_up_circle,
    SmartPlaylistRuleFilterTextSource.filenameWOExt => Broken.quote_up_circle,
    SmartPlaylistRuleFilterTextSource.path => Broken.location,
    SmartPlaylistRuleFilterTextSource.folderName => Broken.folder,
    SmartPlaylistRuleFilterTextSource.folderPath => Broken.folder,
    SmartPlaylistRuleFilterTextSource.extension => Broken.document,
  };
}
