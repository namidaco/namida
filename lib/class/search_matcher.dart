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

  final _videosWordsTexts = <String, String>{};

  String _getVideoWordsText(String videoPath) => _videosWordsTexts[videoPath] ??= _PhrasesQuery.toWordsText(videoPath.getFilenameWOExt);

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

    void addPhrasesMatches(Set<String> candidates, List<String> texts) {
      if (candidates.isEmpty) return;
      final query = _PhrasesQuery.fromTexts(texts);
      final phrasesMatches = candidates.where((vp) => query.isContainedIn(_getVideoWordsText(vp)));
      matched.addAll(phrasesMatches);
    }

    void matchFilename() {
      final filenameMatches = matchText(filenameWOExt);
      addPhrasesMatches(filenameMatches, [filenameWOExt]);
    }

    void matchTitleAndArtist() {
      if (title.isEmpty) return;
      final titleMatches = matchText(title);
      if (titleMatches.isEmpty) return;
      if (artist != null && artist.isNotEmpty) {
        final artistMatches = titleMatches.intersection(matchText(artist));
        addPhrasesMatches(artistMatches, [title, artist]);
      }
      // useful for [Nightcore - title]
      // track must contain Nightcore as the first Genre
      if (genre != null && genre.isNotEmpty) {
        final genreMatches = titleMatches.intersection(matchText(genre));
        addPhrasesMatches(genreMatches, [title, genre]);
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

  static final _trailingBracketsRegex = RegExp(r'\s*[\(\[\{][^\(\)\[\]\{\}]*[\)\]\}]\s*$');

  /// videos that surely belong to the track: the name is the track's filename (bracket parts like `(480p)` can follow), or it has the track's youtube id.
  static Set<String> getSureTrackVideos({required Iterable<String> videoPaths, required String trackFilenameWOExt, required String trackYTID}) {
    final hasYTID = trackYTID.length == 11;
    final trackWordsText = _PhrasesQuery.toWordsText(trackFilenameWOExt);

    bool isSureTrackVideo(String videoPath) {
      var videoName = videoPath.getFilenameWOExt;
      if (hasYTID) {
        final ytIDMatches = _ytIDCandidateRegex.allMatches(videoName);
        if (ytIDMatches.any((m) => m[1] == trackYTID)) return true;
      }
      while (true) {
        final videoWordsText = _PhrasesQuery.toWordsText(videoName);
        if (videoWordsText == trackWordsText) return true;
        final trailingBrackets = _trailingBracketsRegex.firstMatch(videoName);
        if (trailingBrackets == null) return false;
        videoName = videoName.substring(0, trailingBrackets.start);
      }
    }

    return videoPaths.where(isSureTrackVideo).toSet();
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

// by claude
/// texts split at symbols into phrases. a name contains the query when every phrase is in it as consecutive words, in any order and without sharing words.
class _PhrasesQuery {
  final List<_Phrase> _phrases;
  const _PhrasesQuery._(this._phrases);

  static const _kUsedMark = '|';

  factory _PhrasesQuery.fromTexts(List<String> texts) {
    final phrases = <_Phrase>[];
    final phraseBuffer = StringBuffer();

    void addPhrase() {
      if (phraseBuffer.isEmpty) return;
      final words = phraseBuffer.toString();
      phraseBuffer.clear();
      final startCodeUnit = words.codeUnitAt(0);
      final endCodeUnit = words.codeUnitAt(words.length - 1);
      // -- cjk has no spaces between words, so a cjk edge can sit inside a longer run
      final isStartCJK = SearchMatcher._isCJK(startCodeUnit);
      final isEndCJK = SearchMatcher._isCJK(endCodeUnit);
      final startPad = isStartCJK ? '' : ' ';
      final endPad = isEndCJK ? '' : ' ';
      phrases.add((text: '$startPad$words$endPad', usedMark: '$startPad$_kUsedMark$endPad'));
    }

    for (final text in texts) {
      _loopWords(text, (word, isAfterSymbol) {
        if (isAfterSymbol) addPhrase();
        if (phraseBuffer.isNotEmpty) phraseBuffer.write(' ');
        _writeWord(phraseBuffer, word);
      });
      addPhrase();
    }
    // -- longest first, so a short phrase can't take the words of a longer one containing it
    phrases.sortByReverse((e) => e.text.length);
    return _PhrasesQuery._(phrases);
  }

  bool isContainedIn(String wordsText) {
    var unusedWordsText = wordsText;
    for (final phrase in _phrases) {
      final index = unusedWordsText.indexOf(phrase.text);
      if (index == -1) return false;
      final endIndex = index + phrase.text.length;
      unusedWordsText = unusedWordsText.replaceRange(index, endIndex, phrase.usedMark);
    }
    return true;
  }

  /// words of [text] separated by single spaces with a space on both ends, cjk is split from other scripts too.
  static String toWordsText(String text) {
    final buffer = StringBuffer(' ');
    _loopWords(text, (word, _) {
      _writeWord(buffer, word);
      buffer.write(' ');
    });
    return buffer.toString();
  }

  static void _loopWords(String text, void Function(String word, bool isAfterSymbol) onWord) {
    final cleaned = text.normalizeAccents.toLowerCase();
    int previousEnd = 0;
    bool isAfterSymbol = false;
    for (final match in SearchMatcher._wordRegex.allMatches(cleaned)) {
      final gap = cleaned.substring(previousEnd, match.start);
      previousEnd = match.end;
      if (gap.trim().isNotEmpty) isAfterSymbol = true;
      var word = match[0]!;
      if (word.contains("'")) {
        word = word.replaceAll("'", '');
        if (word.isEmpty) continue;
      }
      onWord(word, isAfterSymbol);
      isAfterSymbol = false;
    }
  }

  static void _writeWord(StringBuffer buffer, String word) {
    if (!SearchMatcher._hasCJK(word)) return buffer.write(word);
    bool? wasCJK;
    for (int i = 0; i < word.length; i++) {
      final codeUnit = word.codeUnitAt(i);
      final isCJK = SearchMatcher._isCJK(codeUnit);
      if (wasCJK != null && isCJK != wasCJK) buffer.write(' ');
      buffer.writeCharCode(codeUnit);
      wasCJK = isCJK;
    }
  }
}

typedef _Phrase = ({String text, String usedMark});
