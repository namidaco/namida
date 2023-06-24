import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/ui/dialogs/track_listens_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class PlaylisTracksPage extends StatelessWidget {
  final Playlist playlist;
  final bool disableAnimation;
  final ScrollController? scrollController;
  final int? indexToHighlight;
  PlaylisTracksPage({super.key, required this.playlist, this.disableAnimation = false, this.scrollController, this.indexToHighlight});

  final RxBool shouldReorder = false.obs;

  final ScrollController defController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final finalScrollController = scrollController ?? defController;
    final isMostPlayedPlaylist = playlist.name == k_PLAYLIST_NAME_MOST_PLAYED;
    final isHistoryPlaylist = playlist.name == k_PLAYLIST_NAME_HISTORY;
    return Obx(
      () {
        PlaylistController.inst.playlistList.toList();
        PlaylistController.inst.defaultPlaylists.toList();
        final finalTracks = isMostPlayedPlaylist ? PlaylistController.inst.topTracksMapListens.keys.toList() : playlist.tracks.map((e) => e.track).toList();
        final topContainer = SubpagesTopContainer(
          source: playlist.toQueueSource(),
          title: playlist.name.translatePlaylistName(),
          subtitle: [finalTracks.displayTrackKeyword, playlist.creationDate.dateFormatted].join(' - '),
          thirdLineText: playlist.moods.isNotEmpty ? playlist.moods.join(', ') : '',
          heroTag: 'playlist_${playlist.name}',
          imageWidget: MultiArtworkContainer(
            heroTag: 'playlist_${playlist.name}',
            size: Get.width * 0.35,
            tracks: finalTracks,
          ),
          tracks: finalTracks,
        );

        /// Top Music Playlist
        return isMostPlayedPlaylist
            ? NamidaTracksList(
                queueSource: playlist.toQueueSource(),
                queueLength: PlaylistController.inst.topTracksMapListens.length,
                scrollController: finalScrollController,
                header: topContainer,
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.only(bottom: kBottomPadding),
                itemBuilder: (context, i) {
                  final track = namidaMostPlayedPlaylist.tracks[i];
                  final count = PlaylistController.inst.topTracksMapListens[track.track]?.length;
                  final w = TrackTile(
                    draggableThumbnail: false,
                    index: i,
                    track: track.track,
                    queueSource: playlist.toQueueSource(),
                    playlist: playlist,
                    bgColor: i == indexToHighlight ? context.theme.colorScheme.onBackground.withAlpha(40) : null,
                    onRightAreaTap: () => showTrackListensDialog(track.track, enableBlur: true),
                    trailingWidget: Container(
                      padding: const EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
                        color: context.theme.scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        count.toString(),
                        style: context.textTheme.displaySmall,
                      ),
                    ),
                  );
                  if (disableAnimation) return w;
                  return AnimatingTile(key: ValueKey(i), position: i, child: w);
                },
              )
            :

            /// Normal Tracks
            NamidaTracksList(
                queueSource: playlist.toQueueSource(),
                scrollController: finalScrollController,
                header: topContainer,
                buildDefaultDragHandles: shouldReorder.value,
                padding: const EdgeInsets.only(bottom: kBottomPadding),
                onReorder: (oldIndex, newIndex) => PlaylistController.inst.reorderTrack(playlist, oldIndex, newIndex),
                queueLength: playlist.tracks.length,
                itemBuilder: (context, i) {
                  final track = playlist.tracks[i];
                  final w = FadeDismissible(
                    key: Key("Diss_$i${track.track.path}"),
                    direction: shouldReorder.value ? DismissDirection.horizontal : DismissDirection.none,
                    onDismissed: (direction) => NamidaOnTaps.inst.onRemoveTrackFromPlaylist(i, playlist),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        TrackTile(
                          index: i,
                          track: track.track,
                          playlist: playlist,
                          queueSource: playlist.toQueueSource(),
                          draggableThumbnail: shouldReorder.value,
                          bgColor: i == indexToHighlight ? context.theme.colorScheme.onBackground.withAlpha(40) : null,
                          thirdLineText: isHistoryPlaylist ? track.dateAdded.dateAndClockFormattedOriginal : '',
                        ),
                        if (!isHistoryPlaylist && !isMostPlayedPlaylist) Obx(() => ThreeLineSmallContainers(enabled: shouldReorder.value)),
                      ],
                    ),
                  );
                  if (disableAnimation) return w;
                  return AnimatingTile(key: ValueKey(i), position: i, child: w);
                },
              );
      },
    );
  }
}

class ThreeLineSmallContainers extends StatelessWidget {
  final bool enabled;
  const ThreeLineSmallContainers({Key? key, required this.enabled}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(
        3,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.bounceIn,
          width: enabled ? 9.0 : 2.0,
          height: 1.2,
          margin: const EdgeInsets.symmetric(vertical: 1),
          color: context.theme.listTileTheme.iconColor?.withAlpha(120),
        ),
      ),
    );
  }
}
