import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:known_extents_list_view_builder/sliver_known_extents_list.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:sticky_headers/sticky_headers.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubeHistoryPage extends StatelessWidget {
  const YoutubeHistoryPage({super.key});

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
                              NamidaIconButton(
                                icon: Broken.more,
                                iconSize: 22.0,
                                onPressed: () {},
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
                              final video = videos[i];

                              final info = YoutubeController.inst.fetchVideoDetailsFromCacheSync(video.id);
                              final duration = info?.duration?.inSeconds.secondsLabel;
                              final menuItems = YTUtils.getVideoCardMenuItems(
                                videoId: video.id,
                                url: info?.url,
                                playlistID: const PlaylistID(id: k_PLAYLIST_NAME_HISTORY),
                                idsNamesLookup: {video.id: info?.name},
                              );
                              final backupVideoInfo = YoutubeController.inst.getBackupVideoInfo(video.id);
                              final videoTitle = info?.name ?? backupVideoInfo?.title ?? video.id;
                              final videoSubtitle = info?.uploaderName ?? backupVideoInfo?.channel;
                              final dateText = video.dateTimeAdded.millisecondsSinceEpoch.dateAndClockFormattedOriginal;

                              return Obx(
                                () {
                                  final isCurrentlyPlaying = Player.inst.nowPlayingVideoID == video;
                                  final hightlightedColor = day == YoutubeHistoryController.inst.dayOfHighLight.value && i == YoutubeHistoryController.inst.indexToHighlight.value
                                      ? context.theme.colorScheme.onBackground.withAlpha(40)
                                      : null;
                                  return NamidaPopupWrapper(
                                    openOnTap: false,
                                    childrenDefault: menuItems,
                                    child: NamidaInkWell(
                                      onTap: () {
                                        Player.inst.playOrPause(i, videos, QueueSource.others);
                                      },
                                      height: Dimensions.youtubeCardItemExtent,
                                      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: Dimensions.youtubeCardItemVerticalPadding),
                                      bgColor: isCurrentlyPlaying ? CurrentColor.inst.color.withAlpha(140) : (hightlightedColor ?? context.theme.cardColor),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                                      ),
                                      child: Stack(
                                        children: [
                                          Row(
                                            children: [
                                              const SizedBox(width: Dimensions.youtubeCardItemVerticalPadding),
                                              YoutubeThumbnail(
                                                key: Key(video.id),
                                                isImportantInCache: true,
                                                width: Dimensions.youtubeCardItemHeight * 16 / 9,
                                                height: Dimensions.youtubeCardItemHeight,
                                                videoId: video.id,
                                                onTopWidgets: [
                                                  if (duration != null)
                                                    Positioned(
                                                      bottom: 0.0,
                                                      right: 0.0,
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(3.0),
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                                          child: NamidaBgBlur(
                                                            blur: 2.0,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                                                              color: Colors.black.withOpacity(0.2),
                                                              child: Text(
                                                                duration,
                                                                style: context.textTheme.displaySmall?.copyWith(
                                                                  color: Colors.white.withOpacity(0.8),
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(width: 12.0),
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      videoTitle,
                                                      maxLines: 2,
                                                      style: context.textTheme.displayMedium?.copyWith(
                                                        color: isCurrentlyPlaying ? Colors.white.withOpacity(0.7) : null,
                                                      ),
                                                    ),
                                                    if (videoSubtitle != null)
                                                      Text(
                                                        videoSubtitle,
                                                        maxLines: 1,
                                                        style: context.textTheme.displaySmall?.copyWith(
                                                          color: isCurrentlyPlaying ? Colors.white.withOpacity(0.6) : null,
                                                        ),
                                                      ),
                                                    Text(
                                                      dateText,
                                                      maxLines: 1,
                                                      style: context.textTheme.displaySmall?.copyWith(
                                                        color: isCurrentlyPlaying ? Colors.white.withOpacity(0.5) : null,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12.0),
                                            ],
                                          ),
                                          Positioned(
                                            bottom: 6.0,
                                            right: 12.0,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: YTUtils.getVideoCacheStatusIcons(
                                                context: context,
                                                videoId: video.id,
                                                iconsColor: isCurrentlyPlaying ? Colors.white.withOpacity(0.5) : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: YoutubeHistoryController.inst.historyDays.length,
                ),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: kBottomPadding)),
        ],
      ),
    );
  }
}
