part of '../youtube_info_controller.dart';

class _YoutubeInfoUtils {
  _YoutubeInfoUtils._();

  Map<String, StreamInfoItem> get tempVideoInfosFromStreams => YoutubeInfoController.memoryCache.streamInfoItem.temp;

  /// Used for easily displaying title & channel inside history directly without needing to fetch or rely on cache.
  /// This comes mainly after a youtube history import
  var tempBackupVideoInfo = <String, YoutubeVideoHistory>{}; // {id: YoutubeVideoHistory()}

  final _tempInfoTitle = <String, String?>{};
  final _tempInfoChannelTitle = <String, String?>{};
  final _tempInfoChannelID = <String, String?>{};
  final _tempInfoVideoReleaseDate = <String, DateTime?>{};
  final _tempInfoVideoDurationSeconds = <String, int?>{};

  Future<void> fillBackupInfoMap() async {
    final map = await _parseBackupHistoryInfoIsolate.thready(AppDirs.YT_STATS);
    tempBackupVideoInfo = map;
    tempBackupVideoInfo.remove('');
  }

  static Map<String, YoutubeVideoHistory> _parseBackupHistoryInfoIsolate(String dirPath) {
    final map = <String, YoutubeVideoHistory>{};
    Directory(dirPath).listSyncSafe().loop((f) {
      if (f is File) {
        try {
          final response = f.readAsJsonSync();
          if (response is List) {
            response.loop(
              (r) {
                final yvh = YoutubeVideoHistory.fromJson(r);
                map[yvh.id] = yvh;
              },
            );
          }
        } catch (_) {}
      }
    });
    return map;
  }

  VideoStreamInfo buildVideoStreamInfoFromCache(String videoId) {
    return VideoStreamInfo(
      id: videoId,
      title: getVideoName(videoId) ?? '',
      durSeconds: getVideoDurationSeconds(videoId),
      keywords: [],
      channelName: getVideoChannelName(videoId),
      channelId: getVideoChannelID(videoId),
      description: getVideoDescription(videoId),
      thumbnails: [],
      viewsCount: tempVideoInfosFromStreams[videoId]?.viewsCount,
      isPrivate: null,
      isUnlisted: null,
      isLive: null,
      category: null,
      publishDate: tempVideoInfosFromStreams[videoId]?.publishedAt ?? PublishTime.unknown(),
      uploadDate: tempVideoInfosFromStreams[videoId]?.publishedAt ?? PublishTime.unknown(),
    );
  }

  StreamInfoItem? getStreamInfoSync(String videoId) {
    return YoutiPie.cacheBuilder.forStreamInfoItem(videoId: videoId).read();
  }

  VideoStreamsResult? _getVideoStreamResultSync(String videoId) {
    return YoutubeInfoController.video.fetchVideoStreamsSync(videoId, infoOnly: true);
  }

  YoutiPieVideoPageResult? _getVideoPageResultSync(String videoId) {
    return YoutubeInfoController.video.fetchVideoPageSync(videoId);
  }

  String? getVideoName(String videoId, {bool checkFromStorage = true /* am sorry every follow me */}) {
    String? name = tempVideoInfosFromStreams[videoId]?.title.nullifyEmpty() ?? tempBackupVideoInfo[videoId]?.title.nullifyEmpty();
    if (name != null || checkFromStorage == false) return name;
    return _tempInfoTitle[videoId] ??= getStreamInfoSync(videoId)?.title.nullifyEmpty() ??
        _getVideoStreamResultSync(videoId)?.info?.title.nullifyEmpty() ?? //
        _getVideoPageResultSync(videoId)?.videoInfo?.title.nullifyEmpty();
  }

  String? getVideoDescription(String videoId, {bool checkFromStorage = true /* am sorry every follow me */}) {
    String? name = tempVideoInfosFromStreams[videoId]?.availableDescription?.nullifyEmpty();
    if (name != null || checkFromStorage == false) return name;
    return _tempInfoTitle[videoId] ??= getStreamInfoSync(videoId)?.availableDescription?.nullifyEmpty() ??
        _getVideoStreamResultSync(videoId)?.info?.description?.nullifyEmpty() ?? //
        _getVideoPageResultSync(videoId)?.videoInfo?.description?.rawText?.nullifyEmpty();
  }

  String? getVideoChannelName(String videoId, {bool checkFromStorage = true}) {
    String? name = tempVideoInfosFromStreams[videoId]?.channelName?.nullifyEmpty() ?? tempBackupVideoInfo[videoId]?.channel.nullifyEmpty();
    if (name != null || checkFromStorage == false) return name;
    return _tempInfoChannelTitle[videoId] ??= getStreamInfoSync(videoId)?.channelName?.nullifyEmpty() ??
        _getVideoStreamResultSync(videoId)?.info?.channelName?.nullifyEmpty() ?? //
        _getVideoPageResultSync(videoId)?.channelInfo?.title.nullifyEmpty();
  }

  String? getVideoChannelID(String videoId) {
    return _tempInfoChannelID[videoId] ??= tempVideoInfosFromStreams[videoId]?.channelId?.nullifyEmpty() ??
        getStreamInfoSync(videoId)?.channelId?.nullifyEmpty() ??
        _getVideoStreamResultSync(videoId)?.info?.channelId?.nullifyEmpty() ?? //
        _getVideoPageResultSync(videoId)?.channelInfo?.id.nullifyEmpty();
  }

  List<YoutiPieThumbnail>? getVideoChannelThumbnails(String videoId, {bool checkFromStorage = true}) {
    var thumbnails = tempVideoInfosFromStreams[videoId]?.channel.thumbnails;
    if ((thumbnails != null && thumbnails.isNotEmpty) || checkFromStorage == false) return thumbnails;
    return getStreamInfoSync(videoId)?.channel.thumbnails ?? _getVideoPageResultSync(videoId)?.channelInfo?.thumbnails;
  }

  DateTime? getVideoReleaseDate(String videoId) {
    // -- we check for streams result first cuz others are approximation.
    return _tempInfoVideoReleaseDate[videoId] ??= _getVideoStreamResultSync(videoId)?.info?.publishedAt.date ??
        tempVideoInfosFromStreams[videoId]?.publishedAt.date ??
        getStreamInfoSync(videoId)?.publishedAt.date ?? //
        _getVideoPageResultSync(videoId)?.videoInfo?.publishedAt.date;
  }

  int? getVideoDurationSeconds(String videoId) {
    final cached = tempVideoInfosFromStreams[videoId]?.durSeconds;
    if (cached != null) return cached;
    return _tempInfoVideoDurationSeconds[videoId] ??= getStreamInfoSync(videoId)?.durSeconds ?? //
        _getVideoStreamResultSync(videoId)?.info?.durSeconds;
  }
}

extension _StringChecker on String {
  String? nullifyEmpty() {
    if (isEmpty) return null;
    return this;
  }
}
