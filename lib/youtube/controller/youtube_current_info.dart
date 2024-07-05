part of 'youtube_info_controller.dart';

class _YoutubeCurrentInfoController {
  _YoutubeCurrentInfoController._();

  RelatedVideosRequestParams get _relatedVideosParams => const RelatedVideosRequestParams.allowAll(); // -- from settings
  bool get _canShowComments => settings.youtubeStyleMiniplayer.value;

  RxBaseCore<YoutiPieVideoPageResult?> get currentVideoPage => _currentVideoPage;
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
    _currentRelatedVideos.value = null;
    _currentComments.value = null;
    currentYTStreams.value = null;
    _isLoadingInitialComments.value = false;
    _isLoadingVideoPage.value = false;
    _isLoadingMoreComments.value = false;
    _isCurrentCommentsFromCache.value = null;
  }

  bool updateVideoPageSync(String videoId) {
    final vidcache = YoutiPie.cacheBuilder.forVideoPage(videoId: videoId);
    final vidPageCached = vidcache.read();
    _currentVideoPage.value = vidPageCached;
    final relatedcache = YoutiPie.cacheBuilder.forRelatedVideos(videoId: videoId);
    _currentRelatedVideos.value = relatedcache.read() ?? vidPageCached?.relatedVideosResult;
    return vidPageCached != null;
  }

  bool updateCurrentCommentsSync(String videoId) {
    final commcache = YoutiPie.cacheBuilder.forComments(videoId: videoId);
    final comms = commcache.read();
    _currentComments.value = comms;
    if (_currentComments.value != null) _isCurrentCommentsFromCache.value = true;
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
    if (!requestPage && !requestComments) return;

    if (requestPage) {
      if (onVideoPageReset != null) onVideoPageReset!(); // jumps miniplayer to top
      _currentVideoPage.value = null;
    }
    if (requestComments) {
      _currentComments.value = null;
      _initialCommentsContinuation = null;
    }

    commentsSort ??= YoutubeMiniplayerUiController.inst.currentCommentSort.value;

    _isLoadingVideoPage.value = true;
    final page = await YoutubeInfoController.video.fetchVideoPage(videoId, details: ExecuteDetails.forceRequest());
    _isLoadingVideoPage.value = false;

    if (_canSafelyModifyMetadata(videoId)) {
      if (requestPage) _currentVideoPage.value = page; // page is still requested cuz comments need it
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
            _currentComments.value = comm;
            _isCurrentCommentsFromCache.value = false;
            _initialCommentsContinuation = comm?.continuation;
          }
        }
      }
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
          _currentComments.value = newRes;
          _isCurrentCommentsFromCache.value = false;
        }
      }
      _isLoadingInitialComments.value = false;
    }
    return fetchedSuccessfully;
  }
}
