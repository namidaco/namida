import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/playlists_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showAddToPlaylistDialog(List<Track> tracks) {
  Get.dialog(
    BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Broken.music_library_2,
                    size: 20.0,
                  ),
                  const SizedBox(
                    width: 12.0,
                  ),
                  Text(
                    Language.inst.ADD_TO_PLAYLIST,
                    style: Get.theme.textTheme.displayMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Expanded(
            //   child: ListView.builder(
            //     physics: BouncingScrollPhysics(),
            //     padding: EdgeInsets.zero,
            //     shrinkWrap: true,
            //     itemCount: PlaylistController.inst.playlistList.length,
            //     itemBuilder: (context, i) {
            //       return PlaylistsPage();
            //     },
            //   ),
            // ),
            Flexible(
              child: PlaylistsPage(
                tracksToAdd: tracks,
                countPerRow: 1,
                displayTopRow: false,
                disableBottomPadding: true,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 12.0,
                  ),
                  Expanded(
                    child: Obx(
                      () => Text(
                        "${PlaylistController.inst.playlistList.length.toString()} ${Language.inst.PLAYLISTS}",
                        style: Get.theme.textTheme.displayMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // FittedBox(child: ImportPlaylistButton()),
                  const SizedBox(
                    width: 8.0,
                  ),
                  const FittedBox(child: CreatePlaylistButton()),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
