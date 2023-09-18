import 'package:flutter/material.dart';
import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:get/get.dart';

import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/widgets/yt_card.dart';

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
                () {
                  final idsExist = idsToAdd.isEmpty ? null : playlist.tracks.firstWhereEff((e) => e.id == idsToAdd.firstOrNull) != null;
                  return YoutubeCard(
                    extractColor: true,
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
                        if (idsExist == true) {
                          final indexes = <int>[];
                          playlist.tracks.loop((e, index) {
                            if (idsToAdd.contains(e.id)) {
                              indexes.add(index);
                            }
                          });
                          YoutubePlaylistController.inst.removeTracksFromPlaylist(playlist, indexes);
                        } else {
                          YoutubePlaylistController.inst.addTracksToPlaylist(playlist, idsToAdd);
                        }
                      } else {
                        // navigate
                      }
                    },
                    smallBoxText: playlist.tracks.length.formatDecimal(),
                    checkmarkStatus: idsExist,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
