// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
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
                  if (p.basename(v.path).startsWith(videoId)) {
                    await v.delete();
                  }
                }
              }

              Get.close(1);
              Player.inst.updateVideoPlayingState();
              VideoController.inst.youtubeLink.value = '';
            },
          ),
          CustomListTile(
            title: isSingle ? Language.inst.WAVEFORM_DATA : Language.inst.WAVEFORMS_DATA,
            icon: Broken.sound,
            onTap: () async {
              Get.close(1);
              for (final track in tracks) {
                await File("$kWaveformDirPath${track.displayName}.wave").delete();
              }
            },
          ),
          CustomListTile(
            title: isSingle ? Language.inst.ARTWORK : Language.inst.ARTWORKS,
            icon: Broken.image,
            onTap: () async {
              Get.close(1);
              for (final track in tracks) {
                await File("$kArtworksDirPath${track.displayName}.png").delete();
              }
            },
          ),
          CustomListTile(
            title: isSingle ? Language.inst.ARTWORK_COMPRESSED : Language.inst.ARTWORKS_COMPRESSED,
            icon: Broken.gallery,
            onTap: () async {
              Get.close(1);
              for (final track in tracks) {
                await File("$kArtworksCompDirPath${track.displayName}.png").delete();
              }
            },
          ),
        ],
      ),
    ),
  );
}
