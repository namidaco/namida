// by claude
part of 'tracks_search_wrapper.dart';

class KeysSearchWrapper<T> {
  final List<T> _items;
  final List<_SearchKey> _keys;
  final String Function(String) _textCleanedForSearch;
  final String Function(String)? _textCleanedMinorForSearch;

  KeysSearchWrapper._(
    this._items,
    this._keys,
    this._textCleanedForSearch,
    this._textCleanedMinorForSearch,
  );

  factory KeysSearchWrapper.init(
    List<T> items, {
    required String? Function(T item) title,
    String? Function(T item)? subtitle,
    List<String>? Function(T item)? extras,
    KeysSearchWeights? weights,
    required bool cleanup,
  }) {
    final textCleanedForSearch = TracksSearchWrapper._functionOfCleanup(cleanup);
    final textCleanedMinorForSearch = cleanup ? TracksSearchWrapper._functionOfCleanup(false) : null;

    _Property? propertyOf(String? text, {bool tryCutBeforeBrackets = false}) {
      if (text == null || text.isEmpty) return null;
      return TracksSearchWrapper._splitTextCleanedAndCleanedMinor(
        text,
        textCleanedForSearch,
        textCleanedMinorForSearch,
        tryCutBeforeBrackets: tryCutBeforeBrackets,
      );
    }

    _SearchKey keyOf(T item, int listensMultiplier) {
      final titleText = title(item);
      final subtitleText = subtitle?.call(item);
      final extrasTexts = extras?.call(item);
      final extrasProperties = extrasTexts?.map(propertyOf).nonNulls.toFixedList();
      return _SearchKey(
        title: propertyOf(titleText, tryCutBeforeBrackets: true),
        subtitle: propertyOf(subtitleText),
        extras: extrasProperties,
        listensMultiplier: listensMultiplier,
      );
    }

    final listensCounts = weights?.listensCounts;
    final itemsOrder = weights == null ? null : _orderByWeights(weights);

    final orderedItems = <T>[];
    final keys = <_SearchKey>[];
    for (int i = 0; i < items.length; i++) {
      final itemIndex = itemsOrder == null ? i : itemsOrder[i];
      final item = items[itemIndex];
      final listensCount = listensCounts?[itemIndex];
      final listensMultiplier = TracksSearchWrapper._listensMultiplierOf(listensCount, _kListensBoost);
      orderedItems.add(item);
      keys.add(keyOf(item, listensMultiplier));
    }

    return KeysSearchWrapper._(
      orderedItems,
      keys,
      textCleanedForSearch,
      textCleanedMinorForSearch,
    );
  }

  static const _kListensBoost = 1;

  static KeysSearchWeights createWeights<E>(List<E> groups, {required int Function(E group) listensCount, required int Function(E group) tracksCount}) {
    final listensCounts = Uint32List(groups.length);
    final tracksCounts = Uint32List(groups.length);
    for (int i = 0; i < groups.length; i++) {
      final group = groups[i];
      listensCounts[i] = listensCount(group);
      tracksCounts[i] = tracksCount(group);
    }
    return (listensCounts: listensCounts, tracksCounts: tracksCounts);
  }

  static List<int> _orderByWeights(KeysSearchWeights weights) {
    final listensCounts = weights.listensCounts;
    final tracksCounts = weights.tracksCounts;
    final indices = List<int>.generate(listensCounts.length, (i) => i, growable: false);
    indices.sort((a, b) {
      final byListens = listensCounts[b].compareTo(listensCounts[a]);
      if (byListens != 0) return byListens;
      final byTracksCount = tracksCounts[b].compareTo(tracksCounts[a]);
      if (byTracksCount != 0) return byTracksCount;
      return a.compareTo(b);
    });
    return indices;
  }

  List<T> filter(String text) {
    final results = <T>[];
    _filter(text, results.add, results.add);
    return results;
  }

  KeysSearchRelevanceResults<T> filterRelevantFirst(String text) {
    final results = <T>[];
    final lessRelevant = <T>[];
    final bestScore = _filter(text, results.add, lessRelevant.add);
    final relevantCount = results.length;
    results.addAll(lessRelevant);
    return (results: results, relevantCount: relevantCount, bestScore: bestScore);
  }

  int _filter(String text, void Function(T item) onRelevantMatch, void Function(T item) onLessRelevantMatch) {
    final textTrimmed = text.trimAll();
    final queryProperty = TracksSearchWrapper._splitTextCleanedAndCleanedMinor(textTrimmed, _textCleanedForSearch, _textCleanedMinorForSearch);

    final calculator = _ScoreCalculator(
      matcher: const _StringMatcher(),
      query: queryProperty.cleaned,
      queryMinor: queryProperty.cleanedMinor,
    );

    final keys = _keys;
    final scored = <int, List<int>>{};
    int bestScore = 0;
    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      final score = calculator.calculateKey(key);
      if (score > 0) {
        if (score > bestScore) bestScore = score;
        final scoreKey = score * key.listensMultiplier;
        (scored[scoreKey] ??= []).add(i);
      }
    }

    final items = _items;
    final relevantMinScore = TracksSearchWrapper.relevantMinScoreOf(bestScore);
    final sortedKeys = scored.keys.toFixedList()..sort((a, b) => b.compareTo(a));
    for (final scoreKey in sortedKeys) {
      for (final i in scored[scoreKey]!) {
        final score = scoreKey ~/ keys[i].listensMultiplier;
        if (score >= relevantMinScore) {
          onRelevantMatch(items[i]);
        } else {
          onLessRelevantMatch(items[i]);
        }
      }
    }
    return bestScore;
  }
}

class _SearchKey {
  final _Property? title;
  final _Property? subtitle;
  final List<_Property>? extras;
  final int listensMultiplier;

  const _SearchKey({
    required this.title,
    required this.subtitle,
    required this.extras,
    required this.listensMultiplier,
  });
}

typedef KeysSearchWeights = ({List<int> listensCounts, List<int> tracksCounts});
typedef KeysSearchRelevanceResults<T> = ({List<T> results, int relevantCount, int bestScore});
