import 'package:flutter/material.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/widgets/yt_card.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:playlist_manager/module/playlist_id.dart';

class YoutubePlaylistCard extends StatelessWidget {
  final YoutubePlaylist? playlist;
  const YoutubePlaylistCard({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final count = playlist?.streamCount;
    return YoutubeCard(
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
          final streams = await YoutubeController.inst.getPlaylistStreams(playlist);
          final plID = playlist?.id;
          final videoIDs = streams.map((e) => YoutubeID(
                id: e.id ?? '',
                playlistID: plID == null ? null : PlaylistID(id: plID),
              ));
          await Player.inst.playOrPause(0, videoIDs, QueueSource.others);
        }
      },
      displayChannelThumbnail: false,
      displaythirdLineText: false,
      smallBoxText: count == null || count < 1 ? "+25" : count.formatDecimalShort(),
    );
  }
}
