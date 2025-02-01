part of 'yt_utils.dart';

class _YTUtilsCommentActions {
  const _YTUtilsCommentActions();

  Future<void> createComment({
    required BuildContext context,
    required String videoId,
    required YoutiPieVideoPageResult? videoPage,
    required RxBaseCore<YoutiPieCommentResult?>? mainList,
  }) async {
    return _createEditCommentOrReply(
      context: context,
      isEdit: false,
      isReply: false,
      subtitle: YoutubeInfoController.utils.getVideoName(videoId) ?? '?',
      initialComment: null,
      onButtonConfirm: (commentText) async {
        final newComment = await YoutubeInfoController.commentAction.createComment(
          mainList: mainList?.value ?? YoutiPie.cacheBuilder.forComments(videoId: videoId).read(),
          createCommentParams: mainList?.value?.createParams ?? videoPage?.commentResult.createParams,
          content: commentText,
        );

        if (newComment != null) {
          mainList?.refresh();
          return true;
        }
        _showError();
        return false;
      },
    );
  }

  Future<void> editComment({
    required BuildContext context,
    required String videoId,
    required CommentInfoItem comment,
    required RxBaseCore<YoutiPieCommentResult?> mainList,
    required RxBaseCore<YoutiPieCommentReplyResult?>? mainRepliesList,
    required void Function(CommentInfoItem editedComment)? onEdited,
  }) async {
    return _createEditCommentOrReply(
      context: context,
      isEdit: true,
      isReply: false,
      subtitle: null,
      initialComment: comment.content.rawText ?? '',
      onButtonConfirm: (commentText) async {
        final editedComment = await YoutubeInfoController.commentAction.editComment(
          mainList: mainList.value ?? YoutiPie.cacheBuilder.forComments(videoId: videoId).read(),
          comment: comment,
          content: commentText,
        );
        if (editedComment != null) {
          mainList.refresh();
          mainRepliesList?.refresh();
          onEdited?.call(editedComment);
          return true;
        }
        _showError();
        return false;
      },
    );
  }

  Future<bool> deleteComment({
    required String videoId,
    required CommentInfoItem comment,
    required RxBaseCore<YoutiPieCommentResult?> mainList,
    required RxBaseCore<YoutiPieCommentReplyResult?>? mainRepliesList,
    required void Function()? onDeleted,
  }) async {
    return await _confirmRemoveCommentOrReply(
          comment.content.rawText ?? '',
          () async {
            final didDelete = await YoutubeInfoController.commentAction.deleteComment(
              comment: comment,
              mainList: mainList.value ?? YoutiPie.cacheBuilder.forComments(videoId: videoId).read(),
            );
            if (didDelete == true) {
              mainList.refresh();
              mainRepliesList?.refresh();
              onDeleted?.call();
              return true;
            } else {
              _showError();
              return false;
            }
          },
        ) ??
        false;
  }

  Future<void> createReply({
    required BuildContext context,
    required String videoId,
    required CommentInfoItemBase mainComment,
    required CommentInfoItemBase replyingTo,
    required RxBaseCore<YoutiPieCommentReplyResult?>? mainList,
  }) async {
    final authorHandler = mainComment.author?.displayName;
    return _createEditCommentOrReply(
      context: context,
      isEdit: false,
      isReply: true,
      subtitle: authorHandler ?? '?',
      initialComment: authorHandler == null ? null : '$authorHandler ',
      onButtonConfirm: (replyText) async {
        final newComment = await YoutubeInfoController.commentAction.createReply(
          mainList: mainList?.value ?? YoutiPie.cacheBuilder.forCommentReplies(commentId: mainComment.commentId).read(),
          createReplyParams: replyingTo.engagement.createReplyParams,
          content: replyText,
        );

        if (newComment != null) {
          mainList?.refresh();
          return true;
        }
        _showError();
        return false;
      },
    );
  }

  Future<void> editReply({
    required BuildContext context,
    required String videoId,
    required CommentInfoItem mainComment,
    required CommentInfoItemBase reply,
    required RxBaseCore<YoutiPieCommentReplyResult?>? mainList,
  }) async {
    // return;
    return _createEditCommentOrReply(
      context: context,
      isEdit: true,
      isReply: true,
      // subtitle: mainComment.author?.displayName ?? '?',
      subtitle: null,
      initialComment: reply.content.rawText ?? '',
      onButtonConfirm: (replyText) async {
        final editedComment = await YoutubeInfoController.commentAction.editReply(
          mainList: mainList?.value ?? YoutiPie.cacheBuilder.forCommentReplies(commentId: mainComment.commentId).read(),
          reply: reply,
          content: replyText,
        );
        if (editedComment != null) {
          mainList?.refresh();
          return true;
        }
        _showError();
        return false;
      },
    );
  }

  Future<bool> deleteReply({
    required String videoId,
    required CommentInfoItem mainComment,
    required CommentInfoItemBase reply,
    required RxBaseCore<YoutiPieCommentReplyResult?>? mainList,
  }) async {
    return await _confirmRemoveCommentOrReply(
          reply.content.rawText ?? '',
          () async {
            final didDelete = await YoutubeInfoController.commentAction.deleteReply(
              reply: reply,
              mainList: mainList?.value ?? YoutiPie.cacheBuilder.forCommentReplies(commentId: mainComment.commentId).read(),
            );
            if (didDelete == true) {
              mainList?.refresh();
              return true;
            } else {
              _showError();
              return false;
            }
          },
        ) ??
        false;
  }

  Future<void> _createEditCommentOrReply({
    required BuildContext context,
    required bool isEdit,
    required bool isReply,
    required String? subtitle,
    required String? initialComment,
    required Future<bool> Function(String commentText) onButtonConfirm,
  }) async {
    String? author = _getCurrentAutorIfActive();
    if (author == null) return;

    await showNamidaBottomSheetWithTextField(
      context: context,
      displayAccountThumbnail: true,
      title: author,
      subtitle: subtitle == null ? null : '-> $subtitle',
      textfieldConfig: BottomSheetTextFieldConfig(
        hintText: initialComment ?? '',
        initalControllerText: initialComment,
        labelText: isReply ? lang.REPLY : lang.COMMENT,
        validator: (value) {
          if (value == null || value.isEmpty) return lang.EMPTY_VALUE;
          return null;
        },
      ),
      buttonText: isEdit ? lang.SAVE : lang.ADD,
      onButtonTap: (commentText) async {
        if (commentText.isEmpty) return false;
        return onButtonConfirm(commentText);
      },
    );
  }

  void _showError() {
    snackyy(message: lang.FAILED, isError: true);
  }

  String? _getCurrentAutorIfActive() {
    final activeChannel = YoutubeAccountController.current.activeAccountChannel.value;
    if (activeChannel == null) {
      const YoutubeAccountManagePage().navigate();
      return null;
    }

    String author = activeChannel.title;
    if (author.isEmpty) author = activeChannel.handler;
    return author;
  }

  Future<T?> _confirmRemoveCommentOrReply<T>(String content, Future<T> Function()? onConfirm) async {
    String? author = _getCurrentAutorIfActive();
    if (author == null) return null;

    final activeAccountChannel = YoutubeAccountController.current.activeAccountChannel.value;
    if (activeAccountChannel == null) return null;

    T? res;
    final isDoingStuff = false.obs;
    await NamidaNavigator.inst.navigateDialog(
      tapToDismiss: () => !isDoingStuff.value,
      onDisposing: () {
        isDoingStuff.close();
      },
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        title: lang.CONFIRM,
        actions: [
          const CancelButton(),
          ObxO(
            rx: isDoingStuff,
            builder: (context, doing) => AnimatedEnabled(
              enabled: !doing,
              child: NamidaButton(
                text: lang.DELETE.toUpperCase(),
                textWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (doing) const LoadingIndicator(),
                    if (doing) const SizedBox(width: 4.0),
                    NamidaButtonText(lang.DELETE.toUpperCase()),
                  ],
                ),
                onPressed: () async {
                  isDoingStuff.value = true;
                  res = await onConfirm!();
                  isDoingStuff.value = false;
                  NamidaNavigator.inst.closeDialog();
                },
              ),
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: 12.0),
                  YoutubeThumbnail(
                    type: ThumbnailType.channel,
                    key: Key(activeAccountChannel.id),
                    width: 32.0,
                    forceSquared: false,
                    isImportantInCache: true,
                    customUrl: activeAccountChannel.thumbnails.pick()?.url,
                    isCircle: true,
                  ),
                  const SizedBox(width: 12.0),
                  Text(
                    author,
                    style: nampack.textTheme.displayMedium,
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              const NamidaContainerDivider(margin: EdgeInsets.symmetric(horizontal: 12.0)),
              const SizedBox(height: 6.0),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  content,
                  style: nampack.textTheme.displayMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return res;
  }
}
