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
      baseUrl: authDetails.dir.source,
      auth: authDetails.auth.toSubsonicAuthModel(),
    );
    _serverUri = Uri.parse(authDetails.dir.source);
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

    final uri = Uri(
      host: baseUri.host,
      fragment: baseUri.fragment,
      port: baseUri.port,
      userInfo: baseUri.userInfo,
      scheme: baseUri.scheme,
      path: '/rest/stream',
      queryParameters: {
        'v': api.version,
        'c': api.clientId,
        'id': id,
        ...authDetails.auth.toUrlParams(),
      },
    );
    return WebStreamUriDetails.fromUri(uri);
  }

  @override
  Future<Uint8List?> getImage(String id) async {
    final baseUri = _serverUri;
    if (baseUri == null) return null;
    final api = _api;
    if (api == null) return null;

    final res = await api.api.getCoverArt(id);
    return res.response.data;

    // if (data is Uint8List) {
    //   return data;
    // }

    // if (data is Map) {
    //   // -- is error
    //   return null;
    // }

    // return null;
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
  Future<void> fetchAllMusicAndProcess(void Function(TrackExtended trExt) callback) async {
    final api = _api;
    if (api == null) return;

    final server = authDetails.dir.toDbKey();
    final serverUriParsed = Uri.parse(server);
    final artistsSplitConfig = ArtistsSplitConfig.settings();
    final genresSplitConfig = GenresSplitConfig.settings();

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
        artistsSplitConfig: artistsSplitConfig,
        genresSplitConfig: genresSplitConfig,
      );

      await for (final tr in stream) {
        callback(tr);
      }

      offset += batchSize;

      if (albums.length < batchSize) {
        hasMore = false;
        break;
      }
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
    required ArtistsSplitConfig artistsSplitConfig,
    required GenresSplitConfig genresSplitConfig,
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
            artistsSplitConfig: artistsSplitConfig,
            genresSplitConfig: genresSplitConfig,
            server: server,
            serverUriParsed: serverUriParsed,
          );
        }
      }
    }
  }

  TrackExtended _mediaModelToTrackExtended(
    MediaModel media, {
    required ArtistsSplitConfig artistsSplitConfig,
    required GenresSplitConfig genresSplitConfig,
    required String server,
    required Uri serverUriParsed,
  }) {
    // -- dont use id cuz yt id matcher would catch it
    final newUri = serverUriParsed.replace(queryParameters: {
      ...serverUriParsed.queryParameters,
      'd': media.id,
    });
    final path = newUri.toString();
    final title = media.title;
    final artist = media.artist;
    final genre = media.genre;
    final album = media.album ?? '';
    const albumArtist = ''; // not there
    final year = media.year;
    final yearString = year?.toString() ?? '';
    final artists = artist == null
        ? <String>[]
        : Indexer.splitArtist(
            title: title,
            originalArtist: artist,
            config: artistsSplitConfig,
          );
    final genres = genre == null
        ? <String>[]
        : Indexer.splitGenre(
            genre,
            config: genresSplitConfig,
          );
    return TrackExtended(
      title: media.title,
      originalArtist: media.artist ?? '',
      artistsList: artists,
      album: album,
      albumArtist: albumArtist,
      originalGenre: media.genre ?? '',
      genresList: genres,
      originalMood: '',
      moodList: [],
      composer: '',
      trackNo: media.track ?? 0,
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
      language: '',
      lyrics: '',
      label: '',
      rating: (media.userRating ?? 0) / 5.0,
      originalTags: null,
      tagsList: [],
      gainData: null,
      hashKey: media.id, // TrackExtended.generateHashKeyIfEnabled(null, path, null)
      isVideo: media.isVideo ?? false,
      server: server,
      albumIdentifierWrapper: AlbumIdentifierWrapper.normalize(
        album: album,
        albumArtist: albumArtist,
        year: yearString,
      ),
    );
  }
}
