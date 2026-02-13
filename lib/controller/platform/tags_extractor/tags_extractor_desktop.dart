part of 'tags_extractor.dart';

class _TagsExtractorDesktop extends TagsExtractor {
  _TagsExtractorDesktop._internal();

  @override
  Future<void> updateLogsPath() async {}

  @override
  Future<FAudioModel> extractMetadata({
    FFMPEGExecuter? executer,
    required String trackPath,
    required bool extractArtwork,
    required String? artworkDirectory,
    Set<AlbumIdentifier>? identifiers,
    bool overrideArtwork = false,
    required bool isVideo,
    required bool isNetwork,
    String? networkId,
  }) async {
    final ffmpegInfo = await executer?.extractMetadata(trackPath) ?? await ffmpegController.ffmpegExtractMetadata(trackPath);

    if (ffmpegInfo != null && isVideo) {
      try {
        final stats = await File(trackPath).stat();
        videoController.addLocalVideoFileInfoToCacheMap(trackPath, ffmpegInfo, stats);
      } catch (_) {}
    }

    FArtwork artwork = FArtwork();
    if (extractArtwork) {
      if (artworkDirectory != null) {
        final filename = TagsExtractor.buildImageFilename(
          path: trackPath,
          identifiers: identifiers,
          isNetwork: isNetwork,
          networkId: networkId,
          infoCallback: () => (
            albumName: ffmpegInfo?.format?.tags?.album,
            albumArtist: ffmpegInfo?.format?.tags?.albumArtist,
            year: ffmpegInfo?.format?.tags?.date,
            title: ffmpegInfo?.format?.tags?.title,
            artist: ffmpegInfo?.format?.tags?.artist,
          ),
          hashKeyCallback: () => trackPath.toFastHashKey(),
        );

        final possibleThumbFile = FileParts.join(artworkDirectory, filename);
        artwork.file = possibleThumbFile;

        // specified directory to save in, the file is expected to exist here.
        File? artworkFile = artwork.file;
        if (overrideArtwork || artworkFile == null || !await artworkFile.exists()) {
          final File? thumbFile = await TagsExtractor.extractThumbnailCustom(
            trackPath: trackPath,
            filename: filename,
            artworkDirectory: artworkDirectory,
            isVideo: isVideo,
            overrideOldArtwork: overrideArtwork,
          );
          artwork.file = thumbFile;
        }
      } else {
        // -- otherwise the artwork should be within info as bytes.
        Uint8List? artworkBytes = artwork.bytes;
        if (overrideArtwork || artworkBytes == null || artworkBytes.isEmpty) {
          final File? tempFile = await TagsExtractor.extractThumbnailCustom(
            trackPath: trackPath,
            filename: null,
            artworkDirectory: null,
            isVideo: isVideo,
            overrideOldArtwork: overrideArtwork,
          );
          artwork.bytes = await tempFile?.readAsBytes();
          tempFile?.tryDeleting();
        }
      }
    }

    return ffmpegInfo?.toFAudioModel(artwork: artwork) ?? FAudioModel.dummy(trackPath, artwork);
  }

  @override
  Stream<FAudioModel> extractMetadataAsStream({
    required List<String> paths,
    required ExtractingPathKey keyWrapper,
    required bool extractArtwork,
    required String? audioArtworkDirectory,
    required String? videoArtworkDirectory,
    bool overrideArtwork = false,
    required bool isNetwork,
  }) async* {
    final key = keyWrapper.next();

    // -- create with each batch to avoid piling up the main executer
    final executer = FFMPEGExecuter.platform();
    await executer.init();

    for (int i = 0; i < paths.length; i++) {
      var path = paths[i];
      currentPathsBeingExtracted[key] = path;
      final isVideo = path.isVideo();
      final artworkDirectory = isVideo ? videoArtworkDirectory : audioArtworkDirectory;
      final info = await extractMetadata(
        executer: executer,
        trackPath: path,
        artworkDirectory: artworkDirectory,
        extractArtwork: extractArtwork,
        overrideArtwork: overrideArtwork,
        isVideo: isVideo,
        isNetwork: isNetwork,
      );
      yield info;
    }
    executer.dispose();
    currentPathsBeingExtracted.remove(key);
  }

  @override
  Future<FArtwork?> extractArtwork({required String trackPath, required bool isVideo}) async {
    Uint8List? bytes;

    final File? tempFile = await TagsExtractor.extractThumbnailCustom(
      trackPath: trackPath,
      filename: null,
      artworkDirectory: null,
      isVideo: isVideo,
    );
    bytes = await tempFile?.readAsBytes();
    tempFile?.tryDeleting();

    return bytes == null ? null : FArtwork(bytes: bytes);
  }

  @override
  Future<bool> writeTags({
    required String path,
    required FTags newTags,
    required String? commentToInsert,
    required String? oldComment,
  }) async {
    final ffmpegTagsMap = commentToInsert != null && commentToInsert.isNotEmpty
        ? <String, String?>{
            FFMPEGTagField.comment: oldComment == null || oldComment.isEmpty ? commentToInsert : '$commentToInsert\n$oldComment',
          }
        : FFMPEGTagField.createTagsMapfromFTag(newTags);

    final didUpdate = await ffmpegController.editMetadata(
      path: path,
      tagsMap: ffmpegTagsMap,
    );

    final imageFile = newTags.artwork.file;
    if (imageFile != null) {
      await ffmpegController.editAudioThumbnail(audioPath: path, thumbnailPath: imageFile.path);
    }

    snackyy(
      title: lang.WARNING,
      message: 'FFMPEG was used. Some tags might not have been updated',
      isError: true,
    );

    return didUpdate;
  }
}
