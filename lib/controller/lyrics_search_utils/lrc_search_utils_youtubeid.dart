import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:namida/controller/lyrics_search_utils/lrc_search_details.dart';
import 'package:namida/youtube/class/youtube_id.dart';

import 'lrc_search_utils_base.dart';

class LrcSearchUtilsYoutubeID extends LrcSearchUtils {
  final YoutubeID video;
  final String? videoTitle;
  const LrcSearchUtilsYoutubeID(this.video, this.videoTitle);

  @override
  String? get pickFileInitialDirectory => null;

  @override
  String get initialSearchTextHint => videoTitle ?? '';

  @override
  String get embeddedLyrics => ''; // none

  @override
  File get cachedTxtFile => File(p.join(mainLyricsCacheDirectory, "${video.id}.txt"));

  @override
  File get cachedLRCFile => File(p.join(mainLyricsCacheDirectory, "${video.id}.lrc"));

  @override
  List<File> get deviceLRCFiles => <File>[]; // none

  @override
  List<String> searchQueriesGoogle() {
    if (videoTitle == null) return [];
    return <String>[
      '$videoTitle lyrics',
    ];
  }

  @override
  List<LRCSearchDetails> searchDetailsQueries() => []; //none
}
