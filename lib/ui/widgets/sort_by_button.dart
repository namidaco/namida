import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class SortByMenuTracks extends StatelessWidget {
  const SortByMenuTracks({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final tracksSort = SettingsController.inst.tracksSort.value;
        return Column(
          children: [
            ListTileWithCheckMark(
              active: SettingsController.inst.tracksSortReversed.value,
              onTap: () => Indexer.inst.sortTracks(reverse: !SettingsController.inst.tracksSortReversed.value),
            ),
            ...[
              SortType.title,
              SortType.album,
              SortType.albumArtist,
              SortType.artistsList,
              SortType.composer,
              SortType.genresList,
              SortType.year,
              SortType.dateModified,
              SortType.bitrate,
              SortType.discNo,
              SortType.filename,
              SortType.duration,
              SortType.sampleRate,
              SortType.size,
            ].map(
              (e) => SmallListTile(
                title: e.toText,
                active: tracksSort == e,
                onTap: () => Indexer.inst.sortTracks(sortBy: e),
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
        final albumsort = SettingsController.inst.albumSort.value;
        return Column(
          children: [
            ListTileWithCheckMark(
              active: SettingsController.inst.albumSortReversed.value,
              onTap: () => Indexer.inst.sortAlbums(reverse: !SettingsController.inst.albumSortReversed.value),
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
            ].map(
              (e) => SmallListTile(
                title: e.toText,
                active: albumsort == e,
                onTap: () => Indexer.inst.sortAlbums(sortBy: e),
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
        final artistSort = SettingsController.inst.artistSort.value;
        return Column(
          children: [
            ListTileWithCheckMark(
              active: SettingsController.inst.artistSortReversed.value,
              onTap: () => Indexer.inst.sortArtists(reverse: !SettingsController.inst.artistSortReversed.value),
            ),
            ...[
              GroupSortType.artistsList,
              GroupSortType.composer,
              GroupSortType.numberOfTracks,
              GroupSortType.duration,
              GroupSortType.genresList,
              GroupSortType.album,
              GroupSortType.albumArtist,
              GroupSortType.year,
              GroupSortType.dateModified,
            ].map(
              (e) => SmallListTile(
                title: e.toText,
                active: artistSort == e,
                onTap: () => Indexer.inst.sortArtists(sortBy: e),
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
        final genreSort = SettingsController.inst.genreSort.value;
        return Column(
          children: [
            ListTileWithCheckMark(
              active: SettingsController.inst.genreSortReversed.value,
              onTap: () => Indexer.inst.sortGenres(reverse: !SettingsController.inst.genreSortReversed.value),
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
            ].map(
              (e) => SmallListTile(
                title: e.toText,
                active: genreSort == e,
                onTap: () => Indexer.inst.sortGenres(sortBy: e),
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
        final playlistSort = SettingsController.inst.playlistSort.value;
        return Column(
          children: [
            ListTileWithCheckMark(
              active: SettingsController.inst.playlistSortReversed.value,
              onTap: () => PlaylistController.inst.sortPlaylists(reverse: !SettingsController.inst.playlistSortReversed.value),
            ),
            ...[
              GroupSortType.title,
              GroupSortType.year,
              GroupSortType.duration,
              GroupSortType.numberOfTracks,
            ].map(
              (e) => SmallListTile(
                title: e.toText,
                active: playlistSort == e,
                onTap: () => PlaylistController.inst.sortPlaylists(sortBy: e),
              ),
            ),
          ],
        );
      },
    );
  }
}
