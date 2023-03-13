import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/translations/strings.dart';
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
            SmallListTile(
              title: Language.inst.TITLE,
              active: tracksSort == SortType.title,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.title),
            ),
            SmallListTile(
              title: Language.inst.ALBUM,
              active: tracksSort == SortType.album,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.album),
            ),
            SmallListTile(
              title: Language.inst.ALBUM_ARTIST,
              active: tracksSort == SortType.albumArtist,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.albumArtist),
            ),
            SmallListTile(
              title: Language.inst.ARTISTS,
              active: tracksSort == SortType.artistsList,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.artistsList),
            ),
            SmallListTile(
              title: Language.inst.COMPOSER,
              active: tracksSort == SortType.composer,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.composer),
            ),
            SmallListTile(
              title: Language.inst.GENRES,
              active: tracksSort == SortType.genresList,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.genresList),
            ),
            SmallListTile(
              title: Language.inst.YEAR,
              active: tracksSort == SortType.year,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.year),
            ),
            SmallListTile(
              title: Language.inst.DATE_MODIFIED,
              active: tracksSort == SortType.dateModified,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.dateModified),
            ),
            SmallListTile(
              title: Language.inst.BITRATE,
              active: tracksSort == SortType.bitrate,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.bitrate),
            ),
            SmallListTile(
              title: Language.inst.DISC_NUMBER,
              active: tracksSort == SortType.discNo,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.discNo),
            ),
            SmallListTile(
              title: Language.inst.FILE_NAME,
              active: tracksSort == SortType.filename,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.filename),
            ),
            SmallListTile(
              title: Language.inst.DURATION,
              active: tracksSort == SortType.duration,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.duration),
            ),
            SmallListTile(
              title: Language.inst.SAMPLE_RATE,
              active: tracksSort == SortType.sampleRate,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.sampleRate),
            ),
            SmallListTile(
              title: Language.inst.SIZE,
              active: tracksSort == SortType.size,
              onTap: () => Indexer.inst.sortTracks(sortBy: SortType.size),
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
            SmallListTile(
              title: Language.inst.ALBUM,
              active: albumsort == GroupSortType.album,
              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.album),
            ),
            SmallListTile(
              title: Language.inst.ALBUM_ARTIST,
              active: albumsort == GroupSortType.albumArtist,
              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.albumArtist),
            ),
            SmallListTile(
              title: Language.inst.YEAR,
              active: albumsort == GroupSortType.year,
              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.year),
            ),
            SmallListTile(
              title: Language.inst.DURATION,
              active: albumsort == GroupSortType.duration,
              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.duration),
            ),
            SmallListTile(
              title: Language.inst.NUMBER_OF_TRACKS,
              active: albumsort == GroupSortType.numberOfTracks,
              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.numberOfTracks),
            ),
            SmallListTile(
              title: Language.inst.DATE_MODIFIED,
              active: albumsort == GroupSortType.dateModified,
              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.dateModified),
            ),
            SmallListTile(
              title: Language.inst.ARTISTS,
              active: albumsort == GroupSortType.artistsList,
              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.artistsList),
            ),
            SmallListTile(
              title: Language.inst.COMPOSER,
              active: albumsort == GroupSortType.composer,
              onTap: () => Indexer.inst.sortAlbums(sortBy: GroupSortType.composer),
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
            SmallListTile(
              title: Language.inst.ARTISTS,
              active: artistSort == GroupSortType.artistsList,
              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.artistsList),
            ),
            SmallListTile(
              title: Language.inst.COMPOSER,
              active: artistSort == GroupSortType.composer,
              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.composer),
            ),
            SmallListTile(
              title: Language.inst.NUMBER_OF_TRACKS,
              active: artistSort == GroupSortType.numberOfTracks,
              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.numberOfTracks),
            ),
            SmallListTile(
              title: Language.inst.DURATION,
              active: artistSort == GroupSortType.duration,
              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.duration),
            ),
            SmallListTile(
              title: Language.inst.GENRES,
              active: artistSort == GroupSortType.genresList,
              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.genresList),
            ),
            SmallListTile(
              title: Language.inst.ALBUM,
              active: artistSort == GroupSortType.album,
              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.album),
            ),
            SmallListTile(
              title: Language.inst.ALBUM_ARTIST,
              active: artistSort == GroupSortType.albumArtist,
              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.albumArtist),
            ),
            SmallListTile(
              title: Language.inst.YEAR,
              active: artistSort == GroupSortType.year,
              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.year),
            ),
            SmallListTile(
              title: Language.inst.DATE_MODIFIED,
              active: artistSort == GroupSortType.dateModified,
              onTap: () => Indexer.inst.sortArtists(sortBy: GroupSortType.dateModified),
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
            SmallListTile(
              title: Language.inst.GENRE,
              active: genreSort == GroupSortType.genresList,
              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.genresList),
            ),
            SmallListTile(
              title: Language.inst.DURATION,
              active: genreSort == GroupSortType.duration,
              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.duration),
            ),
            SmallListTile(
              title: Language.inst.NUMBER_OF_TRACKS,
              active: genreSort == GroupSortType.numberOfTracks,
              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.numberOfTracks),
            ),
            SmallListTile(
              title: Language.inst.YEAR,
              active: genreSort == GroupSortType.year,
              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.year),
            ),
            SmallListTile(
              title: Language.inst.ARTISTS,
              active: genreSort == GroupSortType.artistsList,
              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.artistsList),
            ),
            SmallListTile(
              title: Language.inst.ALBUM,
              active: genreSort == GroupSortType.album,
              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.album),
            ),
            SmallListTile(
              title: Language.inst.ALBUM_ARTIST,
              active: genreSort == GroupSortType.albumArtist,
              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.albumArtist),
            ),
            SmallListTile(
              title: Language.inst.DATE_MODIFIED,
              active: genreSort == GroupSortType.dateModified,
              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.dateModified),
            ),
            SmallListTile(
              title: Language.inst.COMPOSER,
              active: genreSort == GroupSortType.composer,
              onTap: () => Indexer.inst.sortGenres(sortBy: GroupSortType.composer),
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
            SmallListTile(
              title: Language.inst.DEFAULT,
              active: playlistSort == GroupSortType.defaultSort,
              onTap: () => PlaylistController.inst.sortPlaylists(sortBy: GroupSortType.defaultSort),
            ),
            SmallListTile(
              title: Language.inst.TITLE,
              active: playlistSort == GroupSortType.title,
              onTap: () => PlaylistController.inst.sortPlaylists(sortBy: GroupSortType.title),
            ),
            SmallListTile(
              title: Language.inst.YEAR,
              active: playlistSort == GroupSortType.year,
              onTap: () => PlaylistController.inst.sortPlaylists(sortBy: GroupSortType.year),
            ),
            SmallListTile(
              title: Language.inst.DURATION,
              active: playlistSort == GroupSortType.duration,
              onTap: () => PlaylistController.inst.sortPlaylists(sortBy: GroupSortType.duration),
            ),
            SmallListTile(
              title: Language.inst.NUMBER_OF_TRACKS,
              active: playlistSort == GroupSortType.numberOfTracks,
              onTap: () => PlaylistController.inst.sortPlaylists(sortBy: GroupSortType.numberOfTracks),
            ),
          ],
        );
      },
    );
  }
}
