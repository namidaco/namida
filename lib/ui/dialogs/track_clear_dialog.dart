// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_selectable.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

void showTrackClearDialog(List<Selectable> tracksPre, Color colorScheme) async {
  final tracksMap = <Track, bool>{};
  int videosTotalSize = 0;
  int audiosTotalSize = 0;
  int lyricsTotalSize = 0;
  int imagesTotalSize = 0;
  tracksPre.loop(
    (item) async {
      var tr = item.track;
      if (tracksMap[tr] == null) {
        tracksMap[tr] = true;
        var ytId = tr.youtubeID;
        (await VideoController.inst.getNVFromID(tr.youtubeID)).loop((item) => videosTotalSize += item.sizeInBytes);
        Player.inst.audioCacheMap[ytId]?.loop((item) async => audiosTotalSize += await item.file.fileSize() ?? 0);

        final artworkFile = File(tr.pathToImage);
        if (await artworkFile.exists()) imagesTotalSize += await artworkFile.fileSize() ?? 0;

        final lrcUtils = LrcSearchUtilsSelectable(kDummyExtendedTrack, tr);
        final cachedLRCFile = lrcUtils.cachedLRCFile;
        final cachedTxtFile = lrcUtils.cachedTxtFile;
        if (await cachedLRCFile.exists()) lyricsTotalSize += await cachedLRCFile.fileSize() ?? 0;
        if (await cachedTxtFile.exists()) lyricsTotalSize += await cachedTxtFile.fileSize() ?? 0;
      }
    },
  );
  final tracks = tracksMap.keys.toList();
  final isSingle = tracks.length == 1;
  final singleVideoId = isSingle ? tracks[0].youtubeID : null;

  if (singleVideoId != null && singleVideoId.isNotEmpty) {
    // -- show custom goofy dialog for single track that has a video id
    final ctx = namida.context;
    if (ctx != null) {
      Future<(String, int, bool, bool)?> magikify(String? img, bool isThumbnail, bool isTempThumbnail) async {
        if (img != null && await File(img).exists()) {
          final size = await File(img).fileSize() ?? 0;
          imagesTotalSize += size;
          return (img, size, isThumbnail, isTempThumbnail);
        }
        return null;
      }

      final singleTrack = tracks[0];
      final localArtworkDetails = magikify(singleTrack.pathToImage, false, false);
      final imageDetailsFuture = await Future.wait(
        [
          localArtworkDetails,
          magikify(ThumbnailManager.inst.imageUrlToCacheFile(id: singleVideoId, url: null, type: ThumbnailType.video, isTemp: true)?.path, true, true),
          magikify(ThumbnailManager.inst.imageUrlToCacheFile(id: singleVideoId, url: null, type: ThumbnailType.video, isTemp: false)?.path, true, false),
          magikify(await ThumbnailManager.getPathToYTImage(singleVideoId), true, false),
        ],
      );
      final imageDetails = imageDetailsFuture.whereType<(String, int, bool, bool)>().toSet().toList();

      final lrcUtils = LrcSearchUtilsSelectable(kDummyExtendedTrack, singleTrack);
      final cachedLRCFile = lrcUtils.cachedLRCFile;
      final cachedTxtFile = lrcUtils.cachedTxtFile;
      final lyricsFiles = <(String, int, bool)>[];
      if (await cachedLRCFile.exists()) {
        lyricsFiles.add((cachedLRCFile.path, await cachedLRCFile.fileSize() ?? 0, true));
      }
      if (await cachedTxtFile.exists()) {
        lyricsFiles.add((cachedTxtFile.path, await cachedTxtFile.fileSize() ?? 0, false));
      }

      const YTUtils().showVideoClearDialog(
        ctx,
        singleVideoId,
        afterDeleting: (pathsDeleted) async {
          final details = await localArtworkDetails;
          if (details != null && pathsDeleted[details.$1] != null) {
            // -- reduce artworks number manually if was deleted
            Indexer.inst.updateImageSizesInStorage(removedCount: 1, removedSize: details.$2);
          }
        },
        extraTiles: (pathsToDelete, totalSizeToDelete, allSelected) {
          return [
            NamidaClearDialogExpansionTile<dynamic>(
              title: lang.ARTWORKS,
              subtitle: imagesTotalSize.fileSizeFormatted,
              icon: Broken.image,
              items: imageDetails,
              itemBuilder: (details) =>
                  (path: details.$1, subtitle: (details.$2 as int).fileSizeFormatted, title: (details.$3 ? lang.THUMBNAILS : lang.ARTWORK) + (details.$4 ? ' (temp)' : '')),
              itemSize: (details) => details.$2,
              tempFilesSize: null,
              tempFilesDelete: null,
              pathsToDelete: pathsToDelete,
              totalSizeToDelete: totalSizeToDelete,
              allSelected: allSelected,
            ),
            NamidaClearDialogExpansionTile<dynamic>(
              title: lang.LYRICS,
              subtitle: lyricsTotalSize.fileSizeFormatted,
              icon: Broken.document,
              items: lyricsFiles,
              itemBuilder: (details) => (path: details.$1, subtitle: (details.$2 as int).fileSizeFormatted, title: lang.LYRICS + (details.$3 ? ' (${lang.SYNCED})' : '')),
              itemSize: (details) => details.$2,
              tempFilesSize: null,
              tempFilesDelete: null,
              pathsToDelete: pathsToDelete,
              totalSizeToDelete: totalSizeToDelete,
              allSelected: allSelected,
            ),
          ];
        },
      );
    }
    return;
  }

  NamidaNavigator.inst.navigateDialog(
    colorScheme: colorScheme,
    dialogBuilder: (theme) => CustomBlurryDialog(
      theme: theme,
      normalTitleStyle: true,
      icon: Broken.broom,
      title: isSingle ? lang.CLEAR_TRACK_ITEM : lang.CLEAR_TRACK_ITEM_MULTIPLE.replaceFirst('_NUMBER_', tracks.length.formatDecimal()),
      child: Column(
        children: [
          if (videosTotalSize > 0)
            CustomListTile(
              passedColor: colorScheme,
              title: isSingle ? lang.VIDEO_CACHE_FILE : lang.VIDEO_CACHE_FILES,
              subtitle: videosTotalSize.fileSizeFormatted,
              icon: Broken.video_square,
              onTap: () async {
                await EditDeleteController.inst.deleteCachedVideos(tracks);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          if (audiosTotalSize > 0)
            CustomListTile(
              passedColor: colorScheme,
              title: lang.AUDIO_CACHE,
              subtitle: audiosTotalSize.fileSizeFormatted,
              icon: Broken.audio_square,
              onTap: () async {
                await EditDeleteController.inst.deleteCachedAudios(tracks);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          if (lyricsTotalSize > 0)
            CustomListTile(
              passedColor: colorScheme,
              title: lang.LYRICS,
              icon: Broken.document,
              onTap: () async {
                await EditDeleteController.inst.deleteLRCLyrics(tracks);
                await EditDeleteController.inst.deleteTXTLyrics(tracks);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          if (imagesTotalSize > 0)
            CustomListTile(
              passedColor: colorScheme,
              title: isSingle ? lang.ARTWORK : lang.ARTWORKS,
              icon: Broken.image,
              onTap: () async {
                await EditDeleteController.inst.deleteArtwork(tracks);
                NamidaNavigator.inst.closeDialog();
              },
            ),
        ],
      ),
    ),
  );
}
