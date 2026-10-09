import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:history_manager/history_manager.dart';
import 'package:intl/intl.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/base/tracks_search_wrapper.dart';
import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/romanizer/romanizer.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_ports_provider.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/sort_key.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';

class SearchSortController extends SearchPortsProvider {
  static SearchSortController get inst => _instance;
  static final SearchSortController _instance = SearchSortController._internal();
  SearchSortController._internal();

  final _lastSearchText = ''.obs;
  RxBaseCore<String> get lastSearchTextRx => _lastSearchText;
  String get lastSearchText => _lastSearchText.value;
  set lastSearchText(String text) => _lastSearchText.value = text;

  bool get isSearching =>
      trackSearchTemp.isNotEmpty ||
      albumSearchTemp.isNotEmpty ||
      artistSearchTemp.isNotEmpty ||
      albumArtistSearchTemp.isNotEmpty ||
      composerSearchTemp.isNotEmpty ||
      genreSearchTemp.isNotEmpty ||
      styleSearchTemp.isNotEmpty ||
      languageSearchTemp.isNotEmpty ||
      playlistSearchTemp.isNotEmpty ||
      folderTracksSearchTemp.isNotEmpty ||
      folderVideosSearchTemp.isNotEmpty ||
      moodSearchTemp.isNotEmpty ||
      tagSearchTemp.isNotEmpty;

  final trackSearchList = <Track>[].obs;
  final albumSearchList = <AlbumIdentifierWrapper>[].obs;
  final playlistSearchList = <String>[].obs;
  RxList<String> get artistSearchList => _searchMap[MediaType.artist]!;
  RxList<String> get genreSearchList => _searchMap[MediaType.genre]!;
  RxList<String> get languageSearchList => _searchMap[MediaType.language]!;

  final _searchMap = <MediaType, RxList<String>>{
    MediaType.artist: <String>[].obs,
    MediaType.genre: <String>[].obs,
    MediaType.language: <String>[].obs,
  };

  // -- Temporary lists, used for global search --
  final _searchMapTemp = <MediaType, RxList<String>>{
    MediaType.artist: <String>[].obs,
    MediaType.albumArtist: <String>[].obs,
    MediaType.composer: <String>[].obs,
    MediaType.genre: <String>[].obs,
    MediaType.style: <String>[].obs,
    MediaType.language: <String>[].obs,
    MediaType.folder: <String>[].obs,
    MediaType.folderMusic: <String>[].obs,
    MediaType.folderVideo: <String>[].obs,
    MediaType.tag: <String>[].obs,
    MediaType.mood: <String>[].obs,
  };

  final trackSearchTemp = <Track>[].obs;
  final trackSearchTempLessRelevant = <Track>[].obs;
  final albumSearchTemp = <AlbumIdentifierWrapper>[].obs;
  final playlistSearchTemp = <String>[].obs;
  RxList<String> get artistSearchTemp => _searchMapTemp[MediaType.artist]!;
  RxList<String> get albumArtistSearchTemp => _searchMapTemp[MediaType.albumArtist]!;
  RxList<String> get composerSearchTemp => _searchMapTemp[MediaType.composer]!;
  RxList<String> get genreSearchTemp => _searchMapTemp[MediaType.genre]!;
  RxList<String> get styleSearchTemp => _searchMapTemp[MediaType.style]!;
  RxList<String> get languageSearchTemp => _searchMapTemp[MediaType.language]!;
  RxList<String> get folderTracksSearchTemp => _searchMapTemp[MediaType.folderMusic]!;
  RxList<String> get folderVideosSearchTemp => _searchMapTemp[MediaType.folderVideo]!;
  RxList<String> get moodSearchTemp => _searchMapTemp[MediaType.mood]!;
  RxList<String> get tagSearchTemp => _searchMapTemp[MediaType.tag]!;

  RxBaseCore<List<Object>> getTempResultsRx(MediaType type) => switch (type) {
    MediaType.track => trackSearchTemp,
    MediaType.album => albumSearchTemp,
    MediaType.playlist => playlistSearchTemp,
    _ => _searchMapTemp[type]!,
  };

  RxList<Track> get _tracksInfoList => Indexer.inst.tracksInfoList;

  LibraryTab _activeTracksTab = LibraryTab.tracks;
  LibraryTab _trackSearchListTab = LibraryTab.tracks;

  void setActiveTracksTab(LibraryTab tab) {
    _activeTracksTab = tab;
    if (_trackSearchListTab != tab) refreshTrackSearchList();
  }

  void refreshTrackSearchList() => searchTracks(_activeTracksTab.textSearchController?.text ?? '');

  void onTrackIndexed(Track tr) {
    final isVideo = _trackSearchListTab.isVideoFilter;
    if (isVideo == null || (tr is Video) == isVideo) trackSearchList.value.add(tr); // -- refreshed by the indexer
  }

  RxMap<String, LocalPlaylist> get playlistsMap => PlaylistController.inst.playlistsMap;

  Map get runningTempSearches => _runningTempSearches;

  final _runningTempSearches = <MediaType, String>{};
  bool _preparingResources = false;

  final runningSearchesTempCount = 0.obs;

  void _refreshRunningSearchesCount() {
    runningSearchesTempCount.value = _runningTempSearches.length + (_preparingResources ? 1 : 0);
  }

  void _onTempSearchStarted(MediaType type, String text) {
    _runningTempSearches[type] = text;
    _refreshRunningSearchesCount();
  }

  /// byll [text] means search nuked (not finished)
  void _onTempSearchEnded(MediaType type, String? text) {
    if (text != null && _runningTempSearches[type] != text) return;
    if (_runningTempSearches.remove(type) != null) _refreshRunningSearchesCount();
  }

  @override
  Future<void> closePorts(MediaType type) {
    _onTempSearchEnded(type, null);
    return super.closePorts(type);
  }

  /// null [sendPort] means port dead before it could be used
  void _sendSearchRequest(MediaType type, SendPortWithCachedMessage? sendPort, String text, bool temp, {bool? isVideo}) {
    if (sendPort == null) {
      if (temp) _onTempSearchEnded(type, text);
      return;
    }
    sendPort.send((text: text, temp: temp, isVideo: isVideo));
  }

  void searchAll(String text) {
    lastSearchText = text;
    final enabledSearches = settings.activeSearchMediaTypes;

    searchTracks(text, temp: true);

    for (final es in enabledSearches.value) {
      if (es == MediaType.track) {
        // -- we always search
      } else if (es == MediaType.album) {
        _searchAlbums(text, temp: true);
      } else if (es == MediaType.playlist) {
        _searchPlaylists(text, temp: true);
      } else {
        _searchMediaType(type: es, text: text, temp: true);
      }
    }
  }

  void setTracksSearchTemp(List<Track> tracks) {
    trackSearchTemp.value = _filterTracksKind(tracks, _activeTrSearchIsVideo);
    trackSearchTempLessRelevant.clear();
    sortTracksSearch();
  }

  void toggleLessRelevantTracksSearch() {
    final shouldShow = !settings.tracksSearchShowLessRelevant.value;
    settings.tracksSearchShowLessRelevant.save(shouldShow);
    final lessRelevant = trackSearchTempLessRelevant.value;
    if (shouldShow) {
      trackSearchTemp.value.addAll(lessRelevant);
    } else {
      final lessRelevantSet = lessRelevant.toSet();
      trackSearchTemp.value.removeWhere(lessRelevantSet.contains);
    }
    final needsSorting = shouldShow && !settings.tracksSortSearchIsAuto.value;
    if (needsSorting) {
      sortTracksSearch();
    } else {
      trackSearchTemp.refresh();
    }
  }

  bool? get _activeTrSearchIsVideo {
    final activeTypes = settings.activeTrSearch.value;
    final tracksActive = activeTypes[TrackTypeSearch.tr] ?? true;
    final videosActive = activeTypes[TrackTypeSearch.v] ?? true;
    if (tracksActive && videosActive) return null;
    return videosActive;
  }

  static List<Track> _filterTracksKind(List<Track> tracks, bool? isVideo) {
    if (isVideo == null) return tracks;
    if (isVideo) return <Track>[...tracks.whereType<Video>()];
    return tracks.where((e) => e is! Video).toList();
  }

  List<String> _filterNonEmptyFolders(MediaType type, List<String> folders) {
    return switch (type) {
      MediaType.folderMusic => folders.where((f) => Folder.explicit(f).tracksDedicated().isNotEmpty).toList(),
      MediaType.folderVideo => folders.where((f) => VideoFolder.explicit(f).tracksDedicated().isNotEmpty).toList(),
      _ => folders,
    };
  }

  void toggleSearchMediaType(MediaType type) async {
    if (settings.activeSearchMediaTypes.value.contains(type)) {
      settings.activeSearchMediaTypes.update((list) => list.remove(type));
      _clearTempResults(type);
      await disposeMediaResources(type);
    } else {
      settings.activeSearchMediaTypes.update((list) => list.addNoDuplicates(type));
      await prepareResources();
      searchAll(ScrollSearchController.inst.searchTextEditingController.text);
    }
  }

  void toggleSearchTrackType(TrackTypeSearch type) {
    final activeTypes = settings.activeTrSearch.value;
    final isTracks = type == TrackTypeSearch.tr;
    final tracksActive = activeTypes[TrackTypeSearch.tr] ?? true;
    final videosActive = activeTypes[TrackTypeSearch.v] ?? true;
    var tracks = isTracks ? !tracksActive : tracksActive;
    var videos = isTracks ? videosActive : !videosActive;
    if (!tracks && !videos) {
      // -- at least one should be active, switch to the other
      tracks = !isTracks;
      videos = isTracks;
    }
    settings.updateActiveTrSearch(tracks: tracks, videos: videos);
    searchAll(ScrollSearchController.inst.searchTextEditingController.text);
  }

  void _clearTempResults(MediaType type) {
    switch (type) {
      case MediaType.track:
        trackSearchTemp.clear();
        trackSearchTempLessRelevant.clear();
      case MediaType.album:
        albumSearchTemp.clear();
      case MediaType.playlist:
        playlistSearchTemp.clear();
      default:
        _searchMapTemp[type]?.clear();
    }
  }

  Future<void> disposeMediaResources(MediaType? media) async {
    if (media == null) return;
    return closePorts(media);
  }

  void searchMedia(String text, MediaType? media) {
    switch (media) {
      case MediaType.track:
        searchTracks(text);
        break;
      case MediaType.album:
        _searchAlbums(text);
        break;
      case MediaType.artist:
      case MediaType.albumArtist:
      case MediaType.composer:
        _searchMediaType(type: settings.activeArtistType.value, text: text);
      case MediaType.genre:
      case MediaType.style:
        _searchMediaType(type: settings.activeGenreType.value, text: text);
        break;
      case MediaType.language:
        _searchMediaType(type: MediaType.language, text: text);
        break;
      case MediaType.playlist:
        _searchPlaylists(text);
        break;

      default:
        null;
    }
  }

  String Function(String text) get sortKeyNormalizer {
    if (settings.romanizeSorting.value) return (text) => SortKey.of(Romanizer.inst.romanizeForSorting(text));
    return SortKey.of;
  }

  Comparable Function(MapEntry<String, List<Track>>)? _getMediaSortingComparable(GroupSortType type, {GroupSortType? overrideKey, TrackSearchFilter? filter}) {
    final ignoreCommonPrefix = settings.ignoreCommonPrefixForTypes.value;
    final normalize = sortKeyNormalizer;

    String Function(MapEntry<String, List<Track>> e) encapsulateSortCanIgnorePrefix(TrackSearchFilter filter, String Function(MapEntry<String, List<Track>> e) comparable) {
      if (ignoreCommonPrefix.contains(filter)) {
        return (e) => comparable(e).ignoreCommonPrefixes();
      } else {
        return comparable;
      }
    }

    if (type == overrideKey && filter != null) {
      return encapsulateSortCanIgnorePrefix(filter, (e) => normalize(e.key));
    }

    return switch (type) {
      GroupSortType.album => encapsulateSortCanIgnorePrefix(TrackSearchFilter.album, (e) => normalize(e.value.first.albumsList.join())),
      GroupSortType.albumArtist => encapsulateSortCanIgnorePrefix(TrackSearchFilter.albumartist, (e) => normalize(e.value.albumArtist)),
      GroupSortType.year => (e) => e.value.yearPreferyyyyMMdd,
      GroupSortType.artistsList => encapsulateSortCanIgnorePrefix(TrackSearchFilter.artist, (e) => normalize(e.value.first.artistsList.join())),
      GroupSortType.genresList => encapsulateSortCanIgnorePrefix(TrackSearchFilter.genre, (e) => normalize(e.value.first.genresList.join())),
      GroupSortType.composer => encapsulateSortCanIgnorePrefix(TrackSearchFilter.composer, (e) => normalize(e.value.composer)),
      GroupSortType.label => (e) => normalize(e.value.recordLabel),
      GroupSortType.releaseType => (e) => e.value.releaseType.toLowerCase(),
      GroupSortType.bpm => (e) => e.value.getAverageBpm(),
      GroupSortType.dateAdded => (e) => e.value.getDateAddedEffective() ?? 0,
      GroupSortType.dateModified => (e) => e.value.getDateModifiedEffective() ?? 0,
      GroupSortType.duration => (e) => e.value.totalDurationInMS,
      GroupSortType.numberOfTracks => (e) => -e.value.length,
      GroupSortType.playCount => (e) => -e.value.getTotalListenCount(),
      GroupSortType.firstListen => (e) => e.value.getFirstListen() ?? DateTime(99999).millisecondsSinceEpoch,
      GroupSortType.latestPlayed => (e) => -(e.value.getLatestListen() ?? 0),
      GroupSortType.albumSort =>
        (e) => normalize(e.value.albumSort).nullifyEmpty() ?? encapsulateSortCanIgnorePrefix(TrackSearchFilter.album, (e) => normalize(e.value.first.albumsList.join()))(e),
      GroupSortType.albumArtistSort =>
        (e) => normalize(e.value.albumArtistSort).nullifyEmpty() ?? encapsulateSortCanIgnorePrefix(TrackSearchFilter.albumartist, (e) => normalize(e.value.albumArtist))(e),
      GroupSortType.artistSort =>
        (e) => normalize(e.value.artistSort).nullifyEmpty() ?? encapsulateSortCanIgnorePrefix(TrackSearchFilter.artist, (e) => normalize(e.value.first.artistsList.join()))(e),
      GroupSortType.composerSort =>
        (e) => normalize(e.value.composerSort).nullifyEmpty() ?? encapsulateSortCanIgnorePrefix(TrackSearchFilter.composer, (e) => normalize(e.value.composer))(e),
      GroupSortType.shuffleDaily => createDailyShuffleComparable<MapEntry<String, List<Track>>>((e) => e.key),
      _ => null,
    };
  }

  Comparable Function(MapEntry<String, List<Track>>) _getArtistsAlbumsCountComparable(MediaType artistType) => switch (artistType) {
    MediaType.albumArtist => (e) => -e.key.getAlbumArtistTracks().toUniqueAlbums().length,
    MediaType.composer => (e) => -e.key.getComposerTracks().toUniqueAlbums().length,
    _ => (e) => -e.key.getArtistTracks().toUniqueAlbums().length,
  };

  static QueueSource Function(String name) _artistQueueSourceOf(MediaType artistType) => switch (artistType) {
    MediaType.albumArtist => QueueSource.albumArtist,
    MediaType.composer => QueueSource.composer,
    _ => QueueSource.artist,
  };

  static QueueSource Function(String name) _genreQueueSourceOf(MediaType genreType) => genreType == MediaType.style ? QueueSource.style : QueueSource.genre;

  static QueueSource Function(String name) _moodsTagsQueueSourceOf(MediaType type) => type == MediaType.tag ? QueueSource.tags : QueueSource.moods;

  static Comparable Function(MapEntry<String, List<Track>>) _createLastPlayedComparable(QueueSource Function(String name) sourceOf) {
    final latestPlayedForSource = QueueController.latestPlayedForSourceManager;
    return (e) => -(latestPlayedForSource.latestPlayedTime(sourceOf(e.key)) ?? 0);
  }

  Comparable Function(MapEntry<String, List<Track>>)? _getArtistsSortingComparable(MediaType artistType, GroupSortType sortBy) {
    if (sortBy == GroupSortType.lastPlayed) return _createLastPlayedComparable(_artistQueueSourceOf(artistType));
    if (artistType == MediaType.albumArtist && sortBy == GroupSortType.albumArtist) {
      return _getMediaSortingComparable(sortBy, overrideKey: GroupSortType.albumArtist, filter: TrackSearchFilter.albumartist);
    }
    if (artistType == MediaType.composer && sortBy == GroupSortType.composer) {
      return _getMediaSortingComparable(sortBy, overrideKey: GroupSortType.composer, filter: TrackSearchFilter.composer);
    }
    return _getMediaSortingComparable(sortBy, overrideKey: GroupSortType.artistsList, filter: TrackSearchFilter.artist);
  }

  Comparable Function(MapEntry<String, List<Track>>)? _getGenresSortingComparable(MediaType genreType, GroupSortType sortBy) {
    if (sortBy == GroupSortType.lastPlayed) return _createLastPlayedComparable(_genreQueueSourceOf(genreType));
    return _getMediaSortingComparable(sortBy, overrideKey: GroupSortType.genresList, filter: TrackSearchFilter.genre);
  }

  Comparable Function(MapEntry<String, List<Track>>)? _getLanguagesSortingComparable(GroupSortType sortBy) {
    if (sortBy == GroupSortType.lastPlayed) return _createLastPlayedComparable(QueueSource.language);
    return _getMediaSortingComparable(sortBy, overrideKey: GroupSortType.title, filter: TrackSearchFilter.language);
  }

  Comparable Function(MapEntry<String, List<Track>>)? _getMoodsTagsSortingComparable(MediaType type, GroupSortType sortBy) {
    if (sortBy == GroupSortType.lastPlayed) return _createLastPlayedComparable(_moodsTagsQueueSourceOf(type));
    final filter = type == MediaType.tag ? TrackSearchFilter.tags : TrackSearchFilter.moods;
    return _getMediaSortingComparable(sortBy, overrideKey: GroupSortType.title, filter: filter);
  }

  Comparable Function(Track e) getTracksSortingComparables(SortType type) {
    final ignoreCommonPrefix = settings.ignoreCommonPrefixForTypes.value;
    final normalize = sortKeyNormalizer;
    String? normalizeOrNull(String? text) => text == null || text.isEmpty ? null : normalize(text);
    String Function(Track e) encapsulateSortCanIgnorePrefix(TrackSearchFilter filter, String Function(Track e) comparable) {
      if (ignoreCommonPrefix.contains(filter)) {
        return (e) => comparable(e).ignoreCommonPrefixes();
      } else {
        return comparable;
      }
    }

    String Function(Track e) sortInfoOrFallback(String? Function(Track e) sortInfoValue, TrackSearchFilter fallbackFilter, String Function(Track e) fallback) {
      final fallbackKey = encapsulateSortCanIgnorePrefix(fallbackFilter, fallback);
      return (e) => normalizeOrNull(sortInfoValue(e)) ?? fallbackKey(e);
    }

    return switch (type) {
      SortType.title => encapsulateSortCanIgnorePrefix(TrackSearchFilter.title, (e) => normalize(e.title)),
      SortType.album => encapsulateSortCanIgnorePrefix(TrackSearchFilter.album, (e) => normalize(e.albumsList.join())),
      SortType.albumArtist => encapsulateSortCanIgnorePrefix(TrackSearchFilter.albumartist, (e) => normalize(e.albumArtist)),
      SortType.year => (e) => e.yearPreferyyyyMMdd,
      SortType.artistsList => encapsulateSortCanIgnorePrefix(TrackSearchFilter.artist, (e) => normalize(e.artistsList.join())),
      SortType.genresList => encapsulateSortCanIgnorePrefix(TrackSearchFilter.genre, (e) => normalize(e.genresList.join())),
      SortType.dateAdded => (e) => e.dateAdded,
      SortType.dateModified => (e) => e.dateModified,
      SortType.bitrate => (e) => e.bitrate,
      SortType.composer => encapsulateSortCanIgnorePrefix(TrackSearchFilter.composer, (e) => normalize(e.composer)),
      SortType.trackNo => (e) => e.trackNo,
      SortType.discNo => (e) => e.discNo,
      SortType.filename => encapsulateSortCanIgnorePrefix(TrackSearchFilter.filename, (e) => normalize(e.filename)),
      SortType.path => (e) => e.path,
      SortType.duration => (e) => e.durationMS,
      SortType.sampleRate => (e) => e.sampleRate,
      SortType.bitDepth => (e) => e.bits,
      SortType.bpm => (e) => e.bpm ?? 0,
      SortType.size => (e) => e.size,
      SortType.rating => (e) => e.effectiveRating,
      SortType.favourite => _createFavouriteComparable(),
      SortType.mostPlayed => (e) => -(HistoryController.inst.topTracksMapListens.value[e]?.length ?? 0),
      SortType.latestPlayed => (e) => -(HistoryController.inst.topTracksMapListens.value[e]?.lastOrNull ?? 0),
      SortType.firstListen => (e) => HistoryController.inst.topTracksMapListens.value[e]?.firstOrNull ?? DateTime(99999).millisecondsSinceEpoch,
      SortType.titleSort => sortInfoOrFallback((e) => e.sortInfo?.title, TrackSearchFilter.title, (e) => normalize(e.title)),
      SortType.albumSort => sortInfoOrFallback((e) => e.sortInfo?.album, TrackSearchFilter.album, (e) => normalize(e.albumsList.join())),
      SortType.albumArtistSort => sortInfoOrFallback((e) => e.sortInfo?.albumArtist, TrackSearchFilter.albumartist, (e) => normalize(e.albumArtist)),
      SortType.artistSort => sortInfoOrFallback((e) => e.sortInfo?.artist, TrackSearchFilter.artist, (e) => normalize(e.artistsList.join())),
      SortType.composerSort => sortInfoOrFallback((e) => e.sortInfo?.composer, TrackSearchFilter.composer, (e) => normalize(e.composer)),
      SortType.shuffle => _createShuffleComparable(),
      SortType.shuffleDaily => createDailyShuffleComparable<Track>((e) => e.path),
    };
  }

  /// each track keeps the same key for the whole sort, otherwise the comparator is
  /// non-transitive and `List.sort` has no defined behaviour.
  static Comparable Function(Track e) _createShuffleComparable() {
    final random = math.Random();
    final assigned = <Track, double>{};
    return (e) => assigned[e] ??= random.nextDouble();
  }

  static Comparable Function(Track e) _createFavouriteComparable() {
    final favouritesPlaylist = PlaylistController.inst.favouritesPlaylist;
    return (e) => favouritesPlaylist.isSubItemFavourite(e) ? 0 : 1;
  }

  /// same order for the whole day regardless of the list order, since each key depends only on the track and the date.
  static Comparable Function(T e) createDailyShuffleComparable<T>(String Function(T e) keyOf) {
    final now = DateTime.now();
    final daySeed = now.year * 10000 + now.month * 100 + now.day;
    return (e) => _seededTextHash(keyOf(e), daySeed);
  }

  /// FNV-1a followed by murmur3's finalizer, `String.hashCode` isn't guaranteed to be stable across runs.
  static int _seededTextHash(String text, int seed) {
    const mask32 = 0xFFFFFFFF;
    int hash = 0x811c9dc5 ^ seed;
    final length = text.length;
    for (int i = 0; i < length; i++) {
      hash = ((hash ^ text.codeUnitAt(i)) * 0x01000193) & mask32;
    }
    hash ^= hash >> 16;
    hash = (hash * 0x85ebca6b) & mask32;
    hash ^= hash >> 13;
    hash = (hash * 0xc2b2ae35) & mask32;
    hash ^= hash >> 16;
    return hash;
  }

  List<Comparable Function(Track tr)> getMediaTracksSortingComparables(MediaType media) {
    final sorts = settings.mediaItemsTrackSorting.value[media] ?? <SortType>[SortType.title];
    final l = <Comparable Function(Track e)>[];
    for (var e in sorts) {
      final sorter = getTracksSortingComparables(e);
      l.add(sorter);
    }

    // -- auto add .trackNo after .discNo for albums if it was the only one there
    if (media == .album && sorts.length == 1 && sorts[0] == .discNo) {
      final sorter = getTracksSortingComparables(.trackNo);
      l.add(sorter);
    }

    return l;
  }

  String? Function(List<Track> tracks)? getGroupSortExtraTextResolver(GroupSortType sort, {GeneralPlaylist? playlist}) => switch (sort) {
    GroupSortType.album => (tracks) => tracks.originalAlbum,
    GroupSortType.artistsList => (tracks) => tracks.originalArtist,
    GroupSortType.composer => (tracks) => tracks.composer,
    GroupSortType.albumArtist => (tracks) => tracks.albumArtist,
    GroupSortType.label => (tracks) => tracks.firstOrNull?.label,
    GroupSortType.releaseType => (tracks) => tracks.releaseType,
    GroupSortType.bpm => (tracks) => tracks.getAverageBpmFormatted(),
    GroupSortType.genresList => (tracks) => tracks.originalGenre,
    GroupSortType.numberOfTracks => (tracks) => tracks.length.toString(),
    GroupSortType.duration => (tracks) => tracks.totalDurationFormatted,
    GroupSortType.albumsCount => (tracks) => tracks.toUniqueAlbums().length.toString(),
    GroupSortType.year => (tracks) => tracks.yearOldest.yearFormatted,
    GroupSortType.dateAdded => (tracks) => tracks.getDateAddedEffective()?.dateFormatted,
    GroupSortType.dateModified => (tracks) => tracks.getDateModifiedEffective()?.dateFormatted,
    GroupSortType.playCount => (tracks) => tracks.getTotalListenCount().toString(),
    GroupSortType.firstListen => (tracks) => tracks.getFirstListen()?.dateFormattedOriginal ?? '',
    GroupSortType.latestPlayed => (tracks) => tracks.getLatestListen()?.dateFormattedOriginal ?? '',
    GroupSortType.albumSort => (tracks) => tracks.albumSort,
    GroupSortType.albumArtistSort => (tracks) => tracks.albumArtistSort,
    GroupSortType.artistSort => (tracks) => tracks.artistSort,
    GroupSortType.composerSort => (tracks) => tracks.composerSort,

    // -- playlists
    GroupSortType.title => (tracks) => playlist?.name ?? '',
    GroupSortType.creationDate => (tracks) => playlist?.creationDate.dateFormatted ?? '',
    GroupSortType.modifiedDate => (tracks) => playlist?.modifiedDate.dateFormatted ?? '',
    GroupSortType.lastPlayed =>
      (tracks) => playlist == null ? '' : QueueController.latestPlayedForSourceManager.latestPlayedTime(QueueSource.playlist(playlist.name))?.dateFormattedOriginal ?? '',
    // ----
    GroupSortType.shuffle => null,
    GroupSortType.shuffleDaily => null,
    GroupSortType.custom => null,
  };

  String? Function(AlbumIdentifierWrapper album, List<Track> tracks)? getAlbumsExtraTextResolver(GroupSortType sort) {
    if (sort == GroupSortType.lastPlayed) {
      final latestPlayedForSource = QueueController.latestPlayedForSourceManager;
      return (album, tracks) => latestPlayedForSource.latestPlayedTime(QueueSource.album(album, null))?.dateFormattedOriginal;
    }
    return _wrapTracksExtraTextResolver(sort);
  }

  String? Function(String artist, List<Track> tracks)? getArtistsExtraTextResolver(MediaType artistType, GroupSortType sort) {
    if (sort == GroupSortType.lastPlayed) return _createLastPlayedExtraTextResolver(_artistQueueSourceOf(artistType));
    return _wrapTracksExtraTextResolver(sort);
  }

  String? Function(String genre, List<Track> tracks)? getGenresExtraTextResolver(MediaType genreType, GroupSortType sort) {
    if (sort == GroupSortType.lastPlayed) return _createLastPlayedExtraTextResolver(_genreQueueSourceOf(genreType));
    return _wrapTracksExtraTextResolver(sort);
  }

  String? Function(String language, List<Track> tracks)? getLanguagesExtraTextResolver(GroupSortType sort) {
    if (sort == GroupSortType.lastPlayed) return _createLastPlayedExtraTextResolver(QueueSource.language);
    return _wrapTracksExtraTextResolver(sort);
  }

  String? Function(String name, List<Track> tracks)? getMoodsTagsExtraTextResolver(MediaType type, GroupSortType sort) {
    if (sort == GroupSortType.lastPlayed) return _createLastPlayedExtraTextResolver(_moodsTagsQueueSourceOf(type));
    return _wrapTracksExtraTextResolver(sort);
  }

  String? Function(K key, List<Track> tracks)? _wrapTracksExtraTextResolver<K>(GroupSortType sort) {
    final tracksResolver = getGroupSortExtraTextResolver(sort);
    if (tracksResolver == null) return null;
    return (key, tracks) => tracksResolver(tracks);
  }

  static String? Function(String name, List<Track> tracks) _createLastPlayedExtraTextResolver(QueueSource Function(String name) sourceOf) {
    final latestPlayedForSource = QueueController.latestPlayedForSourceManager;
    return (name, tracks) => latestPlayedForSource.latestPlayedTime(sourceOf(name))?.dateFormattedOriginal;
  }

  String? Function(LocalPlaylist playlist)? getGroupSortExtraTextResolverPlaylist(GroupSortType sort) => switch (sort) {
    GroupSortType.album => (p) => p.tracks.firstOrNull?.track.originalAlbum,
    GroupSortType.artistsList => (p) => p.tracks.firstOrNull?.track.originalArtist,
    GroupSortType.composer => (p) => p.tracks.firstOrNull?.track.composer,
    GroupSortType.albumArtist => (p) => p.tracks.firstOrNull?.track.albumArtist,
    GroupSortType.label => (p) => p.tracks.firstOrNull?.track.label,
    GroupSortType.releaseType => (p) => p.tracks.firstOrNull?.track.releaseType,
    GroupSortType.bpm => (p) => p.tracks.getAverageBpmFormatted(),
    GroupSortType.genresList => (p) => p.tracks.firstOrNull?.track.originalGenre,
    GroupSortType.numberOfTracks => (p) => p.tracks.length.toString(),
    GroupSortType.duration => (p) => p.tracks.totalDurationFormatted,
    GroupSortType.albumsCount => (p) => p.tracks.toTracks().toUniqueAlbums().length.toString(),
    GroupSortType.year => (p) => p.tracks.firstOrNull?.track.year.yearFormatted,
    GroupSortType.dateAdded => (p) => p.tracks.getDateAddedEffective()?.dateFormatted,
    GroupSortType.dateModified => (p) => p.tracks.getDateModifiedEffective()?.dateFormatted,
    GroupSortType.playCount => (p) => p.tracks.getTotalListenCount().toString(),
    GroupSortType.firstListen => (p) => p.tracks.getFirstListen()?.dateFormattedOriginal,
    GroupSortType.latestPlayed => (p) => p.tracks.getLatestListen()?.dateFormattedOriginal,

    // -- playlists
    GroupSortType.title => (playlist) => playlist.name,
    GroupSortType.creationDate => (playlist) => playlist.creationDate.dateFormatted,
    GroupSortType.modifiedDate => (playlist) => playlist.modifiedDate.dateFormatted,
    GroupSortType.lastPlayed => (playlist) => QueueController.latestPlayedForSourceManager.latestPlayedTime(QueueSource.playlist(playlist.name))?.dateFormattedOriginal,
    // ----
    GroupSortType.albumSort => null,
    GroupSortType.albumArtistSort => null,
    GroupSortType.artistSort => null,
    GroupSortType.composerSort => null,
    GroupSortType.shuffle => null,
    GroupSortType.shuffleDaily => null,
    GroupSortType.custom => null,
  };

  String? Function(Track tr)? getTracksSortLabelResolver(SortType sort) {
    late final sortKey = getTracksSortingComparables(sort);
    late final topTracksMapListens = HistoryController.inst.topTracksMapListens.value;
    return switch (sort) {
      SortType.title ||
      SortType.album ||
      SortType.albumArtist ||
      SortType.artistsList ||
      SortType.genresList ||
      SortType.composer ||
      SortType.filename ||
      SortType.titleSort ||
      SortType.albumSort ||
      SortType.albumArtistSort ||
      SortType.artistSort ||
      SortType.composerSort => _createSortKeyLabelResolver(sortKey),
      SortType.year => (tr) => tr.year.yearFormatted,
      SortType.dateAdded => (tr) => tr.dateAdded.dateFormatted,
      SortType.dateModified => (tr) => tr.dateModified.dateFormatted,
      SortType.bitrate => (tr) => '${tr.bitrate} kb/s',
      SortType.trackNo => (tr) => tr.trackNo.toString(),
      SortType.discNo => (tr) => tr.discNo.toString(),
      SortType.path => (tr) => tr.folderName,
      SortType.duration => (tr) => tr.durationMS.milliSecondsLabel,
      SortType.sampleRate => (tr) => '${tr.sampleRate}Hz',
      SortType.bitDepth => (tr) => '${tr.bits} bit',
      SortType.bpm => (tr) => '${tr.bpm ?? 0} BPM',
      SortType.size => (tr) => tr.size.fileSizeFormatted,
      SortType.rating => (tr) => '${tr.effectiveRating}%',
      SortType.mostPlayed => (tr) => topTracksMapListens[tr]?.length.formatDecimal() ?? '0',
      SortType.latestPlayed => (tr) => topTracksMapListens[tr]?.lastOrNull?.dateFormatted,
      SortType.firstListen => (tr) => topTracksMapListens[tr]?.firstOrNull?.dateFormatted,
      SortType.favourite || SortType.shuffle || SortType.shuffleDaily => null,
    };
  }

  String? Function(AlbumIdentifierWrapper album)? getAlbumsSortLabelResolver() {
    final sort = settings.albumSorts.value.first;
    return _buildGroupSortLabelResolver(
      sort,
      sortKey: _getMediaSortingComparable(sort, overrideKey: GroupSortType.album, filter: TrackSearchFilter.album),
      extraTextOf: getAlbumsExtraTextResolver(sort),
      tracksOf: (album) => album.getAlbumTracks(),
      nameOf: (album) => album.displayAlbumName,
    );
  }

  String? Function(String artist)? getArtistsSortLabelResolver(MediaType artistType) {
    final sort = settings.artistSorts.value.first;
    return _buildGroupSortLabelResolver(
      sort,
      sortKey: _getArtistsSortingComparable(artistType, sort),
      extraTextOf: getArtistsExtraTextResolver(artistType, sort),
      tracksOf: (artist) => artist.getArtistTracksFor(artistType),
      nameOf: (artist) => artist,
    );
  }

  String? Function(String genre)? getGenresSortLabelResolver(MediaType genreType) {
    final sort = settings.genreSorts.value.first;
    return _buildGroupSortLabelResolver(
      sort,
      sortKey: _getGenresSortingComparable(genreType, sort),
      extraTextOf: getGenresExtraTextResolver(genreType, sort),
      tracksOf: (genre) => genre.getGenresTracksFor(genreType),
      nameOf: (genre) => genre,
    );
  }

  String? Function(String language)? getLanguagesSortLabelResolver() {
    final sort = settings.languageSorts.value.first;
    return _buildGroupSortLabelResolver(
      sort,
      sortKey: _getLanguagesSortingComparable(sort),
      extraTextOf: getLanguagesExtraTextResolver(sort),
      tracksOf: (language) => language.getLanguagesTracks(),
      nameOf: (language) => language,
    );
  }

  String? Function(String playlistName)? getPlaylistsSortLabelResolver() {
    final sort = settings.playlistSorts.value.first;
    if (sort == GroupSortType.title) {
      final normalize = sortKeyNormalizer;
      return (playlistName) {
        final translatedName = playlistName.translatePlaylistName();
        final sortKey = normalize(translatedName);
        return _sortKeyToSectionLabel(sortKey);
      };
    }
    final extraTextResolver = getGroupSortExtraTextResolverPlaylist(sort);
    if (extraTextResolver == null) return null;
    final playlists = playlistsMap.value;
    return (playlistName) {
      final playlist = playlists[playlistName];
      if (playlist == null) return null;
      return extraTextResolver(playlist);
    };
  }

  static String? Function(K key)? _buildGroupSortLabelResolver<K>(
    GroupSortType sort, {
    required Comparable Function(MapEntry<String, List<Track>>)? sortKey,
    required String? Function(K key, List<Track> tracks)? extraTextOf,
    required List<Track> Function(K key) tracksOf,
    required String Function(K key) nameOf,
  }) {
    if (sortKey != null && _isGroupSortTextual(sort)) {
      final labelOf = _createSortKeyLabelResolver(sortKey);
      return (key) {
        final tracks = tracksOf(key);
        final name = nameOf(key);
        return labelOf(MapEntry(name, tracks));
      };
    }
    if (extraTextOf == null) return null;
    return (key) {
      final tracks = tracksOf(key);
      return extraTextOf(key, tracks);
    };
  }

  static bool _isGroupSortTextual(GroupSortType sort) => switch (sort) {
    GroupSortType.title ||
    GroupSortType.album ||
    GroupSortType.albumArtist ||
    GroupSortType.artistsList ||
    GroupSortType.genresList ||
    GroupSortType.composer ||
    GroupSortType.label ||
    GroupSortType.releaseType ||
    GroupSortType.albumSort ||
    GroupSortType.albumArtistSort ||
    GroupSortType.artistSort ||
    GroupSortType.composerSort => true,
    GroupSortType.year ||
    GroupSortType.dateAdded ||
    GroupSortType.dateModified ||
    GroupSortType.bpm ||
    GroupSortType.duration ||
    GroupSortType.numberOfTracks ||
    GroupSortType.playCount ||
    GroupSortType.latestPlayed ||
    GroupSortType.lastPlayed ||
    GroupSortType.firstListen ||
    GroupSortType.albumsCount ||
    GroupSortType.creationDate ||
    GroupSortType.modifiedDate ||
    GroupSortType.shuffle ||
    GroupSortType.shuffleDaily ||
    GroupSortType.custom => false,
  };

  static String? Function(T item) _createSortKeyLabelResolver<T>(Comparable Function(T item) sortKey) {
    return (item) {
      final key = sortKey(item);
      return _sortKeyToSectionLabel(key);
    };
  }

  static const _kOtherSectionLabel = '#';
  static const _kAsciiEnd = 0x80;
  static const _kLowerA = 0x61;
  static const _kLowerZ = 0x7A;
  static const _kLowerCaseBit = 0x20;

  static String? _sortKeyToSectionLabel(Comparable key) {
    if (key is! String) return null;
    if (key.isEmpty) return _kOtherSectionLabel;
    final firstCodeUnit = key.codeUnitAt(0);
    if (firstCodeUnit < _kAsciiEnd) {
      final lowerCodeUnit = firstCodeUnit | _kLowerCaseBit;
      final isLetter = lowerCodeUnit >= _kLowerA && lowerCodeUnit <= _kLowerZ;
      if (!isLetter) return _kOtherSectionLabel;
      final upperCodeUnit = lowerCodeUnit - _kLowerCaseBit;
      return String.fromCharCode(upperCodeUnit);
    }
    final firstRune = key.runes.first;
    final firstCharacter = String.fromCharCode(firstRune);
    return firstCharacter.toUpperCase();
  }

  bool? _preparedResources;
  Future<void> prepareResources() async {
    if (_preparedResources == true) return;
    _preparedResources = true;
    final enabledSearchesList = settings.activeSearchMediaTypes;
    final enabledSearches = <MediaType, bool>{};
    for (var f in enabledSearchesList.value) {
      enabledSearches[f] = true;
    }

    _preparingResources = true;
    _refreshRunningSearchesCount();

    Future prepareOrDispose(MediaType type, Future<SendPortWithCachedMessage?> Function() prepareFn) {
      if (enabledSearches[type] ?? false) {
        return prepareFn();
      } else {
        return closePorts(type);
      }
    }

    try {
      await Future.wait(MediaType.values.map((e) => prepareOrDispose(e, mediaTypeToPrepareFn(e))));
    } finally {
      _preparingResources = false;
      _refreshRunningSearchesCount();
    }
  }

  Future<void> disposeResources() async {
    _preparedResources = false;
    _preparingResources = false;
    _runningTempSearches.clear();
    _refreshRunningSearchesCount();
    await super.disposeAll().ignoreError();
  }

  @override
  Future<SendPortWithCachedMessage?> Function() mediaTypeToPrepareFn(MediaType type) {
    return switch (type) {
      MediaType.artist ||
      MediaType.albumArtist ||
      MediaType.composer ||
      MediaType.genre ||
      MediaType.style ||
      MediaType.language ||
      MediaType.folder ||
      MediaType.folderMusic ||
      MediaType.folderVideo ||
      MediaType.mood ||
      MediaType.tag => () => _prepareMediaPorts(type),
      MediaType.rating => () => Future.value(null),
      MediaType.track => _prepareTracksPorts,
      MediaType.album => _prepareAlbumsPorts,
      MediaType.playlist => _preparePlaylistPorts,
    };
  }

  Future<SendPortWithCachedMessage?> _prepareTracksPorts() async {
    return await super.preparePorts(
      type: MediaType.track,
      onResult: (result) {
        final r = result as (List<Track>, List<Track>, bool, String, bool?);
        final isTemp = r.$3;
        final fetchedQuery = r.$4;
        if (isTemp) {
          _onTempSearchEnded(MediaType.track, fetchedQuery);
          if (fetchedQuery == lastSearchText) {
            final relevant = r.$1;
            final lessRelevant = r.$2;
            if (settings.tracksSearchShowLessRelevant.value) relevant.addAll(lessRelevant);
            trackSearchTemp.value = relevant;
            trackSearchTempLessRelevant.value = lessRelevant;
            sortTracksSearch();
          }
        } else {
          final tab = _activeTracksTab;
          if (fetchedQuery == tab.textSearchController?.text && r.$5 == tab.isVideoFilter) {
            trackSearchList.value = r.$1;
            _trackSearchListTab = tab;
          }
        }
      },
      isolateFunction: (itemsSendPort) async {
        await HistoryController.inst.waitForHistoryAndMostPlayedLoad;
        final topTracksMapListens = HistoryController.inst.topTracksMapListens.value;
        final params = generateTrackSearchIsolateParams(itemsSendPort, topTracksMapListens);
        await Isolate.spawn(searchTracksIsolate, params);
      },
    );
  }

  TracksSearchParams generateTrackSearchIsolateParams(SendPort sendPort, ListensSortedMap<Track> topTracksMapListens) {
    final tracks = _tracksInfoList.value.map((e) => e.toTrackExt());
    return TracksSearchWrapper.generateParams(sendPort, tracks, topTracksMapListens);
  }

  Future<SendPortWithCachedMessage?> _preparePlaylistPorts() async {
    return await super.preparePorts(
      type: MediaType.playlist,
      onResult: (result) {
        final r = result as (List<String>, bool, String);
        final isTemp = r.$2;
        final fetchedQuery = r.$3;
        if (isTemp) {
          _onTempSearchEnded(MediaType.playlist, fetchedQuery);
          if (fetchedQuery == lastSearchText) playlistSearchTemp.value = r.$1;
        } else {
          if (fetchedQuery == LibraryTab.playlists.textSearchController?.text) _setPlaylistSearchList(r.$1);
        }
      },
      isolateFunction: (itemsSendPort) async {
        await HistoryController.inst.waitForHistoryAndMostPlayedLoad;
        final playlists = playlistsMap.value.values.toFixedList();
        final playlistsTracks = playlists.map((e) => e.tracks).toFixedList();
        final weights = _keysSearchWeightsOf(playlistsTracks);
        final params = (
          playlists: playlists.map((e) => e.toJson((item) => item.toJson(), PlaylistController.inst.sortToJson)).toFixedList(),
          translations: (
            autoGenerated: lang.autoGenerated,
            favourites: lang.favourites,
            history: lang.history,
            mostPlayed: lang.mostPlayed,
          ),
          filters: settings.playlistSearchFilter.value,
          weights: weights,
          cleanup: _shouldCleanup,
          sendPort: itemsSendPort,
        );

        await Isolate.spawn(_searchPlaylistsIsolate, params);
      },
    );
  }

  Future<SendPortWithCachedMessage?> _prepareAlbumsPorts() async {
    return await super.preparePorts(
      type: MediaType.album,
      onResult: (result) {
        final r = result as (List<AlbumIdentifierWrapper>, bool, String);
        final isTemp = r.$2;
        final fetchedQuery = r.$3;
        final keysResult = _modifyAlbumKeys(r.$1);
        if (isTemp) {
          _onTempSearchEnded(MediaType.album, fetchedQuery);
          if (fetchedQuery == lastSearchText) albumSearchTemp.value = keysResult;
        } else {
          if (fetchedQuery == LibraryTab.albums.textSearchController?.text) albumSearchList.value = keysResult;
        }
      },
      isolateFunction: (itemsSendPort) async {
        await HistoryController.inst.waitForHistoryAndMostPlayedLoad;
        final albumsMap = Indexer.inst.mainMapAlbums.value;
        final albumsTracks = albumsMap.values.toFixedList();
        final weights = _keysSearchWeightsOf(albumsTracks);
        final params = (
          keys: albumsMap.keys.toFixedList(),
          weights: weights,
          cleanup: _shouldCleanup,
          sendPort: itemsSendPort,
        );
        await Isolate.spawn(_searchAlbumsIsolate, params);
      },
    );
  }

  Future<SendPortWithCachedMessage?> _prepareMediaPorts(MediaType type) async {
    return await super.preparePorts(
      type: type,
      onResult: (result) {
        final r = result as (List<String>, bool, String);
        final isTemp = r.$2;
        final fetchedQuery = r.$3;

        if (isTemp) {
          _onTempSearchEnded(type, fetchedQuery);
          if (fetchedQuery == lastSearchText) {
            _searchMapTemp[type]?.value = _filterNonEmptyFolders(type, r.$1);
            // sortMedia(type);
          }
        } else {
          final typeNomalize = type == MediaType.albumArtist || type == MediaType.composer
              ? MediaType.artist
              : type == MediaType.style
              ? MediaType.genre
              : type;
          if (fetchedQuery == typeNomalize.toLibraryTab().textSearchController?.text) _searchMap[typeNomalize]?.value = r.$1;
        }
      },
      isolateFunction: (itemsSendPort) async {
        await HistoryController.inst.waitForHistoryAndMostPlayedLoad;
        final entries = _getMediaEntries(type).toFixedList();
        final entriesTracks = entries.map((e) => e.value).toFixedList();
        final weights = _keysSearchWeightsOf(entriesTracks);
        final params = (
          keys: entries.map((e) => e.key).toFixedList(),
          weights: weights,
          cleanup: _shouldCleanup,
          keyIsPath: type == MediaType.folderMusic || type == MediaType.folderVideo || type == MediaType.folder,
          sendPort: itemsSendPort,
        );

        await Isolate.spawn(_generalSearchIsolate, params);
      },
    );
  }

  Iterable<MapEntry<String, List<Track>>> _getMediaEntries(MediaType type) {
    return switch (type) {
      MediaType.artist => Indexer.inst.mainMapArtists.value.entries,
      MediaType.albumArtist => Indexer.inst.mainMapAlbumArtists.value.entries,
      MediaType.composer => Indexer.inst.mainMapComposer.value.entries,
      MediaType.genre => Indexer.inst.mainMapGenres.value.entries,
      MediaType.style => Indexer.inst.mainMapStyles.value.entries,
      MediaType.language => Indexer.inst.mainMapLanguages.value.entries,
      MediaType.folder => Indexer.inst.mainMapFoldersTracksAndVideos.toPathsEntries(),
      MediaType.folderMusic => Indexer.inst.mainMapFoldersTracks.toPathsEntries(),
      MediaType.folderVideo => Indexer.inst.mainMapFoldersVideos.toPathsEntries(),
      MediaType.mood => Indexer.inst.getTracksGroupedByMoods(sort: false).entries,
      MediaType.tag => Indexer.inst.getTracksGroupedByTags(sort: false).entries,
      MediaType.rating || MediaType.track || MediaType.album || MediaType.playlist => const [],
    };
  }

  static KeysSearchWeights _keysSearchWeightsOf(List<List<Selectable>> groups) {
    return KeysSearchWrapper.createWeights(groups, listensCount: (tracks) => tracks.getTotalListenCount(), tracksCount: (tracks) => tracks.length);
  }

  void searchTracks(String text, {bool temp = false}) async {
    if (text == '') {
      if (temp) {
        trackSearchTemp.clear();
        trackSearchTempLessRelevant.clear();
        _onTempSearchEnded(MediaType.track, null);
      } else {
        final tab = _activeTracksTab;
        tab.textSearchController?.clear();
        final isVideo = tab.isVideoFilter;
        if (isVideo == null) {
          trackSearchList.assignAll(_tracksInfoList.value);
        } else {
          trackSearchList.value = _filterTracksKind(_tracksInfoList.value, isVideo);
        }
        _trackSearchListTab = tab;
      }
      return;
    }
    if (temp) _onTempSearchStarted(MediaType.track, text);
    final isVideo = temp ? _activeTrSearchIsVideo : _activeTracksTab.isVideoFilter;
    _sendSearchRequest(MediaType.track, await _prepareTracksPorts(), text, temp, isVideo: isVideo);
  }

  static void searchTracksIsolate(TracksSearchParams params) {
    final sendPort = params.sendPort;

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final searchWrapper = TracksSearchWrapper.init(params);

    StreamSubscription? streamSub;
    streamSub = receivePort.listen((p) {
      if (p == PortsProviderMessages.disposed) {
        receivePort.close();
        streamSub?.cancel();
        return;
      }
      p as SearchRequest;
      final text = p.text;
      final temp = p.temp;
      final isVideo = p.isVideo;

      if (temp) {
        final result = searchWrapper.filterSplitByRelevance(text, isVideo: isVideo);
        sendPort.send((result.relevant, result.lessRelevant, temp, text, isVideo));
      } else {
        final result = searchWrapper.filter(text, isVideo: isVideo);
        sendPort.send((result, const <Track>[], temp, text, isVideo));
      }
    });

    sendPort.send(PortsProviderMessages.prepared);
  }

  List<AlbumIdentifierWrapper> _modifyAlbumKeys(Iterable<AlbumIdentifierWrapper> original) {
    final activeAlbumTypes = settings.activeAlbumTypes.value;
    final hiddenAlbumTypes = AlbumType.values.where((e) => activeAlbumTypes[e] == false).toSet();

    if (hiddenAlbumTypes.isEmpty) return original.toList();
    if (hiddenAlbumTypes.length == AlbumType.values.length) return [];

    return original.where((element) => !hiddenAlbumTypes.contains(element.getAlbumType())).toList();
  }

  void _searchAlbums(String text, {bool temp = false}) async {
    if (text == '') {
      if (temp) {
        albumSearchTemp.clear();
        _onTempSearchEnded(MediaType.album, null);
      } else {
        LibraryTab.albums.textSearchController?.clear();
        albumSearchList.value = _modifyAlbumKeys(Indexer.inst.mainMapAlbums.value.keys);
      }
      return;
    }

    if (temp) _onTempSearchStarted(MediaType.album, text);
    _sendSearchRequest(MediaType.album, await _prepareAlbumsPorts(), text, temp);
  }

  void _searchMediaType({required MediaType type, required String text, bool temp = false}) async {
    if (text == '') {
      if (temp) {
        _searchMapTemp[type]?.clear();
        _onTempSearchEnded(type, null);
      } else {
        final typeNomalize = type == MediaType.albumArtist || type == MediaType.composer
            ? MediaType.artist
            : type == MediaType.style
            ? MediaType.genre
            : type;
        typeNomalize.toLibraryTab().textSearchController?.clear();
        _searchMap[typeNomalize]?.value = _getMediaEntries(type).map((e) => e.key).toList();
      }
      return;
    }

    if (temp) _onTempSearchStarted(type, text);
    _sendSearchRequest(type, await _prepareMediaPorts(type), text, temp);
  }

  void _searchPlaylists(String text, {bool temp = false}) async {
    if (text == '') {
      if (temp) {
        playlistSearchTemp.clear();
        _onTempSearchEnded(MediaType.playlist, null);
      } else {
        LibraryTab.playlists.textSearchController?.clear();
        final allPlaylists = playlistsMap.keys.toList();
        _setPlaylistSearchList(allPlaylists);
      }
      return;
    }

    if (temp) _onTempSearchStarted(MediaType.playlist, text);
    _sendSearchRequest(MediaType.playlist, await _preparePlaylistPorts(), text, temp);
  }

  var _playlistSearchListUnfiltered = <String>[];

  void _setPlaylistSearchList(List<String> playlists) {
    _playlistSearchListUnfiltered = playlists;
    final tagsFilter = PlaylistController.inst.tagsFilter;
    playlistSearchList.value = tagsFilter.apply(playlists);
  }

  void refreshPlaylistsTagsFilter() => _setPlaylistSearchList(_playlistSearchListUnfiltered);

  static void _searchPlaylistsIsolate(_SearchPlaylistsParams params) {
    final playlistsMap = params.playlists;
    final translations = params.translations;
    final psf = params.filters;
    final cleanup = params.cleanup;
    final sendPort = params.sendPort;

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    String translatePlName(String n) {
      return n
          .replaceFirst(k_PLAYLIST_NAME_AUTO_GENERATED, translations.autoGenerated)
          .replaceFirst(k_PLAYLIST_NAME_FAV, translations.favourites)
          .replaceFirst(k_PLAYLIST_NAME_HISTORY, translations.history)
          .replaceFirst(k_PLAYLIST_NAME_MOST_PLAYED, translations.mostPlayed);
    }

    final formatDate = DateFormat('yyyyMMdd');

    final sTitle = psf.contains(PlaylistSearchFilter.name);
    final sCreationDate = psf.contains(PlaylistSearchFilter.creationDate);
    final sModifiedDate = psf.contains(PlaylistSearchFilter.modifiedDate);
    final sComment = psf.contains(PlaylistSearchFilter.comment);
    final sMoods = psf.contains(PlaylistSearchFilter.moods);
    final sTags = psf.contains(PlaylistSearchFilter.tags);

    final playlists = playlistsMap.map((plMap) => LocalPlaylist.fromJson(plMap, TrackWithDate.fromJson, SortType.sortListFromJsonList)).toFixedList();
    final searchWrapper = KeysSearchWrapper.init(
      playlists,
      title: (pl) => sTitle ? translatePlName(pl.name) : null,
      extras: (pl) => [
        if (sCreationDate) formatDate.format(DateTime.fromMillisecondsSinceEpoch(pl.creationDate)),
        if (sModifiedDate) formatDate.format(DateTime.fromMillisecondsSinceEpoch(pl.modifiedDate)),
        if (sComment) pl.comment,
        if (sMoods) ...pl.moods,
        if (sTags) ...pl.tags,
      ],
      weights: params.weights,
      cleanup: cleanup,
    );

    StreamSubscription? streamSub;
    streamSub = receivePort.listen((p) {
      if (p == PortsProviderMessages.disposed) {
        receivePort.close();
        streamSub?.cancel();
        return;
      }
      p as SearchRequest;
      final text = p.text;
      final results = searchWrapper.filter(text).map((pl) => pl.name).toFixedList();
      sendPort.send((results, p.temp, text));
    });

    sendPort.send(PortsProviderMessages.prepared);
  }

  Future<void> sortAll() async {
    await Future.delayed(Duration.zero, _sortTracks);
    await Future.delayed(Duration.zero, _sortAlbums);
    await Future.delayed(Duration.zero, () => _sortArtistsCurrent(artistType: settings.activeArtistType.value));
    await Future.delayed(Duration.zero, () => _sortGenresCurrent(genreType: settings.activeGenreType.value));
    await Future.delayed(Duration.zero, _sortLanguages);
    await Future.delayed(Duration.zero, _sortPlaylists);
  }

  void sortMedia(MediaType media, {SortType? sortBy, List<GroupSortType>? groupSorts, bool? reverse, bool forceSingleSorting = false}) {
    switch (media) {
      case MediaType.track:
        _sortTracks(sortBy: sortBy, reverse: reverse, forceSingleSorting: forceSingleSorting);
        break;
      case MediaType.album:
        _sortAlbums(sorts: groupSorts, reverse: reverse);
        break;
      case MediaType.artist:
      case MediaType.albumArtist:
      case MediaType.composer:
        _sortArtistsCurrent(artistType: settings.activeArtistType.value, sorts: groupSorts, reverse: reverse);
        break;
      case MediaType.genre:
      case MediaType.style:
        _sortGenresCurrent(genreType: settings.activeGenreType.value, sorts: groupSorts, reverse: reverse);
        break;
      case MediaType.language:
        _sortLanguages(sorts: groupSorts, reverse: reverse);
        break;
      case MediaType.playlist:
        _sortPlaylists(sorts: groupSorts, reverse: reverse);
        break;
      case MediaType.mood:
      case MediaType.tag:
        _saveMoodsTagsSorting(media, sorts: groupSorts, reverse: reverse);
        break;

      default:
        null;
    }
    SearchSortController.inst.refreshPortsIfNecessary();
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
          refreshTrackSearchList();
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

  void sortTracksSearch({SortType? sortBy, bool? reverse}) {
    final isAuto = settings.tracksSortSearchIsAuto.value;
    if (isAuto) {
      // -- already sorted by most relevant
      return;
    }

    sortBy ??= settings.tracksSortSearch.value;
    reverse ??= settings.tracksSortSearchReversed.value;

    _sortTracksRaw(
      sortBy: sortBy,
      reverse: reverse,
      list: trackSearchTemp.value,
      onDone: (sortType, isReverse) {
        if (!isAuto) {
          if (sortBy != settings.tracksSortSearch.value || reverse != settings.tracksSortSearchReversed.value) {
            settings.transaction(() {
              settings.tracksSortSearch.save(sortType);
              settings.tracksSortSearchReversed.save(isReverse);
            });
          }
        }
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
    if (sortBy == SortType.shuffle) {
      list.shuffle();
    } else if (sortBy != null) {
      final comparable = getTracksSortingComparables(sortBy);
      final sameMediaSorters = _getSameMediaTracksSortingComparables(sortBy);
      if (sameMediaSorters == null) {
        list.sortByPrecomputed(comparable, reverse: reverse);
      } else {
        list.sortByAltsPrecomputed([comparable, ...sameMediaSorters], reverse: reverse);
      }
    }
    onDone(sortBy, reverse);
  }

  List<Comparable Function(Track tr)>? _getSameMediaTracksSortingComparables(SortType sort) {
    final media = switch (sort) {
      SortType.album => MediaType.album,
      SortType.albumArtist => MediaType.albumArtist,
      SortType.artistsList => MediaType.artist,
      SortType.genresList => MediaType.genre,
      SortType.title ||
      SortType.year ||
      SortType.dateAdded ||
      SortType.dateModified ||
      SortType.bitrate ||
      SortType.composer ||
      SortType.trackNo ||
      SortType.discNo ||
      SortType.filename ||
      SortType.path ||
      SortType.duration ||
      SortType.sampleRate ||
      SortType.bitDepth ||
      SortType.bpm ||
      SortType.size ||
      SortType.rating ||
      SortType.favourite ||
      SortType.shuffle ||
      SortType.shuffleDaily ||
      SortType.mostPlayed ||
      SortType.latestPlayed ||
      SortType.firstListen ||
      SortType.titleSort ||
      SortType.albumSort ||
      SortType.albumArtistSort ||
      SortType.artistSort ||
      SortType.composerSort => null,
    };
    return media == null ? null : getMediaTracksSortingComparables(media);
  }

  /// Sorts Albums and Saves automatically to settings
  void _sortAlbums({List<GroupSortType>? sorts, bool? reverse}) {
    sorts ??= settings.albumSorts.value;
    reverse ??= settings.albumSortReversed.value;

    final finalMap = Indexer.inst.mainMapAlbums;
    final albumsList = finalMap.value.entries.toFixedList();

    sortAlbumsListRaw(albumsList, sorts, reverse);

    finalMap.value.assignAllEntries(albumsList);
    finalMap.refresh();

    settings.updateGroupSortingAll(MediaType.album, sorts, reverse);

    _searchAlbums(LibraryTab.albums.textSearchController?.text ?? '');
  }

  void sortAlbumsListRaw(List<MapEntry<AlbumIdentifierWrapper, List<Track>>> albumsList, List<GroupSortType> sorts, bool reverse) {
    if (sorts.first == GroupSortType.shuffle) {
      albumsList.shuffle();
    } else {
      String Function(MapEntry<AlbumIdentifierWrapper, List<Track>> e) encapsulateSortCanIgnorePrefix(
        TrackSearchFilter filter,
        String Function(MapEntry<AlbumIdentifierWrapper, List<Track>> e) comparable,
      ) {
        final ignoreCommonPrefix = settings.ignoreCommonPrefixForTypes.value;
        if (ignoreCommonPrefix.contains(filter)) {
          return (e) => comparable(e).ignoreCommonPrefixes();
        } else {
          return comparable;
        }
      }

      final initialSortTypes = {
        ...sorts,
        GroupSortType.album,
        GroupSortType.year,
        GroupSortType.dateModified,
      };

      final allComparables = <Comparable<dynamic> Function(MapEntry<AlbumIdentifierWrapper, List<Track>>)>[];

      for (final s in initialSortTypes) {
        if (s == GroupSortType.album) {
          final normalize = sortKeyNormalizer;
          final mainFn = encapsulateSortCanIgnorePrefix(TrackSearchFilter.album, (e) => normalize(e.key.displayAlbumName));
          allComparables.add((e) => mainFn(e));
        } else if (s == GroupSortType.lastPlayed) {
          final latestPlayedForSource = QueueController.latestPlayedForSourceManager;
          allComparables.add((e) => -(latestPlayedForSource.latestPlayedTime(QueueSource.album(e.key, null)) ?? 0));
        } else {
          final fn = _getMediaSortingComparable(s);
          if (fn != null) {
            allComparables.add((e) => fn(MapEntry(e.key.displayAlbumName, e.value)));
          }
        }
      }
      albumsList.sortByAltsPrecomputed(allComparables, reverse: reverse);
    }
  }

  /// Sorts Artists and Saves automatically to settings
  void _sortArtistsCurrent({required MediaType artistType, List<GroupSortType>? sorts, bool? reverse}) {
    sorts ??= settings.artistSorts.value;
    reverse ??= settings.artistSortReversed.value;

    final finalMap = switch (artistType) {
      MediaType.artist => Indexer.inst.mainMapArtists,
      MediaType.albumArtist => Indexer.inst.mainMapAlbumArtists,
      MediaType.composer => Indexer.inst.mainMapComposer,
      _ => Indexer.inst.mainMapArtists,
    };
    final artistsList = finalMap.value.entries.toFixedList();

    if (sorts.first == GroupSortType.shuffle) {
      artistsList.shuffle();
    } else {
      final fallbackGroupSortTitle = switch (artistType) {
        MediaType.artist => GroupSortType.artistsList,
        MediaType.albumArtist => GroupSortType.albumArtist,
        MediaType.composer => GroupSortType.composer,
        _ => null,
      };
      final allSorts = {
        ...sorts,
        ?fallbackGroupSortTitle,
        GroupSortType.year,
        GroupSortType.dateModified,
      };
      final allComparables = <Comparable Function(MapEntry<String, List<Track>>)>[];
      for (final sort in allSorts) {
        final comparable = sort == GroupSortType.albumsCount ? _getArtistsAlbumsCountComparable(artistType) : _getArtistsSortingComparable(artistType, sort);
        if (comparable != null) allComparables.add(comparable);
      }

      artistsList.sortByAltsPrecomputed(allComparables, reverse: reverse);
    }

    finalMap.value.assignAllEntries(artistsList);
    finalMap.refresh();

    settings.updateGroupSortingAll(artistType, sorts, reverse);

    _searchMediaType(type: artistType, text: LibraryTab.artists.textSearchController?.text ?? '');
  }

  /// Sorts Genres and Saves automatically to settings
  void _sortGenresCurrent({required MediaType genreType, List<GroupSortType>? sorts, bool? reverse}) {
    sorts ??= settings.genreSorts.value;
    reverse ??= settings.genreSortReversed.value;

    final finalMap = Indexer.inst.getGenreMapFor(genreType);
    final genresList = finalMap.value.entries.toFixedList();

    if (sorts.first == GroupSortType.shuffle) {
      genresList.shuffle();
    } else {
      final allSorts = {
        ...sorts,
        GroupSortType.genresList,
        GroupSortType.year,
        GroupSortType.dateModified,
      };
      final allComparables = <Comparable Function(MapEntry<String, List<Track>>)>[];
      for (final sort in allSorts) {
        final comparable = _getGenresSortingComparable(genreType, sort);
        if (comparable != null) allComparables.add(comparable);
      }
      genresList.sortByAltsPrecomputed(allComparables, reverse: reverse);
    }

    finalMap.value.assignAllEntries(genresList);
    finalMap.refresh();

    settings.updateGroupSortingAll(genreType, sorts, reverse);
    _searchMediaType(type: genreType, text: LibraryTab.genres.textSearchController?.text ?? '');
  }

  /// Sorts Languages and Saves automatically to settings
  void _sortLanguages({List<GroupSortType>? sorts, bool? reverse}) {
    sorts ??= settings.languageSorts.value;
    reverse ??= settings.languageSortReversed.value;

    final finalMap = Indexer.inst.mainMapLanguages;
    final languagesList = finalMap.value.entries.toFixedList();

    if (sorts.first == GroupSortType.shuffle) {
      languagesList.shuffle();
    } else {
      final allSorts = {
        ...sorts,
        GroupSortType.title,
        GroupSortType.year,
        GroupSortType.dateModified,
      };
      final allComparables = <Comparable Function(MapEntry<String, List<Track>>)>[];
      for (final sort in allSorts) {
        final comparable = _getLanguagesSortingComparable(sort);
        if (comparable != null) allComparables.add(comparable);
      }
      languagesList.sortByAltsPrecomputed(allComparables, reverse: reverse);
    }

    finalMap.value.assignAllEntries(languagesList);
    finalMap.refresh();

    settings.updateGroupSortingAll(MediaType.language, sorts, reverse);
    _searchMediaType(type: MediaType.language, text: LibraryTab.languages.textSearchController?.text ?? '');
  }

  void _saveMoodsTagsSorting(MediaType type, {List<GroupSortType>? sorts, bool? reverse}) {
    final current = settings.groupSortingOf(type);
    if (current == null) return;
    settings.updateGroupSortingAll(type, sorts ?? current.sorts, reverse ?? current.isReverse);
  }

  void sortMoodsTagsEntries(MediaType type, List<MapEntry<String, List<Track>>> entries) {
    final sorting = settings.groupSortingOf(type);
    if (sorting == null) return;
    final sorts = sorting.sorts;
    if (sorts.first == GroupSortType.shuffle) return entries.shuffle();

    final allSorts = {...sorts, GroupSortType.title};
    final allComparables = <Comparable Function(MapEntry<String, List<Track>>)>[];
    for (final sort in allSorts) {
      final comparable = _getMoodsTagsSortingComparable(type, sort);
      if (comparable != null) allComparables.add(comparable);
    }
    entries.sortByAltsPrecomputed(allComparables, reverse: sorting.isReverse);
  }

  /// Sorts Playlists and Saves automatically to settings
  void _sortPlaylists({List<GroupSortType>? sorts, bool? reverse}) async {
    // -- mainly to avoid resetting custom sort since it wouldn't be loaded yet
    await PlaylistController.inst.waitForPlaylistsLoad;

    sorts ??= settings.playlistSorts.value;
    reverse ??= settings.playlistSortReversed.value;

    final customIndicesOrder = PlaylistController.inst.customIndicesOrderRx.value;
    if (sorts.first == GroupSortType.custom && customIndicesOrder == null) {
      sorts = const [GroupSortType.title];
    }

    final playlistList = playlistsMap.entries.toFixedList();

    switch (sorts.first) {
      case GroupSortType.shuffle:
        playlistList.shuffle();
      case GroupSortType.custom:
        final indices = <String, int>{};
        int index = 0;
        for (final item in customIndicesOrder!) {
          indices[item] = index;
          index++;
        }
        final fallbackIndex = playlistList.length - 1;
        playlistList.sortByPrecomputed((p) => indices[p.key] ?? fallbackIndex, reverse: reverse);
      default:
        final allComparables = <Comparable Function(MapEntry<String, LocalPlaylist> p)>[];
        for (final sort in sorts) {
          final comparable = _getPlaylistSortingComparable(sort);
          if (comparable != null) allComparables.add(comparable);
        }
        playlistList.sortByAltsPrecomputed(allComparables, reverse: reverse);
    }

    playlistList.movePinnedFirst();

    playlistsMap.value.assignAllEntries(playlistList);
    playlistsMap.refresh();

    settings.updateGroupSortingAll(MediaType.playlist, sorts, reverse);

    _searchPlaylists(LibraryTab.playlists.textSearchController?.text ?? '');
  }

  Comparable Function(MapEntry<String, LocalPlaylist> p)? _getPlaylistSortingComparable(GroupSortType sort) {
    switch (sort) {
      case GroupSortType.title:
        final normalize = sortKeyNormalizer;
        return (p) => normalize(p.key.translatePlaylistName());
      case GroupSortType.creationDate:
        return (p) => p.value.creationDate;
      case GroupSortType.modifiedDate:
        return (p) => p.value.modifiedDate;
      case GroupSortType.duration:
        return (p) => p.value.tracks.totalDurationInMS;
      case GroupSortType.numberOfTracks:
        return (p) => -p.value.tracks.length;
      case GroupSortType.playCount:
        return (p) => -p.value.tracks.getTotalListenCount();
      case GroupSortType.firstListen:
        return (p) => p.value.tracks.getFirstListen() ?? DateTime(99999).millisecondsSinceEpoch;
      case GroupSortType.latestPlayed:
        return (p) => -(p.value.tracks.getLatestListen() ?? 0);
      case GroupSortType.lastPlayed:
        return (p) => -(QueueController.latestPlayedForSourceManager.latestPlayedTime(QueueSource.playlist(p.key)) ?? 0);
      case GroupSortType.bpm:
        return (p) => p.value.tracks.getAverageBpm();
      case GroupSortType.shuffleDaily:
        return createDailyShuffleComparable<MapEntry<String, LocalPlaylist>>((p) => p.key);
      case GroupSortType.album ||
          GroupSortType.albumArtist ||
          GroupSortType.year ||
          GroupSortType.artistsList ||
          GroupSortType.genresList ||
          GroupSortType.dateAdded ||
          GroupSortType.dateModified ||
          GroupSortType.composer ||
          GroupSortType.label ||
          GroupSortType.releaseType ||
          GroupSortType.albumsCount ||
          GroupSortType.albumSort ||
          GroupSortType.albumArtistSort ||
          GroupSortType.artistSort ||
          GroupSortType.composerSort ||
          GroupSortType.shuffle ||
          GroupSortType.custom:
        return null;
    }
  }

  static void _searchAlbumsIsolate(({List<AlbumIdentifierWrapper> keys, KeysSearchWeights weights, bool cleanup, SendPort sendPort}) parameters) {
    final sendPort = parameters.sendPort;

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final searchWrapper = KeysSearchWrapper.init(
      parameters.keys,
      title: (key) => key.displayAlbumName,
      subtitle: (key) => key.albumArtist,
      weights: parameters.weights,
      cleanup: parameters.cleanup,
    );

    StreamSubscription? streamSub;
    streamSub = receivePort.listen((p) {
      if (p == PortsProviderMessages.disposed) {
        receivePort.close();
        streamSub?.cancel();
        return;
      }
      p as SearchRequest;
      final text = p.text;
      final results = searchWrapper.filter(text);
      sendPort.send((results, p.temp, text));
    });

    sendPort.send(PortsProviderMessages.prepared);
  }

  static void _generalSearchIsolate(({List<String> keys, KeysSearchWeights weights, bool cleanup, bool keyIsPath, SendPort sendPort}) parameters) {
    final keyIsPath = parameters.keyIsPath;
    final sendPort = parameters.sendPort;

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final searchWrapper = KeysSearchWrapper.init(
      parameters.keys,
      title: (key) => keyIsPath ? Folder.explicit(key).folderNameRaw : key,
      weights: parameters.weights,
      cleanup: parameters.cleanup,
    );

    StreamSubscription? streamSub;
    streamSub = receivePort.listen((p) {
      if (p == PortsProviderMessages.disposed) {
        receivePort.close();
        streamSub?.cancel();
        return;
      }
      p as SearchRequest;
      final text = p.text;
      final results = searchWrapper.filter(text);
      sendPort.send((results, p.temp, text));
    });

    sendPort.send(PortsProviderMessages.prepared);
  }

  KeysSearchWrapper<MapEntry<String, List<Track>>> createMoodsTagsSearchWrapper(List<MapEntry<String, List<Track>>> entries) {
    final entriesTracks = entries.map((e) => e.value).toFixedList();
    final weights = _keysSearchWeightsOf(entriesTracks);
    return KeysSearchWrapper.init(entries, title: (e) => e.key, weights: weights, cleanup: _shouldCleanup);
  }

  bool get _shouldCleanup => settings.enableSearchCleanup.value;
}

extension _FolderMapExt<T extends Track> on RxMap<Folder, List<T>> {
  Iterable<MapEntry<String, List<Track>>> toPathsEntries() {
    return value.entries.map((e) => MapEntry(e.key.path, e.value));
  }
}

typedef _SearchPlaylistsParams = ({
  List<Map<String, dynamic>> playlists,
  ({String autoGenerated, String favourites, String history, String mostPlayed}) translations,
  List<PlaylistSearchFilter> filters,
  KeysSearchWeights weights,
  bool cleanup,
  SendPort sendPort,
});
