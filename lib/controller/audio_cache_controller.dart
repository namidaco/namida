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

  Future<void> updateAudioCacheMap() async {
    final map = await _getAllAudiosInCache.thready(AppDirs.AUDIOS_CACHE);
    audioCacheMap = map;
  }

  Future<AudioCacheDetails?> getCachedAudioForId(String videoId) async {
    final possibleAudioFiles = audioCacheMap[videoId] ?? [];
    final possibleLocalFiles = Indexer.inst.allTracksMappedByYTID[videoId] ?? [];

    final audioFiles = possibleAudioFiles.isNotEmpty
        ? possibleAudioFiles
        : await _getCachedAudiosForID.thready({
            "dirPath": AppDirs.AUDIOS_CACHE,
            "id": videoId,
          });
    final finalAudioFiles = audioFiles..sortByReverseAlt((e) => e.bitrate ?? 0, (e) => e.file.fileSizeSync() ?? 0);
    AudioCacheDetails? cachedAudio = await finalAudioFiles.firstWhereEffAsync((e) => e.file.exists());

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

  void addToCacheMap(String videoId, AudioCacheDetails cacheDetails) {
    audioCacheMap.addForce(videoId, cacheDetails);
  }

  void removeFromCacheMap(String videoId, String path) {
    audioCacheMap[videoId]?.removeWhere((element) => element.file.path == path);
  }

  void clearAll() {
    audioCacheMap.clear();
  }

  Future<void> deleteAudioCache(String videoId) async {
    final audios = audioCacheMap[videoId];
    await audios?.loopAsync((item) => item.file.delete());
    audioCacheMap.remove(videoId);
  }

  /// TODO: improve using PortsProvider
  static List<AudioCacheDetails> _getCachedAudiosForID(Map map) {
    final dirPath = map["dirPath"] as String;
    final id = map["id"] as String;

    final newFiles = <AudioCacheDetails>[];

    final allFiles = Directory(dirPath).listSyncSafe();
    final allLength = allFiles.length;
    for (int i = 0; i < allLength; i++) {
      final fe = allFiles[i];
      final filename = fe.path.getFilename;
      final goodID = filename.startsWith(id);
      final isGood = fe is File && goodID && !filename.endsWith('.part') && !filename.endsWith('.mime') && !filename.endsWith('.metadata');

      if (isGood) {
        try {
          final details = _parseAudioCacheDetailsFromFile(fe);
          newFiles.add(details);
          break; // since its not likely to find other audios
        } catch (_) {}
      }
    }
    return newFiles;
  }

  static Map<String, List<AudioCacheDetails>> _getAllAudiosInCache(String dirPath) {
    final newFiles = <String, List<AudioCacheDetails>>{};

    final files = Directory(dirPath).listSyncSafe();
    final filesL = files.length;
    for (int i = 0; i < filesL; i++) {
      var fe = files[i];
      final filename = fe.path.getFilename;
      final isGood = fe is File && !filename.endsWith('.part') && !filename.endsWith('.mime') && !filename.endsWith('.metadata');

      if (isGood) {
        try {
          final details = _parseAudioCacheDetailsFromFile(fe);
          newFiles.addForce(details.youtubeId, details);
        } catch (_) {}
      }
    }
    return newFiles;
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
