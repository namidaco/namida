import 'package:flutter/material.dart';

import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/items_sort.dart';
import 'package:youtipie/class/result_wrapper/list_wrapper_base.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/youtipie_feed/yt_feed_base.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';

enum YTVideosSorting {
  date,
  views,
  duration,
  title,
  viewsPerDay,
}

/// How the server already orders [YoutubeStreamsManager.streamsList], before any local sorting.
///
/// [StreamInfoItem.publishedAt] is parsed out of texts like `2 months ago`, so a whole month of
/// uploads collapses into a single date. knowing the server order lets date sorting be exact
/// instead of shuffling items that only look like they were published at the same moment.
enum YTStreamsNaturalOrder {
  newestFirst,
  oldestFirst,
  unknown,
}

mixin YoutubeStreamsManager<W extends YoutiPieListWrapper<YoutubeFeed>> {
  /// The list as returned by youtube, this is never sorted in place.
  List<StreamInfoItem>? get streamsList;
  W? get listWrapper;
  ScrollController get scrollController;
  BuildContext get context;
  Color? get sortChipBGColor;
  void onSortChanged(void Function() fn);
  void onListChange(void Function() fn);
  bool canRefreshList(W result);

  YTStreamsNaturalOrder get streamsNaturalOrder => YTStreamsNaturalOrder.unknown;

  /// Server sorting refetches the list from scratch, which only makes sense when the displayed
  /// list is actually the one owned by [listWrapper].
  bool get canSortStreamsServerSide => true;

  /// The whole list gets replaced once a server sort is fetched, consumers can display a loading state.
  void onServerSortLoadingChange(bool isLoading) {}

  final isLoadingMoreUploads = false.obs;

  /// null means [streamsList] is already in the wanted order & is displayed as-is.
  List<StreamInfoItem>? _sortedStreams;

  /// The list that should be displayed.
  List<StreamInfoItem>? get sortedStreams => _sortedStreams ?? streamsList;

  void disposeResources() {
    sorting.close();
    sortingByTop.close();
    _sortedStreams = null;
  }

  static const _defaultSortingByTop = true;
  late final sorting = Rxn<YTVideosSorting>(null);
  late final sortingByTop = _defaultSortingByTop.obs;

  YoutiPieListSorterMixin<YoutubeFeed>? get _serverSorter {
    final wrapper = listWrapper;
    return wrapper is YoutiPieListSorterMixin<YoutubeFeed> ? wrapper : null;
  }

  List<YoutiPieItemsSort> get _serverSorts {
    if (!canSortStreamsServerSide) return const [];
    return _serverSorter?.itemsSort ?? const [];
  }

  YoutiPieItemsSort? get _activeServerSort {
    final sorter = _serverSorter;
    if (sorter == null) return null;
    return sorter.customSort ?? sorter.itemsSort.firstWhereEff((e) => e.initiallySelected);
  }

  Widget get sortWidget {
    return NamidaPopupWrapper(
      openOnLongPress: false,
      children: () => _sortMenuServerChildren(context),
      childrenDefault: _sortMenuLocalItems,
      childrenAfterChildrenDefault: false,
      child: Obx(
        (context) {
          final sort = sorting.valueR;
          final details = sort == null ? null : sortToTextAndIcon(sort);
          final bgColor = sort == null ? null : sortChipBGColor;
          final itemsColor = bgColor == null ? null : Colors.white.withOpacityExt(0.8);
          return NamidaInkWellButton(
            animationDurationMS: 200,
            sizeMultiplier: 0.95,
            borderRadius: 8.0,
            bgColor: bgColor,
            itemsColor: itemsColor,
            icon: details?.$2 ?? Broken.sort,
            text: details?.$1 ?? _activeServerSort?.title ?? lang.sortBy,
            trailing: Icon(
              sort == null
                  ? Broken.arrow_down_1
                  : sortingByTop.valueR
                  ? Broken.arrow_down_2
                  : Broken.arrow_up_3,
              size: 14.0,
              color: itemsColor,
            ),
          );
        },
      ),
    );
  }

  Widget _sortMenuSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Text(
        title,
        style: context.textTheme.displaySmall?.copyWith(fontSize: 11.0),
      ),
    );
  }

  /// Sorts served by youtube itself, they cover the full list so they get their own section.
  List<Widget> _sortMenuServerChildren(BuildContext context) {
    final serverSorts = _serverSorts;
    final activeServerSortTitle = _activeServerSort?.title;
    final textTheme = context.textTheme;
    return [
      if (serverSorts.isNotEmpty) ...[
        _sortMenuSectionTitle(context, lang.youtube),
        ...serverSorts.map(
          (s) => NamidaInkWell(
            borderRadius: 8.0,
            margin: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            bgColor: activeServerSortTitle == s.title ? context.theme.colorScheme.secondary.withOpacityExt(0.1) : null,
            onTap: () {
              NamidaNavigator.inst.popMenu(); // the whole list gets replaced, no point in keeping the menu open
              sortStreamsServerSide(s);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Broken.cloud_change, size: 20.0),
                const SizedBox(width: 6.0),
                Text(
                  s.title,
                  style: textTheme.displayMedium,
                ),
              ],
            ),
          ),
        ),
        const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0)),
      ],
      _sortMenuSectionTitle(context, '${lang.local} (${streamsList?.length ?? 0})'),
    ];
  }

  List<NamidaPopupItem> _sortMenuLocalItems() {
    final currentSort = sorting.value;
    final sortingByTop = this.sortingByTop.value;
    return [
      ...YTVideosSorting.values.map(
        (e) {
          final details = sortToTextAndIcon(e);
          final active = currentSort == e;
          return NamidaPopupItem(
            icon: details.$2,
            secondaryIcon: active ? (sortingByTop ? Broken.arrow_down_2 : Broken.arrow_up_3) : null,
            title: details.$1,
            selected: active,
            onTap: () => sortStreams(sort: e, sortingByTop: active ? !sortingByTop : null),
          );
        },
      ),
      NamidaPopupItem(
        icon: Broken.close_circle,
        title: lang.defaultLabel,
        selected: currentSort == null,
        onTap: removeSorting,
      ),
    ];
  }

  /// return if sorting was done.
  bool trySortStreams() {
    final sort = sorting.value;
    if (sort == null) {
      _sortedStreams = null;
      return false;
    }
    _sortedStreams = _buildSortedStreams(sort, sortingByTop.value);
    return true;
  }

  void sortStreams({required YTVideosSorting sort, bool? sortingByTop, bool jumpToZero = true}) {
    sortingByTop ??= this.sortingByTop.value;
    onSortChanged(
      () {
        this.sortingByTop.value = sortingByTop!;
        sorting.value = sort;
        _sortedStreams = _buildSortedStreams(sort, sortingByTop);
      },
    );
    if (jumpToZero) _jumpToZeroIfScrolledFar();
  }

  void removeSorting({bool jumpToZero = true}) {
    onSortChanged(
      () {
        sorting.value = null;
        sortingByTop.value = _defaultSortingByTop;
        _sortedStreams = null;
      },
    );
    if (jumpToZero) _jumpToZeroIfScrolledFar();
  }

  /// Refetches the whole list with one of the sorts youtube itself provides, unlike local sorting
  /// this covers the full list instead of only what was loaded so far.
  Future<bool> sortStreamsServerSide(YoutiPieItemsSort sort) async {
    final sorter = _serverSorter;
    if (sorter == null) return false;
    if (isLoadingMoreUploads.value) return false;

    isLoadingMoreUploads.value = true;
    onServerSortLoadingChange(true);
    onSortChanged(
      () {
        sorting.value = null;
        sortingByTop.value = _defaultSortingByTop;
        _sortedStreams = null;
      },
    );
    if (scrollController.hasClients) scrollController.jumpTo(0);

    final didFetch = await sorter.fetchWithNewSort(sort: sort, details: ExecuteDetails.kForceRequest);

    isLoadingMoreUploads.value = false;
    onServerSortLoadingChange(false);
    final wrapper = listWrapper;
    if (wrapper != null && canRefreshList(wrapper)) onListChange(trySortStreams);
    return didFetch;
  }

  void _jumpToZeroIfScrolledFar() {
    if (!scrollController.hasClients) return;
    final scrolledFar = scrollController.offset > context.height * 0.7;
    if (scrolledFar) {
      scrollController.animateToEff(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    }
  }

  List<StreamInfoItem>? _buildSortedStreams(YTVideosSorting sort, bool sortingByTop) {
    final source = streamsList;
    if (source == null) return null;

    if (sort == YTVideosSorting.date) {
      final naturalOrder = streamsNaturalOrder;
      if (naturalOrder != YTStreamsNaturalOrder.unknown) {
        // -- the list is already chronological, reusing it keeps the real order of items that share an approximated date.
        final matchesNaturalOrder = sortingByTop == (naturalOrder == YTStreamsNaturalOrder.newestFirst);
        return matchesNaturalOrder ? null : source.reversed.toList();
      }
    }

    return source.sortedByPrecomputed(_sortKeyOf(sort), reverse: sortingByTop);
  }

  Comparable Function(StreamInfoItem e) _sortKeyOf(YTVideosSorting sort) {
    switch (sort) {
      case YTVideosSorting.date:
        return (e) => e.publishedAt.date?.millisecondsSinceEpoch ?? 0;
      case YTVideosSorting.views:
        return (e) => e.viewsCount ?? 0;
      case YTVideosSorting.duration:
        return (e) => e.durSeconds ?? 0;
      case YTVideosSorting.title:
        return (e) => e.title.toLowerCase();
      case YTVideosSorting.viewsPerDay:
        final nowMS = DateTime.now().millisecondsSinceEpoch;
        return (e) {
          final views = e.viewsCount;
          final dateMS = e.publishedAt.date?.millisecondsSinceEpoch;
          if (views == null || dateMS == null) return 0.0;
          final ageMS = nowMS - dateMS;
          return ageMS <= Duration.millisecondsPerDay ? views.toDouble() : views * Duration.millisecondsPerDay / ageMS;
        };
    }
  }

  (String, IconData) sortToTextAndIcon(YTVideosSorting sort) {
    switch (sort) {
      case YTVideosSorting.date:
        return (lang.date, Broken.calendar);
      case YTVideosSorting.views:
        return (lang.views.capitalizeFirst(), Broken.eye);
      case YTVideosSorting.duration:
        return (lang.duration, Broken.timer_1);
      case YTVideosSorting.title:
        return (lang.title, Broken.text);
      case YTVideosSorting.viewsPerDay:
        return ('${lang.views.capitalizeFirst()}/${lang.day.toLowerCase()}', Broken.trend_up);
    }
  }

  Future<bool> fetchStreamsNextPage() async {
    bool didFetch = false;
    if (isLoadingMoreUploads.value) return didFetch;

    final result = this.listWrapper;
    if (result == null) return didFetch;
    if (!result.canFetchNext) return didFetch;

    isLoadingMoreUploads.value = true;
    didFetch = await result.fetchNext();
    isLoadingMoreUploads.value = false;

    if (didFetch) {
      if (canRefreshList(result)) {
        onListChange(trySortStreams); // refresh state even if will not sort
      }
    }
    return didFetch;
  }

  Future<YoutiPieFetchAllResType?> fetchAllStreams(void Function(YoutiPieFetchAllRes fetchAllRes) controller) async {
    if (isLoadingMoreUploads.value) return null;

    final videosTab = this.listWrapper;
    if (videosTab == null) return null;

    final res = videosTab.fetchAll(
      onProgress: () {
        onListChange(trySortStreams); // refresh state even if will not sort
      },
    );

    if (res == null) return null;
    controller(res);

    isLoadingMoreUploads.value = true;
    final didFetch = await res.result;
    isLoadingMoreUploads.value = false;
    return didFetch;
  }
}

/// Doubles as the `load all` button, since loaded-vs-total is the progress of that fetch.
class YTLoadedCountChip extends StatelessWidget {
  final int? loadedCount;
  final int? totalCount;
  final bool isLoading;
  final bool canLoadMore;
  final void Function() onTap;

  const YTLoadedCountChip({
    super.key,
    required this.loadedCount,
    required this.totalCount,
    required this.isLoading,
    required this.canLoadMore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    const borderRadius = 8.0;
    final loadedCount = this.loadedCount;
    final totalCount = this.totalCount;
    final progress = loadedCount == null || totalCount == null || totalCount <= 0 ? null : (loadedCount / totalCount).clampDouble(0.0, 1.0);

    return NamidaTooltip(
      message: canLoadMore ? () => lang.loadAll : null,
      child: NamidaInkWell(
        borderRadius: borderRadius,
        bgColor: theme.cardColor,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.secondary.withOpacityExt(0.5)),
        ),
        onTap: canLoadMore ? onTap : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isLoading
                        ? const LoadingIndicator(boxHeight: 14.0)
                        : Icon(
                            canLoadMore ? Broken.task_square : Broken.video_square,
                            size: 16.0,
                          ),
                    const SizedBox(width: 6.0),
                    Flexible(
                      child: Text(
                        "${loadedCount ?? '?'} / ${totalCount?.formatDecimalShort() ?? '?'}",
                        style: context.textTheme.displayMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (progress != null && progress < 1.0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 2.0,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: ColoredBox(color: theme.colorScheme.secondary.withOpacityExt(0.8)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
