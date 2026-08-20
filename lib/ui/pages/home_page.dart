// ignore_for_file: unused_element, unused_element_parameter

import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:history_manager/history_manager.dart';

import 'package:namida/base/generator_base.dart';
import 'package:namida/base/loading_items_delay.dart';
import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/color_m.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/generators_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/pages/queues_page.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/queue_card.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/stats.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/controller/yt_generators_controller.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

final int _lowestDateMSSEToDisplay = DateTime(1980).millisecondsSinceEpoch + 1;

class HomePageLocal extends StatefulWidget with NamidaRouteWidget {
  const HomePageLocal({super.key});

  @override
  RouteType get route => RouteType.PAGE_Home;

  @override
  State<HomePageLocal> createState() => _TracksHomePageState();
}

class YTHomePageLocal extends StatefulWidget with NamidaRouteWidget {
  const YTHomePageLocal({super.key});

  @override
  RouteType get route => RouteType.YOUTUBE_HOME_LOCAL;

  @override
  State<YTHomePageLocal> createState() => _YoutubeHomePageState();
}

abstract class _HomePageStateBase<T extends ItemWithDate, E, S extends StatefulWidget> extends State<S> with TickerProviderStateMixin, PullToRefreshMixin {
  bool get showStatsButton;

  HistoryManager<T, E> get historyManager;
  NamidaGeneratorBase<T, E> get generator;

  RxBaseCore<List<HomePageItems>> get homePageItemsRx;
  List<HomePageItems> get supportedHomePageItems;
  int get minimumActiveHomePageItems;
  void saveHomePageItems(List<HomePageItems> activeItems);

  List<E> getAllItemsInLibrary();

  List<E>? getRecentlyAddedItems();

  E? getCurrentPlayingItem();
  String? getItemTitle(E item);
  int getItemDateAdded(E item);
  bool isItemFavourite(E item);
  List<E> getFavouritesSample(int count);

  void removeInvalidMixesItems(List<MapEntry<String, List<E>>> mixes) {}

  Future<void> fillExtraLists(DateTime timeNow) async {}
  void onTopRecentsUpdated() {}
  void emptyExtraLists() {}

  Widget buildRecentListensSliver(BuildContext context, HomePageItems element);
  Widget buildTopRecentListensSliver(BuildContext context, HomePageItems element, Widget daysChips);
  Widget buildLostMemoriesSliver(BuildContext context, HomePageItems element, String subtitle, Widget yearsChips);
  Widget buildMixesCard(BuildContext context, int index, MapEntry<String, List<E>>? entry);
  Widget buildOtherSectionSliver(BuildContext context, HomePageItems element);

  final _shimmerList = List.filled(20, null, growable: true);
  late bool _isLoading;

  List<E>? _recentlyAddedFull;
  final _recentlyAdded = <E>[];
  final _randomItems = <E>[];
  final _recentListened = <T>[];
  var _topRecentListened = <MapEntry<E, List<int>>>[];
  var _sameTimeYearAgo = <MapEntry<E, List<int>>>[];

  final _mixes = <MapEntry<String, List<E>>>[];

  var _lostMemoriesYears = <int>[];
  final _topRecentsDaysList = List<int>.generate(21, (index) => index == 0 ? 1 : index * 3);

  int currentYearLostMemories = 0;
  DateRange? currentYearLostMemoriesDateRange;
  int currentTopRecentsDaysAgo = 0;
  late final ScrollController _scrollController;
  late final ScrollController _lostMemoriesScrollController;
  late final ScrollController _topRecentsScrollController;

  List<E>? _allItemsInLibraryCached;
  List<E> get _allItemsInLibrary => _allItemsInLibraryCached ??= getAllItemsInLibrary();

  @override
  void initState() {
    super.initState();
    _scrollController = NamidaScrollController.create();
    _lostMemoriesScrollController = NamidaScrollController.create();
    _topRecentsScrollController = NamidaScrollController.create();
    _fillLists();
  }

  @override
  void dispose() {
    _emptyAll();
    _scrollController.dispose();
    _lostMemoriesScrollController.dispose();
    _topRecentsScrollController.dispose();
    super.dispose();
  }

  void _emptyAll() {
    _allItemsInLibraryCached = null;
    _recentlyAddedFull?.clear();
    _recentlyAdded.clear();
    _randomItems.clear();
    _recentListened.clear();
    _topRecentListened.clear();
    _sameTimeYearAgo.clear();
    _mixes.clear();
    emptyExtraLists();
  }

  void _fillLists() async {
    final historyManager = this.historyManager;
    if (historyManager.isHistoryLoaded) {
      _isLoading = false;
    } else {
      _isLoading = true;
      await historyManager.waitForHistoryAndMostPlayedLoad;
    }

    final timeNow = DateTime.now();

    // -- Recently Added --
    final allRecentlyAddedItems = getRecentlyAddedItems();
    if (allRecentlyAddedItems != null) {
      _recentlyAddedFull = allRecentlyAddedItems;
      _recentlyAdded.addAll(allRecentlyAddedItems.take(40));
    }

    // -- Recent Listens --
    if (_recentListened.isEmpty) {
      _recentListened.addAll(
        generator.generateItemsFromHistoryDates(DateTime(timeNow.year, timeNow.month, timeNow.day - 3), timeNow, sortByListensInRangeIfRequired: false).take(40),
      );
    }

    // -- Top Recents --
    if (_topRecentListened.isEmpty) {
      _updateTopRecents(3);
    }

    // -- Lost Memories --
    _lostMemoriesYears = historyManager.getHistoryYears()..remove(timeNow.year);
    final oldestYear = _lostMemoriesYears.lastOrNull ?? 0;

    final minusYearClamped = (timeNow.year - 1).withMinimum(oldestYear);

    _updateSameTimeNYearsAgo(timeNow, minusYearClamped);

    await fillExtraLists(timeNow);

    // ==== Mixes ====
    if (_mixes.isEmpty) {
      final topTracksMapListens = historyManager.topTracksMapListens.value;

      // -- Random --
      if (_randomItems.isEmpty) _randomItems.addAll(NamidaGeneratorBase.getRandomItems(_allItemsInLibrary, min: 25, max: 26));

      final int mostRecentAdded7DaysMSSE = timeNow.subtract(Duration(days: 7)).millisecondsSinceEpoch;
      final int mostRecentListened14DaysMSSE = timeNow.subtract(Duration(days: 14)).millisecondsSinceEpoch;
      final underrated = _allItemsInLibrary.getRandomSampleWhere(100, (item) {
        if (isItemFavourite(item)) return false; // alr favourited
        final listensCount = topTracksMapListens[item]?.length;
        if (listensCount != null && listensCount > 8) return false; // alr listened enough
        if (getItemDateAdded(item) > mostRecentAdded7DaysMSSE) return false; // its very recently added
        final lastListen = topTracksMapListens[item]?.lastOrNull;
        if (lastListen != null && lastListen > mostRecentListened14DaysMSSE) return false; // recently listened
        return true;
      });

      final avgTopListensCount = (topTracksMapListens.values.take(20).fold(0, (value, element) => value + element.length) ~/ 20).withMinimum(0);
      final int within1MonthsDaysMSSE = timeNow.subtract(Duration(days: 30 * 1)).millisecondsSinceEpoch;
      final int within3MonthsDaysMSSE = timeNow.subtract(Duration(days: 30 * 3)).millisecondsSinceEpoch;
      final int within6MonthsDaysMSSE = timeNow.subtract(Duration(days: 30 * 6)).millisecondsSinceEpoch;
      final int within12MonthsDaysMSSE = timeNow.subtract(Duration(days: 30 * 12)).millisecondsSinceEpoch;
      final lostPartners = _allItemsInLibrary.getRandomSampleWhere(100, (item) {
        final listens = topTracksMapListens[item];
        if (listens != null && listens.isNotEmpty) {
          final lastListen = listens.last;
          final listensPercentage = listens.length / avgTopListensCount;
          // -- if listens percentage >= p and there is no listen in the last n days
          // -- ex: 90/100 >= 0.9 && no listens within 12 months (where 100 is avg top listens)
          return switch (listensPercentage) {
            >= 0.90 when within12MonthsDaysMSSE > lastListen => true,
            >= 0.50 when within6MonthsDaysMSSE > lastListen => true,
            >= 0.20 when within3MonthsDaysMSSE > lastListen => true,
            >= 0.1 when within1MonthsDaysMSSE > lastListen => true,
            _ => false,
          };
        }
        return false;
      });

      // -- items with little to no listens in the past n days
      final discover = _allItemsInLibrary.getRandomSampleWhere(100, (item) {
        final listens = topTracksMapListens[item];
        if (listens == null || listens.isEmpty) return true;
        if (listens.length > 10) return false;
        int listensCountWithinPeriod = 0;
        for (int i = listens.length - 1; i >= 0; i--) {
          final l = listens[i];
          if (l > within3MonthsDaysMSSE) {
            listensCountWithinPeriod++;
            if (listensCountWithinPeriod > 5) break;
          } else {
            break;
          }
        }
        return listensCountWithinPeriod <= 5;
      });

      // -- supermacy
      final ct = getCurrentPlayingItem();
      final maxCount = settings.queueInsertion.value[QueueInsertionType.algorithm]?.numberOfTracks.withMinimum(10) ?? 50;
      MapEntry<String, List<E>>? supremacyEntry;
      if (ct != null) {
        final sameAsCurrent = generator.generateRecommendedItemsFor(ct, historyManager.mainItemToSubItem).take(maxCount);
        if (sameAsCurrent.isNotEmpty) {
          final supremacy = [ct, ...sameAsCurrent];
          final currentItemTitle = getItemTitle(ct);
          supremacyEntry = MapEntry(currentItemTitle == null || currentItemTitle.isEmpty ? lang.supremacy : '"$currentItemTitle" ${lang.supremacy}', supremacy);
        }
      }
      final favsSample = getFavouritesSample(25);
      final topRecentListenedKeys = _topRecentListened.map((e) => e.key).toList();

      final recentTopSortedByTotalListens = List<E>.from(topRecentListenedKeys)..sortByReverse((e) => topTracksMapListens[e]?.length ?? 0);
      final recent30Items = historyManager.historyTracks.take(30).map(historyManager.mainItemToSubItem).toList();

      final topRecentListenedExpanded = historyManager.getMostListensInTimeRange(
        mptr: MostPlayedTimeRange.custom,
        customDate: DateRange(
          oldest: timeNow.subtract(Duration(days: 14)),
          newest: timeNow,
        ),
        isStartOfDay: false,
        mainItemToSubItem: historyManager.mainItemToSubItem,
      );
      recent30Items.sortByReverse((item) => topRecentListenedExpanded[item]?.length ?? 0);

      final sameTimeAyearAgo = historyManager
          .getMostListensInTimeRange(
            mptr: MostPlayedTimeRange.custom,
            customDate: DateRange(
              oldest: DateTime(timeNow.year - 1, timeNow.month, timeNow.day - 9),
              newest: DateTime(timeNow.year - 1, timeNow.month, timeNow.day + 9),
            ),
            isStartOfDay: false,
            mainItemToSubItem: historyManager.mainItemToSubItem,
          )
          .keysSortedByValue
          .take(40);

      final recommendedMixItems = <E>{
        // -- top recents, sorted by total listens
        ...recentTopSortedByTotalListens,

        // -- top recents, but only from favourites
        ...topRecentListenedKeys.where(isItemFavourite),

        // -- recents, sorted by listens count in a wider recent date range
        ...recent30Items,

        // -- top items in the same time, a year ago
        ...sameTimeAyearAgo,
      }.toList();
      recommendedMixItems.shuffle();

      _mixes.addAll([
        MapEntry(lang.newTracksRecommended, recommendedMixItems),
        ?supremacyEntry,
        MapEntry(lang.topRecents, topRecentListenedKeys),
        MapEntry(lang.underrated, underrated),
        MapEntry(lang.lostPartners, lostPartners),
        MapEntry(lang.discover, discover),
        MapEntry(lang.favourites, favsSample),
        MapEntry(lang.randomPicks, _randomItems),
      ]);

      // -- if any one is empty, remove it and add it to the end
      List<MapEntry<String, List<E>>>? emptyOnes;
      _mixes.removeWhere(
        (m) {
          if (m.value.isEmpty) {
            emptyOnes ??= [];
            emptyOnes!.add(m);
            return true;
          }
          return false;
        },
      );
      if (emptyOnes != null) _mixes.addAll(emptyOnes!);
    }

    removeInvalidMixesItems(_mixes);

    _isLoading = false;

    if (mounted) setState(() {});
  }

  void _updateSameTimeNYearsAgo(DateTime timeNow, int year) {
    final dateRange = DateRange(
      oldest: DateTime(year, timeNow.month, timeNow.day - 5),
      newest: DateTime(year, timeNow.month, timeNow.day + 5),
    );
    currentYearLostMemories = year;
    currentYearLostMemoriesDateRange = dateRange;
    final sortedMap = historyManager.getMostListensInTimeRange(
      mptr: MostPlayedTimeRange.custom,
      customDate: dateRange,
      isStartOfDay: false,
      mainItemToSubItem: historyManager.mainItemToSubItem,
    );
    _sameTimeYearAgo = sortedMap.entriesSortedByValue.toList();
    if (_lostMemoriesScrollController.hasClients) _lostMemoriesScrollController.jumpTo(0);
  }

  DateRange _getDateRangeFromNow(int days) {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));
    return DateRange(oldest: start, newest: end);
  }

  void _updateTopRecents(int days) {
    final sortedMap = historyManager.getMostListensInTimeRange(
      mptr: MostPlayedTimeRange.custom,
      customDate: _getDateRangeFromNow(days),
      isStartOfDay: false,
      mainItemToSubItem: historyManager.mainItemToSubItem,
    );
    currentTopRecentsDaysAgo = days;
    _topRecentListened = sortedMap.entriesSortedByValue.toList();
    onTopRecentsUpdated();
    if (_topRecentsScrollController.hasClients) _topRecentsScrollController.jumpTo(0);
  }

  List<Item?> _listOrShimmer<Item>(List<Item> listy) {
    return _isLoading ? _shimmerList : listy;
  }

  void showReorderHomeItemsDialog() async {
    final mainListController = NamidaScrollController.create();

    await NamidaNavigator.inst.navigateDialog(
      scale: 1.0,
      onDisposing: () {
        mainListController.dispose();
      },
      dialog: CustomBlurryDialog(
        title: "${lang.configure} (${lang.reorderable})",
        actions: const [DoneButton()],
        child: SizedBox(
          width: namida.width,
          height: namida.height * 0.5,
          child: NamidaReorderableActiveListView(
            enumValues: supportedHomePageItems,
            rxList: homePageItemsRx,
            toText: (item) => item.toText(),
            toIcon: (item) => item.toMainIcon(),
            toSecondaryIcon: (item) => item.toIcon(),
            minimumItems: minimumActiveHomePageItems,
            onSave: saveHomePageItems,
          ),
        ),
      ),
    );
  }

  Widget _buildTopRecentsDaysChips(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return SizedBox(
      height: 32.0,
      width: context.width,
      child: SmoothSingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _topRecentsDaysList
                .map(
                  (daysAgo) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: TapDetector(
                      onTap: () {
                        _updateTopRecents(daysAgo);
                        if (mounted) setState(() {});
                      },
                      child: AnimatedDecoration(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          color: currentTopRecentsDaysAgo == daysAgo ? CurrentColor.inst.currentColorScheme.withAlpha(160) : theme.cardColor,
                          borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          child: Text(
                            lang.countDays(count: daysAgo),
                            style: textTheme.displaySmall?.copyWith(
                              color: currentTopRecentsDaysAgo == daysAgo ? Colors.white.withAlpha(240) : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toFixedList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLostMemoriesYearsChips(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return SizedBox(
      height: 32.0,
      width: context.width,
      child: SmoothSingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _lostMemoriesYears
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: TapDetector(
                      onTap: () {
                        _updateSameTimeNYearsAgo(DateTime.now(), e);
                        if (mounted) setState(() {});
                      },
                      child: AnimatedDecoration(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          color: currentYearLostMemories == e ? CurrentColor.inst.currentColorScheme.withAlpha(160) : theme.cardColor,
                          borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          child: Text(
                            '$e',
                            style: textTheme.displaySmall?.copyWith(
                              color: currentYearLostMemories == e ? Colors.white.withAlpha(240) : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toFixedList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.theme.textTheme;
    return BackgroundWrapper(
      child: Listener(
        onPointerMove: (event) {
          onPointerMove(_scrollController, event);
        },
        onPointerUp: (event) {
          onRefresh(() async {
            _emptyAll();
            _fillLists();
          });
        },
        onPointerCancel: (event) => onVerticalDragFinish(),
        child: NamidaScrollbar(
          controller: _scrollController,
          child: Stack(
            children: [
              ShimmerWrapper(
                shimmerDurationMS: 550,
                shimmerDelayMS: 250,
                shimmerEnabled: _isLoading,
                child: AnimationLimiter(
                  child: ObxO(
                    rx: homePageItemsRx,
                    builder: (context, homePageItems) => SmoothCustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        const SliverPadding(padding: EdgeInsets.only(bottom: 12.0)),
                        SliverPadding(
                          padding: const EdgeInsets.all(24.0),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Namida',
                                    style: textTheme.displayLarge?.copyWith(fontSize: 32.0),
                                  ),
                                ),
                                if (showStatsButton)
                                  NamidaIconButton(
                                    icon: Broken.chart_21,
                                    onPressed: StatsPage().navigate,
                                  ),
                                NamidaIconButton(
                                  icon: Broken.setting_4,
                                  onPressed: showReorderHomeItemsDialog,
                                ),
                              ],
                            ),
                          ),
                        ),
                        ...homePageItems
                            .map(
                              (element) {
                                switch (element) {
                                  case HomePageItems.mixes:
                                    return SliverToBoxAdapter(
                                      child: _HorizontalList(
                                        homepageItem: element,
                                        isLoading: _isLoading,
                                        icon: element.toMainIcon(),
                                        title: element.toText(),
                                        height: 186.0 + 12.0 + 2.0,
                                        itemCount: _isLoading ? _shimmerList.length : _mixes.length,
                                        itemExtent: 240.0,
                                        itemBuilder: (context, index) {
                                          final entry = _isLoading ? null : _mixes[index];
                                          return buildMixesCard(context, index, entry);
                                        },
                                      ),
                                    );

                                  case HomePageItems.recentListens:
                                    return buildRecentListensSliver(context, element);

                                  case HomePageItems.topRecentListens:
                                    return buildTopRecentListensSliver(context, element, _buildTopRecentsDaysChips(context));

                                  case HomePageItems.lostMemories:
                                    final subtitle = lang.lostMemoriesSubtitle(number: DateTime.now().year - currentYearLostMemories);
                                    return buildLostMemoriesSliver(context, element, subtitle, _buildLostMemoriesYearsChips(context));

                                  case HomePageItems.recentQueues:
                                  case HomePageItems.recentlyAdded:
                                  case HomePageItems.recentAlbums:
                                  case HomePageItems.recentArtists:
                                  case HomePageItems.topRecentAlbums:
                                  case HomePageItems.topRecentArtists:
                                    return buildOtherSectionSliver(context, element);
                                }
                              },
                            )
                            .addSeparators(
                              skipFirst: 1,
                              separator: const SliverPadding(padding: EdgeInsets.only(bottom: 12.0)),
                            ),
                        kBottomPaddingWidgetSliver,
                      ],
                    ),
                  ),
                ),
              ),
              pullToRefreshWidget,
            ],
          ),
        ),
      ),
    );
  }
}

class _TracksHomePageState extends _HomePageStateBase<TrackWithDate, Track, HomePageLocal> {
  @override
  bool get showStatsButton => true;

  @override
  HistoryManager<TrackWithDate, Track> get historyManager => HistoryController.inst;

  @override
  NamidaGeneratorBase<TrackWithDate, Track> get generator => NamidaGenerator.inst;

  @override
  RxBaseCore<List<HomePageItems>> get homePageItemsRx => settings.homePageItems;

  @override
  List<HomePageItems> get supportedHomePageItems => HomePageItems.values;

  @override
  int get minimumActiveHomePageItems => 3;

  @override
  void saveHomePageItems(List<HomePageItems> activeItems) {
    settings.homePageItems.value = activeItems;
    settings.save(homePageItems: null);
  }

  @override
  List<Track> getAllItemsInLibrary() => allTracksInLibrary;

  @override
  List<Track>? getRecentlyAddedItems() => Indexer.inst.recentlyAddedTracksSorted();

  @override
  Track? getCurrentPlayingItem() => Player.inst.currentTrack?.track;

  @override
  String? getItemTitle(Track item) => item.title;

  @override
  int getItemDateAdded(Track item) => item.dateAdded;

  @override
  bool isItemFavourite(Track item) => PlaylistController.inst.favouritesPlaylist.isSubItemFavourite(item);

  @override
  List<Track> getFavouritesSample(int count) => PlaylistController.inst.favouritesPlaylist.value.tracks.getRandomSample(count).tracks.toList();

  @override
  void removeInvalidMixesItems(List<MapEntry<String, List<Track>>> mixes) {
    for (final m in mixes) {
      m.value.removeWhere((tr) => tr.toTrackExtOrNull() == null);
    }
  }

  final _recentAlbums = <AlbumIdentifierWrapper>[];
  final _recentArtists = <String>[];
  final _topRecentAlbums = <AlbumIdentifierWrapper, int>{};
  final _topRecentArtists = <String, int>{};

  var _recentsItemsList = <Queue>[];
  QueueSourceEnum? currentRecentsSourceType = QueueSourceEnum.playlist;
  late final ScrollController _recentsScrollController;

  @override
  void initState() {
    _recentsScrollController = NamidaScrollController.create();
    super.initState();
  }

  @override
  void dispose() {
    _recentsScrollController.dispose();
    super.dispose();
  }

  @override
  void emptyExtraLists() {
    _recentAlbums.clear();
    _recentArtists.clear();
    _topRecentAlbums.clear();
    _topRecentArtists.clear();
  }

  @override
  Future<void> fillExtraLists(DateTime timeNow) async {
    _updateCurrentRecentsSourceTypeAndSetState(currentRecentsSourceType);

    // -- Recent Albums --
    if (_recentAlbums.isEmpty) _recentAlbums.addAll(_recentListened.mappedUniquedList((e) => e.track.albumsIdentifiersModified).take(25));

    // -- Recent Artists --
    if (_recentArtists.isEmpty) _recentArtists.addAll(_recentListened.mappedUniquedList((e) => e.track.artistsList.map((e) => e.toLowerCase())).take(25));

    _topRecentAlbums.sortByReverse((e) => e.value);
    _topRecentArtists.sortByReverse((e) => e.value);
  }

  @override
  void onTopRecentsUpdated() {
    for (var e in _topRecentListened) {
      // -- Top Recent Albums --
      for (var identifier in e.key.albumsIdentifiersModified) {
        _topRecentAlbums.update(identifier, (value) => value + 1, ifAbsent: () => 1);
      }

      // -- Top Recent Artists --
      for (var e in e.key.artistsList) {
        _topRecentArtists.update(e, (value) => value + 1, ifAbsent: () => 1);
      }
    }
  }

  Future<void> _updateCurrentRecentsSourceTypeAndSetState(QueueSourceEnum? type) async {
    await QueueController.inst.waitForQueuesLoad;

    currentRecentsSourceType = type;

    final map = QueueController.inst.queuesMap.value;
    final keysSortedByLatest = map.keys.toList().reversed;
    final addedSources = <QueueSourceBase>{};
    final queuesToTake = <Queue>[];
    for (final k in keysSortedByLatest) {
      final q = map[k];
      if (q != null) {
        if (type == null || q.source.s == type) {
          if (addedSources.add(q.source)) {
            queuesToTake.add(q);
            if (queuesToTake.length >= 30) {
              break;
            }
          }
        }
      }
    }

    _recentsItemsList = queuesToTake;

    if (_recentsScrollController.hasClients) _recentsScrollController.jumpTo(0);

    if (mounted) setState(() {});
  }

  void _navigateToRecentlyListened() {
    final recentlyAdded = _recentlyAddedFull;
    if (recentlyAdded != null && recentlyAdded.isNotEmpty) {
      RecentlyAddedTracksPage(tracksSorted: recentlyAdded).navigate();
    }
  }

  void _navigateToRecentsPage() {
    QueuesPage().navigate();
  }

  @override
  Widget buildMixesCard(BuildContext context, int index, MapEntry<String, List<Track>>? entry) {
    return _MixesCard(
      key: entry == null ? const Key("") : Key("${entry.key}_${entry.value.firstOrNull}"),
      title: entry?.key ?? '',
      width: 240.0,
      height: 186.0 + 12.0,
      index: index,
      dummyContainer: entry == null,
      tracks: entry?.value ?? [],
    );
  }

  @override
  Widget buildRecentListensSliver(BuildContext context, HomePageItems element) {
    return _TracksList(
      listId: 'recentListens',
      homepageItem: element,
      isLoading: _isLoading,
      icon: element.toMainIcon(),
      title: element.toText(),
      listy: _recentListened,
      onTap: NamidaOnTaps.inst.onHistoryPlaylistTap,
      topRightText: (track) {
        if (track?.trackWithDate == null) return null;
        return TimeAgoController.dateMSSEFromNow(track!.trackWithDate!.dateAdded, long: false);
      },
    );
  }

  @override
  Widget buildTopRecentListensSliver(BuildContext context, HomePageItems element, Widget daysChips) {
    return _TracksList(
      listId: 'topRecentListens',
      controller: _topRecentsScrollController,
      homepageItem: element,
      isLoading: _isLoading,
      icon: element.toMainIcon(),
      title: element.toText(),
      listy: const [],
      listWithListens: _topRecentListened,
      onTap: () {
        NamidaOnTaps.inst.onMostPlayedPlaylistTap(
          mptr: MostPlayedTimeRange.custom,
          dateCustom: _getDateRangeFromNow(currentTopRecentsDaysAgo),
        );
      },
      thirdWidget: daysChips,
    );
  }

  @override
  Widget buildLostMemoriesSliver(BuildContext context, HomePageItems element, String subtitle, Widget yearsChips) {
    return _TracksList(
      listId: 'lostMemories_$currentYearLostMemories',
      controller: _lostMemoriesScrollController,
      homepageItem: element,
      isLoading: _isLoading,
      icon: element.toMainIcon(),
      title: element.toText(),
      subtitle: subtitle,
      listy: const [],
      listWithListens: _sameTimeYearAgo,
      onTap: () {
        NamidaOnTaps.inst.onMostPlayedPlaylistTap(
          mptr: MostPlayedTimeRange.custom,
          dateCustom: currentYearLostMemoriesDateRange,
        );
      },
      thirdWidget: yearsChips,
    );
  }

  @override
  Widget buildOtherSectionSliver(BuildContext context, HomePageItems element) {
    switch (element) {
      case HomePageItems.recentlyAdded:
        return _TracksList(
          listId: 'recentlyAdded',
          queueSource: QueueSource.recentlyAdded,
          isLoading: _isLoading,
          homepageItem: element,
          icon: element.toMainIcon(),
          title: element.toText(),
          listy: _recentlyAdded,
          onTap: _navigateToRecentlyListened,
          topRightText: (track) {
            if (track == null) return null;
            final creationDate = track.track.dateAdded;
            if (creationDate > _lowestDateMSSEToDisplay) return TimeAgoController.dateMSSEFromNow(creationDate, long: false);
            return null;
          },
        );

      case HomePageItems.recentQueues:
        final theme = context.theme;
        final textTheme = theme.textTheme;
        return SliverToBoxAdapter(
          child: _HorizontalList(
            isLoading: _isLoading,
            homepageItem: element,
            leading: StackedIcon(
              baseIcon: element.toMainIcon(),
              secondaryIcon: element.toIcon(),
            ),
            title: element.toText(),
            onTap: _navigateToRecentsPage,
            height: 150.0 + 12.0,
            thirdWidget: SizedBox(
              height: 32.0,
              width: context.width,
              child: SmoothSingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        [
                              QueueSourceEnum.playlist,
                              QueueSourceEnum.folder,
                              QueueSourceEnum.folderMusic,
                              QueueSourceEnum.folderVideos,
                              null,
                            ]
                            .map(
                              (sourceType) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                child: TapDetector(
                                  onTap: () {
                                    _updateCurrentRecentsSourceTypeAndSetState(sourceType);
                                  },
                                  child: AnimatedDecoration(
                                    duration: const Duration(milliseconds: 250),
                                    decoration: BoxDecoration(
                                      color: currentRecentsSourceType == sourceType ? CurrentColor.inst.currentColorScheme.withAlpha(160) : theme.cardColor,
                                      borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                      child: Text(
                                        sourceType?.toText() ?? lang.all,
                                        style: textTheme.displaySmall?.copyWith(
                                          color: currentRecentsSourceType == sourceType ? Colors.white.withAlpha(240) : null,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toFixedList(),
                  ),
                ),
              ),
            ),
            itemCount: _recentsItemsList.length,
            itemExtent: 98.0 + 8.0,
            itemBuilder: (context, i) {
              final queue = _recentsItemsList[i];
              return QueueCard(
                queue: queue,
                fullInfo: false,
                homepageItem: element,
                preferOpenOriginalSource: true,
              );
            },
          ),
        );

      case HomePageItems.recentAlbums:
        return _AlbumsList(
          isLoading: _isLoading,
          homepageItem: element,
          mainIcon: element.toMainIcon(),
          title: element.toText(),
          albums: _listOrShimmer(_recentAlbums),
          listens: null,
        );

      case HomePageItems.topRecentAlbums:
        final keys = _topRecentAlbums.keys.toList();
        return _AlbumsList(
          isLoading: _isLoading,
          homepageItem: element,
          mainIcon: element.toMainIcon(),
          title: element.toText(),
          albums: _listOrShimmer(keys),
          listens: (album) => _topRecentAlbums[album] ?? 0,
        );

      case HomePageItems.recentArtists:
        return _ArtistsList(
          isLoading: _isLoading,
          homepageItem: element,
          mainIcon: element.toMainIcon(),
          title: element.toText(),
          artists: _listOrShimmer(_recentArtists),
          listens: null,
        );

      case HomePageItems.topRecentArtists:
        final keys = _topRecentArtists.keys.toList();
        return _ArtistsList(
          isLoading: _isLoading,
          homepageItem: element,
          mainIcon: element.toMainIcon(),
          title: element.toText(),
          artists: _listOrShimmer(keys),
          listens: (artist) => _topRecentArtists[artist] ?? 0,
        );

      case HomePageItems.mixes:
      case HomePageItems.recentListens:
      case HomePageItems.topRecentListens:
      case HomePageItems.lostMemories:
        return const SliverToBoxAdapter(child: SizedBox());
    }
  }
}

class _YoutubeHomePageState extends _HomePageStateBase<YoutubeID, String, YTHomePageLocal> {
  @override
  bool get showStatsButton => false;

  @override
  HistoryManager<YoutubeID, String> get historyManager => YoutubeHistoryController.inst;

  @override
  NamidaGeneratorBase<YoutubeID, String> get generator => NamidaYTGenerator.inst;

  static const _supportedItems = <HomePageItems>[
    HomePageItems.mixes,
    HomePageItems.recentListens,
    HomePageItems.topRecentListens,
    HomePageItems.lostMemories,
  ];

  @override
  RxBaseCore<List<HomePageItems>> get homePageItemsRx => settings.youtube.ytHomePageItems;

  @override
  List<HomePageItems> get supportedHomePageItems => _supportedItems;

  @override
  int get minimumActiveHomePageItems => 2;

  @override
  void saveHomePageItems(List<HomePageItems> activeItems) {
    settings.youtube.save(ytHomePageItems: activeItems);
  }

  @override
  List<String> getAllItemsInLibrary() => historyManager.topTracksMapListens.value.keysSortedByValue.toList();

  @override
  List<String>? getRecentlyAddedItems() => null;

  @override
  String? getCurrentPlayingItem() => Player.inst.currentVideo?.id;

  @override
  String? getItemTitle(String item) => YoutubeInfoController.utils.getVideoNameSync(item, checkFromStorage: false);

  @override
  int getItemDateAdded(String item) => historyManager.topTracksMapListens.value[item]?.firstOrNull ?? 0;

  @override
  bool isItemFavourite(String item) => YoutubePlaylistController.inst.favouritesPlaylist.isSubItemFavourite(item);

  @override
  List<String> getFavouritesSample(int count) => YoutubePlaylistController.inst.favouritesPlaylist.value.tracks.getRandomSample(count).map((e) => e.id).toList();

  static const _cardThumbHeight = 24.0 * 3.2;
  static const _cardThumbWidth = _cardThumbHeight * 16 / 9;
  static const _cardExtent = _cardThumbWidth + 4.0;
  static const _mixCardWidth = 240.0;

  static (String, YTWatch?) _listenEntryToYTVideoId(MapEntry<String, List<int>> e) => (e.key, null);

  Widget _buildDummyCard(BuildContext context) {
    return NamidaInkWell(
      animationDurationMS: 200,
      margin: const EdgeInsets.symmetric(horizontal: 2.0),
      width: _cardThumbWidth,
      bgColor: context.theme.cardColor,
    );
  }

  Widget _buildVideoCardsSliver({
    required HomePageItems element,
    required int itemCount,
    required Widget Function(BuildContext context, int index, VideoTileProperties properties) itemBuilder,
    void Function()? onTap,
    String? subtitle,
    Widget? thirdWidget,
    ScrollController? controller,
    bool extraHeight = false,
  }) {
    return SliverToBoxAdapter(
      child: VideoTilePropertiesProvider(
        configs: const VideoTilePropertiesConfigs(
          queueSource: QueueSourceYoutubeID.ytHomePageItem,
        ),
        builder: (properties) => _HorizontalList(
          homepageItem: element,
          isLoading: _isLoading,
          icon: element.toMainIcon(),
          title: element.toText(),
          subtitle: subtitle,
          thirdWidget: thirdWidget,
          controller: controller,
          onTap: onTap,
          height: 144.0 + (extraHeight ? 12.0 : 0.0),
          itemCount: _isLoading ? _shimmerList.length : itemCount,
          itemExtent: _cardExtent,
          itemBuilder: (context, index) {
            if (_isLoading) return _buildDummyCard(context);
            return itemBuilder(context, index, properties);
          },
        ),
      ),
    );
  }

  @override
  Widget buildMixesCard(BuildContext context, int index, MapEntry<String, List<String>>? entry) {
    return _YTMixesCard(
      key: entry == null ? const Key("") : Key("${entry.key}_${entry.value.firstOrNull}"),
      title: entry?.key ?? '',
      width: _mixCardWidth,
      index: index,
      videoIds: entry?.value ?? [],
    );
  }

  @override
  Widget buildRecentListensSliver(BuildContext context, HomePageItems element) {
    return _buildVideoCardsSliver(
      element: element,
      itemCount: _recentListened.length,
      onTap: YTUtils.onYoutubeHistoryPlaylistTap,
      extraHeight: true,
      itemBuilder: (context, index, properties) => YTHistoryVideoCard(
        properties: properties,
        minimalCard: true,
        videos: _recentListened,
        index: index,
        day: null,
        minimalCardWidth: _cardThumbWidth,
        thumbnailHeight: _cardThumbHeight,
      ),
    );
  }

  @override
  Widget buildTopRecentListensSliver(BuildContext context, HomePageItems element, Widget daysChips) {
    return _buildVideoCardsSliver(
      element: element,
      itemCount: _topRecentListened.length,
      controller: _topRecentsScrollController,
      thirdWidget: daysChips,
      onTap: () {
        YTUtils.onYoutubeMostPlayedPlaylistTap(
          mptr: MostPlayedTimeRange.custom,
          dateCustom: _getDateRangeFromNow(currentTopRecentsDaysAgo),
        );
      },
      itemBuilder: (context, index, properties) => YTHistoryVideoCardBase<MapEntry<String, List<int>>>(
        properties: properties,
        minimalCard: true,
        mainList: _topRecentListened,
        itemToYTVideoId: _listenEntryToYTVideoId,
        info: null,
        index: index,
        day: null,
        minimalCardWidth: _cardThumbWidth,
        thumbnailHeight: _cardThumbHeight,
        overrideListens: _topRecentListened[index].value,
      ),
    );
  }

  @override
  Widget buildLostMemoriesSliver(BuildContext context, HomePageItems element, String subtitle, Widget yearsChips) {
    return _buildVideoCardsSliver(
      element: element,
      itemCount: _sameTimeYearAgo.length,
      controller: _lostMemoriesScrollController,
      subtitle: subtitle,
      thirdWidget: yearsChips,
      onTap: () {
        YTUtils.onYoutubeMostPlayedPlaylistTap(
          mptr: MostPlayedTimeRange.custom,
          dateCustom: currentYearLostMemoriesDateRange,
        );
      },
      itemBuilder: (context, index, properties) => YTHistoryVideoCardBase<MapEntry<String, List<int>>>(
        properties: properties,
        minimalCard: true,
        mainList: _sameTimeYearAgo,
        itemToYTVideoId: _listenEntryToYTVideoId,
        info: null,
        index: index,
        day: null,
        minimalCardWidth: _cardThumbWidth,
        thumbnailHeight: _cardThumbHeight,
        overrideListens: _sameTimeYearAgo[index].value,
      ),
    );
  }

  @override
  Widget buildOtherSectionSliver(BuildContext context, HomePageItems element) {
    return const SliverToBoxAdapter(child: SizedBox());
  }
}

class _TracksList extends StatelessWidget {
  final String title;
  final HomePageItems homepageItem;
  final String? subtitle;
  final Widget? thirdWidget;
  final IconData icon;
  final List<Selectable?> listy;
  final List<MapEntry<Track, List<int>>?>? listWithListens;
  final void Function()? onTap;
  final Widget? leading;
  final String? Function(Selectable? track)? topRightText;
  final QueueSource queueSource;
  final String listId;
  final ScrollController? controller;
  final bool isLoading;

  const _TracksList({
    super.key,
    required this.title,
    required this.homepageItem,
    this.subtitle,
    this.thirdWidget,
    required this.icon,
    required this.listy,
    this.listWithListens,
    this.onTap,
    this.leading,
    this.topRightText,
    this.queueSource = QueueSource.homePageItem,
    required this.listId,
    this.controller,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final finalListWithListens = listWithListens;

    if (finalListWithListens != null) {
      final queue = finalListWithListens.firstOrNull == null ? <Track>[] : finalListWithListens.map((e) => e!.key);
      return SliverToBoxAdapter(
        child: _HorizontalList(
          isLoading: isLoading,
          homepageItem: homepageItem,
          controller: controller,
          title: title,
          icon: icon,
          leading: leading,
          height: 150.0 + 12.0,
          itemCount: finalListWithListens.length,
          itemExtent: 98.0 + 8.0,
          onTap: onTap,
          subtitle: subtitle,
          thirdWidget: thirdWidget,
          itemBuilder: (context, index) {
            final twl = finalListWithListens[index];
            return _TrackCard(
              listId: listId,
              homepageItem: homepageItem,
              title: title,
              index: index,
              queue: queue,
              width: 98.0,
              track: twl?.key,
              listens: twl?.value,
              topRightText: topRightText == null ? null : topRightText!(twl?.key),
            );
          },
        ),
      );
    } else {
      final finalList = listy;
      final queue = listy.firstOrNull == null ? <Track>[] : finalList.cast<Selectable>();
      return SliverToBoxAdapter(
        child: _HorizontalList(
          isLoading: isLoading,
          homepageItem: homepageItem,
          title: title,
          icon: icon,
          leading: leading,
          height: 150.0 + 12.0,
          itemCount: finalList.length,
          itemExtent: 98.0 + 8.0,
          onTap: onTap,
          subtitle: subtitle,
          thirdWidget: thirdWidget,
          itemBuilder: (context, index) {
            final tr = finalList[index];
            return _TrackCard(
              listId: listId,
              homepageItem: homepageItem,
              title: title,
              index: index,
              queue: queue,
              width: 98.0,
              track: tr?.track,
              topRightText: topRightText == null ? null : topRightText!(tr),
            );
          },
        ),
      );
    }
  }
}

class _AlbumsList extends StatelessWidget {
  final bool isLoading;
  final String title;
  final IconData mainIcon;
  final List<AlbumIdentifierWrapper?> albums;
  final int Function(AlbumIdentifierWrapper? album)? listens;
  final HomePageItems homepageItem;

  const _AlbumsList({
    super.key,
    required this.isLoading,
    required this.title,
    required this.mainIcon,
    required this.albums,
    required this.listens,
    required this.homepageItem,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = albums.length;
    return SliverToBoxAdapter(
      child: ObxO(
        rx: Indexer.inst.mainMapAlbums.rx,
        builder: (context, value) => _HorizontalList(
          isLoading: isLoading,
          homepageItem: homepageItem,
          title: title,
          leading: StackedIcon(
            baseIcon: mainIcon,
            secondaryIcon: Broken.music_dashboard,
          ),
          height: 150.0 + 12.0,
          itemCount: itemCount,
          itemExtent: 98.0 + 8.0,
          itemBuilder: (context, index) {
            final albumId = albums[index];
            return AlbumCard(
              key: ValueKey(albumId),
              dummyCard: isLoading,
              homepageItem: homepageItem,
              displayIcon: !isLoading,
              compact: true,
              identifier: albumId,
              album: albumId?.getAlbumTracks() ?? [],
              staggered: false,
              extraInfo: listens == null ? null : "${listens!(albumId)}",
              forceExtraInfoAtTopRight: true,
              additionalHeroTag: "$title$index",
            );
          },
        ),
      ),
    );
  }
}

class _ArtistsList extends StatelessWidget {
  final bool isLoading;
  final String title;
  final IconData mainIcon;
  final List<String?> artists;
  final int Function(String? artist)? listens;
  final HomePageItems homepageItem;

  const _ArtistsList({
    super.key,
    required this.isLoading,
    required this.title,
    required this.mainIcon,
    required this.artists,
    required this.listens,
    required this.homepageItem,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = artists.length;
    return SliverToBoxAdapter(
      child: ObxO(
        rx: Indexer.inst.mainMapArtists.rx,
        builder: (context, value) => _HorizontalList(
          isLoading: isLoading,
          homepageItem: homepageItem,
          title: title,
          leading: StackedIcon(
            baseIcon: mainIcon,
            secondaryIcon: Broken.user,
          ),
          height: 124.0,
          itemCount: itemCount,
          itemExtent: 86.0,
          itemBuilder: (context, index) {
            final a = artists[index];
            return ArtistCard(
              homepageItem: homepageItem,
              displayIcon: !isLoading,
              name: a ?? '',
              artist: a?.getArtistTracks() ?? [],
              bottomCenterText: isLoading || listens == null ? null : "${listens!(a)}",
              additionalHeroTag: "$title$index",
              type: MediaType.artist,
            );
          },
        ),
      ),
    );
  }
}

class _HorizontalList extends StatelessWidget {
  final HomePageItems homepageItem;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final double height;
  final int? itemCount;
  final double? itemExtent;
  final void Function()? onTap;
  final Widget? trailing;
  final Widget? thirdWidget;
  final Widget? leading;
  final NullableIndexedWidgetBuilder itemBuilder;
  final Color? iconColor;
  final ScrollController? controller;
  final bool isLoading;

  const _HorizontalList({
    required this.homepageItem,
    required this.title,
    this.subtitle,
    this.icon,
    required this.itemCount,
    required this.itemExtent,
    required this.itemBuilder,
    this.height = 400,
    this.onTap,
    this.trailing,
    this.thirdWidget,
    this.leading,
    this.iconColor,
    this.controller,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return Column(
      children: [
        NamidaInkWell(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 16.0),
              leading ??
                  Icon(
                    icon,
                    color: iconColor ?? context.defaultIconColor(),
                  ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.displayLarge,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: textTheme.displaySmall,
                      ),
                    ?thirdWidget,
                  ],
                ),
              ),
              if (onTap != null || trailing != null) ...[
                const SizedBox(width: 8.0),
                trailing ??
                    const Icon(
                      Broken.arrow_right_3,
                      size: 20.0,
                    ),
                const SizedBox(width: 12.0),
              ],
            ],
          ),
        ),
        SizedBox(
          height: height,
          width: context.width,
          child: itemCount == 0 && !isLoading
              ? Center(
                  child: SmoothSingleChildScrollView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                    scrollDirection: Axis.horizontal,
                    child: NamidaInkWell(
                      borderRadius: 10.0,
                      bgColor: theme.cardColor.withOpacityExt(0.5),
                      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Text(
                        switch (homepageItem) {
                          HomePageItems.mixes => '',
                          HomePageItems.recentListens || HomePageItems.topRecentListens => lang.noTracksInHistory,
                          HomePageItems.lostMemories => lang.noTracksFoundBetweenDates,
                          HomePageItems.recentlyAdded || HomePageItems.recentQueues => lang.noTracksFound,
                          HomePageItems.recentAlbums || HomePageItems.recentArtists => "${lang.none}: ${lang.noTracksInHistory}",
                          HomePageItems.topRecentAlbums || HomePageItems.topRecentArtists => "${lang.none}: ${lang.noTracksInHistory}",
                        },
                        style: textTheme.displayMedium,
                        softWrap: false,
                      ),
                    ),
                  ),
                )
              : SuperSmoothListView.builder(
                  key: ValueKey(isLoading),
                  controller: controller,
                  itemExtent: itemExtent,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                  scrollDirection: Axis.horizontal,
                  itemCount: itemCount,
                  itemBuilder: itemBuilder,
                ),
        ),
      ],
    );
  }
}

class _MixesCard extends StatefulWidget {
  final String title;
  final double width;
  final double height;
  final Color? color;
  final int index;
  final List<Track> tracks;
  final bool dummyContainer;

  const _MixesCard({
    required super.key,
    required this.width,
    required this.height,
    required this.title,
    this.color,
    required this.index,
    required this.tracks,
    required this.dummyContainer,
  });

  @override
  State<_MixesCard> createState() => _MixesCardState();
}

class _MixesCardState extends State<_MixesCard> {
  Color? _cardColor;
  Track? _track;

  @override
  void initState() {
    super.initState();
    final track = _track ??= widget.tracks.trackOfImage;
    if (track != null) {
      _cardColor = CurrentColor.inst.getTrackColorsSync(track, networkArtworkInfo: null)?.color;
      if (_cardColor == null) {
        Future.delayed(const Duration(milliseconds: 500)).then((_) => _extractColor(track));
      }
    }
  }

  void onMixTap(Widget thumbnailWidget) {
    final textTheme = context.textTheme;
    const contentColor = Color.fromRGBO(242, 242, 242, 0.7);
    const contentColorAlt = Color.fromRGBO(42, 42, 42, 0.8);
    NamidaNavigator.inst.navigateDialog(
      colorScheme: _cardColor,
      durationInMs: 250,
      dialogBuilder: (theme) => Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: Dimensions.inst.availableAppContentWidth,
          child: SafeArea(
            child: SmoothCustomScrollView(
              slivers: [
                const SliverPadding(padding: EdgeInsets.only(top: kToolbarHeight)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  sliver: SliverToBoxAdapter(
                    child: thumbnailWidget,
                  ),
                ),
                SliverToBoxAdapter(
                  child: NamidaInkWell(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12.0.multipliedRadius),
                      ),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 32.0).add(const EdgeInsets.only(top: 12.0)),
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                    bgColor: Color.alphaBlend(_cardColor?.withOpacityExt(0.4) ?? Colors.transparent, Color.fromRGBO(80, 80, 80, 0.4)).withOpacityExt(0.9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Broken.audio_square,
                          size: 26.0,
                          color: contentColor,
                        ),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: textTheme.displayLarge?.copyWith(
                              fontSize: 15.0,
                              color: contentColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        NamidaInkWell(
                          onTap: () {
                            Player.inst.playOrPause(
                              0,
                              widget.tracks,
                              QueueSource.homePageItem,
                              homePageItem: HomePageItems.mixes,
                            );
                          },
                          borderRadius: 8.0,
                          padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 4.0),
                          bgColor: contentColor.withOpacityExt(0.6),
                          child: Row(
                            children: [
                              const Icon(
                                Broken.play_cricle,
                                size: 20.0,
                                color: contentColorAlt,
                              ),
                              const SizedBox(width: 4.0),
                              Text(
                                "${widget.tracks.length}",
                                style: textTheme.displayLarge?.copyWith(
                                  fontSize: 15.0,
                                  color: contentColorAlt,
                                ),
                              ),
                              const SizedBox(width: 2.0),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  sliver: SliverFillRemaining(
                    fillOverscroll: true,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(18.0.multipliedRadius),
                      ),
                      child: TrackTilePropertiesProvider(
                        configs: const TrackTilePropertiesConfigs(
                          queueSource: QueueSource.homePageItem,
                        ),
                        builder: (properties) => SuperSmoothListView.builder(
                          itemExtent: Dimensions.inst.trackTileItemExtent,
                          itemCount: widget.tracks.length,
                          itemBuilder: (context, index) {
                            final tr = widget.tracks[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: theme.scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                              ),
                              child: TrackTile(
                                properties: properties,
                                homePageItem: HomePageItems.mixes,
                                trackOrTwd: tr,
                                index: index,
                                tracks: widget.tracks,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _extractColor(Track track) {
    if (!mounted) return;
    if (_cardColor == null) {
      CurrentColor.inst.getTrackColors(track, networkArtworkInfo: null, useIsolate: true).then((value) {
        if (mounted) setState(() => _cardColor = value.color);
      });
    }
  }

  Widget getStackedWidget({
    required double topPadding,
    required double horizontalPadding,
    int alpha = 255,
    double blur = 0.0,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: NamidaBlur(
        blur: blur,
        fixArtifacts: true,
        child: AnimatedSizedBox(
          duration: const Duration(milliseconds: 300),
          width: widget.width - horizontalPadding,
          height: double.infinity,
          decoration: BoxDecoration(
            color: _cardColor?.withAlpha(alpha),
            border: Border.all(color: context.theme.scaffoldBackgroundColor.withAlpha(alpha)),
            borderRadius: BorderRadius.circular(10.0.multipliedRadius),
          ),
        ),
      ),
    );
  }

  Widget artworkWidget({required bool displayShimmer, required bool fullscreen}) {
    final textTheme = context.textTheme;
    const contentColor = Color.fromRGBO(242, 242, 242, 0.1);
    const contentColorAlt = Color.fromRGBO(242, 242, 242, 0.8);
    final tag = 'mix_thumbnail_${widget.title}${widget.index}';
    return NamidaHero(
      tag: tag,
      child: ArtworkWidget(
        key: Key(tag),
        track: _track,
        compressed: false,
        blur: 10,
        disableBlurBgSizeShrink: true,
        borderRadius: fullscreen ? 12.0 : 8.0,
        forceSquared: true,
        path: _track?.pathToImage,
        displayIcon: !displayShimmer,
        thumbnailSize: widget.width,
        width: fullscreen ? context.width : null,
        onTopWidgets: [
          if (fullscreen)
            Positioned(
              top: 12.0,
              left: 0.0,
              child: NamidaBgBlurClipped(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: contentColor,
                ),
                blur: 8.0,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: NamidaIconButton(
                    verticalPadding: 4.0,
                    horizontalPadding: 12.0,
                    icon: Broken.arrow_left_2,
                    iconColor: contentColorAlt,
                    onPressed: NamidaNavigator.inst.closeDialog,
                  ),
                ),
              ),
            ),
          if (!displayShimmer && !fullscreen)
            Positioned(
              bottom: 0,
              right: 0,
              child: NamidaInkWell(
                onTap: () {
                  Player.inst.playOrPause(
                    0,
                    widget.tracks,
                    QueueSource.homePageItem,
                    homePageItem: HomePageItems.mixes,
                  );
                },
                borderRadius: 8.0,
                margin: const EdgeInsets.all(6.0),
                padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 4.0),
                bgColor: context.theme.cardColor.withAlpha(240),
                child: Row(
                  children: [
                    const Icon(Broken.play_cricle, size: 16.0),
                    const SizedBox(width: 4.0),
                    Text(
                      "${widget.tracks.length}",
                      style: textTheme.displaySmall?.copyWith(fontSize: 15.0),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final displayShimmer = _track == null;

    final thumbnailWidget = Stack(
      alignment: Alignment.topCenter,
      children: [
        getStackedWidget(
          topPadding: 0,
          horizontalPadding: 36.0,
          alpha: 100,
        ),
        getStackedWidget(
          topPadding: 2.5,
          horizontalPadding: 22.0,
          alpha: 180,
        ),
        getStackedWidget(
          topPadding: 6.0,
          horizontalPadding: 0.0,
          alpha: 180,
          blur: 2.0,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6.0).add(const EdgeInsets.all(1.0)),
          child: artworkWidget(fullscreen: false, displayShimmer: displayShimmer),
        ),
      ],
    );

    return NamidaInkWell(
      onTap: () => onMixTap(artworkWidget(fullscreen: true, displayShimmer: displayShimmer)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: AnimatedSizedBox(
          width: widget.width,
          duration: const Duration(milliseconds: 300),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(child: thumbnailWidget),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4.0),
                    Text(
                      widget.title,
                      style: textTheme.displayMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.tracks.take(5).map((e) => e.title).join(', '),
                      style: textTheme.displaySmall?.copyWith(fontSize: 11.0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4.0),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YTMixesCard extends StatefulWidget {
  final String title;
  final double width;
  final int index;
  final List<String> videoIds;

  const _YTMixesCard({
    required super.key,
    required this.width,
    required this.title,
    required this.index,
    required this.videoIds,
  });

  @override
  State<_YTMixesCard> createState() => _YTMixesCardState();
}

class _YTMixesCardState extends State<_YTMixesCard> {
  Color? _cardColor;

  static (String, YTWatch?) _videoIdToYTVideoId(String id) => (id, null);

  void _onColorReady(NamidaColor? color) {
    if (color != null && mounted) setState(() => _cardColor = color.color);
  }

  void _playMix() {
    Player.inst.playOrPause(
      0,
      widget.videoIds.map((id) => YoutubeID(id: id, playlistID: null)),
      QueueSourceYoutubeID.ytHomePageItem,
      homePageItem: HomePageItems.mixes,
    );
  }

  void onMixTap(Widget thumbnailWidget) {
    final textTheme = context.textTheme;
    const contentColor = Color.fromRGBO(242, 242, 242, 0.7);
    const contentColorAlt = Color.fromRGBO(42, 42, 42, 0.8);
    NamidaNavigator.inst.navigateDialog(
      colorScheme: _cardColor,
      durationInMs: 250,
      dialogBuilder: (theme) => Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: Dimensions.inst.availableAppContentWidth,
          child: SafeArea(
            child: SmoothCustomScrollView(
              slivers: [
                const SliverPadding(padding: EdgeInsets.only(top: kToolbarHeight)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  sliver: SliverToBoxAdapter(
                    child: thumbnailWidget,
                  ),
                ),
                SliverToBoxAdapter(
                  child: NamidaInkWell(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12.0.multipliedRadius),
                      ),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 32.0).add(const EdgeInsets.only(top: 12.0)),
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                    bgColor: Color.alphaBlend(_cardColor?.withOpacityExt(0.4) ?? Colors.transparent, Color.fromRGBO(80, 80, 80, 0.4)).withOpacityExt(0.9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Broken.video_square,
                          size: 26.0,
                          color: contentColor,
                        ),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: textTheme.displayLarge?.copyWith(
                              fontSize: 15.0,
                              color: contentColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        NamidaInkWell(
                          onTap: _playMix,
                          borderRadius: 8.0,
                          padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 4.0),
                          bgColor: contentColor.withOpacityExt(0.6),
                          child: Row(
                            children: [
                              const Icon(
                                Broken.play_cricle,
                                size: 20.0,
                                color: contentColorAlt,
                              ),
                              const SizedBox(width: 4.0),
                              Text(
                                "${widget.videoIds.length}",
                                style: textTheme.displayLarge?.copyWith(
                                  fontSize: 15.0,
                                  color: contentColorAlt,
                                ),
                              ),
                              const SizedBox(width: 2.0),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  sliver: SliverFillRemaining(
                    fillOverscroll: true,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(18.0.multipliedRadius),
                      ),
                      child: VideoTilePropertiesProvider(
                        configs: const VideoTilePropertiesConfigs(
                          queueSource: QueueSourceYoutubeID.ytHomePageItem,
                        ),
                        builder: (properties) => SuperSmoothListView.builder(
                          itemExtent: Dimensions.youtubeCardItemExtent,
                          itemCount: widget.videoIds.length,
                          itemBuilder: (context, index) {
                            return YTHistoryVideoCardBase<String>(
                              mainList: widget.videoIds,
                              itemToYTVideoId: _videoIdToYTVideoId,
                              info: null,
                              day: null,
                              index: index,
                              properties: properties,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget getStackedWidget({
    required double topPadding,
    required double horizontalPadding,
    int alpha = 255,
    double blur = 0.0,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: NamidaBlur(
        blur: blur,
        fixArtifacts: true,
        child: AnimatedSizedBox(
          duration: const Duration(milliseconds: 300),
          width: widget.width - horizontalPadding,
          height: double.infinity,
          decoration: BoxDecoration(
            color: _cardColor?.withAlpha(alpha),
            border: Border.all(color: context.theme.scaffoldBackgroundColor.withAlpha(alpha)),
            borderRadius: BorderRadius.circular(10.0.multipliedRadius),
          ),
        ),
      ),
    );
  }

  Widget artworkWidget({required bool fullscreen}) {
    final textTheme = context.textTheme;
    const contentColor = Color.fromRGBO(242, 242, 242, 0.1);
    const contentColorAlt = Color.fromRGBO(242, 242, 242, 0.8);
    final tag = 'ytmix_thumbnail_${widget.title}${widget.index}';
    final displayPlayCount = !fullscreen && widget.videoIds.isNotEmpty;
    final width = fullscreen ? context.width : widget.width - 2.0;
    return NamidaHero(
      tag: tag,
      child: YoutubeThumbnail(
        key: Key(tag),
        type: ThumbnailType.video,
        videoId: widget.videoIds.firstOrNull,
        width: width,
        height: width * 9 / 16,
        borderRadius: fullscreen ? 12.0 : 8.0,
        isImportantInCache: true,
        preferLowerRes: false,
        extractColor: true,
        onColorReady: _onColorReady,
        onTopWidgets: (color) => [
          if (fullscreen)
            Positioned(
              top: 12.0,
              left: 0.0,
              child: NamidaBgBlurClipped(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: contentColor,
                ),
                blur: 8.0,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: NamidaIconButton(
                    verticalPadding: 4.0,
                    horizontalPadding: 12.0,
                    icon: Broken.arrow_left_2,
                    iconColor: contentColorAlt,
                    onPressed: NamidaNavigator.inst.closeDialog,
                  ),
                ),
              ),
            ),
          if (displayPlayCount)
            Positioned(
              bottom: 0,
              right: 0,
              child: NamidaInkWell(
                onTap: _playMix,
                borderRadius: 8.0,
                margin: const EdgeInsets.all(6.0),
                padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 4.0),
                bgColor: context.theme.cardColor.withAlpha(240),
                child: Row(
                  children: [
                    const Icon(Broken.play_cricle, size: 16.0),
                    const SizedBox(width: 4.0),
                    Text(
                      "${widget.videoIds.length}",
                      style: textTheme.displaySmall?.copyWith(fontSize: 15.0),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;

    final thumbHeight = 6.0 + 2.0 + (widget.width - 2.0) * 9 / 16;
    final thumbnailWidget = SizedBox(
      width: widget.width,
      height: thumbHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          getStackedWidget(
            topPadding: 0,
            horizontalPadding: 36.0,
            alpha: 100,
          ),
          getStackedWidget(
            topPadding: 2.5,
            horizontalPadding: 22.0,
            alpha: 180,
          ),
          getStackedWidget(
            topPadding: 6.0,
            horizontalPadding: 0.0,
            alpha: 180,
            blur: 2.0,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6.0).add(const EdgeInsets.all(1.0)),
            child: artworkWidget(fullscreen: false),
          ),
        ],
      ),
    );

    final videoNamesJoined = widget.videoIds.take(5).map((id) => YoutubeInfoController.utils.getVideoNameSync(id, checkFromStorage: false)).nonNulls.join(', ');

    return NamidaInkWell(
      onTap: () => onMixTap(artworkWidget(fullscreen: true)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              thumbnailWidget,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4.0),
                    Text(
                      widget.title,
                      style: textTheme.displayMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      videoNamesJoined,
                      style: textTheme.displaySmall?.copyWith(fontSize: 11.0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4.0),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

(String, int)? _enabledTrack;

class _TrackCard extends StatefulWidget {
  final HomePageItems homepageItem;
  final String title;
  final double width;
  final Track? track;
  final String listId;
  final Iterable<Selectable> queue;
  final int index;
  final Iterable<int>? listens;
  final String? topRightText;
  final QueueSource queueSource;

  const _TrackCard({
    required this.homepageItem,
    required this.title,
    required this.width,
    required this.track,
    required this.listId,
    required this.queue,
    required this.index,
    this.listens,
    this.topRightText,
    this.queueSource = QueueSource.homePageItem,
  });

  @override
  State<_TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends State<_TrackCard> with LoadingItemsDelayMixin {
  Color? _cardColor;

  void _extractColor(Track track) async {
    if (!mounted) return;
    if (!await canStartLoadingItems()) return;

    if (_cardColor == null) {
      CurrentColor.inst.getTrackColors(track, networkArtworkInfo: null, useIsolate: true).then((value) {
        if (mounted) setState(() => _cardColor = value.color);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final track = widget.track;
    if (track != null) {
      _cardColor = CurrentColor.inst.getTrackColorsSync(track, networkArtworkInfo: null)?.color;
      if (_cardColor == null) {
        Future.delayed(const Duration(milliseconds: 500)).then((_) => _extractColor(track));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final track = widget.track;
    final color = Color.alphaBlend((_cardColor ?? theme.scaffoldBackgroundColor).withAlpha(50), theme.cardColor);
    final dummyContainer = track == null;
    if (dummyContainer) {
      return NamidaInkWell(
        animationDurationMS: 200,
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        width: widget.width,
        bgColor: color,
      );
    }
    return NamidaInkWell(
      borderRadius: 10.0,
      onTap: () {
        if (mounted) setState(() => _enabledTrack = (widget.listId, widget.index));

        Player.inst.playOrPause(
          widget.index,
          widget.queue,
          widget.queueSource,
          homePageItem: widget.homepageItem,
        );
      },
      onLongPress: () => NamidaDialogs.inst.showTrackDialog(
        track,
        source: widget.queueSource,
        index: widget.index,
      ),
      decoration: BoxDecoration(
        border: _enabledTrack == (widget.listId, widget.index)
            ? Border.all(
                color: _cardColor ?? color,
                width: 1.5,
              )
            : null,
      ),
      width: widget.width,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      animationDurationMS: 400,
      child: Stack(
        children: [
          Positioned.fill(
            child: BorderRadiusClip(
              borderRadius: BorderRadius.circular(10.0.multipliedRadius),
              child: NamidaBlur(
                blur: 20.0,
                enabled: settings.enableBlurEffect.value,
                fixArtifacts: true,
                child: AnimatedDecoration(
                  duration: Duration(milliseconds: 400),
                  decoration: BoxDecoration(
                    color: color,
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ArtworkWidget(
                key: Key(track.path),
                track: track,
                blur: 3.0,
                forceSquared: true,
                path: track.pathToImage,
                thumbnailSize: widget.width,
                onTopWidgets: [
                  if (widget.topRightText != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(6.0.multipliedRadius),
                            topRight: Radius.circular(6.0.multipliedRadius),
                          ),
                          color: theme.scaffoldBackgroundColor,
                        ),
                        child: Text(
                          widget.topRightText!,
                          style: textTheme.displaySmall?.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (widget.listens != null)
                    Positioned(
                      bottom: 2.0,
                      right: 2.0,
                      child: CircleAvatar(
                        radius: 10.0,
                        backgroundColor: theme.cardColor,
                        child: FittedBox(
                          child: Text(
                            widget.listens!.length.formatDecimal(),
                            style: textTheme.displaySmall,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      track.title,
                      style: textTheme.displaySmall?.copyWith(fontSize: 12.0, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      track.originalArtist,
                      style: textTheme.displaySmall?.copyWith(fontSize: 11.0, fontWeight: FontWeight.w400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

class RecentlyAddedTracksPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.SUBPAGE_recentlyAddedTracks;

  final List<Selectable> tracksSorted;
  const RecentlyAddedTracksPage({super.key, required this.tracksSorted});

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return BackgroundWrapper(
      child: NamidaTracksList(
        infoBox: null,
        header: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Row(
            children: [
              Icon(
                Broken.back_square,
                color: context.defaultIconColor(),
                size: 32.0,
              ),
              const SizedBox(width: 12.0),
              Text(
                lang.recentlyAdded,
                style: textTheme.displayLarge?.copyWith(fontSize: 18.0),
              ),
            ],
          ),
        ),
        queueLength: tracksSorted.length,
        queueSource: QueueSource.recentlyAdded,
        queue: tracksSorted,
        thirdLineText: (track) {
          final creationDate = track.track.dateAdded;
          if (creationDate > _lowestDateMSSEToDisplay) {
            final ago = TimeAgoController.dateMSSEFromNow(creationDate, long: true);
            return "${creationDate.dateAndClockFormattedOriginal} (~$ago)";
          }
          return '';
        },
      ),
    );
  }
}
