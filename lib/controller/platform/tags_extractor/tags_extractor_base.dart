part of 'tags_extractor.dart';

abstract class TagsExtractor {
  final NamidaFFMPEG ffmpegController;
  final VideoController videoController;

  TagsExtractor()
      : this.ffmpegController = NamidaFFMPEG.inst,
        this.videoController = VideoController.inst;

  static TagsExtractor platform() {
    return NamidaPlatformBuilder.init(
      android: () => _TagsExtractorAndroid._init(),
      windows: () => _TagsExtractorWindows._internal(),
    );
  }

  final _streamControllers = <int, StreamController<FAudioModel>>{};
  final currentPathsBeingExtracted = <int, String>{}.obs;

  Future<void> updateLogsPath();

  Future<FAudioModel> extractMetadata({
    required String trackPath,
    bool extractArtwork = true,
    required String? artworkDirectory,
    Set<AlbumIdentifier>? identifiers,
    bool overrideArtwork = false,
    required bool isVideo,
  });

  FutureOr<Stream<FAudioModel>> extractMetadataAsStream({
    required List<String> paths,
    required ExtractingPathKey keyWrapper,
    bool extractArtwork = true,
    required String? audioArtworkDirectory,
    required String? videoArtworkDirectory,
    bool overrideArtwork = false,
  });

  Future<bool> writeTags({
    required String path,
    required FTags newTags,
    required String? commentToInsert,
    required String? oldComment,
  });

  static Future<File?> extractThumbnailCustom({
    required String trackPath,
    required String? filename,
    required String? artworkDirectory,
    required bool isVideo,
  }) async {
    final File? res;
    if (artworkDirectory == null || filename == null) {
      final tempThumbnailSavePath = FileParts.joinPath(AppDirs.APP_CACHE, "${trackPath.hashCode}.png");
      res = isVideo
          ? await NamidaFFMPEG.inst
              .extractVideoThumbnail(
                videoPath: trackPath,
                thumbnailSavePath: tempThumbnailSavePath,
              )
              .then((value) => value ? File(tempThumbnailSavePath) : null)
          : await NamidaFFMPEG.inst.extractAudioThumbnail(
              audioPath: trackPath,
              thumbnailSavePath: tempThumbnailSavePath,
            );
    } else {
      res = isVideo
          ? await ThumbnailManager.inst.extractVideoThumbnailAndSave(
              videoPath: trackPath,
              isLocal: true,
              idOrFileNameWithExt: filename,
              cacheDirPath: artworkDirectory,
              forceExtract: true,
            )
          : await NamidaFFMPEG.inst.extractAudioThumbnail(
              audioPath: trackPath,
              thumbnailSavePath: FileParts.joinPath(artworkDirectory, "$filename.png"),
            );
    }
    return res;
  }

  static bool get defaultUniqueArtworkHash => settings.uniqueArtworkHash.value;
  static bool get defaultGroupArtworksByAlbum => settings.groupArtworksByAlbum.value;
  static List<AlbumIdentifier> get defaultAlbumIdentifier => settings.albumIdentifiers.value;

  static Set<AlbumIdentifier> getAlbumIdentifiersSet() => defaultAlbumIdentifier.toSet();

  static String getArtworkIdentifier({
    required String? albumName,
    required String? albumArtist,
    required String? year,
    required Set<AlbumIdentifier> identifiers,
  }) {
    var buffer = StringBuffer();
    if (albumName != null && identifiers.contains(AlbumIdentifier.albumName)) buffer.write(albumName);
    if (albumArtist != null && identifiers.contains(AlbumIdentifier.albumArtist)) buffer.write(albumArtist);
    if (year != null && identifiers.contains(AlbumIdentifier.year)) buffer.write(year);
    return DownloadTaskFilename.cleanupFilename(buffer.toString());
  }

  static String getArtworkIdentifierFromInfo(FAudioModel? data, Set<AlbumIdentifier> identifiers) {
    return getArtworkIdentifier(
      albumName: data?.tags.album,
      albumArtist: data?.tags.albumArtist,
      year: data?.tags.year,
      identifiers: identifiers,
    );
  }
}

class ExtractingPathKey {
  int _initial = 0;
  ExtractingPathKey.create();

  // always use unique keys, reusing same event channels can result in indexing being stuck
  int next() => (_initial++) + DateTime.now().microsecondsSinceEpoch;
}
