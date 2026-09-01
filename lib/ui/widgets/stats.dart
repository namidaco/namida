import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/creative_animations.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class StatsPage extends StatelessWidget with NamidaRouteWidget {
  const StatsPage({super.key});

  @override
  RouteType get route => RouteType.PAGE_stats;

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: Dimensions.inst.globalBottomPaddingTotalR),
        child: Column(
          children: [
            const StatsSection(),
            if (kEnableFancyAnimations) const ListensTrendSection(),
          ],
        ),
      ),
    );
  }
}

class StatsSection extends StatelessWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.stats,
      subtitle: lang.statsSubtitle,
      icon: Broken.chart_21,
      child: SizedBox(
        width: context.width,
        child: Obx(
          (context) {
            final allTracks = Indexer.inst.tracksInfoList.valueR;
            return Wrap(
              alignment: WrapAlignment.start,
              children: [
                StatsContainer(
                  icon: Broken.music_circle,
                  title: '${lang.tracks} :',
                  value: allTracks.length.formatDecimal(),
                ),
                StatsContainer(
                  icon: Broken.music_dashboard,
                  title: '${lang.albums} :',
                  value: Indexer.inst.mainMapAlbums.valueR.keys.length.formatDecimal(),
                ),
                StatsContainer(
                  icon: Broken.microphone,
                  title: '${lang.artists} :',
                  value: Indexer.inst.mainMapArtists.valueR.length.formatDecimal(),
                ),
                StatsContainer(
                  icon: Broken.smileys,
                  title: '${lang.genres} :',
                  value: Indexer.inst.mainMapGenres.valueR.length.formatDecimal(),
                ),
                StatsContainer(
                  icon: Broken.brush_1,
                  title: '${lang.styles} :',
                  value: Indexer.inst.mainMapStyles.valueR.length.formatDecimal(),
                ),
                StatsContainer(
                  icon: Broken.music_library_2,
                  title: '${lang.totalTracksDuration} :',
                  value: allTracks.totalDurationFormatted,
                ),
                Obx(
                  (context) {
                    final map = Player.inst.totalListenedTimeInSec;
                    final trSec = map?[LibraryCategory.localTracks] ?? 0;
                    final vidSec = map?[LibraryCategory.localVideos] ?? 0;
                    final totalSec = trSec + vidSec;
                    return StatsContainer(
                      icon: Broken.timer_1,
                      title: '${lang.totalListenTime} :',
                      value: totalSec.secondsFormatted,
                      valueWidget: kEnableFancyAnimations ? _ListenTimeOdometer(seconds: totalSec) : null,
                    );
                  },
                ),
                Obx(
                  (context) {
                    final map = Player.inst.totalListenedTimeInSec;
                    final sec = map?[LibraryCategory.youtube] ?? 0;
                    return StatsContainer(
                      leading: const StackedIcon(
                        baseIcon: Broken.timer_1,
                        secondaryIcon: Broken.video_square,
                        secondaryIconSize: 12.0,
                      ),
                      icon: Broken.timer_1,
                      title: '${lang.totalListenTime} (${lang.youtube}) :',
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
class ListensTrendSection extends StatefulWidget {
  const ListensTrendSection({super.key});

  @override
  State<ListensTrendSection> createState() => _ListensTrendSectionState();
}

class _ListensTrendSectionState extends State<ListensTrendSection> {
  static const _days = 30;

  late final List<KineticDataPoint> _points;
  int _peakListens = 0;

  @override
  void initState() {
    super.initState();
    _points = _buildPoints();
  }

  List<KineticDataPoint> _buildPoints() {
    final historyMap = HistoryController.inst.historyMap.value;
    final today = DateTime.now().toDaysSince1970();

    final points = <KineticDataPoint>[];
    int peakDay = -1;
    for (int i = _days - 1; i >= 0; i--) {
      final day = today - i;
      final listens = historyMap[day]?.length ?? 0;
      if (listens > _peakListens) {
        _peakListens = listens;
        peakDay = _days - 1 - i;
      }
      points.add(KineticDataPoint(x: (_days - 1 - i).toDouble(), y: listens.toDouble()));
    }

    // -- only the peak gets a label, anything more turns the line into a wall of text.
    if (peakDay >= 0 && _peakListens > 0) {
      points[peakDay] = KineticDataPoint(
        x: points[peakDay].x,
        y: points[peakDay].y,
        label: lang.countTracks(count: _peakListens),
      );
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    if (_peakListens <= 0) return const SizedBox();
    return SettingsCard(
      title: lang.totalListens,
      subtitle: lang.countDays(count: _days),
      icon: Broken.chart_success,
      child: Padding(
        padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
        child: CAKineticPathReveal(
          points: _points,
          height: 150.0,
          minY: 0.0,
        ),
      ),
    );
  }
}
