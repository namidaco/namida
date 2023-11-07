import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class YTHistoryVideoCard extends StatelessWidget {
  final List<YoutubeID> videos;
  final int? day;
  final int index;
  final List<int> overrideListens;

  const YTHistoryVideoCard({
    super.key,
    required this.videos,
    required this.day,
    required this.index,
    this.overrideListens = const [],
  });

  @override
  Widget build(BuildContext context) {
    final video = videos[index];
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
        final sameDay = day == YoutubeHistoryController.inst.dayOfHighLight.value;
        final sameIndex = index == YoutubeHistoryController.inst.indexToHighlight.value;
        final hightlightedColor = sameDay && sameIndex ? context.theme.colorScheme.onBackground.withAlpha(40) : null;
        return NamidaPopupWrapper(
          openOnTap: false,
          childrenDefault: menuItems,
          child: NamidaInkWell(
            onTap: () {
              YTUtils.expandMiniplayer();
              Player.inst.playOrPause(index, videos, QueueSource.others);
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
                      width: (Dimensions.youtubeCardItemHeight * 16 / 9) - 3.0,
                      height: Dimensions.youtubeCardItemHeight - 3.0,
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
                                  enabled: settings.enableBlurEffect.value,
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
                      overrideListens: overrideListens,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
