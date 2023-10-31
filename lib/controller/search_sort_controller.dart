import 'dart:io';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';

class SearchSortController {
  static SearchSortController get inst => _instance;
  static final SearchSortController _instance = SearchSortController._internal();
  SearchSortController._internal();

  String lastSearchText = '';

  bool get isSearching => (trackSearchTemp.isNotEmpty ||
      albumSearchTemp.isNotEmpty ||
      artistSearchTemp.isNotEmpty ||
      genreSearchTemp.isNotEmpty ||
      playlistSearchTemp.isNotEmpty ||
      folderSearchTemp.isNotEmpty);

  final RxList<Track> trackSearchList = <Track>[].obs;
  final RxList<String> playlistSearchList = <String>[].obs;
  RxList<String> get albumSearchList => _searchMap[MediaType.album]!;
  RxList<String> get artistSearchList => _searchMap[MediaType.artist]!;
  RxList<String> get genreSearchList => _searchMap[MediaType.genre]!;

  final _searchMap = <MediaType, RxList<String>>{
    MediaType.album: <String>[].obs,
    MediaType.artist: <String>[].obs,
    MediaType.genre: <String>[].obs,
  };

  // -- Temporary lists, used for global search --
  final _searchMapTemp = <MediaType, RxList<String>>{
    MediaType.album: <String>[].obs,
    MediaType.artist: <String>[].obs,
    MediaType.genre: <String>[].obs,
    MediaType.folder: <String>[].obs,
  };

  final trackSearchTemp = <Track>[].obs;
  final playlistSearchTemp = <String>[].obs;
  RxList<String> get albumSearchTemp => _searchMapTemp[MediaType.album]!;
  RxList<String> get artistSearchTemp => _searchMapTemp[MediaType.artist]!;
  RxList<String> get genreSearchTemp => _searchMapTemp[MediaType.genre]!;
  RxList<String> get folderSearchTemp => _searchMapTemp[MediaType.folder]!;

  RxList<Track> get tracksInfoList => Indexer.inst.tracksInfoList;

  Rx<Map<String, List<Track>>> get mainMapAlbums => Indexer.inst.mainMapAlbums;
  Rx<Map<String, List<Track>>> get mainMapArtists => Indexer.inst.mainMapArtists;
  Rx<Map<String, List<Track>>> get mainMapGenres => Indexer.inst.mainMapGenres;
  Map<String, List<Track>> get mainMapFolder {
    return Indexer.inst.mainMapFolders.map((key, value) => MapEntry(key.path.getDirectoryName, value));
  }

  RxMap<String, Playlist> get playlistsMap => PlaylistController.inst.playlistsMap;

  void searchAll(String text) {
    lastSearchText = text;
    _searchTracks(text, temp: true);
    _searchMediaType(type: MediaType.album, text: text, temp: true);
    _searchMediaType(type: MediaType.artist, text: text, temp: true);
    _searchMediaType(type: MediaType.genre, text: text, temp: true);
    _searchPlaylists(text, temp: true);
    _searchMediaType(type: MediaType.folder, text: text, temp: true);
  }

  void searchMedia(String text, MediaType? media) {
    switch (media) {
      case MediaType.track:
        _searchTracks(text);
        break;
      case MediaType.album:
        _searchMediaType(type: MediaType.album, text: text);
        break;
      case MediaType.artist:
        _searchMediaType(type: MediaType.artist, text: text);
        break;
      case MediaType.genre:
        _searchMediaType(type: MediaType.genre, text: text);
        break;
      case MediaType.playlist:
        _searchPlaylists(text);
        break;

      default:
        null;
    }
  }

  List<Comparable Function(Track tr)> getMediaTracksSortingComparables(MediaType media) {
    final sorts = settings.mediaItemsTrackSorting[media] ?? <SortType>[SortType.title];

    final map = <SortType, Comparable Function(Track e)>{
      SortType.title: (e) => e.title.toLowerCase(),
      SortType.album: (e) => e.album.toLowerCase(),
      SortType.albumArtist: (e) => e.albumArtist.toLowerCase(),
      SortType.year: (e) => e.yearPreferyyyyMMdd,
      SortType.artistsList: (e) => e.artistsList.join().toLowerCase(),
      SortType.genresList: (e) => e.genresList.join().toLowerCase(),
      SortType.dateAdded: (e) => e.dateAdded,
      SortType.dateModified: (e) => e.dateModified,
      SortType.bitrate: (e) => e.bitrate,
      SortType.composer: (e) => e.composer.toLowerCase(),
      SortType.trackNo: (e) => e.trackNo,
      SortType.discNo: (e) => e.discNo,
      SortType.filename: (e) => e.filename.toLowerCase(),
      SortType.duration: (e) => e.duration,
      SortType.sampleRate: (e) => e.sampleRate,
      SortType.size: (e) => e.size,
      SortType.rating: (e) => e.stats.rating,
    };
    final l = <Comparable Function(Track e)>[];
    sorts.loop((e, index) {
      if (map[e] != null) l.add(map[e]!);
    });
    return l;
  }

  void _searchTracks(String text, {bool temp = false}) async {
    if (text == '') {
      if (temp) {
        trackSearchTemp.clear();
      } else {
        LibraryTab.tracks.textSearchController?.clear();
        trackSearchList.assignAll(tracksInfoList);
      }

      return;
    }

    final tsf = settings.trackSearchFilter;
    final cleanup = settings.enableSearchCleanup.value;

    final map = Indexer.inst.allTracksMappedByPath.map((key, value) {
      final artistsList = Indexer.splitArtist(
        title: value.title,
        originalArtist: value.originalArtist,
        config: ArtistsSplitConfig.settings(),
      );
      final genresList = Indexer.splitGenre(
        value.originalGenre,
        config: GenresSplitConfig.settings(),
      );
      final valueMap = value.toJson();
      valueMap['artistsList'] = artistsList;
      valueMap['genresList'] = genresList;
      return MapEntry(key, valueMap);
    }); // ~0.000010 second

    final result = await _searchTracksIsolate.thready({
      'tsf': tsf.toList(),
      'cleanup': cleanup,
      'tracks': map,
      'text': text,
    });
    final finalList = temp ? trackSearchTemp : trackSearchList;

    finalList
      ..clear()
      ..addAll(result);

    printy("Search Tracks Found: ${finalList.length}");
  }

  void _searchMediaType({required MediaType type, required String text, bool temp = false}) async {
    Iterable<String> keys = [];
    switch (type) {
      case MediaType.album:
        keys = mainMapAlbums.value.keys;
      case MediaType.artist:
        keys = mainMapArtists.value.keys;
      case MediaType.genre:
        keys = mainMapGenres.value.keys;
      case MediaType.folder:
        keys = mainMapFolder.keys;
      default:
        null;
    }

    if (text == '') {
      if (temp) {
        _searchMapTemp[type]?.clear();
      } else {
        type.toLibraryTab()?.textSearchController?.clear();
        _searchMap[type]
          ?..clear()
          ..addAll(keys);
      }
      return;
    }

    final parameter = {
      'keys': keys,
      'cleanup': _shouldCleanup,
      'text': text,
      'keyIsPath': type == MediaType.folder,
    };
    final results = await _generalSearchIsolate.thready(parameter);

    if (temp) {
      _searchMapTemp[type]
        ?..clear()
        ..addAll(results);
    } else {
      _searchMap[type]
        ?..clear()
        ..addAll(results);
    }
  }

  void _searchPlaylists(String text, {bool temp = false}) async {
    if (text == '') {
      if (temp) {
        playlistSearchTemp.clear();
      } else {
        LibraryTab.playlists.textSearchController?.clear();
        playlistSearchList
          ..clear()
          ..addAll(playlistsMap.keys);
      }
      return;
    }

    // TODO(MSOB7YY): expose in settings
    final psf = settings.playlistSearchFilter;

    final cleanupFunction = _functionOfCleanup(_shouldCleanup);
    String textCleanedForSearch(String textToClean) => cleanupFunction(textToClean);

    final sTitle = psf.contains('name');
    final sCreationDate = psf.contains('creationDate');
    final sModifiedDate = psf.contains('modifiedDate');
    final sComment = psf.contains('comment');
    final sMoods = psf.contains('moods');
    final formatDate = DateFormat('yyyyMMdd');

    final results = playlistsMap.entries.where((e) {
      final playlistName = e.key;
      final item = e.value;

      final lctext = textCleanedForSearch(text);
      final dateCreatedFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(item.creationDate));
      final dateModifiedFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(item.modifiedDate));

      return (sTitle && textCleanedForSearch(playlistName.translatePlaylistName()).contains(lctext)) ||
          (sCreationDate && textCleanedForSearch(dateCreatedFormatted.toString()).contains(lctext)) ||
          (sModifiedDate && textCleanedForSearch(dateModifiedFormatted.toString()).contains(lctext)) ||
          (sComment && textCleanedForSearch(item.comment).contains(lctext)) ||
          (sMoods && item.moods.any((element) => textCleanedForSearch(element).contains(lctext)));
    });

    final playlists = results.map((e) => e.key);

    if (temp) {
      playlistSearchTemp
        ..clear()
        ..addAll(playlists);
    } else {
      playlistSearchList
        ..clear()
        ..addAll(playlists);
    }
  }

  void sortAll() {
    _sortTracks();
    _sortAlbums();
    _sortArtists();
    _sortGenres();
    _sortPlaylists();
  }

  void sortMedia(MediaType media, {SortType? sortBy, GroupSortType? groupSortBy, bool? reverse}) {
    switch (media) {
      case MediaType.track:
        _sortTracks(sortBy: sortBy, reverse: reverse);
        break;
      case MediaType.album:
        _sortAlbums(sortBy: groupSortBy, reverse: reverse);
        break;
      case MediaType.artist:
        _sortArtists(sortBy: groupSortBy, reverse: reverse);
        break;
      case MediaType.genre:
        _sortGenres(sortBy: groupSortBy, reverse: reverse);
        break;
      case MediaType.playlist:
        _sortPlaylists(sortBy: groupSortBy, reverse: reverse);
        break;

      default:
        null;
    }
  }

  /// Sorts Tracks and Saves automatically to settings
  void _sortTracks({SortType? sortBy, bool? reverse}) {
    sortBy ??= settings.tracksSort.value;
    reverse ??= settings.tracksSortReversed.value;

    void sortThis(Comparable Function(Track e) comparable) => reverse! ? tracksInfoList.sortByReverse(comparable) : tracksInfoList.sortBy(comparable);
    void sortThisAlts(List<Comparable<dynamic> Function(Track tr)> alternatives) =>
        reverse! ? tracksInfoList.sortByReverseAlts(alternatives) : tracksInfoList.sortByAlts(alternatives);

    final sameAlbumSorters = getMediaTracksSortingComparables(MediaType.album);
    final sameArtistSorters = getMediaTracksSortingComparables(MediaType.artist);
    final sameGenreSorters = getMediaTracksSortingComparables(MediaType.genre);
    switch (sortBy) {
      case SortType.title:
        sortThis((e) => e.title.toLowerCase());
      case SortType.album:
        sortThisAlts(
          [
            (tr) => tr.album.toLowerCase(),
            ...sameAlbumSorters,
          ],
        );
        break;
      case SortType.albumArtist:
        sortThisAlts(
          [
            (tr) => tr.albumArtist.toLowerCase(),
            ...sameAlbumSorters,
          ],
        );
        break;
      case SortType.year:
        sortThis((e) => e.yearPreferyyyyMMdd);
        break;
      case SortType.artistsList:
        sortThisAlts(
          [
            (tr) => tr.artistsList.join().toLowerCase(),
            ...sameArtistSorters,
          ],
        );
        break;
      case SortType.genresList:
        sortThisAlts(
          [
            (tr) => tr.genresList.join().toLowerCase(),
            ...sameGenreSorters,
          ],
        );
        break;
      case SortType.dateAdded:
        sortThis((e) => e.dateAdded);
        break;
      case SortType.dateModified:
        sortThis((e) => e.dateModified);
        break;
      case SortType.bitrate:
        sortThis((e) => e.bitrate);
        break;
      case SortType.composer:
        sortThis((e) => e.composer.toLowerCase());
        break;
      case SortType.trackNo:
        sortThis((e) => e.trackNo);
        break;
      case SortType.discNo:
        sortThis((e) => e.discNo);
        break;
      case SortType.filename:
        sortThis((e) => e.filename.toLowerCase());
        break;
      case SortType.duration:
        sortThis((e) => e.duration);
        break;
      case SortType.sampleRate:
        sortThis((e) => e.sampleRate);
        break;
      case SortType.size:
        sortThis((e) => e.size);
        break;
      case SortType.rating:
        sortThis((e) => e.stats.rating);
        break;
      case SortType.shuffle:
        tracksInfoList.shuffle();
        break;

      default:
        null;
    }

    settings.save(tracksSort: sortBy, tracksSortReversed: reverse);
    _searchTracks(LibraryTab.tracks.textSearchController?.text ?? '');
  }

  /// Sorts Albums and Saves automatically to settings
  void _sortAlbums({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= settings.albumSort.value;
    reverse ??= settings.albumSortReversed.value;

    final albumsList = mainMapAlbums.value.entries.toList();
    void sortThis(Comparable Function(MapEntry<String, List<Track>> e) comparable) => reverse! ? albumsList.sortByReverse(comparable) : albumsList.sortBy(comparable);

    switch (sortBy) {
      case GroupSortType.album:
        sortThis((e) => e.key.toLowerCase());
        break;
      case GroupSortType.albumArtist:
        sortThis((e) => e.value.albumArtist.toLowerCase());
        break;
      case GroupSortType.year:
        sortThis((e) => e.value.yearPreferyyyyMMdd);
        break;
      case GroupSortType.artistsList:
        sortThis((e) => e.value.first.artistsList.join().toLowerCase());
        break;
      case GroupSortType.composer:
        sortThis((e) => e.value.composer.toLowerCase());
        break;
      case GroupSortType.dateModified:
        sortThis((e) => e.value.first.dateModified);
        break;
      case GroupSortType.duration:
        sortThis((e) => e.value.totalDurationInS);
        break;
      case GroupSortType.numberOfTracks:
        sortThis((e) => e.value.length);
        break;
      case GroupSortType.shuffle:
        albumsList.shuffle();
        break;

      default:
        null;
    }

    mainMapAlbums.value
      ..clear()
      ..addEntries(albumsList);

    settings.save(albumSort: sortBy, albumSortReversed: reverse);

    _searchMediaType(type: MediaType.album, text: LibraryTab.albums.textSearchController?.text ?? '');
  }

  /// Sorts Artists and Saves automatically to settings
  void _sortArtists({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= settings.artistSort.value;
    reverse ??= settings.artistSortReversed.value;

    final artistsList = mainMapArtists.value.entries.toList();
    void sortThis(Comparable Function(MapEntry<String, List<Track>> e) comparable) => reverse! ? artistsList.sortByReverse(comparable) : artistsList.sortBy(comparable);

    switch (sortBy) {
      case GroupSortType.album:
        sortThis((e) => e.value.album.toLowerCase());
        break;
      case GroupSortType.albumArtist:
        sortThis((e) => e.value.albumArtist.toLowerCase());
        break;
      case GroupSortType.year:
        sortThis((e) => e.value.yearPreferyyyyMMdd);
        break;
      case GroupSortType.artistsList:
        sortThis((e) => e.key.toLowerCase());
        break;
      case GroupSortType.genresList:
        sortThis((e) => e.value[0].genresList.join().toLowerCase());
        break;
      case GroupSortType.composer:
        sortThis((e) => e.value.composer.toLowerCase());
        break;
      case GroupSortType.dateModified:
        sortThis((e) => e.value[0].dateModified);
        break;
      case GroupSortType.duration:
        sortThis((e) => e.value.totalDurationInS);
        break;
      case GroupSortType.numberOfTracks:
        sortThis((e) => e.value.length);
        break;
      case GroupSortType.albumsCount:
        sortThis((e) => e.key.getArtistAlbums().length);
        break;
      case GroupSortType.shuffle:
        artistsList.shuffle();
        break;
      default:
        null;
    }
    mainMapArtists.value
      ..clear()
      ..addEntries(artistsList);

    settings.save(artistSort: sortBy, artistSortReversed: reverse);

    _searchMediaType(type: MediaType.artist, text: LibraryTab.artists.textSearchController?.text ?? '');
  }

  /// Sorts Genres and Saves automatically to settings
  void _sortGenres({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= settings.genreSort.value;
    reverse ??= settings.genreSortReversed.value;

    final genresList = mainMapGenres.value.entries.toList();
    void sortThis(Comparable Function(MapEntry<String, List<Track>> e) comparable) => reverse! ? genresList.sortByReverse(comparable) : genresList.sortBy(comparable);

    switch (sortBy) {
      case GroupSortType.album:
        sortThis((e) => e.value.album.toLowerCase());
        break;
      case GroupSortType.albumArtist:
        sortThis((e) => e.value.albumArtist.toLowerCase());
        break;
      case GroupSortType.year:
        sortThis((e) => e.value.yearPreferyyyyMMdd);
        break;
      case GroupSortType.artistsList:
        sortThis((e) => e.value[0].artistsList.join().toLowerCase());
        break;
      case GroupSortType.genresList:
        sortThis((e) => e.value[0].genresList.join().toLowerCase());
        break;
      case GroupSortType.composer:
        sortThis((e) => e.value.composer.toLowerCase());
        break;
      case GroupSortType.dateModified:
        sortThis((e) => e.value[0].dateModified);
        break;
      case GroupSortType.duration:
        sortThis((e) => e.value.totalDurationInS);
        break;
      case GroupSortType.numberOfTracks:
        sortThis((e) => e.value.length);
        break;
      case GroupSortType.shuffle:
        genresList.shuffle();
        break;
      default:
        null;
    }

    mainMapGenres.value
      ..clear()
      ..addEntries(genresList);

    settings.save(genreSort: sortBy, genreSortReversed: reverse);
    _searchMediaType(type: MediaType.genre, text: LibraryTab.genres.textSearchController?.text ?? '');
  }

  /// Sorts Playlists and Saves automatically to settings
  void _sortPlaylists({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= settings.playlistSort.value;
    reverse ??= settings.playlistSortReversed.value;

    final playlistList = playlistsMap.entries.toList();
    void sortThis(Comparable Function(MapEntry<String, Playlist> p) comparable) => reverse! ? playlistList.sortByReverse(comparable) : playlistList.sortBy(comparable);

    switch (sortBy) {
      case GroupSortType.title:
        sortThis((p) => p.key.translatePlaylistName().toLowerCase());
        break;
      case GroupSortType.creationDate:
        sortThis((p) => p.value.creationDate);
        break;
      case GroupSortType.modifiedDate:
        sortThis((p) => p.value.modifiedDate);
        break;
      case GroupSortType.duration:
        sortThis((p) => p.value.tracks.totalDurationInS);
        break;
      case GroupSortType.numberOfTracks:
        sortThis((p) => p.value.tracks.length);
        break;
      case GroupSortType.shuffle:
        playlistList.shuffle();
        break;

      default:
        null;
    }

    playlistsMap
      ..clear()
      ..addEntries(playlistList);

    settings.save(playlistSort: sortBy, playlistSortReversed: reverse);

    _searchPlaylists(LibraryTab.playlists.textSearchController?.text ?? '');
  }

  static List<Track> _searchTracksIsolate(Map parameters) {
    final tsf = parameters['tsf'] as List<TrackSearchFilter>;
    final cleanup = parameters['cleanup'] as bool;
    final tracks = parameters['tracks'] as Map<Track, Map<String, dynamic>>;
    final text = parameters['text'] as String;

    final function = _functionOfCleanup(cleanup);
    String textCleanedForSearch(String textToClean) => function(textToClean);

    bool hasF(TrackSearchFilter f) => tsf.contains(f);

    final finalList = <Track>[];

    // -- well i dont think we need the overhead of converting the map into a TrackExtended Object.
    // -- we'll just access the map values.
    for (final entry in tracks.entries) {
      final trExt = entry.value;
      final lctext = textCleanedForSearch(text);

      if ((hasF(TrackSearchFilter.title) && textCleanedForSearch(trExt['title'] as String).contains(lctext)) ||
          (hasF(TrackSearchFilter.filename) && textCleanedForSearch((trExt['path'] as String).getFilename).contains(lctext)) ||
          (hasF(TrackSearchFilter.album) && textCleanedForSearch(trExt['album'] as String).contains(lctext)) ||
          (hasF(TrackSearchFilter.albumartist) && textCleanedForSearch(trExt['albumArtist'] as String).contains(lctext)) ||
          (hasF(TrackSearchFilter.artist) && (trExt['artistsList'] as List<String>).any((element) => textCleanedForSearch(element).contains(lctext))) ||
          (hasF(TrackSearchFilter.genre) && (trExt['genresList'] as List<String>).any((element) => textCleanedForSearch(element).contains(lctext))) ||
          (hasF(TrackSearchFilter.composer) && textCleanedForSearch(trExt['composer'] as String).contains(lctext)) ||
          (hasF(TrackSearchFilter.year) && textCleanedForSearch((trExt['year'] as int).toString()).contains(lctext))) {
        finalList.add(entry.key);
      }
    }

    // tracks.loop((tr, index) {

    // });
    return finalList;
  }

  // static Iterable<MapEntry<String, Playlist>> _searchPlaylistsIsolate(Map parameters) {
  //   final psf = parameters['psf'] as List<String>;
  //   final cleanup = parameters['cleanup'] as bool;
  //   final playlists = parameters['playlists'] as Map<String, Playlist>;
  //   final text = parameters['text'] as String;

  //   final cleanupFunction = _functionOfCleanup(cleanup);
  //   String textCleanedForSearch(String textToClean) => cleanupFunction(textToClean);

  //   final sTitle = psf.contains('name');
  //   final sCreationDate = psf.contains('creationDate');
  //   final sModifiedDate = psf.contains('modifiedDate');
  //   final sComment = psf.contains('comment');
  //   final sMoods = psf.contains('moods');
  //   final formatDate = DateFormat('yyyyMMdd');

  //   final results = playlists.entries.where((e) {
  //     final playlistName = e.key;
  //     final item = e.value;

  //     final lctext = textCleanedForSearch(text);
  //     final dateCreatedFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(item.creationDate));
  //     final dateModifiedFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(item.modifiedDate));

  //     return (sTitle && textCleanedForSearch(playlistName.translatePlaylistName()).contains(lctext)) ||
  //         (sCreationDate && textCleanedForSearch(dateCreatedFormatted.toString()).contains(lctext)) ||
  //         (sModifiedDate && textCleanedForSearch(dateModifiedFormatted.toString()).contains(lctext)) ||
  //         (sComment && textCleanedForSearch(item.comment).contains(lctext)) ||
  //         (sMoods && item.moods.any((element) => textCleanedForSearch(element).contains(lctext)));
  //   });
  //   return results;
  // }

  static Iterable<String> _generalSearchIsolate(Map parameters) {
    final keys = parameters['keys'] as Iterable<String>;
    final cleanup = parameters['cleanup'] as bool;
    final keyIsPath = parameters['keyIsPath'] as bool;
    final text = parameters['text'] as String;

    final cleanupFunction = _functionOfCleanup(cleanup);

    if (keyIsPath) {
      final results = keys.where((path) => cleanupFunction(path.split(Platform.pathSeparator).last).contains(cleanupFunction(text)));
      return results;
    } else {
      final results = keys.where((name) => cleanupFunction(name).contains(cleanupFunction(text)));
      return results;
    }
  }

  bool get _shouldCleanup => settings.enableSearchCleanup.value;

  static String Function(String text) _functionOfCleanup(bool enableSearchCleanup) {
    return (String textToClean) => enableSearchCleanup ? textToClean.cleanUpForComparison : textToClean.toLowerCase();
  }
}
