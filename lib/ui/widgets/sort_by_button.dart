import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class SortByMenuTracks extends StatelessWidget {
  const SortByMenuTracks({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final tracksSort = settings.tracksSort.value;
        return Column(
          children: [
            ListTileWithCheckMark(
              active: settings.tracksSortReversed.value,
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
              SortType.dateModified,
              SortType.bitrate,
              SortType.trackNo,
              SortType.discNo,
              SortType.filename,
              SortType.duration,
              SortType.sampleRate,
              SortType.size,
              SortType.rating,
              SortType.shuffle,
            ].map(
              (e) => SmallListTile(
                title: e.toText(),
                active: tracksSort == e,
                onTap: () => SearchSortController.inst.sortMedia(MediaType.track, sortBy: e),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SortByMenuAlbums extends StatelessWidget {
  const SortByMenuAlbums({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final albumsort = settings.albumSort.value;
        return Column(
          children: [
            ListTileWithCheckMark(
              active: settings.albumSortReversed.value,
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
              (e) => SmallListTile(
                title: e.toText(),
                active: albumsort == e,
                onTap: () => SearchSortController.inst.sortMedia(MediaType.album, groupSortBy: e),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SortByMenuArtists extends StatelessWidget {
  const SortByMenuArtists({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final artistSort = settings.artistSort.value;
        return Column(
          children: [
            ListTileWithCheckMark(
              active: settings.artistSortReversed.value,
              onTap: () => SearchSortController.inst.sortMedia(MediaType.artist, reverse: !settings.artistSortReversed.value),
            ),
            ...[
              GroupSortType.artistsList,
              GroupSortType.composer,
              GroupSortType.numberOfTracks,
              GroupSortType.albumsCount,
              GroupSortType.duration,
              GroupSortType.genresList,
              GroupSortType.album,
              GroupSortType.albumArtist,
              GroupSortType.year,
              GroupSortType.dateModified,
              GroupSortType.shuffle,
            ].map(
              (e) => SmallListTile(
                title: e.toText(),
                active: artistSort == e,
                onTap: () => SearchSortController.inst.sortMedia(MediaType.artist, groupSortBy: e),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SortByMenuGenres extends StatelessWidget {
  const SortByMenuGenres({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final genreSort = settings.genreSort.value;
        return Column(
          children: [
            ListTileWithCheckMark(
              active: settings.genreSortReversed.value,
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
              (e) => SmallListTile(
                title: e.toText(),
                active: genreSort == e,
                onTap: () => SearchSortController.inst.sortMedia(MediaType.genre, groupSortBy: e),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SortByMenuPlaylist extends StatelessWidget {
  const SortByMenuPlaylist({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final playlistSort = settings.playlistSort.value;
        return Column(
          children: [
            ListTileWithCheckMark(
              active: settings.playlistSortReversed.value,
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
              (e) => SmallListTile(
                title: e.toText(),
                active: playlistSort == e,
                onTap: () => SearchSortController.inst.sortMedia(MediaType.playlist, groupSortBy: e),
              ),
            ),
          ],
        );
      },
    );
  }
}
