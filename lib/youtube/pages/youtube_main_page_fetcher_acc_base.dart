import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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

typedef YoutubeMainPageFetcherItemBuilder<T, W> = Widget? Function(T item, int index, W list);

final _resultsFetchTime = <Type, DateTime>{};

class YoutubeMainPageFetcherAccBase<W extends YoutiPieListWrapper<T>, T extends MapSerializable> extends StatefulWidget {
  final bool transparentShimmer;
  final String title;
  final CacheDetails<W> cacheReader;
  final Future<W?> Function(ExecuteDetails details) networkFetcher;
  final Widget dummyCard;
  final double itemExtent;
  final YoutubeMainPageFetcherItemBuilder<T, W> itemBuilder;
  final RenderObjectWidget? Function(W list, YoutubeMainPageFetcherItemBuilder<T, W> itemBuilder, Widget dummyCard)? sliverListBuilder;

  final Widget? pageHeader;
  final void Function()? onHeaderTap;
  final bool isHorizontal;
  final double? horizontalHeight;
  final double topPadding;
  final Future<void> Function()? onPullToRefresh;
  final bool enablePullToRefresh;
  final void Function(W? result)? onListUpdated;

  const YoutubeMainPageFetcherAccBase({
    super.key,
    required this.transparentShimmer,
    required this.title,
    required this.cacheReader,
    required this.networkFetcher,
    required this.dummyCard,
    required this.itemExtent,
    required this.itemBuilder,
    this.sliverListBuilder,
    this.pageHeader,
    this.onHeaderTap,
    this.isHorizontal = false,
    this.horizontalHeight,
    this.topPadding = 24.0,
    this.onPullToRefresh,
    this.enablePullToRefresh = true,
    this.onListUpdated,
  });

  @override
  State<YoutubeMainPageFetcherAccBase> createState() => _YoutubePageState<W, T>();
}

class _YoutubePageState<W extends YoutiPieListWrapper<T>, T extends MapSerializable> extends State<YoutubeMainPageFetcherAccBase<W, T>>
    with TickerProviderStateMixin, PullToRefreshMixin {
  @override
  bool get enablePullToRefresh => widget.enablePullToRefresh;

  @override
  double get maxDistance => 64.0;

  Future<void> forceFetchFeed() => _fetchFeed();
  void updateList(W? list) {
    _currentFeed.value = list;
    _lastFetchWasCached.value = false;
  }

  void _onListUpdated() {
    widget.onListUpdated!(_currentFeed.value);
  }

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

    bool needNewRequest = false;
    final lastFetchedTime = _resultsFetchTime[W];
    if (_hasConnection) {
      if (lastFetchedTime == null) {
        needNewRequest = true;
      } else if (lastFetchedTime.difference(DateTime.now()).abs() > const Duration(seconds: 180)) {
        needNewRequest = true;
      }
    }

    final cachedFeed = widget.cacheReader.read();
    if (cachedFeed != null) {
      _currentFeed.value = cachedFeed;
      _lastFetchWasCached.value = true;
      if (needNewRequest) {
        if (widget.enablePullToRefresh) {
          onRefresh(_fetchFeedSilent, forceProceed: true);
        } else {
          _fetchFeedSilent();
        }
      }
    } else {
      _fetchFeed();
    }
    if (widget.onListUpdated != null) _currentFeed.addListener(_onListUpdated);
  }

  @override
  void dispose() {
    if (widget.onListUpdated != null) _currentFeed.removeListener(_onListUpdated);

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
    _resultsFetchTime[W] = DateTime.now();
    _isLoadingCurrentFeed.value = false;
    if (val != null) {
      _currentFeed.value = val;
    } else {
      _lastFetchWasCached.value = true;
    }
  }

  Future<void> _fetchFeedSilent() async {
    if (!_hasConnection) return _showNetworkError();

    final val = await widget.networkFetcher(ExecuteDetails.forceRequest());
    _resultsFetchTime[W] = DateTime.now();
    if (val != null) {
      _currentFeed.value = val;
    } else {
      _lastFetchWasCached.value = true;
    }
  }

  Future<bool> _fetchFeedNext() async {
    bool fetched = false;
    final feed = _currentFeed;
    if (feed.value?.canFetchNext != true) return fetched;

    _isLoadingNext.value = true;
    fetched = await feed.value?.fetchNext() ?? false;
    if (fetched == true) feed.refresh();
    _isLoadingNext.value = false;
    return fetched;
  }

  @override
  Widget build(BuildContext context) {
    Widget header = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Text(
            widget.title,
            style: context.textTheme.displayLarge?.copyWith(fontSize: 28.0),
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
        if (widget.onHeaderTap != null) const SizedBox(width: 12.0),
        if (widget.onHeaderTap != null) const Icon(Broken.arrow_right_3),
      ],
    );
    const headerMaxHorizontalPadding = 24.0;
    const headerMaxVerticalPadding = 16.0;

    if (widget.onHeaderTap != null) {
      header = Padding(
        padding: const EdgeInsets.symmetric(horizontal: headerMaxHorizontalPadding / 2, vertical: headerMaxVerticalPadding / 2),
        child: header,
      );
      header = NamidaInkWell(
        onTap: widget.onHeaderTap,
        margin: const EdgeInsets.symmetric(horizontal: headerMaxHorizontalPadding / 2, vertical: headerMaxVerticalPadding / 2),
        child: header,
      );
    } else {
      header = Padding(
        padding: const EdgeInsets.symmetric(horizontal: headerMaxHorizontalPadding, vertical: headerMaxVerticalPadding),
        child: header,
      );
    }

    final pagePadding = EdgeInsets.only(top: widget.topPadding, bottom: Dimensions.inst.globalBottomPaddingTotalR);

    final EdgeInsets firstPadding;
    final EdgeInsets lastPadding;
    if (widget.isHorizontal) {
      firstPadding = const EdgeInsets.only(left: 12.0);
      lastPadding = const EdgeInsets.only(right: 12.0);
    } else {
      firstPadding = EdgeInsets.only(top: pagePadding.top);
      lastPadding = EdgeInsets.only(bottom: pagePadding.bottom);
    }

    return BackgroundWrapper(
      child: PullToRefreshWidget(
        state: this,
        controller: _controller,
        onRefresh: widget.onPullToRefresh == null
            ? _fetchFeedSilent
            : () => Future.wait([
                  _fetchFeedSilent(),
                  widget.onPullToRefresh!(),
                ]),
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
                        listview: (controller) {
                          final customScrollView = CustomScrollView(
                            scrollDirection: widget.isHorizontal ? Axis.horizontal : Axis.vertical,
                            controller: controller,
                            slivers: [
                              if (!widget.isHorizontal && widget.pageHeader != null)
                                SliverToBoxAdapter(
                                  child: widget.pageHeader,
                                ),
                              SliverPadding(padding: firstPadding),
                              if (!widget.isHorizontal)
                                SliverToBoxAdapter(
                                  child: header,
                                ),
                              isLoadingCurrentFeed
                                  ? SliverToBoxAdapter(
                                      child: ShimmerWrapper(
                                        transparent: widget.transparentShimmer,
                                        shimmerEnabled: true,
                                        child: ListView.builder(
                                          scrollDirection: widget.isHorizontal ? Axis.horizontal : Axis.vertical,
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
                                      : widget.sliverListBuilder?.call(listItems, widget.itemBuilder, widget.dummyCard) ??
                                          SliverFixedExtentList.builder(
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
                              SliverPadding(padding: lastPadding),
                            ],
                          );
                          return widget.isHorizontal
                              ? Column(
                                  children: [
                                    if (widget.pageHeader != null) widget.pageHeader!,
                                    SizedBox(height: widget.topPadding),
                                    header,
                                    SizedBox(
                                      height: widget.horizontalHeight,
                                      child: customScrollView,
                                    ),
                                  ],
                                )
                              : customScrollView;
                        },
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
