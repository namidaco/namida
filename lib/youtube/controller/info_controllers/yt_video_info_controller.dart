part of namidayoutubeinfo;

class _VideoInfoController {
  const _VideoInfoController();

  static const _usedClient = InnertubeClients.ios; // TODO: tvEmbedded should be used to bypass age restricted and obtain higher quality streams.
  static const _requiresJSPlayer = false;

  Future<YoutiPieVideoPageResult?> fetchVideoPage(String videoId, {ExecuteDetails? details}) async {
    final relatedVideosParams = YoutubeInfoController.current._relatedVideosParams;
    final res = await YoutiPie.video.fetchVideoPage(videoId: videoId, relatedVideosParams: relatedVideosParams, details: details);
    return res;
  }

  /// By default, this will force a network request since most implementations use this as fallback to [fetchVideoPageSync].
  Future<VideoStreamsResult?> fetchVideoStreams(String videoId, {bool forceRequest = true}) async {
    final res = await YoutiPie.video.fetchVideoStreams(
      id: videoId,
      details: forceRequest ? ExecuteDetails.forceRequest() : null,
      client: _usedClient,
    );
    if (_requiresJSPlayer) {
      // -- await preparing before returning result
      if (!YoutiPie.cipher.isPrepared) {
        await YoutubeInfoController.ensureJSPlayerInitialized();
      }
    }
    return res;
  }

  YoutiPieVideoPageResult? fetchVideoPageSync(String videoId) {
    final res = YoutiPie.cacheBuilder.forVideoPage(videoId: videoId);
    return res.read();
  }

  VideoStreamsResult? fetchVideoStreamsSync(String videoId, {bool bypassJSCheck = false}) {
    final res = YoutiPie.cacheBuilder.forVideoStreams(videoId: videoId);
    final cached = res.read();
    if (cached == null || cached.client != _usedClient) return null;
    if (_requiresJSPlayer) {
      if (!YoutiPie.cipher.isPrepared) {
        YoutubeInfoController.ensureJSPlayerInitialized();
        if (bypassJSCheck == false) return null; // the player is not prepared, hence the urls are just useless
      }
    }
    return cached;
  }
}
