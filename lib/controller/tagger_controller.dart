import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:queue/queue.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';

class FAudioTaggerController {
  static final FAudioTaggerController inst = FAudioTaggerController._internal();
  FAudioTaggerController._internal() {
    _channel.invokeMethod("setLogFile", {"path": AppPaths.LOGS_TAGGER});
  }

  late final MethodChannel _channel = const MethodChannel('faudiotagger');

  bool get _defaultGroupArtworksByAlbum => settings.groupArtworksByAlbum.value;
  List<AlbumIdentifier> get _defaultAlbumIdentifier => settings.albumIdentifiers;
  bool get _defaultKeepFileDates => settings.editTagsKeepFileDates.value;

  Future<FAudioModel> _readAllData({
    required String path,
    String? artworkDirectory,
    bool extractArtwork = true,
    bool overrideArtwork = false,
  }) async {
    final map = await _channel.invokeMethod<Map<Object?, Object?>?>("readAllData", {
      "path": path,
      "artworkDirectory": artworkDirectory,
      "extractArtwork": extractArtwork,
      "overrideArtwork": overrideArtwork,
      "artworkIdentifiers": _defaultGroupArtworksByAlbum ? _defaultAlbumIdentifier.map((e) => e.index).toList() : null,
    });
    try {
      return FAudioModel.fromMap(map!.cast());
    } catch (e) {
      return FAudioModel.dummy(map?["path"] as String?);
    }
  }

  Future<Stream<Map<String, dynamic>>> _readAllDataAsStream({
    required int streamKey,
    required List<String> paths,
    String? artworkDirectory,
    bool extractArtwork = true,
    bool overrideArtwork = false,
  }) async {
    await _channel.invokeMethod("readAllDataAsStream", {
      "streamKey": streamKey,
      "paths": paths,
      "artworkDirectory": artworkDirectory,
      "extractArtwork": extractArtwork,
      "overrideArtwork": overrideArtwork,
      "artworkIdentifiers": _defaultGroupArtworksByAlbum ? _defaultAlbumIdentifier.map((e) => e.index).toList() : null,
    });
    final channelEvent = EventChannel('faudiotagger/stream/$streamKey');
    return channelEvent.receiveBroadcastStream().map((event) {
      final message = event as Map<Object?, Object?>;
      final map = message.cast<String, dynamic>();
      return map;
    });
  }

  Future<String?> writeTags({
    required String path,
    required FTags tags,
  }) async {
    try {
      return await _channel.invokeMethod<String?>("writeTags", {
        "path": path,
        "tags": tags.toMap(),
      });
    } catch (e) {
      return e.toString();
    }
  }

  final _streamControllers = <int, StreamController<FAudioModel>>{};

  Future<Stream<FAudioModel>> extractMetadataAsStream({
    required List<String> paths,
    bool extractArtwork = true,
    bool saveArtworkToCache = true,
    bool fallbackToFFMPEG = true,
    bool overrideArtwork = false,
  }) async {
    final streamKey = DateTime.now().microsecondsSinceEpoch;
    final identifiersMap = _getIdentifiersMap();
    final artworkDirectory = saveArtworkToCache ? AppDirs.ARTWORKS : null;
    final initialStream = await _readAllDataAsStream(
      streamKey: streamKey,
      paths: paths,
      extractArtwork: extractArtwork,
      artworkDirectory: artworkDirectory,
      overrideArtwork: overrideArtwork,
    );
    StreamSubscription<dynamic>? streamSub;
    final usingStream = Completer<void>();
    int toExtract = paths.length;

    _streamControllers[streamKey] = StreamController<FAudioModel>();
    final streamController = _streamControllers[streamKey]!;

    Future<void> closeStreams() async {
      await usingStream.future;
      streamController.close();
      streamSub?.cancel();
      _streamControllers.remove(streamKey);
    }

    void onExtract(FAudioModel info) {
      streamController.add(info);
      toExtract--;
      if (toExtract <= 0) usingStream.completeIfWasnt();
    }

    streamSub = initialStream.listen(
      (map) {
        if (map["ERROR_FAULTY"] == true) {
          extractMetadata(
            trackPath: map['path'] as String,
            tagger: false,
            ffmpeg: fallbackToFFMPEG,
            saveArtworkToCache: saveArtworkToCache,
            identifiers: identifiersMap,
            extractArtwork: extractArtwork,
            overrideArtwork: overrideArtwork,
          ).then(onExtract);
        } else {
          try {
            onExtract(FAudioModel.fromMap(map));
          } catch (e) {
            onExtract(FAudioModel.dummy(map['path'] as String));
          }
        }
      },
      onDone: closeStreams,
      onError: (e) => closeStreams(),
    );
    return streamController.stream;
  }

  final _ffmpegQueue = Queue(timeout: const Duration(seconds: 5)); // concurrent execution can result in being stuck

  Future<FAudioModel> extractMetadata({
    required String trackPath,
    bool tagger = true,
    bool ffmpeg = true,
    bool extractArtwork = true,
    bool saveArtworkToCache = true,
    String? cacheDirectoryPath,
    Map<AlbumIdentifier, bool>? identifiers,
    bool overrideArtwork = false,
  }) async {
    final artworkDirectory = saveArtworkToCache ? cacheDirectoryPath ?? AppDirs.ARTWORKS : null;

    FAudioModel? trackInfo;

    if (tagger) {
      trackInfo = await _readAllData(
        path: trackPath,
        artworkDirectory: artworkDirectory,
        extractArtwork: extractArtwork,
        overrideArtwork: overrideArtwork,
      );
    }

    if (ffmpeg) {
      if (trackInfo == null || trackInfo.hasError) {
        // final ffmpegInfo = await NamidaFFMPEG.inst.extractMetadata(trackPath);
        final ffmpegInfo = await _ffmpegQueue.add(() => NamidaFFMPEG.inst.extractMetadata(trackPath));
        if (ffmpegInfo != null) trackInfo = ffmpegInfo.toFAudioModel();
      }
      if (extractArtwork && trackInfo != null && !trackInfo.hasError) {
        if (artworkDirectory != null) {
          // specified directory to save in, the file is expected to exist here.
          File? artworkFile = trackInfo.tags.artwork.file;
          if (artworkFile == null || !await artworkFile.exists()) {
            final identifiersMap = identifiers ?? _getIdentifiersMap();
            final filename = _defaultGroupArtworksByAlbum ? getArtworkIdentifierFromInfo(trackInfo, identifiersMap) : trackPath.getFilename;
            final res = await NamidaFFMPEG.inst.extractAudioThumbnail(
              audioPath: trackPath,
              thumbnailSavePath: "$artworkDirectory/$filename.png",
            );
            trackInfo.tags.artwork.file = res;
          }
        } else {
          // -- otherwise the artwork should be within info as bytes.
          Uint8List? artworkBytes = trackInfo.tags.artwork.bytes;
          if (artworkBytes == null || artworkBytes.isEmpty) {
            final tempFile = await NamidaFFMPEG.inst.extractAudioThumbnail(
              audioPath: trackPath,
              thumbnailSavePath: "${AppDirs.APP_CACHE}/${trackPath.hashCode}.png",
            );
            trackInfo.tags.artwork.bytes = await tempFile?.readAsBytes();
            tempFile?.tryDeleting();
          }
        }
      }
    }

    return trackInfo ?? FAudioModel.dummy(trackPath);
  }

  Future<File?> copyArtworkToCache({
    required String trackPath,
    required TrackExtended trackExtended,
    required File artworkFile,
  }) async {
    final filename = _defaultGroupArtworksByAlbum
        ? getArtworkIdentifier(
            albumName: trackExtended.album,
            albumArtist: trackExtended.albumArtist,
            year: trackExtended.year.toString(),
            identifiers: _getIdentifiersMap(),
          )
        : trackPath.getFilename;
    try {
      return await artworkFile.copy("${AppDirs.ARTWORKS}$filename.png");
    } catch (e) {
      printy(e, isError: true);
      return null;
    }
  }

  /// [commentToInsert] is applicable for first track only
  Future<void> updateTracksMetadata({
    required List<Track> tracks,
    required Map<TagField, String> editedTags,
    required bool trimWhiteSpaces,
    String imagePath = '',
    String commentToInsert = '',
    void Function(bool didUpdate, String? error, Track track)? onEdit,
    void Function()? onUpdatingTracksStart,
    bool? keepFileDates,
  }) async {
    if (trimWhiteSpaces) {
      editedTags.updateAll((key, value) => value.trimAll());
    }

    final shouldUpdateArtwork = imagePath != '';

    String oldComment = '';
    if (commentToInsert != '') {
      oldComment = await FAudioTaggerController.inst.extractMetadata(trackPath: tracks.first.path).then((value) => value.tags.comment ?? '');
    }
    final newTags = commentToInsert != ''
        ? FTags(
            path: '',
            comment: oldComment == '' ? commentToInsert : '$commentToInsert\n$oldComment',
            artwork: FArtwork(),
          )
        : FTags(
            path: '',
            artwork: FArtwork(file: shouldUpdateArtwork ? File(imagePath) : null),
            title: editedTags[TagField.title],
            album: editedTags[TagField.album],
            artist: editedTags[TagField.artist],
            albumArtist: editedTags[TagField.albumArtist],
            composer: editedTags[TagField.composer],
            genre: editedTags[TagField.genre],
            mood: editedTags[TagField.mood],
            trackNumber: editedTags[TagField.trackNumber],
            discNumber: editedTags[TagField.discNumber],
            year: editedTags[TagField.year],
            comment: editedTags[TagField.comment],
            lyrics: editedTags[TagField.lyrics],
            remixer: editedTags[TagField.remixer],
            trackTotal: editedTags[TagField.trackTotal],
            discTotal: editedTags[TagField.discTotal],
            lyricist: editedTags[TagField.lyricist],
            language: editedTags[TagField.language],
            recordLabel: editedTags[TagField.recordLabel],
            country: editedTags[TagField.country],
          );

    final tracksMap = <Track, TrackExtended>{};
    for (final track in tracks) {
      final file = File(track.path);
      bool fileExists = false;
      String? error;

      try {
        fileExists = await file.exists();
        if (!fileExists) error = 'file not found';
      } catch (e) {
        error = e.toString();
      }

      if (error != null) {
        printo('Did Update Metadata: false', isError: true);
        if (onEdit != null) onEdit(false, error, track);
        continue;
      }

      await file.executeAndKeepStats(
        () async {
          bool didUpdate = false;

          // -- 1. try tagger
          error = await FAudioTaggerController.inst.writeTags(
            path: track.path,
            tags: newTags,
          );

          // didUpdate = error == null || error == '';

          if (!didUpdate) {
            // -- 2. try with ffmpeg
            final ffmpegTagsMap = commentToInsert != ''
                ? <String, String?>{
                    FFMPEGTagField.comment: oldComment == '' ? commentToInsert : '$commentToInsert\n$oldComment',
                  }
                : <String, String?>{
                    FFMPEGTagField.title: editedTags[TagField.title],
                    FFMPEGTagField.artist: editedTags[TagField.artist],
                    FFMPEGTagField.album: editedTags[TagField.album],
                    FFMPEGTagField.albumArtist: editedTags[TagField.albumArtist],
                    FFMPEGTagField.composer: editedTags[TagField.composer],
                    FFMPEGTagField.genre: editedTags[TagField.genre],
                    FFMPEGTagField.mood: editedTags[TagField.mood],
                    FFMPEGTagField.year: editedTags[TagField.year],
                    FFMPEGTagField.trackNumber: editedTags[TagField.trackNumber],
                    FFMPEGTagField.discNumber: editedTags[TagField.discNumber],
                    FFMPEGTagField.trackTotal: editedTags[TagField.trackTotal],
                    FFMPEGTagField.discTotal: editedTags[TagField.discTotal],
                    FFMPEGTagField.comment: editedTags[TagField.comment],
                    FFMPEGTagField.lyrics: editedTags[TagField.lyrics],
                    FFMPEGTagField.remixer: editedTags[TagField.remixer],
                    FFMPEGTagField.lyricist: editedTags[TagField.lyricist],
                    FFMPEGTagField.language: editedTags[TagField.language],
                    FFMPEGTagField.recordLabel: editedTags[TagField.recordLabel],
                    FFMPEGTagField.country: editedTags[TagField.country],
                  };
            didUpdate = await NamidaFFMPEG.inst.editMetadata(
              path: track.path,
              tagsMap: ffmpegTagsMap,
            );
          }
          if (didUpdate) {
            final trExt = track.toTrackExt();
            tracksMap[track] = trExt.copyWithTag(tag: newTags);
          }
          printo('Did Update Metadata: $didUpdate', isError: !didUpdate);
          if (onEdit != null) onEdit(didUpdate, error, track);
        },
        keepStats: keepFileDates ?? _defaultKeepFileDates,
      );
    }

    if (onUpdatingTracksStart != null) onUpdatingTracksStart();

    if (tracksMap.isNotEmpty) {
      await Indexer.inst.updateTrackMetadata(
        tracksMap: tracksMap,
        newArtworkPath: imagePath,
      );
    }
  }

  String getArtworkIdentifierFromInfo(FAudioModel? data, Map<AlbumIdentifier, bool> identifiers) {
    return getArtworkIdentifier(
      albumName: data?.tags.album,
      albumArtist: data?.tags.albumArtist,
      year: data?.tags.year,
      identifiers: identifiers,
    );
  }

  String getArtworkIdentifier({
    required String? albumName,
    required String? albumArtist,
    required String? year,
    required Map<AlbumIdentifier, bool> identifiers,
  }) {
    final n = identifiers[AlbumIdentifier.albumName] == true ? albumName ?? '' : '';
    final aa = identifiers[AlbumIdentifier.albumArtist] == true ? albumArtist ?? '' : '';
    final y = identifiers[AlbumIdentifier.year] == true ? year ?? '' : '';
    return "$n$aa$y";
  }

  Map<AlbumIdentifier, bool> _getIdentifiersMap() {
    final map = <AlbumIdentifier, bool>{};
    _defaultAlbumIdentifier.loop((e, _) => map[e] = true);
    return map;
  }
}
