import 'package:flutter/material.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/functions/yt_playlist_utils.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/widgets/yt_card.dart';

class YoutubePlaylistCard extends StatelessWidget {
  final YoutubePlaylist? playlist;
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  final bool playOnTap;

  const YoutubePlaylistCard({
    super.key,
    required this.playlist,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.playOnTap = false,
  });

  @override
  Widget build(BuildContext context) {
    final count = playlist?.streamCount;
    final countText = count == null || count < 0 ? "+25" : count.formatDecimalShort();
    return YoutubeCard(
      thumbnailHeight: thumbnailHeight,
      thumbnailWidth: thumbnailWidth,
      isImageImportantInCache: false,
      extractColor: true,
      borderRadius: 12.0,
      videoId: null,
      thumbnailUrl: playlist?.thumbnailUrl ?? '',
      shimmerEnabled: playlist == null,
      title: playlist?.name ?? '',
      subtitle: playlist?.uploaderName ?? '',
      thirdLineText: '',
      onTap: () async {
        if (playlist != null) {
          if (playOnTap) {
            final videos = await playlist!.fetchAllPlaylistAsYTIDs(context: context);
            if (videos.isEmpty) return;
            Player.inst.playOrPause(0, videos, QueueSource.others);
          } else {
            NamidaNavigator.inst.navigateTo(YTHostedPlaylistSubpage(playlist: playlist!));
          }
        }
      },
      displayChannelThumbnail: false,
      displaythirdLineText: false,
      smallBoxText: countText,
      menuChildrenDefault: playlist?.getPopupMenuItems(
            context,
            displayPlay: playOnTap == false,
            playlistToOpen: playOnTap ? playlist : null,
          ) ??
          [],
    );
  }
}
