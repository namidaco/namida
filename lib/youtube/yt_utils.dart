import 'package:flutter/material.dart';
import 'package:namida/controller/video_controller.dart';

import 'package:playlist_manager/module/playlist_id.dart';
import 'package:share_plus/share_plus.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/functions/download_sheet.dart';

class YTUtils {
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
}
