import 'dart:async';

import 'package:namida/controller/party/party_protocol.dart';
import 'package:namida/controller/party/party_state.dart';

abstract class PartyHostDelegate {
  /// relay clock.
  int nowMS();
  void broadcast(PartyMsg event);

  /// [n] can be the host itself.
  void sendTo(int n, PartyMsg event);
  void relayKick(int n, {required bool ban});
  void relaySuccessors(List<int> ns);

  /// resolve a youtube replacement for a local entry, then call [PartyHost.setFallback].
  void resolveFallback(PartyEntry entry);
}

/// the room authority, only alive on the host device. validates member commands & turns them into events.
/// every mutation goes through [PartyState.apply] with the same event the members get, so states can't diverge.
class PartyHost {
  final PartyState state;
  final int selfN;
  final PartyHostDelegate _delegate;

  PartyHost._(this.state, this.selfN, this._delegate) : _nextEntryId = state.maxEntryId + 1;

  static const _advanceGraceMS = 600;
  static const _endedToleranceMS = 4000;

  int _nextEntryId;
  Timer? _advanceTimer;
  final _fallbackRequested = <int>{};
  final _lastReactionMS = <int, int>{};

  factory PartyHost.create({
    required PartyState state,
    required int selfN,
    required String selfName,
    required String roomName,
    required bool listening,
    required PartyHostDelegate delegate,
  }) {
    final snapshot = PartyMsg.snapshot(
      epoch: 1,
      roomName: roomName,
      members: [PartyMember(n: selfN, name: selfName, role: .host, listening: listening)],
      perms: const PartyPermissions(),
      anchor: PartyAnchor.empty,
      chat: const [],
      entries: const [],
      more: false,
    );
    state.apply(snapshot);
    return PartyHost._(state, selfN, delegate);
  }

  /// the relay promoted us. [connected] is who the relay says is still there.
  factory PartyHost.takeOver({
    required PartyState state,
    required int selfN,
    required Map<int, String> connected,
    required PartyHostDelegate delegate,
  }) {
    final members = <PartyMember>[];
    for (final e in connected.entries) {
      final old = state.members[e.key];
      final PartyRole role;
      if (e.key == selfN) {
        role = .host;
      } else if (old == null || old.role == PartyRole.guest) {
        role = .guest;
      } else {
        role = .admin;
      }
      members.add(PartyMember(n: e.key, name: e.value, role: role, listening: old?.listening ?? true));
    }
    final snapshot = PartyMsg.snapshot(
      epoch: state.epoch + 1,
      roomName: state.roomName,
      members: members,
      perms: state.perms,
      anchor: state.anchor,
      chat: state.chat.toList(),
      entries: state.entries.toList(),
      more: false,
    );
    state.apply(snapshot);
    final host = PartyHost._(state, selfN, delegate);
    host._broadcastSnapshot();
    host._scheduleAdvance();
    host._pushSuccessors();
    return host;
  }

  void dispose() {
    _advanceTimer?.cancel();
    _advanceTimer = null;
  }

  // ------------------------------------------------------------

  void onMemberJoined(int n, String name) {
    final existing = state.members[n];
    final member = PartyMember(
      n: n,
      name: name,
      role: existing?.role ?? .guest,
      listening: existing?.listening ?? true,
    );
    _emit(PartyMsg.member(member));
  }

  void onMemberLeft(int n) {
    if (!state.members.containsKey(n)) return;
    final wasAdmin = state.members[n]!.role == PartyRole.admin;
    _lastReactionMS.remove(n);
    _emit(PartyMsg.memberGone(n));
    if (wasAdmin) _pushSuccessors();
  }

  void setFallback(int entryId, String ytId, {required bool approximate}) {
    final entry = state.entryById(entryId);
    if (entry == null || !entry.isLocal || entry.fallbackYtId != null) return;
    _emit(PartyMsg.fallback(entryId, ytId, approximate: approximate));
  }

  void onCommand(int fromN, PartyMsg cmd) {
    final member = state.members[fromN];
    if (member == null || !cmd.type.isCommand) return;
    PartyDenyReason? denied;
    try {
      denied = _handle(member, cmd);
    } catch (_) {
      denied = .invalid;
    }
    if (denied != null) _delegate.sendTo(fromN, PartyMsg.denied(cmd.type, denied));
  }

  PartyDenyReason? _handle(PartyMember member, PartyMsg cmd) {
    final data = cmd.data;
    switch (cmd.type) {
      case PartyMsgType.hello:
        _setListening(member, data['l'] == true);
        _sendSnapshotTo(member.n);

      case PartyMsgType.sync:
        _sendSnapshotTo(member.n);

      case PartyMsgType.listening:
        _setListening(member, data['l'] == true);

      case PartyMsgType.play:
        if (!state.canControl(member)) return .permission;
        _setPlaying(true);

      case PartyMsgType.pause:
        if (!state.canControl(member)) return .permission;
        _setPlaying(false);

      case PartyMsgType.seek:
        if (!state.canControl(member)) return .permission;
        final entry = state.currentEntry;
        if (entry == null) return .invalid;
        var position = data['p'] as int;
        if (position < 0) position = 0;
        if (entry.durationMS > 0 && position > entry.durationMS) position = entry.durationMS;
        _setAnchor(entry.id, position, state.anchor.playing);

      case PartyMsgType.skip:
        if (!state.canControl(member)) return .permission;
        final entry = state.entryById(data['id'] as int);
        if (entry == null) return .invalid;
        _setAnchor(entry.id, 0, true);

      case PartyMsgType.next:
        if (!state.canControl(member)) return .permission;
        _skipBy(1);

      case PartyMsgType.previous:
        if (!state.canControl(member)) return .permission;
        _skipBy(-1);

      case PartyMsgType.add:
        return _add(member, data);

      case PartyMsgType.remove:
        return _remove(member, (data['ids'] as List).cast<int>());

      case PartyMsgType.move:
        return _move(member, data['id'] as int, data['a'] as int);

      case PartyMsgType.setQueue:
        return _setQueue(member, data);

      case PartyMsgType.chat:
        if (!state.canChat(member)) return .permission;
        var text = (data['t'] as String).trim();
        if (text.isEmpty) return .invalid;
        if (text.length > PartyLimits.maxChatLength) text = text.substring(0, PartyLimits.maxChatLength);
        _emit(PartyMsg.chatted(PartyChatMessage(n: member.n, name: member.name, text: text, atMS: _delegate.nowMS())));

      case PartyMsgType.react:
        if (!state.canChat(member)) return .permission;
        final emoji = (data['e'] as String).trim();
        if (emoji.isEmpty || emoji.length > PartyLimits.maxReactionLength) return .invalid;
        final now = _delegate.nowMS();
        final last = _lastReactionMS[member.n];
        if (last != null && now - last < PartyLimits.reactionCooldownMS) return null;
        _lastReactionMS[member.n] = now;
        _emit(PartyMsg.reacted(member.n, emoji));

      case PartyMsgType.ended:
        if (!member.listening) return null;
        _onEndedReport(data['id'] as int);

      case PartyMsgType.duration:
        final entry = state.entryById(data['id'] as int);
        final duration = data['d'] as int;
        if (entry == null || duration <= 0) return null;
        if (entry.durationMS > 0 && member.n != selfN) return null;
        if (entry.durationMS == duration) return null;
        _emit(PartyMsg.durationChanged(entry.id, duration));
        if (entry.id == state.anchor.entryId) _scheduleAdvance();

      case PartyMsgType.missing:
        for (final id in (data['ids'] as List).cast<int>()) {
          final entry = state.entryById(id);
          if (entry == null || !entry.isLocal || entry.fallbackYtId != null) continue;
          if (_fallbackRequested.add(id)) _delegate.resolveFallback(entry);
        }

      case PartyMsgType.kick:
        if (!member.role.isPrivileged) return .permission;
        final target = state.members[data['n'] as int];
        if (target == null || target.n == member.n) return .invalid;
        if (target.role == PartyRole.host) return .permission;
        if (target.role == PartyRole.admin && member.role != PartyRole.host) return .permission;
        _delegate.relayKick(target.n, ban: data['b'] == true);

      case PartyMsgType.role:
        if (member.role != PartyRole.host) return .permission;
        final target = state.members[data['n'] as int];
        final role = PartyRole.values[data['r'] as int];
        if (target == null || target.role == PartyRole.host || role == PartyRole.host) return .invalid;
        if (target.role == role) return null;
        _emit(PartyMsg.member(PartyMember(n: target.n, name: target.name, role: role, listening: target.listening)));
        _pushSuccessors();

      case PartyMsgType.perms:
        if (member.role != PartyRole.host) return .permission;
        _emit(PartyMsg.permsChanged(PartyPermissions.fromBits(data['p'] as int)));

      default:
        return .invalid;
    }
    return null;
  }

  // ------------------------------------------------------------

  void _setListening(PartyMember member, bool listening) {
    if (member.listening == listening) return;
    _emit(PartyMsg.member(PartyMember(n: member.n, name: member.name, role: member.role, listening: listening)));
  }

  void _setPlaying(bool playing) {
    final anchor = state.anchor;
    if (anchor.playing == playing || state.currentEntry == null) return;
    _setAnchor(anchor.entryId, anchor.positionAt(_delegate.nowMS()), playing);
  }

  void _skipBy(int offset) {
    final length = state.entries.length;
    if (length == 0) return;
    final current = state.currentIndex;
    final index = current < 0 ? 0 : (current + offset) % length;
    _setAnchor(state.entries[index].id, 0, true);
  }

  void _setAnchor(int entryId, int positionMS, bool playing) {
    _emit(PartyMsg.anchor(_anchorOf(entryId, positionMS, playing)));
    _scheduleAdvance();
  }

  PartyAnchor _anchorOf(int entryId, int positionMS, bool playing) {
    return PartyAnchor(entryId: entryId, positionMS: positionMS, atMS: _delegate.nowMS(), playing: playing);
  }

  void _scheduleAdvance() {
    _advanceTimer?.cancel();
    _advanceTimer = null;
    final anchor = state.anchor;
    if (!anchor.playing) return;
    final entry = state.currentEntry;
    if (entry == null || entry.durationMS <= 0) return;
    final remaining = entry.durationMS - anchor.positionAt(_delegate.nowMS());
    final delay = (remaining / anchor.speed).round() + _advanceGraceMS;
    final entryId = entry.id;
    _advanceTimer = Timer(Duration(milliseconds: delay < 0 ? 0 : delay), () => _autoAdvance(entryId));
  }

  void _onEndedReport(int entryId) {
    final anchor = state.anchor;
    if (!anchor.playing || anchor.entryId != entryId) return;
    final entry = state.currentEntry;
    if (entry == null) return;
    if (entry.durationMS > 0 && anchor.positionAt(_delegate.nowMS()) < entry.durationMS - _endedToleranceMS) return;
    _autoAdvance(entryId);
  }

  void _autoAdvance(int entryId) {
    if (state.anchor.entryId != entryId) return;
    _skipBy(1);
  }

  PartyDenyReason? _add(PartyMember member, Map<String, dynamic> data) {
    if (!state.canAdd(member)) return .permission;
    final raw = data['e'] as List;
    if (raw.isEmpty) return .invalid;
    if (!member.role.isPrivileged && raw.length > PartyLimits.maxEntriesPerGuestAdd) return .invalid;
    if (state.entries.length + raw.length > PartyLimits.maxEntries) return .queueFull;

    final entries = _parseDrafts(raw, member.n);
    final afterId = data['a'] as int?;
    final int index;
    if (afterId == null) {
      index = state.entries.length;
    } else if (afterId == 0) {
      index = 0;
    } else {
      final after = state.indexOfId(afterId == -1 ? state.anchor.entryId : afterId);
      index = after < 0 ? state.entries.length : after + 1;
    }

    final wasEmpty = state.entries.isEmpty;
    _emit(PartyMsg.added(entries, index));
    if (wasEmpty) {
      _setAnchor(entries.first.id, 0, true);
    } else {
      final playIndex = data['pi'] as int?;
      if (playIndex != null && playIndex >= 0 && playIndex < entries.length && state.canControl(member)) {
        _setAnchor(entries[playIndex].id, 0, true);
      }
    }
    return null;
  }

  List<PartyEntry> _parseDrafts(List raw, int by) {
    return List<PartyEntry>.generate(raw.length, (i) => PartyEntry.fromList(raw[i] as List, id: _nextEntryId++, by: by), growable: false);
  }

  PartyDenyReason? _remove(PartyMember member, List<int> ids) {
    final allowed = <int>{};
    for (final id in ids) {
      final entry = state.entryById(id);
      if (entry != null && state.canEditEntry(member, entry)) allowed.add(id);
    }
    if (allowed.isEmpty) return ids.isEmpty ? .invalid : .permission;

    PartyAnchor? newAnchor;
    final anchor = state.anchor;
    if (allowed.contains(anchor.entryId)) {
      final entries = state.entries;
      final length = entries.length;
      final current = state.currentIndex;
      PartyEntry? next;
      for (var i = 1; i < length; i++) {
        final candidate = entries[(current + i) % length];
        if (!allowed.contains(candidate.id)) {
          next = candidate;
          break;
        }
      }
      newAnchor = next == null ? PartyAnchor.empty : _anchorOf(next.id, 0, anchor.playing);
    }
    _emit(PartyMsg.removed(allowed.toList(growable: false), newAnchor));
    if (newAnchor != null) _scheduleAdvance();
    return null;
  }

  PartyDenyReason? _move(PartyMember member, int id, int afterId) {
    final entry = state.entryById(id);
    if (entry == null || id == afterId) return .invalid;
    if (!state.canEditEntry(member, entry)) return .permission;
    final from = state.indexOfId(id);
    final int to;
    if (afterId == 0) {
      to = 0;
    } else {
      final after = state.indexOfId(afterId);
      if (after < 0) return .invalid;
      to = after < from ? after + 1 : after;
    }
    if (to != from) _emit(PartyMsg.moved(id, to));
    return null;
  }

  PartyDenyReason? _setQueue(PartyMember member, Map<String, dynamic> data) {
    if (!state.canSetQueue(member)) return .permission;
    final raw = data['e'] as List;
    if (raw.length > PartyLimits.maxEntries) return .queueFull;
    final entries = _parseDrafts(raw, member.n);
    final PartyAnchor anchor;
    if (entries.isEmpty) {
      anchor = PartyAnchor.empty;
    } else {
      final index = (data['i'] as int).clamp(0, entries.length - 1);
      final position = data['p'] as int;
      anchor = _anchorOf(entries[index].id, position < 0 ? 0 : position, data['pl'] == true);
    }
    _fallbackRequested.clear();

    const chunk = PartyLimits.snapshotChunkSize;
    final firstEnd = entries.length < chunk ? entries.length : chunk;
    _emit(PartyMsg.queueSet(entries.sublist(0, firstEnd), anchor, more: firstEnd < entries.length));
    for (var start = firstEnd; start < entries.length; start += chunk) {
      final end = start + chunk < entries.length ? start + chunk : entries.length;
      _emit(PartyMsg.entriesChunk(entries.sublist(start, end), more: end < entries.length));
    }
    _scheduleAdvance();
    return null;
  }

  // ------------------------------------------------------------

  void _emit(PartyMsg event) {
    final withRev = event.withRev(state.rev + 1);
    if (!state.apply(withRev)) return;
    _delegate.broadcast(withRev);
  }

  void _pushSuccessors() {
    final admins = <int>[];
    for (final m in state.members.values) {
      if (m.role == PartyRole.admin) admins.add(m.n);
    }
    _delegate.relaySuccessors(admins);
  }

  void _sendSnapshotTo(int n) {
    if (n == selfN) return;
    _forEachSnapshotChunk((msg) => _delegate.sendTo(n, msg));
  }

  void _broadcastSnapshot() => _forEachSnapshotChunk(_delegate.broadcast);

  void _forEachSnapshotChunk(void Function(PartyMsg msg) send) {
    final entries = state.entries;
    const chunk = PartyLimits.snapshotChunkSize;
    final firstEnd = entries.length < chunk ? entries.length : chunk;
    final snapshot = PartyMsg.snapshot(
      epoch: state.epoch,
      roomName: state.roomName,
      members: state.members.values,
      perms: state.perms,
      anchor: state.anchor,
      chat: state.chat,
      entries: entries.sublist(0, firstEnd),
      more: firstEnd < entries.length,
    ).withRev(state.rev);
    send(snapshot);
    for (var start = firstEnd; start < entries.length; start += chunk) {
      final end = start + chunk < entries.length ? start + chunk : entries.length;
      send(PartyMsg.entriesChunk(entries.sublist(start, end), more: end < entries.length));
    }
  }
}
