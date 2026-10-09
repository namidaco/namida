// by claude
part of 'music_web_server_base.dart';

/// servers that hand out whole files (smb, ftp, sftp): a subclass lists a directory and reads a file, indexing, caching & artwork are shared.
abstract class _FileTransferServer extends MusicWebServer {
  _FileTransferServer(super.authDetails);

  /// files fetched at once while indexing.
  int get _fetchConcurrency;

  /// whether [_openRead] fetches only the requested range, tags are then read through [_LocalRangeProxy] instead of downloading whole files.
  bool get _canReadRanges;

  String get _basePath;

  Future<List<_RemoteEntry>> _listDir(String dirPath);

  /// [end] is exclusive, defaults to the end of the file.
  Future<Stream<List<int>>> _openRead(String path, int start, [int? end]);

  Future<int> _fileSize(String path);

  void _onFetchError(Object error) {}

  @override
  Future<WebStreamUriDetails?> getStreamUrl(String id, {void Function(File cachedFile)? onFetchedIfLocal}) async {
    try {
      final cacheFile = ServerCacheController.cacheFileFor(authDetails.dir.type, authDetails.auth.username, id);
      await _downloadToFile(id, cacheFile);
      onFetchedIfLocal?.call(cacheFile);
      return WebStreamUriDetails.fromUri(
        Uri.file(cacheFile.path),
        allowStreamCaching: false, // already cached
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<_ServerFileSource?> _getOriginalFileSource(String id) async {
    return _ServerFileSourceStream((start) => _openRead(id, start));
  }

  @override
  Future<Uint8List?> getImage(String id) async {
    final isVideo = id.isVideo();
    if (_canReadRanges) {
      try {
        final size = await _fileSize(id);
        final url = await _LocalRangeProxy.inst.urlFor(this, id, size);
        final artwork = await NamidaTaggerController.inst.extractArtwork(trackPath: url, isVideo: isVideo);
        return artwork?.bytes;
      } catch (_) {
        return null;
      }
    }

    final tempFile = _tempFileFor(id);
    try {
      await _downloadToFile(id, tempFile);
      final artwork = await NamidaTaggerController.inst.extractArtwork(trackPath: tempFile.path, isVideo: isVideo);
      return artwork?.bytes;
    } catch (_) {
      return null;
    } finally {
      tempFile.tryDeleting();
    }
  }

  @override
  Future<void> fetchAllMusicAndProcess(Map<String, int> serverTracksInLibrary, void Function(TrackExtended trExt) callback, {required bool forceReIndex}) async {
    final server = authDetails.dir.toDbKey();
    final serverUriParsed = Uri.parse(server);
    final scan = _FileTransferScan(
      server: server,
      serverUriParsed: serverUriParsed,
      splittersConfigs: SplitArtistGenreConfigsWrapper.settings(),
      minDur: settings.indexMinDurationInSec.value,
      minSize: settings.indexMinFileSizeInB.value,
      extractArtwork: Indexer.inst.isNetworkArtworkCachingEnabled,
      diffState: forceReIndex ? null : _ServerDiffManager(serverUriParsed, serverTracksInLibrary, callback),
      baseSegments: _splitRemotePath(_basePath),
    );
    try {
      await for (final trExt in _walk(_basePath, scan, isRoot: true)) {
        callback(trExt);
      }
    } catch (e) {
      _onFetchError(e);
    }
  }

  /// an unreachable subfolder is skipped, the root is not so auth errors reach [_onFetchError].
  Stream<TrackExtended> _walk(String dirPath, _FileTransferScan scan, {required bool isRoot}) async* {
    final List<_RemoteEntry> entries;
    try {
      entries = await _listDir(dirPath);
    } catch (_) {
      if (isRoot) rethrow;
      return;
    }

    final mediaFiles = <_RemoteEntry>[];
    final lrcFiles = <_RemoteEntry>[];
    final subdirs = <_RemoteEntry>[];
    for (final entry in entries) {
      final name = entry.name;
      if (entry.isDir) {
        subdirs.add(entry);
      } else if (NamidaFileExtensionsWrapper.audioAndVideo.isPathValid(name)) {
        mediaFiles.add(entry);
      } else if (NamidaFileExtensionsWrapper.lrc.isPathValid(name) || NamidaFileExtensionsWrapper.txt.isPathValid(name)) {
        lrcFiles.add(entry);
      }
    }

    final tracksByNameWOExt = lrcFiles.isEmpty ? null : <String, TrackExtended>{};
    final total = mediaFiles.length;
    if (total > 0) {
      // -- a sliding window, a new file starts as soon as any finishes instead of each batch waiting for its slowest
      final processed = StreamController<(int, TrackExtended?)>();
      int nextIndex = 0;
      Future<void> worker() async {
        while (nextIndex < total) {
          final index = nextIndex++;
          final trExt = await _processFile(mediaFiles[index], scan);
          processed.add((index, trExt));
        }
      }

      final workersCount = _fetchConcurrency.withMaximum(total);
      final workers = Future.wait(List.generate(workersCount, (_) => worker()));
      workers.whenComplete(processed.close).ignoreError();
      await for (final (index, trExt) in processed.stream) {
        if (trExt == null) continue;
        yield trExt;
        tracksByNameWOExt?[mediaFiles[index].name.getFilenameWOExt] = trExt;
      }
    }

    if (tracksByNameWOExt != null) {
      for (final lrc in lrcFiles) {
        final trExt = tracksByNameWOExt[lrc.name.getFilenameWOExt];
        if (trExt == null) continue;
        final isSynced = NamidaFileExtensionsWrapper.lrc.isPathValid(lrc.name);
        final lrcUtils = LrcSearchUtilsSelectableFromNetwork(trExt, trExt.asTrack());
        final lrcFileInCache = isSynced ? lrcUtils.cachedLRCFile : lrcUtils.cachedTxtFile;
        try {
          await _downloadToFile(lrc.path, lrcFileInCache);
        } catch (_) {}
      }
    }

    for (final dir in subdirs) {
      yield* _walk(dir.path, scan, isRoot: false);
    }
  }

  Future<TrackExtended?> _processFile(_RemoteEntry entry, _FileTransferScan scan) async {
    final path = entry.path;
    final modifiedMS = entry.modifiedMS;
    final serverFolder = _serverFolderOf(path, baseSegments: scan.baseSegments);
    final diffState = scan.diffState;
    if (diffState != null) {
      final remoteModified = modifiedMS == null ? null : DateTime.fromMillisecondsSinceEpoch(modifiedMS);
      final canSkip = diffState.checkCanSkipScanAndMarkExists(path, remoteModified, serverFolder: serverFolder);
      if (canSkip) return null;
    }

    try {
      final trackInfo = await _extractMetadata(entry, scan.extractArtwork);
      final trExt = await Indexer.convertServerTagToTrack(
        path: path,
        trackInfo: trackInfo,
        stats: FileStatsAdv(
          creationDateMS: null,
          modifiedMS: modifiedMS,
          size: entry.size,
        ),
        server: scan.server,
        minDur: scan.minDur,
        minSize: scan.minSize,
        tryExtractingFromFilename: true,
        onMinDurTrigger: () {
          Indexer.inst.filteredForSizeDurationTracks.value++;
          return null;
        },
        onMinSizeTrigger: () {
          Indexer.inst.filteredForSizeDurationTracks.value++;
          return null;
        },
        onError: (_) => null,
        splittersConfigs: scan.splittersConfigs,
      );
      if (trExt == null) return null;
      final serverUriParsed = scan.serverUriParsed;
      final newUri = serverUriParsed.replace(
        queryParameters: {
          ...serverUriParsed.queryParameters,
          'd': path,
        },
      );
      return trExt.copyWith(generatePathHash: true, path: newUri.toString(), serverFolder: serverFolder);
    } catch (_) {
      return null;
    }
  }

  Future<FAudioModel> _extractMetadata(_RemoteEntry entry, bool extractArtwork) async {
    final path = entry.path;
    final size = entry.size;
    final isVideo = entry.name.isVideo();
    if (_canReadRanges && size != null) {
      final url = await _LocalRangeProxy.inst.urlFor(this, path, size);
      final trackInfo = await NamidaTaggerController.inst.extractMetadata(
        trackPath: url,
        isVideo: isVideo,
        extractArtwork: extractArtwork,
        saveArtworkToCache: extractArtwork,
        isNetwork: true,
        networkId: path,
      );
      if (!trackInfo.hasError) return trackInfo;
      // -- the whole file tells apart a network error (skipped) from a file taglib can't read (filename info)
    }

    final tempFile = _tempFileFor(path);
    try {
      await _downloadToFile(path, tempFile);
      return await NamidaTaggerController.inst.extractMetadata(
        trackPath: tempFile.path,
        isVideo: isVideo,
        extractArtwork: extractArtwork,
        saveArtworkToCache: extractArtwork,
        isNetwork: true,
        networkId: path,
      );
    } finally {
      tempFile.tryDeleting();
    }
  }

  Future<void> _downloadToFile(String path, File toFile) async {
    await toFile.create(recursive: true);
    final sink = toFile.openWrite();
    try {
      await sink.addStream(await _openRead(path, 0));
    } finally {
      await sink.close();
    }
  }

  File _tempFileFor(String path) => FileParts.join(AppDirs.APP_CACHE, authDetails.dir.type.name, authDetails.auth.username, path.toFastHashKey());
}

class _RemoteEntry {
  final String path;
  final String name;
  final bool isDir;
  final int? size;
  final int? modifiedMS;

  const _RemoteEntry({
    required this.path,
    required this.name,
    required this.isDir,
    required this.size,
    required this.modifiedMS,
  });
}

class _FileTransferScan {
  final String server;
  final Uri serverUriParsed;
  final SplitArtistGenreConfigsWrapper splittersConfigs;
  final int minDur;
  final int minSize;
  final bool extractArtwork;
  final _ServerDiffManager? diffState;
  final List<String> baseSegments;

  const _FileTransferScan({
    required this.server,
    required this.serverUriParsed,
    required this.splittersConfigs,
    required this.minDur,
    required this.minSize,
    required this.extractArtwork,
    required this.diffState,
    required this.baseSegments,
  });
}
