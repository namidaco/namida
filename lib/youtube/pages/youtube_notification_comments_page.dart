import 'dart:async';

import 'package:flutter/material.dart';

import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:youtipie/class/comments/comment_info_item.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/result_wrapper/comment_notification_result.dart';
import 'package:youtipie/class/result_wrapper/comment_reply_result.dart';
import 'package:youtipie/class/result_wrapper/comment_result.dart';
import 'package:youtipie/class/result_wrapper/notification_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_notification.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/scroll_physics_modified.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/widgets/yt_comment_card.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_notification_card.dart';
import 'package:namida/youtube/yt_minplayer_comment_replies_subpage.dart';

class YoutubeNotificationCommentsPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_NOTIFICATION_COMMENTS_SUBPAGE;
  @override
  String? get name => notification.notificationId;

  final StreamInfoItemNotification notification;
  final YoutiPieNotificationResult Function() mainNotificationsList;
  final int index;
  final double thumbnailWidth;
  final double thumbnailHeight;

  const YoutubeNotificationCommentsPage({
    super.key,
    required this.notification,
    required this.mainNotificationsList,
    required this.index,
    required this.thumbnailWidth,
    required this.thumbnailHeight,
  });

  @override
  State<YoutubeNotificationCommentsPage> createState() => _YoutubeNotificationCommentsPageState();
}

class _YoutubeNotificationCommentsPageState extends State<YoutubeNotificationCommentsPage> {
  late final ScrollController sc;
  late final _lastFetchWasCached = Rxn<bool>();
  late final _isLoadingInitialComments = Rxn<bool>();
  late final _isLoadingMoreComments = Rxn<bool>();
  late final _currentComments = Rxn<YoutiPieCommentResult>();

  bool _didOpenLinkedReply = false;

  String get _videoId => widget.notification.id;
  String get _linkedCommentId => widget.notification.linkedCommentId ?? '';

  @override
  void initState() {
    super.initState();
    sc = NamidaScrollController.create();

    _isLoadingInitialComments.value = true;
    _initValues().whenComplete(
      () => _isLoadingInitialComments.value = false,
    );
  }

  @override
  void dispose() {
    sc.dispose();
    _lastFetchWasCached.close();
    _isLoadingInitialComments.close();
    _isLoadingMoreComments.close();
    _currentComments.close();
    super.dispose();
  }

  Future<void> _initValues() async {
    if (_videoId.isEmpty || _linkedCommentId.isEmpty) return;

    final cached = await YoutiPie.cacheBuilder.forNotificationComments(videoId: _videoId, linkedCommentId: _linkedCommentId).read();
    if (cached != null) {
      _currentComments.value = cached;
      _lastFetchWasCached.value = true;
      _openLinkedReplyIfNeeded();
    } else {
      return _fetchComments();
    }
  }

  void _showNetworkError() {
    Timer(Duration.zero, () {
      snackyy(
        title: "${lang.error} (${lang.comments})",
        message: lang.noNetworkAvailableToFetchData,
        isError: true,
        top: false,
      );
    });
  }

  Future<void> _fetchComments({bool forceRequest = false}) async {
    if (!ConnectivityController.inst.hasConnection) return _showNetworkError();

    _lastFetchWasCached.value = false;
    final res = await YoutubeInfoController.comment.fetchNotificationComments(
      videoId: _videoId,
      linkedCommentId: _linkedCommentId,
      details: forceRequest ? ExecuteDetails.kForceRequest : null,
    );
    if (res != null) {
      _currentComments.value?.transferLocalItemsTo(res);
      _currentComments.value = res;
      _openLinkedReplyIfNeeded();
    } else {
      _lastFetchWasCached.value = true;
    }
  }

  Future<bool> _fetchCommentsNext() async {
    bool fetched = false;
    final comments = _currentComments;
    if (comments.value?.canFetchNext != true) return fetched;

    _isLoadingMoreComments.value = true;
    fetched = await comments.value?.fetchNext() ?? false;
    if (fetched == true) comments.refresh();
    _isLoadingMoreComments.value = false;
    return fetched;
  }

  void _openLinkedReplyIfNeeded() {
    if (_didOpenLinkedReply || !mounted) return;
    final comments = _currentComments.value;
    if (comments is! YoutiPieNotificationCommentResult || comments.linkedReply == null) return;
    final mainComment = comments.items.firstWhereEff((e) => e.commentId == comments.linkedMainCommentId);
    if (mainComment == null) return;
    _didOpenLinkedReply = true;
    _openReplies(mainComment);
  }

  void _openReplies(CommentInfoItem comment) {
    final comments = _currentComments.value;
    if (comments == null) return;

    YoutiPieCommentReplyResult? initialReplies;
    if (comments is YoutiPieNotificationCommentResult) {
      final linkedReply = comments.linkedReply;
      // -- not written to cache, it holds a single reply.
      if (linkedReply != null && comments.linkedMainCommentId == comment.commentId) {
        initialReplies = YoutiPieCommentReplyResult(
          commentId: comment.commentId,
          cacheKey: comment.commentId,
          items: [linkedReply],
          continuation: null,
        );
      }
    }

    YTMiniplayerCommentRepliesSubpage(
      videoId: _videoId,
      initialComment: comment,
      mainList: () => comments,
      repliesCount: comment.repliesCount,
      initialReplies: initialReplies,
      displayBackButton: false,
      useGlobalPadding: true,
    ).navigate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final commentsIconColor = theme.iconTheme.color;

    return BackgroundWrapper(
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  blurRadius: 12.0,
                  color: theme.secondaryHeaderColor.withOpacityExt(0.5),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 6.0),
                Row(
                  children: [
                    const SizedBox(width: 12.0),
                    ObxO(
                      rx: _lastFetchWasCached,
                      builder: (context, isFromCache) => (isFromCache ?? false)
                          ? StackedIcon(
                              baseIcon: Broken.document,
                              secondaryIcon: Broken.global,
                              iconSize: 22.0,
                              secondaryIconSize: 12.0,
                              baseIconColor: commentsIconColor,
                              secondaryIconColor: commentsIconColor,
                            )
                          : const Icon(
                              Broken.document,
                              size: 22.0,
                            ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        lang.comments,
                        style: textTheme.displayMedium,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                  ],
                ),
                const SizedBox(height: 6.0),
                VideoTilePropertiesProvider(
                  configs: const VideoTilePropertiesConfigs(
                    queueSource: QueueSourceYoutubeID.ytNotificationsHosted,
                    horizontalGestures: false,
                  ),
                  builder: (properties) => YoutubeVideoCardNotification(
                    properties: properties,
                    notification: widget.notification,
                    mainList: widget.mainNotificationsList,
                    index: widget.index,
                    playlistID: null,
                    thumbnailWidth: widget.thumbnailWidth,
                    thumbnailHeight: widget.thumbnailHeight,
                    canOpenComments: false,
                  ),
                ),
                const NamidaContainerDivider(
                  margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                ),
              ],
            ),
          ),
          Expanded(
            child: NamidaScrollbar(
              controller: sc,
              child: PullToRefresh(
                maxDistance: 64.0,
                controller: sc,
                onRefresh: () async {
                  if (!ConnectivityController.inst.hasConnection) return;
                  try {
                    sc.jumpTo(0);
                  } catch (_) {}
                  return _fetchComments(forceRequest: true);
                },
                child: LazyLoadListView(
                  onReachingEnd: _fetchCommentsNext,
                  extend: 400,
                  scrollController: sc,
                  listview: (controller) => SmoothCustomScrollView(
                    physics: const ClampingScrollPhysicsModified(),
                    controller: controller,
                    slivers: [
                      ObxO(
                        rx: _isLoadingInitialComments,
                        builder: (context, loadingInitial) {
                          if (loadingInitial == true) {
                            return SliverToBoxAdapter(
                              child: ShimmerWrapper(
                                transparent: false,
                                shimmerEnabled: true,
                                child: SuperSmoothListView.builder(
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: 10,
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) {
                                    return const YTCommentCard(
                                      margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                      comment: null,
                                      mainList: null,
                                      videoId: null,
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                          return ObxO(
                            rx: _currentComments,
                            builder: (context, comments) {
                              if (comments == null) return const SliverToBoxAdapter();
                              return SuperSliverList.builder(
                                itemCount: comments.length,
                                itemBuilder: (context, i) {
                                  final comment = comments.items[i];
                                  return YTCommentCard(
                                    key: Key(comment.commentId),
                                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                    comment: comment,
                                    mainList: () => comments,
                                    videoId: _videoId,
                                    commentsListForEdit: _currentComments,
                                    onRepliesTap: _openReplies,
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      ObxO(
                        rx: _isLoadingMoreComments,
                        builder: (context, isLoadingMore) => isLoadingMore == true
                            ? const SliverPadding(
                                padding: EdgeInsets.all(12.0),
                                sliver: SliverToBoxAdapter(
                                  child: Center(
                                    child: LoadingIndicator(),
                                  ),
                                ),
                              )
                            : const SliverToBoxAdapter(),
                      ),
                      const SliverPadding(padding: EdgeInsets.only(bottom: Dimensions.globalBottomPaddingTotal)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
