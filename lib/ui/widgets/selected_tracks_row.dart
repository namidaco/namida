import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/ui/widgets/dialogs/edit_tags_dialog.dart';

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
                stc.isMenuMinimized.value = true;
              },
              icon: const Icon(Broken.close_circle),
              splashRadius: 20.0,
            ),
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stc.selectedTracks.displayTrackKeyword,
                    style: context.theme.textTheme.displayLarge!.copyWith(fontSize: 26.0),
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
            // IconButton(
            //   onPressed: () => Playback.instance.insertAt(selectedTracks, Playback.instance.index + 1),
            //   tooltip: Language.instance.PLAY_NEXT,
            //   icon: Icon(Broken.next),
            //   splashRadius: 20.0,
            // ),
            // IconButton(
            //   onPressed: () => Playback.instance.add(selectedTracks),
            //   tooltip: Language.instance.PLAY_LAST,
            //   icon: Icon(
            //     Iconsax.play_add,
            //   ),
            //   splashRadius: 20.0,
            // ),
            // IconButton(
            //   onPressed: () {
            //     Playback.instance.open([
            //       ...selectedTracks,
            //       if (Configuration.instance.seamlessPlayback) ...[...Collection.instance.tracks]..shuffle(),
            //     ]);
            //   },
            //   tooltip: Language.instance.PLAY_ALL,
            //   icon: Icon(Broken.play_circle),
            //   splashRadius: 20.0,
            // ),
            // IconButton(
            //   onPressed: () {
            //     Playback.instance.open(
            //       [...selectedTracks]..shuffle(),
            //     );
            //   },
            //   tooltip: Language.instance.SHUFFLE,
            //   icon: Icon(Broken.shuffle),
            //   splashRadius: 20.0,
            // ),
            IconButton(
              onPressed: () {
                editMultipleTracksTags(tracks);
              },
              tooltip: Language.inst.EDIT_TAGS,
              icon: const Icon(Broken.edit),
            ),
            IconButton(
              onPressed: () {
                showAddToPlaylistDialog(tracks);
              },
              tooltip: Language.inst.ADD_TO_PLAYLIST,
              icon: const Icon(Broken.music_playlist),
            ),
            // IconButton(
            //   onPressed: () {
            //     setState(() {
            //       selectedTracks = [];
            //       selectedTracks.addAll(Collection.instance.tracks);
            //     });
            //   },
            //   icon: Icon(Broken.category),
            //   splashRadius: 20.0,
            // ),
            stc.isMenuMinimized.value ? const Icon(Broken.arrow_up_3) : const Icon(Broken.arrow_down_2)
          ],
        );
      },
    );
  }
}
