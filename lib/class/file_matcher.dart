import 'package:dart_extensions/dart_extensions.dart';

import 'package:namida/core/constants.dart';

class FileMatcher {
  final Set<String> allAudioFiles;
  FileMatcher.init({bool buildIndex = true, required this.allAudioFiles}) {
    if (buildIndex) _fillData();
  }

  final _allFilesByName = <String, List<String>>{};
  final _allFilesByNameWOExt = <String, List<String>>{};
  final _allFilesByCleanedToken = <String, List<String>>{};
  final _allFilesByTitleToken = <String, List<String>>{};
  final _allFilesByArtistToken = <String, List<String>>{};

  void _fillData() {
    for (final path in allAudioFiles) {
      final filename = path.getFilename;
      final filenameWOExt = path.getFilenameWOExt;

      _allFilesByName.addForce(filename, path);
      _allFilesByNameWOExt.addForce(filenameWOExt, path);

      final cleaned = filename.cleanUpForComparison;
      for (final token in cleaned.split(' ')) {
        if (token.isNotEmpty) _allFilesByCleanedToken.addForce(token, path);
      }

      final l = FileMatcher.getTitleAndArtistFromFilename(filename);
      final title = l.$1;
      final artist = l.$2;
      for (final token in title.split(' ')) {
        if (token.isNotEmpty) _allFilesByTitleToken.addForce(token, path);
      }
      for (final token in artist.split(' ')) {
        if (token.isNotEmpty) _allFilesByArtistToken.addForce(token, path);
      }
    }
  }

  String? getSuggestion(String path) {
    final all = _getAllSuggestionsInternal(path, singleOnly: true);
    return all.firstOrNull;
  }

  Iterable<String> getAllSuggestions(String path) {
    return _getAllSuggestionsInternal(path, singleOnly: false);
  }

  Iterable<String> _getAllSuggestionsInternal(
    String filePathToMatch, {
    bool singleOnly = false,
  }) {
    int? latestPriority;
    bool requiresSorting = false;
    final matches = <(String, int)>[];

    void addMatch(String filePath, int priority) {
      matches.add((filePath, priority));
      if (!requiresSorting) {
        if (latestPriority == null) {
          latestPriority = priority;
        } else if (priority != latestPriority) {
          requiresSorting = true;
        }
      }
    }

    final filenameToMatch = filePathToMatch.getFilename;
    final filenameWOExtToMatch = filePathToMatch.getFilenameWOExt;

    // -- filename
    if (_allFilesByName.isNotEmpty) {
      final matches = _allFilesByName[filenameToMatch] ?? [];
      for (final e in matches) {
        if (singleOnly) return [e];
        addMatch(e, 0);
      }
    }

    // -- filename without ext
    if (_allFilesByNameWOExt.isNotEmpty) {
      final matches = _allFilesByNameWOExt[filenameWOExtToMatch] ?? [];
      for (final e in matches) {
        if (singleOnly) return [e];
        addMatch(e, 1);
      }
    }

    final filenameToMatchCleaned = filenameToMatch.cleanUpForComparison;
    final l = FileMatcher.getTitleAndArtistFromFilename(filenameToMatch);
    final trackTitle = l.$1;
    final trackArtist = l.$2;

    if (_allFilesByCleanedToken.isNotEmpty) {
      final queryTokens = filenameToMatchCleaned.split(' ').where((t) => t.isNotEmpty);
      if (queryTokens.isNotEmpty) {
        final sets = queryTokens.map((t) => _allFilesByCleanedToken[t]?.toSet() ?? <String>{});
        final matches = sets.reduce((a, b) => a.intersection(b));
        for (final path in matches) {
          if (singleOnly) return [path];
          addMatch(path, 2);
        }
      }
    }

    // -- title + artist
    if (_allFilesByTitleToken.isNotEmpty && _allFilesByArtistToken.isNotEmpty) {
      final titleFragment = trackTitle.splitFirst('(');
      final titleTokens = titleFragment.split(' ').where((t) => t.isNotEmpty).toSet();
      final artistTokens = trackArtist.split(' ').where((t) => t.isNotEmpty).toSet();

      if (titleTokens.isNotEmpty && artistTokens.isNotEmpty) {
        final titleMatches = titleTokens.map((t) => _allFilesByTitleToken[t]?.toSet() ?? <String>{}).reduce((a, b) => a.intersection(b));
        final artistMatches = artistTokens.map((t) => _allFilesByArtistToken[t]?.toSet() ?? <String>{}).reduce((a, b) => a.intersection(b));
        for (final path in titleMatches.intersection(artistMatches)) {
          if (singleOnly) return [path];
          addMatch(path, 3);
        }
      }
    }

    // -- fallback, if index was not built
    if (_allFilesByName.isEmpty && _allFilesByNameWOExt.isEmpty && _allFilesByCleanedToken.isEmpty && _allFilesByTitleToken.isEmpty) {
      for (final path in allAudioFiles) {
        final fileSystemFilename = path.getFilename;
        if (filenameToMatch == fileSystemFilename) {
          if (singleOnly) return [path];
          addMatch(path, 0);
          continue;
        }
        final fileSystemFilenameWOExt = path.getFilenameWOExt;
        if (filenameWOExtToMatch == fileSystemFilenameWOExt) {
          if (singleOnly) return [path];
          addMatch(path, 1);
          continue;
        }
        final fileSystemFilenameCleaned = fileSystemFilename.cleanUpForComparison;
        if (fileSystemFilenameCleaned.contains(filenameToMatchCleaned)) {
          addMatch(path, 2);
          continue;
        }
        if (fileSystemFilenameCleaned.contains(trackTitle.splitFirst('(')) && fileSystemFilenameCleaned.contains(trackArtist)) {
          addMatch(path, 3);
        }
      }
    }

    if (requiresSorting) matches.sortBy((e) => e.$2);
    return matches.map((e) => e.$1);
  }

  void dispose() {
    _allFilesByName.clear();
    _allFilesByNameWOExt.clear();
    _allFilesByCleanedToken.clear();
    _allFilesByTitleToken.clear();
    _allFilesByArtistToken.clear();
  }

  /// (title, artist)
  static (String, String) getTitleAndArtistFromFilename(String filename) {
    final filenameWOEx = filename.replaceAll('_', ' ');
    List<String> titleAndArtist;

    /// preferring to split by [' - '], since there are artists that has '-' in their name.
    titleAndArtist = filenameWOEx.split(' - ');
    if (titleAndArtist.length == 1) {
      titleAndArtist = filenameWOEx.split('-');
    }

    /// in case splitting produced 2 entries or more, it means its high likely to be [artist - title]
    /// otherwise [title] will be the [filename] and [artist] will be [Unknown]
    final title = titleAndArtist.length >= 2 ? titleAndArtist[1].trimAll() : filenameWOEx;
    final artist = titleAndArtist.length >= 2 ? titleAndArtist[0].trimAll() : UnknownTags.ARTIST;

    final cleanedUpTitle = _stripParenGroups(_stripBracketGroups(title, fallback: title.splitFirst('[').trimAll()));
    final cleanedUpArtist = _stripParenGroups(_stripBracketGroups(artist, fallback: artist.splitLast(']').trimAll()));

    return (cleanedUpTitle.isEmpty ? filenameWOEx.trimAll() : cleanedUpTitle, cleanedUpArtist.isEmpty ? UnknownTags.ARTIST : cleanedUpArtist);
  }

  static final _bracketGroupRegex = RegExp(r'\[[^\]]*\]');
  static final _parenGroupRegex = RegExp(r'\([^)]*\)');

  /// groups that carry actual identity of the track, ex: `(feat. X)`, `(Slowed Remix)`.
  static final _meaningfulParenGroupRegex = RegExp(
    r'\b(?:feat|ft|featuring|remix|rmx|remixed|mix|bootleg|mashup|cover|edit|flip|vip|acoustic|instrumental|version|sped|slowed|nightcore|reverb)\b',
    caseSensitive: false,
  );

  /// `[Group] Title [1080p]` => `Title`, keeps the middle when the name starts with a tag.
  static String _stripBracketGroups(String text, {required String fallback}) {
    if (!text.contains('[')) return text.trimAll();
    final stripped = text.replaceAll(_bracketGroupRegex, ' ').trimAll();
    return stripped.isEmpty ? fallback : stripped;
  }

  /// `Title (Official Video) (Remix)` => `Title (Remix)`.
  static String _stripParenGroups(String text) {
    if (!text.contains('(')) return text;
    final stripped = text.replaceAllMapped(_parenGroupRegex, (m) {
      final group = m[0]!;
      return _meaningfulParenGroupRegex.hasMatch(group) ? group : ' ';
    }).trimAll();
    return stripped.isEmpty ? text.trimAll() : stripped;
  }
}
