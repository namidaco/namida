// ignore_for_file: avoid_print, public_member_api_docs, sort_constructors_first
part of 'music_web_server_base.dart';

class _SMBServer extends MusicWebServer {
  Completer<SmbConnect?>? _connectionCompleter;
  SMBServerInfo? _serverUriInfo;

  late final _smbAuthInfo = authDetails.auth.toSMBAuthModel();

  _SMBServer.init(super.authDetails) {
    _initializeConnection();
  }

  Configuration _configBuilder(
    Credentials creds,
    String username,
    String password,
    String domain,
  ) {
    return BaseConfiguration(
      credentials: creds,
      username: username,
      password: password,
      domain: domain,
      port: _serverUriInfo?.port,
      forceSmb1: false,
      minimumVersion: DialectVersion.SMB1,
      maximumVersion: DialectVersion.SMB302, // 3.1 requires preauth hash
      bufferCacheSize: 0x1FFF * 20,
      sendBufferSize: 0xFFFF * 20,
      receiveBufferSize: 0xFFFF * 30,
      transactionBufferSize: 0xFFFF * 30,
      maximumBufferSize: 0x10000 * 30,
      isUseBatching: true,
    );
  }

  void _initializeConnection() {
    _serverUriInfo = SMBServerInfo.fromUrl(authDetails.dir.sourceRaw);
  }

  Future<SmbConnect> _getConnection() async {
    if (_connectionCompleter != null) {
      final res = await _connectionCompleter!.future;
      if (res != null) {
        return res;
      }
    }

    _connectionCompleter = Completer<SmbConnect?>();

    try {
      final host = _serverUriInfo?.host;
      if (host == null || host.isEmpty) {
        throw Exception('SMB host is empty');
      }

      final authInfo = _smbAuthInfo;

      final connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: authInfo.username,
        password: authInfo.password,
        configBuilder: _configBuilder,
      );

      _connectionCompleter!.complete(connection);

      return connection;
    } catch (e) {
      _connectionCompleter!.complete(null);
      _connectionCompleter = null;
      rethrow;
    }
  }

  @override
  void dispose() async {
    (await _connectionCompleter?.future)?.close();
    _connectionCompleter = null;
  }

  @override
  Future<WebStreamUriDetails?> getStreamUrl(String id, {void Function(File cachedFile)? onFetchedIfLocal}) async {
    try {
      final serverPath = Uri.decodeQueryComponent(id);

      final tempFile = FileParts.joinAll([
        AppDirs.APP_CACHE,
        authDetails.dir.type.name,
        authDetails.auth.username,
        ...serverPath.split('/'),
      ]);

      await _downloadFileToCache(serverPath, tempFile);

      onFetchedIfLocal?.call(tempFile);

      final newUri = Uri.file(tempFile.path);

      return WebStreamUriDetails.fromUri(
        newUri,
        allowStreamCaching: false, // already cached
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Uint8List?> getImage(String id) async {
    try {
      final serverPath = Uri.decodeQueryComponent(id);

      final res = await _fetchFileAndExtractArtwork(
        serverPath,
        null,
      );
      if (res == null) return null;

      final bytes = res.$1?.bytes;

      res.$3.tryDeleting();

      return bytes;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<MusicWebServerError?> ping() async {
    try {
      await _getConnection(); // cuz pingConnection can return true even if connection would get rejected later

      final host = _serverUriInfo?.host;
      if (host == null || host.isEmpty) {
        return MusicWebServerError(code: 0, message: 'Host is empty');
      }

      final authInfo = _smbAuthInfo;

      final result = await SmbConnect.pingConnection(
        host: host,
        username: authInfo.username,
        password: authInfo.password,
        domain: '',
        configBuilder: _configBuilder,
      );

      return result ? null : MusicWebServerError(code: 0, message: 'Connection failed');
    } catch (e) {
      return MusicWebServerError(code: 0, message: e.toString());
    }
  }

  @override
  Future<Set<String>?> getAvailableShares() async {
    try {
      final connection = await _getConnection();
      final shares = await connection.listShares();
      // -- move shared with $ to the end
      final invalidShares = <SmbFile>[];
      shares.removeWhere(
        (m) {
          if (m.name.contains(r'$')) {
            invalidShares.add(m);
            return true;
          }
          return false;
        },
      );
      shares.addAll(invalidShares);
      return shares.map((e) => e.name).toSet();
    } catch (_) {}
    return null;
  }

  @override
  Future<void> fetchAllMusicAndProcess(void Function(TrackExtended trExt) callback) async {
    try {
      final connection = await _getConnection();
      final server = authDetails.dir.toDbKey();
      final serverUriParsed = Uri.parse(server);
      final splittersConfigs = SplitArtistGenreConfigsWrapper.settings();
      final minDur = settings.indexMinDurationInSec.value;
      final minSize = settings.indexMinFileSizeInB.value;

      final basePath = _serverUriInfo?.basePath ?? '/';

      final baseFolder = await connection.file(basePath);
      final networkFiles = await connection.listFiles(baseFolder);

      final stream = _fetchSongsForFilesBatch(
        connection: connection,
        server: server,
        serverUriParsed: serverUriParsed,
        files: networkFiles,
        splittersConfigs: splittersConfigs,
        minDur: minDur,
        minSize: minSize,
      );

      await for (final tr in stream) {
        callback(tr);
      }
    } catch (e) {
      _onResError(authDetails.dir, e);
    }
  }

  void _onResError(DirectoryIndex dir, dynamic err) {
    if (err is SmbAuthException || err.toString().contains('unauthorized') || err.toString().contains('access denied')) {
      if (dir is DirectoryIndexServer) {
        MusicWebServerAuthDetails.manager.deleteFromDb(dir);
      }
    }
  }

  Stream<TrackExtended> _fetchSongsForFilesBatch({
    required SmbConnect connection,
    required String server,
    required Uri serverUriParsed,
    required List<SmbFile> files,
    required SplitArtistGenreConfigsWrapper splittersConfigs,
    required int minDur,
    required int minSize,
  }) async* {
    const subBatchSize = 10;
    for (var i = 0; i < files.length; i += subBatchSize) {
      final batch = files.skip(i).take(subBatchSize);
      final subfiles = <SmbFile>[];
      final subdirectories = <SmbFile>[];

      for (final file in batch) {
        if (file.isDirectory()) {
          subdirectories.add(file);
        } else {
          final path = file.path;
          if (NamidaFileExtensionsWrapper.audioAndVideo.isPathValid(path)) {
            subfiles.add(file);
          }
        }
      }

      if (subfiles.isNotEmpty) {
        final futures = subfiles.map((file) async {
          final serverPath = file.path;
          final res = await _fetchFileAndExtractInfo(serverPath, file.name);
          if (res == null) return null;

          final trExt = await Indexer.convertTagToTrack(
            trackPath: res.$1.tags.path,
            trackInfo: res.$1,
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

          res.$3.tryDeleting();

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
        try {
          final subfiles = await connection.listFiles(dir);
          yield* _fetchSongsForFilesBatch(
            connection: connection,
            server: server,
            serverUriParsed: serverUriParsed,
            files: subfiles,
            splittersConfigs: splittersConfigs,
            minDur: minDur,
            minSize: minSize,
          );
        } catch (_) {
          continue;
        }
      }
    }
  }

  Future<(FAudioModel, String, File)?> _fetchFileAndExtractInfo(
    String serverPath,
    String? name, {
    bool? extractArtwork,
    bool? saveArtworkToCache,
  }) async {
    return _fetchFileAnd(
      serverPath,
      name,
      builder: (tempFile, isVideo, networkId) {
        return NamidaTaggerController.inst.extractMetadata(
          trackPath: tempFile.path,
          isVideo: isVideo,
          extractArtwork: extractArtwork ?? Indexer.inst.isNetworkArtworkCachingEnabled,
          saveArtworkToCache: saveArtworkToCache ?? Indexer.inst.isNetworkArtworkCachingEnabled,
          isNetwork: true,
          networkId: networkId,
        );
      },
    );
  }

  Future<(FArtwork?, String, File)?> _fetchFileAndExtractArtwork(
    String serverPath,
    String? name,
  ) async {
    return _fetchFileAnd(
      serverPath,
      name,
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
    String? name, {
    required Future<T> Function(File tempFile, bool isVideo, String networkId) builder,
  }) async {
    name ??= serverPath.getFilename;
    final tempFile = FileParts.join(
      AppDirs.APP_CACHE,
      authDetails.dir.type.name,
      authDetails.auth.username,
      serverPath.toFastHashKey(),
    );
    final networkId = serverPath;

    try {
      await _downloadFileToCache(serverPath, tempFile);
      final isVideo = name.isVideo() == true;
      final res = await builder(tempFile, isVideo, networkId);
      return (res, networkId, tempFile);
    } catch (e) {
      tempFile.tryDeleting();
      return null;
    }
  }

  Future<void> _downloadFileToCache(String serverPath, File toFile) async {
    final connection = await _getConnection();

    await toFile.create(recursive: true);

    RandomAccessFile? raf;
    try {
      final smbFile = await connection.file(serverPath);
      final fileSize = smbFile.size;

      raf = await connection.open(smbFile);
      final bytes = await raf.read(fileSize);

      await toFile.writeAsBytes(bytes);
    } catch (e, st) {
      if (kDebugMode) {
        printy('_SMBServer._downloadFileToCache error: $e\n$st', isError: true);
      }
      rethrow;
    } finally {
      unawaited(raf?.close());
    }
  }
}

class SMBAuth {
  final String username;
  final String password;

  const SMBAuth({
    required this.username,
    required this.password,
  });
}

class SMBServerInfo {
  final String host;
  final String? share;
  final String? subdir;
  final String? basePath;
  final int? port;

  const SMBServerInfo({
    required this.host,
    required this.share,
    required this.subdir,
    required this.basePath,
    required this.port,
  });

  static String _normalizePathSegment(String? segment) {
    String normalized = (segment ?? '').trim();
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  factory SMBServerInfo.fromUrl(String url) {
    final uri = Uri.parse(url);
    final share = uri.queryParameters['_share'];
    final subdir = uri.queryParameters['_subdir'];
    final port = int.tryParse(uri.queryParameters['_p'] ?? '');

    final normalizedShare = _normalizePathSegment(share);
    final normalizedSubdir = _normalizePathSegment(subdir);

    final segments = [
      normalizedShare,
      normalizedSubdir,
    ].where((s) => s.isNotEmpty).toList();

    final basePath = segments.isEmpty ? '/' : '/${segments.join('/')}';

    return SMBServerInfo(
      host: uri.host,
      share: share,
      subdir: subdir,
      basePath: basePath,
      port: port,
    );
  }

  @override
  String toString() {
    return 'SMBServerInfo(host: $host, share: $share, subdir: $subdir, basePath: $basePath, port: $port)';
  }
}
