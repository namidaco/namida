import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';
import 'package:intl/intl.dart';

import 'package:namida/class/history_stats.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/stats_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/pages/subpages/your_year_page.dart';
import 'package:namida/ui/widgets/creative_animations.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/stats_charts.dart';
import 'package:namida/ui/widgets/stats_widgets.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/yt_utils.dart';

class StatsPage extends StatelessWidget with NamidaRouteWidget {
  final bool isYoutube;
  const StatsPage({super.key, required this.isYoutube});

  @override
  RouteType get route => RouteType.PAGE_stats;

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: SmoothCustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: StatsSection(),
          ),
          // if (kEnableFancyAnimations) const SliverToBoxAdapter(child: ListensTrendSection()),
          StatsChartsSlivers(
            isYoutube: isYoutube,
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: Dimensions.inst.globalBottomPaddingTotalR,
            ),
          ),
        ],
      ),
    );
  }
}

class StatsSection extends StatelessWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StatsChartCard(
      title: lang.stats,
      subtitle: lang.statsSubtitle,
      icon: Broken.chart_21,
      copyText: () {
        final map = Player.inst.totalListenedTimeInSec;
        final localSec = (map?[LibraryCategory.localTracks] ?? 0) + (map?[LibraryCategory.localVideos] ?? 0);
        return [
          '${lang.tracks}: ${Indexer.inst.tracksInfoList.value.length}',
          '${lang.albums}: ${Indexer.inst.mainMapAlbums.value.keys.length}',
          '${lang.artists}: ${Indexer.inst.mainMapArtists.value.length}',
          '${lang.genres}: ${Indexer.inst.mainMapGenres.value.length}',
          '${lang.totalTracksDuration}: ${Indexer.inst.tracksInfoList.value.totalDurationFormatted}',
          '${lang.totalListenTime}: ${localSec.secondsFormatted}',
          '${lang.totalListenTime} (${lang.youtube}): ${(map?[LibraryCategory.youtube] ?? 0).secondsFormatted}',
        ].join('\n');
      },
      child: SizedBox(
        width: context.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          child: Obx(
            (context) {
              final allTracks = Indexer.inst.tracksInfoList.valueR;
              final stylesR = Indexer.inst.mainMapStyles.valueR;
              int? stylesLength = stylesR.length;
              if (stylesLength <= 1) {
                final firstStyle = stylesR.keys.firstOrNull;
                if (firstStyle == null || firstStyle == UnknownTags.STYLE) {
                  stylesLength = null;
                }
              }
              return Wrap(
                alignment: WrapAlignment.start,
                children: [
                  StatsMiniTile(icon: Broken.music_circle, label: lang.tracks, value: allTracks.length.formatDecimal()),
                  StatsMiniTile(icon: Broken.music_dashboard, label: lang.albums, value: Indexer.inst.mainMapAlbums.valueR.keys.length.formatDecimal()),
                  StatsMiniTile(icon: Broken.microphone, label: lang.artists, value: Indexer.inst.mainMapArtists.valueR.length.formatDecimal()),
                  StatsMiniTile(icon: Broken.smileys, label: lang.genres, value: Indexer.inst.mainMapGenres.valueR.length.formatDecimal()),
                  if (stylesLength != null) StatsMiniTile(icon: Broken.brush_1, label: lang.styles, value: stylesLength.formatDecimal()),
                  StatsMiniTile(icon: Broken.music_library_2, label: lang.totalTracksDuration, value: allTracks.totalDurationFormatted),
                  Obx(
                    (context) {
                      final map = Player.inst.totalListenedTimeInSec;
                      final trSec = map?[LibraryCategory.localTracks] ?? 0;
                      final vidSec = map?[LibraryCategory.localVideos] ?? 0;
                      final totalSec = trSec + vidSec;
                      return StatsMiniTile(
                        icon: Broken.timer_1,
                        label: lang.totalListenTime,
                        value: totalSec.secondsFormatted,
                        valueWidget: kEnableFancyAnimations ? _ListenTimeOdometer(seconds: totalSec) : null,
                      );
                    },
                  ),
                  Obx(
                    (context) {
                      final map = Player.inst.totalListenedTimeInSec;
                      final sec = map?[LibraryCategory.youtube] ?? 0;
                      return StatsMiniTile(
                        leading: const StackedIcon(
                          baseIcon: Broken.timer_1,
                          secondaryIcon: Broken.video_square,
                          secondaryIconSize: 10.0,
                          iconSize: 16.0,
                        ),
                        icon: Broken.timer_1,
                        label: '${lang.totalListenTime} (${lang.youtube})',
                        value: sec.secondsFormatted,
                        valueWidget: kEnableFancyAnimations ? _ListenTimeOdometer(seconds: sec) : null,
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// by claude
class _ListenTimeOdometer extends StatelessWidget {
  final int seconds;

  const _ListenTimeOdometer({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return CAMagnitudeOdometer(
      value: seconds.secondsFormatted,
      magnitude: seconds,
      // -- an hour of extra listening is a full length roll.
      magnitudeRange: 3600,
    );
  }
}

// by claude
// class ListensTrendSection extends StatefulWidget {
//   const ListensTrendSection({super.key});

//   @override
//   State<ListensTrendSection> createState() => _ListensTrendSectionState();
// }

// class _ListensTrendSectionState extends State<ListensTrendSection> {
//   static const _days = 30;

//   late final List<KineticDataPoint> _points;
//   int _peakListens = 0;

//   @override
//   void initState() {
//     super.initState();
//     _points = _buildPoints();
//   }

//   List<KineticDataPoint> _buildPoints() {
//     final historyMap = HistoryController.inst.historyMap.value;
//     final today = DateTime.now().toDaysSince1970();

//     final points = <KineticDataPoint>[];
//     int peakDay = -1;
//     for (int i = _days - 1; i >= 0; i--) {
//       final day = today - i;
//       final listens = historyMap[day]?.length ?? 0;
//       if (listens > _peakListens) {
//         _peakListens = listens;
//         peakDay = _days - 1 - i;
//       }
//       points.add(KineticDataPoint(x: (_days - 1 - i).toDouble(), y: listens.toDouble()));
//     }

//     // -- only the peak gets a label, anything more turns the line into a wall of text.
//     if (peakDay >= 0 && _peakListens > 0) {
//       points[peakDay] = KineticDataPoint(
//         x: points[peakDay].x,
//         y: points[peakDay].y,
//         label: lang.countTracks(count: _peakListens),
//       );
//     }
//     return points;
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_peakListens <= 0) return const SizedBox();
//     return SettingsCard(
//       title: lang.totalListens,
//       subtitle: lang.countDays(count: _days),
//       icon: Broken.chart_success,
//       child: Padding(
//         padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
//         child: CAKineticPathReveal(
//           points: _points,
//           height: 150.0,
//           minY: 0.0,
//         ),
//       ),
//     );
//   }
// }

// ======================================== charts ========================================

// all below by claude
class StatsChartsSlivers extends StatefulWidget {
  final bool isYoutube;
  const StatsChartsSlivers({super.key, required this.isYoutube});

  @override
  State<StatsChartsSlivers> createState() => _StatsChartsSliversState();
}

class _StatsChartsSliversState extends State<StatsChartsSlivers> {
  static const _periods = [
    MostPlayedTimeRange.week,
    MostPlayedTimeRange.month,
    MostPlayedTimeRange.month3,
    MostPlayedTimeRange.month6,
    MostPlayedTimeRange.year,
    MostPlayedTimeRange.allTime,
  ];

  MostPlayedTimeRange _mptr = MostPlayedTimeRange.allTime;
  DateRange? _custom;
  bool _isYoutube = false;
  bool _loading = true;
  bool _showAllArtists = false;
  int _requestId = 0;

  HistoryStatsSnapshot<Track>? _local;
  HistoryStatsSnapshot<String>? _youtube;
  HistoryStatsSnapshot<Track>? _localPrev;
  HistoryStatsSnapshot<String>? _youtubePrev;

  bool get _hasYoutubeHistory => YoutubeHistoryController.inst.historyMap.value.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _isYoutube = widget.isYoutube;
    _compute();
  }

  @override
  void dispose() {
    StatsController.inst.clearCache();
    super.dispose();
  }

  DateRange _resolveRange() {
    final now = DateTime.now();
    final custom = _custom;
    if (_mptr == MostPlayedTimeRange.custom && custom != null) return custom;
    if (_mptr == MostPlayedTimeRange.allTime) {
      final localOldest = HistoryController.inst.oldestTrack?.dateAddedMS;
      final ytOldest = YoutubeHistoryController.inst.oldestTrack?.dateAddedMS;
      int? oldest = localOldest;
      if (ytOldest != null && (oldest == null || ytOldest < oldest)) oldest = ytOldest;
      return DateRange(oldest: oldest == null ? now : DateTime.fromMillisecondsSinceEpoch(oldest), newest: now);
    }
    final oldest = HistoryController.inst.resolveOldDate(_mptr, now, true, null) ?? now;
    return DateRange(oldest: oldest, newest: now);
  }

  Future<void> _compute() async {
    final id = ++_requestId;
    if (!_loading) setState(() => _loading = true);
    await Future.wait([
      HistoryController.inst.waitForHistoryAndMostPlayedLoad,
      YoutubeHistoryController.inst.waitForHistoryAndMostPlayedLoad,
    ]);
    final range = _resolveRange();
    final local = await StatsController.inst.local(range);
    final yt = _hasYoutubeHistory ? await StatsController.inst.youtube(range) : null;

    HistoryStatsSnapshot<Track>? localPrev;
    HistoryStatsSnapshot<String>? ytPrev;
    if (_mptr != MostPlayedTimeRange.allTime) {
      final length = range.toDurationSafe();
      final prevRange = DateRange(oldest: range.oldest.subtract(length), newest: range.oldest.subtract(const Duration(milliseconds: 1)));
      localPrev = await StatsController.inst.localPrevious(prevRange);
      ytPrev = yt == null ? null : await StatsController.inst.youtubePrevious(prevRange);
    }

    if (id != _requestId || !mounted) return;
    setState(() {
      _local = local;
      _youtube = yt;
      _localPrev = localPrev;
      _youtubePrev = ytPrev;
      _loading = false;
    });
  }

  void _selectPeriod(MostPlayedTimeRange mptr, [DateRange? custom]) {
    _mptr = mptr;
    _custom = custom;
    _showAllArtists = false;
    _compute();
  }

  void _openCustomCalendar() {
    showCalendarDialog(
      title: lang.choose,
      buttonText: lang.confirm,
      useHistoryDates: true,
      historyController: HistoryController.inst,
      onGenerate: (dates) {
        NamidaNavigator.inst.closeDialog();
        _selectPeriod(MostPlayedTimeRange.custom, DateRange(oldest: dates.first, newest: dates.last));
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final years = _isYoutube ? YoutubeHistoryController.inst.getHistoryYears() : HistoryController.inst.getHistoryYears();
    final customText = _custom == null ? '' : '${_custom!.oldest.dateFormattedOriginalNoYears(_custom!.newest)} → ${_custom!.newest.dateFormattedOriginalNoYears(_custom!.oldest)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Icon(Broken.chart_2, size: 22.0, color: context.defaultIconColor()),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    lang.charts,
                    style: textTheme.displayLarge?.copyWith(fontSize: 18.0),
                  ),
                ),
                if (_hasYoutubeHistory) ...[
                  StatsPeriodChip(
                    text: '',
                    icon: Broken.music_circle,
                    isActive: !_isYoutube,
                    dense: true,
                    onTap: () => setState(() => _isYoutube = false),
                  ),
                  StatsPeriodChip(
                    text: '',
                    icon: Broken.video_square,
                    isActive: _isYoutube,
                    dense: true,
                    onTap: () => setState(() => _isYoutube = true),
                  ),
                  const SizedBox(width: 6.0),
                ],
                if (years.isNotEmpty)
                  NamidaInkWell(
                    borderRadius: 10.0,
                    bgColor: theme.cardColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    onTap: () => YourYearPage(year: years.first, isYoutube: _isYoutube).navigate(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Broken.magic_star, size: 16.0, color: context.defaultIconColor()),
                        const SizedBox(width: 6.0),
                        Text(
                          lang.yourYear(year: years.first.toString()),
                          style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              StatsPeriodChip(
                text: customText,
                icon: Broken.calendar,
                isActive: _mptr == MostPlayedTimeRange.custom,
                onTap: _openCustomCalendar,
                dense: true,
              ),
              Expanded(
                child: SmoothSingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _periods
                        .map(
                          (p) => StatsPeriodChip(
                            text: p.toText(),
                            isActive: _mptr == p,
                            onTap: () => _selectPeriod(p),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget Function(BuildContext)> _buildCards() {
    final local = _local;
    final yt = _youtube;
    final HistoryStatsSnapshot? s = _isYoutube ? yt : local;
    if (s == null || s.isEmpty) return [(context) => const StatsEmptyHint()];

    final isYoutube = _isYoutube;
    final itemsLabel = isYoutube ? lang.videos : lang.tracks;
    final artistsLabel = isYoutube ? lang.channels : lang.artists;

    final cards = <Widget Function(BuildContext)>[];

    // -- summary tiles, deltas against the previous equal-length period
    final HistoryStatsSnapshot? prev = isYoutube ? _youtubePrev : _localPrev;
    final hasPrev = prev != null && !prev.isEmpty;
    cards.add(
      (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              children: [
                StatsMiniTile(
                  icon: Broken.music_playlist,
                  label: lang.totalListens,
                  value: s.totalListens.formatDecimal(),
                  trailing: hasPrev ? StatsDelta(now: s.totalListens, previous: prev.totalListens) : null,
                ),
                StatsMiniTile(
                  icon: Broken.timer_1,
                  label: lang.totalListenTime,
                  value: StatsFormat.listenTime(s),
                  trailing: hasPrev ? StatsDelta(now: s.listenSeconds, previous: prev.listenSeconds) : null,
                ),
                StatsMiniTile(
                  icon: isYoutube ? Broken.video_square : Broken.music_circle,
                  label: itemsLabel,
                  value: s.uniqueItems.formatDecimal(),
                  trailing: hasPrev ? StatsDelta(now: s.uniqueItems, previous: prev.uniqueItems) : null,
                ),
                StatsMiniTile(
                  icon: isYoutube ? Broken.profile_2user : Broken.microphone,
                  label: artistsLabel,
                  value: s.uniqueArtists.formatDecimal(),
                  trailing: hasPrev ? StatsDelta(now: s.uniqueArtists, previous: prev.uniqueArtists) : null,
                ),
                StatsMiniTile(
                  icon: Broken.calendar_1,
                  label: lang.days,
                  value: '${s.daysWithListens.formatDecimal()} / ${s.totalDays.formatDecimal()}',
                  trailing: hasPrev ? StatsDelta(now: s.daysWithListens, previous: prev.daysWithListens) : null,
                ),
                StatsMiniTile(
                  icon: Broken.flash,
                  label: lang.streak,
                  value: lang.countDays(count: s.currentStreak),
                ),
              ],
            ),
            if (hasPrev)
              Padding(
                padding: const EdgeInsets.only(left: 4.0, top: 2.0),
                child: Text(
                  '${lang.previous}: ${StatsFormat.rangeText(prev)}',
                  style: context.theme.textTheme.displaySmall?.copyWith(fontSize: 10.5),
                ),
              ),
          ],
        ),
      ),
    );

    // -- listens per month, tap sets the period to that month
    if (s.totalDays > 31) {
      cards.add(
        (context) {
          final monthFmt = DateFormat.MMM();
          final data = List.generate(12, (m) => ChartData(monthFmt.format(DateTime(2024, m + 1)), s.months[m]), growable: false);
          final lastDate = HistoryManager.daysSince1970ToDate(s.lastDay);
          return StatsChartCard(
            title: lang.months,
            subtitle: s.totalDays > 366 ? lang.allTime : lastDate.year.toString(),
            icon: Broken.calendar,
            copyText: () => data.map((e) => '${e.label} • ${e.value}').join('\n'),
            child: VerticalBarsChart(
              data: data,
              height: 110.0,
              onTap: (m) {
                var year = lastDate.year;
                if (m + 1 > lastDate.month) year--;
                final start = DateTime(year, m + 1);
                final end = DateTime(year, m + 2).subtract(const Duration(milliseconds: 1));
                if (start.toDaysSince1970() < s.firstDay) return;
                _selectPeriod(MostPlayedTimeRange.custom, DateRange(oldest: start, newest: end));
              },
            ),
          );
        },
      );
    }

    // -- cumulative line, local vs youtube
    cards.add(
      (context) {
        final series = <ChartSeries>[];
        int firstDay = s.firstDay;
        if (local != null && !local.isEmpty && local.firstDay < firstDay) firstDay = local.firstDay;
        if (yt != null && !yt.isEmpty && yt.firstDay < firstDay) firstDay = yt.firstDay;
        if (local != null && !local.isEmpty) series.add(ChartSeries(label: lang.local, perDay: _aligned(local, firstDay, s.lastDay)));
        if (yt != null && !yt.isEmpty) series.add(ChartSeries(label: lang.youtube, perDay: _aligned(yt, firstDay, s.lastDay)));
        return StatsChartCard(
          title: lang.totalListens,
          subtitle: StatsFormat.rangeText(s),
          icon: Broken.trend_up,
          copyText: () => series.map((e) => '${e.label}: ${_sum(e.perDay).formatDecimal()}').join('\n'),
          child: CumulativeLineChart(
            series: series,
            firstDay: firstDay,
          ),
        );
      },
    );

    // -- heatmap
    cards.add(
      (context) {
        final streak = s.longestStreak;
        return StatsChartCard(
          title: lang.days,
          subtitle: streak == null
              ? null
              : '${lang.longestStreak}: ${lang.countDays(count: streak.days)} • ${lang.busiestDay}: ${StatsFormat.day(s.peakDay)} (${s.peakDayListens.formatDecimal()})',
          icon: Broken.calendar_1,
          copyText: () => '${lang.longestStreak}: ${lang.countDays(count: streak?.days ?? 0)}\n${lang.busiestDay}: ${StatsFormat.day(s.peakDay)} • ${s.peakDayListens}',
          child: ListensHeatmapChart(
            values: s.listensPerDay,
            firstDay: s.firstDay,
            onDayLongPress: (day, listens) {
              if (listens <= 0) return;
              final ms = HistoryManager.daysSince1970ToMilliseconds(day) + (Duration.millisecondsPerDay ~/ 2);
              if (isYoutube) {
                YTUtils.onYoutubeHistoryPlaylistTap(initialListen: ms);
              } else {
                NamidaOnTaps.inst.onHistoryPlaylistTap(initialListen: ms);
              }
            },
          ),
        );
      },
    );

    // -- clock + weekdays
    cards.add(
      (context) {
        final weekdayFmt = DateFormat.E();
        final sunday = DateTime(2024, 1, 7);
        final weekdays = List.generate(7, (i) => ChartData(weekdayFmt.format(sunday.add(Duration(days: i))), s.weekdays[i]), growable: false);
        return StatsChartCard(
          title: lang.listeningClock,
          icon: Broken.clock,
          copyText: () {
            final buf = StringBuffer();
            for (int h = 0; h < 24; h++) {
              buf.writeln('${h.toString().padLeft(2, '0')}:00 • ${s.hours[h]}');
            }
            for (final w in weekdays) {
              buf.writeln('${w.label} • ${w.value}');
            }
            return buf.toString();
          },
          child: LayoutWidthProvider(
            builder: (context, maxWidth) {
              final wide = maxWidth > 420;
              final clock = ListeningClockChart(hours: s.hours, size: wide ? 200.0 : (maxWidth * 0.62).clamp(160.0, 220.0));
              final bars = VerticalBarsChart(data: weekdays, height: 90.0);
              final grid = GridHeatmapChart(
                values: s.weekHours,
                rows: 7,
                cols: 24,
                rowLabels: weekdays.map((e) => e.label).toList(growable: false),
                colLabels: List.generate(24, (h) => h.toString().padLeft(2, '0'), growable: false),
                colLabelStep: 3,
                tipBuilder: (row, col, value) => '${weekdays[row].label} ${col.toString().padLeft(2, '0')}:00\n${lang.countTracks(count: value)}',
              );
              final top = wide
                  ? Row(
                      children: [
                        clock,
                        const SizedBox(width: 12.0),
                        Expanded(child: bars),
                      ],
                    )
                  : Column(
                      children: [
                        clock,
                        const SizedBox(height: 8.0),
                        bars,
                      ],
                    );
              return Column(
                children: [
                  top,
                  const SizedBox(height: 14.0),
                  grid,
                ],
              );
            },
          ),
        );
      },
    );

    // -- habits: simple numbers combined
    cards.add(
      (context) {
        final textTheme = context.theme.textTheme;
        final repeatPct = s.totalListens <= 1 ? 0 : (s.repeatListens * 100 / (s.totalListens - 1)).round();
        int libraryCount = 0;
        int neverPlayed = 0;
        if (!isYoutube) {
          libraryCount = Indexer.inst.tracksInfoList.value.length;
          final playedEver = HistoryController.inst.topTracksMapListens.value.length;
          neverPlayed = libraryCount - playedEver;
          if (neverPlayed < 0) neverPlayed = 0;
        }
        final reachPct = libraryCount == 0 ? 0 : (s.uniqueItems * 100 / libraryCount).round();
        final streak = s.longestItemStreak;
        final rangeMS = (HistoryManager.daysSince1970ToMilliseconds(s.firstDay), HistoryManager.daysSince1970ToMilliseconds(s.lastDay + 1) - 1);
        return StatsChartCard(
          title: lang.habits,
          icon: Broken.activity,
          copyText: () => [
            '${lang.repeatRate}: $repeatPct%',
            '${lang.totalListens} = 1: ${s.oneTimeItems} $itemsLabel',
            '${lang.totalListens} ≥ ${HistoryStatsSnapshot.heavyRotationCount}: ${s.heavyRotationItems} $itemsLabel',
            if (libraryCount > 0) '${lang.libraryReach}: $reachPct%',
            if (libraryCount > 0) '${lang.never}: $neverPlayed',
            '${lang.firstListen}: ${statsMinuteOfDay(s.avgFirstMinute)}',
            '${lang.lastListen}: ${statsMinuteOfDay(s.avgLastMinute)}',
          ].join('\n'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                children: [
                  StatsMiniTile(icon: Broken.repeat, label: lang.repeatRate, value: '$repeatPct%'),
                  StatsMiniTile(icon: Broken.music_square, label: '${lang.totalListens} = 1', value: '${s.oneTimeItems.formatDecimal()} $itemsLabel'),
                  StatsMiniTile(
                    icon: Broken.flash,
                    label: '${lang.totalListens} ≥ ${HistoryStatsSnapshot.heavyRotationCount}',
                    value: '${s.heavyRotationItems.formatDecimal()} $itemsLabel',
                  ),
                  if (libraryCount > 0) StatsMiniTile(icon: Broken.music_library_2, label: lang.libraryReach, value: '$reachPct%'),
                  if (libraryCount > 0) StatsMiniTile(icon: Broken.eye, label: '${lang.never} • ${lang.tracks}', value: neverPlayed.formatDecimal()),
                  if (s.avgFirstMinute >= 0) StatsMiniTile(icon: Broken.sun_1, label: lang.firstListen, value: statsMinuteOfDay(s.avgFirstMinute)),
                  if (s.avgLastMinute >= 0) StatsMiniTile(icon: Broken.moon, label: lang.lastListen, value: statsMinuteOfDay(s.avgLastMinute)),
                ],
              ),
              if (streak != null) ...[
                const SizedBox(height: 6.0),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6.0, 0.0, 6.0, 6.0),
                  child: Text(
                    '${lang.streak} • ${lang.countDays(count: streak.days)} • ${StatsFormat.day(streak.endDay - streak.days + 1)} → ${StatsFormat.day(streak.endDay)}',
                    style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                _buildSingleItem(context, s, streak.item, s.topItems.firstWhereEff((e) => e.key == streak.item)?.count ?? streak.days, listensRangeMS: rangeMS),
              ],
            ],
          ),
        );
      },
    );

    // -- obsession & longest session
    if (s.obsessions.isNotEmpty || s.longestSession != null) {
      cards.add(
        (context) {
          final obsessions = s.obsessions;
          final session = s.longestSession;
          final textTheme = context.theme.textTheme;
          return StatsChartCard(
            title: lang.obsession,
            subtitle: obsessions.isEmpty ? null : '${lang.mostPlayed} • ${lang.day}',
            icon: Broken.repeat,
            copyText: () => [
              ...obsessions.map((o) => '${o.count}× • ${StatsFormat.day(o.day)}'),
              if (session != null)
                '${lang.longestSession}: ${StatsFormat.durationMS(session.durationMS)} • ${lang.countTracks(count: session.listens)} • ${session.startMS.dateFormattedOriginal}',
            ].join('\n'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (obsessions.isNotEmpty)
                  _buildItemsList(
                    context,
                    s,
                    obsessions.map((o) => StatsRankEntry(o.item, o.count)).toList(),
                    trailingTexts: obsessions.map((o) => StatsFormat.day(o.day)).toList(),
                    listensRangeMS: obsessions.map((o) => (HistoryManager.daysSince1970ToMilliseconds(o.day), HistoryManager.daysSince1970ToMilliseconds(o.day + 1) - 1)).toList(),
                  ),
                if (session != null) ...[
                  const SizedBox(height: 10.0),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6.0, 0.0, 6.0, 6.0),
                    child: Text('${lang.longestSession} • ${session.startMS.dateFormattedOriginal}', style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Wrap(
                    children: [
                      StatsMiniTile(
                        icon: Broken.timer_1,
                        label: '${session.startMS.clockFormatted} → ${session.endMS.clockFormatted}',
                        value: StatsFormat.durationMS(session.durationMS),
                      ),
                      StatsMiniTile(
                        icon: Broken.music_playlist,
                        label: lang.totalListens,
                        value: session.listens.formatDecimal(),
                        onTap: () {
                          if (isYoutube) {
                            YTUtils.onYoutubeHistoryPlaylistTap(initialListen: session.endMS);
                          } else {
                            NamidaOnTaps.inst.onHistoryPlaylistTap(initialListen: session.endMS);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

    // -- discoveries
    cards.add(
      (context) {
        final oldest = s.oldestFavorite;
        final textTheme = context.theme.textTheme;
        final captionStyle = textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600);
        final rangeMS = (HistoryManager.daysSince1970ToMilliseconds(s.firstDay), HistoryManager.daysSince1970ToMilliseconds(s.lastDay + 1) - 1);
        return StatsChartCard(
          title: lang.discoveries,
          subtitle: '${lang.firstListen} • ${StatsFormat.rangeText(s)}',
          icon: Broken.discover,
          copyText: () => [
            '${lang.tracks}: ${s.newItems}',
            '${lang.artists}: ${s.newArtists}',
            ...s.newArtistsTop.map((e) => '${e.key} • ${e.count}'),
          ].join('\n'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                children: [
                  StatsMiniTile(icon: isYoutube ? Broken.video_square : Broken.music_circle, label: itemsLabel, value: s.newItems.formatDecimal()),
                  StatsMiniTile(icon: isYoutube ? Broken.profile_2user : Broken.microphone, label: artistsLabel, value: s.newArtists.formatDecimal()),
                ],
              ),
              if (s.newItemsTop.isNotEmpty) ...[
                const SizedBox(height: 4.0),
                _buildItemsList(
                  context,
                  s,
                  s.newItemsTop.map((e) => StatsRankEntry(e.item, e.count)).toList(),
                  trailingTexts: s.newItemsTop.map((e) => e.firstListenMS.dateFormattedOriginal).toList(),
                  listensRangeMS: rangeMS,
                ),
              ],
              if (s.newArtistsTop.isNotEmpty) ...[
                const SizedBox(height: 8.0),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6.0, 0.0, 6.0, 6.0),
                  child: Text('${lang.top} $artistsLabel • ${lang.firstListen}', style: captionStyle),
                ),
                Wrap(
                  children: s.newArtistsTop
                      .map(
                        (e) => StatsMiniTile(
                          icon: isYoutube ? Broken.profile_2user : Broken.microphone,
                          label: e.count.formatDecimal(),
                          value: e.key,
                          onTap: isYoutube ? null : () => NamidaOnTaps.inst.onArtistTap(e.key, MediaType.artist),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (oldest != null) ...[
                const SizedBox(height: 8.0),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6.0, 0.0, 6.0, 6.0),
                  child: Text('${lang.oldestFavorite} • ${oldest.firstListenMS.dateFormattedOriginal}', style: captionStyle),
                ),
                _buildSingleItem(context, s, oldest.item, oldest.count, listensRangeMS: rangeMS),
              ],
            ],
          ),
        );
      },
    );

    // -- top items
    cards.add(
      (context) {
        if (isYoutube) {
          final items = (s as HistoryStatsSnapshot<String>).topItems;
          return StatsChartCard(
            title: '${lang.top} $itemsLabel',
            icon: Broken.video_square,
            copyText: () => items.map((e) => '${e.key} • ${e.count}').join('\n'),
            child: StatsTopVideosRow(items: items),
          );
        }
        final items = (s as HistoryStatsSnapshot<Track>).topItems;
        final shown = items.length > 10 ? items.sublist(0, 10) : items;
        final queue = shown.map((e) => e.key).toList();
        return StatsChartCard(
          title: '${lang.top} $itemsLabel',
          icon: Broken.music_circle,
          copyText: () => items.map((e) => '${e.key.toTrackExt().originalArtist} - ${e.key.toTrackExt().title} • ${e.count}').join('\n'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              shown.length,
              (i) => StatsTopTrackTile(
                track: shown[i].key,
                index: i,
                count: shown[i].count,
                queue: queue,
                listensRangeMS: (HistoryManager.daysSince1970ToMilliseconds(s.firstDay), HistoryManager.daysSince1970ToMilliseconds(s.lastDay + 1) - 1),
              ),
              growable: false,
            ),
          ),
        );
      },
    );

    // -- most played: artist / album / genre (or channel)
    {
      final rows = <(IconData, String, StatsRankEntry<String>?)>[
        (isYoutube ? Broken.profile_2user : Broken.microphone, isYoutube ? lang.channel : lang.artist, s.topArtists.firstOrNull),
        if (!isYoutube) (Broken.music_dashboard, lang.album, s.topAlbums.firstOrNull),
        if (!isYoutube) (Broken.smileys, lang.genre, s.topGenres.firstOrNull),
      ].where((e) => e.$3 != null).toList();
      if (rows.isNotEmpty) {
        cards.add(
          (context) {
            final textTheme = context.theme.textTheme;
            return StatsChartCard(
              title: lang.mostPlayed,
              icon: Broken.cup,
              copyText: () => rows.map((r) => '${r.$2}: ${r.$3!.key} • ${r.$3!.count}').join('\n'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: rows
                    .map(
                      (r) => NamidaInkWell(
                        borderRadius: 10.0,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                        onTap: isYoutube
                            ? null
                            : () {
                                if (r.$2 == lang.artist) NamidaOnTaps.inst.onArtistTap(r.$3!.key, MediaType.artist);
                                if (r.$2 == lang.genre) NamidaOnTaps.inst.onGenreTap(r.$3!.key);
                              },
                        child: Row(
                          children: [
                            Icon(r.$1, size: 18.0, color: context.defaultIconColor()),
                            const SizedBox(width: 10.0),
                            SizedBox(
                              width: 64.0,
                              child: Text(r.$2, style: textTheme.displaySmall?.copyWith(fontSize: 11.5)),
                            ),
                            Expanded(
                              child: Text(
                                r.$3!.key,
                                style: textTheme.displayMedium?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Text(r.$3!.count.formatDecimal(), style: textTheme.displayMedium?.copyWith(fontSize: 13.0, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        );
      }
    }

    // -- top artists bars
    if (s.topArtists.isNotEmpty) {
      cards.add(
        (context) {
          final all = s.topArtists;
          final shown = _showAllArtists || all.length <= 10 ? all : all.sublist(0, 10);
          final data = shown.map((e) => ChartData(e.key, e.count)).toList(growable: false);
          return StatsChartCard(
            title: '${lang.top} $artistsLabel',
            icon: isYoutube ? Broken.profile_2user : Broken.microphone,
            copyText: () => all.map((e) => '${e.key} • ${e.count}').join('\n'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RankBarsChart(
                  data: data,
                  onTap: isYoutube ? null : (i) => NamidaOnTaps.inst.onArtistTap(shown[i].key, MediaType.artist),
                ),
                if (all.length > 10)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: NamidaInkWell(
                      borderRadius: 6.0,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      onTap: () => setState(() => _showAllArtists = !_showAllArtists),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_showAllArtists) ...[
                            Text(
                              lang.showMore,
                              style: context.theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4.0),
                          ],
                          Icon(_showAllArtists ? Broken.arrow_up_3 : Broken.arrow_down_2, size: 14.0),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    // -- rediscoveries
    if (s.rediscoveries.isNotEmpty) {
      cards.add(
        (context) {
          final rangeMS = (HistoryManager.daysSince1970ToMilliseconds(s.firstDay), HistoryManager.daysSince1970ToMilliseconds(s.lastDay + 1) - 1);
          return StatsChartCard(
            title: lang.rediscoveries,
            subtitle: '${lang.lastListen} > ${lang.countDays(count: HistoryStatsSnapshot.rediscoveryGapDays)}',
            icon: Broken.refresh,
            copyText: () => s.rediscoveries.map((e) => '${e.item} • ${e.count} • ${lang.countDays(count: e.gapDays)}').join('\n'),
            child: _buildItemsList(
              context,
              s,
              s.rediscoveries.map((e) => StatsRankEntry(e.item, e.count)).toList(),
              trailingTexts: s.rediscoveries.map((e) => lang.countDays(count: e.gapDays)).toList(),
              listensRangeMS: rangeMS,
            ),
          );
        },
      );
    }

    // -- completed albums (local)
    if (s.completedAlbums.isNotEmpty) {
      cards.add(
        (context) {
          final textTheme = context.theme.textTheme;
          final shown = s.completedAlbums.length > 10 ? s.completedAlbums.sublist(0, 10) : s.completedAlbums;
          return StatsChartCard(
            title: lang.completedAlbums,
            subtitle: lang.countAlbums(count: s.completedAlbums.length),
            icon: Broken.music_dashboard,
            copyText: () => s.completedAlbums.map((e) => '${e.name} • ${lang.countTracks(count: e.tracks)} • ${e.listens}').join('\n'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: shown
                  .map(
                    (e) => NamidaInkWell(
                      borderRadius: 10.0,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      onTap: () => NamidaOnTaps.inst.onAlbumTap(e.key as AlbumIdentifierWrapper),
                      child: Row(
                        children: [
                          Icon(Broken.music_dashboard, size: 18.0, color: context.defaultIconColor()),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Text(
                              e.name,
                              style: textTheme.displayMedium?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Text(lang.countTracks(count: e.tracks), style: textTheme.displaySmall?.copyWith(fontSize: 11.0)),
                          const SizedBox(width: 8.0),
                          Text(e.listens.formatDecimal(), style: textTheme.displayMedium?.copyWith(fontSize: 13.0, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      );
    }

    // -- genres donut (local), sources donut when imported
    if (s.topGenres.isNotEmpty) {
      cards.add(
        (context) {
          final top = s.topGenres.length > 8 ? s.topGenres.sublist(0, 8) : s.topGenres;
          int other = s.otherGenresListens;
          for (int i = top.length; i < s.topGenres.length; i++) {
            other += s.topGenres[i].count;
          }
          final data = top.map((e) => ChartData(e.key, e.count)).toList(growable: false);
          return StatsChartCard(
            title: lang.genres,
            subtitle: lang.countGenres(count: s.uniqueGenres),
            icon: Broken.smileys,
            copyText: () => s.topGenres.map((e) => '${e.key} • ${e.count}').join('\n'),
            child: DonutChart(
              data: data,
              otherValue: other,
              centerLabel: lang.totalListens,
            ),
          );
        },
      );
    }

    // -- audio quality (local)
    if (s.losslessListens + s.lossyListens > 0 || s.bitrateBuckets.any((e) => e > 0)) {
      cards.add(
        (context) {
          const labels = ['< 128', '128 – 255', '256 – 319', '320+'];
          final buckets = List.generate(4, (i) => ChartData('${labels[i]} kbps', s.bitrateBuckets[i]), growable: false).where((e) => e.value > 0).toList(growable: false);
          final total = s.losslessListens + s.lossyListens;
          final losslessPct = total == 0 ? 0 : (s.losslessListens * 100 / total).round();
          return StatsChartCard(
            title: lang.audio,
            subtitle: total == 0 ? null : '${lang.lossless}: $losslessPct%',
            icon: Broken.audio_square,
            copyText: () => [
              if (total > 0) '${lang.lossless}: ${s.losslessListens} / $total',
              ...buckets.map((e) => '${e.label} • ${e.value}'),
            ].join('\n'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (buckets.isNotEmpty) DonutChart(data: buckets, centerLabel: lang.bitrate),
                if (total > 0) ...[
                  const SizedBox(height: 8.0),
                  Wrap(
                    children: [
                      StatsMiniTile(icon: Broken.musicnote, label: lang.lossless, value: s.losslessListens.formatDecimal()),
                      StatsMiniTile(icon: Broken.music, label: lang.others, value: s.lossyListens.formatDecimal()),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

    if (s.sources.length > 1) {
      cards.add(
        (context) {
          final entries = s.sources.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final data = entries.map((e) => ChartData(_sourceText(e.key), e.value)).toList(growable: false);
          return StatsChartCard(
            title: lang.source,
            icon: Broken.import_1,
            copyText: () => data.map((e) => '${e.label} • ${e.value}').join('\n'),
            child: DonutChart(
              data: data,
              centerLabel: lang.totalListens,
            ),
          );
        },
      );
    }

    // -- gauge: total listen time vs library duration
    if (!isYoutube) {
      cards.add(
        (context) {
          final map = Player.inst.totalListenedTimeInSec;
          final listenSec = (map?[LibraryCategory.localTracks] ?? 0) + (map?[LibraryCategory.localVideos] ?? 0);
          int librarySec = 0;
          for (final tr in Indexer.inst.tracksInfoList.value) {
            librarySec += tr.durationMS;
          }
          librarySec ~/= 1000;
          final fraction = librarySec == 0 ? 0.0 : listenSec / librarySec;
          return StatsChartCard(
            title: lang.totalListenTime,
            subtitle: '${lang.totalTracksDuration}: ${librarySec.secondsFormatted}',
            icon: Broken.timer_1,
            copyText: () => '${lang.totalListenTime}: ${listenSec.secondsFormatted}\n${lang.totalTracksDuration}: ${librarySec.secondsFormatted}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: GaugeChart(
                  fraction: fraction,
                  valueText: listenSec.secondsFormatted,
                  subText: '${(fraction * 100).toStringAsFixed(fraction >= 10 ? 0 : 1)}%',
                  size: 160.0,
                ),
              ),
            ),
          );
        },
      );
    }

    // -- release decades (local)
    if (s.decades.isNotEmpty) {
      cards.add(
        (context) {
          final data = s.decades.map((e) => ChartData('${e.key}s', e.count)).toList(growable: false);
          return StatsChartCard(
            title: lang.year,
            icon: Broken.cake,
            copyText: () => data.map((e) => '${e.label} • ${e.value}').join('\n'),
            child: VerticalBarsChart(data: data, height: 110.0),
          );
        },
      );
    }

    return cards;
  }

  Widget _buildSingleItem(BuildContext context, HistoryStatsSnapshot s, Object item, int count, {(int, int)? listensRangeMS}) {
    if (item is Track) {
      return StatsTopTrackTile(track: item, index: 0, count: count, queue: [item], showIndex: false, listensRangeMS: listensRangeMS);
    }
    if (item is String) {
      return StatsTopVideosRow(items: [StatsRankEntry(item, count)]);
    }
    return const SizedBox();
  }

  Widget _buildItemsList(
    BuildContext context,
    HistoryStatsSnapshot s,
    List<StatsRankEntry> items, {
    List<String>? trailingTexts,
    Object? listensRangeMS,
  }) {
    if (items.isEmpty) return const SizedBox();
    if (items.first.key is String) {
      return StatsTopVideosRow(items: items.map((e) => StatsRankEntry(e.key as String, e.count)).toList(growable: false));
    }
    final tracks = items.map((e) => e.key as Track).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        items.length,
        (i) => StatsTopTrackTile(
          track: tracks[i],
          index: i,
          count: items[i].count,
          queue: tracks,
          showIndex: false,
          trailingText: trailingTexts?[i],
          listensRangeMS: listensRangeMS is List<(int, int)> ? listensRangeMS[i] : listensRangeMS as (int, int)?,
        ),
        growable: false,
      ),
    );
  }

  static String _sourceText(TrackSource source) => switch (source) {
    TrackSource.local => lang.local,
    TrackSource.youtube => lang.youtube,
    TrackSource.youtubeMusic => lang.youtubeMusic,
    TrackSource.lastfm => 'Last.fm',
    TrackSource.spotify => 'Spotify',
    TrackSource.listenbrainz => 'ListenBrainz',
  };

  static Int32List _aligned(HistoryStatsSnapshot s, int firstDay, int lastDay) {
    if (s.firstDay == firstDay && s.lastDay == lastDay) return s.listensPerDay;
    final out = Int32List(lastDay - firstDay + 1);
    final offset = s.firstDay - firstDay;
    for (int i = 0; i < s.listensPerDay.length; i++) {
      final j = i + offset;
      if (j >= 0 && j < out.length) out[j] = s.listensPerDay[i];
    }
    return out;
  }

  static int _sum(Int32List l) {
    int t = 0;
    for (final v in l) {
      t += v;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final cards = _loading ? const <Widget Function(BuildContext)>[] : _buildCards();
    final loadingWidget = Padding(
      padding: EdgeInsets.all(32.0),
      child: Center(
        child: ThreeArchedCircle(
          color: context.theme.colorScheme.secondary.withOpacityExt(0.5),
          size: 48.0,
        ),
      ),
    );
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) return _buildHeader(context);
          if (_loading) return loadingWidget;
          return cards[index - 1](context);
        },
        childCount: 1 + (_loading ? 1 : cards.length),
      ),
    );
  }
}
