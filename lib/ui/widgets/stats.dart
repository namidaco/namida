import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class StatsPage extends StatelessWidget with NamidaRouteWidget {
  const StatsPage({super.key});

  @override
  RouteType get route => RouteType.PAGE_stats;

  @override
  Widget build(BuildContext context) {
    return const BackgroundWrapper(
      child: Column(
        children: [
          StatsSection(),
        ],
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
                  icon: Broken.music_library_2,
                  title: '${lang.totalTracksDuration} :',
                  value: allTracks.totalDurationFormatted,
                ),
                Obx(
                  (context) {
                    final map = Player.inst.totalListenedTimeInSec;
                    final trSec = map?[LibraryCategory.localTracks] ?? 0;
                    final vidSec = map?[LibraryCategory.localVideos] ?? 0;
                    return StatsContainer(
                      icon: Broken.timer_1,
                      title: '${lang.totalListenTime} :',
                      value: (trSec + vidSec).secondsFormatted,
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
