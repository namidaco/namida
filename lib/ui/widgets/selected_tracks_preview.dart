import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/dialogs/general_popup_dialog.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class SelectedTracksPreviewContainer extends StatelessWidget {
  const SelectedTracksPreviewContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final SelectedTracksController stc = SelectedTracksController.inst;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: stc.selectedTracks.isNotEmpty
              ? Center(
                  child: Container(
                    width: context.width,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => stc.isMenuMinimized.value = !stc.isMenuMinimized.value,
                          onTapDown: (value) => stc.isExpanded.value = true,
                          onTapUp: (value) => stc.isExpanded.value = false,
                          onTapCancel: () => stc.isExpanded.value = !stc.isExpanded.value,

                          // dragging upwards or downwards
                          onPanEnd: (details) {
                            if (details.velocity.pixelsPerSecond.dy < 0) {
                              stc.isMenuMinimized.value = false;
                            } else if (details.velocity.pixelsPerSecond.dy > 0) {
                              stc.isMenuMinimized.value = true;
                            }
                          },
                          child: AnimatedContainer(
                            clipBehavior: Clip.antiAlias,
                            duration: const Duration(seconds: 1),
                            curve: Curves.fastLinearToSlowEaseIn,
                            height: stc.isMenuMinimized.value
                                ? stc.isExpanded.value
                                    ? 80
                                    : 85
                                : stc.isExpanded.value
                                    ? 425
                                    : 430,
                            width: stc.isExpanded.value ? 375 : 380,
                            decoration: BoxDecoration(
                              color: context.theme.colorScheme.background,
                              borderRadius: const BorderRadius.all(Radius.circular(20)),
                              boxShadow: [
                                BoxShadow(
                                  color: context.theme.shadowColor,
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(15),
                            child: stc.isMenuMinimized.value
                                ? const FittedBox(child: SelectedTracksRow())
                                : Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      const FittedBox(child: SelectedTracksRow()),
                                      const SizedBox(
                                        height: 20,
                                      ),
                                      Expanded(
                                        child: Container(
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                                          child: NamidaTracksList(
                                            queueSource: QueueSource.selectedTracks,
                                            queueLength: stc.selectedTracks.length,
                                            onReorder: (oldIndex, newIndex) => stc.reorderTracks(oldIndex, newIndex),
                                            padding: EdgeInsets.zero,
                                            itemBuilder: (context, i) {
                                              return Dismissible(
                                                key: ValueKey(stc.selectedTracks[i]),
                                                onDismissed: (direction) => stc.removeTrack(i),
                                                child: TrackTile(
                                                  index: i,
                                                  track: stc.selectedTracks[i],
                                                  displayRightDragHandler: true,
                                                  queueSource: QueueSource.selectedTracks,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class SelectedTracksRow extends StatelessWidget {
  const SelectedTracksRow({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => SelectedTracksController.inst.clearEverything(),
          icon: const Icon(Broken.close_circle),
        ),
        SizedBox(
          width: 140,
          child: Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SelectedTracksController.inst.selectedTracks.displayTrackKeyword,
                  style: context.theme.textTheme.displayLarge!.copyWith(fontSize: 23.0.multipliedFontScale),
                ),
                if (!SelectedTracksController.inst.isMenuMinimized.value)
                  Text(
                    SelectedTracksController.inst.selectedTracks.totalDurationFormatted,
                    style: context.theme.textTheme.displayMedium,
                  )
              ],
            ),
          ),
        ),
        const SizedBox(
          width: 32,
        ),
        Obx(
          () => AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: SelectedTracksController.inst.didInsertTracks.value ? 0.5 : 1.0,
            child: IgnorePointer(
              ignoring: SelectedTracksController.inst.didInsertTracks.value,
              child: IconButton(
                onPressed: () {
                  SelectedTracksController.inst.didInsertTracks.value = true;
                  Player.inst.addToQueue(SelectedTracksController.inst.selectedTracks.toList());
                },
                icon: const Icon(Broken.play_cricle),
                tooltip: Language.inst.PLAY_LAST,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => editMultipleTracksTags(SelectedTracksController.inst.selectedTracks.toList()),
          tooltip: Language.inst.EDIT_TAGS,
          icon: const Icon(Broken.edit),
        ),
        IconButton(
          onPressed: () => showAddToPlaylistDialog(SelectedTracksController.inst.selectedTracks.toList()),
          tooltip: Language.inst.ADD_TO_PLAYLIST,
          icon: const Icon(Broken.music_playlist),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final tracks = SelectedTracksController.inst.selectedTracks.toList();
            showGeneralPopupDialog(
              tracks,
              tracks.displayTrackKeyword,
              [
                tracks.map((e) => e.size).reduce((a, b) => a + b).fileSizeFormatted,
                tracks.totalDurationFormatted,
              ].join(' • '),
              QueueSource.selectedTracks,
              thirdLineText: tracks.length == 1
                  ? tracks.first.title
                  : tracks.map((e) {
                      final maxLet = 20 - tracks.length.clamp(0, 17);
                      return '${e.title.substring(0, (e.title.length > maxLet ? maxLet : e.title.length))}..';
                    }).join(', '),
            );
          },
          tooltip: Language.inst.MORE,
          icon: const RotatedBox(quarterTurns: 1, child: Icon(Broken.more)),
        ),
        IconButton(
          onPressed: () => SelectedTracksController.inst.selectAllTracks(),
          icon: const Icon(Broken.category),
          tooltip: Language.inst.SELECT_ALL,
        ),
        SelectedTracksController.inst.isMenuMinimized.value ? const Icon(Broken.arrow_up_3) : const Icon(Broken.arrow_down_2)
      ],
    );
  }
}
