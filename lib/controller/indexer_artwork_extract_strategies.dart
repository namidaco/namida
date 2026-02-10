part of 'indexer_controller.dart';

abstract class _ArtworkExtractStrategy {
  final Indexer parent;
  const _ArtworkExtractStrategy(this.parent);

  Future<FArtwork> getArtwork({
    required String? imagePath,
    required Track? track,
    required bool checkFileFirst,
    required int? size,
    required bool compressed,
  });

  Future<void> Function()? _getPendingRequestResult(String imagePath, bool compressed) {
    if (compressed) {
      if (parent._pendingArtworksCompressed.containsKey(imagePath)) {
        return () => parent._pendingArtworksCompressed[imagePath]!.future;
      }
    } else {
      if (parent._pendingArtworksFullRes.containsKey(imagePath)) {
        return () => parent._pendingArtworksFullRes[imagePath]!.future;
      }
    }
    return null;
  }
}

/// ============================================
/// Network-based strategy (for web servers)
/// ============================================
class _NetworkBasedArtworkExtractStrategy extends _ArtworkExtractStrategy {
  const _NetworkBasedArtworkExtractStrategy(super.parent);

  @override
  Future<FArtwork> getArtwork({
    required String? imagePath,
    required Track? track,
    required bool checkFileFirst,
    required int? size,
    required bool compressed,
  }) async {
    if (track == null) return FArtwork.dummy();

    if (imagePath != null && checkFileFirst && await File(imagePath).exists()) {
      return FArtwork(file: File(imagePath));
    }

    imagePath ??= track.pathToImage;

    final pendingResFn = _getPendingRequestResult(imagePath, false);
    if (pendingResFn != null) {
      await pendingResFn();
      return FArtwork(bytes: parent.artworksBytesMap[imagePath]);
    }

    parent._pendingArtworksFullRes[imagePath] = Completer<void>();

    try {
      final resBytes = await MusicWebServer.baseUrlToImage(track.path);
      parent.artworksBytesMap[imagePath] = resBytes;
      if (resBytes != null && parent.isNetworkArtworkCachingEnabled) {
        File(imagePath).writeAsBytes(resBytes).ignoreError();
      }
    } catch (_) {}

    parent._pendingArtworksFullRes[imagePath]!.completeIfWasnt();
    parent._pendingArtworksFullRes.remove(imagePath);

    return FArtwork(bytes: parent.artworksBytesMap[imagePath]);
  }
}

/// ============================================
/// File-based strategy (for physical files)
/// ============================================
class _FileBasedArtworkExtractStrategy extends _ArtworkExtractStrategy {
  const _FileBasedArtworkExtractStrategy(super.parent);

  @override
  Future<FArtwork> getArtwork({
    required String? imagePath,
    required Track? track,
    required bool checkFileFirst,
    required int? size,
    required bool compressed,
  }) async {
    if (imagePath != null && checkFileFirst && await File(imagePath).exists()) {
      return FArtwork(file: File(imagePath));
    }

    if (track != null) {
      return await _extractFromTrack(track.path);
    }

    return FArtwork.dummy();
  }

  Future<FArtwork> _extractFromTrack(String trackPath) async {
    final pendingResFn = _getPendingRequestResult(trackPath, false);
    if (pendingResFn != null) {
      await pendingResFn();
      return FArtwork(file: parent.artworksFilesMap[trackPath], bytes: parent.artworksBytesMap[trackPath]);
    }

    parent._pendingArtworksFullRes[trackPath] = Completer<void>();

    final isVideo = trackPath.isVideo();
    final artworkDirectory = isVideo ? AppDirs.THUMBNAILS : AppDirs.ARTWORKS;
    final trExt = Track.decide(trackPath, isVideo).toTrackExtOrNull();

    final filename = TagsExtractor.buildImageFilename(
      path: trackPath,
      identifiers: null,
      identifierCallback: () => trExt?.albumIdentifierWrapper?.resolved(),
      infoCallback: () => (
        albumName: trExt?.album,
        albumArtist: trExt?.albumArtist,
        year: trExt?.year.toString(),
        title: trExt?.title,
        artist: trExt?.originalArtist,
      ),
      isNetwork: false,
      hashKeyCallback: () => trExt?.hashKey ?? trackPath.toFastHashKey(),
    );

    Uint8List? bytes;
    File? file;
    final isCachingEnabled = parent._isArtworkCachingEnabled;
    // -- prefer this way before ffmpeg since this can return bytes directly and is generally faster
    final model = await NamidaTaggerController.inst.extractMetadata(
      trackPath: trackPath,
      isVideo: isVideo,
      extractArtwork: true,
      saveArtworkToCache: isCachingEnabled,
      isNetwork: false,
    );
    final artwork = model.tags.artwork;
    bytes = artwork.bytes;
    file = artwork.file;

    if (bytes == null && file == null) {
      file = await TagsExtractor.extractThumbnailCustom(
        trackPath: trackPath,
        isVideo: isVideo,
        artworkDirectory: artworkDirectory,
        filename: filename,
      );
      if (!isCachingEnabled) {
        bytes = await file?.readAsBytes();
        file?.tryDeleting();
        file = null;
      }
    }

    if (bytes != null) {
      parent.artworksBytesMap[trackPath] = bytes;
    } else {
      // -- even if file null
      parent.artworksFilesMap[trackPath] = file;
    }

    parent._pendingArtworksFullRes[trackPath]!.completeIfWasnt();
    parent._pendingArtworksFullRes.remove(trackPath);

    return FArtwork(file: parent.artworksFilesMap[trackPath], bytes: parent.artworksBytesMap[trackPath]);
  }
}

/// ============================================
/// Media Store Strategy (for local tracks with media store)
/// Automatically falls back to [_FileBasedArtworkExtractStrategy] if failed.
/// ============================================
class _MediaStoreArtworkExtractStrategy extends _ArtworkExtractStrategy {
  const _MediaStoreArtworkExtractStrategy(super.parent);

  @override
  Future<FArtwork> getArtwork({
    required String? imagePath,
    required Track? track,
    required bool checkFileFirst,
    required int? size,
    required bool compressed,
  }) async {
    if (imagePath == null) return FArtwork.dummy();

    final pendingResFn = _getPendingRequestResult(imagePath, compressed);
    if (pendingResFn != null) {
      await pendingResFn();
      return FArtwork(bytes: parent.artworksBytesMap[imagePath]);
    }

    if (checkFileFirst && await File(imagePath).exists()) {
      return FArtwork(file: File(imagePath));
    }

    FArtwork? artwork;

    final info = parent._backupMediaStoreIDS[imagePath];
    if (info != null) {
      artwork = compressed ? await _getCompressed(imagePath, info.$2, size) : await _getFullRes(imagePath, info);
    }

    // -- fallback to file-based if no info or media store failed
    if (artwork == null || !artwork.hasArtwork) {
      artwork = await _FileBasedArtworkExtractStrategy(parent).getArtwork(
        imagePath: imagePath,
        track: track,
        checkFileFirst: false,
        size: size,
        compressed: compressed,
      );
    }

    return artwork;
  }

  Future<FArtwork> _getCompressed(
    String imagePath,
    int id,
    int? size,
  ) async {
    parent._pendingArtworksCompressed[imagePath] = Completer<void>();

    final artwork = await parent._audioQuery.queryArtwork(
      id,
      ArtworkType.AUDIO,
      format: ArtworkFormat.JPEG,
      quality: null,
      size: size?.clampInt(48, 360) ?? 360,
    );

    parent.artworksBytesMap[imagePath] = artwork;
    parent._pendingArtworksCompressed[imagePath]!.completeIfWasnt();
    parent._pendingArtworksCompressed.remove(imagePath);

    return FArtwork(bytes: parent.artworksBytesMap[imagePath]);
  }

  Future<FArtwork> _getFullRes(
    String imagePath,
    (Track, int) info,
  ) async {
    parent._pendingArtworksFullRes[imagePath] = Completer<void>();

    final res = await _FileBasedArtworkExtractStrategy(parent).getArtwork(
      imagePath: imagePath,
      track: info.$1,
      checkFileFirst: false,
      size: null,
      compressed: false,
    );
    var file = res.file;

    if (file == null) {
      final artwork = await parent._audioQuery.queryArtwork(
        info.$2,
        ArtworkType.AUDIO,
        format: ArtworkFormat.PNG,
        quality: 100,
        size: 720,
      );

      if (artwork != null) {
        file = File(imagePath);
        await FileImage(file).evict();
        await file.writeAsBytes(artwork);
      }
    }

    parent.artworksFilesMap[imagePath] = file;
    parent._pendingArtworksFullRes[imagePath]!.completeIfWasnt();
    parent._pendingArtworksFullRes.remove(imagePath);

    return FArtwork(file: parent.artworksFilesMap[imagePath]);
  }
}
