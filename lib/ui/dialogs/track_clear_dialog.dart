// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/audio_cache_controller.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_selectable.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

void showTrackClearDialog(List<Selectable> tracksPre, Color colorScheme) async {
  final tracksMap = <Track, bool>{};
  int videosTotalSize = 0;
  int audiosTotalSize = 0;
  int lyricsTotalSize = 0;
  int imagesTotalSize = 0;

  for (final item in tracksPre) {
    tracksMap[item.track] = true;
  }

  await tracksMap.keys.loopConcurrent((tr) async {
    for (final video in (await VideoController.inst.getNVFromID(tr.youtubeID))) {
      videosTotalSize += video.sizeInBytes;
    }

    final audioCaches = AudioCacheController.inst.audioCacheMap[tr.youtubeID];
    if (audioCaches != null) {
      for (final audio in audioCaches) {
        audiosTotalSize += await audio.file.fileSize() ?? 0;
      }
    }

    imagesTotalSize += await File(tr.pathToImage).fileSize() ?? 0;

    final lrcUtils = LrcSearchUtilsSelectable(kDummyExtendedTrack, tr);
    lyricsTotalSize += await lrcUtils.cachedLRCFile.fileSize() ?? 0;
    lyricsTotalSize += await lrcUtils.cachedTxtFile.fileSize() ?? 0;
  });

  final tracks = tracksMap.keys.toList();
  final isSingle = tracks.length == 1;
  final serverCacheTotalSize = await ServerCacheController.inst.getCachedSize(tracks);
  final singleVideoId = isSingle ? tracks[0].youtubeID : null;

  if (singleVideoId != null && singleVideoId.isNotEmpty) {
    // -- show custom goofy dialog for single track that has a video id

    Future<(String, int, bool, bool)?> magikify(String? img, bool isThumbnail, bool isTempThumbnail) async {
      if (img == null) return null;
      final size = await File(img).fileSize();
      if (size == null) return null; // -- doesn't exist
      imagesTotalSize += size;
      return (img, size, isThumbnail, isTempThumbnail);
    }

    final singleTrack = tracks[0];
    final serverCacheFilePath = serverCacheTotalSize > 0 ? ServerCacheController.cacheFileForPath(singleTrack.path).path : null;
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
      singleVideoId,
      afterDeleting: (pathsDeleted) async {
        final details = await localArtworkDetails;
        if (details != null && pathsDeleted[details.$1] != null) {
          // -- reduce artworks number manually if was deleted
          Indexer.inst.updateImageSizesInStorage(removedCount: 1, removedSize: details.$2);
        }
        if (serverCacheFilePath != null && pathsDeleted[serverCacheFilePath] != null) {
          await ServerCacheController.inst.removeCached(tracks);
        }
      },
      extraTiles: (pathsToDelete, totalSizeToDelete, allSelected) {
        return [
          NamidaClearDialogExpansionTile<dynamic>(
            title: lang.artworks,
            subtitle: imagesTotalSize.fileSizeFormatted,
            icon: Broken.image,
            items: imageDetails,
            itemBuilder: (details) =>
                (path: details.$1, subtitle: (details.$2 as int).fileSizeFormatted, title: (details.$3 ? lang.thumbnails : lang.artwork) + (details.$4 ? ' (temp)' : '')),
            itemSize: (details) => details.$2,
            tempFilesSize: null,
            tempFilesDelete: null,
            pathsToDelete: pathsToDelete,
            totalSizeToDelete: totalSizeToDelete,
            allSelected: allSelected,
          ),
          if (serverCacheFilePath != null)
            NamidaClearDialogExpansionTile<dynamic>(
              title: lang.serverCache,
              subtitle: serverCacheTotalSize.fileSizeFormatted,
              icon: Broken.cloud,
              items: [serverCacheFilePath],
              itemBuilder: (_) => (path: serverCacheFilePath, subtitle: serverCacheTotalSize.fileSizeFormatted, title: singleTrack.title),
              itemSize: (_) => serverCacheTotalSize,
              tempFilesSize: null,
              tempFilesDelete: null,
              pathsToDelete: pathsToDelete,
              totalSizeToDelete: totalSizeToDelete,
              allSelected: allSelected,
            ),
          NamidaClearDialogExpansionTile<dynamic>(
            title: lang.lyrics,
            subtitle: lyricsTotalSize.fileSizeFormatted,
            icon: Broken.document,
            items: lyricsFiles,
            itemBuilder: (details) => (path: details.$1, subtitle: (details.$2 as int).fileSizeFormatted, title: lang.lyrics + (details.$3 ? ' (${lang.synced})' : '')),
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
    return;
  }

  NamidaNavigator.inst.navigateDialog(
    colorScheme: colorScheme,
    dialogBuilder: (theme) => CustomBlurryDialog(
      theme: theme,
      normalTitleStyle: true,
      icon: Broken.broom,
      title: isSingle ? lang.clearTrackItem : lang.clearTrackItemMultiple(number: tracks.length),
      child: Column(
        children: [
          if (videosTotalSize > 0)
            CustomListTile(
              passedColor: colorScheme,
              title: isSingle ? lang.videoCacheFile : lang.videoCacheFiles,
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
              title: lang.audioCache,
              subtitle: audiosTotalSize.fileSizeFormatted,
              icon: Broken.audio_square,
              onTap: () async {
                await EditDeleteController.inst.deleteCachedAudios(tracks);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          if (serverCacheTotalSize > 0)
            CustomListTile(
              passedColor: colorScheme,
              title: lang.serverCache,
              subtitle: serverCacheTotalSize.fileSizeFormatted,
              icon: Broken.cloud,
              onTap: () async {
                await ServerCacheController.inst.removeCached(tracks);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          if (lyricsTotalSize > 0)
            CustomListTile(
              passedColor: colorScheme,
              title: lang.lyrics,
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
              title: isSingle ? lang.artwork : lang.artworks,
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
