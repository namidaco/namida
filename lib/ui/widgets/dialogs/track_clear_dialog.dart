import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/video_controller.dart';
import 'package:namida/ui/widgets/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/edits_tags_dialog.dart';

void showTrackClearDialog(Track track) {
  Get.dialog(
    CustomBlurryDialog(
      normalTitleStyle: true,
      title: 'Clear Track\'s',
      child: Column(
        children: [
          CustomListTile(
            title: 'Video File',
            onTap: () {},
          ),
          CustomListTile(
            title: 'Waveform Data',
            onTap: () {},
          ),
          CustomListTile(
            title: 'Artwork',
            onTap: () {},
          ),
          CustomListTile(
            title: 'Compressed Artwork',
            onTap: () {},
          ),
        ],
      ),
    ),
  );
}
