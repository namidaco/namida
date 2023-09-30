import 'package:flutter/material.dart';
import 'package:namida/youtube/yt_utils.dart';

import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/widgets/yt_card.dart';

class YoutubeVideoCard extends StatelessWidget {
  final StreamInfoItem? video;
  final PlaylistID? playlistID;
  const YoutubeVideoCard({
    super.key,
    required this.video,
    required this.playlistID,
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
    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: menuItems,
      child: YoutubeCard(
        borderRadius: 12.0,
        videoId: video?.id,
        thumbnailUrl: null,
        shimmerEnabled: video == null,
        title: video?.name ?? '',
        subtitle: [
          video?.viewCount?.formatDecimalShort() ?? 0,
          if (video?.textualUploadDate != null) video?.textualUploadDate,
        ].join(' - '),
        thirdLineText: video?.uploaderName ?? '',
        onTap: () {
          if (video?.id != null) {
            final st = MiniPlayerController.inst.ytMiniplayerKey.currentState;
            if (st != null) st.animateToState(true);

            Player.inst.playOrPause(
              0,
              [YoutubeID(id: videoId, playlistID: playlistID)],
              QueueSource.others,
            );

            // if the miniplayer wasnt already active, we wait till the queue get filled (i.e. miniplayer gets a state)
            // it would be better if we had a callback instead of waiting 100ms.
            // since awaiting [playOrPause] would take quite long.
            if (st == null) {
              Future.delayed(
                const Duration(milliseconds: 100),
                () => MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(true),
              );
            }
          }
        },
        channelThumbnailUrl: video?.uploaderAvatarUrl,
        displayChannelThumbnail: true,
        smallBoxText: video?.duration?.inSeconds.secondsLabel,
        smallBoxIcon: null,
        bottomRightWidgets: YTUtils.getVideoCacheStatusIcons(videoId: videoId),
        menuChildrenDefault: menuItems,
      ),
    );
  }
}
