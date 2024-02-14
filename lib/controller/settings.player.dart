import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

import 'package:namida/base/settings_file_writer.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class PlayerSettings with SettingsFileWriter {
  static final PlayerSettings inst = PlayerSettings._internal();
  PlayerSettings._internal();

  final enableVolumeFadeOnPlayPause = true.obs;
  final playFadeDurInMilli = 300.obs;
  final pauseFadeDurInMilli = 300.obs;

  final volume = 1.0.obs;
  final speed = 1.0.obs;
  final pitch = 1.0.obs;

  final seekDurationInSeconds = 5.obs;
  final seekDurationInPercentage = 2.obs;
  final isSeekDurationPercentage = false.obs;
  final minTrackDurationToRestoreLastPosInMinutes = 5.obs;
  final interruptionResumeThresholdMin = 2.obs;
  final volume0ResumeThresholdMin = 5.obs;
  final enableCrossFade = true.obs;
  final crossFadeDurationMS = 500.obs;
  final crossFadeAutoTriggerSeconds = 5.obs;
  final playOnNextPrev = true.obs;
  final skipSilenceEnabled = false.obs;
  final shuffleAllTracks = false.obs;
  final pauseOnVolume0 = true.obs;
  final resumeAfterOnVolume0Pause = true.obs;
  final resumeAfterWasInterrupted = true.obs;
  final jumpToFirstTrackAfterFinishingQueue = true.obs;
  final repeatMode = RepeatMode.none.obs;
  final infiniyQueueOnNextPrevious = true.obs;
  final displayRemainingDurInsteadOfTotal = false.obs;
  final killAfterDismissingApp = KillAppMode.ifNotPlaying.obs;

  final onInterrupted = <InterruptionType, InterruptionAction>{
    InterruptionType.shouldPause: InterruptionAction.pause,
    InterruptionType.shouldDuck: InterruptionAction.duckAudio,
    InterruptionType.unknown: InterruptionAction.pause,
  }.obs;

  final lastPlayedIndices = {
    LibraryCategory.localTracks: 0,
    LibraryCategory.localVideos: 0,
    LibraryCategory.youtube: 0,
  };

  void save({
    bool? enableVolumeFadeOnPlayPause,
    bool? infiniyQueueOnNextPrevious,
    bool? displayRemainingDurInsteadOfTotal,
    double? volume,
    double? speed,
    double? pitch,
    int? seekDurationInSeconds,
    int? seekDurationInPercentage,
    bool? isSeekDurationPercentage,
    int? playFadeDurInMilli,
    int? pauseFadeDurInMilli,
    int? minTrackDurationToRestoreLastPosInMinutes,
    int? interruptionResumeThresholdMin,
    int? volume0ResumeThresholdMin,
    bool? enableCrossFade,
    int? crossFadeDurationMS,
    int? crossFadeAutoTriggerSeconds,
    bool? playOnNextPrev,
    bool? skipSilenceEnabled,
    bool? shuffleAllTracks,
    bool? pauseOnVolume0,
    bool? resumeAfterOnVolume0Pause,
    bool? resumeAfterWasInterrupted,
    bool? jumpToFirstTrackAfterFinishingQueue,
    RepeatMode? repeatMode,
    KillAppMode? killAfterDismissingApp,
    Map<String, int>? lastPlayedIndices,
  }) {
    if (enableVolumeFadeOnPlayPause != null) this.enableVolumeFadeOnPlayPause.value = enableVolumeFadeOnPlayPause;
    if (infiniyQueueOnNextPrevious != null) this.infiniyQueueOnNextPrevious.value = infiniyQueueOnNextPrevious;
    if (displayRemainingDurInsteadOfTotal != null) this.displayRemainingDurInsteadOfTotal.value = displayRemainingDurInsteadOfTotal;
    if (volume != null) this.volume.value = volume;
    if (speed != null) this.speed.value = speed;
    if (pitch != null) this.pitch.value = pitch;
    if (seekDurationInSeconds != null) this.seekDurationInSeconds.value = seekDurationInSeconds;
    if (seekDurationInPercentage != null) this.seekDurationInPercentage.value = seekDurationInPercentage;
    if (isSeekDurationPercentage != null) this.isSeekDurationPercentage.value = isSeekDurationPercentage;
    if (playFadeDurInMilli != null) this.playFadeDurInMilli.value = playFadeDurInMilli;
    if (pauseFadeDurInMilli != null) this.pauseFadeDurInMilli.value = pauseFadeDurInMilli;
    if (minTrackDurationToRestoreLastPosInMinutes != null) this.minTrackDurationToRestoreLastPosInMinutes.value = minTrackDurationToRestoreLastPosInMinutes;
    if (interruptionResumeThresholdMin != null) this.interruptionResumeThresholdMin.value = interruptionResumeThresholdMin;
    if (volume0ResumeThresholdMin != null) this.volume0ResumeThresholdMin.value = volume0ResumeThresholdMin;
    if (enableCrossFade != null) this.enableCrossFade.value = enableCrossFade;
    if (crossFadeDurationMS != null) this.crossFadeDurationMS.value = crossFadeDurationMS;
    if (crossFadeAutoTriggerSeconds != null) this.crossFadeAutoTriggerSeconds.value = crossFadeAutoTriggerSeconds;
    if (playOnNextPrev != null) this.playOnNextPrev.value = playOnNextPrev;
    if (skipSilenceEnabled != null) this.skipSilenceEnabled.value = skipSilenceEnabled;
    if (shuffleAllTracks != null) this.shuffleAllTracks.value = shuffleAllTracks;
    if (pauseOnVolume0 != null) this.pauseOnVolume0.value = pauseOnVolume0;
    if (resumeAfterOnVolume0Pause != null) this.resumeAfterOnVolume0Pause.value = resumeAfterOnVolume0Pause;
    if (resumeAfterWasInterrupted != null) this.resumeAfterWasInterrupted.value = resumeAfterWasInterrupted;
    if (jumpToFirstTrackAfterFinishingQueue != null) this.jumpToFirstTrackAfterFinishingQueue.value = jumpToFirstTrackAfterFinishingQueue;
    if (repeatMode != null) this.repeatMode.value = repeatMode;
    if (killAfterDismissingApp != null) this.killAfterDismissingApp.value = killAfterDismissingApp;
    if (lastPlayedIndices != null) {
      for (final e in lastPlayedIndices.entries) {
        this.lastPlayedIndices[e.key] = e.value;
      }
    }
    _writeToStorage();
  }

  void updatePlayerInterruption(InterruptionType type, InterruptionAction action) {
    onInterrupted[type] = action;
    _writeToStorage();
  }

  Future<void> prepareSettingsFile() async {
    final json = await prepareSettingsFile_();
    if (json == null) return;
    try {
      enableVolumeFadeOnPlayPause.value = json['enableVolumeFadeOnPlayPause'] ?? enableVolumeFadeOnPlayPause.value;
      volume.value = json['volume'] ?? volume.value;
      speed.value = json['speed'] ?? speed.value;
      pitch.value = json['pitch'] ?? pitch.value;
      seekDurationInSeconds.value = json['seekDurationInSeconds'] ?? seekDurationInSeconds.value;
      seekDurationInPercentage.value = json['seekDurationInPercentage'] ?? seekDurationInPercentage.value;
      isSeekDurationPercentage.value = json['isSeekDurationPercentage'] ?? isSeekDurationPercentage.value;
      playFadeDurInMilli.value = json['playFadeDurInMilli'] ?? playFadeDurInMilli.value;
      pauseFadeDurInMilli.value = json['pauseFadeDurInMilli'] as int? ?? pauseFadeDurInMilli.value;
      minTrackDurationToRestoreLastPosInMinutes.value = json['minTrackDurationToRestoreLastPosInMinutes'] ?? minTrackDurationToRestoreLastPosInMinutes.value;
      interruptionResumeThresholdMin.value = json['interruptionResumeThresholdMin'] ?? interruptionResumeThresholdMin.value;
      volume0ResumeThresholdMin.value = json['volume0ResumeThresholdMin'] ?? volume0ResumeThresholdMin.value;
      enableCrossFade.value = json['enableCrossFade'] ?? enableCrossFade.value;
      crossFadeDurationMS.value = json['crossFadeDurationMS'] ?? crossFadeDurationMS.value;
      crossFadeAutoTriggerSeconds.value = json['crossFadeAutoTriggerSeconds'] ?? crossFadeAutoTriggerSeconds.value;
      playOnNextPrev.value = json['playOnNextPrev'] ?? playOnNextPrev.value;
      skipSilenceEnabled.value = json['skipSilenceEnabled'] ?? skipSilenceEnabled.value;
      shuffleAllTracks.value = json['shuffleAllTracks'] ?? shuffleAllTracks.value;
      pauseOnVolume0.value = json['pauseOnVolume0'] ?? pauseOnVolume0.value;
      resumeAfterOnVolume0Pause.value = json['resumeAfterOnVolume0Pause'] ?? resumeAfterOnVolume0Pause.value;
      resumeAfterWasInterrupted.value = json['resumeAfterWasInterrupted'] ?? resumeAfterWasInterrupted.value;
      jumpToFirstTrackAfterFinishingQueue.value = json['jumpToFirstTrackAfterFinishingQueue'] ?? jumpToFirstTrackAfterFinishingQueue.value;
      repeatMode.value = RepeatMode.values.getEnum(json['repeatMode']) ?? repeatMode.value;
      infiniyQueueOnNextPrevious.value = json['infiniyQueueOnNextPrevious'] ?? infiniyQueueOnNextPrevious.value;
      displayRemainingDurInsteadOfTotal.value = json['displayRemainingDurInsteadOfTotal'] ?? displayRemainingDurInsteadOfTotal.value;
      killAfterDismissingApp.value = KillAppMode.values.getEnum(json['killAfterDismissingApp']) ?? killAfterDismissingApp.value;
      onInterrupted.value = getEnumMap_(
            json['onInterrupted'],
            InterruptionType.values,
            InterruptionType.unknown,
            InterruptionAction.values,
            InterruptionAction.doNothing,
          ) ??
          onInterrupted.map((key, value) => MapEntry(key, value));
      final lpi = json['lastPlayedIndices'];
      if (lpi is Map) {
        lastPlayedIndices.clear();
        lastPlayedIndices.addAll(lpi.cast());
      }
    } catch (e) {
      printy(e, isError: true);
    }
  }

  @override
  Object get jsonToWrite => <String, dynamic>{
        'enableVolumeFadeOnPlayPause': enableVolumeFadeOnPlayPause.value,
        'volume': volume.value,
        'speed': speed.value,
        'pitch': pitch.value,
        'seekDurationInSeconds': seekDurationInSeconds.value,
        'seekDurationInPercentage': seekDurationInPercentage.value,
        'isSeekDurationPercentage': isSeekDurationPercentage.value,
        'playFadeDurInMilli': playFadeDurInMilli.value,
        'pauseFadeDurInMilli': pauseFadeDurInMilli.value,
        'minTrackDurationToRestoreLastPosInMinutes': minTrackDurationToRestoreLastPosInMinutes.value,
        'interruptionResumeThresholdMin': interruptionResumeThresholdMin.value,
        'volume0ResumeThresholdMin': volume0ResumeThresholdMin.value,
        'enableCrossFade': enableCrossFade.value,
        'crossFadeDurationMS': crossFadeDurationMS.value,
        'crossFadeAutoTriggerSeconds': crossFadeAutoTriggerSeconds.value,
        'playOnNextPrev': playOnNextPrev.value,
        'skipSilenceEnabled': skipSilenceEnabled.value,
        'shuffleAllTracks': shuffleAllTracks.value,
        'pauseOnVolume0': pauseOnVolume0.value,
        'resumeAfterOnVolume0Pause': resumeAfterOnVolume0Pause.value,
        'resumeAfterWasInterrupted': resumeAfterWasInterrupted.value,
        'jumpToFirstTrackAfterFinishingQueue': jumpToFirstTrackAfterFinishingQueue.value,
        'repeatMode': repeatMode.value.convertToString,
        'killAfterDismissingApp': killAfterDismissingApp.value.convertToString,
        'infiniyQueueOnNextPrevious': infiniyQueueOnNextPrevious.value,
        'displayRemainingDurInsteadOfTotal': displayRemainingDurInsteadOfTotal.value,
        'onInterrupted': onInterrupted.map((key, value) => MapEntry(key.convertToString, value.convertToString)),
        'lastPlayedIndices': lastPlayedIndices,
      };

  Future<void> _writeToStorage() async => await writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_PLAYER;
}
