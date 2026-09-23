part of 'youtube_miniplayer.dart';

// rewritten by claude, new one builds lazily with O(1) chapter tracking, adds progress, a header, an all chapters sheet & a long press menu
class _StreamSegmentsRow extends StatefulWidget {
  final String videoId;
  final List<StreamSegment> segments;
  final int? videoDurationMS;

  const _StreamSegmentsRow({
    super.key,
    required this.videoId,
    required this.segments,
    required this.videoDurationMS,
  });

  @override
  State<_StreamSegmentsRow> createState() => _StreamSegmentsRowState();
}

class _StreamSegmentsRowState extends State<_StreamSegmentsRow> {
  static const _kListPadding = 8.0;
  static const _kUserScrollHoldMS = 4000;

  late final _controller = NamidaScrollController.create();
  late final _tracker = _ChaptersTracker(widget.segments);
  double _itemExtent = 0.0;
  int _lastUserScrollMS = 0;

  @override
  void initState() {
    super.initState();
    _tracker.currentIndex.addListener(_onCurrentIndexChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent(animate: false));
  }

  @override
  void didUpdateWidget(covariant _StreamSegmentsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.segments, widget.segments)) _tracker.updateSegments(widget.segments);
  }

  @override
  void dispose() {
    _tracker.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onCurrentIndexChange() {
    if (DateTime.now().millisecondsSinceEpoch - _lastUserScrollMS < _kUserScrollHoldMS) return;
    _scrollToCurrent(animate: true);
  }

  bool _onUserScroll(UserScrollNotification _) {
    _lastUserScrollMS = DateTime.now().millisecondsSinceEpoch;
    return false;
  }

  void _scrollToCurrent({required bool animate}) {
    final index = _tracker.currentIndex.value;
    if (index < 0 || !_controller.hasClients) return;
    final position = _controller.position;
    final offset = (_kListPadding + index * _itemExtent - (position.viewportDimension - _itemExtent) * 0.4).clampDouble(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (animate) {
      _controller.animateTo(offset, duration: const Duration(milliseconds: 200), curve: Curves.fastEaseInToSlowEaseOut);
    } else {
      _controller.jumpTo(offset);
    }
  }

  void _showAllChapters() {
    NamidaNavigator.inst.showSheet(
      isScrollControlled: true,
      heightPercentage: 0.7,
      builder: (context, bottomPadding, maxWidth, maxHeight) => _ChaptersSheet(
        videoId: widget.videoId,
        segments: widget.segments,
        videoDurationMS: widget.videoDurationMS,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbWidth = (context.width * 0.2).withMaximum(128.0);
    final thumbHeight = thumbWidth * 9 / 16;
    final titleHeight = _ChapterTile.titleHeightFor(MediaQuery.textScalerOf(context));
    _itemExtent = thumbWidth + _ChapterTile.horizontalInsets;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChaptersHeader(
          tracker: _tracker,
          onShowAll: _showAllChapters,
        ),
        const SizedBox(height: 4.0),
        SizedBox(
          height: thumbHeight + titleHeight + _ChapterTile.verticalInsets,
          child: NotificationListener<UserScrollNotification>(
            onNotification: _onUserScroll,
            child: SmoothCustomScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: _kListPadding),
                  sliver: SliverFixedExtentList.builder(
                    itemExtent: _itemExtent,
                    itemCount: _tracker.segments.length,
                    itemBuilder: (context, index) => _ChapterTile(
                      videoId: widget.videoId,
                      tracker: _tracker,
                      index: index,
                      videoDurationMS: widget.videoDurationMS,
                      thumbWidth: thumbWidth,
                      thumbHeight: thumbHeight,
                      titleHeight: titleHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4.0),
      ],
    );
  }
}

class _ChaptersTracker {
  static const _kUnboundedMS = 1 << 40;

  final currentIndex = (-1).obs;
  List<StreamSegment> _segments;
  List<int> _startsMS;
  int _rangeStartMS = 0;
  int _rangeEndMS = 0;

  _ChaptersTracker(List<StreamSegment> segments) : _segments = segments, _startsMS = _buildStartsMS(segments) {
    _resolve(Player.inst.nowPlayingPosition.value);
    Player.inst.nowPlayingPosition.addListener(_onPositionChange);
  }

  List<StreamSegment> get segments => _segments;

  void updateSegments(List<StreamSegment> segments) {
    _segments = segments;
    _startsMS = _buildStartsMS(segments);
    _resolve(Player.inst.nowPlayingPosition.value);
  }

  void dispose() {
    Player.inst.nowPlayingPosition.removeListener(_onPositionChange);
    currentIndex.close();
  }

  static List<int> _buildStartsMS(List<StreamSegment> segments) {
    return List<int>.generate(
      segments.length,
      (i) {
        final startSeconds = segments[i].startSeconds;
        return startSeconds == null ? -1 : startSeconds * 1000;
      },
      growable: false,
    );
  }

  int? startMSOf(int index) {
    final startMS = _startsMS[index];
    return startMS < 0 ? null : startMS;
  }

  int? endMSOf(int index, int? videoDurationMS) {
    final startsMS = _startsMS;
    for (int i = index + 1; i < startsMS.length; i++) {
      final startMS = startsMS[i];
      if (startMS >= 0) return startMS;
    }
    return videoDurationMS;
  }

  (int, int)? rangeMSOf(int index, int? videoDurationMS) {
    final startMS = startMSOf(index);
    final endMS = endMSOf(index, videoDurationMS);
    if (startMS == null || endMS == null || endMS <= startMS) return null;
    return (startMS, endMS);
  }

  static String lengthLabel((int, int) rangeMS) => ((rangeMS.$2 - rangeMS.$1) ~/ 1000).secondsLabel;

  YoutubeDownloadChapter? downloadChapterOf(int index) {
    final startMS = startMSOf(index);
    if (startMS == null) return null;
    return YoutubeDownloadChapter(
      startMS: startMS,
      endMS: endMSOf(index, null),
      title: _segments[index].title,
      number: index + 1,
      total: _segments.length,
    );
  }

  void seekTo(int index) {
    final startMS = startMSOf(index);
    if (startMS != null) Player.inst.seek(Duration(milliseconds: startMS + 1));
  }

  void _onPositionChange() {
    final positionMS = Player.inst.nowPlayingPosition.value;
    if (positionMS >= _rangeStartMS && positionMS < _rangeEndMS) return;
    _resolve(positionMS);
  }

  /// same bounds as `findByMillisecond`, a chapter counts from 1ms before its start.
  void _resolve(int positionMS) {
    final startsMS = _startsMS;
    int index = -1;
    for (int i = startsMS.length - 1; i >= 0; i--) {
      final startMS = startsMS[i];
      if (startMS >= 0 && positionMS + 1 >= startMS) {
        index = i;
        break;
      }
    }
    _rangeStartMS = index < 0 ? -_kUnboundedMS : startsMS[index] - 1;
    _rangeEndMS = (endMSOf(index, null) ?? _kUnboundedMS) - 1;
    currentIndex.value = index;
  }
}

class _ChaptersHeader extends StatelessWidget {
  final _ChaptersTracker tracker;
  final VoidCallback onShowAll;

  const _ChaptersHeader({
    required this.tracker,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final count = tracker.segments.length;
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 8.0),
      child: Row(
        children: [
          Expanded(
            child: ObxO(
              rx: tracker.currentIndex,
              builder: (context, currentIndex) => Text.rich(
                TextSpan(
                  text: lang.chapters,
                  children: [
                    TextSpan(
                      text: currentIndex < 0 ? '  •  $count' : '  •  ${currentIndex + 1}/$count',
                      style: textTheme.displaySmall,
                    ),
                  ],
                ),
                style: textTheme.displayMedium?.copyWith(fontSize: 13.0),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          NamidaIconButton(
            icon: Broken.row_vertical,
            iconSize: 18.0,
            horizontalPadding: 8.0,
            verticalPadding: 4.0,
            tooltip: () => lang.showAll,
            onPressed: onShowAll,
          ),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  static const _kThumbPadding = 1.0;
  static const _kMargin = 2.0;
  static const _kProgressHeight = 5.0;
  static const _kTitleBottomPadding = 3.0;
  static const _kTitleFontSize = 11.0;
  static const _kTitleLineHeight = 1.25;
  static const _kTitleStrut = StrutStyle(fontSize: _kTitleFontSize, height: _kTitleLineHeight, forceStrutHeight: true);

  static const horizontalInsets = (_kThumbPadding + _kMargin) * 2;
  static const verticalInsets = _kThumbPadding * 2 + _kProgressHeight + _kTitleBottomPadding;

  static double titleHeightFor(TextScaler textScaler) => (textScaler.scale(_kTitleFontSize) * _kTitleLineHeight * 2).ceilToDouble();

  final String videoId;
  final _ChaptersTracker tracker;
  final int index;
  final int? videoDurationMS;
  final double thumbWidth;
  final double thumbHeight;
  final double titleHeight;

  const _ChapterTile({
    required this.videoId,
    required this.tracker,
    required this.index,
    required this.videoDurationMS,
    required this.thumbWidth,
    required this.thumbHeight,
    required this.titleHeight,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: () => _chapterMenuItems(videoId, tracker, index),
      child: ObxOSelect(
        rx: tracker.currentIndex,
        selector: (currentIndex) => _ChapterStatus.of(index, currentIndex),
        builder: (context, status) {
          final theme = context.theme;
          final textTheme = theme.textTheme;
          final segment = tracker.segments[index];
          final url = segment.thumbnail?.url;
          final rangeMS = tracker.rangeMSOf(index, videoDurationMS);
          final isCurrent = status == _ChapterStatus.current;
          final isPlayed = status == _ChapterStatus.played;
          final titleStyle = textTheme.displaySmall?.copyWith(
            fontSize: _kTitleFontSize,
            fontWeight: FontWeight.w500,
            color: isPlayed ? textTheme.displaySmall?.color?.withOpacityExt(0.5) : null,
          );

          return NamidaInkWell(
            animationDurationMS: 200,
            borderRadius: 6.0,
            margin: const EdgeInsets.symmetric(horizontal: _kMargin),
            bgColor: isCurrent ? theme.colorScheme.secondaryContainer : theme.cardColor.withOpacityExt(0.4),
            onTap: () => tracker.seekTo(index),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(_kThumbPadding),
                  child: YoutubeThumbnail(
                    type: ThumbnailType.video,
                    key: Key('${videoId}_$url'),
                    borderRadius: 6.0,
                    isImportantInCache: false,
                    width: thumbWidth,
                    height: thumbHeight,
                    videoId: videoId,
                    preferLowerRes: true,
                    customUrl: url,
                    smallBoxText: rangeMS == null ? null : _ChaptersTracker.lengthLabel(rangeMS),
                    smallBoxIcon: isCurrent ? Broken.play : null,
                    forceSquared: true,
                    onTopWidgets: isPlayed ? (_) => const [_PlayedScrim()] : null,
                  ),
                ),
                SizedBox(
                  height: _kProgressHeight,
                  child: isCurrent && rangeMS != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.5),
                          child: _ChapterProgressBar(
                            rangeMS: rangeMS,
                          ),
                        )
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: _kTitleBottomPadding),
                  child: SizedBox(
                    height: titleHeight,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (segment.startSeconds case final startSeconds?)
                            TextSpan(
                              text: '${startSeconds.secondsLabel}  ',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          TextSpan(text: segment.title),
                        ],
                      ),
                      style: titleStyle,
                      strutStyle: _kTitleStrut,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChaptersSheet extends StatefulWidget {
  final String videoId;
  final List<StreamSegment> segments;
  final int? videoDurationMS;

  const _ChaptersSheet({
    required this.videoId,
    required this.segments,
    required this.videoDurationMS,
  });

  @override
  State<_ChaptersSheet> createState() => _ChaptersSheetState();
}

class _ChaptersSheetState extends State<_ChaptersSheet> {
  late final _controller = NamidaScrollController.create();
  late final _tracker = _ChaptersTracker(widget.segments);
  double _itemExtent = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  @override
  void dispose() {
    _tracker.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _jumpToCurrent() {
    final index = _tracker.currentIndex.value;
    if (index < 0 || !_controller.hasClients) return;
    final position = _controller.position;
    final offset = (index * _itemExtent - (position.viewportDimension - _itemExtent) * 0.3).clampDouble(position.minScrollExtent, position.maxScrollExtent);
    _controller.jumpTo(offset);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    _itemExtent = _ChapterSheetRow.extentFor(MediaQuery.textScalerOf(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 12.0),
          child: Text.rich(
            TextSpan(
              text: lang.chapters,
              children: [
                TextSpan(
                  text: '  •  ${widget.segments.length}',
                  style: textTheme.displayMedium,
                ),
              ],
            ),
            style: textTheme.displayLarge,
          ),
        ),
        Expanded(
          child: SmoothCustomScrollView(
            controller: _controller,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 4.0),
                sliver: SliverFixedExtentList.builder(
                  itemExtent: _itemExtent,
                  itemCount: widget.segments.length,
                  itemBuilder: (context, index) => _ChapterSheetRow(
                    videoId: widget.videoId,
                    tracker: _tracker,
                    index: index,
                    videoDurationMS: widget.videoDurationMS,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18.0, 8.0, 18.0, 12.0),
          child: SizedBox(
            width: double.infinity,
            child: NamidaButton(
              text: lang.done,
              minHeight: NamidaButton.kDefaultMinHeight * 1.2,
              onTap: Navigator.of(context).pop,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChapterSheetRow extends StatelessWidget {
  static const _kThumbWidth = 104.0;
  static const _kThumbHeight = _kThumbWidth * 9 / 16;
  static const _kMargin = EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0);
  static const _kPadding = 6.0;
  static const _kTitleFontSize = 13.0;
  static const _kSubtitleFontSize = 11.0;
  static const _kLineHeight = 1.25;
  static const _kTitleStrut = StrutStyle(fontSize: _kTitleFontSize, height: _kLineHeight, forceStrutHeight: true);
  static const _kSubtitleStrut = StrutStyle(fontSize: _kSubtitleFontSize, height: _kLineHeight, forceStrutHeight: true);
  static const _kSubtitleGap = 2.0;
  static const _kProgressGap = 6.0;
  static const _kProgressHeight = 3.0;

  static double extentFor(TextScaler textScaler) {
    final textBlockHeight =
        textScaler.scale(_kTitleFontSize) * _kLineHeight * 2 + _kSubtitleGap + textScaler.scale(_kSubtitleFontSize) * _kLineHeight + _kProgressGap + _kProgressHeight;
    return (textBlockHeight.withMinimum(_kThumbHeight) + _kPadding * 2 + _kMargin.vertical).ceilToDouble();
  }

  final String videoId;
  final _ChaptersTracker tracker;
  final int index;
  final int? videoDurationMS;

  const _ChapterSheetRow({
    required this.videoId,
    required this.tracker,
    required this.index,
    required this.videoDurationMS,
  });

  @override
  Widget build(BuildContext context) {
    List<NamidaPopupItem> menuItems() => _chapterMenuItems(videoId, tracker, index);
    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: menuItems,
      child: ObxOSelect(
        rx: tracker.currentIndex,
        selector: (currentIndex) => _ChapterStatus.of(index, currentIndex),
        builder: (context, status) {
          final theme = context.theme;
          final textTheme = theme.textTheme;
          final segment = tracker.segments[index];
          final url = segment.thumbnail?.url;
          final rangeMS = tracker.rangeMSOf(index, videoDurationMS);
          final isCurrent = status == _ChapterStatus.current;
          final isPlayed = status == _ChapterStatus.played;
          final startLabel = segment.startSeconds?.secondsLabel;

          return NamidaInkWell(
            animationDurationMS: 200,
            borderRadius: 10.0,
            margin: _kMargin,
            padding: const EdgeInsets.all(_kPadding),
            bgColor: isCurrent ? theme.colorScheme.secondaryContainer : null,
            onTap: () => tracker.seekTo(index),
            child: Row(
              children: [
                YoutubeThumbnail(
                  type: ThumbnailType.video,
                  key: Key('${videoId}_$url'),
                  borderRadius: 8.0,
                  isImportantInCache: false,
                  width: _kThumbWidth,
                  height: _kThumbHeight,
                  videoId: videoId,
                  preferLowerRes: true,
                  customUrl: url,
                  smallBoxText: rangeMS == null ? null : _ChaptersTracker.lengthLabel(rangeMS),
                  smallBoxIcon: isCurrent ? Broken.play : null,
                  forceSquared: true,
                  onTopWidgets: isPlayed ? (_) => const [_PlayedScrim()] : null,
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        segment.title,
                        style: textTheme.displayMedium?.copyWith(
                          fontSize: _kTitleFontSize,
                          color: isPlayed ? textTheme.displayMedium?.color?.withOpacityExt(0.5) : null,
                        ),
                        strutStyle: _kTitleStrut,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: _kSubtitleGap),
                      Text(
                        startLabel == null ? '${index + 1}' : '${index + 1}  •  $startLabel',
                        style: textTheme.displaySmall?.copyWith(fontSize: _kSubtitleFontSize),
                        strutStyle: _kSubtitleStrut,
                        maxLines: 1,
                      ),
                      const SizedBox(height: _kProgressGap),
                      SizedBox(
                        height: _kProgressHeight,
                        child: isCurrent && rangeMS != null
                            ? _ChapterProgressBar(
                                rangeMS: rangeMS,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4.0),
                NamidaPopupWrapper(
                  childrenDefault: menuItems,
                  child: const MoreIcon(
                    iconSize: 16.0,
                    padding: 6.0,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChapterProgressBar extends StatelessWidget {
  final (int, int) rangeMS;

  const _ChapterProgressBar({
    required this.rangeMS,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ChapterProgressPainter(
          startMS: rangeMS.$1,
          endMS: rangeMS.$2,
          trackColor: colorScheme.onSecondaryContainer.withOpacityExt(0.15),
          fillColor: colorScheme.primary,
        ),
      ),
    );
  }
}

class _ChapterProgressPainter extends CustomPainter {
  final int startMS;
  final int endMS;
  final Color trackColor;
  final Color fillColor;
  final Paint _trackPaint;
  final Paint _fillPaint;

  _ChapterProgressPainter({
    required this.startMS,
    required this.endMS,
    required this.trackColor,
    required this.fillColor,
  }) : _trackPaint = Paint()..color = trackColor,
       _fillPaint = Paint()..color = fillColor,
       super(repaint: Player.inst.nowPlayingPosition);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromLTRBR(0.0, 0.0, size.width, size.height, radius), _trackPaint);
    final fraction = ((Player.inst.nowPlayingPosition.value - startMS) / (endMS - startMS)).clampDouble(0.0, 1.0);
    if (fraction > 0.0) canvas.drawRRect(RRect.fromLTRBR(0.0, 0.0, size.width * fraction, size.height, radius), _fillPaint);
  }

  @override
  bool shouldRepaint(_ChapterProgressPainter oldDelegate) {
    return oldDelegate.startMS != startMS || oldDelegate.endMS != endMS || oldDelegate.trackColor != trackColor || oldDelegate.fillColor != fillColor;
  }
}

class _PlayedScrim extends StatelessWidget {
  const _PlayedScrim();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: context.theme.scaffoldBackgroundColor.withAlpha(110),
      ),
    );
  }
}

List<NamidaPopupItem> _chapterMenuItems(String videoId, _ChaptersTracker tracker, int index) {
  final startMS = tracker.startMSOf(index);
  final url = YTUrlUtils.buildVideoUrl(videoId, timestampSeconds: startMS == null ? null : startMS ~/ 1000);
  final downloadChapter = tracker.downloadChapterOf(index);
  return [
    NamidaPopupItem(
      icon: Broken.copy,
      title: lang.copy,
      subtitle: url,
      oneLinedSub: true,
      onTap: () => NamidaUtils.copyToClipboard(content: url),
    ),
    NamidaPopupItem(
      icon: Broken.import,
      title: lang.download,
      subtitle: tracker.segments[index].title,
      oneLinedSub: true,
      enabled: downloadChapter != null,
      onTap: () => showDownloadVideoBottomSheet(
        videoId: videoId,
        originalIndex: null,
        totalLength: null,
        playlistId: null,
        streamInfoItem: null,
        chapter: downloadChapter,
      ),
    ),
  ];
}

enum _ChapterStatus {
  played,
  current,
  upcoming;

  static _ChapterStatus of(int index, int currentIndex) {
    if (index < currentIndex) return played;
    if (index == currentIndex) return current;
    return upcoming;
  }
}
