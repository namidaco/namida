import 'dart:async';
import 'dart:io';

import 'package:namida/class/audio_cache_detail.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class AudioCacheController {
  static final inst = AudioCacheController._();
  AudioCacheController._();

  var audioCacheMap = <String, List<AudioCacheDetails>>{};

  final _audioCacheMapLoadedCompleter = Completer<void>();

  Future<void> updateAudioCacheMap() async {
    try {
      final map = await _getAllAudiosInCache.thready(AppDirs.AUDIOS_CACHE);
      audioCacheMap = map;
    } finally {
      _audioCacheMapLoadedCompleter.completeIfWasnt();
    }
  }

  Future<AudioCacheDetails?> getCachedAudioForId(String videoId) async {
    await _audioCacheMapLoadedCompleter.future;

    final audioFiles = audioCacheMap[videoId] ?? [];
    final possibleLocalFiles = Indexer.inst.allTracksMappedByYTID[videoId] ?? [];

    audioFiles.sortByAltsPrecomputed([(e) => e.bitrate ?? 0, (e) => e.file.fileSizeSync() ?? 0], reverse: true);
    AudioCacheDetails? cachedAudio = await audioFiles.firstWhereEffAsync((e) => e.file.exists());

    if (cachedAudio == null) {
      final localTrack = await possibleLocalFiles.firstWhereEffAsync((e) => File(e.path).exists());
      if (localTrack != null) {
        cachedAudio = AudioCacheDetails(
          youtubeId: videoId,
          bitrate: localTrack.bitrate,
          langaugeCode: null,
          langaugeName: null,
          file: File(localTrack.path),
        );
      }
    }
    return cachedAudio;
  }

  bool isAvailableOffline(String videoId) => audioCacheMap[videoId]?.isNotEmpty == true || Indexer.inst.allTracksMappedByYTID[videoId]?.isNotEmpty == true;

  void addToCacheMap(String videoId, AudioCacheDetails cacheDetails) {
    audioCacheMap.addForce(videoId, cacheDetails);
  }

  void addFileToCacheMap(File file) {
    final details = _tryParseAudioCacheFile(file);
    if (details == null) return;
    removeFromCacheMap(details.youtubeId, file.path);
    addToCacheMap(details.youtubeId, details);
  }

  void removeFromCacheMap(String videoId, String path) {
    audioCacheMap[videoId]?.removeWhere((element) => element.file.path == path);
  }

  void clearAll() {
    audioCacheMap.clear();
  }

  Future<void> deleteAudioCache(String videoId) async {
    final audios = audioCacheMap[videoId];
    if (audios != null) {
      await audios.loopConcurrent((item) => item.file.tryDeleting());
    }
    audioCacheMap.remove(videoId);
  }

  static Map<String, List<AudioCacheDetails>> _getAllAudiosInCache(String dirPath) {
    final newFiles = <String, List<AudioCacheDetails>>{};

    final files = Directory(dirPath).listSyncSafe();
    for (final fe in files) {
      if (fe is! File) continue;
      final details = _tryParseAudioCacheFile(fe);
      if (details != null) newFiles.addForce(details.youtubeId, details);
    }
    return newFiles;
  }

  static AudioCacheDetails? _tryParseAudioCacheFile(File file) {
    final filename = file.path.getFilename;
    final isGood = !filename.endsWith('.part') && !filename.endsWith('.mime') && !filename.endsWith('.metadata');
    if (!isGood) return null;
    try {
      return _parseAudioCacheDetailsFromFile(file);
    } catch (_) {
      return null;
    }
  }

  static AudioCacheDetails _parseAudioCacheDetailsFromFile(File file) {
    final filenamewe = file.path.getFilenameWOExt;
    final id = filenamewe.substring(0, 11); // 'Wd_gr91dgDa_23393.m4a' -> 'Wd_gr91dgDa'
    final languagesAndBitrate = filenamewe.substring(12, filenamewe.length - 1).split('_');
    final languageCode = languagesAndBitrate.length >= 2 ? languagesAndBitrate[0] : null;
    final languageName = languagesAndBitrate.length >= 3 ? languagesAndBitrate[1] : null;
    final bitrateText = filenamewe.splitLast('_');
    return AudioCacheDetails(
      file: file,
      bitrate: int.tryParse(bitrateText),
      langaugeCode: languageCode,
      langaugeName: languageName,
      youtubeId: id,
    );
  }
}
