part of '../youtube_info_controller.dart';

class _YoutubeInfoUtils {
  _YoutubeInfoUtils._();

  Map<String, StreamInfoItem> get tempVideoInfosFromStreams => YoutubeInfoController.memoryCache.streamInfoItem.temp;

  /// Used for easily displaying title & channel inside history directly without needing to fetch or rely on cache.
  /// This comes mainly after a youtube history import
  var tempBackupVideoInfo = <String, YoutubeVideoHistory>{}; // {id: YoutubeVideoHistory()}

  Future<void> fillBackupInfoMap() async {
    final map = await _fillBackupInfoMapIsolate.thready(AppDirs.YT_STATS);
    tempBackupVideoInfo = map;
    tempBackupVideoInfo.remove('');
  }

  static Map<String, YoutubeVideoHistory> _fillBackupInfoMapIsolate(String dirPath) {
    final map = <String, YoutubeVideoHistory>{};
    for (final f in Directory(dirPath).listSyncSafe()) {
      if (f is File) {
        try {
          final response = f.readAsJsonSync();
          if (response != null) {
            for (final r in response as List) {
              final yvh = YoutubeVideoHistory.fromJson(r);
              map[yvh.id] = yvh;
            }
          }
        } catch (e) {
          continue;
        }
      }
    }
    return map;
  }

  StreamInfoItem? getStreamInfoSync(String videoId) {
    return YoutiPie.cacheBuilder.forStreamInfoItem(videoId: videoId).read();
  }

  VideoStreamsResult? _getVideoStreamResultSync(String videoId) {
    return YoutubeInfoController.video.fetchVideoStreamsSync(videoId, bypassJSCheck: true);
  }

  YoutiPieVideoPageResult? _getVideoPageResultSync(String videoId) {
    return YoutubeInfoController.video.fetchVideoPageSync(videoId);
  }

  String? getVideoName(String videoId, {bool checkFromStorage = true /* am sorry every follow me */}) {
    String? name = tempVideoInfosFromStreams[videoId]?.title.nullifyEmpty() ?? tempBackupVideoInfo[videoId]?.title.nullifyEmpty();
    if (name != null || checkFromStorage == false) return name;
    return getStreamInfoSync(videoId)?.title.nullifyEmpty() ??
        _getVideoStreamResultSync(videoId)?.info?.title.nullifyEmpty() ?? //
        _getVideoPageResultSync(videoId)?.videoInfo?.title.nullifyEmpty();
  }

  String? getVideoChannelName(String videoId, {bool checkFromStorage = true}) {
    String? name = tempVideoInfosFromStreams[videoId]?.channelName?.nullifyEmpty() ?? tempBackupVideoInfo[videoId]?.channel.nullifyEmpty();
    if (name != null || checkFromStorage == false) return name;
    return getStreamInfoSync(videoId)?.channelName?.nullifyEmpty() ??
        _getVideoStreamResultSync(videoId)?.info?.channelName?.nullifyEmpty() ?? //
        _getVideoPageResultSync(videoId)?.channelInfo?.title.nullifyEmpty();
  }

  String? getVideoChannelID(String videoId) {
    return tempVideoInfosFromStreams[videoId]?.channelId?.nullifyEmpty() ??
        getStreamInfoSync(videoId)?.channelId?.nullifyEmpty() ??
        _getVideoStreamResultSync(videoId)?.info?.channelId?.nullifyEmpty() ?? //
        _getVideoPageResultSync(videoId)?.channelInfo?.id.nullifyEmpty();
  }

  DateTime? getVideoReleaseDate(String videoId) {
    // -- we check for streams result first cuz others are approximation.
    return _getVideoStreamResultSync(videoId)?.info?.publishedAt.date ??
        tempVideoInfosFromStreams[videoId]?.publishedAt.date ??
        getStreamInfoSync(videoId)?.publishedAt.date ?? //
        _getVideoPageResultSync(videoId)?.videoInfo?.publishedAt.date;
  }

  int? getVideoDurationSeconds(String videoId) {
    return tempVideoInfosFromStreams[videoId]?.durSeconds ??
        getStreamInfoSync(videoId)?.durSeconds ?? //
        _getVideoStreamResultSync(videoId)?.info?.durSeconds;
  }
}

extension _StringChecker on String {
  String? nullifyEmpty() {
    if (isEmpty) return null;
    return this;
  }
}
