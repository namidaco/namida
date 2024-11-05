import 'dart:io';

class LyricsModel {
  final String lyrics;
  final bool synced;
  final bool isInCache;
  final bool fromInternet;
  final bool isEmbedded;
  final File? file;

  const LyricsModel({
    required this.lyrics,
    required this.synced,
    required this.isInCache,
    required this.fromInternet,
    required this.isEmbedded,
    required this.file,
  });

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
