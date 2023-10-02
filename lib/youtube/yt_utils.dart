import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:share_plus/share_plus.dart';

import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/functions/download_sheet.dart';

class YTUtils {
  static void expandMiniplayer() {
    final st = MiniPlayerController.inst.ytMiniplayerKey.currentState;
    if (st != null) st.animateToState(true);

    // if the miniplayer wasnt already active, we wait till the queue get filled (i.e. miniplayer gets a state)
    // it would be better if we had a callback instead of waiting 300ms.
    // since awaiting [playOrPause] would take quite long.
    if (st == null) {
      Future.delayed(
        const Duration(milliseconds: 300),
        () => MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(true),
      );
    }
  }

  static List<Widget> getVideoCacheStatusIcons({
    required String videoId,
  }) {
    return [
      Opacity(
        opacity: VideoController.inst.getNVFromID(videoId).isNotEmpty ? 0.6 : 0.1,
        child: Tooltip(message: lang.VIDEO_CACHE, child: const Icon(Broken.video, size: 15.0)),
      ),
      const SizedBox(width: 4.0),
      Opacity(
        opacity: Player.inst.audioCacheMap[videoId] != null ? 0.6 : 0.1,
        child: Tooltip(message: lang.AUDIO_CACHE, child: const Icon(Broken.audio_square, size: 15.0)),
      ),
    ];
  }

  static List<NamidaPopupItem> getVideoCardMenuItems({
    required String videoId,
    required String? url,
    required PlaylistID? playlistID,
    required Map<String, String?> idsNamesLookup,
  }) {
    return [
      NamidaPopupItem(
        icon: Broken.music_library_2,
        title: lang.ADD_TO_PLAYLIST,
        onTap: () {
          showAddToPlaylistSheet(ids: [videoId], idsNamesLookup: idsNamesLookup);
        },
      ),
      NamidaPopupItem(
        icon: Broken.import,
        title: lang.DOWNLOAD,
        onTap: () {
          showDownloadVideoBottomSheet(
            videoId: videoId,
          );
        },
      ),
      NamidaPopupItem(
        icon: Broken.share,
        title: lang.SHARE,
        onTap: () {
          if (url != null) Share.share(url);
        },
      ),
      NamidaPopupItem(
        icon: Broken.next,
        title: lang.PLAY_NEXT,
        onTap: () {
          Player.inst.addToQueue([YoutubeID(id: videoId, playlistID: playlistID)], insertNext: true);
        },
      ),
      NamidaPopupItem(
        icon: Broken.play_cricle,
        title: lang.PLAY_LAST,
        onTap: () {
          Player.inst.addToQueue([YoutubeID(id: videoId, playlistID: playlistID)], insertNext: false);
        },
      ),
    ];
  }

  static Map<FFMPEGTagField, String?> getMetadataInitialMap(String id, VideoInfo? info, {bool autoExtract = true}) {
    final date = info?.date;
    final description = info?.description;
    String? title = info?.name;
    String? artist = info?.uploaderName;
    String? album;
    if (autoExtract) {
      final splitted = info?.name?.splitArtistAndTitle();
      if (splitted != null && splitted.$1 != null && splitted.$2 != null) {
        title = splitted.$2;
        artist = splitted.$1;
        album = info?.uploaderName;
      }
    }
    return {
      FFMPEGTagField.title: title,
      FFMPEGTagField.artist: artist,
      FFMPEGTagField.album: album,
      FFMPEGTagField.comment: YoutubeController.inst.getYoutubeLink(id),
      FFMPEGTagField.year: date == null ? null : DateFormat('yyyyMMdd').format(date),
      FFMPEGTagField.synopsis: description == null ? null : HtmlParser.parseHTML(description).text,
    };
  }

  static Future<bool> writeAudioMetadata({
    required String videoId,
    required File audioFile,
    required File? thumbnailFile,
    required Map<FFMPEGTagField, String?> tagsMap,
  }) async {
    final thumbnail = thumbnailFile ?? await VideoController.inst.getYoutubeThumbnailAndCache(id: videoId);
    if (thumbnail != null) {
      await NamidaFFMPEG.inst.editAudioThumbnail(audioPath: audioFile.path, thumbnailPath: thumbnail.path);
    }
    return await NamidaFFMPEG.inst.editMetadata(
      path: audioFile.path,
      tagsMap: tagsMap,
    );
  }
}
