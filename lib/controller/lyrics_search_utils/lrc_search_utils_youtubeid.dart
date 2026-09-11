import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:namida/controller/lyrics_search_utils/lrc_search_details.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

import 'lrc_search_utils_base.dart';

class LrcSearchUtilsYoutubeID extends LrcSearchUtils {
  final YoutubeID video;
  final String? videoTitle;
  final String? channelTitle;
  final Duration? duration;

  const LrcSearchUtilsYoutubeID(
    this.video, {
    required this.videoTitle,
    required this.channelTitle,
    required this.duration,
  });

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
  Future<File?> firstDeviceLRCFile() => Future.value(null);

  @override
  Future<int> getItemDurationMS() async {
    final dur = this.duration;
    if (dur != null && dur > Duration.zero) {
      return dur.inMilliseconds;
    }
    final seconds = await YoutubeInfoController.utils.getVideoDurationSeconds(video.id);
    if (seconds == null) return 0;
    return seconds * 1000;
  }

  @override
  List<String> searchQueriesGoogle() {
    if (videoTitle == null) return [];
    return <String>[
      '$videoTitle lyrics',
    ];
  }

  /// "Artist - Title" style titles carry the artist themselves, the channel is usually an uploader.
  static final _artistTitleSeparatorRegex = RegExp(r'\s[-–—]\s');

  static const _topicChannelSuffix = ' - Topic';

  @override
  List<LRCSearchDetails> searchDetailsQueries() {
    final durMS = duration?.inMilliseconds ?? 0;
    final videoTitle = this.videoTitle ?? '';

    String artist = '';
    String title = videoTitle;
    final separator = _artistTitleSeparatorRegex.firstMatch(videoTitle);
    if (separator != null) {
      final before = videoTitle.substring(0, separator.start).trim();
      final after = videoTitle.substring(separator.end).trim();
      if (before.isNotEmpty && after.isNotEmpty) {
        artist = before;
        title = after;
      }
    }
    if (artist.isEmpty) {
      artist = channelTitle ?? '';
      if (artist.endsWith(_topicChannelSuffix)) artist = artist.substring(0, artist.length - _topicChannelSuffix.length);
    }

    return [
      LRCSearchDetails(
        title: title,
        artist: artist,
        album: '',
        durationMS: durMS,
        isDurationModified: false,
      ),
      LRCSearchDetails(
        title: videoTitle,
        artist: '',
        album: '',
        durationMS: durMS,
        isDurationModified: false,
      ),
    ];
  }
}
