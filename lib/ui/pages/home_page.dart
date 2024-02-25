// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';
import 'package:history_manager/history_manager.dart';
import 'package:jiffy/jiffy.dart';

import 'package:namida/base/loading_items_delay.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/generators_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

extension _ListUtilsHomePage<E> on List<E> {
  void addAllIfEmpty(Iterable<E> iterable) {
    if (isEmpty) addAll(iterable);
  }
}

extension _MapUtilsHomePage<K, V> on Map<K, V> {
  void addAllIfEmpty(Map<K, V> other) {
    if (isEmpty) addAll(other);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final _shimmerList = List.filled(20, null, growable: true);
  late bool _isLoading;

  final _recentlyAddedFull = <Track>[];
  final _recentlyAdded = <Track>[];
  final _randomTracks = <Track>[];
  final _recentListened = <TrackWithDate>[];
  final _topRecentListened = <MapEntry<Track, List<int>>>[];
  var _sameTimeYearAgo = <MapEntry<Track, List<int>>>[];

  final _recentAlbums = <String>[];
  final _recentArtists = <String>[];
  final _topRecentAlbums = <String, int>{};
  final _topRecentArtists = <String, int>{};

  final _mixes = <String, List<Track>>{};

  int currentYearLostMemories = 0;

  @override
  void initState() {
    _fillLists();
    super.initState();
  }

  @override
  void dispose() {
    _recentlyAddedFull.clear();
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
    super.dispose();
  }

  void _fillLists() async {
    if (HistoryController.inst.isHistoryLoaded) {
      _isLoading = false;
    } else {
      _isLoading = true;
      await HistoryController.inst.waitForHistoryAndMostPlayedLoad;
    }
    final timeNow = DateTime.now();

    // -- Recently Added --
    final alltracks = Indexer.inst.recentlyAddedTracks;

    _recentlyAddedFull.addAll(alltracks);
    _recentlyAdded.addAll(alltracks.take(40));

    // -- Recent Listens --
    _recentListened.addAllIfEmpty(NamidaGenerator.inst.generateItemsFromHistoryDates(DateTime(timeNow.year, timeNow.month, timeNow.day - 3), timeNow).take(40));

    // -- Top Recents --
    _topRecentListened.addAllIfEmpty(
      HistoryController.inst
          .getMostListensInTimeRange(
            mptr: MostPlayedTimeRange.day3,
            isStartOfDay: false,
          )
          .take(50),
    );

    // -- Lost Memories --
    final oldestYear = HistoryController.inst.oldestTrack?.dateAdded.milliSecondsSinceEpoch?.year;
    final minusYearClamped = (timeNow.year - 1).withMinimum(oldestYear ?? 0);
    _updateSameTimeNYearsAgo(timeNow, minusYearClamped);

    // -- Recent Albums --
    _recentAlbums.addAllIfEmpty(_recentListened.mappedUniqued((e) => e.track.albumIdentifier).take(25));

    // -- Recent Artists --
    _recentArtists.addAllIfEmpty(_recentListened.mappedUniquedList((e) => e.track.artistsList).take(25));

    _topRecentListened.loop((e, _) {
      // -- Top Recent Albums --
      _topRecentAlbums.update(e.key.albumIdentifier, (value) => value + 1, ifAbsent: () => 1);

      // -- Top Recent Artists --
      e.key.artistsList.loop((e, _) => _topRecentArtists.update(e, (value) => value + 1, ifAbsent: () => 1));
    });
    _topRecentAlbums.sortByReverse((e) => e.value);
    _topRecentArtists.sortByReverse((e) => e.value);

    // ==== Mixes ====
    // -- Random --
    _randomTracks.addAllIfEmpty(NamidaGenerator.inst.getRandomTracks(min: 24, max: 25));

    // -- favs --
    final favs = List<TrackWithDate>.from(PlaylistController.inst.favouritesPlaylist.value.tracks);
    favs.shuffle();

    // -- supermacy
    final ct = Player.inst.nowPlayingTrack;
    final maxCount = settings.queueInsertion[QueueInsertionType.algorithm]?.numberOfTracks ?? 25;
    final sameAsCurrent = NamidaGenerator.inst.generateRecommendedTrack(ct).take(maxCount);

    _mixes.addAllIfEmpty({
      lang.TOP_RECENTS: _topRecentListened.map((e) => e.key).toList(),
      if (sameAsCurrent.isNotEmpty) '"${ct.title}" ${lang.SUPREMACY}': [ct, ...sameAsCurrent],
      lang.FAVOURITES: favs.take(25).tracks.toList(),
      lang.RANDOM_PICKS: _randomTracks,
    });

    _isLoading = false;

    if (mounted) setState(() {});
  }

  void _updateSameTimeNYearsAgo(DateTime timeNow, int year) {
    _sameTimeYearAgo = HistoryController.inst.getMostListensInTimeRange(
      mptr: MostPlayedTimeRange.custom,
      customDate: DateRange(
        oldest: DateTime(year, timeNow.month, timeNow.day - 5),
        newest: DateTime(year, timeNow.month, timeNow.day + 5),
      ),
      isStartOfDay: false,
    );
    currentYearLostMemories = year;
  }

  List<E?> _listOrShimmer<E>(List<E> listy) {
    return _isLoading ? _shimmerList : listy;
  }

  void showReorderHomeItemsDialog() async {
    final subList = <HomePageItems>[].obs;
    HomePageItems.values.loop((e, index) {
      if (!settings.homePageItems.contains(e)) {
        subList.add(e);
      }
    });
    final mainListController = ScrollController();
    void jumpToLast() {
      mainListController.animateTo(
        mainListController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      jumpToLast();
    });

    await NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        subList.close();
        mainListController.dispose();
      },
      dialog: CustomBlurryDialog(
        title: "${lang.CONFIGURE} (${lang.REORDERABLE})",
        actions: [
          NamidaButton(
            text: lang.DONE,
            onPressed: NamidaNavigator.inst.closeDialog,
          ),
        ],
        child: SizedBox(
          width: Get.width,
          height: Get.height * 0.5,
          child: Obx(
            () => Column(
              children: [
                Expanded(
                  flex: 6,
                  child: ReorderableListView.builder(
                    scrollController: mainListController,
                    itemCount: settings.homePageItems.length,
                    proxyDecorator: (child, index, animation) => child,
                    itemBuilder: (context, index) {
                      final item = settings.homePageItems[index];
                      return Material(
                        key: ValueKey(index),
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

                      final item = settings.homePageItems.elementAt(oldIndex);
                      settings.removeFromList(homePageItem1: item);
                      settings.insertInList(newIndex, homePageItem1: item);
                    },
                  ),
                ),
                const NamidaContainerDivider(height: 4.0, margin: EdgeInsets.symmetric(vertical: 4.0)),
                if (subList.isNotEmpty)
                  Expanded(
                    flex: subList.length,
                    child: ListView.builder(
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToRecentlyListened() {
    if (_recentlyAddedFull.isNotEmpty) {
      NamidaNavigator.inst.navigateTo(
        RecentlyAddedTracksPage(tracksSorted: _recentlyAddedFull),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: NamidaScrollbar(
        child: ShimmerWrapper(
          shimmerDurationMS: 550,
          shimmerDelayMS: 250,
          shimmerEnabled: _isLoading,
          child: AnimationLimiter(
            child: StreamBuilder<List<HomePageItems>>(
              initialData: settings.homePageItems,
              stream: settings.homePageItems.stream,
              builder: (context, homePageItems) => CustomScrollView(
                slivers: [
                  const SliverPadding(padding: EdgeInsets.only(bottom: 12.0)),
                  SliverPadding(
                    padding: const EdgeInsets.all(24.0),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Text(
                            'Namida',
                            style: context.textTheme.displayLarge?.copyWith(fontSize: 32.0.multipliedFontScale),
                          ),
                          const Spacer(),
                          NamidaIconButton(
                            icon: Broken.setting_4,
                            onPressed: showReorderHomeItemsDialog,
                          )
                        ],
                      ),
                    ),
                  ),
                  ...homePageItems.data!.map(
                    (element) {
                      switch (element) {
                        case HomePageItems.mixes:
                          return SliverToBoxAdapter(
                            child: _HorizontalList(
                              title: lang.MIXES,
                              icon: Broken.scanning,
                              height: 186.0 + 12.0,
                              itemCount: _isLoading ? _shimmerList.length : _mixes.length,
                              itemExtent: 240.0,
                              itemBuilder: (context, index) {
                                final entry = _isLoading ? null : _mixes.entries.elementAt(index);
                                return _MixesCard(
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
                            homepageItem: element,
                            title: lang.RECENT_LISTENS,
                            icon: Broken.command_square,
                            listy: _recentListened,
                            onTap: NamidaOnTaps.inst.onHistoryPlaylistTap,
                            topRightText: (track) {
                              if (track?.trackWithDate == null) return null;
                              return Jiffy.parseFromMillisecondsSinceEpoch(track!.trackWithDate!.dateAdded).fromNow(
                                withPrefixAndSuffix: false,
                              );
                            },
                          );

                        case HomePageItems.topRecentListens:
                          return _TracksList(
                            homepageItem: element,
                            title: lang.TOP_RECENTS,
                            icon: Broken.crown_1,
                            listy: const [],
                            listWithListens: _topRecentListened,
                            onTap: NamidaOnTaps.inst.onMostPlayedPlaylistTap,
                          );

                        case HomePageItems.lostMemories:
                          return _TracksList(
                            homepageItem: element,
                            title: lang.LOST_MEMORIES,
                            subtitle: () {
                              final diff = DateTime.now().year - currentYearLostMemories;
                              return lang.LOST_MEMORIES_SUBTITLE.replaceFirst('_NUM_', '$diff');
                            }(),
                            icon: Broken.link_21,
                            listy: const [],
                            listWithListens: _sameTimeYearAgo,
                            onTap: NamidaOnTaps.inst.onMostPlayedPlaylistTap,
                            thirdWidget: SizedBox(
                              height: 32.0,
                              width: context.width,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    children: [
                                      ...() {
                                        final oldest = DateTime.fromMillisecondsSinceEpoch(HistoryController.inst.oldestTrack?.dateAdded ?? 0);
                                        final newest = DateTime.fromMillisecondsSinceEpoch(HistoryController.inst.newestTrack?.dateAdded ?? 0);

                                        final years = <int>[];
                                        final diff = (newest.year - oldest.year).abs();
                                        for (int i = 1; i <= diff; i++) {
                                          years.add(newest.year - i);
                                        }
                                        return years.map(
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
                                                  color: currentYearLostMemories == e ? CurrentColor.inst.currentColorScheme.withAlpha(160) : context.theme.cardColor,
                                                  borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                                  child: Text(
                                                    '$e',
                                                    style: context.textTheme.displaySmall?.copyWith(
                                                      color: currentYearLostMemories == e ? Colors.white.withAlpha(240) : null,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }()
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );

                        case HomePageItems.recentlyAdded:
                          return _TracksList(
                            queueSource: QueueSource.recentlyAdded,
                            homepageItem: element,
                            title: lang.RECENTLY_ADDED,
                            icon: Broken.back_square,
                            listy: _recentlyAdded,
                            onTap: _navigateToRecentlyListened,
                            topRightText: (track) {
                              if (track == null) return null;
                              return Jiffy.parseFromMillisecondsSinceEpoch(track.track.dateAdded).fromNow(
                                withPrefixAndSuffix: false,
                              );
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

                        default:
                          return const SliverPadding(padding: EdgeInsets.zero);
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
  });

  @override
  Widget build(BuildContext context) {
    final finalListWithListens = listWithListens;

    if (finalListWithListens != null) {
      final queue = listWithListens?.firstOrNull == null ? <Track>[] : listWithListens!.map((e) => e!.key);
      return SliverToBoxAdapter(
        child: _HorizontalList(
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
    final albumDimensions = Dimensions.inst.getAlbumCardDimensions(4);
    final itemCount = albums.length;
    return SliverToBoxAdapter(
      child: _HorizontalList(
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
            dummyCard: isLoading,
            homepageItem: homepageItem,
            displayIcon: !isLoading,
            compact: true,
            identifier: albumId ?? '',
            album: albumId?.getAlbumTracks() ?? [],
            staggered: false,
            dimensions: albumDimensions,
            topRightText: listens == null ? null : "${listens!(albumId)}",
            additionalHeroTag: "$title$index",
          );
        },
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
    final artistDimensions = Dimensions.inst.getArtistCardDimensions(5);
    final itemCount = artists.length;
    return SliverToBoxAdapter(
      child: _HorizontalList(
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
            dimensions: artistDimensions,
            bottomCenterText: isLoading || listens == null ? null : "${listens!(a)}",
            additionalHeroTag: "$title$index",
          );
        },
      ),
    );
  }
}

class _HorizontalList extends StatelessWidget {
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

  const _HorizontalList({
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        NamidaInkWell(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          onTap: onTap,
          child: Row(
            children: [
              const SizedBox(width: 16.0),
              leading ?? Icon(icon, color: iconColor ?? context.defaultIconColor()),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.textTheme.displayLarge),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: context.textTheme.displaySmall,
                      ),
                    if (thirdWidget != null) thirdWidget!,
                  ],
                ),
              ),
              if (onTap != null || trailing != null) ...[
                const SizedBox(width: 8.0),
                trailing ?? const Icon(Broken.arrow_right_3, size: 20.0),
                const SizedBox(width: 12.0),
              ]
            ],
          ),
        ),
        SizedBox(
          height: height,
          width: context.width,
          child: ListView.builder(
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
  Track? track;

  @override
  void initState() {
    super.initState();
    _assignTrack();
    Future.delayed(const Duration(milliseconds: 500)).then((value) => _extractColor());
  }

  void onMixTap(Widget thumbnailWidget) {
    NamidaNavigator.inst.navigateDialog(
      colorScheme: _cardColor,
      durationInMs: 250,
      dialogBuilder: (theme) => SafeArea(
        child: SizedBox(
          child: CustomScrollView(
            slivers: [
              const SliverPadding(padding: EdgeInsets.only(top: kToolbarHeight)),
              // Text(
              //   widget.title,
              //   style: context.textTheme.displayLarge,
              // ).toSliver(),
              // const SliverPadding(padding: EdgeInsets.only(top: 24.0)),
              SliverPadding(
                padding: const EdgeInsets.all(24.0),
                sliver: thumbnailWidget.toSliver(),
              ),

              // SliverToBoxAdapter(
              //   child: SizedBox(height: widget.height, width: widget.width, child: thumbnailWidget),
              // ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                sliver: SliverFillRemaining(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: context.theme.cardColor,
                      borderRadius: BorderRadius.circular(18.0.multipliedRadius),
                    ),
                    child: ListView.builder(
                      itemExtent: Dimensions.inst.trackTileItemExtent,
                      itemCount: widget.tracks.length,
                      itemBuilder: (context, index) {
                        final tr = widget.tracks[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: context.theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                          ),
                          child: TrackTile(
                            queueSource: QueueSource.homePageItem,
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
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _assignTrack() {
    track ??= widget.tracks.trackOfImage;
  }

  void _extractColor() {
    if (track != null && _cardColor == null) {
      CurrentColor.inst.getTrackColors(track!, useIsolate: true).then((value) {
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
      child: AnimatedSizedBox(
        duration: const Duration(milliseconds: 300),
        width: widget.width - horizontalPadding,
        height: double.infinity,
        decoration: BoxDecoration(
          color: _cardColor?.withAlpha(alpha),
          border: Border.all(color: context.theme.scaffoldBackgroundColor.withAlpha(alpha)),
          borderRadius: BorderRadius.circular(10.0.multipliedRadius),
        ),
        child: NamidaBgBlur(
          blur: blur,
          child: Container(
            color: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget artworkWidget(bool titleInside, bool displayShimmer) => NamidaHero(
        tag: 'mix_thumbnail_${widget.title}${widget.index}',
        child: ArtworkWidget(
          key: Key(track?.pathToImage ?? ''),
          track: track,
          compressed: false,
          blur: 1.5,
          borderRadius: titleInside ? 12.0 : 8.0,
          forceSquared: true,
          path: track?.pathToImage,
          displayIcon: !displayShimmer,
          thumbnailSize: widget.width,
          onTopWidgets: [
            if (titleInside) ...[
              Positioned(
                top: 12.0,
                left: 0.0,
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.theme.colorScheme.background.withAlpha(50),
                  ),
                  child: NamidaBgBlur(
                    blur: 2.0,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: NamidaIconButton(
                        icon: Broken.arrow_left_2,
                        iconColor: context.theme.colorScheme.onBackground.withAlpha(160),
                        onPressed: NamidaNavigator.inst.closeDialog,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: NamidaInkWell(
                  borderRadius: 8.0,
                  margin: const EdgeInsets.all(6.0),
                  padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 4.0),
                  bgColor: context.theme.cardColor.withAlpha(240),
                  child: Row(
                    children: [
                      const Icon(Broken.audio_square, size: 22.0),
                      const SizedBox(width: 6.0),
                      Text(
                        widget.title,
                        style: context.textTheme.displayLarge?.copyWith(fontSize: 15.0.multipliedFontScale),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (!displayShimmer)
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
                      Icon(Broken.play_cricle, size: titleInside ? 22.0 : 16.0),
                      const SizedBox(width: 4.0),
                      Text(
                        "${widget.tracks.length}",
                        style: (titleInside ? context.textTheme.displayLarge : context.textTheme.displaySmall)?.copyWith(fontSize: 15.0.multipliedFontScale),
                      ),
                    ],
                  ),
                ),
              )
          ],
        ),
      );
  @override
  Widget build(BuildContext context) {
    final displayShimmer = track == null;

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
          blur: 0.4,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6.0).add(const EdgeInsets.all(1.0)),
          child: artworkWidget(false, displayShimmer),
        ),
      ],
    );

    return NamidaInkWell(
      onTap: () => onMixTap(artworkWidget(true, displayShimmer)),
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
                      style: context.textTheme.displayMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.tracks.map((e) => e.title).join(', '),
                      style: context.textTheme.displaySmall?.copyWith(fontSize: 11.0.multipliedFontScale),
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
  final Color? color;
  final Track? track;
  final Iterable<Selectable> queue;
  final int index;
  final Iterable<int>? listens;
  final String? topRightText;
  final QueueSource queueSource;

  const _TrackCard({
    required this.homepageItem,
    required this.title,
    required this.width,
    this.color,
    required this.track,
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

  void _extractColor() async {
    if (!mounted) return;
    if (!await canStartLoadingItems()) return;

    if (widget.track != null && _cardColor == null) {
      CurrentColor.inst.getTrackColors(widget.track!, useIsolate: true).then((value) {
        if (mounted) setState(() => _cardColor = value.color);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500)).then((value) => _extractColor());
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final color = Color.alphaBlend((_cardColor ?? context.theme.scaffoldBackgroundColor).withAlpha(50), context.theme.cardColor);
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
      onTap: () {
        if (mounted) setState(() => _enabledTrack = (widget.title, widget.index));

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
      width: widget.width,
      bgColor: color,
      decoration: BoxDecoration(
        border: _enabledTrack == (widget.title, widget.index)
            ? Border.all(
                color: _cardColor ?? color,
                width: 1.5,
              )
            : null,
        borderRadius: BorderRadius.circular(10.0.multipliedRadius),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      animationDurationMS: 400,
      child: NamidaBgBlur(
        blur: 20.0,
        enabled: settings.enableBlurEffect.value,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ArtworkWidget(
              key: Key(track.path),
              track: track,
              blur: 0.0,
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
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6.0.multipliedRadius)),
                        color: context.theme.scaffoldBackgroundColor,
                      ),
                      child: Text(
                        widget.topRightText!,
                        style: context.textTheme.displaySmall?.copyWith(
                          fontSize: 10.5.multipliedFontScale,
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
                        backgroundColor: context.theme.cardColor,
                        child: FittedBox(
                          child: Text(
                            widget.listens!.length.formatDecimal(),
                            style: context.textTheme.displaySmall,
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
                    style: context.textTheme.displaySmall?.copyWith(fontSize: 12.0.multipliedFontScale, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track.originalArtist,
                    style: context.textTheme.displaySmall?.copyWith(fontSize: 11.0.multipliedFontScale, fontWeight: FontWeight.w400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class RecentlyAddedTracksPage extends StatelessWidget {
  final List<Selectable> tracksSorted;
  const RecentlyAddedTracksPage({super.key, required this.tracksSorted});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: NamidaTracksList(
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
                style: context.textTheme.displayLarge?.copyWith(fontSize: 18.0.multipliedFontScale),
              )
            ],
          ),
        ),
        queueLength: tracksSorted.length,
        isTrackSelectable: true,
        queueSource: QueueSource.recentlyAdded,
        queue: tracksSorted,
        thirdLineText: (track) {
          final dateMS = track.track.dateAdded;
          final ago = Jiffy.parseFromMillisecondsSinceEpoch(dateMS).fromNow(withPrefixAndSuffix: true);
          return "${dateMS.dateAndClockFormattedOriginal} (~$ago)";
        },
      ),
    );
  }
}
