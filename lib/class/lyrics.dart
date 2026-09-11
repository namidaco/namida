import 'dart:io';

import 'package:namida/core/enums.dart';

class LyricsModel {
  final String lyrics;
  final bool synced;
  final bool isInCache;
  final bool fromInternet;
  final bool isEmbedded;
  final File? file;
  final LyricsProvider? provider;
  late final int? durationMS = _extractDurationMS();

  /// see [LrcFingerprint].
  late final String fingerprint = LrcFingerprint.of(lyrics);

  /// removes entries with the same [fingerprint], keeping the first occurrence.
  static void removeDuplicateLyrics(List<LyricsModel> list) {
    if (list.length < 2) return;
    final seen = <String>{};
    list.retainWhere((l) => seen.add(l.fingerprint));
  }

  LyricsModel({
    required this.lyrics,
    required this.synced,
    required this.isInCache,
    required this.fromInternet,
    required this.isEmbedded,
    required this.file,
    this.provider,
  });

  int? _extractDurationMS() {
    if (!synced) return null;

    final regex = RegExp(r'\[length:([\d:\.]+)\]');
    final match = regex.firstMatch(lyrics);

    if (match == null) return null;
    String? length = match.group(1);
    if (length == null) return null;
    return _convertToMilliseconds(length);
  }

  int _convertToMilliseconds(String length) {
    final parts = length.split(':');
    final minutes = int.parse(parts[0]);
    final secondsParts = parts[1].split('.');
    final seconds = int.parse(secondsParts[0]);

    // Handle fractional seconds properly
    int fractionalMs = 0;
    if (secondsParts.length > 1) {
      String fractional = secondsParts[1];

      // "213" (3 digits) = 213ms
      // "21" (2 digits/centiseconds) = 210ms
      // "2130" (4 digits) = 213ms
      // "213000" (6 digits/microseconds) = 213ms
      if (fractional.length <= 3) {
        fractional = fractional.padRight(3, '0');
        fractionalMs = int.parse(fractional);
      } else {
        fractionalMs = int.parse(fractional.substring(0, 3));
        // -- round up if 4th digit >= 5
        if (fractional.length > 3 && int.parse(fractional[3]) >= 5) {
          fractionalMs++;
        }
      }
    }

    return minutes * 60000 + seconds * 1000 + fractionalMs;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LyricsModel) return false;
    return other.lyrics == lyrics &&
        other.synced == synced &&
        other.isInCache == isInCache &&
        other.fromInternet == fromInternet &&
        other.isEmbedded == isEmbedded &&
        other.file == file;
  }

  @override
  int get hashCode {
    return lyrics.hashCode ^ synced.hashCode ^ isInCache.hashCode ^ fromInternet.hashCode ^ isEmbedded.hashCode ^ file.hashCode;
  }
}

/// Normalized lyrics content for duplicate detection, in a single pass without parsing.
///
/// Metadata tags (`[ti:..]`, `[ar:..]`, `[length:..]`..) are dropped, timestamps are reduced to
/// centiseconds so `[00:12.3]`, `[00:12.30]` and `[0:12.300]` are the same, spaces around
/// timestamps and lines are trimmed and empty lines are skipped.
/// Same text with a different sync is intentionally not a duplicate.
// by claude
class LrcFingerprint {
  static String of(String lyrics) {
    final buffer = StringBuffer();
    final length = lyrics.length;
    int lineStart = 0;
    for (int i = 0; i <= length; i++) {
      if (i == length || lyrics.codeUnitAt(i) == _kLF) {
        _writeLine(lyrics, lineStart, i, buffer);
        lineStart = i + 1;
      }
    }
    return buffer.toString();
  }

  static void _writeLine(String s, int start, int end, StringBuffer out) {
    while (start < end && _isSpace(s.codeUnitAt(start))) {
      start++;
    }
    while (end > start && _isSpace(s.codeUnitAt(end - 1))) {
      end--;
    }
    if (start >= end) return;

    bool wroteTimestamp = false;
    while (start < end && s.codeUnitAt(start) == _kOpenBracket) {
      final close = s.indexOf(']', start + 1);
      if (close < 0 || close >= end) break;
      final cs = _parseTimestampCS(s, start + 1, close);
      if (cs >= 0) {
        out.write('[');
        out.write(cs);
        out.write(']');
        wroteTimestamp = true;
      }
      start = close + 1;
      while (start < end && _isSpace(s.codeUnitAt(start))) {
        start++;
      }
    }

    if (start >= end) {
      // -- metadata-only lines are dropped, timestamp-only lines are kept as sync markers.
      if (wroteTimestamp) out.write('\n');
      return;
    }
    out.write(s.substring(start, end));
    out.write('\n');
  }

  /// centiseconds of a `mm:ss.xx` / `hh:mm:ss.xxx` timestamp, or -1 if [from]..[to] is not one.
  static int _parseTimestampCS(String s, int from, int to) {
    if (from >= to) return -1;
    int total = 0;
    int number = 0;
    int fraction = 0;
    int fractionDigits = -1;
    bool sawColon = false;
    for (int i = from; i < to; i++) {
      final c = s.codeUnitAt(i);
      if (c >= _k0 && c <= _k9) {
        final d = c - _k0;
        if (fractionDigits < 0) {
          number = number * 10 + d;
        } else if (fractionDigits < 3) {
          fraction = fraction * 10 + d;
          fractionDigits++;
        }
      } else if (c == _kColon) {
        if (fractionDigits >= 0) return -1;
        total = (total + number) * 60;
        number = 0;
        sawColon = true;
      } else if (c == _kDot || c == _kComma) {
        if (fractionDigits >= 0) return -1;
        fractionDigits = 0;
      } else {
        return -1;
      }
    }
    if (!sawColon) return -1;
    final seconds = total + number;
    final cs = switch (fractionDigits) {
      1 => fraction * 10,
      2 => fraction,
      3 => (fraction + 5) ~/ 10,
      _ => 0,
    };
    return seconds * 100 + cs;
  }

  static bool _isSpace(int c) => c == _kSpace || c == _kTab || c == _kCR;

  static const _kLF = 0x0A;
  static const _kCR = 0x0D;
  static const _kTab = 0x09;
  static const _kSpace = 0x20;
  static const _kOpenBracket = 0x5B;
  static const _kColon = 0x3A;
  static const _kDot = 0x2E;
  static const _kComma = 0x2C;
  static const _k0 = 0x30;
  static const _k9 = 0x39;
}
