// by claude, no mistakes.
import 'package:flutter/widgets.dart';

import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/iso639.dart';

class TextSuggestionsProvider {
  /// lyrics & titles of the track being edited, the languages written in their scripts are suggested first.
  final String Function()? languageHintText;

  TextSuggestionsProvider({this.languageHintText});

  final _cache = <TextSuggestionsSource, TextSuggestionsValues>{};

  TextSuggestionsValues valuesFor(TextSuggestionsSource source) => _cache[source] ??= _compute(source);

  /// most used values come first, ties are alphabetical.
  TextSuggestionsValues _compute(TextSuggestionsSource source) => switch (source) {
    TextSuggestionsSource.album => _buildFromGroups(Indexer.inst.mainMapAlbums.value, (e) => e.album, unknown: UnknownTags.ALBUM),
    TextSuggestionsSource.artist => _buildFromGroups(Indexer.inst.mainMapArtists.value, (e) => e, unknown: UnknownTags.ARTIST),
    TextSuggestionsSource.albumArtist => _buildFromGroups(Indexer.inst.mainMapAlbumArtists.value, (e) => e, unknown: UnknownTags.ALBUMARTIST),
    TextSuggestionsSource.composer => _buildFromGroups(Indexer.inst.mainMapComposer.value, (e) => e, unknown: UnknownTags.COMPOSER),
    TextSuggestionsSource.genre => _buildFromGroups(Indexer.inst.mainMapGenres.value, (e) => e, unknown: UnknownTags.GENRE),
    TextSuggestionsSource.style => _buildFromGroups(Indexer.inst.mainMapStyles.value, (e) => e, unknown: UnknownTags.STYLE),
    TextSuggestionsSource.folderName => _buildFromGroups(Indexer.inst.mainMapFoldersTracksAndVideos.value, (e) => e.folderNameRaw),
    TextSuggestionsSource.folderPath => _buildFromGroups(Indexer.inst.mainMapFoldersTracksAndVideos.value, (e) => e.path),
    TextSuggestionsSource.playlist => _buildPlaylists(),

    TextSuggestionsSource.mood => _buildFromCounts(Indexer.inst.getLibraryMoodsCounts()),
    TextSuggestionsSource.tags => _buildFromCounts(Indexer.inst.getLibraryTagsCounts()),
    TextSuggestionsSource.playlistTags => _buildPlaylistTags(),

    TextSuggestionsSource.language => _buildLanguages(languageHintText?.call()),

    // -- no library grouping for these, a single pass is required.
    TextSuggestionsSource.recordLabel => _buildFromTracks((trExt) => trExt.label),
    TextSuggestionsSource.releaseType => _buildFromTracks((trExt) => trExt.releaseType),
    TextSuggestionsSource.format => _buildFromTracks((trExt) => trExt.format),
    TextSuggestionsSource.channels => _buildFromTracks((trExt) => trExt.channels),
    TextSuggestionsSource.extension => _buildFromTracks((trExt) => trExt.path.getExtension),
  };

  static List<MapEntry<String, String>>? _languagesSortedByName;

  /// every iso language, codes are inserted while names are shown, the scripts found in [hintText] decide what comes first.
  static TextSuggestionsValues _buildLanguages(String? hintText) {
    final sortedByName = _languagesSortedByName ??= Iso639.entries.toFixedList()..sort((a, b) => a.value.compareTo(b.value));
    final preferred = hintText == null ? const <String>[] : _LanguageScriptHints.detect(hintText);

    final total = sortedByName.length;
    final codes = <String>[];
    final labels = <String>[];
    final searchTexts = <String>[];
    void add(String code) {
      final label = Iso639.labelOf(code);
      final labelLower = label.toLowerCase();
      final part1 = Iso639.part1Of(code);
      codes.add(code);
      labels.add(label);
      searchTexts.add(part1 == null ? labelLower : '$labelLower $part1');
    }

    for (final code in preferred) {
      add(code);
    }
    for (int i = 0; i < total; i++) {
      final code = sortedByName[i].key;
      if (preferred.contains(code)) continue;
      add(code);
    }
    // -- codes are already lowercase
    return TextSuggestionsValues(codes, codes, labels: labels, searchTexts: searchTexts);
  }

  static TextSuggestionsValues _buildFromTracks(String Function(TrackExtended trExt) getValue) {
    final counts = <String, int>{};
    for (final trExt in Indexer.inst.allTracksMappedByPath.values) {
      final value = getValue(trExt);
      if (value.isEmpty) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return _buildFromCounts(counts);
  }

  static TextSuggestionsValues _buildPlaylists() {
    final counts = <String, int>{};
    for (final e in PlaylistController.inst.playlistsMap.value.entries) {
      counts[e.key] = e.value.tracks.length;
    }
    return _buildFromCounts(counts);
  }

  static TextSuggestionsValues _buildPlaylistTags() {
    final filter = PlaylistController.inst.tagsFilter;
    final counts = <String, int>{};
    for (final path in filter.allPaths) {
      counts[path] = filter.playlistsCountOf(path);
    }
    return _buildFromCounts(counts);
  }

  /// the same name can come from several keys (albums with different identifiers, folders sharing a name), their counts add up.
  static TextSuggestionsValues _buildFromGroups<K, V>(Map<K, List<V>> groups, String Function(K key) nameOf, {String? unknown}) {
    final counts = <String, int>{};
    for (final e in groups.entries) {
      final name = nameOf(e.key);
      if (name.isEmpty || name == unknown) continue;
      counts[name] = (counts[name] ?? 0) + e.value.length;
    }
    return _buildFromCounts(counts);
  }

  static TextSuggestionsValues _buildFromCounts(Map<String, int> counts) {
    if (counts.isEmpty) return TextSuggestionsValues.empty;

    final total = counts.length;
    final values = List<String>.filled(total, '', growable: false);
    final countsList = List<int>.filled(total, 0, growable: false);
    int i = 0;
    for (final e in counts.entries) {
      values[i] = e.key;
      countsList[i] = e.value;
      i++;
    }
    final lowercased = List<String>.generate(total, (index) => values[index].toLowerCase(), growable: false);
    final indices = List<int>.generate(total, (index) => index, growable: false)
      ..sort((a, b) {
        final byCount = countsList[b].compareTo(countsList[a]);
        return byCount != 0 ? byCount : lowercased[a].compareTo(lowercased[b]);
      });
    return TextSuggestionsValues(
      List<String>.generate(total, (index) => values[indices[index]], growable: false),
      List<String>.generate(total, (index) => lowercased[indices[index]], growable: false),
    );
  }
}

// by claude
/// iso codes of the scripts found in a text, most frequent first. ex: hangul with some latin -> `[kor, eng]`.
abstract final class _LanguageScriptHints {
  static const _latin = 0;
  static const _greek = 1;
  static const _cyrillic = 2;
  static const _armenian = 3;
  static const _hebrew = 4;
  static const _arabic = 5;
  static const _devanagari = 6;
  static const _bengali = 7;
  static const _gurmukhi = 8;
  static const _gujarati = 9;
  static const _tamil = 10;
  static const _telugu = 11;
  static const _kannada = 12;
  static const _malayalam = 13;
  static const _thai = 14;
  static const _georgian = 15;
  static const _hangul = 16;
  static const _kana = 17;
  static const _han = 18;

  static const _kScriptCodes = <List<String>>[
    ['eng'], ['ell'], ['rus', 'ukr'], ['hye'], ['heb'], ['ara', 'fas'], ['hin'], ['ben'], ['pan'], ['guj'], //
    ['tam'], ['tel'], ['kan'], ['mal'], ['tha'], ['kat'], ['kor'], ['jpn'], ['zho'], //
  ];

  static List<String> detect(String text) {
    final counts = List<int>.filled(_kScriptCodes.length, 0);
    int total = 0;
    final length = text.length;
    for (int i = 0; i < length; i++) {
      final script = _scriptOf(text.codeUnitAt(i));
      if (script < 0) continue;
      counts[script]++;
      total++;
    }
    if (total == 0) return const [];

    // -- a few stray letters of another script are noise
    final minCount = total ~/ 20;
    final scripts = <int>[];
    for (int script = 0; script < counts.length; script++) {
      final count = counts[script];
      if (count > 0 && count >= minCount) scripts.add(script);
    }
    scripts.sort((a, b) => counts[b].compareTo(counts[a]));

    final hasKana = counts[_kana] > 0;
    final codes = <String>[];
    for (final script in scripts) {
      // -- han next to kana is japanese, already covered by the kana bucket
      if (script == _han && hasKana) continue;
      codes.addAll(_kScriptCodes[script]);
    }
    return codes;
  }

  static int _scriptOf(int c) {
    if (c < 0x0041) return -1;
    if (c <= 0x024F) {
      final isBasicLetter = c <= 0x005A || (c >= 0x0061 && c <= 0x007A);
      return isBasicLetter || c >= 0x00C0 ? _latin : -1;
    }
    if (c < 0x0370) return -1;
    if (c <= 0x03FF) return _greek;
    if (c <= 0x052F) return _cyrillic;
    if (c <= 0x058F) return _armenian;
    if (c <= 0x05FF) return _hebrew;
    if (c <= 0x06FF || (c >= 0x0750 && c <= 0x077F)) return _arabic;
    if (c < 0x0900) return -1;
    if (c <= 0x097F) return _devanagari;
    if (c <= 0x09FF) return _bengali;
    if (c <= 0x0A7F) return _gurmukhi;
    if (c <= 0x0AFF) return _gujarati;
    if (c < 0x0B80) return -1;
    if (c <= 0x0BFF) return _tamil;
    if (c <= 0x0C7F) return _telugu;
    if (c <= 0x0CFF) return _kannada;
    if (c <= 0x0D7F) return _malayalam;
    if (c >= 0x0E00 && c <= 0x0E7F) return _thai;
    if (c >= 0x10A0 && c <= 0x10FF) return _georgian;
    if (c >= 0x1100 && c <= 0x11FF) return _hangul;
    if (c >= 0x3041 && c <= 0x30FF) return _kana;
    if (c >= 0x3130 && c <= 0x318F) return _hangul;
    if ((c >= 0x3400 && c <= 0x9FFF) || c == 0x3005) return _han;
    if (c >= 0xAC00 && c <= 0xD7A3) return _hangul;
    return -1;
  }
}

abstract final class TextSuggestionsMatcher {
  static const defaultLimit = 100;

  static RegExp? buildSeparatorsRegex(List<String> separators) {
    if (separators.isEmpty) return null;
    return RegExp(separators.map(RegExp.escape).join('|'), caseSensitive: false);
  }

  /// indices of the matching values, the ones starting with [query] come first. [values] are expected to be already unique.
  static List<int> filter({
    required TextSuggestionsValues values,
    required String query,
    Set<String>? excludeLowercased,
    int limit = defaultLimit,
  }) {
    final total = values.length;
    if (total == 0) return const [];

    final lowercased = values.lowercased;
    final searchTexts = values.searchTexts ?? lowercased;
    final queryLower = query.trim().toLowerCase();

    final startsWith = <int>[];
    final contains = <int>[];
    for (int i = 0; i < total; i++) {
      if (excludeLowercased != null && excludeLowercased.contains(lowercased[i])) continue;
      if (queryLower.isEmpty) {
        startsWith.add(i);
      } else {
        final index = searchTexts[i].indexOf(queryLower);
        if (index == 0) {
          startsWith.add(i);
        } else if (index > 0 && contains.length < limit) {
          contains.add(i);
        }
      }
      if (startsWith.length >= limit) break;
    }

    if (startsWith.length < limit && contains.isNotEmpty) {
      final remaining = limit - startsWith.length;
      startsWith.addAll(contains.length <= remaining ? contains : contains.take(remaining));
    }
    return startsWith;
  }

  /// the value being typed at the cursor, alongside the other values already in the field.
  static TextSuggestionsQuery parse(TextEditingValue value, RegExp? separatorsRegex) {
    final text = value.text;
    if (separatorsRegex == null) return TextSuggestionsQuery(text.trim(), null);

    final ranges = _partsRanges(text, separatorsRegex);
    if (ranges.length == 1) return TextSuggestionsQuery(text.trim(), null);

    final activeIndex = _activeRangeIndex(ranges, value);

    String query = '';
    Set<String>? exclude;
    for (int i = 0; i < ranges.length; i++) {
      final range = ranges[i];
      final part = text.substring(range.$1, range.$2).trim();
      if (i == activeIndex) {
        query = part;
      } else if (part.isNotEmpty) {
        (exclude ??= <String>{}).add(part.toLowerCase());
      }
    }
    return TextSuggestionsQuery(query, exclude);
  }

  /// Replaces the value at the cursor (the same one [parse] used as the query) with [suggestion].
  static TextEditingValue applySuggestion({
    required TextEditingValue current,
    required String suggestion,
    required RegExp? separatorsRegex,
  }) {
    final text = current.text;
    if (separatorsRegex == null) return _valueOf(suggestion, suggestion.length);

    final ranges = _partsRanges(text, separatorsRegex);
    final range = ranges[_activeRangeIndex(ranges, current)];
    return _replaceRange(text, range.$1, range.$2, suggestion);
  }

  static List<(int, int)> _partsRanges(String text, RegExp separatorsRegex) {
    final ranges = <(int, int)>[];
    int start = 0;
    for (final match in separatorsRegex.allMatches(text)) {
      ranges.add((start, match.start));
      start = match.end;
    }
    ranges.add((start, text.length));
    return ranges;
  }

  /// index of the value containing the cursor, the last one if the selection is invalid.
  static int _activeRangeIndex(List<(int, int)> ranges, TextEditingValue value) {
    final selection = value.selection;
    final cursor = selection.isValid ? selection.end : value.text.length;
    for (int i = 0; i < ranges.length; i++) {
      final range = ranges[i];
      if (cursor >= range.$1 && cursor <= range.$2) return i;
    }
    return ranges.length - 1;
  }

  static TextEditingValue _replaceRange(String text, int start, int end, String replacement) {
    // -- preserving the spacing typed around the separators
    while (start < end && _isWhitespace(text.codeUnitAt(start))) {
      start++;
    }
    while (end > start && _isWhitespace(text.codeUnitAt(end - 1))) {
      end--;
    }
    return _valueOf(text.replaceRange(start, end, replacement), start + replacement.length);
  }

  static bool _isWhitespace(int codeUnit) => codeUnit == 32 || codeUnit == 9;

  static TextEditingValue _valueOf(String text, int cursor) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor),
  );
}

/// the query & the already-used values of a text field, at the current cursor position.
class TextSuggestionsQuery {
  final String query;
  final Set<String>? excludeLowercased;

  const TextSuggestionsQuery(this.query, this.excludeLowercased);
}

class TextSuggestionsValues {
  /// what gets inserted in the field.
  final List<String> values;
  final List<String> lowercased;

  /// what gets displayed, null when same as [values].
  final List<String>? labels;

  /// what gets matched against the query, null when same as [lowercased].
  final List<String>? searchTexts;

  const TextSuggestionsValues(this.values, this.lowercased, {this.labels, this.searchTexts});

  static const empty = TextSuggestionsValues([], []);

  int get length => values.length;
  bool get isEmpty => values.isEmpty;

  String labelAt(int index) => labels?[index] ?? values[index];
}

enum TextSuggestionsSource {
  album,
  artist,
  albumArtist,
  composer,
  genre,
  style,
  mood,
  tags,
  language,
  recordLabel,
  releaseType,
  format,
  channels,
  extension,
  folderName,
  folderPath,
  playlist,
  playlistTags;

  /// whether a single field can hold multiple values separated by [buildSeparators].
  bool get isMultiValue => switch (this) {
    TextSuggestionsSource.artist ||
    TextSuggestionsSource.composer ||
    TextSuggestionsSource.genre ||
    TextSuggestionsSource.style ||
    TextSuggestionsSource.mood ||
    TextSuggestionsSource.tags ||
    TextSuggestionsSource.language => true,
    TextSuggestionsSource.album ||
    TextSuggestionsSource.albumArtist ||
    TextSuggestionsSource.recordLabel ||
    TextSuggestionsSource.releaseType ||
    TextSuggestionsSource.format ||
    TextSuggestionsSource.channels ||
    TextSuggestionsSource.extension ||
    TextSuggestionsSource.folderName ||
    TextSuggestionsSource.folderPath ||
    TextSuggestionsSource.playlist ||
    TextSuggestionsSource.playlistTags => false,
  };

  /// separators used to split a field text into individual values, empty for single-value sources.
  List<String> buildSeparators() => switch (this) {
    TextSuggestionsSource.artist || TextSuggestionsSource.composer => settings.trackArtistsSeparators.value,
    TextSuggestionsSource.genre || TextSuggestionsSource.style => settings.trackGenresSeparators.value,
    TextSuggestionsSource.mood || TextSuggestionsSource.tags => GeneralSplitConfig.buildSeparatorsSet().toList(),
    TextSuggestionsSource.language => Iso639.separators,
    TextSuggestionsSource.album ||
    TextSuggestionsSource.albumArtist ||
    TextSuggestionsSource.recordLabel ||
    TextSuggestionsSource.releaseType ||
    TextSuggestionsSource.format ||
    TextSuggestionsSource.channels ||
    TextSuggestionsSource.extension ||
    TextSuggestionsSource.folderName ||
    TextSuggestionsSource.folderPath ||
    TextSuggestionsSource.playlist ||
    TextSuggestionsSource.playlistTags => const <String>[],
  };
}

extension TagFieldSuggestionsUtils on TagField {
  TextSuggestionsSource? toSuggestionsSource() => switch (this) {
    TagField.album => TextSuggestionsSource.album,
    TagField.artist => TextSuggestionsSource.artist,
    TagField.albumArtist => TextSuggestionsSource.albumArtist,
    TagField.composer => TextSuggestionsSource.composer,
    TagField.genre => TextSuggestionsSource.genre,
    TagField.style => TextSuggestionsSource.style,
    TagField.mood => TextSuggestionsSource.mood,
    TagField.tags => TextSuggestionsSource.tags,
    TagField.language => TextSuggestionsSource.language,
    TagField.recordLabel => TextSuggestionsSource.recordLabel,
    TagField.releaseType => TextSuggestionsSource.releaseType,
    TagField.title ||
    TagField.year ||
    TagField.trackNumber ||
    TagField.discNumber ||
    TagField.comment ||
    TagField.description ||
    TagField.synopsis ||
    TagField.lyrics ||
    TagField.remixer ||
    TagField.trackTotal ||
    TagField.discTotal ||
    TagField.lyricist ||
    TagField.country ||
    TagField.rating ||
    TagField.titleSort ||
    TagField.albumSort ||
    TagField.albumArtistSort ||
    TagField.artistSort ||
    TagField.composerSort => null,
  };
}

extension SmartPlaylistTextSourceSuggestionsUtils on SmartPlaylistRuleFilterTextSource {
  TextSuggestionsSource? toSuggestionsSource() => switch (this) {
    SmartPlaylistRuleFilterTextSource.album => TextSuggestionsSource.album,
    SmartPlaylistRuleFilterTextSource.artist => TextSuggestionsSource.artist,
    SmartPlaylistRuleFilterTextSource.albumArtist => TextSuggestionsSource.albumArtist,
    SmartPlaylistRuleFilterTextSource.composer => TextSuggestionsSource.composer,
    SmartPlaylistRuleFilterTextSource.genre => TextSuggestionsSource.genre,
    SmartPlaylistRuleFilterTextSource.style => TextSuggestionsSource.style,
    SmartPlaylistRuleFilterTextSource.moods => TextSuggestionsSource.mood,
    SmartPlaylistRuleFilterTextSource.tags => TextSuggestionsSource.tags,
    SmartPlaylistRuleFilterTextSource.language => TextSuggestionsSource.language,
    SmartPlaylistRuleFilterTextSource.label => TextSuggestionsSource.recordLabel,
    SmartPlaylistRuleFilterTextSource.releaseType => TextSuggestionsSource.releaseType,
    SmartPlaylistRuleFilterTextSource.format => TextSuggestionsSource.format,
    SmartPlaylistRuleFilterTextSource.channels => TextSuggestionsSource.channels,
    SmartPlaylistRuleFilterTextSource.extension => TextSuggestionsSource.extension,
    SmartPlaylistRuleFilterTextSource.folderName => TextSuggestionsSource.folderName,
    SmartPlaylistRuleFilterTextSource.folderPath => TextSuggestionsSource.folderPath,
    SmartPlaylistRuleFilterTextSource.playlist => TextSuggestionsSource.playlist,
    SmartPlaylistRuleFilterTextSource.playlistTags => TextSuggestionsSource.playlistTags,
    SmartPlaylistRuleFilterTextSource.title ||
    SmartPlaylistRuleFilterTextSource.comment ||
    SmartPlaylistRuleFilterTextSource.description ||
    SmartPlaylistRuleFilterTextSource.synopsis ||
    SmartPlaylistRuleFilterTextSource.lyrics ||
    SmartPlaylistRuleFilterTextSource.youtubeLink ||
    SmartPlaylistRuleFilterTextSource.youtubeID ||
    SmartPlaylistRuleFilterTextSource.filename ||
    SmartPlaylistRuleFilterTextSource.filenameWOExt ||
    SmartPlaylistRuleFilterTextSource.path => null,
  };
}
