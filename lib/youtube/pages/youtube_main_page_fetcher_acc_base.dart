import 'package:flutter/material.dart';
import 'package:youtipie/class/cache_details.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/map_serializable.dart';
import 'package:youtipie/class/result_wrapper/list_wrapper_base.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/pages/user/youtube_account_manage_page.dart';

class YoutubeMainPageFetcherAccBase<W extends YoutiPieListWrapper<T>, T extends MapSerializable> extends StatefulWidget {
  final bool transparentShimmer;
  final String title;
  final CacheDetails<W> cacheReader;
  final Future<W?> Function(ExecuteDetails details) networkFetcher;
  final Widget dummyCard;
  final double itemExtent;
  final Widget? Function(T item, int index, W list) itemBuilder;

  const YoutubeMainPageFetcherAccBase({
    super.key,
    required this.transparentShimmer,
    required this.title,
    required this.cacheReader,
    required this.networkFetcher,
    required this.dummyCard,
    required this.itemExtent,
    required this.itemBuilder,
  });

  @override
  State<YoutubeMainPageFetcherAccBase> createState() => _YoutubePageState<W, T>();
}

class _YoutubePageState<W extends YoutiPieListWrapper<T>, T extends MapSerializable> extends State<YoutubeMainPageFetcherAccBase<W, T>> {
  final _controller = ScrollController();
  final _isLoadingCurrentFeed = false.obs;
  final _isLoadingNext = false.obs;
  final _lastFetchWasCached = false.obs;
  final _currentFeed = Rxn<W>();

  bool get _hasConnection => ConnectivityController.inst.hasConnection;
  void _showNetworkError() {
    snackyy(
      title: lang.ERROR,
      message: lang.NO_NETWORK_AVAILABLE_TO_FETCH_DATA,
      isError: true,
      top: false,
    );
  }

  @override
  void initState() {
    super.initState();
    final cachedFeed = widget.cacheReader.read();
    if (cachedFeed != null) {
      _currentFeed.value = cachedFeed;
      _lastFetchWasCached.value = true;
    } else {
      _fetchFeed();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _isLoadingCurrentFeed.close();
    _currentFeed.close();
    _lastFetchWasCached.close();
    super.dispose();
  }

  Future<void> _fetchFeed() async {
    if (!_hasConnection) return _showNetworkError();

    _lastFetchWasCached.value = false;
    _isLoadingCurrentFeed.value = true;
    final val = await widget.networkFetcher(ExecuteDetails.forceRequest());
    _isLoadingCurrentFeed.value = false;
    if (val != null) {
      _currentFeed.value = val;
    } else {
      _lastFetchWasCached.value = true;
    }
  }

  Future<void> _fetchFeedNext() async {
    final feed = _currentFeed;
    if (feed.value?.canFetchNext != true) return;

    _isLoadingNext.value = true;
    final fetched = await feed.value?.fetchNext();
    if (fetched == true) feed.refresh();
    _isLoadingNext.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: context.textTheme.displayLarge?.copyWith(fontSize: 38.0),
            ),
          ),
          const SizedBox(width: 12.0),
          ObxO(
            rx: _lastFetchWasCached,
            builder: (value) => value
                ? NamidaIconButton(
                    icon: Broken.refresh,
                    onPressed: _fetchFeed,
                  )
                : const SizedBox(),
          ),
        ],
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
                        onTap: const YoutubeAccountManagePage().navigate,
                      ),
                    ],
                  ),
                )
              : ObxO(
                  rx: _isLoadingCurrentFeed,
                  builder: (isLoadingCurrentFeed) => ObxO(
                    rx: _currentFeed,
                    builder: (listItems) {
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
                            isLoadingCurrentFeed
                                ? SliverToBoxAdapter(
                                    child: ShimmerWrapper(
                                      transparent: widget.transparentShimmer,
                                      shimmerEnabled: true,
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: 15,
                                        shrinkWrap: true,
                                        itemBuilder: (_, __) {
                                          return widget.dummyCard;
                                        },
                                      ),
                                    ),
                                  )
                                : listItems == null
                                    ? const SliverToBoxAdapter()
                                    : SliverFixedExtentList.builder(
                                        itemCount: listItems.items.length,
                                        itemExtent: widget.itemExtent,
                                        itemBuilder: (context, i) {
                                          final item = listItems.items[i];
                                          return widget.itemBuilder(item, i, listItems);
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
