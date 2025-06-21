import 'package:namida/class/folder.dart';
import 'package:namida/class/library_item_map.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class LibraryGroup<T extends Track> {
  bool didFill = false;

  final mainMapAlbums = LibraryItemMap();
  final mainMapArtists = LibraryItemMap();
  final mainMapAlbumArtists = LibraryItemMap();
  final mainMapComposer = LibraryItemMap();
  final mainMapGenres = LibraryItemMap();
  final mainMapFolders = <Folder, List<T>>{}.obs;
  final mainMapFoldersVideos = <VideoFolder, List<Video>>{}.obs;

  void fillAll(List<T> allTracks, TrackExtended Function(T tr) trackToExtended) {
    final mainMapAlbums = this.mainMapAlbums.value;
    final mainMapArtists = this.mainMapArtists.value;
    final mainMapAlbumArtists = this.mainMapAlbumArtists.value;
    final mainMapComposer = this.mainMapComposer.value;
    final mainMapGenres = this.mainMapGenres.value;
    final mainMapFolders = this.mainMapFolders.value;
    final mainMapFoldersVideos = this.mainMapFoldersVideos.value;

    mainMapAlbums.clear();
    mainMapArtists.clear();
    mainMapAlbumArtists.clear();
    mainMapComposer.clear();
    mainMapGenres.clear();
    mainMapFolders.clear();
    mainMapFoldersVideos.clear();

    allTracks.loop(
      (tr) {
        final trExt = trackToExtended(tr);

        // -- Assigning Albums
        mainMapAlbums.addForce(trExt.albumIdentifier, tr);

        // -- Assigning Artists
        trExt.artistsList.loop((artist) {
          mainMapArtists.addForce(artist, tr);
        });

        // -- Assigning Album Artist
        mainMapAlbumArtists.addForce(trExt.albumArtist, tr);

        // -- Assigning Composer
        mainMapComposer.addForce(trExt.composer, tr);

        // -- Assigning Genres
        trExt.genresList.loop((genre) {
          mainMapGenres.addForce(genre, tr);
        });

        // -- Assigning Folders
        tr is Video ? mainMapFoldersVideos.addForce(tr.folder, tr) : mainMapFolders.addForce(tr.folder, tr);
      },
    );

    didFill = true;
  }

  void refreshAll() {
    this.mainMapAlbums.refresh();
    this.mainMapArtists.refresh();
    this.mainMapAlbumArtists.refresh();
    this.mainMapComposer.refresh();
    this.mainMapGenres.refresh();
    this.mainMapFolders.refresh();
    this.mainMapFoldersVideos.refresh();
  }

  Future<void> sortAll(
    Map<MediaType, List<Comparable<dynamic> Function(Track)>> mediasWithSorts,
    Map<MediaType, bool> mediaItemsTrackSortingReverse,
    List<T> allTracks,
  ) async {
    for (final entry in mediasWithSorts.entries) {
      final e = entry.key;
      final sorters = entry.value;
      Future<void> sortPls<Tr extends Track>(Iterable<List<Tr>> trs, MediaType type) async {
        final reverse = mediaItemsTrackSortingReverse[type] ?? false;
        if (reverse) {
          for (final e in trs) {
            e.sortByReverseAlts(sorters);
            await Future.delayed(Duration.zero);
          }
        } else {
          for (final e in trs) {
            e.sortByAlts(sorters);
            await Future.delayed(Duration.zero);
          }
        }
      }

      final listsToSort = _mediaTypeToLists(e, allTracks);
      if (listsToSort != null) {
        await sortPls(listsToSort, e);
      }
    }
  }

  void sortAllSync(
    Map<MediaType, List<Comparable<dynamic> Function(Track)>> mediasWithSorts,
    Map<MediaType, bool> mediaItemsTrackSortingReverse,
    List<T> allTracks,
  ) async {
    for (final entry in mediasWithSorts.entries) {
      final e = entry.key;
      final sorters = entry.value;
      void sortPls<Tr extends Track>(Iterable<List<Tr>> trs, MediaType type) {
        final reverse = mediaItemsTrackSortingReverse[type] ?? false;
        if (reverse) {
          for (final e in trs) {
            e.sortByReverseAlts(sorters);
          }
        } else {
          for (final e in trs) {
            e.sortByAlts(sorters);
          }
        }
      }

      final listsToSort = _mediaTypeToLists(e, allTracks);
      if (listsToSort != null) {
        sortPls(listsToSort, e);
      }
    }
  }

  Iterable<List<Track>>? _mediaTypeToLists(MediaType e, List<T> allTracks) {
    return switch (e) {
      MediaType.track => [allTracks],
      MediaType.album => mainMapAlbums.value.values,
      MediaType.artist => mainMapArtists.value.values,
      MediaType.albumArtist => mainMapAlbumArtists.value.values,
      MediaType.composer => mainMapComposer.value.values,
      MediaType.genre => mainMapGenres.value.values,
      MediaType.folder => mainMapFolders.values,
      MediaType.folderVideo => mainMapFoldersVideos.values,
      _ => null,
    };
  }
}
