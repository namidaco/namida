import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/ui/dialogs/track_listens_dialog.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/yt_utils.dart';

void showVideoListensDialog(String videoId, {List<int> datesOfListen = const [], Color? colorScheme}) async {
  showListensDialog(
    datesOfListen: datesOfListen.isNotEmpty ? datesOfListen : YoutubeHistoryController.inst.topTracksMapListens[videoId] ?? [],
    colorScheme: colorScheme,
    colorSchemeFunction: () async {
      final image = ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(id: videoId);
      if (image != null) {
        final color = await CurrentColor.inst.extractPaletteFromImage(image.path, paletteSaveDirectory: Directory(AppDirs.YT_PALETTES), useIsolate: true);
        return color?.color;
      }
      return null;
    },
    onListenTap: (listen) {
      final scrollInfo = YoutubeHistoryController.inst.getListenScrollPosition(
        listenMS: listen,
        extraItemsOffset: 2,
      );

      final totalItemsExtent = scrollInfo.itemsToScroll * Dimensions.youtubeCardItemExtent;
      final totalDaysExtent = scrollInfo.daysToScroll * kYoutubeHistoryDayHeaderHeightWithPadding;

      YTUtils.onYoutubeHistoryPlaylistTap(
        indexToHighlight: scrollInfo.indexOfSmallList,
        dayOfHighLight: scrollInfo.dayToHighLight,
        initialScrollOffset: totalItemsExtent + totalDaysExtent,
      );
    },
  );
}
