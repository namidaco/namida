import 'package:flutter/material.dart';

import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:share_plus/share_plus.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/widgets/yt_card.dart';

class YoutubePlaylistCard extends StatelessWidget {
  final YoutubePlaylist? playlist;
  final double? thumbnailWidth;
  final double? thumbnailHeight;

  const YoutubePlaylistCard({
    super.key,
    required this.playlist,
    this.thumbnailWidth,
    this.thumbnailHeight,
  });

  /// Returns all available streams as youtube id, no matter how many times [_fetchVideos] was called.
  Future<Iterable<YoutubeID>> _fetchVideos([int? max = 100]) async {
    final pl = playlist;

    if (pl != null) {
      final first100 = max != null && pl.streams.length >= max ? pl.streams : await YoutubeController.inst.getPlaylistStreams(pl);

      final plID = pl.id;
      final videoIDs = first100.map((e) => YoutubeID(
            id: e.id ?? '',
            playlistID: plID == null ? null : PlaylistID(id: plID),
          ));
      return videoIDs;
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final count = playlist?.streamCount;
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
        final allIDS = await _fetchVideos();
        await Player.inst.playOrPause(0, allIDS, QueueSource.others);
      },
      displayChannelThumbnail: false,
      displaythirdLineText: false,
      smallBoxText: count == null || count < 1 ? "+25" : count.formatDecimalShort(),
      menuChildrenDefault: [
        NamidaPopupItem(
          icon: Broken.share,
          title: lang.SHARE,
          onTap: () {
            final url = playlist?.url;
            if (url != null) Share.share(url);
          },
        ),
        NamidaPopupItem(
          icon: Broken.next,
          title: "${lang.PLAY_NEXT} (100)",
          onTap: () async {
            final allIDS = await _fetchVideos();
            Player.inst.addToQueue(allIDS, insertNext: true);
          },
        ),
        NamidaPopupItem(
          icon: Broken.play_cricle,
          title: "${lang.PLAY_LAST} (100)",
          onTap: () async {
            final allIDS = await _fetchVideos();
            Player.inst.addToQueue(allIDS, insertNext: false);
          },
        ),
      ],
    );
  }
}
