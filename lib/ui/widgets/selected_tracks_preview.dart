import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/dialogs/general_popup_dialog.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class SelectedTracksPreviewContainer extends StatelessWidget {
  final AnimationController animation;
  const SelectedTracksPreviewContainer({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    final sysNavBar = MediaQuery.paddingOf(context).bottom;
    return AnimatedBuilder(
      animation: animation,
      child: Obx(
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
                            child: AnimatedSizedBox(
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
                                color: Color.alphaBlend(context.theme.colorScheme.background.withAlpha(160), context.theme.scaffoldBackgroundColor),
                                borderRadius: const BorderRadius.all(Radius.circular(20)),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.theme.shadowColor.withAlpha(30),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
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
                                              child: NamidaListView(
                                                itemExtents: stc.selectedTracks.toTrackItemExtents(),
                                                itemCount: stc.selectedTracks.length,
                                                onReorder: (oldIndex, newIndex) => stc.reorderTracks(oldIndex, newIndex),
                                                padding: EdgeInsets.zero,
                                                itemBuilder: (context, i) {
                                                  return Dismissible(
                                                    key: ValueKey(stc.selectedTracks[i]),
                                                    onDismissed: (direction) => stc.removeTrack(i),
                                                    child: TrackTile(
                                                      key: Key('$i${stc.selectedTracks[i].track.path}'),
                                                      index: i,
                                                      trackOrTwd: stc.selectedTracks[i],
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
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
      builder: (context, child) {
        if (animation.value == 1.0) return const SizedBox();

        final miniHeight = animation.value.clamp(0.0, 1.0);
        final queueHeight = animation.value > 1.0 ? animation.value.clamp(1.0, 2.0) : 0.0;
        final isMini = animation.value <= 1.0;
        final isInQueue = !isMini;
        final percentage = isMini ? animation.value : animation.value - 1;

        final navHeight = (settings.enableBottomNavBar.value ? kBottomNavigationBarHeight : -4.0) - 10.0;
        final initH = isInQueue ? kQueueBottomRowHeight * 2 : 12.0 + (miniHeight * 24.0);

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 100),
          bottom: sysNavBar + initH + (navHeight * (1 - queueHeight)),
          child: NamidaOpacity(
            opacity: (isInQueue ? percentage : 1 - percentage).clamp(0, 1),
            child: child!,
          ),
        );
      },
    );
  }
}

class SelectedTracksRow extends StatelessWidget {
  const SelectedTracksRow({super.key});

  List<Track> get selectedTracks => SelectedTracksController.inst.selectedTracks.tracks.toList();

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
                    selectedTracks.totalDurationFormatted,
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
                  Player.inst.addToQueue(selectedTracks);
                },
                icon: const Icon(Broken.play_cricle),
                tooltip: lang.PLAY_LAST,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => showEditTracksTagsDialog(selectedTracks, null),
          tooltip: lang.EDIT_TAGS,
          icon: const Icon(Broken.edit),
        ),
        IconButton(
          onPressed: () => showAddToPlaylistDialog(selectedTracks),
          tooltip: lang.ADD_TO_PLAYLIST,
          icon: const Icon(Broken.music_playlist),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final tracks = selectedTracks;
            final selectedPl = SelectedTracksController.inst.selectedPlaylistsNames.values.toList();
            selectedPl.removeDuplicates();
            showGeneralPopupDialog(
              tracks,
              tracks.displayTrackKeyword,
              [
                tracks.totalSizeFormatted,
                tracks.totalDurationFormatted,
              ].join(' • '),
              QueueSource.selectedTracks,
              thirdLineText: tracks.length == 1
                  ? tracks.first.title
                  : tracks.map((e) {
                      final title = e.toTrackExt().title;
                      final maxLet = 20 - tracks.length.clamp(0, 17);
                      return '${title.substring(0, (title.length > maxLet ? maxLet : title.length))}..';
                    }).join(', '),
              tracksWithDates: SelectedTracksController.inst.selectedTracks.tracksWithDates.toList(),
              playlistName: selectedPl.length == 1 ? selectedPl.first : null,
            );
          },
          tooltip: lang.MORE,
          icon: const RotatedBox(quarterTurns: 1, child: Icon(Broken.more)),
        ),
        IconButton(
          onPressed: () => SelectedTracksController.inst.selectAllTracks(),
          icon: const Icon(Broken.category),
          tooltip: lang.SELECT_ALL,
        ),
        SelectedTracksController.inst.isMenuMinimized.value ? const Icon(Broken.arrow_up_3) : const Icon(Broken.arrow_down_2)
      ],
    );
  }
}
