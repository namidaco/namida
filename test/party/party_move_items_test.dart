// by claude
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:basic_audio_handler/basic_audio_handler.dart' show PlayerRepeatMode;
import 'package:nampack/nampack.dart' show Rx, RxBaseCore;

import 'package:namida/class/track.dart';
import 'package:namida/controller/party/party_host.dart';
import 'package:namida/controller/party/party_player_binder.dart';
import 'package:namida/controller/party/party_player_gate.dart';
import 'package:namida/controller/party/party_protocol.dart';
import 'package:namida/controller/party/party_state.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/youtube/class/youtube_id.dart';

/// in-memory room: every message goes through encode/decode like on the wire.
class _Room implements PartyHostDelegate {
  final hostState = PartyState();
  late final PartyHost host;
  final members = <int, PartyState>{};
  final denied = <int, List<PartyMsg>>{};
  final events = <PartyMsg>[];
  final needsSync = <int>{};

  /// members on a build without [PartyMsgType.movedMany], they drop what they can't decode.
  final legacyMembers = <int>{};

  _Room() {
    host = PartyHost.create(state: hostState, selfN: 1, selfName: 'host', roomName: 'room', listening: true, repeat: PartyRepeat.initial, delegate: this);
  }

  PartyState join(int n) {
    final state = PartyState();
    members[n] = state;
    host.onMemberJoined(n, 'm$n');
    send(n, PartyMsg.hello(listening: true));
    return state;
  }

  void send(int fromN, PartyMsg cmd) => host.onCommand(fromN, PartyMsg.decode(cmd.encode()));

  void _deliver(int n, PartyMsg event) {
    final decoded = PartyMsg.decode(event.encode());
    if (decoded.type == PartyMsgType.denied) {
      (denied[n] ??= []).add(decoded);
      return;
    }
    if (legacyMembers.contains(n) && decoded.type == PartyMsgType.movedMany) return;
    final state = members[n];
    if (state == null) return;
    if (state.epoch == 0 && decoded.type != PartyMsgType.snapshot) return;
    if (!state.apply(decoded)) needsSync.add(n);
  }

  void expectConverged() {
    expect(needsSync, isEmpty);
    for (final state in members.values) {
      expect(state.rev, hostState.rev);
      expect(_ids(state), _ids(hostState));
    }
  }

  @override
  int nowMS() => 1000;

  @override
  void broadcast(PartyMsg event) {
    events.add(event);
    for (final n in members.keys.toList()) {
      _deliver(n, event);
    }
  }

  @override
  void sendTo(int n, PartyMsg event) => _deliver(n, event);

  @override
  void relayKick(int n, {required bool ban}) {}

  @override
  void relaySuccessors(List<int> ns) {}

  @override
  void resolveFallback(PartyEntry entry) {}
}

/// commands wait in [outbox], so a guest's binder keeps working from the pre-move queue like over the relay.
class _Member implements PartyBinderDelegate {
  final _Room room;
  final int n;
  final PartyState state;
  final Player player;
  late final binder = PartyPlayerBinder.withPlayer(state, this, player);
  final outbox = <PartyMsg>[];
  final deniedReasons = <PartyDenyReason>[];

  _Member(this.room, this.n, this.state, {Player? player}) : player = player ?? Player.inst;

  void mirrorState() => binder.debugMirrorIds(_ids(state));

  void flush() {
    for (final command in outbox) {
      room.send(n, command);
    }
    outbox.clear();
  }

  @override
  bool get isHost => n == 1;

  @override
  PartyMember? get me => state.members[n];

  @override
  int nowMS() => 1000;

  @override
  void sendCommand(PartyMsg command) => outbox.add(command);

  @override
  void notifyDenied(PartyDenyReason reason, {String? details}) => deniedReasons.add(reason);

  @override
  void onForcesMixedQueueChanged(bool forcesMixedQueue) {}

  @override
  void onSyncStateChanged(PartySyncState state) {}
}

/// the queue side of the player, anything else the binder calls throws.
class _FakePlayer implements Player {
  final _queue = Rx<List<Playable>>([]);
  final _index = Rx<int>(0);
  final _position = Rx<int>(0);
  final _duration = Rx<Duration?>(null);
  final _isPlaying = Rx<bool>(false);
  final _playWhenReady = Rx<bool>(false);
  final _numberOfRepeats = Rx<int>(1);

  /// holds the next assignment back until completed, keeping the binder chain busy.
  Completer<void>? assignBlocker;

  List<String> get queueYtIds => _queue.value.map((e) => (e as YoutubeID).id).toList();

  @override
  PartyPlayerGate? partyGate;

  @override
  RxBaseCore<List<Playable>> get currentQueue => _queue;

  @override
  RxBaseCore<int> get currentIndex => _index;

  @override
  RxBaseCore<int> get nowPlayingPosition => _position;

  @override
  RxBaseCore<Duration?> get currentItemDuration => _duration;

  @override
  RxBaseCore<bool> get isPlaying => _isPlaying;

  @override
  RxBaseCore<bool> get playWhenReady => _playWhenReady;

  @override
  RxBaseCore<int> get numberOfRepeats => _numberOfRepeats;

  @override
  bool get isLoadingR => false;

  @override
  bool get isBufferingR => false;

  @override
  void updateNumberOfRepeats(int newNumber) {}

  @override
  void partySetRepeat(PlayerRepeatMode repeatMode, int times) {}

  @override
  Future<void> partyAssignQueue(List<Playable> queue, int index, {required bool startPlaying, required String roomName}) async {
    final blocker = assignBlocker;
    assignBlocker = null;
    if (blocker != null) await blocker.future;
    _queue.value = queue.toList();
    _index.value = index;
  }

  @override
  Future<void> partyClearQueue() async {
    _queue.value = [];
  }

  @override
  FutureOr<void> partyMove(int fromIndex, int toIndex) {
    final queue = _queue.value;
    queue.insert(toIndex, queue.removeAt(fromIndex));
  }

  @override
  Future<void> partySkipTo(int index, {required bool startPlaying}) async {
    _index.value = index;
  }

  @override
  Future<void> partySeek(Duration position) async {}

  @override
  Future<void> partyPlay() async {}

  @override
  Future<void> partyPause() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MovesRecorder implements PartyStateListener {
  final batchIndices = <int>[];
  final batchIds = <List<int>>[];
  int singleMoves = 0;

  @override
  void onEntriesMoved(int index, List<PartyEntry> entries) {
    batchIndices.add(index);
    batchIds.add(entries.map((e) => e.id).toList());
  }

  @override
  void onEntryMoved(int fromIndex, int toIndex) => singleMoves++;

  @override
  void onQueueSet() {}
  @override
  void onEntriesAdded(int index, List<PartyEntry> entries) {}
  @override
  void onEntriesRemoved(List<int> ids) {}
  @override
  void onEntryMetaChanged(PartyEntry entry, {required bool fallbackChanged}) {}
  @override
  void onAnchorChanged() {}
  @override
  void onRepeatChanged() {}
  @override
  void onMembersChanged() {}
  @override
  void onPermsChanged() {}
  @override
  void onChat(PartyChatMessage message) {}
  @override
  void onReaction(int n, String emoji) {}
}

const _guestMaxFrameBytes = 16 * 1024;

PartyEntry _yt(String id) {
  return PartyEntry(id: 0, by: 0, ytId: id, fingerprint: null, title: 't$id', artist: 'a', album: '', durationMS: 200000);
}

List<PartyEntry> _drafts(int count) => List.generate(count, (i) => _yt('v$i'));

List<int> _ids(PartyState state) => state.entries.map((e) => e.id).toList();

List<String?> _ytIds(PartyState state) => state.entries.map((e) => e.ytId).toList();

/// what the local queue does with the same move.
List<String> _localMove(List<String> queue, List<int> indices, int current, {required bool toLast}) {
  final moved = indices.where((i) => i >= 0 && i < queue.length && i != current).toSet().toList()..sort();
  final movedItems = moved.map((i) => queue[i]).toList();
  final rest = [
    for (var i = 0; i < queue.length; i++)
      if (!moved.contains(i)) queue[i],
  ];
  if (toLast) return [...rest, ...movedItems];
  final currentAt = rest.indexOf(queue[current]);
  return rest..insertAll(currentAt + 1, movedItems);
}

/// [sortedIndices] consecutively right after [afterIndex], -1 for the top.
List<T> _reference<T>(List<T> queue, List<int> sortedIndices, int afterIndex) {
  final movedSet = sortedIndices.toSet();
  final moved = sortedIndices.map((i) => queue[i]).toList();
  final rest = [
    for (var i = 0; i < queue.length; i++)
      if (!movedSet.contains(i)) queue[i],
  ];
  final insertAt = afterIndex < 0 ? 0 : rest.indexOf(queue[afterIndex]) + 1;
  return rest..insertAll(insertAt, moved);
}

/// [n] adds [queue] then moves through its binder, an observer guest checks the broadcast.
List<String?> _moveItems(int n, List<String> queue, List<int> sortedIndices, int afterIndex) {
  final room = _Room();
  room.join(9);
  final memberState = n == 1 ? room.hostState : room.join(n);
  final member = _Member(room, n, memberState);
  room.send(n, PartyMsg.add(queue.map(_yt).toList()));
  member.mirrorState();
  final revBefore = room.hostState.rev;
  final eventsBefore = room.events.length;

  expect(member.binder.interceptMoveItems(sortedIndices, afterIndex: afterIndex), true);
  expect(member.outbox.length, sortedIndices.isEmpty ? 0 : 1);
  member.flush();

  expect(member.deniedReasons, isEmpty);
  expect(room.denied, isEmpty);
  final newEvents = room.events.skip(eventsBefore).map((e) => e.type).toList();
  expect(newEvents, room.hostState.rev == revBefore ? isEmpty : [PartyMsgType.movedMany]);
  room.expectConverged();
  return _ytIds(room.hostState);
}

void main() {
  test('batch moves end in the same order on the host & on a guest', () {
    final cases = <(List<String>, List<int>, int, List<String>)>[
      (['a', 'b', 'c', 'd', 'e', 'f'], [0, 3, 5], 2, ['b', 'c', 'a', 'd', 'f', 'e']),
      (['a', 'b', 'c', 'd'], [0, 1], 3, ['c', 'd', 'a', 'b']),
      (['a', 'b', 'c', 'd', 'e'], [2, 4], 3, ['a', 'b', 'd', 'c', 'e']),
      (['a', 'b', 'c', 'd', 'e'], [3, 4], 2, ['a', 'b', 'c', 'd', 'e']),
      (['a', 'b', 'c', 'd', 'e'], [3, 4], -1, ['d', 'e', 'a', 'b', 'c']),
    ];
    for (final (queue, sortedIndices, afterIndex, expected) in cases) {
      for (final n in [1, 2]) {
        expect(_moveItems(n, queue, sortedIndices, afterIndex), expected, reason: 'member $n moving $sortedIndices after $afterIndex');
      }
    }
  });

  test('play next & play last from the player end like the local moves', () {
    final queue = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
    final cases = <(List<int>, int)>[
      ([0, 3, 5], 2),
      ([3, 4], 2),
      ([3, 4, 6], 2),
      ([0, 3, 4], 2),
      ([2, 5, 6], 2),
      ([5, 6], 6),
      ([0, 1, 6, 6], 6),
      ([2, 4, 9, -1], 0),
    ];
    for (final (indices, current) in cases) {
      for (final toLast in [false, true]) {
        final expected = _localMove(queue, indices, current, toLast: toLast);
        final move = Player.partyMoveOf(indices, queueLength: queue.length, currentIndex: current, toLast: toLast);
        for (final n in [1, 2]) {
          final reason = 'member $n moving $indices ${toLast ? 'last' : 'next'} with current $current';
          expect(_moveItems(n, queue, move.sortedIndices, move.afterIndex), expected, reason: reason);
        }
      }
    }
  });

  test('items already in place are not sent', () {
    void expectMove(List<int> indices, int current, bool toLast, List<int> sortedIndices, int afterIndex) {
      final move = Player.partyMoveOf(indices, queueLength: 7, currentIndex: current, toLast: toLast);
      expect(move.sortedIndices, sortedIndices);
      expect(move.afterIndex, afterIndex);
    }

    expectMove([3, 4], 2, false, [], 4);
    expectMove([3, 4, 6], 2, false, [6], 4);
    expectMove([0, 3, 4], 2, false, [0, 3, 4], 2);
    expectMove([2, 5, 6], 0, true, [2], 4);
  });

  test('the host applies a batch as one event & guests apply it the same way', () {
    final room = _Room();
    final guest = room.join(2);
    final recorder = _MovesRecorder();
    guest.listener = recorder;
    room.send(1, PartyMsg.add(_drafts(10)));
    final revBefore = room.hostState.rev;
    final eventsBefore = room.events.length;

    room.send(1, PartyMsg.moveMany([9, 2, 6], 4));
    expect(room.hostState.rev, revBefore + 1);
    expect(room.events.skip(eventsBefore).map((e) => e.type), [PartyMsgType.movedMany]);
    expect(_ids(room.hostState), [1, 3, 4, 9, 2, 6, 5, 7, 8, 10]);
    expect(recorder.batchIndices, [3]);
    expect(recorder.batchIds, [
      [9, 2, 6],
    ]);
    expect(recorder.singleMoves, 0);
    room.expectConverged();

    room.send(1, PartyMsg.moveMany([10, 1], 0));
    expect(_ids(room.hostState), [10, 1, 3, 4, 9, 2, 6, 5, 7, 8]);
    expect(recorder.batchIndices.last, 0);
    room.expectConverged();

    final revBeforeNoop = room.hostState.rev;
    room.send(1, PartyMsg.moveMany([3, 4], 1));
    expect(room.hostState.rev, revBeforeNoop);
    expect(room.denied, isEmpty);
  });

  test('a batch equals the chained single moves', () {
    final random = Random(7);
    for (var round = 0; round < 400; round++) {
      final length = 1 + random.nextInt(40);
      final batchRoom = _Room();
      final chainRoom = _Room();
      batchRoom.join(2);
      chainRoom.join(2);
      batchRoom.send(1, PartyMsg.add(_drafts(length)));
      chainRoom.send(1, PartyMsg.add(_drafts(length)));

      final shuffled = List.generate(length, (i) => i + 1)..shuffle(random);
      final isTop = length == 1 || random.nextInt(4) == 0;
      final afterId = isTop ? 0 : shuffled.removeLast();
      final moved = shuffled.sublist(0, 1 + random.nextInt(shuffled.length));
      final revBefore = batchRoom.hostState.rev;

      batchRoom.send(1, PartyMsg.moveMany(moved, afterId));
      var chainAfterId = afterId;
      for (final id in moved) {
        chainRoom.send(1, PartyMsg.move(id, chainAfterId));
        chainAfterId = id;
      }

      final reason = 'round $round moving $moved after $afterId';
      expect(_ids(batchRoom.hostState), _ids(chainRoom.hostState), reason: reason);
      expect(batchRoom.hostState.rev - revBefore, lessThanOrEqualTo(1), reason: reason);
      expect(batchRoom.denied, isEmpty, reason: reason);
      batchRoom.expectConverged();
    }
  });

  test('the host moves only what the sender may edit', () {
    final room = _Room();
    room.join(2);
    room.send(1, PartyMsg.add([_yt('a'), _yt('b')]));
    room.send(2, PartyMsg.add([_yt('c'), _yt('d')]));
    room.send(1, PartyMsg.add([_yt('e')]));

    room.send(2, PartyMsg.moveMany([1, 3, 4], 0));
    expect(_ytIds(room.hostState), ['c', 'd', 'a', 'b', 'e']);
    expect(room.denied[2], isNull);

    final revBefore = room.hostState.rev;
    room.send(2, PartyMsg.moveMany([1, 2], 5));
    expect(room.denied[2]!.single.data['r'], PartyDenyReason.permission.index);
    expect(room.hostState.rev, revBefore);

    room.send(1, PartyMsg.perms(const PartyPermissions(edit: true)));
    room.send(2, PartyMsg.moveMany([1, 2], 5));
    expect(_ytIds(room.hostState), ['c', 'd', 'e', 'a', 'b']);
    room.expectConverged();
  });

  test('malformed batches are refused', () {
    final room = _Room();
    room.join(2);
    room.send(1, PartyMsg.add(_drafts(4)));
    final revBefore = room.hostState.rev;
    for (final (ids, afterId) in [
      (<int>[], 0),
      ([1, 2], 2),
      ([1], 99),
      ([98, 99], 0),
    ]) {
      room.denied.clear();
      room.send(1, PartyMsg.moveMany(ids, afterId));
      expect(room.denied[1]!.single.data['r'], PartyDenyReason.invalid.index, reason: 'moving $ids after $afterId');
    }
    expect(room.hostState.rev, revBefore);

    room.send(2, PartyMsg.movedMany([1], 0));
    expect(room.hostState.rev, revBefore);
    room.expectConverged();
  });

  test('the binder sends only entries the member may edit', () {
    final room = _Room();
    final guest = _Member(room, 2, room.join(2));
    room.send(1, PartyMsg.add([_yt('a'), _yt('b')]));
    room.send(2, PartyMsg.add([_yt('c'), _yt('d')]));
    room.send(1, PartyMsg.add([_yt('e')]));
    guest.mirrorState();

    expect(guest.binder.interceptMoveItems([0, 1], afterIndex: 4), true);
    expect(guest.outbox, isEmpty);
    expect(guest.deniedReasons, [PartyDenyReason.permission]);

    guest.deniedReasons.clear();
    expect(guest.binder.interceptMoveItems([0, 2, 3], afterIndex: 4), true);
    expect(guest.outbox.single.data['ids'], [3, 4]);
    guest.flush();
    expect(_ytIds(room.hostState), ['a', 'b', 'e', 'c', 'd']);
    expect(guest.deniedReasons, isEmpty);
    room.expectConverged();
  });

  test('large batches travel in one message within the guest frame limit', () {
    final room = _Room();
    final guest = _Member(room, 2, room.join(2));
    room.join(3);
    room.send(1, PartyMsg.add(_drafts(1000)));
    room.send(1, PartyMsg.perms(const PartyPermissions(edit: true)));
    guest.mirrorState();
    final before = _ids(room.hostState);
    final sortedIndices = List.generate(500, (i) => i * 2);
    final eventsBefore = room.events.length;

    expect(guest.binder.interceptMoveItems(sortedIndices, afterIndex: 999), true);
    expect(guest.outbox.length, 1);
    expect(guest.outbox.single.encode().length, lessThan(_guestMaxFrameBytes));
    guest.flush();

    expect(_ids(room.hostState), _reference(before, sortedIndices, 999));
    expect(room.events.skip(eventsBefore).map((e) => e.type), [PartyMsgType.movedMany]);
    expect(guest.deniedReasons, isEmpty);
    room.expectConverged();
  });

  test('batches past the guest frame limit are chained, the host never splits', () {
    final room = _Room();
    final guest = _Member(room, 2, room.join(2));
    room.send(1, PartyMsg.add(_drafts(PartyLimits.maxEntries)));
    room.send(1, PartyMsg.perms(const PartyPermissions(edit: true)));
    guest.mirrorState();
    final before = _ids(room.hostState);
    final sortedIndices = List.generate(2500, (i) => i + 400);

    expect(guest.binder.interceptMoveItems(sortedIndices, afterIndex: 10), true);
    expect(guest.outbox.length, 2);
    for (final command in guest.outbox) {
      expect(command.encode().length, lessThan(_guestMaxFrameBytes));
    }
    guest.flush();
    final expected = _reference(before, sortedIndices, 10);
    expect(_ids(room.hostState), expected);
    room.expectConverged();

    final host = _Member(room, 1, room.hostState)..mirrorState();
    final hostIndices = List.generate(PartyLimits.maxEntries - 1, (i) => i + 1);
    final eventsBefore = room.events.length;
    expect(host.binder.interceptMoveItems(hostIndices, afterIndex: -1), true);
    expect(host.outbox.length, 1);
    host.flush();
    expect(_ids(room.hostState), _reference(expected, hostIndices, -1));
    expect(room.events.skip(eventsBefore).map((e) => e.type), [PartyMsgType.movedMany]);
    room.expectConverged();
  });

  test('builds without the batched message drop it & recover through a snapshot', () {
    final unknown = Uint8List.fromList(utf8.encode(jsonEncode(['someFutureType', 3, <String, dynamic>{}])));
    expect(() => PartyMsg.decode(unknown), throwsFormatException);
    expect(PartyMsgType.moveMany.isCommand, true);
    expect(PartyMsgType.movedMany.isCommand, false);

    final room = _Room();
    room.legacyMembers.add(2);
    final legacy = room.join(2);
    room.join(3);
    room.send(1, PartyMsg.add(_drafts(6)));
    room.send(1, PartyMsg.moveMany([5, 6], 1));
    expect(_ids(legacy), [1, 2, 3, 4, 5, 6]);
    expect(room.needsSync, isEmpty);

    room.send(1, const PartyMsg.pause());
    expect(room.needsSync, {2});
    room.needsSync.clear();
    room.send(2, const PartyMsg.sync());
    expect(_ids(legacy), [1, 5, 6, 2, 3, 4]);
    room.expectConverged();
  });

  test('moves arriving while the player is busy are applied once after a reassign', () async {
    final room = _Room();
    final player = _FakePlayer();
    final guest = _Member(room, 2, room.join(2), player: player);
    guest.state.listener = guest.binder;
    room.send(1, PartyMsg.add(_drafts(30)));
    final busyAssign = Completer<void>();
    player.assignBlocker = busyAssign;
    await guest.binder.bind(listening: true);

    final reassigningIds = List.generate(20, (i) => 30 - i);
    room.send(1, PartyMsg.moveMany(reassigningIds, 0));
    room.send(1, PartyMsg.moveMany([5, 6], 0));
    room.send(1, PartyMsg.move(7, 0));
    busyAssign.complete();
    await pumpEventQueue();

    expect(player.queueYtIds, _ytIds(room.hostState));
    await guest.binder.unbind(restoreQueue: false);
  });
}
