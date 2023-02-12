import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/core/extensions.dart';

class Stats extends StatelessWidget {
  const Stats({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: Language.inst.STATS,
      subtitle: Language.inst.STATS_SUBTITLE,
      icon: Broken.brush_1,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Obx(
          () => Wrap(
            alignment: WrapAlignment.start,
            children: [
              StatsContainerModern(
                icon: Broken.music_circle,
                title: '${Language.inst.TRACKS} :',
                value: Indexer.inst.tracksInfoList.length.toString(),
              ),
              StatsContainerModern(
                icon: Broken.music_dashboard,
                title: '${Language.inst.ALBUMS} :',
                value: Indexer.inst.albumsMap.length.toString(),
              ),
              StatsContainerModern(
                icon: Broken.microphone,
                title: '${Language.inst.ARTISTS} :',
                value: Indexer.inst.groupedArtistsMap.length.toString(),
              ),
              StatsContainerModern(
                icon: Broken.smileys,
                title: '${Language.inst.GENRES} :',
                value: Indexer.inst.groupedGenresMap.length.toString(),
              ),

              // StatsContainerModern(
              //   icon: Broken.profile_2user,
              //   title: Language.inst.ARTISTS + ' :',
              //   value: Indexer.inst.artists.length.toString(),
              // ),
              // StatsContainerModern(
              //   icon: Broken.smileys,
              //   title: Language.inst.GENRES + ' :',
              //   value: Indexer.inst.genres.length.toString(),
              // ),
              // StatsContainerModern(
              //   icon: Broken.microphone,
              //   title: Language.inst.ALBUM_ARTISTS + ' :',
              //   value: Indexer.inst.albumArtists.length.toString(),
              // ),
              // StatsContainerModern(
              //   icon: Broken.refresh,
              //   title: Language.inst.HISTORY + ' :',
              //   value: Indexer.inst.historyPlaylist.tracks.length.toString(),
              // ),

              StatsContainerModern(
                icon: Broken.music_library_2,
                title: '${Language.inst.TOTAL_TRACKS_DURATION} :',
                value: Indexer.inst.tracksInfoList.totalDurationFormatted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatsContainerModern extends StatelessWidget {
  final Widget? child;
  final IconData? icon;
  final String? title;
  final String? value;
  final String? total;

  const StatsContainerModern({super.key, this.child, this.icon, this.title, this.value, this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: context.theme.cardTheme.color?.withAlpha(200),
        borderRadius: BorderRadius.circular(22.0.multipliedRadius),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 5.0),
      child: child ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(
                width: 8.0,
              ),
              Text(title ?? ''),
              const SizedBox(
                width: 8.0,
              ),
              Text(value ?? ''),
              if (total != null) Text(" ${Language.inst.OF} $total")
            ],
          ),
    );
  }
}
