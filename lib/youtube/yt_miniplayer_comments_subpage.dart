import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/scroll_physics_modified.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
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

  String? get currentId {
    final videoInfo = YoutubeController.inst.currentYoutubeMetadataVideo.value ?? Player.inst.currentVideoInfo;
    return videoInfo?.id ?? Player.inst.nowPlayingVideoID?.id;
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Column(
        children: [
          Obx(
            () {
              final totalCommentsCount = YoutubeController.inst.currentTotalCommentsCount.value;
              return DecoratedBox(
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
                      Text(
                        [
                          lang.COMMENTS,
                          if (totalCommentsCount != null) totalCommentsCount.formatDecimalShort(),
                        ].join(' • '),
                        style: context.textTheme.displayMedium,
                        textAlign: TextAlign.start,
                      ),
                      const Spacer(),
                      NamidaIconButton(
                        tooltip: YoutubeController.inst.isCurrentCommentsFromCache ? lang.CACHE : null,
                        icon: Broken.refresh,
                        iconSize: 22.0,
                        onPressed: () async {
                          if (!ConnectivityController.inst.hasConnection) return;
                          sc.jumpTo(0);
                          await YoutubeController.inst.updateCurrentComments(
                            currentId ?? '',
                            forceRequest: ConnectivityController.inst.hasConnection,
                          );
                        },
                        child: YoutubeController.inst.isCurrentCommentsFromCache
                            ? const StackedIcon(
                                baseIcon: Broken.refresh,
                                secondaryIcon: Broken.global,
                              )
                            : Icon(
                                Broken.refresh,
                                color: context.defaultIconColor(),
                              ),
                      ),
                      const SizedBox(width: 8.0),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: NamidaScrollbar(
              controller: sc,
              child: LazyLoadListView(
                onReachingEnd: () async => await YoutubeController.inst.updateCurrentComments(currentId ?? '', fetchNextOnly: true),
                extend: 400,
                scrollController: sc,
                listview: (controller) => CustomScrollView(
                  restorationId: currentId,
                  physics: const ClampingScrollPhysicsModified(),
                  controller: controller,
                  slivers: [
                    Obx(
                      () {
                        final comments = YoutubeController.inst.currentComments;
                        if (comments.isNotEmpty && comments.first == null) {
                          return SliverToBoxAdapter(
                            key: Key("${currentId}_comments_shimmer"),
                            child: ShimmerWrapper(
                              transparent: false,
                              shimmerEnabled: true,
                              child: ListView.builder(
                                // key: Key(currentId),
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: comments.length,
                                shrinkWrap: true,
                                itemBuilder: (context, index) {
                                  const comment = null;
                                  return YTCommentCard(
                                    key: Key("${comment == null}_${context.hashCode}"),
                                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                    comment: comment,
                                  );
                                },
                              ),
                            ),
                          );
                        }
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
                                key: Key("${comment == null}_${context.hashCode}_${comment?.commentId}"),
                                margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                comment: comment,
                              ),
                            );
                          },
                        );
                      },
                    ),
                    Obx(
                      () {
                        final isLoadingComments = YoutubeController.inst.isLoadingComments.value;
                        return isLoadingComments
                            ? SliverPadding(
                                padding: const EdgeInsets.all(12.0),
                                sliver: const Center(
                                  child: LoadingIndicator(),
                                ).toSliver(),
                              )
                            : const SizedBox().toSliver();
                      },
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
