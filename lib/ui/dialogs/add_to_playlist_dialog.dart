import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/playlists_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showAddToPlaylistDialog(List<Track> tracks) {
  Get.dialog(
    NamidaBgBlur(
      blur: 7,
      enabled: true,
      child: Theme(
        data: AppThemes.inst.getAppTheme(CurrentColor.inst.color.value, !Get.isDarkMode),
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
    ),
  );
}
