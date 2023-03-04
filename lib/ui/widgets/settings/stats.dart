import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/core/extensions.dart';

class Stats extends StatelessWidget {
  const Stats({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: Language.inst.STATS,
      subtitle: Language.inst.STATS_SUBTITLE,
      icon: Broken.chart_21,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Obx(
          () => Wrap(
            alignment: WrapAlignment.start,
            children: [
              StatsContainer(
                icon: Broken.music_circle,
                title: '${Language.inst.TRACKS} :',
                value: Indexer.inst.tracksInfoList.length.toString(),
              ),
              StatsContainer(
                icon: Broken.music_dashboard,
                title: '${Language.inst.ALBUMS} :',
                value: Indexer.inst.albumsMap.length.toString(),
              ),
              StatsContainer(
                icon: Broken.microphone,
                title: '${Language.inst.ARTISTS} :',
                value: Indexer.inst.groupedArtistsMap.length.toString(),
              ),
              StatsContainer(
                icon: Broken.smileys,
                title: '${Language.inst.GENRES} :',
                value: Indexer.inst.groupedGenresMap.length.toString(),
              ),
              StatsContainer(
                icon: Broken.music_library_2,
                title: '${Language.inst.TOTAL_TRACKS_DURATION} :',
                value: Indexer.inst.tracksInfoList.totalDurationFormatted,
              ),
              Obx(
                () => StatsContainer(
                  icon: Broken.music_library_2,
                  title: '${Language.inst.TOTAL_LISTEN_TIME} :',
                  value: SettingsController.inst.totalListenedTimeInSec.value.getTimeFormatted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
