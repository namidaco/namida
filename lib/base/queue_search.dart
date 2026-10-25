// by claude
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:namida/base/tracks_search_wrapper.dart';
import 'package:namida/class/jump_highlight.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

class QueueSearch with PortsProvider<TracksSearchParams> {
  final void Function(bool isNewQuery) onResultsChanged;

  /// the search is closed already, [index] is the tapped result in the full queue.
  final void Function(int index) onResultSelected;

  QueueSearch({required this.onResultsChanged, required this.onResultSelected});

  final _isOpen = false.obso;

  /// queue indices of the matching items by relevance, null while not filtering.
  final results = RxnO<List<int>>();

  /// position of each queue index in [results], -1 when it didn't match.
  Int32List? _resultPositions;

  TextEditingController? _textController;
  FocusNode? _focusNode;

  static final _kNoMatches = Int32List(0);

  String _query = '';
  String _queryLower = '';
  bool _isAwaitingQueryResult = false;

  /// append-only during a session, so indices in [_localMatchRanks] stay valid after queue changes.
  Map<Track, int>? _localIndexOf;
  int _isolateTracksCount = 0;

  /// 1 is the best match and 0 is no match.
  Int32List? _localMatchRanks;
  int _localMatchesCount = 0;

  /// local index of each queue item, -1 for videos.
  Int32List? _queueLocalIndices;

  Map<String, String>? _videoTextsLower;

  bool get _hasLocalTracks => _localIndexOf?.isNotEmpty == true;
  bool get _isolateLacksTracks => (_localIndexOf?.length ?? 0) > _isolateTracksCount;

  /// position of the queue [index] in the shown list, null when it's filtered out.
  int? positionOf(int index) {
    final resultPositions = _resultPositions;
    if (resultPositions == null) return index;
    if (index >= resultPositions.length) return null;
    final position = resultPositions[index];
    return position < 0 ? null : position;
  }

  void toggle() {
    if (_isOpen.value) {
      _close();
    } else {
      _open();
    }
  }

  void close() {
    if (_isOpen.value) _close();
  }

  void selectResult(int index) {
    if (!_isOpen.value) return;
    final item = Player.inst.currentQueue.value[index];
    _close(selectedIndex: index);
    JumpHighlight.showBriefly(item, index, inQueue: true);
  }

  void dispose() {
    if (_isOpen.value) _release();
    _textController?.dispose();
    _focusNode?.dispose();
    _isOpen.close();
    results.close();
  }

  void _open() {
    _textController ??= TextEditingController();
    final focusNode = _focusNode ??= FocusNode();
    Player.inst.currentQueue.addListener(_onQueueChanged);
    settings.trackSearchFilterDefault.addListener(_restartIsolate);
    _isOpen.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());
  }

  void _close({int? selectedIndex}) {
    _release();
    _textController?.clear();
    _focusNode?.unfocus();
    _isOpen.value = false;
    if (selectedIndex == null) {
      _setResults(null, null, isNewQuery: true);
    } else {
      _resultPositions = null;
      results.value = null;
      onResultSelected(selectedIndex);
    }
  }

  void _release() {
    Player.inst.currentQueue.removeListener(_onQueueChanged);
    settings.trackSearchFilterDefault.removeListener(_restartIsolate);
    disposePort();
    _query = '';
    _queryLower = '';
    _isAwaitingQueryResult = false;
    _localIndexOf = null;
    _isolateTracksCount = 0;
    _localMatchRanks = null;
    _localMatchesCount = 0;
    _queueLocalIndices = null;
    _videoTextsLower = null;
  }

  Future<void> _onTextChanged(String text) async {
    final query = text.trim();
    if (query == _query) return;
    _query = query;
    _queryLower = query.toLowerCase();
    if (query.isEmpty) {
      _isAwaitingQueryResult = false;
      _localMatchRanks = null;
      _localMatchesCount = 0;
      _setResults(null, null, isNewQuery: true);
      return;
    }

    if (_queueLocalIndices == null) _mapQueue();
    if (!_hasLocalTracks) {
      _applyResults(isNewQuery: true);
      return;
    }

    _isAwaitingQueryResult = true;
    if (_isolateLacksTracks) await disposePort();
    if (!isInitialized) await initialize();
    await sendPort(query);
  }

  void _onQueueChanged() {
    _queueLocalIndices = null;
    if (_query.isEmpty) return;
    _mapQueue();
    if (results.value != null) _applyResults(isNewQuery: false);
    if (_isolateLacksTracks) _restartIsolate();
  }

  Future<void> _restartIsolate() async {
    await disposePort();
    if (_query.isEmpty || !_hasLocalTracks) return;
    await initialize();
    await sendPort(_query);
  }

  Int32List _mapQueue() {
    final queue = Player.inst.currentQueue.value;
    final localIndexOf = _localIndexOf ??= <Track, int>{};
    final queueLength = queue.length;
    final queueLocalIndices = Int32List(queueLength);
    for (int i = 0; i < queueLength; i++) {
      final item = queue[i];
      if (item is! Selectable) {
        queueLocalIndices[i] = -1;
        continue;
      }
      final track = item.track;
      int? localIndex = localIndexOf[track];
      if (localIndex == null) {
        localIndex = localIndexOf.length;
        localIndexOf[track] = localIndex;
      }
      queueLocalIndices[i] = localIndex;
    }
    return _queueLocalIndices = queueLocalIndices;
  }

  /// counting sort by rank so it stays linear. repeated tracks and videos keep their queue order.
  void _applyResults({required bool isNewQuery}) {
    final queue = Player.inst.currentQueue.value;
    final queueLocalIndices = _queueLocalIndices ?? _mapQueue();
    final localMatchRanks = _localMatchRanks ?? _kNoMatches;
    final localMatchRanksLength = localMatchRanks.length;
    final videosRank = _localMatchesCount + 1;
    final queryLower = _queryLower;
    final queueLength = queueLocalIndices.length;

    // -- holds each item's rank first, then its position in the results
    final resultPositions = Int32List(queueLength);
    final rankOffsets = Int32List(videosRank + 1);
    int matchedCount = 0;
    for (int i = 0; i < queueLength; i++) {
      final localIndex = queueLocalIndices[i];
      int rank = 0;
      if (localIndex >= 0) {
        if (localIndex < localMatchRanksLength) rank = localMatchRanks[localIndex];
      } else {
        final item = queue[i];
        if (item is YoutubeID && _isVideoMatch(item.id, queryLower)) rank = videosRank;
      }
      resultPositions[i] = rank;
      if (rank > 0) {
        rankOffsets[rank]++;
        matchedCount++;
      }
    }

    int offset = 0;
    for (int rank = 1; rank <= videosRank; rank++) {
      final rankCount = rankOffsets[rank];
      rankOffsets[rank] = offset;
      offset += rankCount;
    }

    final matchedIndices = Int32List(matchedCount);
    for (int i = 0; i < queueLength; i++) {
      final rank = resultPositions[i];
      if (rank == 0) {
        resultPositions[i] = -1;
        continue;
      }
      final position = rankOffsets[rank]++;
      matchedIndices[position] = i;
      resultPositions[i] = position;
    }
    _setResults(matchedIndices, resultPositions, isNewQuery: isNewQuery);
  }

  bool _isVideoMatch(String videoId, String queryLower) {
    final videoTextsLower = _videoTextsLower ??= <String, String>{};
    final cached = videoTextsLower[videoId];
    if (cached != null) return cached.contains(queryLower);
    final title = YoutubeInfoController.utils.getVideoNameSync(videoId, checkFromStorage: false);
    final channelName = YoutubeInfoController.utils.getVideoChannelNameSync(videoId, checkFromStorage: false);
    final text = '${title ?? ''}\n${channelName ?? ''}';
    final textLower = text.toLowerCase();
    // -- not cached without a title, it can still be loaded later
    if (title != null) videoTextsLower[videoId] = textLower;
    return textLower.contains(queryLower);
  }

  void _setResults(List<int>? newResults, Int32List? newResultPositions, {required bool isNewQuery}) {
    if (newResults == null && results.value == null) return;
    _resultPositions = newResultPositions;
    results.value = newResults;
    onResultsChanged(isNewQuery);
  }

  @override
  void onResult(dynamic result) {
    if (result is! (Int32List, int, String)) return;
    final (matchRanks, matchesCount, text) = result;
    if (text != _query) return;
    _localMatchRanks = matchRanks;
    _localMatchesCount = matchesCount;
    final isNewQuery = _isAwaitingQueryResult;
    _isAwaitingQueryResult = false;
    _applyResults(isNewQuery: isNewQuery);
  }

  @override
  Future<IsolateFunctionReturnBuild<TracksSearchParams>> isolateFunction(SendPort port) async {
    await HistoryController.inst.waitForHistoryAndMostPlayedLoad;
    final topTracksMapListens = HistoryController.inst.topTracksMapListens.value;
    final localTracks = _localIndexOf?.keys ?? const <Track>[];
    _isolateTracksCount = localTracks.length;
    final tracksExtended = localTracks.map((e) => e.toTrackExt());
    final params = TracksSearchWrapper.generateParams(port, tracksExtended, topTracksMapListens, filters: settings.trackSearchFilterDefault.value);
    return IsolateFunctionReturnBuild(_searchIsolate, params);
  }

  static void _searchIsolate(TracksSearchParams params) {
    final sendPort = params.sendPort;

    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final searchWrapper = TracksSearchWrapper.init(params);

    StreamSubscription? streamSub;
    streamSub = receivePort.listen((p) {
      if (p == PortsProviderMessages.disposed) {
        receivePort.close();
        streamSub?.cancel();
        return;
      }
      if (p is! String) return;
      final result = searchWrapper.filterRanks(p);
      sendPort.send((result.ranks, result.matchesCount, p));
    });

    sendPort.send(PortsProviderMessages.prepared);
  }
}

class QueueSearchBox extends StatelessWidget {
  final QueueSearch search;

  const QueueSearchBox({super.key, required this.search});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: search._isOpen,
      builder: (context, isOpen) {
        final textController = search._textController;
        return AnimatedShow(
          duration: const Duration(milliseconds: 250),
          show: isOpen,
          child: textController == null
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: _QueueSearchFieldRow(
                    search: search,
                    textController: textController,
                  ),
                ),
        );
      },
    );
  }
}

/// [itemExtentOf] and [itemBuilder] always receive the real queue index.
class QueueSliverList extends StatelessWidget {
  final List<Playable> queue;
  final QueueSearch? search;
  final double? itemExtent;
  final double? Function(int index)? itemExtentOf;
  final Widget Function(BuildContext context, int index, List<Playable> queue, void Function(int index)? onResultTap) itemBuilder;

  const QueueSliverList({
    super.key,
    required this.queue,
    required this.search,
    required this.itemExtent,
    this.itemExtentOf,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final search = this.search;
    if (search == null) {
      return _QueueSliverListContent(
        list: this,
        results: null,
      );
    }
    return ObxO(
      rx: search.results,
      builder: (context, results) => _QueueSliverListContent(
        list: this,
        results: results,
      ),
    );
  }
}

class _QueueSliverListContent extends StatelessWidget {
  final QueueSliverList list;
  final List<int>? results;

  const _QueueSliverListContent({required this.list, required this.results});

  @override
  Widget build(BuildContext context) {
    final queue = list.queue;
    final itemExtent = list.itemExtent;
    final itemExtentOf = list.itemExtentOf;
    final itemBuilder = list.itemBuilder;
    final results = this.results;

    if (results == null) {
      return NamidaSliverReorderableList(
        itemCount: queue.length,
        itemExtent: itemExtent,
        itemExtentBuilder: itemExtentOf == null ? null : (index, _) => itemExtentOf(index),
        onReorderStart: (index) => Player.inst.invokeQueueModifyLock(),
        onReorderEnd: (index) => Player.inst.invokeQueueModifyLockRelease(),
        onReorder: (oldIndex, newIndex) => Player.inst.reorderTrack(oldIndex, newIndex),
        onReorderCancel: () => Player.inst.invokeQueueModifyOnModifyCancel(),
        itemBuilder: (context, i) => itemBuilder(context, i, queue, null),
      );
    }

    final onResultTap = list.search?.selectResult;
    final resultsLength = results.length;
    Widget resultBuilder(BuildContext context, int i) => itemBuilder(context, results[i], queue, onResultTap);
    if (itemExtent != null) {
      return SliverFixedExtentList.builder(
        itemCount: resultsLength,
        itemExtent: itemExtent,
        itemBuilder: resultBuilder,
      );
    }
    if (itemExtentOf != null) {
      return SliverVariedExtentList.builder(
        itemCount: resultsLength,
        itemExtentBuilder: (i, _) => i < resultsLength ? itemExtentOf(results[i]) : null,
        itemBuilder: resultBuilder,
      );
    }
    return SliverList.builder(
      itemCount: resultsLength,
      itemBuilder: resultBuilder,
    );
  }
}

class _QueueSearchFieldRow extends StatelessWidget {
  final QueueSearch search;
  final TextEditingController textController;

  const _QueueSearchFieldRow({required this.search, required this.textController});

  @override
  Widget build(BuildContext context) {
    // -- the miniplayer queue has no Material for the text field
    return Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          const SizedBox(width: 12.0),
          Expanded(
            child: CustomTextField(
              focusNode: search._focusNode,
              textFieldController: textController,
              textFieldHintText: lang.search,
              onTextFieldValueChanged: search._onTextChanged,
            ),
          ),
          const SizedBox(width: 12.0),
          NamidaIconButton(
            icon: Broken.close_circle,
            onPressed: search.close,
          ),
          const SizedBox(width: 8.0),
        ],
      ),
    );
  }
}
