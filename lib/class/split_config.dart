import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';

class SplitArtistGenreConfigsWrapper {
  final String dbPath;
  final ArtistsSplitConfig artistsConfig;
  final GenresSplitConfig genresConfig;
  final AlbumsSplitConfig albumConfig;
  final GeneralSplitConfig generalConfig;

  const SplitArtistGenreConfigsWrapper({
    required this.dbPath,
    required this.artistsConfig,
    required this.genresConfig,
    required this.albumConfig,
    required this.generalConfig,
  });

  factory SplitArtistGenreConfigsWrapper.settings() {
    return SplitArtistGenreConfigsWrapper(
      dbPath: AppPaths.TRACKS_DB_INFO.file.path,
      artistsConfig: ArtistsSplitConfig.settings(),
      genresConfig: GenresSplitConfig.settings(),
      albumConfig: AlbumsSplitConfig.settings(),
      generalConfig: GeneralSplitConfig(),
    );
  }
}

class ArtistsSplitConfig extends SplitterConfig {
  final bool addFeatArtist;

  ArtistsSplitConfig({
    required this.addFeatArtist,
    required super.separators,
    required super.separatorsBlacklist,
  });

  factory ArtistsSplitConfig.settings({
    final bool? addFeatArtist,
    final List<String>? separators,
    final List<String>? separatorsBlacklist,
  }) {
    return ArtistsSplitConfig(
      addFeatArtist: addFeatArtist ?? settings.extractFeatArtistFromTitle.value,
      separators: separators ?? settings.trackArtistsSeparators.value,
      separatorsBlacklist: separatorsBlacklist ?? settings.trackArtistsSeparatorsBlacklist.value,
    );
  }

  factory ArtistsSplitConfig.fromMap(Map<String, dynamic> map) {
    return ArtistsSplitConfig(
      addFeatArtist: map["addFeatArtist"],
      separators: map["separators"],
      separatorsBlacklist: map["separatorsBlacklist"],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "addFeatArtist": addFeatArtist,
      "separators": separators,
      "separatorsBlacklist": separatorsBlacklist,
    };
  }
}

class GenresSplitConfig extends SplitterConfig {
  GenresSplitConfig({
    required super.separators,
    required super.separatorsBlacklist,
  });

  factory GenresSplitConfig.settings({
    final List<String>? separators,
    final List<String>? separatorsBlacklist,
  }) {
    return GenresSplitConfig(
      separators: separators ?? settings.trackGenresSeparators.value,
      separatorsBlacklist: separatorsBlacklist ?? settings.trackGenresSeparatorsBlacklist.value,
    );
  }

  factory GenresSplitConfig.fromMap(Map<String, dynamic> map) {
    return GenresSplitConfig(
      separators: map["separators"],
      separatorsBlacklist: map["separatorsBlacklist"],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "separators": separators,
      "separatorsBlacklist": separatorsBlacklist,
    };
  }
}

class AlbumsSplitConfig extends SplitterConfig {
  AlbumsSplitConfig({
    required super.separators,
    required super.separatorsBlacklist,
  });

  factory AlbumsSplitConfig.settings() {
    return AlbumsSplitConfig(
      separators: settings.trackAlbumsSeparators.value,
      separatorsBlacklist: settings.trackAlbumsSeparatorsBlacklist.value,
    );
  }
}

class GeneralSplitConfig extends SplitterConfig {
  GeneralSplitConfig._({
    required super.separators,
    required super.separatorsBlacklist,
  });

  factory GeneralSplitConfig() {
    return GeneralSplitConfig._(
      separators: buildSeparatorsSet().toList(),
      separatorsBlacklist: [],
    );
  }

  static Set<String> buildSeparatorsSet() {
    final finalSplitters = <String>{};
    finalSplitters.addAll(settings.trackArtistsSeparators.value);
    finalSplitters.addAll(settings.trackGenresSeparators.value);
    finalSplitters.addAll({';', ',', '//', r'\\'});
    return finalSplitters;
  }
}

class SplitDelimiter {
  final RegExp? _regex;
  final RegExp _extraWhitespaceRegex;

  const SplitDelimiter._(this._regex, this._extraWhitespaceRegex);

  factory SplitDelimiter.fromSingle(String singleDelimiter) {
    assert(singleDelimiter.length == 1);
    return SplitDelimiter.fromList([singleDelimiter]);
  }

  factory SplitDelimiter.fromList(Iterable<String> delimiters) {
    final extraWhitespaceRegex = _buildExtraWhitespaceRegex(delimiters);
    if (delimiters.isEmpty) return SplitDelimiter._(null, extraWhitespaceRegex);
    final normalizedDelimiters = delimiters.map((e) => e.replaceAll(extraWhitespaceRegex, ' '));
    final regexString = normalizedDelimiters.map(RegExp.escape).join('|');
    final regex = RegExp(regexString, caseSensitive: false);
    return SplitDelimiter._(regex, extraWhitespaceRegex);
  }

  static final _defaultExtraWhitespaceRegex = RegExp(r'\s{2,}|[^\S ]');
  static final _nonSpaceWhitespaceRegex = RegExp(r'[^\S ]');

  static RegExp _buildExtraWhitespaceRegex(Iterable<String> delimiters) {
    final keptWhitespace = <String>{};
    for (final d in delimiters) {
      for (final m in _nonSpaceWhitespaceRegex.allMatches(d)) {
        keptWhitespace.add(m[0]!);
      }
    }
    if (keptWhitespace.isEmpty) return _defaultExtraWhitespaceRegex;
    final kept = keptWhitespace.join();
    return RegExp('[^\\S$kept]{2,}|[^\\S $kept]');
  }

  /// `trimAll()` that keeps the separators' own whitespace.
  String _normalize(String text) => _normalizeWith(text, _extraWhitespaceRegex);

  static String _normalizeWith(String text, RegExp extraWhitespaceRegex) {
    if (!_mayHaveExtraWhitespace(text)) return text.trim();
    final collapsed = text.replaceAll(extraWhitespaceRegex, ' ');
    return collapsed.trim();
  }

  /// values kept whole, without empties and case duplicates.
  static List<String> normalizeValues(List<String> values) {
    final normalized = <String>[];
    for (final v in values) {
      final value = _normalizeWith(v, _defaultExtraWhitespaceRegex);
      if (value.isEmpty || _containsIgnoreCase(normalized, normalized.length, value)) continue;
      normalized.add(value);
    }
    return normalized;
  }

  /// false only when [_extraWhitespaceRegex] can't match: no double space and no whitespace other than a space.
  static bool _mayHaveExtraWhitespace(String text) {
    bool wasSpace = false;
    for (int i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c == 0x20) {
        if (wasSpace) return true;
        wasSpace = true;
        continue;
      }
      wasSpace = false;
      if (_isNonSpaceWhitespace(c)) return true;
    }
    return false;
  }

  /// the `\s` set of dart regexes, minus the space itself.
  static bool _isNonSpaceWhitespace(int c) {
    if (c < 0x09) return false;
    if (c <= 0x0D) return true;
    if (c < 0xA0) return false;
    return c == 0xA0 || //
        c == 0x1680 ||
        (c >= 0x2000 && c <= 0x200A) ||
        c == 0x2028 ||
        c == 0x2029 ||
        c == 0x202F ||
        c == 0x205F ||
        c == 0x3000 ||
        c == 0xFEFF;
  }

  /// blacklisted names match ignoring case, kept as written in [text].
  List<String> multiSplit(String text, RegExp? blacklistRegex) {
    final normalized = _normalize(text);
    final regex = _regex;
    if (regex == null) return normalized.isEmpty ? <String>[] : <String>[normalized];
    if (blacklistRegex == null) return _splitParts(normalized, regex);

    List<String>? parts;
    int start = 0;
    for (final m in blacklistRegex.allMatches(normalized)) {
      parts ??= <String>[];
      if (m.start > start) parts.addAll(_splitParts(normalized.substring(start, m.start), regex));
      parts.add(m[0]!);
      start = m.end;
    }
    if (parts == null) return _splitParts(normalized, regex);
    if (start < normalized.length) parts.addAll(_splitParts(normalized.substring(start), regex));
    _removeCaseDuplicates(parts);
    return parts;
  }

  /// longest names first, so a name containing another blacklisted name wins.
  static RegExp? _buildBlacklistRegex(List<String> blacklist) {
    if (blacklist.isEmpty) return null;
    blacklist.sort((a, b) => b.length.compareTo(a.length));
    final regexString = blacklist.map(RegExp.escape).join('|');
    return RegExp(regexString, caseSensitive: false);
  }

  /// drops case duplicates, the library maps ignore case.
  static List<String> _splitParts(String text, RegExp regex) {
    final parts = text.split(regex);
    int length = 0;
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i].trim();
      if (part.isEmpty || _containsIgnoreCase(parts, length, part)) continue;
      parts[length++] = part;
    }
    parts.length = length;
    return parts;
  }

  static void _removeCaseDuplicates(List<String> items) {
    int length = 0;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (_containsIgnoreCase(items, length, item)) continue;
      items[length++] = item;
    }
    items.length = length;
  }

  static bool _containsIgnoreCase(List<String> items, int length, String item) {
    if (length == 0) return false;
    final itemLower = item.toLowerCase();
    for (int i = 0; i < length; i++) {
      if (items[i].toLowerCase() == itemLower) return true;
    }
    return false;
  }
}

interface class SplitterConfig {
  final List<String> separators;
  final List<String> separatorsBlacklist;
  late final SplitDelimiter delimiter;
  late final RegExp? _blacklistRegex;

  SplitterConfig({
    required this.separators,
    required this.separatorsBlacklist,
  }) {
    final delimiter = SplitDelimiter.fromList(separators);
    this.delimiter = delimiter;
    final blacklistNormalized = separatorsBlacklist.map(delimiter._normalize).where((e) => e.isNotEmpty).toList();
    _blacklistRegex = SplitDelimiter._buildBlacklistRegex(blacklistNormalized);
  }

  String normalize(String text) => delimiter._normalize(text);

  List<String> splitText(String? string, {String? fallback}) {
    if (string == null) return fallback == null ? [] : [fallback];
    final splitted = delimiter.multiSplit(string, _blacklistRegex);
    if (splitted.isEmpty) return fallback == null ? [] : [fallback];
    return splitted;
  }

  void addSplitTextTo(List<String> items, String string) {
    for (final part in splitText(string)) {
      if (!SplitDelimiter._containsIgnoreCase(items, items.length, part)) items.add(part);
    }
  }
}
