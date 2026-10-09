import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:namida/base/tracks_search_wrapper.dart';
import 'package:namida/base/tracks_search_widget_mixin.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/pages/main_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/network_artwork.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class ArtistTracksPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route {
    return type == MediaType.albumArtist
        ? RouteType.SUBPAGE_albumArtistTracks
        : type == MediaType.composer
        ? RouteType.SUBPAGE_composerTracks
        : RouteType.SUBPAGE_artistTracks;
  }

  @override
  final String name;

  final List<Track> tracks;
  final List<MapEntry<AlbumIdentifierWrapper, List<Track>>> albums;
  final List<MapEntry<AlbumIdentifierWrapper, List<Track>>> eps;
  final List<MapEntry<AlbumIdentifierWrapper, List<Track>>> singles;
  final List<MapEntry<AlbumIdentifierWrapper, List<Track>>> extras;
  final MediaType type;

  const ArtistTracksPage({
    super.key,
    required this.name,
    required this.tracks,
    required this.albums,
    required this.eps,
    required this.singles,
    required this.extras,
    required this.type,
  });

  @override
  State<ArtistTracksPage> createState() => _ArtistTracksPageState();
}

class _ArtistTracksPageState extends State<ArtistTracksPage> with PortsProvider<TracksSearchParams>, TracksSearchWidgetMixin<ArtistTracksPage> {
  @override
  Iterable<TrackExtended> getTracksExtended() {
    return widget.tracks.map((e) => e.track.toTrackExt());
  }

  @override
  RxBaseCore listChangesListenerRx() => Indexer.inst.getArtistMapFor(widget.type).rx;

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final type = widget.type;
    final queueSource = type == MediaType.albumArtist
        ? QueueSource.albumArtist(name)
        : type == MediaType.composer
        ? QueueSource.composer(name)
        : QueueSource.artist(name);
    final tracks = widget.tracks;
    final searchResults = this.searchResults;
    final heroTag = 'artist_$name';
    return AnimationLimiter(
      child: BackgroundWrapper(
        child: TrackTilePropertiesProvider(
          configs: TrackTilePropertiesConfigs(
            queueSource: queueSource,
          ),
          builder: (properties) => Obx(
            (context) {
              // to update after sorting
              Indexer.inst.getArtistMapFor(widget.type).valueR;

              return NamidaListView(
                header: _ArtistAlbumsHeader(
                  albums: widget.albums,
                  eps: widget.eps,
                  singles: widget.singles,
                  extras: widget.extras,
                ),
                stickyHeader: TracksSearchWidgetBox(
                  state: this,
                  leftText: [
                    tracks.displayTrackKeyword,
                    tracks.totalDurationFormatted,
                  ].join(' - '),
                  type: type,
                  pageTitle: name,
                ),
                infoBox: (maxWidth) => SubpageInfoContainer(
                  maxWidth: maxWidth,
                  type: type,
                  onOpenMenu: () => NamidaDialogs.inst.showArtistDialog(name, type),
                  customArtworkManager: NetworkArtworkInfo.artist(name).toManager(),
                  topPadding: 8.0,
                  bottomPadding: 8.0,
                  title: name,
                  source: queueSource,
                  subtitle: tracks._yearsRangeFormatted,
                  heroTag: heroTag,
                  imageBuilder: (size) {
                    final info = NetworkArtworkInfo.artist(name);
                    final tracksPathToImage = tracks.pathToImage;
                    final artworkPre = NetworkArtwork.orLocal(
                      key: Key(tracksPathToImage),
                      info: info,
                      path: tracksPathToImage,
                      track: tracks.trackOfImage,
                      thumbnailSize: size,
                      fit: BoxFit.cover,
                      forceSquared: true,
                      isCircle: true,
                      blur: 12.0,
                      iconSize: 32.0,
                    );
                    final artwork = NamidaArtworkExpandableToFullscreen(
                      artwork: artworkPre,
                      heroTag: heroTag,
                      imageFile: () => info.toArtworkIfExistsAndValidAndEnabled() ?? File(tracksPathToImage),
                      fetchImage: () => null,
                      onSave: (imgFile, _) => imgFile == null ? null : EditDeleteController.inst.saveImageToStorage(imgFile),
                      themeColor: null,
                    );
                    return NamidaHero(
                      tag: heroTag,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: ContainerWithBorder(
                          child: artwork,
                        ),
                      ),
                    );
                  },
                  tracksFn: () => tracks,
                  bannerBuilder: (width, height) {
                    final info = NetworkArtworkInfo.artist(name);
                    final tracksPathToImage = tracks.pathToImage;
                    final banner = NetworkArtwork.orLocal(
                      key: Key(tracksPathToImage),
                      path: tracksPathToImage,
                      track: tracks.trackOfImage,
                      info: info,
                      thumbnailSize: height,
                      width: width,
                      height: height,
                      forceSquared: true,
                      compressed: true,
                      borderRadius: 0.0,
                      blur: 0.0,
                      iconSize: 32.0,
                    );
                    return NamidaArtworkExpandableToFullscreen(
                      artwork: banner,
                      heroTag: null,
                      imageFile: () => info.toArtworkIfExistsAndValidAndEnabled() ?? File(tracksPathToImage),
                      fetchImage: () => null,
                      onSave: (imgFile, _) => imgFile == null ? null : EditDeleteController.inst.saveImageToStorage(imgFile),
                      themeColor: null,
                    );
                  },
                ),
                itemCount: searchResults?.length ?? tracks.length,
                itemExtent: Dimensions.inst.trackTileItemExtent,
                itemBuilder: (context, i) {
                  final index = searchResults == null ? i : searchResults[i];
                  final track = tracks[index];
                  return AnimatingTile(
                    key: ValueKey(index),
                    position: i,
                    child: TrackTile(
                      properties: properties,
                      index: index,
                      trackOrTwd: track,
                      tracks: tracks,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ArtistAlbumsHeader extends StatefulWidget {
  final List<MapEntry<AlbumIdentifierWrapper, List<Track>>> albums;
  final List<MapEntry<AlbumIdentifierWrapper, List<Track>>> eps;
  final List<MapEntry<AlbumIdentifierWrapper, List<Track>>> singles;
  final List<MapEntry<AlbumIdentifierWrapper, List<Track>>> extras;

  const _ArtistAlbumsHeader({
    required this.albums,
    required this.eps,
    required this.singles,
    required this.extras,
  });

  @override
  State<_ArtistAlbumsHeader> createState() => _ArtistAlbumsHeaderState();
}

class _ArtistAlbumsHeaderState extends State<_ArtistAlbumsHeader> {
  @override
  void initState() {
    _sortAll();
    settings.artistAlbumsSort.addListener(_onSortingChanged);
    settings.artistAlbumsSortReversed.addListener(_onSortingChanged);
    settings.albumSorts.addListener(_onSortingChanged);
    settings.albumSortReversed.addListener(_onSortingChanged);
    super.initState();
  }

  @override
  void dispose() {
    settings.artistAlbumsSort.removeListener(_onSortingChanged);
    settings.artistAlbumsSortReversed.removeListener(_onSortingChanged);
    settings.albumSorts.removeListener(_onSortingChanged);
    settings.albumSortReversed.removeListener(_onSortingChanged);
    super.dispose();
  }

  void _sortAll() {
    final sort = settings.artistAlbumsSort.value;
    final (sorts, reverse) = sort == null ? _artistAlbumsAutoSorting() : ([sort], settings.artistAlbumsSortReversed.value);
    for (final list in [widget.albums, widget.eps, widget.singles, widget.extras]) {
      if (list.length > 1) SearchSortController.inst.sortAlbumsListRaw(list, sorts, reverse);
    }
  }

  void _onSortingChanged() {
    _sortAll();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final albumsInitiallyExpanded = settings.extra.artistAlbumsExpanded.value ?? true;
    final epsInitiallyExpanded = settings.extra.artistEpsExpanded.value ?? false;
    final singlesInitiallyExpanded = settings.extra.artistSinglesExpanded.value ?? false; // cuz no space
    final extrasInitiallyExpanded = widget.albums.isEmpty && widget.eps.isEmpty && widget.singles.isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4.0),
        if (widget.albums.isNotEmpty) ...[
          _AlbumsRow(
            title: lang.albums,
            icon: Broken.music_dashboard,
            albums: widget.albums,
            initiallyExpanded: albumsInitiallyExpanded,
            onExpansionChanged: (value) => settings.extra.artistAlbumsExpanded.save(value),
          ),
        ],
        if (widget.eps.isNotEmpty) ...[
          const SizedBox(height: 6.0),
          _AlbumsRow(
            title: lang.eps,
            icon: Broken.music_playlist,
            albums: widget.eps,
            initiallyExpanded: epsInitiallyExpanded,
            onExpansionChanged: (value) => settings.extra.artistEpsExpanded.save(value),
          ),
        ],
        if (widget.singles.isNotEmpty) ...[
          const SizedBox(height: 6.0),
          _AlbumsRow(
            title: lang.singles,
            icon: Broken.music_square,
            albums: widget.singles,
            initiallyExpanded: singlesInitiallyExpanded,
            onExpansionChanged: (value) => settings.extra.artistSinglesExpanded.save(value),
          ),
        ],
        if (widget.extras.isNotEmpty) ...[
          const SizedBox(height: 6.0),
          _AlbumsRow(
            title: lang.appearsOn,
            icon: Broken.format_circle,
            albums: widget.extras,
            initiallyExpanded: extrasInitiallyExpanded,
            onExpansionChanged: (value) {},
          ),
        ],
        const SizedBox(height: 4.0),
      ],
    );
  }
}

class _AlbumsRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<MapEntry<AlbumIdentifierWrapper, List<Track>>> albums;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  const _AlbumsRow({
    required this.title,
    required this.icon,
    required this.albums,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsGeometry.symmetric(horizontal: 8.0),
      child: BorderRadiusClip(
        borderRadius: BorderRadiusGeometry.circular(8.0.multipliedRadius),
        child: NamidaExpansionTile(
          compact: false,
          bgColor: context.theme.cardColor,
          leading: _AlbumsRowLeading(
            icon: icon,
          ),
          borderless: true,
          titleText: "$title: ${albums.length}",
          initiallyExpanded: albums.isNotEmpty && initiallyExpanded,
          onExpansionChanged: albums.isEmpty ? null : onExpansionChanged,
          trailingBuilder: (iconWidget) => Row(
            mainAxisSize: .min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1.0),
                child: NamidaIconButton(
                  icon: Broken.export_2,
                  iconSize: 18.0,
                  disableColor: true,
                  onPressed: () {
                    final albumIdentifiers = albums.map((e) => e.key).toFixedList();
                    final page = AlbumCustomResultsPage(
                      albumIdentifiers: albumIdentifiers,
                    );
                    page.navigate();
                  },
                ),
              ),
              iconWidget,
            ],
          ),
          children: albums.isEmpty
              ? const []
              : [
                  SizedBox(
                    height: 130.0 + 28.0,
                    child: SuperSmoothListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      scrollDirection: Axis.horizontal,
                      itemExtent: 100.0,
                      itemCount: albums.length,
                      itemBuilder: (context, i) {
                        final album = albums[i];
                        return Padding(
                          padding: const EdgeInsets.only(left: 2.0),
                          child: AlbumCard(
                            identifier: album.key,
                            album: album.value,
                            staggered: false,
                            compact: true,
                            width: 98.0,
                            height: 130.0,
                          ),
                        );
                      },
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}

class _AlbumsRowLeading extends StatelessWidget {
  final IconData icon;

  const _AlbumsRowLeading({
    required this.icon,
  });

  void _showSortMenu(BuildContext context) {
    NamidaPopupWrapper(
      children: () => const [_ArtistAlbumsSortMenu()],
    ).showPopupMenu(context);
  }

  @override
  Widget build(BuildContext context) {
    return LongPressDetector(
      behavior: HitTestBehavior.opaque,
      enableSecondaryTap: true,
      onLongPress: () => _showSortMenu(context),
      child: Icon(
        icon,
      ),
    );
  }
}

class _ArtistAlbumsSortMenu extends StatelessWidget {
  const _ArtistAlbumsSortMenu();

  void _pin(GroupSortType sort, bool reversed) {
    settings.artistAlbumsSortReversed.save(reversed);
    settings.artistAlbumsSort.save(sort);
  }

  void _onSortTap(GroupSortType tapped, GroupSortType effectiveSort, bool effectiveReversed) {
    final reversed = tapped == effectiveSort ? effectiveReversed : settings.artistAlbumsSortReversed.value;
    _pin(tapped, reversed);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final sort = settings.artistAlbumsSort.valueR;
        final sortReversed = settings.artistAlbumsSortReversed.valueR;
        final (autoSorts, autoReversed) = _artistAlbumsAutoSorting();
        final autoSort = autoSorts.first;
        final effectiveSort = sort ?? autoSort;
        final effectiveReversed = sort == null ? autoReversed : sortReversed;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SortOptionsCards(
              isReversed: effectiveReversed,
              onReverseTap: () => _pin(effectiveSort, !effectiveReversed),
              withSortKeyOptions: false,
              prefixFilters: null,
            ),
            SmallListTile(
              borderRadius: 12.0,
              visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
              title: lang.auto,
              subtitle: autoSort.toText(),
              trailingIcon: Broken.medal_star,
              active: sort == null,
              onTap: () => settings.artistAlbumsSort.save(null),
            ),
            ...GroupSortType.forAlbums().map(
              (e) => SmallListTile(
                borderRadius: 12.0,
                visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                title: e.toText(),
                trailingIcon: e.toIcon(),
                active: sort == e,
                onTap: () => _onSortTap(e, effectiveSort, effectiveReversed),
              ),
            ),
          ],
        );
      },
    );
  }
}

(List<GroupSortType>, bool) _artistAlbumsAutoSorting() {
  final albumSorts = settings.albumSorts.value;
  if (albumSorts.first.suitsDiscography()) return (albumSorts, settings.albumSortReversed.value);
  return (const [GroupSortType.year], true);
}

extension _TracksYearsRange on List<Track> {
  String get _yearsRangeFormatted {
    int oldest = 0;
    int newest = 0;
    for (int i = 0; i < length; i++) {
      int y = this[i].year;
      if (y == 0) continue;
      while (y > 9999) {
        y ~/= 10;
      }
      if (oldest == 0 || y < oldest) oldest = y;
      if (y > newest) newest = y;
    }
    if (oldest == 0) return '';
    return oldest == newest ? '$oldest' : '$oldest – $newest';
  }
}

extension _GroupSortTypeDiscography on GroupSortType {
  bool suitsDiscography() => switch (this) {
    GroupSortType.album || GroupSortType.albumSort || GroupSortType.albumArtist || GroupSortType.albumArtistSort || GroupSortType.artistsList => false,
    GroupSortType.title ||
    GroupSortType.year ||
    GroupSortType.genresList ||
    GroupSortType.dateAdded ||
    GroupSortType.dateModified ||
    GroupSortType.composer ||
    GroupSortType.label ||
    GroupSortType.releaseType ||
    GroupSortType.bpm ||
    GroupSortType.duration ||
    GroupSortType.numberOfTracks ||
    GroupSortType.playCount ||
    GroupSortType.latestPlayed ||
    GroupSortType.lastPlayed ||
    GroupSortType.firstListen ||
    GroupSortType.albumsCount ||
    GroupSortType.creationDate ||
    GroupSortType.modifiedDate ||
    GroupSortType.artistSort ||
    GroupSortType.composerSort ||
    GroupSortType.shuffle ||
    GroupSortType.shuffleDaily ||
    GroupSortType.custom => true,
  };
}
