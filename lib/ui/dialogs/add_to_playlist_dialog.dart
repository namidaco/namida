import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/playlists_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showAddToPlaylistDialog(List<Track> tracks) {
  NamidaNavigator.inst.navigateDialog(
    NamidaBgBlur(
      blur: 7,
      enabled: true,
      child: Theme(
        data: AppThemes.inst.getAppTheme(),
        child: CustomBlurryDialog(
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
                  Language.inst.ADD_TO_PLAYLIST,
                  style: Get.theme.textTheme.displayMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          leftAction: Obx(
            () => Text(
              "${PlaylistController.inst.playlistsMap.length.toString()} ${Language.inst.PLAYLISTS}",
              style: Get.theme.textTheme.displayMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          actions: const [CreatePlaylistButton()],
          child: SizedBox(
            height: Get.height * 0.7,
            width: Get.width,
            child: PlaylistsPage(
              tracksToAdd: tracks,
              countPerRow: 1,
              displayTopRow: false,
              disableBottomPadding: true,
            ),
          ),
        ),
      ),
    ),
  );
}
