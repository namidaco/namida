import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/ui/widgets/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/dialogs/general_popup_dialog.dart';

class SelectedTracksRow extends StatelessWidget {
  const SelectedTracksRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final SelectedTracksController stc = SelectedTracksController.inst;
        final tracks = SelectedTracksController.inst.selectedTracks.toList();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                stc.selectedTracks.clear();
                stc.currentAllTracks.assignAll(Indexer.inst.tracksInfoList.toList());
                stc.isMenuMinimized.value = true;
              },
              icon: const Icon(Broken.close_circle),
            ),
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stc.selectedTracks.displayTrackKeyword,
                    style: context.theme.textTheme.displayLarge!.copyWith(fontSize: 23.0.multipliedFontScale),
                  ),
                  if (!stc.isMenuMinimized.value)
                    Text(
                      stc.selectedTracks.totalDurationFormatted,
                      style: context.theme.textTheme.displayMedium,
                    )
                ],
              ),
            ),
            const SizedBox(
              width: 32,
            ),
            IconButton(
              onPressed: () => editMultipleTracksTags(tracks),
              tooltip: Language.inst.EDIT_TAGS,
              icon: const Icon(Broken.edit),
            ),
            IconButton(
              onPressed: () => showAddToPlaylistDialog(tracks),
              tooltip: Language.inst.ADD_TO_PLAYLIST,
              icon: const Icon(Broken.music_playlist),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {
                showGeneralPopupDialog(
                  tracks,
                  tracks.displayTrackKeyword,
                  [
                    tracks.map((e) => e.size).reduce((a, b) => a + b).fileSizeFormatted,
                    tracks.totalDurationFormatted,
                  ].join(' • '),
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
              onPressed: () {
                stc.selectedTracks.clear();
                stc.selectedTracks.addAll(SelectedTracksController.inst.currentAllTracks.toList());
              },
              icon: const Icon(Broken.category),
              splashRadius: 20.0,
            ),
            stc.isMenuMinimized.value ? const Icon(Broken.arrow_up_3) : const Icon(Broken.arrow_down_2)
          ],
        );
      },
    );
  }
}
