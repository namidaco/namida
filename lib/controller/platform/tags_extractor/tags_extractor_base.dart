part of 'tags_extractor.dart';

abstract class TagsExtractor {
  final NamidaFFMPEG ffmpegController;
  final VideoController videoController;

  TagsExtractor() : this.ffmpegController = NamidaFFMPEG.inst, this.videoController = VideoController.inst;

  static TagsExtractor platform() {
    return NamidaPlatformBuilder.init(
      android: () => _TagsExtractorAndroid._init(),
      windows: () => _TagsExtractorDesktop._internal(),
      linux: () => _TagsExtractorDesktop._internal(),
    );
  }

  final _streamControllers = <int, StreamController<FAudioModel>>{};
  final currentPathsBeingExtracted = <int, String>{}.obs;

  Future<void> updateLogsPath();

  Future<FAudioModel> extractMetadata({
    required String trackPath,
    required bool extractArtwork,
    required String? artworkDirectory,
    Set<AlbumIdentifier>? identifiers,
    bool overrideArtwork = false,
    required bool isVideo,
    required bool isNetwork,
    String? networkId,
  });

  FutureOr<Stream<FAudioModel>> extractMetadataAsStream({
    required List<String> paths,
    required ExtractingPathKey keyWrapper,
    required bool extractArtwork,
    required String? audioArtworkDirectory,
    required String? videoArtworkDirectory,
    bool overrideArtwork = false,
    required bool isNetwork,
  });

  Future<FArtwork?> extractArtwork({
    required String trackPath,
    required bool isVideo,
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
    bool overrideOldArtwork = false,
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
              forceExtract: overrideOldArtwork,
            )
          : await NamidaFFMPEG.inst.extractAudioThumbnail(
              audioPath: trackPath,
              thumbnailSavePath: FileParts.joinPath(artworkDirectory, filename),
              forceReExtract: overrideOldArtwork,
            );
    }
    return res;
  }

  static bool get defaultUniqueArtworkHash => settings.uniqueArtworkHash.value;
  static bool get defaultGroupArtworksByAlbum => settings.groupArtworksByAlbum.value;
  static List<AlbumIdentifier> get defaultAlbumIdentifier => settings.albumIdentifiers.value;

  static Set<AlbumIdentifier> getAlbumIdentifiersSet() => defaultAlbumIdentifier.toSet();

  static String buildImageFilenameFromTrack({required Track track, String? networkId, required TrackExtended? trExt}) {
    return TagsExtractor.buildImageFilename(
      path: track.path,
      isNetwork: track.isNetwork,
      networkId: networkId,
      identifiers: null,
      identifierCallback: () => trExt?.albumIdentifierWrapper?.resolved(),
      infoCallback: () => (
        albumName: trExt?.album,
        albumArtist: trExt?.albumArtist,
        year: trExt?.year.toString(),
        title: trExt?.title,
        artist: trExt?.originalArtist,
      ),
      hashKeyCallback: () => trExt?.hashKey ?? track.path.toFastHashKey(),
    );
  }

  static String buildImageFilename({
    required String path,
    required Set<AlbumIdentifier>? identifiers,
    required bool? isNetwork,
    String? networkId,
    String? Function()? identifierCallback,
    required ({
      String? albumName,
      String? albumArtist,
      String? year,
      String? title,
      String? artist,
    })
    Function()
    infoCallback,
    required String? Function() hashKeyCallback,
  }) {
    final woext = buildImageFilenameWOExt(
      path: path,
      identifiers: identifiers,
      isNetwork: isNetwork,
      networkId: networkId,
      identifierCallback: identifierCallback,
      infoCallback: infoCallback,
      hashKeyCallback: hashKeyCallback,
    );
    return '$woext.png';
  }

  static String buildImageFilenameWOExt({
    required String path,
    required Set<AlbumIdentifier>? identifiers,
    required bool? isNetwork,
    String? networkId,
    String? Function()? identifierCallback,
    required ({
      String? albumName,
      String? albumArtist,
      String? year,
      String? title,
      String? artist,
    })
    Function()
    infoCallback,
    required String? Function() hashKeyCallback,
  }) {
    final identifiersSet = identifiers ?? TagsExtractor.getAlbumIdentifiersSet();
    if (TagsExtractor.defaultGroupArtworksByAlbum) {
      if (identifierCallback != null) {
        final id = identifierCallback();
        if (id != null && id.isNotEmpty) return id;
      }

      final info = infoCallback();
      final id = TagsExtractor.getArtworkIdentifier(
        albumName: info.albumName,
        albumArtist: info.albumArtist,
        year: info.year,
        identifiers: identifiersSet,
      );
      if (id.isNotEmpty) return id;
    }
    String filename;
    isNetwork ??= path.startsWith('http');
    if (isNetwork) {
      final info = infoCallback();
      filename = DownloadTaskFilename.cleanupFilename(
        [
          info.artist ?? '',
          info.title ?? '',
          networkId ?? MusicWebServer.baseUrlToId(path) ?? '',
        ].joinText(separator: ' - '),
      );
    } else {
      filename = path.getFilename;
    }

    if (TagsExtractor.defaultUniqueArtworkHash) {
      final key = hashKeyCallback();
      if (key != null) {
        return "${filename}_$key";
      }
    }
    return filename;
  }

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
