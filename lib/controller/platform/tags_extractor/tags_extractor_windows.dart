part of 'tags_extractor.dart';

class _TagsExtractorWindows extends TagsExtractor {
  _TagsExtractorWindows._internal();

  @override
  Future<void> updateLogsPath() async {}

  @override
  Future<FAudioModel> extractMetadata({
    required String trackPath,
    bool extractArtwork = true,
    required String? artworkDirectory,
    Set<AlbumIdentifier>? identifiers,
    bool overrideArtwork = false,
    required bool isVideo,
  }) async {
    final ffmpegInfo = await ffmpegController.extractMetadata(trackPath);

    if (ffmpegInfo != null && isVideo) {
      try {
        final stats = File(trackPath).statSync();
        videoController.addLocalVideoFileInfoToCacheMap(trackPath, ffmpegInfo, stats);
      } catch (_) {}
    }

    FArtwork artwork = FArtwork();
    if (extractArtwork) {
      if (artworkDirectory != null) {
        final identifiersSet = identifiers ?? TagsExtractor.getAlbumIdentifiersSet();
        final filename = TagsExtractor.defaultGroupArtworksByAlbum
            ? TagsExtractor.getArtworkIdentifier(
                albumName: ffmpegInfo?.format?.tags?.album,
                albumArtist: ffmpegInfo?.format?.tags?.albumArtist,
                year: ffmpegInfo?.format?.tags?.date,
                identifiers: identifiersSet,
              )
            : trackPath.getFilename;
        final possibleThumbFile = FileParts.join(artworkDirectory, '$filename.png');
        artwork.file = possibleThumbFile;

        // specified directory to save in, the file is expected to exist here.
        File? artworkFile = artwork.file;
        if (artworkFile == null || !await artworkFile.exists()) {
          final File? thumbFile = await TagsExtractor.extractThumbnailCustom(
            trackPath: trackPath,
            filename: filename,
            artworkDirectory: artworkDirectory,
            isVideo: isVideo,
          );
          artwork.file = thumbFile;
        }
      } else {
        // -- otherwise the artwork should be within info as bytes.
        Uint8List? artworkBytes = artwork.bytes;
        if (artworkBytes == null || artworkBytes.isEmpty) {
          final File? tempFile = await TagsExtractor.extractThumbnailCustom(
            trackPath: trackPath,
            filename: null,
            artworkDirectory: null,
            isVideo: isVideo,
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
    bool extractArtwork = true,
    required String? audioArtworkDirectory,
    required String? videoArtworkDirectory,
    bool overrideArtwork = false,
  }) async* {
    for (int i = 0; i < paths.length; i++) {
      var path = paths[i];
      final isVideo = path.isVideo();
      final artworkDirectory = isVideo ? videoArtworkDirectory : audioArtworkDirectory;
      final info = await extractMetadata(
        trackPath: path,
        artworkDirectory: artworkDirectory,
        extractArtwork: extractArtwork,
        overrideArtwork: overrideArtwork,
        isVideo: isVideo,
      );
      yield info;
    }
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
        : <String, String?>{
            FFMPEGTagField.title: newTags.title,
            FFMPEGTagField.artist: newTags.artist,
            FFMPEGTagField.album: newTags.album,
            FFMPEGTagField.albumArtist: newTags.albumArtist,
            FFMPEGTagField.composer: newTags.composer,
            FFMPEGTagField.genre: newTags.genre,
            FFMPEGTagField.year: newTags.year,
            FFMPEGTagField.trackNumber: newTags.trackNumber,
            FFMPEGTagField.discNumber: newTags.discNumber,
            FFMPEGTagField.trackTotal: newTags.trackTotal,
            FFMPEGTagField.discTotal: newTags.discTotal,
            FFMPEGTagField.comment: newTags.comment,
            FFMPEGTagField.description: newTags.description,
            FFMPEGTagField.synopsis: newTags.synopsis,
            FFMPEGTagField.lyrics: newTags.lyrics,
            FFMPEGTagField.remixer: newTags.remixer,
            FFMPEGTagField.lyricist: newTags.lyricist,
            FFMPEGTagField.language: newTags.language,
            FFMPEGTagField.recordLabel: newTags.recordLabel,
            FFMPEGTagField.country: newTags.country,

            // -- TESTED NOT WORKING. disabling to prevent unwanted fields corruption etc.
            // FFMPEGTagField.mood: editedTags[TagField.mood],
            // FFMPEGTagField.tags: editedTags[TagField.tags],
            // FFMPEGTagField.rating: editedTags[TagField.rating],
          };

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
