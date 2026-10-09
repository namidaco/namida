// by claude
import 'dart:math';

import 'package:dart_extensions/dart_extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lrc/lrc.dart';

import 'bench_data.dart';

void main() {
  test('lyrics current line lookup', () async {
    final runner = BenchRunner('lyrics');
    final content = _buildEnhancedLrc(100, Random(5));
    final lrc = LrcParser.parse(content);
    final ui = lrc.forUiDisplay(1.0, durationDifferenceToInsertEmptyLine: const Duration(seconds: 1));
    final lines = ui.uiLyricsLines;
    final highlightTimestampsMap = ui.highlightTimestampsMap;
    final endMS = lines.last.timestamp.inMilliseconds + 5000;
    const positionsCount = 100000;
    final stepMS = (endMS + 1000) / positionsCount;
    final positions = List.generate(positionsCount, (i) => (i * stepMS).floor() - 1000, growable: false);

    runner.digest('parsed lines', lrc.lyrics.map((e) => '${e.timestamp.inMicroseconds}|${e.person}|${e.readableText}'));
    runner.digest('ui lines', lines.map((e) => '${e.timestamp.inMicroseconds}|${e.isBGLyrics}|${e.readableText}'));
    const repeats = 100;
    int parseRepeated() {
      int count = 0;
      for (int i = 0; i < repeats; i++) {
        final parsed = LrcParser.parse(content);
        count += parsed.lyrics.length;
      }
      return count;
    }

    int forUiDisplayRepeated() {
      int count = 0;
      for (int i = 0; i < repeats; i++) {
        final uiInfo = lrc.forUiDisplay(1.0, durationDifferenceToInsertEmptyLine: const Duration(seconds: 1));
        count += uiInfo.uiLyricsLines.length;
      }
      return count;
    }

    await runner.run('LrcParser.parse ${lrc.lyrics.length} lines x$repeats', parseRepeated, iterations: 15);
    await runner.run('forUiDisplay ${lrc.lyrics.length} lines x$repeats', forUiDisplayRepeated, iterations: 15);

    List<int> resolveOldParsedView() {
      final res = List.filled(positions.length, -1);
      for (int i = 0; i < positions.length; i++) {
        final durMS = positions[i];
        final lrcDur = lines.lastWhereEff((e) => e.timestamp <= Duration(milliseconds: durMS + 5) && !e.isBGLyrics);
        final newLineDuration = lrcDur?.timestamp;
        if (newLineDuration == null) continue;
        final newIndexPre = highlightTimestampsMap[newLineDuration]?.firstOrNull;
        if (newIndexPre == null) continue;
        res[i] = newIndexPre;
      }
      return res;
    }

    List<int> resolveOldSimpleLine() {
      final res = List.filled(positions.length, -1);
      int lastScanIndex = -1;
      for (int i = 0; i < positions.length; i++) {
        final position = Duration(milliseconds: positions[i] + 5);
        int idx = lastScanIndex;
        if (idx >= lines.length) idx = -1;
        if (idx >= 0 && lines[idx].timestamp > position) idx = -1;
        while (idx + 1 < lines.length && lines[idx + 1].timestamp <= position) {
          idx++;
        }
        lastScanIndex = idx;
        var lineIndex = idx;
        while (lineIndex >= 0 && lines[lineIndex].isBGLyrics) {
          lineIndex--;
        }
        if (lineIndex >= 0) {
          lineIndex = highlightTimestampsMap[lines[lineIndex].timestamp]?.firstOrNull ?? lineIndex;
        }
        res[i] = lineIndex;
      }
      return res;
    }

    runner.digest('old parsed view lookup', resolveOldParsedView().map((e) => '$e'));
    runner.digest('old simple line lookup', resolveOldSimpleLine().map((e) => '$e'));
    await runner.run('old parsed view lookup x$positionsCount', resolveOldParsedView, iterations: 7);
    await runner.run('old simple line lookup x$positionsCount', resolveOldSimpleLine, iterations: 15);

    List<int> resolveLineResolver() {
      final sourceResolver = ui.lineResolver;
      final resolver = LrcLineResolver(sourceResolver.startsMS, sourceResolver.lineIndices);
      final res = List.filled(positions.length, -1);
      for (int i = 0; i < positions.length; i++) {
        res[i] = resolver.indexAt(positions[i]);
      }
      return res;
    }

    runner.digest('LrcLineResolver lookup', resolveLineResolver().map((e) => '$e'));
    await runner.run('LrcLineResolver.indexAt x$positionsCount', resolveLineResolver, iterations: 15);
    runner.finish();
  }, timeout: Timeout.none);
}

String _buildEnhancedLrc(int linesCount, Random random) {
  const words = ['hold', 'on', 'to', 'the', 'night', 'we', 'are', 'falling', 'into', 'light', 'never', 'let', 'go', 'my', 'heart', 'sings'];
  final buffer = StringBuffer('[ti:Bench]\n[ar:Bench]\n[offset:0]\n\n');
  int timeMS = 5000;
  for (int i = 0; i < linesCount; i++) {
    final lineStartMS = timeMS;
    final wordsCount = 4 + random.nextInt(5);
    final lineStart = _lrcTime(lineStartMS);
    final lineBuffer = StringBuffer('[$lineStart]');
    for (int w = 0; w < wordsCount; w++) {
      final wordStart = _lrcTime(timeMS);
      final word = words[random.nextInt(words.length)];
      lineBuffer.write('<$wordStart>$word ');
      timeMS += 250 + random.nextInt(450);
    }
    final lineEnd = _lrcTime(timeMS);
    lineBuffer.write('<$lineEnd>');
    buffer.writeln(lineBuffer);
    if (random.nextDouble() < 0.05) {
      final bgStartMS = lineStartMS + 400;
      final bgStart = _lrcTime(bgStartMS);
      final bgMiddle = _lrcTime(bgStartMS + 600);
      final bgEnd = _lrcTime(bgStartMS + 1200);
      buffer.writeln('[bg:<$bgStart>ooh <$bgMiddle>yeah<$bgEnd>]');
    }
    if (random.nextDouble() < 0.05) buffer.writeln('[$lineStart]translated line $i');
    final isLongGap = random.nextDouble() < 0.1;
    timeMS += isLongGap ? 2500 + random.nextInt(4000) : 100 + random.nextInt(500);
  }
  return buffer.toString();
}

String _lrcTime(int ms) {
  final minutes = (ms ~/ 60000).toString().padLeft(2, '0');
  final seconds = (ms % 60000 ~/ 1000).toString().padLeft(2, '0');
  final millis = (ms % 1000).toString().padLeft(3, '0');
  return '$minutes:$seconds.$millis';
}
