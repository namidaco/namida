// by claude
part of 'indexer_controller.dart';

class _FilteredFilesMemory {
  final String _filePath;
  _FilteredFilesMemory(this._filePath);

  final _files = <String, _FilteredFile>{};
  Future<void>? _loadFuture;
  bool _didChange = false;

  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    final json = await File(_filePath).readAsJson();
    if (json is! Map) return;
    for (final e in json.entries) {
      try {
        final String path = e.key;
        final List fileJson = e.value;
        _files[path] = _FilteredFile.fromJson(fileJson);
      } catch (_) {}
    }
  }

  bool isStillFiltered(String path, FilesStats stats, int index, {required int minSize, required int minDurMS}) {
    final file = _files[path];
    if (file == null || !stats.isKnownAt(index)) return false;
    // -- seconds, same as library tracks
    final isSameDate = file.modifiedMS ~/ 1000 == stats.modifiedMSAt(index) ~/ 1000;
    if (!isSameDate || file.size != stats.sizeAt(index)) return false;
    return file.isFiltered(minSize: minSize, minDurMS: minDurMS);
  }

  void add(String path, {required int size, required int modifiedMS, required int durationMS}) {
    _files[path] = _FilteredFile(size: size, modifiedMS: modifiedMS, durationMS: durationMS);
    _didChange = true;
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
    await file.writeAsJson(json);
  }
}

class _FilteredFile {
  final int size;
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

  List<int> toJson() => [size, modifiedMS, durationMS];

  /// same checks as [Indexer.convertTagToTrack].
  bool isFiltered({required int minSize, required int minDurMS}) {
    final isTooSmall = size < minSize;
    final isTooShort = durationMS != 0 && durationMS < minDurMS;
    return isTooSmall || isTooShort;
  }
}
