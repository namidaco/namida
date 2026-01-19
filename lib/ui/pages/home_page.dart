// ignore_for_file: unused_element, unused_element_parameter

import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:history_manager/history_manager.dart';
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/base/loading_items_delay.dart';
import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/generators_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
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
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/stats.dart';

final int _lowestDateMSSEToDisplay = DateTime(1980).millisecondsSinceEpoch + 1;

class HomePage extends StatefulWidget with NamidaRouteWidget {
  final HistoryManager<TrackWithDate, Track> historyManager;
  final PlaylistManager<TrackWithDate, Track, SortType> playlistManager;
  final NamidaGenerator generator;

  @override
  RouteType get route => RouteType.PAGE_Home;

  HomePage.tracks({super.key})
      : historyManager = HistoryController.inst,
        playlistManager = PlaylistController.inst,
        generator = NamidaGenerator.inst;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, PullToRefreshMixin {
  final _shimmerList = List.filled(20, null, growable: true);
  late bool _isLoading;

  List<Track>? _recentlyAddedFull;
  final _recentlyAdded = <Track>[];
  final _randomTracks = <Track>[];
  final _recentListened = <TrackWithDate>[];
  final _topRecentListened = <MapEntry<Track, List<int>>>[];
  var _sameTimeYearAgo = <MapEntry<Track, List<int>>>[];

  final _recentAlbums = <String>[];
  final _recentArtists = <String>[];
  final _topRecentAlbums = <String, int>{};
  final _topRecentArtists = <String, int>{};

  final _mixes = <MapEntry<String, List<Track>>>[];

  var _lostMemoriesYears = <int>[];

  int currentYearLostMemories = 0;
  DateRange? currentYearLostMemoriesDateRange;
  late final ScrollController _scrollController;
  late final ScrollController _lostMemoriesScrollController;

  final MostPlayedTimeRange _topRecentsTimeRange = MostPlayedTimeRange.day3;

  @override
  void initState() {
    super.initState();
    _scrollController = NamidaScrollController.create();
    _lostMemoriesScrollController = NamidaScrollController.create();
    _fillLists();
  }

  @override
  void dispose() {
    _emptyAll();
    _scrollController.dispose();
    _lostMemoriesScrollController.dispose();
    super.dispose();
  }

  void _emptyAll() {
    _recentlyAddedFull?.clear();
    _recentlyAdded.clear();
    _randomTracks.clear();
    _recentListened.clear();
    _topRecentListened.clear();
    _sameTimeYearAgo.clear();
    _recentAlbums.clear();
    _recentArtists.clear();
    _topRecentAlbums.clear();
    _topRecentArtists.clear();
    _mixes.clear();
  }

  void _fillLists() async {
    if (widget.historyManager.isHistoryLoaded) {
      _isLoading = false;
    } else {
      _isLoading = true;
      await widget.historyManager.waitForHistoryAndMostPlayedLoad;
    }

    final timeNow = DateTime.now();

    // -- Recently Added --
    final alltracks = Indexer.inst.recentlyAddedTracksSorted();

    _recentlyAddedFull = alltracks;
    _recentlyAdded.addAll(alltracks.take(40));

    // -- Recent Listens --
    if (_recentListened.isEmpty) {
      _recentListened
          .addAll(widget.generator.generateItemsFromHistoryDates(DateTime(timeNow.year, timeNow.month, timeNow.day - 3), timeNow, sortByListensInRangeIfRequired: false).take(40));
    }

    // -- Top Recents --
    if (_topRecentListened.isEmpty) {
      final sortedMap = widget.historyManager.getMostListensInTimeRange(
        mptr: _topRecentsTimeRange,
        isStartOfDay: false,
        mainItemToSubItem: widget.historyManager.mainItemToSubItem,
      );
      _topRecentListened.addAll(sortedMap.entriesSortedByValue);
    }

    // -- Lost Memories --
    _lostMemoriesYears = widget.historyManager.getHistoryYears()..remove(timeNow.year);
    final oldestYear = _lostMemoriesYears.lastOrNull ?? 0;

    final minusYearClamped = (timeNow.year - 1).withMinimum(oldestYear);

    _updateSameTimeNYearsAgo(timeNow, minusYearClamped);

    // -- Recent Albums --
    if (_recentAlbums.isEmpty) _recentAlbums.addAll(_recentListened.mappedUniqued((e) => e.track.albumIdentifier).take(25));

    // -- Recent Artists --
    if (_recentArtists.isEmpty) _recentArtists.addAll(_recentListened.mappedUniquedList((e) => e.track.artistsList).take(25));

    _topRecentListened.loop((e) {
      // -- Top Recent Albums --
      _topRecentAlbums.update(e.key.albumIdentifier, (value) => value + 1, ifAbsent: () => 1);

      // -- Top Recent Artists --
      e.key.artistsList.loop((e) => _topRecentArtists.update(e, (value) => value + 1, ifAbsent: () => 1));
    });

    _topRecentAlbums.sortByReverse((e) => e.value);
    _topRecentArtists.sortByReverse((e) => e.value);

    // ==== Mixes ====
    // -- Random --
    if (_randomTracks.isEmpty) _randomTracks.addAll(widget.generator.getRandomTracks(min: 25, max: 26));

    final int mostRecentAddedMSSE = DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch;
    final int mostRecentListenedMSSE = DateTime.now().subtract(Duration(days: 2)).millisecondsSinceEpoch;
    final underrated = allTracksInLibrary.getRandomSampleWhere(100, (tr) {
      if (widget.playlistManager.favouritesPlaylist.isSubItemFavourite(tr)) return false; // alr favourited
      final listensCount = widget.historyManager.topTracksMapListens.value[tr]?.length;
      if (listensCount != null && listensCount > 8) return false; // alr listened enough
      if (tr.dateAdded > mostRecentAddedMSSE) return false; // its very recently added
      final lastListen = widget.historyManager.topTracksMapListens.value[tr]?.lastOrNull;
      if (lastListen != null && lastListen > mostRecentListenedMSSE) return false; // recently listened
      return true;
    });

    if (_mixes.isEmpty) {
      // -- supermacy
      final ct = Player.inst.currentTrack?.track;
      final maxCount = settings.queueInsertion.value[QueueInsertionType.algorithm]?.numberOfTracks.withMinimum(10) ?? 25;
      MapEntry<String, List<Track>>? supremacyEntry;
      if (ct != null) {
        final sameAsCurrent = widget.generator.generateRecommendedTrack(ct).take(maxCount);
        if (sameAsCurrent.isNotEmpty) {
          final supremacy = [ct, ...sameAsCurrent];
          supremacyEntry = MapEntry('"${ct.title}" ${lang.SUPREMACY}', supremacy);
        }
      }
      final favsSample = widget.playlistManager.favouritesPlaylist.value.tracks.getRandomSample(25).tracks.toList();
      final topRecentListenedKeys = _topRecentListened.map((e) => e.key).toList();

      final recentTopSortedByTotalListens = List.from(topRecentListenedKeys)..sortByReverse((e) => widget.historyManager.topTracksMapListens.value[e.track]?.length ?? 0);
      final recent30Tracks = widget.historyManager.historyTracks.take(30).map(widget.historyManager.mainItemToSubItem).toList();

      final topRecentListenedExpanded = widget.historyManager.getMostListensInTimeRange(
        mptr: MostPlayedTimeRange.custom,
        customDate: DateRange(
          oldest: timeNow.subtract(Duration(days: 14)),
          newest: timeNow,
        ),
        isStartOfDay: false,
        mainItemToSubItem: widget.historyManager.mainItemToSubItem,
      );
      recent30Tracks.sortByReverse((tr) => topRecentListenedExpanded[tr]?.length ?? 0);

      final sameTimeAyearAgo = widget.historyManager
          .getMostListensInTimeRange(
            mptr: MostPlayedTimeRange.custom,
            customDate: DateRange(
              oldest: DateTime(timeNow.year - 1, timeNow.month, timeNow.day - 9),
              newest: DateTime(timeNow.year - 1, timeNow.month, timeNow.day + 9),
            ),
            isStartOfDay: false,
            mainItemToSubItem: widget.historyManager.mainItemToSubItem,
          )
          .keysSortedByValue
          .take(40);

      final recommendedMixTracks = <Track>{
        // -- top recents, sorted by total listens
        ...recentTopSortedByTotalListens,

        // -- top recents, but only from favourites
        ...topRecentListenedKeys.where((element) => element.isFavourite),

        // -- recents, sorted by listens count in a wider recent date range
        ...recent30Tracks,

        // -- top tracks in the same time, a year ago
        ...sameTimeAyearAgo,
      }.toList();
      recommendedMixTracks.shuffle();

      _mixes.addAll([
        MapEntry(lang.NEW_TRACKS_RECOMMENDED, recommendedMixTracks),
        MapEntry(lang.TOP_RECENTS, topRecentListenedKeys),
        if (supremacyEntry != null) supremacyEntry,
        MapEntry(lang.FAVOURITES, favsSample),
        MapEntry(lang.UNDERRATED, underrated),
        MapEntry(lang.RANDOM_PICKS, _randomTracks),
      ]);

      // -- if any one is empty, remove it and add it to the end
      List<MapEntry<String, List<Track>>>? emptyOnes;
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
    final sortedMap = widget.historyManager.getMostListensInTimeRange(
      mptr: MostPlayedTimeRange.custom,
      customDate: dateRange,
      isStartOfDay: false,
      mainItemToSubItem: widget.historyManager.mainItemToSubItem,
    );
    _sameTimeYearAgo = sortedMap.entriesSortedByValue.toList();
    if (_lostMemoriesScrollController.hasClients) _lostMemoriesScrollController.jumpTo(0);
  }

  void _onGoingToMostPlayedPage({
    required MostPlayedTimeRange mptr,
    DateRange? dateCustom,
  }) {
    settings.save(
      mostPlayedTimeRange: mptr,
      mostPlayedCustomDateRange: dateCustom,
    );
    widget.historyManager.updateTempMostPlayedPlaylist(
      mptr: mptr,
      customDateRange: dateCustom,
    );
    NamidaOnTaps.inst.onMostPlayedPlaylistTap();
  }

  List<E?> _listOrShimmer<E>(List<E> listy) {
    return _isLoading ? _shimmerList : listy;
  }

  void showReorderHomeItemsDialog() async {
    final subList = <HomePageItems>[].obs;
    HomePageItems.values.loop((e) {
      if (!settings.homePageItems.contains(e)) {
        subList.add(e);
      }
    });
    final mainListController = NamidaScrollController.create();
    void jumpToLast() {
      mainListController.animateTo(
        mainListController.positions.first.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      jumpToLast();
    });

    await NamidaNavigator.inst.navigateDialog(
      scale: 1.0,
      onDisposing: () {
        subList.close();
        mainListController.dispose();
      },
      dialog: CustomBlurryDialog(
        title: "${lang.CONFIGURE} (${lang.REORDERABLE})",
        actions: const [
          DoneButton(),
        ],
        child: SizedBox(
          width: namida.width,
          height: namida.height * 0.5,
          child: Column(
            children: [
              Expanded(
                flex: 6,
                child: Builder(builder: (context) {
                  return ObxO(
                    rx: settings.homePageItems,
                    builder: (context, homePageItems) => NamidaListView(
                      itemExtent: null,
                      scrollController: mainListController,
                      itemCount: homePageItems.length,
                      itemBuilder: (context, index) {
                        final item = homePageItems[index];
                        return Material(
                          key: ValueKey(item),
                          type: MaterialType.transparency,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: ListTileWithCheckMark(
                              active: true,
                              icon: Broken.recovery_convert,
                              title: item.toText(),
                              onTap: () {
                                if (settings.homePageItems.length <= 3) {
                                  showMinimumItemsSnack(3);
                                  return;
                                }
                                subList.add(item);
                                settings.removeFromList(homePageItem1: item);
                              },
                            ),
                          ),
                        );
                      },
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = settings.homePageItems.value.elementAt(oldIndex);
                        settings.removeFromList(homePageItem1: item);
                        settings.insertInList(newIndex, homePageItem1: item);
                      },
                    ),
                  );
                }),
              ),
              const NamidaContainerDivider(height: 4.0, margin: EdgeInsets.symmetric(vertical: 4.0)),
              if (subList.isNotEmpty)
                ObxO(
                  rx: subList,
                  builder: (context, subList) => subList.isEmpty
                      ? const SizedBox()
                      : Expanded(
                          flex: subList.length,
                          child: SuperSmoothListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: subList.length,
                            itemBuilder: (context, index) {
                              final item = subList[index];
                              return Material(
                                type: MaterialType.transparency,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: ListTileWithCheckMark(
                                    active: false,
                                    icon: Broken.recovery_convert,
                                    title: item.toText(),
                                    onTap: () {
                                      settings.save(homePageItems: [item]);
                                      subList.remove(item);
                                      jumpToLast();
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToRecentlyListened() {
    final recentlyAdded = _recentlyAddedFull;
    if (recentlyAdded != null && recentlyAdded.isNotEmpty) {
      RecentlyAddedTracksPage(tracksSorted: recentlyAdded).navigate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
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
                    rx: settings.homePageItems,
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
                                NamidaIconButton(
                                  icon: Broken.chart_21,
                                  onPressed: StatsPage().navigate,
                                ),
                                NamidaIconButton(
                                  icon: Broken.setting_4,
                                  onPressed: showReorderHomeItemsDialog,
                                )
                              ],
                            ),
                          ),
                        ),
                        ...homePageItems.map(
                          (element) {
                            switch (element) {
                              case HomePageItems.mixes:
                                return SliverToBoxAdapter(
                                  child: _HorizontalList(
                                    homepageItem: element,
                                    isLoading: _isLoading,
                                    title: lang.MIXES,
                                    icon: Broken.scanning,
                                    height: 186.0 + 12.0,
                                    itemCount: _isLoading ? _shimmerList.length : _mixes.length,
                                    itemExtent: 240.0,
                                    itemBuilder: (context, index) {
                                      final entry = _isLoading ? null : _mixes[index];
                                      return _MixesCard(
                                        key: entry == null ? const Key("") : Key("${entry.key}_${entry.value.firstOrNull}"),
                                        title: entry?.key ?? '',
                                        width: 240.0,
                                        height: 186.0 + 12.0,
                                        index: index,
                                        dummyContainer: _isLoading,
                                        tracks: entry?.value ?? [],
                                      );
                                    },
                                  ),
                                );

                              case HomePageItems.recentListens:
                                return _TracksList(
                                  listId: 'recentListens',
                                  homepageItem: element,
                                  isLoading: _isLoading,
                                  title: lang.RECENT_LISTENS,
                                  icon: Broken.command_square,
                                  listy: _recentListened,
                                  onTap: NamidaOnTaps.inst.onHistoryPlaylistTap,
                                  topRightText: (track) {
                                    if (track?.trackWithDate == null) return null;
                                    return TimeAgoController.dateMSSEFromNow(track!.trackWithDate!.dateAdded, long: false);
                                  },
                                );

                              case HomePageItems.topRecentListens:
                                return _TracksList(
                                  listId: 'topRecentListens',
                                  homepageItem: element,
                                  isLoading: _isLoading,
                                  title: lang.TOP_RECENTS,
                                  icon: Broken.crown_1,
                                  listy: const [],
                                  listWithListens: _topRecentListened,
                                  onTap: () {
                                    _onGoingToMostPlayedPage(
                                      mptr: _topRecentsTimeRange,
                                    );
                                  },
                                );

                              case HomePageItems.lostMemories:
                                return _TracksList(
                                  listId: 'lostMemories_$currentYearLostMemories',
                                  controller: _lostMemoriesScrollController,
                                  homepageItem: element,
                                  isLoading: _isLoading,
                                  title: lang.LOST_MEMORIES,
                                  subtitle: () {
                                    final diff = DateTime.now().year - currentYearLostMemories;
                                    return lang.LOST_MEMORIES_SUBTITLE.replaceFirst('_NUM_', '$diff');
                                  }(),
                                  icon: Broken.link_21,
                                  listy: const [],
                                  listWithListens: _sameTimeYearAgo,
                                  onTap: () {
                                    _onGoingToMostPlayedPage(
                                      mptr: MostPlayedTimeRange.custom,
                                      dateCustom: currentYearLostMemoriesDateRange,
                                    );
                                  },
                                  thirdWidget: SizedBox(
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
                                              .toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                );

                              case HomePageItems.recentlyAdded:
                                return _TracksList(
                                  listId: 'recentlyAdded',
                                  queueSource: QueueSource.recentlyAdded,
                                  isLoading: _isLoading,
                                  homepageItem: element,
                                  title: lang.RECENTLY_ADDED,
                                  icon: Broken.back_square,
                                  listy: _recentlyAdded,
                                  onTap: _navigateToRecentlyListened,
                                  topRightText: (track) {
                                    if (track == null) return null;
                                    final creationDate = track.track.dateAdded;
                                    if (creationDate > _lowestDateMSSEToDisplay) return TimeAgoController.dateMSSEFromNow(creationDate, long: false);
                                    return null;
                                  },
                                );

                              case HomePageItems.recentAlbums:
                                return _AlbumsList(
                                  isLoading: _isLoading,
                                  homepageItem: element,
                                  title: lang.RECENT_ALBUMS,
                                  mainIcon: Broken.undo,
                                  albums: _listOrShimmer(_recentAlbums),
                                  listens: null,
                                );

                              case HomePageItems.topRecentAlbums:
                                final keys = _topRecentAlbums.keys.toList();
                                return _AlbumsList(
                                  isLoading: _isLoading,
                                  homepageItem: element,
                                  title: lang.TOP_RECENT_ALBUMS,
                                  mainIcon: Broken.crown_1,
                                  albums: _listOrShimmer(keys),
                                  listens: (album) => _topRecentAlbums[album] ?? 0,
                                );

                              case HomePageItems.recentArtists:
                                return _ArtistsList(
                                  isLoading: _isLoading,
                                  homepageItem: element,
                                  title: lang.RECENT_ARTISTS,
                                  mainIcon: Broken.undo,
                                  artists: _listOrShimmer(_recentArtists),
                                  listens: null,
                                );

                              case HomePageItems.topRecentArtists:
                                final keys = _topRecentArtists.keys.toList();
                                return _ArtistsList(
                                  isLoading: _isLoading,
                                  homepageItem: element,
                                  title: lang.TOP_RECENT_ARTISTS,
                                  mainIcon: Broken.crown_1,
                                  artists: _listOrShimmer(keys),
                                  listens: (artist) => _topRecentArtists[artist] ?? 0,
                                );
                            }
                          },
                        ).addSeparators(
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
      final queue = listWithListens?.firstOrNull == null ? <Track>[] : listWithListens!.map((e) => e!.key);
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
            }),
      );
    }
  }
}

class _AlbumsList extends StatelessWidget {
  final bool isLoading;
  final String title;
  final IconData mainIcon;
  final List<String?> albums;
  final int Function(String? album)? listens;
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
          itemExtent: 98.0,
          itemBuilder: (context, index) {
            final albumId = albums[index];
            return AlbumCard(
              key: ValueKey(albumId),
              dummyCard: isLoading,
              homepageItem: homepageItem,
              displayIcon: !isLoading,
              compact: true,
              identifier: albumId ?? '',
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
                    if (thirdWidget != null) thirdWidget!,
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
              ]
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
                      bgColor: theme.cardColor.withValues(alpha: 0.5),
                      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Text(
                        switch (homepageItem) {
                          HomePageItems.mixes => '',
                          HomePageItems.recentListens || HomePageItems.topRecentListens => lang.NO_TRACKS_IN_HISTORY,
                          HomePageItems.lostMemories => lang.NO_TRACKS_FOUND_BETWEEN_DATES,
                          HomePageItems.recentlyAdded => lang.NO_TRACKS_FOUND,
                          HomePageItems.recentAlbums || HomePageItems.recentArtists => "${lang.NONE}: ${lang.NO_TRACKS_IN_HISTORY}",
                          HomePageItems.topRecentAlbums || HomePageItems.topRecentArtists => "${lang.NONE}: ${lang.NO_TRACKS_IN_HISTORY}",
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
                    bgColor: Color.alphaBlend(_cardColor?.withValues(alpha: 0.4) ?? Colors.transparent, Color.fromRGBO(80, 80, 80, 0.4)).withValues(alpha: 0.9),
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
                          bgColor: contentColor.withValues(alpha: 0.6),
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
                                onTap: () {
                                  Player.inst.playOrPause(
                                    index,
                                    widget.tracks,
                                    QueueSource.homePageItem,
                                    homePageItem: HomePageItems.mixes,
                                  );
                                },
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
            )
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
              )
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
                        ))
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
                lang.RECENTLY_ADDED,
                style: textTheme.displayLarge?.copyWith(fontSize: 18.0),
              )
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
