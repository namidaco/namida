import 'package:flutter/material.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/result_wrapper/feed_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_short.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/pages/user/youtube_account_manage_page.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubeHomeFeedPage extends StatefulWidget {
  const YoutubeHomeFeedPage({super.key});

  @override
  State<YoutubeHomeFeedPage> createState() => _YoutubePageState();
}

class _YoutubePageState extends State<YoutubeHomeFeedPage> with AutomaticKeepAliveClientMixin<YoutubeHomeFeedPage> {
  @override
  bool get wantKeepAlive => true;

  final _controller = ScrollController();
  final _isLoadingCurrentFeed = Rxn<bool>();
  final _isLoadingNext = false.obs;
  final _currentFeed = Rxn<YoutiPieFeedResult>();

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  @override
  void dispose() {
    _controller.dispose();
    _isLoadingCurrentFeed.close();
    _currentFeed.close();
    super.dispose();
  }

  Future<void> _fetchFeed() async {
    _isLoadingCurrentFeed.value = true;
    final val = await YoutiPie.feed.fetchFeed(details: ExecuteDetails.forceRequest());
    _isLoadingCurrentFeed.value = false;
    if (val != null) _currentFeed.value = val;
  }

  Future<void> _fetchFeedNext() async {
    _isLoadingNext.value = true;
    final feed = _currentFeed;
    final fetched = await feed.value?.fetchNext();
    if (fetched == true) feed.refresh();
    _isLoadingNext.value = false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Text(
        lang.HOME,
        style: context.textTheme.displayLarge?.copyWith(fontSize: 38.0),
      ),
    );

    final pagePadding = EdgeInsets.only(top: 24.0, bottom: Dimensions.inst.globalBottomPaddingTotalR);

    return BackgroundWrapper(
      child: PullToRefresh(
        controller: _controller,
        onRefresh: _fetchFeed,
        child: ObxO(
          rx: YoutubeAccountController.current.activeAccountChannel,
          builder: (activeAccountChannel) => activeAccountChannel == null
              ? Padding(
                  padding: pagePadding,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: header,
                      ),
                      const SizedBox(height: 38.0),
                      Text(
                        lang.SIGN_IN_YOU_NEED_ACCOUNT_TO_VIEW_PAGE,
                        style: context.textTheme.displayLarge,
                      ),
                      const SizedBox(height: 12.0),
                      NamidaInkWellButton(
                        sizeMultiplier: 1.1,
                        icon: Broken.user_edit,
                        text: lang.MANAGE_YOUR_ACCOUNTS,
                        onTap: () {
                          NamidaNavigator.inst.navigateTo(const YoutubeAccountManagePage());
                        },
                      ),
                    ],
                  ),
                )
              : ObxO(
                  rx: _isLoadingCurrentFeed,
                  builder: (isLoadingCurrentFeed) => ObxO(
                    rx: _currentFeed,
                    builder: (homepageFeed) {
                      return LazyLoadListView(
                        onReachingEnd: _fetchFeedNext,
                        scrollController: _controller,
                        listview: (controller) => CustomScrollView(
                          controller: controller,
                          slivers: [
                            SliverPadding(padding: EdgeInsets.only(top: pagePadding.top)),
                            SliverToBoxAdapter(
                              child: header,
                            ),
                            isLoadingCurrentFeed == null
                                ? const SliverToBoxAdapter()
                                : isLoadingCurrentFeed == true
                                    ? SliverToBoxAdapter(
                                        child: ShimmerWrapper(
                                          transparent: false,
                                          shimmerEnabled: true,
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: 15,
                                            shrinkWrap: true,
                                            itemBuilder: (context, index) {
                                              return const YoutubeVideoCardDummy(
                                                shimmerEnabled: true,
                                                thumbnailWidth: thumbnailWidth,
                                                thumbnailHeight: thumbnailHeight,
                                              );
                                            },
                                          ),
                                        ),
                                      )
                                    : homepageFeed == null
                                        ? const SliverToBoxAdapter()
                                        : SliverFixedExtentList.builder(
                                            itemCount: homepageFeed.items.length,
                                            itemExtent: thumbnailItemExtent,
                                            itemBuilder: (context, i) {
                                              final item = homepageFeed.items[i];
                                              return switch (item.runtimeType) {
                                                const (StreamInfoItem) => YoutubeVideoCard(
                                                    key: Key((item as StreamInfoItem).id),
                                                    thumbnailWidth: thumbnailWidth,
                                                    thumbnailHeight: thumbnailHeight,
                                                    isImageImportantInCache: false,
                                                    video: item,
                                                    playlistID: null,
                                                  ),
                                                const (StreamInfoItemShort) => YoutubeShortVideoCard(
                                                    key: Key("${(item as StreamInfoItemShort?)?.id}"),
                                                    thumbnailWidth: thumbnailWidth,
                                                    thumbnailHeight: thumbnailHeight,
                                                    short: item as StreamInfoItemShort,
                                                    playlistID: null,
                                                  ),
                                                const (PlaylistInfoItem) => YoutubePlaylistCard(
                                                    key: Key((item as PlaylistInfoItem).id),
                                                    playlist: item,
                                                    thumbnailWidth: thumbnailWidth,
                                                    thumbnailHeight: thumbnailHeight,
                                                    subtitle: item.subtitle,
                                                    playOnTap: true,
                                                  ),
                                                _ => const YoutubeVideoCardDummy(
                                                    shimmerEnabled: true,
                                                    thumbnailWidth: thumbnailWidth,
                                                    thumbnailHeight: thumbnailHeight,
                                                  ),
                                              };
                                            },
                                          ),
                            SliverToBoxAdapter(
                              child: ObxO(
                                rx: _isLoadingNext,
                                builder: (isLoadingNext) => isLoadingNext
                                    ? const Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: Center(
                                          child: LoadingIndicator(),
                                        ),
                                      )
                                    : const SizedBox(),
                              ),
                            ),
                            SliverPadding(padding: EdgeInsets.only(top: pagePadding.bottom)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
