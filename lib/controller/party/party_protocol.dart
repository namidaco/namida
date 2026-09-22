import 'dart:convert';
import 'dart:typed_data';

/// bump on breaking changes of the data payloads, the relay rejects joins with a different version.
const kPartyVersion = 1;

abstract final class PartyLimits {
  static const maxEntries = 3000;
  static const maxEntriesPerGuestAdd = 50;
  static const maxTextLength = 120;
  static const maxChatLength = 500;
  static const maxChatHistory = 200;
  static const maxReactionLength = 8;
  static const reactionCooldownMS = 1500;
  static const snapshotChunkSize = 500;
}

enum PartyRole {
  host,
  admin,
  guest;

  bool get isPrivileged => this != guest;
}

/// what guests can do. admins & the host can always do everything.
class PartyPermissions {
  final bool control;
  final bool add;
  final bool edit;
  final bool chat;

  const PartyPermissions({
    this.control = false,
    this.add = true,
    this.edit = false,
    this.chat = true,
  });

  factory PartyPermissions.fromBits(int bits) {
    return PartyPermissions(
      control: bits & 1 != 0,
      add: bits & 2 != 0,
      edit: bits & 4 != 0,
      chat: bits & 8 != 0,
    );
  }

  int toBits() => (control ? 1 : 0) | (add ? 2 : 0) | (edit ? 4 : 0) | (chat ? 8 : 0);

  PartyPermissions copyWith({bool? control, bool? add, bool? edit, bool? chat}) {
    return PartyPermissions(
      control: control ?? this.control,
      add: add ?? this.add,
      edit: edit ?? this.edit,
      chat: chat ?? this.chat,
    );
  }
}

class PartyMember {
  final int n;
  String name;
  PartyRole role;

  /// false for remote-control members, they render the state without playing it.
  bool listening;

  PartyMember({
    required this.n,
    required this.name,
    required this.role,
    required this.listening,
  });

  factory PartyMember.fromList(List list) {
    return PartyMember(
      n: list[0] as int,
      name: list[1] as String,
      role: PartyRole.values[list[2] as int],
      listening: list[3] == 1,
    );
  }

  List<Object> toList() => [n, name, role.index, listening ? 1 : 0];
}

class PartyEntry {
  final int id;

  /// member number who added it.
  final int by;

  /// non null for youtube items.
  final String? ytId;

  /// non null for local tracks, title + artist + album + duration hash.
  final int? fingerprint;

  final String title;
  final String artist;
  final String album;

  int durationMS;

  /// youtube replacement for members who don't have the local track.
  String? fallbackYtId;

  /// the replacement came from a search, not from a link the track already carried.
  bool fallbackApproximate;

  PartyEntry({
    required this.id,
    required this.by,
    required this.ytId,
    required this.fingerprint,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMS,
    this.fallbackYtId,
    this.fallbackApproximate = false,
  });

  bool get isLocal => ytId == null;

  static String _text(dynamic value) {
    if (value is! String) return '';
    return value.length > PartyLimits.maxTextLength ? value.substring(0, PartyLimits.maxTextLength) : value;
  }

  static String? _ytIdOrNull(dynamic value) {
    if (value is! String || value.isEmpty || value.length > 16) return null;
    return value;
  }

  /// throws on malformed input. [id] & [by] override what the list carries, the host never trusts them from members.
  factory PartyEntry.fromList(List list, {int? id, int? by}) {
    final ytId = _ytIdOrNull(list[2]);
    final fingerprint = list[3] as int?;
    if (ytId == null && fingerprint == null) throw const FormatException('entry without identity');
    final durationMS = list[7] as int;
    return PartyEntry(
      id: id ?? list[0] as int,
      by: by ?? list[1] as int,
      ytId: ytId,
      fingerprint: ytId == null ? fingerprint : null,
      title: _text(list[4]),
      artist: _text(list[5]),
      album: _text(list[6]),
      durationMS: durationMS < 0 ? 0 : durationMS,
      fallbackYtId: _ytIdOrNull(list[8]),
      fallbackApproximate: list.length > 9 && list[9] == 1,
    );
  }

  List<Object?> toList() => [id, by, ytId, fingerprint, title, artist, album, durationMS, fallbackYtId, fallbackApproximate ? 1 : 0];
}

class PartyAnchor {
  final int entryId;
  final int positionMS;

  /// relay clock time at which [positionMS] was true.
  final int atMS;
  final bool playing;
  final double speed;

  const PartyAnchor({
    required this.entryId,
    required this.positionMS,
    required this.atMS,
    required this.playing,
    this.speed = 1.0,
  });

  static const empty = PartyAnchor(entryId: 0, positionMS: 0, atMS: 0, playing: false);

  factory PartyAnchor.fromList(List list) {
    return PartyAnchor(
      entryId: list[0] as int,
      positionMS: list[1] as int,
      atMS: list[2] as int,
      playing: list[3] == 1,
      speed: (list[4] as num).toDouble(),
    );
  }

  List<Object> toList() => [entryId, positionMS, atMS, playing ? 1 : 0, speed];

  int positionAt(int nowMS) {
    if (!playing) return positionMS;
    final elapsed = nowMS - atMS;
    if (elapsed <= 0) return positionMS;
    return positionMS + (elapsed * speed).round();
  }
}

class PartyChatMessage {
  final int n;
  final String name;
  final String text;
  final int atMS;

  const PartyChatMessage({
    required this.n,
    required this.name,
    required this.text,
    required this.atMS,
  });

  factory PartyChatMessage.fromList(List list) {
    return PartyChatMessage(
      n: list[0] as int,
      name: list[1] as String,
      text: list[2] as String,
      atMS: list[3] as int,
    );
  }

  List<Object> toList() => [n, name, text, atMS];
}

/// how close this device is to the party timeline.
enum PartySyncState {
  idle,
  inSync,
  catchingUp,
  pausedLocally,
  unavailable,
}

enum PartyDenyReason {
  permission,
  invalid,
  queueFull,
}

enum PartyMsgType {
  // ---- commands, member -> host
  hello,
  sync,
  play,
  pause,
  seek,
  skip,
  next,
  previous,
  add,
  remove,
  move,
  setQueue,
  chat,
  ended,
  duration,
  missing,
  listening,
  react,
  kick,
  role,
  perms,

  // ---- events, host -> members
  snapshot,
  entriesChunk,
  anchor,
  added,
  removed,
  moved,
  queueSet,
  member,
  memberGone,
  permsChanged,
  chatted,
  reacted,
  fallback,
  durationChanged,
  denied;

  static final lookupMap = {for (final e in values) e.name: e};

  bool get isCommand => index <= perms.index;
}

/// wire format: utf8 json `[type, rev, payload]`. rev is 0 for commands & for events sent to a single member.
class PartyMsg {
  final PartyMsgType type;
  final int rev;
  final Map<String, dynamic> data;

  const PartyMsg(this.type, this.data, {this.rev = 0});

  static const _empty = <String, dynamic>{};

  static final _encoder = JsonUtf8Encoder();
  static final _decoder = const Utf8Decoder().fuse(const JsonDecoder());

  Uint8List encode() {
    final bytes = _encoder.convert([type.name, rev, data]);
    return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  }

  /// throws on malformed input.
  static PartyMsg decode(Uint8List bytes) {
    final list = _decoder.convert(bytes) as List;
    final type = PartyMsgType.lookupMap[list[0]];
    if (type == null) throw FormatException('unknown party message: ${list[0]}');
    return PartyMsg(type, list[2] as Map<String, dynamic>, rev: list[1] as int);
  }

  PartyMsg withRev(int rev) => PartyMsg(type, data, rev: rev);

  // ---- commands

  factory PartyMsg.hello({required bool listening}) => PartyMsg(.hello, {'l': listening});
  const PartyMsg.sync() : this(.sync, _empty);
  const PartyMsg.play() : this(.play, _empty);
  const PartyMsg.pause() : this(.pause, _empty);
  factory PartyMsg.seek(int positionMS) => PartyMsg(.seek, {'p': positionMS});
  factory PartyMsg.skip(int entryId) => PartyMsg(.skip, {'id': entryId});
  const PartyMsg.next() : this(.next, _empty);
  const PartyMsg.previous() : this(.previous, _empty);

  /// [afterId]: null appends, 0 inserts at the start, -1 inserts after the current entry.
  /// [playIndex] asks to play that entry of this batch, honored only if the sender can control.
  factory PartyMsg.add(List<PartyEntry> entries, {int? afterId, int? playIndex}) => PartyMsg(.add, {'e': _entriesToList(entries), 'a': ?afterId, 'pi': ?playIndex});
  factory PartyMsg.remove(List<int> ids) => PartyMsg(.remove, {'ids': ids});

  /// [afterId]: 0 moves to the start.
  factory PartyMsg.move(int id, int afterId) => PartyMsg(.move, {'id': id, 'a': afterId});
  factory PartyMsg.setQueue(List<PartyEntry> entries, {required int index, required int positionMS, required bool playing}) {
    return PartyMsg(.setQueue, {'e': _entriesToList(entries), 'i': index, 'p': positionMS, 'pl': playing});
  }

  factory PartyMsg.chat(String text) => PartyMsg(.chat, {'t': text});
  factory PartyMsg.react(String emoji) => PartyMsg(.react, {'e': emoji});
  factory PartyMsg.ended(int entryId) => PartyMsg(.ended, {'id': entryId});
  factory PartyMsg.duration(int entryId, int durationMS) => PartyMsg(.duration, {'id': entryId, 'd': durationMS});
  factory PartyMsg.missing(List<int> ids) => PartyMsg(.missing, {'ids': ids});
  factory PartyMsg.listening(bool listening) => PartyMsg(.listening, {'l': listening});
  factory PartyMsg.kick(int n, {required bool ban}) => PartyMsg(.kick, {'n': n, 'b': ban});
  factory PartyMsg.role(int n, PartyRole role) => PartyMsg(.role, {'n': n, 'r': role.index});
  factory PartyMsg.perms(PartyPermissions perms) => PartyMsg(.perms, {'p': perms.toBits()});

  // ---- events

  factory PartyMsg.snapshot({
    required int epoch,
    required String roomName,
    required Iterable<PartyMember> members,
    required PartyPermissions perms,
    required PartyAnchor anchor,
    required Iterable<PartyChatMessage> chat,
    required List<PartyEntry> entries,
    required bool more,
  }) {
    return PartyMsg(.snapshot, {
      'ep': epoch,
      'n': roomName,
      'ms': members.map((e) => e.toList()).toList(growable: false),
      'p': perms.toBits(),
      'a': anchor.toList(),
      'c': chat.map((e) => e.toList()).toList(growable: false),
      'e': _entriesToList(entries),
      'm': more,
    });
  }

  factory PartyMsg.anchor(PartyAnchor anchor) => PartyMsg(.anchor, {'a': anchor.toList()});
  factory PartyMsg.added(List<PartyEntry> entries, int index) => PartyMsg(.added, {'e': _entriesToList(entries), 'i': index});
  factory PartyMsg.removed(List<int> ids, PartyAnchor? anchor) => PartyMsg(.removed, {'ids': ids, 'a': ?anchor?.toList()});
  factory PartyMsg.moved(int id, int toIndex) => PartyMsg(.moved, {'id': id, 'i': toIndex});
  factory PartyMsg.queueSet(List<PartyEntry> entries, PartyAnchor anchor, {required bool more}) {
    return PartyMsg(.queueSet, {'e': _entriesToList(entries), 'a': anchor.toList(), 'm': more});
  }

  factory PartyMsg.entriesChunk(List<PartyEntry> entries, {required bool more}) => PartyMsg(.entriesChunk, {'e': _entriesToList(entries), 'm': more});
  factory PartyMsg.member(PartyMember member) => PartyMsg(.member, {'m': member.toList()});
  factory PartyMsg.memberGone(int n) => PartyMsg(.memberGone, {'n': n});
  factory PartyMsg.permsChanged(PartyPermissions perms) => PartyMsg(.permsChanged, {'p': perms.toBits()});
  factory PartyMsg.chatted(PartyChatMessage message) => PartyMsg(.chatted, {'c': message.toList()});
  factory PartyMsg.reacted(int n, String emoji) => PartyMsg(.reacted, {'n': n, 'e': emoji});
  factory PartyMsg.fallback(int entryId, String ytId, {required bool approximate}) => PartyMsg(.fallback, {'id': entryId, 'yt': ytId, 'a': approximate});
  factory PartyMsg.durationChanged(int entryId, int durationMS) => PartyMsg(.durationChanged, {'id': entryId, 'd': durationMS});
  factory PartyMsg.denied(PartyMsgType command, PartyDenyReason reason) => PartyMsg(.denied, {'c': command.name, 'r': reason.index});

  static List<List<Object?>> _entriesToList(List<PartyEntry> entries) {
    return List<List<Object?>>.generate(entries.length, (i) => entries[i].toList(), growable: false);
  }
}
