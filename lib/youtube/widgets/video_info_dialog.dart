import 'package:flutter/material.dart';

import 'package:jiffy/jiffy.dart';
import 'package:photo_view/photo_view.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/videos/missing_video_info.dart';
import 'package:youtipie/class/videos/video_playability.dart';
import 'package:youtipie/class/videos/video_result.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/core/url_utils.dart';

import 'package:namida/base/yt_video_like_manager.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/track_info_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/functions/video_listens_dialog.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class VideoInfoDialog extends StatefulWidget {
  final String videoId;
  final StreamInfoItem? info;
  final String? saveLocation;
  final Map<String, String?>? tags;
  final List<Widget>? extraColumnChildren;

  const VideoInfoDialog({
    super.key,
    required this.videoId,
    this.info,
    this.saveLocation,
    this.tags,
    this.extraColumnChildren,
  });

  @override
  State<VideoInfoDialog> createState() => _VideoInfoDialogState();
}

class _VideoInfoDialogState extends State<VideoInfoDialog> {
  late final _videoLikeManager = YtVideoLikeManager(page: _videoPageInfo);
  final _videoPageInfo = Rxn<YoutiPieVideoPageResult?>();
  final _isLoadingInfo = false.obs;
  final _isLoadingThumbnail = false.obs;
  Color? _themeColor;
  bool _videoIsMissingOriginalInfo = false;
  VideoPlayabilty? _playablity;

  late final videoId = widget.videoId.replaceFirst(' ', '');
  late final isDummyVideoId = videoId.isEmpty || videoId == 'null';

  void _setLoadingIfThumbDoesntExist() {
    if (isDummyVideoId) return;
    final thumbInCache = ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(
      id: videoId,
      customUrl: null,
      isTemp: false,
      type: ThumbnailType.video,
    );
    if (thumbInCache == null) {
      _isLoadingThumbnail.value = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _videoLikeManager.init();
    _fillInfo();
    _fillMissingInfoIfRequired().then(
      (value) {
        _isLoadingInfo.value = false;
      },
    );
    _setLoadingIfThumbDoesntExist();
  }

  @override
  void dispose() {
    _videoLikeManager.dispose();
    _videoPageInfo.close();
    _isLoadingInfo.close();
    _isLoadingThumbnail.close();
    super.dispose();
  }

  bool isTitleFetchedFromMissingInfo = false;
  String? videoTitle;
  String? channelTitle;
  String? channelId;
  int? dateMS;
  int? durationSeconds;
  String? description;
  String? sourcesText;

  void _fillInfo() {
    if (isDummyVideoId) return;
    final videoId = this.videoId;

    final info = widget.info;

    String? title = info?.title;
    if (title == null || title.isEmpty) {
      title = YoutubeInfoController.utils.getVideoName(videoId, onMissingInfo: () {
        isTitleFetchedFromMissingInfo = true;
        VideoController.inst.videosPriorityManager.setVideoPriority(videoId, CacheVideoPriority.VIP);
      });
    } else if (title.isYTTitleFaulty()) {
      title = YoutubeInfoController.utils.getVideoName(videoId, onMissingInfo: null);
      isTitleFetchedFromMissingInfo = true;
      VideoController.inst.videosPriorityManager.setVideoPriority(videoId, CacheVideoPriority.VIP);
    }
    videoTitle = title ?? '?';

    channelTitle = info?.channel.title ?? YoutubeInfoController.utils.getVideoChannelName(videoId);
    channelId = info?.channel.id ?? YoutubeInfoController.utils.getVideoChannelID(videoId);
    dateMS = (info?.publishedAt.accurateDate ?? YoutubeInfoController.utils.getVideoReleaseDate(videoId))?.millisecondsSinceEpoch;
    durationSeconds = info?.durSeconds ?? YoutubeInfoController.utils.getVideoDurationSeconds(videoId);
    description = YoutubeInfoController.utils.getVideoDescription(videoId);

    _videoPageInfo.value = YoutubeInfoController.video.fetchVideoPageSync(videoId);
  }

  Future<void> _fillMissingInfoIfRequired() async {
    if (isDummyVideoId) {
      refreshState(() => _videoIsMissingOriginalInfo = true);
      return;
    }

    if (isTitleFetchedFromMissingInfo) refreshState(() => _videoIsMissingOriginalInfo = true);

    final videoId = this.videoId;
    if ((videoTitle != null && !videoTitle!.startsWith(YTUrlUtils.buildVideoUrl(videoId))) && //
        channelTitle != null &&
        dateMS != null) {
      return;
    }
    return _fillMissingInfoForce();
  }

  Future<void> _fillMissingInfoForce() async {
    final missingInfoCached = await YoutubeInfoController.missingInfo.fetchMissingInfoCache(videoId);
    if (missingInfoCached != null) {
      _refreshMissingInfo(missingInfoCached);
      _videoIsMissingOriginalInfo = true;
    }

    _isLoadingInfo.value = true;
    refreshState();

    final didRefreshWithLiveInfo = await _fillLiveInfo(videoId);
    if (didRefreshWithLiveInfo) {
      _videoIsMissingOriginalInfo = false;
      refreshState();
      if (_videoPageInfo.value == null) {
        YoutubeInfoController.video.fetchVideoPage(videoId, details: ExecuteDetails.forceRequest()).then((page) {
          refreshState(() {
            _videoPageInfo.value = page;
          });
        });
      }
      return;
    } else {
      // also dont check new missing info if cached version was set
      if (missingInfoCached != null) return;
    }

    _videoIsMissingOriginalInfo = true;
    refreshState();

    final newInfo = await YoutubeInfoController.missingInfo.fetchMissingInfo(videoId);
    if (newInfo != null) {
      _refreshMissingInfo(newInfo);
    }
  }

  Future<bool> _fillLiveInfo(String videoId) async {
    final originalInfo = await YoutubeInfoController.video.fetchVideoStreams(videoId, forceRequest: true);
    final originalVideoInfo = originalInfo?.info;
    if (originalInfo != null && originalVideoInfo != null && originalInfo.playability.status == VideoPlayabiltyStatus.ok) {
      videoTitle = originalVideoInfo.title;
      channelTitle = originalVideoInfo.channelName;
      channelId = originalVideoInfo.channelId;
      dateMS = (originalVideoInfo.publishedAt.accurateDate ?? originalVideoInfo.publishedAt.date)?.millisecondsSinceEpoch;
      durationSeconds = originalVideoInfo.durSeconds;
      description = originalVideoInfo.description;

      _playablity = originalInfo.playability;

      return true;
    } else if (originalInfo?.playability != null) {
      _playablity = originalInfo?.playability;
    }
    return false;
  }

  void _refreshMissingInfo(MissingVideoInfo newInfo) {
    _videoPageInfo.value ??= newInfo.videoPage;
    refreshState(() {
      videoTitle = newInfo.title; // cuz sometimes title is url etc
      channelTitle ??= newInfo.channelName;
      channelId ??= newInfo.channelId;
      dateMS ??= (newInfo.date.accurateDate ?? newInfo.date.date)?.millisecondsSinceEpoch;
      durationSeconds ??= newInfo.durSeconds;
      description ??= newInfo.description;
      sourcesText = newInfo.sources.map((e) => e.host).join(' & ');
      if (newInfo.subsource?.isNotEmpty == true) sourcesText = "$sourcesText (${newInfo.subsource})";
    });
  }

  @override
  Widget build(BuildContext context) {
    final videoId = this.videoId;
    final saveLocation = widget.saveLocation;
    final tags = widget.tags;
    final extraColumnChildren = widget.extraColumnChildren;

    final description = this.description;
    final descriptionWidget = description == null || description.isEmpty ? null : NamidaSelectableAutoLinkText(text: description);

    final dateText = dateMS?.dateAndClockFormattedOriginal;
    final dateAgo = dateMS == null ? '' : "\n(${Jiffy.parseFromMillisecondsSinceEpoch(dateMS!).fromNow()})";

    final theme = AppThemes.inst.getAppTheme(_themeColor);
    final headerIconColor = theme.colorScheme.primary;

    final totalListens = YoutubeHistoryController.inst.topTracksMapListens.value[videoId] ?? [];
    final firstListenTrack = totalListens.firstOrNull;

    final playabilityText = [
      _playablity?.reason,
      ...?_playablity?.messages,
    ].joinText(separator: ' - ');

    return AnimatedThemeOrTheme(
      data: theme,
      child: CustomBlurryDialog(
        theme: theme,
        horizontalInset: 38.0,
        normalTitleStyle: true,
        titleWidgetInPadding: ObxO(
          rx: _isLoadingInfo,
          builder: (context, loading) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lang.INFO,
                      style: theme.textTheme.displayLarge,
                    ),
                    if (loading) ...[
                      const SizedBox(width: 12.0),
                      SizedBox(
                        width: 12.0,
                        height: 12.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          value: null,
                        ),
                      ),
                    ],
                    if (_videoIsMissingOriginalInfo && !loading) ...[
                      const SizedBox(width: 6.0),
                      NamidaIconButton(
                        horizontalPadding: 6.0,
                        icon: Broken.refresh,
                        iconSize: 16.0,
                        onPressed: () => _fillMissingInfoForce().then((_) => _isLoadingInfo.value = false),
                      )
                    ],
                  ],
                ),
              ),
              Icon(
                Broken.eye,
                size: 18.0,
                color: headerIconColor,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ObxO(
                  rx: _videoPageInfo,
                  builder: (context, videoPageInfo) {
                    final viewsCountText =
                        (videoPageInfo?.videoInfo?.viewsCount)?.formatDecimalShort() ?? videoPageInfo?.videoInfo?.viewCountTextShort ?? videoPageInfo?.videoInfo?.viewCountTextLong;
                    return Text(
                      viewsCountText ?? '?',
                      style: theme.textTheme.displaySmall,
                    );
                  },
                ),
              ),
              const SizedBox(width: 6.0),
              ObxO(
                rx: _videoPageInfo,
                builder: (context, videoPageInfo) => ObxO(
                  rx: _videoLikeManager.currentVideoLikeStatus,
                  builder: (context, currentLikeStatus) {
                    final isUserLiked = currentLikeStatus == LikeStatus.liked;
                    final likesCount = videoPageInfo?.videoInfo?.engagement?.likesCount;
                    final videoLikeCount = likesCount == null && !isUserLiked ? null : (isUserLiked ? 1 : 0) + (likesCount ?? 0);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NamidaLoadingSwitcher(
                          size: 18.0,
                          builder: (loadingController) => NamidaRawLikeButton(
                            isLiked: isUserLiked,
                            likedIcon: Broken.like_filled,
                            normalIcon: Broken.like_1,
                            enabledColor: headerIconColor,
                            disabledColor: headerIconColor,
                            size: 18.0,
                            onTap: (isLiked) {
                              return _videoLikeManager.onLikeClicked(
                                YTVideoLikeParamters(
                                  isActive: isLiked,
                                  action: isLiked ? LikeAction.removeLike : LikeAction.addLike,
                                  onStart: loadingController.startLoading,
                                  onEnd: loadingController.stopLoading,
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            videoLikeCount?.formatDecimalShort() ?? '?',
                            style: theme.textTheme.displaySmall,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 6.0),
              ObxOClass(
                rx: YoutubePlaylistController.inst.favouritesPlaylist,
                builder: (context, favouritesPlaylist) => NamidaRawLikeButton(
                  size: 18.0,
                  likedIcon: Broken.heart_tick,
                  normalIcon: Broken.heart,
                  disabledColor: headerIconColor,
                  isLiked: favouritesPlaylist.isSubItemFavourite(videoId),
                  onTap: (isLiked) async => YoutubePlaylistController.inst.favouriteButtonOnPressed(videoId),
                ),
              ),
            ],
          ),
        ),
        child: LayoutWidthProvider(
          builder: (context, maxWidth) {
            final thumbWidth = maxWidth * 0.5;
            final artwork = YoutubeThumbnail(
              key: ValueKey(videoId),
              type: ThumbnailType.video,
              videoId: isDummyVideoId ? null : videoId,
              compressed: false,
              preferLowerRes: false,
              iconSize: 24.0,
              width: thumbWidth,
              height: thumbWidth * 9 / 16,
              forceSquared: true,
              isImportantInCache: false,
              extractColor: true,
              onColorReady: (color) async {
                if (color != null) {
                  await Future.delayed(const Duration(milliseconds: 200)); // navigation delay
                  refreshState(() {
                    _themeColor = color.color;
                  });
                }
              },
              onTopWidgets: (color) => [
                ObxO(
                  rx: _isLoadingThumbnail,
                  builder: (context, loading) => loading
                      ? Positioned(
                          bottom: 8.0,
                          right: 8.0,
                          child: SizedBox(
                            width: 14.0,
                            height: 14.0,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.0,
                            ),
                          ),
                        )
                      : SizedBox(),
                )
              ],
              fetchMissingIfRequired: true,
              onImageReady: (_) => _isLoadingThumbnail.value = false,
            );
            return SizedBox(
              height: context.height * 0.7,
              width: maxWidth,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24.0),
                          NamidaInkWell(
                            padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                            onTap: () => showVideoListensDialog(videoId, colorScheme: _themeColor),
                            borderRadius: 12.0,
                            child: Row(
                              children: [
                                const SizedBox(width: 2.0),
                                TapDetector(
                                  onTap: () {
                                    final imgFile = ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(id: videoId, type: ThumbnailType.video);
                                    if (imgFile == null) return;
                                    NamidaNavigator.inst.navigateDialog(
                                      scale: 1.0,
                                      blackBg: true,
                                      dialog: LongPressDetector(
                                        onLongPress: () async {
                                          final saveDirPath = await YTUtils.copyThumbnailToStorage(videoId);
                                          String title = lang.COPIED_ARTWORK;
                                          String subtitle = '${lang.SAVED_IN} $saveDirPath';
                                          Color snackColor = _themeColor ?? CurrentColor.inst.color;

                                          if (saveDirPath == null) {
                                            title = lang.ERROR;
                                            subtitle = lang.COULDNT_SAVE_IMAGE;
                                            snackColor = Colors.red;
                                          }
                                          snackyy(
                                            title: title,
                                            message: subtitle,
                                            leftBarIndicatorColor: snackColor,
                                            altDesign: true,
                                            top: false,
                                          );
                                        },
                                        child: PhotoView(
                                          gaplessPlayback: true,
                                          tightMode: true,
                                          minScale: PhotoViewComputedScale.contained,
                                          loadingBuilder: (context, event) => artwork,
                                          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                                          filterQuality: FilterQuality.high,
                                          imageProvider: FileImage(imgFile),
                                        ),
                                      ),
                                    );
                                  },
                                  child: artwork,
                                ),
                                const SizedBox(width: 10.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Broken.hashtag_1,
                                            size: 18.0,
                                          ),
                                          const SizedBox(width: 4.0),
                                          Expanded(
                                            child: Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  '${lang.TOTAL_LISTENS}: ',
                                                  style: theme.textTheme.displaySmall,
                                                ),
                                                Text(
                                                  '${totalListens.length}',
                                                  style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8.0),
                                      Row(
                                        children: [
                                          const Icon(
                                            Broken.cake,
                                            size: 18.0,
                                          ),
                                          const SizedBox(width: 4.0),
                                          Expanded(
                                            child: Text(
                                              firstListenTrack?.dateAndClockFormattedOriginal ?? lang.MAKE_YOUR_FIRST_LISTEN,
                                              style: theme.textTheme.displaySmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12.0),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          if (_videoIsMissingOriginalInfo)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Broken.danger,
                                    size: 21.0,
                                  ),
                                  SizedBox(width: 6.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          lang.THIS_VIDEO_IS_LIKELY_DELETED_OR_SET_TO_PRIVATE,
                                          style: theme.textTheme.displaySmall,
                                        ),
                                        if (playabilityText.isNotEmpty && playabilityText != 'Video unavailable' && playabilityText != 'This video is unavailable')
                                          Text(
                                            playabilityText.addDQuotation(),
                                            style: theme.textTheme.displaySmall?.copyWith(
                                              fontSize: 11.0,
                                            ),
                                          ),
                                        if (sourcesText != null)
                                          Text(
                                            "${lang.SOURCE}: ${sourcesText!}",
                                            style: theme.textTheme.displaySmall?.copyWith(
                                              fontSize: 11.0,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          TrackInfoListTile(
                            title: lang.TITLE,
                            value: videoTitle ?? '',
                            icon: Broken.text,
                          ),
                          TrackInfoListTile(
                            title: lang.CHANNEL,
                            value: channelTitle ?? '',
                            icon: Broken.user,
                          ),
                          TrackInfoListTile(
                            title: lang.DATE,
                            value: dateText == null ? '' : "$dateText$dateAgo",
                            icon: Broken.calendar,
                          ),
                          TrackInfoListTile(
                            title: lang.DURATION,
                            value: durationSeconds?.secondsLabel ?? '',
                            icon: Broken.clock,
                          ),
                          TrackInfoListTile(
                            title: 'ID',
                            value: isDummyVideoId ? '' : videoId,
                            icon: Broken.video_square,
                          ),
                          TrackInfoListTile(
                            title: lang.LINK,
                            value: isDummyVideoId ? '' : YTUrlUtils.buildVideoUrl(videoId),
                            icon: Broken.link_1,
                          ),
                          TrackInfoListTile(
                            title: "${lang.LINK} (${lang.CHANNEL})",
                            value: channelId != null && channelId!.isNotEmpty ? YTUrlUtils.buildChannelUrl(channelId!) : '?',
                            icon: Broken.link_1,
                          ),
                          if (saveLocation != null)
                            TrackInfoListTile(
                              title: lang.PATH,
                              value: saveLocation,
                              icon: Broken.location,
                            ),
                          TrackInfoListTile(
                            title: lang.DESCRIPTION,
                            value: description ?? '',
                            icon: Broken.message_text_1,
                            child: descriptionWidget,
                          ),
                          if (tags != null)
                            TrackInfoListTile(
                              title: lang.TAGS,
                              value: tags.entries.map((e) => e.value == null ? null : "- ${e.key}: ${e.value}").whereType<String>().join('\n'),
                              icon: Broken.tag,
                            ),
                        ]
                            .addSeparators(
                              separator: NamidaContainerDivider(
                                height: 1.5,
                                colorForce: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                              ),
                              skipFirst: 4,
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  if (extraColumnChildren != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.cardColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Column(
                          children: extraColumnChildren,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
