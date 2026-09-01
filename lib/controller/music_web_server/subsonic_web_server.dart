part of 'music_web_server_base.dart';

class _SubsonicWebServer extends MusicWebServer {
  SubsonicApi? _api;
  Uri? _serverUri;
  Dio? _client;

  _SubsonicWebServer.init(super.authDetails) {
    _api = SubsonicApi(
      onCreateDio: (baseUrl, version, apiId) {
        return _client = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            queryParameters: {
              'v': version,
              'c': apiId,
            },
          ),
        );
      },
      baseUrl: authDetails.dir.sourceRaw,
      clientId: 'com.msob7y.namida',
      version: VersionWrapper.current?.name ?? '1.0.0',
      auth: authDetails.auth.toSubsonicAuthModel(),
    );
    _serverUri = Uri.parse(authDetails.dir.sourceRaw);
  }

  @override
  void dispose() {
    _client?.close(force: true);
  }

  @override
  WebStreamUriDetails? getStreamUrl(String id, {void Function(File cachedFile)? onFetchedIfLocal}) {
    final api = _api;
    if (api == null) return null;
    final baseUri = _serverUri;
    if (baseUri == null) return null;

    final uri = baseUri.buildEndpointUri(
      '/rest/stream',
      {
        'v': api.version,
        'c': api.clientId,
        'id': id,
        ...authDetails.auth.toUrlParams(),
      },
    );
    return WebStreamUriDetails.fromUri(uri);
  }

  static final _cachedArtworksForAlbumIds = <String, Completer<Uint8List>>{};

  @override
  Future<Uint8List?> getImage(String id) async {
    final baseUri = _serverUri;
    if (baseUri == null) return null;
    final api = _api;
    if (api == null) return null;

    final res = await api.api.getCoverArt(id);
    final data = res.response.data;
    int? possibleErrorCode;
    if (data is Uint8List) {
      possibleErrorCode = _checkIfBytesActuallyJsonErrorReturnCode(data);
      if (possibleErrorCode == null) return data;
    }

    if (possibleErrorCode == 70) {
      // -- track has no cover. fetch info to get album id then fetch its artwork

      final songRes = await api.api.getSong(id);
      final media = songRes.response.data;
      if (media != null) {
        final coverId = media.coverArt ?? media.albumId;

        if (coverId != null) {
          final cachedArtworkC = _cachedArtworksForAlbumIds[coverId];
          if (cachedArtworkC != null) return cachedArtworkC.future;

          _cachedArtworksForAlbumIds[coverId] = Completer<Uint8List>();

          final fallbackRes = await api.api.getCoverArt(coverId);
          final data = fallbackRes.response.data;
          if (data is Uint8List) {
            final possibleErrorCode = _checkIfBytesActuallyJsonErrorReturnCode(data);
            if (possibleErrorCode == null) {
              _cachedArtworksForAlbumIds[coverId]?.completeIfWasnt(data);
              return data;
            }
          }
        }
      }
    }

    // if (data is Map) {
    //   // -- is error
    //   return null;
    // }

    return null;
  }

  int? _checkIfBytesActuallyJsonErrorReturnCode(Uint8List bytes) {
    final errorMap = _checkIfBytesActuallyJsonError(bytes);
    try {
      final error = errorMap!['subsonic-response']!['error'];
      final code = error!['code'] as int;
      return code;
    } catch (_) {}
    return null;
  }

  Map? _checkIfBytesActuallyJsonError(Uint8List bytes) {
    // -- check if starts with {
    // -- application/json in headers is not guranteed
    if (bytes.isNotEmpty && bytes[0] == 123) {
      try {
        final errorMap = jsonDecode(String.fromCharCodes(bytes)) as Map;
        return errorMap;
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<MusicWebServerError?> ping() async {
    final res = await _api?.api.ping();
    if (res == null) return null;
    final err = res.response.error;
    if (err != null) {
      return MusicWebServerError(code: err.code, message: err.message);
    }
    return null;
  }

  @override
  Future<void> fetchAllMusicAndProcess(Map<String, int> serverTracksInLibrary, void Function(TrackExtended trExt) callback, {required bool forceReIndex}) async {
    final api = _api;
    if (api == null) return;

    final server = authDetails.dir.toDbKey();
    final serverUriParsed = Uri.parse(server);

    final splitConfig = SplitArtistGenreConfigsWrapper.settings();

    const batchSize = 400;
    int offset = 0;
    bool hasMore = true;
    while (hasMore) {
      final albumsRes = await api.api.getAlbumList('newest', size: batchSize, offset: offset);
      if (_checkResError(authDetails.dir, albumsRes)) {
        break;
      }
      final albums = albumsRes.response.data?.albums ?? [];

      if (albums.isEmpty) {
        hasMore = false;
        break;
      }

      final stream = _fetchSongsForAlbumsBatch(
        api: api,
        server: server,
        serverUriParsed: serverUriParsed,
        albums: albums,
        splitConfig: splitConfig,
      );

      await for (final trExt in stream) {
        callback(trExt);
      }

      offset += batchSize;

      if (albums.length < batchSize) {
        hasMore = false;
        break;
      }
    }
  }

  @override
  Future<List<WebServerPlaylist>?> fetchPlaylists({required int? Function(String remoteId) knownChangedMS}) async {
    final api = _api;
    if (api == null) return null;

    final server = authDetails.dir.toDbKey();
    final serverUriParsed = Uri.parse(server);

    final splitConfig = SplitArtistGenreConfigsWrapper.settings();

    try {
      final res = await api.api.getPlaylists();
      if (res.response.error != null) {
        _checkResError(authDetails.dir, res);
        return null;
      }

      final playlists = res.response.data?.playlists ?? [];
      final result = <WebServerPlaylist>[];
      for (final pl in playlists) {
        final createdMS = pl.created?.millisecondsSinceEpoch;
        final changedMS = pl.changed?.millisecondsSinceEpoch ?? createdMS;

        Iterable<TrackExtended>? tracks;
        final known = knownChangedMS(pl.id);
        if (known == null || changedMS == null || known != changedMS) {
          final detail = await api.api.getPlaylist(pl.id);
          if (detail.response.error != null) {
            _checkResError(authDetails.dir, detail);
          } else {
            final songs = detail.response.data?.songs ?? [];
            tracks = songs.map(
              (s) => _mediaModelToTrackExtended(
                s,
                splitConfig: splitConfig,
                server: server,
                serverUriParsed: serverUriParsed,
              ),
            );
          }
        }

        result.add(
          WebServerPlaylist(
            id: pl.id,
            name: pl.name,
            comment: pl.comment,
            createdMS: createdMS,
            changedMS: changedMS,
            coverArtId: pl.coverArt,
            tracks: tracks,
          ),
        );
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  bool _checkResError(DirectoryIndex dir, SubsonicResponse res) {
    final err = res.response.error;
    if (err != null) {
      if (err.code == SubsonicErrorModel.wrongUsernameOrPassword || err.code == SubsonicErrorModel.userNotAuthorized) {
        if (dir is DirectoryIndexServer) MusicWebServerAuthDetails.manager.deleteFromDb(dir);
        return true;
      }
    }
    return false;
  }

  Stream<TrackExtended> _fetchSongsForAlbumsBatch({
    required SubsonicApi api,
    required String server,
    required Uri serverUriParsed,
    required List<AlbumModel> albums,
    required SplitArtistGenreConfigsWrapper splitConfig,
  }) async* {
    const subBatchSize = 10;
    for (var i = 0; i < albums.length; i += subBatchSize) {
      final batch = albums.skip(i).take(subBatchSize);
      final futures = batch.map((album) => api.api.getAlbum(album.id));
      final results = await Future.wait(futures);

      for (final albumDetail in results) {
        final songs = albumDetail.response.data?.song ?? [];
        for (final s in songs) {
          yield _mediaModelToTrackExtended(
            s,
            splitConfig: splitConfig,
            server: server,
            serverUriParsed: serverUriParsed,
          );
        }
      }
    }
  }

  TrackExtended _mediaModelToTrackExtended(
    MediaModel media, {
    required SplitArtistGenreConfigsWrapper splitConfig,
    required String server,
    required Uri serverUriParsed,
  }) {
    // -- dont use id cuz yt id matcher would catch it
    final newUri = serverUriParsed.replace(
      queryParameters: {
        ...serverUriParsed.queryParameters,
        'd': media.id,
      },
    );
    final path = newUri.toString();
    final title = media.title;
    final artist = media.artist;
    final genre = media.genre;
    final album = media.album ?? '';
    final albums = Indexer.splitAlbum(
      album,
      config: splitConfig.albumConfig,
    );
    const albumArtist = ''; // not there
    final year = media.year;
    final yearString = year?.toString() ?? '';
    final artists = artist == null
        ? <String>[]
        : Indexer.splitArtist(
            title: title,
            originalArtist: artist,
            config: splitConfig.artistsConfig,
          );
    final genres = genre == null
        ? <String>[]
        : Indexer.splitGenre(
            genre,
            config: splitConfig.genresConfig,
          );
    return TrackExtended(
      title: media.title,
      originalArtist: media.artist ?? '',
      artistsList: artists,
      originalAlbum: album,
      albumsList: albums,
      albumArtist: albumArtist,
      originalGenre: media.genre ?? '',
      genresList: genres,
      originalStyle: '',
      stylesList: const [],
      originalMood: '',
      moodList: [],
      composer: '',
      trackNo: media.track ?? 0,
      trackTo: 0,
      durationMS: media.duration?.inMilliseconds ?? 0,
      year: year ?? 0,
      yearText: yearString,
      size: media.size ?? 0,
      dateAdded: media.created?.millisecondsSinceEpoch ?? 0,
      dateModified: media.created?.millisecondsSinceEpoch ?? 0,
      path: path,
      comment: '',
      description: '',
      synopsis: '',
      bitrate: media.bitRate ?? 0,
      sampleRate: 0,
      bits: 0,
      isLossless: null,
      format: media.suffix ?? media.contentType ?? '',
      channels: '',
      discNo: media.discNumber ?? 0,
      discTo: 0,
      language: '',
      lyrics: '',
      label: '',
      bpm: 0,
      rating: (media.userRating ?? 0) / 5.0,
      originalTags: null,
      tagsList: [],
      gainData: null,
      sortInfo: null,
      hashKey: media.id, // TrackExtended.generateHashKeyIfEnabled(null, path, null)
      isVideo: media.isVideo ?? false,
      server: server,
      albumsIdentifiersWrappers: AlbumIdentifierWrapper.fromAlbums(
        albums: albums,
        albumArtist: albumArtist,
        year: yearString,
        mbAlbumId: '',
        mbAlbumArtistId: '',
      ),
    );
  }
}
