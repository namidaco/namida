import 'package:flutter_test/flutter_test.dart';

import 'package:namida/controller/party/party_host.dart';
import 'package:namida/controller/party/party_protocol.dart';
import 'package:namida/controller/party/party_state.dart';

/// in-memory room: every message goes through encode/decode like on the wire.
class _Room implements PartyHostDelegate {
  int now = 1000;
  final hostState = PartyState();
  late PartyHost host;
  final members = <int, PartyState>{};
  final needsSync = <int>{};
  final denied = <int, List<PartyMsg>>{};
  final kicked = <int>[];
  final successors = <List<int>>[];
  final fallbackRequests = <int>[];
  List<String>? reactions;

  _Room() {
    host = PartyHost.create(state: hostState, selfN: 1, selfName: 'host', roomName: 'room', listening: true, delegate: this);
  }

  PartyState join(int n, {String? name}) {
    final state = PartyState();
    members[n] = state;
    host.onMemberJoined(n, name ?? 'm$n');
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
    if (decoded.type == PartyMsgType.reacted) reactions?.add(decoded.data['e'] as String);
    final state = n == 1 ? hostState : members[n];
    if (state == null) return;
    if (state.epoch == 0 && decoded.type != PartyMsgType.snapshot) return; // -- not synced yet, like the controller does
    if (!state.apply(decoded)) needsSync.add(n);
  }

  @override
  int nowMS() => now;

  @override
  void broadcast(PartyMsg event) {
    for (final n in members.keys.toList()) {
      _deliver(n, event);
    }
  }

  @override
  void sendTo(int n, PartyMsg event) => _deliver(n, event);

  @override
  void relayKick(int n, {required bool ban}) => kicked.add(n);

  @override
  void relaySuccessors(List<int> ns) => successors.add(ns);

  @override
  void resolveFallback(PartyEntry entry) => fallbackRequests.add(entry.id);

  void expectConverged() {
    expect(needsSync, isEmpty);
    for (final state in members.values) {
      expect(state.rev, hostState.rev);
      expect(state.entries.map((e) => e.id), hostState.entries.map((e) => e.id));
      expect(state.anchor.toList(), hostState.anchor.toList());
      expect(state.members.keys, hostState.members.keys);
      expect(state.perms.toBits(), hostState.perms.toBits());
    }
  }
}

PartyEntry _yt(String id, {int durationMS = 200000}) {
  return PartyEntry(id: 0, by: 0, ytId: id, fingerprint: null, title: 't$id', artist: 'a', album: '', durationMS: durationMS);
}

PartyEntry _local(int fingerprint) {
  return PartyEntry(id: 0, by: 0, ytId: null, fingerprint: fingerprint, title: 'l$fingerprint', artist: 'a', album: 'b', durationMS: 180000);
}

void main() {
  test('message roundtrip', () {
    final msg = PartyMsg.add([_yt('abc'), _local(42)], afterId: -1).withRev(7);
    final decoded = PartyMsg.decode(msg.encode());
    expect(decoded.type, PartyMsgType.add);
    expect(decoded.rev, 7);
    final entries = (decoded.data['e'] as List).map((e) => PartyEntry.fromList(e as List)).toList();
    expect(entries[0].ytId, 'abc');
    expect(entries[1].fingerprint, 42);
    expect(entries[1].isLocal, true);
  });

  test('entry without identity is rejected', () {
    expect(() => PartyEntry.fromList([0, 0, null, null, 't', 'a', 'b', 1, null]), throwsFormatException);
  });

  test('guests add by default, first add starts playback, ids are host assigned', () {
    final room = _Room();
    final guest = room.join(2);
    room.send(2, PartyMsg.add([_yt('a'), _yt('b')]));
    room.expectConverged();
    expect(guest.entries.map((e) => e.id), [1, 2]);
    expect(guest.entries.first.by, 2);
    expect(guest.anchor.playing, true);
    expect(guest.anchor.entryId, 1);
  });

  test('guest control denied without permission, allowed after perms change', () {
    final room = _Room();
    room.join(2);
    room.send(1, PartyMsg.add([_yt('a')]));
    room.send(2, const PartyMsg.pause());
    expect(room.denied[2]!.single.data['r'], PartyDenyReason.permission.index);
    expect(room.hostState.anchor.playing, true);

    room.send(2, PartyMsg.perms(const PartyPermissions(control: true)));
    expect(room.denied[2]!.length, 2);

    room.send(1, PartyMsg.perms(const PartyPermissions(control: true)));
    room.now += 5000;
    room.send(2, const PartyMsg.pause());
    room.expectConverged();
    expect(room.hostState.anchor.playing, false);
    expect(room.hostState.anchor.positionMS, 5000);
    room.now += 9000;
    expect(room.hostState.anchor.positionAt(room.now), 5000);
  });

  test('seek clamps to duration, skip/next/previous wrap', () {
    final room = _Room();
    room.send(1, PartyMsg.add([_yt('a', durationMS: 1000), _yt('b'), _yt('c')]));
    room.send(1, PartyMsg.seek(999999));
    expect(room.hostState.anchor.positionMS, 1000);
    room.send(1, const PartyMsg.previous());
    expect(room.hostState.currentIndex, 2);
    room.send(1, const PartyMsg.next());
    expect(room.hostState.currentIndex, 0);
    room.send(1, PartyMsg.skip(2));
    expect(room.hostState.currentIndex, 1);
    room.send(1, PartyMsg.skip(99));
    expect(room.denied[1]!.single.data['r'], PartyDenyReason.invalid.index);
  });

  test('add positions', () {
    final room = _Room();
    room.send(1, PartyMsg.add([_yt('a'), _yt('b')]));
    room.send(1, PartyMsg.add([_yt('c')], afterId: -1));
    room.send(1, PartyMsg.add([_yt('d')], afterId: 0));
    room.send(1, PartyMsg.add([_yt('e')], afterId: 2));
    room.send(1, PartyMsg.add([_yt('f')], afterId: 999));
    expect(room.hostState.entries.map((e) => e.ytId), ['d', 'a', 'c', 'b', 'e', 'f']);
  });

  test('add with playIndex plays it only when the sender can control', () {
    final room = _Room();
    final guest = room.join(2);
    room.send(1, PartyMsg.add([_yt('a'), _yt('b')]));
    room.send(1, PartyMsg.skip(2));

    // -- guest can add but not control, the queue grows & the anchor stays
    room.send(2, PartyMsg.add([_yt('c')], afterId: -1, playIndex: 0));
    expect(room.hostState.entries.map((e) => e.ytId), ['a', 'b', 'c']);
    expect(room.hostState.anchor.entryId, 2);

    room.send(1, PartyMsg.perms(const PartyPermissions(add: true, control: true)));
    room.send(2, PartyMsg.add([_yt('d'), _yt('e')], afterId: -1, playIndex: 1));
    expect(room.hostState.entries.map((e) => e.ytId), ['a', 'b', 'd', 'e', 'c']);
    expect(guest.currentEntry?.ytId, 'e');
    expect(guest.anchor.playing, true);
    room.expectConverged();
  });

  test('add with playIndex into an empty queue plays the first entry', () {
    final room = _Room();
    final guest = room.join(2);
    room.send(2, PartyMsg.add([_yt('a'), _yt('b')], afterId: -1, playIndex: 1));
    expect(guest.currentEntry?.ytId, 'a');
    expect(guest.anchor.playing, true);
    room.expectConverged();
  });

  test('move semantics', () {
    final room = _Room();
    final guest = room.join(2);
    room.send(1, PartyMsg.add([_yt('a'), _yt('b'), _yt('c'), _yt('d')]));
    room.send(1, PartyMsg.move(1, 3));
    expect(guest.entries.map((e) => e.ytId), ['b', 'c', 'a', 'd']);
    room.send(1, PartyMsg.move(4, 0));
    expect(guest.entries.map((e) => e.ytId), ['d', 'b', 'c', 'a']);
    room.send(1, PartyMsg.move(1, 4));
    expect(guest.entries.map((e) => e.ytId), ['d', 'a', 'b', 'c']);
    room.expectConverged();
  });

  test('guests edit only their own entries, removing current moves the anchor', () {
    final room = _Room();
    room.join(2);
    room.send(1, PartyMsg.add([_yt('a'), _yt('b')]));
    room.send(2, PartyMsg.add([_yt('c')]));
    room.send(2, PartyMsg.remove([1]));
    expect(room.denied[2]!.single.data['r'], PartyDenyReason.permission.index);
    room.send(2, PartyMsg.remove([3]));
    expect(room.hostState.entries.length, 2);

    room.send(1, PartyMsg.remove([1]));
    expect(room.hostState.anchor.entryId, 2);
    room.send(1, PartyMsg.remove([2]));
    expect(room.hostState.entries, isEmpty);
    expect(room.hostState.currentEntry, isNull);
    room.expectConverged();
  });

  test('missed event needs a sync, snapshot recovers', () {
    final room = _Room();
    final guest = room.join(2);
    room.send(1, PartyMsg.add([_yt('a')]));
    guest.rev -= 1;
    room.send(1, PartyMsg.add([_yt('b')]));
    expect(room.needsSync, {2});
    room.needsSync.clear();
    room.send(2, const PartyMsg.sync());
    room.expectConverged();
  });

  test('large queue is chunked for setQueue & snapshots', () {
    final room = _Room();
    final early = room.join(2);
    final entries = List.generate(1234, (i) => _yt('v$i'));
    room.send(1, PartyMsg.setQueue(entries, index: 700, positionMS: 1500, playing: false));
    expect(early.isLoading, false);
    expect(early.entries.length, 1234);
    expect(early.currentIndex, 700);
    final late = room.join(3);
    expect(late.entries.length, 1234);
    expect(late.anchor.positionMS, 1500);
    room.expectConverged();

    room.send(2, PartyMsg.setQueue([_yt('x')], index: 0, positionMS: 0, playing: true));
    expect(room.denied[2]!.single.data['r'], PartyDenyReason.permission.index);
  });

  test('roles, kick rules & successors', () {
    final room = _Room();
    room.join(2);
    room.join(3);
    room.send(2, PartyMsg.kick(3, ban: false));
    expect(room.kicked, isEmpty);
    room.send(1, PartyMsg.role(2, PartyRole.admin));
    expect(room.successors.last, [2]);
    room.send(2, PartyMsg.kick(3, ban: true));
    expect(room.kicked, [3]);
    room.send(2, PartyMsg.kick(1, ban: false));
    expect(room.kicked, [3]);
    room.send(2, PartyMsg.role(3, PartyRole.admin));
    expect(room.hostState.members[3]!.role, PartyRole.guest);
    room.host.onMemberLeft(3);
    room.members.remove(3);
    room.expectConverged();
  });

  test('reactions respect chat permission & a cooldown', () {
    final room = _Room();
    final guest = room.join(2);
    final seen = <String>[];
    room.reactions = seen;

    room.send(2, PartyMsg.react('🔥'));
    expect(seen, ['🔥']);

    // -- same member again right away is dropped, not denied
    room.send(2, PartyMsg.react('🎉'));
    expect(seen, ['🔥']);
    expect(room.denied[2], null);

    room.now += PartyLimits.reactionCooldownMS + 1;
    room.send(2, PartyMsg.react('🎉'));
    expect(seen, ['🔥', '🎉']);

    room.send(2, PartyMsg.react(''));
    expect(room.denied[2]!.single.data['r'], PartyDenyReason.invalid.index);

    room.send(1, PartyMsg.perms(const PartyPermissions(chat: false)));
    room.now += PartyLimits.reactionCooldownMS + 1;
    room.send(2, PartyMsg.react('🔥'));
    expect(seen.length, 2);
    expect(guest.rev, room.hostState.rev);
  });

  test('a search based fallback is flagged approximate & survives the wire', () {
    final room = _Room();
    final guest = room.join(2);
    room.send(1, PartyMsg.add([_local(9)]));
    room.send(2, PartyMsg.missing([1]));
    room.host.setFallback(1, 'guessed', approximate: true);
    expect(guest.entries.first.fallbackYtId, 'guessed');
    expect(guest.entries.first.fallbackApproximate, true);
    expect(PartyEntry.fromList(guest.entries.first.toList()).fallbackApproximate, true);
    room.expectConverged();
    room.host.dispose();
  });

  test('fallback requested once per local entry', () {
    final room = _Room();
    final guest = room.join(2);
    room.send(1, PartyMsg.add([_local(5), _yt('a')]));
    room.send(2, PartyMsg.missing([1, 2, 77]));
    room.send(2, PartyMsg.missing([1]));
    expect(room.fallbackRequests, [1]);
    room.host.setFallback(1, 'ytFallback', approximate: false);
    expect(guest.entries.first.fallbackYtId, 'ytFallback');
    room.expectConverged();
  });

  test('a preloaded youtube fallback skips the lookup', () {
    final room = _Room();
    room.join(2);
    final withFallback = _local(7)..fallbackYtId = 'alreadyKnown';
    room.send(1, PartyMsg.add([withFallback, _local(8)]));
    room.send(2, PartyMsg.missing([1, 2]));
    expect(room.fallbackRequests, [2]);
    expect(room.hostState.entries.first.fallbackYtId, 'alreadyKnown');
    room.host.dispose();
  });

  test('ended reports advance only near the end', () {
    final room = _Room();
    room.join(2);
    room.send(1, PartyMsg.add([_yt('a', durationMS: 100000), _yt('b', durationMS: 0)]));
    room.send(2, PartyMsg.ended(1));
    expect(room.hostState.currentIndex, 0);
    room.now += 97000;
    room.send(2, PartyMsg.ended(1));
    expect(room.hostState.currentIndex, 1);
    room.send(2, PartyMsg.duration(2, 5000));
    expect(room.hostState.entries[1].durationMS, 5000);
    room.expectConverged();
    room.host.dispose();
  });

  test('auto advance by timer', () async {
    final room = _Room();
    room.send(1, PartyMsg.add([_yt('a', durationMS: 50), _yt('b')]));
    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(room.hostState.currentIndex, 1);
    room.host.dispose();
  });

  test('take over keeps the queue, bumps epoch, old snapshots are ignored', () {
    final room = _Room();
    final guest = room.join(2);
    room.join(3);
    room.send(1, PartyMsg.role(3, PartyRole.admin));
    room.send(1, PartyMsg.add([_yt('a'), _yt('b')]));

    final takeover = _Room();
    takeover.members.clear();
    final newHost = PartyHost.takeOver(state: guest, selfN: 2, connected: {2: 'm2', 3: 'm3'}, delegate: takeover);
    expect(guest.epoch, 2);
    expect(guest.members[2]!.role, PartyRole.host);
    expect(guest.members[3]!.role, PartyRole.admin);
    expect(guest.members.containsKey(1), false);
    expect(guest.entries.length, 2);
    expect(takeover.successors.last, [3]);

    newHost.onCommand(2, PartyMsg.add([_yt('c')]));
    expect(guest.entries.last.id, 3);

    final stale = PartyMsg.snapshot(
      epoch: 1,
      roomName: 'old',
      members: const [],
      perms: const PartyPermissions(),
      anchor: PartyAnchor.empty,
      chat: const [],
      entries: const [],
      more: false,
    );
    expect(guest.apply(stale), true);
    expect(guest.entries.length, 3);
    newHost.dispose();
    room.host.dispose();
  });
}
