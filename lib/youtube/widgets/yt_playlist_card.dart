import 'package:flutter/material.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
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
    final thumbnailUrl = playlist?.thumbnailUrl;
    final firstVideoID = playlist?.streams.firstOrNull?.id;
    final goodVideoID = firstVideoID != null && firstVideoID != '';
    return YoutubeCard(
      thumbnailHeight: thumbnailHeight,
      thumbnailWidth: thumbnailWidth,
      isPlaylist: true,
      isImageImportantInCache: false,
      extractColor: true,
      borderRadius: 12.0,
      videoId: goodVideoID ? firstVideoID : null,
      thumbnailUrl: goodVideoID ? null : thumbnailUrl,
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
      smallBoxIcon: Broken.play_cricle,
      menuChildrenDefault: () =>
          playlist?.getPopupMenuItems(
            context,
            displayPlay: playOnTap == false,
            playlistToOpen: playOnTap ? playlist : null,
          ) ??
          [],
    );
  }
}
