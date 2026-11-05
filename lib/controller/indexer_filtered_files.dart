// by claude
part of 'indexer_controller.dart';

class _SkippedFilesMemory<E extends _SkippedFile> {
  final String _filePath;
  final E Function(List json) _fromJson;
  _SkippedFilesMemory(this._filePath, this._fromJson);

  final _files = <String, E>{};
  Future<void>? _loadFuture;
  bool _didChange = false;

  int get length => _files.length;
  bool get isEmpty => _files.isEmpty;
  Iterable<MapEntry<String, E>> get entries => _files.entries;

  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    final json = await File(_filePath).readAsJson();
    if (json is! Map) return;
    for (final e in json.entries) {
      try {
        final String path = e.key;
        final List fileJson = e.value;
        _files[path] = _fromJson(fileJson);
      } catch (_) {}
    }
  }

  E? get(String path) => _files[path];

  E? getUnchanged(String path, FilesStats stats, int index) {
    final file = _files[path];
    if (file == null || !stats.isKnownAt(index)) return null;
    // -- seconds, same as library tracks
    final isSameDate = file.modifiedMS ~/ 1000 == stats.modifiedMSAt(index) ~/ 1000;
    if (!isSameDate || file.size != stats.sizeAt(index)) return null;
    return file;
  }

  void add(String path, E file) {
    _files[path] = file;
    _didChange = true;
  }

  void remove(String path) {
    final removed = _files.remove(path);
    if (removed != null) _didChange = true;
  }

  int removeAll(Iterable<String> paths) {
    final lengthBefore = _files.length;
    for (final path in paths) {
      _files.remove(path);
    }
    final removedCount = lengthBefore - _files.length;
    if (removedCount > 0) _didChange = true;
    return removedCount;
  }

  void retainOnly(Set<String> paths) {
    final lengthBefore = _files.length;
    _files.removeWhere((path, _) => !paths.contains(path));
    if (_files.length != lengthBefore) _didChange = true;
  }

  void clear() {
    if (_files.isEmpty) return;
    _files.clear();
    _didChange = true;
  }

  Future<void> saveIfChanged() async {
    if (!_didChange) return;
    _didChange = false;
    final file = File(_filePath);
    if (_files.isEmpty) {
      await file.deleteIfExists();
      return;
    }
    final json = {for (final e in _files.entries) e.key: e.value.toJson()};
    await file.writeAsJsonAtomic(json);
  }
}

abstract interface class _SkippedFile {
  int get size;
  int get modifiedMS;
  List<Object?> toJson();
}

class _FilteredFile implements _SkippedFile {
  @override
  final int size;
  @override
  final int modifiedMS;

  /// 0 when unknown.
  final int durationMS;

  const _FilteredFile({
    required this.size,
    required this.modifiedMS,
    required this.durationMS,
  });

  factory _FilteredFile.fromJson(List json) {
    return _FilteredFile(
      size: json[0],
      modifiedMS: json[1],
      durationMS: json[2],
    );
  }

  @override
  List<int> toJson() => [size, modifiedMS, durationMS];

  /// same checks as [Indexer.convertTagToTrack].
  bool isFiltered({required int minSize, required int minDurMS}) {
    final isTooSmall = size < minSize;
    final isTooShort = durationMS != 0 && durationMS < minDurMS;
    return isTooSmall || isTooShort;
  }
}

typedef FilteredTrackFile = ({String path, int size, int durationMS});
