import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:history_manager/history_manager.dart';
import 'package:intl/intl.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/history_stats.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/history_controller.dart';
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
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/creative_animations.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/stats_charts.dart';
import 'package:namida/ui/widgets/stats_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

// by claude
class YourYearPage extends StatefulWidget with NamidaRouteWidget {
  final int year;
  final bool isYoutube;

  const YourYearPage({super.key, required this.year, this.isYoutube = false});

  @override
  RouteType get route => RouteType.PAGE_yourYear;

  @override
  String? get name => isYoutube ? '${year}_yt' : '$year';

  @override
  State<YourYearPage> createState() => _YourYearPageState();
}

class _YourYearPageState extends State<YourYearPage> {
  late int _year = widget.year;
  late final List<int> _years = widget.isYoutube ? YoutubeHistoryController.inst.getHistoryYears() : HistoryController.inst.getHistoryYears();
  late final PageController _pageController = PageController();

  bool _loading = true;
  int _requestId = 0;
  int _currentPage = 0;
  List<_StoryPage> _pages = const [];

  final _exportKey = GlobalKey();
  int? _exportingIndex;
  double _cardWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void dispose() {
    StatsController.inst.clearCache();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _compute() async {
    final id = ++_requestId;
    if (!_loading) setState(() => _loading = true);
    final range = StatsController.yearRange(_year);
    final local = await StatsController.inst.local(range, monthlyTopYear: _year);
    final yt = await StatsController.inst.youtube(range, monthlyTopYear: _year);
    final prevRange = StatsController.yearRange(_year - 1);
    final HistoryStatsSnapshot prev = widget.isYoutube ? await StatsController.inst.youtubePrevious(prevRange) : await StatsController.inst.localPrevious(prevRange);
    if (id != _requestId || !mounted) return;
    final pages = widget.isYoutube
        ? _buildPages(yt, const _YoutubeStoryAdapter(), local, const _TrackStoryAdapter(), prev, await const _YoutubeStoryAdapter().tint(yt.topItems.firstOrNull?.key))
        : _buildPages(local, const _TrackStoryAdapter(), yt, const _YoutubeStoryAdapter(), prev, await const _TrackStoryAdapter().tint(local.topItems.firstOrNull?.key));
    if (id != _requestId || !mounted) return;
    setState(() {
      _pages = pages;
      _loading = false;
      _currentPage = 0;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  void _selectYear(int year) {
    if (year == _year) return;
    _year = year;
    _compute();
  }

  List<_StoryPage> _buildPages<E, O>(
    HistoryStatsSnapshot<E> s,
    _StoryAdapter<E> a,
    HistoryStatsSnapshot<O> other,
    _StoryAdapter<O> otherAdapter,
    HistoryStatsSnapshot? prev,
    Color baseTint,
  ) {
    final pages = <_StoryPage>[];
    if (s.isEmpty && other.isEmpty) return pages;

    final topItem = s.topItems.firstOrNull?.key;
    final yearText = _year.toString();
    final rangeMS = (HistoryManager.daysSince1970ToMilliseconds(s.firstDay), HistoryManager.daysSince1970ToMilliseconds(s.lastDay + 1) - 1);

    if (!s.isEmpty) {
      // -- intro
      pages.add(
        _StoryPage(
          tint: baseTint,
          builder: (context, style) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang.yourYear(year: yearText), style: style.title),
              if (a.isYoutube) Text(lang.youtube, style: style.subtitle),
              const SizedBox(height: 12.0),
              CAKineticPathReveal(
                points: _monthlyPoints(s),
                height: 110.0,
                minY: 0.0,
                showMarkers: false,
              ),
              const SizedBox(height: 12.0),
              _BigStat(value: s.totalListens.formatDecimal(), label: lang.totalListens, style: style),
              const SizedBox(height: 16.0),
              _BigStat(value: StatsFormat.listenTime(s), label: lang.totalListenTime, style: style),
              const SizedBox(height: 16.0),
              _BigStat(
                value: lang.countDays(count: s.daysWithListens),
                label: lang.days,
                style: style,
              ),
              const SizedBox(height: 16.0),
              _BigStat(value: s.uniqueItems.formatDecimal(), label: a.itemsLabel, style: style),
            ],
          ),
        ),
      );

      // -- top items
      if (s.topItems.isNotEmpty) {
        final shown = s.topItems.length > 5 ? s.topItems.sublist(0, 5) : s.topItems;
        pages.add(
          _StoryPage(
            tint: baseTint,
            builder: (context, style) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${lang.top} ${a.itemsLabel}', style: style.title),
                const SizedBox(height: 16.0),
                a.list(shown, listensRangeMS: rangeMS, big: true),
              ],
            ),
          ),
        );
      }

      // -- top artists / channels
      if (s.topArtists.isNotEmpty) {
        final shown = s.topArtists.length > 8 ? s.topArtists.sublist(0, 8) : s.topArtists;
        final data = shown.map((e) => ChartData(e.key, e.count)).toList(growable: false);
        pages.add(
          _StoryPage(
            tint: baseTint,
            builder: (context, style) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${lang.top} ${a.artistsLabel}', style: style.title),
                const SizedBox(height: 6.0),
                Text('${s.uniqueArtists.formatDecimal()} ${a.artistsLabel}', style: style.subtitle),
                const SizedBox(height: 16.0),
                RankBarsChart(
                  data: data,
                  rowHeight: 32.0,
                  onTap: a.isYoutube ? null : (i) => NamidaOnTaps.inst.onArtistTap(shown[i].key, MediaType.artist),
                ),
                if (s.topAlbums.isNotEmpty || s.topGenres.isNotEmpty) ...[
                  const SizedBox(height: 20.0),
                  Wrap(
                    children: [
                      if (s.topAlbums.isNotEmpty) StatsMiniTile(icon: Broken.music_dashboard, label: lang.album, value: s.topAlbums.first.key),
                      if (s.topGenres.isNotEmpty) StatsMiniTile(icon: Broken.smileys, label: lang.genre, value: s.topGenres.first.key),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }

      // -- genres
      if (s.topGenres.isNotEmpty) {
        final top = s.topGenres.length > 6 ? s.topGenres.sublist(0, 6) : s.topGenres;
        int other = s.otherGenresListens;
        for (int i = top.length; i < s.topGenres.length; i++) {
          other += s.topGenres[i].count;
        }
        final data = top.map((e) => ChartData(e.key, e.count)).toList(growable: false);
        pages.add(
          _StoryPage(
            tint: baseTint,
            builder: (context, style) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.genres, style: style.title),
                const SizedBox(height: 6.0),
                Text(lang.countGenres(count: s.uniqueGenres), style: style.subtitle),
                const SizedBox(height: 16.0),
                DonutChart(data: data, otherValue: other, size: 160.0, centerLabel: lang.totalListens),
              ],
            ),
          ),
        );
      }

      // -- clock
      {
        final weekdayFmt = DateFormat.E();
        final sunday = DateTime(2024, 1, 7);
        final weekdays = List.generate(7, (i) => ChartData(weekdayFmt.format(sunday.add(Duration(days: i))), s.weekdays[i]), growable: false);
        pages.add(
          _StoryPage(
            tint: baseTint,
            builder: (context, style) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.listeningClock, style: style.title),
                const SizedBox(height: 16.0),
                Center(child: ListeningClockChart(hours: s.hours, size: 220.0)),
                const SizedBox(height: 16.0),
                VerticalBarsChart(data: weekdays, height: 90.0),
              ],
            ),
          ),
        );
      }

      // -- heatmap + streak
      {
        final streak = s.longestStreak;
        pages.add(
          _StoryPage(
            tint: baseTint,
            builder: (context, style) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.days, style: style.title),
                const SizedBox(height: 16.0),
                ListensHeatmapChart(values: s.listensPerDay, firstDay: s.firstDay, cellMaxSize: 12.0),
                const SizedBox(height: 20.0),
                if (streak != null)
                  _BigStat(
                    value: lang.countDays(count: streak.days),
                    label: '${lang.longestStreak} • ${StatsFormat.day(streak.startDay)}',
                    style: style,
                  ),
                const SizedBox(height: 12.0),
                _BigStat(value: s.peakDayListens.formatDecimal(), label: '${lang.busiestDay} • ${StatsFormat.day(s.peakDay)}', style: style),
              ],
            ),
          ),
        );
      }

      // -- discoveries
      if (s.newItems > 0 || s.oldestFavorite != null) {
        final oldest = s.oldestFavorite;
        pages.add(
          _StoryPage(
            tint: baseTint,
            builder: (context, style) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.discoveries, style: style.title),
                const SizedBox(height: 6.0),
                Text(lang.firstListen, style: style.subtitle),
                const SizedBox(height: 16.0),
                Row(
                  children: [
                    Expanded(
                      child: _BigStat(value: s.newItems.formatDecimal(), label: a.itemsLabel, style: style),
                    ),
                    Expanded(
                      child: _BigStat(value: s.newArtists.formatDecimal(), label: a.artistsLabel, style: style),
                    ),
                  ],
                ),
                if (s.newItemsTop.isNotEmpty) ...[
                  const SizedBox(height: 12.0),
                  a.list(
                    s.newItemsTop.map((e) => StatsRankEntry(e.item, e.count)).toList(),
                    trailingTexts: s.newItemsTop.map((e) => e.firstListenMS.dateFormattedOriginal).toList(),
                    listensRangeMS: rangeMS,
                  ),
                ],
                if (s.newArtistsTop.isNotEmpty) ...[
                  const SizedBox(height: 12.0),
                  Wrap(
                    children: s.newArtistsTop
                        .take(6)
                        .map(
                          (e) => StatsMiniTile(
                            icon: a.isYoutube ? Broken.profile_2user : Broken.microphone,
                            label: e.count.formatDecimal(),
                            value: e.key,
                            onTap: a.isYoutube ? null : () => NamidaOnTaps.inst.onArtistTap(e.key, MediaType.artist),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (oldest != null) ...[
                  const SizedBox(height: 16.0),
                  Text('${lang.oldestFavorite} • ${oldest.firstListenMS.dateFormattedOriginal}', style: style.subtitle),
                  const SizedBox(height: 10.0),
                  a.item(oldest.item, oldest.count, big: true, listensRangeMS: rangeMS),
                ],
              ],
            ),
          ),
        );
      }

      // -- year in N songs
      final monthly = s.monthlyTop;
      if (monthly != null && monthly.any((e) => e != null)) {
        final monthFmt = DateFormat.MMM();
        final songsCount = monthly.where((e) => e != null).length;
        pages.add(
          _StoryPage(
            tint: baseTint,
            builder: (context, style) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.yearInSongs(count: songsCount), style: style.title),
                const SizedBox(height: 16.0),
                LayoutWidthProvider(
                  builder: (context, maxWidth) {
                    final columns = maxWidth > 360 ? (a.isYoutube ? 3 : 4) : (a.isYoutube ? 2 : 3);
                    final cell = (maxWidth - (columns - 1) * 8.0) / columns;
                    return Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: List.generate(
                        12,
                        (m) => SizedBox(
                          width: cell,
                          child: a.monthCell(monthly[m], monthFmt.format(DateTime(_year, m + 1)), cell),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }

      // -- obsession & session
      if (s.obsessions.isNotEmpty || s.longestSession != null) {
        final obsessions = s.obsessions;
        final session = s.longestSession;
        pages.add(
          _StoryPage(
            tint: baseTint,
            builder: (context, style) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.obsession, style: style.title),
                if (obsessions.isNotEmpty) ...[
                  const SizedBox(height: 6.0),
                  Text('${lang.mostPlayed} • ${lang.day}', style: style.subtitle),
                  const SizedBox(height: 12.0),
                  a.list(
                    obsessions.map((o) => StatsRankEntry(o.item, o.count)).toList(),
                    trailingTexts: obsessions.map((o) => StatsFormat.day(o.day)).toList(),
                    listensRangeMS: rangeMS,
                    big: true,
                  ),
                ],
                if (session != null) ...[
                  const SizedBox(height: 24.0),
                  _BigStat(value: StatsFormat.durationMS(session.durationMS), label: '${lang.longestSession} • ${session.startMS.dateFormattedOriginal}', style: style),
                  const SizedBox(height: 6.0),
                  Text('${session.startMS.clockFormatted} → ${session.endMS.clockFormatted} • ${lang.totalListens}: ${session.listens.formatDecimal()}', style: style.subtitle),
                ],
              ],
            ),
          ),
        );
      }
    }

    // -- habits
    if (!s.isEmpty) {
      final repeatPct = s.totalListens <= 1 ? 0 : (s.repeatListens * 100 / (s.totalListens - 1)).round();
      final itemStreak = s.longestItemStreak;
      final rediscoveries = s.rediscoveries.length > 3 ? s.rediscoveries.sublist(0, 3) : s.rediscoveries;
      pages.add(
        _StoryPage(
          tint: baseTint,
          builder: (context, style) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang.habits, style: style.title),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: _BigStat(value: '$repeatPct%', label: lang.repeatRate, style: style),
                  ),
                  Expanded(
                    child: _BigStat(
                      value: '${s.heavyRotationItems.formatDecimal()} ${a.itemsLabel}',
                      label: '${lang.totalListens} ≥ ${HistoryStatsSnapshot.heavyRotationCount}',
                      style: style,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: _BigStat(value: statsMinuteOfDay(s.avgFirstMinute), label: lang.firstListen, style: style),
                  ),
                  Expanded(
                    child: _BigStat(value: statsMinuteOfDay(s.avgLastMinute), label: lang.lastListen, style: style),
                  ),
                ],
              ),
              if (s.completedAlbums.isNotEmpty) ...[
                const SizedBox(height: 12.0),
                _BigStat(
                  value: lang.countAlbums(count: s.completedAlbums.length),
                  label: lang.completedAlbums,
                  style: style,
                ),
              ],
              if (itemStreak != null) ...[
                const SizedBox(height: 16.0),
                Text('${lang.streak} • ${lang.countDays(count: itemStreak.days)}', style: style.subtitle),
                const SizedBox(height: 10.0),
                a.item(itemStreak.item, s.topItems.firstWhereEff((e) => e.key == itemStreak.item)?.count ?? itemStreak.days, big: true, listensRangeMS: rangeMS),
              ],
              if (rediscoveries.isNotEmpty) ...[
                const SizedBox(height: 16.0),
                Text(lang.rediscoveries, style: style.subtitle),
                const SizedBox(height: 10.0),
                a.list(
                  rediscoveries.map((e) => StatsRankEntry(e.item, e.count)).toList(),
                  trailingTexts: rediscoveries.map((e) => lang.countDays(count: e.gapDays)).toList(),
                  listensRangeMS: rangeMS,
                ),
              ],
            ],
          ),
        ),
      );
    }

    // -- other source
    if (!other.isEmpty) {
      final shown = other.topItems.length > 5 ? other.topItems.sublist(0, 5) : other.topItems;
      pages.add(
        _StoryPage(
          tint: baseTint,
          builder: (context, style) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(otherAdapter.isYoutube ? lang.youtube : lang.local, style: style.title),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: _BigStat(value: other.totalListens.formatDecimal(), label: lang.totalListens, style: style),
                  ),
                  Expanded(
                    child: _BigStat(value: StatsFormat.listenTime(other), label: lang.totalListenTime, style: style),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: _BigStat(value: other.uniqueItems.formatDecimal(), label: otherAdapter.itemsLabel, style: style),
                  ),
                  Expanded(
                    child: _BigStat(value: other.uniqueArtists.formatDecimal(), label: otherAdapter.artistsLabel, style: style),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              otherAdapter.list(shown),
            ],
          ),
        ),
      );
    }

    // -- summary
    if (!s.isEmpty) {
      pages.add(
        _StoryPage(
          tint: baseTint,
          builder: (context, style) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang.yourYear(year: yearText), style: style.title),
              const SizedBox(height: 20.0),
              if (topItem != null) ...[
                Center(child: a.hero(topItem)),
                const SizedBox(height: 8.0),
                Center(
                  child: Text(
                    a.title(topItem),
                    style: style.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 20.0),
              ],
              Row(
                children: [
                  Expanded(
                    child: _BigStat(value: s.totalListens.formatDecimal(), label: lang.totalListens, style: style),
                  ),
                  Expanded(
                    child: _BigStat(value: StatsFormat.listenTime(s), label: lang.totalListenTime, style: style),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: _BigStat(value: s.topArtists.firstOrNull?.key ?? '', label: '${lang.top} ${a.isYoutube ? lang.channel : lang.artist}', style: style),
                  ),
                  Expanded(
                    child: s.topGenres.isNotEmpty
                        ? _BigStat(value: s.topGenres.first.key, label: lang.genre, style: style)
                        : s.topAlbums.isNotEmpty
                        ? _BigStat(value: s.topAlbums.first.key, label: lang.album, style: style)
                        : _BigStat(value: s.uniqueItems.formatDecimal(), label: a.itemsLabel, style: style),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: _BigStat(
                      value: lang.countDays(count: s.daysWithListens),
                      label: lang.days,
                      style: style,
                    ),
                  ),
                  Expanded(
                    child: _BigStat(
                      value: lang.countDays(count: s.longestStreak?.days ?? 0),
                      label: lang.longestStreak,
                      style: style,
                    ),
                  ),
                ],
              ),
              if (prev != null && !prev.isEmpty) ...[
                const SizedBox(height: 20.0),
                Text('${lang.previous} • ${_year - 1}', style: style.subtitle),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _BigStat(value: prev.totalListens.formatDecimal(), label: lang.totalListens, style: style),
                          const SizedBox(width: 8.0),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: StatsDelta(now: s.totalListens, previous: prev.totalListens),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _BigStat(value: prev.topArtists.firstOrNull?.key ?? '', label: '${lang.top} ${a.isYoutube ? lang.channel : lang.artist}', style: style),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    return pages;
  }

  static List<KineticDataPoint> _monthlyPoints(HistoryStatsSnapshot s) {
    final months = List.filled(12, 0);
    final start = HistoryManager.daysSince1970ToDate(s.firstDay);
    var monthIndex = start.month - 1;
    var nextMonthDay = DateTime(start.year, start.month + 1).toDaysSince1970();
    for (int i = 0; i < s.listensPerDay.length; i++) {
      final day = s.firstDay + i;
      while (day >= nextMonthDay && monthIndex < 11) {
        monthIndex++;
        final d = HistoryManager.daysSince1970ToDate(nextMonthDay);
        nextMonthDay = DateTime(d.year, d.month + 1).toDaysSince1970();
      }
      months[monthIndex] += s.listensPerDay[i];
    }
    int peak = 0;
    for (int i = 1; i < 12; i++) {
      if (months[i] > months[peak]) peak = i;
    }
    final fmt = DateFormat.MMM();
    return List.generate(
      12,
      (i) => KineticDataPoint(
        x: i.toDouble(),
        y: months[i].toDouble(),
        label: i == peak && months[i] > 0 ? '${fmt.format(DateTime(2024, i + 1))} • ${months[i].formatDecimal()}' : null,
      ),
      growable: false,
    );
  }

  Future<void> _exportCurrent() async {
    if (_currentPage < 0 || _currentPage >= _pages.length) return;
    if (_exportingIndex != null) return;
    setState(() => _exportingIndex = _currentPage);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      final dir = Directory(FileParts.joinPath(AppDirs.APP_CACHE, 'stats_export'));
      await dir.create(recursive: true);
      final file = File(FileParts.joinPath(dir.path, 'namida_${_year}_${_currentPage + 1}.png'));
      await file.writeAsBytes(Uint8List.sublistView(bytes));
      await NamidaUtils.shareFiles([file.path]);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _exportingIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return BackgroundWrapper(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 8.0, 8.0, 4.0),
            child: Row(
              children: [
                if (widget.isYoutube) ...[
                  Icon(Broken.video_square, size: 18.0, color: context.defaultIconColor()),
                  const SizedBox(width: 8.0),
                ],
                Expanded(
                  child: SmoothSingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _years
                          .map(
                            (y) => StatsPeriodChip(
                              text: y.toString(),
                              isActive: y == _year,
                              onTap: () => _selectYear(y),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                NamidaIconButton(
                  icon: Broken.share,
                  iconSize: 20.0,
                  onPressed: _exportCurrent,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: ThreeArchedCircle(
                      color: theme.colorScheme.secondary.withOpacityExt(0.5),
                      size: 48.0,
                    ),
                  )
                : _pages.isEmpty
                ? const StatsEmptyHint()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      _cardWidth = math.min(480.0, constraints.maxWidth - 24.0);
                      final exporting = _exportingIndex;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            clipBehavior: Clip.none,
                            itemCount: _pages.length,
                            onPageChanged: (i) => setState(() => _currentPage = i),
                            itemBuilder: (context, index) => _pages[index].build(context, _year),
                          ),
                          // -- rendered off-screen only while exporting, so the png holds the whole page instead of the visible part.
                          if (exporting != null && exporting < _pages.length)
                            Positioned(
                              left: -_cardWidth * 4,
                              top: 0.0,
                              width: _cardWidth,
                              child: IgnorePointer(
                                child: MediaQuery(
                                  data: MediaQuery.of(context).copyWith(disableAnimations: true),
                                  child: _pages[exporting].buildForExport(context, _year, _cardWidth, _exportKey),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          if (!_loading && _pages.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6.0, bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => TapDetector(
                    onTap: () => _pageController.animateToPage(i, duration: const Duration(milliseconds: 500), curve: Curves.fastEaseInToSlowEaseOut),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3.0),
                      width: i == _currentPage ? 18.0 : 6.0,
                      height: 6.0,
                      decoration: BoxDecoration(
                        color: i == _currentPage ? CurrentColor.inst.color : textTheme.displaySmall?.color?.withOpacityExt(0.25),
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(height: Dimensions.inst.globalBottomPaddingTotalR),
        ],
      ),
    );
  }
}

// ======================================== adapters ========================================

abstract class _StoryAdapter<E> {
  const _StoryAdapter();

  bool get isYoutube;
  String get itemsLabel;
  String get artistsLabel;

  /// one tint for the whole year, extracted from the top item artwork.
  Future<Color> tint(E? item);
  String title(E item);
  Widget hero(E item);
  Widget item(E item, int count, {bool big = false, String? trailingText, (int, int)? listensRangeMS});
  Widget list(List<StatsRankEntry<E>> items, {List<String>? trailingTexts, (int, int)? listensRangeMS, bool big = false});
  Widget monthCell(StatsRankEntry<E>? entry, String label, double size);
}

class _TrackStoryAdapter extends _StoryAdapter<Track> {
  const _TrackStoryAdapter();

  @override
  bool get isYoutube => false;

  @override
  String get itemsLabel => lang.tracks;

  @override
  String get artistsLabel => lang.artists;

  @override
  Future<Color> tint(Track? item) async {
    if (item == null) return CurrentColor.inst.color;
    final sync = CurrentColor.inst.getTrackColorsSync(item, networkArtworkInfo: null)?.color;
    if (sync != null) return sync;
    return (await CurrentColor.inst.getTrackColors(item, networkArtworkInfo: null, useIsolate: true)).color;
  }

  @override
  String title(Track item) {
    final ext = item.toTrackExt();
    return '${ext.originalArtist} - ${ext.title}';
  }

  @override
  Widget hero(Track item) => ArtworkWidget(
    key: Key(item.path),
    track: item,
    path: item.pathToImage,
    thumbnailSize: 160.0,
    forceSquared: true,
    borderRadius: 16.0,
    blur: 0.0,
  );

  @override
  Widget item(Track item, int count, {bool big = false, String? trailingText, (int, int)? listensRangeMS}) => StatsTopTrackTile(
    track: item,
    index: 0,
    count: count,
    queue: [item],
    showIndex: false,
    thumbnailSize: big ? 60.0 : 42.0,
    trailingText: trailingText,
    listensRangeMS: listensRangeMS,
  );

  @override
  Widget list(List<StatsRankEntry<Track>> items, {List<String>? trailingTexts, (int, int)? listensRangeMS, bool big = false}) {
    final queue = items.map((e) => e.key).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        items.length,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: StatsTopTrackTile(
            track: items[i].key,
            index: i,
            count: items[i].count,
            queue: queue,
            showIndex: trailingTexts == null,
            thumbnailSize: big ? (i == 0 ? 64.0 : 48.0) : 42.0,
            trailingText: trailingTexts?[i],
            listensRangeMS: listensRangeMS,
          ),
        ),
        growable: false,
      ),
    );
  }

  @override
  Widget monthCell(StatsRankEntry<Track>? entry, String label, double size) => _MonthCell(
    label: label,
    size: size,
    height: size,
    count: entry?.count,
    title: entry?.key.toTrackExt().title,
    onTap: entry == null ? null : () => Player.inst.playOrPause(0, [entry.key], QueueSource.mostPlayed),
    onLongPress: entry == null ? null : () => NamidaDialogs.inst.showTrackDialog(entry.key, source: QueueSource.mostPlayed, index: 0),
    child: entry == null
        ? null
        : ArtworkWidget(
            key: Key(entry.key.path),
            track: entry.key,
            path: entry.key.pathToImage,
            thumbnailSize: size,
            forceSquared: true,
            borderRadius: 10.0,
            blur: 0.0,
          ),
  );
}

class _YoutubeStoryAdapter extends _StoryAdapter<String> {
  const _YoutubeStoryAdapter();

  @override
  bool get isYoutube => true;

  @override
  String get itemsLabel => lang.videos;

  @override
  String get artistsLabel => lang.channels;

  @override
  Future<Color> tint(String? item) async => CurrentColor.inst.color;

  @override
  String title(String item) => YoutubeInfoController.utils.getVideoNameSync(item) ?? item;

  @override
  Widget hero(String item) => YoutubeThumbnail(
    key: Key(item),
    videoId: item,
    type: ThumbnailType.video,
    width: 240.0,
    height: 135.0,
    borderRadius: 14.0,
    isImportantInCache: false,
  );

  @override
  Widget item(String item, int count, {bool big = false, String? trailingText, (int, int)? listensRangeMS}) => StatsTopVideosRow(items: [StatsRankEntry(item, count)]);

  @override
  Widget list(List<StatsRankEntry<String>> items, {List<String>? trailingTexts, (int, int)? listensRangeMS, bool big = false}) => StatsTopVideosRow(items: items);

  @override
  Widget monthCell(StatsRankEntry<String>? entry, String label, double size) => _MonthCell(
    label: label,
    size: size,
    height: size * 9 / 16,
    count: entry?.count,
    title: entry == null ? null : title(entry.key),
    onTap: entry == null ? null : () => Player.inst.playOrPause(0, [YoutubeID(id: entry.key, playlistID: null)], QueueSourceYoutubeID.ytMostPlayed),
    child: entry == null
        ? null
        : YoutubeThumbnail(
            key: Key(entry.key),
            videoId: entry.key,
            type: ThumbnailType.video,
            width: size,
            height: size * 9 / 16,
            borderRadius: 10.0,
            isImportantInCache: false,
          ),
  );
}

// ======================================== pieces ========================================

class _StoryStyle {
  final TextStyle title;
  final TextStyle subtitle;
  final TextStyle bigValue;
  final TextStyle label;

  const _StoryStyle({
    required this.title,
    required this.subtitle,
    required this.bigValue,
    required this.label,
  });
}

class _StoryPage {
  final Color tint;
  final Widget Function(BuildContext context, _StoryStyle style) builder;
  final GlobalKey key = GlobalKey();

  _StoryPage({required this.tint, required this.builder});

  static const _radius = 24.0;
  static const _contentPadding = EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 48.0);

  _StoryStyle _style(BuildContext context) {
    final textTheme = context.theme.textTheme;
    return _StoryStyle(
      title: textTheme.displayLarge!.copyWith(fontSize: 28.0, fontWeight: FontWeight.w800),
      subtitle: textTheme.displayMedium!.copyWith(fontSize: 13.5, color: textTheme.displayMedium!.color?.withOpacityExt(0.8)),
      bigValue: textTheme.displayLarge!.copyWith(fontSize: 26.0, fontWeight: FontWeight.w700),
      label: textTheme.displaySmall!.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
    );
  }

  Widget _card(BuildContext context, int year, {required Widget content, required bool clipContent}) {
    final theme = context.theme;
    final bg = Color.alphaBlend(tint.withOpacityExt(theme.brightness == Brightness.dark ? 0.16 : 0.12), theme.scaffoldBackgroundColor);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_radius.multipliedRadius),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(40),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220.0,
              height: 220.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withOpacityExt(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -40,
            child: Container(
              width: 200.0,
              height: 200.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withOpacityExt(0.07),
              ),
            ),
          ),
          if (clipContent) Positioned.fill(child: content) else content,
          Positioned(
            bottom: 0.0,
            right: 0.0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14.0, 8.0, 16.0, 10.0),
              decoration: BoxDecoration(
                color: Color.alphaBlend(tint.withOpacityExt(0.2), theme.cardColor),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(_radius.multipliedRadius)),
              ),
              child: StatsWatermark(text: 'Namida • $year'),
            ),
          ),
        ],
      ),
    );
  }

  Widget build(BuildContext context, int year) {
    final style = _style(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0).add(EdgeInsetsGeometry.only(top: 8.0)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480.0),
          child: RepaintBoundary(
            key: key,
            child: _card(
              context,
              year,
              clipContent: true,
              content: LayoutBuilder(
                builder: (context, constraints) => SmoothSingleChildScrollView(
                  padding: _contentPadding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 72.0),
                    child: builder(context, style),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// full height, nothing scrolls, so the whole page fits in one image.
  Widget buildForExport(BuildContext context, int year, double width, GlobalKey exportKey) {
    final style = _style(context);
    return SizedBox(
      width: width,
      child: RepaintBoundary(
        key: exportKey,
        child: _card(
          context,
          year,
          clipContent: false,
          content: Padding(
            padding: _contentPadding,
            child: builder(context, style),
          ),
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final _StoryStyle style;

  const _BigStat({required this.value, required this.label, required this.style});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: style.bigValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: style.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  final String label;
  final double size;
  final double height;
  final int? count;
  final String? title;
  final Widget? child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _MonthCell({
    required this.label,
    required this.size,
    required this.height,
    required this.count,
    required this.title,
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NamidaInkWell(
          borderRadius: 10.0,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              child ??
                  Container(
                    width: size,
                    height: height,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacityExt(0.06),
                      borderRadius: BorderRadius.circular(10.0.multipliedRadius),
                    ),
                  ),
              Positioned(
                top: 4.0,
                left: 4.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor.withOpacityExt(0.85),
                    borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                  ),
                  child: Text(
                    label,
                    style: textTheme.displaySmall?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          title ?? label,
          style: textTheme.displaySmall?.copyWith(fontSize: 11.0, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (count != null)
          Text(
            count!.formatDecimal(),
            style: textTheme.displaySmall?.copyWith(fontSize: 10.0),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
