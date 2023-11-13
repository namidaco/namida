import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
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
  final PlaylistID? playlistID;
  final bool minimalCard;
  final bool displayTimeAgo;
  final double? thumbnailHeight;
  final double? minimalCardWidth;
  final bool reversedList;
  final String playlistName;

  const YTHistoryVideoCard({
    super.key,
    required this.videos,
    required this.day,
    required this.index,
    this.overrideListens = const [],
    required this.playlistID,
    this.minimalCard = false,
    this.displayTimeAgo = true,
    this.thumbnailHeight,
    this.minimalCardWidth,
    this.reversedList = false,
    required this.playlistName,
  });

  Widget _columnOrRow({required List<Widget> children, bool isRow = true}) {
    return isRow ? Row(children: children) : Column(children: children);
  }

  @override
  Widget build(BuildContext context) {
    final thumbHeight = thumbnailHeight ?? (minimalCard ? 24.0 * 3.2 : Dimensions.youtubeCardItemHeight);
    final thumbWidth = minimalCardWidth ?? thumbHeight * 16 / 9;

    final index = reversedList ? videos.length - 1 - this.index : this.index;
    final video = videos[index];
    final info = YoutubeController.inst.fetchVideoDetailsFromCacheSync(video.id);
    final duration = info?.duration?.inSeconds.secondsLabel;
    final menuItems = YTUtils.getVideoCardMenuItems(
      videoId: video.id,
      url: info?.url,
      playlistID: playlistID,
      idsNamesLookup: {video.id: info?.name},
      playlistName: playlistName,
      videoYTID: video,
    );
    final backupVideoInfo = YoutubeController.inst.getBackupVideoInfo(video.id);
    final videoTitle = info?.name ?? backupVideoInfo?.title ?? video.id;
    final videoSubtitle = info?.uploaderName ?? backupVideoInfo?.channel;
    final watchMS = video.dateTimeAdded.millisecondsSinceEpoch;
    final dateText = !displayTimeAgo
        ? ''
        : minimalCard
            ? Jiffy.parseFromMillisecondsSinceEpoch(watchMS).fromNow()
            : watchMS.dateAndClockFormattedOriginal;

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
            borderRadius: minimalCard ? 8.0 : 10.0,
            width: minimalCard ? thumbWidth : null,
            onTap: () {
              YTUtils.expandMiniplayer();
              Player.inst.playOrPause(
                  this.index, (reversedList ? videos.reversed : videos).map((e) => YoutubeID(id: e.id, watchNull: e.watchNull, playlistID: playlistID)), QueueSource.others);
            },
            height: minimalCard ? 100 : Dimensions.youtubeCardItemExtent,
            margin: EdgeInsets.symmetric(horizontal: minimalCard ? 2.0 : 4.0, vertical: Dimensions.youtubeCardItemVerticalPadding),
            bgColor: isCurrentlyPlaying ? CurrentColor.inst.color.withAlpha(140) : (hightlightedColor ?? context.theme.cardColor),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0.multipliedRadius),
            ),
            child: Stack(
              children: [
                _columnOrRow(
                  isRow: !minimalCard,
                  children: [
                    SizedBox(
                      width: minimalCard ? null : Dimensions.youtubeCardItemVerticalPadding,
                      height: minimalCard ? 1.0 : null,
                    ),
                    YoutubeThumbnail(
                      key: Key(video.id),
                      borderRadius: 8.0,
                      isImportantInCache: true,
                      width: thumbWidth - 3.0,
                      height: thumbHeight - 3.0,
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
                      child: Padding(
                        padding: minimalCard ? const EdgeInsets.all(4.0) : EdgeInsets.zero,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              videoTitle,
                              maxLines: minimalCard ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.displayMedium?.copyWith(
                                fontSize: minimalCard ? 12.0.multipliedFontScale : null,
                                color: isCurrentlyPlaying ? Colors.white.withOpacity(0.7) : null,
                              ),
                            ),
                            if (videoSubtitle != null)
                              Text(
                                videoSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.displaySmall?.copyWith(
                                  fontSize: minimalCard ? 11.5.multipliedFontScale : null,
                                  color: isCurrentlyPlaying ? Colors.white.withOpacity(0.6) : null,
                                ),
                              ),
                            if (dateText != '')
                              Text(
                                dateText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.displaySmall?.copyWith(
                                  fontSize: minimalCard ? 11.0.multipliedFontScale : null,
                                  color: isCurrentlyPlaying ? Colors.white.withOpacity(0.5) : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                  ],
                ),
                Positioned(
                  bottom: 6.0,
                  right: minimalCard ? 6.0 : 12.0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: YTUtils.getVideoCacheStatusIcons(
                      context: context,
                      videoId: video.id,
                      iconsColor: isCurrentlyPlaying ? Colors.white.withOpacity(0.5) : null,
                      overrideListens: overrideListens,
                      displayCacheIcons: !minimalCard,
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
