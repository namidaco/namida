// by claude
import 'dart:async';
import 'dart:io';

import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart' as mk;

import 'package:namida/class/custom_mpv_player.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

/// android routes every player at once, desktop players each own their output, see [Player.applyAudioOutput].
class AudioOutputController {
  static final inst = AudioOutputController._();
  AudioOutputController._();

  static const _kSystemDefaultKey = '';

  final devices = Rx<List<AudioOutputDevice>>(const []);

  /// android only.
  final bitPerfectStatus = Rxn<BitPerfectStatusMessage>();

  /// android only.
  final usbDirectStatus = Rxn<UsbDirectStatusMessage>();

  /// android only, desktop reads it on demand with [Player.getDesktopSignalPath].
  final signalPath = Rxn<AudioSignalPath>();

  static List<AudioOutputForcedOff> getForcedOffOptionsOf(AudioOutputForcedOffCause cause) => switch (cause) {
    AudioOutputForcedOffCause.bitPerfect => const [
      AudioOutputForcedOff.equalizer, AudioOutputForcedOff.loudnessEnhancer, AudioOutputForcedOff.speed, AudioOutputForcedOff.pitch, //
      AudioOutputForcedOff.skipSilence, AudioOutputForcedOff.monoAudio, AudioOutputForcedOff.soundEffects, AudioOutputForcedOff.volume, //
      AudioOutputForcedOff.systemVolume, AudioOutputForcedOff.fadeOnPlayPause, AudioOutputForcedOff.crossfade, AudioOutputForcedOff.otherSounds, //
    ],
    AudioOutputForcedOffCause.usbDirect => const [
      AudioOutputForcedOff.crossfade, AudioOutputForcedOff.loudnessEnhancer, AudioOutputForcedOff.systemEffects, AudioOutputForcedOff.otherSounds, //
    ],
    AudioOutputForcedOffCause.exclusiveMode => const [
      AudioOutputForcedOff.crossfade, AudioOutputForcedOff.otherSounds, //
    ],
  };

  StreamSubscription<AudioOutputEventMessage>? _androidEventsSub;
  String? _presetAppliedForDeviceKey;

  /// null when unknown, or when following the system on desktop.
  AudioOutputDevice? getRoutedDevice() => devices.value.firstWhereEff((d) => d.isRouted);

  /// nothing touches the samples, see [isForcedOffR] for what that turns off.
  bool isBitPerfectActiveR() => _isBitPerfectActive(reactive: true);

  bool isUsbDirectActiveR() => usbDirectStatus.valueR?.isActive ?? false;

  bool isForcedOff(AudioOutputForcedOff option) => _getForcedOffCause(option, reactive: false) != null;

  bool isForcedOffR(AudioOutputForcedOff option) => _getForcedOffCause(option, reactive: true) != null;

  AudioOutputForcedOffCause? getForcedOffCauseR(AudioOutputForcedOff option) => _getForcedOffCause(option, reactive: true);

  bool isForcedOffByR(AudioOutputForcedOff option, AudioOutputForcedOffCause cause) => _isForcedOffBy(option, cause, reactive: true);

  AudioOutputForcedOffCause? _getForcedOffCause(AudioOutputForcedOff option, {required bool reactive}) {
    for (final cause in AudioOutputForcedOffCause.values) {
      if (_isForcedOffBy(option, cause, reactive: reactive)) return cause;
    }
    return null;
  }

  /// processing is only off while bit-perfect actually plays, fades and crossfade are decided ahead so they follow the setting.
  /// usb direct feeds one stream to the dac, bypassing android's effects, the dac follows android's media volume and
  /// its own volume keeps bit-perfect adjustable, without one bit-perfect samples stay at full scale.
  /// both keep other apps off the device: desktop exclusive mode and usb direct own it, android's bit-perfect mixer mutes them.
  /// desktop exclusive mode alone keeps processing, only crossfade's second player can't open the owned device.
  bool _isForcedOffBy(AudioOutputForcedOff option, AudioOutputForcedOffCause cause, {required bool reactive}) {
    final usbDirect = reactive ? usbDirectStatus.valueR : usbDirectStatus.value;
    final isUsbDirectActive = usbDirect?.isActive ?? false;
    switch (cause) {
      case AudioOutputForcedOffCause.bitPerfect:
        final isBitPerfectActive = _isBitPerfectActive(reactive: reactive);
        final hasDacVolume = isUsbDirectActive && usbDirect!.hasHardwareVolume;
        return switch (option) {
          AudioOutputForcedOff.equalizer ||
          AudioOutputForcedOff.loudnessEnhancer ||
          AudioOutputForcedOff.speed ||
          AudioOutputForcedOff.pitch ||
          AudioOutputForcedOff.skipSilence ||
          AudioOutputForcedOff.monoAudio ||
          AudioOutputForcedOff.soundEffects => isBitPerfectActive,
          AudioOutputForcedOff.volume => isBitPerfectActive && !hasDacVolume,
          AudioOutputForcedOff.systemVolume => isBitPerfectActive && isUsbDirectActive && !hasDacVolume,
          AudioOutputForcedOff.fadeOnPlayPause || AudioOutputForcedOff.crossfade => _isBitPerfectEnabled(reactive: reactive),
          AudioOutputForcedOff.otherSounds => isBitPerfectActive,
          AudioOutputForcedOff.systemEffects => false,
        };
      case AudioOutputForcedOffCause.usbDirect:
        return switch (option) {
          AudioOutputForcedOff.crossfade ||
          AudioOutputForcedOff.loudnessEnhancer ||
          AudioOutputForcedOff.systemEffects ||
          AudioOutputForcedOff.otherSounds => isUsbDirectActive,
          AudioOutputForcedOff.equalizer ||
          AudioOutputForcedOff.speed ||
          AudioOutputForcedOff.pitch ||
          AudioOutputForcedOff.skipSilence ||
          AudioOutputForcedOff.monoAudio ||
          AudioOutputForcedOff.soundEffects ||
          AudioOutputForcedOff.volume ||
          AudioOutputForcedOff.systemVolume ||
          AudioOutputForcedOff.fadeOnPlayPause => false,
        };
      case AudioOutputForcedOffCause.exclusiveMode:
        final isExclusiveMode = reactive ? settings.player.exclusiveMode.valueR : settings.player.exclusiveMode.value;
        return switch (option) {
          AudioOutputForcedOff.crossfade || AudioOutputForcedOff.otherSounds => isExclusiveMode,
          AudioOutputForcedOff.equalizer ||
          AudioOutputForcedOff.loudnessEnhancer ||
          AudioOutputForcedOff.speed ||
          AudioOutputForcedOff.pitch ||
          AudioOutputForcedOff.skipSilence ||
          AudioOutputForcedOff.monoAudio ||
          AudioOutputForcedOff.soundEffects ||
          AudioOutputForcedOff.volume ||
          AudioOutputForcedOff.systemVolume ||
          AudioOutputForcedOff.fadeOnPlayPause ||
          AudioOutputForcedOff.systemEffects => false,
        };
    }
  }

  bool _isBitPerfectEnabled({required bool reactive}) => reactive ? settings.player.bitPerfect.valueR : settings.player.bitPerfect.value;

  bool _isBitPerfectActive({required bool reactive}) {
    if (!_isBitPerfectEnabled(reactive: reactive)) return false;
    if (!Platform.isAndroid) return true;
    final status = reactive ? bitPerfectStatus.valueR : bitPerfectStatus.value;
    return status?.isActive ?? false;
  }

  Future<void> init() async {
    if (Platform.isAndroid) {
      _androidEventsSub?.cancel();
      _androidEventsSub = AndroidAudioOutput.events.listen(_onAndroidEvent);
      await AndroidAudioOutput.setBitPerfectEnabled(settings.player.bitPerfect.value);
      await AndroidAudioOutput.setUsbDirectEnabled(settings.player.usbDirect.value);
      await AndroidAudioOutput.setMonoAudio(settings.player.monoAudio.value);
      if (settings.equalizer.soundEffects.value.isNotEmpty) await _applySoundEffects();
      _onAndroidEvent(await AndroidAudioOutput.getState());
    } else {
      CustomMPVPlayer.outputDevices.removeListener(_onMpvDevices);
      CustomMPVPlayer.outputDevices.addListener(_onMpvDevices);
      _onMpvDevices();
    }
  }

  Future<void> setDevice(AudioOutputDevice? device) async {
    settings.player.audioOutputDevice.save(device?.key);
    if (Platform.isAndroid) {
      await AndroidAudioOutput.setPreferredDevice(device?.androidId);
    } else {
      _onMpvDevices();
      await Player.inst.applyAudioOutput();
    }
  }

  Future<void> setBitPerfect(bool enabled) async {
    settings.player.bitPerfect.save(enabled);
    if (Platform.isAndroid) {
      await AndroidAudioOutput.setBitPerfectEnabled(enabled);
    } else {
      await Player.inst.applyAudioOutput();
    }
  }

  /// desktop only.
  Future<void> setExclusiveMode(bool enabled) async {
    settings.player.exclusiveMode.save(enabled);
    await Player.inst.applyAudioOutput();
  }

  Future<void> setMonoAudio(bool enabled) async {
    settings.player.monoAudio.save(enabled);
    if (Platform.isAndroid) {
      await AndroidAudioOutput.setMonoAudio(enabled);
    } else {
      await Player.inst.applyAudioOutput();
    }
  }

  /// android only.
  Future<void> setSoundEffectEnabled(SoundEffectType type, bool enabled) {
    settings.equalizer.soundEffects.update((effects) {
      if (enabled) {
        effects.add(type);
      } else {
        effects.remove(type);
      }
    });
    return _applySoundEffects();
  }

  /// android only.
  Future<void> setSoundEffectIntensity(SoundEffectType type, double intensity) {
    settings.equalizer.soundEffectIntensities.update((intensities) => intensities[type] = intensity);
    return _applySoundEffects();
  }

  Future<void> _applySoundEffects() {
    final intensities = settings.equalizer.soundEffectIntensities.value;
    final effects = settings.equalizer.soundEffects.value.map((type) {
      final intensity = intensities[type] ?? type.defaultIntensity;
      return SoundEffectMessage(type: type.toMessage(), intensity: intensity);
    }).toFixedList();
    return AndroidAudioOutput.setSoundEffects(SoundEffectsMessage(effects: effects));
  }

  /// android only, a released dac pauses playback like unplugged headphones.
  Future<void> setUsbDirect(bool enabled) async {
    settings.player.usbDirect.save(enabled);
    await [
      NamidaChannel.inst.setUsbDacHandlerEnabled(enabled),
      AndroidAudioOutput.setUsbDirectEnabled(enabled),
    ].execute();
  }

  void setDevicePreset(String deviceKey, EqualizerPreset? preset) {
    settings.equalizer.devicePresets.update((map) {
      if (preset == null) {
        map.remove(deviceKey);
      } else {
        map[deviceKey] = preset.name;
      }
    });
    _presetAppliedForDeviceKey = null;
    _applyDevicePreset();
  }

  String keyForDevicePreset(AudioOutputDevice? device) => device?.key ?? _kSystemDefaultKey;

  void _onAndroidEvent(AudioOutputEventMessage event) {
    bitPerfectStatus.value = event.bitPerfect;
    usbDirectStatus.value = event.usbDirect;
    signalPath.value = AudioSignalPath._fromAndroid(event.signalPath);
    final androidDevices = event.devices;
    if (androidDevices == null) return;
    devices.value = androidDevices.map(AudioOutputDevice._fromAndroid).toFixedList();

    // -- device ids change on every reconnect, the saved key is resolved again each time.
    final key = settings.player.audioOutputDevice.value;
    final wantedDevice = key == null ? null : devices.value.firstWhereEff((d) => d.key == key);
    final wantedId = wantedDevice?.androidId;
    if (wantedId != event.preferredDeviceId) AndroidAudioOutput.setPreferredDevice(wantedId);

    _applyDevicePreset();
  }

  void _onMpvDevices() {
    final selected = settings.player.audioOutputDevice.value;
    devices.value = [
      for (final d in CustomMPVPlayer.outputDevices.value)
        if (d.name != 'auto') AudioOutputDevice._fromMpv(d, isRouted: d.name == selected),
    ];
    _applyDevicePreset();
  }

  void _applyDevicePreset() {
    final routedDevice = getRoutedDevice();
    final deviceKey = keyForDevicePreset(routedDevice);
    if (deviceKey == _presetAppliedForDeviceKey) return;
    _presetAppliedForDeviceKey = deviceKey;
    final presetName = settings.equalizer.devicePresets.value[deviceKey];
    if (presetName == null) return;
    final preset = settings.equalizer.eqPresets.value.firstWhereEff((p) => p.name == presetName);
    if (preset != null) Player.inst.setGlobalEqualizer(preset.equalizer, preset: preset);
  }
}

class AudioOutputDevice {
  /// survives reconnects, unlike android's device ids.
  final String key;
  final String name;
  final AudioOutputDeviceType type;
  final int? androidId;
  final bool isRouted;
  final bool supportsBitPerfect;
  final int maxSampleRate;
  final int maxBitDepth;

  /// the dac claimed by usb direct, it plays everything while claimed.
  final bool isUsbDirect;

  const AudioOutputDevice._({
    required this.key,
    required this.name,
    required this.type,
    required this.androidId,
    required this.isRouted,
    required this.supportsBitPerfect,
    required this.maxSampleRate,
    required this.maxBitDepth,
    required this.isUsbDirect,
  });

  factory AudioOutputDevice._fromAndroid(AudioOutputDeviceMessage m) {
    final type = AudioOutputDeviceType._fromAndroidType(m.type);
    final name = m.name ?? '';
    final address = type == AudioOutputDeviceType.bluetooth ? m.address ?? '' : '';
    return AudioOutputDevice._(
      key: '${m.type}:$name:$address',
      name: name,
      type: type,
      androidId: m.id,
      isRouted: m.isRouted,
      supportsBitPerfect: m.bitPerfect,
      maxSampleRate: m.maxSampleRate,
      maxBitDepth: m.maxBitDepth,
      isUsbDirect: m.isUsbDirect,
    );
  }

  factory AudioOutputDevice._fromMpv(mk.AudioDevice d, {required bool isRouted}) {
    return AudioOutputDevice._(
      key: d.name,
      name: d.description.isEmpty ? d.name : d.description,
      type: AudioOutputDeviceType.other,
      androidId: null,
      isRouted: isRouted,
      supportsBitPerfect: true,
      maxSampleRate: 0,
      maxBitDepth: 0,
      isUsbDirect: false,
    );
  }
}

/// from the file to the device, 0 marks what the backend doesn't know.
class AudioSignalPath {
  final String? codec;
  final AudioSignalFormat source;
  final int sourceBitrate;
  final String? decoderName;
  final AudioSignalFormat decoded;
  final bool isBitPerfect;
  final AudioSignalOutputType? outputType;

  /// desktop audio output driver, `wasapi`, `pipewire`, ...
  final String? outputDriver;
  final String? outputDeviceName;
  final AudioSignalFormat output;
  final bool isOutputDithered;
  final bool hasOutputHardwareVolume;

  /// what android's mixer resamples everything to.
  final int mixerSampleRate;

  const AudioSignalPath({
    required this.codec,
    required this.source,
    required this.sourceBitrate,
    required this.decoderName,
    required this.decoded,
    required this.isBitPerfect,
    required this.outputType,
    required this.outputDriver,
    required this.outputDeviceName,
    required this.output,
    required this.isOutputDithered,
    required this.hasOutputHardwareVolume,
    required this.mixerSampleRate,
  });

  factory AudioSignalPath._fromAndroid(AudioSignalPathMessage m) {
    final outputType = switch (m.output) {
      AudioSignalPathOutputMessage.androidMixer => AudioSignalOutputType.androidMixer,
      AudioSignalPathOutputMessage.bitPerfectMixer => AudioSignalOutputType.bitPerfectMixer,
      AudioSignalPathOutputMessage.usbDirect => AudioSignalOutputType.usbDirect,
      null => null,
    };
    return AudioSignalPath(
      codec: _codecOfMime(m.sourceMime),
      source: AudioSignalFormat(sampleRate: m.sourceSampleRate, bitDepth: m.sourceBitDepth, isFloat: false, channels: m.sourceChannels),
      sourceBitrate: m.sourceBitrate,
      decoderName: m.decoderName,
      decoded: AudioSignalFormat(sampleRate: m.decodedSampleRate, bitDepth: m.decodedBitDepth, isFloat: m.isDecodedFloat, channels: m.decodedChannels),
      isBitPerfect: m.isBitPerfect,
      outputType: outputType,
      outputDriver: null,
      outputDeviceName: m.outputDeviceName,
      output: AudioSignalFormat(sampleRate: m.outputSampleRate, bitDepth: m.outputBitDepth, isFloat: m.isOutputFloat, channels: m.outputChannels),
      isOutputDithered: m.isOutputDithered,
      hasOutputHardwareVolume: m.hasOutputHardwareVolume,
      mixerSampleRate: m.mixerSampleRate,
    );
  }

  static String? _codecOfMime(String? mime) {
    if (mime == null) return null;
    return switch (mime) {
      'audio/mpeg' || 'audio/mpeg-L1' || 'audio/mpeg-L2' => 'MP3',
      'audio/mp4a-latm' => 'AAC',
      'audio/raw' || 'audio/wav' => 'PCM',
      'audio/ac3' => 'AC-3',
      'audio/eac3' || 'audio/eac3-joc' => 'E-AC-3',
      'audio/vnd.dts' || 'audio/vnd.dts.hd' => 'DTS',
      'audio/true-hd' => 'TrueHD',
      'audio/x-wavpack' => 'WavPack',
      _ => mime.splitLast('/').replaceFirst('x-', '').toUpperCase(),
    };
  }
}

class AudioSignalFormat {
  final int sampleRate;
  final int bitDepth;
  final bool isFloat;
  final int channels;

  const AudioSignalFormat({
    required this.sampleRate,
    required this.bitDepth,
    required this.isFloat,
    required this.channels,
  });
}

enum AudioSignalOutputType {
  androidMixer,
  bitPerfectMixer,
  usbDirect,
  desktopShared,
  desktopExclusive,
}

enum AudioOutputForcedOffCause {
  bitPerfect,
  usbDirect,
  exclusiveMode,
}

enum AudioOutputForcedOff {
  equalizer,
  loudnessEnhancer,
  speed,
  pitch,
  skipSilence,
  monoAudio,
  soundEffects,
  volume,
  fadeOnPlayPause,
  crossfade,
  systemEffects,
  systemVolume,
  otherSounds,
}

enum AudioOutputDeviceType {
  speaker,
  wired,
  bluetooth,
  usb,
  digital,
  other;

  static AudioOutputDeviceType _fromAndroidType(int type) => switch (type) {
    2 => speaker,
    3 || 4 || 5 || 13 || 19 || 31 => wired,
    8 || 23 || 26 || 27 || 30 => bluetooth,
    11 || 12 || 22 => usb,
    6 || 9 || 10 || 29 => digital,
    _ => other,
  };
}

extension _SoundEffectTypeMessage on SoundEffectType {
  SoundEffectTypeMessage toMessage() => switch (this) {
    SoundEffectType.crossfeed => SoundEffectTypeMessage.crossfeed,
    SoundEffectType.virtualSurround => SoundEffectTypeMessage.virtualSurround,
    SoundEffectType.echo => SoundEffectTypeMessage.echo,
    SoundEffectType.chorus => SoundEffectTypeMessage.chorus,
    SoundEffectType.autoPan => SoundEffectTypeMessage.autoPan,
    SoundEffectType.compressor => SoundEffectTypeMessage.compressor,
    SoundEffectType.instrumental => SoundEffectTypeMessage.instrumental,
    SoundEffectType.bassEnhancer => SoundEffectTypeMessage.bassEnhancer,
    SoundEffectType.tubeWarmth => SoundEffectTypeMessage.tubeWarmth,
  };
}
