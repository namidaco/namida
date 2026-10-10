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
  WebStreamUriDetails? getStreamUrl(String id, {void Function(File cachedFile)? onFetchedIfLocal}) => _buildEndpointUrl('/rest/stream', id);

  /// `/rest/stream` can be transcoded by the server.
  @override
  Future<_ServerFileSource?> _getOriginalFileSource(String id) async {
    final details = _buildEndpointUrl('/rest/download', id);
    return details == null ? null : _ServerFileSourceUrl(details);
  }

  WebStreamUriDetails? _buildEndpointUrl(String endpointPath, String id) {
    final api = _api;
    if (api == null) return null;
    final baseUri = _serverUri;
    if (baseUri == null) return null;

    final uri = baseUri.buildEndpointUri(
      endpointPath,
      {
        'v': api.version,
        'c': api.clientId,
        'id': id,
        ...authDetails.auth.toUrlParams(),
      },
    );
    return WebStreamUriDetails.fromUri(uri);
  }

  @override
  Future<void> _reportPlayback(String id, _PlaybackReport report, int positionMS) async {
    final client = _client;
    if (client == null) return;
    final isNowPlaying = switch (report) {
      _PlaybackReport.started || _PlaybackReport.resumed => true,
      _PlaybackReport.paused || _PlaybackReport.progress || _PlaybackReport.stopped => false,
    };
    if (!isNowPlaying) return;
    await client.get<void>(
      '/rest/scrobble',
      queryParameters: {
        'id': id,
        'submission': false,
      },
    );
  }

  @override
  Future<_ListensReportResult> _reportListens(List<_ServerListen> listens) async {
    final client = _client;
    if (client == null) return _ListensReportResult.retryLater;
    final ids = listens.map((e) => e.id).toFixedList();
    final times = listens.map((e) => e.dateMS).toFixedList();
    try {
      final res = await client.get<Map<String, dynamic>>(
        '/rest/scrobble',
        queryParameters: {
          'id': ids,
          'time': times,
          'submission': true,
        },
      );
      final body = res.data?['subsonic-response'] as Map?;
      final error = body?['error'] as Map?;
      if (error == null) return _ListensReportResult.sent;
      final code = error['code'] as int?;
      final isAuthError = code == SubsonicErrorModel.wrongUsernameOrPassword || code == SubsonicErrorModel.tokenAuthenticationNotSupportedForLdapUsers;
      return isAuthError ? _ListensReportResult.retryLater : _ListensReportResult.rejected;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      return _ListensReportResult.fromStatusCode(statusCode);
    } catch (_) {
      // -- unexpected response, would fail the same way again
      return _ListensReportResult.rejected;
    }
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

  Future<List<AlbumModel>>? _albumsForNextFetch;

  @override
  Future<int?> prepareTracksCount() async {
    final api = _api;
    if (api == null) return null;

    final albumsFuture = _fetchAllAlbums(api);
    _albumsForNextFetch = albumsFuture;
    final albums = await albumsFuture;

    int tracksCount = 0;
    for (final album in albums) {
      tracksCount += album.songCount ?? 0;
    }
    return tracksCount;
  }

  @override
  Future<void> fetchAllMusicAndProcess(Map<String, int> serverTracksInLibrary, void Function(TrackExtended trExt) callback, {required bool forceReIndex}) async {
    final api = _api;
    if (api == null) return;

    final server = authDetails.dir.toDbKey();
    final serverUriParsed = Uri.parse(server);

    final splitConfig = SplitArtistGenreConfigsWrapper.settings();

    final albumsFuture = _albumsForNextFetch ?? _fetchAllAlbums(api);
    _albumsForNextFetch = null;
    final albums = await albumsFuture;

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
  }

  Future<List<AlbumModel>> _fetchAllAlbums(SubsonicApi api) async {
    final allAlbums = <AlbumModel>[];
    const batchSize = 400;
    int offset = 0;
    while (true) {
      final albumsRes = await api.api.getAlbumList('newest', size: batchSize, offset: offset);
      if (_checkResError(authDetails.dir, albumsRes)) break;

      final albums = albumsRes.response.data?.albums ?? [];
      allAlbums.addAll(albums);

      if (albums.length < batchSize) break;
      offset += batchSize;
    }
    return allAlbums;
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
                album: null,
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
        final album = albumDetail.response.data;
        final songs = album?.song ?? [];
        for (final s in songs) {
          yield _mediaModelToTrackExtended(
            s,
            album: album,
            splitConfig: splitConfig,
            server: server,
            serverUriParsed: serverUriParsed,
          );
        }
      }
    }
  }

  /// [album] is the `getAlbum` detail the song came from, playlist songs don't have one.
  static TrackExtended _mediaModelToTrackExtended(
    MediaModel media, {
    required AlbumModel? album,
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
    final year = media.year;
    final yearFallbackText = year?.toString() ?? '';
    final yearString = _releaseDateText(album, year) ?? yearFallbackText;
    final remotePath = media.path;
    final serverFolder = remotePath == null ? null : _serverFolderOf(remotePath);

    final artists = _namesOrNull(media.artists.map((e) => e.name));
    final albumArtists = _namesOrNull(media.albumArtists.map((e) => e.name));
    final genres = _namesOrNull(media.genres.map((e) => e.name));
    final composerContributors = media.contributors.where((c) => c.role == _kSubsonicComposerRole);
    final composers = _namesOrNull(composerContributors.map((c) => c.artist.name));
    final moods = _namesOrNull(media.moods);
    final recordLabels = album?.recordLabels ?? const [];
    final labels = _namesOrNull(recordLabels.map((e) => e.name));
    final releaseTypes = _namesOrNull(album?.releaseTypes ?? const []);

    final originalArtist = artists?.join(FTagsMultiValues.kJoiner) ?? media.artist ?? '';
    final albumArtist = albumArtists?.join(FTagsMultiValues.kJoiner) ?? media.displayAlbumArtist ?? album?.artist ?? '';
    final originalGenre = genres?.join(FTagsMultiValues.kJoiner) ?? media.genre ?? '';
    final composer = composers?.join(FTagsMultiValues.kJoiner) ?? media.displayComposer ?? '';
    final mood = moods?.join(FTagsMultiValues.kJoiner) ?? '';
    final label = labels?.join(FTagsMultiValues.kJoiner) ?? '';
    final releaseType = releaseTypes?.join(FTagsMultiValues.kJoiner) ?? '';

    final multiValues = FTagsMultiValues.orNull(
      artists: artists == null ? null : FTagsMultiValues.valuesOrNull(artists),
      albumArtists: albumArtists == null ? null : FTagsMultiValues.valuesOrNull(albumArtists),
      genres: genres == null ? null : FTagsMultiValues.valuesOrNull(genres),
      composers: composers == null ? null : FTagsMultiValues.valuesOrNull(composers),
      moods: moods == null ? null : FTagsMultiValues.valuesOrNull(moods),
    );
    final replayGain = media.replayGain;
    final gainData = replayGain == null
        ? null
        : ReplayGainData.orNull(
            trackGain: replayGain.trackGain,
            albumGain: replayGain.albumGain,
            trackPeak: replayGain.trackPeak,
            albumPeak: replayGain.albumPeak,
          );
    final sortInfo = FTagsSortInfo.orNull(
      title: media.sortName,
      album: album?.sortName,
    );
    final bpm = media.bpm;
    final validBpm = bpm == null || bpm <= 0 ? null : bpm;

    return TrackExtended.derive(
      splitConfig: splitConfig,
      mbAlbumId: album?.musicBrainzId ?? '',
      mbAlbumArtistId: '',
      title: media.title,
      originalArtist: originalArtist,
      originalAlbum: media.album ?? '',
      albumArtist: albumArtist,
      originalGenre: originalGenre,
      originalStyle: '',
      originalMood: mood,
      composer: composer,
      trackNo: media.track ?? 0,
      trackTo: 0,
      durationMS: media.duration?.inMilliseconds ?? 0,
      chapters: null,
      year: year ?? 0,
      yearText: yearString,
      size: media.size ?? 0,
      dateAdded: media.created?.millisecondsSinceEpoch ?? 0,
      dateModified: media.created?.millisecondsSinceEpoch ?? 0,
      path: path,
      comment: media.comment ?? '',
      description: '',
      synopsis: '',
      bitrate: media.bitRate ?? 0,
      sampleRate: media.samplingRate ?? 0,
      bits: media.bitDepth ?? 0,
      isLossless: null,
      format: media.suffix ?? media.contentType ?? '',
      channels: _channelsText(media.channelCount),
      discNo: media.discNumber ?? 0,
      discTo: 0,
      language: '',
      lyrics: '',
      label: label,
      releaseType: releaseType,
      bpm: validBpm,
      musicalKey: '',
      rating: (media.userRating ?? 0) / 5.0,
      originalTags: null,
      gainData: gainData,
      sortInfo: sortInfo,
      multiValues: multiValues,
      extraTags: null,
      hashKey: media.id, // TrackExtended.generateHashKeyIfEnabled(null, path, null)
      isVideo: media.isVideo ?? false,
      server: server,
      serverFolder: serverFolder,
    );
  }
}

/// the album's release date as a tag-like `yyyy-mm-dd` text, only when it's the song's year.
String? _releaseDateText(AlbumModel? album, int? songYear) {
  if (album == null || songYear == null) return null;
  final date = album.originalReleaseDate ?? album.releaseDate;
  if (date == null || date.year != songYear) return null;
  final month = date.month;
  if (month == null) return null;
  final day = date.day;
  final buffer = StringBuffer()
    ..write(songYear)
    ..write('-')
    ..write(month.toString().padLeft(2, '0'));
  if (day != null) {
    buffer
      ..write('-')
      ..write(day.toString().padLeft(2, '0'));
  }
  return buffer.toString();
}

const _kSubsonicComposerRole = 'composer';

@visibleForTesting
TrackExtended debugSubsonicMediaToTrack(MediaModel media, {AlbumModel? album, required SplitArtistGenreConfigsWrapper splitConfig, required String server}) {
  final serverUriParsed = Uri.parse(server);
  return _SubsonicWebServer._mediaModelToTrackExtended(media, album: album, splitConfig: splitConfig, server: server, serverUriParsed: serverUriParsed);
}
