// by claude
import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/class/history_stats.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/track_listens_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/stats_charts.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';

class StatsFormat {
  StatsFormat._();

  static String listenTime(HistoryStatsSnapshot snapshot) {
    final text = snapshot.listenSeconds.secondsFormatted;
    return snapshot.listenSecondsExact ? text : '≈ $text';
  }

  static String day(int day) => HistoryManager.daysSince1970ToDate(day).dateFormattedOriginal;

  static String rangeText(HistoryStatsSnapshot snapshot) {
    final oldest = HistoryManager.daysSince1970ToDate(snapshot.firstDay);
    final newest = HistoryManager.daysSince1970ToDate(snapshot.lastDay);
    return '${oldest.dateFormattedOriginalNoYears(newest)} → ${newest.dateFormattedOriginalNoYears(oldest)}';
  }

  static String durationMS(int ms) => (ms ~/ 1000).secondsFormatted;
}

class StatsPeriodChip extends StatelessWidget {
  final String text;
  final bool isActive;
  final IconData? icon;
  final VoidCallback onTap;
  final bool dense;

  const StatsPeriodChip({
    super.key,
    required this.text,
    required this.isActive,
    this.icon,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textColor = isActive ? const Color.fromARGB(200, 255, 255, 255) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: TapDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(horizontal: dense ? 8.0 : 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: isActive ? CurrentColor.inst.currentColorScheme.withAlpha(160) : theme.cardColor,
            borderRadius: BorderRadius.circular(8.0.multipliedRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16.0, color: textColor),
                if (text.isNotEmpty) const SizedBox(width: 4.0),
              ],
              if (text.isNotEmpty)
                Text(
                  text,
                  style: theme.textTheme.displaySmall?.copyWith(color: textColor, fontWeight: FontWeight.w600),
                  softWrap: false,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatsTopTrackTile extends StatelessWidget {
  final Track track;
  final int index;
  final int count;
  final List<Track> queue;
  final String? trailingText;
  final double thumbnailSize;
  final bool showIndex;

  /// listens dialog will show listens between these (ms), all listens when null.
  final (int, int)? listensRangeMS;

  const StatsTopTrackTile({
    super.key,
    required this.track,
    required this.index,
    required this.count,
    required this.queue,
    this.trailingText,
    this.thumbnailSize = 42.0,
    this.showIndex = true,
    this.listensRangeMS,
  });

  void _openListens() {
    final all = HistoryController.inst.topTracksMapListens.value[track] ?? const <int>[];
    final range = listensRangeMS;
    final dates = range == null ? all : all.where((ms) => ms >= range.$1 && ms <= range.$2).toList();
    showTrackListensDialog(track, datesOfListen: dates);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final trExt = track.toTrackExt();
    return NamidaInkWell(
      borderRadius: 10.0,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      onTap: () => Player.inst.playOrPause(index, queue, QueueSource.mostPlayed),
      onLongPress: () => NamidaDialogs.inst.showTrackDialog(track, source: QueueSource.mostPlayed, index: index),
      child: Row(
        children: [
          if (showIndex)
            SizedBox(
              width: 22.0,
              child: Text(
                '${index + 1}',
                style: textTheme.displaySmall?.copyWith(fontSize: 11.0, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withOpacityExt(0.5)),
                textAlign: TextAlign.center,
              ),
            ),
          ArtworkWidget(
            key: Key(track.path),
            track: track,
            path: track.pathToImage,
            thumbnailSize: thumbnailSize,
            forceSquared: true,
            borderRadius: 8.0,
            blur: 0.0,
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trExt.title,
                  style: textTheme.displayMedium?.copyWith(fontSize: 13.0, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  trExt.originalArtist,
                  style: textTheme.displaySmall?.copyWith(fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          NamidaInkWell(
            borderRadius: 8.0,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            onTap: _openListens,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count.formatDecimal(),
                  style: textTheme.displayMedium?.copyWith(fontSize: 13.0, fontWeight: FontWeight.w700),
                ),
                if (trailingText != null)
                  Text(
                    trailingText!,
                    style: textTheme.displaySmall?.copyWith(fontSize: 10.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatsTopVideosRow extends StatelessWidget {
  final List<StatsRankEntry<String>> items;

  const StatsTopVideosRow({
    super.key,
    required this.items,
  });

  static const _thumbHeight = 24.0 * 3.2;
  static const _thumbWidth = _thumbHeight * 16 / 9;
  static const rowHeight = 124.0;

  @override
  Widget build(BuildContext context) {
    final videos = items
        .map(
          (e) => YoutubeID(
            id: e.key,
            playlistID: const PlaylistID(id: k_PLAYLIST_NAME_MOST_PLAYED),
          ),
        )
        .toList(growable: false);
    return VideoTilePropertiesProvider(
      configs: const VideoTilePropertiesConfigs(
        queueSource: QueueSourceYoutubeID.ytMostPlayed,
        playlistID: PlaylistID(id: k_PLAYLIST_NAME_MOST_PLAYED),
      ),
      builder: (properties) => SizedBox(
        height: rowHeight,
        child: SuperSmoothListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          scrollDirection: Axis.horizontal,
          itemCount: videos.length,
          itemBuilder: (context, index) => YTHistoryVideoCard(
            properties: properties,
            minimalCard: true,
            videos: videos,
            index: index,
            day: null,
            minimalCardWidth: _thumbWidth,
            thumbnailHeight: _thumbHeight,
            overrideListens: List.filled(items[index].count, 0),
            preferFetchNewInfo: true,
          ),
        ),
      ),
    );
  }
}

/// compact `icon value label` pill for inside cards.
class StatsMiniTile extends StatelessWidget {
  final IconData icon;
  final Widget? leading;
  final String label;
  final String value;
  final Widget? valueWidget;
  final Widget? trailing;
  final VoidCallback? onTap;

  const StatsMiniTile({
    super.key,
    required this.icon,
    this.leading,
    required this.label,
    required this.value,
    this.valueWidget,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return NamidaInkWell(
      onTap: onTap,
      borderRadius: 10.0,
      margin: const EdgeInsets.only(right: 6.0, bottom: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
      bgColor: theme.colorScheme.onSurface.withOpacityExt(0.05),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading ?? Icon(icon, size: 16.0, color: context.defaultIconColor()),
          const SizedBox(width: 8.0),
          if (valueWidget != null) ...[
            DefaultTextStyle(
              style: textTheme.displayMedium!.copyWith(fontSize: 13.0, fontWeight: FontWeight.w700),
              child: valueWidget!,
            ),
            Text(
              '  $label',
              style: textTheme.displaySmall?.copyWith(fontSize: 11.0),
            ),
          ] else
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: textTheme.displayMedium?.copyWith(fontSize: 13.0, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: '  $label',
                    style: textTheme.displaySmall?.copyWith(fontSize: 11.0),
                  ),
                ],
              ),
            ),
          if (trailing != null) ...[
            const SizedBox(width: 6.0),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// `▲ 12%` against a previous value.
class StatsDelta extends StatelessWidget {
  final int now;
  final int previous;

  const StatsDelta({super.key, required this.now, required this.previous});

  @override
  Widget build(BuildContext context) {
    if (previous <= 0 || now == previous) return const SizedBox();
    final up = now > previous;
    final pct = ((now - previous) * 100 / previous).round().abs();
    final color = up ? Colors.green : Colors.red;
    return Text(
      '${up ? '▲' : '▼'} $pct%',
      style: context.theme.textTheme.displaySmall?.copyWith(fontSize: 10.0, fontWeight: FontWeight.w700, color: color.withOpacityExt(0.85)),
    );
  }
}

String statsMinuteOfDay(int minute) {
  if (minute < 0) return '';
  final dt = DateTime(2024, 1, 1, minute ~/ 60, minute % 60);
  return dt.clockFormatted;
}

class StatsInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const StatsInfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return StatsContainer(
      icon: icon,
      title: '$title :',
      value: value,
    );
  }
}

class StatsEmptyHint extends StatelessWidget {
  const StatsEmptyHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Broken.chart_2, size: 36.0, color: context.theme.colorScheme.onSurface.withOpacityExt(0.4)),
            const SizedBox(height: 8.0),
            Text(
              lang.history,
              style: context.theme.textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }
}

void showTracksStatsCardDialog({
  required List<Track> tracks,
  required String title,
  required String subtitle,
  bool isCircle = false,
}) {
  final listensMap = HistoryController.inst.topTracksMapListens.value;
  int totalListens = 0;
  int playedTracks = 0;
  int firstMS = 0;
  int lastMS = 0;
  int estimatedSeconds = 0;
  final ranked = <StatsRankEntry<Track>>[];
  for (final tr in tracks) {
    final listens = listensMap[tr];
    if (listens == null || listens.isEmpty) continue;
    playedTracks++;
    totalListens += listens.length;
    ranked.add(StatsRankEntry(tr, listens.length));
    final f = listens.first;
    final l = listens.last;
    if (firstMS == 0 || f < firstMS) firstMS = f;
    if (l > lastMS) lastMS = l;
    estimatedSeconds += (tr.toTrackExtOrNull()?.durationMS ?? 0) ~/ 1000 * listens.length;
  }
  ranked.sort((a, b) => b.count.compareTo(a.count));
  final top = ranked.length > 5 ? ranked.sublist(0, 5) : ranked;
  final queue = top.map((e) => e.key).toList();

  NamidaNavigator.inst.navigateDialog(
    dialog: CustomBlurryDialog(
      normalTitleStyle: true,
      horizontalInset: 12.0,
      contentPadding: EdgeInsets.zero,
      title: lang.stats,
      child: StatsChartCard(
        title: title,
        subtitle: subtitle,
        icon: Broken.chart_2,
        copyText: () => [
          title,
          '${lang.totalListens}: $totalListens',
          '${lang.totalListenTime}: ≈ ${estimatedSeconds.secondsFormatted}',
          if (firstMS > 0) '${lang.firstListen}: ${firstMS.dateFormattedOriginal}',
          if (lastMS > 0) '${lang.lastListen}: ${lastMS.dateFormattedOriginal}',
          ...top.map((e) => '${e.key.toTrackExt().title} • ${e.count}'),
        ].join('\n'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (tracks.isNotEmpty)
                  ArtworkWidget(
                    key: Key(tracks.first.path),
                    track: tracks.first,
                    path: tracks.first.pathToImage,
                    thumbnailSize: 64.0,
                    forceSquared: true,
                    isCircle: isCircle,
                    borderRadius: 12.0,
                    blur: 0.0,
                  ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Wrap(
                    children: [
                      StatsMiniTile(icon: Broken.music_playlist, label: lang.totalListens, value: totalListens.formatDecimal()),
                      StatsMiniTile(icon: Broken.timer_1, label: lang.totalListenTime, value: '≈ ${estimatedSeconds.secondsFormatted}'),
                      StatsMiniTile(icon: Broken.music_circle, label: lang.tracks, value: '$playedTracks / ${tracks.length}'),
                    ],
                  ),
                ),
              ],
            ),
            if (firstMS > 0) ...[
              const SizedBox(height: 4.0),
              Wrap(
                children: [
                  StatsMiniTile(icon: Broken.calendar_1, label: lang.firstListen, value: firstMS.dateFormattedOriginal),
                  StatsMiniTile(icon: Broken.calendar, label: lang.lastListen, value: lastMS.dateFormattedOriginal),
                ],
              ),
            ],
            if (top.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              ...List.generate(
                top.length,
                (i) => StatsTopTrackTile(
                  track: top[i].key,
                  index: i,
                  count: top[i].count,
                  queue: queue,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
