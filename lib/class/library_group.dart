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
    mainMapStyles.update(other.mainMapStyles);
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
  final mainMapStyles = LibraryItemMap();
  final mainMapFoldersTracksAndVideos = <Folder, List<T>>{}.obs;
  final mainMapFoldersTracks = <Folder, List<T>>{}.obs;
  final mainMapFoldersVideos = <VideoFolder, List<Video>>{}.obs;

  void fillAll(List<T> allTracks, TrackExtended Function(T tr) trackToExtended, List<AlbumIdentifier> albumIdentifier) {
    final mainMapAlbums = this.mainMapAlbums.value..clear();
    final mainMapArtists = this.mainMapArtists.value..clear();
    final mainMapAlbumArtists = this.mainMapAlbumArtists.value..clear();
    final mainMapComposer = this.mainMapComposer.value..clear();
    final mainMapGenres = this.mainMapGenres.value..clear();
    final mainMapStyles = this.mainMapStyles.value..clear();
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
      for (var albumArtist in trExt.albumArtistsList) {
        mainMapAlbumArtists.addForce(albumArtist, tr);
      }

      // -- Assigning Composers
      for (var composer in trExt.composersList) {
        mainMapComposer.addForce(composer, tr);
      }

      // -- Assigning Genres
      for (var genre in trExt.genresList) {
        mainMapGenres.addForce(genre, tr);
      }

      // -- Assigning Styles
      for (var style in trExt.stylesList) {
        mainMapStyles.addForce(style, tr);
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
    this.mainMapStyles.refresh();
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
      allTracks.sortByAltsPrecomputed(allTracksSorter, reverse: reverse);
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

  /// moves [tracks] to where [mediasWithSorts] place them now, for when only their own sort keys changed.
  /// returns the medias that had a list changed.
  Set<MediaType> repositionTracksSync(
    Iterable<T> tracks,
    Map<MediaType, List<Comparable<dynamic> Function(Track)>> mediasWithSorts,
    Map<MediaType, bool> mediaItemsTrackSortingReverse,
    List<T> allTracks,
    TrackExtended Function(T tr) trackToExtended,
    List<AlbumIdentifier> albumIdentifier,
  ) {
    final changedMedias = <MediaType>{};

    for (final entry in mediasWithSorts.entries) {
      final type = entry.key;
      final sorters = entry.value;
      final sortersLength = sorters.length;
      final reverse = mediaItemsTrackSortingReverse[type] ?? false;

      // -- all are taken out before any goes back, the binary search needs the rest of the list sorted
      final insertions = <void Function()>[];

      for (final tr in tracks) {
        late final trExt = trackToExtended(tr);
        final trackKeys = [for (final sorter in sorters) sorter(tr)];

        int compareWithTrack(Track other) {
          for (int i = 0; i < sortersLength; i++) {
            final compare = sorters[i](other).compareTo(trackKeys[i]);
            if (compare != 0) return reverse ? -compare : compare;
          }
          return 0;
        }

        void takeOut<E extends Track>(List<E>? list, E track) {
          if (list == null) return;
          final didRemove = list.remove(track);
          if (didRemove) insertions.add(() => _insertSorted(list, track, compareWithTrack));
        }

        switch (type) {
          case MediaType.track:
            takeOut(allTracks, tr);
          case MediaType.album:
            for (final album in trExt.getAlbumsIdentifiersModified(albumIdentifier)) {
              takeOut(mainMapAlbums.value[album], tr);
            }
          case MediaType.artist:
            for (final artist in trExt.artistsList) {
              takeOut(mainMapArtists.value[artist], tr);
            }
          case MediaType.albumArtist:
            for (final albumArtist in trExt.albumArtistsList) {
              takeOut(mainMapAlbumArtists.value[albumArtist], tr);
            }
          case MediaType.composer:
            for (final composer in trExt.composersList) {
              takeOut(mainMapComposer.value[composer], tr);
            }
          case MediaType.genre:
            for (final genre in trExt.genresList) {
              takeOut(mainMapGenres.value[genre], tr);
            }
          case MediaType.style:
            for (final style in trExt.stylesList) {
              takeOut(mainMapStyles.value[style], tr);
            }
          case MediaType.folder:
            takeOut(mainMapFoldersTracksAndVideos.value[tr.folder], tr);
          case MediaType.folderMusic:
            if (tr is! Video) takeOut(mainMapFoldersTracks.value[tr.folder], tr);
          case MediaType.folderVideo:
            if (tr is Video) takeOut(mainMapFoldersVideos.value[tr.folder], tr);
          case MediaType.mood || MediaType.tag || MediaType.rating || MediaType.playlist:
            null;
        }
      }

      if (insertions.isEmpty) continue;
      for (final insert in insertions) {
        insert();
      }
      changedMedias.add(type);
    }

    return changedMedias;
  }

  /// [compareWithTrack] is positive when the item belongs after [track].
  static void _insertSorted<E extends Track>(List<E> list, E track, int Function(Track other) compareWithTrack) {
    int low = 0;
    int high = list.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (compareWithTrack(list[mid]) > 0) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    list.insert(low, track);
  }

  void refreshMedias(Iterable<MediaType> medias) {
    for (final e in medias) {
      _mediaTypeToRx(e)?.refresh();
    }
  }

  RxBaseCore? _mediaTypeToRx(MediaType e) {
    return switch (e) {
      MediaType.album => mainMapAlbums.rx,
      MediaType.artist => mainMapArtists.rx,
      MediaType.albumArtist => mainMapAlbumArtists.rx,
      MediaType.composer => mainMapComposer.rx,
      MediaType.genre => mainMapGenres.rx,
      MediaType.style => mainMapStyles.rx,
      MediaType.folder => mainMapFoldersTracksAndVideos,
      MediaType.folderMusic => mainMapFoldersTracks,
      MediaType.folderVideo => mainMapFoldersVideos,
      MediaType.track || MediaType.mood || MediaType.tag || MediaType.rating || MediaType.playlist => null,
    };
  }

  Iterable<List<T>>? _mediaTypeToLists(MediaType e, List<T> allTracks) {
    return switch (e) {
      MediaType.track => [allTracks],
      MediaType.album => mainMapAlbums.value.values as Iterable<List<T>>,
      MediaType.artist => mainMapArtists.value.values as Iterable<List<T>>,
      MediaType.albumArtist => mainMapAlbumArtists.value.values as Iterable<List<T>>,
      MediaType.composer => mainMapComposer.value.values as Iterable<List<T>>,
      MediaType.genre => mainMapGenres.value.values as Iterable<List<T>>,
      MediaType.style => mainMapStyles.value.values as Iterable<List<T>>,
      MediaType.folder => mainMapFoldersTracksAndVideos.values,
      MediaType.folderMusic => mainMapFoldersTracks.values,
      MediaType.folderVideo => mainMapFoldersVideos.values as Iterable<List<T>>,
      MediaType.mood => null,
      MediaType.tag => null,
      MediaType.rating => null,
      MediaType.playlist => null,
    };
  }
}
