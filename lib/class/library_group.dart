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
    mainMapLanguages.update(other.mainMapLanguages);
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
  final mainMapLanguages = LibraryItemMap();
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
    final mainMapLanguages = this.mainMapLanguages.value..clear();
    final mainMapFoldersTracksAndVideos = this.mainMapFoldersTracksAndVideos.value..clear();
    final mainMapFoldersTracks = this.mainMapFoldersTracks.value..clear();
    final mainMapFoldersVideos = this.mainMapFoldersVideos.value..clear();

    for (var tr in allTracks) {
      final trExt = trackToExtended(tr);

      // -- Assigning Albums
      final identifiers = trExt.getAlbumsIdentifiersModified(albumIdentifier);
      for (var item in identifiers) {
        _addOnce(mainMapAlbums, item, tr);
      }

      // -- Assigning Artists
      for (var artist in trExt.artistsList) {
        _addOnce(mainMapArtists, artist, tr);
      }

      // -- Assigning Album Artist
      for (var albumArtist in trExt.albumArtistsList) {
        _addOnce(mainMapAlbumArtists, albumArtist, tr);
      }

      // -- Assigning Composers
      for (var composer in trExt.composersList) {
        _addOnce(mainMapComposer, composer, tr);
      }

      // -- Assigning Genres
      for (var genre in trExt.genresList) {
        _addOnce(mainMapGenres, genre, tr);
      }

      // -- Assigning Styles
      for (var style in trExt.stylesList) {
        _addOnce(mainMapStyles, style, tr);
      }

      // -- Assigning Languages
      for (var language in trExt.languagesList) {
        _addOnce(mainMapLanguages, language, tr);
      }

      // -- Assigning Folders
      final folderPath = trExt.folderPath;
      if (tr is Video) {
        final folder = VideoFolder.explicit(folderPath);
        _addOnce(mainMapFoldersVideos, folder, tr);
        _addOnce(mainMapFoldersTracksAndVideos, folder, tr);
      } else {
        final folder = Folder.explicit(folderPath);
        _addOnce(mainMapFoldersTracks, folder, tr);
        _addOnce(mainMapFoldersTracksAndVideos, folder, tr);
      }
    }

    didFill = true;
  }

  /// [track] was just added when it's the last item, keys can collapse into one list (case insensitive maps, album identifiers without the name).
  static void _addOnce<K, E>(Map<K, List<E>> map, K key, E track) {
    final list = map[key];
    if (list == null) {
      map[key] = <E>[track];
    } else if (!identical(list.last, track)) {
      list.add(track);
    }
  }

  void refreshAll() {
    this.mainMapAlbums.refresh();
    this.mainMapArtists.refresh();
    this.mainMapAlbumArtists.refresh();
    this.mainMapComposer.refresh();
    this.mainMapGenres.refresh();
    this.mainMapStyles.refresh();
    this.mainMapLanguages.refresh();
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

      final precomputedKeys = _precomputeSortKeys(sorters, allTracks);
      for (final list in lists) {
        _sortByPrecomputedKeys(list, trackIndex, precomputedKeys, reverse);
      }
    }
  }

  LibraryGroupChanges updateTracksSync(Map<TrackExtended, TrackExtended?> newOldTracks, List<AlbumIdentifier> albumIdentifier) {
    final changes = LibraryGroupChanges._();
    final mainMapAlbums = this.mainMapAlbums.value;
    final mainMapArtists = this.mainMapArtists.value;
    final mainMapAlbumArtists = this.mainMapAlbumArtists.value;
    final mainMapComposer = this.mainMapComposer.value;
    final mainMapGenres = this.mainMapGenres.value;
    final mainMapStyles = this.mainMapStyles.value;
    final mainMapLanguages = this.mainMapLanguages.value;
    final mainMapFoldersTracksAndVideos = this.mainMapFoldersTracksAndVideos.value;
    final mainMapFoldersTracks = this.mainMapFoldersTracks.value;
    final mainMapFoldersVideos = this.mainMapFoldersVideos.value;

    for (final e in newOldTracks.entries) {
      final newtr = e.key;
      final oldtr = e.value;
      final newTrack = newtr.asTrack() as T;
      final oldTrack = oldtr?.asTrack() as T?;
      final isSameTrack = newTrack == oldTrack;

      final newAlbums = newtr.getAlbumsIdentifiersModified(albumIdentifier);
      final oldAlbums = oldtr?.getAlbumsIdentifiersModified(albumIdentifier);
      changes._updateKeys(MediaType.album, mainMapAlbums, newAlbums, oldAlbums, newTrack, oldTrack, isSameTrack);
      changes._updateKeys(MediaType.artist, mainMapArtists, newtr.artistsList, oldtr?.artistsList, newTrack, oldTrack, isSameTrack);
      changes._updateKeys(MediaType.albumArtist, mainMapAlbumArtists, newtr.albumArtistsList, oldtr?.albumArtistsList, newTrack, oldTrack, isSameTrack);
      changes._updateKeys(MediaType.composer, mainMapComposer, newtr.composersList, oldtr?.composersList, newTrack, oldTrack, isSameTrack);
      changes._updateKeys(MediaType.genre, mainMapGenres, newtr.genresList, oldtr?.genresList, newTrack, oldTrack, isSameTrack);
      changes._updateKeys(MediaType.style, mainMapStyles, newtr.stylesList, oldtr?.stylesList, newTrack, oldTrack, isSameTrack);
      changes._updateKeys(MediaType.language, mainMapLanguages, newtr.languagesList, oldtr?.languagesList, newTrack, oldTrack, isSameTrack);

      final newFolder = newtr.folder;
      final oldFolder = oldtr?.folder;
      changes._updateKey(MediaType.folder, mainMapFoldersTracksAndVideos, newFolder, oldFolder, newTrack, oldTrack, isSameTrack);

      final Video? newVideo = newTrack is Video ? newTrack : null;
      final Video? oldVideo = oldTrack is Video ? oldTrack : null;
      final newVideoFolder = newFolder is VideoFolder ? newFolder : null;
      final oldVideoFolder = oldFolder is VideoFolder ? oldFolder : null;
      changes._updateKey(MediaType.folderVideo, mainMapFoldersVideos, newVideoFolder, oldVideoFolder, newVideo, oldVideo, isSameTrack);

      final T? newMusic = newVideo == null ? newTrack : null;
      final T? oldMusic = oldVideo == null ? oldTrack : null;
      final newMusicFolder = newMusic == null ? null : newFolder;
      final oldMusicFolder = oldMusic == null ? null : oldFolder;
      changes._updateKey(MediaType.folderMusic, mainMapFoldersTracks, newMusicFolder, oldMusicFolder, newMusic, oldMusic, isSameTrack);
    }

    changes._longListsSets.clear();
    return changes;
  }

  void sortChangedSync(
    LibraryGroupChanges changes,
    Map<MediaType, List<Comparable<dynamic> Function(Track)>> mediasWithSorts,
    Map<MediaType, bool> mediaItemsTrackSortingReverse,
  ) {
    for (final entry in changes._modifiedKeys.entries) {
      final type = entry.key;
      final sorters = mediasWithSorts[type];
      final map = _mediaTypeToMap(type);
      if (sorters == null || map == null) continue;
      final reverse = mediaItemsTrackSortingReverse[type] ?? false;

      final lists = <List<Track>>[];
      final affectedTracks = <Track>[];
      final trackIndex = <Track, int>{};
      for (final key in entry.value) {
        final list = map[key];
        if (list == null) continue;
        lists.add(list);
        for (final track in list) {
          if (trackIndex.containsKey(track)) continue;
          trackIndex[track] = affectedTracks.length;
          affectedTracks.add(track);
        }
      }

      final precomputedKeys = _precomputeSortKeys(sorters, affectedTracks);
      for (final list in lists) {
        _sortByPrecomputedKeys(list, trackIndex, precomputedKeys, reverse);
      }
    }
  }

  static List<List<Comparable<dynamic>>> _precomputeSortKeys(List<Comparable<dynamic> Function(Track)> sorters, List<Track> tracks) {
    final tracksLength = tracks.length;
    return List.generate(
      sorters.length,
      (sorterIndex) => List.generate(
        tracksLength,
        (trackIndex) => sorters[sorterIndex](tracks[trackIndex]),
        growable: false,
      ),
      growable: false,
    );
  }

  static void _sortByPrecomputedKeys<E extends Track>(List<E> list, Map<Track, int> trackIndex, List<List<Comparable<dynamic>>> precomputedKeys, bool reverse) {
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
          case MediaType.language:
            for (final language in trExt.languagesList) {
              takeOut(mainMapLanguages.value[language], tr);
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
      MediaType.language => mainMapLanguages.rx,
      MediaType.folder => mainMapFoldersTracksAndVideos,
      MediaType.folderMusic => mainMapFoldersTracks,
      MediaType.folderVideo => mainMapFoldersVideos,
      MediaType.track || MediaType.mood || MediaType.tag || MediaType.rating || MediaType.playlist => null,
    };
  }

  Map<Object?, List<Track>>? _mediaTypeToMap(MediaType e) {
    return switch (e) {
      MediaType.album => mainMapAlbums.value,
      MediaType.artist => mainMapArtists.value,
      MediaType.albumArtist => mainMapAlbumArtists.value,
      MediaType.composer => mainMapComposer.value,
      MediaType.genre => mainMapGenres.value,
      MediaType.style => mainMapStyles.value,
      MediaType.language => mainMapLanguages.value,
      MediaType.folder => mainMapFoldersTracksAndVideos.value,
      MediaType.folderMusic => mainMapFoldersTracks.value,
      MediaType.folderVideo => mainMapFoldersVideos.value,
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
      MediaType.language => mainMapLanguages.value.values as Iterable<List<T>>,
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

class LibraryGroupChanges {
  final _modifiedKeys = <MediaType, Set<Object?>>{};
  final _mediasWithNewKeys = <MediaType>{};

  /// a batch edit can move many tracks into one long list, its set is built once instead of a scan per track.
  static const _kLongListMinLength = 32;
  final _longListsSets = Map<List<Object?>, Set<Object?>>.identity();

  LibraryGroupChanges._();

  Iterable<MediaType> get changedMedias => _modifiedKeys.keys;

  bool hasNewKeys(MediaType media) => _mediasWithNewKeys.contains(media);

  /// removals go first, so a case only rename isn't skipped by the case insensitive maps.
  void _updateKeys<K, E>(MediaType type, Map<K, List<E>> map, List<K> newKeys, List<K>? oldKeys, E newTrack, E? oldTrack, bool isSameTrack) {
    if (oldKeys == null || oldTrack == null) {
      for (final key in newKeys) {
        _addNew(type, map, key, newTrack);
      }
      return;
    }
    final keptKeys = isSameTrack ? oldKeys : null;
    for (final key in oldKeys) {
      if (keptKeys != null && newKeys.contains(key)) continue;
      _remove(type, map, key, oldTrack);
    }
    for (final key in newKeys) {
      if (keptKeys != null && keptKeys.contains(key)) continue;
      _add(type, map, key, newTrack);
    }
  }

  void _updateKey<K, E>(MediaType type, Map<K, List<E>> map, K? newKey, K? oldKey, E? newTrack, E? oldTrack, bool isSameTrack) {
    if (isSameTrack && newKey == oldKey) return;
    if (oldKey != null && oldTrack != null) _remove(type, map, oldKey, oldTrack);
    if (newKey == null || newTrack == null) return;
    if (oldTrack == null) {
      _addNew(type, map, newKey, newTrack);
    } else {
      _add(type, map, newKey, newTrack);
    }
  }

  void _remove<K, E>(MediaType type, Map<K, List<E>> map, K key, E track) {
    final list = map[key];
    if (list == null || !list.remove(track)) return;
    _longListsSets[list]?.remove(track);
    if (list.isEmpty) {
      map.remove(key);
      (_modifiedKeys[type] ??= <Object?>{}).add(key);
    }
  }

  void _add<K, E>(MediaType type, Map<K, List<E>> map, K key, E track) {
    final list = map[key];
    if (list == null) {
      map[key] = <E>[track];
      _mediasWithNewKeys.add(type);
    } else {
      final listTracks = _longListsSets[list] ?? _createLongListSet(list);
      if (listTracks == null) {
        if (list.contains(track)) return;
      } else if (!listTracks.add(track)) {
        return;
      }
      list.add(track);
    }
    (_modifiedKeys[type] ??= <Object?>{}).add(key);
  }

  /// a list that shrinks back under the limit keeps its set, so every later add still goes through it.
  Set<Object?>? _createLongListSet(List<Object?> list) {
    if (list.length < _kLongListMinLength) return null;
    final listTracks = Set<Object?>.of(list);
    _longListsSets[list] = listTracks;
    return listTracks;
  }

  /// a new track is in no list yet, it can only meet itself when its keys collapse into one list.
  void _addNew<K, E>(MediaType type, Map<K, List<E>> map, K key, E track) {
    final list = map[key];
    if (list == null) {
      map[key] = <E>[track];
      _mediasWithNewKeys.add(type);
    } else {
      if (identical(list.last, track)) return;
      list.add(track);
    }
    (_modifiedKeys[type] ??= <Object?>{}).add(key);
  }
}
