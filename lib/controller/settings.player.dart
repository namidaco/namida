part of 'settings_controller.dart';

class _PlayerSettings extends _SettingsKeysWriter {
  _PlayerSettings._internal();

  late final enableVolumeFadeOnPlayPause = _key('enableVolumeFadeOnPlayPause', true);
  late final playFadeDurInMilli = _key('playFadeDurInMilli', 300);
  late final pauseFadeDurInMilli = _key('pauseFadeDurInMilli', 300);

  late final volume = _key('volume', 1.0, sync: false);
  late final speed = _key('speed', 1.0);
  late final pitch = _key('pitch', 1.0);
  late final longPressSpeed = _key('longPressSpeed', 1.5);
  late final linkSpeedPitch = _key('linkSpeedPitch', false);
  late final useSemitones = _key('useSemitones', false);
  late final isPerTrackAudioConfigOverriden = _key('isPerTrackAudioConfigOverriden', false);
  late final speeds = _keyList<double>('speeds', const [0.25, 0.5, 0.75, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0]);
  late final sleepTimerPresetsMin = _keyList<int>('sleepTimerPresetsMin', const [15, 30, 45, 60, 90, 120]);

  late final seekDurationInSeconds = _key('seekDurationInSeconds', 5);
  late final seekDurationInPercentage = _key('seekDurationInPercentage', 2);
  late final isSeekDurationPercentage = _key('isSeekDurationPercentage', false);
  late final minTrackDurationToRestoreLastPosInMinutes = _key('minTrackDurationToRestoreLastPosInMinutes', 20);
  late final interruptionResumeThresholdMin = _key('interruptionResumeThresholdMin', 2);
  late final volume0ResumeThresholdMin = _key('volume0ResumeThresholdMin', 5);
  late final connectWiredResumeThresholdMin = _key('connectWiredResumeThresholdMin', -1);
  late final connectWirelessResumeThresholdMin = _key('connectWirelessResumeThresholdMin', -1);
  late final enableGaplessPlayback = _key('enableGaplessPlayback', false);
  late final enableCrossFade = _key('enableCrossFade', isKuru ? true : false);
  late final crossFadeDurationMS = _key('crossFadeDurationMS', isKuru ? 1500 : 500);
  late final crossFadeAutoTriggerSeconds = _key('crossFadeAutoTriggerSeconds', isKuru ? 0 : 5);
  late final playOnNextPrev = _key('playOnNextPrev', isKuru ? false : true);
  late final skipSilenceEnabled = _key('skipSilenceEnabled', false);
  late final pauseOnVolume0 = _key('pauseOnVolume0', true);
  late final jumpToFirstTrackAfterFinishingQueue = _key('jumpToFirstTrackAfterFinishingQueue', false);
  late final repeatMode = _keyEnum('repeatMode', PlayerRepeatMode.none, PlayerRepeatMode.values, sync: false);
  late final shuffleQueue = _key('shuffleQueue', false, sync: false);
  late final infiniyQueueOnNextPrevious = _key('infiniyQueueOnNextPrevious', true);
  late final displayRemainingDurInsteadOfTotal = _key('displayRemainingDurInsteadOfTotal', false);
  late final displayActualPositionWhenSeeking = _key('displayActualPositionWhenSeeking', false);
  late final killAfterDismissingApp = _keyEnum('killAfterDismissingApp', isKuru ? KillAppMode.never : KillAppMode.ifNotPlaying, KillAppMode.values);
  late final lockscreenArtwork = _key('lockscreenArtwork', true);
  late final replayGainType = _keyEnum('replayGainType', isKuru ? ReplayGainType.volume : ReplayGainType.platform_default, ReplayGainType.values, sync: false);
  late final internalPlayer = _keyEnum('internalPlayer', InternalPlayerType.auto, InternalPlayerType.getAvailableForCurrentPlatform(), sync: false);
  late final bitPerfect = _key('bitPerfect', false, sync: false);
  late final usbDirect = _key('usbDirect', false, sync: false);
  late final monoAudio = _key('monoAudio', false);

  /// [AudioOutputDevice.key], null follows the system.
  late final audioOutputDevice = _key<String?>('audioOutputDevice', null, sync: false);

  late final onInterrupted = _keyMap<InterruptionType, InterruptionAction>(
    'onInterrupted',
    const {
      InterruptionType.shouldPause: InterruptionAction.pause,
      InterruptionType.shouldDuck: InterruptionAction.duckAudio,
      InterruptionType.unknown: InterruptionAction.pause,
    },
    key: InterruptionType.values.asCodec(),
    value: InterruptionAction.values.asCodec(),
  );

  @override
  void _migrateLegacy() {
    if (_raw['repeatMode'] == 'shuffle') {
      _raw['repeatMode'] = PlayerRepeatMode.all.name;
      _raw['shuffleQueue'] = true;
    }
    _migrateKey('replayGain', 'replayGainType', (json) {
      if (json is! bool) return null;
      final type = json ? ReplayGainType.getPlatformDefault() : ReplayGainType.off;
      return type.name;
    });
    _dropKey('resumeAfterOnVolume0Pause');
    _dropKey('resumeAfterWasInterrupted');
    _dropKey('shuffleAllTracks');
  }

  @override
  bool get syncable => true;

  @override
  String get filePath => AppPaths.SETTINGS_PLAYER;
}
