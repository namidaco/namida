import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_details.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_selectable.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_youtubeid.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';

abstract class LrcSearchUtils {
  const LrcSearchUtils();

  static LrcSearchUtils? fromPlayable(Playable item) {
    if (item is Selectable) {
      final tr = item.track;
      return LrcSearchUtilsSelectable(tr.toTrackExt(), tr);
    } else if (item is YoutubeID) {
      final videoInfo = YoutubeController.inst.getVideoInfo(item.id, checkFromStorage: true);
      return LrcSearchUtilsYoutubeID(item, videoInfo?.name);
    }
    return null;
  }

  String get initialSearchTextHint;
  String? get pickFileInitialDirectory;
  String get embeddedLyrics;
  File get cachedTxtFile;
  File get cachedLRCFile;
  List<File> get deviceLRCFiles;

  Future<void> saveLyricsToCache(String formatted, bool isSynced) async {
    final fc = isSynced ? cachedLRCFile : cachedTxtFile;
    await fc.create();
    await fc.writeAsString(formatted);
  }

  @mustCallSuper
  bool hasLyrics() {
    return cachedLRCFile.existsSync() || deviceLRCFiles.any((element) => element.existsSync()) || cachedTxtFile.existsSync();
  }

  List<LRCSearchDetails> searchDetailsQueries();
  List<String> searchQueriesGoogle();
}
