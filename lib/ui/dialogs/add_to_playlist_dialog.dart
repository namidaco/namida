import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/pages/playlists_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showAddToPlaylistDialog(List<Track> tracks) {
  NamidaNavigator.inst.navigateDialog(
    dialog: CustomBlurryDialog(
      insetPadding: const EdgeInsets.all(30.0),
      contentPadding: EdgeInsets.zero,
      titleWidget: Container(
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
              lang.ADD_TO_PLAYLIST,
              style: Get.theme.textTheme.displayMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      leftAction: Obx(
        () => Text(
          "${PlaylistController.inst.playlistsMap.length.formatDecimal()} ${lang.PLAYLISTS}",
          style: Get.theme.textTheme.displayMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      actions: const [
        SizedBox(
          width: 128.0,
          child: CreatePlaylistButton(),
        ),
      ],
      child: SizedBox(
        height: Get.height * 0.7,
        width: Get.width,
        child: PlaylistsPage(
          enableHero: true,
          tracksToAdd: tracks,
          countPerRow: 1,
        ),
      ),
    ),
  );
}
