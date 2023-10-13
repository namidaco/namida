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
  bool operator ==(other) {
    if (other is LyricsModel) {
      return lyrics == other.lyrics &&
          synced == other.synced &&
          isInCache == other.isInCache &&
          fromInternet == other.fromInternet &&
          isEmbedded == other.isEmbedded &&
          file == other.file;
    }
    return false;
  }

  @override
  int get hashCode => "$lyrics$synced$isInCache$fromInternet$isEmbedded$file".hashCode;
}
