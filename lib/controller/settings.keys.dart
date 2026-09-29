// by claude
part of 'settings_controller.dart';

/// keys are declared `late final` and decode on first access.
/// reserved file keys: `_v` format version, `_legacy` names not yet migrated from the full-dump format, `_m` modification times of synced keys,
/// `_x` enum values a customized enum list left out, to tell them apart from values added to the enum later.
sealed class _SettingsKeysWriter with SettingsFileWriter {
  static const _kVersion = 2;

  /// older than any real change, so a value set on another device always wins over a migrated one.
  static const _kLegacyModifiedMS = 1;

  Map<String, dynamic> _raw = {'_v': _kVersion};
  List? _legacy;
  final _keys = <String, _SettingsKey>{};
  bool _didCreateAllKeys = false;

  bool get syncable => false;

  void _createAllKeys() {
    if (_didCreateAllKeys) return;
    _allSettingsKeys(this);
    _didCreateAllKeys = true;
  }

  @override
  Map<String, dynamic> buildJson() => _raw;

  @override
  Map<String, dynamic> redactedJson() {
    final json = Map<String, dynamic>.of(_raw);
    return redactSensitive_(json);
  }

  /// every key's resolved value, encoded. only keys created so far are included.
  @override
  Map<String, dynamic> debugFullJson() {
    return {for (final key in _keys.values) key.name: key._encode(key.value)};
  }

  _SettingsKey<T> _key<T>(String name, T fallback, {_SettingsCodec<T>? codec, bool sync = true}) {
    final key = _SettingsKey<T>._(this, name, fallback, codec, sync);
    key._load(_raw[name]);
    return _keys[name] = key;
  }

  _SettingsKey<E> _keyEnum<E extends Enum>(String name, E fallback, List<E> values, {bool sync = true}) {
    return _key(name, fallback, codec: _EnumCodec(values), sync: sync);
  }

  _SettingsKey<T> _keyObject<T>(String name, T fallback, T? Function(Map<String, dynamic> json) fromJson, Object? Function(T value) toJson, {bool sync = true}) {
    return _key(name, fallback, codec: _ObjectCodec(fromJson, toJson), sync: sync);
  }

  _SettingsListKey<T> _keyList<T>(String name, List<T> fallback, {_SettingsCodec<T>? item, bool sync = true}) {
    final key = _SettingsListKey<T>._(this, name, _ProtectedList(fallback), _ListCodec(item), sync);
    key._load(_raw[name]);
    return _keys[name] = key;
  }

  /// a list of distinct enum values, a customized one still gains values added to the enum afterwards, when the default has them.
  _SettingsEnumListKey<E> _keyEnumList<E extends Enum>(String name, List<E> fallback, List<E> values, {_SettingsCodec<E>? item, bool sync = true}) {
    final key = _SettingsEnumListKey<E>._(this, name, _ProtectedList(fallback), _ListCodec(item ?? _EnumCodec(values), isUnique: true), sync, values);
    key._load(_raw[name]);
    return _keys[name] = key;
  }

  _SettingsSetKey<T> _keySet<T>(String name, Set<T> fallback, {_SettingsCodec<T>? item, bool sync = true}) {
    final key = _SettingsSetKey<T>._(this, name, _ProtectedSet(fallback), _SetCodec(item), sync);
    key._load(_raw[name]);
    return _keys[name] = key;
  }

  _SettingsMapKey<K, V> _keyMap<K, V>(String name, Map<K, V> fallback, {_SettingsCodec<K>? key, _SettingsCodec<V>? value, bool sync = true}) {
    final mapKey = _SettingsMapKey<K, V>._(this, name, _ProtectedMap(fallback), _MapCodec(key, value), sync);
    mapKey._load(_raw[name]);
    return _keys[name] = mapKey;
  }

  @override
  Future<void> prepareSettingsFile() async {
    final json = await prepareSettingsFile_();
    bool isLegacyFormat = false;
    if (json is! Map<String, dynamic>) {
      _raw = {'_v': _kVersion};
      _legacy = null;
    } else if (json['_v'] == null) {
      isLegacyFormat = true;
      final legacy = json.keys.toList();
      json['_legacy'] = legacy;
      json['_v'] = _kVersion;
      _legacy = legacy;
      _raw = json;
      _migrateLegacy();
    } else {
      _legacy = json['_legacy'];
      _raw = json;
      json['_v'] = _kVersion;
    }
    _migrateKeys();
    for (final key in _keys.values) {
      key._load(_raw[key.name]);
    }
    _onLoaded();
    if (isLegacyFormat || _legacy != null) _finishLegacyMigration();
  }

  /// creating every key consumes its legacy value, whatever is left belongs to no key anymore.
  void _finishLegacyMigration() {
    _createAllKeys();
    final unknownNames = _legacy;
    if (unknownNames != null) {
      for (final name in unknownNames) {
        _raw.remove(name);
      }
      _raw.remove('_legacy');
      _legacy = null;
    }
    if (syncable) _markMigratedKeysModified();
    writeToStorage();
  }

  void _markMigratedKeysModified() {
    for (final key in _keys.values) {
      final name = key.name;
      if (!key.sync || !_raw.containsKey(name)) continue;
      final Map modified = _raw['_m'] ??= <String, dynamic>{};
      if (!modified.containsKey(name)) modified[name] = _kLegacyModifiedMS;
    }
  }

  /// runs before keys load, only for a file still in the full-dump format.
  void _migrateLegacy() {}

  /// runs before keys load, for every file format. used when a key changes its format under a new name,
  /// so devices syncing with an older version keep reading the name they know.
  void _migrateKeys() {}

  /// runs after every load, for values that depend on other keys.
  void _onLoaded() {}

  void _migrateKey(String oldName, String newName, Object? Function(dynamic json) convert) {
    if (!_raw.containsKey(oldName)) return;
    final json = _raw.remove(oldName);
    _takeLegacy(oldName);
    final converted = convert(json);
    if (converted != null) _raw[newName] = converted;
  }

  dynamic _dropKey(String name) {
    _takeLegacy(name);
    return _raw.remove(name);
  }

  int _transactionDepth = 0;
  bool _isTransactionDirty = false;

  void transaction(void Function() fn) {
    _transactionDepth++;
    try {
      fn();
    } finally {
      _transactionDepth--;
      if (_transactionDepth == 0 && _isTransactionDirty) {
        _isTransactionDirty = false;
        writeToStorage();
      }
    }
  }

  void _markDirty() {
    if (_transactionDepth > 0) {
      _isTransactionDirty = true;
    } else {
      writeToStorage();
    }
  }

  /// changes made after [sinceMS]. a name in `m` without a value in `v` was reset to default.
  @override
  Map<String, dynamic>? syncDelta(int sinceMS) {
    final modified = _raw['_m'] as Map?;
    if (modified == null) return null;
    _createAllKeys();
    final v = <String, dynamic>{};
    final m = <String, dynamic>{};
    for (final e in modified.entries) {
      if (e.value <= sinceMS) continue;
      final name = e.key;
      final key = _keys[name];
      if (key == null || !key.sync) continue;
      m[name] = e.value;
      final json = _raw[name];
      if (json != null) v[name] = json;
    }
    return m.isEmpty ? null : {'v': v, 'm': m};
  }

  /// newest modification wins per key.
  @override
  void applySyncDelta(Map delta) {
    if (!syncable) return;
    final Map values = delta['v'];
    final Map incoming = delta['m'];
    _createAllKeys();
    final Map modified = _raw['_m'] ??= <String, dynamic>{};
    bool didChange = false;
    for (final e in incoming.entries) {
      final String name = e.key;
      final key = _keys[name];
      if (key == null || !key.sync) continue;
      final int ms = e.value;
      if (ms <= (modified[name] ?? 0)) continue;
      final json = values[name];
      if (json == null) {
        _raw.remove(name);
      } else {
        _raw[name] = json;
      }
      modified[name] = ms;
      key._loadFromPeer(json);
      didChange = true;
    }
    if (didChange) writeToStorage();
  }

  bool _takeLegacy(String name) {
    final legacy = _legacy;
    if (legacy == null) return false;
    final wasLegacy = legacy.remove(name);
    if (legacy.isEmpty) {
      _raw.remove('_legacy');
      _legacy = null;
    }
    return wasLegacy;
  }

  static bool _jsonEquals(dynamic a, dynamic b) {
    if (a is Map) {
      if (b is! Map || a.length != b.length) return false;
      for (final e in a.entries) {
        if (!b.containsKey(e.key) || !_jsonEquals(e.value, b[e.key])) return false;
      }
      return true;
    }
    if (a is List) {
      if (b is! List || a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_jsonEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}

/// [value] is [userValue] or, when none is set, [fallback].
class _SettingsKey<T> extends Rx<T> {
  final String name;
  final bool sync;
  final T fallback;
  final _SettingsKeysWriter _owner;
  final _SettingsCodec<T>? _codec;
  T? _override;

  _SettingsKey._(this._owner, this.name, this.fallback, this._codec, this.sync) : super(fallback);

  T? get userValue => _override;

  @protected
  @override
  set value(T other) => throw _DirectKeyWriteError();

  @protected
  @override
  void set(T val) => throw _DirectKeyWriteError();

  void _setValue(T newValue) => super.value = newValue;

  late final Object? _encodedFallback = _encode(fallback);

  /// a value equal to the default is kept as no override, so later changes to the default still reach it.
  void save(T? value) {
    final stored = value == null ? null : _encodeForStorage(value);
    final newOverride = stored == null ? null : value;
    _override = newOverride;
    final newValue = newOverride ?? fallback;
    _setValue(newValue);
    _writeIfChanged(stored);
  }

  void reset() => save(null);

  /// the override collection [fn] mutates, copied from the default when there is none yet.
  T _overrideForUpdate() {
    final current = _override;
    if (current != null) return current;
    final copy = _copyOfFallback();
    _override = copy;
    super.set(copy);
    return copy;
  }

  void _afterUpdate(T current) {
    final stored = _encodeForStorage(current);
    if (stored == null) {
      _override = null;
      _setValue(fallback);
    } else {
      refresh();
    }
    _writeIfChanged(stored);
  }

  T _copyOfFallback() {
    final codec = _codec!;
    final encoded = codec.encode(fallback);
    return codec.decode(encoded) ?? fallback;
  }

  Object? _encode(T value) {
    if (value == null) return null;
    final codec = _codec;
    return codec == null ? value : codec.encode(value);
  }

  /// what goes to the file, null means nothing differs from the default.
  Object? _encodeForStorage(T value) {
    final encoded = _encode(value);
    if (_SettingsKeysWriter._jsonEquals(encoded, _encodedFallback)) return null;
    return encoded;
  }

  void _writeIfChanged(Object? stored) {
    final raw = _owner._raw;
    if (_SettingsKeysWriter._jsonEquals(stored, raw[name])) return;
    _setStored(stored);
    if (sync && _owner.syncable) {
      final Map modified = raw['_m'] ??= <String, dynamic>{};
      modified[name] = DateTime.now().millisecondsSinceEpoch;
    }
    _owner._markDirty();
  }

  void _setStored(Object? stored) {
    final raw = _owner._raw;
    if (stored == null) {
      raw.remove(name);
    } else {
      raw[name] = stored;
    }
  }

  void _loadFromPeer(dynamic json) => _load(json);

  void _load(dynamic json) {
    if (_owner._takeLegacy(name)) {
      final isDefault = json == null || _SettingsKeysWriter._jsonEquals(json, _encodedFallback);
      if (isDefault) {
        _owner._raw.remove(name);
        json = null;
      }
    }
    T? decoded;
    if (json != null) {
      final codec = _codec;
      if (codec != null) {
        decoded = codec.decode(json);
      } else if (json is T) {
        decoded = json;
      } else if (json is int && fallback is double) {
        decoded = json.toDouble() as T;
      }
    }
    _override = decoded;
    final newValue = decoded ?? fallback;
    _setValue(newValue);
  }
}

class _SettingsListKey<T> extends _SettingsKey<_ProtectedList<T>> {
  _SettingsListKey._(super.owner, super.name, super.fallback, super.codec, super.sync) : super._();

  void update(void Function(List<T> value) fn) {
    final current = _overrideForUpdate();
    fn(current._source);
    _afterUpdate(current);
  }

  void replace(List<T> value) => save(_ProtectedList(value));
}

/// a stored list records the enum values it left out, any other missing value was added to the enum later and joins the list when the default has it.
/// load only fixes `_raw` in memory (a missing record, added values), the next write persists it.
class _SettingsEnumListKey<E extends Enum> extends _SettingsListKey<E> {
  final List<E> _values;

  _SettingsEnumListKey._(super.owner, super.name, super.fallback, super.codec, super.sync, this._values) : super._();

  @override
  void _load(dynamic json) {
    super._load(json);
    final override = _override;
    if (override == null) return;
    final Map? records = _owner._raw['_x'];
    final excludedNames = records?[name];
    if (excludedNames is List) {
      final list = override._source;
      final defaults = fallback._source;
      bool didFindAdded = false;
      for (final enumValue in _values) {
        if (list.contains(enumValue) || excludedNames.contains(enumValue.name)) continue;
        didFindAdded = true;
        final defaultIndex = defaults.indexOf(enumValue);
        if (defaultIndex != -1) list.insertSafe(defaultIndex, enumValue);
      }
      if (!didFindAdded) return;
    }
    final stored = _encodeForStorage(override);
    if (stored == null) {
      _override = null;
      _setValue(fallback);
    }
    _setStored(stored);
  }

  /// the peer's list is taken as is, nothing in it counts as added to the enum.
  @override
  void _loadFromPeer(dynamic json) {
    _removeRecord();
    _load(json);
  }

  @override
  void _setStored(Object? stored) {
    super._setStored(stored);
    final override = _override;
    if (stored == null || override == null) {
      _removeRecord();
      return;
    }
    final Map records = _owner._raw['_x'] ??= <String, dynamic>{};
    records[name] = [
      for (final enumValue in _values)
        if (!override.contains(enumValue)) enumValue.name,
    ];
  }

  void _removeRecord() {
    final raw = _owner._raw;
    final Map? records = raw['_x'];
    if (records == null) return;
    records.remove(name);
    if (records.isEmpty) raw.remove('_x');
  }
}

class _SettingsSetKey<T> extends _SettingsKey<_ProtectedSet<T>> {
  _SettingsSetKey._(super.owner, super.name, super.fallback, super.codec, super.sync) : super._();

  @override
  Object? _encodeForStorage(_ProtectedSet<T> value) {
    if (value.length == fallback.length && value.containsAll(fallback)) return null;
    return _encode(value);
  }

  void update(void Function(Set<T> value) fn) {
    final current = _overrideForUpdate();
    fn(current._source);
    _afterUpdate(current);
  }

  void replace(Set<T> value) => save(_ProtectedSet(value));
}

/// only entries that differ from a non-empty default are stored, the rest is merged back in on load,
/// so entries added to or changed in the default later still apply.
class _SettingsMapKey<K, V> extends _SettingsKey<_ProtectedMap<K, V>> {
  _SettingsMapKey._(super.owner, super.name, super.fallback, super.codec, super.sync) : super._();

  @override
  void _load(dynamic json) {
    super._load(json);
    final override = _override;
    if (override == null || fallback.isEmpty) return;
    for (final e in fallback._source.entries) {
      override._source.putIfAbsent(e.key, () => e.value);
    }
    final stored = _encodeForStorage(override);
    _setStored(stored);
  }

  @override
  Object? _encodeForStorage(_ProtectedMap<K, V> value) {
    final json = _encode(value) as Map<String, dynamic>;
    final defaults = _encodedFallback as Map<String, dynamic>;
    if (defaults.isNotEmpty) json.removeWhere((key, entry) => defaults.containsKey(key) && _SettingsKeysWriter._jsonEquals(entry, defaults[key]));
    return json.isEmpty ? null : json;
  }

  void update(void Function(Map<K, V> value) fn) {
    final current = _overrideForUpdate();
    fn(current._source);
    _afterUpdate(current);
  }

  void replace(Map<K, V> value) => save(_ProtectedMap(value));
}

abstract class _SettingsCodec<T> {
  const _SettingsCodec();

  /// null means the stored value is unusable and the default applies.
  T? decode(dynamic json);
  Object? encode(T value);
}

class _EnumCodec<E extends Enum> extends _SettingsCodec<E> {
  final List<E> values;
  const _EnumCodec(this.values);

  @override
  E? decode(dynamic json) => json is String ? values.getEnum(json) : null;

  @override
  Object? encode(E value) => value.name;
}

class _ObjectCodec<T> extends _SettingsCodec<T> {
  final T? Function(Map<String, dynamic> json) fromJson;
  final Object? Function(T value) toJson;
  const _ObjectCodec(this.fromJson, this.toJson);

  @override
  T? decode(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Object? encode(T value) => toJson(value);
}

class _ListCodec<T> extends _SettingsCodec<_ProtectedList<T>> {
  final _SettingsCodec<T>? item;
  final bool isUnique;
  const _ListCodec(this.item, {this.isUnique = false});

  @override
  _ProtectedList<T>? decode(dynamic json) {
    if (json is! List) return null;
    final items = _decodeItems(json, item);
    final list = isUnique ? items.toSet().toList() : items.toList();
    return _ProtectedList(list);
  }

  @override
  Object? encode(_ProtectedList<T> value) => _encodeItems(value._source, item);
}

/// for lists nested inside another key's value, which are mutated through the outer key.
class _PlainListCodec<T> extends _SettingsCodec<List<T>> {
  final _SettingsCodec<T>? item;
  const _PlainListCodec(this.item);

  @override
  List<T>? decode(dynamic json) => json is List ? _decodeItems(json, item).toList() : null;

  @override
  Object? encode(List<T> value) => _encodeItems(value, item);
}

class _SetCodec<T> extends _SettingsCodec<_ProtectedSet<T>> {
  final _SettingsCodec<T>? item;
  const _SetCodec(this.item);

  @override
  _ProtectedSet<T>? decode(dynamic json) {
    if (json is! List) return null;
    final set = _decodeItems(json, item).toSet();
    return _ProtectedSet(set);
  }

  @override
  Object? encode(_ProtectedSet<T> value) => _encodeItems(value._source, item);
}

class _MapCodec<K, V> extends _SettingsCodec<_ProtectedMap<K, V>> {
  final _SettingsCodec<K>? keyCodec;
  final _SettingsCodec<V>? valueCodec;
  const _MapCodec(this.keyCodec, this.valueCodec);

  @override
  _ProtectedMap<K, V>? decode(dynamic json) {
    if (json is! Map) return null;
    final keyCodec = this.keyCodec;
    final valueCodec = this.valueCodec;
    final map = <K, V>{};
    for (final e in json.entries) {
      final key = keyCodec == null ? e.key : keyCodec.decode(e.key);
      if (key is! K) continue;
      final value = valueCodec == null ? e.value : valueCodec.decode(e.value);
      if (value is! V) continue;
      map[key] = value;
    }
    return _ProtectedMap(map);
  }

  @override
  Object? encode(_ProtectedMap<K, V> value) {
    final keyCodec = this.keyCodec;
    final valueCodec = this.valueCodec;
    final json = <String, dynamic>{};
    for (final e in value._source.entries) {
      final key = keyCodec == null ? e.key : keyCodec.encode(e.key);
      final entryValue = e.value;
      json[key as String] = valueCodec == null || entryValue == null ? entryValue : valueCodec.encode(entryValue);
    }
    return json;
  }
}

Iterable<T> _decodeItems<T>(List json, _SettingsCodec<T>? item) {
  if (item == null) return json.whereType<T>();
  return json.map<T?>(item.decode).whereType<T>();
}

List<Object?> _encodeItems<T>(Iterable<T> value, _SettingsCodec<T>? item) {
  if (item == null) return value.toFixedList();
  return value.map(item.encode).toFixedList();
}

extension _EnumValuesCodec<E extends Enum> on List<E> {
  _SettingsCodec<E> asCodec() => _EnumCodec(this);
}

/// read-only view over a key's collection. mutation goes through the key's `update`,
/// the analyzer reports direct calls and they throw at runtime.
class _ProtectedList<E> extends ListBase<E> {
  final List<E> _source;
  const _ProtectedList(this._source);

  @override
  E operator [](int index) => _source[index];
  @override
  int get length => _source.length;
  @override
  bool get isEmpty => _source.isEmpty;
  @override
  bool get isNotEmpty => _source.isNotEmpty;
  @override
  Iterator<E> get iterator => _source.iterator;
  @override
  E get first => _source.first;
  @override
  E get last => _source.last;
  @override
  bool contains(Object? element) => _source.contains(element);
  @override
  int indexOf(Object? element, [int start = 0]) => element is E ? _source.indexOf(element, start) : -1;
  @override
  List<E> toList({bool growable = true}) => _source.toList(growable: growable);

  @protected
  @override
  set length(int newLength) => throw _ProtectedCollectionError();
  @protected
  @override
  set first(E value) => throw _ProtectedCollectionError();
  @protected
  @override
  set last(E value) => throw _ProtectedCollectionError();
  @protected
  @override
  void operator []=(int index, E value) => throw _ProtectedCollectionError();
  @protected
  @override
  void add(E element) => throw _ProtectedCollectionError();
  @protected
  @override
  void addAll(Iterable<E> iterable) => throw _ProtectedCollectionError();
  @protected
  @override
  void insert(int index, E element) => throw _ProtectedCollectionError();
  @protected
  @override
  void insertAll(int index, Iterable<E> iterable) => throw _ProtectedCollectionError();
  @protected
  @override
  bool remove(Object? element) => throw _ProtectedCollectionError();
  @protected
  @override
  E removeAt(int index) => throw _ProtectedCollectionError();
  @protected
  @override
  E removeLast() => throw _ProtectedCollectionError();
  @protected
  @override
  void removeRange(int start, int end) => throw _ProtectedCollectionError();
  @protected
  @override
  void removeWhere(bool Function(E element) test) => throw _ProtectedCollectionError();
  @protected
  @override
  void retainWhere(bool Function(E element) test) => throw _ProtectedCollectionError();
  @protected
  @override
  void clear() => throw _ProtectedCollectionError();
  @protected
  @override
  void sort([int Function(E a, E b)? compare]) => throw _ProtectedCollectionError();
  @protected
  @override
  void shuffle([Random? random]) => throw _ProtectedCollectionError();
  @protected
  @override
  void setAll(int index, Iterable<E> iterable) => throw _ProtectedCollectionError();
  @protected
  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) => throw _ProtectedCollectionError();
  @protected
  @override
  void replaceRange(int start, int end, Iterable<E> newContents) => throw _ProtectedCollectionError();
  @protected
  @override
  void fillRange(int start, int end, [E? fill]) => throw _ProtectedCollectionError();
}

class _ProtectedSet<E> extends SetBase<E> {
  final Set<E> _source;
  const _ProtectedSet(this._source);

  @override
  Iterator<E> get iterator => _source.iterator;
  @override
  int get length => _source.length;
  @override
  bool get isEmpty => _source.isEmpty;
  @override
  bool get isNotEmpty => _source.isNotEmpty;
  @override
  bool contains(Object? element) => _source.contains(element);
  @override
  E? lookup(Object? element) => _source.lookup(element);
  @override
  Set<E> toSet() => _source.toSet();

  @protected
  @override
  bool add(E value) => throw _ProtectedCollectionError();
  @protected
  @override
  void addAll(Iterable<E> elements) => throw _ProtectedCollectionError();
  @protected
  @override
  bool remove(Object? value) => throw _ProtectedCollectionError();
  @protected
  @override
  void removeAll(Iterable<Object?> elements) => throw _ProtectedCollectionError();
  @protected
  @override
  void retainAll(Iterable<Object?> elements) => throw _ProtectedCollectionError();
  @protected
  @override
  void removeWhere(bool Function(E element) test) => throw _ProtectedCollectionError();
  @protected
  @override
  void retainWhere(bool Function(E element) test) => throw _ProtectedCollectionError();
  @protected
  @override
  void clear() => throw _ProtectedCollectionError();
}

class _ProtectedMap<K, V> extends MapBase<K, V> {
  final Map<K, V> _source;
  const _ProtectedMap(this._source);

  @override
  V? operator [](Object? key) => _source[key];
  @override
  Iterable<K> get keys => _source.keys;
  @override
  Iterable<V> get values => _source.values;
  @override
  Iterable<MapEntry<K, V>> get entries => _source.entries;
  @override
  int get length => _source.length;
  @override
  bool get isEmpty => _source.isEmpty;
  @override
  bool get isNotEmpty => _source.isNotEmpty;
  @override
  bool containsKey(Object? key) => _source.containsKey(key);
  @override
  bool containsValue(Object? value) => _source.containsValue(value);

  @protected
  @override
  void operator []=(K key, V value) => throw _ProtectedCollectionError();
  @protected
  @override
  void addAll(Map<K, V> other) => throw _ProtectedCollectionError();
  @protected
  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) => throw _ProtectedCollectionError();
  @protected
  @override
  V putIfAbsent(K key, V Function() ifAbsent) => throw _ProtectedCollectionError();
  @protected
  @override
  V? remove(Object? key) => throw _ProtectedCollectionError();
  @protected
  @override
  void removeWhere(bool Function(K key, V value) test) => throw _ProtectedCollectionError();
  @protected
  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) => throw _ProtectedCollectionError();
  @protected
  @override
  void updateAll(V Function(K key, V value) update) => throw _ProtectedCollectionError();
  @protected
  @override
  void clear() => throw _ProtectedCollectionError();
}

class _DirectKeyWriteError extends UnsupportedError {
  _DirectKeyWriteError() : super('settings keys are written through save(), reset() or update(), a direct write would skip the file');
}

class _ProtectedCollectionError extends UnsupportedError {
  _ProtectedCollectionError() : super('settings collections are read-only, mutate through the key\'s update()');
}
