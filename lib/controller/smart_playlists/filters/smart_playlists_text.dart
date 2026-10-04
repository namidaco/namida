part of '../smart_playlists_controller.dart';

final class SmartPlaylistRuleText
    extends SmartPlaylistRuleBase<List<SmartPlaylistTextDataToken>, List<SmartPlaylistTextDataToken>, SmartPlaylistRuleFilterText, SmartPlaylistRuleFilterTextSource> {
  SmartPlaylistRuleText({
    required super.data,
    required super.data2,
    required super.filter,
    required super.source,
    required super.enableCleanup,
  }) : super(
         type: SmartPlaylistFilterType.text,
         clockOnly: false,
         relativeDuration: null,
       );

  @override
  SmartPlaylistRuleText copyWith({
    (List<SmartPlaylistTextDataToken>? data, List<SmartPlaylistTextDataToken>? data2)? datas,
    SmartPlaylistRuleFilterText? filter,
    bool? enableCleanup,
    bool? clockOnly,
    SmartPlaylistRelativeDuration? relativeDuration,
  }) => SmartPlaylistRuleText(
    data: datas != null ? datas.$1 : this.data,
    data2: datas != null ? datas.$2 : this.data2,
    filter: filter ?? this.filter,
    source: this.source,
    enableCleanup: enableCleanup ?? this.enableCleanup,
  );

  @override
  String datasDisplayText() {
    final dataText = dataToText(data) ?? '';
    return switch (filter) {
      SmartPlaylistRuleFilterText.isInBetween => '$dataText -> • <- ${data2ToText(data2)}',
      SmartPlaylistRuleFilterText.isOutside => '• <- $dataText - ${data2ToText(data2)} -> •',
      _ => dataText,
    };
  }

  @override
  List<SmartPlaylistTextDataToken>? textToData(String? value) {
    if (value == null || value.isEmpty) return null;
    return [SmartPlaylistTextDataTokenLiteral(value)];
  }

  @override
  List<SmartPlaylistTextDataToken>? textToData2(String? value) => textToData(value);

  @override
  String? dataToText(List<SmartPlaylistTextDataToken>? data) {
    final tokens = data;
    if (tokens == null || tokens.isEmpty) return '';
    return tokens.map((t) => t.isSourceBased ? '[${t.displayText()}]' : t.displayText()).join();
  }

  @override
  String? data2ToText(List<SmartPlaylistTextDataToken>? data2) => dataToText(data2);

  @override
  String? toHintText() => null;

  @override
  String? dataValidator(String? value) {
    final tokens = data;
    if (tokens == null || tokens.isEmpty) return lang.emptyValue;
    if (filter.isRegex()) {
      // -- hack sources to a fake simple regex to validate
      final samplePattern = tokens.map((t) => t is SmartPlaylistTextDataTokenLiteral ? t.text : '.*').join();
      try {
        RegExp(samplePattern);
      } catch (e) {
        return 'Invalid regex:\n$e';
      }
    }
    return null;
  }

  @override
  String? validate() {
    final hasTokens = data?.isNotEmpty == true;
    final hasTokens2 = data2?.isNotEmpty == true;
    if (filter.requiresDataField && !hasTokens) return lang.emptyValue;
    if (!filter.requiresDataField && hasTokens) return lang.nameContainsBadCharacter;
    if (filter.requiresData2Field && !hasTokens2) return lang.emptyValue;
    if (!filter.requiresData2Field && hasTokens2) return lang.nameContainsBadCharacter;
    return null;
  }

  late final String? _staticData = data?.joinedLiteralTextOnly();
  late final String? _staticData2 = data2?.joinedLiteralTextOnly();
  late final String? _staticDataOrCleaned = _cleanedIfEnabled(_staticData);
  late final String? _staticData2OrCleaned = _cleanedIfEnabled(_staticData2);
  late final (String, String)? _staticBounds = _sortedBounds(_staticDataOrCleaned, _staticData2OrCleaned);
  late final RegExp? _staticRegex = _tryCompile(_staticData);

  RegExp? _tryCompile(String? pattern) {
    if (pattern == null) return null;
    try {
      return RegExp(pattern, caseSensitive: !enableCleanup, multiLine: true);
    } catch (_) {
      return null;
    }
  }

  String? _cleanedIfEnabled(String? text) => enableCleanup ? text?.cleanUpForComparison : text;

  static String? _resolveTokens(List<SmartPlaylistTextDataToken>? tokens, Track track, _SmartPlaylistResolveContext context, {bool escapeSources = false}) {
    if (tokens == null || tokens.isEmpty) return null;
    if (escapeSources) {
      return tokens
          .map(
            (t) => t.isSourceBased ? RegExp.escape(t._resolveFor(track, context)) : t._resolveFor(track, context),
          )
          .join();
    } else {
      return tokens.map((t) => t._resolveFor(track, context)).join();
    }
  }

  (String, String)? _resolveBounds(String? dataOrCleaned, Track track, _SmartPlaylistResolveContext context) {
    if (_staticData != null && _staticData2 != null) return _staticBounds;
    final data2OrCleaned = _staticData2 != null ? _staticData2OrCleaned : _cleanedIfEnabled(_resolveTokens(data2, track, context));
    return _sortedBounds(dataOrCleaned, data2OrCleaned);
  }

  static (String, String)? _sortedBounds(String? a, String? b) {
    if (a == null || b == null) return null;
    return a.compareTo(b) <= 0 ? (a, b) : (b, a);
  }

  /// compares [text] cut to [bound]'s length, so a bound covers everything starting with it: `C` is equal to `Coldplay`.
  static int _compareCutToBound(String text, String bound) {
    final textLength = text.length;
    final boundLength = bound.length;
    final length = textLength < boundLength ? textLength : boundLength;
    for (int i = 0; i < length; i++) {
      final diff = text.codeUnitAt(i) - bound.codeUnitAt(i);
      if (diff != 0) return diff;
    }
    return textLength < boundLength ? -1 : 0;
  }

  static bool _isBefore(String text, String bound) => text.isNotEmpty && text.compareTo(bound) < 0;
  static bool _isAfter(String text, String bound) => text.isNotEmpty && _compareCutToBound(text, bound) > 0;
  static bool _isInRange(String text, (String, String) bounds) => text.isNotEmpty && text.compareTo(bounds.$1) >= 0 && _compareCutToBound(text, bounds.$2) <= 0;
  static bool _isOutsideRange(String text, (String, String) bounds) => _isBefore(text, bounds.$1) || _isAfter(text, bounds.$2);

  @override
  bool _matches(Track track, _SmartPlaylistResolveContext context) {
    final isStatic = _staticData != null;
    final resolved = isStatic ? _staticData : _resolveTokens(data, track, context);
    final dataOrCleaned = isStatic ? _staticDataOrCleaned : _cleanedIfEnabled(resolved);
    late final dataAsRegex = resolved != null ? _staticRegex ?? _tryCompile(_resolveTokens(data, track, context, escapeSources: true)) : null;
    late final bounds = _resolveBounds(dataOrCleaned, track, context);

    bool textFnRaw(String trackText) => switch (filter) {
      SmartPlaylistRuleFilterText.isSame => trackText == dataOrCleaned,
      SmartPlaylistRuleFilterText.isNotSame => trackText != dataOrCleaned,
      SmartPlaylistRuleFilterText.contains => dataOrCleaned != null && trackText.contains(dataOrCleaned),
      SmartPlaylistRuleFilterText.notContains => dataOrCleaned != null && !trackText.contains(dataOrCleaned),
      SmartPlaylistRuleFilterText.startsWith => dataOrCleaned != null && trackText.startsWith(dataOrCleaned),
      SmartPlaylistRuleFilterText.endsWith => dataOrCleaned != null && trackText.endsWith(dataOrCleaned),
      SmartPlaylistRuleFilterText.regexMatch => dataAsRegex != null && dataAsRegex.hasMatch(trackText),
      SmartPlaylistRuleFilterText.regexNotMatch => dataAsRegex != null && !dataAsRegex.hasMatch(trackText),
      SmartPlaylistRuleFilterText.isBefore => dataOrCleaned != null && _isBefore(trackText, dataOrCleaned),
      SmartPlaylistRuleFilterText.isAfter => dataOrCleaned != null && _isAfter(trackText, dataOrCleaned),
      SmartPlaylistRuleFilterText.isInBetween => bounds != null && _isInRange(trackText, bounds),
      SmartPlaylistRuleFilterText.isOutside => bounds != null && _isOutsideRange(trackText, bounds),
      SmartPlaylistRuleFilterText.exists => trackText.isNotEmpty,
      SmartPlaylistRuleFilterText.missing => trackText.isEmpty,
    };

    bool textListFnRaw(Iterable<String> list) => switch (filter) {
      SmartPlaylistRuleFilterText.isSame => list.any((e) => e == dataOrCleaned),
      SmartPlaylistRuleFilterText.isNotSame => !list.any((e) => e == dataOrCleaned),
      SmartPlaylistRuleFilterText.contains => dataOrCleaned != null && list.any((e) => e.contains(dataOrCleaned)),
      SmartPlaylistRuleFilterText.notContains => dataOrCleaned != null && !list.any((e) => e.contains(dataOrCleaned)),
      SmartPlaylistRuleFilterText.startsWith => dataOrCleaned != null && list.any((e) => e.startsWith(dataOrCleaned)),
      SmartPlaylistRuleFilterText.endsWith => dataOrCleaned != null && list.any((e) => e.endsWith(dataOrCleaned)),
      SmartPlaylistRuleFilterText.regexMatch => dataAsRegex != null && list.any((e) => dataAsRegex.hasMatch(e)),
      SmartPlaylistRuleFilterText.regexNotMatch => dataAsRegex != null && !list.any((e) => dataAsRegex.hasMatch(e)),
      SmartPlaylistRuleFilterText.isBefore => dataOrCleaned != null && list.any((e) => _isBefore(e, dataOrCleaned)),
      SmartPlaylistRuleFilterText.isAfter => dataOrCleaned != null && list.any((e) => _isAfter(e, dataOrCleaned)),
      SmartPlaylistRuleFilterText.isInBetween => bounds != null && list.any((e) => _isInRange(e, bounds)),
      SmartPlaylistRuleFilterText.isOutside => bounds != null && list.any((e) => _isOutsideRange(e, bounds)),
      SmartPlaylistRuleFilterText.exists => list.isNotEmpty,
      SmartPlaylistRuleFilterText.missing => list.isEmpty,
    };

    bool textFn(String t) => enableCleanup ? textFnRaw(t.cleanUpForComparison) : textFnRaw(t);
    bool textListFn(List<String> list) => enableCleanup ? textListFnRaw(list.map((e) => e.cleanUpForComparison)) : textListFnRaw(list);

    return switch (source) {
      SmartPlaylistRuleFilterTextSource.title => textFn(track.title),
      SmartPlaylistRuleFilterTextSource.album => textListFn(track.albumsList),
      SmartPlaylistRuleFilterTextSource.artist => textListFn(track.artistsList),
      SmartPlaylistRuleFilterTextSource.albumArtist => textFn(track.albumArtist),
      SmartPlaylistRuleFilterTextSource.composer => textListFn(track.composersList),
      SmartPlaylistRuleFilterTextSource.genre => textListFn(track.genresList),
      SmartPlaylistRuleFilterTextSource.style => textListFn(track.stylesList),
      SmartPlaylistRuleFilterTextSource.comment => textFn(track.comment),
      SmartPlaylistRuleFilterTextSource.description => textFn(track.description),
      SmartPlaylistRuleFilterTextSource.synopsis => textFn(track.synopsis),
      SmartPlaylistRuleFilterTextSource.language => textListFn(track.languagesList),
      SmartPlaylistRuleFilterTextSource.label => textFn(track.label),
      SmartPlaylistRuleFilterTextSource.releaseType => textFn(track.releaseType),
      SmartPlaylistRuleFilterTextSource.format => textFn(track.format),
      SmartPlaylistRuleFilterTextSource.channels => textFn(track.channels),
      SmartPlaylistRuleFilterTextSource.lyrics => textFn(track.lyrics),
      SmartPlaylistRuleFilterTextSource.moods => textListFn(track.effectiveMoods),
      SmartPlaylistRuleFilterTextSource.tags => textListFn(track.effectiveTags),
      SmartPlaylistRuleFilterTextSource.playlist => textListFn(context.playlistsOf(track) ?? const []),
      SmartPlaylistRuleFilterTextSource.playlistTags => textListFn(context.playlistsTagsOf(track) ?? const []),
      SmartPlaylistRuleFilterTextSource.youtubeLink => textFn(track.youtubeLink),
      SmartPlaylistRuleFilterTextSource.youtubeID => textFn(track.youtubeID),
      SmartPlaylistRuleFilterTextSource.filename => textFn(track.filename),
      SmartPlaylistRuleFilterTextSource.filenameWOExt => textFn(track.filenameWOExt),
      SmartPlaylistRuleFilterTextSource.path => textFn(track.path),
      SmartPlaylistRuleFilterTextSource.folderName => textFn(track.folderName),
      SmartPlaylistRuleFilterTextSource.folderPath => textFn(track.folderPath),
      SmartPlaylistRuleFilterTextSource.extension => textFn(track.extension),
    };
  }

  factory SmartPlaylistRuleText.fromMap(Map map) {
    return SmartPlaylistRuleText(
      data: _tokensFromJson(map['data']),
      data2: _tokensFromJson(map['data2']),
      filter: SmartPlaylistRuleFilterText.values.getEnum(map['filter'])!,
      source: SmartPlaylistRuleFilterTextSource.values.getEnum(map['source'])!,
      enableCleanup: map['enableCleanup'] == true,
    );
  }

  static List<SmartPlaylistTextDataToken>? _tokensFromJson(dynamic raw) {
    if (raw is String) return raw.isEmpty ? null : [SmartPlaylistTextDataTokenLiteral(raw)];
    if (raw is! List) return null;
    final tokens = raw.map(SmartPlaylistTextDataToken.fromAny).whereType<SmartPlaylistTextDataToken>().toList();
    return tokens.isEmpty ? null : tokens;
  }

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type.name,
      'filter': filter.name,
      'source': source.name,
      'data': data?.map((t) => t.toMap()).toFixedList(),
      'data2': ?data2?.map((t) => t.toMap()).toFixedList(),
      if (enableCleanup) 'enableCleanup': enableCleanup,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SmartPlaylistRuleText) return false;
    return other.type == type && //
        other.filter == filter &&
        other.source == source &&
        _tokensEqual(other.data, data) &&
        _tokensEqual(other.data2, data2) &&
        other.enableCleanup == enableCleanup;
  }

  @override
  int get hashCode =>
      type.hashCode ^ //
      filter.hashCode ^
      source.hashCode ^
      _tokensHash(data) ^
      _tokensHash(data2) ^
      enableCleanup.hashCode;

  static bool _tokensEqual(List<SmartPlaylistTextDataToken>? a, List<SmartPlaylistTextDataToken>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static int _tokensHash(List<SmartPlaylistTextDataToken>? tokens) {
    if (tokens == null) return 0;
    return Object.hashAll(tokens);
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
  isBefore,
  isAfter,
  isInBetween(requiresData2Field: true),
  isOutside(requiresData2Field: true),
  exists(requiresDataField: false),
  missing(requiresDataField: false),
  ;

  bool isRegex() => switch (this) {
    SmartPlaylistRuleFilterText.regexMatch => true,
    SmartPlaylistRuleFilterText.regexNotMatch => true,
    _ => false,
  };

  bool isAlphabetical() => switch (this) {
    SmartPlaylistRuleFilterText.isBefore || SmartPlaylistRuleFilterText.isAfter || SmartPlaylistRuleFilterText.isInBetween || SmartPlaylistRuleFilterText.isOutside => true,
    _ => false,
  };

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
    SmartPlaylistRuleFilterText.isBefore => "${lang.isBefore} (A-Z)",
    SmartPlaylistRuleFilterText.isAfter => "${lang.isAfter} (A-Z)",
    SmartPlaylistRuleFilterText.isInBetween => "${lang.isInBetween} (A-Z)",
    SmartPlaylistRuleFilterText.isOutside => "${lang.isOutside} (A-Z)",
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
    SmartPlaylistRuleFilterText.isBefore => null,
    SmartPlaylistRuleFilterText.isAfter => null,
    SmartPlaylistRuleFilterText.isInBetween => null,
    SmartPlaylistRuleFilterText.isOutside => null,
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
    SmartPlaylistRuleFilterText.isBefore => '<--',
    SmartPlaylistRuleFilterText.isAfter => '-->',
    SmartPlaylistRuleFilterText.isInBetween => '-><-',
    SmartPlaylistRuleFilterText.isOutside => '<-->',
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
  style,
  comment,
  description(canAffectPerformance: true),
  synopsis(canAffectPerformance: true),
  language,
  label,
  releaseType,
  format,
  channels,
  lyrics(canAffectPerformance: true),
  moods,
  tags,
  playlist,
  playlistTags,
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
    SmartPlaylistRuleFilterTextSource.style => lang.style,
    SmartPlaylistRuleFilterTextSource.comment => lang.comment,
    SmartPlaylistRuleFilterTextSource.description => lang.description,
    SmartPlaylistRuleFilterTextSource.synopsis => lang.synopsis,
    SmartPlaylistRuleFilterTextSource.language => lang.language,
    SmartPlaylistRuleFilterTextSource.label => lang.recordLabel,
    SmartPlaylistRuleFilterTextSource.releaseType => lang.releaseType,
    SmartPlaylistRuleFilterTextSource.format => lang.format,
    SmartPlaylistRuleFilterTextSource.channels => lang.channels,
    SmartPlaylistRuleFilterTextSource.lyrics => lang.lyrics,
    SmartPlaylistRuleFilterTextSource.moods => lang.moods,
    SmartPlaylistRuleFilterTextSource.tags => lang.tags,
    SmartPlaylistRuleFilterTextSource.playlist => lang.playlist,
    SmartPlaylistRuleFilterTextSource.playlistTags => lang.playlistTags,
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
    SmartPlaylistRuleFilterTextSource.style => Broken.brush_1,
    SmartPlaylistRuleFilterTextSource.comment => Broken.message_text,
    SmartPlaylistRuleFilterTextSource.description => Broken.note_text,
    SmartPlaylistRuleFilterTextSource.synopsis => Broken.text,
    SmartPlaylistRuleFilterTextSource.language => Broken.language_circle,
    SmartPlaylistRuleFilterTextSource.label => Broken.ticket,
    SmartPlaylistRuleFilterTextSource.releaseType => Broken.cd,
    SmartPlaylistRuleFilterTextSource.format => Broken.voice_cricle,
    SmartPlaylistRuleFilterTextSource.channels => Broken.airpods,
    SmartPlaylistRuleFilterTextSource.lyrics => Broken.message_text,
    SmartPlaylistRuleFilterTextSource.moods => Broken.smileys,
    SmartPlaylistRuleFilterTextSource.tags => Broken.tag,
    SmartPlaylistRuleFilterTextSource.playlist => Broken.music_library_2,
    SmartPlaylistRuleFilterTextSource.playlistTags => Broken.tag_2,
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

sealed class SmartPlaylistTextDataToken {
  final _SmartPlaylistTextDataTokenType _type;
  const SmartPlaylistTextDataToken(this._type);

  bool get isLiteral => switch (_type) {
    _SmartPlaylistTextDataTokenType.literal => true,
    _SmartPlaylistTextDataTokenType.source => false,
  };

  bool get isSourceBased => switch (_type) {
    _SmartPlaylistTextDataTokenType.literal => false,
    _SmartPlaylistTextDataTokenType.source => true,
  };

  String _resolveFor(Track track, _SmartPlaylistResolveContext context);
  String displayText();
  Map<String, dynamic> toMap();

  static SmartPlaylistTextDataToken? fromAny(dynamic value) {
    // -- backward compatibility
    if (value is String) return SmartPlaylistTextDataTokenLiteral(value);
    if (value is! Map) return null;
    final type = _SmartPlaylistTextDataTokenType.values.getEnum(value['type']);
    return switch (type) {
      _SmartPlaylistTextDataTokenType.literal => SmartPlaylistTextDataTokenLiteral.fromTextNullable(value['text']),
      _SmartPlaylistTextDataTokenType.source => SmartPlaylistTextDataTokenSource.fromSourceStringNullable(value['source']),
      null => null,
    };
  }
}

class SmartPlaylistTextDataTokenLiteral extends SmartPlaylistTextDataToken {
  final String text;
  const SmartPlaylistTextDataTokenLiteral(this.text) : super(_SmartPlaylistTextDataTokenType.literal);

  static SmartPlaylistTextDataTokenLiteral? fromTextNullable(String? text) {
    return text == null ? null : SmartPlaylistTextDataTokenLiteral(text);
  }

  @override
  String _resolveFor(Track track, _SmartPlaylistResolveContext context) => text;

  @override
  String displayText() => text;

  @override
  Map<String, dynamic> toMap() => {
    'type': _type.name,
    'text': text,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SmartPlaylistTextDataTokenLiteral) return false;

    return other.text == text;
  }

  @override
  int get hashCode => text.hashCode;
}

class SmartPlaylistTextDataTokenSource extends SmartPlaylistTextDataToken {
  final SmartPlaylistRuleFilterTextSource source;
  const SmartPlaylistTextDataTokenSource(this.source) : super(_SmartPlaylistTextDataTokenType.source);

  static SmartPlaylistTextDataTokenSource? fromSourceStringNullable(String? source) {
    final src = SmartPlaylistRuleFilterTextSource.values.getEnum(source);
    return src == null ? null : SmartPlaylistTextDataTokenSource(src);
  }

  @override
  String _resolveFor(Track track, _SmartPlaylistResolveContext context) => switch (source) {
    SmartPlaylistRuleFilterTextSource.title => track.title,
    SmartPlaylistRuleFilterTextSource.album => track.albumsList.join(' '),
    SmartPlaylistRuleFilterTextSource.artist => track.artistsList.join(' '),
    SmartPlaylistRuleFilterTextSource.albumArtist => track.albumArtist,
    SmartPlaylistRuleFilterTextSource.composer => track.composersList.join(' '),
    SmartPlaylistRuleFilterTextSource.genre => track.genresList.join(' '),
    SmartPlaylistRuleFilterTextSource.style => track.stylesList.join(' '),
    SmartPlaylistRuleFilterTextSource.comment => track.comment,
    SmartPlaylistRuleFilterTextSource.description => track.description,
    SmartPlaylistRuleFilterTextSource.synopsis => track.synopsis,
    SmartPlaylistRuleFilterTextSource.language => track.languagesList.join(' '),
    SmartPlaylistRuleFilterTextSource.label => track.label,
    SmartPlaylistRuleFilterTextSource.releaseType => track.releaseType,
    SmartPlaylistRuleFilterTextSource.format => track.format,
    SmartPlaylistRuleFilterTextSource.channels => track.channels,
    SmartPlaylistRuleFilterTextSource.lyrics => track.lyrics,
    SmartPlaylistRuleFilterTextSource.moods => track.effectiveMoods.join(' '),
    SmartPlaylistRuleFilterTextSource.tags => track.effectiveTags.join(' '),
    SmartPlaylistRuleFilterTextSource.playlist => context.playlistsOf(track)?.join(' ') ?? '',
    SmartPlaylistRuleFilterTextSource.playlistTags => context.playlistsTagsOf(track)?.join(' ') ?? '',
    SmartPlaylistRuleFilterTextSource.youtubeLink => track.youtubeLink,
    SmartPlaylistRuleFilterTextSource.youtubeID => track.youtubeID,
    SmartPlaylistRuleFilterTextSource.filename => track.filename,
    SmartPlaylistRuleFilterTextSource.filenameWOExt => track.filenameWOExt,
    SmartPlaylistRuleFilterTextSource.path => track.path,
    SmartPlaylistRuleFilterTextSource.folderName => track.folderName,
    SmartPlaylistRuleFilterTextSource.folderPath => track.folderPath,
    SmartPlaylistRuleFilterTextSource.extension => track.extension,
  };

  @override
  String displayText() => source.toText();

  @override
  Map<String, dynamic> toMap() => {
    'type': _type.name,
    'source': source.name,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SmartPlaylistTextDataTokenSource) return false;

    return other.source == source;
  }

  @override
  int get hashCode => source.hashCode;
}

enum _SmartPlaylistTextDataTokenType {
  literal,
  source,
}

extension on List<SmartPlaylistTextDataToken> {
  String? joinedLiteralTextOnly() {
    final buffer = StringBuffer();
    for (final token in this) {
      switch (token) {
        case SmartPlaylistTextDataTokenLiteral():
          buffer.write(token.text);
        case SmartPlaylistTextDataTokenSource():
          return null; // source detected, not text only anymore
      }
    }
    final result = buffer.toString();
    if (result.isEmpty) return null;
    return result;
  }
}
