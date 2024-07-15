import 'package:flutter/widgets.dart';
import 'package:youtipie/class/comments/comment_info_item.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/result_wrapper/comment_reply_result.dart';
import 'package:youtipie/class/result_wrapper/comment_result.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/scroll_physics_modified.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/widgets/yt_comment_card.dart';

class YTMiniplayerCommentRepliesSubpage extends StatefulWidget {
  final String? videoId;
  final CommentInfoItem comment;
  final YoutiPieCommentResult Function() mainList;
  final int? repliesCount;

  const YTMiniplayerCommentRepliesSubpage({
    super.key,
    this.videoId,
    required this.comment,
    required this.mainList,
    required this.repliesCount,
  });

  @override
  State<YTMiniplayerCommentRepliesSubpage> createState() => _YTMiniplayerCommentRepliesSubpageState();
}

class _YTMiniplayerCommentRepliesSubpageState extends State<YTMiniplayerCommentRepliesSubpage> {
  late final ScrollController sc;
  late final _lastFetchWasCached = Rxn<bool>();
  late final _isLoadingCurrentReplies = Rxn<bool>();
  late final _isLoadingMoreReplies = Rxn<bool>();
  late final _currentReplies = Rxn<YoutiPieCommentReplyResult>();

  @override
  void initState() {
    super.initState();
    sc = ScrollController();
    final cachedReplies = YoutiPie.cacheBuilder.forCommentReplies(commentId: widget.comment.commentId).read();
    if (cachedReplies != null) {
      _currentReplies.value = cachedReplies;
      _lastFetchWasCached.value = true;
    } else {
      _fetchReplies();
    }
  }

  @override
  void dispose() {
    sc.dispose();
    _lastFetchWasCached.close();
    _isLoadingCurrentReplies.close();
    _isLoadingMoreReplies.close();
    _currentReplies.close();
    super.dispose();
  }

  bool get _hasConnection => ConnectivityController.inst.hasConnection;
  void _showNetworkError() {
    snackyy(
      title: lang.ERROR,
      message: lang.NO_NETWORK_AVAILABLE_TO_FETCH_DATA,
      isError: true,
      top: false,
    );
  }

  Future<void> _fetchReplies() async {
    if (!_hasConnection) return _showNetworkError();

    _lastFetchWasCached.value = false;
    _isLoadingCurrentReplies.value = true;
    final val = await YoutubeInfoController.comment.fetchCommentReplies(
      mainComment: widget.comment,
      details: ExecuteDetails.forceRequest(),
    );
    _isLoadingCurrentReplies.value = false;
    if (val != null) {
      _currentReplies.value = val;
    } else {
      _lastFetchWasCached.value = true;
    }
  }

  Future<bool> _fetchRepliesNext() async {
    bool fetched = false;
    final replies = _currentReplies;
    if (replies.value?.canFetchNext != true) return fetched;

    _isLoadingMoreReplies.value = true;
    fetched = await replies.value?.fetchNext() ?? false;
    if (fetched == true) replies.refresh();
    _isLoadingMoreReplies.value = false;
    return fetched;
  }

  @override
  Widget build(BuildContext context) {
    final commentsIconColor = context.theme.iconTheme.color;
    final repliesCount = widget.repliesCount;
    return BackgroundWrapper(
      child: ObxO(
        rx: Player.inst.currentItem,
        builder: (currentItem) {
          if (currentItem is! YoutubeID) return const SizedBox();
          final currentId = currentItem.id;
          return Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12.0,
                      color: context.theme.secondaryHeaderColor.withOpacity(0.5),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(width: 12.0),
                        NamidaIconButton(
                          horizontalPadding: 0,
                          icon: Broken.arrow_left_2,
                          onPressed: NamidaNavigator.inst.popPage,
                        ),
                        const SizedBox(width: 12.0),
                        ObxO(
                          rx: _lastFetchWasCached,
                          builder: (isRepliesFromCache) => (isRepliesFromCache ?? false)
                              ? StackedIcon(
                                  baseIcon: Broken.note_2,
                                  secondaryIcon: Broken.global,
                                  iconSize: 22.0,
                                  secondaryIconSize: 12.0,
                                  baseIconColor: commentsIconColor,
                                  secondaryIconColor: commentsIconColor,
                                )
                              : const Icon(
                                  Broken.note_2,
                                  size: 22.0,
                                ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            [
                              lang.REPLIES,
                              if (repliesCount != null) repliesCount.formatDecimalShort(),
                            ].join(' • '),
                            style: context.textTheme.displayMedium,
                            textAlign: TextAlign.start,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                      ],
                    ),
                    const SizedBox(height: 12.0),
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
                      return _fetchReplies();
                    },
                    child: LazyLoadListView(
                      onReachingEnd: _fetchRepliesNext,
                      scrollController: sc,
                      listview: (controller) => CustomScrollView(
                        physics: const ClampingScrollPhysicsModified(),
                        controller: controller,
                        slivers: [
                          SliverToBoxAdapter(
                            child: YTCommentCard(
                              key: Key(widget.comment.commentId),
                              bgAlpha: 200,
                              showRepliesBox: false,
                              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                              comment: widget.comment,
                              mainList: widget.mainList,
                              videoId: currentId,
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: NamidaContainerDivider(
                              margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            ),
                          ),
                          ObxO(
                            rx: _isLoadingCurrentReplies,
                            builder: (loadingInitial) {
                              if (loadingInitial == true) {
                                return SliverToBoxAdapter(
                                  child: ShimmerWrapper(
                                    transparent: false,
                                    shimmerEnabled: true,
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: repliesCount?.withMaximum(20) ?? 10,
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
                                rx: _currentReplies,
                                builder: (replies) {
                                  if (replies == null) return const SliverToBoxAdapter();
                                  return SliverList.builder(
                                    itemCount: replies.length,
                                    itemBuilder: (context, i) {
                                      final reply = replies.items[i];
                                      return YTCommentCard(
                                        key: Key(reply.commentId),
                                        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                        comment: reply,
                                        mainList: () => replies,
                                        videoId: currentId,
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          ObxO(
                            rx: _isLoadingMoreReplies,
                            builder: (isLoadingMore) => isLoadingMore == true
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
                          const SliverPadding(padding: EdgeInsets.only(bottom: kYTQueueSheetMinHeight + 12.0))
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
