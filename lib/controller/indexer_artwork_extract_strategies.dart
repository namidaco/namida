part of 'indexer_controller.dart';

abstract class _ArtworkExtractStrategy {
  final Indexer parent;
  const _ArtworkExtractStrategy(this.parent);

  Future<(File?, Uint8List?)> getArtwork({
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

// ============================================
// Network-based strategy (for web servers)
// ============================================
class _NetworkBasedArtworkExtractStrategy extends _ArtworkExtractStrategy {
  const _NetworkBasedArtworkExtractStrategy(super.parent);

  @override
  Future<(File?, Uint8List?)> getArtwork({
    required String? imagePath,
    required Track? track,
    required bool checkFileFirst,
    required int? size,
    required bool compressed,
  }) async {
    if (track == null) return (null, null);

    if (imagePath != null && checkFileFirst && await File(imagePath).exists()) {
      return (File(imagePath), null);
    }

    imagePath ??= track.pathToImage;

    final pendingResFn = _getPendingRequestResult(imagePath, false);
    if (pendingResFn != null) {
      await pendingResFn();
      return (null, parent.artworksBytesMap[imagePath]);
    }

    parent._pendingArtworksFullRes[imagePath] = Completer<void>();

    final isNetwork = track.isNetwork;
    if (isNetwork) {
      try {
        final resBytes = await MusicWebServer.baseUrlToImage(track.path);
        parent.artworksBytesMap[imagePath] = resBytes;
      } catch (_) {}
    }

    parent._pendingArtworksFullRes[imagePath]!.completeIfWasnt();
    parent._pendingArtworksFullRes.remove(imagePath);

    return (null, parent.artworksBytesMap[imagePath]);
  }
}

// ============================================
// File-based strategy (for physical files)
// ============================================
class _FileBasedArtworkExtractStrategy extends _ArtworkExtractStrategy {
  const _FileBasedArtworkExtractStrategy(super.parent);

  @override
  Future<(File?, Uint8List?)> getArtwork({
    required String? imagePath,
    required Track? track,
    required bool checkFileFirst,
    required int? size,
    required bool compressed,
  }) async {
    if (imagePath != null && checkFileFirst && await File(imagePath).exists()) {
      return (File(imagePath), null);
    }

    if (track != null) {
      return await _extractFromTrack(track.path);
    }

    return (null, null);
  }

  Future<(File?, Uint8List?)> _extractFromTrack(String trackPath) async {
    final pendingResFn = _getPendingRequestResult(trackPath, false);
    if (pendingResFn != null) {
      await pendingResFn();
      return (parent.artworksFilesMap[trackPath], null);
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
      ),
      hashKeyCallback: () => trExt?.hashKey ?? trackPath.toFastHashKey(),
    );

    final file = await TagsExtractor.extractThumbnailCustom(
      trackPath: trackPath,
      isVideo: isVideo,
      artworkDirectory: artworkDirectory,
      filename: filename,
    );

    parent.artworksFilesMap[trackPath] = file;
    parent._pendingArtworksFullRes[trackPath]!.completeIfWasnt();
    parent._pendingArtworksFullRes.remove(trackPath);

    return (parent.artworksFilesMap[trackPath], null);
  }
}

// ============================================
// Media Store Strategy (for local tracks with media store)
// ============================================
class _MediaStoreArtworkExtractStrategy extends _ArtworkExtractStrategy {
  const _MediaStoreArtworkExtractStrategy(super.parent);

  @override
  Future<(File?, Uint8List?)> getArtwork({
    required String? imagePath,
    required Track? track,
    required bool checkFileFirst,
    required int? size,
    required bool compressed,
  }) async {
    if (imagePath == null) return (null, null);

    final pendingResFn = _getPendingRequestResult(imagePath, compressed);
    if (pendingResFn != null) {
      await pendingResFn();
      return (null, parent.artworksBytesMap[imagePath]);
    }

    if (checkFileFirst && await File(imagePath).exists()) {
      return (File(imagePath), null);
    }

    final info = parent._backupMediaStoreIDS[imagePath];
    if (info == null) {
      return await _FileBasedArtworkExtractStrategy(parent).getArtwork(
        imagePath: imagePath,
        track: track,
        checkFileFirst: false,
        size: size,
        compressed: compressed,
      );
    }

    return compressed ? await _getCompressed(imagePath, info.$2, size) : await _getFullRes(imagePath, info);
  }

  Future<(File?, Uint8List?)> _getCompressed(
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

    return (null, artwork);
  }

  Future<(File?, Uint8List?)> _getFullRes(
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
    var file = res.$1;

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

    return (parent.artworksFilesMap[imagePath], null);
  }
}
