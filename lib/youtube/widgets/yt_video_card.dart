import 'package:flutter/material.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/widgets/yt_card.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubeVideoCard extends StatelessWidget {
  final StreamInfoItem? video;
  final PlaylistID? playlistID;
  final bool isImageImportantInCache;
  final void Function()? onTap;
  final double? thumbnailWidth;
  final double? thumbnailHeight;

  const YoutubeVideoCard({
    super.key,
    required this.video,
    required this.playlistID,
    required this.isImageImportantInCache,
    this.onTap,
    this.thumbnailWidth,
    this.thumbnailHeight,
  });

  @override
  Widget build(BuildContext context) {
    final videoId = video?.id ?? '';
    final menuItems = YTUtils.getVideoCardMenuItems(
      videoId: videoId,
      url: video?.url,
      playlistID: playlistID,
      idsNamesLookup: {videoId: video?.name},
    );
    final videoViewCount = video?.viewCount;
    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: menuItems,
      child: YoutubeCard(
        thumbnailWidth: thumbnailWidth,
        thumbnailHeight: thumbnailHeight,
        isImageImportantInCache: isImageImportantInCache,
        borderRadius: 12.0,
        videoId: video?.id,
        thumbnailUrl: null,
        shimmerEnabled: video == null,
        title: video?.name ?? '',
        subtitle: [
          if (videoViewCount != null) "${videoViewCount.formatDecimalShort()} ${videoViewCount == 0 ? lang.VIEW : lang.VIEWS}",
          if (video?.textualUploadDate != null) video?.textualUploadDate,
        ].join(' - '),
        thirdLineText: video?.uploaderName ?? '',
        onTap: onTap ??
            () {
              if (video?.id != null) {
                Player.inst.playOrPause(
                  0,
                  [YoutubeID(id: videoId, playlistID: playlistID)],
                  QueueSource.others,
                );
                YTUtils.expandMiniplayer();
              }
            },
        channelThumbnailUrl: video?.uploaderAvatarUrl,
        displayChannelThumbnail: true,
        smallBoxText: video?.duration?.inSeconds.secondsLabel,
        smallBoxIcon: null,
        bottomRightWidgets: YTUtils.getVideoCacheStatusIcons(videoId: videoId, context: context),
        menuChildrenDefault: menuItems,
      ),
    );
  }
}
