import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:sticky_and_expandable_list/sticky_and_expandable_list.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class _Section implements ExpandableListSection<YoutubeID> {
  final int day;
  const _Section(this.day);

  @override
  List<YoutubeID> getItems() {
    return YoutubeHistoryController.inst.historyMap.value[day] ?? [];
  }

  @override
  bool isSectionExpanded() {
    return true;
  }

  @override
  void setSectionExpanded(bool expanded) {}
}

class YoutubeHistoryPage extends StatelessWidget {
  const YoutubeHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Obx(
        () {
          final days = YoutubeHistoryController.inst.historyDays.toList();
          final sections = days.map((e) => _Section(e)).toList();

          return ExpandableListView(
            builder: SliverExpandableChildDelegate<YoutubeID, _Section>(
                sectionList: sections,
                headerBuilder: (context, sectionIndex, index) {
                  final day = days[sectionIndex];
                  final dayInMs = Duration(days: day).inMilliseconds;
                  return Container(
                    color: context.theme.scaffoldBackgroundColor,
                    padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      width: context.width,
                      height: kHistoryDayHeaderHeight * 1.2,
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
                            offset: const Offset(0, 2.0),
                            blurRadius: 4.0,
                            color: Color.alphaBlend(context.theme.shadowColor.withAlpha(140), context.theme.scaffoldBackgroundColor),
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
                                sections[sectionIndex].getItems().length.displayVideoKeyword,
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
                    ),
                  );
                },
                itemBuilder: (context, sectionIndex, itemIndex, index) {
                  final videos = sections[sectionIndex].getItems();
                  final video = videos[itemIndex];
                  final info = YoutubeController.inst.fetchVideoDetailsFromCacheSync(video.id);
                  final date = video.addedDate?.millisecondsSinceEpoch.dateAndClockFormattedOriginal;
                  final isCurrentlyPlaying = Player.inst.currentIndex == itemIndex && Player.inst.nowPlayingVideoID == video;
                  final menuItems = getVideoCardMenuItems(
                    videoId: video.id,
                    url: info?.url,
                    playlistID: const PlaylistID(id: k_PLAYLIST_NAME_HISTORY),
                    idsNamesLookup: {video.id: info?.name},
                  );
                  return NamidaPopupWrapper(
                    openOnTap: false,
                    childrenDefault: menuItems,
                    child: NamidaInkWell(
                      onTap: () {
                        Player.inst.playOrPause(itemIndex, videos, QueueSource.others);
                      },
                      height: Dimensions.youtubeCardItemExtent,
                      margin: const EdgeInsets.all(4.0),
                      padding: const EdgeInsets.symmetric(vertical: Dimensions.youtubeCardItemVerticalPadding),
                      bgColor: isCurrentlyPlaying ? CurrentColor.inst.color.withAlpha(140) : context.theme.cardColor,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12.0),
                          YoutubeThumbnail(
                            key: Key(video.id),
                            width: Dimensions.youtubeCardItemHeight * 16 / 9,
                            height: Dimensions.youtubeCardItemHeight,
                            videoId: video.id,
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  info?.name ?? video.id,
                                  maxLines: 2,
                                  style: context.textTheme.displayMedium,
                                ),
                                if (info?.uploaderName != null)
                                  Text(
                                    info!.uploaderName!,
                                    maxLines: 1,
                                    style: context.textTheme.displaySmall,
                                  ),
                                if (date != null)
                                  Text(
                                    date,
                                    maxLines: 1,
                                    style: context.textTheme.displaySmall,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12.0),
                        ],
                      ),
                              Positioned(
                                bottom: 0.0,
                                right: 12.0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: YTUtils.getVideoCacheStatusIcons(videoId: video.id),
                                ),
                              ),
                            ],
                          ),
                    ),
                  );
                }),
          );
        },
      ),
    );
  }
}
