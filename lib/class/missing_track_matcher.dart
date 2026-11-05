// by claude
import 'dart:math' as math;

import 'package:dart_extensions/dart_extensions.dart';

import 'package:namida/class/file_matcher.dart';
import 'package:namida/class/fuzzy_matcher.dart';
import 'package:namida/core/constants.dart';

/// existing files that could be a missing path after a move or a rename, built once for many [getSuggestions] calls.
/// paths from another platform work too.
class MissingTrackMatcher {
  final Map<String, MissingTrackFingerprint> _fingerprintsByPath;

  MissingTrackMatcher(Iterable<String> existingPaths, {Map<String, MissingTrackFingerprint> fingerprintsByPath = const {}}) : _fingerprintsByPath = fingerprintsByPath {
    for (final path in existingPaths) {
      final index = _paths.length;
      final filename = _filenameOf(path);
      final filenameWOExt = _withoutExtension(filename);
      final name = _NameWords.of(filenameWOExt);
      _paths.add(path);
      _wordsOfPath.add(name.words);
      _tokensOfPath.add(name.tokens);
      _indicesByFilename.addForce(filename, index);
      _indicesByFilenameWOExt.addForce(filenameWOExt, index);
      if (name.words.isNotEmpty) {
        final wordsKey = name.toWordsKey();
        _indicesByWordsKey.addForce(wordsKey, index);
      }
      for (final token in name.tokens) {
        _indicesByToken.addForce(token, index);
      }
      final fingerprint = fingerprintsByPath[path];
      if (fingerprint != null) _indicesByFingerprint.addForce(fingerprint, index);
    }
  }

  final _paths = <String>[];
  final _wordsOfPath = <Set<String>>[];
  final _tokensOfPath = <Set<String>>[];
  final _indicesByFilename = <String, List<int>>{};
  final _indicesByFilenameWOExt = <String, List<int>>{};
  final _indicesByWordsKey = <String, List<int>>{};
  final _indicesByToken = <String, List<int>>{};
  final _indicesByFingerprint = <MissingTrackFingerprint, List<int>>{};

  static const kMaxSuggestions = 8;
  static const _kMinSharedWords = 2;
  static const _kMinMostSharedWords = 3;
  static const _kMostSharedRatioNumerator = 3;
  static const _kMostSharedRatioDenominator = 4;

  /// words found in more files than this are too common to look for loose matches with.
  static const _kMaxFilesOfLooseMatchWord = 500;

  static const _kMinSimilarNameLength = 8;
  static const _kMaxSimilarNameDistanceRatio = 0.15;

  static final _pathSeparatorsRegex = RegExp(r'[\\/]');

  static MissingTrackFingerprint? fingerprintOf({required int size, required int durationMS}) {
    if (size <= 0 || durationMS <= 0) return null;
    return (size: size, durationMS: durationMS);
  }

  /// one lookup without indexing every file, only files that can match get indexed: the same name, a known same file,
  /// the longest word of the name or of its title and artist. when nothing matched, files sharing 2 words or a word found in few files.
  /// unlike [getSuggestions], files sharing 2 words found in many files aren't skipped for loose matches.
  static List<String> scanSuggestions(MissingTrackScanParams params) {
    final missingPath = params.missingPath;
    final missingFilename = _filenameOf(missingPath);
    final missingFilenameWOExt = _withoutExtension(missingFilename);
    final words = _NameWords.toWordsList(missingFilenameWOExt).toSet();
    final titleAndArtist = _getTitleAndArtistWords(missingFilenameWOExt);
    final longestWord = _longestOf(words);
    final longestCoreWord = titleAndArtist == null ? null : _longestOf(titleAndArtist.words);
    final sameFingerprintPaths = params.sameFingerprintPaths.toSet();

    final candidates = <String>[];
    final lowerNames = <({String path, String lowerName})>[];
    for (final path in params.existingPaths) {
      final filenameWOExt = _withoutExtension(_filenameOf(path));
      if (filenameWOExt == missingFilenameWOExt || sameFingerprintPaths.contains(path)) {
        candidates.add(path);
        continue;
      }
      final lowerName = _NameWords.toLowerName(filenameWOExt);
      lowerNames.add((path: path, lowerName: lowerName));
      final hasLongestWord = longestWord != null && lowerName.contains(longestWord);
      final hasLongestCoreWord = longestCoreWord != null && lowerName.contains(longestCoreWord);
      if (hasLongestWord || hasLongestCoreWord) candidates.add(path);
    }

    final fingerprint = params.fingerprint;
    final fingerprintsByPath = <String, MissingTrackFingerprint>{
      if (fingerprint != null) ...{missingPath: fingerprint, for (final path in sameFingerprintPaths) path: fingerprint},
    };
    final matcher = MissingTrackMatcher(candidates, fingerprintsByPath: fingerprintsByPath);
    final suggestions = matcher.getSuggestions(missingPath, includeLooseMatches: false);
    if (suggestions.isNotEmpty || words.isEmpty) return suggestions;

    final filesCountByWord = {for (final word in words) word: lowerNames.where((e) => e.lowerName.contains(word)).length};
    final rareWords = words.where((word) => filesCountByWord[word]! <= _kMaxFilesOfLooseMatchWord).toFixedList();
    bool canMatchLoosely(String lowerName) => rareWords.any(lowerName.contains) || words.where(lowerName.contains).length >= _kMinSharedWords;
    final looseCandidates = lowerNames.where((e) => canMatchLoosely(e.lowerName)).map((e) => e.path);
    final looseMatcher = MissingTrackMatcher(looseCandidates);
    return looseMatcher.getSuggestions(missingPath);
  }

  static String? _longestOf(Iterable<String> words) {
    String? longest;
    for (final word in words) {
      if (longest == null || word.length > longest.length) longest = word;
    }
    return longest;
  }

  List<String> getSuggestions(String missingPath, {int limit = kMaxSuggestions, bool includeLooseMatches = true}) {
    final tierByIndex = <int, _MatchTier>{};
    void addMatches(Iterable<int>? indices, _MatchTier tier) {
      if (indices == null) return;
      for (final index in indices) {
        tierByIndex.putIfAbsent(index, () => tier);
      }
    }

    final filename = _filenameOf(missingPath);
    final filenameWOExt = _withoutExtension(filename);
    final name = _NameWords.of(filenameWOExt);
    final words = name.words;
    String? titlePhrase;

    final fingerprint = _fingerprintsByPath[missingPath];
    if (fingerprint != null) {
      final sameFileIndices = _indicesByFingerprint[fingerprint];
      addMatches(sameFileIndices, _MatchTier.sameFile);
    }
    final sameFilenameIndices = _indicesByFilename[filename];
    addMatches(sameFilenameIndices, _MatchTier.sameFilename);
    final sameFilenameWOExtIndices = _indicesByFilenameWOExt[filenameWOExt];
    addMatches(sameFilenameWOExtIndices, _MatchTier.sameFilenameOtherExtension);
    if (words.isNotEmpty) {
      final wordsKey = name.toWordsKey();
      final sameWordsIndices = _indicesByWordsKey[wordsKey];
      addMatches(sameWordsIndices, _MatchTier.sameWords);
      final containingWordsIndices = _indicesContainingAll(words);
      addMatches(containingWordsIndices, _MatchTier.containsAllWords);
      if (!name.hasChunksSameAsWords) {
        final containingChunksIndices = _indicesContainingAll(name.chunks);
        addMatches(containingChunksIndices, _MatchTier.containsAllWords);
      }
      final titleAndArtist = _getTitleAndArtistWords(filenameWOExt);
      if (titleAndArtist != null) {
        titlePhrase = titleAndArtist.titlePhrase;
        final coreWords = titleAndArtist.words;
        final hasOtherCoreWords = coreWords.length != words.length || !words.containsAll(coreWords);
        if (hasOtherCoreWords) {
          final indices = _indicesContainingAll(coreWords);
          final matchingIndices = titleAndArtist.hasArtist ? indices : indices.where(_hasNoArtistPart);
          addMatches(matchingIndices, _MatchTier.containsTitleAndArtist);
        }
      }
      if (tierByIndex.isEmpty && includeLooseMatches) _addLooseMatches(filenameWOExt, words, tierByIndex);
    }

    if (tierByIndex.isEmpty) return const [];

    final missingParentsLower = _parentsLowerOf(missingPath);
    final missingExtensionLower = filename.substring(filenameWOExt.length).toLowerCase();
    final ranked = tierByIndex.entries.map((e) {
      final index = e.key;
      final tier = e.value;
      final path = _paths[index];
      final candidateWords = _wordsOfPath[index];
      final sharedWordsCount = candidateWords.where(words.contains).length;
      final hasTitlePhrase = titlePhrase != null && tier.isWordsMatch && _hasPhrase(index, titlePhrase);
      final parentsLower = _parentsLowerOf(path);
      final commonParentsCount = _countCommonParents(missingParentsLower, parentsLower);
      final isSameExtension = path.toLowerCase().endsWith(missingExtensionLower);
      return (
        index: index,
        isWordsMatch: tier.isWordsMatch ? 1 : 0,
        tier: tier.index,
        commonParentsCount: commonParentsCount,
        hasTitlePhrase: hasTitlePhrase ? 0 : 1,
        sharedWordsCount: sharedWordsCount,
        allWordsCount: words.length + candidateWords.length - sharedWordsCount,
        isOtherExtension: isSameExtension ? 0 : 1,
      );
    }).toFixedList();
    ranked.sort((a, b) {
      final byKind = a.isWordsMatch.compareTo(b.isWordsMatch);
      if (byKind != 0) return byKind;
      final byTier = a.tier.compareTo(b.tier);
      final byParents = b.commonParentsCount.compareTo(a.commonParentsCount);
      if (a.isWordsMatch == 1) {
        // -- a renamed file usually stays in its folder
        if (byParents != 0) return byParents;
        final byTitlePhrase = a.hasTitlePhrase.compareTo(b.hasTitlePhrase);
        if (byTitlePhrase != 0) return byTitlePhrase;
        if (byTier != 0) return byTier;
      } else {
        if (byTier != 0) return byTier;
        if (byParents != 0) return byParents;
      }
      final bySharedWordsRatio = (b.sharedWordsCount * a.allWordsCount).compareTo(a.sharedWordsCount * b.allWordsCount);
      if (bySharedWordsRatio != 0) return bySharedWordsRatio;
      final byExtension = a.isOtherExtension.compareTo(b.isOtherExtension);
      if (byExtension != 0) return byExtension;
      return _paths[a.index].compareTo(_paths[b.index]);
    });
    return ranked.take(limit).map((e) => _paths[e.index]).toFixedList();
  }

  Iterable<int> _indicesContainingAll(Set<String> tokens) {
    List<int>? rarestIndices;
    for (final token in tokens) {
      final indices = _indicesByToken[token];
      if (indices == null) return const [];
      if (rarestIndices == null || indices.length < rarestIndices.length) rarestIndices = indices;
    }
    if (rarestIndices == null) return const [];
    return rarestIndices.where((index) => _tokensOfPath[index].containsAll(tokens));
  }

  /// names that lost some words ([_MatchTier.wordsRemoved]) or share most of them ([_MatchTier.mostWordsShared]), then similar names.
  void _addLooseMatches(String filenameWOExt, Set<String> words, Map<int, _MatchTier> tierByIndex) {
    final numbers = _numbersOfName(filenameWOExt);
    final candidates = <int>{};
    for (final word in words) {
      final indices = _indicesByToken[word];
      if (indices == null || indices.length > _kMaxFilesOfLooseMatchWord) continue;
      candidates.addAll(indices);
    }
    for (final index in candidates) {
      final candidateWords = _wordsOfPath[index];
      final sharedCount = candidateWords.where(words.contains).length;
      final isWordsRemoved = sharedCount == candidateWords.length && sharedCount >= _kMinSharedWords && sharedCount * 2 >= words.length;
      if (isWordsRemoved) {
        tierByIndex[index] = _MatchTier.wordsRemoved;
        continue;
      }
      final maxWordsCount = math.max(words.length, candidateWords.length);
      final isMostShared = sharedCount >= _kMinMostSharedWords && sharedCount * _kMostSharedRatioDenominator >= maxWordsCount * _kMostSharedRatioNumerator;
      if (isMostShared && _isSameNumbers(numbers, index)) tierByIndex[index] = _MatchTier.mostWordsShared;
    }
    if (tierByIndex.isEmpty) _addSimilarNameMatches(filenameWOExt, numbers, candidates, tierByIndex);
  }

  final _similarNameTextOfPath = <int, String>{};

  String _getSimilarNameText(int index) {
    final cached = _similarNameTextOfPath[index];
    if (cached != null) return cached;
    final filenameWOExt = _withoutExtension(_filenameOf(_paths[index]));
    return _similarNameTextOfPath[index] = _toSimilarNameText(filenameWOExt);
  }

  /// words with numbers written without leading zeros, read before normalizing since that turns `0` into `o`.
  static String _toSimilarNameText(String filenameWOExt) {
    final rawWords = _NameWords.toRawWordsList(filenameWOExt);
    return rawWords.map(_toSimilarNameWord).join(' ');
  }

  static String _toSimilarNameWord(String rawWord) {
    if (_digitsRegex.hasMatch(rawWord)) return _withoutLeadingZeros(rawWord);
    return rawWord.normalizeAccents.toLowerCase();
  }

  /// names that differ by a few letters, like a typo fix or a plural. numbers have to stay the same, `part 1` isn't `part 2`.
  void _addSimilarNameMatches(String filenameWOExt, Set<String> numbers, Set<int> candidates, Map<int, _MatchTier> tierByIndex) {
    final missingText = _toSimilarNameText(filenameWOExt);
    final missingLength = missingText.length;
    if (missingLength < _kMinSimilarNameLength) return;
    final fuzzy = FuzzyMatcher(missingText);
    for (final index in candidates) {
      final candidateText = _getSimilarNameText(index);
      final candidateLength = candidateText.length;
      final longerLength = math.max(missingLength, candidateLength);
      final maxDistance = (longerLength * _kMaxSimilarNameDistanceRatio).round();
      if (maxDistance < 1 || (missingLength - candidateLength).abs() > maxDistance) continue;
      final distance = fuzzy.distanceTo(candidateText, candidateLength, maxDistance);
      if (distance > maxDistance) continue;
      if (!_isSameNumbers(numbers, index)) continue;
      tierByIndex[index] = _MatchTier.similarName;
    }
  }

  static final _digitsRegex = RegExp(r'^\d+$');
  static final _leadingZerosRegex = RegExp(r'^0+(?=\d)');

  static String _withoutLeadingZeros(String word) => word.replaceFirst(_leadingZerosRegex, '');

  /// `track 01` and `track 1` have the same numbers.
  static Set<String> _numbersOfName(String filenameWOExt) {
    final rawWords = _NameWords.toRawWordsList(filenameWOExt);
    return rawWords.where(_digitsRegex.hasMatch).map(_withoutLeadingZeros).toSet();
  }

  final _numbersOfPath = <int, Set<String>>{};

  Set<String> _getNumbers(int index) {
    final cached = _numbersOfPath[index];
    if (cached != null) return cached;
    final filenameWOExt = _withoutExtension(_filenameOf(_paths[index]));
    return _numbersOfPath[index] = _numbersOfName(filenameWOExt);
  }

  bool _isSameNumbers(Set<String> numbers, int index) {
    final candidateNumbers = _getNumbers(index);
    return candidateNumbers.length == numbers.length && candidateNumbers.containsAll(numbers);
  }

  bool _hasNoArtistPart(int index) {
    final filenameWOExt = _withoutExtension(_filenameOf(_paths[index]));
    final (_, artist) = FileMatcher.getTitleAndArtistFromFilename(filenameWOExt);
    return artist == UnknownTags.ARTIST;
  }

  bool _hasPhrase(int index, String phrase) {
    final filenameWOExt = _withoutExtension(_filenameOf(_paths[index]));
    final wordsList = _NameWords.toWordsList(filenameWOExt);
    return _NameWords.toPhrase(wordsList).contains(phrase);
  }

  /// null when the name has no title words.
  static ({Set<String> words, String titlePhrase, bool hasArtist})? _getTitleAndArtistWords(String filenameWOExt) {
    final (title, artist) = FileMatcher.getTitleAndArtistFromFilename(filenameWOExt);
    final titleFragment = title.splitFirst('(');
    final titleWords = _NameWords.toWordsList(titleFragment);
    if (titleWords.isEmpty) return null;
    final hasArtist = artist != UnknownTags.ARTIST;
    final words = {...titleWords, if (hasArtist) ..._NameWords.toWordsList(artist)};
    final titlePhrase = _NameWords.toPhrase(titleWords);
    return (words: words, titlePhrase: titlePhrase, hasArtist: hasArtist);
  }

  static List<String> _parentsLowerOf(String path) {
    final segments = path.toLowerCase().split(_pathSeparatorsRegex);
    segments.removeLast();
    return segments;
  }

  /// same folders from the root (moves inside one library) plus from the end (another root or platform).
  static int _countCommonParents(List<String> missingParentsLower, List<String> parentsLower) {
    final maxCount = math.min(missingParentsLower.length, parentsLower.length);
    int fromRootCount = 0;
    while (fromRootCount < maxCount && missingParentsLower[fromRootCount] == parentsLower[fromRootCount]) {
      fromRootCount++;
    }
    final maxFromEndCount = maxCount - fromRootCount;
    final missingLastIndex = missingParentsLower.length - 1;
    final lastIndex = parentsLower.length - 1;
    int fromEndCount = 0;
    while (fromEndCount < maxFromEndCount && missingParentsLower[missingLastIndex - fromEndCount] == parentsLower[lastIndex - fromEndCount]) {
      fromEndCount++;
    }
    return fromRootCount + fromEndCount;
  }

  /// splits at both separators, a missing path can come from another platform.
  static String _filenameOf(String path) {
    final lastSeparator = math.max(path.lastIndexOf('/'), path.lastIndexOf(r'\'));
    return path.substring(lastSeparator + 1);
  }

  static String _withoutExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex <= 0 ? filename : filename.substring(0, dotIndex);
  }
}

/// best first.
enum _MatchTier {
  sameFile(isWordsMatch: false),
  sameFilename(isWordsMatch: false),
  sameFilenameOtherExtension(isWordsMatch: false),
  sameWords(isWordsMatch: true),
  containsAllWords(isWordsMatch: true),
  containsTitleAndArtist(isWordsMatch: true),
  wordsRemoved(isWordsMatch: true),
  mostWordsShared(isWordsMatch: true),
  similarName(isWordsMatch: true),
  ;

  final bool isWordsMatch;
  const _MatchTier({required this.isWordsMatch});
}

class _NameWords {
  /// split at every symbol and space, `a-b c` => `[a, b, c]`.
  final Set<String> words;

  /// split at spaces only with the symbols dropped, `a-b c` => `[ab, c]`.
  final Set<String> chunks;

  /// [words] and [chunks] together.
  final Set<String> tokens;

  const _NameWords._(this.words, this.chunks, this.tokens);

  static final _nonWordCharsRegex = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static final _whitespacesRegex = RegExp(r'\s+');

  static String toLowerName(String name) => name.normalizeAccents.toLowerCase();

  /// lowercased without normalizing, which changes digits too.
  static List<String> toRawWordsList(String name) {
    final lowerName = name.toLowerCase();
    return lowerName.split(_nonWordCharsRegex).where((e) => e.isNotEmpty).toFixedList();
  }

  static List<String> toWordsList(String name) {
    final lowerName = toLowerName(name);
    return lowerName.split(_nonWordCharsRegex).where((e) => e.isNotEmpty).toFixedList();
  }

  /// ` a b c `, to find phrases of whole words only.
  static String toPhrase(List<String> wordsList) => ' ${wordsList.join(' ')} ';

  factory _NameWords.of(String name) {
    final lowerName = toLowerName(name);
    final words = lowerName.split(_nonWordCharsRegex).where((e) => e.isNotEmpty).toSet();
    final chunks = lowerName.split(_whitespacesRegex).map((e) => e.replaceAll(_nonWordCharsRegex, '')).where((e) => e.isNotEmpty).toSet();
    final isSameAsWords = chunks.length == words.length && words.containsAll(chunks);
    final tokens = isSameAsWords ? words : {...words, ...chunks};
    return _NameWords._(words, chunks, tokens);
  }

  bool get hasChunksSameAsWords => identical(tokens, words);

  String toWordsKey() {
    final sortedWords = words.toList()..sort();
    return sortedWords.join(' ');
  }
}

typedef MissingTrackFingerprint = ({int size, int durationMS});

typedef MissingTrackScanParams = ({String missingPath, Set<String> existingPaths, MissingTrackFingerprint? fingerprint, List<String> sameFingerprintPaths});
