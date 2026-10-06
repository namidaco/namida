// by claude
import 'package:flutter/material.dart';

import 'package:namida/base/audio_handler.dart';
import 'package:namida/class/media_chapter.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/chapters_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/seekbar_chapters.dart';

void showChaptersSheet(Playable item) {
  final chapters = ChaptersController.inst.chaptersOf(item);
  if (chapters == null || chapters.isEmpty) return;
  NamidaNavigator.inst.showSheet(
    isScrollControlled: true,
    heightPercentage: 0.6,
    builder: (context, bottomPadding, maxWidth, maxHeight) => _ChaptersSheet(
      item: item,
      chapters: chapters,
    ),
  );
}

/// [startMS, endMS) of chapter [index], the last one ends at [durationMS].
(int, int)? _chapterRangeMS(List<MediaChapter> chapters, int index, int? durationMS) {
  final startMS = chapters[index].startMS;
  final nextIndex = index + 1;
  final endMS = nextIndex < chapters.length ? chapters[nextIndex].startMS : durationMS;
  if (endMS == null || endMS <= startMS) return null;
  return (startMS, endMS);
}

int? _durationMSOf(Playable item) {
  if (Player.inst.isCurrentItem(item)) return Player.inst.currentItemDuration.value?.inMilliseconds;
  return item.execute<int?>(
    selectable: (finalItem) => finalItem.track.durationMS,
    youtubeID: (_) => null,
  );
}

/// builds nothing when [item] has no chapters.
class ChaptersSection extends StatelessWidget {
  final Playable item;

  const ChaptersSection({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final chapters = ChaptersController.inst.chaptersOf(item);
    if (chapters == null || chapters.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, bottom: 12.0),
      child: Row(
        children: [
          const Icon(
            Broken.weight_1,
            size: 20.0,
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: SmoothSingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 12.0),
              child: Row(
                children: chapters
                    .map(
                      (chapter) => _ChapterChip(
                        chapter: chapter,
                        onTap: () => ChaptersController.inst.play(item, chapter),
                      ),
                    )
                    .addSeparators(separator: const SizedBox(width: 6.0))
                    .toFixedList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// the playing chapter of the current item, opens its chapters on tap. builds nothing without chapters.
class CurrentChapterBadge extends StatelessWidget {
  final Playable item;

  const CurrentChapterBadge({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: ChaptersController.inst.currentChapters,
      builder: (context, chapters) => chapters.isEmpty
          ? const SizedBox()
          : _CurrentChapterBadgeContent(
              item: item,
              chapters: chapters,
            ),
    );
  }
}

class _CurrentChapterBadgeContent extends StatefulWidget {
  final Playable item;
  final List<MediaChapter> chapters;

  const _CurrentChapterBadgeContent({
    required this.item,
    required this.chapters,
  });

  @override
  State<_CurrentChapterBadgeContent> createState() => _CurrentChapterBadgeContentState();
}

class _CurrentChapterBadgeContentState extends State<_CurrentChapterBadgeContent> {
  late final _tracker = ChaptersTracker.fromChapters(widget.chapters);

  @override
  void didUpdateWidget(covariant _CurrentChapterBadgeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.chapters, widget.chapters)) return;
    final startsMS = widget.chapters.map((e) => e.startMS).toFixedList();
    _tracker.updateStartsMS(startsMS);
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: NamidaInkWell(
        borderRadius: 4.0,
        bgColor: theme.cardColor.withAlpha(60),
        padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
        onTap: () => showChaptersSheet(widget.item),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Broken.weight_1,
              size: 10.0,
            ),
            const SizedBox(width: 2.0),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120.0),
              child: ObxO(
                rx: _tracker.currentIndex,
                builder: (context, currentIndex) {
                  final chapters = widget.chapters;
                  final title = currentIndex < 0 ? '' : chapters[currentIndex].title;
                  final label = title.isEmpty ? '${currentIndex + 1}/${chapters.length}' : title;
                  return Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 10.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChaptersSheet extends StatefulWidget {
  final Playable item;
  final List<MediaChapter> chapters;

  const _ChaptersSheet({
    required this.item,
    required this.chapters,
  });

  @override
  State<_ChaptersSheet> createState() => _ChaptersSheetState();
}

class _ChaptersSheetState extends State<_ChaptersSheet> {
  late final _scrollController = NamidaScrollController.create();

  /// only the current item has a playing chapter to follow.
  late final _tracker = Player.inst.isCurrentItem(widget.item) ? ChaptersTracker.fromChapters(widget.chapters) : null;
  late final _durationMS = _durationMSOf(widget.item);
  double _itemExtent = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  @override
  void dispose() {
    _tracker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToCurrent() {
    final index = _tracker?.currentIndex.value ?? -1;
    if (index < 0 || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final offset = (index * _itemExtent - (position.viewportDimension - _itemExtent) * 0.3).clampDouble(position.minScrollExtent, position.maxScrollExtent);
    _scrollController.jumpTo(offset);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final chapters = widget.chapters;
    _itemExtent = _ChapterRowContent.extentFor(MediaQuery.textScalerOf(context));

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
                  text: '  •  ${chapters.length}',
                  style: textTheme.displayMedium,
                ),
              ],
            ),
            style: textTheme.displayLarge,
          ),
        ),
        Expanded(
          child: SmoothCustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 4.0),
                sliver: SliverFixedExtentList.builder(
                  itemExtent: _itemExtent,
                  itemCount: chapters.length,
                  itemBuilder: (context, index) => _ChapterRow(
                    chapter: chapters[index],
                    index: index,
                    rangeMS: _chapterRangeMS(chapters, index, _durationMS),
                    tracker: _tracker,
                    onTap: () => ChaptersController.inst.play(widget.item, chapters[index]),
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

class _ChapterRow extends StatelessWidget {
  final MediaChapter chapter;
  final int index;
  final (int, int)? rangeMS;
  final ChaptersTracker? tracker;
  final VoidCallback onTap;

  const _ChapterRow({
    required this.chapter,
    required this.index,
    required this.rangeMS,
    required this.tracker,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tracker = this.tracker;
    if (tracker == null) {
      return _ChapterRowContent(
        chapter: chapter,
        index: index,
        rangeMS: rangeMS,
        status: ChapterStatus.upcoming,
        onTap: onTap,
      );
    }
    return ObxOSelect(
      rx: tracker.currentIndex,
      selector: (currentIndex) => ChapterStatus.of(index, currentIndex),
      builder: (context, status) => _ChapterRowContent(
        chapter: chapter,
        index: index,
        rangeMS: rangeMS,
        status: status,
        onTap: onTap,
      ),
    );
  }
}

class _ChapterRowContent extends StatelessWidget {
  static const _kMargin = EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0);
  static const _kPadding = EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0);
  static const _kNumberWidth = 28.0;
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
    return (textBlockHeight + _kPadding.vertical + _kMargin.vertical).ceilToDouble();
  }

  final MediaChapter chapter;
  final int index;
  final (int, int)? rangeMS;
  final ChapterStatus status;
  final VoidCallback onTap;

  const _ChapterRowContent({
    required this.chapter,
    required this.index,
    required this.rangeMS,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final rangeMS = this.rangeMS;
    final isCurrent = status == ChapterStatus.current;
    final isPlayed = status == ChapterStatus.played;
    final startLabel = chapter.startMS.milliSecondsLabel;
    final title = chapter.title.isEmpty ? startLabel : chapter.title;
    final subtitle = rangeMS == null ? startLabel : '$startLabel  •  ${ChaptersTracker.lengthLabel(rangeMS)}';

    return NamidaInkWell(
      animationDurationMS: 200,
      borderRadius: 10.0,
      margin: _kMargin,
      padding: _kPadding,
      bgColor: isCurrent ? theme.colorScheme.secondaryContainer : theme.cardColor.withOpacityExt(0.4),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: _kNumberWidth,
            child: isCurrent
                ? const Icon(
                    Broken.play,
                    size: 16.0,
                  )
                : Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                  subtitle,
                  style: textTheme.displaySmall?.copyWith(fontSize: _kSubtitleFontSize),
                  strutStyle: _kSubtitleStrut,
                  maxLines: 1,
                ),
                const SizedBox(height: _kProgressGap),
                SizedBox(
                  height: _kProgressHeight,
                  child: isCurrent && rangeMS != null
                      ? ChapterProgressBar(
                          rangeMS: rangeMS,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterChip extends StatelessWidget {
  final MediaChapter chapter;
  final VoidCallback onTap;

  const _ChapterChip({
    required this.chapter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final title = chapter.title;
    return NamidaInkWell(
      borderRadius: 8.0,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      bgColor: theme.cardColor.withOpacityExt(0.6),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160.0),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: chapter.startMS.milliSecondsLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (title.isNotEmpty) TextSpan(text: '  $title'),
            ],
          ),
          style: theme.textTheme.displaySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
