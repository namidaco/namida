import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:share_plus/share_plus.dart';

import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/functions/video_listens_dialog.dart';
import 'package:namida/youtube/pages/yt_history_page.dart';

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
    required BuildContext context,
    Color? iconsColor,
    List<int> overrideListens = const [],
    bool displayCacheIcons = true,
  }) {
    iconsColor ??= context.theme.iconTheme.color;
    final listens = overrideListens.isNotEmpty ? overrideListens : YoutubeHistoryController.inst.topTracksMapListens[videoId] ?? [];
    return [
      if (listens.isNotEmpty)
        NamidaInkWell(
          borderRadius: 6.0,
          bgColor: context.theme.scaffoldBackgroundColor.withOpacity(0.5),
          onTap: () {
            showVideoListensDialog(videoId);
          },
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
          child: Text(
            listens.length.formatDecimal(),
            style: context.textTheme.displaySmall,
          ),
        ),
      if (displayCacheIcons) ...[
        const SizedBox(width: 4.0),
        Tooltip(
          message: lang.VIDEO_CACHE,
          child: Icon(
            Broken.video,
            size: 15.0,
            color: iconsColor?.withOpacity(VideoController.inst.getNVFromID(videoId).isNotEmpty ? 0.6 : 0.1),
          ),
        ),
        const SizedBox(width: 4.0),
        Tooltip(
          message: lang.AUDIO_CACHE,
          child: Icon(
            Broken.audio_square,
            size: 15.0,
            color: iconsColor?.withOpacity(Player.inst.audioCacheMap[videoId] != null ? 0.6 : 0.1),
          ),
        ),
      ],
    ];
  }

  static List<NamidaPopupItem> getVideosMenuItems({
    required List<YoutubeID> videos,
    List<NamidaPopupItem> moreItems = const [],
    required String playlistName,
  }) {
    return [
      NamidaPopupItem(
        icon: Broken.music_library_2,
        title: lang.ADD_TO_PLAYLIST,
        onTap: () {
          showAddToPlaylistSheet(ids: videos.map((e) => e.id), idsNamesLookup: {});
        },
      ),
      NamidaPopupItem(
        icon: Broken.share,
        title: lang.SHARE,
        onTap: videos.shareVideos,
      ),
      NamidaPopupItem(
        icon: Broken.next,
        title: lang.PLAY_NEXT,
        onTap: () => Player.inst.addToQueue(videos, insertNext: true),
      ),
      NamidaPopupItem(
        icon: Broken.play_cricle,
        title: lang.PLAY_LAST,
        onTap: () => Player.inst.addToQueue(videos, insertNext: false),
      ),
      if (playlistName != '')
        NamidaPopupItem(
          icon: Broken.trash,
          title: lang.DELETE,
          onTap: () => YTUtils.onRemoveVideosFromPlaylist(k_PLAYLIST_NAME_HISTORY, videos),
        ),
      ...moreItems,
    ];
  }

  static List<NamidaPopupItem> getVideoCardMenuItems({
    required String videoId,
    required String? url,
    required PlaylistID? playlistID,
    required Map<String, String?> idsNamesLookup,
    String playlistName = '',
    YoutubeID? videoYTID,
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
      if (playlistName != '' && videoYTID != null)
        NamidaPopupItem(
          icon: Broken.box_remove,
          title: lang.REMOVE_FROM_PLAYLIST,
          subtitle: playlistName.translatePlaylistName(),
          onTap: () => YTUtils.onRemoveVideosFromPlaylist(playlistName, [videoYTID]),
        ),
    ];
  }

  static Map<String, String?> getMetadataInitialMap(String id, VideoInfo? info, {bool autoExtract = true}) {
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

    String? synopsis;
    if (description != null) {
      try {
        synopsis = HtmlParser.parseHTML(description).text;
      } catch (_) {}
    }
    return {
      FFMPEGTagField.title: title,
      FFMPEGTagField.artist: artist,
      FFMPEGTagField.album: album,
      FFMPEGTagField.comment: YoutubeController.inst.getYoutubeLink(id),
      FFMPEGTagField.year: date == null ? null : DateFormat('yyyyMMdd').format(date),
      FFMPEGTagField.synopsis: synopsis,
    };
  }

  static Future<bool> writeAudioMetadata({
    required String videoId,
    required File audioFile,
    required File? thumbnailFile,
    required Map<String, String?> tagsMap,
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

  static Future<void> onYoutubeHistoryPlaylistTap({
    double initialScrollOffset = 0,
    int? indexToHighlight,
    int? dayOfHighLight,
  }) async {
    YoutubeHistoryController.inst.indexToHighlight.value = indexToHighlight;
    YoutubeHistoryController.inst.dayOfHighLight.value = dayOfHighLight;

    void jump() => YoutubeHistoryController.inst.scrollController.jumpTo(initialScrollOffset);

    NamidaNavigator.inst.hideStuff();

    if (YoutubeHistoryController.inst.scrollController.hasClients) {
      jump();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        jump();
      });
      await NamidaNavigator.inst.navigateTo(
        const YoutubeHistoryPage(),
      );
    }
  }

  static Future<void> onRemoveVideosFromPlaylist(String name, List<YoutubeID> videosToDelete) async {
    void showSnacky({required void Function() whatDoYouWant}) {
      snackyy(
        title: lang.UNDO_CHANGES,
        message: lang.UNDO_CHANGES_DELETED_TRACK,
        displaySeconds: 3,
        button: TextButton(
          onPressed: () {
            Get.closeCurrentSnackbar();
            whatDoYouWant();
          },
          child: Text(lang.UNDO),
        ),
      );
    }

    final bool isHistory = name == k_PLAYLIST_NAME_HISTORY;

    if (isHistory) {
      final tempList = List<YoutubeID>.from(videosToDelete);
      await YoutubeHistoryController.inst.removeTracksFromHistory(videosToDelete);
      showSnacky(
        whatDoYouWant: () async {
          await YoutubeHistoryController.inst.addTracksToHistory(tempList);
          YoutubeHistoryController.inst.sortHistoryTracks(tempList.mapped((e) => e.dateTimeAdded.toDaysSince1970()));
        },
      );
    } else {
      final playlist = YoutubePlaylistController.inst.getPlaylist(name);
      if (playlist == null) return;

      final Map<YoutubeID, int> twdAndIndexes = {};
      videosToDelete.loop((twd, index) {
        twdAndIndexes[twd] = playlist.tracks.indexOf(twd);
      });

      await YoutubePlaylistController.inst.removeTracksFromPlaylist(playlist, twdAndIndexes.values.toList());
      showSnacky(
        whatDoYouWant: () async {
          YoutubePlaylistController.inst.insertTracksInPlaylistWithEachIndex(
            playlist,
            twdAndIndexes,
          );
        },
      );
    }
  }
}
