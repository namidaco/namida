import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/file_parts.dart';
import 'package:namida/class/media_info.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

import 'platform/ffmpeg_executer/ffmpeg_executer.dart';

class NamidaFFMPEG {
  static NamidaFFMPEG get inst => _instance;
  static final NamidaFFMPEG _instance = NamidaFFMPEG._internal();
  NamidaFFMPEG._internal();

  static Future<void> configure() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await [
        FFmpegKitConfig.disableLogs(),
        FFmpegKitConfig.setSessionHistorySize(900),
      ].executeAllAndSilentReportErrors();
    }
  }

  final _executer = FFMPEGExecuter.platform()..init();

  Future<bool> supportsWebDAV() => _executer.supportsWebDAV();
  Future<bool> supportsSMB() => _executer.supportsSMB();

  final currentOperations = <OperationType, Rx<OperationProgress>>{
    OperationType.imageCompress: OperationProgress().obs,
    OperationType.ytdlpThumbnailFix: OperationProgress().obs,
  };

  Future<MediaInfo?> ffmpegExtractMetadata(String path) async {
    return _executer.extractMetadata(path);
  }

  Future<bool> ffmpegEditMetadata({
    required String path,
    MIFormatTags? oldTags,
    required Map<String, String?> tagsMap,
    bool keepFileStats = true,
  }) async {
    final originalFile = File(path);
    final originalStats = keepFileStats ? await originalFile.stat() : null;
    String ext = 'm4a';
    try {
      ext = path.getExtension;
    } catch (_) {}
    final cacheFile = FileParts.join(AppDirs.INTERNAL_STORAGE, ".temp_${path.hashCode}.$ext");

    // if (tagsMap[FFMPEGTagField.trackNumber] != null || tagsMap[FFMPEGTagField.discNumber] != null) {
    //   oldTags ??= await extractMetadata(path).then((value) => value?.format?.tags);
    //   void plsAddDT(String valInMap, (String, String?)? trackOrDisc) {
    //     if (trackOrDisc != null) {
    //       final trackN = trackOrDisc.$1;
    //       final trackT = trackOrDisc.$2;
    //       if (trackT == null && trackN != "0") {
    //         tagsMapToEditConverted[valInMap] = trackN;
    //       } else if (trackT != null) {
    //         tagsMapToEditConverted[valInMap] = "${trackOrDisc.$1}/${trackOrDisc.$2}";
    //       }
    //     }
    //   }

    //   final trackNT = _trackAndDiscSplitter(oldTags?.track);
    //   final discNT = _trackAndDiscSplitter(oldTags?.disc);
    //   plsAddDT("track", (tagsMapToEditConverted["track"] ?? trackNT?.$1 ?? "0", trackNT?.$2));
    //   plsAddDT("disc", (tagsMapToEditConverted["disc"] ?? discNT?.$1 ?? "0", trackNT?.$2));
    // }

    final params = [
      '-i',
      originalFile.path,
    ];

    final oldTagsToApply = <String, String>{};
    final oldMetadata = await ffmpegExtractMetadata(originalFile.path);

    // -- not all of them but always one of them
    const opusEtcFormats = {'opus', 'ogg', 'oga', 'ogx', 'flac', 'alac'};

    bool isOpusEtc() {
      if (oldMetadata == null) return false;
      final formatName = oldMetadata.format?.formatName;
      if (formatName != null && opusEtcFormats.contains(formatName.toLowerCase())) {
        return true;
      }
      final oldMetadataStreams = oldMetadata.streams;
      if (oldMetadataStreams != null) {
        for (final stream in oldMetadataStreams) {
          final streamName = stream.codecName;
          if (streamName != null && opusEtcFormats.contains(streamName.toLowerCase())) {
            return true;
          }
        }
      }
      return false;
    }

    if (isOpusEtc()) {
      // -- overwriting tags for opus is not supported, we need to remove all first (-map_metadata -1) and write all combined
      final tags = oldMetadata?.toFAudioModel(artwork: null).tags;
      if (tags != null) {
        final oldTags = FFMPEGTagField.createTagsMapfromFTag(tags);
        for (final e in oldTags.entries) {
          if (tagsMap[e.key] != null) continue;

          final val = e.value;
          if (val != null) {
            oldTagsToApply[e.key] = val;
          }
        }
      }

      if (oldTagsToApply.isNotEmpty) {
        params.addAll(
          [
            '-map_metadata',
            '-1',
            '-disposition:v',
            'attached_pic',
          ],
        );
      }
    }

    for (final e in tagsMap.entries.followedBy(oldTagsToApply.entries)) {
      final val = e.value;
      if (val != null) {
        final valueCleaned = val.replaceAll('"', r'\"');
        params.add('-metadata');
        params.add('${e.key}=$valueCleaned');
      }
    }

    params.addAll([
      '-id3v2_version',
      '3',
      '-write_id3v2',
      '1',
      '-c',
      'copy',
      '-y',
      cacheFile.path,
    ]);

    final didSuccess = await _executer.ffmpegExecute(params);

    return await _ensureFileValidBeforeMovingBack(
      didSuccess,
      originalFile,
      cacheFile,
      originalStats,
    );
  }

  Future<File?> extractAudioThumbnail({
    required String audioPath,
    required String thumbnailSavePath,
    bool compress = false,
    bool forceReExtract = false,
  }) async {
    if (!forceReExtract && await File(thumbnailSavePath).exists()) {
      return File(thumbnailSavePath);
    }

    final codecParams = compress ? ['-filter:v', 'scale=-2:250', '-an'] : ['-c', 'copy'];

    bool didSuccess = await _executer.ffmpegExecute(['-i', audioPath, '-map', '0:v', '-map', '-0:V', ...codecParams, '-y', thumbnailSavePath]);
    if (didSuccess) return File(thumbnailSavePath);

    didSuccess = await _executer.ffmpegExecute(['-i', audioPath, '-an', '-c:v', 'copy', '-y', thumbnailSavePath]);
    if (didSuccess) return File(thumbnailSavePath);

    return null;
  }

  Future<bool> editAudioThumbnail({
    required String audioPath,
    required String thumbnailPath,
    bool keepOriginalFileStats = true,
  }) async {
    final audioFile = File(audioPath);
    final originalStats = keepOriginalFileStats ? await audioFile.stat() : null;

    String ext = 'm4a';
    try {
      ext = audioPath.getExtension;
    } catch (_) {}

    final isVideoFile = NamidaFileExtensionsWrapper.video.isExtensionValid(ext);
    final cacheFile = FileParts.join(AppDirs.APP_CACHE, "${audioPath.hashCode}.$ext");
    final didSuccess = await _executer.ffmpegExecute([
      '-i',
      audioPath,
      '-i',
      thumbnailPath,
      '-map',
      '0:a?',
      if (isVideoFile) ...[
        '-map',
        '0:v:0?',
      ],
      '-map',
      '1',
      '-c',
      'copy',
      isVideoFile ? '-disposition:v:1' : '-disposition:v:0',
      'attached_pic',
      '-y',
      cacheFile.path,
    ]);

    return await _ensureFileValidBeforeMovingBack(
      didSuccess,
      audioFile,
      cacheFile,
      originalStats,
    );
  }

  Future<bool> _ensureFileValidBeforeMovingBack(bool didSuccess, File originalFile, File cacheFile, FileStat? originalStats) async {
    bool canSafelyMoveBack = false;
    try {
      int? preferredMinSize;
      if (originalStats != null) {
        if (originalStats.size > 0) {
          preferredMinSize = (originalStats.size * 0.1).round().withMinimum(1);
        }
      }
      preferredMinSize ??= 0;
      canSafelyMoveBack = didSuccess && await cacheFile.exists() && await cacheFile.length() > preferredMinSize;
    } catch (_) {}

    try {
      if (canSafelyMoveBack) {
        // -- only move output file back in case of success.
        await cacheFile.copy(originalFile.path);
        if (originalStats != null) {
          await setFileStats(originalFile, originalStats);
        }
      }
    } finally {
      cacheFile.tryDeleting();
    }

    return canSafelyMoveBack;
  }

  Future<bool> setFileStats(File file, FileStat stats) async {
    try {
      await file.setLastAccessed(stats.accessed);
      await file.setLastModified(stats.modified);
      return true;
    } catch (e) {
      printy(e, isError: true);
      return false;
    }
  }

  Future<bool> compressImage({
    required String path,
    required String saveDir,
    bool keepOriginalFileStats = true,
    int percentage = 50,
  }) async {
    assert(percentage >= 0 && percentage <= 100);

    final toQSC = (percentage / 3.2).round();

    final imageFile = File(path);
    final originalStats = keepOriginalFileStats ? await imageFile.stat() : null;
    final newFilePath = FileParts.joinPath(saveDir, "${path.getFilenameWOExt}.jpg");
    final didSuccess = await _executer.ffmpegExecute(['-i', path, '-qscale:v', '$toQSC', '-y', newFilePath]);

    if (originalStats != null) {
      await setFileStats(File(newFilePath), originalStats);
    }

    return didSuccess;
  }

  Future<void> compressImageDirectories({
    required Iterable<String> dirs,
    required int compressionPerc,
    required bool keepOriginalFileStats,
    bool recursive = true,
  }) async {
    final saveDirPath = AppDirs.COMPRESSED_IMAGES;
    if (!await requestManageStoragePermission(directoryToCreate: saveDirPath)) return;

    final dirFiles = <FileSystemEntity>[];

    for (final d in dirs) {
      dirFiles.addAll(await Directory(d).listAllIsolate(recursive: recursive));
    }

    dirFiles.retainWhere((element) => element is File);
    currentOperations[OperationType.imageCompress]!.value = OperationProgress(); // resetting

    final totalFiles = dirFiles.length;
    int currentProgress = 0;
    int currentFailed = 0;

    for (final f in dirFiles) {
      final didUpdate = await compressImage(
        path: f.path,
        saveDir: saveDirPath,
        percentage: compressionPerc,
        keepOriginalFileStats: keepOriginalFileStats,
      );
      if (!didUpdate) currentFailed++;
      currentProgress++;
      currentOperations[OperationType.imageCompress]!.value = OperationProgress(
        totalFiles: totalFiles,
        progress: currentProgress,
        currentFilePath: f.path,
        totalFailed: currentFailed,
      );
    }
    currentOperations[OperationType.imageCompress]!.value.currentFilePath = null;
  }

  Future<void> fixYTDLPBigThumbnailSize({required List<String> directoriesPaths, bool recursive = true}) async {
    if (!await requestManageStoragePermission()) return;

    final allFiles = <FileSystemEntity>[];
    int remainingDirsLength = directoriesPaths.length;
    final completer = Completer<void>();
    for (var e in directoriesPaths) {
      Directory(e).listAllIsolate(recursive: recursive).then(
        (value) {
          allFiles.addAll(value);
          remainingDirsLength--;
          if (remainingDirsLength == 0) completer.complete();
        },
      );
    }
    await completer.future;
    final totalFilesLength = allFiles.length;

    int currentProgress = 0;
    int currentFailed = 0;

    currentOperations[OperationType.ytdlpThumbnailFix]!.value = OperationProgress(); // resetting

    for (final filee in allFiles) {
      currentProgress++;
      if (filee is File) {
        final tr =
            Indexer.inst.allTracksMappedByPath[filee.path] ??
            await Indexer.inst.getTrackInfo(
              trackPath: filee.path,
              onMinDurTrigger: () => null,
              onMinSizeTrigger: () => null,
              isNetwork: false,
            );
        if (tr == null) continue;
        final videoId = tr.youtubeID;
        if (videoId.isEmpty) continue;

        File? thumbnailFile;
        bool isTempThumbnail = false;
        try {
          // -- try getting cropped version if required
          final channelName = await YoutubeInfoController.utils.getVideoChannelName(videoId);
          const topic = '- Topic';
          if (channelName != null && channelName.endsWith(topic)) {
            final thumbFilePath = FileParts.joinPath(Directory.systemTemp.path, '$videoId.png');
            final thumbFile = await YoutubeInfoController.video.fetchMusicVideoThumbnailToFile(videoId, thumbFilePath);
            if (thumbFile != null) {
              thumbnailFile = thumbFile;
              isTempThumbnail = true;
            }
          }
        } catch (_) {}

        thumbnailFile ??= await ThumbnailManager.inst.getYoutubeThumbnailAndCache(
          id: videoId,
          isImportantInCache: true,
          type: ThumbnailType.video,
        );

        if (thumbnailFile == null) {
          currentFailed++;
        } else {
          final didUpdate = await editAudioThumbnail(
            audioPath: filee.path,
            thumbnailPath: thumbnailFile.path,
          );
          if (!didUpdate) currentFailed++;

          if (isTempThumbnail) {
            thumbnailFile.tryDeleting();
          }
        }

        currentOperations[OperationType.ytdlpThumbnailFix]!.value = OperationProgress(
          totalFiles: totalFilesLength,
          progress: currentProgress,
          currentFilePath: filee.path,
          totalFailed: currentFailed,
        );
      }
    }
    currentOperations[OperationType.ytdlpThumbnailFix]!.value.currentFilePath = null;
  }

  /// * Extracts thumbnail from a given video, usually this tries to get embed thumbnail,
  ///   if failed then it will extract a frame at a given duration.
  /// * [quality] & [atDuration] will not be used in case an embed thumbnail was found
  /// * [quality] ranges on a scale of 1-31, where 1 is the best & 31 is the worst.
  /// * if [atDuration] is not specified, it will try to calculate based on video duration
  ///   (typically thumbnail at duration of 10% of the original duration),
  ///   if failed then a thumbnail at Duration.zero will be extracted.
  Future<bool> extractVideoThumbnail({
    required String videoPath,
    required String thumbnailSavePath,
    int quality = 1,
    Duration? atDuration,
  }) async {
    assert(quality >= 1 && quality <= 31, 'quality ranges only between 1 & 31');

    final didExecute = await _executer.ffmpegExecute(['-i', videoPath, '-map', '0:v', '-map', '-0:V', '-c', 'copy', '-y', thumbnailSavePath]);
    if (didExecute) return true;

    int? atMillisecond = atDuration?.inMilliseconds;
    if (atMillisecond == null) {
      final duration = await getMediaDuration(videoPath);
      if (duration != null) atMillisecond = duration.inMilliseconds;
    }

    final totalSeconds = (atMillisecond ?? 0) / 1000; // converting to decimal seconds.
    final extractFromSecond = totalSeconds * 0.1; // thumbnail at 10% of duration.
    return await _executer.ffmpegExecute(['-ss', '$extractFromSecond', '-i', videoPath, '-frames:v', '1', '-q:v', '$quality', '-y', thumbnailSavePath]);
  }

  Future<Duration?> getMediaDuration(String path) async {
    final output = await _executer.ffprobeExecute(['-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', path]);
    final duration = output == null ? null : double.tryParse(output);
    return duration == null ? null : Duration(microseconds: (duration * 1000 * 1000).floor());
  }

  // Future<List<String>> getTrackAndDiscField(String path) async {
  //   await _ffprobeExecute('-v quiet -loglevel error -show_entries format_tags=track,disc -of default=noprint_wrappers=1:nokey=1 "$path"');
  //   final output = await _ffmpegConfig.getLastCommandOutput();
  //   return output.split('\n');
  // }

  Future<bool> mergeAudioAndVideo({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    bool override = true,
  }) async {
    return await _executer.ffmpegExecute([
      '-i',
      videoPath,
      '-i',
      audioPath,
      '-map',
      '0:V:0', // uppercase V to skip cover arts, they are video streams too
      '-map',
      '1:a:0', // map to ensure audio only is merged (in case file extension was mp4 etc)
      '-c',
      'copy',
      if (override) '-y',
      outputPath,
    ], noTimeout: true);
  }

  /// Cuts [sortedCutRangesMS] out of [path] & stitches the remaining parts back together, without re-encoding.
  /// Cuts are keyframe aligned, so a video part can start slightly before its requested point.
  ///
  /// [sortedCutRangesMS] must be sorted & non-overlapping. [cutStartPaddingMS] delays every cut, to keep
  /// some room before it for containers whose last packets before a non keyframe boundary go unplayed.
  ///
  /// Attached cover arts are dropped, the caller is responsible for re-writing them.
  Future<bool> removeSegments({
    required String path,
    required List<(int, int)> sortedCutRangesMS,
    int cutStartPaddingMS = 0,
  }) async {
    final totalDuration = await getMediaDuration(path);
    if (totalDuration == null) return false;

    final totalDurationMS = totalDuration.inMilliseconds;
    final keepRanges = _buildKeepRanges(sortedCutRangesMS, totalDurationMS, cutStartPaddingMS);
    if (keepRanges.isEmpty) return false; // nothing would be left, the file is kept as is
    if (keepRanges.length == 1 && keepRanges.first.$1 <= 0 && keepRanges.first.$2 >= totalDurationMS) return false;

    String ext = 'mp4';
    try {
      ext = path.getExtension;
    } catch (_) {}

    // -- kept next to the target so the finished file is a rename away instead of a full cross volume copy
    final workingDirPath = FileParts.joinPath(path.getDirectoryPath, '.tempcut_${path.hashCode}');
    final workingDir = Directory(workingDirPath);

    try {
      await workingDir.create(recursive: true);

      final partsPaths = <String>[];
      for (int i = 0; i < keepRanges.length; i++) {
        final range = keepRanges[i];
        final partPath = FileParts.joinPath(workingDirPath, 'part_$i.$ext');
        final didExtract = await extractRange(
          path: path,
          startMS: range.$1,
          endMS: range.$2,
          outputPath: partPath,
        );
        if (!didExtract) return false;
        partsPaths.add(partPath);
      }

      if (partsPaths.length == 1) {
        return await _moveResultBack(File(partsPaths.first), path);
      }

      final listFile = FileParts.join(workingDirPath, 'parts.txt');
      final partsList = partsPaths.map((p) => "file '${p.replaceAll('\\', '/').replaceAll("'", r"'\''")}'").join('\n');
      await listFile.writeAsString(partsList);

      final outputPath = FileParts.joinPath(workingDirPath, 'output.$ext');
      final didConcat = await _executer.ffmpegExecute([
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        listFile.path,
        '-map',
        '0',
        '-c',
        'copy',
        '-y',
        outputPath,
      ], noTimeout: true);

      if (!didConcat) return false;
      return await _moveResultBack(File(outputPath), path);
    } catch (_) {
      return false;
    } finally {
      workingDir.delete(recursive: true).ignoreError();
    }
  }

  /// Copies `[startMS, endMS]` of [path] into [outputPath] without re-encoding.
  /// The start snaps back to the closest keyframe, so a part can begin slightly early but never ends late.
  ///
  /// Attached cover arts are dropped, the caller is responsible for re-writing them.
  Future<bool> extractRange({
    required String path,
    required int startMS,
    required int endMS,
    required String outputPath,
  }) async {
    return await _executer.ffmpegExecute([
      // -- both as input options, so [-to] stays absolute on the source timeline & no wanted content is lost
      '-ss',
      '${startMS / 1000}',
      '-to',
      '${endMS / 1000}',
      '-i',
      path,
      '-map',
      '0:V?', // uppercase V to skip cover arts, they would break concat demuxing
      '-map',
      '0:a?',
      '-c',
      'copy',
      '-avoid_negative_ts',
      'make_zero',
      '-y',
      outputPath,
    ], noTimeout: true);
  }

  static Future<bool> _moveResultBack(File resultFile, String targetPath) async {
    final resultSize = await resultFile.fileSize();
    if (resultSize == null || resultSize <= 0) return false;
    final moved = await resultFile.move(targetPath);
    return moved != null;
  }

  static List<(int, int)> _buildKeepRanges(List<(int, int)> sortedCutRangesMS, int totalDurationMS, int cutStartPaddingMS) {
    const minimumKeepDurationMS = 100;
    final keepRanges = <(int, int)>[];
    int cursorMS = 0;
    for (final cut in sortedCutRangesMS) {
      final endMS = cut.$2.withMaximum(totalDurationMS);
      if (endMS <= cursorMS) continue;
      final startMS = (cut.$1 + cutStartPaddingMS).withMaximum(endMS).withMinimum(cursorMS);
      if (startMS - cursorMS >= minimumKeepDurationMS) keepRanges.add((cursorMS, startMS));
      cursorMS = endMS;
    }
    if (totalDurationMS - cursorMS >= minimumKeepDurationMS) keepRanges.add((cursorMS, totalDurationMS));
    return keepRanges;
  }

  Future<bool> convertToWav({
    required String audioPath,
    required String outputPath,
  }) async {
    return await _executer.ffmpegExecute(
      ['-i', audioPath, '-f', 'wav', outputPath],
    );
  }

  /// First field is track/disc number, can be 0 or more.
  ///
  /// Second is track/disc total, can exist or can be null.
  ///
  /// Returns null if splitting failed or [discOrTrack] == null.
  // (String, String?)? _trackAndDiscSplitter(String? discOrTrack) {
  //   if (discOrTrack != null) {
  //     final discNT = discOrTrack.split('/');
  //     if (discNT.length == 2) {
  //       // -- track/disc total exist
  //       final discN = discNT.first; // might be 0 or more
  //       final discT = discNT.last; // always more than 0
  //       return (discN, discT);
  //     } else if (discNT.length == 1) {
  //       // -- only track/disc number is provided
  //       final discN = discNT.first;
  //       return (discN, null);
  //     }
  //   }
  //   return null;
  // }
}

enum FFMPEGTagField {
  title('title'),
  artist('artist'),
  album('album'),
  albumArtist('album_artist'),
  composer('composer'),
  synopsis('synopsis'),
  description('description'),
  genre('genre'),
  style('STYLE'),
  year('date'),
  trackNumber('track'),
  discNumber('disc'),
  trackTotal('TRACKTOTAL'),
  discTotal('DISCTOTAL'),
  comment('comment'),
  lyrics('lyrics'),
  remixer('REMIXER'),
  lyricist('LYRICIST'),
  language('LANGUAGE'),
  recordLabel('LABEL'),
  releaseType('RELEASETYPE'),
  country('Country'),

  // -- NOT WORKING
  mood('mood'),
  rating('rating'),
  tags('tags'),
  // ---------

  titleSort('titlesort'),
  artistSort('artistsort'),
  albumSort('albumsort'),
  albumArtistSort('albumartistsort'),
  composerSort('composersort'),
  ;

  final String tagKey;
  const FFMPEGTagField(this.tagKey);

  @override
  String toString() {
    return tagKey;
  }

  static String? _fieldToValue(FFMPEGTagField f, FTags newTags) {
    return switch (f) {
      FFMPEGTagField.title => newTags.title,
      FFMPEGTagField.artist => newTags.artist,
      FFMPEGTagField.album => newTags.album,
      FFMPEGTagField.albumArtist => newTags.albumArtist,
      FFMPEGTagField.composer => newTags.composer,
      FFMPEGTagField.genre => newTags.genre,
      FFMPEGTagField.style => newTags.style,
      FFMPEGTagField.year => newTags.year,
      FFMPEGTagField.trackNumber => newTags.trackNumber,
      FFMPEGTagField.discNumber => newTags.discNumber,
      FFMPEGTagField.trackTotal => newTags.trackTotal,
      FFMPEGTagField.discTotal => newTags.discTotal,
      FFMPEGTagField.comment => newTags.comment,
      FFMPEGTagField.description => newTags.description,
      FFMPEGTagField.synopsis => newTags.synopsis,
      FFMPEGTagField.lyrics => newTags.lyrics,
      FFMPEGTagField.remixer => newTags.remixer,
      FFMPEGTagField.lyricist => newTags.lyricist,
      FFMPEGTagField.language => newTags.language,
      FFMPEGTagField.recordLabel => newTags.recordLabel,
      FFMPEGTagField.releaseType => newTags.releaseType,
      FFMPEGTagField.country => newTags.country,

      // -- TESTED NOT WORKING. disabling to prevent unwanted fields corruption etc.
      FFMPEGTagField.mood => null,
      FFMPEGTagField.tags => null,
      FFMPEGTagField.rating => newTags.ratingPercentage?.toString(),
      // ----------
      FFMPEGTagField.titleSort => newTags.sortInfo?.title,
      FFMPEGTagField.artistSort => newTags.sortInfo?.artist,
      FFMPEGTagField.albumSort => newTags.sortInfo?.album,
      FFMPEGTagField.albumArtistSort => newTags.sortInfo?.albumArtist,
      FFMPEGTagField.composerSort => newTags.sortInfo?.composer,
    };
  }

  static Map<String, String?> createTagsMapfromFTag(FTags newTags) {
    return {for (final f in FFMPEGTagField.values) f.tagKey: ?_fieldToValue(f, newTags)};
  }
}

class OperationProgress {
  final int totalFiles;
  final int progress;
  String? currentFilePath;
  final int totalFailed;

  OperationProgress({
    this.totalFiles = 0,
    this.progress = 0,
    this.currentFilePath,
    this.totalFailed = 0,
  });
}

enum OperationType {
  imageCompress,
  ytdlpThumbnailFix,
}
