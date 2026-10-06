import 'dart:isolate';
import 'dart:math' as math;

import 'package:namida_waveform/namida_lossless.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

// by claude
/// One time scan for lossless files built from a lossy, lower rate or lower depth source.
class LosslessCheckController {
  static final inst = LosslessCheckController._();
  LosslessCheckController._();

  static const _batchSize = 16;

  /// a lossy encoder's or a resampler's lowpass falls this far at once, music rolling off on its own much less.
  static const _minEdgeDropDB = 25.0;

  /// lossy encoders cut under this, edges over it are mostly the mastering's own.
  static const _maxLossyCutoffHz = 20500.0;
  static const _maxUpsampledCutoffShare = 0.6;

  static const _losslessExtensions = {'flac', 'wav', 'wave', 'm4a', 'alac', 'ape', 'wv', 'aiff', 'aif', 'aifc', 'tta', 'tak'};

  late final isSupported = _readNativeVersion() != null;

  final isScanning = false.obs;
  final scanDone = 0.obs;
  final scanTotal = 0.obs;

  /// of the latest finished scan, null before one finished.
  final findings = Rxn<List<LosslessFinding>>();

  static int? _readNativeVersion() {
    try {
      return NamidaLossless.nativeVersion;
    } catch (_) {
      return null;
    }
  }

  void stop() => isScanning.value = false;

  /// null when stopped before finishing.
  Future<List<LosslessFinding>?> scan() async {
    if (isScanning.value || !isSupported) return null;
    final tracks = Indexer.inst.tracksInfoList.value.where(_mightBeLossless).toFixedList();
    final found = <LosslessFinding>[];
    scanDone.value = 0;
    scanTotal.value = tracks.length;
    isScanning.value = true;
    for (int start = 0; start < tracks.length; start += _batchSize) {
      if (!isScanning.value) return null;
      final end = math.min(start + _batchSize, tracks.length);
      final batch = tracks.sublist(start, end);
      final paths = batch.map((e) => e.path).toFixedList();
      final checks = await Isolate.run(() => _checkAll(paths));
      for (int i = 0; i < batch.length; i++) {
        final issues = _issuesOf(checks[i]);
        if (issues.isNotEmpty) found.add(LosslessFinding._(batch[i], issues));
      }
      scanDone.value = end;
    }
    isScanning.value = false;
    findings.value = found;
    return found;
  }

  Future<void> saveAsPlaylist(List<LosslessFinding> findings) async {
    final tracks = findings.map((e) => e.track).toFixedList();
    final date = DateTime.now().millisecondsSinceEpoch.dateFormattedOriginal;
    await PlaylistController.inst.addNewPlaylist('Not lossless $date', tracks: tracks);
  }

  static bool _mightBeLossless(Track track) {
    if (!track.isPhysical) return false;
    final extension = track.path.getExtension.toLowerCase();
    return _losslessExtensions.contains(extension);
  }

  static List<LosslessCheck> _checkAll(List<String> paths) => paths.map(NamidaLossless.check).toFixedList();

  static List<_LosslessIssue> _issuesOf(LosslessCheck check) {
    if (!check.isLossless || check.error != WaveformError.none) return const [];
    final issues = <_LosslessIssue>[];
    final hasPaddedBits = check.usedBits > 0 && check.storedBits > 16 && check.usedBits <= 16;
    if (hasPaddedBits) issues.add(_LosslessIssue.paddedBits(check.usedBits, check.storedBits));
    if (check.cutoffDropDB >= _minEdgeDropDB) {
      final nyquistHz = check.sampleRate / 2;
      if (check.cutoffHz < _maxLossyCutoffHz) {
        issues.add(_LosslessIssue.lossySource(check.cutoffHz));
      } else if (check.sampleRate > 48000 && check.cutoffHz <= nyquistHz * _maxUpsampledCutoffShare) {
        issues.add(_LosslessIssue.upsampled(check.cutoffHz));
      }
    }
    return issues;
  }
}

class LosslessFinding {
  final Track track;
  final List<_LosslessIssue> _issues;

  const LosslessFinding._(this.track, this._issues);

  String issuesText() => _issues.map((e) => e.toText()).join(', ');
}

class _LosslessIssue {
  final _LosslessIssueType _type;
  final double cutoffHz;
  final int usedBits;
  final int storedBits;

  const _LosslessIssue._(this._type, {this.cutoffHz = 0, this.usedBits = 0, this.storedBits = 0});

  const _LosslessIssue.lossySource(double cutoffHz) : this._(_LosslessIssueType.lossySource, cutoffHz: cutoffHz);
  const _LosslessIssue.upsampled(double cutoffHz) : this._(_LosslessIssueType.upsampled, cutoffHz: cutoffHz);
  const _LosslessIssue.paddedBits(int usedBits, int storedBits) : this._(_LosslessIssueType.paddedBits, usedBits: usedBits, storedBits: storedBits);

  /// rough lame/aac lowpass of each bitrate.
  String _likelyBitrate() {
    if (cutoffHz <= 16500) return '~128 kbps';
    if (cutoffHz <= 17500) return '~160 kbps';
    if (cutoffHz <= 19500) return '~192-256 kbps';
    return '~320 kbps';
  }

  String toText() {
    final cutoffKHz = (cutoffHz / 1000).toStringAsFixed(1);
    return switch (_type) {
      _LosslessIssueType.lossySource => 'lossy source, cut at $cutoffKHz kHz (${_likelyBitrate()})',
      _LosslessIssueType.upsampled => 'upsampled, nothing over $cutoffKHz kHz',
      _LosslessIssueType.paddedBits => '$usedBits-bit padded to $storedBits-bit',
    };
  }
}

enum _LosslessIssueType {
  lossySource,
  upsampled,
  paddedBits,
}
