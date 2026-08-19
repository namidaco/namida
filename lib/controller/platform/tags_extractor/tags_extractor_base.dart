part of 'tags_extractor.dart';

abstract class TagsExtractor {
  final NamidaFFMPEG ffmpegController;
  final VideoController videoController;

  TagsExtractor() : this.ffmpegController = NamidaFFMPEG.inst, this.videoController = VideoController.inst;

  static TagsExtractor platform() {
    return _TagsExtractorTagLib._internal();
    // return NamidaPlatformBuilder.init(
    //   android: () => _TagsExtractorAndroid._init(),
    //   windows: () => _TagsExtractorDesktop._internal(),
    //   linux: () => _TagsExtractorDesktop._internal(),
    // );
  }

  final _streamControllers = <int, StreamController<FAudioModel>>{};
  final currentPathsBeingExtracted = <int, String>{}.obsThrottle(const Duration(milliseconds: 20));

  static final _safDeniedVolumes = <String>{};
  static void resetSafDeniedVolumes() => _safDeniedVolumes.clear();

  Future<void> initializeForWrite();
  Future<void> disposeForWrite();

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

  Future<String?> writeTags({
    required String path,
    required FTags newTags,
    required String? commentToInsert,
    required String? oldComment,
    required bool displayFFmpegFallbackWarning,
  });

  static Future<String?> _canWriteDirectlyOrError(String path) async {
    try {
      final raf = await File(path).open(mode: FileMode.append);
      await raf.close();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> executeWriteWithSafFallback({
    required String path,
    required Future<String?> Function(String effectivePath) operation,
  }) async {
    String? error;

    // -- the reason we try first is because all file permission is required, so usually saf is not required
    // -- except on android <= 10 sdcard, where there is no other way to grant permission
    error = await operation(path);
    if (error == null) return null;

    if (!Platform.isAndroid) return 'Unknown Error'; // -- below is for saf, which is android only

    // -- but even if for heavenly reasons we bypassed permission, let's just give it a try with saf
    // -- (uncomment to enfore permission)
    // if (NamidaFeaturesAvailablity.android11and_plus.resolve()) return 'Grant all-files-access permission instead';

    final originalFile = File(path);
    if (!await originalFile.exists()) return 'File does not exist';

    // -- write failed for a reason other than permission, saf won't help
    error = await _canWriteDirectlyOrError(path);
    if (error != null) return error;

    final storage = NamidaStorage.inst;
    bool hasAccess = await storage.safHasAccess(path);
    if (!hasAccess) {
      final directoryPath = path.getDirectoryPath;
      if (_safDeniedVolumes.contains(directoryPath)) return 'Permission for "$directoryPath" was denied';
      hasAccess = await storage.safRequestAccess(path, note: 'Please select grand access to "$directoryPath" to allow editing files inside it');
      if (!hasAccess) {
        _safDeniedVolumes.add(directoryPath);
        return 'Storage access was not granted, cannot edit "$path"';
      }
    }

    String ext = '';
    try {
      ext = path.getExtension;
    } catch (_) {}
    final tempFile = FileParts.join(AppDirs.APP_CACHE, '.saf_tag_edit_${path.hashCode}${ext.isEmpty ? '' : '.$ext'}');
    try {
      await originalFile.copy(tempFile.path);
    } catch (e) {
      error = e.toString();
      return error;
    }

    try {
      error = await operation(tempFile.path);
      error ??= await storage.safCopyFile(tempFile.path, path);
    } catch (e) {
      error = e.toString();
    } finally {
      tempFile.tryDeleting();
    }
    return error;
  }

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

  static String buildImageFilenameFromTrack({required Track track, String? networkId, required TrackExtended? trExt, required String parentDirPath}) {
    return TagsExtractor.buildImageFilename(
      path: track.path,
      isNetwork: track.isNetwork,
      networkId: networkId,
      identifiers: null,
      identifierCallback: () => trExt?.albumsIdentifiersWrappers.map((e) => e.resolved()).join(),
      infoCallback: () => (
        albumName: trExt?.originalAlbum,
        albumArtist: trExt?.albumArtist,
        year: trExt?.year.toString(),
        mbAlbumId: trExt?.albumsIdentifiersWrappers.firstOrNull?.mbAlbumId,
        mbAlbumArtistId: trExt?.albumsIdentifiersWrappers.firstOrNull?.mbAlbumArtistId,
        title: trExt?.title,
        artist: trExt?.originalArtist,
      ),
      hashKeyCallback: () => trExt?.hashKey ?? track.path.toFastHashKey(),
      parentDirPath: parentDirPath,
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
      String? mbAlbumId,
      String? mbAlbumArtistId,
      String? title,
      String? artist,
    })
    Function()
    infoCallback,
    required String? Function() hashKeyCallback,
    required String parentDirPath,
  }) {
    final woext = buildImageFilenameWOExt(
      path: path,
      identifiers: identifiers,
      isNetwork: isNetwork,
      networkId: networkId,
      identifierCallback: identifierCallback,
      infoCallback: infoCallback,
      hashKeyCallback: hashKeyCallback,
      parentDirPath: parentDirPath,
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
      String? mbAlbumId,
      String? mbAlbumArtistId,
      String? title,
      String? artist,
    })
    Function()
    infoCallback,
    required String? Function() hashKeyCallback,
    required String parentDirPath,
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
        mbAlbumId: info.mbAlbumId,
        mbAlbumArtistId: info.mbAlbumArtistId,
        identifiers: identifiersSet,
        parentDirPath: parentDirPath,
      );
      if (id.isNotEmpty) return id;
    }
    String filename;
    isNetwork ??= path.startsWith('http');
    if (isNetwork) {
      final info = infoCallback();
      filename = DownloadTaskFilename.cleanupFilename(
        [
          info.title ?? '',
          networkId ?? MusicWebServer.baseUrlToId(path) ?? '',
        ].joinText(separator: ' - '),
        parentDirPath: parentDirPath,
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
    required String? mbAlbumId,
    required String? mbAlbumArtistId,
    required Set<AlbumIdentifier> identifiers,
    required String parentDirPath,
  }) {
    var buffer = StringBuffer();
    if (albumName != null && identifiers.contains(AlbumIdentifier.albumName)) buffer.write(albumName);
    if (albumArtist != null && identifiers.contains(AlbumIdentifier.albumArtist)) buffer.write(albumArtist);
    if (year != null && identifiers.contains(AlbumIdentifier.year)) buffer.write(year);
    if (mbAlbumId != null && identifiers.contains(AlbumIdentifier.mbAlbumId)) buffer.write(mbAlbumId);
    if (mbAlbumArtistId != null && identifiers.contains(AlbumIdentifier.mbAlbumArtistId)) buffer.write(mbAlbumArtistId);
    return DownloadTaskFilename.cleanupFilename(
      buffer.toString(),
      parentDirPath: parentDirPath,
    );
  }

  static String getArtworkIdentifierFromInfo(FAudioModel? data, Set<AlbumIdentifier> identifiers, String parentDirPath) {
    return getArtworkIdentifier(
      albumName: data?.tags.album,
      albumArtist: data?.tags.albumArtist,
      year: data?.tags.year,
      mbAlbumId: data?.tags.mbAlbumId,
      mbAlbumArtistId: data?.tags.mbAlbumArtistId,
      identifiers: identifiers,
      parentDirPath: parentDirPath,
    );
  }
}

class ExtractingPathKey {
  int _initial = 0;
  ExtractingPathKey.create();

  // always use unique keys, reusing same event channels can result in indexing being stuck
  int next() => (_initial++) + DateTime.now().microsecondsSinceEpoch;
}
