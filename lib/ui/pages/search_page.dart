import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/clipboard_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/pages/main_page.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/multi_artwork_card.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';
import 'package:namida/youtube/pages/yt_search_results_page.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  SliverToBoxAdapter _horizontalSliverList<T>({
    required double height,
    required double? itemExtent,
    required List<T> list,
    required Widget Function(T item) builder,
  }) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: height + 24.0,
        child: ListView.builder(
          clipBehavior: Clip.none,
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          scrollDirection: Axis.horizontal,
          itemExtent: itemExtent,
          itemCount: list.length,
          itemBuilder: (context, i) {
            return builder(list[i]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final albumDimensions = Dimensions.inst.getAlbumCardDimensions(Dimensions.albumSearchGridCount);
    final artistDimensions = Dimensions.inst.getArtistCardDimensions(Dimensions.artistSearchGridCount);
    final genreDimensions = Dimensions.inst.getArtistCardDimensions(Dimensions.genreSearchGridCount);
    final playlistDimensions = Dimensions.inst.getArtistCardDimensions(Dimensions.playlistSearchGridCount);
    return BackgroundWrapper(
      child: NamidaTabView(
        initialIndex: () {
          switch (ScrollSearchController.inst.currentSearchType.value) {
            case SearchType.localTracks:
              return 0;
            case SearchType.youtube:
              return 1;
            default:
              return 0;
          }
        }(),
        onIndexChanged: (index) async {
          switch (index) {
            case 0:
              ScrollSearchController.inst.currentSearchType.value = SearchType.localTracks;
              final srchTxt = ScrollSearchController.inst.searchTextEditingController.text;
              ClipboardController.inst.updateTextInControllerEmpty(srchTxt == '');
              await SearchSortController.inst.prepareResources();
              SearchSortController.inst.searchAll(srchTxt);
              break;
            case 1:
              ScrollSearchController.inst.currentSearchType.value = SearchType.youtube;
              final searchValue = ScrollSearchController.inst.ytSearchKey.currentState?.currentSearchText;
              if (SearchSortController.inst.lastSearchText != searchValue) {
                ScrollSearchController.inst.ytSearchKey.currentState?.fetchSearch(customText: SearchSortController.inst.lastSearchText);
              }
              break;
          }
        },
        tabs: [
          lang.LOCAL,
          lang.YOUTUBE,
        ],
        children: [
          Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...MediaType.values.map(
                      (e) => Obx(
                        () {
                          final list = settings.activeSearchMediaTypes;
                          final isActive = list.contains(e);
                          final isForcelyEnabled = e == MediaType.track;
                          return NamidaOpacity(
                            opacity: isForcelyEnabled ? 0.6 : 1.0,
                            child: NamidaInkWell(
                              bgColor: isActive ? context.theme.colorScheme.secondary.withOpacity(0.12) : null,
                              borderRadius: 8.0,
                              onTap: () async {
                                if (isForcelyEnabled) return;
                                if (isActive) {
                                  settings.removeFromList(activeSearchMediaTypes1: e);
                                } else {
                                  settings.save(activeSearchMediaTypes: [e]);
                                  await SearchSortController.inst.prepareResources();
                                  SearchSortController.inst.searchAll(ScrollSearchController.inst.searchTextEditingController.text);
                                }
                              },
                              margin: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 12.0),
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: context.theme.colorScheme.secondary.withOpacity(0.7),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    e.toText(),
                                    style: context.textTheme.displayMedium?.copyWith(
                                      color: context.theme.colorScheme.secondary.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  NamidaCheckMark(
                                    size: 12.0,
                                    active: isActive,
                                    activeColor: context.theme.colorScheme.secondary.withOpacity(0.7),
                                    inactiveColor: context.theme.colorScheme.secondary.withOpacity(0.7),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Obx(
                  () => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: !SearchSortController.inst.isSearching
                        ? Container(
                            key: const Key('emptysearch'),
                            padding: const EdgeInsets.all(64.0).add(const EdgeInsets.only(bottom: 64.0)),
                            width: context.width,
                            height: context.height,
                            child: NamidaOpacity(
                              opacity: 0.8,
                              child: TweenAnimationBuilder(
                                tween: Tween<double>(begin: 4.0, end: ScrollSearchController.inst.isGlobalSearchMenuShown.value ? 4.0 : 12.0),
                                duration: const Duration(milliseconds: 500),
                                child: Image.asset('assets/namida_icon.png'),
                                builder: (context, value, child) => ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                    sigmaX: value,
                                    sigmaY: value,
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          )
                        : AnimationLimiter(
                            key: const Key('fullsearch'),
                            child: NamidaScrollbarWithController(
                              child: (sc) => Obx(
                                () {
                                  final activeList = settings.activeSearchMediaTypes;

                                  final albumSearchTemp = SearchSortController.inst.albumSearchTemp;
                                  final artistSearchTemp = SearchSortController.inst.artistSearchTemp;
                                  final genreSearchTemp = SearchSortController.inst.genreSearchTemp;
                                  final playlistSearchTemp = SearchSortController.inst.playlistSearchTemp;
                                  final folderSearchTemp = SearchSortController.inst.folderSearchTemp.where((f) => Folder(f).tracks.isNotEmpty).toList();

                                  return CustomScrollView(
                                    controller: sc,
                                    slivers: [
                                      // == Albums ==
                                      if (activeList.contains(MediaType.album) && albumSearchTemp.isNotEmpty) ...[
                                        SliverToBoxAdapter(
                                          child: SearchPageTitleRow(
                                            title: '${lang.ALBUMS} • ${albumSearchTemp.length}',
                                            icon: Broken.music_dashboard,
                                            buttonIcon: Broken.category,
                                            buttonText: lang.VIEW_ALL,
                                            onPressed: () => NamidaNavigator.inst.navigateTo(const AlbumSearchResultsPage()),
                                          ),
                                        ),
                                        _horizontalSliverList(
                                          height: 138.0,
                                          itemExtent: 108.0,
                                          list: albumSearchTemp,
                                          builder: (item) {
                                            final albumId = item;
                                            return Container(
                                              width: 130.0,
                                              margin: const EdgeInsets.only(left: 2.0),
                                              child: AlbumCard(
                                                dimensions: albumDimensions,
                                                identifier: albumId,
                                                album: albumId.getAlbumTracks(),
                                                staggered: false,
                                              ),
                                            );
                                          },
                                        ),
                                      ],

                                      // == Artists ==
                                      if (activeList.contains(MediaType.artist) && artistSearchTemp.isNotEmpty) ...[
                                        SliverToBoxAdapter(
                                          child: SearchPageTitleRow(
                                            title: '${lang.ARTISTS} • ${artistSearchTemp.length}',
                                            icon: Broken.profile_2user,
                                            buttonIcon: Broken.category,
                                            buttonText: lang.VIEW_ALL,
                                            onPressed: () => NamidaNavigator.inst.navigateTo(const ArtistSearchResultsPage()),
                                          ),
                                        ),
                                        _horizontalSliverList(
                                          height: 100.0,
                                          itemExtent: 82.0,
                                          list: artistSearchTemp,
                                          builder: (item) {
                                            final artistName = item;
                                            return Container(
                                              width: 80.0,
                                              margin: const EdgeInsets.only(left: 2.0),
                                              child: ArtistCard(
                                                dimensions: artistDimensions,
                                                name: artistName,
                                                artist: artistName.getArtistTracks(),
                                              ),
                                            );
                                          },
                                        ),
                                      ],

                                      // == Genres ==
                                      if (activeList.contains(MediaType.genre) && genreSearchTemp.isNotEmpty) ...[
                                        SliverToBoxAdapter(
                                          child: SearchPageTitleRow(
                                            title: '${lang.GENRES} • ${genreSearchTemp.length}',
                                            icon: Broken.smileys,
                                          ),
                                        ),
                                        _horizontalSliverList(
                                          height: 138.0,
                                          itemExtent: 108.0,
                                          list: genreSearchTemp,
                                          builder: (item) {
                                            final genreName = item;
                                            return Container(
                                              width: 130.0,
                                              margin: const EdgeInsets.only(left: 2.0),
                                              child: MultiArtworkCard(
                                                tracks: genreName.getGenresTracks(),
                                                name: genreName,
                                                gridCount: Dimensions.genreSearchGridCount,
                                                heroTag: 'genre_$genreName',
                                                dimensions: genreDimensions,
                                                showMenuFunction: () => NamidaDialogs.inst.showGenreDialog(genreName),
                                                onTap: () => NamidaOnTaps.inst.onGenreTap(genreName),
                                              ),
                                            );
                                          },
                                        ),
                                      ],

                                      // == Playlists ==
                                      if (activeList.contains(MediaType.playlist) && playlistSearchTemp.isNotEmpty) ...[
                                        SliverToBoxAdapter(
                                          child: SearchPageTitleRow(
                                            title: '${lang.PLAYLISTS} • ${playlistSearchTemp.length}',
                                            icon: Broken.music_library_2,
                                          ),
                                        ),
                                        _horizontalSliverList(
                                          height: 138.0,
                                          itemExtent: 108.0,
                                          list: playlistSearchTemp,
                                          builder: (item) {
                                            final playlistName = item;
                                            final playlist = PlaylistController.inst.getPlaylist(playlistName);

                                            return Container(
                                              width: 130.0,
                                              margin: const EdgeInsets.only(left: 2.0),
                                              child: MultiArtworkCard(
                                                tracks: playlist?.tracks.toTracks() ?? [],
                                                name: playlist?.name.translatePlaylistName() ?? playlistName,
                                                gridCount: Dimensions.playlistSearchGridCount,
                                                heroTag: 'playlist_$playlistName',
                                                dimensions: playlistDimensions,
                                                showMenuFunction: () => NamidaDialogs.inst.showPlaylistDialog(playlistName),
                                                onTap: () => NamidaOnTaps.inst.onNormalPlaylistTap(playlistName),
                                              ),
                                            );
                                          },
                                        ),
                                      ],

                                      // == Playlists ==
                                      if (activeList.contains(MediaType.folder) && folderSearchTemp.isNotEmpty) ...[
                                        SliverToBoxAdapter(
                                          child: SearchPageTitleRow(
                                            title: '${lang.FOLDERS} • ${folderSearchTemp.length}',
                                            icon: Broken.folder,
                                          ),
                                        ),
                                        _horizontalSliverList(
                                          height: 48.0 + 4 * 2,
                                          itemExtent: null,
                                          list: folderSearchTemp,
                                          builder: (item) {
                                            final folder = Folder(item);
                                            final tracks = folder.tracks;

                                            return NamidaInkWell(
                                              margin: const EdgeInsets.only(left: 6.0),
                                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                                              onTap: () => NamidaOnTaps.inst.onFolderTap(folder),
                                              onLongPress: () => NamidaDialogs.inst.showFolderDialog(folder: folder, tracks: tracks),
                                              borderRadius: 8.0,
                                              bgColor: context.theme.colorScheme.secondary.withOpacity(0.12),
                                              child: Row(
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
                                                  Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        folder.folderName,
                                                        style: context.textTheme.displayMedium?.copyWith(
                                                          fontSize: 13.0.multipliedFontScale,
                                                        ),
                                                      ),
                                                      Text(
                                                        tracks.length.displayTrackKeyword,
                                                        style: context.textTheme.displaySmall?.copyWith(
                                                          fontSize: 12.0.multipliedFontScale,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(width: 12.0),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],

                                      // == Tracks ==
                                      if (activeList.contains(MediaType.track) && SearchSortController.inst.trackSearchTemp.isNotEmpty) ...[
                                        SliverToBoxAdapter(
                                          child: Tooltip(
                                            message: lang.TRACK_PLAY_MODE,
                                            child: SearchPageTitleRow(
                                              title: '${lang.TRACKS} • ${SearchSortController.inst.trackSearchTemp.length}',
                                              icon: Broken.music_circle,
                                              subtitleWidget: Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  NamidaPopupWrapper(
                                                    useRootNavigator: false,
                                                    children: () => const [SortByMenuTracksSearch()],
                                                    child: NamidaInkWell(
                                                      child: Obx(
                                                        () {
                                                          final isAuto = settings.tracksSortSearchIsAuto.value;
                                                          final activeType = isAuto ? settings.tracksSort.value : settings.tracksSortSearch.value;
                                                          return Text(
                                                            activeType.toText() + (isAuto ? ' (${lang.AUTO})' : ''),
                                                            style: context.textTheme.displaySmall?.copyWith(
                                                              color: isAuto ? null : context.theme.colorScheme.secondary,
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
                                                      () {
                                                        final isAuto = settings.tracksSortSearchIsAuto.value;
                                                        final activeReverse = isAuto ? settings.tracksSortReversed.value : settings.tracksSortSearchReversed.value;
                                                        return Icon(
                                                          activeReverse ? Broken.arrow_up_3 : Broken.arrow_down_2,
                                                          size: 16.0,
                                                          color: isAuto ? null : context.theme.colorScheme.secondary,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              buttonIcon: Broken.play,
                                              buttonText: settings.trackPlayMode.value.toText(),
                                              onPressed: () {
                                                final element = settings.trackPlayMode.value.nextElement(TrackPlayMode.values);
                                                settings.save(trackPlayMode: element);
                                              },
                                            ),
                                          ),
                                        ),
                                        const SliverPadding(padding: EdgeInsets.only(bottom: 8.0)),
                                        SliverFixedExtentList.builder(
                                          itemCount: SearchSortController.inst.trackSearchTemp.length,
                                          itemExtent: Dimensions.inst.trackTileItemExtent,
                                          itemBuilder: (context, i) {
                                            final track = SearchSortController.inst.trackSearchTemp[i];
                                            return AnimatingTile(
                                              position: i,
                                              child: TrackTile(
                                                index: i,
                                                trackOrTwd: track,
                                                queueSource: QueueSource.search,
                                              ),
                                            );
                                          },
                                        ),
                                      ],

                                      kBottomPaddingWidgetSliver
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          YoutubeSearchResultsPage(
            key: ScrollSearchController.inst.ytSearchKey,
            searchText: '',
          ),
        ],
      ),
    );
  }
}
