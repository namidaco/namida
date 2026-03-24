// ignore_for_file: public_member_api_docs, sort_constructors_first
part of 'music_web_server_base.dart';

class _WebDAVServer extends MusicWebServer {
  _ClientApiWrapper? _api;
  late Uri _serverUri;
  late WebDAVAuth _authInfo;
  Uri _buildServerUri(String serverPath) {
    final basePath = _serverUri.path.endsWith('/') ? _serverUri.path : '${_serverUri.path}/';
    final trimmed = serverPath.startsWith('/') ? serverPath.substring(1) : serverPath;
    return _serverUri.replace(
      userInfo: '${_authInfo.username}:${_authInfo.password}',
      path: '$basePath$trimmed',
    );
  }

  // -- it's safe to assume that webdav(http) is supported for all platforms, however it's kept
  // -- in case the system one was picked and didn't support it.
  late final Future<bool> _ffmpegSupportsWebDAV = NamidaFFMPEG.inst.supportsWebDAV();

  _WebDAVServer.init(super.authDetails) {
    _authInfo = authDetails.auth.toWebDAVAuthModel();
    _api = _ClientApiWrapper(
      webdav.newClient(
        authDetails.dir.sourceRaw,
        user: _authInfo.username,
        password: _authInfo.password,
      ),
    );

    _serverUri = Uri.parse(authDetails.dir.sourceRaw);
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
    final File? tempFile = await TagsExtractor.extractThumbnailCustom(
      trackPath: uriString,
      filename: null,
      artworkDirectory: null,
      isVideo: isVideo,
    );

    final bytes = await tempFile?.readAsBytes();
    tempFile?.tryDeleting();

    return bytes;
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
  Future<void> fetchAllMusicAndProcess(void Function(TrackExtended trExt) callback) async {
    final api = _api;
    if (api == null) return;

    final server = authDetails.dir.toDbKey();
    final serverUriParsed = Uri.parse(server);
    final splittersConfigs = SplitArtistGenreConfigsWrapper.settings();
    final identifiersSet = TagsExtractor.getAlbumIdentifiersSet();
    final minDur = settings.indexMinDurationInSec.value;
    final minSize = settings.indexMinFileSizeInB.value;

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
      );

      await for (final tr in stream) {
        callback(tr);
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
  }) async* {
    final imageFiles = <webdav.File>[];
    final artworksToExtractLater = <String, List<_ExtractInfo>>{};
    const subBatchSize = 20;
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
            }
            if (NamidaFileExtensionsWrapper.image.isPathValid(path)) {
              imageFiles.add(file);
            }
          }
        }
      }

      if (subfiles.isNotEmpty) {
        final futures = subfiles.map((file) async {
          final serverPath = file.path;
          if (serverPath == null) return null;
          final res = await _fetchFileAndExtractInfo(serverPath, file.name, api, identifiersSet, artworksToExtractLater);
          if (res == null) return null;
          final trExt = await Indexer.convertServerTagToTrack(
            path: serverPath,
            trackInfo: res.$1,
            stats: FileStatsAdv(
              creationDate: file.cTime,
              modified: file.mTime,
              size: file.size,
            ),
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
            return trExt.copyWith(generatePathHash: true, path: newPath);
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
        final p = dir.path;
        if (p != null) {
          final subfiles = await api.readDir(p);
          yield* _fetchSongsForFilesBatch(
            api: api,
            server: server,
            serverUriParsed: serverUriParsed,
            files: subfiles,
            splittersConfigs: splittersConfigs,
            identifiersSet: identifiersSet,
            minDur: minDur,
            minSize: minSize,
          );
        }
      }
    }

    // -- prefer already existing images
    for (final img in imageFiles) {
      final imgPath = img.path;
      if (imgPath != null) {
        final bytes = await _api?.read(imgPath);
        final serverPathWOExt = p.basenameWithoutExtension(imgPath);
        final artworksToExtract = artworksToExtractLater[serverPathWOExt];
        if (artworksToExtract != null) {
          for (final e in artworksToExtract) {
            await _writeOrExtractArtwork(e, bytes);
          }
          artworksToExtractLater.remove(serverPathWOExt);
        }
      }
    }

    // -- extract remaining that had no cover.png
    for (final artworksToExtract in artworksToExtractLater.values) {
      for (final e in artworksToExtract) {
        await _writeOrExtractArtwork(e, null);
      }
    }
    artworksToExtractLater.clear();
  }

  Future<void> _writeOrExtractArtwork(_ExtractInfo info, List<int>? bytes) async {
    final serverPath = info.serverPath;
    final ffmpegInfo = info.ffmpegInfo;
    final name = serverPath.getFilename;
    final isVideo = name.isVideo();
    final filename = TagsExtractor.buildImageFilename(
      path: serverPath,
      identifiers: info.identifiersSet,
      isNetwork: true,
      networkId: serverPath,
      infoCallback: () => (
        albumName: ffmpegInfo?.format?.tags?.album,
        albumArtist: ffmpegInfo?.format?.tags?.albumArtist,
        year: ffmpegInfo?.format?.tags?.date,
        title: ffmpegInfo?.format?.tags?.title,
        artist: ffmpegInfo?.format?.tags?.artist,
      ),
      hashKeyCallback: () => serverPath.toFastHashKey(),
    );

    final artworkDirectory = isVideo ? AppDirs.THUMBNAILS : AppDirs.ARTWORKS;
    if (bytes != null && bytes.isNotEmpty) {
      await FileParts.join(artworkDirectory, filename).writeAsBytes(bytes);
    } else {
      await TagsExtractor.extractThumbnailCustom(
        trackPath: info.uriString,
        filename: filename,
        artworkDirectory: artworkDirectory,
        isVideo: isVideo,
      );
    }
  }

  Future<(FAudioModel, String, File?)?> _fetchFileAndExtractInfo(
    String serverPath,
    String? name,
    _ClientApiWrapper api,
    Set<AlbumIdentifier> identifiersSet,
    Map<String, List<_ExtractInfo>> artworksToExtractLater,
  ) async {
    final extractArtwork = Indexer.inst.isNetworkArtworkCachingEnabled;
    if (await _ffmpegSupportsWebDAV) {
      final uri = _buildServerUri(serverPath);
      final uriString = uri.toString();
      final ffmpegInfo = await NamidaFFMPEG.inst.ffmpegExtractMetadata(uriString);

      if (extractArtwork) {
        name ??= serverPath.getFilename;
        final extractInfo = _ExtractInfo(
          serverPath: serverPath,
          uriString: uriString,
          name: name,
          ffmpegInfo: ffmpegInfo,
          identifiersSet: identifiersSet,
        );
        final serverPathWOExt = p.basenameWithoutExtension(serverPath);
        artworksToExtractLater[serverPathWOExt] ??= [];
        artworksToExtractLater[serverPathWOExt]!.add(extractInfo);
      }

      final model = ffmpegInfo?.toFAudioModel(artwork: null);
      if (model != null) {
        return (model, serverPath, null);
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

class WebDAVAuth {
  final String username;
  final String password;

  const WebDAVAuth({
    required this.username,
    required this.password,
  });
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
  final String uriString;
  final String name;
  final MediaInfo? ffmpegInfo;
  final Set<AlbumIdentifier> identifiersSet;

  const _ExtractInfo({
    required this.serverPath,
    required this.uriString,
    required this.name,
    required this.ffmpegInfo,
    required this.identifiersSet,
  });
}
