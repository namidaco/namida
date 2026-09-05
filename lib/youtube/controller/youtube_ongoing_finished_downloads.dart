// rewrite by claude

import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/download_task_base.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';

typedef _TempListItem = (DownloadTaskGroupName, YoutubeItemDownloadConfig);

class YTOnGoingFinishedDownloads {
  static final YTOnGoingFinishedDownloads inst = YTOnGoingFinishedDownloads._internal();
  YTOnGoingFinishedDownloads._internal();

  final youtubeDownloadTasksTempList = <_TempListItem>[].obs;
  final isOnGoingSelected = Rxn<bool>();

  /// configs currently inside [youtubeDownloadTasksTempList], by their filename key, which is unique globally.
  ///
  /// allows telling wether an item has to move in/out of the list without scanning it.
  final _currentConfigs = <String, YoutubeItemDownloadConfig>{};

  static bool _isOnGoing(DownloadTaskGroupName groupName, YoutubeItemDownloadConfig config) {
    final filename = config.filename;
    final fileExists = YoutubeController.inst.downloadedFilesMap.value[groupName]?[filename] != null;
    if (!fileExists) return true;
    final id = config.id;
    return (YoutubeController.inst.isDownloading.value[id]?.value[filename] ?? false) || (YoutubeController.inst.isFetchingData.value[id]?.value[filename] ?? false);
  }

  static DateTime _sortDate(_TempListItem item, DateTime fallback) => item.$2.addedAt ?? item.$2.fileDate ?? fallback;

  /// newer first, ties broken by the original playlist order.
  static int _compare(_TempListItem a, _TempListItem b, DateTime fallback) {
    final compare = _sortDate(b, fallback).compareTo(_sortDate(a, fallback));
    if (compare != 0) return compare;
    return (a.$2.originalIndex ?? 0).compareTo(b.$2.originalIndex ?? 0);
  }

  static int _findInsertIndex(List<_TempListItem> list, _TempListItem item, DateTime fallback) {
    int low = 0;
    int high = list.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_compare(item, list[mid], fallback) < 0) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }

  /// Re-evaluates [configs] against the active filter, keeping the list sorted without re-sorting it.
  void onTasksStatusChanged(DownloadTaskGroupName groupName, List<YoutubeItemDownloadConfig> configs) {
    final forIsGoing = isOnGoingSelected.value;
    if (forIsGoing == null) return; // -- list isn't displayed.

    List<_TempListItem>? toInsert;
    Set<String>? toRemove;
    for (final config in configs) {
      final filenameKey = config.filename.key;
      final configInList = _currentConfigs[filenameKey];
      final shouldBeInList = _isOnGoing(groupName, config) == forIsGoing;
      if (shouldBeInList) {
        if (identical(configInList, config)) continue;
        // -- same task but a new instance (ex. edited) has to be swapped, and it can sort differently now.
        if (configInList != null) (toRemove ??= {}).add(filenameKey);
        (toInsert ??= []).add((groupName, config));
        _currentConfigs[filenameKey] = config;
      } else {
        if (configInList == null) continue;
        (toRemove ??= {}).add(filenameKey);
        _currentConfigs.remove(filenameKey);
      }
    }
    _applyChanges(toInsert, toRemove);
  }

  void onTasksRemoved(DownloadTaskGroupName groupName, List<YoutubeItemDownloadConfig> configs) {
    if (isOnGoingSelected.value == null) return; // -- list isn't displayed.

    Set<String>? toRemove;
    for (final config in configs) {
      final filenameKey = config.filename.key;
      if (_currentConfigs.remove(filenameKey) != null) (toRemove ??= {}).add(filenameKey);
    }
    _applyChanges(null, toRemove);
  }

  void _applyChanges(List<_TempListItem>? toInsert, Set<String>? toRemove) {
    if (toInsert == null && toRemove == null) return;

    final list = youtubeDownloadTasksTempList.value;
    // -- removals first, an item can be in both when its instance got swapped.
    if (toRemove != null) list.removeWhere((e) => toRemove.contains(e.$2.filename.key));
    if (toInsert != null) {
      final dateNow = DateTime.now();
      if (toInsert.length == 1) {
        final item = toInsert.first;
        list.insert(_findInsertIndex(list, item, dateNow), item);
      } else {
        list.addAll(toInsert);
        list.sort((a, b) => _compare(a, b, dateNow));
      }
    }
    youtubeDownloadTasksTempList.refresh();
  }

  /// Full rebuild, only needed when the filter itself changes.
  void updateTempList(bool? forIsGoing) {
    final list = youtubeDownloadTasksTempList.value;
    list.clear();
    _currentConfigs.clear();
    if (forIsGoing != null) {
      final tasksMap = YoutubeController.inst.youtubeDownloadTasksMap.value;
      tasksMap.keys.toFixedList().reverseLoop((groupName) {
        // -- reverseLoop to insert newer first.
        tasksMap[groupName]?.values.toFixedList().reverseLoop((config) {
          if (_isOnGoing(groupName, config) == forIsGoing) {
            list.add((groupName, config));
            _currentConfigs[config.filename.key] = config;
          }
        });
      });

      final dateNow = DateTime.now();
      list.sort((a, b) => _compare(a, b, dateNow));
    }
    youtubeDownloadTasksTempList.refresh();
  }
}
