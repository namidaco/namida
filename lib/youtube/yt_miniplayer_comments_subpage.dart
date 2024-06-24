import 'package:flutter/material.dart';

import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/scroll_physics_modified.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';
import 'package:namida/youtube/widgets/yt_comment_card.dart';

class YTMiniplayerCommentsSubpage extends StatefulWidget {
  const YTMiniplayerCommentsSubpage({super.key});

  @override
  State<YTMiniplayerCommentsSubpage> createState() => _YTMiniplayerCommentsSubpageState();
}

class _YTMiniplayerCommentsSubpageState extends State<YTMiniplayerCommentsSubpage> {
  late final ScrollController sc;
  @override
  void initState() {
    super.initState();
    sc = ScrollController();
  }

  @override
  void dispose() {
    sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentId = Player.inst.currentVideo?.id;
    return BackgroundWrapper(
      child: Column(
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
            child: Padding(
              key: Key("${currentId}_comments_header"),
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  NamidaIconButton(
                    horizontalPadding: 12.0,
                    icon: Broken.arrow_left_2,
                    onPressed: NamidaNavigator.inst.popPage,
                  ),
                  const Icon(Broken.document, size: 20.0),
                  const SizedBox(width: 8.0),
                  ObxO(
                    rx: YoutubeInfoController.current.currentComments,
                    builder: (comments) {
                      final count = comments?.commentsCount;
                      return Text(
                        [
                          lang.COMMENTS,
                          if (count != null) count.formatDecimalShort(),
                        ].join(' • '),
                        style: context.textTheme.displayMedium,
                        textAlign: TextAlign.start,
                      );
                    },
                  ),
                  const Spacer(),
                  // TODO sort types
                  ObxO(
                    rx: YoutubeInfoController.current.isCurrentCommentsFromCache,
                    builder: (isCurrentCommentsFromCache) {
                      isCurrentCommentsFromCache ??= false;
                      return NamidaIconButton(
                        tooltip: isCurrentCommentsFromCache ? () => lang.CACHE : null,
                        icon: Broken.refresh,
                        iconSize: 22.0,
                        onPressed: () async {
                          if (!ConnectivityController.inst.hasConnection) return;
                          try {
                            sc.jumpTo(0);
                          } catch (_) {}
                          if (currentId != null) {
                            await YoutubeInfoController.current.updateCurrentComments(
                              currentId,
                              sortType: YoutubeMiniplayerUiController.inst.currentCommentSort.value,
                              initial: true,
                            );
                          }
                        },
                        child: isCurrentCommentsFromCache
                            ? const StackedIcon(
                                baseIcon: Broken.refresh,
                                secondaryIcon: Broken.global,
                              )
                            : Icon(
                                Broken.refresh,
                                color: context.defaultIconColor(),
                              ),
                      );
                    },
                  ),
                  const SizedBox(width: 8.0),
                ],
              ),
            ),
          ),
          Expanded(
            child: NamidaScrollbar(
              controller: sc,
              child: LazyLoadListView(
                onReachingEnd: () async => currentId == null ? null : await YoutubeInfoController.current.updateCurrentComments(currentId),
                extend: 400,
                scrollController: sc,
                listview: (controller) => CustomScrollView(
                  restorationId: currentId,
                  physics: const ClampingScrollPhysicsModified(),
                  controller: controller,
                  slivers: [
                    ObxO(
                      rx: YoutubeInfoController.current.isLoadingInitialComments,
                      builder: (loadingInitial) {
                        if (loadingInitial) {
                          return SliverToBoxAdapter(
                            key: Key("${currentId}_comments_shimmer"),
                            child: ShimmerWrapper(
                              transparent: false,
                              shimmerEnabled: true,
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: 10,
                                shrinkWrap: true,
                                itemBuilder: (context, index) {
                                  const comment = null;
                                  return const YTCommentCard(
                                    key: Key("${comment == null}"),
                                    margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                    comment: comment,
                                  );
                                },
                              ),
                            ),
                          );
                        }
                        return ObxO(
                          rx: YoutubeInfoController.current.currentComments,
                          builder: (comments) {
                            if (comments == null) return const SliverToBoxAdapter();
                            return SliverList.builder(
                              key: Key("${currentId}_comments"),
                              itemCount: comments.length,
                              itemBuilder: (context, i) {
                                final comment = comments[i];
                                return ShimmerWrapper(
                                  transparent: false,
                                  shimmerDurationMS: 550,
                                  shimmerDelayMS: 250,
                                  shimmerEnabled: comment == null,
                                  child: YTCommentCard(
                                    key: Key("${comment == null}_${comment?.commentId}"),
                                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                    comment: comment,
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    ObxO(
                      rx: YoutubeInfoController.current.isLoadingMoreComments,
                      builder: (isLoadingMoreComments) => isLoadingMoreComments
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
        ],
      ),
    );
  }
}
