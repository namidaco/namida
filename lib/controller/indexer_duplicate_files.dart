// all duplicate tracks logic by claude
part of 'indexer_controller.dart';

class _IndexerDuplicates<T extends Track> {
  final Indexer<T> _indexer;
  _IndexerDuplicates(this._indexer);

  final files = _SkippedFilesMemory(AppPaths.TRACKS_DUPLICATED, _DuplicateFile.fromJson);

  Future<void> load() async {
    await files.ensureLoaded();
    _indexer.duplicatedTracksLength.value = files.length;
  }

  /// copies whose kept track left the library or changed.
  List<String> popOrphans() {
    final libraryTracks = _indexer.allTracksMappedByPath;
    final orphanPaths = <String>[];
    for (final e in files.entries) {
      final file = e.value;
      final kept = libraryTracks[file.keptPath];
      if (kept != null && file.isCopyOf(kept)) continue;
      orphanPaths.add(e.key);
    }
    for (final path in orphanPaths) {
      files.remove(path);
    }
    return orphanPaths;
  }

  Future<void> onRefreshed(_DuplicatesResolver? resolver) async {
    resolver?.addCopiesTo(files);
    _indexer.duplicatedTracksLength.value = files.length;
    await files.saveIfChanged();
  }

  void onDeleted(Iterable<String> paths) {
    if (files.isEmpty) return;
    final removedCount = files.removeAll(paths);
    if (removedCount == 0) return;
    _indexer.duplicatedTracksLength.value = files.length;
    unawaited(files.saveIfChanged());
  }

  /// enabling keeps the best copy of each track in the library, disabling indexes all the copies back.
  Future<void> onToggled(bool isEnabled) async {
    await files.ensureLoaded();
    if (isEnabled) {
      final resolver = _DuplicatesResolver.empty();
      for (final tr in _indexer.allTracksMappedByPath.values) {
        resolver.shouldAdd(tr);
      }
      final copies = resolver.addCopiesTo(files);
      final tracksToRemove = copies.map((e) => e.asTrack());
      await _indexer.removeTracksFromLibrary(tracksToRemove, isFromDelete: false);
    } else {
      final paths = files.entries.map((e) => e.key).toFixedList();
      files.clear();
      await _indexer.convertPathsToTracksAndAddToLists(paths);
    }
    _indexer.duplicatedTracksLength.value = files.length;
    await files.saveIfChanged();
  }

  List<DuplicateTracksGroup> getGroups() {
    final copiesByKeptPath = <String, List<MapEntry<String, _DuplicateFile>>>{};
    for (final e in files.entries) {
      copiesByKeptPath.addForce(e.value.keptPath, e);
    }

    final libraryTracks = _indexer.allTracksMappedByPath;
    final groups = <DuplicateTracksGroup>[];
    for (final e in copiesByKeptPath.entries) {
      final keptPath = e.key;
      final copies = e.value;
      final kept = libraryTracks[keptPath];
      var bestPath = keptPath;
      var bestQuality = kept == null ? null : _DuplicateQuality.ofTrack(kept);
      for (final copy in copies) {
        final quality = _DuplicateQuality.ofFile(copy.value);
        if (bestQuality != null && quality.compareTo(bestQuality) <= 0) continue;
        bestQuality = quality;
        bestPath = copy.key;
      }
      final groupCopies = copies.map((copy) => copy.value.toCopy(copy.key)).toFixedList();
      groups.add((keptPath: keptPath, bestPath: bestPath, copies: groupCopies));
    }
    groups.sortBy((e) => e.keptPath);
    return groups;
  }

  /// indexes [copyPath] instead of its kept track, history, playlists and stats move to it.
  Future<void> useCopy(String copyPath) async {
    final copy = files.get(copyPath);
    if (copy == null) return;
    final keptPath = copy.keptPath;
    final kept = _indexer.allTracksMappedByPath[keptPath];

    files.remove(copyPath);
    if (kept != null) {
      final keptAsCopy = _DuplicateFile.ofTrack(kept, keptPath: copyPath, key: copy.key);
      files.add(keptPath, keptAsCopy);
    }
    final otherCopies = files.entries.where((e) => e.value.keptPath == keptPath).toFixedList();
    for (final e in otherCopies) {
      final repointed = e.value.copyWithKeptPath(copyPath);
      files.add(e.key, repointed);
    }

    await EditDeleteController.inst.updateTrackPathInEveryPartOfNamidaBulk({keptPath: copyPath}, removeOldTracksFromLibrary: true);
    _indexer.duplicatedTracksLength.value = files.length;
    await files.saveIfChanged();
  }
}

/// keeps one copy of each track while indexing, copies have the same title, artist and duration.
/// a copy already in the library always wins, otherwise the best quality one.
class _DuplicatesResolver {
  static const _kDurationToleranceMS = 2000;
  static const _kFnvOffset = 0xcbf29ce484222325;
  static const _kFnvPrime = 0x100000001b3;
  static const _kFieldSeparator = 0x1F;
  static const _kVideoMark = 0x76;

  final _libraryCopies = <int, List<TrackExtended>>{};
  final _groupsByKey = <int, List<_DuplicateGroup>>{};

  /// added earlier in the same refresh, then replaced by a better copy.
  final replacedPaths = <String>{};

  _DuplicatesResolver.empty();

  _DuplicatesResolver.ofLibrary(Iterable<TrackExtended> tracks) {
    for (final tr in tracks) {
      final key = keyOf(tr);
      if (key == null) continue;
      _libraryCopies.addForce(key, tr);
    }
  }

  static int? keyOf(TrackExtended tr) {
    if (tr.durationMS <= 0 || tr.isNetwork) return null;
    var hash = _hashText(_kFnvOffset, tr.title);
    hash = (hash ^ _kFieldSeparator) * _kFnvPrime;
    hash = _hashText(hash, tr.originalArtist);
    if (tr.isVideo) hash = (hash ^ _kVideoMark) * _kFnvPrime;
    return hash;
  }

  static int _hashText(int hash, String text) {
    final lowerText = text.toLowerCase();
    for (int i = 0; i < lowerText.length; i++) {
      final unit = lowerText.codeUnitAt(i);
      if (_isIgnoredUnit(unit)) continue;
      hash = (hash ^ unit) * _kFnvPrime;
    }
    return hash;
  }

  /// symbols and spaces, so `Song (Live)` matches `song - live`.
  static bool _isIgnoredUnit(int unit) {
    if (unit < 0x80) {
      final isDigit = unit >= 0x30 && unit <= 0x39;
      final isLetter = unit >= 0x61 && unit <= 0x7A;
      return !isDigit && !isLetter;
    }
    final isLatinPunctuation = unit <= 0xBF;
    final isGeneralPunctuation = unit >= 0x2000 && unit <= 0x206F;
    final isCjkPunctuation = unit >= 0x3000 && unit <= 0x303F;
    return isLatinPunctuation || isGeneralPunctuation || isCjkPunctuation;
  }

  static bool isSameDuration(int durationMS, int otherDurationMS) {
    final difference = (durationMS - otherDurationMS).abs();
    return difference <= _kDurationToleranceMS;
  }

  static String? recordingIdOf(TrackExtended tr) {
    final recordingId = tr.extraTags?[TagLibField.MUSICBRAINZ_TRACKID];
    return recordingId?.nullifyEmpty();
  }

  /// known and different recording ids are other versions (mono/stereo mixes, re-recordings).
  static bool isCopyOf(TrackExtended kept, {required int durationMS, required String? recordingId}) {
    if (!isSameDuration(kept.durationMS, durationMS)) return false;
    final keptRecordingId = recordingIdOf(kept);
    return recordingId == null || keptRecordingId == null || recordingId == keptRecordingId;
  }

  bool shouldAdd(TrackExtended tr) {
    final key = keyOf(tr);
    if (key == null) return true;
    final group = _findGroup(key, tr);
    if (group == null) {
      final newGroup = _DuplicateGroup(key: key, kept: tr, isKeptFromLibrary: false);
      _groupsByKey.addForce(key, newGroup);
      return true;
    }

    final kept = group.kept;
    final isPreferredOverKept = !group.isKeptFromLibrary && _isPreferred(tr, kept);
    if (!isPreferredOverKept) {
      group.copies.add(tr);
      return false;
    }
    replacedPaths.add(kept.path);
    group.copies.add(kept);
    group.kept = tr;
    return true;
  }

  /// equal quality falls back to the older file then the path, so a re-index keeps the same copy.
  static bool _isPreferred(TrackExtended tr, TrackExtended kept) {
    final quality = _DuplicateQuality.ofTrack(tr);
    final keptQuality = _DuplicateQuality.ofTrack(kept);
    final qualityOrder = quality.compareTo(keptQuality);
    if (qualityOrder != 0) return qualityOrder > 0;
    if (tr.dateModified != kept.dateModified) return tr.dateModified < kept.dateModified;
    return tr.path.compareTo(kept.path) < 0;
  }

  _DuplicateGroup? _findGroup(int key, TrackExtended tr) {
    final groups = _groupsByKey[key];
    final libraryCopies = _libraryCopies[key];
    if (groups == null && libraryCopies == null) return null;

    final durationMS = tr.durationMS;
    final recordingId = recordingIdOf(tr);
    if (groups != null) {
      for (final group in groups) {
        if (isCopyOf(group.kept, durationMS: durationMS, recordingId: recordingId)) return group;
      }
    }

    if (libraryCopies == null) return null;
    for (final copy in libraryCopies) {
      if (!isCopyOf(copy, durationMS: durationMS, recordingId: recordingId)) continue;
      final group = _DuplicateGroup(key: key, kept: copy, isKeptFromLibrary: true);
      _groupsByKey.addForce(key, group);
      return group;
    }
    return null;
  }

  List<TrackExtended> addCopiesTo(_SkippedFilesMemory<_DuplicateFile> files) {
    final copies = <TrackExtended>[];
    for (final groups in _groupsByKey.values) {
      for (final group in groups) {
        final keptPath = group.kept.path;
        for (final copy in group.copies) {
          final file = _DuplicateFile.ofTrack(copy, keptPath: keptPath, key: group.key);
          files.add(copy.path, file);
          copies.add(copy);
        }
      }
    }
    return copies;
  }
}

class _DuplicateGroup {
  final int key;
  final bool isKeptFromLibrary;
  TrackExtended kept;
  final copies = <TrackExtended>[];

  _DuplicateGroup({
    required this.key,
    required this.kept,
    required this.isKeptFromLibrary,
  });
}

class _DuplicateFile implements _SkippedFile {
  @override
  final int size;
  @override
  final int modifiedMS;
  final String keptPath;
  final int key;
  final int durationMS;
  final String format;
  final int bitrate;
  final int sampleRate;
  final int bits;
  final bool isLossless;

  /// empty when unknown.
  final String recordingId;

  const _DuplicateFile({
    required this.size,
    required this.modifiedMS,
    required this.keptPath,
    required this.key,
    required this.durationMS,
    required this.format,
    required this.bitrate,
    required this.sampleRate,
    required this.bits,
    required this.isLossless,
    required this.recordingId,
  });

  factory _DuplicateFile.ofTrack(TrackExtended tr, {required String keptPath, required int key}) {
    return _DuplicateFile(
      size: tr.size,
      modifiedMS: tr.dateModified,
      keptPath: keptPath,
      key: key,
      durationMS: tr.durationMS,
      format: tr.format,
      bitrate: tr.bitrate,
      sampleRate: tr.sampleRate,
      bits: tr.bits,
      isLossless: tr.isLossless == true,
      recordingId: _DuplicatesResolver.recordingIdOf(tr) ?? '',
    );
  }

  factory _DuplicateFile.fromJson(List json) {
    return _DuplicateFile(
      size: json[0],
      modifiedMS: json[1],
      keptPath: json[2],
      key: json[3],
      durationMS: json[4],
      format: json[5],
      bitrate: json[6],
      sampleRate: json[7],
      bits: json[8],
      isLossless: json[9],
      recordingId: json[10],
    );
  }

  @override
  List<Object> toJson() => [size, modifiedMS, keptPath, key, durationMS, format, bitrate, sampleRate, bits, isLossless, recordingId];

  bool isCopyOf(TrackExtended kept) {
    final keptKey = _DuplicatesResolver.keyOf(kept);
    if (keptKey != key) return false;
    final knownRecordingId = recordingId.nullifyEmpty();
    return _DuplicatesResolver.isCopyOf(kept, durationMS: durationMS, recordingId: knownRecordingId);
  }

  _DuplicateFile copyWithKeptPath(String keptPath) {
    return _DuplicateFile(
      size: size,
      modifiedMS: modifiedMS,
      keptPath: keptPath,
      key: key,
      durationMS: durationMS,
      format: format,
      bitrate: bitrate,
      sampleRate: sampleRate,
      bits: bits,
      isLossless: isLossless,
      recordingId: recordingId,
    );
  }

  DuplicateTrackCopy toCopy(String path) {
    return (
      path: path,
      size: size,
      durationMS: durationMS,
      format: format,
      bitrate: bitrate,
      sampleRate: sampleRate,
      isLossless: isLossless,
    );
  }
}

class _DuplicateQuality {
  final bool isLossless;
  final int bitrate;
  final int sampleRate;
  final int bits;
  final int size;

  const _DuplicateQuality({
    required this.isLossless,
    required this.bitrate,
    required this.sampleRate,
    required this.bits,
    required this.size,
  });

  factory _DuplicateQuality.ofTrack(TrackExtended tr) {
    return _DuplicateQuality(
      isLossless: tr.isLossless == true,
      bitrate: tr.bitrate,
      sampleRate: tr.sampleRate,
      bits: tr.bits,
      size: tr.size,
    );
  }

  factory _DuplicateQuality.ofFile(_DuplicateFile file) {
    return _DuplicateQuality(
      isLossless: file.isLossless,
      bitrate: file.bitrate,
      sampleRate: file.sampleRate,
      bits: file.bits,
      size: file.size,
    );
  }

  int compareTo(_DuplicateQuality other) {
    if (isLossless != other.isLossless) return isLossless ? 1 : -1;
    if (bitrate != other.bitrate) return bitrate.compareTo(other.bitrate);
    if (sampleRate != other.sampleRate) return sampleRate.compareTo(other.sampleRate);
    if (bits != other.bits) return bits.compareTo(other.bits);
    return size.compareTo(other.size);
  }
}

typedef DuplicateTrackCopy = ({String path, int size, int durationMS, String format, int bitrate, int sampleRate, bool isLossless});
typedef DuplicateTracksGroup = ({String keptPath, String bestPath, List<DuplicateTrackCopy> copies});
