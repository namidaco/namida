import 'package:namida/class/folder.dart';
import 'package:namida/class/library_item_map.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class LibraryGroup<T extends Track> {
  bool didFill = false;

  void updateFrom(LibraryGroup other) {
    mainMapAlbums.update(other.mainMapAlbums);
    mainMapArtists.update(other.mainMapArtists);
    mainMapAlbumArtists.update(other.mainMapAlbumArtists);
    mainMapComposer.update(other.mainMapComposer);
    mainMapGenres.update(other.mainMapGenres);
    mainMapFoldersTracksAndVideos.value = other.mainMapFoldersTracksAndVideos.value as Map<Folder, List<T>>;
    mainMapFoldersTracks.value = other.mainMapFoldersTracks.value as Map<Folder, List<T>>;
    mainMapFoldersVideos.value = other.mainMapFoldersVideos.value;

    didFill = other.didFill;
  }

  final mainMapAlbums = LibraryItemMapRaw<AlbumIdentifierWrapper>(equals: (item1, item2) => item1 == item2, hashCode: (p0) => p0.hashCode);
  final mainMapArtists = LibraryItemMap();
  final mainMapAlbumArtists = LibraryItemMap();
  final mainMapComposer = LibraryItemMap();
  final mainMapGenres = LibraryItemMap();
  final mainMapFoldersTracksAndVideos = <Folder, List<T>>{}.obs;
  final mainMapFoldersTracks = <Folder, List<T>>{}.obs;
  final mainMapFoldersVideos = <VideoFolder, List<Video>>{}.obs;

  void fillAll(List<T> allTracks, TrackExtended Function(T tr) trackToExtended, List<AlbumIdentifier> albumIdentifier) {
    final mainMapAlbums = this.mainMapAlbums.value..clear();
    final mainMapArtists = this.mainMapArtists.value..clear();
    final mainMapAlbumArtists = this.mainMapAlbumArtists.value..clear();
    final mainMapComposer = this.mainMapComposer.value..clear();
    final mainMapGenres = this.mainMapGenres.value..clear();
    final mainMapFoldersTracksAndVideos = this.mainMapFoldersTracksAndVideos.value..clear();
    final mainMapFoldersTracks = this.mainMapFoldersTracks.value..clear();
    final mainMapFoldersVideos = this.mainMapFoldersVideos.value..clear();

    for (var tr in allTracks) {
      final trExt = trackToExtended(tr);

      // -- Assigning Albums
      final identifiers = trExt.getAlbumsIdentifiersModified(albumIdentifier);
      for (var item in identifiers) {
        mainMapAlbums.addForce(item, tr);
      }

      // -- Assigning Artists
      for (var artist in trExt.artistsList) {
        mainMapArtists.addForce(artist, tr);
      }

      // -- Assigning Album Artist
      mainMapAlbumArtists.addForce(trExt.albumArtist, tr);

      // -- Assigning Composer
      mainMapComposer.addForce(trExt.composer, tr);

      // -- Assigning Genres
      for (var genre in trExt.genresList) {
        mainMapGenres.addForce(genre, tr);
      }

      // -- Assigning Folders
      if (tr is Video) {
        final folder = tr.folder;
        mainMapFoldersVideos.addForce(folder, tr);
        mainMapFoldersTracksAndVideos.addForce(folder, tr);
      } else {
        final folder = tr.folder;
        mainMapFoldersTracks.addForce(folder, tr);
        mainMapFoldersTracksAndVideos.addForce(folder, tr);
      }
    }

    didFill = true;
  }

  void refreshAll() {
    this.mainMapAlbums.refresh();
    this.mainMapArtists.refresh();
    this.mainMapAlbumArtists.refresh();
    this.mainMapComposer.refresh();
    this.mainMapGenres.refresh();
    this.mainMapFoldersTracksAndVideos.refresh();
    this.mainMapFoldersTracks.refresh();
    this.mainMapFoldersVideos.refresh();
  }

  void sortAllSync(
    Map<MediaType, List<Comparable<dynamic> Function(Track)>> mediasWithSorts,
    Map<MediaType, bool> mediaItemsTrackSortingReverse,
    List<T> allTracks,
  ) {
    final allTracksSorter = mediasWithSorts[MediaType.track];
    if (allTracksSorter != null) {
      final reverse = mediaItemsTrackSortingReverse[MediaType.track] ?? false;
      reverse ? allTracks.sortByReverseAlts(allTracksSorter) : allTracks.sortByAlts(allTracksSorter);
    }

    final allTracksLength = allTracks.length;
    final trackIndex = <T, int>{};
    for (int i = 0; i < allTracksLength; i++) {
      trackIndex[allTracks[i]] = i;
    }

    for (final entry in mediasWithSorts.entries) {
      final type = entry.key;
      final sorters = entry.value;
      final reverse = mediaItemsTrackSortingReverse[type] ?? false;

      if (type == MediaType.track) {
        // -- already sorted early
        continue;
      }

      final lists = _mediaTypeToLists(type, allTracks);
      if (lists == null) continue;

      final precomputedKeys = List.generate(
        sorters.length,
        (sorterIndex) => List.generate(
          allTracksLength,
          (trackIndex) => sorters[sorterIndex](allTracks[trackIndex]),
          growable: false,
        ),
        growable: false,
      );

      for (final list in lists) {
        if (reverse) {
          list.sort((a, b) {
            final aIndex = trackIndex[a]!;
            final bIndex = trackIndex[b]!;
            for (final key in precomputedKeys) {
              final cmp = key[bIndex].compareTo(key[aIndex]);
              if (cmp != 0) return cmp;
            }
            return 0;
          });
        } else {
          list.sort((a, b) {
            final aIndex = trackIndex[a]!;
            final bIndex = trackIndex[b]!;
            for (final key in precomputedKeys) {
              final cmp = key[aIndex].compareTo(key[bIndex]);
              if (cmp != 0) return cmp;
            }
            return 0;
          });
        }
      }
    }
  }

  Iterable<List<T>>? _mediaTypeToLists(MediaType e, List<T> allTracks) {
    return switch (e) {
      MediaType.track => [allTracks],
      MediaType.album => mainMapAlbums.value.values as Iterable<List<T>>,
      MediaType.artist => mainMapArtists.value.values as Iterable<List<T>>,
      MediaType.albumArtist => mainMapAlbumArtists.value.values as Iterable<List<T>>,
      MediaType.composer => mainMapComposer.value.values as Iterable<List<T>>,
      MediaType.genre => mainMapGenres.value.values as Iterable<List<T>>,
      MediaType.folder => mainMapFoldersTracksAndVideos.values,
      MediaType.folderMusic => mainMapFoldersTracks.values,
      MediaType.folderVideo => mainMapFoldersVideos.values as Iterable<List<T>>,
      MediaType.mood => null,
      MediaType.tag => null,
      MediaType.playlist => null,
    };
  }
}
