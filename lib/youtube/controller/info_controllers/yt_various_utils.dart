part of '../youtube_info_controller.dart';

class _YoutubeInfoUtils {
  _YoutubeInfoUtils._();

  Map<String, StreamInfoItem> get tempVideoInfosFromStreams => YoutubeInfoController.memoryCache.streamInfoItem.temp;

  /// Used for easily displaying title & channel inside history directly without needing to fetch or rely on cache.
  /// This comes mainly after a youtube history import
  var tempBackupVideoInfo = <String, YoutubeVideoHistory>{}; // {id: YoutubeVideoHistory()}

  final _tempInfoTitle = <String, String?>{};
  final _tempInfoDescription = <String, String?>{};
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

  MissingVideoInfo? _getMissingInfoSync(String videoId) {
    return YoutubeInfoController.missingInfo.fetchMissingInfoCacheSync(videoId);
  }

  String? getVideoName(String videoId, {void Function()? onMissingInfo, bool checkFromStorage = true /* am sorry every follow me */}) {
    String? title = tempVideoInfosFromStreams[videoId]?.title.nullifyTitle(onMissingInfo) ?? tempBackupVideoInfo[videoId]?.title.nullifyTitle(onMissingInfo);
    if (title != null || checkFromStorage == false) return title;

    title = _tempInfoTitle[videoId] ??= getStreamInfoSync(videoId)?.title.nullifyTitle(onMissingInfo) ??
        _getVideoStreamResultSync(videoId)?.info?.title.nullifyTitle(onMissingInfo) ?? //
        _getVideoPageResultSync(videoId)?.videoInfo?.title.nullifyTitle(onMissingInfo);

    if (title == null) {
      title = _getMissingInfoSync(videoId)?.title?.nullifyTitle();
      if (title != null) onMissingInfo?.call();
    }

    return title;
  }

  String? getVideoDescription(String videoId) {
    return _tempInfoDescription[videoId] ??= _getVideoPageResultSync(videoId)?.videoInfo?.description?.rawText?.nullifyEmpty() ??
        _getVideoStreamResultSync(videoId)?.info?.description?.nullifyEmpty() ??
        tempVideoInfosFromStreams[videoId]?.availableDescription?.nullifyEmpty() ??
        getStreamInfoSync(videoId)?.availableDescription?.nullifyEmpty() ?? //
        _getMissingInfoSync(videoId)?.description?.nullifyEmpty();
  }

  String? getVideoChannelName(String videoId, {bool checkFromStorage = true}) {
    String? name = tempVideoInfosFromStreams[videoId]?.channelName?.nullifyEmpty() ?? tempBackupVideoInfo[videoId]?.channel.nullifyEmpty();
    if (name != null || checkFromStorage == false) return name;
    return _tempInfoChannelTitle[videoId] ??= getStreamInfoSync(videoId)?.channelName?.nullifyEmpty() ??
        _getVideoStreamResultSync(videoId)?.info?.channelName?.nullifyEmpty() ?? //
        _getVideoPageResultSync(videoId)?.channelInfo?.title.nullifyEmpty() ?? //
        _getMissingInfoSync(videoId)?.channelName?.nullifyEmpty();
  }

  String? getVideoChannelID(String videoId) {
    return _tempInfoChannelID[videoId] ??= tempVideoInfosFromStreams[videoId]?.channelId?.nullifyEmpty() ??
        getStreamInfoSync(videoId)?.channelId?.nullifyEmpty() ??
        _getVideoStreamResultSync(videoId)?.info?.channelId?.nullifyEmpty() ?? //
        _getVideoPageResultSync(videoId)?.channelInfo?.id.nullifyEmpty() ?? //
        _getMissingInfoSync(videoId)?.channelId?.nullifyEmpty();
  }

  List<YoutiPieThumbnail>? getVideoChannelThumbnails(String videoId, {bool checkFromStorage = true}) {
    var thumbnails = tempVideoInfosFromStreams[videoId]?.channel.thumbnails;
    if ((thumbnails != null && thumbnails.isNotEmpty) || checkFromStorage == false) return thumbnails;
    return getStreamInfoSync(videoId)?.channel.thumbnails ?? _getVideoPageResultSync(videoId)?.channelInfo?.thumbnails;
  }

  DateTime? getVideoReleaseDate(String videoId) {
    // -- we check for streams result first cuz others are approximation.
    return _tempInfoVideoReleaseDate[videoId] ??= _getVideoStreamResultSync(videoId)?.info?.publishedAt.accurateDate ??
        tempVideoInfosFromStreams[videoId]?.publishedAt.accurateDate ??
        getStreamInfoSync(videoId)?.publishedAt.accurateDate ?? //
        _getVideoPageResultSync(videoId)?.videoInfo?.publishedAt.accurateDate ?? //
        _getMissingInfoSync(videoId)?.date.accurateDate;
  }

  int? getVideoDurationSeconds(String videoId) {
    final cached = tempVideoInfosFromStreams[videoId]?.durSeconds;
    if (cached != null) return cached;
    return _tempInfoVideoDurationSeconds[videoId] ??= getStreamInfoSync(videoId)?.durSeconds ?? //
        _getVideoStreamResultSync(videoId)?.info?.durSeconds ?? //
        _getMissingInfoSync(videoId)?.durSeconds;
  }

  bool? isShortContent(String videoId) {
    final cached = tempVideoInfosFromStreams[videoId]?.isActuallyShortContent;
    if (cached != null) return cached;
    return getStreamInfoSync(videoId)?.isActuallyShortContent;
  }

  // ==== async methods ====

  Future<StreamInfoItem?> getStreamInfoAsync(String videoId) {
    return YoutiPie.cacheBuilder.forStreamInfoItem(videoId: videoId).readAsync();
  }

  Future<VideoStreamsResult?> _getVideoStreamResultAsync(String videoId) {
    return YoutubeInfoController.video.fetchVideoStreams(videoId, forceRequest: false);
  }

  Future<YoutiPieVideoPageResult?> _getVideoPageResultAsync(String videoId) {
    return YoutubeInfoController.video.fetchVideoPage(videoId);
  }

  Future<String?> getVideoNameAsync(String videoId) async {
    String? name = tempVideoInfosFromStreams[videoId]?.title.nullifyEmpty() ?? tempBackupVideoInfo[videoId]?.title.nullifyEmpty();
    if (name != null) return name;
    final title = await getStreamInfoAsync(videoId).then((value) => value?.title.nullifyEmpty()) ??
        await _getVideoStreamResultAsync(videoId).then((value) => value?.info?.title.nullifyEmpty()) ?? //
        await _getVideoPageResultAsync(videoId).then((value) => value?.videoInfo?.title.nullifyEmpty());
    return _tempInfoTitle[videoId] ??= title;
  }

  Future<String?> getVideoChannelNameAsync(String videoId) async {
    String? name = tempVideoInfosFromStreams[videoId]?.channelName?.nullifyEmpty() ?? tempBackupVideoInfo[videoId]?.channel.nullifyEmpty();
    if (name != null) return name;
    final channelName = await getStreamInfoAsync(videoId).then((value) => value?.channelName?.nullifyEmpty()) ??
        await _getVideoStreamResultAsync(videoId).then((value) => value?.info?.channelName?.nullifyEmpty()) ?? //
        await _getVideoPageResultAsync(videoId).then((value) => value?.channelInfo?.title.nullifyEmpty());
    return _tempInfoChannelTitle[videoId] ??= channelName;
  }
}

extension _StringChecker on String {
  String? nullifyEmpty() {
    if (isEmpty) return null;
    return this;
  }

  String? nullifyTitle([void Function()? onMissingInfo]) {
    if (isEmpty) return null;
    if (isYTTitleFaulty()) {
      onMissingInfo?.call();
      return null;
    }

    return this;
  }
}
