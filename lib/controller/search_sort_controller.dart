import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_ports_provider.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';

class SearchSortController {
  static SearchSortController get inst => _instance;
  static final SearchSortController _instance = SearchSortController._internal();
  SearchSortController._internal();

  String lastSearchText = '';

  bool get isSearching => (trackSearchTemp.isNotEmpty ||
      albumSearchTemp.isNotEmpty ||
      artistSearchTemp.isNotEmpty ||
      albumArtistSearchTemp.isNotEmpty ||
      composerSearchTemp.isNotEmpty ||
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
    MediaType.albumArtist: <String>[].obs,
    MediaType.composer: <String>[].obs,
    MediaType.genre: <String>[].obs,
    MediaType.folder: <String>[].obs,
  };

  var trackSearchTemp = <Track>[].obs;
  final playlistSearchTemp = <String>[].obs;
  RxList<String> get albumSearchTemp => _searchMapTemp[MediaType.album]!;
  RxList<String> get artistSearchTemp => _searchMapTemp[MediaType.artist]!;
  RxList<String> get albumArtistSearchTemp => _searchMapTemp[MediaType.albumArtist]!;
  RxList<String> get composerSearchTemp => _searchMapTemp[MediaType.composer]!;
  RxList<String> get genreSearchTemp => _searchMapTemp[MediaType.genre]!;
  RxList<String> get folderSearchTemp => _searchMapTemp[MediaType.folder]!;

  RxList<Track> get tracksInfoList => Indexer.inst.tracksInfoList;
  Map<String, List<Track>> get mainMapFolder {
    return Indexer.inst.mainMapFolders.map((key, value) => MapEntry(key.path.getDirectoryName, value));
  }

  RxMap<String, Playlist> get playlistsMap => PlaylistController.inst.playlistsMap;

  bool get hasRunningSearch => _runningSearches.values.any((running) => running);

  final _runningSearches = <MediaType, bool>{}.obs;

  void searchAll(String text) {
    lastSearchText = text;
    final enabledSearches = settings.activeSearchMediaTypes;

    _searchTracks(text, temp: true);
    if (enabledSearches.contains(MediaType.album)) _searchMediaType(type: MediaType.album, text: text, temp: true);
    if (enabledSearches.contains(MediaType.artist)) _searchMediaType(type: MediaType.artist, text: text, temp: true);
    if (enabledSearches.contains(MediaType.albumArtist)) _searchMediaType(type: MediaType.albumArtist, text: text, temp: true);
    if (enabledSearches.contains(MediaType.composer)) _searchMediaType(type: MediaType.composer, text: text, temp: true);
    if (enabledSearches.contains(MediaType.genre)) _searchMediaType(type: MediaType.genre, text: text, temp: true);
    if (enabledSearches.contains(MediaType.playlist)) _searchPlaylists(text, temp: true);
    if (enabledSearches.contains(MediaType.folder)) _searchMediaType(type: MediaType.folder, text: text, temp: true);
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
      case MediaType.albumArtist:
      case MediaType.composer:
        _searchMediaType(type: settings.activeArtistType.value, text: text);
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

  late final _mediaTracksSortingComparables = <SortType, Comparable Function(Track e)>{
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
    SortType.mostPlayed: (e) => HistoryController.inst.topTracksMapListens[e]?.length ?? 0,
    SortType.latestPlayed: (e) => HistoryController.inst.topTracksMapListens[e]?.lastOrNull ?? 0,
  };

  List<Comparable Function(Track tr)> getMediaTracksSortingComparables(MediaType media) {
    final sorts = settings.mediaItemsTrackSorting[media] ?? <SortType>[SortType.title];
    final l = <Comparable Function(Track e)>[];
    sorts.loop((e, index) {
      if (_mediaTracksSortingComparables[e] != null) l.add(_mediaTracksSortingComparables[e]!);
    });
    return l;
  }

  bool? _preparedResources;
  Future<void> prepareResources() async {
    if (_preparedResources == true) return;
    _preparedResources = true;
    final enabledSearchesList = settings.activeSearchMediaTypes;
    final enabledSearches = <MediaType, bool>{};
    enabledSearchesList.loop((f, _) => enabledSearches[f] = true);

    final mainMapArtists = Indexer.inst.mainMapArtists.value.keys;
    final mainMapAA = Indexer.inst.mainMapAlbumArtists.value.keys;
    final mainMapComposers = Indexer.inst.mainMapComposer.value.keys;

    final mainMapAlbums = Indexer.inst.mainMapAlbums.value.keys;
    final mainMapGenres = Indexer.inst.mainMapGenres.value.keys;

    await Future.wait([
      _prepareTracksPorts(),
      if (enabledSearches[MediaType.album] ?? false) _prepareMediaPorts(mainMapAlbums, MediaType.album) else SearchPortsProvider.inst.closePorts(MediaType.album),
      if (enabledSearches[MediaType.artist] ?? false) _prepareMediaPorts(mainMapArtists, MediaType.artist) else SearchPortsProvider.inst.closePorts(MediaType.artist),
      if (enabledSearches[MediaType.albumArtist] ?? false) _prepareMediaPorts(mainMapAA, MediaType.albumArtist) else SearchPortsProvider.inst.closePorts(MediaType.albumArtist),
      if (enabledSearches[MediaType.composer] ?? false) _prepareMediaPorts(mainMapComposers, MediaType.composer) else SearchPortsProvider.inst.closePorts(MediaType.composer),
      if (enabledSearches[MediaType.genre] ?? false) _prepareMediaPorts(mainMapGenres, MediaType.genre) else SearchPortsProvider.inst.closePorts(MediaType.genre),
      if (enabledSearches[MediaType.playlist] ?? false) _preparePlaylistPorts() else SearchPortsProvider.inst.closePorts(MediaType.playlist),
      if (enabledSearches[MediaType.folder] ?? false) _prepareMediaPorts(mainMapFolder.keys, MediaType.folder) else SearchPortsProvider.inst.closePorts(MediaType.folder),
    ]);
  }

  void disposeResources() {
    _preparedResources = false;
    SearchPortsProvider.inst.disposeAll();
  }

  Future<SendPort> _prepareTracksPorts() async {
    return await SearchPortsProvider.inst.preparePorts(
      type: MediaType.track,
      onResult: (result) {
        _runningSearches[MediaType.track] = false;
        final r = result as (List<Track>, bool, String);
        final isTemp = r.$2;
        final fetchedQuery = r.$3;
        if (isTemp) {
          if (fetchedQuery == lastSearchText) {
            trackSearchTemp.value = r.$1;
            sortTracksSearch(canSkipSorting: true);
          }
        } else {
          if (fetchedQuery == LibraryTab.tracks.textSearchController?.text) trackSearchList.value = r.$1;
        }
      },
      isolateFunction: (itemsSendPort) async {
        final params = generateTrackSearchIsolateParams(itemsSendPort);
        await Isolate.spawn(searchTracksIsolate, params);
      },
    );
  }

  Map<String, dynamic> generateTrackSearchIsolateParams(SendPort sendPort, {bool sendPrepared = false}) {
    final params = {
      'tracks': Indexer.inst.allTracksMappedByPath.values
          .map((e) => {
                'title': e.title,
                'artist': e.originalArtist,
                'album': e.album,
                'albumArtist': e.albumArtist,
                'genre': e.originalGenre,
                'composer': e.composer,
                'year': e.year,
                'comment': e.comment,
                'path': e.path,
              })
          .toList(),
      'artistsSplitConfig': ArtistsSplitConfig.settings().toMap(),
      'genresSplitConfig': GenresSplitConfig.settings().toMap(),
      // ignore: invalid_use_of_protected_member
      'filters': settings.trackSearchFilter.value,
      'cleanup': _shouldCleanup,
      'sendPrepared': sendPrepared,
      'sendPort': sendPort,
    };
    return params;
  }

  Future<SendPort> _preparePlaylistPorts() async {
    return await SearchPortsProvider.inst.preparePorts(
      type: MediaType.playlist,
      onResult: (result) {
        _runningSearches[MediaType.playlist] = false;

        final r = result as (List<String>, bool, String);
        final isTemp = r.$2;
        final fetchedQuery = r.$3;
        if (isTemp) {
          if (fetchedQuery == lastSearchText) playlistSearchTemp.value = r.$1;
        } else {
          if (fetchedQuery == LibraryTab.playlists.textSearchController?.text) playlistSearchList.value = r.$1;
        }
      },
      isolateFunction: (itemsSendPort) async {
        final params = {
          'playlists': playlistsMap.values.map((e) => e.toJson((item) => item.toJson())).toList(),
          'translations': {
            'k_PLAYLIST_NAME_AUTO_GENERATED': lang.AUTO_GENERATED,
            'k_PLAYLIST_NAME_FAV': lang.FAVOURITES,
            'k_PLAYLIST_NAME_HISTORY': lang.HISTORY,
            'k_PLAYLIST_NAME_MOST_PLAYED': lang.MOST_PLAYED,
          },
          'filters': settings.playlistSearchFilter.cast<String>(),
          'cleanup': _shouldCleanup,
          'sendPort': itemsSendPort,
        };

        await Isolate.spawn(_searchPlaylistsIsolate, params);
      },
    );
  }

  Future<SendPort> _prepareMediaPorts(Iterable<String> keysList, MediaType type) async {
    return await SearchPortsProvider.inst.preparePorts(
      type: type,
      onResult: (result) {
        _runningSearches[type] = false;
        final r = result as (List<String>, bool, String);
        final isTemp = r.$2;
        final fetchedQuery = r.$3;
        if (isTemp) {
          if (fetchedQuery == lastSearchText) _searchMapTemp[type]?.value = r.$1;
        } else {
          final typeNomalize = type == MediaType.albumArtist || type == MediaType.composer ? MediaType.artist : type;
          if (fetchedQuery == typeNomalize.toLibraryTab()?.textSearchController?.text) _searchMap[typeNomalize]?.value = r.$1;
        }
      },
      isolateFunction: (itemsSendPort) async {
        final params = {
          'keys': keysList.toList(),
          'cleanup': _shouldCleanup,
          'keyIsPath': type == MediaType.folder,
          'sendPort': itemsSendPort,
        };

        await Isolate.spawn(_generalSearchIsolate, params);
      },
    );
  }

  void _searchTracks(String text, {bool temp = false}) async {
    if (text == '') {
      if (temp) {
        trackSearchTemp.clear();
      } else {
        LibraryTab.tracks.textSearchController?.clear();
        trackSearchList
          ..clear()
          ..addAll(tracksInfoList);
      }
      return;
    }
    _runningSearches[MediaType.track] = true;
    final sp = await _prepareTracksPorts();
    sp.send({
      'text': text,
      'temp': temp,
    });
  }

  static void searchTracksIsolate(Map params) {
    final tracks = params['tracks'] as List<Map>;
    final artistsSplitConfig = ArtistsSplitConfig.fromMap(params['artistsSplitConfig']);
    final genresSplitConfig = GenresSplitConfig.fromMap(params['genresSplitConfig']);
    final tsf = params['filters'] as List<TrackSearchFilter>;
    final cleanup = params['cleanup'] as bool;
    final sendPrepared = params['sendPrepared'] as bool?;
    final sendPort = params['sendPort'] as SendPort;

    final receivePort = ReceivePort();

    sendPort.send(receivePort.sendPort);

    final tsfMap = <TrackSearchFilter, bool>{};
    tsf.loop((f, _) => tsfMap[f] = true);

    final stitle = tsfMap[TrackSearchFilter.title] ?? true;
    final sfilename = tsfMap[TrackSearchFilter.filename] ?? true;
    final salbum = tsfMap[TrackSearchFilter.album] ?? true;
    final salbumartist = tsfMap[TrackSearchFilter.albumartist] ?? false;
    final sartist = tsfMap[TrackSearchFilter.artist] ?? true;
    final sgenre = tsfMap[TrackSearchFilter.genre] ?? false;
    final scomposer = tsfMap[TrackSearchFilter.composer] ?? false;
    final scomment = tsfMap[TrackSearchFilter.comment] ?? false;
    final syear = tsfMap[TrackSearchFilter.year] ?? false;

    final textCleanedForSearch = _functionOfCleanup(cleanup);

    Iterable<String> splitThis(String? property, bool split) => !split || property == null ? [] : property.split(' ').map((e) => textCleanedForSearch(e));

    final tracksExtended = <({
      String path,
      Iterable<String> splitTitle,
      Iterable<String> splitFilename,
      Iterable<String> splitAlbum,
      Iterable<String> splitAlbumArtist,
      List<String> splitArtist,
      List<String> splitGenre,
      Iterable<String> splitComposer,
      Iterable<String> splitComment,
      String year,
    })>[];
    for (final trMap in tracks) {
      final path = trMap['path'] as String;
      tracksExtended.add(
        (
          path: path,
          splitTitle: splitThis(trMap['title'], stitle),
          splitFilename: splitThis(path.getFilename, sfilename),
          splitAlbum: splitThis(trMap['album'], salbum),
          splitAlbumArtist: splitThis(trMap['albumArtist'], salbumartist),
          splitArtist: sartist
              ? Indexer.splitArtist(
                  title: trMap['title'],
                  originalArtist: trMap['artist'],
                  config: artistsSplitConfig,
                ).map((e) => textCleanedForSearch(e)).toList()
              : [],
          splitGenre: sgenre
              ? Indexer.splitGenre(
                  trMap['genre'],
                  config: genresSplitConfig,
                ).map((e) => textCleanedForSearch(e)).toList()
              : [],
          splitComposer: splitThis(trMap['composer'], scomposer),
          splitComment: splitThis(trMap['comment'], scomment),
          year: textCleanedForSearch(trMap['year'].toString()),
        ),
      );
    }

    StreamSubscription? streamSub;
    streamSub = receivePort.listen((p) {
      if (PortsProvider.isDisposeMessage(p)) {
        receivePort.close();
        streamSub?.cancel();
        return;
      }
      p as Map<String, dynamic>;
      final text = p['text'] as String;
      final temp = p['temp'] as bool;

      final lctext = textCleanedForSearch(text);
      final lctextSplit = text.split(' ').map((e) => textCleanedForSearch(e));

      bool isMatch(Iterable<String> propertySplit) {
        final match1 = lctextSplit.every((element) => propertySplit.any((p) => p.contains(element)));
        if (match1) return true;
        if (!cleanup) return false;
        final match2 = propertySplit.join().contains(lctext);
        return match2;
      }

      final result = <Track>[];
      tracksExtended.loop((trExt, index) {
        if ((stitle && isMatch(trExt.splitTitle)) ||
            (sfilename && isMatch(trExt.splitFilename)) ||
            (salbum && isMatch(trExt.splitAlbum)) ||
            (salbumartist && isMatch(trExt.splitAlbumArtist)) ||
            (sartist && isMatch(trExt.splitArtist)) ||
            (sgenre && isMatch(trExt.splitGenre)) ||
            (scomposer && isMatch(trExt.splitComposer)) ||
            (scomment && isMatch(trExt.splitComment)) ||
            (syear && trExt.year.contains(lctext))) {
          result.add(Track(trExt.path));
        }
      });

      sendPort.send((result, temp, text));
    });
    if (sendPrepared == true) sendPort.send(null);
  }

  void _searchMediaType({required MediaType type, required String text, bool temp = false}) async {
    Iterable<String> keys = [];
    switch (type) {
      case MediaType.album:
        keys = Indexer.inst.mainMapAlbums.value.keys;
      case MediaType.artist:
        keys = Indexer.inst.mainMapArtists.value.keys;
      case MediaType.albumArtist:
        keys = Indexer.inst.mainMapAlbumArtists.value.keys;
      case MediaType.composer:
        keys = Indexer.inst.mainMapComposer.value.keys;
      case MediaType.genre:
        keys = Indexer.inst.mainMapGenres.value.keys;
      case MediaType.folder:
        keys = mainMapFolder.keys;
      default:
        null;
    }

    if (text == '') {
      if (temp) {
        _searchMapTemp[type]?.clear();
      } else {
        final typeNomalize = type == MediaType.albumArtist || type == MediaType.composer ? MediaType.artist : type;
        typeNomalize.toLibraryTab()?.textSearchController?.clear();
        _searchMap[typeNomalize]?.value = keys.toList();
      }
      return;
    }

    _runningSearches[type] = true;
    final sp = await _prepareMediaPorts(keys, type);
    sp.send({
      'text': text,
      'temp': temp,
    });
  }

  void _searchPlaylists(String text, {bool temp = false}) async {
    if (text == '') {
      if (temp) {
        playlistSearchTemp.clear();
      } else {
        LibraryTab.playlists.textSearchController?.clear();
        playlistSearchList.value = playlistsMap.keys.toList();
      }
      return;
    }
    _runningSearches[MediaType.playlist] = true;
    final sp = await _preparePlaylistPorts();
    sp.send({
      'text': text,
      'temp': temp,
    });
  }

  static void _searchPlaylistsIsolate(Map params) {
    final playlistsMap = params['playlists'] as List<Map<String, dynamic>>;
    final translations = params['translations'] as Map<String, String>;
    final psf = params['filters'] as List<String>;
    final cleanup = params['cleanup'] as bool;
    final sendPort = params['sendPort'] as SendPort;

    final receivePort = ReceivePort();

    sendPort.send(receivePort.sendPort);

    String translatePlName(String n) {
      return n
          .replaceFirst(k_PLAYLIST_NAME_AUTO_GENERATED, translations['k_PLAYLIST_NAME_AUTO_GENERATED'] ?? k_PLAYLIST_NAME_AUTO_GENERATED)
          .replaceFirst(k_PLAYLIST_NAME_FAV, translations['k_PLAYLIST_NAME_FAV'] ?? k_PLAYLIST_NAME_FAV)
          .replaceFirst(k_PLAYLIST_NAME_HISTORY, translations['k_PLAYLIST_NAME_HISTORY'] ?? k_PLAYLIST_NAME_HISTORY)
          .replaceFirst(k_PLAYLIST_NAME_MOST_PLAYED, translations['k_PLAYLIST_NAME_MOST_PLAYED'] ?? k_PLAYLIST_NAME_MOST_PLAYED);
    }

    final formatDate = DateFormat('yyyyMMdd');

    final playlists = <({
      GeneralPlaylist<TrackWithDate> pl,
      String name,
      String dateCreatedFormatted,
      String dateModifiedFormatted,
    })>[];
    for (final plMap in playlistsMap) {
      final pl = GeneralPlaylist<TrackWithDate>.fromJson(plMap, (itemJson) => TrackWithDate.fromJson(itemJson));
      final trName = translatePlName(pl.name);
      final dateCreatedFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(pl.creationDate));
      final dateModifiedFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(pl.modifiedDate));
      playlists.add((
        pl: pl,
        name: trName,
        dateCreatedFormatted: dateCreatedFormatted,
        dateModifiedFormatted: dateModifiedFormatted,
      ));
    }

    final textCleanedForSearch = _functionOfCleanup(cleanup);

    final psfMap = <String, bool>{};
    psf.loop((f, _) => psfMap[f] = true);

    final sTitle = psfMap['name'] ?? true;
    final sCreationDate = psfMap['creationDate'] ?? false;
    final sModifiedDate = psfMap['modifiedDate'] ?? false;
    final sComment = psfMap['comment'] ?? false;
    final sMoods = psfMap['moods'] ?? false;

    StreamSubscription? streamSub;
    streamSub = receivePort.listen((p) {
      if (PortsProvider.isDisposeMessage(p)) {
        receivePort.close();
        streamSub?.cancel();
        return;
      }
      p as Map<String, dynamic>;
      final text = p['text'] as String;
      final temp = p['temp'] as bool;

      final lctext = textCleanedForSearch(text);

      final results = <String>[];
      playlists.loop((itemInfo, _) {
        final item = itemInfo.pl;
        final playlistName = item.name;

        if ((sTitle && textCleanedForSearch(itemInfo.name).contains(lctext)) ||
            (sCreationDate && textCleanedForSearch(itemInfo.dateCreatedFormatted).contains(lctext)) ||
            (sModifiedDate && textCleanedForSearch(itemInfo.dateModifiedFormatted).contains(lctext)) ||
            (sComment && textCleanedForSearch(item.comment).contains(lctext)) ||
            (sMoods && item.moods.any((element) => textCleanedForSearch(element).contains(lctext)))) {
          results.add(playlistName);
        }
      });
      sendPort.send((results, temp, text));
    });
  }

  void sortAll() {
    _sortTracks();
    _sortAlbums();
    _sortArtistsCurrent(artistType: settings.activeArtistType.value);
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
      case MediaType.albumArtist:
      case MediaType.composer:
        _sortArtistsCurrent(artistType: settings.activeArtistType.value, sortBy: groupSortBy, reverse: reverse);
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
    _sortTracksRaw(
      sortBy: sortBy ?? settings.tracksSort.value,
      reverse: reverse ?? settings.tracksSortReversed.value,
      list: tracksInfoList,
      onDone: (sortType, isReverse) {
        settings.save(tracksSort: sortType, tracksSortReversed: isReverse);
        _searchTracks(LibraryTab.tracks.textSearchController?.text ?? '');
      },
    );
  }

  void sortTracksSearch({SortType? sortBy, bool? reverse, bool canSkipSorting = false}) {
    final isAuto = settings.tracksSortSearchIsAuto.value;

    sortBy ??= isAuto ? settings.tracksSort.value : settings.tracksSortSearch.value;
    reverse ??= isAuto ? settings.tracksSortReversed.value : settings.tracksSortSearchReversed.value;

    if (canSkipSorting) {
      final identicalToMainOne = isAuto ? true : sortBy == settings.tracksSort.value && reverse == settings.tracksSortReversed.value;
      if (identicalToMainOne) return; // since the looped list already has the same order
    }

    _sortTracksRaw(
      sortBy: sortBy,
      reverse: reverse,
      list: trackSearchTemp,
      onDone: (sortType, isReverse) {
        if (!isAuto) {
          settings.save(tracksSortSearch: sortType, tracksSortSearchReversed: isReverse);
        }
      },
    );
  }

  void _sortTracksRaw({
    required SortType? sortBy,
    required bool reverse,
    required List<Track> list,
    required void Function(SortType? sortType, bool isReverse) onDone,
  }) {
    void sortThis(Comparable Function(Track e) comparable) => reverse ? list.sortByReverse(comparable) : list.sortBy(comparable);
    void sortThisAlts(List<Comparable<dynamic> Function(Track tr)> alternatives) => reverse ? list.sortByReverseAlts(alternatives) : list.sortByAlts(alternatives);

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
        list.shuffle();
        break;
      case SortType.mostPlayed:
        sortThis((e) => HistoryController.inst.topTracksMapListens[e]?.length ?? 0);
        break;
      case SortType.latestPlayed:
        sortThis((e) => HistoryController.inst.topTracksMapListens[e]?.lastOrNull ?? 0);
        break;

      default:
        null;
    }
    onDone(sortBy, reverse);
  }

  /// Sorts Albums and Saves automatically to settings
  void _sortAlbums({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= settings.albumSort.value;
    reverse ??= settings.albumSortReversed.value;

    final finalMap = Indexer.inst.mainMapAlbums;
    final albumsList = finalMap.value.entries.toList();
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

    finalMap.value
      ..clear()
      ..addEntries(albumsList);

    settings.save(albumSort: sortBy, albumSortReversed: reverse);

    _searchMediaType(type: MediaType.album, text: LibraryTab.albums.textSearchController?.text ?? '');
  }

  /// Sorts Artists and Saves automatically to settings
  void _sortArtistsCurrent({required MediaType artistType, GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= settings.artistSort.value;
    reverse ??= settings.artistSortReversed.value;

    final finalMap = switch (artistType) {
      MediaType.artist => Indexer.inst.mainMapArtists,
      MediaType.albumArtist => Indexer.inst.mainMapAlbumArtists,
      MediaType.composer => Indexer.inst.mainMapComposer,
      _ => Indexer.inst.mainMapArtists,
    };
    final artistsList = finalMap.value.entries.toList();

    void sortThis(Comparable Function(MapEntry<String, List<Track>> e) comparable) => reverse! ? artistsList.sortByReverse(comparable) : artistsList.sortBy(comparable);

    switch (sortBy) {
      case GroupSortType.artistsList:
        artistType == MediaType.artist
            ? sortThis((e) => e.key.toLowerCase())
            : sortThis((e) => e.value.firstWhereEff((e) => e.originalArtist != '')?.originalArtist.toLowerCase() ?? '');
        break;
      case GroupSortType.albumArtist:
        artistType == MediaType.albumArtist
            ? sortThis((e) => e.key.toLowerCase())
            : sortThis((e) => e.value.firstWhereEff((e) => e.albumArtist != '')?.albumArtist.toLowerCase() ?? '');
        break;
      case GroupSortType.composer:
        artistType == MediaType.composer
            ? sortThis((e) => e.key.toLowerCase()) //
            : sortThis((e) => e.value.firstWhereEff((e) => e.composer != '')?.composer.toLowerCase() ?? '');
        break;
      case GroupSortType.albumsCount:
        artistType == MediaType.albumArtist
            ? sortThis((e) => e.key.getAlbumArtistTracks().toUniqueAlbums().length)
            : artistType == MediaType.composer
                ? sortThis((e) => e.key.getComposerTracks().toUniqueAlbums().length)
                : sortThis((e) => e.key.getArtistTracks().toUniqueAlbums().length);
        break;
      case GroupSortType.album:
        sortThis((e) => e.value.album.toLowerCase());
        break;
      case GroupSortType.year:
        sortThis((e) => e.value.yearPreferyyyyMMdd);
        break;
      case GroupSortType.genresList:
        sortThis((e) => e.value[0].genresList.join().toLowerCase());
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
        artistsList.shuffle();
        break;
      default:
        null;
    }
    finalMap.value
      ..clear()
      ..addEntries(artistsList);

    settings.save(artistSort: sortBy, artistSortReversed: reverse);

    _searchMediaType(type: artistType, text: LibraryTab.artists.textSearchController?.text ?? '');
  }

  /// Sorts Genres and Saves automatically to settings
  void _sortGenres({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= settings.genreSort.value;
    reverse ??= settings.genreSortReversed.value;

    final finalMap = Indexer.inst.mainMapGenres;
    final genresList = finalMap.value.entries.toList();
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

    finalMap.value
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

  static void _generalSearchIsolate(Map parameters) {
    final keys = parameters['keys'] as List<String>;
    final cleanup = parameters['cleanup'] as bool;
    final keyIsPath = parameters['keyIsPath'] as bool;

    final sendPort = parameters['sendPort'] as SendPort;

    final receivePort = ReceivePort();

    sendPort.send(receivePort.sendPort);

    final cleanupFunction = _functionOfCleanup(cleanup);
    StreamSubscription? streamSub;
    streamSub = receivePort.listen((p) {
      if (PortsProvider.isDisposeMessage(p)) {
        receivePort.close();
        streamSub?.cancel();
        return;
      }
      p as Map<String, dynamic>;
      final text = p['text'] as String;
      final temp = p['temp'] as bool;

      final results = <String>[];
      if (keyIsPath) {
        keys.loop((path, _) {
          String pathN = path;
          while (pathN.isNotEmpty && pathN[pathN.length - 1] == Platform.pathSeparator) {
            pathN = pathN.substring(0, pathN.length);
          }
          if (cleanupFunction(pathN.split(Platform.pathSeparator).last).contains(cleanupFunction(text))) {
            results.add(pathN);
          }
        });
      } else {
        keys.loop((name, _) {
          if (cleanupFunction(name).contains(cleanupFunction(text))) {
            results.add(name);
          }
        });
      }
      sendPort.send((results, temp, text));
    });
  }

  bool get _shouldCleanup => settings.enableSearchCleanup.value;

  static String Function(String text) _functionOfCleanup(bool enableSearchCleanup) {
    return (String textToClean) => enableSearchCleanup ? textToClean.cleanUpForComparison : textToClean.toLowerCase();
  }
}
