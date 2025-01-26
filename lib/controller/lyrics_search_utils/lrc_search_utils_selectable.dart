import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:namida/class/track.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_details.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

import 'lrc_search_utils_base.dart';

class LrcSearchUtilsSelectable extends LrcSearchUtils {
  final TrackExtended trackExt;
  final Track track;
  const LrcSearchUtilsSelectable(this.trackExt, this.track);

  @override
  String get pickFileInitialDirectory => track.path.getDirectoryPath;

  @override
  String get initialSearchTextHint => '${trackExt.originalArtist} - ${trackExt.title}';

  @override
  String get embeddedLyrics => trackExt.lyrics;

  @override
  File get cachedTxtFile => File(p.join(AppDirs.LYRICS, "${track.filename}.txt"));

  @override
  File get cachedLRCFile => File(p.join(AppDirs.LYRICS, "${track.filename}.lrc"));

  @override
  List<File> get deviceLRCFiles {
    final dirPath = track.path.getDirectoryPath;
    return [
      File(p.join(dirPath, "${track.filename}.lrc")),
      File(p.join(dirPath, "${track.filenameWOExt}.lrc")),
      File(p.join(dirPath, "${track.filename}.LRC")),
      File(p.join(dirPath, "${track.filenameWOExt}.LRC")),
    ];
  }

  @override
  bool hasLyrics() {
    return track.lyrics != '' || super.hasLyrics();
  }

  static final _durationModifiedRegex = RegExp('nightcore|sped up', caseSensitive: false);
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
        album: trackExt.album,
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
          album: trackExt.album,
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
