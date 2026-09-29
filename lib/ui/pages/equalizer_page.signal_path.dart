// signal path ui by claude
part of 'equalizer_page.dart';

class _SignalPathSheet extends StatefulWidget {
  final double maxHeight;

  const _SignalPathSheet({required this.maxHeight});

  @override
  State<_SignalPathSheet> createState() => _SignalPathSheetState();
}

class _SignalPathSheetState extends State<_SignalPathSheet> {
  static const _kDesktopRefreshInterval = Duration(seconds: 1);

  /// android pushes its path, mpv is asked while the sheet is open.
  final _desktopPath = Rxn<AudioSignalPath>();
  Timer? _desktopRefreshTimer;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) return;
    _refreshDesktopPath();
    _desktopRefreshTimer = Timer.periodic(_kDesktopRefreshInterval, (_) => _refreshDesktopPath());
  }

  Future<void> _refreshDesktopPath() async {
    final path = await Player.inst.getDesktopSignalPath();
    if (mounted) _desktopPath.value = path;
  }

  @override
  void dispose() {
    _desktopRefreshTimer?.cancel();
    _desktopPath.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final pathRx = Platform.isAndroid ? AudioOutputController.inst.signalPath : _desktopPath;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight * 0.85),
      child: Obx(
        (context) {
          final path = pathRx.valueR;
          final steps = path == null ? const <_SignalPathStep>[] : _SignalPathSteps.buildR(path);
          final isBitPerfect = path != null && path.isBitPerfect && !steps.any((step) => step.changesAudio);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        lang.signalPath,
                        style: textTheme.displayLarge,
                      ),
                    ),
                    if (isBitPerfect)
                      _SignalPathBadge(
                        icon: Broken.flash,
                        title: lang.bitPerfect,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              Flexible(
                child: SmoothSingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22.0).add(const EdgeInsets.only(bottom: 24.0)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < steps.length; i++)
                        _SignalPathStepTile(
                          step: steps[i],
                          isFirst: i == 0,
                          isLast: i == steps.length - 1,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// every stage between the file and the device, the ones that change the audio are marked.
abstract final class _SignalPathSteps {
  static List<_SignalPathStep> buildR(AudioSignalPath path) {
    final steps = <_SignalPathStep>[_sourceStep(path)];
    final decoderName = path.decoderName;
    if (decoderName != null) {
      final decodedText = _SignalPathFormat.of(path.decoded, withChannels: false);
      steps.add(_SignalPathStep(icon: Broken.code, title: lang.decoder, detail: '$decoderName → $decodedText', changesAudio: false));
    }
    if (path.isBitPerfect) {
      steps.add(_untouchedStep(path));
    } else {
      steps.addAll(_processingStepsR(path));
    }
    final outputStep = _outputStep(path);
    if (outputStep != null) steps.add(outputStep);
    final deviceName = path.outputDeviceName ?? lang.systemDefault;
    steps.add(_SignalPathStep(icon: Broken.speaker, title: deviceName, detail: null, changesAudio: false));
    return steps;
  }

  static _SignalPathStep _sourceStep(AudioSignalPath path) {
    final codec = path.codec;
    final title = codec == null ? lang.source : '${lang.source} · $codec';
    final formatText = _SignalPathFormat.of(path.source, withChannels: true);
    final bitrateKbps = (path.sourceBitrate / 1000).round();
    final detail = bitrateKbps > 0 ? '$formatText · $bitrateKbps kbps' : formatText;
    return _SignalPathStep(icon: Broken.music, title: title, detail: detail, changesAudio: false);
  }

  /// integer samples widened into a bigger container keep every bit.
  static _SignalPathStep _untouchedStep(AudioSignalPath path) {
    final decodedBits = path.decoded.bitDepth;
    final outputBits = path.output.bitDepth;
    final isPadded = decodedBits > 0 && outputBits > decodedBits;
    final detail = isPadded ? '$decodedBits-bit → $outputBits-bit' : null;
    return _SignalPathStep(icon: Broken.flash, title: lang.bitPerfect, detail: detail, changesAudio: false);
  }

  static List<_SignalPathStep> _processingStepsR(AudioSignalPath path) {
    final item = Player.inst.currentItem.valueR;
    final itemKey = item?.key;
    final isPerTrackConfigOverriden = settings.player.isPerTrackAudioConfigOverriden.valueR;
    final itemConfig = isPerTrackConfigOverriden || itemKey == null ? null : Player.audioConfigs.map.valueR[itemKey];
    final config = itemConfig ?? Player.inst.getDefaultPlayerConfigR(item);
    final replayGainLinear = Player.inst.replayGainLinearVolumeMultiplierRx.valueR;
    final outputType = path.outputType;
    final isUsbDirect = outputType == AudioSignalOutputType.usbDirect;

    final steps = <_SignalPathStep>[];
    if (Platform.isAndroid && !path.decoded.isFloat) {
      steps.add(const _SignalPathStep(icon: Broken.convert, title: '32-bit float', detail: null, changesAudio: false));
    }
    if (config.skipSilence) {
      steps.add(_SignalPathStep(icon: Broken.forward, title: lang.skipSilence, detail: null, changesAudio: true));
    }
    if (config.speed != 1.0) {
      final speedText = config.speed.roundDecimals(2);
      steps.add(_SignalPathStep(icon: Broken.forward, title: lang.speed, detail: '$speedText×', changesAudio: true));
    }
    if (config.pitch != 1.0) {
      final pitchPercentage = (config.pitch * 100).roundDecimals(1);
      steps.add(_SignalPathStep(icon: Broken.airpods, title: lang.pitch, detail: '$pitchPercentage%', changesAudio: true));
    }
    final equalizer = config.equalizer;
    if (config.equalizerEnabled && equalizer.getActiveBands().isNotEmpty) {
      final preamp = equalizer.computeEffectivePreamp();
      final preampText = _EqualizerFormat.gain(preamp);
      steps.add(_SignalPathStep(icon: Broken.chart_3, title: lang.equalizer, detail: '${lang.preamp} $preampText', changesAudio: true));
    }
    final isLoudnessEnhancerAudible = Platform.isAndroid && !isUsbDirect && config.loudnessEnhancerEnabled && config.loudnessEnhancer != 0.0;
    if (isLoudnessEnhancerAudible) {
      final gainText = _EqualizerFormat.gain(config.loudnessEnhancer);
      steps.add(_SignalPathStep(icon: Broken.volume_high, title: lang.loudnessEnhancer, detail: gainText, changesAudio: true));
    }
    final volume = config.volume * replayGainLinear;
    final isVolumeInHardware = isUsbDirect && path.hasOutputHardwareVolume;
    if (volume != 1.0 && !isVolumeInHardware) {
      final volumePercentage = (volume * 100).round();
      steps.add(_SignalPathStep(icon: Broken.volume_up, title: lang.volume, detail: '$volumePercentage%', changesAudio: true));
    }
    final decodedRate = path.decoded.sampleRate;
    final outputRate = path.output.sampleRate;
    if (decodedRate > 0 && outputRate > 0 && decodedRate != outputRate) {
      final decodedRateText = _SignalPathFormat.rate(decodedRate);
      final outputRateText = _SignalPathFormat.rate(outputRate);
      final detail = '$decodedRateText → $outputRateText';
      steps.add(_SignalPathStep(icon: Broken.convert, title: lang.resample, detail: detail, changesAudio: true));
    }
    final decodedChannels = path.decoded.channels;
    final outputChannels = path.output.channels;
    if (outputChannels > 0 && decodedChannels > outputChannels) {
      steps.add(_SignalPathStep(icon: Broken.blend, title: lang.downmix, detail: '$decodedChannels → $outputChannels ch', changesAudio: true));
    }
    if (path.isOutputDithered) {
      steps.add(_SignalPathStep(icon: Broken.convert, title: lang.dither, detail: '→ ${path.output.bitDepth}-bit', changesAudio: true));
    }
    return steps;
  }

  static _SignalPathStep? _outputStep(AudioSignalPath path) {
    final outputType = path.outputType;
    if (outputType == null) return null;
    final formatText = _SignalPathFormat.of(path.output, withChannels: false);
    switch (outputType) {
      case AudioSignalOutputType.androidMixer:
        final mixerRate = path.mixerSampleRate;
        final isResampled = mixerRate > 0 && mixerRate != path.output.sampleRate;
        final mixerRateText = _SignalPathFormat.rate(mixerRate);
        final detail = isResampled ? '$formatText → $mixerRateText' : formatText;
        return _SignalPathStep(icon: Broken.blend_2, title: lang.androidMixer, detail: detail, changesAudio: true);
      case AudioSignalOutputType.bitPerfectMixer:
        return _SignalPathStep(icon: Broken.blend_2, title: '${lang.androidMixer} · ${lang.bitPerfect}', detail: formatText, changesAudio: false);
      case AudioSignalOutputType.usbDirect:
        final detail = path.hasOutputHardwareVolume ? '$formatText · ${lang.usbDirectHardwareVolume}' : formatText;
        return _SignalPathStep(icon: Broken.cpu, title: lang.usbDirect, detail: detail, changesAudio: false);
      case AudioSignalOutputType.desktopShared:
        final driver = path.outputDriver?.toUpperCase() ?? lang.output;
        return _SignalPathStep(icon: Broken.blend_2, title: driver, detail: formatText, changesAudio: true);
      case AudioSignalOutputType.desktopExclusive:
        final driver = path.outputDriver?.toUpperCase() ?? lang.output;
        return _SignalPathStep(icon: Broken.blend_2, title: '$driver · ${lang.exclusive}', detail: formatText, changesAudio: !path.isBitPerfect);
    }
  }
}

abstract final class _SignalPathFormat {
  static String of(AudioSignalFormat format, {required bool withChannels}) {
    final parts = <String>[];
    final bitDepth = format.bitDepth;
    if (bitDepth > 0) parts.add(format.isFloat ? '$bitDepth-bit float' : '$bitDepth-bit');
    if (format.sampleRate > 0) parts.add(rate(format.sampleRate));
    if (withChannels && format.channels > 0) parts.add('${format.channels} ch');
    return parts.join(' · ');
  }

  static String rate(int sampleRate) {
    final khz = (sampleRate / 1000).roundDecimals(1);
    return '$khz kHz';
  }
}

class _SignalPathStepTile extends StatelessWidget {
  final _SignalPathStep step;
  final bool isFirst;
  final bool isLast;

  const _SignalPathStepTile({
    required this.step,
    required this.isFirst,
    required this.isLast,
  });

  static const _kChangesAudioColor = Color(0xFFE0A030);

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final nodeColor = step.changesAudio ? _kChangesAudioColor : theme.colorScheme.primary;
    final lineColor = theme.colorScheme.onSurface.withOpacityExt(0.15);
    final detail = step.detail;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36.0,
            child: Column(
              children: [
                Expanded(
                  child: isFirst
                      ? const SizedBox()
                      : Column(
                          children: [
                            Expanded(
                              child: Container(
                                width: 2.0,
                                color: lineColor,
                              ),
                            ),
                            CustomPaint(
                              size: const Size(10.0, 6.0),
                              painter: _SignalPathArrowHeadPainter(color: lineColor),
                            ),
                            const SizedBox(height: 3.0),
                          ],
                        ),
                ),
                Container(
                  width: 34.0,
                  height: 34.0,
                  decoration: BoxDecoration(
                    color: nodeColor.withOpacityExt(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: nodeColor,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    step.icon,
                    size: 16.0,
                    color: nodeColor,
                  ),
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox()
                      : Container(
                          width: 2.0,
                          color: lineColor,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: textTheme.displayMedium,
                  ),
                  if (detail != null && detail.isNotEmpty)
                    Text(
                      detail,
                      style: textTheme.displaySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalPathArrowHeadPainter extends CustomPainter {
  final Color color;

  const _SignalPathArrowHeadPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0.0, 0.0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0.0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignalPathArrowHeadPainter oldDelegate) => oldDelegate.color != color;
}

class _SignalPathBadge extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SignalPathBadge({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacityExt(0.15),
        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14.0,
          ),
          const SizedBox(width: 4.0),
          Text(
            title,
            style: theme.textTheme.displaySmall,
          ),
        ],
      ),
    );
  }
}

class _SignalPathStep {
  final IconData icon;
  final String title;
  final String? detail;
  final bool changesAudio;

  const _SignalPathStep({
    required this.icon,
    required this.title,
    required this.detail,
    required this.changesAudio,
  });
}
