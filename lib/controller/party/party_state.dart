import 'dart:collection';

import 'package:namida/controller/party/party_protocol.dart';

abstract class PartyStateListener {
  /// the whole queue got replaced (snapshot, new queue), fully loaded.
  void onQueueSet();
  void onEntriesAdded(int index, List<PartyEntry> entries);

  void onEntriesRemoved(List<int> ids);
  void onEntryMoved(int fromIndex, int toIndex);
  void onEntryMetaChanged(PartyEntry entry, {required bool fallbackChanged});
  void onAnchorChanged();
  void onMembersChanged();
  void onPermsChanged();
  void onChat(PartyChatMessage message);
  void onReaction(int n, String emoji);
}

/// the room state, identical on all members. mutated only through [apply], by events made by the host.
class PartyState {
  PartyStateListener? listener;

  int epoch = 0;
  int rev = 0;
  String roomName = '';
  PartyPermissions perms = const PartyPermissions();
  PartyAnchor anchor = PartyAnchor.empty;

  List<PartyEntry> get entries => _entries;
  Map<int, PartyMember> get members => _members;
  Iterable<PartyChatMessage> get chat => _chat;

  /// a chunked queue is still arriving.
  bool get isLoading => _loading;

  final _entries = <PartyEntry>[];
  final _members = <int, PartyMember>{};
  final _chat = ListQueue<PartyChatMessage>();

  final _indexById = <int, int>{};
  bool _indexDirty = false;
  bool _loading = false;

  int indexOfId(int id) {
    if (_indexDirty) {
      _indexById.clear();
      for (var i = 0; i < _entries.length; i++) {
        _indexById[_entries[i].id] = i;
      }
      _indexDirty = false;
    }
    return _indexById[id] ?? -1;
  }

  int get currentIndex => indexOfId(anchor.entryId);

  PartyEntry? get currentEntry {
    final index = currentIndex;
    return index < 0 ? null : _entries[index];
  }

  PartyEntry? entryById(int id) {
    final index = indexOfId(id);
    return index < 0 ? null : _entries[index];
  }

  int get maxEntryId {
    var max = 0;
    for (var i = 0; i < _entries.length; i++) {
      final id = _entries[i].id;
      if (id > max) max = id;
    }
    return max;
  }

  bool canControl(PartyMember member) => member.role.isPrivileged || perms.control;
  bool canAdd(PartyMember member) => member.role.isPrivileged || perms.add;
  bool canChat(PartyMember member) => member.role.isPrivileged || perms.chat;
  bool canSetQueue(PartyMember member) => member.role.isPrivileged;
  bool canEditEntry(PartyMember member, PartyEntry entry) => member.role.isPrivileged || perms.edit || (perms.add && entry.by == member.n);

  /// returns false when the event can't be applied (missed events, malformed), a fresh snapshot is needed.
  bool apply(PartyMsg event) {
    final type = event.type;
    final rev = event.rev;
    if (type == PartyMsgType.snapshot) {
      try {
        _applySnapshot(event);
        return true;
      } catch (_) {
        return false;
      }
    }
    if (rev == 0 && type == PartyMsgType.entriesChunk) {
      // -- chunk of a snapshot sent to us only
      try {
        _applyEvent(event);
        return true;
      } catch (_) {
        return false;
      }
    }
    if (rev != this.rev + 1) return false;
    try {
      _applyEvent(event);
    } catch (_) {
      return false;
    }
    this.rev = rev;
    return true;
  }

  void _applySnapshot(PartyMsg event) {
    final data = event.data;
    if ((data['ep'] as int) < epoch) return; // -- late snapshot of a previous host
    final members = (data['ms'] as List).map((e) => PartyMember.fromList(e as List)).toList();
    final entries = _parseEntries(data['e']);
    final chat = (data['c'] as List).map((e) => PartyChatMessage.fromList(e as List)).toList();

    epoch = data['ep'] as int;
    rev = event.rev;
    roomName = data['n'] as String;
    perms = PartyPermissions.fromBits(data['p'] as int);
    anchor = PartyAnchor.fromList(data['a'] as List);
    _members
      ..clear()
      ..addEntries(members.map((e) => MapEntry(e.n, e)));
    _chat
      ..clear()
      ..addAll(chat);
    _entries
      ..clear()
      ..addAll(entries);
    _indexDirty = true;
    _loading = data['m'] == true;

    final l = listener;
    if (l == null) return;
    l.onMembersChanged();
    l.onPermsChanged();
    if (!_loading) l.onQueueSet();
  }

  static List<PartyEntry> _parseEntries(dynamic list) {
    list as List;
    return List<PartyEntry>.generate(list.length, (i) => PartyEntry.fromList(list[i] as List), growable: false);
  }

  void _applyEvent(PartyMsg event) {
    final data = event.data;
    final l = listener;
    switch (event.type) {
      case PartyMsgType.anchor:
        anchor = PartyAnchor.fromList(data['a'] as List);
        l?.onAnchorChanged();

      case PartyMsgType.added:
        final entries = _parseEntries(data['e']);
        final index = (data['i'] as int).clamp(0, _entries.length);
        _entries.insertAll(index, entries);
        _indexDirty = true;
        if (!_loading) l?.onEntriesAdded(index, entries);

      case PartyMsgType.removed:
        final ids = (data['ids'] as List).cast<int>();
        final indices = <int>[];
        for (final id in ids) {
          final index = indexOfId(id);
          if (index >= 0) indices.add(index);
        }
        indices.sort((a, b) => b.compareTo(a));
        if (indices.length == 1) {
          _entries.removeAt(indices.first);
        } else if (indices.isNotEmpty) {
          final idsSet = ids.toSet();
          _entries.removeWhere((e) => idsSet.contains(e.id));
        }
        _indexDirty = true;
        final newAnchor = data['a'];
        if (newAnchor != null) anchor = PartyAnchor.fromList(newAnchor as List);
        if (indices.isNotEmpty) l?.onEntriesRemoved(ids);
        if (newAnchor != null) l?.onAnchorChanged();

      case PartyMsgType.moved:
        final from = indexOfId(data['id'] as int);
        if (from < 0) return;
        final to = (data['i'] as int).clamp(0, _entries.length - 1);
        if (from == to) return;
        _entries.insert(to, _entries.removeAt(from));
        _indexDirty = true;
        l?.onEntryMoved(from, to);

      case PartyMsgType.queueSet:
        final entries = _parseEntries(data['e']);
        anchor = PartyAnchor.fromList(data['a'] as List);
        _entries
          ..clear()
          ..addAll(entries);
        _indexDirty = true;
        _loading = data['m'] == true;
        if (!_loading) l?.onQueueSet();

      case PartyMsgType.entriesChunk:
        if (!_loading) return;
        _entries.addAll(_parseEntries(data['e']));
        _indexDirty = true;
        _loading = data['m'] == true;
        if (!_loading) l?.onQueueSet();

      case PartyMsgType.member:
        final member = PartyMember.fromList(data['m'] as List);
        _members[member.n] = member;
        l?.onMembersChanged();

      case PartyMsgType.memberGone:
        if (_members.remove(data['n'] as int) != null) l?.onMembersChanged();

      case PartyMsgType.permsChanged:
        perms = PartyPermissions.fromBits(data['p'] as int);
        l?.onPermsChanged();

      case PartyMsgType.chatted:
        final message = PartyChatMessage.fromList(data['c'] as List);
        _chat.addLast(message);
        if (_chat.length > PartyLimits.maxChatHistory) _chat.removeFirst();
        l?.onChat(message);

      case PartyMsgType.reacted:
        l?.onReaction(data['n'] as int, data['e'] as String);

      case PartyMsgType.fallback:
        final entry = entryById(data['id'] as int);
        if (entry == null) return;
        entry.fallbackYtId = data['yt'] as String;
        entry.fallbackApproximate = data['a'] == true;
        l?.onEntryMetaChanged(entry, fallbackChanged: true);

      case PartyMsgType.durationChanged:
        final entry = entryById(data['id'] as int);
        if (entry == null) return;
        entry.durationMS = data['d'] as int;
        l?.onEntryMetaChanged(entry, fallbackChanged: false);

      default:
        throw FormatException('not a state event: ${event.type}');
    }
  }
}
