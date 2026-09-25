import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/func_execute_limiter.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_id.dart';

class QueueController {
  static final QueueController inst = QueueController._internal();
  QueueController._internal();

  static final latestPlayedForSourceManager = _LatestPlayedForSourceManager();

  /// holds all queues mapped & sorted by `date` chronologically & reversly.
  final Rx<SplayTreeMap<int, Queue>> queuesMap = SplayTreeMap<int, Queue>((date1, date2) => date2.compareTo(date1)).obs;

  /// counts the ones not loaded yet into [queuesMap] too.
  final totalQueuesCount = 0.obs;

  List<int> _unloadedQueuesDates = const [];
  Future<void>? _loadAllQueuesOperation;

  void _refreshTotalQueuesCount() => totalQueuesCount.value = queuesMap.value.length + _unloadedQueuesDates.length;

  Queue? get _latestQueueInMap => queuesMap.value[_latestAddedQueueDate];

  /// faster way to access latest queue
  int _latestAddedQueueDate = 0;
  int _sessionQueueDate = 0;
  Playable? _sessionQueuePendingItem;

  void _bindSessionQueueDate(int date) {
    if (date <= 0) return;
    _sessionQueueDate = date;
    final pendingItem = _sessionQueuePendingItem;
    if (pendingItem != null) {
      _sessionQueuePendingItem = null;
      _updateLatestPlayedForQueueDate(date, pendingItem);
    }
  }

  void _updateLatestPlayedForQueueDate(int date, Playable item) {
    latestPlayedForSourceManager.update(QueueSource.queuePageByName(date.toString()), item);
  }

  void updateLatestPlayedForCurrentQueue(Playable item, {QueueSourceBase? alreadyUpdatedSource}) {
    final date = _sessionQueueDate;
    if (date <= 0) {
      _sessionQueuePendingItem = item;
      return;
    }
    if (alreadyUpdatedSource != null && alreadyUpdatedSource.s == QueueSourceEnum.queuePage && int.tryParse(alreadyUpdatedSource.title ?? '') == date) return;
    _updateLatestPlayedForQueueDate(date, item);
  }

  static const kMaxQueueTracksCountToSave = 2000;

  Future<bool> _allowSavingQueue(int count) async {
    // -- if there are more than 2000 tracks.
    if (count > kMaxQueueTracksCountToSave) {
      printy("UWAH QUEUE DEKKA", isError: true);
      return false;
    }

    await _queuesLoad.future;

    return true;
  }

  /// doesnt save queues with more than 2000 tracks.
  Future<void> addNewQueue({
    required QueueSourceBase source,
    required HomePageItems? homePageItem,
    int? date,
    int? dateComparison,
    List<Track> tracks = const <Track>[],
  }) async {
    date ??= currentTimeMS;

    if (!await _allowSavingQueue(tracks.length)) return;

    // -- Prevents saving [allTracksAll] source over and over.
    final latestQueue = _latestQueueInMap;
    if (latestQueue != null) {
      final isSameAllTracksAll = source.s == QueueSourceEnum.allTracksAll && latestQueue.source.s == QueueSourceEnum.allTracksAll;
      final isSameQueuePage = dateComparison == latestQueue.date && (source == latestQueue.source || source.s == QueueSourceEnum.queuePage);
      if (isSameAllTracksAll || isSameQueuePage) {
        if (isSameQueuePage) date = latestQueue.date;
        await removeQueue(latestQueue);
      }
    }

    final q = Queue(source: source, homePageItem: homePageItem, date: date, isFav: false, tracks: tracks);
    _updateMap(q);
    _latestAddedQueueDate = q.date;
    _bindSessionQueueDate(q.date);
    printy("Added New Queue");
    await _saveQueueToStorage(q);
  }

  Future<void> removeQueue(Queue queue) async {
    queuesMap.value.remove(queue.date);
    queuesMap.refresh();
    _refreshTotalQueuesCount();
    if (queue.date == _latestAddedQueueDate) _latestAddedQueueDate = 0;
    await _deleteQueueFromStorage(queue);
  }

  Future<void> removeQueues(List<int> queuesDates) async {
    bool hasLatestAdded = false;
    for (var date in queuesDates) {
      queuesMap.value.remove(date);
      if (date == _latestAddedQueueDate) hasLatestAdded = true;
    }
    if (_unloadedQueuesDates.isNotEmpty) {
      final removedDates = queuesDates.toSet();
      _unloadedQueuesDates = _unloadedQueuesDates.where((date) => !removedDates.contains(date)).toList();
    }
    queuesMap.refresh();
    _refreshTotalQueuesCount();
    if (hasLatestAdded) _latestAddedQueueDate = 0;
    await _deleteQueuesFromStorage(queuesDates);
  }

  Future<void> reAddQueue(Queue queue) async {
    _updateMap(queue);
    await _saveQueueToStorage(queue);
  }

  void _updateMap(Queue queue, [int? date]) {
    date ??= queue.date;
    queuesMap.value[date] = queue;
    queuesMap.refresh();
    _refreshTotalQueuesCount();
  }

  Future<bool> toggleFavButton(Queue oldQueue) async {
    final isNowFav = !(queuesMap.value[oldQueue.date]?.isFav ?? false);
    final newQueue = oldQueue.copyWith(isFav: isNowFav);
    _updateMap(newQueue);
    await _saveQueueToStorage(newQueue);
    return isNowFav;
  }

  Future<void> updateQueue(Queue oldQueue, Queue newQueue) async {
    _updateMap(newQueue, oldQueue.date);
    await _saveQueueToStorage(newQueue);
  }

  /// [originalIndices] is provided when the queue is shuffled, queues map saves the original order.
  Future<void> updateLatestQueue(List<Playable> items, {required List<int>? originalIndices, required QueueSourceBase<Enum> source, HomePageItems? homePageItem}) async {
    _sessionQueueDate = 0;
    _playerQueueModifiedTime = _pendingSyncQueueTimestamp ?? currentTimeMS;
    // -- some actions in ui would wait for this (ex: scrolling to current item in queue right after modifying queue)
    // -- hopefully this doesn't cause other issues (pls)
    unawaited(
      Future.wait([
        _saveLatestQueueToStorage(items, originalIndices),
        if (await _allowSavingQueue(items.length))
          _updateLatestQueueInsideMap(
            originalIndices == null ? items : _toOriginalOrder(items, originalIndices),
            source: source,
            homePageItem: homePageItem,
          ),
      ]),
    );
  }

  Future<void> _updateLatestQueueInsideMap(List<Playable> items, {required QueueSourceBase<Enum> source, HomePageItems? homePageItem}) async {
    try {
      final firstItem = items.firstOrNull;
      if (firstItem is Selectable) {
        int? queueDate;
        if (source.s == QueueSourceEnum.queuePage) {
          // -- allow skip adding as a new queue (if same as latest queue)
          final dateText = source.title;
          if (dateText != null) {
            queueDate = int.tryParse(dateText);
          }
        }

        final tracks = items.map((e) => (e as Selectable).track).toList();
        final latestQueueInsideMap = _latestQueueInMap;
        final shouldUpdateLatestQueueInsteadOfAdding = latestQueueInsideMap != null && latestQueueInsideMap.source == source;
        if (shouldUpdateLatestQueueInsteadOfAdding) {
          await this.updateQueue(
            latestQueueInsideMap,
            latestQueueInsideMap.copyWith(
              tracks: tracks,
              source: source is QueueSource ? source : null,
              homePageItem: homePageItem,
            ),
          );
          _bindSessionQueueDate(latestQueueInsideMap.date);
        } else {
          await this.addNewQueue(
            source: source,
            dateComparison: queueDate,
            homePageItem: homePageItem,
            tracks: tracks,
          );
        }
      }
    } catch (_) {
      // -- is mixed queue
    }
  }

  Future<void> insertTracksQueue(Queue queue, List<Track> tracks, int index) async {
    queue.tracks.insertAllSafe(index, tracks);
    _updateMap(queue);
    await _saveQueueToStorage(queue);
  }

  Future<void> removeTrackFromQueue(Queue queue, int index) async {
    queue.tracks.removeAt(index);
    _updateMap(queue);
    await _saveQueueToStorage(queue);
  }

  /// Only use when updating missing track.
  Future<void> replaceTracksDirectoryInQueues(
    String normalizedOldDir,
    String normalizedNewDir, {
    Iterable<String>? forThesePathsOnly,
    bool ensureNewFileExists = false,
  }) async {
    final queuesToSave = <Queue>{};
    final pathsOnlySet = forThesePathsOnly?.toSet();
    final existenceCache = <String, bool>{};
    final normalizedPathCache = <String, String>{};

    for (final q in queuesMap.value.values) {
      q.tracks.replaceWhere(
        (e) {
          final tr = e.track;
          normalizedPathCache[tr.path] ??= replaceFunctionNormalizePath(tr.path);
          return replaceFunctionForUpdatedPaths(
            tr.path,
            normalizedOldDir,
            normalizedNewDir,
            pathsOnlySet,
            ensureNewFileExists,
            existenceCache,
          );
        },
        (old) {
          final normalized = normalizedPathCache[old.path] ?? replaceFunctionNormalizePath(old.path);
          return Track.fromTypeParameter(
            old.runtimeType,
            replaceFunctionGetNewPath(normalized, normalizedOldDir, normalizedNewDir),
          );
        },
        onMatch: () => queuesToSave.add(q),
      );
    }
    for (final q in queuesToSave) {
      _updateMap(q);
      await _saveQueueToStorage(q);
    }
  }

  Future<void> replaceTrackInAllQueues(Map<Track, Track> oldNewTrack) async {
    final queuesToSave = <Queue>{};
    for (final q in queuesMap.value.values) {
      for (final e in oldNewTrack.entries) {
        q.tracks.replaceItems(
          e.key,
          e.value,
          onMatch: () => queuesToSave.add(q),
        );
      }
    }
    for (final q in queuesToSave) {
      _updateMap(q);
      await _saveQueueToStorage(q);
    }
  }

  /// the rest are read on demand by [loadAllQueues].
  static const _kInitialQueuesLoadCount = 20;

  Future<void> prepareAllQueuesFile() async {
    _loadAllQueuesOperation = null;
    final res = await _readQueueFilesCompute.thready((AppDirs.QUEUES, _kInitialQueuesLoadCount));
    queuesMap.value = res.map;
    _unloadedQueuesDates = res.unloadedDates;
    _latestAddedQueueDate = res.newestDate;
    _refreshTotalQueuesCount();
    _bindSessionQueueDate(res.newestDate);
    _queuesLoad.completeIfWasnt(true);
  }

  Future<void> loadAllQueues() => _loadAllQueuesOperation ??= _loadAllQueues();

  Future<void> _loadAllQueues() async {
    await _queuesLoad.future;
    final dates = _unloadedQueuesDates;
    if (dates.isEmpty) return;
    final map = await _readQueuesForDatesCompute.thready((AppDirs.QUEUES, dates));
    _unloadedQueuesDates = const [];
    queuesMap.value.addAll(map);
    queuesMap.refresh();
    _refreshTotalQueuesCount();
  }

  static ({SplayTreeMap<int, Queue> map, int newestDate, List<int> unloadedDates}) _readQueueFilesCompute((String, int) pathAndLoadCount) {
    final (path, loadCount) = pathAndLoadCount;
    final dates = <int>[];
    final files = Directory(path).listSyncSafe();
    for (final f in files) {
      if (f is File) {
        final date = int.tryParse(f.path.getFilenameWOExt);
        if (date != null) dates.add(date);
      }
    }
    dates.sort((date1, date2) => date2.compareTo(date1));

    int newestQueueDate = 0;
    final map = SplayTreeMap<int, Queue>((date1, date2) => date1.compareTo(date2));
    final loadedCount = dates.length < loadCount ? dates.length : loadCount;
    for (int i = 0; i < loadedCount; i++) {
      final q = _readQueueFile(path, dates[i]);
      if (q == null) continue;
      map[q.date] = q;
      if (q.date > newestQueueDate) newestQueueDate = q.date;
    }
    return (
      map: map,
      newestDate: newestQueueDate,
      unloadedDates: dates.length > loadedCount ? dates.sublist(loadedCount) : const <int>[],
    );
  }

  static Map<int, Queue> _readQueuesForDatesCompute((String, List<int>) pathAndDates) {
    final (path, dates) = pathAndDates;
    final map = <int, Queue>{};
    for (final date in dates) {
      final q = _readQueueFile(path, date);
      if (q != null) map[q.date] = q;
    }
    return map;
  }

  static Queue? _readQueueFile(String dirPath, int date) {
    try {
      final bytes = File('$dirPath$date.json').readAsBytesSync();
      if (bytes[0] != _QueueSerializer._kMagic) return Queue.fromJson(jsonDecodeUtf8(bytes));
      final decoded = _QueueSerializer.decode<Track>(bytes);
      final meta = decoded.meta;
      return meta == null ? null : Queue.fromMeta(meta, decoded.items);
    } catch (_) {}
    return null;
  }

  Future<void> emptyLatestQueue() async {
    _playerQueueModifiedTime = _pendingSyncQueueTimestamp ?? currentTimeMS;
    await File(AppPaths.LATEST_QUEUE).tryDeleting();
  }

  /// media browser clients (android auto, wear, etc) can start the app on their own,
  /// they have to wait for this before requesting anything
  Future<void> get latestQueueRestored => _latestQueueRestoredCompleter.future;
  final _latestQueueRestoredCompleter = Completer<void>();
  void markLatestQueueRestored() {
    if (!_latestQueueRestoredCompleter.isCompleted) _latestQueueRestoredCompleter.complete();
  }

  Future<void> prepareLatestQueueAndLatestPlayedForSourceAsync() async {
    try {
      await _prepareLatestQueueAsync();
    } catch (_) {}

    markLatestQueueRestored();

    unawaited(latestPlayedForSourceManager.prepareAll());
  }

  /// Assigns the last queue to the [Player]
  Future<void> _prepareLatestQueueAsync() async {
    var (latestQueue, originalIndices) = await _prepareLatestQueueSync.thready(AppPaths.LATEST_QUEUE);
    if (latestQueue.isEmpty) return;

    int index = settings.extra.lastPlayedIndex;
    if (index > latestQueue.length - 1) index = 0;

    // -- shuffle was toggled off but the app was killed before the queue file was rewritten.
    // -- 0.67% chance..
    if (originalIndices != null && !settings.player.shuffleQueue.value) {
      if (_isValidOriginalIndices(originalIndices, latestQueue.length)) {
        latestQueue = _toOriginalOrder(latestQueue, originalIndices);
        index = originalIndices[index];
      }
      originalIndices = null;
    }

    final startPlaying = Player.inst.playWhenReady.value && await NamidaChannel.inst.consumeSelfSentMediaCommand();

    Player.inst.playOrPause(
      index,
      latestQueue,
      QueueSource.playerQueue,
      originalIndices: originalIndices,
      startPlaying: startPlaying,
      updateQueue: false,
      maximumItems: null,
    );
  }

  /// a partially decodable queue file could hand us indices of a longer original list
  static bool _isValidOriginalIndices(List<int> originalIndices, int length) {
    if (originalIndices.length != length) return false;
    final seen = List<bool>.filled(length, false);
    for (int i = 0; i < length; i++) {
      final index = originalIndices[i];
      if (index < 0 || index >= length || seen[index]) return false;
      seen[index] = true;
    }
    return true;
  }

  /// [originalIndices] can be stale (live player list), items without a valid unique index go to the end.
  static List<Playable> _toOriginalOrder(List<Playable> items, List<int> originalIndices) {
    final length = items.length;
    final indicesLength = originalIndices.length;
    final ordered = List<Playable>.of(items);
    final placed = Uint8List(length);
    List<Playable>? misplaced;
    for (int i = 0; i < length; i++) {
      final index = i < indicesLength ? originalIndices[i] : -1;
      if (index >= 0 && index < length && placed[index] == 0) {
        placed[index] = 1;
        ordered[index] = items[i];
      } else {
        (misplaced ??= <Playable>[]).add(items[i]);
      }
    }
    if (misplaced == null) return ordered;

    int writeIndex = 0;
    for (int i = 0; i < length; i++) {
      if (placed[i] == 1) ordered[writeIndex++] = ordered[i];
    }
    ordered.setAll(writeIndex, misplaced);
    return ordered;
  }

  static (List<Playable>, List<int>?) _prepareLatestQueueSync(String filePath) {
    try {
      final bytes = File(filePath).readAsBytesSync();
      if (bytes.isNotEmpty) {
        if (bytes[0] != _QueueSerializer._kMagic) return _QueueSerializer.decodeLegacyJson(bytes);
        final decoded = _QueueSerializer.decode<Playable>(bytes);
        return (decoded.items, decoded.originalIndices);
      }
    } catch (_) {}
    return (const [], null);
  }

  Future<void> _saveQueueToStorage(Queue queue) async {
    final bytes = _QueueSerializer.encode(queue.tracks, meta: queue.metaToJson());
    await _writeAtomic(FileParts.joinPath(AppDirs.QUEUES, '${queue.date}.json'), bytes);
  }

  static const _kTempFileSuffix = '.tmp';

  static Future<void> _writeAtomic(String path, Uint8List bytes) async {
    final tempFile = await File('$path$_kTempFileSuffix').writeAsBytes(bytes, flush: true);
    await tempFile.rename(path);
  }

  final _queueFnLimiter = FunctionExecuteLimiter(
    considerRapid: const Duration(seconds: 2),
    executeAfter: const Duration(seconds: 2),
    considerRapidAfterNExecutions: 1,
  );
  Future<void> _saveLatestQueueToStorage(List<Playable> items, List<int>? originalIndices) async {
    return _queueFnLimiter.executeFuture(() async {
      try {
        final bytes = _QueueSerializer.encode(items, originalIndices: originalIndices);
        await _writeAtomic(AppPaths.LATEST_QUEUE, bytes);
      } catch (e) {
        printy(e, isError: true);
      }
    });
  }

  Future<void> _deleteQueueFromStorage(Queue queue) async {
    await FileParts.join(AppDirs.QUEUES, '${queue.date}.json').tryDeleting();
  }

  Future<void> _deleteQueuesFromStorage(List<int> queuesDates) async {
    await _deleteQueuesFromStorageIsolate.thready((AppDirs.QUEUES, queuesDates));
  }

  static void _deleteQueuesFromStorageIsolate((String, List<int>) pathAndDates) async {
    for (var date in pathAndDates.$2) {
      try {
        File('${pathAndDates.$1}$date.json').deleteSync();
      } catch (_) {}
    }
  }

  final _queuesLoad = Completer<bool>();
  bool get isQueuesLoaded => _queuesLoad.isCompleted;

  int get playerQueueModifiedTime => _playerQueueModifiedTime;
  int _playerQueueModifiedTime = 0;

  /// used when importing queue from another device,
  /// cuz [_playerQueueModifiedTime] is used as a token
  int? _pendingSyncQueueTimestamp;

  (Iterable<Map<String, dynamic>>, int, int)? buildPlayerQueueSyncPayload() {
    final queue = Player.inst.currentQueue.value;
    if (queue.isEmpty) return null;
    final originalIndices = Player.inst.currentQueueOriginalIndices;
    final withOriginal = originalIndices != null && originalIndices.length == queue.length;
    final items = List.generate(
      queue.length,
      (i) {
        final item = queue[i];
        return <String, dynamic>{
          'p': item.toJson(),
          't': item.playableType.jsonKey,
          if (withOriginal) _QueueSerializer._kOriginalIndex: originalIndices[i],
        };
      },
      growable: false,
    );
    return (items, _playerQueueModifiedTime, Player.inst.currentIndex.value);
  }

  Future<void> importPlayerQueue(Iterable<dynamic> items, int queueModifiedTime, int currentIndex, String senderDeviceId) async {
    final resolvedItems = <Playable>[];
    List<int>? originalIndices = <int>[];
    for (final e in items) {
      final map = (e as Map).cast<String, dynamic>();
      final type = _QueueSerializer.typeFromJsonKey(map['t']);
      if (type == null) continue;
      final (resolvedType, payload) = _QueueSerializer.resolveSyncPayload(type, map['p'], senderDeviceId);
      resolvedItems.add(_QueueSerializer.build(resolvedType, payload));
      if (originalIndices != null) {
        final originalIndex = map[_QueueSerializer._kOriginalIndex];
        if (originalIndex is int) {
          originalIndices.add(originalIndex);
        } else {
          originalIndices = null;
        }
      }
    }
    if (resolvedItems.isEmpty) return;
    if (currentIndex < 0 || currentIndex >= resolvedItems.length) currentIndex = 0;

    _pendingSyncQueueTimestamp = queueModifiedTime;
    try {
      await Player.inst.playOrPause(
        currentIndex,
        resolvedItems,
        QueueSource.playerQueue,
        originalIndices: originalIndices,
      );
    } finally {
      _playerQueueModifiedTime = queueModifiedTime;
      _pendingSyncQueueTimestamp = null;
    }
  }
}

class _LatestPlayedForSourceManager {
  RxBaseCore<Map<QueueSourceBase<dynamic>, Playable>> get map => _mapRx;
  static final _mapRx = <QueueSourceBase<dynamic>, Playable>{}.obs;

  static final _modifiedTimesMap = <QueueSourceBase<dynamic>, int>{};

  late final _dBManager = DBWrapper.openFromInfo(
    fileInfo: AppPaths.LATEST_PLAYED_FOR_SOURCE,
    config: const DBConfig(createIfNotExist: true),
  );

  Future<void> prepareAll() async {
    final res = await _dBManager.loadEverythingKeyedResult();
    for (final entry in res.entries) {
      final sourceRaw = jsonDecode(entry.key);
      final QueueSourceBase source = QueueSource.fromJson(sourceRaw) ?? QueueSourceYoutubeID.fromJson(sourceRaw) ?? QueueSource.others(null);

      final map = entry.value;
      final type = map['t'] as String;
      final valueMap = map['p'];
      final item = _QueueSerializer.buildFromJson(type, valueMap);
      if (item != null) {
        _mapRx.value[source] ??= item;
        final mt = map['_mt'] as int? ?? 0;
        if (mt > 0) _modifiedTimesMap[source] ??= mt;
      }
    }
    _mapRx.refresh();
  }

  void update(QueueSourceBase source, Playable item) async {
    _mapRx[source] = item;
    final mt = currentTimeMS;
    _modifiedTimesMap[source] = mt;
    await _dBManager.put(source.toDbKey(), {
      'p': item.toJson(),
      't': item.playableType.jsonKey,
      '_mt': mt,
    });
  }

  Future<void> move(QueueSourceBase oldSource, QueueSourceBase newSource) async {
    final oldValue = _mapRx.value.remove(oldSource);
    if (oldValue != null) {
      _mapRx.value[newSource] = oldValue;
      _mapRx.refresh();
    }
    final mt = _modifiedTimesMap.remove(oldSource);
    if (mt != null) _modifiedTimesMap[newSource] = mt;
    final oldValueDB = await _dBManager.get(oldSource.toDbKey());
    await _dBManager.put(newSource.toDbKey(), oldValueDB);
    await delete(oldSource);
  }

  Future<void> delete(QueueSourceBase source) async {
    _mapRx.remove(source);
    _modifiedTimesMap.remove(source);
    await _dBManager.delete(source.toDbKey());
  }

  Future<void> deleteMultiple(Iterable<QueueSourceBase> sources) async {
    final keysToRemove = <String>[];
    for (final source in sources) {
      _mapRx.value.remove(source);
      _modifiedTimesMap.remove(source);
      keysToRemove.add(source.toDbKey());
    }
    _mapRx.refresh();
    await _dBManager.deleteBulk(keysToRemove);
  }

  Iterable<MapEntry<String, Map<String, dynamic>>> buildSyncEntries() {
    return _mapRx.value.entries.map(
      (e) => MapEntry(e.key.toDbKey(), <String, dynamic>{
        'p': e.value.toJson(),
        't': e.value.playableType.jsonKey,
        '_mt': _modifiedTimesMap[e.key] ?? 0,
      }),
    );
  }

  Future<void> import(Iterable<MapEntry<String, Map<String, dynamic>>> incomingEntries, String senderDeviceId) async {
    bool anyChanged = false;
    for (final entry in incomingEntries) {
      final incoming = entry.value;
      final incomingMt = incoming['_mt'] as int? ?? 0;

      final sourceRaw = jsonDecode(entry.key);
      final QueueSourceBase? source = QueueSource.fromJson(sourceRaw) ?? QueueSourceYoutubeID.fromJson(sourceRaw);
      if (source == null) continue; // -- unknown source, dont force into `others`

      if (_mapRx.value[source] != null && (_modifiedTimesMap[source] ?? 0) >= incomingMt) continue;

      final type = _QueueSerializer.typeFromJsonKey(incoming['t']);
      if (type == null) continue;
      final (resolvedType, payload) = _QueueSerializer.resolveSyncPayload(type, incoming['p'], senderDeviceId);
      final item = _QueueSerializer.build(resolvedType, payload);

      _mapRx.value[source] = item;
      _modifiedTimesMap[source] = incomingMt;
      anyChanged = true;
      await _dBManager.put(source.toDbKey(), {
        'p': payload,
        't': resolvedType.jsonKey,
        '_mt': incomingMt,
      });
    }
    if (anyChanged) _mapRx.refresh();
  }
}

/// Binary layout: `magic u8, flags u8, metaLength u32, meta utf8 json, count u32, items...`
/// item: `type u8, [originalIndex u32], length u32, payload bytes`
/// payload is the raw path for tracks/videos, utf8 json otherwise.
// optimizations by claude
class _QueueSerializer {
  const _QueueSerializer();

  static const _kMagic = 0x01;
  static const _kFlagOriginalIndices = 0x01;

  static final _kEmptyBytes = Uint8List(0);

  static const _kOriginalIndex = 'o';

  static final _typesByJsonKey = <String, PlayableType>{for (final t in PlayableType.values) t.jsonKey: t};

  static final _playableTypeFromId = () {
    final list = [...PlayableType.values]..sort((a, b) => a.binaryId.compareTo(b.binaryId));
    assert(() {
      for (int i = 0; i < list.length; i++) {
        if (list[i].binaryId != i) return false;
      }
      return true;
    }(), 'PlayableType.binaryId must be unique & contiguous');
    return list;
  }();

  static PlayableType? typeFromJsonKey(dynamic key) => _typesByJsonKey[key];

  static Playable build(PlayableType type, dynamic payload) => switch (type) {
    PlayableType.track => Track.explicit(payload),
    PlayableType.video => Video.explicit(payload),
    PlayableType.trackWithDate => TrackWithDate.fromJson(payload),
    PlayableType.ytVideo => YoutubeID.fromJson(payload),
  };

  static Playable? buildFromJson(dynamic typeKey, dynamic payload) {
    final type = _typesByJsonKey[typeKey];
    return type == null ? null : build(type, payload);
  }

  /// resolves sender paths into local ones
  static (PlayableType, dynamic) resolveSyncPayload(PlayableType type, dynamic payload, String senderDeviceId) {
    switch (type) {
      case PlayableType.track || PlayableType.video:
        final resolved = SyncPathResolver.resolveTrackByPath(senderDeviceId, payload as String);
        if (resolved != null) return (resolved.playableType, resolved.path);
      case PlayableType.trackWithDate:
        payload = SyncPathResolver.resolveTrackWithDate(senderDeviceId, TrackWithDate.fromJson(payload)).toJson();
      case PlayableType.ytVideo:
        break;
    }
    return (type, payload);
  }

  static Uint8List encode(List<Playable> items, {List<int>? originalIndices, Map<String, dynamic>? meta}) {
    final count = items.length;
    final metaBytes = meta == null ? _kEmptyBytes : jsonEncodeUtf8(meta);
    final payloads = List<Uint8List>.generate(count, (i) => _encodePayload(items[i]), growable: false);
    final indices = originalIndices != null && originalIndices.length == count ? originalIndices : null;

    int total = 10 + metaBytes.length + count * (indices != null ? 9 : 5);
    for (int i = 0; i < count; i++) {
      total += payloads[i].length;
    }

    final bytes = Uint8List(total);
    final data = ByteData.sublistView(bytes);
    bytes[0] = _kMagic;
    bytes[1] = indices != null ? _kFlagOriginalIndices : 0;
    int offset = _writeChunk(bytes, data, 2, metaBytes);
    data.setUint32(offset, count, Endian.little);
    offset += 4;

    for (int i = 0; i < count; i++) {
      bytes[offset++] = items[i].playableType.binaryId;
      if (indices != null) {
        data.setUint32(offset, indices[i], Endian.little);
        offset += 4;
      }
      offset = _writeChunk(bytes, data, offset, payloads[i]);
    }
    return bytes;
  }

  static int _writeChunk(Uint8List bytes, ByteData data, int offset, Uint8List chunk) {
    data.setUint32(offset, chunk.length, Endian.little);
    offset += 4;
    bytes.setRange(offset, offset + chunk.length, chunk);
    return offset + chunk.length;
  }

  static Uint8List _encodePayload(Playable item) {
    final json = item.toJson();
    return utf8.encode(json is String ? json : jsonEncode(json));
  }

  static ({List<T> items, List<int>? originalIndices, Map<String, dynamic>? meta}) decode<T extends Playable>(Uint8List bytes) {
    final items = <T>[];
    List<int>? originalIndices;
    Map<String, dynamic>? meta;
    try {
      final data = ByteData.sublistView(bytes);
      final hasIndices = bytes[1] & _kFlagOriginalIndices != 0;
      if (hasIndices) originalIndices = <int>[];
      int offset = 2;
      final metaLength = data.getUint32(offset, Endian.little);
      offset += 4;
      if (metaLength > 0) {
        meta = jsonDecodeUtf8(Uint8List.sublistView(bytes, offset, offset + metaLength)) as Map<String, dynamic>;
        offset += metaLength;
      }
      final count = data.getUint32(offset, Endian.little);
      offset += 4;
      for (int i = 0; i < count; i++) {
        final type = _playableTypeFromId[bytes[offset++]];
        int originalIndex = 0;
        if (hasIndices) {
          originalIndex = data.getUint32(offset, Endian.little);
          offset += 4;
        }
        final length = data.getUint32(offset, Endian.little);
        offset += 4;
        final text = utf8.decoder.convert(bytes, offset, offset + length);
        offset += length;
        final payload = switch (type) {
          PlayableType.track || PlayableType.video => text,
          PlayableType.trackWithDate || PlayableType.ytVideo => jsonDecode(text),
        };
        items.add(build(type, payload) as T);
        originalIndices?.add(originalIndex);
      }
    } catch (_) {}
    return (items: items, originalIndices: originalIndices, meta: meta);
  }

  static (List<Playable>, List<int>?) decodeLegacyJson(Uint8List bytes) {
    final items = <Playable>[];
    List<int>? originalIndices = <int>[];
    try {
      final list = jsonDecodeUtf8(bytes) as List?;
      if (list != null) {
        for (final e in list) {
          final item = buildFromJson(e['t'], e['p']);
          if (item != null) {
            items.add(item);
            if (originalIndices != null) {
              final originalIndex = e[_kOriginalIndex];
              if (originalIndex is int) {
                originalIndices.add(originalIndex);
              } else {
                originalIndices = null;
              }
            }
          }
        }
      }
    } catch (_) {}
    return (items, originalIndices);
  }
}
