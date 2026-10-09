// by claude
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

import 'bench_data.dart';

void main() {
  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_library_group_benchmark');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('library maps update after indexing', () async {
    final runner = BenchRunner('library_group');
    const newTracksCount = 5000;
    final synthetic = SyntheticLibrary.generate(kBenchTracksCount + newTracksCount);
    final random = Random(31);
    final extendedTracks = synthetic.map(_extendedOf).toFixedList();
    final libraryTracks = extendedTracks.take(kBenchTracksCount).map((e) => e.asTrack()).toFixedList();
    final newTracks = extendedTracks.skip(kBenchTracksCount).toFixedList();
    final editedOldSet = <TrackExtended>{};
    for (int i = 0; i < newTracksCount; i++) {
      final index = random.nextInt(kBenchTracksCount);
      editedOldSet.add(extendedTracks[index]);
    }
    final editedOld = editedOldSet.toFixedList();
    final editedNew = editedOld.map(_editedOf).toFixedList();
    final group = Indexer.inst.mainMapsGroup;

    void resetLibrary() {
      for (final e in extendedTracks) {
        Indexer.inst.allTracksMappedByPath[e.path] = e;
      }
      group.fillAll(libraryTracks, (tr) => tr.toTrackExt(), settings.albumIdentifiers.value);
    }

    void resetLibraryWithEdits() {
      resetLibrary();
      for (final e in editedNew) {
        Indexer.inst.allTracksMappedByPath[e.path] = e;
      }
    }

    Iterable<String> mapsLines() sync* {
      for (final e in group.mainMapArtists.value.entries) {
        yield 'artist|${e.key}|${e.value.map((e) => e.path).join(',')}';
      }
      for (final e in group.mainMapGenres.value.entries) {
        yield 'genre|${e.key}|${e.value.map((e) => e.path).join(',')}';
      }
      for (final e in group.mainMapAlbums.value.entries) {
        yield 'album|${e.key.album}|${e.value.map((e) => e.path).join(',')}';
      }
      for (final e in group.mainMapFoldersTracks.value.entries) {
        yield 'folder|${e.key.path}|${e.value.map((e) => e.path).join(',')}';
      }
    }

    final addedMap = {for (final e in newTracks) e: null};
    final editedMap = {for (int i = 0; i < editedNew.length; i++) editedNew[i]: editedOld[i]};
    final scenarios = [
      (name: 'add ${addedMap.length} new tracks', map: addedMap, reset: resetLibrary),
      (name: 'edit ${editedMap.length} tracks', map: editedMap, reset: resetLibraryWithEdits),
    ];
    for (final scenario in scenarios) {
      scenario.reset();
      _addTheseTracksToAlbumGenreArtistEtc(scenario.map);
      runner.digest(scenario.name, mapsLines());
      await runner.run(scenario.name, () => _addTheseTracksToAlbumGenreArtistEtc(scenario.map), setUp: scenario.reset, warmups: 1, iterations: 5);
    }
    runner.finish();
  }, timeout: Timeout.none);
}

final _separatorsRegex = RegExp(r'&|,|;|//| ft\. | x ', caseSensitive: false);

List<String> _splitOrFallback(String? text, String fallback) {
  if (text == null) return [fallback];
  final parts = text.split(_separatorsRegex).map((e) => e.trim()).where((e) => e.isNotEmpty).toFixedList();
  return parts.isEmpty ? [fallback] : parts;
}

TrackExtended _editedOf(TrackExtended e) {
  final genres = [...e.genresList, 'Edited'];
  final artists = [...e.artistsList, 'Edited Artist'];
  return e.copyWith(genresList: genres, artistsList: artists, generatePathHash: false);
}

TrackExtended _extendedOf(SyntheticTrack s) {
  final album = s.album ?? '';
  final albumArtist = s.albumArtist ?? '';
  final albums = album.isEmpty ? const <String>[] : album.split(';').map((e) => e.trim()).toFixedList();
  final title = s.title ?? s.path.getFilename;
  final originalArtist = s.artist ?? UnknownTags.ARTIST;
  final originalGenre = s.genre ?? UnknownTags.GENRE;
  final composer = s.composer ?? '';
  final yearText = s.year ?? '';
  final artists = _splitOrFallback(s.artist, UnknownTags.ARTIST);
  final albumArtists = _splitOrFallback(s.albumArtist, UnknownTags.ALBUMARTIST);
  final genres = _splitOrFallback(s.genre, UnknownTags.GENRE);
  final composers = _splitOrFallback(s.composer, UnknownTags.COMPOSER);
  final albumsWrappers = AlbumIdentifierWrapper.fromAlbums(albums: albums, albumArtist: albumArtist, year: yearText, mbAlbumId: '', mbAlbumArtistId: '');
  return kDummyExtendedTrack.copyWith(
    path: s.path,
    title: title,
    originalArtist: originalArtist,
    artistsList: artists,
    originalAlbum: album,
    albumsList: albums,
    albumArtist: albumArtist,
    albumArtistsList: albumArtists,
    originalGenre: originalGenre,
    genresList: genres,
    composer: composer,
    composersList: composers,
    yearText: yearText,
    durationMS: s.durationMS,
    dateAdded: s.dateAddedMS,
    albumsIdentifiersWrappers: albumsWrappers,
    generatePathHash: false,
  );
}

int _addTheseTracksToAlbumGenreArtistEtc(Map<TrackExtended, TrackExtended?> tracksMap) {
  final group = Indexer.inst.mainMapsGroup;
  final changes = group.updateTracksSync(tracksMap, settings.albumIdentifiers.value);
  final changedMedias = changes.changedMedias;
  final mediaSorters = {for (final e in changedMedias) e: SearchSortController.inst.getMediaTracksSortingComparables(e)};
  group.sortChangedSync(changes, mediaSorters, settings.mediaItemsTrackSortingReverse.value);
  for (final e in changedMedias) {
    SearchSortController.inst.sortMedia(e);
  }
  if (changes.hasNewKeys(MediaType.folder)) FoldersController.tracksAndVideos.onMapChanged(group.mainMapFoldersTracksAndVideos.value);
  if (changes.hasNewKeys(MediaType.folderMusic)) FoldersController.tracks.onMapChanged(group.mainMapFoldersTracks.value);
  if (changes.hasNewKeys(MediaType.folderVideo)) FoldersController.videos.onMapChanged(group.mainMapFoldersVideos.value);
  return changedMedias.length;
}
