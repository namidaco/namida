import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:known_extents_list_view_builder/sliver_known_extents_list.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:sticky_headers/sticky_headers.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubeHistoryPage extends StatefulWidget {
  const YoutubeHistoryPage({super.key});

  @override
  State<YoutubeHistoryPage> createState() => _YoutubeHistoryPageState();
}

class _YoutubeHistoryPageState extends State<YoutubeHistoryPage> {
  @override
  void initState() {
    super.initState();
    YoutubeHistoryController.inst.canUpdateAllItemsExtentsInHistory = true;
    YoutubeHistoryController.inst.calculateAllItemsExtentsInHistory();
  }

  @override
  void dispose() {
    YoutubeHistoryController.inst.canUpdateAllItemsExtentsInHistory = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: CustomScrollView(
        controller: YoutubeHistoryController.inst.scrollController,
        slivers: [
          Obx(
            () {
              final days = YoutubeHistoryController.inst.historyDays.toList();
              return SliverKnownExtentsList(
                key: UniqueKey(),
                itemExtents: YoutubeHistoryController.inst.allItemsExtentsHistory,
                delegate: SliverChildBuilderDelegate(
                  childCount: YoutubeHistoryController.inst.historyDays.length,
                  (context, index) {
                    final day = days[index];
                    final dayInMs = Duration(days: day).inMilliseconds;
                    final videos = YoutubeHistoryController.inst.historyMap.value[day] ?? [];

                    return StickyHeaderBuilder(
                      key: ValueKey(index),
                      builder: (context, stuckAmount) {
                        return Container(
                          clipBehavior: Clip.antiAlias,
                          width: context.width,
                          height: kYoutubeHistoryDayHeaderHeight,
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(context.theme.cardColor.withAlpha(100), context.theme.scaffoldBackgroundColor),
                            border: Border(
                              left: BorderSide(
                                color: CurrentColor.inst.color,
                                width: (4.0).withMinimum(3.0),
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                offset: const Offset(0, 8.0),
                                blurRadius: 12.0,
                                spreadRadius: 2.0,
                                color: Color.alphaBlend(context.theme.shadowColor.withAlpha(180), context.theme.scaffoldBackgroundColor).withOpacity(0.4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Text(
                                  [
                                    dayInMs.dateFormattedOriginal,
                                    videos.length.displayVideoKeyword,
                                  ].join('  •  '),
                                  style: context.textTheme.displayMedium,
                                ),
                              ),
                              NamidaPopupWrapper(
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
                              const SizedBox(width: 2.0),
                            ],
                          ),
                        );
                      },
                      content: Obx(
                        () => SizedBox(
                          height: YoutubeHistoryController.inst.allItemsExtentsHistory[index],
                          width: context.width,
                          child: ListView.builder(
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
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          kBottomPaddingWidgetSliver,
        ],
      ),
    );
  }
}
