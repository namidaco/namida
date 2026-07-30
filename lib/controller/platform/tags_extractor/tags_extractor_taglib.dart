part of 'tags_extractor.dart';

class _TagsExtractorTagLib extends TagsExtractor {
  _TagsExtractorTagLib._internal();

  _TagLibIsolateManager? _isolateWriteExecuter;
  int _isolateWriteExecuterClients = 0;

  @override
  Future<void> initializeForWrite() async {
    _isolateWriteExecuterClients++;
    if (_isolateWriteExecuter != null) return;

    _isolateWriteExecuter = _TagLibIsolateManager();
    await _isolateWriteExecuter!.initialize();
  }

  @override
  Future<void> disposeForWrite() async {
    _isolateWriteExecuterClients--;
    if (_isolateWriteExecuterClients <= 0) {
      await _isolateWriteExecuter?.dispose();
    }
  }

  @override
  Future<void> updateLogsPath() async {}

  @override
  Future<FAudioModel> extractMetadata({
    _TagLibIsolateManager? executer,
    required String trackPath,
    required bool extractArtwork,
    required String? artworkDirectory,
    Set<AlbumIdentifier>? identifiers,
    bool overrideArtwork = false,
    required bool isVideo,
    required bool isNetwork,
    String? networkId,
  }) async {
    final taglibInfo =
        await executer?.read(
          _TagLibIsolateRequestReadTags(
            path: trackPath,
            extractArtwork: extractArtwork,
          ),
        ) ??
        await TagLibRes.readIsolate(
          trackPath,
          extractArtwork: extractArtwork,
        );

    if (taglibInfo != null && isVideo) {
      try {
        // final stats = await File(trackPath).stat();
        // videoController.addLocalVideoFileInfoToCacheMap(trackPath, taglibInfo, stats);
      } catch (_) {}
    }

    final taglibInfoProps = taglibInfo?.properties;
    FArtwork artwork = taglibInfoProps?.artwork ?? FArtwork();
    if (extractArtwork && (artwork.file == null && artwork.bytes == null)) {
      if (artworkDirectory != null) {
        final filename = TagsExtractor.buildImageFilename(
          path: trackPath,
          identifiers: identifiers,
          isNetwork: isNetwork,
          networkId: networkId,
          infoCallback: () => (
            albumName: taglibInfoProps?.album,
            albumArtist: taglibInfoProps?.albumArtist,
            year: taglibInfoProps?.date,
            title: taglibInfoProps?.title,
            artist: taglibInfoProps?.artist,
          ),
          hashKeyCallback: () => trackPath.toFastHashKey(),
          parentDirPath: artworkDirectory,
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

    return taglibInfo?.toFAudioModel(artwork: artwork) ?? FAudioModel.dummy(trackPath, artwork);
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
    final executer = _TagLibIsolateManager();
    await executer.initialize();

    for (final path in paths) {
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

    try {
      bytes = await TagLibRes.getArtworkIsolate(trackPath);
    } catch (_) {}

    if (bytes == null) {
      final File? tempFile = await TagsExtractor.extractThumbnailCustom(
        trackPath: trackPath,
        filename: null,
        artworkDirectory: null,
        isVideo: isVideo,
      );
      bytes = await tempFile?.readAsBytes();
      tempFile?.tryDeleting();
    }

    return bytes == null ? null : FArtwork(bytes: bytes);
  }

  Future<String?> _writeTagsInternal({
    required String path,
    required FTags newTags,
  }) async {
    try {
      await initializeForWrite();
      return await _isolateWriteExecuter!.write(
        _TagLibIsolateRequestWriteTags(
          path: path,
          newTags: newTags,
        ),
      );
    } catch (e) {
      return e.toString();
    } finally {
      await disposeForWrite();
    }
  }

  @override
  Future<bool> writeTags({
    required String path,
    required FTags newTags,
    required String? commentToInsert,
    required String? oldComment,
    required bool displayFFmpegFallbackWarning,
  }) async {
    // -- 1. try tagger
    String? error = await _writeTagsInternal(
      path: path,
      newTags: newTags,
    );

    bool didUpdate = error == null || error == '';

    if (!didUpdate) {
      // -- 2. try with ffmpeg
      final ffmpegTagsMap = commentToInsert != null && commentToInsert.isNotEmpty
          ? <String, String?>{
              FFMPEGTagField.comment.tagKey: oldComment == null || oldComment.isEmpty ? commentToInsert : '$commentToInsert\n$oldComment',
            }
          : FFMPEGTagField.createTagsMapfromFTag(newTags);
      didUpdate = await ffmpegController.ffmpegEditMetadata(
        path: path,
        tagsMap: ffmpegTagsMap,
      );

      final imageFile = newTags.artwork.file;
      if (imageFile != null) {
        await ffmpegController.editAudioThumbnail(audioPath: path, thumbnailPath: imageFile.path);
      }
      if (displayFFmpegFallbackWarning) {
        snackyy(
          title: lang.warning,
          message: 'FFMPEG was used. Some tags might not have been updated',
          isError: true,
        );
      }
    }
    return didUpdate;
  }
}

class _TagLibIsolateManager with PortsProvider<SendPort> {
  _TagLibIsolateManager();

  final _completers = <int, Completer<dynamic>?>{};
  final _messageTokenWrapper = IsolateMessageTokenWrapper.create();

  Future<void> dispose() => disposePort();

  Future<TagLibRes?> read(_TagLibIsolateRequestReadTags request) async {
    return await _executeIsolate(request) as TagLibRes?;
  }

  Future<String?> write(_TagLibIsolateRequestWriteTags request) async {
    return await _executeIsolate(request) as String?;
  }

  Future<dynamic> _executeIsolate(_TagLibIsolateRequestBase request) async {
    if (!isInitialized) await initialize();
    final token = _messageTokenWrapper.getToken();
    _completers[token]?.complete(null); // useless but anyways
    final completer = _completers[token] = Completer<dynamic>();
    sendPort([token, request]);
    var res = await completer.future;
    if (res is _TagLibError) {
      logger.error('Error reading/writing tags', e: res.e, st: res.st);
      return null;
    }
    return res;
  }

  @override
  IsolateFunctionReturnBuild<SendPort> isolateFunction(SendPort port) {
    return IsolateFunctionReturnBuild(_prepareResourcesAndListen, port);
  }

  static void _prepareResourcesAndListen(SendPort sendPort) async {
    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (PortsProvider.isDisposeMessage(p)) {
        recievePort.close();
        streamSub?.cancel();
        return;
      }

      p as List;
      final token = p[0] as int;
      final request = p[1] as _TagLibIsolateRequestBase;

      try {
        final res = request.execute();
        sendPort.send([token, res]);
      } catch (e, st) {
        sendPort.send([token, _TagLibError(e, st)]);
        logger.error('Error reading tags', e: e, st: st);
        return;
      }
    });

    sendPort.send(null); // prepared
  }

  @override
  void onResult(result) {
    final token = result[0] as int;
    final completer = _completers.remove(token);
    if (completer != null && completer.isCompleted == false) {
      completer.complete(result[1]);
    }
  }
}

class _TagLibIsolateRequestReadTags extends _TagLibIsolateRequestBase<TagLibRes?> {
  final bool extractArtwork;
  const _TagLibIsolateRequestReadTags({required super.path, required this.extractArtwork});

  @override
  TagLibRes? execute() {
    return TagLibRes.readSync(
      path,
      extractArtwork: extractArtwork,
    );
  }
}

class _TagLibIsolateRequestWriteTags extends _TagLibIsolateRequestBase<String?> {
  final FTags newTags;
  const _TagLibIsolateRequestWriteTags({required super.path, required this.newTags});

  @override
  String? execute() {
    return TagLibRes.writeSync(
      path,
      newPropertiesMap: newTags.toTagLibMap(),
      artwork: newTags.artwork,
    );
  }
}

sealed class _TagLibIsolateRequestBase<T> {
  final String path;

  const _TagLibIsolateRequestBase({required this.path});

  T execute();
}

class _TagLibError {
  final Object e;
  final StackTrace st;

  const _TagLibError(
    this.e,
    this.st,
  );
}
