import 'dart:async';

import 'package:namida/class/track.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/party/party_player_gate.dart';
import 'package:namida/controller/party/party_protocol.dart';
import 'package:namida/controller/party/party_state.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

abstract class PartyBinderDelegate {
  int nowMS();
  PartyMember? get me;
  bool get isHost;
  void sendCommand(PartyMsg command);
  void notifyDenied(PartyDenyReason reason, {String? details});
  void onForcesMixedQueueChanged(bool forcesMixedQueue);
  void onSyncStateChanged(PartySyncState state);
}

/// mirrors the party queue into the player & keeps the playback converging to the anchor.
/// the player is only a renderer here, user actions are turned into commands by the gate.
///
/// entries this device can't play are left out of the player queue entirely, so indices are
/// translated through entry ids rather than shared.
class PartyPlayerBinder implements PartyStateListener, PartyPlayerGate {
  final PartyState state;
  final PartyBinderDelegate _delegate;

  PartyPlayerBinder(this.state, this._delegate);

  static const _driftWhilePlayingMS = 1200;
  static const _driftWhilePausedMS = 300;
  static const _naturalAdvanceWindowMS = 12000;
  static const _localSeekSettleMS = 1000;
  static const _reconcileInterval = Duration(seconds: 4);
  static const _entriesPerFrame = 30;
  static const _maxEntriesForNonHostRewrite = 900;
  static const _maxIdsPerFrame = 1500;
  static const _maxRemovalsBeforeReassign = 16;

  final _playables = <Playable>[];

  /// entry id of each item in [_playables].
  final _playableIds = <int>[];
  final _unavailableIds = <int>{};
  final _idToPlayerIndex = <int, int>{};
  bool _indexDirty = false;

  Map<int, Track> _localIndex = const {};

  bool _locallyPaused = false;
  bool _listening = true;
  PartySyncState _syncState = PartySyncState.idle;
  int _lastLocalSeekMS = 0;
  bool _bound = false;
  bool _binding = false;
  Timer? _reconcileTimer;
  Timer? _deviationTimer;
  Future<void> _chain = Future.value();

  _StashedQueue? _stash;

  /// a party queue can hold both kinds at any moment, the dedicated players would break on the other one.
  @override
  bool get forcesMixedQueue => _bound;

  @override
  bool get canSkip {
    final me = _delegate.me;
    return me != null && state.canControl(me);
  }

  bool isUnavailable(PartyEntry entry) => _unavailableIds.contains(entry.id);

  // ------------------------------------------------------------

  /// [inheritLocalPause] keeps a paused player paused, for joining without a play intent.
  Future<void> bind({bool inheritLocalPause = true, required bool listening}) async {
    if (_bound || _binding) return;
    _listening = listening;
    _binding = true;
    _localIndex = await SyncPathResolver.localCoreIndex();
    if (!_binding) return;
    _binding = false;
    _bound = true;
    final player = Player.inst;
    // -- joining a party is not a play command, a paused player stays paused until the user says otherwise
    _locallyPaused = inheritLocalPause && !player.isPlaying.value;
    _stash = _StashedQueue(
      queue: player.currentQueue.value.toList(),
      index: player.currentIndex.value,
      positionMS: player.nowPlayingPosition.value,
    );
    player.partyGate = this;
    player.currentItemDuration.addListener(_onLocalDurationChanged);
    _delegate.onForcesMixedQueueChanged(true);
    _reconcileTimer = Timer.periodic(_reconcileInterval, (_) => reconcile());
    onQueueSet();
  }

  Future<void> unbind({required bool restoreQueue}) async {
    _binding = false;
    if (!_bound) return;
    _bound = false;
    _reconcileTimer?.cancel();
    _deviationTimer?.cancel();
    final player = Player.inst;
    player.currentItemDuration.removeListener(_onLocalDurationChanged);
    await _chain;
    player.partyGate = null;
    _clearQueueMirror();
    _delegate.onForcesMixedQueueChanged(false);
    _publishSyncState(.idle);

    final stash = _stash;
    _stash = null;
    if (!restoreQueue || stash == null) return;
    if (stash.queue.isEmpty) {
      await player.partyClearQueue();
      return;
    }
    await player.partyRestoreQueue(stash.queue, stash.index);
    if (stash.positionMS > 0) await player.partySeek(Duration(milliseconds: stash.positionMS));
  }

  void _clearQueueMirror() {
    _playables.clear();
    _playableIds.clear();
    _unavailableIds.clear();
    _idToPlayerIndex.clear();
    _indexDirty = false;
  }

  bool _matchesPlayerQueue() {
    final current = Player.inst.currentQueue.value;
    final length = _playables.length;
    if (current.length != length) return false;
    for (var i = 0; i < length; i++) {
      if (current[i].key != _playables[i].key) return false;
    }
    return true;
  }

  void _run(Future<void> Function() action) {
    _chain = _chain.then((_) => _bound ? action() : null).catchError((Object e, StackTrace st) => logger.error('party binder action failed', e: e, st: st));
  }

  // ------------------------------------------------------------ entries <-> playables

  static PartyEntry entryOf(Playable item) {
    if (item is YoutubeID) {
      final id = item.id;
      final utils = YoutubeInfoController.utils;
      return PartyEntry(
        id: 0,
        by: 0,
        ytId: id,
        fingerprint: null,
        title: utils.getVideoNameSync(id) ?? '',
        artist: utils.getVideoChannelNameSync(id) ?? '',
        album: '',
        durationMS: (utils.getVideoDurationSecondsSyncTemp(id) ?? 0) * 1000,
      );
    }
    final ext = (item as Selectable).track.toTrackExt();
    final knownYtId = ext.youtubeID;
    return PartyEntry(
      id: 0,
      by: 0,
      ytId: null,
      fingerprint: SyncTrackFingerprint.coreOf(ext),
      title: ext.title,
      artist: ext.originalArtist,
      album: ext.originalAlbum,
      durationMS: ext.durationMS,
      // -- saves everyone else a youtube search when the file is only on this device
      fallbackYtId: knownYtId.isEmpty ? null : knownYtId,
    );
  }

  /// null when this device can't play it, its id lands in [_unavailableIds].
  Playable? _resolve(PartyEntry entry) {
    final ytId = entry.ytId;
    if (ytId != null) return YoutubeID(id: ytId, playlistID: null);
    final local = _localIndex[entry.fingerprint];
    if (local != null) return local;
    final fallback = entry.fallbackYtId;
    if (fallback != null) return YoutubeID(id: fallback, playlistID: null);
    _unavailableIds.add(entry.id);
    return null;
  }

  int _playerIndexOf(int entryId) {
    if (_indexDirty) {
      _idToPlayerIndex.clear();
      for (var i = 0; i < _playableIds.length; i++) {
        _idToPlayerIndex[_playableIds[i]] = i;
      }
      _indexDirty = false;
    }
    return _idToPlayerIndex[entryId] ?? -1;
  }

  /// where an entry at [partyIndex] belongs in the player queue.
  int _playerInsertIndexFor(int partyIndex) {
    final entries = state.entries;
    final end = partyIndex.withMaximum(entries.length);
    if (_unavailableIds.isEmpty) return end;
    var count = 0;
    for (var i = 0; i < end; i++) {
      if (!_unavailableIds.contains(entries[i].id)) count++;
    }
    return count;
  }

  void _reportMissing(Iterable<PartyEntry> entries) {
    final ids = <int>[];
    for (final e in entries) {
      if (_unavailableIds.contains(e.id)) ids.add(e.id);
      if (ids.length >= _maxIdsPerFrame) break;
    }
    if (ids.isNotEmpty) _delegate.sendCommand(PartyMsg.missing(ids));
  }

  // ------------------------------------------------------------ state -> player

  @override
  void onQueueSet() {
    if (!_bound) return;
    _clearQueueMirror();
    final entries = state.entries;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final playable = _resolve(entry);
      if (playable == null) continue;
      _playables.add(playable);
      _playableIds.add(entry.id);
    }
    _indexDirty = true;
    _reportMissing(entries);

    _run(() async {
      final player = Player.inst;
      if (_playables.isEmpty) {
        await player.partyClearQueue();
        return;
      }
      // -- the player may already hold this exact queue (we seeded the room with it), reassigning would restart playback
      if (!_matchesPlayerQueue()) {
        final index = _playerIndexOf(state.anchor.entryId);
        final startPlaying = state.anchor.playing && !_locallyPaused && index >= 0;
        await player.partyAssignQueue(_playables.toList(), index < 0 ? 0 : index, startPlaying: startPlaying, roomName: state.roomName);
      }
      await _reconcileNow();
    });
  }

  @override
  void onEntriesAdded(int index, List<PartyEntry> entries) {
    if (!_bound) return;
    if (_playables.isEmpty) return onQueueSet();
    final insertAt = _playerInsertIndexFor(index);
    final items = <Playable>[];
    final ids = <int>[];
    for (final entry in entries) {
      final playable = _resolve(entry);
      if (playable == null) continue;
      items.add(playable);
      ids.add(entry.id);
    }
    _reportMissing(entries);
    if (items.isEmpty) return;
    _playables.insertAll(insertAt, items);
    _playableIds.insertAll(insertAt, ids);
    _indexDirty = true;
    _run(() async => Player.inst.partyInsert(items, insertAt));
  }

  @override
  void onEntriesRemoved(List<int> ids) {
    if (!_bound) return;
    _unavailableIds.removeAll(ids);
    final playerIndices = <int>[];
    for (final id in ids) {
      final index = _playerIndexOf(id);
      if (index >= 0) playerIndices.add(index);
    }
    if (playerIndices.isEmpty) return;
    // -- the player refreshes everything per removal, a single reassign is cheaper for bulk ones
    if (playerIndices.length > _maxRemovalsBeforeReassign || playerIndices.length >= _playables.length) return onQueueSet();
    playerIndices.sort((a, b) => b.compareTo(a));
    for (final index in playerIndices) {
      _playables.removeAt(index);
      _playableIds.removeAt(index);
    }
    _indexDirty = true;
    _run(() async {
      for (final index in playerIndices) {
        await Player.inst.partyRemoveAt(index);
      }
    });
  }

  @override
  void onEntryMoved(int fromIndex, int toIndex) {
    if (!_bound || toIndex < 0 || toIndex >= state.entries.length) return;
    final entryId = state.entries[toIndex].id;
    final from = _playerIndexOf(entryId);
    if (from < 0) return;
    final to = _playerInsertIndexFor(toIndex);
    if (from == to) return;
    _playables.insert(to, _playables.removeAt(from));
    _playableIds.insert(to, _playableIds.removeAt(from));
    _indexDirty = true;
    _run(() async => Player.inst.partyMove(from, to));
  }

  @override
  void onEntryMetaChanged(PartyEntry entry, {required bool fallbackChanged}) {
    if (!_bound || !fallbackChanged || !_unavailableIds.remove(entry.id)) return;
    final playable = _resolve(entry);
    final partyIndex = state.indexOfId(entry.id);
    if (playable == null || partyIndex < 0) return;
    final insertAt = _playerInsertIndexFor(partyIndex);
    _playables.insert(insertAt, playable);
    _playableIds.insert(insertAt, entry.id);
    _indexDirty = true;
    _run(() async {
      await Player.inst.partyInsert([playable], insertAt);
      if (entry.id == state.anchor.entryId) await _reconcileNow();
    });
  }

  @override
  void onAnchorChanged() => reconcile();

  @override
  void onMembersChanged() {}

  @override
  void onPermsChanged() {}

  @override
  void onChat(PartyChatMessage message) {}

  @override
  void onReaction(int n, String emoji) {}

  void reconcile() {
    if (!_bound) return;
    _run(_reconcileNow);
  }

  /// a remote keeps mirroring the queue & routing commands, it only stops playing.
  void setListening(bool listening) {
    if (_listening == listening) return;
    _listening = listening;
    // -- turning it on is a play command of its own, a stale local pause would swallow it
    if (listening) _locallyPaused = false;
    reconcile();
  }

  void _publishSyncState(PartySyncState state) {
    if (state == _syncState) return;
    _syncState = state;
    _delegate.onSyncStateChanged(state);
  }

  Future<void> _reconcileNow() async {
    final player = Player.inst;
    if (player.currentQueue.value.length != _playables.length) {
      // -- something edited the queue behind our back
      onQueueSet();
      return;
    }
    if (!_listening) {
      if (player.playWhenReady.value) await player.partyPause();
      final remoteIndex = _playerIndexOf(state.anchor.entryId);
      if (remoteIndex >= 0 && player.currentIndex.value != remoteIndex) await player.partySkipTo(remoteIndex, startPlaying: false);
      _publishSyncState(.idle);
      return;
    }
    final anchor = state.anchor;
    final index = _playerIndexOf(anchor.entryId);
    if (index < 0) {
      // -- nothing playable for this device at the party's position
      _publishSyncState(state.currentEntry == null ? .idle : .unavailable);
      if (player.playWhenReady.value) await player.partyPause();
      return;
    }

    final shouldPlay = anchor.playing && !_locallyPaused;
    if (!anchor.playing) {
      _publishSyncState(.inSync);
    } else if (_locallyPaused) {
      _publishSyncState(.pausedLocally);
    }
    final expected = anchor.positionAt(_delegate.nowMS());

    final localIndex = player.currentIndex.value;
    if (localIndex != index) {
      // -- gapless/crossfade start the next item before the party timeline gets there
      final durationMS = state.currentEntry?.durationMS ?? 0;
      final isNaturalAdvance = localIndex == (index + 1) % _playables.length && durationMS > 0 && expected >= durationMS - _naturalAdvanceWindowMS;
      if (isNaturalAdvance && shouldPlay) return;
      await player.partySkipTo(index, startPlaying: shouldPlay);
      if (expected > _driftWhilePlayingMS) await player.partySeek(Duration(milliseconds: expected));
      return;
    }

    final isLocalSeekSettling = DateTime.now().millisecondsSinceEpoch - _lastLocalSeekMS < _localSeekSettleMS;
    final isWaitingOnPlayer = player.isLoadingR || player.isBufferingR;
    if (!isLocalSeekSettling && !isWaitingOnPlayer) {
      final duration = player.currentItemDuration.value?.inMilliseconds ?? 0;
      final nearEnd = duration > 0 && expected >= duration - 500;
      if (!nearEnd) {
        final drift = (player.nowPlayingPosition.value - expected).abs();
        if (drift > (shouldPlay ? _driftWhilePlayingMS : _driftWhilePausedMS)) {
          await player.partySeek(Duration(milliseconds: expected));
        }
      }
    }
    if (shouldPlay) _publishSyncState(isWaitingOnPlayer ? .catchingUp : .inSync);

    if (shouldPlay != player.playWhenReady.value) {
      shouldPlay ? await player.partyPlay() : await player.partyPause();
    }
  }

  bool _isPlayingAnchorItem() => Player.inst.currentIndex.value == _playerIndexOf(state.anchor.entryId);

  void _onLocalDurationChanged() {
    if (!_listening) return;
    final duration = Player.inst.currentItemDuration.value?.inMilliseconds ?? 0;
    if (duration <= 0 || !_isPlayingAnchorItem()) return;
    final entry = state.currentEntry;
    if (entry == null || entry.durationMS > 0) return;
    _delegate.sendCommand(PartyMsg.duration(entry.id, duration));
  }

  // ------------------------------------------------------------ player -> commands

  bool _can(bool Function(PartyMember me) check) {
    final me = _delegate.me;
    if (me != null && check(me)) return true;
    _delegate.notifyDenied(.permission);
    return false;
  }

  @override
  bool interceptPlay() {
    _locallyPaused = false;
    if (state.anchor.playing) {
      // -- resuming a local pause, catch up with the party
      reconcile();
      return false;
    }
    final me = _delegate.me;
    if (me == null || !state.canControl(me)) {
      _delegate.notifyDenied(.permission);
      return true;
    }
    _delegate.sendCommand(const PartyMsg.play());
    return false;
  }

  @override
  bool interceptPause({required bool isUserInitiated}) {
    if (!isUserInitiated) return false;
    final me = _delegate.me;
    if (me != null && state.canControl(me)) {
      _delegate.sendCommand(const PartyMsg.pause());
    } else {
      _locallyPaused = true;
    }
    return false;
  }

  @override
  bool interceptSeek(Duration position) {
    if (!_can(state.canControl)) return true;
    _lastLocalSeekMS = DateTime.now().millisecondsSinceEpoch;
    _delegate.sendCommand(PartyMsg.seek(position.inMilliseconds));
    return false;
  }

  @override
  bool interceptSkip({int? index, int offset = 0}) {
    if (!_can(state.canControl)) return true;
    if (index == null) {
      _delegate.sendCommand(offset < 0 ? const PartyMsg.previous() : const PartyMsg.next());
    } else if (index >= 0 && index < _playableIds.length) {
      _delegate.sendCommand(PartyMsg.skip(_playableIds[index]));
    }
    return true;
  }

  @override
  bool interceptAdd(Iterable<Playable> items, {required bool insertNext, int? atIndex}) {
    if (!_can(state.canAdd)) return true;
    final drafts = items.map(entryOf).toList();
    if (drafts.isEmpty) return true;
    final int? afterId;
    if (atIndex != null) {
      afterId = atIndex <= 0 || _playableIds.isEmpty ? 0 : _playableIds[(atIndex - 1).withMaximum(_playableIds.length - 1)];
    } else {
      afterId = insertNext ? -1 : null;
    }
    _sendAddChunked(drafts, afterId);
    return true;
  }

  /// positioned chunks are sent last to first, so that they end up in order after the same anchor entry.
  void _sendAddChunked(List<PartyEntry> drafts, int? afterId, {int? playIndex}) {
    if (_delegate.isHost || drafts.length <= _entriesPerFrame) {
      _delegate.sendCommand(PartyMsg.add(drafts, afterId: afterId, playIndex: playIndex));
      return;
    }
    final chunks = <List<PartyEntry>>[];
    for (var start = 0; start < drafts.length; start += _entriesPerFrame) {
      chunks.add(drafts.sublist(start, (start + _entriesPerFrame).withMaximum(drafts.length)));
    }
    final reversed = afterId != null;
    for (var i = 0; i < chunks.length; i++) {
      final ci = reversed ? chunks.length - 1 - i : i;
      final start = ci * _entriesPerFrame;
      final inChunk = playIndex != null && playIndex >= start && playIndex < start + chunks[ci].length;
      _delegate.sendCommand(PartyMsg.add(chunks[ci], afterId: afterId, playIndex: inChunk ? playIndex - start : null));
    }
  }

  @override
  bool interceptRemove(int start, int end) {
    final me = _delegate.me;
    if (me == null || start < 0 || end > _playableIds.length || start >= end) return true;
    final ids = <int>[];
    for (var i = start; i < end; i++) {
      final entry = state.entryById(_playableIds[i]);
      if (entry != null && state.canEditEntry(me, entry)) ids.add(entry.id);
    }
    if (ids.isEmpty) {
      _delegate.notifyDenied(.permission);
      return true;
    }
    for (var i = 0; i < ids.length; i += _maxIdsPerFrame) {
      _delegate.sendCommand(PartyMsg.remove(ids.sublist(i, (i + _maxIdsPerFrame).withMaximum(ids.length))));
    }
    return true;
  }

  @override
  bool interceptReorder(int oldIndex, int newIndex) {
    final me = _delegate.me;
    if (me == null || oldIndex < 0 || oldIndex >= _playableIds.length) return true;
    final entry = state.entryById(_playableIds[oldIndex]);
    if (entry == null) return true;
    if (!state.canEditEntry(me, entry)) {
      _delegate.notifyDenied(.permission);
      return true;
    }
    final finalIndex = (newIndex > oldIndex ? newIndex - 1 : newIndex).clampInt(0, _playableIds.length - 1);
    if (finalIndex == oldIndex) return true;
    final int afterId;
    if (finalIndex == 0) {
      afterId = 0;
    } else {
      final before = finalIndex - 1;
      afterId = _playableIds[before < oldIndex ? before : before + 1];
    }
    _delegate.sendCommand(PartyMsg.move(entry.id, afterId));
    return true;
  }

  @override
  bool interceptNewQueue(Iterable<Playable> queue, int index, {required bool startPlaying, required bool shuffle, required bool isPlayerQueue}) {
    if (isPlayerQueue) return interceptSkip(index: index);
    final me = _delegate.me;
    if (me == null) return true;
    final canSetQueue = state.canSetQueue(me);
    if (!canSetQueue && !state.canAdd(me)) {
      _delegate.notifyDenied(.permission);
      return true;
    }
    final drafts = queue.map(entryOf).toList();
    if (drafts.isEmpty) return true;
    var playIndex = index.clampInt(0, drafts.length - 1);
    if (shuffle) {
      final first = drafts.removeAt(playIndex);
      drafts
        ..shuffle()
        ..insert(0, first);
      playIndex = 0;
    }
    if (canSetQueue) {
      _sendQueue(drafts, playIndex, 0, startPlaying);
    } else {
      // -- no right to replace the queue, add after the current entry & play it instead
      playIndex = _trimForNonHost(drafts, playIndex);
      _sendAddChunked(drafts, -1, playIndex: startPlaying ? playIndex : null);
    }
    return true;
  }

  @override
  bool interceptQueueRewrite(PartyQueueRewrite rewrite) {
    if (!_can(state.canSetQueue)) return true;
    final entries = state.entries.toList();
    final current = state.currentIndex;
    final currentEntry = state.currentEntry;
    switch (rewrite) {
      case PartyQueueRewrite.clear:
        entries.clear();
      case PartyQueueRewrite.shuffleAll:
        entries.shuffle();
        if (currentEntry != null) {
          entries
            ..remove(currentEntry)
            ..insert(0, currentEntry);
        }
      case PartyQueueRewrite.shuffleNext:
        if (current + 1 < entries.length) {
          final next = entries.sublist(current + 1)..shuffle();
          entries.replaceRange(current + 1, entries.length, next);
        }
      case PartyQueueRewrite.removeDuplicates:
        final seen = <Object>{};
        entries.retainWhere((e) => seen.add(e.ytId ?? e.fingerprint ?? e.id));
    }
    final anchor = state.anchor;
    final newIndex = currentEntry == null ? 0 : entries.indexOf(currentEntry);
    _sendQueue(entries, newIndex < 0 ? 0 : newIndex, newIndex < 0 ? 0 : anchor.positionAt(_delegate.nowMS()), anchor.playing);
    return true;
  }

  /// non hosts are limited in frame size & rate by the relay, keep the window around [index].
  int _trimForNonHost(List<PartyEntry> drafts, int index) {
    if (drafts.length <= _maxEntriesForNonHostRewrite) return index;
    final start = (index - _maxEntriesForNonHostRewrite ~/ 2).clampInt(0, drafts.length - _maxEntriesForNonHostRewrite);
    drafts
      ..removeRange(start + _maxEntriesForNonHostRewrite, drafts.length)
      ..removeRange(0, start);
    _delegate.notifyDenied(.queueFull);
    return index - start;
  }

  void _sendQueue(List<PartyEntry> drafts, int index, int positionMS, bool playing) {
    if (_delegate.isHost || drafts.length <= _entriesPerFrame) {
      _delegate.sendCommand(PartyMsg.setQueue(drafts, index: index, positionMS: positionMS, playing: playing));
      return;
    }
    index = _trimForNonHost(drafts, index);
    // -- the chunk holding the playing item goes first, the rest gets added around it
    final firstStart = (index ~/ _entriesPerFrame) * _entriesPerFrame;
    final firstEnd = (firstStart + _entriesPerFrame).withMaximum(drafts.length);
    _delegate.sendCommand(PartyMsg.setQueue(drafts.sublist(firstStart, firstEnd), index: index - firstStart, positionMS: positionMS, playing: playing));
    if (firstStart > 0) _sendAddChunked(drafts.sublist(0, firstStart), 0);
    if (firstEnd < drafts.length) {
      for (var start = firstEnd; start < drafts.length; start += _entriesPerFrame) {
        _delegate.sendCommand(PartyMsg.add(drafts.sublist(start, (start + _entriesPerFrame).withMaximum(drafts.length))));
      }
    }
  }

  @override
  void onLocalIndexChanged(int index) {
    if (index >= 0 && index < _playableIds.length && _playableIds[index] == state.anchor.entryId) return;
    // -- most likely a natural advance slightly ahead of the host, give its anchor a moment to arrive
    _deviationTimer?.cancel();
    _deviationTimer = Timer(const Duration(milliseconds: 1500), reconcile);
  }

  @override
  void onLocalItemCompleted() {
    if (!_listening || !_isPlayingAnchorItem()) return;
    _delegate.sendCommand(PartyMsg.ended(state.anchor.entryId));
  }
}

class _StashedQueue {
  final List<Playable> queue;
  final int index;
  final int positionMS;

  const _StashedQueue({required this.queue, required this.index, required this.positionMS});
}
