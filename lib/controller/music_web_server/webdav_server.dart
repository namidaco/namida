part of 'music_web_server_base.dart';

class _WebDAVServer extends MusicWebServer {
  _ClientApiWrapper? _api;
  late Uri _serverUri;
  Map<String, String>? _serverAuthHeaders;
  late BasicAuth _authInfo;
  Uri _buildServerUri(String serverPath) {
    final basePath = _serverUri.path.endsWith('/') ? _serverUri.path : '${_serverUri.path}/';
    final trimmed = serverPath.startsWith('/') ? serverPath.substring(1) : serverPath;
    return _serverUri.replace(
      path: '$basePath$trimmed',
    );
  }

  // -- it's safe to assume that webdav(http) is supported for all platforms, however it's kept
  // -- in case the system one was picked and didn't support it.
  // -- only used for files taglib can't read.
  late final Future<bool> _ffmpegSupportsWebDAV = NamidaFFMPEG.inst.supportsWebDAV();

  _WebDAVServer.init(super.authDetails) {
    _authInfo = authDetails.auth.toBasicAuthModel();
    _api = _ClientApiWrapper(
      webdav.newClient(
        authDetails.dir.sourceRaw,
        user: _authInfo.username,
        password: _authInfo.password,
      ),
    );

    _serverUri = Uri.parse(authDetails.dir.sourceRaw);

    if (_authInfo.username.isNotEmpty) {
      final userInfoEncoded = '${Uri.encodeComponent(_authInfo.username)}:${Uri.encodeComponent(_authInfo.password)}';
      final credentials = base64Encode(utf8.encode('${_authInfo.username}:${_authInfo.password}'));
      _serverUri = _serverUri.replace(userInfo: userInfoEncoded);
      _serverAuthHeaders = {
        "Authorization": "Basic $credentials",
      };
    }
  }

  @override
  void dispose() {
    _api?.close(force: true);
  }

  @override
  Future<WebStreamUriDetails?> getStreamUrl(String id, {void Function(File cachedFile)? onFetchedIfLocal}) async {
    final api = _api;
    if (api == null) return null;

    final serverPath = id; // -- already decoded
    final uri = _buildServerUri(serverPath);

    return WebStreamUriDetails.fromUri(
      uri,
      headers: _serverAuthHeaders,
      allowStreamCaching: false, // already cached
    );
  }

  @override
  Future<Uint8List?> getImage(String id) async {
    final api = _api;
    if (api == null) return null;

    final serverPath = id;

    final uri = _buildServerUri(serverPath);
    final uriString = uri.toString();
    final name = serverPath.getFilename;
    final isVideo = name.isVideo();
    final artwork = await NamidaTaggerController.inst.extractArtwork(
      trackPath: uriString,
      isVideo: isVideo,
      httpHeaders: _serverAuthHeaders,
    );
    return artwork?.bytes;
  }

  @override
  Future<MusicWebServerError?> ping() async {
    try {
      await _api?.ping();
      return null;
    } on DioException catch (e) {
      return MusicWebServerError(code: e.response?.statusCode ?? 0, message: e.message ?? e.response?.statusMessage ?? '?');
    } catch (e) {
      return MusicWebServerError(code: 0, message: 'Unknown Error: $e');
    }
  }

  @override
  Future<void> fetchAllMusicAndProcess(Map<String, int> serverTracksInLibrary, void Function(TrackExtended trExt) callback, {required bool forceReIndex}) async {
    final api = _api;
    if (api == null) return;

    final server = authDetails.dir.toDbKey();
    final serverUriParsed = Uri.parse(server);
    final splittersConfigs = SplitArtistGenreConfigsWrapper.settings();
    final identifiersSet = TagsExtractor.getAlbumIdentifiersSet();
    final minDur = settings.indexMinDurationInSec.value;
    final minSize = settings.indexMinFileSizeInB.value;

    final diffState = _ServerDiffManager(serverUriParsed, serverTracksInLibrary, callback);

    try {
      final networkFiles = await api.readDir('/');

      final stream = _fetchSongsForFilesBatch(
        api: api,
        server: server,
        serverUriParsed: serverUriParsed,
        files: networkFiles,
        splittersConfigs: splittersConfigs,
        identifiersSet: identifiersSet,
        minDur: minDur,
        minSize: minSize,
        diffState: diffState,
      );

      await for (final trExt in stream) {
        callback(trExt);
      }
    } on DioException catch (e) {
      _onResError(authDetails.dir, e);
    }
  }

  void _onResError(DirectoryIndex dir, DioException err) {
    if (err.isUnAuthorized()) {
      if (dir is DirectoryIndexServer) MusicWebServerAuthDetails.manager.deleteFromDb(dir);
    }
  }

  Stream<TrackExtended> _fetchSongsForFilesBatch({
    required _ClientApiWrapper api,
    required String server,
    required Uri serverUriParsed,
    required List<webdav.File> files,
    required SplitArtistGenreConfigsWrapper splittersConfigs,
    required Set<AlbumIdentifier> identifiersSet,
    required int minDur,
    required int minSize,
    required _ServerDiffManager diffState,
  }) async* {
    final imageFiles = <webdav.File>[];
    final lrcFiles = <(webdav.File, bool)>[];
    final lrcFilesInfoToExtractLater = <String, TrackExtended>{};
    final artworksToExtractLater = <String, List<_ExtractInfo>>{};
    const subBatchSize = 10;

    for (var i = 0; i < files.length; i += subBatchSize) {
      final batch = files.skip(i).take(subBatchSize);
      final subfiles = <webdav.File>[];
      final subdirectories = <webdav.File>[];

      for (final file in batch) {
        if (file.isDir == true) {
          subdirectories.add(file);
        } else {
          final path = file.path;
          if (path != null) {
            if (NamidaFileExtensionsWrapper.audioAndVideo.isPathValid(path)) {
              subfiles.add(file);
            } else if (NamidaFileExtensionsWrapper.image.isPathValid(path)) {
              imageFiles.add(file);
            } else if (NamidaFileExtensionsWrapper.lrc.isPathValid(path)) {
              lrcFiles.add((file, true));
            } else if (NamidaFileExtensionsWrapper.txt.isPathValid(path)) {
              lrcFiles.add((file, false));
            }
          }
        }
      }

      if (subfiles.isNotEmpty) {
        final futures = subfiles.map((file) async {
          final serverPath = file.path;
          if (serverPath == null) return null;

          final serverFolder = _serverFolderOf(serverPath);
          final canSkip = diffState.checkCanSkipScanAndMarkExists(serverPath, file.mTime, serverFolder: serverFolder);
          if (canSkip) return null;

          final res = await _fetchFileAndExtractInfo(serverPath, file.name, api, identifiersSet, artworksToExtractLater);
          if (res == null) return null;

          final trExt = await Indexer.convertServerTagToTrack(
            path: serverPath,
            trackInfo: res.$1,
            stats: FileStatsAdv(
              creationDateMS: file.cTime?.millisecondsSinceEpoch,
              modifiedMS: file.mTime?.millisecondsSinceEpoch,
              size: file.size,
            ),
            server: server,
            minDur: minDur,
            minSize: minSize,
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
            splittersConfigs: splittersConfigs,
          );

          res.$3?.tryDeleting();

          if (trExt != null) {
            final newUri = serverUriParsed.replace(
              queryParameters: {
                ...serverUriParsed.queryParameters,
                'd': res.$2,
              },
            );
            final newPath = newUri.toString();
            final newTrExt = trExt.copyWith(generatePathHash: true, path: newPath, serverFolder: serverFolder);

            final serverPathWOExt = p.basenameWithoutExtension(serverPath);
            lrcFilesInfoToExtractLater[serverPathWOExt] = newTrExt;

            return newTrExt;
          }
          return null;
        });

        final results = await Future.wait(futures);

        for (final trExt in results) {
          if (trExt != null) {
            yield trExt;
          }
        }
      }

      for (final dir in subdirectories) {
        final dirPath = dir.path;
        if (dirPath != null) {
          try {
            final subfiles = await api.readDir(dirPath);
            yield* _fetchSongsForFilesBatch(
              api: api,
              server: server,
              serverUriParsed: serverUriParsed,
              files: subfiles,
              splittersConfigs: splittersConfigs,
              identifiersSet: identifiersSet,
              minDur: minDur,
              minSize: minSize,
              diffState: diffState,
            );
          } catch (_) {
            continue;
          }
        }
      }
    }

    for (final lrc in lrcFiles) {
      final lrcPath = lrc.$1.path;
      if (lrcPath != null) {
        try {
          final lrcPathWOExt = p.basenameWithoutExtension(lrcPath);
          final trackInfo = lrcFilesInfoToExtractLater[lrcPathWOExt];
          if (trackInfo != null) {
            final bytes = await _api?.read(lrcPath);
            if (bytes != null) {
              final lrcUtils = LrcSearchUtilsSelectableFromNetwork(trackInfo, trackInfo.asTrack());
              final isSynced = lrc.$2;
              final lrcFileInCache = isSynced ? lrcUtils.cachedLRCFile : lrcUtils.cachedTxtFile;
              await lrcFileInCache.writeAsBytes(bytes);
            }
          }
        } catch (_) {}
      }
    }

    // -- a sibling image wins over the embedded artwork already saved while reading tags
    for (final img in imageFiles) {
      final imgPath = img.path;
      if (imgPath != null) {
        try {
          final serverPathWOExt = p.basenameWithoutExtension(imgPath);
          final artworksToWrite = artworksToExtractLater[serverPathWOExt];
          if (artworksToWrite == null) continue;
          final bytes = await _api?.read(imgPath);
          if (bytes == null || bytes.isEmpty) continue;
          for (final e in artworksToWrite) {
            await _writeSiblingArtwork(e, bytes);
          }
        } catch (_) {}
      }
    }
    artworksToExtractLater.clear();
  }

  Future<void> _writeSiblingArtwork(_ExtractInfo info, List<int> bytes) async {
    final serverPath = info.serverPath;
    final tags = info.tags;
    final isVideo = info.name.isVideo();
    final artworkDirectory = isVideo ? AppDirs.THUMBNAILS : AppDirs.ARTWORKS;
    final filename = TagsExtractor.buildImageFilename(
      path: serverPath,
      identifiers: info.identifiersSet,
      isNetwork: true,
      networkId: serverPath,
      infoCallback: () => (
        albumName: tags.album,
        albumArtist: tags.albumArtist,
        year: tags.year,
        mbAlbumId: tags.mbAlbumId,
        mbAlbumArtistId: tags.mbAlbumArtistId,
        title: tags.title,
        artist: tags.artist,
      ),
      hashKeyCallback: () => serverPath.toFastHashKey(),
      parentDirPath: artworkDirectory,
    );
    await FileParts.join(artworkDirectory, filename).writeAsBytes(bytes);
  }

  Future<(FAudioModel, String, File?)?> _fetchFileAndExtractInfo(
    String serverPath,
    String? name,
    _ClientApiWrapper api,
    Set<AlbumIdentifier> identifiersSet,
    Map<String, List<_ExtractInfo>> artworksToExtractLater,
  ) async {
    final extractArtwork = Indexer.inst.isNetworkArtworkCachingEnabled;
    final effectiveName = name ?? serverPath.getFilename;
    final uri = _buildServerUri(serverPath);
    final uriString = uri.toString();
    final model = await NamidaTaggerController.inst.extractMetadata(
      trackPath: uriString,
      isVideo: effectiveName.isVideo(),
      extractArtwork: extractArtwork,
      saveArtworkToCache: true,
      isNetwork: true,
      networkId: serverPath,
      httpHeaders: _serverAuthHeaders,
    );
    if (!model.hasError) {
      if (extractArtwork) {
        final extractInfo = _ExtractInfo(
          serverPath: serverPath,
          name: effectiveName,
          tags: model.tags,
          identifiersSet: identifiersSet,
        );
        final serverPathWOExt = p.basenameWithoutExtension(serverPath);
        artworksToExtractLater[serverPathWOExt] ??= [];
        artworksToExtractLater[serverPathWOExt]!.add(extractInfo);
      }
      return (model, serverPath, null);
    }

    if (await _ffmpegSupportsWebDAV) {
      final ffmpegInfo = await NamidaFFMPEG.inst.ffmpegExtractMetadata(uriString);
      final ffmpegModel = ffmpegInfo?.toFAudioModel(artwork: null);
      if (ffmpegModel != null) {
        return (ffmpegModel, serverPath, null);
      }
    }

    return _fetchFileAnd(
      serverPath,
      name,
      api,
      builder: (tempFile, isVideo, networkId) {
        return NamidaTaggerController.inst.extractMetadata(
          trackPath: tempFile.path,
          isVideo: isVideo,
          extractArtwork: extractArtwork,
          saveArtworkToCache: true,
          isNetwork: true,
          networkId: networkId,
        );
      },
    );
  }

  // Future<(FArtwork?, String, File)?> _fetchFileAndExtractArtwork(
  //   String serverPath,
  //   String? name,
  //   _ClientApiWrapper api,
  // ) async {
  //   return _fetchFileAnd(
  //     serverPath,
  //     name,
  //     api,
  //     builder: (tempFile, isVideo, networkId) {
  //       return NamidaTaggerController.inst.extractArtwork(
  //         trackPath: tempFile.path,
  //         isVideo: isVideo,
  //       );
  //     },
  //   );
  // }

  Future<(T, String, File)?> _fetchFileAnd<T>(
    String serverPath,
    String? name,
    _ClientApiWrapper api, {
    required Future<T> Function(File tempFile, bool isVideo, String networkId) builder,
  }) async {
    name ??= serverPath.getFilename;
    final tempFile = FileParts.join(AppDirs.APP_CACHE, authDetails.dir.type.name, authDetails.auth.username, serverPath.toFastHashKey());
    final networkId = serverPath;
    try {
      await api.read2File(serverPath, tempFile.path);
      final isVideo = name.isVideo() == true;
      final res = await builder(tempFile, isVideo, networkId);
      return (res, networkId, tempFile);
    } catch (_) {
      tempFile.tryDeleting();
      return Future.value(null);
    }
  }
}

extension on DioException {
  bool isUnAuthorized() {
    final err = this;
    if (err.response?.statusCode == 401 || (err.message ?? err.response?.statusMessage)?.contains('Unauthorized') == true) {
      return true;
    }
    return false;
  }
}

class _ClientApiWrapper {
  final webdav.Client api;
  const _ClientApiWrapper(
    this.api,
  );

  Future<T> _executeEnsureAuthorized<T>(Future<T> Function(webdav.Client api) fn) async {
    try {
      return await fn(api);
    } on DioException catch (e) {
      if (e.isUnAuthorized()) {
        await api.ping().ignoreError();
        return await fn(api);
      } else {
        rethrow;
      }
    }
  }

  Future<void> ping() async {
    // -- even ping can fail if not pre authorized
    return await _executeEnsureAuthorized(
      (api) => api.ping(),
    );
  }

  Future<void> read2File(
    String path,
    String savePath, {
    void Function(int count, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    return await _executeEnsureAuthorized(
      (api) => api.read2File(
        path,
        savePath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<List<int>> read(
    String path, {
    void Function(int count, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    return await _executeEnsureAuthorized(
      (api) => api.read(
        path,
        onProgress: onProgress,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<List<webdav.File>> readDir(String path, [CancelToken? cancelToken]) async {
    return await _executeEnsureAuthorized(
      (api) => api.readDir(
        path,
        cancelToken,
      ),
    );
  }

  void close({bool force = true}) {
    api.c.close(force: force);
  }
}

class _ExtractInfo {
  final String serverPath;
  final String name;
  final FTags tags;
  final Set<AlbumIdentifier> identifiersSet;

  const _ExtractInfo({
    required this.serverPath,
    required this.name,
    required this.tags,
    required this.identifiersSet,
  });
}

