part of '../youtube_info_controller.dart';

class _VideoInfoController {
  const _VideoInfoController();

  /// tv_embedded can bypass age restricted and obtain higher quality streams,
  /// but doesnt work with many vids, web clients are more stable and can also obtain higher quality streams.
  /// internally, a set of fallbacks is used before returning null result.
  /// the fallback clients can be modified using [YoutiPie.setDefaultClients].
  static const _defaultClient = InnertubeClients.web; // even tho `web` is more prone to errors, its the only client that contains reliable info like date & endcards.
  static const _defaultRequiresJSPlayer = true;

  InnertubeClients get _usedClient => settings.youtube.innertubeClient ?? _defaultClient;
  bool get _requiresJSPlayer {
    final userSpecified = settings.youtube.innertubeClient;
    if (userSpecified == null) return _defaultRequiresJSPlayer;
    return userSpecified.configuration.requireJSPlayer == true;
  }

  bool get jsPreparedIfRequired => _requiresJSPlayer ? YoutiPie.cipher.isPrepared : true;

  Future<bool> ensureJSPlayerInitialized() async {
    if (YoutiPie.cipher.isPrepared) return true;
    return YoutiPie.cipher.prepareJSPlayer(cacheDirectoryPath: AppDirs.YOUTIPIE_CACHE);
  }

  Future<bool> forceRefreshJSPlayer() async {
    return YoutiPie.cipher.forceRefreshJSPlayer(cacheDirectoryPath: AppDirs.YOUTIPIE_CACHE);
  }

  String? getJSPlayerVersion() => YoutiPie.cipher.jsPlayerVersion;

  Future<YoutiPieVideoPageResult?> fetchVideoPage(String videoId, {ExecuteDetails? details}) async {
    final relatedVideosParams = YoutubeInfoController.current._relatedVideosParams;
    final res = await YoutiPie.video.fetchVideoPage(videoId: videoId, relatedVideosParams: relatedVideosParams, details: details);
    if (res != null && res.videoInfo == null && res.channelInfo == null) {
      VideoController.inst.videosPriorityManager.setVideoPriority(videoId, CacheVideoPriority.VIP);
    }
    return res;
  }

  Future<YoutiPieRelatedVideosResult?> fetchRelatedVideos(String videoId, bool userPersonalized, {ExecuteDetails? details}) async {
    final relatedVideosParams = YoutubeInfoController.current._relatedVideosParams;
    final res = await YoutiPie.video.fetchRelatedVideos(videoId: videoId, userPersonalized: userPersonalized, relatedVideosParams: relatedVideosParams, details: details);
    return res;
  }

  YoutiPieVideoPageResult? fetchVideoPageSync(String videoId) {
    final res = YoutiPie.cacheBuilder.forVideoPage(videoId: videoId);
    return res.read();
  }

  /// By default, this will force a network request since most implementations use this as fallback to [fetchVideoStreamsSync].
  Future<VideoStreamsResult?> fetchVideoStreams(String videoId, {bool forceRequest = true}) async {
    // -- preparing jsplayer *before* fetching streams is important, fetching *after* will return non-working urls.
    if (_requiresJSPlayer) {
      // -- await preparing before returning result
      if (!YoutiPie.cipher.isPrepared) {
        await ensureJSPlayerInitialized();
      }
    }
    final res = await YoutiPie.video.fetchVideoStreams(
      id: videoId,
      details: forceRequest ? ExecuteDetails.forceRequest() : null,
      client: _usedClient,
    );
    if (res != null && res.playability.status != VideoPlayabiltyStatus.ok) {
      VideoController.inst.videosPriorityManager.setVideoPriority(videoId, CacheVideoPriority.VIP);
    }
    return res;
  }

  Future<File?> fetchMusicVideoThumbnailToFile(String videoId, String filePath) {
    return YoutiPie.video.fetchMusicVideoThumbnailToFile(id: videoId, filePath: filePath);
  }

  /// Returns cached streams result if exist. you need to ensure that urls didn't expire ![VideoStreamsResult.hasExpired] before consuming them.
  ///
  /// Enable [bypassJSCheck] if you gurantee using [VideoStreamsResult.info] only.
  VideoStreamsResult? fetchVideoStreamsSync(String videoId, {bool bypassJSCheck = false, bool infoOnly = false}) {
    final res = YoutiPie.cacheBuilder.forVideoStreams(videoId: videoId);
    final cached = res.read();
    if (infoOnly) return cached;
    if (cached == null || cached.client != _usedClient) return null;
    if (_requiresJSPlayer && bypassJSCheck == false) {
      if (!YoutiPie.cipher.isPrepared) {
        ensureJSPlayerInitialized();
        return null; // the player is not prepared, hence the urls are just useless
      }
    }
    return cached;
  }
}
