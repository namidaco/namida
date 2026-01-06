import 'dart:io';

class LyricsModel {
  final String lyrics;
  final bool synced;
  final bool isInCache;
  final bool fromInternet;
  final bool isEmbedded;
  final File? file;
  late final int? durationMS = _extractDurationMS();

  LyricsModel({
    required this.lyrics,
    required this.synced,
    required this.isInCache,
    required this.fromInternet,
    required this.isEmbedded,
    required this.file,
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
  bool operator ==(covariant LyricsModel other) {
    if (identical(this, other)) return true;
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
