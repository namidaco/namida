import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class StatsSection extends StatelessWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.STATS,
      subtitle: lang.STATS_SUBTITLE,
      icon: Broken.chart_21,
      child: SizedBox(
        width: context.width,
        child: Obx(
          () => Wrap(
            alignment: WrapAlignment.start,
            children: [
              StatsContainer(
                icon: Broken.music_circle,
                title: '${lang.TRACKS} :',
                value: allTracksInLibrary.length.formatDecimal(),
              ),
              StatsContainer(
                icon: Broken.music_dashboard,
                title: '${lang.ALBUMS} :',
                value: Indexer.inst.mainMapAlbums.value.keys.length.formatDecimal(),
              ),
              StatsContainer(
                icon: Broken.microphone,
                title: '${lang.ARTISTS} :',
                value: Indexer.inst.mainMapArtists.value.length.formatDecimal(),
              ),
              StatsContainer(
                icon: Broken.smileys,
                title: '${lang.GENRES} :',
                value: Indexer.inst.mainMapGenres.value.length.formatDecimal(),
              ),
              StatsContainer(
                icon: Broken.music_library_2,
                title: '${lang.TOTAL_TRACKS_DURATION} :',
                value: allTracksInLibrary.totalDurationFormatted,
              ),
              Obx(
                () {
                  final map = Player.inst.totalListenedTimeInSec;
                  final trSec = map?[LibraryCategory.localTracks] ?? 0;
                  return StatsContainer(
                    icon: Broken.timer_1,
                    title: '${lang.TOTAL_LISTEN_TIME} :',
                    value: trSec.formattedTime,
                  );
                },
              ),
              Obx(
                () {
                  final map = Player.inst.totalListenedTimeInSec;
                  final sec = map?[LibraryCategory.youtube] ?? 0;
                  return StatsContainer(
                    leading: const StackedIcon(
                      baseIcon: Broken.timer_1,
                      secondaryIcon: Broken.video_square,
                      secondaryIconSize: 12.0,
                    ),
                    icon: Broken.timer_1,
                    title: '${lang.TOTAL_LISTEN_TIME} (${lang.YOUTUBE}) :',
                    value: sec.formattedTime,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
