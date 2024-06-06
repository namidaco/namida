import 'package:flutter/material.dart';

import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class SortByMenuTracks extends StatelessWidget {
  const SortByMenuTracks({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTileWithCheckMark(
          activeRx: settings.tracksSortReversed,
          onTap: () => SearchSortController.inst.sortMedia(MediaType.track, reverse: !settings.tracksSortReversed.value),
        ),
        ...[
          SortType.title,
          SortType.album,
          SortType.artistsList,
          SortType.albumArtist,
          SortType.composer,
          SortType.genresList,
          SortType.year,
          SortType.dateAdded,
          SortType.dateModified,
          SortType.bitrate,
          SortType.trackNo,
          SortType.discNo,
          SortType.filename,
          SortType.duration,
          SortType.sampleRate,
          SortType.size,
          SortType.rating,
          SortType.latestPlayed,
          SortType.mostPlayed,
          SortType.shuffle,
        ].map(
          (e) => ObxO(
            rx: settings.tracksSort,
            builder: (tracksSort) => SmallListTile(
              title: e.toText(),
              active: tracksSort == e,
              onTap: () => SearchSortController.inst.sortMedia(MediaType.track, sortBy: e),
            ),
          ),
        ),
      ],
    );
  }
}

class SortByMenuTracksSearch extends StatelessWidget {
  const SortByMenuTracksSearch({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.height * 0.5,
      child: SingleChildScrollView(
        child: Obx(
          () {
            final tracksSortSearch = settings.tracksSortSearch.valueR;
            final reversed = settings.tracksSortSearchReversed.valueR;
            final isAuto = settings.tracksSortSearchIsAuto.valueR;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ListTileWithCheckMark(
                    icon: Broken.arrow_swap_horizontal,
                    title: lang.AUTO,
                    activeRx: settings.tracksSortSearchIsAuto,
                    onTap: () {
                      settings.save(tracksSortSearchIsAuto: !settings.tracksSortSearchIsAuto.value);
                      SearchSortController.inst.sortTracksSearch(canSkipSorting: false);
                    },
                  ),
                ),
                const SizedBox(height: 4.0),
                TapDetector(
                  onTap: isAuto ? () {} : null,
                  child: ColoredBox(
                    color: Colors.transparent,
                    child: IgnorePointer(
                      ignoring: isAuto,
                      child: AnimatedOpacity(
                        opacity: isAuto ? 0.6 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ListTileWithCheckMark(
                                active: isAuto ? settings.tracksSortReversed.valueR : reversed,
                                onTap: () {
                                  SearchSortController.inst.sortTracksSearch(reverse: !reversed);
                                },
                              ),
                            ),
                            ...[
                              SortType.title,
                              SortType.album,
                              SortType.artistsList,
                              SortType.albumArtist,
                              SortType.composer,
                              SortType.genresList,
                              SortType.year,
                              SortType.dateAdded,
                              SortType.dateModified,
                              SortType.bitrate,
                              SortType.trackNo,
                              SortType.discNo,
                              SortType.filename,
                              SortType.duration,
                              SortType.sampleRate,
                              SortType.size,
                              SortType.rating,
                              SortType.latestPlayed,
                              SortType.mostPlayed,
                              SortType.shuffle,
                            ].map(
                              (e) => SmallListTile(
                                title: e.toText(),
                                active: (isAuto ? settings.tracksSort.value : tracksSortSearch) == e,
                                onTap: () {
                                  SearchSortController.inst.sortTracksSearch(sortBy: e);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }
}

class SortByMenuAlbums extends StatelessWidget {
  const SortByMenuAlbums({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTileWithCheckMark(
          activeRx: settings.albumSortReversed,
          onTap: () => SearchSortController.inst.sortMedia(MediaType.album, reverse: !settings.albumSortReversed.value),
        ),
        ...[
          GroupSortType.album,
          GroupSortType.albumArtist,
          GroupSortType.year,
          GroupSortType.duration,
          GroupSortType.numberOfTracks,
          GroupSortType.dateModified,
          GroupSortType.artistsList,
          GroupSortType.composer,
          GroupSortType.shuffle,
        ].map(
          (e) => ObxO(
            rx: settings.albumSort,
            builder: (albumsort) => SmallListTile(
              title: e.toText(),
              active: albumsort == e,
              onTap: () => SearchSortController.inst.sortMedia(MediaType.album, groupSortBy: e),
            ),
          ),
        ),
      ],
    );
  }
}

class SortByMenuArtists extends StatelessWidget {
  const SortByMenuArtists({super.key});

  @override
  Widget build(BuildContext context) {
    final artistType = settings.activeArtistType.value;
    return Column(
      children: [
        ListTileWithCheckMark(
          activeRx: settings.artistSortReversed,
          onTap: () => SearchSortController.inst.sortMedia(MediaType.artist, reverse: !settings.artistSortReversed.value),
        ),
        ...[
          artistType == MediaType.albumArtist
              ? GroupSortType.albumArtist
              : artistType == MediaType.composer
                  ? GroupSortType.composer
                  : GroupSortType.artistsList,
          GroupSortType.numberOfTracks,
          GroupSortType.albumsCount,
          GroupSortType.duration,
          GroupSortType.genresList,
          GroupSortType.album,
          GroupSortType.year,
          GroupSortType.dateModified,
          GroupSortType.shuffle,
        ].map(
          (e) => ObxO(
            rx: settings.artistSort,
            builder: (artistSort) => SmallListTile(
              title: e.toText(),
              active: artistSort == e,
              onTap: () => SearchSortController.inst.sortMedia(MediaType.artist, groupSortBy: e),
            ),
          ),
        ),
      ],
    );
  }
}

class SortByMenuGenres extends StatelessWidget {
  const SortByMenuGenres({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTileWithCheckMark(
          activeRx: settings.genreSortReversed,
          onTap: () => SearchSortController.inst.sortMedia(MediaType.genre, reverse: !settings.genreSortReversed.value),
        ),
        ...[
          GroupSortType.genresList,
          GroupSortType.duration,
          GroupSortType.numberOfTracks,
          GroupSortType.year,
          GroupSortType.artistsList,
          GroupSortType.album,
          GroupSortType.albumArtist,
          GroupSortType.dateModified,
          GroupSortType.composer,
          GroupSortType.shuffle,
        ].map(
          (e) => ObxO(
            rx: settings.genreSort,
            builder: (genreSort) => SmallListTile(
              title: e.toText(),
              active: genreSort == e,
              onTap: () => SearchSortController.inst.sortMedia(MediaType.genre, groupSortBy: e),
            ),
          ),
        ),
      ],
    );
  }
}

class SortByMenuPlaylist extends StatelessWidget {
  const SortByMenuPlaylist({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTileWithCheckMark(
          activeRx: settings.playlistSortReversed,
          onTap: () => SearchSortController.inst.sortMedia(MediaType.playlist, reverse: !settings.playlistSortReversed.value),
        ),
        ...[
          GroupSortType.title,
          GroupSortType.creationDate,
          GroupSortType.modifiedDate,
          GroupSortType.duration,
          GroupSortType.numberOfTracks,
          GroupSortType.shuffle,
        ].map(
          (e) => ObxO(
            rx: settings.playlistSort,
            builder: (playlistSort) => SmallListTile(
              title: e.toText(),
              active: playlistSort == e,
              onTap: () => SearchSortController.inst.sortMedia(MediaType.playlist, groupSortBy: e),
            ),
          ),
        ),
      ],
    );
  }
}
