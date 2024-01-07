import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:read_more_text/read_more_text.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class YTCommentCard extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  final YoutubeComment? comment;
  const YTCommentCard({super.key, required this.comment, required this.margin});

  @override
  Widget build(BuildContext context) {
    final uploaderAvatar = comment?.uploaderAvatarUrl;
    final author = comment?.author;
    final uploadedFrom = comment?.uploadDate;
    final commentText = comment?.commentText;
    final likeCount = comment?.likeCount;
    final repliesCount = comment?.replyCount == -1 ? null : comment?.replyCount;
    final isHearted = comment?.hearted ?? false;
    final isPinned = comment?.pinned ?? false;

    final containerColor = context.theme.cardColor.withAlpha(100);
    final readmoreColor = context.theme.colorScheme.primary.withAlpha(160);

    final cid = comment?.commentId;

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(10.0),
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
      child: SizedBox(
        width: context.width,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NamidaDummyContainer(
              width: 38.0,
              height: 38.0,
              isCircle: true,
              shimmerEnabled: uploaderAvatar == null,
              child: YoutubeThumbnail(
                key: Key(uploaderAvatar ?? ''),
                isImportantInCache: false,
                channelUrl: uploaderAvatar,
                width: 38.0,
                isCircle: true,
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2.0),
                  if (isPinned) ...[
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
                            fontSize: 11.5.multipliedFontScale,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2.0),
                  ],
                  NamidaDummyContainer(
                    width: context.width * 0.5,
                    height: 12.0,
                    borderRadius: 6.0,
                    shimmerEnabled: author == null,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              author,
                              if (uploadedFrom != null) uploadedFrom,
                            ].join(' • '),
                            style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w400, color: context.theme.colorScheme.onBackground.withAlpha(180)),
                          ),
                        ),
                        if (isHearted) ...[
                          const SizedBox(width: 4.0),
                          const Icon(
                            Broken.heart_tick,
                            size: 16.0,
                            color: Color.fromARGB(200, 250, 90, 80),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: commentText == null
                        ? Column(
                            children: [
                              ...List.filled(
                                3,
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
                        : ReadMoreText(
                            YoutubeController.inst.commentToParsedHtml[cid] ?? commentText,
                            numLines: 5,
                            readMoreText: lang.SHOW_MORE,
                            readLessText: '',
                            readLessIcon: Icon(
                              Broken.arrow_up_3,
                              size: 18.0,
                              color: readmoreColor,
                            ),
                            readMoreIcon: Icon(
                              Broken.arrow_down_2,
                              size: 18.0,
                              color: readmoreColor,
                            ),
                            readMoreTextStyle: context.textTheme.displaySmall?.copyWith(color: readmoreColor),
                            style: context.textTheme.displaySmall?.copyWith(
                              fontSize: 13.5.multipliedFontScale,
                              fontWeight: FontWeight.w500,
                              color: context.theme.colorScheme.onBackground.withAlpha(220),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      const Icon(Broken.like_1, size: 16.0),
                      if (likeCount == null || likeCount > 0) ...[
                        const SizedBox(width: 4.0),
                        NamidaDummyContainer(
                          width: 18.0,
                          height: 8.0,
                          borderRadius: 4.0,
                          shimmerEnabled: likeCount == null,
                          child: Text(
                            likeCount?.formatDecimalShort() ?? '?',
                            style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w300),
                          ),
                        ),
                      ],
                      const SizedBox(width: 12.0),
                      const Icon(Broken.dislike, size: 16.0),
                      const SizedBox(width: 16.0),
                      SizedBox(
                        height: 28.0,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: context.theme.colorScheme.onBackground.withAlpha(200),
                          ),
                          onPressed: () {},
                          icon: const Icon(Broken.document, size: 16.0),
                          label: Text(
                            [
                              lang.REPLIES,
                              if (repliesCount != null) repliesCount,
                            ].join(' • '),
                            style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w300),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // TODO: view channel details.
            NamidaPopupWrapper(
              childrenDefault: [
                NamidaPopupItem(
                  icon: Broken.copy,
                  title: lang.COPY,
                  onTap: () => comment?.commentText != null ? Clipboard.setData(ClipboardData(text: comment!.commentText!)) : null,
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class YTCommentCardCompact extends StatelessWidget {
  final YoutubeComment? comment;
  const YTCommentCardCompact({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    final uploaderAvatar = comment?.uploaderAvatarUrl;
    final author = comment?.author;
    final uploadedFrom = comment?.uploadDate;
    final commentText = comment?.commentText;
    final likeCount = comment?.likeCount;
    final repliesCount = comment?.replyCount == -1 ? null : comment?.replyCount;
    final isHearted = comment?.hearted ?? false;
    final isPinned = comment?.pinned ?? false;

    final cid = comment?.commentId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NamidaDummyContainer(
          width: 28.0,
          height: 28.0,
          isCircle: true,
          shimmerEnabled: uploaderAvatar == null,
          child: YoutubeThumbnail(
            key: Key(uploaderAvatar ?? ''),
            isImportantInCache: false,
            channelUrl: uploaderAvatar,
            width: 28.0,
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
                width: context.width * 0.5,
                height: 8.0,
                borderRadius: 4.0,
                shimmerEnabled: author == null,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          author,
                          if (uploadedFrom != null) uploadedFrom,
                        ].join(' • '),
                        style: context.textTheme.displaySmall?.copyWith(
                          fontSize: 11.5.multipliedFontScale,
                          fontWeight: FontWeight.w400,
                          color: context.theme.colorScheme.onBackground.withAlpha(180),
                        ),
                      ),
                    ),
                    if (isPinned) ...[
                      const SizedBox(width: 4.0),
                      const Icon(
                        Broken.path,
                        size: 14.0,
                      ),
                    ],
                    if (isHearted) ...[
                      const SizedBox(width: 4.0),
                      const Icon(
                        Broken.heart_tick,
                        size: 14.0,
                        color: Color.fromARGB(200, 250, 90, 80),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 2.0),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: commentText == null
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
                        YoutubeController.inst.commentToParsedHtml[cid] ?? commentText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.displaySmall?.copyWith(
                          fontSize: 12.5.multipliedFontScale,
                          fontWeight: FontWeight.w500,
                          color: context.theme.colorScheme.onBackground.withAlpha(220),
                        ),
                      ),
              ),
              const SizedBox(height: 4.0),
              Row(
                children: [
                  const SizedBox(width: 4.0),
                  const Icon(Broken.like_1, size: 12.0),
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
                          fontSize: 11.5.multipliedFontScale,
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
                        fontSize: 11.5.multipliedFontScale,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
