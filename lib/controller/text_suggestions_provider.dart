// by claude, no mistakes.
import 'package:flutter/widgets.dart';

import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class TextSuggestionsProvider {
  final _cache = <TextSuggestionsSource, TextSuggestionsValues>{};

  TextSuggestionsValues valuesFor(TextSuggestionsSource source) => _cache[source] ??= _compute(source);

  static TextSuggestionsValues _compute(TextSuggestionsSource source) => switch (source) {
    // -- already grouped by the library, keys are unique & sorted by the user preference.
    TextSuggestionsSource.album => _build(Indexer.inst.mainMapAlbums.value.keys.map((e) => e.album), unknown: UnknownTags.ALBUM, alreadyUnique: false),
    TextSuggestionsSource.artist => _build(Indexer.inst.mainMapArtists.value.keys, unknown: UnknownTags.ARTIST),
    TextSuggestionsSource.albumArtist => _build(Indexer.inst.mainMapAlbumArtists.value.keys, unknown: UnknownTags.ALBUMARTIST),
    TextSuggestionsSource.composer => _build(Indexer.inst.mainMapComposer.value.keys, unknown: UnknownTags.COMPOSER),
    TextSuggestionsSource.genre => _build(Indexer.inst.mainMapGenres.value.keys, unknown: UnknownTags.GENRE),
    TextSuggestionsSource.style => _build(Indexer.inst.mainMapStyles.value.keys, unknown: UnknownTags.STYLE),
    TextSuggestionsSource.folderName => _build(Indexer.inst.mainMapFoldersTracksAndVideos.value.keys.map((e) => e.folderNameRaw), alreadyUnique: false),
    TextSuggestionsSource.folderPath => _build(Indexer.inst.mainMapFoldersTracksAndVideos.value.keys.map((e) => e.path), alreadyUnique: false),

    TextSuggestionsSource.mood => _build(Indexer.inst.getAllLibraryMoods(), sort: true),
    TextSuggestionsSource.tags => _build(Indexer.inst.getAllLibraryTags(), sort: true),

    // -- no library grouping for these, a single pass is required.
    TextSuggestionsSource.language => _buildFromTracks((trExt) => trExt.language),
    TextSuggestionsSource.recordLabel => _buildFromTracks((trExt) => trExt.label),
    TextSuggestionsSource.format => _buildFromTracks((trExt) => trExt.format),
    TextSuggestionsSource.channels => _buildFromTracks((trExt) => trExt.channels),
    TextSuggestionsSource.extension => _buildFromTracks((trExt) => trExt.path.getExtension),
  };

  static TextSuggestionsValues _buildFromTracks(String Function(TrackExtended trExt) getValue) {
    final values = <String>{};
    for (final trExt in Indexer.inst.allTracksMappedByPath.values) {
      final value = getValue(trExt);
      if (value.isNotEmpty) values.add(value);
    }
    return _build(values, sort: true);
  }

  static TextSuggestionsValues _build(Iterable<String> source, {String? unknown, bool sort = false, bool alreadyUnique = true}) {
    List<String> values;
    if (alreadyUnique) {
      values = <String>[];
      for (final value in source) {
        if (value.isEmpty || value == unknown) continue;
        values.add(value);
      }
    } else {
      final uniqued = <String>{};
      for (final value in source) {
        if (value.isEmpty || value == unknown) continue;
        uniqued.add(value);
      }
      values = uniqued.toList();
    }

    if (values.isEmpty) return TextSuggestionsValues.empty;

    final lowercased = List<String>.generate(values.length, (index) => values[index].toLowerCase(), growable: false);
    if (sort) {
      final indices = List<int>.generate(values.length, (index) => index, growable: false)..sort((a, b) => lowercased[a].compareTo(lowercased[b]));
      return TextSuggestionsValues(
        List<String>.generate(indices.length, (index) => values[indices[index]], growable: false),
        List<String>.generate(indices.length, (index) => lowercased[indices[index]], growable: false),
      );
    }
    return TextSuggestionsValues(values, lowercased);
  }
}

abstract final class TextSuggestionsMatcher {
  static const defaultLimit = 100;

  static RegExp? buildSeparatorsRegex(List<String> separators) {
    if (separators.isEmpty) return null;
    return RegExp(separators.map(RegExp.escape).join('|'), caseSensitive: false);
  }

  /// values starting with [query] come first, [values] are expected to be already unique.
  static List<String> filter({
    required TextSuggestionsValues values,
    required String query,
    Set<String>? excludeLowercased,
    int limit = defaultLimit,
  }) {
    final total = values.length;
    if (total == 0) return const [];

    final valuesList = values.values;
    final lowercased = values.lowercased;
    final queryLower = query.trim().toLowerCase();

    final startsWith = <String>[];
    final contains = <String>[];
    for (int i = 0; i < total; i++) {
      final valueLower = lowercased[i];
      if (excludeLowercased != null && excludeLowercased.contains(valueLower)) continue;
      if (queryLower.isEmpty) {
        startsWith.add(valuesList[i]);
      } else {
        final index = valueLower.indexOf(queryLower);
        if (index == 0) {
          startsWith.add(valuesList[i]);
        } else if (index > 0 && contains.length < limit) {
          contains.add(valuesList[i]);
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
  static _TextSuggestionsQuery parse(TextEditingValue value, RegExp? separatorsRegex) {
    final text = value.text;
    if (separatorsRegex == null) return _TextSuggestionsQuery(text.trim(), null);

    final ranges = _partsRanges(text, separatorsRegex);
    if (ranges.length == 1) return _TextSuggestionsQuery(text.trim(), null);

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
    return _TextSuggestionsQuery(query, exclude);
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
class _TextSuggestionsQuery {
  final String query;
  final Set<String>? excludeLowercased;

  const _TextSuggestionsQuery(this.query, this.excludeLowercased);
}

class TextSuggestionsValues {
  final List<String> values;
  final List<String> lowercased;

  const TextSuggestionsValues(this.values, this.lowercased);

  static const empty = TextSuggestionsValues([], []);

  int get length => values.length;
  bool get isEmpty => values.isEmpty;
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
  format,
  channels,
  extension,
  folderName,
  folderPath;

  /// whether a single field can hold multiple values separated by [buildSeparators].
  bool get isMultiValue => switch (this) {
    TextSuggestionsSource.artist || TextSuggestionsSource.genre || TextSuggestionsSource.style || TextSuggestionsSource.mood || TextSuggestionsSource.tags => true,
    TextSuggestionsSource.album ||
    TextSuggestionsSource.albumArtist ||
    TextSuggestionsSource.composer ||
    TextSuggestionsSource.language ||
    TextSuggestionsSource.recordLabel ||
    TextSuggestionsSource.format ||
    TextSuggestionsSource.channels ||
    TextSuggestionsSource.extension ||
    TextSuggestionsSource.folderName ||
    TextSuggestionsSource.folderPath => false,
  };

  /// separators used to split a field text into individual values, empty for single-value sources.
  List<String> buildSeparators() => switch (this) {
    TextSuggestionsSource.artist => settings.trackArtistsSeparators.value,
    TextSuggestionsSource.genre || TextSuggestionsSource.style => settings.trackGenresSeparators.value,
    TextSuggestionsSource.mood || TextSuggestionsSource.tags => GeneralSplitConfig.buildSeparatorsSet().toList(),
    TextSuggestionsSource.album ||
    TextSuggestionsSource.albumArtist ||
    TextSuggestionsSource.composer ||
    TextSuggestionsSource.language ||
    TextSuggestionsSource.recordLabel ||
    TextSuggestionsSource.format ||
    TextSuggestionsSource.channels ||
    TextSuggestionsSource.extension ||
    TextSuggestionsSource.folderName ||
    TextSuggestionsSource.folderPath => const <String>[],
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
    SmartPlaylistRuleFilterTextSource.format => TextSuggestionsSource.format,
    SmartPlaylistRuleFilterTextSource.channels => TextSuggestionsSource.channels,
    SmartPlaylistRuleFilterTextSource.extension => TextSuggestionsSource.extension,
    SmartPlaylistRuleFilterTextSource.folderName => TextSuggestionsSource.folderName,
    SmartPlaylistRuleFilterTextSource.folderPath => TextSuggestionsSource.folderPath,
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
