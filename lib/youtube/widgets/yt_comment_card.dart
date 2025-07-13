import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:youtipie/class/comments/comment_info_item.dart';
import 'package:youtipie/class/comments/comment_info_item_base.dart';
import 'package:youtipie/class/result_wrapper/comment_reply_result.dart';
import 'package:youtipie/class/result_wrapper/comment_result.dart';
import 'package:youtipie/class/result_wrapper/list_wrapper_base.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/widgets/namida_read_more.dart';
import 'package:namida/youtube/widgets/yt_description_widget.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_minplayer_comment_replies_subpage.dart';
import 'package:namida/youtube/yt_utils.dart';

class YTCommentCard<W extends YoutiPieListWrapper<CommentInfoItemBase>> extends StatefulWidget {
  final EdgeInsetsGeometry? margin;
  final int bgAlpha;
  final bool showRepliesBox;
  final String? videoId;
  final CommentInfoItemBase? comment;
  final W Function()? mainList;

  final CommentInfoItem Function()? mainCommentForReplies;
  final RxBaseCore<YoutiPieCommentReplyResult?>? mainRepliesList;
  final void Function(CommentInfoItem editedComment) Function()? onCommentEdited;
  final void Function() Function()? onCommentDeleted;

  const YTCommentCard({
    super.key,
    required this.margin,
    this.bgAlpha = 100,
    this.showRepliesBox = true,
    required this.videoId,
    required this.comment,
    required this.mainList,
    this.mainCommentForReplies,
    this.mainRepliesList,
    this.onCommentEdited,
    this.onCommentDeleted,
  });

  @override
  State<YTCommentCard> createState() => _YTCommentCardState();
}

class _YTCommentCardState extends State<YTCommentCard> {
  late final _currentLikeStatus = Rxn<LikeStatus>(widget.comment?.likeStatus);

  @override
  void dispose() {
    _currentLikeStatus.close();
    super.dispose();
  }

  Future<bool> _onChangeLikeStatus(bool isLiked, LikeAction action, void Function() onStart, void Function() onEnd) async {
    final comment = this.widget.comment;
    final mainList = this.widget.mainList;
    if (comment == null || mainList == null) return isLiked;

    onStart();
    final res = await YoutubeInfoController.commentAction.changeLikeStatus(
      comment: comment,
      mainList: mainList(),
      action: action,
    );
    onEnd();
    if (res == true) {
      _currentLikeStatus.value = _currentLikeStatus.value = action.toExpectedStatus();
      return !isLiked;
    }

    return isLiked;
  }

  void _onRepliesTap({required CommentInfoItem comment, required int? repliesCount}) {
    final mainList = widget.mainList;
    if (mainList == null) return;
    if (mainList is! YoutiPieCommentResult Function()) return;
    NamidaNavigator.inst.isInYTCommentRepliesSubpage = true;
    NamidaNavigator.inst.ytMiniplayerCommentsPageKey.currentState?.pushPage(
      YTMiniplayerCommentRepliesSubpage(
        initialComment: comment,
        mainList: mainList,
        repliesCount: repliesCount,
        videoId: widget.videoId,
      ),
      maintainState: false,
    );
  }

  List<NamidaPopupItem> _getCommentPopupItems() {
    final comment = widget.comment;
    final activeChannel = YoutubeAccountController.current.activeAccountChannel.value;
    final isUserOwnedComment = activeChannel != null && (activeChannel.id == comment?.author?.channelId);

    NamidaPopupItem? editCommentOrReply;
    NamidaPopupItem? deleteCommentOrReply;
    if (isUserOwnedComment) {
      if (comment is CommentInfoItem) {
        // -- is comment
        editCommentOrReply = NamidaPopupItem(
          icon: Broken.sms_edit,
          title: lang.EDIT,
          subtitle: lang.COMMENT,
          onTap: () {
            YTUtils.comments.editComment(
              videoId: widget.videoId ?? '',
              comment: comment,
              mainList: YoutubeInfoController.current.currentComments,
              mainRepliesList: widget.mainRepliesList,
              onEdited: widget.onCommentEdited?.call(),
            );
          },
        );
        deleteCommentOrReply = NamidaPopupItem(
          icon: Broken.pen_remove,
          title: lang.DELETE,
          subtitle: lang.COMMENT,
          onTap: () {
            YTUtils.comments.deleteComment(
              videoId: widget.videoId ?? '',
              comment: comment,
              mainList: YoutubeInfoController.current.currentComments,
              mainRepliesList: widget.mainRepliesList,
              onDeleted: widget.onCommentDeleted?.call(),
            );
          },
        );
      } else if (comment is CommentInfoItemBase) {
        // -- is reply
        editCommentOrReply = NamidaPopupItem(
          icon: Broken.message_edit,
          title: lang.EDIT,
          subtitle: lang.REPLY,
          onTap: () {
            if (widget.mainCommentForReplies != null) {
              YTUtils.comments.editReply(
                videoId: widget.videoId ?? '',
                mainComment: widget.mainCommentForReplies!(),
                reply: comment,
                mainList: widget.mainRepliesList,
              );
            }
          },
        );
        deleteCommentOrReply = NamidaPopupItem(
          icon: Broken.message_minus,
          title: lang.DELETE,
          subtitle: lang.REPLY,
          onTap: () {
            YTUtils.comments.deleteReply(
              videoId: widget.videoId ?? '',
              mainComment: widget.mainCommentForReplies!(),
              reply: comment,
              mainList: widget.mainRepliesList,
            );
          },
        );
      }
    }
    return [
      NamidaPopupItem(
        icon: Broken.copy,
        title: lang.COPY,
        onTap: () {
          final rawText = comment?.content.rawText;
          if (rawText != null) {
            Clipboard.setData(ClipboardData(text: rawText));
          }
        },
      ),
      NamidaPopupItem(
        icon: Broken.user,
        title: lang.GO_TO_CHANNEL,
        onTap: () {
          final channelId = comment?.author?.channelId;
          if (channelId != null) {
            YTChannelSubpage(channelID: channelId).navigate();
          }
        },
      ),
      if (editCommentOrReply != null) editCommentOrReply,
      if (deleteCommentOrReply != null) deleteCommentOrReply,
      NamidaPopupItem(
        icon: Broken.message_add_1,
        title: lang.REPLY,
        onTap: () {
          if (comment == null) return;
          YTUtils.comments.createReply(
            videoId: widget.videoId ?? '',
            mainComment: comment,
            replyingTo: comment,
            mainList: widget.mainRepliesList,
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final comment = this.widget.comment;
    final uploaderAvatar = comment?.authorAvatarUrl ?? comment?.author?.avatarThumbnailUrl;
    final author = comment?.author?.displayName;
    final isArtist = comment?.author?.isArtist ?? false;

    final uploadedFromDate = comment?.publishedAt.date;
    String? uploadedFromText = uploadedFromDate == null ? null : TimeAgoController.dateFromNow(uploadedFromDate);
    uploadedFromText ??= comment?.publishedTimeText;

    final commentContent = comment?.content;
    final isHearted = comment?.isHearted ?? false;

    final containerColor = context.theme.cardColor.withAlpha(widget.bgAlpha);
    final readmoreColor = context.theme.colorScheme.primary.withAlpha(160);

    final authorTextColor = context.theme.colorScheme.onSurface.withAlpha(180);
    final authorTextStyle = context.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w400,
      color: authorTextColor,
    );

    return LayoutWidthProvider(
      builder: (context, maxWidth) {
        final thumbSize = 38.0.withMaximum(maxWidth * 0.15);
        return Stack(
          children: [
            Padding(
              padding: widget.margin ?? EdgeInsets.zero,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                  boxShadow: [
                    BoxShadow(
                      color: context.theme.secondaryHeaderColor.withAlpha(60),
                      blurRadius: 4.0,
                      spreadRadius: 1.5,
                      offset: const Offset(0.0, 1.0),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: SizedBox(
                    width: maxWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NamidaDummyContainer(
                          width: thumbSize,
                          height: thumbSize,
                          isCircle: true,
                          shimmerEnabled: uploaderAvatar == null,
                          child: YoutubeThumbnail(
                            type: ThumbnailType.channel,
                            key: Key(uploaderAvatar ?? ''),
                            isImportantInCache: false,
                            customUrl: uploaderAvatar,
                            width: thumbSize,
                            isCircle: true,
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2.0),
                              if (comment is CommentInfoItem && comment.isPinned) ...[
                                Row(
                                  children: [
                                    const Icon(
                                      Broken.path,
                                      size: 14.0,
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      lang.PINNED,
                                      style: context.textTheme.displaySmall?.copyWith(
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2.0),
                              ],
                              NamidaDummyContainer(
                                width: maxWidth * 0.5,
                                height: 12.0,
                                borderRadius: 6.0,
                                shimmerEnabled: author == null,
                                child: FittedBox(
                                  alignment: Alignment.centerLeft,
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    children: [
                                      if (author != null)
                                        Text(
                                          author,
                                          style: authorTextStyle,
                                        ),
                                      if (uploadedFromText != null)
                                        Text(
                                          " • $uploadedFromText",
                                          style: authorTextStyle,
                                        ),
                                      if (comment?.isEdited == true) ...[
                                        const SizedBox(width: 4.0),
                                        Icon(
                                          Broken.edit_2,
                                          size: 12.0,
                                          color: authorTextColor,
                                        ),
                                      ],
                                      if (isArtist) ...[
                                        const SizedBox(width: 4.0),
                                        Icon(
                                          Broken.musicnote,
                                          size: 12.0,
                                          color: authorTextColor,
                                        ),
                                      ],
                                      if (isHearted) ...[
                                        const SizedBox(width: 4.0),
                                        const Icon(
                                          Broken.heart_tick,
                                          size: 14.0,
                                          color: Color.fromARGB(210, 233, 80, 112),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: commentContent == null
                                      ? Column(
                                          children: [
                                            ...List.filled(
                                              (4 - 1).getRandomNumberBelow(1),
                                              const Padding(
                                                padding: EdgeInsets.only(top: 2.0),
                                                child: NamidaDummyContainer(
                                                  width: null,
                                                  height: 12.0,
                                                  borderRadius: 4.0,
                                                  shimmerEnabled: true,
                                                  child: null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : commentContent.rawText == null
                                          ? const SizedBox()
                                          : YoutubeDescriptionWidget(
                                              videoId: widget.videoId,
                                              content: commentContent,
                                              linkColor: context.theme.colorScheme.primary.withAlpha(210),
                                              childBuilder: (span) {
                                                return NamidaReadMoreText(
                                                  span: span,
                                                  lines: 5,
                                                  builder: (span, lines, isExpanded, exceededMaxLines, toggle) {
                                                    return Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text.rich(
                                                          span,
                                                          maxLines: lines,
                                                        ),
                                                        if (exceededMaxLines)
                                                          Padding(
                                                            padding: const EdgeInsets.all(8.0),
                                                            child: TapDetector(
                                                              onTap: toggle,
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.end,
                                                                children: [
                                                                  Text(
                                                                    isExpanded ? '' : lang.SHOW_MORE,
                                                                    style: context.textTheme.displaySmall?.copyWith(color: readmoreColor),
                                                                  ),
                                                                  const SizedBox(width: 8),
                                                                  Icon(
                                                                    isExpanded ? Broken.arrow_up_3 : Broken.arrow_down_2,
                                                                    size: 18.0,
                                                                    color: readmoreColor,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                            )),
                              const SizedBox(height: 8.0),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: ObxO(
                                  rx: _currentLikeStatus,
                                  builder: (context, currentLikeStatus) {
                                    int? likeCount = comment?.likesCount;
                                    if (likeCount != null && currentLikeStatus == LikeStatus.liked) likeCount++;
                                    return Row(
                                      children: [
                                        if (comment != null)
                                          NamidaLoadingSwitcher(
                                            size: 16.0,
                                            builder: (loadingController) => NamidaRawLikeButton(
                                              isLiked: currentLikeStatus == LikeStatus.liked,
                                              likedIcon: Broken.like_filled,
                                              normalIcon: Broken.like_1,
                                              size: 16.0,
                                              onTap: (isLiked) async {
                                                return _onChangeLikeStatus(
                                                  isLiked,
                                                  isLiked ? LikeAction.removeLike : LikeAction.addLike,
                                                  loadingController.startLoading,
                                                  loadingController.stopLoading,
                                                );
                                              },
                                            ),
                                          ),
                                        if (likeCount == null || likeCount > 0) ...[
                                          const SizedBox(width: 4.0),
                                          NamidaDummyContainer(
                                            width: 18.0,
                                            height: 8.0,
                                            borderRadius: 4.0,
                                            shimmerEnabled: likeCount == null,
                                            child: Text(
                                              likeCount?.formatDecimalShort() ?? '?',
                                              style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w400),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(width: 12.0),
                                        if (comment != null)
                                          NamidaLoadingSwitcher(
                                            size: 16.0,
                                            builder: (loadingController) => NamidaRawLikeButton(
                                              isLiked: currentLikeStatus == LikeStatus.disliked,
                                              likedIcon: Broken.dislike_filled,
                                              normalIcon: Broken.dislike,
                                              size: 16.0,
                                              onTap: (isDisLiked) async {
                                                return _onChangeLikeStatus(
                                                  isDisLiked,
                                                  isDisLiked ? LikeAction.removeDislike : LikeAction.addDislike,
                                                  loadingController.startLoading,
                                                  loadingController.stopLoading,
                                                );
                                              },
                                            ),
                                          ),
                                        if (widget.showRepliesBox && comment is CommentInfoItem) const SizedBox(width: 8.0),
                                        if (widget.showRepliesBox && comment is CommentInfoItem)
                                          NamidaInkWellButton(
                                            sizeMultiplier: 0.8,
                                            borderRadius: 6.0,
                                            onTap: () => _onRepliesTap(comment: comment, repliesCount: comment.repliesCount),
                                            bgColor: context.theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
                                            icon: Broken.document,
                                            text: [
                                              lang.REPLIES,
                                              if (comment.repliesCount != null) comment.repliesCount!,
                                            ].join(' • '),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6.0 + 12.0), // right + iconWidth
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: NamidaPopupWrapper(
                childrenDefault: _getCommentPopupItems,
                child: const Padding(
                  padding: EdgeInsets.all(12.0 + 4.0),
                  child: MoreIcon(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class YTCommentCardCompact extends StatelessWidget {
  final CommentInfoItem? comment;
  const YTCommentCardCompact({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    final uploaderAvatar = comment?.authorAvatarUrl ?? comment?.author?.avatarThumbnailUrl;
    final author = comment?.author?.displayName;

    final uploadedFromDate = comment?.publishedAt.date;
    String? uploadedFromText = uploadedFromDate == null ? null : TimeAgoController.dateFromNow(uploadedFromDate);
    uploadedFromText ??= comment?.publishedTimeText;

    final commentTextParsed = comment?.content.rawText;
    final likeCount = comment?.likesCount;
    final repliesCount = comment?.repliesCount;
    final isHearted = comment?.isHearted ?? false;
    final isPinned = comment?.isPinned ?? false;
    final isArtist = comment?.author?.isArtist ?? false;

    final authorTextColor = context.theme.colorScheme.onSurface.withAlpha(180);
    final authorTextStyle = context.textTheme.displaySmall?.copyWith(
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
      color: authorTextColor,
    );

    return LayoutWidthProvider(
      builder: (context, maxWidth) {
        final thumbSize = 28.0.withMaximum(maxWidth * 0.1);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NamidaDummyContainer(
              width: thumbSize,
              height: thumbSize,
              isCircle: true,
              shimmerEnabled: uploaderAvatar == null,
              child: YoutubeThumbnail(
                type: ThumbnailType.channel,
                key: Key(uploaderAvatar ?? ''),
                isImportantInCache: false,
                customUrl: uploaderAvatar,
                width: thumbSize,
                isCircle: true,
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2.0),
                  NamidaDummyContainer(
                    width: maxWidth * 0.35,
                    height: 8.0,
                    borderRadius: 4.0,
                    shimmerEnabled: author == null,
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Row(
                        children: [
                          if (author != null)
                            Text(
                              author,
                              style: authorTextStyle,
                            ),
                          if (uploadedFromText != null)
                            Text(
                              " • $uploadedFromText",
                              style: authorTextStyle,
                            ),
                          if (comment?.isEdited == true) ...[
                            const SizedBox(width: 4.0),
                            Icon(
                              Broken.edit_2,
                              size: 12.0,
                              color: authorTextColor,
                            ),
                          ],
                          if (isArtist) ...[
                            const SizedBox(width: 4.0),
                            Icon(
                              Broken.musicnote,
                              size: 12.0,
                              color: authorTextColor,
                            ),
                          ],
                          if (isHearted) ...[
                            const SizedBox(width: 4.0),
                            const Icon(
                              Broken.heart_tick,
                              size: 14.0,
                              color: Color.fromARGB(210, 233, 80, 112),
                            ),
                          ],
                          if (isPinned) ...[
                            const SizedBox(width: 4.0),
                            const Icon(
                              Broken.path,
                              size: 14.0,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: commentTextParsed == null
                        ? Column(
                            children: [
                              ...List.filled(
                                2,
                                const Padding(
                                  padding: EdgeInsets.only(top: 2.0),
                                  child: NamidaDummyContainer(
                                    width: null,
                                    height: 8.0,
                                    borderRadius: 3.0,
                                    shimmerEnabled: true,
                                    child: null,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            commentTextParsed,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.displaySmall?.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: context.theme.colorScheme.onSurface.withAlpha(220),
                            ),
                          ),
                  ),
                  const SizedBox(height: 4.0),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        const SizedBox(width: 4.0),
                        if (comment != null)
                          Icon(
                            comment!.likeStatus == LikeStatus.liked ? Broken.like_filled : Broken.like_1,
                            size: 12.0,
                          ),
                        if (likeCount == null || likeCount > 0) ...[
                          const SizedBox(width: 4.0),
                          NamidaDummyContainer(
                            width: 18.0,
                            height: 6.0,
                            borderRadius: 4.0,
                            shimmerEnabled: likeCount == null,
                            child: Text(
                              likeCount?.formatDecimalShort() ?? '?',
                              style: context.textTheme.displaySmall?.copyWith(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                        if (repliesCount != null && repliesCount > 0) ...[
                          Text(
                            ' | ',
                            style: context.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w300),
                          ),
                          Text(
                            [
                              lang.REPLIES,
                              repliesCount,
                            ].join(' • '),
                            style: context.textTheme.displaySmall?.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
