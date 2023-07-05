import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:namida/class/track.dart';
import 'package:sticky_headers/sticky_headers.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/ui/dialogs/general_popup_dialog.dart';
import 'package:namida/ui/dialogs/track_listens_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class HistoryTracksPage extends StatelessWidget {
  const HistoryTracksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sc = HistoryController.inst.scrollController;

    return BackgroundWrapper(
      child: Obx(
        () => NamidaListView(
          scrollController: sc,
          itemCount: HistoryController.inst.historyDays.length,
          itemExtents: Dimensions.inst.allItemsExtentsHistory.toList(),
          header: SubpagesTopContainer(
            source: QueueSource.history,
            title: k_PLAYLIST_NAME_HISTORY.translatePlaylistName(),
            subtitle: HistoryController.inst.historyTracksLength.displayTrackKeyword,
            heroTag: 'playlist_$k_PLAYLIST_NAME_HISTORY',
            imageWidget: MultiArtworkContainer(
              heroTag: 'playlist_$k_PLAYLIST_NAME_HISTORY',
              size: Get.width * 0.35,
              tracks: QueueSource.history.toTracks(4),
            ),
            tracks: QueueSource.history.toTracks(),
          ),
          itemBuilder: (context, index) {
            final day = HistoryController.inst.historyDays.toList()[index];
            final dayInMs = (day * 8.64e7).round();
            final tracks = HistoryController.inst.historyMap.value[day] ?? [];

            return StickyHeaderBuilder(
              key: ValueKey(index),
              builder: (context, stuckAmount) {
                final reverseStuck = 1 - stuckAmount;
                return Container(
                  clipBehavior: Clip.antiAlias,
                  width: context.width,
                  height: kHistoryDayHeaderHeight,
                  decoration: BoxDecoration(
                      color: Color.alphaBlend(context.theme.cardTheme.color!.withAlpha(140), context.theme.scaffoldBackgroundColor),
                      boxShadow: [
                        BoxShadow(
                          offset: Offset(0, 2.0 * reverseStuck),
                          blurRadius: 4.0,
                          color: Color.alphaBlend(context.theme.shadowColor.withAlpha(140), context.theme.scaffoldBackgroundColor).withOpacity(reverseStuck.clamp(0.0, 0.4)),
                        ),
                      ],
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(6.0.multipliedRadius * reverseStuck),
                        bottomRight: Radius.circular(6.0.multipliedRadius * reverseStuck),
                      )),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: CurrentColor.inst.color.value,
                                width: (4.0 * stuckAmount).withMinimum(3.0),
                              ),
                            ),
                          ),
                          child: Text(
                            [dayInMs.dateFormattedOriginal, tracks.length.displayTrackKeyword].join('  •  '),
                            style: context.textTheme.displayMedium,
                          ),
                        ),
                      ),
                      NamidaIconButton(
                        icon: Broken.more,
                        iconSize: 22.0,
                        onPressed: () {
                          showGeneralPopupDialog(
                            tracks.toTracks(),
                            dayInMs.dateFormattedOriginal,
                            tracks.length.displayTrackKeyword,
                            QueueSource.history,
                            extractColor: false,
                          );
                        },
                      ),
                      const SizedBox(width: 2.0),
                    ],
                  ),
                );
              },
              content: SizedBox(
                height: Dimensions.inst.allItemsExtentsHistory[index],
                width: context.width,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: kHistoryDayListBottomPadding, top: kHistoryDayListTopPadding),
                  primary: false,
                  itemExtent: Dimensions.inst.trackTileItemExtent,
                  itemCount: tracks.length,
                  itemBuilder: (context, i) {
                    final reverseIndex = (tracks.length - 1) - i;
                    final tr = tracks[reverseIndex];

                    return TrackTile(
                      track: tr.track,
                      trackWithDate: tr,
                      index: i,
                      queueSource: QueueSource.history,
                      bgColor: day == HistoryController.inst.dayOfHighLight.value && reverseIndex == HistoryController.inst.indexToHighlight.value
                          ? context.theme.colorScheme.onBackground.withAlpha(40)
                          : null,
                      draggableThumbnail: false,
                      playlistName: k_PLAYLIST_NAME_HISTORY,
                      thirdLineText: tr.dateAdded.dateAndClockFormattedOriginal,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class MostPlayedTracksPage extends StatelessWidget {
  const MostPlayedTracksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Obx(
        () {
          final tracks = QueueSource.mostPlayed.toTracks();
          return NamidaListView(
            itemExtents: tracks.toTrackItemExtents(),
            header: SubpagesTopContainer(
              source: QueueSource.mostPlayed,
              title: k_PLAYLIST_NAME_MOST_PLAYED.translatePlaylistName(),
              subtitle: tracks.displayTrackKeyword,
              heroTag: 'playlist_$k_PLAYLIST_NAME_MOST_PLAYED',
              imageWidget: MultiArtworkContainer(
                heroTag: 'playlist_$k_PLAYLIST_NAME_MOST_PLAYED',
                size: Get.width * 0.35,
                tracks: tracks.withLimit(4).toList(),
              ),
              tracks: tracks,
            ),
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: kBottomPadding),
            itemCount: HistoryController.inst.topTracksMapListens.length,
            itemBuilder: (context, i) {
              final track = tracks[i];
              final listens = HistoryController.inst.topTracksMapListens[track] ?? [];

              return AnimatingTile(
                key: ValueKey(i),
                position: i,
                child: TrackTile(
                  draggableThumbnail: false,
                  index: i,
                  track: tracks[i],
                  queueSource: QueueSource.mostPlayed,
                  playlistName: k_PLAYLIST_NAME_MOST_PLAYED,
                  onRightAreaTap: () => showTrackListensDialog(track, datesOfListen: listens, enableBlur: true),
                  trailingWidget: Container(
                    padding: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(
                      color: context.theme.scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      listens.length.toString(),
                      style: context.textTheme.displaySmall,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class NormalPlaylistTracksPage extends StatelessWidget {
  final String playlistName;
  final bool disableAnimation;
  const NormalPlaylistTracksPage({super.key, required this.playlistName, this.disableAnimation = false});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Obx(
        () {
          PlaylistController.inst.playlistsMap.entries;
          final playlist = PlaylistController.inst.getPlaylist(playlistName);
          if (playlist == null) return const SizedBox();

          final tracksWithDate = playlist.tracks;
          final tracks = tracksWithDate.toTracks();
          final reorderable = PlaylistController.inst.canReorderTracks.value;

          return NamidaTracksList(
            queueSource: playlist.toQueueSource(),
            header: SubpagesTopContainer(
              source: playlist.toQueueSource(),
              title: playlist.name.translatePlaylistName(),
              subtitle: [tracks.displayTrackKeyword, playlist.creationDate.dateFormatted].join(' - '),
              thirdLineText: playlist.moods.isNotEmpty ? playlist.moods.join(', ') : '',
              heroTag: 'playlist_${playlist.name}',
              imageWidget: MultiArtworkContainer(
                heroTag: 'playlist_${playlist.name}',
                size: Get.width * 0.35,
                tracks: tracks,
              ),
              tracks: tracks,
            ),
            buildDefaultDragHandles: reorderable,
            padding: const EdgeInsets.only(bottom: kBottomPadding),
            onReorder: (oldIndex, newIndex) => PlaylistController.inst.reorderTrack(playlist, oldIndex, newIndex),
            queueLength: playlist.tracks.length,
            itemBuilder: (context, i) {
              final trackWithDate = tracksWithDate[i];
              final w = FadeDismissible(
                key: Key("Diss_$i${trackWithDate.track.path}"),
                direction: reorderable ? DismissDirection.horizontal : DismissDirection.none,
                onDismissed: (direction) => NamidaOnTaps.inst.onRemoveTrackFromPlaylist(playlist.name, i, trackWithDate),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    TrackTile(
                      index: i,
                      track: trackWithDate.track,
                      trackWithDate: trackWithDate,
                      playlistName: playlist.name,
                      queueSource: playlist.toQueueSource(),
                      draggableThumbnail: reorderable,
                    ),
                    ThreeLineSmallContainers(enabled: reorderable),
                  ],
                ),
              );
              if (disableAnimation) return w;
              return AnimatingTile(key: ValueKey(i), position: i, child: w);
            },
          );
        },
      ),
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
      children: List<Widget>.filled(
        3,
        AnimatedContainer(
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
