import 'package:flutter/material.dart';

import 'package:namida/youtube/widgets/yt_card.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

class YoutubePlaylistCard extends StatelessWidget {
  final YoutubePlaylist? playlist;
  const YoutubePlaylistCard({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return YoutubeCard(
      extractColor: true,
      borderRadius: 12.0,
      videoId: null,
      thumbnailUrl: playlist?.thumbnailUrl ?? '',
      shimmerEnabled: playlist == null,
      title: playlist?.name ?? '',
      subtitle: playlist?.uploaderName ?? '',
      thirdLineText: '',
      onTap: () {},
      displayChannelThumbnail: false,
      displaythirdLineText: false,
      smallBoxText: '+25',
    );
  }
}
