import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:lrc/lrc.dart';
import 'package:path/path.dart' as p;

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

  static FutureOr<LrcSearchUtils?> fromPlayable(Playable item) async {
    if (item is Selectable) {
      final tr = item.track;
      return LrcSearchUtilsSelectable(tr.toTrackExt(), tr);
    } else if (item is YoutubeID) {
      final info = await (
        YoutubeInfoController.utils.getVideoName(item.id),
        YoutubeInfoController.utils.getVideoChannelName(item.id),
        YoutubeInfoController.utils.getVideoDuration(item.id),
      ).wait;
      return LrcSearchUtilsYoutubeID(
        item,
        videoTitle: info.$1,
        channelTitle: info.$2,
        duration: info.$3,
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

  /// files outside the cache, txt is only filled when there is no lrc.
  Future<LyricsFiles> firstDeviceFiles();

  Future<List<File>> allDeviceLyricsFiles();

  /// the location lyrics are saved in is looked up first, so that an edit always wins.
  bool shouldPreferDeviceFiles();

  /// txt is only filled when there is no lrc.
  Future<LyricsFiles> firstLyricsFiles({required bool includeTxt}) async {
    final shouldPreferDevice = shouldPreferDeviceFiles();
    final cachedLRC = cachedLRCFile;
    if (!shouldPreferDevice) {
      final isCachedLRCValid = await cachedLRC.existsAndValid();
      if (isCachedLRCValid) return (lrc: cachedLRC, txt: null);
    }

    final deviceFiles = await firstDeviceFiles();
    if (deviceFiles.lrc != null) return deviceFiles;

    if (shouldPreferDevice) {
      final isCachedLRCValid = await cachedLRC.existsAndValid();
      if (isCachedLRCValid) return (lrc: cachedLRC, txt: null);
    }

    if (!includeTxt) return kNoLyricsFiles;
    if (shouldPreferDevice && deviceFiles.txt != null) return deviceFiles;

    final cachedTxt = cachedTxtFile;
    final isCachedTxtValid = await cachedTxt.existsAndValid();
    if (isCachedTxtValid) return (lrc: null, txt: cachedTxt);
    return deviceFiles;
  }

  bool isCacheFile(File file) => p.isWithin(mainLyricsCacheDirectory, file.path);

  Future<int> getItemDurationMS();

  /// null when lyrics belong in the cache, or the location is not writable.
  Future<File?> saveLyricsToDevice(String formatted, bool isSynced, {void Function(File deviceFile)? onFailed});

  Future<File> saveLyrics(String formatted, bool isSynced) async {
    final deviceFile = await saveLyricsToDevice(formatted, isSynced);
    if (deviceFile != null) return deviceFile;
    return saveLyricsToCache(formatted, isSynced);
  }

  Future<File> saveLyricsToCache(String formatted, bool isSynced) async {
    final fc = isSynced ? cachedLRCFile : cachedTxtFile;
    await fc.create();
    await fc.writeAsString(formatted);
    return fc;
  }

  static const kIgnoreMarker = 'IGNORE';
  static bool isIgnoreMarker(String lyrics) => lyrics.startsWith(kIgnoreMarker);

  bool isInstrumental();

  static final _instrumentalTitleRegex = RegExp(
    r'[(\[【「][^)\]】」]*\b(?:instrumental|off[ -]?vocal|inst)\b|(?:^|\s)[-–—~～]\s*(?:instrumental|off[ -]?vocal|inst\.?)(?:\s+ver(?:sion|\.)?)?\s*(?:[-–—~～]|$)',
    caseSensitive: false,
  );

  /// `Song (Instrumental)`, `Song [Off Vocal Ver.]`, `Song -Inst.-`, `Song - Instrumental`, but not `Artist - Instrumental Dreams`.
  static bool isInstrumentalTitle(String title) => _instrumentalTitleRegex.hasMatch(title);

  /// the cached lrc is looked up before the cached txt, so the marker also shadows a txt saved later.
  Future<void> ignoreLyrics() async {
    await cachedTxtFile.tryDeleting();
    await saveLyricsToCache(kIgnoreMarker, true);
  }

  Future<void> removeIgnoreMarker() async {
    final cachedLRC = cachedLRCFile;
    if (!await cachedLRC.exists()) return;
    final cachedLyrics = await cachedLRC.readLrcString();
    if (isIgnoreMarker(cachedLyrics)) await cachedLRC.tryDeleting();
  }

  @mustCallSuper
  Future<bool> hasLyrics() async {
    final files = await firstLyricsFiles(includeTxt: true);
    return files.lrc != null || files.txt != null;
  }

  List<LRCSearchDetails> searchDetailsQueries();
  List<String> searchQueriesGoogle();
}

const LyricsFiles kNoLyricsFiles = (lrc: null, txt: null);

typedef LyricsFiles = ({File? lrc, File? txt});
