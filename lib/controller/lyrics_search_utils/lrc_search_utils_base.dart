import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_details.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_selectable.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_youtubeid.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

abstract class LrcSearchUtils {
  const LrcSearchUtils();

  static FutureOr<LrcSearchUtils?> fromPlayable(Playable item) {
    if (item is Selectable) {
      final tr = item.track;
      return LrcSearchUtilsSelectable(tr.toTrackExt(), tr);
    } else if (item is YoutubeID) {
      return YoutubeInfoController.utils
          .getVideoName(item.id)
          .then(
            (value) => LrcSearchUtilsYoutubeID(item, value),
          );
    }
    return null;
  }

  String get initialSearchTextHint;
  String? get pickFileInitialDirectory;
  String get mainLyricsCacheDirectory => AppDirs.LYRICS;
  String get embeddedLyrics;
  File get cachedTxtFile;
  File get cachedLRCFile;
  List<File> get deviceLRCFiles;

  Future<int> getItemDurationMS();

  Future<File> saveLyricsToCache(String formatted, bool isSynced) async {
    final fc = isSynced ? cachedLRCFile : cachedTxtFile;
    await fc.create();
    await fc.writeAsString(formatted);
    return fc;
  }

  @mustCallSuper
  Future<bool> hasLyrics() async {
    return await cachedLRCFile.exists() || await deviceLRCFiles.anyAsync((element) => element.exists()) || await cachedTxtFile.exists();
  }

  List<LRCSearchDetails> searchDetailsQueries();
  List<String> searchQueriesGoogle();
}
