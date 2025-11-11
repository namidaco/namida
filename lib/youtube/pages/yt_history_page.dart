import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:sticky_headers/sticky_headers.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';

import 'package:namida/base/history_days_rebuilder.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubeHistoryPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_HISTORY_SUBPAGE;

  const YoutubeHistoryPage({super.key});

  @override
  State<YoutubeHistoryPage> createState() => _YoutubeHistoryPageState();
}

class _YoutubeHistoryPageState extends State<YoutubeHistoryPage> with HistoryDaysRebuilderMixin<YoutubeHistoryPage, YoutubeID, String> {
  @override
  HistoryManager<YoutubeID, String> get historyManager => YoutubeHistoryController.inst;

  void _onYearTap(int year) => onYearTap(year, Dimensions.youtubeCardItemExtent, kYoutubeHistoryDayHeaderHeightWithPadding, addJumpPadding: false);

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    const cardExtent = Dimensions.youtubeCardItemExtent;
    const dayHeaderExtent = kYoutubeHistoryDayHeaderHeightWithPadding;

    const dayHeaderHeight = kYoutubeHistoryDayHeaderHeight;
    final dayHeaderBgColor = Color.alphaBlend(theme.cardColor.withAlpha(100), theme.scaffoldBackgroundColor);
    final dayHeaderSideColor = CurrentColor.inst.color;
    final dayHeaderShadowColor = Color.alphaBlend(theme.shadowColor.withAlpha(160), theme.scaffoldBackgroundColor).withValues(alpha: 0.4);

    final daysLength = historyDays.length;

    final highlightColor = theme.colorScheme.onSurface.withAlpha(40);
    final smallTextStyle = textTheme.displaySmall?.copyWith(fontSize: 12.0);

    final yearsRow = getYearsRowWidget(context, _onYearTap);

    return BackgroundWrapper(
      child: Column(
        children: [
          yearsRow,
          Expanded(
            child: VideoTilePropertiesProvider(
              configs: VideoTilePropertiesConfigs(
                queueSource: QueueSourceYoutubeID.history,
                playlistName: k_PLAYLIST_NAME_HISTORY,
                playlistID: PlaylistID(id: k_PLAYLIST_NAME_HISTORY),
                playlistInfo: () => PlaylistBasicInfo(
                  id: '',
                  title: lang.HISTORY,
                  videosCountText: YoutubeHistoryController.inst.totalHistoryItemsCount.value.displayVideoKeyword,
                  videosCount: YoutubeHistoryController.inst.totalHistoryItemsCount.value,
                  thumbnails: [],
                ),
              ),
              builder: (properties) => CustomScrollView(
                controller: YoutubeHistoryController.inst.scrollController,
                slivers: [
                  ObxO(
                    rx: YoutubeHistoryController.inst.historyMap,
                    builder: (context, history) => ObxO(
                      rx: YoutubeHistoryController.inst.highlightedItem,
                      builder: (context, highlightedItem) => SliverVariedExtentList.builder(
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
                                  queueSource: QueueSourceYoutubeID.history,
                                  context: context,
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
                              physics: const NeverScrollableScrollPhysics(),
                              itemExtent: Dimensions.youtubeCardItemExtent,
                              itemCount: videos.length,
                              itemBuilder: (context, i) {
                                final watch = videos[i];
                                final topRightWidget = listenOrderWidget(watch, watch.id, smallTextStyle, topRightRadius: YTHistoryVideoCardBase.kDefaultBorderRadius);
                                return YTHistoryVideoCard(
                                  properties: properties,
                                  videos: videos,
                                  index: i,
                                  day: day,
                                  bgColor: highlightedItem != null && day == highlightedItem.dayToHighLight && i == highlightedItem.indexOfSmallList ? highlightColor : null,

                                  isImportantInCache: false, // long old history is lowkey useless
                                  topRightWidget: topRightWidget,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  kBottomPaddingWidgetSliver,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
