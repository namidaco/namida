// by claude
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/ui/widgets/simple_lyrics_line.dart';

void main() {
  const shortLength = 12;
  const longLength = 60;
  const lengthKinds = [shortLength, longLength];

  List<List<int>> lengthCombos(int count) {
    var combos = <List<int>>[[]];
    for (var i = 0; i < count; i++) {
      combos = [
        for (final combo in combos)
          for (final length in lengthKinds) [...combo, length],
      ];
    }
    return combos;
  }

  test('short translation and long romaji with a budget of 3', () {
    final linesCounts = SimpleLyricsLineWidget.splitSecondaryLinesBudget(3, [shortLength, longLength]);
    expect(linesCounts, [1, 2]);
  });

  test('no secondary lines', () {
    final linesCounts = SimpleLyricsLineWidget.splitSecondaryLinesBudget(4, []);
    expect(linesCounts, isEmpty);
  });

  for (var budget = 0; budget <= 5; budget++) {
    for (var count = 1; count <= 3; count++) {
      for (final textLengths in lengthCombos(count)) {
        test('budget $budget, lengths $textLengths', () {
          final linesCounts = SimpleLyricsLineWidget.splitSecondaryLinesBudget(budget, textLengths);
          expect(linesCounts, hasLength(count));
          final isEveryLineShown = linesCounts.every((e) => e >= 1);
          expect(isEveryLineShown, isTrue);

          final linesSum = linesCounts.fold(0, (a, b) => a + b);
          final expectedSum = math.max(budget, count);
          expect(linesSum, expectedSum);

          for (var i = 0; i < count; i++) {
            for (var j = 0; j < count; j++) {
              if (textLengths[i] > textLengths[j]) expect(linesCounts[i], greaterThanOrEqualTo(linesCounts[j]));
              if (textLengths[i] != textLengths[j]) continue;
              final linesDifference = (linesCounts[i] - linesCounts[j]).abs();
              expect(linesDifference, lessThanOrEqualTo(1));
            }
          }

          final hasLongText = textLengths.contains(longLength);
          if (hasLongText) {
            for (var i = 0; i < count; i++) {
              if (textLengths[i] == shortLength) expect(linesCounts[i], 1);
            }
          }
        });
      }
    }
  }
}
