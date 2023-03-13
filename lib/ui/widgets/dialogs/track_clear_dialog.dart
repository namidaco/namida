import 'dart:io';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showTrackClearDialog(List<Track> tracks) {
  final isSingle = tracks.length == 1;
  Get.dialog(
    CustomBlurryDialog(
      normalTitleStyle: true,
      title: isSingle ? Language.inst.CLEAR_TRACK_ITEM : Language.inst.CLEAR_TRACK_ITEM_MULTIPLE.replaceFirst('_NUMBER_', tracks.length.toString()),
      child: Column(
        children: [
          CustomListTile(
            title: isSingle ? Language.inst.VIDEO_CACHE_FILE : Language.inst.VIDEO_CACHE_FILES,
            icon: Broken.video,
            onTap: () async {
              final allvideo = Directory(kVideosCachePath).listSync();

              for (final track in tracks) {
                final videoId = VideoController.inst.extractYTIDFromTrack(track);
                for (final v in allvideo) {
                  if (v.path.getFilename.startsWith(videoId)) {
                    await v.delete();
                  }
                }
              }

              Get.close(1);
              Player.inst.updateVideoPlayingState();
              VideoController.inst.resetEverything();
            },
          ),
          CustomListTile(
            title: isSingle ? Language.inst.WAVEFORM_DATA : Language.inst.WAVEFORMS_DATA,
            icon: Broken.sound,
            onTap: () async {
              Get.close(1);
              for (final track in tracks) {
                await File("$kWaveformDirPath${track.filename}.wave").delete();
              }
            },
          ),
          CustomListTile(
            title: Language.inst.LYRICS,
            icon: Broken.document,
            onTap: () async {
              Get.close(1);
              for (final track in tracks) {
                await File("$kLyricsDirPath${track.filename}.txt").delete();
              }
            },
          ),
          CustomListTile(
            title: isSingle ? Language.inst.ARTWORK : Language.inst.ARTWORKS,
            icon: Broken.image,
            onTap: () async {
              Get.close(1);
              for (final track in tracks) {
                await File("$kArtworksDirPath${track.filename}.png").delete();
              }
            },
          ),
        ],
      ),
    ),
  );
}
