import 'dart:async';
import 'dart:io';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/platform/tags_extractor/tags_extractor.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart' show RxMap;

class NamidaTaggerController {
  static final NamidaTaggerController inst = NamidaTaggerController._internal();
  NamidaTaggerController._internal();

  final _extractor = TagsExtractor.platform();

  bool get _defaultKeepFileDates => settings.editTagsKeepFileDates.value;

  RxMap<int, String> get currentPathsBeingExtracted => _extractor.currentPathsBeingExtracted;

  Future<void> updateLogsPath() => _extractor.updateLogsPath();

  Future<Stream<FAudioModel>> extractMetadataAsStream({
    required List<String> paths,
    required ExtractingPathKey keyWrapper,
    required bool? extractArtwork,
    bool? saveArtworkToCache,
    bool overrideArtwork = false,
    required bool isNetwork,
  }) async {
    extractArtwork ??= settings.cacheArtworks.value; // no need to extract artwork while indexing if caching is disabled
    saveArtworkToCache ??= settings.cacheArtworks.value;
    return _extractor.extractMetadataAsStream(
      paths: paths,
      keyWrapper: keyWrapper,
      extractArtwork: extractArtwork,
      audioArtworkDirectory: saveArtworkToCache ? AppDirs.ARTWORKS : null,
      videoArtworkDirectory: saveArtworkToCache ? AppDirs.THUMBNAILS : null,
      overrideArtwork: overrideArtwork,
      isNetwork: isNetwork,
    );
  }

  Future<FAudioModel> extractMetadata({
    required String trackPath,
    required bool? extractArtwork,
    bool? saveArtworkToCache,
    String? cacheDirectoryPath,
    Set<AlbumIdentifier>? identifiers,
    bool overrideArtwork = false,
    required bool isVideo,
    required bool isNetwork,
    String? networkId,
  }) async {
    extractArtwork ??= settings.cacheArtworks.value;
    saveArtworkToCache ??= settings.cacheArtworks.value;
    final artworkDirectory = saveArtworkToCache ? cacheDirectoryPath ?? (isVideo ? AppDirs.THUMBNAILS : AppDirs.ARTWORKS) : null;
    return _extractor.extractMetadata(
      trackPath: trackPath,
      extractArtwork: extractArtwork,
      artworkDirectory: artworkDirectory,
      identifiers: identifiers,
      overrideArtwork: overrideArtwork,
      isVideo: isVideo,
      isNetwork: isNetwork,
      networkId: networkId,
    );
  }

  Future<FArtwork?> extractArtwork({
    required String trackPath,
    required bool isVideo,
  }) async {
    return _extractor.extractArtwork(
      trackPath: trackPath,
      isVideo: isVideo,
    );
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
    void Function(TrackStats newStats)? onStatsEdit,
  }) async {
    if (trimWhiteSpaces) {
      editedTags.updateAll((key, value) => value.trimAll());
    }

    final imageFile = imagePath.isNotEmpty ? File(imagePath) : null;

    String oldComment = '';
    if (commentToInsert.isNotEmpty) {
      final tr = tracks.first;
      if (tr.isPhysical) {
        // -- tho its almost always physical, but just in case since this fn can be used to update stats
        oldComment = await NamidaTaggerController.inst
            .extractMetadata(
              trackPath: tr.path,
              isVideo: tr is Video,
              extractArtwork: false,
              isNetwork: false,
            )
            .then((value) => value.tags.comment ?? '');
      }
    }

    final newTags = commentToInsert.isNotEmpty
        ? FTags(
            path: '',
            comment: oldComment.isEmpty ? commentToInsert : '$commentToInsert\n$oldComment',
            artwork: FArtwork(),
          )
        : FTags(
            path: '',
            artwork: FArtwork(file: imageFile),
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
            description: editedTags[TagField.description],
            synopsis: editedTags[TagField.synopsis],
            lyrics: editedTags[TagField.lyrics],
            remixer: editedTags[TagField.remixer],
            trackTotal: editedTags[TagField.trackTotal],
            discTotal: editedTags[TagField.discTotal],
            lyricist: editedTags[TagField.lyricist],
            language: editedTags[TagField.language],
            recordLabel: editedTags[TagField.recordLabel],
            country: editedTags[TagField.country],
            tags: editedTags[TagField.tags],
            ratingPercentage: () {
              final ratingString = editedTags[TagField.rating];
              if (ratingString != null) {
                return _ratingStringToPercentage(ratingString);
              }
              return null;
            }(),
          );

    const kStatsFields = {TagField.mood, TagField.tags, TagField.rating};
    final shouldEditStats = kStatsFields.any((f) => editedTags[f] != null);
    late final wantedToEditNonStatsTags = editedTags.keys.any((et) => kStatsFields.contains(et));

    final splittersConfigs = SplitArtistGenreConfigsWrapper.settings();
    final tracksMap = <Track, TrackExtended>{};
    for (int i = 0; i < tracks.length; i++) {
      var track = tracks[i];
      String? error;

      if (shouldEditStats && track.isNetwork) {
        final newStats = await Indexer.inst.updateTrackStats(
          tracks.first,
          ratingString: editedTags[TagField.rating],
          moodsString: editedTags[TagField.mood],
          tagsString: editedTags[TagField.tags],
        );
        onStatsEdit?.call(newStats);

        if (onEdit != null) {
          if (wantedToEditNonStatsTags) {
            error = 'Not Supported for network files';
            onEdit(false, error, track);
          } else {
            onEdit(true, error, track);
          }
        }
      } else {
        final file = File(track.path);
        bool fileExists = false;
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
            // -- 1. try tagger
            final didUpdate = await _extractor.writeTags(
              path: track.path,
              newTags: newTags,
              commentToInsert: commentToInsert,
              oldComment: oldComment,
            );

            if (didUpdate) {
              final trExt = track.toTrackExt();
              final newTrExt = trExt.copyWithTag(tag: newTags, splittersConfigs: splittersConfigs, generatePathHash: TagsExtractor.defaultUniqueArtworkHash);
              tracksMap[track] = newTrExt;
              if (imageFile != null) await imageFile.copy(newTrExt.pathToImage);
            }
            printo('Did Update Metadata: $didUpdate', isError: !didUpdate);
            if (onEdit != null) onEdit(didUpdate, error, track);

            // -- update app-related stats even if tags editing failed.
            if (shouldEditStats) {
              final newStats = await Indexer.inst.updateTrackStats(
                tracks.first,
                ratingString: editedTags[TagField.rating],
                moodsString: editedTags[TagField.mood],
                tagsString: editedTags[TagField.tags],
              );
              onStatsEdit?.call(newStats);
            }
          },
          keepStats: keepFileDates ?? _defaultKeepFileDates,
        );
      }
    }

    if (onUpdatingTracksStart != null) onUpdatingTracksStart();

    if (tracksMap.isNotEmpty) {
      await Indexer.inst.updateTrackMetadata(
        tracksMap: tracksMap,
        artworkWasEdited: imageFile != null,
      );
    }
  }

  double? _ratingStringToPercentage(String ratingString) {
    if (ratingString.isEmpty) return 0.0;
    final intval = int.tryParse(ratingString);
    if (intval == null) return null;
    return intval / 100;
  }
}
