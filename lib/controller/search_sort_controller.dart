import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:namida/class/playlist.dart';
import 'package:namida/controller/indexer_controller.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/namida_converter_ext.dart';

class SearchSortController {
  static SearchSortController get inst => _instance;
  static final SearchSortController _instance = SearchSortController._internal();
  SearchSortController._internal();

  RxBool get isSearching => (trackSearchTemp.isNotEmpty || albumSearchTemp.isNotEmpty || artistSearchTemp.isNotEmpty).obs;

  final RxList<Track> trackSearchList = <Track>[].obs;
  final RxList<String> albumSearchList = <String>[].obs;
  final RxList<String> artistSearchList = <String>[].obs;
  final RxList<String> genreSearchList = <String>[].obs;

  final RxList<String> playlistSearchList = <String>[].obs;

  // -- Temporary lists, used for global search --
  final RxList<Track> trackSearchTemp = <Track>[].obs;
  final RxList<String> albumSearchTemp = <String>[].obs;
  final RxList<String> artistSearchTemp = <String>[].obs;

  RxList<Track> get tracksInfoList => Indexer.inst.tracksInfoList;
  Rx<Map<String, List<Track>>> get mainMapAlbums => Indexer.inst.mainMapAlbums;
  Rx<Map<String, List<Track>>> get mainMapArtists => Indexer.inst.mainMapArtists;
  Rx<Map<String, List<Track>>> get mainMapGenres => Indexer.inst.mainMapGenres;
  RxMap<String, Playlist> get playlistsMap => PlaylistController.inst.playlistsMap;

  void searchAll(String text) {
    _searchTracks(text, temp: true);
    _searchAlbums(text, temp: true);
    _searchArtists(text, temp: true);
  }

  void searchMedia(String text, MediaType media) {
    switch (media) {
      case MediaType.track:
        _searchTracks(text);
        break;
      case MediaType.album:
        _searchAlbums(text);
        break;
      case MediaType.artist:
        _searchArtists(text);
        break;
      case MediaType.genre:
        _searchGenres(text);
        break;
      case MediaType.playlist:
        _searchPlaylists(text);
        break;

      default:
        null;
    }
  }

  void _searchTracks(String text, {bool temp = false}) {
    final finalList = temp ? trackSearchTemp : trackSearchList;
    finalList.clear();
    if (text == '') {
      if (temp) {
        trackSearchTemp.clear();
      } else {
        LibraryTab.tracks.textSearchController?.clear();
        trackSearchList.assignAll(tracksInfoList);
      }

      return;
    }

    final tsf = SettingsController.inst.trackSearchFilter;
    final sTitle = tsf.contains('title');
    final sAlbum = tsf.contains('album');
    final sAlbumArtist = tsf.contains('albumartist');
    final sArtist = tsf.contains('artist');
    final sGenre = tsf.contains('genre');
    final sComposer = tsf.contains('composer');
    final sYear = tsf.contains('year');

    tracksInfoList.loop((tr, index) {
      final item = tr.toTrackExt();
      final lctext = textCleanedForSearch(text);

      if ((sTitle && textCleanedForSearch(item.title).contains(lctext)) ||
          (sAlbum && textCleanedForSearch(item.album).contains(lctext)) ||
          (sAlbumArtist && textCleanedForSearch(item.albumArtist).contains(lctext)) ||
          (sArtist && item.artistsList.any((element) => textCleanedForSearch(element).contains(lctext))) ||
          (sGenre && item.genresList.any((element) => textCleanedForSearch(element).contains(lctext))) ||
          (sComposer && textCleanedForSearch(item.composer).contains(lctext)) ||
          (sYear && textCleanedForSearch(item.year.toString()).contains(lctext))) {
        finalList.add(tr);
      }
    });

    printy("Search Tracks Found: ${finalList.length}");
  }

  void _searchAlbums(String text, {bool temp = false}) {
    if (text == '') {
      if (temp) {
        albumSearchTemp.clear();
      } else {
        LibraryTab.albums.textSearchController?.clear();
        albumSearchList
          ..clear()
          ..addAll(mainMapAlbums.value.keys);
      }
      return;
    }
    final results = mainMapAlbums.value.keys.where((albumName) => textCleanedForSearch(albumName).contains(textCleanedForSearch(text)));

    if (temp) {
      albumSearchTemp
        ..clear()
        ..addAll(results);
    } else {
      albumSearchList
        ..clear()
        ..addAll(results);
    }
  }

  void _searchArtists(String text, {bool temp = false}) {
    if (text == '') {
      if (temp) {
        artistSearchTemp.clear();
      } else {
        LibraryTab.artists.textSearchController?.clear();
        artistSearchList
          ..clear()
          ..addAll(mainMapArtists.value.keys);
      }
      return;
    }
    final results = mainMapArtists.value.keys.where((artistName) => textCleanedForSearch(artistName).contains(textCleanedForSearch(text)));

    if (temp) {
      artistSearchTemp
        ..clear()
        ..addAll(results);
    } else {
      artistSearchList
        ..clear()
        ..addAll(results);
    }
  }

  void _searchGenres(String text) {
    if (text == '') {
      LibraryTab.genres.textSearchController?.clear();
      genreSearchList.assignAll(mainMapGenres.value.keys);
      return;
    }
    final results = mainMapGenres.value.keys.where((genreName) => textCleanedForSearch(genreName).contains(textCleanedForSearch(text)));

    genreSearchList
      ..clear()
      ..addAll(results);
  }

  void _searchPlaylists(String text) {
    playlistSearchList.clear();

    if (text == '') {
      LibraryTab.playlists.textSearchController?.clear();
      playlistSearchList.addAll(playlistsMap.keys);
      return;
    }
    // TODO(MSOB7YY): expose in settings
    final psf = SettingsController.inst.playlistSearchFilter;
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
    playlistSearchList.addAll(results.map((e) => e.key));
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
    sortBy ??= SettingsController.inst.tracksSort.value;
    reverse ??= SettingsController.inst.tracksSortReversed.value;

    void sortThis(Comparable Function(Track tr) comparable) => reverse! ? tracksInfoList.sortByReverse(comparable) : tracksInfoList.sortBy(comparable);

    switch (sortBy) {
      case SortType.title:
        sortThis((e) => e.title);
      case SortType.album:
        sortThis((e) => e.album);
        break;
      case SortType.albumArtist:
        sortThis((e) => e.albumArtist);
        break;
      case SortType.year:
        sortThis((e) => e.year);
        break;
      case SortType.artistsList:
        sortThis((e) => e.artistsList.join());
        break;
      case SortType.genresList:
        sortThis((e) => e.genresList.join());
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
        sortThis((e) => e.composer);
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

      default:
        null;
    }

    SettingsController.inst.save(tracksSort: sortBy, tracksSortReversed: reverse);
    _searchTracks(LibraryTab.tracks.textSearchController?.text ?? '');
  }

  /// Sorts Albums and Saves automatically to settings
  void _sortAlbums({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.albumSort.value;
    reverse ??= SettingsController.inst.albumSortReversed.value;

    final albumsList = mainMapAlbums.value.entries.toList();
    void sortThis(Comparable Function(MapEntry<String, List<Track>> e) comparable) => reverse! ? albumsList.sortByReverse(comparable) : albumsList.sortBy(comparable);

    switch (sortBy) {
      case GroupSortType.album:
        sortThis((e) => e.key);
        break;
      case GroupSortType.albumArtist:
        sortThis((e) => e.value.albumArtist);
        break;
      case GroupSortType.year:
        sortThis((e) => e.value.year);
        break;
      case GroupSortType.artistsList:
        sortThis((e) => e.value.first.artistsList.join());
        break;
      case GroupSortType.composer:
        sortThis((e) => e.value.composer);
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

      default:
        null;
    }

    mainMapAlbums.value
      ..clear()
      ..addEntries(albumsList);

    SettingsController.inst.save(albumSort: sortBy, albumSortReversed: reverse);

    _searchAlbums(LibraryTab.albums.textSearchController?.text ?? '');
  }

  /// Sorts Artists and Saves automatically to settings
  void _sortArtists({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.artistSort.value;
    reverse ??= SettingsController.inst.artistSortReversed.value;

    final artistsList = mainMapArtists.value.entries.toList();
    void sortThis(Comparable Function(MapEntry<String, List<Track>> e) comparable) => reverse! ? artistsList.sortByReverse(comparable) : artistsList.sortBy(comparable);

    switch (sortBy) {
      case GroupSortType.album:
        sortThis((e) => e.value.album);
        break;
      case GroupSortType.albumArtist:
        sortThis((e) => e.value.albumArtist);
        break;
      case GroupSortType.year:
        sortThis((e) => e.value.year);
        break;
      case GroupSortType.artistsList:
        sortThis((e) => e.key);
        break;
      case GroupSortType.genresList:
        sortThis((e) => e.value[0].genresList.join());
        break;
      case GroupSortType.composer:
        sortThis((e) => e.value.composer);
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
      default:
        null;
    }
    mainMapArtists.value
      ..clear()
      ..addEntries(artistsList);

    SettingsController.inst.save(artistSort: sortBy, artistSortReversed: reverse);

    _searchArtists(LibraryTab.artists.textSearchController?.text ?? '');
  }

  /// Sorts Genres and Saves automatically to settings
  void _sortGenres({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.genreSort.value;
    reverse ??= SettingsController.inst.genreSortReversed.value;

    final genresList = mainMapGenres.value.entries.toList();
    void sortThis(Comparable Function(MapEntry<String, List<Track>> e) comparable) => reverse! ? genresList.sortByReverse(comparable) : genresList.sortBy(comparable);

    switch (sortBy) {
      case GroupSortType.album:
        sortThis((e) => e.value.album);
        break;
      case GroupSortType.albumArtist:
        sortThis((e) => e.value.albumArtist);
        break;
      case GroupSortType.year:
        sortThis((e) => e.value.year);
        break;
      case GroupSortType.artistsList:
        sortThis((e) => e.value[0].artistsList.join());
        break;
      case GroupSortType.genresList:
        sortThis((e) => e.value[0].genresList.join());
        break;
      case GroupSortType.composer:
        sortThis((e) => e.value.composer);
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

      default:
        null;
    }

    mainMapGenres.value
      ..clear()
      ..addEntries(genresList);

    SettingsController.inst.save(genreSort: sortBy, genreSortReversed: reverse);
    _searchGenres(LibraryTab.genres.textSearchController?.text ?? '');
  }

  /// Sorts Playlists and Saves automatically to settings
  void _sortPlaylists({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.playlistSort.value;
    reverse ??= SettingsController.inst.playlistSortReversed.value;

    final playlistList = playlistsMap.entries.toList();
    void sortThis(Comparable Function(MapEntry<String, Playlist> p) comparable) => reverse! ? playlistList.sortByReverse(comparable) : playlistList.sortBy(comparable);

    switch (sortBy) {
      case GroupSortType.title:
        sortThis((p) => p.key.translatePlaylistName());
        break;
      case GroupSortType.creationDate:
        sortThis((p) => p.value.creationDate);
        break;
      case GroupSortType.modifiedDate:
        sortThis((p) => p.value.modifiedDate);
        break;
      case GroupSortType.duration:
        sortThis((p) => p.value.tracks.toTracks().totalDurationInS);
        break;
      case GroupSortType.numberOfTracks:
        sortThis((p) => p.value.tracks.length);
        break;

      default:
        null;
    }

    playlistsMap
      ..clear()
      ..addEntries(playlistList);

    SettingsController.inst.save(playlistSort: sortBy, playlistSortReversed: reverse);

    _searchPlaylists(LibraryTab.playlists.textSearchController?.text ?? '');
  }
}