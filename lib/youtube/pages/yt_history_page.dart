import 'package:flutter/material.dart';
import 'package:history_manager/history_manager.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:sticky_headers/sticky_headers.dart';

import 'package:namida/base/history_days_rebuilder.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubeHistoryPage extends StatefulWidget {
  const YoutubeHistoryPage({super.key});

  @override
  State<YoutubeHistoryPage> createState() => _YoutubeHistoryPageState();
}

class _YoutubeHistoryPageState extends State<YoutubeHistoryPage> with HistoryDaysRebuilderMixin<YoutubeHistoryPage, YoutubeID, String> {
  @override
  HistoryManager<YoutubeID, String> get historyManager => YoutubeHistoryController.inst;

  @override
  Widget build(BuildContext context) {
    const cardExtent = Dimensions.youtubeCardItemExtent;
    const dayHeaderExtent = kYoutubeHistoryDayHeaderHeightWithPadding;

    const dayHeaderHeight = kYoutubeHistoryDayHeaderHeight;
    final dayHeaderBgColor = Color.alphaBlend(context.theme.cardColor.withAlpha(100), context.theme.scaffoldBackgroundColor);
    final dayHeaderSideColor = CurrentColor.inst.color;
    final dayHeaderShadowColor = Color.alphaBlend(context.theme.shadowColor.withAlpha(160), context.theme.scaffoldBackgroundColor).withOpacity(0.4);

    final daysLength = historyDays.length;

    return BackgroundWrapper(
      child: CustomScrollView(
        controller: YoutubeHistoryController.inst.scrollController,
        slivers: [
          ObxO(
            rx: YoutubeHistoryController.inst.historyMap,
            builder: (history) => SliverVariedExtentList.builder(
              key: ValueKey(daysLength), // rebuild after adding/removing day
              itemExtentBuilder: (index, dimensions) {
                final day = historyDays[index];
                return YoutubeHistoryController.inst.dayToSectionExtent(day, cardExtent, dayHeaderExtent);
              },
              itemCount: daysLength,
              itemBuilder: (context, index) {
                final day = historyDays[index];
                final dayInMs = super.dayToMillis(day);
                final videos = history[day] ?? [];

                return StickyHeader(
                  key: ValueKey(index),
                  header: NamidaHistoryDayHeaderBox(
                    height: dayHeaderHeight,
                    title: [
                      dayInMs.dateFormattedOriginal,
                      videos.length.displayVideoKeyword,
                    ].join('  •  '),
                    sideColor: dayHeaderSideColor,
                    bgColor: dayHeaderBgColor,
                    shadowColor: dayHeaderShadowColor,
                    menu: NamidaPopupWrapper(
                      openOnLongPress: false,
                      childrenDefault: () => YTUtils.getVideosMenuItems(
                        playlistName: k_PLAYLIST_NAME_HISTORY,
                        videos: videos,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(
                          Broken.more,
                          size: 22.0,
                        ),
                      ),
                    ),
                  ),
                  content: ListView.builder(
                    padding: const EdgeInsets.only(bottom: kYoutubeHistoryDayListBottomPadding, top: kYoutubeHistoryDayListTopPadding),
                    primary: false,
                    itemExtent: Dimensions.youtubeCardItemExtent,
                    itemCount: videos.length,
                    itemBuilder: (context, i) {
                      return YTHistoryVideoCard(
                        videos: videos,
                        index: i,
                        day: day,
                        playlistID: const PlaylistID(id: k_PLAYLIST_NAME_HISTORY),
                        playlistName: k_PLAYLIST_NAME_HISTORY,
                        isImportantInCache: false, // long old history is lowkey useless
                      );
                    },
                  ),
                );
              },
            ),
          ),
          kBottomPaddingWidgetSliver,
        ],
      ),
    );
  }
}
