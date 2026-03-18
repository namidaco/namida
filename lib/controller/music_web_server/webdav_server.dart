// ignore_for_file: public_member_api_docs, sort_constructors_first
part of 'music_web_server_base.dart';

class _WebDAVServer extends MusicWebServer {
  _ClientApiWrapper? _api;
  late Uri _serverUri;
  late WebDAVAuth _authInfo;

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

    final serverPath = Uri.decodeQueryComponent(id);
    final tempFile = FileParts.joinAll([
      AppDirs.APP_CACHE,
      authDetails.dir.type.name,
      authDetails.auth.username,
      ...serverPath.split('/'),
    ]);

    await api.read2File(serverPath, tempFile.path);

    onFetchedIfLocal?.call(tempFile);

    final newUri = Uri.file(tempFile.path);

    return WebStreamUriDetails.fromUri(
      newUri,
      allowStreamCaching: false, // already cached
    );
  }

  @override
  Future<Uint8List?> getImage(String id) async {
    final api = _api;
    if (api == null) return null;

    final serverPath = Uri.decodeQueryComponent(id);

    final res = await _fetchFileAndExtractArtwork(
      serverPath,
      null,
      api,
    );
    if (res == null) return null;

    final bytes = res.$1?.bytes;

    res.$3.tryDeleting();

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
          if (path != null && NamidaFileExtensionsWrapper.audioAndVideo.isPathValid(path)) {
            subfiles.add(file);
          }
        }
      }

      if (subfiles.isNotEmpty) {
        final futures = subfiles.map((file) async {
          final serverPath = file.path;
          if (serverPath == null) return null;
          final res = await _fetchFileAndExtractInfo(serverPath, file.name, api, identifiersSet);
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
  }

  Future<(FAudioModel, String, File?)?> _fetchFileAndExtractInfo(String serverPath, String? name, _ClientApiWrapper api, Set<AlbumIdentifier> identifiersSet) async {
    final extractArtwork = Indexer.inst.isNetworkArtworkCachingEnabled;
    if (await _ffmpegSupportsWebDAV) {
      final uri = _serverUri.replace(
        userInfo: '${_authInfo.username}:${_authInfo.password}',
        path: serverPath,
      );
      final uriString = uri.toString();
      final ffmpegInfo = await NamidaFFMPEG.inst.ffmpegExtractMetadata(uriString);
      File? artworkFile;
      if (extractArtwork) {
        final isVideo = name?.isVideo() == true;
        final filename = TagsExtractor.buildImageFilename(
          path: serverPath,
          identifiers: identifiersSet,
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
        artworkFile = await TagsExtractor.extractThumbnailCustom(
          trackPath: uriString,
          filename: filename,
          artworkDirectory: isVideo ? AppDirs.THUMBNAILS : AppDirs.ARTWORKS,
          isVideo: isVideo,
        );
      }

      final model = ffmpegInfo?.toFAudioModel(
        artwork: FArtwork(file: artworkFile),
      );
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

  Future<(FArtwork?, String, File)?> _fetchFileAndExtractArtwork(
    String serverPath,
    String? name,
    _ClientApiWrapper api,
  ) async {
    return _fetchFileAnd(
      serverPath,
      name,
      api,
      builder: (tempFile, isVideo, networkId) {
        return NamidaTaggerController.inst.extractArtwork(
          trackPath: tempFile.path,
          isVideo: isVideo,
        );
      },
    );
  }

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
