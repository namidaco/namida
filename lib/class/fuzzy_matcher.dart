import 'dart:typed_data' show Uint32List, Uint64List;

/// Fuzzy matching of a fixed [query] against any number of properties.
///
/// A substitution costs `1 + `[_kSubstitutionExtraCost] which is dearer than a deletion plus an
/// insertion, so the distance is always a pure insert/delete one, ie. `queryLength +
/// propertyLength - 2 * lcsLength`. That lets a whole row be done in a few word operations over a
/// bitset of the query character positions, instead of a cell per character pair.
// by claude
class FuzzyMatcher {
  final String query;
  final int queryLength;

  /// null when [query] has more characters than a single word can hold, [_levenshteinDistance] is used then.
  final Uint64List? _asciiPositions;
  final Map<int, int>? _otherPositions;
  final int _queryPositionsMask;

  FuzzyMatcher._(this.query, this.queryLength, this._asciiPositions, this._otherPositions, this._queryPositionsMask);

  factory FuzzyMatcher(String query) {
    final queryLength = query.length;
    if (queryLength == 0 || queryLength > _kMaxBitsetLength) {
      return FuzzyMatcher._(query, queryLength, null, null, 0);
    }

    final asciiPositions = Uint64List(_kAsciiRange);
    Map<int, int>? otherPositions;
    for (int i = 0; i < queryLength; i++) {
      final codeUnit = query.codeUnitAt(i);
      if (codeUnit < _kAsciiRange) {
        asciiPositions[codeUnit] |= 1 << i;
      } else {
        otherPositions ??= {};
        otherPositions[codeUnit] = (otherPositions[codeUnit] ?? 0) | (1 << i);
      }
    }

    final queryPositionsMask = queryLength >= _kMaxBitsetLength ? -1 : (1 << queryLength) - 1;
    return FuzzyMatcher._(query, queryLength, asciiPositions, otherPositions, queryPositionsMask);
  }

  /// Returns [maxDistance] + 1 as soon as the distance is known to exceed it.
  int distanceTo(String property, int propertyLength, int maxDistance) {
    final asciiPositions = _asciiPositions;
    if (asciiPositions == null) return _levenshteinDistance(property, propertyLength, maxDistance);

    final otherPositions = _otherPositions;
    int bits = -1;
    for (int i = 0; i < propertyLength; i++) {
      final codeUnit = property.codeUnitAt(i);
      final positions = codeUnit < _kAsciiRange ? asciiPositions[codeUnit] : (otherPositions?[codeUnit] ?? 0);
      final matched = bits & positions;
      bits = (bits + matched) | (bits - matched);
    }

    final lcsLength = queryLength - _popCount(bits & _queryPositionsMask);
    return queryLength + propertyLength - 2 * lcsLength;
  }

  Uint32List _prevRow = Uint32List(_kInitialRowLength);
  Uint32List _currRow = Uint32List(_kInitialRowLength);

  int _levenshteinDistance(String property, int propertyLength, int maxDistance) {
    if (queryLength == 0) return propertyLength;
    if (propertyLength == 0) return queryLength;

    var prevRow = _prevRow;
    var currRow = _currRow;
    if (prevRow.length <= propertyLength) {
      prevRow = _prevRow = Uint32List(propertyLength + 1);
      currRow = _currRow = Uint32List(propertyLength + 1);
    }

    for (var k = 0; k <= propertyLength; k++) {
      prevRow[k] = k;
    }

    for (var i = 0; i < queryLength; i++) {
      currRow[0] = i + 1;
      final u1 = query.codeUnitAt(i);
      var rowMinimum = i + 1;
      for (var j = 0; j < propertyLength; j++) {
        final cost = u1 == property.codeUnitAt(j) ? 0 : 1 + _kSubstitutionExtraCost;
        var best = prevRow[j + 1] + 1;
        final insertion = currRow[j] + 1;
        if (insertion < best) best = insertion;
        final substitution = prevRow[j] + cost;
        if (substitution < best) best = substitution;
        currRow[j + 1] = best;
        if (best < rowMinimum) rowMinimum = best;
      }

      // -- every path to the end goes through this row and costs can only add up
      if (rowMinimum > maxDistance) break;

      final temp = prevRow;
      prevRow = currRow;
      currRow = temp;
      if (i == queryLength - 1) {
        _prevRow = prevRow;
        _currRow = currRow;
        return prevRow[propertyLength];
      }
    }

    _prevRow = prevRow;
    _currRow = currRow;
    return maxDistance + 1;
  }

  static int _popCount(int bits) {
    bits = bits - ((bits >>> 1) & 0x5555555555555555);
    bits = (bits & 0x3333333333333333) + ((bits >>> 2) & 0x3333333333333333);
    bits = (bits + (bits >>> 4)) & 0x0F0F0F0F0F0F0F0F;
    return (bits * 0x0101010101010101) >>> 56;
  }

  static const int _kAsciiRange = 128;
  static const int _kMaxBitsetLength = 64;
  static const int _kInitialRowLength = 64;
  static const int _kSubstitutionExtraCost = 4;
}
