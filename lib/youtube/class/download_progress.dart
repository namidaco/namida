class DownloadProgress {
  final int progress;
  final int totalProgress;

  const DownloadProgress({
    required this.progress,
    required this.totalProgress,
  });

  double get percentage => progress / totalProgress;

  String? percentageText({String? prefix}) {
    final p = percentage;
    if (p.isFinite) {
      final String res = (percentage * 100).toStringAsFixed(0);
      return prefix != null ? "$prefix $res%" : "$res%";
    }
    return null;
  }
}
