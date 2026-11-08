// logic rewritten by claude, new one finds every cached file of tracks and youtube videos in one isolate pass, temp files in a later one, and cleans the cache maps on delete
import 'dart:io';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/subtitle_track.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/audio_cache_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_selectable.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_youtubeid.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/spectrum_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/waveform_extractor.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class ItemsCache {
  final bool _isSingle;
  final Set<String> _videoIds;
  final _ItemsCacheRefs _refs;

  ItemsCache._(this._isSingle, this._videoIds, this._refs);

  final _entries = <ItemCacheEntry>[];
  final _entriesByType = <ItemCacheType, List<ItemCacheEntry>>{};
  final _groupedEntries = <String, ItemCacheEntry>{};
  var _groups = const <ItemCacheGroup>[];

  List<ItemCacheEntry> get entries => _entries;
  List<ItemCacheGroup> get groups => _groups;

  /// a single item lists each file, several items merge files of the same kind into one entry.
  /// temp files are left for [collectTempFiles].
  static Future<ItemsCache> collect({required Iterable<Track> tracks, required Iterable<String> videoIds}) async {
    final candidates = await _ItemsCacheCandidates.build(tracks: tracks, videoIds: videoIds);
    final scanParams = _ScanParams.inAppDirs(paths: candidates.paths, videoIds: candidates.videoIds);
    final scanned = await _scanIsolate.thready(scanParams);
    final cache = ItemsCache._(candidates.isSingle, candidates.videoIds, candidates.refs);
    candidates.addScannedTo(cache, scanned);
    cache._buildGroups();
    return cache;
  }

  /// lists the whole video and audio cache folders, which can take seconds.
  /// returns true if anything was added.
  Future<bool> collectTempFiles() async {
    if (_videoIds.isEmpty) return false;
    final scanParams = _ScanParams.inAppDirs(paths: const [], videoIds: _videoIds);
    final tempFiles = await _scanTempFilesIsolate.thready(scanParams);
    if (tempFiles.isEmpty) return false;
    for (final f in tempFiles) {
      _addEntry(f.type, lang.deleteTempFiles, true, [f.path], f.size);
    }
    _buildGroups();
    return true;
  }

  void _addEntry(ItemCacheType type, String title, bool isTemp, List<String> paths, int size) {
    final shouldGroup = !_isSingle || isTemp;
    final groupKey = shouldGroup ? '${type.index}_${isTemp}_$title' : null;
    final grouped = groupKey == null ? null : _groupedEntries[groupKey];
    if (grouped != null) {
      grouped._merge(paths, size);
      return;
    }
    final entry = ItemCacheEntry._(type, title, isTemp, paths, size);
    if (groupKey != null) _groupedEntries[groupKey] = entry;
    (_entriesByType[type] ??= []).add(entry);
    _entries.add(entry);
  }

  void _buildGroups() {
    _groups = [
      for (final type in ItemCacheType.values)
        if (_entriesByType[type] case final entries?) ItemCacheGroup._(type, entries),
    ];
  }

  /// checked in chunks to stop early, files that need listing a directory are checked last for all at once.
  static Future<bool> hasAnything(List<Track> tracks) async {
    final videoIds = <String>{};
    for (int start = 0; start < tracks.length; start += _kHasAnythingChunkSize) {
      final end = (start + _kHasAnythingChunkSize).withMaximum(tracks.length);
      final chunk = tracks.sublist(start, end);
      final candidates = await _ItemsCacheCandidates.build(tracks: chunk, videoIds: const []);
      final scanParams = _ScanParams.inAppDirs(paths: candidates.paths, videoIds: const {});
      final hasAnyFile = await _anyExistsIsolate.thready(scanParams);
      if (hasAnyFile) return true;
      videoIds.addAll(candidates.videoIds);
    }
    if (videoIds.isEmpty) return false;
    final listingParams = _ScanParams.inAppDirs(paths: const [], videoIds: videoIds);
    return _anyExistsIsolate.thready(listingParams);
  }

  static const _kHasAnythingChunkSize = 200;

  static _ScanResult _scanIsolate(_ScanParams params) {
    final paths = params.paths;
    final sizes = List<int>.filled(paths.length, -1);
    for (int i = 0; i < paths.length; i++) {
      final size = File(paths[i]).fileSizeSync();
      if (size != null) sizes[i] = size;
    }
    final subtitleFiles = _listFiles(params, _loopSubtitleFiles);
    return _ScanResult(sizes, subtitleFiles);
  }

  static List<_ListedFile> _scanTempFilesIsolate(_ScanParams params) => _listFiles(params, _loopTempFiles);

  static List<_ListedFile> _listFiles(_ScanParams params, bool Function(_ScanParams params, _OnListedFile onFile) loopFiles) {
    final listedFiles = <_ListedFile>[];
    loopFiles(params, (type, file) {
      final size = file.fileSizeSync();
      if (size != null) listedFiles.add(_ListedFile(type, file.path, size));
      return false;
    });
    return listedFiles;
  }

  static bool _anyExistsIsolate(_ScanParams params) {
    for (final path in params.paths) {
      if (File(path).existsSync()) return true;
    }
    bool stopAtFirst(ItemCacheType type, File file) => true;
    return _loopSubtitleFiles(params, stopAtFirst) || _loopTempFiles(params, stopAtFirst);
  }

  /// subtitles folder is small, unlike the video and audio cache folders.
  static bool _loopSubtitleFiles(_ScanParams params, _OnListedFile onFile) {
    final videoIds = params.videoIds;
    if (videoIds.isEmpty) return false;
    bool isSubtitleFile(String filename) => filename.length > _kVideoIdLength + 1 && filename.codeUnitAt(_kVideoIdLength) == 0x5F /* _ */ && filename.endsWith('.vtt');
    return _loopVideoIdsFilesIn(params.subtitlesDirPath, videoIds, ItemCacheType.subtitles, isSubtitleFile, onFile);
  }

  static bool _loopTempFiles(_ScanParams params, _OnListedFile onFile) {
    final videoIds = params.videoIds;
    if (videoIds.isEmpty) return false;
    bool isAnyFile(String filename) => true;
    bool isPartFile(String filename) => filename.endsWith('.part');
    return _loopVideoIdsFilesIn(params.videosTempDirPath, videoIds, ItemCacheType.video, isAnyFile, onFile) ||
        _loopVideoIdsFilesIn(params.videosDirPath, videoIds, ItemCacheType.video, isPartFile, onFile) ||
        _loopVideoIdsFilesIn(params.audiosDirPath, videoIds, ItemCacheType.audio, isPartFile, onFile);
  }

  /// [onFile] returns true to stop, the result is whether it stopped.
  static bool _loopVideoIdsFilesIn(String dirPath, Set<String> videoIds, ItemCacheType type, bool Function(String filename) isMatching, _OnListedFile onFile) {
    for (final e in Directory(dirPath).listSyncSafe()) {
      if (e is! File) continue;
      final filename = e.path.getFilename;
      if (filename.length < _kVideoIdLength) continue;
      final videoId = filename.substring(0, _kVideoIdLength);
      if (!videoIds.contains(videoId)) continue;
      if (!isMatching(filename)) continue;
      if (onFile(type, e)) return true;
    }
    return false;
  }

  static const _kVideoIdLength = 11;

  Future<void> deleteEntries(Iterable<ItemCacheEntry> entries) async {
    final paths = entries.expand((e) => e.paths).toFixedList();
    await _deleteFilesIsolate.thready(paths);

    final refs = _refs;
    final serverTracks = <Track>[];
    final videoIdsToRecheck = <String>{};
    int removedArtworksCount = 0;
    int removedArtworksSize = 0;
    for (final path in paths) {
      final videoIdOfVideo = refs.videoIdByVideoPath[path];
      if (videoIdOfVideo != null) {
        VideoController.inst.removeNVFromCacheMap(videoIdOfVideo, path);
        videoIdsToRecheck.add(videoIdOfVideo);
        continue;
      }
      final videoIdOfAudio = refs.videoIdByAudioPath[path];
      if (videoIdOfAudio != null) {
        AudioCacheController.inst.removeFromCacheMap(videoIdOfAudio, path);
        continue;
      }
      final serverTrack = refs.serverTrackByPath[path];
      if (serverTrack != null) {
        serverTracks.add(serverTrack);
        continue;
      }
      final artworkSize = refs.artworkSizeByPath[path];
      if (artworkSize != null) {
        removedArtworksCount++;
        removedArtworksSize += artworkSize;
      }
    }

    if (removedArtworksCount > 0) Indexer.inst.updateImageSizesInStorage(removedCount: removedArtworksCount, removedSize: removedArtworksSize);
    if (serverTracks.isNotEmpty) await ServerCacheController.inst.removeCached(serverTracks);
    for (final videoId in videoIdsToRecheck) {
      Player.inst.recheckCachedVideos(videoId);
    }
  }

  static void _deleteFilesIsolate(List<String> paths) {
    for (final path in paths) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
  }
}

class _ItemsCacheCandidates {
  final bool isSingle;
  final Set<String> videoIds;
  final Set<String> vipVideoIds;
  final Map<String, List<NamidaVideo>> videosByVideoId;

  _ItemsCacheCandidates._(this.isSingle, this.videoIds, this.vipVideoIds, this.videosByVideoId);

  final refs = _ItemsCacheRefs();
  final paths = <String>[];
  final _candidates = <_Candidate>[];
  final _addedPaths = <String>{};

  static Future<_ItemsCacheCandidates> build({required Iterable<Track> tracks, required Iterable<String> videoIds}) async {
    final uniqueTracks = <Track, String?>{};
    final allVideoIds = <String>{};
    for (final tr in tracks) {
      if (uniqueTracks.containsKey(tr)) continue;
      final videoId = tr.youtubeID.nullifyEmpty();
      uniqueTracks[tr] = videoId;
      if (videoId != null) allVideoIds.add(videoId);
    }
    final standaloneVideoIds = <String>{};
    for (final videoId in videoIds) {
      if (allVideoIds.add(videoId)) standaloneVideoIds.add(videoId);
    }

    final vipVideoIds = <String>{};
    final videosByVideoId = <String, List<NamidaVideo>>{};
    await allVideoIds.loopConcurrent((videoId) async {
      final hasVideos = VideoController.inst.hasNVCachedFromID(videoId);
      final hasAudios = AudioCacheController.inst.audioCacheMap[videoId]?.isNotEmpty == true;
      if (!hasVideos && !hasAudios) return;
      final priority = await VideoController.inst.videosPriorityManager.getVideoPriority(videoId);
      if (priority == CacheVideoPriority.VIP) {
        vipVideoIds.add(videoId);
        return;
      }
      if (hasVideos) videosByVideoId[videoId] = await VideoController.inst.getNVFromID(videoId);
    });

    final itemsCount = uniqueTracks.length + standaloneVideoIds.length;
    final res = _ItemsCacheCandidates._(itemsCount == 1, allVideoIds, vipVideoIds, videosByVideoId);
    for (final e in uniqueTracks.entries) {
      res._addItem(e.key, e.value);
    }
    for (final videoId in standaloneVideoIds) {
      res._addItem(null, videoId);
    }
    return res;
  }

  void _addItem(Track? tr, String? videoId) {
    final waveformSources = <String>[];
    if (tr != null) _addTrack(tr, waveformSources);
    if (videoId != null) _addVideoId(videoId, waveformSources, isFromTrack: tr != null);
    if (waveformSources.isEmpty) return;

    final waveformPaths = <String>[];
    for (final source in waveformSources) {
      waveformPaths.add(WaveformExtractor.cacheFilePathFor(source));
      waveformPaths.add(SpectrumController.cacheFilePathFor(source));
    }
    _add(ItemCacheType.waveform, lang.waveform, waveformPaths);
  }

  void _addTrack(Track tr, List<String> waveformSources) {
    final imagePath = tr.pathToImage;
    final paletteKey = tr.cacheKeyForImage(AppDirs.PALETTES);
    final palettePath = FileParts.joinPath(AppDirs.PALETTES, '$paletteKey.palette');
    _add(ItemCacheType.artwork, lang.artwork, [imagePath, palettePath]);
    if (imagePath.startsWith(AppDirs.ARTWORKS)) refs.artworkPaths.add(imagePath);

    final lrcUtils = LrcSearchUtilsSelectable(kDummyExtendedTrack, tr);
    final lrcPath = lrcUtils.cachedLRCFile.path;
    final txtPath = lrcUtils.cachedTxtFile.path;
    _add(ItemCacheType.lyrics, '${lang.lyrics} (${lang.synced})', [lrcPath]);
    _add(ItemCacheType.lyrics, '${lang.lyrics} (${lang.plain})', [txtPath]);

    if (tr.isNetwork) {
      final serverFile = ServerCacheController.cacheFileForPath(tr.path);
      final serverFilePath = serverFile.path;
      final metadataFilePath = ServerCacheController.metadataFileOf(serverFile).path;
      _add(ItemCacheType.server, lang.audio, [serverFilePath, metadataFilePath]);
      refs.serverTrackByPath[serverFilePath] = tr;
      waveformSources.add(serverFilePath);
    } else {
      waveformSources.add(tr.path);
    }
  }

  void _addVideoId(String videoId, List<String> waveformSources, {required bool isFromTrack}) {
    final audios = AudioCacheController.inst.audioCacheMap[videoId];
    if (audios != null) {
      for (final a in audios) {
        waveformSources.add(a.file.path);
      }
    }

    if (!vipVideoIds.contains(videoId)) {
      final videos = videosByVideoId[videoId];
      if (videos != null) {
        for (final v in videos) {
          final path = v.path;
          final title = "${v.resolution}p • ${v.framerate}fps";
          _add(ItemCacheType.video, title, [path, '$path.metadata']);
          refs.videoIdByVideoPath[path] = videoId;
        }
      }
      if (audios != null) {
        for (final a in audios) {
          final path = a.file.path;
          final bitrate = a.bitrate;
          final bitrateText = bitrate == null ? lang.audio : "${bitrate ~/ 1000}kb/s";
          final languageName = a.langaugeName;
          final title = languageName == null ? bitrateText : "$bitrateText • $languageName";
          _add(ItemCacheType.audio, title, [path, '$path.metadata']);
          refs.videoIdByAudioPath[path] = videoId;
        }
      }
    }

    final thumbnailPath = ThumbnailManager.inst.imageUrlToCacheFile(id: videoId, url: null, type: ThumbnailType.video)?.path;
    if (thumbnailPath != null) {
      final palettePath = FileParts.joinPath(AppDirs.YT_PALETTES, '${thumbnailPath.getFilenameWOExt}.palette');
      _add(ItemCacheType.artwork, lang.thumbnails, [thumbnailPath, palettePath]);
    }
    final extractedThumbnailFilenameWOExt = 'EXT_$videoId';
    final extractedThumbnailPath = FileParts.joinPath(AppDirs.YT_THUMBNAILS, '$extractedThumbnailFilenameWOExt.png');
    final extractedPalettePath = FileParts.joinPath(AppDirs.YT_PALETTES, '$extractedThumbnailFilenameWOExt.palette');
    _add(ItemCacheType.artwork, '${lang.thumbnails} (${lang.video})', [extractedThumbnailPath, extractedPalettePath]);
    final tempThumbnailPath = ThumbnailManager.inst
        .imageUrlToCacheFile(
          id: videoId,
          url: null,
          type: ThumbnailType.video,
          isTemp: true,
        )
        ?.path;
    if (tempThumbnailPath != null) _add(ItemCacheType.artwork, lang.deleteTempFiles, [tempThumbnailPath], isTemp: true);

    final video = YoutubeID(id: videoId, playlistID: null);
    final lrcUtils = LrcSearchUtilsYoutubeID(video, videoTitle: null, channelTitle: null, duration: null);
    final lrcPath = lrcUtils.cachedLRCFile.path;
    final txtPath = lrcUtils.cachedTxtFile.path;
    final lyricsSourceSuffix = isFromTrack ? ' • ${lang.youtube}' : '';
    _add(ItemCacheType.lyrics, '${lang.lyrics} (${lang.synced})$lyricsSourceSuffix', [lrcPath]);
    _add(ItemCacheType.lyrics, '${lang.lyrics} (${lang.plain})$lyricsSourceSuffix', [txtPath]);
  }

  /// a path goes to the first entry only, two thumbnails can share one palette.
  void _add(ItemCacheType type, String title, List<String> entryPaths, {bool isTemp = false}) {
    final start = paths.length;
    for (final path in entryPaths) {
      if (_addedPaths.add(path)) paths.add(path);
    }
    final end = paths.length;
    if (end == start) return;
    _candidates.add(_Candidate(type, title, isTemp, start, end));
  }

  void addScannedTo(ItemsCache cache, _ScanResult scanned) {
    final sizes = scanned.sizes;
    final artworkPaths = refs.artworkPaths;
    for (final c in _candidates) {
      final existingPaths = <String>[];
      int totalSize = 0;
      for (int i = c.start; i < c.end; i++) {
        final size = sizes[i];
        if (size < 0) continue;
        final path = paths[i];
        existingPaths.add(path);
        totalSize += size;
        if (artworkPaths.contains(path)) refs.artworkSizeByPath[path] = size;
      }
      if (existingPaths.isEmpty) continue;
      cache._addEntry(c.type, c.title, c.isTemp, existingPaths, totalSize);
    }

    for (final f in scanned.subtitleFiles) {
      final title = _subtitleTitleOf(f.path);
      cache._addEntry(f.type, title, false, [f.path], f.size);
    }
  }

  /// subtitle files are named `{videoId}_{vssId}`, where vssId is like `.en` or `a.en` for auto generated ones.
  static String _subtitleTitleOf(String path) {
    final filenameWOExt = path.getFilenameWOExt;
    final vssId = filenameWOExt.substring(ItemsCache._kVideoIdLength + 1);
    final isAutoGenerated = vssId.startsWith('a.');
    final dotIndex = vssId.indexOf('.');
    final languageCode = dotIndex == -1 ? vssId : vssId.substring(dotIndex + 1);
    final languageName = SubtitleTrack.languageNameOf(languageCode);
    final title = languageName.isEmpty ? vssId : languageName;
    return isAutoGenerated ? '$title • ${lang.autoGenerated}' : title;
  }
}

class _ItemsCacheRefs {
  final videoIdByVideoPath = <String, String>{};
  final videoIdByAudioPath = <String, String>{};
  final serverTrackByPath = <String, Track>{};

  /// only the ones inside [AppDirs.ARTWORKS], which the indexer counts.
  final artworkPaths = <String>{};
  final artworkSizeByPath = <String, int>{};
}

enum ItemCacheType {
  video,
  audio,
  server,
  artwork,
  lyrics,
  subtitles,
  waveform,
}

class ItemCacheGroup {
  final ItemCacheType type;
  final List<ItemCacheEntry> entries;

  ItemCacheGroup._(this.type, this.entries);

  late final int totalSize = entries.fold(0, (p, e) => p + e.size);
  late final int totalMergedCount = entries.fold(0, (p, e) => p + e.mergedCount);
}

class ItemCacheEntry {
  final ItemCacheType type;
  final String title;
  final bool isTemp;
  final List<String> paths;

  ItemCacheEntry._(this.type, this.title, this.isTemp, this.paths, this._size);

  int _size;
  int _mergedCount = 1;

  int get size => _size;
  int get mergedCount => _mergedCount;

  void _merge(List<String> paths, int size) {
    this.paths.addAll(paths);
    _size += size;
    _mergedCount++;
  }
}

class _Candidate {
  final ItemCacheType type;
  final String title;
  final bool isTemp;
  final int start;
  final int end;

  const _Candidate(this.type, this.title, this.isTemp, this.start, this.end);
}

class _ScanParams {
  final List<String> paths;
  final Set<String> videoIds;
  final String videosDirPath;
  final String videosTempDirPath;
  final String audiosDirPath;
  final String subtitlesDirPath;

  const _ScanParams({
    required this.paths,
    required this.videoIds,
    required this.videosDirPath,
    required this.videosTempDirPath,
    required this.audiosDirPath,
    required this.subtitlesDirPath,
  });

  /// [AppDirs] is not filled inside other isolates.
  factory _ScanParams.inAppDirs({required List<String> paths, required Set<String> videoIds}) {
    return _ScanParams(
      paths: paths,
      videoIds: videoIds,
      videosDirPath: AppDirs.VIDEOS_CACHE,
      videosTempDirPath: AppDirs.VIDEOS_CACHE_TEMP,
      audiosDirPath: AppDirs.AUDIOS_CACHE,
      subtitlesDirPath: AppDirs.SUBTITLES,
    );
  }
}

class _ScanResult {
  final List<int> sizes;
  final List<_ListedFile> subtitleFiles;

  const _ScanResult(this.sizes, this.subtitleFiles);
}

class _ListedFile {
  final ItemCacheType type;
  final String path;
  final int size;

  const _ListedFile(this.type, this.path, this.size);
}

typedef _OnListedFile = bool Function(ItemCacheType type, File file);
