import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'package:namida/class/track.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_details.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/download_task_base.dart';

import 'lrc_search_utils_base.dart';

class LrcSearchUtilsSelectable extends LrcSearchUtils {
  final TrackExtended trackExt;
  final Track track;
  const LrcSearchUtilsSelectable(this.trackExt, this.track);

  @override
  String? get pickFileInitialDirectory => track.isNetwork ? null : track.path.getDirectoryPath;

  @override
  String get initialSearchTextHint => '${trackExt.originalArtist} - ${trackExt.title}';

  @override
  String get embeddedLyrics => trackExt.lyrics;

  @override
  File get cachedTxtFile => File(p.join(mainLyricsCacheDirectory, "${track.rawCacheKey(mainLyricsCacheDirectory)}.txt"));

  @override
  File get cachedLRCFile => File(p.join(mainLyricsCacheDirectory, "${track.rawCacheKey(mainLyricsCacheDirectory)}.lrc"));

  @override
  Future<File?> firstDeviceLRCFile() {
    final path = this.track.path;

    // -- network track
    if (path.startsWith('http')) return Future.value(null);

    return Isolate.run(() => _firstDeviceLRCFileSkipCheckSync(path));
  }

  File? firstDeviceLRCFileSync() {
    final path = this.track.path;

    // -- network track
    if (path.startsWith('http')) return null;

    return _firstDeviceLRCFileSkipCheckSync(path);
  }

  static File? _firstDeviceLRCFileSkipCheckSync(String localTrackPath) {
    final lyricsFilesLocal = _buildDeviceLRCFilesCallbacks(localTrackPath);
    for (final lfn in lyricsFilesLocal) {
      final lf = lfn();
      if (lf.existsAndValidSync()) {
        return lf;
      }
    }
    return null;
  }

  static List<File Function()> _buildDeviceLRCFilesCallbacks(String localTrackPath) {
    final dirPath = localTrackPath.getDirectoryPath;
    final fwoe = localTrackPath.getFilenameWOExt;
    final fwe = localTrackPath.getFilename;
    return [
      () => File(p.join(dirPath, "$fwoe.lrc")),
      () => File(p.join(dirPath, "$fwe.lrc")),
      () => File(p.join(dirPath, "$fwoe.ttml")),
      () => File(p.join(dirPath, "$fwe.ttml")),
      () => File(p.join(dirPath, "$fwoe.LRC")),
      () => File(p.join(dirPath, "$fwe.LRC")),
      () => File(p.join(dirPath, "$fwoe.srt")),
      () => File(p.join(dirPath, "$fwoe.vtt")),
      () => File(p.join(dirPath, "$fwoe.sbv")),
      () => File(p.join(dirPath, "$fwoe.ssa")),
      () => File(p.join(dirPath, "$fwoe.ass")),
    ];
  }

  @override
  Future<int> getItemDurationMS() async => trackExt.durationMS;

  @override
  Future<bool> hasLyrics() async {
    return track.lyrics != '' || await super.hasLyrics();
  }

  static final _durationModifiedRegex = RegExp('nightcore|sped up|slowed', caseSensitive: false);
  static bool _checkIsDurationModified(String property) {
    return _durationModifiedRegex.firstMatch(property) != null;
  }

  @override
  List<LRCSearchDetails> searchDetailsQueries() {
    final durMS = trackExt.durationMS;
    final isDurationModified = _checkIsDurationModified(trackExt.originalGenre) || _checkIsDurationModified(trackExt.title) || _checkIsDurationModified(trackExt.originalArtist);
    return [
      LRCSearchDetails(
        title: trackExt.title,
        artist: trackExt.originalArtist,
        album: '',
        durationMS: durMS,
        isDurationModified: isDurationModified,
      ),
      LRCSearchDetails(
        title: trackExt.title,
        artist: trackExt.originalArtist,
        album: trackExt.originalAlbum,
        durationMS: durMS,
        isDurationModified: isDurationModified,
      ),
      if (trackExt.artistsList.isNotEmpty)
        LRCSearchDetails(
          title: trackExt.title,
          artist: trackExt.artistsList.first,
          album: '',
          durationMS: durMS,
          isDurationModified: isDurationModified,
        ),
      if (trackExt.artistsList.isNotEmpty)
        LRCSearchDetails(
          title: trackExt.title,
          artist: trackExt.artistsList.first,
          album: trackExt.originalAlbum,
          durationMS: durMS,
          isDurationModified: isDurationModified,
        ),
    ];
  }

  @override
  List<String> searchQueriesGoogle() {
    final title = trackExt.title;
    final artist = trackExt.originalArtist;
    return <String>[
      '$title by $artist lyrics',
      '${title.splitFirst("-")} by $artist lyrics',
      '$title by $artist song lyrics',
    ];
  }
}

class LrcSearchUtilsSelectableIsolate extends LrcSearchUtilsSelectable {
  @override
  final String mainLyricsCacheDirectory;

  const LrcSearchUtilsSelectableIsolate(
    super.trackExt,
    super.track, {
    required this.mainLyricsCacheDirectory,
  });
}

class LrcSearchUtilsSelectableFromNetwork extends LrcSearchUtilsSelectable {
  const LrcSearchUtilsSelectableFromNetwork(super.trackExt, super.track);

  @override
  File get cachedTxtFile => File(
    p.join(
      mainLyricsCacheDirectory,
      "${DownloadTaskFilename.cleanupFilename(
        track.rawCacheKey(mainLyricsCacheDirectory),
        parentDirPath: mainLyricsCacheDirectory,
      )}.txt",
    ),
  );

  @override
  File get cachedLRCFile => File(
    p.join(
      mainLyricsCacheDirectory,
      "${DownloadTaskFilename.cleanupFilename(
        track.rawCacheKey(mainLyricsCacheDirectory),
        parentDirPath: mainLyricsCacheDirectory,
      )}.lrc",
    ),
  );
}
