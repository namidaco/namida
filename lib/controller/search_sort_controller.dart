import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/base/tracks_search_wrapper.dart';
import 'package:namida/class/folder.dart';
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
import 'package:namida/core/utils.dart';

class SearchSortController extends SearchPortsProvider {
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
      folderSearchTemp.isNotEmpty ||
      folderVideosSearchTemp.isNotEmpty);

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
    MediaType.folderVideo: <String>[].obs,
  };

  var trackSearchTemp = <Track>[].obs;
  final playlistSearchTemp = <String>[].obs;
  RxList<String> get albumSearchTemp => _searchMapTemp[MediaType.album]!;
  RxList<String> get artistSearchTemp => _searchMapTemp[MediaType.artist]!;
  RxList<String> get albumArtistSearchTemp => _searchMapTemp[MediaType.albumArtist]!;
  RxList<String> get composerSearchTemp => _searchMapTemp[MediaType.composer]!;
  RxList<String> get genreSearchTemp => _searchMapTemp[MediaType.genre]!;
  RxList<String> get folderSearchTemp => _searchMapTemp[MediaType.folder]!;
  RxList<String> get folderVideosSearchTemp => _searchMapTemp[MediaType.folderVideo]!;

  RxList<Track> get _tracksInfoList => Indexer.inst.tracksInfoList;

  RxMap<String, LocalPlaylist> get playlistsMap => PlaylistController.inst.playlistsMap;

  final runningSearchesTempCount = 0.obs;

  void searchAll(String text) {
    lastSearchText = text;
    final enabledSearches = settings.activeSearchMediaTypes;
    if (text.isNotEmpty) runningSearchesTempCount.value = runningSearchesTempCount.value + enabledSearches.value.length;

    searchTracks(text, temp: true);

    final int length = enabledSearches.length;
    for (int i = 0; i < length; i++) {
      var es = enabledSearches[i];
      if (es == MediaType.track) {
        // -- we always search
      } else if (es == MediaType.playlist) {
        _searchPlaylists(text, temp: true);
      } else {
        _searchMediaType(type: es, text: text, temp: true);
      }
    }
  }

  void searchMedia(String text, MediaType? media) {
    switch (media) {
      case MediaType.track:
        searchTracks(text);
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

  Comparable Function(MapEntry<String, List<Track>>)? _getMediaSortingComparable(GroupSortType type, {GroupSortType? overrideKey, TrackSearchFilter? filter}) {
    final ignoreCommonPrefix = settings.ignoreCommonPrefixForTypes.value;

    String Function(MapEntry<String, List<Track>> e) encapsulateSortCanIgnorePrefix(TrackSearchFilter filter, String Function(MapEntry<String, List<Track>> e) comparable) {
      if (ignoreCommonPrefix.contains(filter)) {
        return (e) => comparable(e).ignoreCommonPrefixes();
      } else {
        return comparable;
      }
    }

    if (type == overrideKey && filter != null) {
      return encapsulateSortCanIgnorePrefix(filter, (e) => e.key.toLowerCase());
    }

    return switch (type) {
      GroupSortType.album => encapsulateSortCanIgnorePrefix(TrackSearchFilter.album, (e) => e.value.album.toLowerCase()),
      GroupSortType.albumArtist => encapsulateSortCanIgnorePrefix(TrackSearchFilter.albumartist, (e) => e.value.albumArtist.toLowerCase()),
      GroupSortType.year => (e) => e.value.yearPreferyyyyMMdd,
      GroupSortType.artistsList => encapsulateSortCanIgnorePrefix(TrackSearchFilter.artist, (e) => e.value.first.artistsList.join().toLowerCase()),
      GroupSortType.genresList => encapsulateSortCanIgnorePrefix(TrackSearchFilter.genre, (e) => e.value.first.genresList.join().toLowerCase()),
      GroupSortType.composer => encapsulateSortCanIgnorePrefix(TrackSearchFilter.composer, (e) => e.value.composer.toLowerCase()),
      GroupSortType.label => (e) => e.value.recordLabel.toLowerCase(),
      GroupSortType.dateModified => (e) => e.value.first.dateModified,
      GroupSortType.duration => (e) => e.value.totalDurationInMS,
      GroupSortType.numberOfTracks => (e) => -e.value.length,
      GroupSortType.playCount => (e) => -e.value.getTotalListenCount(),
      GroupSortType.firstListen => (e) => e.value.getFirstListen() ?? DateTime(99999).millisecondsSinceEpoch,
      GroupSortType.latestPlayed => (e) => -(e.value.getLatestListen() ?? 0),
      _ => null,
    };
  }

  Comparable Function(Track e) getTracksSortingComparables(SortType type) {
    final ignoreCommonPrefix = settings.ignoreCommonPrefixForTypes.value;
    String Function(Track e) encapsulateSortCanIgnorePrefix(TrackSearchFilter filter, String Function(Track e) comparable) {
      if (ignoreCommonPrefix.contains(filter)) {
        return (e) => comparable(e).ignoreCommonPrefixes();
      } else {
        return comparable;
      }
    }

    return switch (type) {
      SortType.title => encapsulateSortCanIgnorePrefix(TrackSearchFilter.title, (e) => e.title.toLowerCase()),
      SortType.album => encapsulateSortCanIgnorePrefix(TrackSearchFilter.album, (e) => e.album.toLowerCase()),
      SortType.albumArtist => encapsulateSortCanIgnorePrefix(TrackSearchFilter.albumartist, (e) => e.albumArtist.toLowerCase()),
      SortType.year => (e) => e.yearPreferyyyyMMdd,
      SortType.artistsList => encapsulateSortCanIgnorePrefix(TrackSearchFilter.artist, (e) => e.artistsList.join().toLowerCase()),
      SortType.genresList => encapsulateSortCanIgnorePrefix(TrackSearchFilter.genre, (e) => e.genresList.join().toLowerCase()),
      SortType.dateAdded => (e) => e.dateAdded,
      SortType.dateModified => (e) => e.dateModified,
      SortType.bitrate => (e) => e.bitrate,
      SortType.composer => encapsulateSortCanIgnorePrefix(TrackSearchFilter.composer, (e) => e.composer.toLowerCase()),
      SortType.trackNo => (e) => e.trackNo,
      SortType.discNo => (e) => e.discNo,
      SortType.filename => encapsulateSortCanIgnorePrefix(TrackSearchFilter.filename, (e) => e.filename.toLowerCase()),
      SortType.duration => (e) => e.durationMS,
      SortType.sampleRate => (e) => e.sampleRate,
      SortType.size => (e) => e.size,
      SortType.rating => (e) => e.effectiveRating,
      SortType.mostPlayed => (e) => -(HistoryController.inst.topTracksMapListens.value[e]?.length ?? 0),
      SortType.latestPlayed => (e) => -(HistoryController.inst.topTracksMapListens.value[e]?.lastOrNull ?? 0),
      SortType.firstListen => (e) => HistoryController.inst.topTracksMapListens.value[e]?.firstOrNull ?? DateTime(99999).millisecondsSinceEpoch,
      SortType.shuffle => (e) => math.Random().nextInt(3) - 1,
    };
  }

  List<Comparable Function(Track tr)> getMediaTracksSortingComparables(MediaType media) {
    final sorts = settings.mediaItemsTrackSorting.value[media] ?? <SortType>[SortType.title];
    final l = <Comparable Function(Track e)>[];
    sorts.loop((e) {
      final sorter = getTracksSortingComparables(e);
      l.add(sorter);
    });
    return l;
  }

  String? Function(List<Track> tracks)? getGroupSortExtraTextResolver(GroupSortType sort, {GeneralPlaylist? playlist}) => switch (sort) {
        GroupSortType.album => (tracks) => tracks.album,
        GroupSortType.artistsList => (tracks) => tracks.firstOrNull?.originalArtist,
        GroupSortType.composer => (tracks) => tracks.firstOrNull?.composer,
        GroupSortType.albumArtist => (tracks) => tracks.albumArtist,
        GroupSortType.label => (tracks) => tracks.firstOrNull?.label,
        GroupSortType.genresList => (tracks) => tracks.firstOrNull?.originalGenre,
        GroupSortType.numberOfTracks => (tracks) => tracks.length.toString(),
        GroupSortType.duration => (tracks) => tracks.totalDurationFormatted,
        GroupSortType.albumsCount => (tracks) => tracks.toUniqueAlbums().length.toString(),
        GroupSortType.year => (tracks) => tracks.year.yearFormatted,
        GroupSortType.dateModified => (tracks) => tracks.firstOrNull?.dateModified.dateFormatted,
        GroupSortType.playCount => (tracks) => tracks.getTotalListenCount().toString(),
        GroupSortType.firstListen => (tracks) => tracks.getFirstListen()?.dateFormattedOriginal ?? '',
        GroupSortType.latestPlayed => (tracks) => tracks.getLatestListen()?.dateFormattedOriginal ?? '',

        // -- playlists
        GroupSortType.title => (tracks) => playlist?.name ?? '',
        GroupSortType.creationDate => (tracks) => playlist?.creationDate.dateFormatted ?? '',
        GroupSortType.modifiedDate => (tracks) => playlist?.modifiedDate.dateFormatted ?? '',
        // ----
        GroupSortType.shuffle => null,
        GroupSortType.custom => null,
      };

  String? Function(LocalPlaylist playlist)? getGroupSortExtraTextResolverPlaylist(GroupSortType sort) => switch (sort) {
        GroupSortType.album => (p) => p.tracks.firstOrNull?.track.album,
        GroupSortType.artistsList => (p) => p.tracks.firstOrNull?.track.originalArtist,
        GroupSortType.composer => (p) => p.tracks.firstOrNull?.track.composer,
        GroupSortType.albumArtist => (p) => p.tracks.firstOrNull?.track.albumArtist,
        GroupSortType.label => (p) => p.tracks.firstOrNull?.track.label,
        GroupSortType.genresList => (p) => p.tracks.firstOrNull?.track.originalGenre,
        GroupSortType.numberOfTracks => (p) => p.tracks.length.toString(),
        GroupSortType.duration => (p) => p.tracks.totalDurationFormatted,
        GroupSortType.albumsCount => (p) => p.tracks.toTracks().toUniqueAlbums().length.toString(),
        GroupSortType.year => (p) => p.tracks.firstOrNull?.track.year.yearFormatted,
        GroupSortType.dateModified => (p) => p.tracks.firstOrNull?.track.dateModified.dateFormatted,
        GroupSortType.playCount => (p) => p.tracks.getTotalListenCount().toString(),
        GroupSortType.firstListen => (p) => p.tracks.getFirstListen()?.dateFormattedOriginal,
        GroupSortType.latestPlayed => (p) => p.tracks.getLatestListen()?.dateFormattedOriginal,

        // -- playlists
        GroupSortType.title => (playlist) => playlist.name,
        GroupSortType.creationDate => (playlist) => playlist.creationDate.dateFormatted,
        GroupSortType.modifiedDate => (playlist) => playlist.modifiedDate.dateFormatted,
        // ----
        GroupSortType.shuffle => null,
        GroupSortType.custom => null,
      };

  bool? _preparedResources;
  Future<void> prepareResources() async {
    if (_preparedResources == true) return;
    _preparedResources = true;
    final enabledSearchesList = settings.activeSearchMediaTypes;
    final enabledSearches = <MediaType, bool>{};
    enabledSearchesList.loop((f) => enabledSearches[f] = true);

    runningSearchesTempCount.value = runningSearchesTempCount.value + 1;

    Future prepareOrDispose(MediaType type, Future<SendPortWithCachedMessage> Function() prepareFn) {
      if ((enabledSearches[type] ?? false) && type != MediaType.track) {
        return prepareFn();
      } else {
        return super.closePorts(type);
      }
    }

    await Future.wait(MediaType.values.map((e) => prepareOrDispose(e, mediaTypeToPrepareFn(e))));

    runningSearchesTempCount.value = runningSearchesTempCount.value - 1;
  }

  void disposeResources() {
    _preparedResources = false;
    super.disposeAll();
  }

  @override
  Future<SendPortWithCachedMessage> Function() mediaTypeToPrepareFn(MediaType type) {
    return switch (type) {
      MediaType.album => () => _prepareMediaPorts(Indexer.inst.mainMapAlbums.value.keys, MediaType.album),
      MediaType.artist => () => _prepareMediaPorts(Indexer.inst.mainMapArtists.value.keys, MediaType.artist),
      MediaType.albumArtist => () => _prepareMediaPorts(Indexer.inst.mainMapAlbumArtists.value.keys, MediaType.albumArtist),
      MediaType.composer => () => _prepareMediaPorts(Indexer.inst.mainMapComposer.value.keys, MediaType.composer),
      MediaType.genre => () => _prepareMediaPorts(Indexer.inst.mainMapGenres.value.keys, MediaType.genre),
      MediaType.folder => () => _prepareMediaPorts(Indexer.inst.mainMapFolders.mapToPaths(), MediaType.folder),
      MediaType.folderVideo => () => _prepareMediaPorts(Indexer.inst.mainMapFoldersVideos.mapToPaths(), MediaType.folderVideo),
      MediaType.track => _prepareTracksPorts,
      MediaType.playlist => _preparePlaylistPorts,
    };
  }

  Future<SendPortWithCachedMessage> _prepareTracksPorts() async {
    return await super.preparePorts(
      type: MediaType.track,
      portRefreshListener: _tracksInfoList,
      onResult: (result) {
        runningSearchesTempCount.value = runningSearchesTempCount.value - 1;
        if (result == null) return; // -- prepared

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

  Map<String, dynamic> generateTrackSearchIsolateParams(SendPort sendPort) {
    final tracks = _tracksInfoList.value.map((e) => e.toTrackExt());
    return TracksSearchWrapper.generateParams(sendPort, tracks);
  }

  Future<SendPortWithCachedMessage> _preparePlaylistPorts() async {
    return await super.preparePorts(
      type: MediaType.playlist,
      portRefreshListener: playlistsMap,
      onResult: (result) {
        runningSearchesTempCount.value = runningSearchesTempCount.value - 1;
        if (result == null) return; // -- prepared

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
          'playlists': playlistsMap.value.values.map((e) => e.toJson((item) => item.toJson(), PlaylistController.inst.sortToJson)).toList(),
          'translations': {
            'k_PLAYLIST_NAME_AUTO_GENERATED': lang.AUTO_GENERATED,
            'k_PLAYLIST_NAME_FAV': lang.FAVOURITES,
            'k_PLAYLIST_NAME_HISTORY': lang.HISTORY,
            'k_PLAYLIST_NAME_MOST_PLAYED': lang.MOST_PLAYED,
          },
          'filters': settings.playlistSearchFilter.value,
          'cleanup': _shouldCleanup,
          'sendPort': itemsSendPort,
        };

        await Isolate.spawn(_searchPlaylistsIsolate, params);
      },
    );
  }

  Future<SendPortWithCachedMessage> _prepareMediaPorts(Iterable<String> keysList, MediaType type) async {
    return await super.preparePorts(
      type: type,
      portRefreshListener: switch (type) {
        MediaType.album => Indexer.inst.mainMapAlbums.rx,
        MediaType.artist => Indexer.inst.mainMapArtists.rx,
        MediaType.albumArtist => Indexer.inst.mainMapAlbumArtists.rx,
        MediaType.composer => Indexer.inst.mainMapComposer.rx,
        MediaType.genre => Indexer.inst.mainMapGenres.rx,
        MediaType.folder => Indexer.inst.mainMapFolders,
        MediaType.folderVideo => Indexer.inst.mainMapFoldersVideos,
        MediaType.track => null,
        MediaType.playlist => null,
      },
      onResult: (result) {
        runningSearchesTempCount.value = runningSearchesTempCount.value - 1;
        if (result == null) return; // -- prepared

        final r = result as (List<String>, bool, String);
        final isTemp = r.$2;
        final fetchedQuery = r.$3;

        if (isTemp) {
          if (fetchedQuery == lastSearchText) {
            _searchMapTemp[type]?.value = r.$1;
            // sortMedia(type);
          }
        } else {
          List<String> keysList;
          if (type == MediaType.album) {
            keysList = _modifyAlbumKeys(r.$1);
          } else {
            keysList = r.$1.toList();
          }

          final typeNomalize = type == MediaType.albumArtist || type == MediaType.composer ? MediaType.artist : type;
          if (fetchedQuery == typeNomalize.toLibraryTab().textSearchController?.text) _searchMap[typeNomalize]?.value = keysList;
        }
      },
      isolateFunction: (itemsSendPort) async {
        final params = {
          'keys': keysList.toList(),
          'cleanup': _shouldCleanup,
          'keyIsPath': type == MediaType.folder || type == MediaType.folderVideo,
          'sendPort': itemsSendPort,
        };

        await Isolate.spawn(_generalSearchIsolate, params);
      },
    );
  }

  void searchTracks(String text, {bool temp = false}) async {
    if (text == '') {
      super.closePorts(MediaType.track);
      if (temp) {
        trackSearchTemp.clear();
      } else {
        LibraryTab.tracks.textSearchController?.clear();
        trackSearchList.assignAll(_tracksInfoList.value);
      }
      return;
    }
    final sp = await _prepareTracksPorts();
    sp.send({
      'text': text,
      'temp': temp,
    });
  }

  static void searchTracksIsolate(Map params) {
    final sendPort = params['sendPort'] as SendPort;

    final receivePort = ReceivePort();

    sendPort.send(receivePort.sendPort);

    final searchWrapper = TracksSearchWrapper.init(params);

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

      final result = searchWrapper.filter(text);
      sendPort.send((result, temp, text));
    });

    sendPort.send(null);
  }

  List<String> _modifyAlbumKeys(Iterable<String> original) {
    final activeAlbumTypes = settings.activeAlbumTypes.value;
    final showSingles = activeAlbumTypes[AlbumType.single] ?? true;
    final showAlbums = activeAlbumTypes[AlbumType.normal] ?? true;

    if (showSingles == false && showAlbums == false) return [];

    if (!showSingles) {
      return original.where((element) => !(element.getAlbumTracks().length == 1)).toList();
    }
    if (!showAlbums) {
      return original.where((element) => element.getAlbumTracks().length == 1).toList();
    }

    return original.toList();
  }

  void _searchMediaType({required MediaType type, required String text, bool temp = false}) async {
    final Iterable<String> keys = switch (type) {
      MediaType.album => Indexer.inst.mainMapAlbums.value.keys,
      MediaType.artist => Indexer.inst.mainMapArtists.value.keys,
      MediaType.albumArtist => Indexer.inst.mainMapAlbumArtists.value.keys,
      MediaType.composer => Indexer.inst.mainMapComposer.value.keys,
      MediaType.genre => Indexer.inst.mainMapGenres.value.keys,
      MediaType.folder => Indexer.inst.mainMapFolders.mapToPaths(),
      MediaType.folderVideo => Indexer.inst.mainMapFoldersVideos.mapToPaths(),
      MediaType.track => <String>[],
      MediaType.playlist => <String>[],
    };

    if (text == '') {
      super.closePorts(type);
      if (temp) {
        _searchMapTemp[type]?.clear();
      } else {
        final typeNomalize = type == MediaType.albumArtist || type == MediaType.composer ? MediaType.artist : type;
        typeNomalize.toLibraryTab().textSearchController?.clear();
        List<String> keysList;
        if (type == MediaType.album) {
          keysList = _modifyAlbumKeys(keys);
        } else {
          keysList = keys.toList();
        }
        _searchMap[typeNomalize]?.value = keysList;
      }
      return;
    }

    final sp = await _prepareMediaPorts(keys, type);
    sp.send({
      'text': text,
      'temp': temp,
    });
  }

  void _searchPlaylists(String text, {bool temp = false}) async {
    if (text == '') {
      super.closePorts(MediaType.playlist);
      if (temp) {
        playlistSearchTemp.clear();
      } else {
        LibraryTab.playlists.textSearchController?.clear();
        playlistSearchList.value = playlistsMap.keys.toList();
      }
      return;
    }

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
    final textCleanedForSearch = _functionOfCleanup(cleanup);
    final textNonCleanedForSearch = cleanup ? _functionOfCleanup(false) : null;

    final playlists = <({
      LocalPlaylist pl,
      String trName,
      String dateCreatedFormatted,
      String dateModifiedFormatted,
    })>[];
    for (int i = 0; i < playlistsMap.length; i++) {
      var plMap = playlistsMap[i];
      final pl = LocalPlaylist.fromJson(plMap, (itemJson) => TrackWithDate.fromJson(itemJson), PlaylistController.sortFromJson);
      final trName = textCleanedForSearch(translatePlName(pl.name));
      final dateCreatedFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(pl.creationDate));
      final dateModifiedFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(pl.modifiedDate));
      playlists.add((
        pl: pl,
        trName: trName,
        dateCreatedFormatted: dateCreatedFormatted,
        dateModifiedFormatted: dateModifiedFormatted,
      ));
    }

    final psfMap = <String, bool>{};
    psf.loop((f) => psfMap[f] = true);

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
      final lctextNonCleaned = textNonCleanedForSearch == null ? null : textNonCleanedForSearch(text);

      bool isMatch(String property) {
        final match1 = property.contains(lctext);
        if (match1) return true;

        if (lctextNonCleaned != null) {
          final match2 = property.contains(lctextNonCleaned);
          if (match2) return true;
        }

        return false;
      }

      final results = <String>[];
      playlists.loop((itemInfo) {
        final item = itemInfo.pl;
        final playlistName = item.name;

        if ((sTitle && (isMatch(itemInfo.trName))) ||
            (sCreationDate && isMatch(itemInfo.dateCreatedFormatted)) ||
            (sModifiedDate && isMatch(itemInfo.dateModifiedFormatted)) ||
            (sComment && isMatch(item.comment)) ||
            (sMoods && item.moods.any((element) => isMatch(element)))) {
          results.add(playlistName);
        }
      });
      sendPort.send((results, temp, text));
    });

    sendPort.send(null);
  }

  Future<void> sortAll() async {
    await Future.delayed(Duration.zero, _sortTracks);
    await Future.delayed(Duration.zero, _sortAlbums);
    await Future.delayed(Duration.zero, () => _sortArtistsCurrent(artistType: settings.activeArtistType.value));
    await Future.delayed(Duration.zero, _sortGenres);
    await Future.delayed(Duration.zero, _sortPlaylists);
  }

  void sortMedia(MediaType media, {SortType? sortBy, GroupSortType? groupSortBy, bool? reverse, bool forceSingleSorting = false}) {
    switch (media) {
      case MediaType.track:
        _sortTracks(sortBy: sortBy, reverse: reverse, forceSingleSorting: forceSingleSorting);
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
  void _sortTracks({SortType? sortBy, bool? reverse, bool forceSingleSorting = false}) {
    final trackSortsSettings = settings.mediaItemsTrackSorting.value[MediaType.track];

    sortBy ??= trackSortsSettings?.firstOrNull;
    reverse ??= settings.mediaItemsTrackSortingReverse.value[MediaType.track];

    if (forceSingleSorting) {
      settings.updateMediaItemsTrackSortingAll(MediaType.track, sortBy == null ? null : [sortBy], reverse);

      _sortTracksRaw(
        sortBy: sortBy,
        reverse: reverse ?? false,
        list: _tracksInfoList.value,
        onDone: (sortType, isReverse) {
          searchTracks(LibraryTab.tracks.textSearchController?.text ?? '');
        },
      );
    } else {
      settings.updateMediaItemsTrackSortingAll(
        MediaType.track,
        sortBy == null
            ? null
            : trackSortsSettings == null || trackSortsSettings.isEmpty
                ? [sortBy]
                : [
                    if (!trackSortsSettings.contains(sortBy)) sortBy,
                    ...trackSortsSettings,
                  ],
        reverse,
      );
      Indexer.inst.sortMediaTracksSubLists([MediaType.track]);
    }

    _tracksInfoList.refresh();
  }

  void sortTracksSearch({SortType? sortBy, bool? reverse, bool canSkipSorting = false}) {
    final isAuto = settings.tracksSortSearchIsAuto.value;

    sortBy ??= isAuto ? settings.mediaItemsTrackSorting.value[MediaType.track]?.firstOrNull ?? settings.tracksSortSearch.value : settings.tracksSortSearch.value;
    reverse ??= isAuto ? settings.mediaItemsTrackSortingReverse.value[MediaType.track] ?? settings.tracksSortSearchReversed.value : settings.tracksSortSearchReversed.value;

    if (canSkipSorting) {
      final identicalToMainOne =
          isAuto ? true : sortBy == settings.mediaItemsTrackSorting.value[MediaType.track]?.firstOrNull && reverse == settings.mediaItemsTrackSortingReverse.value[MediaType.track];
      if (identicalToMainOne) return; // since the looped list already has the same order
    }

    _sortTracksRaw(
      sortBy: sortBy,
      reverse: reverse,
      list: trackSearchTemp.value,
      onDone: (sortType, isReverse) {
        if (!isAuto) settings.save(tracksSortSearch: sortType, tracksSortSearchReversed: isReverse);
        trackSearchTemp.refresh();
      },
    );
  }

  void _sortTracksRaw({
    required SortType? sortBy,
    required bool reverse,
    required List<Track> list,
    required void Function(SortType? sortType, bool isReverse) onDone,
  }) {
    final ignoreCommonPrefix = settings.ignoreCommonPrefixForTypes.value;

    void sortThis(Comparable Function(Track e) comparable) => reverse ? list.sortByReverse(comparable) : list.sortBy(comparable);
    void sortThisAlts(List<Comparable<dynamic> Function(Track tr)> alternatives) => reverse ? list.sortByReverseAlts(alternatives) : list.sortByAlts(alternatives);

    String Function(Track e) encapsulateSortCanIgnorePrefix(TrackSearchFilter filter, String Function(Track e) comparable) {
      if (ignoreCommonPrefix.contains(filter)) {
        return (e) => comparable(e).ignoreCommonPrefixes();
      } else {
        return comparable;
      }
    }

    void sortThisCanIgnorePrefix(TrackSearchFilter filter, String Function(Track e) comparable) {
      if (ignoreCommonPrefix.contains(filter)) {
        sortThis((e) => comparable(e).ignoreCommonPrefixes());
      } else {
        sortThis(comparable);
      }
    }

    switch (sortBy) {
      case SortType.title:
        sortThisCanIgnorePrefix(TrackSearchFilter.title, (e) => e.title.toLowerCase());
      case SortType.album:
        final sameAlbumSorters = getMediaTracksSortingComparables(MediaType.album);
        sortThisAlts(
          [
            encapsulateSortCanIgnorePrefix(TrackSearchFilter.album, (tr) => tr.album.toLowerCase()),
            ...sameAlbumSorters,
          ],
        );
        break;
      case SortType.albumArtist:
        final sameAlbumSorters = getMediaTracksSortingComparables(MediaType.albumArtist);
        sortThisAlts(
          [
            encapsulateSortCanIgnorePrefix(TrackSearchFilter.albumartist, (tr) => tr.albumArtist.toLowerCase()),
            ...sameAlbumSorters,
          ],
        );
        break;
      case SortType.year:
        sortThis((e) => e.yearPreferyyyyMMdd);
        break;
      case SortType.artistsList:
        final sameArtistSorters = getMediaTracksSortingComparables(MediaType.artist);
        sortThisAlts(
          [
            encapsulateSortCanIgnorePrefix(TrackSearchFilter.album, (tr) => tr.artistsList.join().toLowerCase()),
            ...sameArtistSorters,
          ],
        );
        break;
      case SortType.genresList:
        final sameGenreSorters = getMediaTracksSortingComparables(MediaType.genre);
        sortThisAlts(
          [
            encapsulateSortCanIgnorePrefix(TrackSearchFilter.genre, (tr) => tr.genresList.join().toLowerCase()),
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
        sortThis((e) => e.durationMS);
        break;
      case SortType.sampleRate:
        sortThis((e) => e.sampleRate);
        break;
      case SortType.size:
        sortThis((e) => e.size);
        break;
      case SortType.rating:
        sortThis((e) => e.effectiveRating);
        break;
      case SortType.shuffle:
        list.shuffle();
        break;
      case SortType.mostPlayed:
        sortThis((e) => -(HistoryController.inst.topTracksMapListens.value[e]?.length ?? 0));
        break;
      case SortType.latestPlayed:
        sortThis((e) => HistoryController.inst.topTracksMapListens.value[e]?.lastOrNull ?? 0);
        break;
      case SortType.firstListen:
        sortThis((e) => HistoryController.inst.topTracksMapListens.value[e]?.firstOrNull ?? 0);
        break;

      case null:
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

    sortAlbumsListRaw(albumsList, sortBy, reverse);

    finalMap.value.assignAllEntries(albumsList);
    finalMap.refresh();

    settings.save(albumSort: sortBy, albumSortReversed: reverse);

    _searchMediaType(type: MediaType.album, text: LibraryTab.albums.textSearchController?.text ?? '');
  }

  void sortAlbumsListRaw(List<MapEntry<String, List<Track>>> albumsList, GroupSortType sortBy, bool reverse) {
    if (sortBy == GroupSortType.shuffle) {
      albumsList.shuffle();
    } else {
      final allComparables = {
        sortBy,
        GroupSortType.album,
        GroupSortType.year,
        GroupSortType.dateModified,
      }
          .map((e) => e == sortBy ? _getMediaSortingComparable(e, overrideKey: GroupSortType.album, filter: TrackSearchFilter.album) : _getMediaSortingComparable(e))
          .whereType<Comparable Function(MapEntry<String, List<Track>>)>()
          .toList();
      if (reverse) {
        albumsList.sortByReverseAlts(allComparables);
      } else {
        albumsList.sortByAlts(allComparables);
      }
    }
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

    if (sortBy == GroupSortType.shuffle) {
      artistsList.shuffle();
    } else {
      final fallbackGroupSortTitle = switch (artistType) {
        MediaType.artist => GroupSortType.artistsList,
        MediaType.albumArtist => GroupSortType.albumArtist,
        MediaType.composer => GroupSortType.composer,
        _ => null,
      };
      final allComparables = {
        sortBy,
        if (fallbackGroupSortTitle != null) fallbackGroupSortTitle,
        GroupSortType.year,
        GroupSortType.dateModified,
      }
          .map(
            (e) => e == sortBy
                ? artistType == MediaType.artist && sortBy == GroupSortType.artistsList
                    ? _getMediaSortingComparable(e, overrideKey: GroupSortType.artistsList, filter: TrackSearchFilter.artist)
                    : artistType == MediaType.albumArtist && sortBy == GroupSortType.albumArtist
                        ? _getMediaSortingComparable(e, overrideKey: GroupSortType.albumArtist, filter: TrackSearchFilter.albumartist)
                        : artistType == MediaType.composer && sortBy == GroupSortType.composer
                            ? _getMediaSortingComparable(e, overrideKey: GroupSortType.composer, filter: TrackSearchFilter.composer)
                            : _getMediaSortingComparable(e, overrideKey: GroupSortType.artistsList, filter: TrackSearchFilter.artist)
                : _getMediaSortingComparable(e),
          )
          .whereType<Comparable Function(MapEntry<String, List<Track>>)>()
          .toList();
      if (sortBy == GroupSortType.albumsCount) {
        final Comparable Function(MapEntry<String, List<Track>>) comparable = artistType == MediaType.albumArtist
            ? (e) => e.key.getAlbumArtistTracks().toUniqueAlbums().length
            : artistType == MediaType.composer
                ? (e) => e.key.getComposerTracks().toUniqueAlbums().length
                : (e) => e.key.getArtistTracks().toUniqueAlbums().length;

        allComparables.insert(0, comparable);
      }

      if (reverse) {
        artistsList.sortByReverseAlts(allComparables);
      } else {
        artistsList.sortByAlts(allComparables);
      }
    }

    finalMap.value.assignAllEntries(artistsList);
    finalMap.refresh();

    settings.save(artistSort: sortBy, artistSortReversed: reverse);

    _searchMediaType(type: artistType, text: LibraryTab.artists.textSearchController?.text ?? '');
  }

  /// Sorts Genres and Saves automatically to settings
  void _sortGenres({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= settings.genreSort.value;
    reverse ??= settings.genreSortReversed.value;

    final finalMap = Indexer.inst.mainMapGenres;
    final genresList = finalMap.value.entries.toList();

    if (sortBy == GroupSortType.shuffle) {
      genresList.shuffle();
    } else {
      final allComparables = {
        sortBy,
        GroupSortType.genresList,
        GroupSortType.year,
        GroupSortType.dateModified,
      }
          .map((e) => e == sortBy ? _getMediaSortingComparable(e, overrideKey: GroupSortType.genresList, filter: TrackSearchFilter.genre) : _getMediaSortingComparable(e))
          .whereType<Comparable Function(MapEntry<String, List<Track>>)>()
          .toList();
      if (reverse) {
        genresList.sortByReverseAlts(allComparables);
      } else {
        genresList.sortByAlts(allComparables);
      }
    }

    finalMap.value.assignAllEntries(genresList);
    finalMap.refresh();

    settings.save(genreSort: sortBy, genreSortReversed: reverse);
    _searchMediaType(type: MediaType.genre, text: LibraryTab.genres.textSearchController?.text ?? '');
  }

  /// Sorts Playlists and Saves automatically to settings
  void _sortPlaylists({GroupSortType? sortBy, bool? reverse, Map<String, int>? customIndicesOrder}) {
    sortBy ??= settings.playlistSort.value;
    reverse ??= settings.playlistSortReversed.value;

    final playlistList = playlistsMap.entries.toList();
    void sortThis(Comparable Function(MapEntry<String, LocalPlaylist> p) comparable) => reverse! ? playlistList.sortByReverse(comparable) : playlistList.sortBy(comparable);

    final customIndicesOrder = PlaylistController.inst.customIndicesOrderRx.value;
    if (sortBy == GroupSortType.custom && customIndicesOrder == null) {
      sortBy = GroupSortType.title;
    }

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
        sortThis((p) => p.value.tracks.totalDurationInMS);
        break;
      case GroupSortType.numberOfTracks:
        sortThis((p) => -p.value.tracks.length);
        break;
      case GroupSortType.playCount:
        sortThis((e) => -e.value.tracks.getTotalListenCount());
        break;
      case GroupSortType.firstListen:
        sortThis((e) => e.value.tracks.getFirstListen() ?? DateTime(99999).millisecondsSinceEpoch);
        break;
      case GroupSortType.latestPlayed:
        sortThis((e) => -(e.value.tracks.getLatestListen() ?? 0));
        break;
      case GroupSortType.shuffle:
        playlistList.shuffle();
        break;
      case GroupSortType.custom:
        final indices = <String, int>{};
        for (int i = 0; i < customIndicesOrder!.length; i++) {
          indices[customIndicesOrder[i]] = i;
        }
        sortThis((p) => indices[p.key] ?? (playlistList.length - 1));
        break;

      default:
        null;
    }

    playlistsMap.value.assignAllEntries(playlistList);
    playlistsMap.refresh();

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

    final textCleanedForSearch = _functionOfCleanup(cleanup);
    final textNonCleanedForSearch = cleanup ? _functionOfCleanup(false) : null;

    final keysCleaned = <String>[];
    final keysNonCleaned = textNonCleanedForSearch == null ? null : <String>[];
    if (keyIsPath) {
      for (int i = 0; i < keys.length; i++) {
        var path = keys[i];
        final folder = Folder.explicit(path);
        final folderName = folder.folderName;
        keysCleaned.add(textCleanedForSearch(folderName)); // if adding failed we are cooked
        if (keysNonCleaned != null) {
          keysNonCleaned.add(textNonCleanedForSearch!(folderName));
        }
      }
    } else {
      for (int i = 0; i < keys.length; i++) {
        var kd = keys[i];
        keysCleaned.add(textCleanedForSearch(kd));
        if (keysNonCleaned != null) {
          keysNonCleaned.add(textNonCleanedForSearch!(kd));
        }
      }
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
      final lctextNonCleaned = textNonCleanedForSearch == null ? null : textNonCleanedForSearch(text);

      bool isMatch(int keyIndex) {
        final match1 = keysCleaned[keyIndex].contains(lctext);
        if (match1) return true;

        if (keysNonCleaned != null) {
          final match2 = keysNonCleaned[keyIndex].contains(lctextNonCleaned!);
          if (match2) return true;
        }

        return false;
      }

      final results = <String>[];
      for (int i = 0; i < keys.length; i++) {
        if (isMatch(i)) {
          results.add(keys[i]);
        }
      }
      sendPort.send((results, temp, text));
    });

    sendPort.send(null);
  }

  bool get _shouldCleanup => settings.enableSearchCleanup.value;

  static String Function(String text) _functionOfCleanup(bool enableSearchCleanup) {
    return (String textToClean) => enableSearchCleanup ? textToClean.cleanUpForComparison : textToClean.toLowerCase();
  }
}

extension _FolderMapExt<T> on RxMap<Folder, List<T>> {
  Iterable<String> mapToPaths() {
    return value.keys.map((key) => key.path);
  }
}
