class LRCSearchDetails {
  final String title, artist, album;
  final int durationMS;
  final bool isDurationModified;

  const LRCSearchDetails({
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMS,
    required this.isDurationModified,
  });
}
