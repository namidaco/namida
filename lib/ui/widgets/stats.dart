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
      title: Language.inst.STATS,
      subtitle: Language.inst.STATS_SUBTITLE,
      icon: Broken.chart_21,
      child: SizedBox(
        width: context.width,
        child: Obx(
          () => Wrap(
            alignment: WrapAlignment.start,
            children: [
              StatsContainer(
                icon: Broken.music_circle,
                title: '${Language.inst.TRACKS} :',
                value: allTracksInLibrary.length.formatDecimal(),
              ),
              StatsContainer(
                icon: Broken.music_dashboard,
                title: '${Language.inst.ALBUMS} :',
                value: Indexer.inst.mainMapAlbums.value.keys.length.formatDecimal(),
              ),
              StatsContainer(
                icon: Broken.microphone,
                title: '${Language.inst.ARTISTS} :',
                value: Indexer.inst.mainMapArtists.value.length.formatDecimal(),
              ),
              StatsContainer(
                icon: Broken.smileys,
                title: '${Language.inst.GENRES} :',
                value: Indexer.inst.mainMapGenres.value.length.formatDecimal(),
              ),
              StatsContainer(
                icon: Broken.music_library_2,
                title: '${Language.inst.TOTAL_TRACKS_DURATION} :',
                value: allTracksInLibrary.totalDurationFormatted,
              ),
              Obx(
                () => StatsContainer(
                  icon: Broken.timer_1,
                  title: '${Language.inst.TOTAL_LISTEN_TIME} :',
                  value: Player.inst.totalListenedTimeInSec.value.formattedTime,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
