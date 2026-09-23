import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/clipboard_controller.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/create_smart_playlist_dialog.dart';
import 'package:namida/ui/pages/main_page.dart';
import 'package:namida/ui/pages/subpages/moods_tags_tracks_subpage.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/multi_artwork_card.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';
import 'package:namida/youtube/pages/yt_search_results_page.dart';

class SearchPage extends StatefulWidget {
  SearchPage.main() : super(key: _globalKey);

  static final _globalKey = GlobalKey<_SearchPageState>();

  static void setSmartSearchPlaylistWrapper({SmartPlaylistWrapper? initialSmartSearchPlaylistWrapper}) {
    // -- give chance for `NamidaTabView.onIndexChanged` to call `SearchSortController.inst.searchAll()`
    Timer(
      const Duration(milliseconds: 50),
      () {
        _globalKey.currentState?._onSmartSearchTap(
          initialSmartSearchPlaylistWrapper: initialSmartSearchPlaylistWrapper,
        );
      },
    );
  }

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static SmartPlaylistWrapper? _smartSearchPlaylistWrapper;
  final _isTracksFromSmartSearch = false.obs;

  final _sectionKeys = <MediaType, GlobalKey>{for (final type in MediaType.values) type: GlobalKey()};

  @override
  void initState() {
    SearchSortController.inst.trackSearchTemp.addListener(_onTrackSearchTempChanged);
    super.initState();
  }

  void _onTrackSearchTempChanged() {
    _isTracksFromSmartSearch.value = false;
  }

  void _onSmartSearchTap({SmartPlaylistWrapper? initialSmartSearchPlaylistWrapper}) async {
    final smartPlaylistWrapper =
        initialSmartSearchPlaylistWrapper ??
        await CreateSmartPlaylistDialog.getTempPlaylist(
          initialSmartPlaylistWrapper: _smartSearchPlaylistWrapper,
        );

    if (mounted) {
      if (smartPlaylistWrapper != null && smartPlaylistWrapper.value.ruleGroups.isValid()) {
        _smartSearchPlaylistWrapper = smartPlaylistWrapper;
        final tracks = smartPlaylistWrapper.value.resolve();
        SearchSortController.inst.setTracksSearchTemp(tracks);
        _isTracksFromSmartSearch.value = true;
      } else {
        if (initialSmartSearchPlaylistWrapper == null) {
          // -- only if not coming from subpage
          _searchTracksByText();
        }
      }
    }
  }

  void _onSmartSearchButtonTap() {
    if (_isTracksFromSmartSearch.value) {
      _searchTracksByText();
    } else {
      _onSmartSearchTap();
    }
  }

  void _searchTracksByText() {
    SearchSortController.inst.searchTracks(ScrollSearchController.inst.searchTextEditingController.text, temp: true);
  }

  void _jumpToSection(MediaType type) {
    final sectionContext = _sectionKeys[type]?.currentContext;
    final renderObject = sectionContext?.findRenderObject();
    if (sectionContext == null || renderObject == null) return;
    Scrollable.of(sectionContext).position.ensureVisible(
      renderObject,
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastLinearToSlowEaseIn,
    );
  }

  @override
  void dispose() {
    SearchSortController.inst.trackSearchTemp.removeListener(_onTrackSearchTempChanged);
    _isTracksFromSmartSearch.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var initialSearchType = settings.extra.preferredSearchType.value;
    if (initialSearchType == null || initialSearchType == .auto) {
      initialSearchType = ScrollSearchController.inst.currentSearchType.value;
    }
    return BackgroundWrapper(
      child: NamidaTabView(
        key: ScrollSearchController.inst.tabViewKey,
        initialIndex: initialSearchType.index,
        onIndexChanged: (index) async {
          final type = SearchType.values[index];
          switch (type) {
            case SearchType.localTracks || SearchType.auto:
              ScrollSearchController.inst.currentSearchType.value = SearchType.localTracks;
              final srchTxt = ScrollSearchController.inst.searchTextEditingController.text;
              ClipboardController.inst.updateTextInControllerEmpty(srchTxt == '');
              await SearchSortController.inst.prepareResources();
              SearchSortController.inst.searchAll(srchTxt);
              break;
            case SearchType.youtube:
              ScrollSearchController.inst.currentSearchType.value = SearchType.youtube;
              final searchValue = ScrollSearchController.inst.ytSearchKey.currentState?.currentSearchText;
              if (SearchSortController.inst.lastSearchText != searchValue) {
                ScrollSearchController.inst.latestSubmittedYTSearch.value = SearchSortController.inst.lastSearchText;
                ScrollSearchController.inst.ytSearchKey.currentState?.fetchSearch(customText: SearchSortController.inst.lastSearchText);
              }
              break;
          }
        },
        tabs: [
          lang.local,
          lang.youtube,
        ],
        children: [
          Column(
            children: [
              _SearchFiltersHeader(
                isTracksFromSmartSearch: _isTracksFromSmartSearch,
                onJump: _jumpToSection,
                onSmartSearchTap: _onSmartSearchButtonTap,
                onSmartSearchLongPress: _onSmartSearchTap,
              ),
              Expanded(
                child: Stack(
                  children: [
                    // -- always mounted, the switcher would otherwise duplicate its global keys while fading
                    _SearchResultsView(
                      sectionKeys: _sectionKeys,
                      isTracksFromSmartSearch: _isTracksFromSmartSearch,
                    ),
                    Positioned.fill(
                      child: Obx(
                        (context) {
                          final Widget? child;
                          if (SearchSortController.inst.isSearching) {
                            child = null;
                          } else if (SearchSortController.inst.lastSearchTextRx.valueR == '') {
                            child = const _SearchOverlay(
                              key: Key('emptysearch'),
                              child: _RecentSearchesView(),
                            );
                          } else {
                            child = const _SearchOverlay(
                              key: Key('noresults'),
                              child: _NoResultsView(),
                            );
                          }
                          return CustomAnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: child,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          YoutubeSearchResultsPage(
            key: ScrollSearchController.inst.ytSearchKey,
            searchTextCallback: null,
          ),
        ],
      ),
    );
  }
}

class _SearchFiltersHeader extends StatelessWidget {
  final RxBaseCore<bool> isTracksFromSmartSearch;
  final void Function(MediaType type) onJump;
  final VoidCallback onSmartSearchTap;
  final VoidCallback onSmartSearchLongPress;

  const _SearchFiltersHeader({
    required this.isTracksFromSmartSearch,
    required this.onJump,
    required this.onSmartSearchTap,
    required this.onSmartSearchLongPress,
  });

  // -- same order as the results sections
  static const _chipsTypes = <MediaType>[
    .album,
    .artist,
    .albumArtist,
    .composer,
    .genre,
    .style,
    .playlist,
    .folderMusic,
    .folderVideo,
    .mood,
    .tag,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final secondaryColor = theme.colorScheme.secondary;
    return Row(
      children: [
        Expanded(
          child: NamidaEndEdgeFeather(
            child: SmoothSingleChildScrollView(
              padding: const EdgeInsetsDirectional.only(start: 4.0, end: 16.0),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TrackTypesChip(
                    onJump: onJump,
                  ),
                  for (final type in _chipsTypes)
                    _FilterChip(
                      type: type,
                      onJump: onJump,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4.0),
        ObxO(
          rx: isTracksFromSmartSearch,
          builder: (context, isFromSmartSearch) => NamidaInkWell(
            animationDurationMS: 200,
            borderRadius: 8.0,
            bgColor: secondaryColor.withOpacityExt(isFromSmartSearch ? 0.3 : 0.08),
            decoration: BoxDecoration(
              border: Border.all(
                color: secondaryColor.withOpacityExt(isFromSmartSearch ? 0.8 : 0.4),
                width: isFromSmartSearch ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            onTap: onSmartSearchTap,
            onLongPress: onSmartSearchLongPress,
            child: Icon(
              isFromSmartSearch ? Broken.magicpen : Broken.filter_search,
              size: 20.0,
            ),
          ),
        ),
        const SizedBox(width: 4.0),
      ],
    );
  }
}

const _kFilterChipMargin = EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0);
const _kFilterChipPadding = EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0);
const _kFilterChipBorderWidth = 1.5;

extension _FilterChipColors on Color {
  Color filterChipBg(bool isActive) => withOpacityExt(isActive ? 0.18 : 0.0);
  Color filterChipBorder(bool isActive) => withOpacityExt(isActive ? 0.7 : 0.3);
  Color filterChipText(bool isActive) => withOpacityExt(isActive ? 0.9 : 0.6);
}

class _FilterChip extends StatelessWidget {
  final MediaType type;
  final void Function(MediaType type) onJump;

  const _FilterChip({
    required this.type,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final secondaryColor = theme.colorScheme.secondary;
    final textStyle = theme.textTheme.displayMedium;
    final resultsRx = SearchSortController.inst.getTempResultsRx(type);
    return Obx(
      (context) {
        final isActive = settings.activeSearchMediaTypes.valueR.contains(type);
        final style = textStyle?.copyWith(color: secondaryColor.filterChipText(isActive));
        return NamidaInkWell(
          animationDurationMS: 200,
          bgColor: secondaryColor.filterChipBg(isActive),
          borderRadius: 8.0,
          onTap: () => SearchSortController.inst.toggleSearchMediaType(type),
          onLongPress: () => onJump(type),
          margin: _kFilterChipMargin,
          padding: _kFilterChipPadding,
          decoration: BoxDecoration(
            border: Border.all(
              color: secondaryColor.filterChipBorder(isActive),
              width: _kFilterChipBorderWidth,
            ),
          ),
          child: Row(
            children: [
              Text(
                type.toText(),
                style: style,
              ),
              _FilterChipCount(
                rx: resultsRx,
                style: style,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrackTypesChip extends StatelessWidget {
  final void Function(MediaType type) onJump;

  const _TrackTypesChip({
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final secondaryColor = theme.colorScheme.secondary;
    final radius = Radius.circular(8.0.multipliedRadius);
    return Obx(
      (context) {
        final activeTypes = settings.activeTrSearch.valueR;
        final tracksActive = activeTypes[TrackTypeSearch.tr] ?? true;
        final videosActive = activeTypes[TrackTypeSearch.v] ?? true;
        final bothActive = tracksActive && videosActive;
        final divider = NamidaContainerDivider(
          width: _kFilterChipBorderWidth,
          height: double.infinity,
          colorForce: secondaryColor.filterChipBorder(false),
        );
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: _kFilterChipMargin,
          decoration: BoxDecoration(
            color: secondaryColor.filterChipBg(bothActive),
            borderRadius: BorderRadius.all(radius),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.all(radius),
            border: Border.all(
              color: secondaryColor.filterChipBorder(true),
              width: _kFilterChipBorderWidth,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TrackTypeSegment(
                  title: lang.tracks,
                  isActive: tracksActive,
                  isFilled: tracksActive && !bothActive,
                  showCount: tracksActive && !bothActive,
                  padding: bothActive ? const EdgeInsetsDirectional.only(start: 12.0, end: 8.0, top: 6.0, bottom: 6.0) : _kFilterChipPadding,
                  borderRadius: BorderRadiusDirectional.horizontal(start: radius),
                  onTap: () => SearchSortController.inst.toggleSearchTrackType(TrackTypeSearch.tr),
                  onLongPress: () => onJump(MediaType.track),
                ),
                if (bothActive)
                  _FilterChipCount(
                    rx: SearchSortController.inst.trackSearchTemp,
                    style: theme.textTheme.displayMedium?.copyWith(color: secondaryColor.filterChipText(true)),
                    padding: EdgeInsets.zero,
                    emptyChild: divider,
                  )
                else
                  divider,
                _TrackTypeSegment(
                  title: lang.videos,
                  isActive: videosActive,
                  isFilled: videosActive && !bothActive,
                  showCount: !tracksActive,
                  padding: bothActive ? const EdgeInsetsDirectional.only(start: 8.0, end: 12.0, top: 6.0, bottom: 6.0) : _kFilterChipPadding,
                  borderRadius: BorderRadiusDirectional.horizontal(end: radius),
                  onTap: () => SearchSortController.inst.toggleSearchTrackType(TrackTypeSearch.v),
                  onLongPress: () => onJump(MediaType.track),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrackTypeSegment extends StatelessWidget {
  final String title;
  final bool isActive;
  final bool isFilled;
  final bool showCount;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TrackTypeSegment({
    required this.title,
    required this.isActive,
    required this.isFilled,
    required this.showCount,
    required this.padding,
    required this.borderRadius,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final secondaryColor = theme.colorScheme.secondary;
    final style = theme.textTheme.displayMedium?.copyWith(color: secondaryColor.filterChipText(isActive));
    return NamidaInkWell(
      animationDurationMS: 200,
      bgColor: secondaryColor.filterChipBg(isFilled),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      padding: padding,
      child: Row(
        children: [
          Text(
            title,
            style: style,
          ),
          if (showCount)
            _FilterChipCount(
              rx: SearchSortController.inst.trackSearchTemp,
              style: style,
            ),
        ],
      ),
    );
  }
}

class _FilterChipCount extends StatelessWidget {
  final RxBaseCore<List<Object>> rx;
  final TextStyle? style;
  final EdgeInsetsGeometry padding;
  final Widget emptyChild;

  const _FilterChipCount({
    required this.rx,
    required this.style,
    this.padding = const EdgeInsetsDirectional.only(start: 6.0),
    this.emptyChild = const SizedBox(),
  });

  @override
  Widget build(BuildContext context) {
    return ObxOSelect<List<Object>, int>(
      rx: rx,
      selector: (list) => list.length,
      builder: (context, count) => count == 0
          ? emptyChild
          : Padding(
              padding: padding,
              child: Center(
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: Text(
                  '$count',
                  style: style?.copyWith(fontSize: 12.0),
                ),
              ),
            ),
    );
  }
}

/// opaque so that the results beneath don't show through while fading.
class _SearchOverlay extends StatelessWidget {
  final Widget child;

  const _SearchOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: BackgroundWrapper(
        child: Align(
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }
}

class _RecentSearchesView extends StatelessWidget {
  const _RecentSearchesView();

  @override
  Widget build(BuildContext context) {
    if (settings.extra.recentSearchesEnabled != true) return const SizedBox.expand();
    final theme = context.theme;
    final chipBgColor = theme.colorScheme.secondary.withOpacityExt(0.12);
    final chipTextStyle = theme.textTheme.displayMedium?.copyWith(fontSize: 13.0);
    return ObxO(
      rx: settings.extra.recentSearches,
      builder: (context, recentSearches) {
        if (recentSearches.isEmpty) return const SizedBox.expand();
        return SmoothSingleChildScrollView(
          padding: kBottomPaddingInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10.0),
              SearchPageTitleRow(
                title: lang.recentSearches,
                icon: Broken.clock,
                trailing: NamidaButton(
                  colors: .mid,
                  icon: Broken.broom,
                  text: lang.clear,
                  onTap: settings.extra.clearRecentSearches,
                ),
              ),
              const SizedBox(height: 6.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: [
                    for (final text in recentSearches)
                      NamidaInkWell(
                        borderRadius: 8.0,
                        bgColor: chipBgColor,
                        padding: const EdgeInsetsDirectional.only(start: 10.0),
                        onTap: () => ScrollSearchController.inst.searchLocal(text),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                text,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                                style: chipTextStyle,
                              ),
                            ),
                            NamidaIconButton(
                              horizontalPadding: 8.0,
                              verticalPadding: 8.0,
                              icon: Broken.close_circle,
                              iconSize: 14.0,
                              onPressed: () => settings.extra.removeRecentSearch(text),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoResultsView extends StatelessWidget {
  const _NoResultsView();

  @override
  Widget build(BuildContext context) {
    final iconColor = context.theme.colorScheme.secondary.withOpacityExt(0.6);
    return Align(
      alignment: const Alignment(0.0, -0.4),
      child: ObxO(
        rx: SearchSortController.inst.runningSearchesTempCount,
        builder: (context, runningSearchesCount) => AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: runningSearchesCount > 0 ? 0.0 : 1.0,
          child: NoResultsWidget(
            icon: Broken.search_status,
            iconColor: iconColor,
          ),
        ),
      ),
    );
  }
}

class _SearchResultsView extends StatelessWidget {
  final Map<MediaType, GlobalKey> sectionKeys;
  final RxBaseCore<bool> isTracksFromSmartSearch;

  const _SearchResultsView({
    required this.sectionKeys,
    required this.isTracksFromSmartSearch,
  });

  _HorizontalSection<String> _artistSection({
    required String title,
    required IconData icon,
    required RxList<String> rx,
    required MediaType type,
    required List<Track> Function(String item) getTracks,
  }) {
    return _HorizontalSection<String>(
      titleKey: sectionKeys[type],
      rx: rx,
      title: title,
      icon: icon,
      trailing: NamidaButton(
        colors: .mid,
        icon: Broken.category,
        text: lang.viewAll,
        onTap: () => ArtistSearchResultsPage(artists: rx, type: type).navigate(),
      ),
      height: 100.0,
      itemExtent: 92.0,
      itemBuilder: (itemName) => Padding(
        padding: const EdgeInsets.only(left: 2.0),
        child: ArtistCard(
          name: itemName,
          artist: getTracks(itemName),
          type: type,
          width: 90.0,
          height: 100.0,
        ),
      ),
    );
  }

  _HorizontalSection<String> _multiArtworkSection({
    required String title,
    required IconData icon,
    required RxList<String> rx,
    required MediaType type,
    required Widget Function(String item) cardBuilder,
  }) {
    return _HorizontalSection<String>(
      titleKey: sectionKeys[type],
      rx: rx,
      title: title,
      icon: icon,
      height: 138.0,
      itemExtent: 108.0,
      itemBuilder: (item) => Padding(
        padding: const EdgeInsets.only(left: 2.0),
        child: cardBuilder(item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchController = SearchSortController.inst;
    return NamidaScrollbarWithController(
      child: (sc) => AnimationLimiter(
        child: TrackTilePropertiesProvider(
          configs: const TrackTilePropertiesConfigs(
            queueSource: QueueSource.search,
          ),
          builder: (properties) => SmoothCustomScrollView(
            controller: sc,
            slivers: [
              // == Albums ==
              _HorizontalSection<AlbumIdentifierWrapper>(
                titleKey: sectionKeys[MediaType.album],
                rx: searchController.albumSearchTemp,
                title: lang.albums,
                icon: Broken.music_dashboard,
                trailing: NamidaButton(
                  colors: .mid,
                  icon: Broken.category,
                  text: lang.viewAll,
                  onTap: const AlbumSearchResultsPage().navigate,
                ),
                height: 138.0,
                itemExtent: 108.0,
                itemBuilder: (albumId) => Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: AlbumCard(
                    identifier: albumId,
                    album: albumId.getAlbumTracks(),
                    staggered: false,
                    width: 106.0,
                    height: 138.0,
                  ),
                ),
              ),

              // == Artists ==
              _artistSection(
                title: lang.artists,
                icon: Broken.user,
                rx: searchController.artistSearchTemp,
                type: MediaType.artist,
                getTracks: (item) => item.getArtistTracks(),
              ),

              // == Album Artists ==
              _artistSection(
                title: lang.albumArtists,
                icon: Broken.user,
                rx: searchController.albumArtistSearchTemp,
                type: MediaType.albumArtist,
                getTracks: (item) => item.getAlbumArtistTracks(),
              ),

              // == Composers ==
              _artistSection(
                title: lang.composer,
                icon: Broken.profile_2user,
                rx: searchController.composerSearchTemp,
                type: MediaType.composer,
                getTracks: (item) => item.getComposerTracks(),
              ),

              // == Genres ==
              _multiArtworkSection(
                title: lang.genres,
                icon: Broken.smileys,
                rx: searchController.genreSearchTemp,
                type: MediaType.genre,
                cardBuilder: (genreName) => MultiArtworkCard(
                  tracks: genreName.getGenresTracks(),
                  name: genreName,
                  countPerRow: Dimensions.genreSearchGridCount,
                  heroTag: 'genre_$genreName',
                  showMenuFunction: () => NamidaDialogs.inst.showGenreDialog(genreName),
                  onTap: () => NamidaOnTaps.inst.onGenreTap(genreName),
                  width: 106.0,
                  height: 138.0,
                ),
              ),

              // == Styles ==
              _multiArtworkSection(
                title: lang.styles,
                icon: Broken.brush_1,
                rx: searchController.styleSearchTemp,
                type: MediaType.style,
                cardBuilder: (styleName) => MultiArtworkCard(
                  tracks: styleName.getStylesTracks(),
                  name: styleName,
                  countPerRow: Dimensions.genreSearchGridCount,
                  heroTag: 'style_$styleName',
                  showMenuFunction: () => NamidaDialogs.inst.showGenreDialog(styleName, MediaType.style),
                  onTap: () => NamidaOnTaps.inst.onGenreTap(styleName, MediaType.style),
                  width: 106.0,
                  height: 138.0,
                ),
              ),

              // == Playlists ==
              _HorizontalSection<String>(
                titleKey: sectionKeys[MediaType.playlist],
                rx: searchController.playlistSearchTemp,
                title: lang.playlists,
                icon: Broken.music_library_2,
                height: 138.0,
                itemExtent: 108.0,
                itemBuilder: (playlistName) {
                  final playlist = PlaylistController.inst.getPlaylist(playlistName);
                  return Padding(
                    padding: const EdgeInsets.only(left: 2.0),
                    child: MultiArtworkCard(
                      tracks: playlist?.tracks.toTracks() ?? [],
                      name: playlist?.name.translatePlaylistName() ?? playlistName,
                      countPerRow: Dimensions.playlistSearchGridCount,
                      heroTag: 'playlist_$playlistName',
                      showMenuFunction: () => NamidaDialogs.inst.showPlaylistDialog(playlistName),
                      onTap: () => NamidaOnTaps.inst.onNormalPlaylistTap(playlistName),
                      width: 106.0,
                      height: 138.0,
                    ),
                  );
                },
              ),

              // == Folders ==
              _HorizontalSection<String>(
                titleKey: sectionKeys[MediaType.folderMusic],
                rx: searchController.folderTracksSearchTemp,
                title: MediaType.folderMusic.toText(),
                icon: Broken.folder_2,
                height: 48.0 + 4 * 2,
                itemExtent: null,
                itemBuilder: (item) {
                  final folder = Folder.explicit(item);
                  return _FolderSmallCard(
                    folder: folder,
                    controller: FoldersController.tracks,
                    tracks: folder.tracksDedicated(),
                  );
                },
              ),

              // == Video Folders ==
              _HorizontalSection<String>(
                titleKey: sectionKeys[MediaType.folderVideo],
                rx: searchController.folderVideosSearchTemp,
                title: MediaType.folderVideo.toText(),
                icon: Broken.video_play,
                height: 48.0 + 4 * 2,
                itemExtent: null,
                itemBuilder: (item) {
                  final folder = VideoFolder.explicit(item);
                  return _FolderSmallCard(
                    folder: folder,
                    controller: FoldersController.videos,
                    tracks: folder.tracksDedicated(),
                  );
                },
              ),

              // == Moods ==
              _HorizontalSection<String>(
                titleKey: sectionKeys[MediaType.mood],
                rx: searchController.moodSearchTemp,
                title: lang.moods,
                icon: Broken.emoji_happy,
                height: 32.0 + 4,
                itemExtent: null,
                itemBuilder: (item) => _MoodTagSmallCard(
                  icon: Broken.emoji_happy,
                  name: item,
                  onTap: () => MoodsTracksSubPage.open(item, Indexer.inst.getTracksForMood(item) ?? []),
                  onLongPress: () => NamidaDialogs.inst.showMoodDialog(item, Indexer.inst.getTracksForMood(item) ?? []),
                ),
              ),

              // == Tags ==
              _HorizontalSection<String>(
                titleKey: sectionKeys[MediaType.tag],
                rx: searchController.tagSearchTemp,
                title: lang.tags,
                icon: Broken.tag,
                height: 32.0 + 4,
                itemExtent: null,
                itemBuilder: (item) => _MoodTagSmallCard(
                  icon: Broken.tag,
                  name: item,
                  onTap: () => TagsTracksSubPage.open(item, Indexer.inst.getTracksForTag(item) ?? []),
                  onLongPress: () => NamidaDialogs.inst.showTagDialog(item, Indexer.inst.getTracksForTag(item) ?? []),
                ),
              ),

              // == Tracks ==
              _TracksSectionTitle(
                titleKey: sectionKeys[MediaType.track],
                isTracksFromSmartSearch: isTracksFromSmartSearch,
              ),
              _TracksSectionList(
                properties: properties,
              ),

              kBottomPaddingWidgetSliver,
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizontalSection<T extends Object> extends StatelessWidget {
  final GlobalKey? titleKey;
  final RxBaseCore<List<T>> rx;
  final String title;
  final IconData icon;
  final Widget? trailing;
  final double height;
  final double? itemExtent;
  final Widget Function(T item) itemBuilder;

  const _HorizontalSection({
    required this.titleKey,
    required this.rx,
    required this.title,
    required this.icon,
    this.trailing,
    required this.height,
    required this.itemExtent,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: rx,
      builder: (context, list) => SliverToBoxAdapter(
        child: list.isEmpty
            ? null
            : Column(
                children: [
                  SearchPageTitleRow(
                    key: titleKey,
                    title: '$title • ${list.length}',
                    icon: icon,
                    trailing: trailing,
                  ),
                  SizedBox(
                    height: height + 24.0,
                    child: SuperSmoothListView.builder(
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                      scrollDirection: Axis.horizontal,
                      itemExtent: itemExtent,
                      itemCount: list.length,
                      itemBuilder: (context, i) => itemBuilder(list[i]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TracksSectionTitle extends StatelessWidget {
  final GlobalKey? titleKey;
  final RxBaseCore<bool> isTracksFromSmartSearch;

  const _TracksSectionTitle({
    required this.titleKey,
    required this.isTracksFromSmartSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return Obx(
      (context) {
        final tracksCount = SearchSortController.inst.trackSearchTemp.valueR.length;
        if (tracksCount == 0) return const SliverToBoxAdapter();
        final isTracksSearchActive = settings.activeTrSearch.valueR[TrackTypeSearch.tr] ?? true;
        return SliverPadding(
          padding: const EdgeInsets.only(bottom: 8.0),
          sliver: SliverToBoxAdapter(
            child: SearchPageTitleRow(
              key: titleKey,
              title: '${isTracksSearchActive ? lang.tracks : lang.videos} • $tracksCount',
              icon: Broken.music_circle,
              leading: ObxO(
                rx: isTracksFromSmartSearch,
                builder: (context, isFromSmartSearch) => Icon(
                  isFromSmartSearch ? Broken.magicpen : Broken.music_circle,
                ),
              ),
              subtitleWidget: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  NamidaPopupWrapper(
                    children: () => const [SortByMenuTracksSearch()],
                    child: NamidaInkWell(
                      child: Obx(
                        (context) {
                          final isAuto = settings.tracksSortSearchIsAuto.valueR;
                          final activeType = isAuto ? null : settings.tracksSortSearch.valueR;
                          return Text(
                            [
                              ?activeType?.toText(),
                              if (isAuto) lang.auto,
                            ].join(' '),
                            style: textTheme.displaySmall?.copyWith(
                              color: isAuto ? null : theme.colorScheme.secondary,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  NamidaInkWell(
                    onTap: () {
                      if (settings.tracksSortSearchIsAuto.value) return;
                      SearchSortController.inst.sortTracksSearch(reverse: !settings.tracksSortSearchReversed.value);
                    },
                    child: Obx(
                      (context) {
                        final isAuto = settings.tracksSortSearchIsAuto.valueR;
                        final activeReverse = isAuto ? false : settings.tracksSortSearchReversed.valueR;
                        return Icon(
                          activeReverse ? Broken.arrow_up_3 : Broken.arrow_down_2,
                          size: 16.0,
                          color: isAuto ? null : theme.colorScheme.secondary,
                        );
                      },
                    ),
                  ),
                ],
              ),
              trailing: Obx(
                (context) => NamidaButton(
                  colors: .mid,
                  icon: Broken.play,
                  text: settings.trackPlayMode.valueR.toText(),
                  tooltip: () => lang.trackPlayMode,
                  onTap: () {
                    final menu = NamidaPopupWrapper(
                      childrenDefault: () => TrackPlayMode.values.map(
                        (e) => NamidaPopupItem(
                          icon: e.toIcon(),
                          title: e.toText(),
                          selected: e == settings.trackPlayMode.value,
                          onTap: () {
                            settings.save(trackPlayMode: e);
                            NamidaNavigator.inst.popMenu();
                          },
                        ),
                      ),
                    );
                    menu.showPopupMenu(context);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TracksSectionList extends StatelessWidget {
  final TrackTileProperties properties;

  const _TracksSectionList({
    required this.properties,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: SearchSortController.inst.trackSearchTemp,
      builder: (context, tracks) => SliverFixedExtentList.builder(
        itemCount: tracks.length,
        itemExtent: Dimensions.inst.trackTileItemExtent,
        itemBuilder: (context, i) {
          return AnimatingTile(
            position: i,
            child: TrackTile(
              properties: properties,
              index: i,
              trackOrTwd: tracks[i],
              tracks: tracks,
            ),
          );
        },
      ),
    );
  }
}

class _FolderSmallCard extends StatelessWidget {
  final Folder folder;
  final FoldersController controller;
  final List<Track> tracks;

  const _FolderSmallCard({
    required this.folder,
    required this.controller,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    final folderName = folder.folderNameTryFormatNetwork();
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.width * 0.75),
      child: NamidaInkWell(
        margin: const EdgeInsets.only(left: 6.0),
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        onTap: () => NamidaOnTaps.inst.onFolderTapNavigate(folder, controller),
        onLongPress: () => NamidaDialogs.inst.showFolderDialog(
          folder: folder,
          tracks: tracks,
          controller: controller,
          isTracksRecursive: false,
        ),
        borderRadius: 8.0,
        bgColor: theme.colorScheme.secondary.withOpacityExt(0.12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 4.0),
            ArtworkWidget(
              key: Key(tracks.pathToImage),
              track: tracks.trackOfImage,
              thumbnailSize: 48.0,
              path: tracks.pathToImage,
              forceSquared: true,
            ),
            const SizedBox(width: 4.0),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folderName,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: textTheme.displayMedium?.copyWith(
                      fontSize: 13.0,
                    ),
                  ),
                  const SizedBox(height: 1.0),
                  Text(
                    tracks.length.displayTrackKeyword,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: textTheme.displaySmall?.copyWith(
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12.0),
          ],
        ),
      ),
    );
  }
}

class _MoodTagSmallCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final void Function() onTap;
  final void Function() onLongPress;

  const _MoodTagSmallCard({
    required this.name,
    required this.icon,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.width * 0.75),
      child: NamidaInkWell(
        margin: const EdgeInsets.only(left: 6.0),
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: 8.0,
        bgColor: theme.colorScheme.secondary.withOpacityExt(0.12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8.0),
            Icon(
              icon,
              size: 16.0,
            ),
            const SizedBox(width: 6.0),
            Flexible(
              child: Text(
                name,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: textTheme.displayMedium?.copyWith(
                  fontSize: 13.0,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
          ],
        ),
      ),
    );
  }
}
