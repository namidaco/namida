import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:share_plus/share_plus.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/pages/yt_playlist_download_subpage.dart';
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
      smallBoxText: count == null || count < 0 ? "+25" : count.formatDecimalShort(),
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
          icon: Broken.import,
          title: lang.DOWNLOAD,
          onTap: () {
            if (playlist != null) _showPlaylistDownloadSheet(context, playlist!);
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

  Future<void> _showPlaylistDownloadSheet(BuildContext context, YoutubePlaylist playlist) async {
    final currentCount = playlist.streams.length.obs;
    final totalCount = playlist.streamCount.obs;
    const switchAnimationDur = Duration(milliseconds: 600);
    const switchAnimationDurHalf = Duration(milliseconds: 300);

    bool isTotalCountNull() => totalCount.value < 0;

    await Future.delayed(Duration.zero);
    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      builder: (context) {
        final iconSize = context.width * 0.5;
        final iconColor = context.theme.colorScheme.onBackground.withOpacity(0.6);
        return SizedBox(
          width: context.width,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Obx(
                  () => AnimatedSwitcher(
                    key: const Key('circle_switch'),
                    duration: switchAnimationDurHalf,
                    child: currentCount.value < totalCount.value || isTotalCountNull()
                        ? ThreeArchedCircle(
                            size: iconSize,
                            color: iconColor,
                          )
                        : Icon(
                            key: const Key('tick_switch'),
                            Broken.tick_circle,
                            size: iconSize,
                            color: iconColor,
                          ),
                  ),
                ),
                const SizedBox(height: 12.0),
                Text(
                  '${lang.FETCHING}...',
                  style: context.textTheme.displayLarge,
                ),
                const SizedBox(height: 8.0),
                Obx(
                  () => Text(
                    '${currentCount.value.formatDecimal()}/${isTotalCountNull() ? '?' : totalCount.value.formatDecimal()}',
                    style: context.textTheme.displayLarge,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (isTotalCountNull() || currentCount.value == 0) {
      await YoutubeController.inst.getPlaylistStreams(playlist, forceInitial: currentCount.value == 0);
      currentCount.value = playlist.streams.length;
      totalCount.value = playlist.streamCount < 0 ? playlist.streams.length : playlist.streamCount;
    }

    // -- if still not fetched
    if (isTotalCountNull()) {
      if (context.mounted) Navigator.of(context).pop();
      currentCount.close();
      return;
    }

    while (currentCount.value < totalCount.value) {
      final res = await YoutubeController.inst.getPlaylistStreams(playlist);
      if (res.isEmpty) break;
      currentCount.value = playlist.streams.length;
    }

    await Future.delayed(switchAnimationDur);
    if (context.mounted) Navigator.of(context).pop();

    currentCount.close();

    final plID = playlist.id;
    final videoIDs = playlist.streams.map((e) => YoutubeID(
          id: e.id ?? '',
          playlistID: plID == null ? null : PlaylistID(id: plID),
        ));
    final infoLookup = <String, StreamInfoItem>{};
    playlist.streams.loop((e, index) {
      infoLookup[e.id ?? ''] = e;
    });
    NamidaNavigator.inst.navigateTo(
      YTPlaylistDownloadPage(
        ids: videoIDs.toList(),
        playlistName: playlist.name ?? '',
        infoLookup: infoLookup,
      ),
    );
  }
}
