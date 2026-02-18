part of 'music_web_server_base.dart';

class _JellyfinServer extends MusicWebServer {
  Uri? _serverUri;
  late _JellyfinClientWrapper _wrapper;

  _JellyfinServer.init(super.authDetails) {
    _serverUri = Uri.parse(authDetails.dir.sourceRaw);
    final jellyfinAuth = authDetails.auth.toJellyfinAuthModel();
    _wrapper = _JellyfinClientWrapper(
      JellyfinDart(basePathOverride: authDetails.dir.sourceRaw),
      jellyfinAuth.username,
      jellyfinAuth.password,
    );
  }

  @override
  void dispose() {
    _wrapper.dispose();
  }

  @override
  Future<MusicWebServerError?> ping() => _wrapper.ping();

  @override
  Future<Uint8List?> getImage(String id) => _wrapper.getImage(id);

  @override
  Future<void> fetchAllMusicAndProcess(void Function(TrackExtended trExt) callback) async {
    final wrapper = _wrapper;

    final server = authDetails.dir.toDbKey();
    final serverUriParsed = Uri.parse(server);
    final artistsSplitConfig = ArtistsSplitConfig.settings();
    final genresSplitConfig = GenresSplitConfig.settings();

    final stream = wrapper.fetchAllMedia(
      batchSize: 400,
      checkResError: (res) => _checkResError(authDetails.dir, res),
    );
    await for (final item in stream) {
      callback(
        _baseItemDtoToTrackExtended(
          item,
          artistsSplitConfig: artistsSplitConfig,
          genresSplitConfig: genresSplitConfig,
          server: server,
          serverUriParsed: serverUriParsed,
        ),
      );
    }
  }

  @override
  Future<WebStreamUriDetails?> getStreamUrl(String id, {void Function(File cachedFile)? onFetchedIfLocal}) async {
    final baseUri = _serverUri;
    if (baseUri == null) return null;

    await _wrapper.ensureAuthenticated();

    final uri = Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.port,
      userInfo: baseUri.userInfo,
      path: '/Audio/$id/stream',
      queryParameters: {
        'UserId': ?_wrapper._userId,
        'api_key': ?_wrapper._token,
        'static': 'true',
      },
    );
    return WebStreamUriDetails.fromUri(uri);
  }

  bool _checkResError(DirectoryIndex dir, Response<dynamic>? res) {
    final statusCode = res?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      if (dir is DirectoryIndexServer) {
        MusicWebServerAuthDetails.manager.deleteFromDb(dir);
      }
      return true;
    }
    return false;
  }

  Iterable<String> _splitAll(List<String>? original, List<String> Function(String part) splitter) sync* {
    for (final item in original ?? <String>[]) {
      final parts = splitter(item);
      yield* parts;
    }
  }

  TrackExtended _baseItemDtoToTrackExtended(
    BaseItemDto item, {
    required ArtistsSplitConfig artistsSplitConfig,
    required GenresSplitConfig genresSplitConfig,
    required String server,
    required Uri serverUriParsed,
  }) {
    final id = item.id ?? '';

    final newUri = serverUriParsed.replace(
      queryParameters: {
        ...serverUriParsed.queryParameters,
        'd': id,
      },
    );
    final path = newUri.toString();

    final title = item.name ?? '';
    final album = item.album ?? '';
    final albumArtist = item.albumArtist ?? '';

    final originalArtist = item.artists?.join(', ') ?? '';
    final artistsList = _splitAll(
      item.artists,
      (p) => Indexer.splitArtist(
        title: title,
        originalArtist: p,
        config: artistsSplitConfig,
      ),
    ).toList();

    final originalGenre = item.genres?.join(', ') ?? '';
    final genresList = _splitAll(
      item.genres,
      (p) => Indexer.splitGenre(
        p,
        config: genresSplitConfig,
      ),
    ).toList();

    final year = item.productionYear ?? 0;
    final yearString = year != 0 ? year.toString() : '';

    final durationMs = item.runTimeTicks != null ? (item.runTimeTicks! ~/ 10000) : 0;
    final mediaSource = item.mediaSources?.firstOrNull;
    final bitrate = (mediaSource?.bitrate ?? 0) ~/ 1000;
    final size = mediaSource?.size ?? 0;
    final format = item.container ?? '';
    final dateAddedMs = item.dateCreated?.millisecondsSinceEpoch ?? 0;
    final rating = (item.userData?.rating ?? 0);

    final isVideo = item.videoType != null;

    return TrackExtended(
      title: title,
      originalArtist: originalArtist,
      artistsList: artistsList,
      album: album,
      albumArtist: albumArtist,
      originalGenre: originalGenre,
      genresList: genresList,
      originalMood: '',
      moodList: [],
      composer: '',
      trackNo: item.indexNumber ?? 0,
      durationMS: durationMs,
      year: year,
      yearText: yearString,
      size: size,
      dateAdded: dateAddedMs,
      dateModified: dateAddedMs,
      path: path,
      comment: '',
      description: '',
      synopsis: '',
      bitrate: bitrate,
      sampleRate: 0,
      bits: 0,
      isLossless: null,
      format: format,
      channels: '',
      discNo: item.parentIndexNumber ?? 0,
      language: '',
      lyrics: '',
      label: '',
      rating: rating,
      originalTags: null,
      tagsList: [],
      gainData: null,
      hashKey: id,
      isVideo: isVideo,
      server: server,
      albumIdentifierWrapper: AlbumIdentifierWrapper.normalize(
        album: album,
        albumArtist: albumArtist,
        year: yearString,
      ),
    );
  }
}

class JellyfinAuth {
  final String username;
  final String password;

  const JellyfinAuth({
    required this.username,
    required this.password,
  });
}

class _JellyfinClientWrapper {
  final JellyfinDart _client;
  final String _username;
  final String _password;

  _JellyfinClientWrapper(
    this._client,
    this._username,
    this._password,
  );

  String? _userId;
  String? _token;
  Completer<bool>? _authCompleter;

  Future<bool> ensureAuthenticated() async {
    if (_token != null && _userId != null) return true;

    if (_authCompleter != null) return _authCompleter!.future;

    _authCompleter = Completer<bool>();
    try {
      final deviceId = await NamidaDeviceInfo.fetchDeviceId() ?? 'namida';
      final version = VersionWrapper.current?.name ?? '1.0.0';

      _client.setMediaBrowserAuth(
        deviceId: deviceId,
        version: version,
      );
      final authResponse = await _client.getUserApi().authenticateUserByName(
        authenticateUserByName: AuthenticateUserByName(
          username: _username,
          pw: _password,
        ),
      );
      final data = authResponse.data;
      if (data == null) {
        _authCompleter!.complete(false);
        _authCompleter = null;
        return false;
      }

      _token = data.accessToken;
      _userId = data.user?.id;
      if (_token != null) _client.setToken(_token!);

      final success = _token != null && _userId != null;
      _authCompleter!.complete(success);
      return success;
    } on DioException catch (_) {
      _authCompleter!.complete(false);
      return false;
    } finally {
      _authCompleter = null;
    }
  }

  Future<MusicWebServerError?> ping() async {
    if (!await ensureAuthenticated()) {
      return MusicWebServerError(
        code: 0,
        message: 'Jellyfin authentication failed',
      );
    }
    try {
      await _client.getSystemApi().getSystemInfo();
      return null;
    } on DioException catch (e) {
      return MusicWebServerError(
        code: e.response?.statusCode ?? -1,
        message: e.message ?? 'Unknown error',
      );
    }
  }

  Future<Uint8List?> getImage(String id) async {
    if (!await ensureAuthenticated()) return null;
    try {
      final res = await _client.getImageApi().getItemImage(
        itemId: id,
        imageType: ImageType.primary,
      );
      final data = res.data;
      if (data is Uint8List) return data;
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  Stream<BaseItemDto> fetchAllMedia({int batchSize = 400, required bool Function(Response<dynamic>? res) checkResError}) async* {
    final itemsApi = _client.getItemsApi();
    int offset = 0;

    while (true) {
      try {
        final res = await itemsApi.getItems(
          userId: _userId,
          includeItemTypes: [.audio, .video, .musicVideo],
          recursive: true,
          startIndex: offset,
          limit: batchSize,
          fields: [
            ItemFields.mediaStreams,
            ItemFields.mediaSources,
            ItemFields.genres,
            ItemFields.dateCreated,
            ItemFields.overview,
            ItemFields.path,
            ItemFields.tags,
          ],
        );

        if (checkResError(res)) {
          break;
        }

        final items = res.data?.items ?? [];
        for (final item in items) {
          yield item;
        }

        if (items.length < batchSize) break;
        offset += batchSize;
      } on DioException catch (e) {
        if (checkResError(e.response)) {
          break;
        }
      }
    }
  }

  void dispose() {
    _client.dio.close(force: true);
  }
}
