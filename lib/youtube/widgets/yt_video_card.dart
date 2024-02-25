import 'package:flutter/material.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/functions/yt_playlist_utils.dart';
import 'package:namida/youtube/widgets/yt_card.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubeVideoCard extends StatelessWidget {
  final StreamInfoItem? video;
  final PlaylistID? playlistID;
  final bool isImageImportantInCache;
  final void Function()? onTap;
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  final YoutubePlaylist? playlist;
  final int? index;
  final double fontMultiplier;
  final double thumbnailWidthPercentage;
  final bool dateInsteadOfChannel;

  const YoutubeVideoCard({
    super.key,
    required this.video,
    required this.playlistID,
    required this.isImageImportantInCache,
    this.onTap,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.playlist,
    this.index,
    this.fontMultiplier = 1.0,
    this.thumbnailWidthPercentage = 1.0,
    this.dateInsteadOfChannel = false,
  });

  List<NamidaPopupItem> getMenuItems() {
    final videoId = video?.id ?? '';
    return YTUtils.getVideoCardMenuItems(
      videoId: videoId,
      url: video?.url,
      channelUrl: video?.uploaderUrl,
      playlistID: playlistID,
      idsNamesLookup: {videoId: video?.name},
    );
  }

  @override
  Widget build(BuildContext context) {
    final idNull = video?.id;
    final videoId = idNull ?? '';
    final videoViewCount = video?.viewCount;
    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: getMenuItems,
      child: YoutubeCard(
        thumbnailWidthPercentage: thumbnailWidthPercentage,
        fontMultiplier: fontMultiplier,
        thumbnailWidth: thumbnailWidth,
        thumbnailHeight: thumbnailHeight,
        isImageImportantInCache: isImageImportantInCache,
        borderRadius: 12.0,
        videoId: idNull,
        thumbnailUrl: null,
        shimmerEnabled: video == null,
        title: video?.name ?? YoutubeController.inst.getVideoName(videoId) ?? '',
        subtitle: [
          if (videoViewCount != null && videoViewCount >= 0) "${videoViewCount.formatDecimalShort()} ${videoViewCount == 0 ? lang.VIEW : lang.VIEWS}",
          if (video?.textualUploadDate != null) video?.textualUploadDate,
        ].join(' - '),
        displaythirdLineText: true,
        thirdLineText: dateInsteadOfChannel
            ? video?.date?.millisecondsSinceEpoch.dateAndClockFormattedOriginal ?? ''
            : video?.uploaderName ?? YoutubeController.inst.getVideoChannelName(videoId) ?? '',
        displayChannelThumbnail: !dateInsteadOfChannel,
        channelThumbnailUrl: video?.uploaderAvatarUrl,
        onTap: onTap ??
            () async {
              if (idNull != null) {
                Player.inst.playOrPause(
                  0,
                  [YoutubeID(id: videoId, playlistID: playlistID)],
                  QueueSource.others,
                  onAssigningCurrentItem: (currentItem) async {
                    // -- add the remaining playlist videos, only if the same item is still playing
                    final playlist = this.playlist;
                    final index = this.index;

                    if (playlist != null && index != null) {
                      await playlist.fetchAllPlaylistStreams(context: null);
                      if (currentItem is YoutubeID && currentItem.id == videoId) {
                        try {
                          final firstHalf = playlist.streams.getRange(0, index).map((e) => YoutubeID(id: e.id ?? '', playlistID: playlistID));
                          final lastHalf = playlist.streams.getRange(index + 1, playlist.streams.length).map((e) => YoutubeID(id: e.id ?? '', playlistID: playlistID));

                          Player.inst.addToQueue(lastHalf); // adding first bcz inserting would mess up indexes in lastHalf.
                          await Player.inst.insertInQueue(firstHalf, 0);
                        } catch (e) {
                          printy(e, isError: true);
                        }
                      }
                    }
                  },
                );
                YTUtils.expandMiniplayer();
              }
            },
        smallBoxText: video?.duration?.inSeconds.secondsLabel,
        bottomRightWidgets: idNull == null ? [] : YTUtils.getVideoCacheStatusIcons(videoId: idNull, context: context),
        menuChildrenDefault: getMenuItems,
      ),
    );
  }
}
