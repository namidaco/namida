part of 'youtube_info_controller.dart';

class _YoutubeCurrentInfoController {
  _YoutubeCurrentInfoController._();

  RelatedVideosRequestParams get _relatedVideosParams => const RelatedVideosRequestParams.allowAll(); // -- from settings
  bool get _canShowComments => settings.youtube.youtubeStyleMiniplayer.value;
  bool get _personzaliedRelatedVideos => settings.youtube.personalizedRelatedVideos.value;

  RxBaseCore<YoutiPieVideoPageResult?> get currentVideoPage => _currentVideoPage;
  RxBaseCore<VideoStreamInfo?> get currentStreamInfo => _currentStreamInfo;
  RxBaseCore<YoutiPieChannelPageResult?> get currentChannelPage => _currentChannelPage;
  RxBaseCore<YoutiPieRelatedVideosResult?> get currentRelatedVideos => _currentRelatedVideos;
  RxBaseCore<YoutiPieCommentResult?> get currentComments => _currentComments;
  RxBaseCore<bool> get isLoadingVideoPage => _isLoadingVideoPage;
  RxBaseCore<bool> get isLoadingInitialComments => _isLoadingInitialComments;
  RxBaseCore<bool> get isLoadingMoreComments => _isLoadingMoreComments;

  /// Used to keep track of current comments sources, mainly to
  /// prevent fetching next comments when cached version is loaded.
  RxBaseCore<bool?> get isCurrentCommentsFromCache => _isCurrentCommentsFromCache;

  /// Used as a backup in case of no connection.
  final currentCachedQualities = <NamidaVideo>[].obs;

  final _currentVideoPage = Rxn<YoutiPieVideoPageResult>();
  final _currentStreamInfo = Rxn<VideoStreamInfo>();
  final _currentChannelPage = Rxn<YoutiPieChannelPageResult>();
  final _currentRelatedVideos = Rxn<YoutiPieRelatedVideosResult>();
  final _currentComments = Rxn<YoutiPieCommentResult>();
  final currentYTStreams = Rxn<VideoStreamsResult>();
  final _isLoadingVideoPage = false.obs;
  final _isLoadingInitialComments = false.obs;
  final _isLoadingMoreComments = false.obs;
  final _isCurrentCommentsFromCache = Rxn<bool>();

  String? _initialCommentsContinuation;

  /// Checks if the requested id is still playing, since most functions are async and will often
  /// take time to fetch from internet, and user may have played other vids, this covers such cases.
  bool _canSafelyModifyMetadata(String id) => Player.inst.currentVideo?.id == id;

  void Function()? onVideoPageReset;

  void resetAll() {
    currentCachedQualities.clear();
    _currentVideoPage.value = null;
    _currentStreamInfo.value = null;
    _currentChannelPage.value = null;
    _currentRelatedVideos.value = null;
    _currentComments.value = null;
    currentYTStreams.value = null;
    _isLoadingInitialComments.value = false;
    _isLoadingVideoPage.value = false;
    _isLoadingMoreComments.value = false;
    _isCurrentCommentsFromCache.value = null;
  }

  Future<void> onPersonalizedRelatedVideosChanged(bool personalized) async {
    YoutiPieRelatedVideosResult? relatedResult;
    if (personalized) {
      relatedResult = _currentVideoPage.value?.relatedVideosResult;
    }
    if (relatedResult == null) {
      final videoId = Player.inst.currentVideo?.id ?? _currentVideoPage.value?.videoId;
      if (videoId != null) {
        final relatedRes = await YoutubeInfoController.video.fetchRelatedVideos(videoId, personalized, details: ExecuteDetails.normal());
        if (_canSafelyModifyMetadata(videoId)) {
          relatedResult = relatedRes;
        }
      }
    }
    _currentRelatedVideos.value = relatedResult;
  }

  Future<bool> updateVideoPageCache(String videoId) async {
    final vidcache = YoutiPie.cacheBuilder.forVideoPage(videoId: videoId);
    final vidPageCached = await vidcache.readAsync();
    if (!_canSafelyModifyMetadata(videoId)) return false;
    _currentVideoPage.value = vidPageCached;

    final streamInfo = YoutiPie.cacheBuilder.forVideoStreams(videoId: videoId);
    final streamInfoCached = await streamInfo.readAsync();
    if (!_canSafelyModifyMetadata(videoId)) return false;
    _currentStreamInfo.value = streamInfoCached?.info;

    final chId = vidPageCached?.channelInfo?.id ?? YoutubeInfoController.utils.getVideoChannelID(videoId);
    final chPage = chId == null ? null : await YoutiPie.cacheBuilder.forChannel(channelId: chId).readAsync();
    if (!_canSafelyModifyMetadata(videoId)) return false;
    _currentChannelPage.value = chPage;

    final personzaliedRelatedVideos = _personzaliedRelatedVideos;
    final relatedcache = YoutiPie.cacheBuilder.forRelatedVideos(videoId: videoId, userPersonalized: _personzaliedRelatedVideos);
    YoutiPieRelatedVideosResult? relatedVideos = await relatedcache.readAsync();
    if (relatedVideos == null) {
      final hasAcc = YoutubeAccountController.current.activeAccountChannel.value != null;
      if (personzaliedRelatedVideos || (hasAcc && !personzaliedRelatedVideos)) relatedVideos = vidPageCached?.relatedVideosResult;
    }
    if (!_canSafelyModifyMetadata(videoId)) return false;
    _currentRelatedVideos.value = relatedVideos;
    return vidPageCached != null;
  }

  Future<bool> updateCurrentCommentsCache(String videoId) async {
    final commcache = YoutiPie.cacheBuilder.forComments(videoId: videoId);
    final comms = await commcache.readAsync();
    if (!_canSafelyModifyMetadata(videoId)) return false;
    _currentComments.value = comms;
    _isCurrentCommentsFromCache.value = _currentComments.value != null;
    return comms != null;
  }

  Future<void> updateVideoPage(String videoId, {required bool requestPage, required bool requestComments, CommentsSortType? commentsSort}) async {
    if (!ConnectivityController.inst.hasConnection) {
      snackyy(
        title: lang.ERROR,
        message: lang.NO_NETWORK_AVAILABLE_TO_FETCH_DATA,
        isError: true,
        top: false,
      );
      return;
    }
    if (!requestPage && !requestComments) {
      if (requestPage && !_personzaliedRelatedVideos) _fetchAndUpdateRelatedVideos(videoId);
      return;
    }

    final requestCustomRelatedVideos = requestPage && !_personzaliedRelatedVideos;

    if (requestPage) {
      if (onVideoPageReset != null) onVideoPageReset!(); // jumps miniplayer to top
      _currentVideoPage.value = null;
      _currentRelatedVideos.value = null;
      _currentChannelPage.value = null;
    }

    if (requestComments) {
      _currentComments.value = null;
      _initialCommentsContinuation = null;
    }

    commentsSort ??= YoutubeMiniplayerUiController.inst.currentCommentSort.value;

    _isLoadingVideoPage.value = true;
    final page = await YoutubeInfoController.video.fetchVideoPage(videoId, details: ExecuteDetails.forceRequest());
    _isLoadingVideoPage.value = false;

    if (page != null) {
      final chId = page.channelInfo?.id ?? YoutubeInfoController.utils.getVideoChannelID(videoId);
      if (chId != null) {
        YoutubeInfoController.channel.fetchChannelInfo(channelId: page.channelInfo?.id, details: ExecuteDetails.forceRequest()).then(
          (chPage) {
            if (_canSafelyModifyMetadata(videoId)) {
              _currentChannelPage.value = chPage;
            }
          },
        );
      }
    }

    if (_canSafelyModifyMetadata(videoId)) {
      if (requestPage) {
        _currentVideoPage.value = page; // page is still requested cuz comments need it
      }
      if (_personzaliedRelatedVideos) {
        _currentRelatedVideos.value = page?.relatedVideosResult;
      } else {
        if (requestCustomRelatedVideos) _fetchAndUpdateRelatedVideos(videoId);
      }

      if (requestComments) {
        final commentsContinuation = page?.commentResult.continuation;
        if (commentsContinuation != null && _canShowComments) {
          _isLoadingInitialComments.value = true;
          final comm = await YoutubeInfoController.comment.fetchComments(
            videoId: videoId,
            continuationToken: commentsContinuation,
            details: ExecuteDetails.forceRequest(),
          );
          if (_canSafelyModifyMetadata(videoId)) {
            _isLoadingInitialComments.value = false;
            _currentVideoPage.refresh();
            _currentChannelPage.refresh();
            _currentComments.value = comm;
            _isCurrentCommentsFromCache.value = false;
            _initialCommentsContinuation = comm?.continuation;
          }
        }
      }
    }
  }

  Future<void> _fetchAndUpdateRelatedVideos(String videoId) async {
    final relatedVideos = await YoutubeInfoController.video.fetchRelatedVideos(videoId, false, details: ExecuteDetails.forceRequest());
    if (_canSafelyModifyMetadata(videoId)) {
      _currentRelatedVideos.value = relatedVideos;
    }
  }

  /// -- Specify [newSortType] to force refresh. otherwise fetches next.
  /// -- returns wether a new comment result is assigned or not. use to revert ui actions.
  Future<bool> updateCurrentComments(String videoId, {CommentsSortType? newSortType, bool initial = false}) async {
    final commentRes = _currentComments.value;
    if (commentRes == null) return false;
    if (initial == false && commentRes.canFetchNext == false) return false;

    bool fetchedSuccessfully = false;
    if (initial == false && commentRes.canFetchNext && newSortType == null) {
      _isLoadingMoreComments.value = true;
      final didFetch = await commentRes.fetchNext();
      if (didFetch) _currentComments.refresh();
      _isLoadingMoreComments.value = false;
    } else {
      // -- fetch initial.
      _isLoadingInitialComments.value = true;
      final initialContinuation = newSortType == null ? _initialCommentsContinuation : commentRes.sorters[newSortType] ?? _initialCommentsContinuation;
      if (initialContinuation != null) {
        final newRes = await YoutubeInfoController.comment.fetchComments(
          videoId: videoId,
          continuationToken: initialContinuation,
          details: ExecuteDetails.forceRequest(),
        );
        if (newRes != null && _canSafelyModifyMetadata(videoId)) {
          fetchedSuccessfully = true;
          _currentComments.value = newRes;
          _isCurrentCommentsFromCache.value = false;
        }
      }
      _isLoadingInitialComments.value = false;
    }
    return fetchedSuccessfully;
  }
}
