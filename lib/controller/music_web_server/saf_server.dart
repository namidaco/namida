// by claude
part of 'music_web_server_base.dart';

/// a folder granted through the storage access framework, read through the android document provider that owns it (rsaf, drive, nextcloud, file managers...).
class _SAFServer extends MusicWebServer {
  late final String _treeUri = switch (authDetails.dir) {
    DirectoryIndexServer dir => dir.safTreeUri() ?? '',
    DirectoryIndexLocal() => '',
  };

  _SAFServer.init(super.authDetails);

  @override
  void dispose() {}

  @override
  Future<MusicWebServerError?> ping() async {
    final hasAccess = await NamidaStorage.inst.safTreeHasAccess(_treeUri);
    if (hasAccess) return null;
    return const MusicWebServerError(code: 0, message: 'Access to the folder was revoked, remove it and pick it again');
  }

  @override
  Future<WebStreamUriDetails?> getStreamUrl(String id, {void Function(File cachedFile)? onFetchedIfLocal}) async {
    final playsContentUris = settings.player.internalPlayer.value.ensureResolved() != InternalPlayerType.mpv;
    if (playsContentUris) {
      final documentUri = Uri.parse(_documentUriOf(id));
      return WebStreamUriDetails.fromUri(documentUri, allowStreamCaching: false);
    }

    // -- mpv can't open android content uris
    final cacheFile = ServerCacheController.cacheFileFor(authDetails.dir.type, authDetails.auth.username, id);
    final error = await _copyToFile(id, cacheFile);
    if (error != null) return null;
    onFetchedIfLocal?.call(cacheFile);
    return WebStreamUriDetails.fromUri(Uri.file(cacheFile.path), allowStreamCaching: false);
  }

  @override
  Future<_ServerFileSource?> _getOriginalFileSource(String id) async {
    return _ServerFileSourceStream((start) => _openReadStream(id, start));
  }

  @override
  Future<Uint8List?> getImage(String id) async {
    final tempFile = _tempFileFor(id);
    final error = await _copyToFile(id, tempFile);
    if (error != null) return null;
    try {
      final artwork = await NamidaTaggerController.inst.extractArtwork(trackPath: tempFile.path, isVideo: id.isVideo());
      return artwork?.bytes;
    } catch (_) {
      return null;
    } finally {
      tempFile.tryDeleting();
    }
  }

  @override
  Future<void> fetchAllMusicAndProcess(Map<String, int> serverTracksInLibrary, void Function(TrackExtended trExt) callback, {required bool forceReIndex}) async {
    final listing = await NamidaStorage.inst.safListTree(_treeUri);
    if (listing == null) return;

    final server = authDetails.dir.toDbKey();
    final serverUriParsed = Uri.parse(server);
    final splittersConfigs = SplitArtistGenreConfigsWrapper.settings();
    final minDur = settings.indexMinDurationInSec.value;
    final minSize = settings.indexMinFileSizeInB.value;
    final extractArtwork = Indexer.inst.isNetworkArtworkCachingEnabled;
    final diffState = forceReIndex ? null : _ServerDiffManager(serverUriParsed, serverTracksInLibrary);

    final mediaIndices = <int>[];
    final lrcIndices = <int>[];
    final total = listing.length;
    for (int i = 0; i < total; i++) {
      final name = listing.names[i];
      if (NamidaFileExtensionsWrapper.audioAndVideo.isPathValid(name)) {
        mediaIndices.add(i);
      } else if (NamidaFileExtensionsWrapper.lrc.isPathValid(name) || NamidaFileExtensionsWrapper.txt.isPathValid(name)) {
        lrcIndices.add(i);
      }
    }

    String siblingKey(int index) => '${listing.dirIndices[index]}/${listing.names[index].getFilenameWOExt}';

    Future<TrackExtended?> processMedia(int index) async {
      final docId = listing.ids[index];
      final modifiedMS = listing.modifiedMS[index];
      if (diffState != null) {
        final remoteModified = modifiedMS >= 0 ? DateTime.fromMillisecondsSinceEpoch(modifiedMS) : null;
        final canSkip = diffState.checkCanSkipScanAndMarkExists(docId, remoteModified);
        if (canSkip) return null;
      }

      final name = listing.names[index];
      final tempFile = _tempFileFor(docId);
      final error = await _copyToFile(docId, tempFile);
      if (error != null) return null;
      try {
        final trackInfo = await NamidaTaggerController.inst.extractMetadata(
          trackPath: tempFile.path,
          isVideo: name.isVideo(),
          extractArtwork: extractArtwork,
          saveArtworkToCache: extractArtwork,
          isNetwork: true,
          networkId: docId,
        );
        final size = listing.sizes[index];
        final trExt = await Indexer.convertServerTagToTrack(
          path: name,
          trackInfo: trackInfo,
          stats: FileStatsAdv(
            creationDateMS: null,
            modifiedMS: modifiedMS >= 0 ? modifiedMS : null,
            size: size >= 0 ? size : null,
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
        if (trExt == null) return null;
        final newUri = serverUriParsed.replace(
          queryParameters: {
            ...serverUriParsed.queryParameters,
            'd': docId,
          },
        );
        return trExt.copyWith(generatePathHash: true, path: newUri.toString());
      } catch (_) {
        return null;
      } finally {
        tempFile.tryDeleting();
      }
    }

    final tracksBySibling = <String, TrackExtended>{};
    const batchSize = 4;
    final mediaCount = mediaIndices.length;
    for (int i = 0; i < mediaCount; i += batchSize) {
      final end = (i + batchSize).withMaximum(mediaCount);
      final futures = <Future<TrackExtended?>>[];
      for (int j = i; j < end; j++) {
        futures.add(processMedia(mediaIndices[j]));
      }
      final results = await Future.wait(futures);
      for (int j = 0; j < results.length; j++) {
        final trExt = results[j];
        if (trExt == null) continue;
        callback(trExt);
        if (lrcIndices.isNotEmpty) tracksBySibling[siblingKey(mediaIndices[i + j])] = trExt;
      }
    }

    for (final index in lrcIndices) {
      final trExt = tracksBySibling[siblingKey(index)];
      if (trExt == null) continue;
      final name = listing.names[index];
      final isSynced = NamidaFileExtensionsWrapper.lrc.isPathValid(name);
      final lrcUtils = LrcSearchUtilsSelectableFromNetwork(trExt, trExt.asTrack());
      final lrcFileInCache = isSynced ? lrcUtils.cachedLRCFile : lrcUtils.cachedTxtFile;
      await _copyToFile(listing.ids[index], lrcFileInCache);
    }
  }

  Future<Stream<List<int>>> _openReadStream(String docId, int start) async {
    final tempFile = _tempFileFor(docId);
    final error = await _copyToFile(docId, tempFile);
    if (error != null) throw Exception(error);
    return _readThenDelete(tempFile, start);
  }

  String _documentUriOf(String docId) => '$_treeUri/document/${Uri.encodeComponent(docId)}';

  File _tempFileFor(String docId) => FileParts.join(AppDirs.APP_CACHE, authDetails.dir.type.name, docId.toFastHashKey());

  Future<String?> _copyToFile(String docId, File file) => NamidaStorage.inst.safCopyDocument(_documentUriOf(docId), file.path);
}
