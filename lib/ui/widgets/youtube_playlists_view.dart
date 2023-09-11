import 'package:flutter/material.dart';
import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:get/get.dart';

import 'package:namida/controller/youtube_playlist_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/pages/youtube_page.dart';

class YoutubePlaylistsView extends StatelessWidget {
  final Iterable<String> idsToAdd;

  const YoutubePlaylistsView({
    super.key,
    this.idsToAdd = const <String>[],
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoScrollbar(
      child: Obx(
        () {
          final pcontroller = YoutubePlaylistController.inst;
          final playlistsNames = pcontroller.playlistsMap.keys.toList();
          return ListView.builder(
            padding: const EdgeInsets.only(top: 24.0),
            itemCount: playlistsNames.length,
            itemBuilder: (context, index) {
              final name = playlistsNames[index];
              final playlist = pcontroller.playlistsMap[name]!;
              return Obx(
                () => YoutubeCard(
                  thumbnailWidthPercentage: 0.8,
                  videoId: playlist.tracks.firstOrNull?.id,
                  thumbnailUrl: null,
                  shimmerEnabled: false,
                  title: playlist.name,
                  subtitle: playlist.creationDate.dateFormattedOriginal,
                  thirdLineText: playlist.tracks.length.displayVideoKeyword,
                  displayChannelThumbnail: false,
                  channelThumbnailUrl: '',
                  onTap: () {
                    if (idsToAdd.isNotEmpty) {
                      YoutubePlaylistController.inst.addTracksToPlaylist(playlist, idsToAdd);
                    } else {
                      // navigate
                    }
                  },
                  smallBoxText: playlist.tracks.length.formatDecimal(),
                  checkmarkStatus: idsToAdd.isEmpty ? null : playlist.tracks.firstWhereEff((e) => e.id == idsToAdd.firstOrNull) != null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
