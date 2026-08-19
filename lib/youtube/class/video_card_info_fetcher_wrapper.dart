import 'package:flutter/material.dart';

import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/streams/video_stream_info.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

class VideoCardInfoFetcherWrapper {
  final State _state;

  /// publish date, views count, channel thumbnail..
  final bool fetchExtraDetails;

  VideoCardInfoFetcherWrapper(this._state, {required this.fetchExtraDetails});

  String videoId = '';

  StreamInfoItem? infoFinal;
  VideoStreamInfo? infoVideoFinal;
  String? videoTitle = ' '; // nice hack to preserve an empty verical place for the future title :D
  String? videoChannel = ' ';
  String? duration;
  DateTime? publishedDate;
  int? viewsCount;
  String? viewsText;
  String? channelThumbnailUrl;
  bool isVideoUnavailable = false;

  String? _fetchingVideoId;

  String? get channelId => infoVideoFinal?.channelId ?? infoFinal?.channelId ?? infoFinal?.channel?.id;

  bool get isTitleMissing {
    final title = videoTitle;
    return _isEmpty(title) || title!.isYTTitleFaulty();
  }

  bool get isViewsAndDateMissing => viewsCount == null && _isEmpty(viewsText) && publishedDate == null;

  static bool _isEmpty(String? text) => text == null || text.trim().isEmpty;

  bool _isStale(String videoId) => this.videoId != videoId;

  void reset(String videoId) {
    this.videoId = videoId;
    infoFinal = null;
    infoVideoFinal = null;
    videoTitle = ' ';
    videoChannel = ' ';
    duration = null;
    publishedDate = null;
    viewsCount = null;
    viewsText = null;
    channelThumbnailUrl = null;
    isVideoUnavailable = false;
  }

  /// Assigns known values from [info] synchronously, without fetching anything.
  void assign(StreamInfoItem info) {
    videoId = info.id;
    infoFinal = info;
    infoVideoFinal = null;
    videoTitle = info.title;
    videoChannel = info.channelName?.nullifyEmpty() ?? info.channel?.title?.nullifyEmpty();
    duration = info.durSeconds?.secondsLabel;
    publishedDate = info.publishedAt.date;
    viewsCount = info.viewsCount;
    viewsText = info.viewsText;
    channelThumbnailUrl = info.channel?.thumbnails.pick()?.url;
    isVideoUnavailable = false;
  }

  Future<void> fetchMissing({required bool preferFetchNewInfo}) async {
    final videoId = this.videoId;
    if (_fetchingVideoId == videoId) return;
    _fetchingVideoId = videoId;
    try {
      await _fetchMissing(videoId, preferFetchNewInfo: preferFetchNewInfo);
    } finally {
      if (_fetchingVideoId == videoId) _fetchingVideoId = null;
    }
  }

  Future<void> _fetchMissing(String videoId, {required bool preferFetchNewInfo}) async {
    final utils = YoutubeInfoController.utils;

    // -- basic init to reduce eliminate flashes, checkFromStorage is always false to prevent ui blocking
    infoFinal ??= utils.tempVideoInfosFromStreams[videoId];
    if (_isEmpty(videoTitle)) videoTitle = utils.getVideoNameSync(videoId, checkFromStorage: false);
    if (_isEmpty(videoChannel)) videoChannel = utils.getVideoChannelNameSync(videoId, checkFromStorage: false);
    duration ??= utils.getVideoDurationSecondsSyncTemp(videoId)?.secondsLabel;
    if (fetchExtraDetails) {
      publishedDate ??= utils.getVideoReleaseDateSyncTemp(videoId);
      viewsCount ??= utils.tempVideoInfosFromStreams[videoId]?.viewsCount;
      channelThumbnailUrl ??= utils.getVideoChannelThumbnailsSync(videoId, checkFromStorage: false)?.pick()?.url;
    }

    final newInfo = await utils.getStreamInfo(videoId);
    if (_isStale(videoId)) return;
    if (newInfo != null) {
      _state.refreshState(
        () {
          infoFinal = newInfo;
          final newTitle = newInfo.title;
          if (newTitle.isNotEmpty) videoTitle = newTitle;
          final newChannel = newInfo.channelName?.nullifyEmpty() ?? newInfo.channel?.title?.nullifyEmpty();
          if (newChannel != null) videoChannel = newChannel;
          final newDurSeconds = newInfo.durSeconds;
          if (newDurSeconds != null) duration = newDurSeconds.secondsLabel;
          publishedDate ??= newInfo.publishedAt.date;
          viewsCount ??= newInfo.viewsCount;
          viewsText ??= newInfo.viewsText;
          channelThumbnailUrl ??= newInfo.channel?.thumbnails.pick()?.url;
        },
      );
    }

    String? newVideoTitle = videoTitle;
    String? newVideoChannel = videoChannel;
    String? newDuration = duration;
    bool newIsVideoUnavailable = isVideoUnavailable;
    DateTime? newPublishedDate = publishedDate;
    int? newViewsCount = viewsCount;
    String? newChannelThumbnailUrl = channelThumbnailUrl;

    await [
      () async {
        if (_isEmpty(newDuration)) {
          final dur = await utils.getVideoDurationSeconds(videoId);
          newDuration = dur?.secondsLabel;
        }
      }(),
      () async {
        if (_isEmpty(newVideoTitle)) {
          newVideoTitle = await utils.getVideoName(
            videoId,
            onMissingInfo: () {
              VideoController.inst.videosPriorityManager.setVideoPriority(videoId, CacheVideoPriority.VIP);
              newIsVideoUnavailable = true;
            },
          );
        } else if (newVideoTitle?.isYTTitleFaulty() == true) {
          VideoController.inst.videosPriorityManager.setVideoPriority(videoId, CacheVideoPriority.VIP);
          newIsVideoUnavailable = true;
          newVideoTitle = await utils.getVideoName(videoId, onMissingInfo: null);
        }
      }(),
      () async {
        if (_isEmpty(newVideoChannel)) {
          newVideoChannel = await utils.getVideoChannelName(videoId);
        }
      }(),
      if (fetchExtraDetails) ...[
        () async {
          newPublishedDate ??= await utils.getVideoReleaseDate(videoId);
        }(),
        () async {
          newViewsCount ??= await utils.getVideoViewsCount(videoId);
        }(),
        () async {
          newChannelThumbnailUrl ??= (await utils.getVideoChannelThumbnails(videoId))?.pick()?.url;
        }(),
      ],
    ].wait;

    if (_isStale(videoId)) return;

    if (newVideoTitle != videoTitle ||
        newVideoChannel != videoChannel ||
        newDuration != duration ||
        newIsVideoUnavailable != isVideoUnavailable ||
        newPublishedDate != publishedDate ||
        newViewsCount != viewsCount ||
        newChannelThumbnailUrl != channelThumbnailUrl) {
      _state.refreshState(
        () {
          videoTitle = newVideoTitle;
          videoChannel = newVideoChannel;
          duration = newDuration;
          isVideoUnavailable = newIsVideoUnavailable;
          publishedDate = newPublishedDate;
          viewsCount = newViewsCount;
          channelThumbnailUrl = newChannelThumbnailUrl;
        },
      );
    }

    final titleMissing = _isEmpty(videoTitle);
    final detailsMissing = fetchExtraDetails && isViewsAndDateMissing;
    if (_state.mounted && (titleMissing || detailsMissing)) {
      // -- if only title is missing then most likely video is deleted/etc so no need to refetch (unless enforced),
      // -- but missing details for an available video are worth a network request.
      final fromNetwork = preferFetchNewInfo || (detailsMissing && !isVideoUnavailable);
      await _fetchNewInfo(videoId, fromNetwork: fromNetwork);
    }
  }

  Future<void> _fetchNewInfo(String videoId, {required bool fromNetwork}) async {
    if (!ConnectivityController.inst.hasConnection) return;
    final newInfo = fromNetwork
        ? await YoutubeInfoController.video.fetchVideoStreams(videoId, forceRequest: false) // uses cache if valid
        : await YoutubeInfoController.video.fetchVideoStreamsCache(videoId, infoOnly: true);
    if (_isStale(videoId)) return;
    if (newInfo != null) {
      final info = newInfo.info;
      _state.refreshState(
        () {
          infoVideoFinal = info;
          final newTitle = info?.title;
          if (newTitle != null && newTitle.isNotEmpty) videoTitle = newTitle;
          videoChannel = info?.channelName?.nullifyEmpty() ?? videoChannel;
          duration = (info?.durSeconds ?? newInfo.audioStreams.firstOrNull?.duration?.inSeconds)?.secondsLabel ?? duration;
          publishedDate ??= info?.publishedAt.date;
          viewsCount ??= info?.viewsCount;
        },
      );
    }
  }
}
