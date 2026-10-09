import 'package:dart_extensions/dart_extensions.dart';

import 'package:namida/core/enums.dart';

class FilePathMatcher extends SearchMatcher {
  FilePathMatcher.init(super.paths) : super.init(transformer: _pathTransformer);

  static String _pathTransformer(String item) => item.getFilenameWOExt;

  // -- any standalone 11 chars, `-` & `_` can also surround it: `Title [ID]`, `Title-ID`, `v=ID`. lookahead so candidates can overlap.
  static final _ytIDCandidateRegex = RegExp(r'(?<![a-zA-Z0-9])(?=([\w-]{11})(?![a-zA-Z0-9]))');

  late final _videosGroupedByYTID = _buildYTIDIndex();

  Map<String, List<String>> _buildYTIDIndex() {
    final map = <String, List<String>>{};
    for (final vp in items) {
      final filename = vp.getFilenameWOExt;
      for (final match in _ytIDCandidateRegex.allMatches(filename)) {
        map.addForce(match[1]!, vp);
      }
    }
    return map;
  }

  Set<String> matchTrackVideos({
    required String filenameWOExt,
    required String title,
    required String? artist,
    required String? genre,
    required String ytID,
    required LocalVideoMatchingType matchingType,
    required String? onlyInDirectory,
  }) {
    final matched = <String>{};

    void matchFilename() => matched.addAll(matchText(filenameWOExt));

    void matchTitleAndArtist() {
      if (title.isEmpty) return;
      final titleMatches = matchText(title);
      if (titleMatches.isEmpty) return;
      if (artist != null && artist.isNotEmpty) {
        matched.addAll(titleMatches.intersection(matchText(artist)));
      }
      // useful for [Nightcore - title]
      // track must contain Nightcore as the first Genre
      if (genre != null && genre.isNotEmpty) {
        matched.addAll(titleMatches.intersection(matchText(genre)));
      }
    }

    void matchYTID() {
      if (ytID.length != 11) return;
      final videosByYTID = _videosGroupedByYTID[ytID];
      if (videosByYTID != null) matched.addAll(videosByYTID);
    }

    switch (matchingType) {
      case LocalVideoMatchingType.auto:
        matchFilename();
        matchTitleAndArtist();
        matchYTID();
      case LocalVideoMatchingType.filename:
        matchFilename();
      case LocalVideoMatchingType.titleAndArtist:
        matchTitleAndArtist();
      case LocalVideoMatchingType.youtubeID:
        matchYTID();
    }

    if (onlyInDirectory != null) matched.retainWhere((vp) => vp.getDirectoryPath == onlyInDirectory);
    return matched;
  }
}

abstract class SearchMatcher {
  final Iterable<String> items;
  SearchMatcher.init(this.items, {String Function(String item)? transformer}) {
    _fillData(items, transformer: transformer);
  }

  final _tokenIndex = <String, Set<String>>{};

  void _fillData(Iterable<String> items, {required String Function(String item)? transformer}) {
    for (final p in items) {
      final tokens = tokenizeHaystack(transformer?.call(p) ?? p);
      for (final token in tokens) {
        final set = _tokenIndex[token] ??= {};
        set.add(p);
      }
    }
  }

  static final _wordRegex = RegExp(r"[\p{L}\p{M}\p{N}']+", unicode: true);

  static Set<String> tokenize(String text) => _tokenize(text, isHaystack: false);

  /// for texts that others are searched in, every cjk character is added alone too.
  static Set<String> tokenizeHaystack(String text) => _tokenize(text, isHaystack: true);

  static bool isContainedIn(Set<String> tokens, Set<String> haystackTokens) => tokens.isNotEmpty && haystackTokens.containsAll(tokens);

  static Set<String> _tokenize(String text, {required bool isHaystack}) {
    final tokens = <String>{};
    final cleaned = text.normalizeAccents.toLowerCase();
    for (final match in _wordRegex.allMatches(cleaned)) {
      var word = match[0]!;
      if (word.contains("'")) {
        word = word.replaceAll("'", '');
        if (word.isEmpty) continue;
      }
      if (_hasCJK(word)) {
        _addCJKAwareTokens(tokens, word, isHaystack);
      } else {
        tokens.add(word);
      }
    }
    return tokens;
  }

  static bool _isCJK(int codeUnit) => (codeUnit >= 0x3005 && codeUnit <= 0x9FFF) || (codeUnit >= 0xF900 && codeUnit <= 0xFAFF) || (codeUnit >= 0xFF66 && codeUnit <= 0xFF9F);

  static bool _hasCJK(String word) {
    for (int i = 0; i < word.length; i++) {
      if (_isCJK(word.codeUnitAt(i))) return true;
    }
    return false;
  }

  /// cjk has no spaces between words, so its runs are split into overlapping pairs.
  static void _addCJKAwareTokens(Set<String> tokens, String word, bool isHaystack) {
    final length = word.length;
    int start = 0;
    while (start < length) {
      final isCJK = _isCJK(word.codeUnitAt(start));
      int end = start + 1;
      while (end < length && _isCJK(word.codeUnitAt(end)) == isCJK) {
        end++;
      }
      if (!isCJK) {
        tokens.add(word.substring(start, end));
      } else {
        if (isHaystack || end - start == 1) {
          for (int i = start; i < end; i++) {
            tokens.add(word[i]);
          }
        }
        for (int i = start + 1; i < end; i++) {
          tokens.add(word.substring(i - 1, i + 1));
        }
      }
      start = end;
    }
  }

  Set<String> matchAllTokens(Iterable<String> tokens) {
    Set<String>? matched;
    for (final token in tokens) {
      final paths = _tokenIndex[token];
      if (paths == null) return {};
      matched = matched == null ? paths : matched.intersection(paths);
      if (matched.isEmpty) return matched;
    }
    return matched ?? {};
  }

  Set<String> matchText(String text) => matchAllTokens(tokenize(text));

  Set<String> matchBoth(String a, String b) => matchText(a).intersection(matchText(b));
}

class ReverseSearchMatcher<T> {
  final _entriesByAnchorToken = <String, List<(T, Set<String>)>>{};

  /// indexed by its longest token only, any haystack containing all of its tokens has that one too.
  void addItem(T item, String property) {
    final tokens = SearchMatcher.tokenize(property);
    if (tokens.isEmpty) return;
    var anchorToken = tokens.first;
    for (final token in tokens) {
      if (token.length > anchorToken.length) anchorToken = token;
    }
    final entries = _entriesByAnchorToken[anchorToken] ??= [];
    entries.add((item, tokens));
  }

  /// items whose tokens are all inside [haystackTokens], built by [SearchMatcher.tokenizeHaystack].
  List<T> matchContainedIn(Set<String> haystackTokens) {
    final matched = <T>[];
    for (final token in haystackTokens) {
      final entries = _entriesByAnchorToken[token];
      if (entries == null) continue;
      for (final (item, tokens) in entries) {
        if (haystackTokens.containsAll(tokens)) matched.add(item);
      }
    }
    return matched;
  }

  /// the [matchContainedIn] item passing [test] with the most tokens, ties keep the first.
  T? matchMostSpecific(Set<String> haystackTokens, bool Function(T item) test) {
    T? mostSpecific;
    int mostTokensCount = 0;
    for (final token in haystackTokens) {
      final entries = _entriesByAnchorToken[token];
      if (entries == null) continue;
      for (final (item, tokens) in entries) {
        final tokensCount = tokens.length;
        if (tokensCount <= mostTokensCount) continue;
        if (!haystackTokens.containsAll(tokens) || !test(item)) continue;
        mostSpecific = item;
        mostTokensCount = tokensCount;
      }
    }
    return mostSpecific;
  }
}
