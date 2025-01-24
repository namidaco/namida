import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:youtipie/class/cache_details.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/items_sort.dart';
import 'package:youtipie/class/map_serializable.dart';
import 'package:youtipie/class/result_wrapper/list_wrapper_base.dart';
import 'package:youtipie/core/enum.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
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
  final YoutiPieOperation operation;
  final String title;
  final CacheDetails<W> cacheReader;
  final Future<W?> Function(ExecuteDetails details) networkFetcher;
  final bool isSortable;
  final Widget dummyCard;
  final double itemExtent;
  final YoutubeMainPageFetcherItemBuilder<T, W> itemBuilder;
  final RenderObjectWidget? Function(W list, YoutubeMainPageFetcherItemBuilder<T, W> itemBuilder, Widget dummyCard)? sliverListBuilder;
  final bool showRefreshInsteadOfRefreshing;

  final Widget? pageHeader;
  final Widget? headerTrailing;
  final void Function()? onHeaderTap;
  final bool isHorizontal;
  final double? horizontalHeight;
  final double topPadding;
  final double? bottomPadding;
  final Future<void> Function()? onPullToRefresh;
  final bool enablePullToRefresh;
  final void Function(W? result)? onListUpdated;
  final void Function(Rxn<W> wrapper)? onInitState;
  final void Function(Rxn<W> wrapper)? onDispose;

  const YoutubeMainPageFetcherAccBase({
    super.key,
    required this.transparentShimmer,
    required this.operation,
    required this.title,
    required this.cacheReader,
    required this.networkFetcher,
    this.isSortable = false,
    required this.dummyCard,
    required this.itemExtent,
    required this.itemBuilder,
    this.sliverListBuilder,
    this.showRefreshInsteadOfRefreshing = false,
    this.pageHeader,
    this.headerTrailing,
    this.onHeaderTap,
    this.isHorizontal = false,
    this.horizontalHeight,
    this.topPadding = 24.0,
    this.bottomPadding,
    this.onPullToRefresh,
    this.enablePullToRefresh = true,
    this.onListUpdated,
    this.onInitState,
    this.onDispose,
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

  Future<void> forceFetchFeed() => _fetchFeedSilent();
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
  final _refreshButtonShown = false.obs;
  final _currentFeed = Rxn<W>();
  Rxn<YoutiPieItemsSort>? _currentSort;

  bool get _hasConnection => ConnectivityController.inst.hasConnection;
  void _showNetworkError() {
    Future.delayed(Duration.zero, () {
      snackyy(
        title: lang.ERROR,
        message: lang.NO_NETWORK_AVAILABLE_TO_FETCH_DATA,
        isError: true,
        top: false,
      );
    });
  }

  void _onInit({bool forceRequest = false}) async {
    bool needNewRequest = false;
    bool preferPromptRefreshing = false;

    if (forceRequest) {
      needNewRequest = true;
    } else {
      final lastFetchedTime = _resultsFetchTime[W];
      if (_hasConnection) {
        if (lastFetchedTime == null) {
          needNewRequest = true;
          _refreshButtonShown.value = true;
        } else if (lastFetchedTime.difference(DateTime.now()).abs() > const Duration(seconds: 180)) {
          needNewRequest = true;
          _refreshButtonShown.value = true;
          if (widget.showRefreshInsteadOfRefreshing) preferPromptRefreshing = true;
        }
      }
    }

    final cachedFeed = await widget.cacheReader.readAsync();
    if (cachedFeed != null) {
      _currentFeed.value = cachedFeed;
      _lastFetchWasCached.value = true;
      if (needNewRequest) {
        if (preferPromptRefreshing) {
          _refreshButtonShown.value = true;
        } else {
          if (widget.enablePullToRefresh) {
            onRefresh(_fetchFeedSilent, forceProceed: true);
          } else {
            _fetchFeedSilent();
          }
        }
      }
    } else {
      _fetchFeed();
    }
  }

  void _onAccChanged() {
    final isSignedIn = YoutubeAccountController.current.activeAccountChannel.value != null;
    if (isSignedIn) {
      _onInit(forceRequest: true);
    } else {
      _currentFeed.value = null;
      _lastFetchWasCached.value = false;
      _refreshButtonShown.value = false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isSortable) _currentSort = Rxn<YoutiPieItemsSort>();
    widget.onInitState?.call(_currentFeed);
    YoutubeAccountController.current.addOnAccountChanged(_onAccChanged);
    if (widget.onListUpdated != null) _currentFeed.addListener(_onListUpdated);
    Future.delayed(Duration.zero, _onInit); // delayed to prevent setState error when snackbar is shown
  }

  @override
  void dispose() {
    widget.onDispose?.call(_currentFeed);
    if (widget.onListUpdated != null) _currentFeed.removeListener(_onListUpdated);
    YoutubeAccountController.current.removeOnAccountChanged(_onAccChanged);

    _controller.dispose();
    _isLoadingCurrentFeed.close();
    _currentFeed.close();
    _currentSort?.close();
    _lastFetchWasCached.close();
    super.dispose();
  }

  Future<void> _fetchFeed() async {
    if (!_hasConnection) return _showNetworkError();

    _lastFetchWasCached.value = false;
    _refreshButtonShown.value = false;
    _isLoadingCurrentFeed.value = true;
    final val = await widget.networkFetcher(ExecuteDetails.forceRequest());
    _resultsFetchTime[W] = DateTime.now();
    _isLoadingCurrentFeed.value = false;
    if (val != null) {
      _currentFeed.value = val;
    } else {
      _lastFetchWasCached.value = true;
      _refreshButtonShown.value = true;
    }
  }

  Future<void> _fetchFeedSilent() async {
    if (!_hasConnection) return _showNetworkError();

    final val = await widget.networkFetcher(ExecuteDetails.forceRequest());
    _resultsFetchTime[W] = DateTime.now();
    if (val != null) {
      _currentFeed.value = val;
      _lastFetchWasCached.value = false;
      _refreshButtonShown.value = false;
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
    Widget headerTitle = Text(
      widget.title,
      style: context.textTheme.displayLarge?.copyWith(fontSize: 28.0),
    );
    if (widget.isSortable) {
      headerTitle = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerTitle,
          const SizedBox(height: 2.0),
          ObxO(
            rx: _currentFeed,
            builder: (context, listItemsPre) {
              if (listItemsPre is YoutiPieListSorterMixin) {
                final listItems = listItemsPre as YoutiPieListSorterMixin;
                final selectedSort = listItems.customSort ?? listItems.itemsSort.firstWhereEff((e) => e.initiallySelected);
                return NamidaPopupWrapper(
                  childrenDefault: () {
                    return (listItems).itemsSort.map(
                      (s) {
                        return NamidaPopupItem(
                          icon: s.title == selectedSort?.title ? Broken.tick_circle : Broken.arrow_swap,
                          title: s.title,
                          onTap: () async {
                            final currentSort = _currentSort;
                            if (currentSort!.value?.title == s.title) return;

                            final initialSort = currentSort.value;

                            _isLoadingCurrentFeed.value = true;
                            currentSort.value = s;

                            final didFetch = await listItems.fetchWithNewSort(sort: s, details: ExecuteDetails.forceRequest());
                            if (currentSort.value?.title != s.title) return; // if interrupted

                            _isLoadingCurrentFeed.value = false;

                            if (didFetch) {
                              if (mounted) _currentFeed.refresh();
                            } else {
                              currentSort.value = initialSort;
                            }
                          },
                        );
                      },
                    ).toList();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: ObxO(
                      rx: _currentSort!,
                      builder: (context, sort) => Text(
                        sort?.title ?? selectedSort?.title ?? '?',
                        style: context.textTheme.displaySmall?.copyWith(
                          color: context.theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      );
    }
    Widget header = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: headerTitle,
        ),
        const SizedBox(width: 12.0),
        ObxO(
          rx: _refreshButtonShown,
          builder: (context, value) => value
              ? NamidaIconButton(
                  icon: Broken.refresh,
                  onPressed: _fetchFeed,
                )
              : const SizedBox(),
        ),
        if (widget.headerTrailing != null) widget.headerTrailing!,
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

    final pagePadding = EdgeInsets.only(top: widget.topPadding, bottom: widget.bottomPadding ?? Dimensions.inst.globalBottomPaddingTotalR);

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
          rx: YoutubeAccountController.membership.userMembershipTypeGlobal,
          builder: (context, membership) => ObxO(
            rx: YoutubeAccountController.current.activeAccountChannel,
            builder: (context, activeAccountChannel) {
              String? errorMessage;
              Widget? button;
              if (activeAccountChannel == null) {
                errorMessage = lang.SIGN_IN_YOU_NEED_ACCOUNT_TO_VIEW_PAGE;
                button = NamidaInkWellButton(
                  sizeMultiplier: 1.1,
                  icon: Broken.user_edit,
                  text: lang.MANAGE_YOUR_ACCOUNTS,
                  onTap: const YoutubeAccountManagePage().navigate,
                );
              } else if (YoutubeAccountController.operationBlockedByMembership(widget.operation, membership)) {
                errorMessage = YoutubeAccountController.formatMembershipErrorMessage(widget.operation, membership);
                button = NamidaInkWellButton(
                  sizeMultiplier: 1.1,
                  icon: Broken.message_edit,
                  text: lang.MEMBERSHIP_MANAGE,
                  onTap: const YoutubeManageSubscriptionPage().navigate,
                );
              }
              return errorMessage != null
                  ? Padding(
                      padding: pagePadding,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.pageHeader != null) widget.pageHeader!,
                          Align(
                            alignment: Alignment.centerLeft,
                            child: header,
                          ),
                          const SizedBox(height: 38.0),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  errorMessage,
                                  style: context.textTheme.displayLarge,
                                  textAlign: TextAlign.center,
                                ),
                                if (button != null) ...[
                                  const SizedBox(height: 12.0),
                                  button,
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ObxO(
                      rx: _isLoadingCurrentFeed,
                      builder: (context, isLoadingCurrentFeed) => ObxO(
                        rx: _currentFeed,
                        builder: (context, listItems) {
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
                                      builder: (context, isLoadingNext) => isLoadingNext
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
                    );
            },
          ),
        ),
      ),
    );
  }
}
