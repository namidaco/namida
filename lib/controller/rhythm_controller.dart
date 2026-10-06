import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:namida_waveform/namida_rhythm.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/audio_cache_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_id.dart';

// by claude
/// Tempo, beat grid and key of the library and of cached youtube audio, analyzed in the background while beat matching is on.
/// Feeds the beat matched crossfade and the bpm/key aware shuffle, tags win over the analysis wherever they hold a value.
class RhythmController {
  static final inst = RhythmController._();
  RhythmController._();

  static const _upcomingItemsToAnalyze = 20;

  /// a wrong grid sounds worse than a plain crossfade.
  static const _minBeatConfidence = 0.5;
  static const _minKeyConfidence = 0.5;

  /// skipping through the queue costs nothing, and the waveform goes first.
  static const _analysisDelay = Duration(seconds: 3);

  bool get isEnabled => settings.player.crossfadeMode.value != CrossfadeMode.standard && settings.player.enableCrossFade.value;

  bool get isBeatMatching => settings.player.crossfadeMode.value == CrossfadeMode.beatMatched && settings.player.enableCrossFade.value;

  bool get isSupported => _version != null;

  /// smart and beat matched modes only shape automatic transitions.
  bool get hasAutoTransitionsR => settings.player.enableCrossFade.valueR && !settings.player.enableGaplessPlayback.valueR && settings.player.crossFadeAutoTriggerSeconds.valueR > 0;

  /// null when the native library can't analyze at all (a desktop library built before it).
  late final int? _version = _readNativeVersion();

  late final _db = DBWrapper.openFromInfo(
    fileInfo: AppPaths.TRACKS_RHYTHM_DB_INFO,
    config: const DBConfig(createIfNotExist: true),
  );

  final _analyzer = _RhythmIsolateManager();
  final _rhythms = <String, _Rhythm>{};
  Future<void>? _loading;

  final _urgentJobs = <String, _RhythmJob>{};
  final _jobs = <String, _RhythmJob>{};
  bool _isAnalyzing = false;
  Timer? _analysisTimer;

  final isScanning = false.obs;
  final scanDone = 0.obs;
  final scanTotal = 0.obs;

  static int? _readNativeVersion() {
    try {
      return NamidaRhythm.nativeVersion;
    } catch (_) {
      return null;
    }
  }

  void setMode(CrossfadeMode mode) {
    settings.player.crossfadeMode.save(mode);
    Player.inst.refreshCrossfadeTransition();
  }

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final rows = await _db.loadEverythingKeyedResult();
      for (final e in rows.entries) {
        try {
          _rhythms[e.key] ??= _Rhythm.fromMap(e.value);
        } catch (_) {}
      }
    } catch (e, st) {
      logger.error('RhythmController._load', e: e, st: st);
    }
  }

  /// null when [item] has no steady beat grid to match.
  BeatGrid? gridOf(Playable item) {
    final rhythm = _rhythms[item.key];
    if (rhythm == null || rhythm.bpm <= 0 || rhythm.beatConfidence < _minBeatConfidence) return null;
    return BeatGrid(
      bpm: rhythm.bpm,
      beatOffsetMS: rhythm.beatOffsetMS,
    );
  }

  ItemTiming? timingOf(Playable item) {
    final rhythm = _rhythms[item.key];
    if (rhythm == null || rhythm.audibleEndMS <= 0) return null;
    return ItemTiming(
      audibleStartMS: rhythm.audibleStartMS,
      audibleEndMS: rhythm.audibleEndMS,
      fadeOutStartMS: rhythm.fadeOutStartMS,
    );
  }

  QueueShuffler<Q> createFlowShuffler<Q extends Playable>() => _RhythmFlowShuffler<Q>(this);

  /// bpm 0 and key -1 when unknown.
  _Flow _flowOf(Playable item) {
    final rhythm = _rhythms[item.key];
    double bpm = rhythm != null && rhythm.bpm > 0 ? rhythm.bpm : 0.0;
    int key = rhythm != null && rhythm.keyConfidence >= _minKeyConfidence ? rhythm.key : -1;
    if (item is Selectable) {
      final trackExt = item.track.toTrackExt();
      if (bpm <= 0) bpm = (trackExt.bpm ?? 0).toDouble();
      final tagKey = _MusicalKey.parse(trackExt.musicalKey);
      if (tagKey >= 0) key = tagKey;
    }
    return (bpm: bpm, key: key);
  }

  void onItemPlaying() {
    if (!isEnabled || _version == null) return;
    _analysisTimer?.cancel();
    _analysisTimer = Timer(_analysisDelay, _queueAroundCurrent);
  }

  Future<void> _queueAroundCurrent() async {
    await ensureLoaded();
    final queue = Player.inst.currentQueue.value;
    if (queue.isEmpty) return;
    final index = Player.inst.currentIndex.value;
    final nextIndex = index + 1 < queue.length ? index + 1 : 0;
    _enqueue(queue[index], urgent: true);
    _enqueue(queue[nextIndex], urgent: true);
    final end = math.min(queue.length, nextIndex + 1 + _upcomingItemsToAnalyze);
    for (int i = nextIndex + 1; i < end; i++) {
      _enqueue(queue[i], urgent: false);
    }
    _analyzeQueued();
  }

  void toggleLibraryScan() {
    if (isScanning.value) {
      stopLibraryScan();
    } else {
      startLibraryScan();
    }
  }

  Future<void> startLibraryScan() async {
    if (isScanning.value || _version == null) return;
    await ensureLoaded();
    int total = 0;
    for (final track in Indexer.inst.tracksInfoList.value) {
      if (!track.isPhysical || _isUpToDate(track.path)) continue;
      _jobs[track.path] ??= _RhythmJob(track, isScan: true);
      total++;
    }
    scanDone.value = 0;
    scanTotal.value = total;
    isScanning.value = total > 0;
    _analyzeQueued();
  }

  void stopLibraryScan() {
    _jobs.removeWhere((_, job) => job.isScan);
    isScanning.value = false;
  }

  bool _isUpToDate(String key) => _rhythms[key]?.version == _version;

  void _enqueue(Playable item, {required bool urgent}) {
    final key = item.key;
    if (_isUpToDate(key)) return;
    if (urgent) {
      final queuedJob = _jobs.remove(key);
      _urgentJobs[key] ??= queuedJob ?? _RhythmJob(item, isScan: false);
    } else if (!_urgentJobs.containsKey(key)) {
      _jobs[key] ??= _RhythmJob(item, isScan: false);
    }
  }

  _RhythmJob? _takeNextJob() {
    final jobs = _urgentJobs.isNotEmpty ? _urgentJobs : _jobs;
    if (jobs.isEmpty) return null;
    return jobs.remove(jobs.keys.first);
  }

  Future<void> _analyzeQueued() async {
    if (_isAnalyzing) return;
    _isAnalyzing = true;
    try {
      _RhythmJob? job;
      while ((job = _takeNextJob()) != null) {
        await _analyze(job!);
        if (job.isScan) _onScanJobDone();
      }
    } finally {
      _isAnalyzing = false;
    }
  }

  void _onScanJobDone() {
    if (!isScanning.value) return;
    scanDone.value++;
    if (scanDone.value >= scanTotal.value) isScanning.value = false;
  }

  Future<void> _analyze(_RhythmJob job) async {
    final item = job.item;
    final key = item.key;
    if (_isUpToDate(key)) return;
    final source = await _sourceOf(item);
    if (source == null) return;
    final bpmHint = item is Selectable ? (item.track.bpm ?? 0).toDouble() : 0.0;
    final data = await _analyzer.analyze(source, bpmHint);
    // -- a file that can't be opened might be back later, anything else is final for this version
    if (data == null || data.error == WaveformError.openInput) return;
    final rhythm = _Rhythm.fromData(data, _version ?? 0);
    _rhythms[key] = rhythm;
    await _db.put(key, rhythm.toMap());
  }

  Future<String?> _sourceOf(Playable item) async {
    if (item is Selectable) {
      final track = item.track;
      return track.isPhysical ? track.path : null;
    }
    if (item is YoutubeID) {
      final cachedAudio = await AudioCacheController.inst.getCachedAudioForId(item.id);
      return cachedAudio?.file.path;
    }
    return null;
  }
}

/// Every next item is the best fitting of a few random picks, close in tempo and harmonically compatible, which keeps it a shuffle.
class _RhythmFlowShuffler<Q extends Playable> extends QueueShuffler<Q> {
  final RhythmController _controller;
  _RhythmFlowShuffler(this._controller);

  static const _picksPerItem = 6;
  static const _tempoCostStep = 0.06;
  static const _maxTempoCost = 3.0;
  static const _unknownCost = 1.0;
  static const _jitter = 0.3;

  static final _random = math.Random();

  @override
  void shuffleRange(List<Q> items, List<int>? pairedIndices, int start, int end) {
    final count = end - start;
    if (count < 3) return super.shuffleRange(items, pairedIndices, start, end);

    final bpms = Float64List(count);
    final keys = Int8List(count);
    for (int i = 0; i < count; i++) {
      final flow = _controller._flowOf(items[start + i]);
      bpms[i] = flow.bpm;
      keys[i] = flow.key;
    }

    void swap(int a, int b) {
      if (a == b) return;
      QueueShuffler.swap(items, pairedIndices, a, b);
      final bpm = bpms[a - start];
      bpms[a - start] = bpms[b - start];
      bpms[b - start] = bpm;
      final key = keys[a - start];
      keys[a - start] = keys[b - start];
      keys[b - start] = key;
    }

    int position = start;
    _Flow previous;
    if (start > 0) {
      previous = _controller._flowOf(items[start - 1]);
    } else {
      final first = start + _random.nextInt(count);
      swap(start, first);
      previous = (bpm: bpms[0], key: keys[0]);
      position++;
    }

    for (; position < end; position++) {
      final remaining = end - position;
      int best = position;
      double bestCost = double.infinity;
      final picks = math.min(_picksPerItem, remaining);
      for (int p = 0; p < picks; p++) {
        final candidate = position + _random.nextInt(remaining);
        final offset = candidate - start;
        final cost = _costBetween(previous, bpms[offset], keys[offset]) + _random.nextDouble() * _jitter;
        if (cost < bestCost) {
          bestCost = cost;
          best = candidate;
        }
      }
      swap(position, best);
      previous = (bpm: bpms[position - start], key: keys[position - start]);
    }
  }

  static double _costBetween(_Flow previous, double bpm, int key) {
    final tempoCost = previous.bpm <= 0 || bpm <= 0 ? _unknownCost : _tempoCostBetween(previous.bpm, bpm);
    final keyCost = previous.key < 0 || key < 0 ? _unknownCost : _MusicalKey.costBetween(previous.key, key);
    return tempoCost + keyCost;
  }

  /// tempos an octave apart mix as well as equal ones.
  static double _tempoCostBetween(double a, double b) {
    double ratio = b / a;
    while (ratio >= 1.5) {
      ratio /= 2;
    }
    while (ratio < 0.75) {
      ratio *= 2;
    }
    final steps = math.log(ratio).abs() / math.log(1 + _tempoCostStep);
    return steps.withMaximum(_maxTempoCost);
  }
}

/// Keys as `0..11` for the major keys C to B and `12..23` for the minor keys C to B.
class _MusicalKey {
  static final _parsed = <String, int>{};

  static final _camelotRegex = RegExp(r'^0?(1[0-2]|[1-9])\s*([ab])$', caseSensitive: false);
  static final _openKeyRegex = RegExp(r'^(1[0-2]|[1-9])\s*([dm])$', caseSensitive: false);
  static final _noteRegex = RegExp(r'^([a-g])\s*([#♯b♭]?)\s*(m|min|minor|maj|major)?$', caseSensitive: false);

  static const _noteClasses = {'c': 0, 'd': 2, 'e': 4, 'f': 5, 'g': 7, 'a': 9, 'b': 11};

  /// reads tags like `Am`, `C#`, `Dbm`, `A minor`, camelot `8A` and open key `1d`. -1 when it can't tell.
  static int parse(String raw) {
    if (raw.isEmpty) return -1;
    return _parsed[raw] ??= _parseTrimmed(raw.trim());
  }

  static int _parseTrimmed(String text) {
    final camelot = _camelotRegex.firstMatch(text);
    if (camelot != null) {
      final number = int.parse(camelot.group(1)!);
      final letter = camelot.group(2)!.toLowerCase();
      return _fromCamelot(number, isMinor: letter == 'a');
    }

    final openKey = _openKeyRegex.firstMatch(text);
    if (openKey != null) {
      final number = int.parse(openKey.group(1)!);
      final letter = openKey.group(2)!.toLowerCase();
      final camelotNumber = (number + 6) % 12 + 1;
      return _fromCamelot(camelotNumber, isMinor: letter == 'm');
    }

    final note = _noteRegex.firstMatch(text);
    if (note != null) {
      final noteLetter = note.group(1)!.toLowerCase();
      final noteClass = _noteClasses[noteLetter]!;
      final accidental = note.group(2) ?? '';
      final shift = accidental == '#' || accidental == '♯' ? 1 : (accidental.isEmpty ? 0 : -1);
      final mode = note.group(3);
      final modeLower = mode?.toLowerCase();
      // -- a capital M alone is major, any other spelling of m is minor
      final isMinor = mode != null && mode != 'M' && modeLower != 'maj' && modeLower != 'major';
      final tonic = (noteClass + shift + 12) % 12;
      return isMinor ? 12 + tonic : tonic;
    }
    return -1;
  }

  /// camelot 8 is C major, each step up is a fifth up, a minor key sits a minor third under its relative major.
  static int _fromCamelot(int number, {required bool isMinor}) {
    final majorTonic = ((number - 8) * 7 % 12 + 12) % 12;
    return isMinor ? 12 + (majorTonic + 9) % 12 : majorTonic;
  }

  static int _camelotNumber(int key) {
    final isMinor = key >= 12;
    final tonic = key % 12;
    final majorTonic = isMinor ? (tonic + 3) % 12 : tonic;
    return (majorTonic * 7 % 12 + 7) % 12 + 1;
  }

  /// 0 for the same key, 0.5 for a neighbour on the camelot wheel or the relative key, more the further apart.
  static double costBetween(int a, int b) {
    if (a == b) return 0.0;
    final difference = (_camelotNumber(a) - _camelotNumber(b)).abs();
    final steps = math.min(difference, 12 - difference);
    final isSameMode = (a >= 12) == (b >= 12);
    final distance = isSameMode ? steps : steps + 1;
    return switch (distance) {
      1 => 0.5,
      2 => 1.5,
      _ => 2.5,
    };
  }
}

class _RhythmIsolateManager with PortsProvider<SendPort> {
  final _completers = <int, Completer<RhythmData?>>{};
  final _messageTokenWrapper = IsolateMessageTokenWrapper.create();

  Future<RhythmData?> analyze(String source, double bpmHint) async {
    if (!isInitialized) await initialize();
    final token = _messageTokenWrapper.getToken();
    final completer = _completers[token] = Completer<RhythmData?>();
    sendPort([token, source, bpmHint]);
    return completer.future;
  }

  @override
  IsolateFunctionReturnBuild<SendPort> isolateFunction(SendPort port) {
    return IsolateFunctionReturnBuild(_prepareResourcesAndListen, port);
  }

  static void _prepareResourcesAndListen(SendPort sendPort) async {
    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) {
      if (p == PortsProviderMessages.disposed) {
        recievePort.close();
        streamSub?.cancel();
        return;
      }

      p as List;
      final token = p[0] as int;
      final source = p[1] as String;
      final bpmHint = p[2] as double;

      RhythmData? data;
      Object? error;
      try {
        data = NamidaRhythm.analyze(source, bpmHint: bpmHint);
      } catch (e) {
        error = e;
      }
      sendPort.send([token, data, ?error]);
    });

    sendPort.send(PortsProviderMessages.prepared);
  }

  @override
  void onResult(result) {
    result as List;
    final token = result[0] as int;
    final completer = _completers.remove(token);
    if (completer != null && !completer.isCompleted) completer.complete(result[1] as RhythmData?);
    if (result.length > 2) logger.error('RhythmController', e: result[2]);
  }
}

class _Rhythm {
  final double bpm;
  final double beatOffsetMS;
  final double beatConfidence;
  final int key;
  final double keyConfidence;
  final int audibleStartMS;
  final int audibleEndMS;
  final int fadeOutStartMS;
  final int version;

  const _Rhythm({
    required this.bpm,
    required this.beatOffsetMS,
    required this.beatConfidence,
    required this.key,
    required this.keyConfidence,
    required this.audibleStartMS,
    required this.audibleEndMS,
    required this.fadeOutStartMS,
    required this.version,
  });

  factory _Rhythm.fromData(RhythmData data, int version) {
    return _Rhythm(
      bpm: data.bpm,
      beatOffsetMS: data.beatOffsetMS,
      beatConfidence: data.beatConfidence,
      key: data.key,
      keyConfidence: data.keyConfidence,
      audibleStartMS: data.audibleStartMS,
      audibleEndMS: data.audibleEndMS,
      fadeOutStartMS: data.fadeOutStartMS,
      version: version,
    );
  }

  factory _Rhythm.fromMap(Map<String, dynamic> map) {
    return _Rhythm(
      bpm: (map['b'] as num).toDouble(),
      beatOffsetMS: (map['o'] as num).toDouble(),
      beatConfidence: (map['c'] as num).toDouble(),
      key: map['k'] as int,
      keyConfidence: (map['kc'] as num).toDouble(),
      audibleStartMS: map['s'] as int,
      audibleEndMS: map['e'] as int,
      fadeOutStartMS: map['f'] as int,
      version: map['v'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
    'b': bpm,
    'o': beatOffsetMS,
    'c': beatConfidence,
    'k': key,
    'kc': keyConfidence,
    's': audibleStartMS,
    'e': audibleEndMS,
    'f': fadeOutStartMS,
    'v': version,
  };
}

class _RhythmJob {
  final Playable item;
  final bool isScan;

  const _RhythmJob(this.item, {required this.isScan});
}

typedef _Flow = ({double bpm, int key});
