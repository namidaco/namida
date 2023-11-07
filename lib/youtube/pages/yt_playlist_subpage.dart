import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/ui/pages/subpages/most_played_subpage.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';

class MostPlayedYTVideosPage extends StatelessWidget {
  const MostPlayedYTVideosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final videos = YoutubeHistoryController.inst.currentMostPlayedTracks.toList();
        return MostPlayedItemsPage(
          itemExtents: List.filled(videos.length, Dimensions.youtubeCardItemExtent),
          historyController: YoutubeHistoryController.inst,
          customDateRange: settings.ytMostPlayedCustomDateRange,
          isTimeRangeChipEnabled: (type) => type == settings.ytMostPlayedTimeRange.value,
          onSavingTimeRange: ({dateCustom, isStartOfDay, mptr}) {
            settings.save(
              ytMostPlayedTimeRange: mptr,
              ytMostPlayedCustomDateRange: dateCustom,
              ytMostPlayedCustomisStartOfDay: isStartOfDay,
            );
          },
          header: (timeRangeChips, bottomPadding) {
            return Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: timeRangeChips,
            );
          },
          itemBuilder: (context, i, listensMap) {
            final videoID = videos[i];
            final listens = listensMap[videoID] ?? [];

            return YTHistoryVideoCard(
              key: Key("${videoID}_$i"),
              videos: videos
                  .map(
                    (e) => YoutubeID(
                      id: e,
                      playlistID: const PlaylistID(id: k_PLAYLIST_NAME_MOST_PLAYED),
                    ),
                  )
                  .toList(),
              index: i,
              day: null,
              overrideListens: listens,
            );
          },
        );
      },
    );
  }
}
