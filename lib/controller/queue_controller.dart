import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:namida/class/func_execute_limiter.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
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

  Queue? get _latestQueueInMap => queuesMap.value[_latestAddedQueueDate];

  /// faster way to access latest queue
  int _latestAddedQueueDate = 0;

  Future<bool> _allowSavingQueue(int count) async {
    // -- if there are more than 2000 tracks.
    if (count > 2000) {
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

    // -- Prevents saving [allTracks] source over and over.
    final latestQueue = _latestQueueInMap;
    if (latestQueue != null) {
      if ((source == QueueSource.allTracks && latestQueue.source == QueueSource.allTracks) || dateComparison == latestQueue.date) {
        await removeQueue(latestQueue);
      }
    }

    final q = Queue(source: source, homePageItem: homePageItem, date: date, isFav: false, tracks: tracks);
    _updateMap(q);
    _latestAddedQueueDate = q.date;
    printy("Added New Queue");
    await _saveQueueToStorage(q);
  }

  Future<void> removeQueue(Queue queue) async {
    queuesMap.value.remove(queue.date);
    queuesMap.refresh();
    if (queue.date == _latestAddedQueueDate) _latestAddedQueueDate = 0;
    await _deleteQueueFromStorage(queue);
  }

  Future<void> removeQueues(List<int> queuesDates) async {
    bool hasLatestAdded = false;
    queuesDates.loop((date) {
      queuesMap.value.remove(date);
      if (date == _latestAddedQueueDate) hasLatestAdded = true;
    });
    queuesMap.refresh();
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
  }

  // void removeQueues(List<Queue> queues) async {
  //   queues.loop((q) => removeQueue(q));
  // }

  Future<bool> toggleFavButton(Queue oldQueue) async {
    final isNowFav = !(queuesMap.value[oldQueue.date]?.isFav ?? false);
    final newQueue = oldQueue.copyWith(isFav: isNowFav);
    queuesMap.value[oldQueue.date] = newQueue;
    _updateMap(newQueue);
    await _saveQueueToStorage(newQueue);
    return isNowFav;
  }

  Future<void> updateQueue(Queue oldQueue, Queue newQueue) async {
    _updateMap(newQueue, oldQueue.date);
    await _saveQueueToStorage(newQueue);
  }

  Future<void> updateLatestQueue(List<Playable> items, {required QueueSourceBase? source, HomePageItems? homePageItem}) async {
    await Future.wait([
      _saveLatestQueueToStorage(items),
      () async {
        // updating last queue inside queuesMap.
        try {
          final firstItem = items.firstOrNull;
          if (firstItem is Selectable) {
            int? queueDate;
            if (source != null && source.s == QueueSourceEnum.queuePage) {
              // -- allow skip adding as a new queue (if same as latest queue)
              final dateText = source.title;
              if (dateText != null) {
                queueDate = int.tryParse(dateText);
              }
            }

            final tracks = items.cast<Selectable>().tracks.toList();
            final latestQueueInsideMap = _latestQueueInMap;
            final shouldUpdateLatestQueueInsteadOfAdding = latestQueueInsideMap != null && (source == null || latestQueueInsideMap.source == source);
            if (shouldUpdateLatestQueueInsteadOfAdding) {
              await updateQueue(
                latestQueueInsideMap,
                latestQueueInsideMap.copyWith(
                  tracks: tracks,
                  source: source is QueueSource ? source : null,
                  homePageItem: homePageItem,
                ),
              );
            } else {
              if (source != null) {
                await this.addNewQueue(
                  source: source,
                  dateComparison: queueDate,
                  homePageItem: homePageItem,
                  tracks: tracks,
                );
              }
            }
          }
        } catch (_) {
          // -- is mixed queue
        }
      }(),
    ]);
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
            tr,
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

  Future<void> prepareAllQueuesFile() async {
    final mapAndLatest = await _readQueueFilesCompute.thready(AppDirs.QUEUES);
    queuesMap.value = mapAndLatest.$1;
    _latestAddedQueueDate = mapAndLatest.$2;
    _queuesLoad.completeIfWasnt(true);
  }

  static (SplayTreeMap<int, Queue>, int) _readQueueFilesCompute(String path) {
    int newestQueueDate = 0;
    final map = SplayTreeMap<int, Queue>((date1, date2) => date1.compareTo(date2));
    final files = Directory(path).listSyncSafe();
    final filesL = files.length;
    for (int i = 0; i < filesL; i++) {
      var f = files[i];
      if (f is File) {
        try {
          final response = f.readAsJsonSync(ensureExists: false);
          final q = Queue.fromJson(response);
          map[q.date] = q;
          if (q.date > newestQueueDate) newestQueueDate = q.date;
        } catch (_) {}
      }
    }
    return (map, newestQueueDate);
  }

  Future<void> emptyLatestQueue() async {
    await File(AppPaths.LATEST_QUEUE).tryDeleting();
  }

  Future<void> prepareLatestQueueAndLatestPlayedForSourceAsync() async {
    try {
      await _prepareLatestQueueAsync();
    } catch (_) {}

    unawaited(latestPlayedForSourceManager.prepareAll());
  }

  /// Assigns the last queue to the [Player]
  Future<void> _prepareLatestQueueAsync() async {
    final latestQueue = await _prepareLatestQueueSync.thready(AppPaths.LATEST_QUEUE);
    if (latestQueue == null || latestQueue.isEmpty) return;

    int index = settings.extra.lastPlayedIndex;
    if (index > latestQueue.length - 1) index = 0;

    Player.inst.playOrPause(
      index,
      latestQueue,
      QueueSource.playerQueue,
      startPlaying: Player.inst.playWhenReady.value, // false by default, unless started from home widget/quick settings
      updateQueue: false,
      maximumItems: null,
    );
  }

  static List<Playable>? _prepareLatestQueueSync(String filePath) {
    final latestQueue = <Playable>[];
    try {
      final items = File(filePath).readAsJsonSync() as List?;
      if (items != null) {
        items.loop((e) {
          final type = e['t'] as String;
          final valueMap = e['p'];
          final item = _LatestQueueSaver._typesBuilderMapLookup[type]?.call(valueMap);
          if (item != null) {
            latestQueue.add(item);
          }
        });
      }
    } catch (_) {}
    return latestQueue;
  }

  Future<void> _saveQueueToStorage(Queue queue) async {
    await File('${AppDirs.QUEUES}${queue.date}.json').writeAsJson(queue.toJson());
  }

  final _queueFnLimiter = FunctionExecuteLimiter(
    considerRapid: const Duration(seconds: 2),
    executeAfter: const Duration(seconds: 2),
    considerRapidAfterNExecutions: 1,
  );
  Future<void> _saveLatestQueueToStorage(List<Playable> items) async {
    return _queueFnLimiter.executeFuture(() async {
      try {
        final file = await File(AppPaths.LATEST_QUEUE).create(recursive: true);
        var encoder = JsonEncoder(
          (e) => {
            'p': (e as Playable).toJson(),
            't': _LatestQueueSaver._typesMapLookup[e.runtimeType],
          },
        );
        await file.writeAsString(encoder.convert(items));
      } catch (e) {
        printy(e, isError: true);
      }
    });
  }

  Future<void> _deleteQueueFromStorage(Queue queue) async {
    await File('${AppDirs.QUEUES}${queue.date}.json').tryDeleting();
  }

  Future<void> _deleteQueuesFromStorage(List<int> queuesDates) async {
    await _deleteQueuesFromStorageIsolate.thready((AppDirs.QUEUES, queuesDates));
  }

  static void _deleteQueuesFromStorageIsolate((String, List<int>) pathAndDates) async {
    pathAndDates.$2.loop((date) {
      try {
        File('${pathAndDates.$1}$date.json').deleteSync();
      } catch (_) {}
    });
  }

  final _queuesLoad = Completer<bool>();
  Future<bool> get waitForQueuesLoad => _queuesLoad.future;
  bool get isQueuesLoaded => _queuesLoad.isCompleted;
}

class _LatestPlayedForSourceManager {
  RxBaseCore<Map<QueueSourceBase<dynamic>, Playable>> get map => _mapRx;
  static final _mapRx = <QueueSourceBase<dynamic>, Playable>{}.obs;

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
      final item = _LatestQueueSaver._typesBuilderMapLookup[type]?.call(valueMap);
      if (item != null) {
        _mapRx.value[source] ??= item;
      }
    }
    _mapRx.refresh();
  }

  void update(QueueSourceBase source, Playable item) async {
    _mapRx[source] = item;
    await _dBManager.put(source.toDbKey(), {
      'p': item.toJson(),
      't': _LatestQueueSaver._typesMapLookup[item.runtimeType],
    });
  }

  Future<void> move(QueueSourceBase oldSource, QueueSourceBase newSource) async {
    final oldValue = _mapRx.value.remove(oldSource);
    if (oldValue != null) {
      _mapRx.value[newSource] = oldValue;
      _mapRx.refresh();
    }
    final oldValueDB = await _dBManager.get(oldSource.toDbKey());
    await _dBManager.put(newSource.toDbKey(), oldValueDB);
    await delete(oldSource);
  }

  Future<void> delete(QueueSourceBase source) async {
    _mapRx.remove(source);
    await _dBManager.delete(source.toDbKey());
  }

  Future<void> deleteMultiple(Iterable<QueueSourceBase> sources) async {
    final keysToRemove = <String>[];
    for (final source in sources) {
      _mapRx.value.remove(source);
      keysToRemove.add(source.toDbKey());
    }
    _mapRx.refresh();
    await _dBManager.deleteBulk(keysToRemove);
  }
}

class _LatestQueueSaver {
  const _LatestQueueSaver();

  static final _typesBuilderMapLookup = <String, Playable Function(dynamic p)>{
    'v': (p) => Video.explicit(p),
    'tr': (p) => Track.explicit(p),
    'twd': (p) => TrackWithDate.fromJson(p),
    'ytv': (p) => YoutubeID.fromJson(p),
  };

  static const _typesMapLookup = <Type, String>{
    Video: 'v',
    Track: 'tr',
    TrackWithDate: 'twd',
    YoutubeID: 'ytv',
  };
}
