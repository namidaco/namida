import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// see `external/party_relay/PROTOCOL.md`.
abstract final class PartyRoute {
  static const toHost = 0;
  static const broadcast = 1;
  static const toMember = 2;
  static const headerSize = 5;
}

enum PartyConnectionStatus {
  connecting,
  pendingApproval,
  connected,
  reconnecting,
  closed,
}

class PartyRoomOpts {
  final bool approval;
  final bool hasPassword;
  final bool locked;
  final bool isPublic;

  const PartyRoomOpts({required this.approval, required this.hasPassword, required this.locked, required this.isPublic});

  factory PartyRoomOpts.fromMap(Map map) {
    return PartyRoomOpts(
      approval: map['approval'] == true,
      hasPassword: map['password'] == true,
      locked: map['locked'] == true,
      isPublic: map['public'] == true,
    );
  }
}

/// a room listed by `GET /v1/rooms`.
class PartyPublicRoom {
  final String code;
  final String name;
  final String ownerId;
  final int members;
  final int maxMembers;
  final int partyVersion;
  final bool approval;
  final bool hasPassword;
  final String? title;
  final String? artist;

  const PartyPublicRoom({
    required this.code,
    required this.name,
    required this.ownerId,
    required this.members,
    required this.maxMembers,
    required this.partyVersion,
    required this.approval,
    required this.hasPassword,
    required this.title,
    required this.artist,
  });

  bool get isFull => maxMembers > 0 && members >= maxMembers;

  static PartyPublicRoom? fromMap(Object? value) {
    if (value is! Map) return null;
    final code = value['code'];
    final name = value['name'];
    if (code is! String || name is! String) return null;
    return PartyPublicRoom(
      code: code,
      name: name,
      ownerId: value['hid'] as String? ?? '',
      members: value['members'] as int? ?? 0,
      maxMembers: value['max'] as int? ?? 0,
      partyVersion: value['pv'] as int? ?? 0,
      approval: value['approval'] == true,
      hasPassword: value['password'] == true,
      title: value['title'] as String?,
      artist: value['artist'] as String?,
    );
  }
}

class PartyRoomsPage {
  final List<PartyPublicRoom> rooms;
  final String? next;

  const PartyRoomsPage(this.rooms, this.next);
}

class PartyWelcome {
  final int n;
  final int hostN;
  final bool hostOnline;
  final int maxMembers;
  final PartyRoomOpts opts;

  /// connected members, `{n: name}`.
  final Map<int, String> members;

  const PartyWelcome({
    required this.n,
    required this.hostN,
    required this.hostOnline,
    required this.maxMembers,
    required this.opts,
    required this.members,
  });
}

class PartyBan {
  final String id;
  final String name;
  const PartyBan(this.id, this.name);
}

abstract class PartyConnectionListener {
  void onStatus(PartyConnectionStatus status);

  /// called on first join & after every successful reconnect.
  void onWelcome(PartyWelcome welcome);
  void onMemberJoined(int n, String name);
  void onMemberLeft(int n, String reason);
  void onHostChanged(int n, bool online);
  void onOpts(PartyRoomOpts opts);
  void onJoinRequest(String requestId, String name, String deviceId);
  void onJoinRequestGone(String requestId);
  void onBans(List<PartyBan> bans);
  void onData(int route, int senderN, Uint8List payload);

  /// non fatal relay error (`forbidden`, `rate_limited`, `too_large`..).
  void onRelayError(String code);

  /// the connection is over for good (kicked, room closed, wrong password, version mismatch..).
  void onFatal(String code, Map<String, dynamic> details);
}

class PartyConnection {
  final Uri roomUri;
  final int partyVersion;
  final String name;
  final String deviceId;
  final String? password;
  final PartyConnectionListener listener;

  PartyConnection({
    required this.roomUri,
    required this.partyVersion,
    required this.name,
    required this.deviceId,
    required this.listener,
    this._token,
    this.password,
  });

  static const _pingBurstCount = 5;
  static const _pingBurstInterval = Duration(milliseconds: 400);
  static const _pingInterval = Duration(seconds: 60);
  static const _maxClockSamples = 8;
  static const _maxReconnectDelaySeconds = 15;
  static const _maxReconnectAttempts = 12;

  String? get token => _token;
  PartyConnectionStatus get status => _status;

  String? _token;
  WebSocket? _ws;
  PartyConnectionStatus _status = .closed;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _pingsSent = 0;

  /// `(rtt, offset)` samples, the lowest rtt one is the most accurate.
  final _clockSamples = <(int, int)>[];
  int _clockOffsetMS = 0;

  /// relay clock.
  int nowMS() => DateTime.now().millisecondsSinceEpoch + _clockOffsetMS;

  Future<void> connect() => _open(isReconnect: false);

  Future<void> _open({required bool isReconnect}) async {
    if (_disposed) return;
    _setStatus(isReconnect ? .reconnecting : .connecting);
    try {
      final ws = await WebSocket.connect(roomUri.toString()).timeout(const Duration(seconds: 15));
      if (_disposed) {
        ws.close();
        return;
      }
      ws.pingInterval = const Duration(seconds: 25);
      _ws = ws;
      ws.listen(
        _onFrame,
        onDone: () => _onSocketClosed(ws),
        onError: (_) => _onSocketClosed(ws),
        cancelOnError: true,
      );
      _sendControl({
        't': 'join',
        'pv': partyVersion,
        'name': name,
        'did': deviceId,
        'token': _token,
        'password': password,
      });
    } on WebSocketException catch (e) {
      // -- a refused upgrade means the room is gone, no point retrying
      if (e.message.contains('404') || (e.httpStatusCode == 404)) {
        _fatal('not_found', const {});
      } else {
        _scheduleReconnect();
      }
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onSocketClosed(WebSocket ws) {
    if (_ws != ws) return;
    _ws = null;
    _pingTimer?.cancel();
    if (_disposed || _status == PartyConnectionStatus.closed) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (_token == null || _reconnectAttempt >= _maxReconnectAttempts) {
      // -- never got in (nothing to resume), or the relay is gone for good
      _fatal('unreachable', const {});
      return;
    }
    _setStatus(.reconnecting);
    final exp = _reconnectAttempt > 4 ? 4 : _reconnectAttempt;
    _reconnectAttempt++;
    final seconds = 1 << exp;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      Duration(seconds: seconds > _maxReconnectDelaySeconds ? _maxReconnectDelaySeconds : seconds),
      () => _open(isReconnect: true),
    );
  }

  void _fatal(String code, Map<String, dynamic> details) {
    if (_status == PartyConnectionStatus.closed && _disposed) return;
    _teardown();
    listener.onFatal(code, details);
  }

  void _teardown() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    final ws = _ws;
    _ws = null;
    ws?.close();
    _setStatus(.closed);
  }

  void _setStatus(PartyConnectionStatus status) {
    if (_status == status) return;
    _status = status;
    listener.onStatus(status);
  }

  // ------------------------------------------------------------

  void _onFrame(dynamic frame) {
    if (frame is String) {
      Map<String, dynamic> map;
      try {
        map = jsonDecode(frame) as Map<String, dynamic>;
      } catch (_) {
        return;
      }
      try {
        _onControl(map);
      } catch (_) {}
      return;
    }
    if (frame is! Uint8List || frame.length < PartyRoute.headerSize) return;
    final senderN = (frame[1] << 24) | (frame[2] << 16) | (frame[3] << 8) | frame[4];
    listener.onData(frame[0], senderN, Uint8List.sublistView(frame, PartyRoute.headerSize));
  }

  void _onControl(Map<String, dynamic> map) {
    switch (map['t']) {
      case 'welcome':
        _token = map['token'] as String;
        _reconnectAttempt = 0;
        final now = map['now'];
        if (now is int && _clockSamples.isEmpty) _clockOffsetMS = now - DateTime.now().millisecondsSinceEpoch;
        _setStatus(.connected);
        _startPinging();
        listener.onWelcome(
          PartyWelcome(
            n: map['n'] as int,
            hostN: map['host'] as int,
            hostOnline: map['hostOnline'] == true,
            maxMembers: map['max'] as int? ?? 0,
            opts: PartyRoomOpts.fromMap(map['opts'] as Map),
            members: {for (final m in map['members'] as List) (m as Map)['n'] as int: m['name'] as String},
          ),
        );
      case 'pending':
        _setStatus(.pendingApproval);
      case 'pong':
        _onPong(map['c'] as int, map['s'] as int);
      case 'joined':
        listener.onMemberJoined(map['n'] as int, map['name'] as String);
      case 'left':
        listener.onMemberLeft(map['n'] as int, map['r'] as String? ?? '');
      case 'host':
        listener.onHostChanged(map['n'] as int, map['online'] == true);
      case 'opts':
        listener.onOpts(PartyRoomOpts.fromMap(map));
      case 'joinreq':
        listener.onJoinRequest(map['r'] as String, map['name'] as String? ?? '', map['did'] as String? ?? '');
      case 'joinreqgone':
        listener.onJoinRequestGone(map['r'] as String);
      case 'bans':
        listener.onBans([for (final b in map['list'] as List) PartyBan((b as Map)['id'] as String, b['name'] as String? ?? '')]);
      case 'closed':
        _fatal('closed', map);
      case 'error':
        final code = map['code'] as String? ?? 'unknown';
        if (map['fatal'] == true) {
          _fatal(code, map);
        } else {
          listener.onRelayError(code);
        }
    }
  }

  // ------------------------------------------------------------

  void _startPinging() {
    _pingTimer?.cancel();
    _pingsSent = 0;
    void ping() {
      _sendControl({'t': 'ping', 'c': DateTime.now().millisecondsSinceEpoch});
      _pingsSent++;
      _pingTimer = Timer(_pingsSent < _pingBurstCount ? _pingBurstInterval : _pingInterval, ping);
    }

    ping();
  }

  void _onPong(int clientSentMS, int serverMS) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rtt = now - clientSentMS;
    if (rtt < 0) return;
    final offset = serverMS - (clientSentMS + rtt ~/ 2);
    _clockSamples.add((rtt, offset));
    if (_clockSamples.length > _maxClockSamples) _clockSamples.removeAt(0);
    var best = _clockSamples.first;
    for (final s in _clockSamples) {
      if (s.$1 < best.$1) best = s;
    }
    _clockOffsetMS = best.$2;
  }

  // ------------------------------------------------------------

  void _sendControl(Map<String, dynamic> map) {
    try {
      _ws?.add(jsonEncode(map));
    } catch (_) {}
  }

  /// returns false when not connected.
  bool sendData(int route, Uint8List payload, {int n = 0}) {
    final ws = _ws;
    if (ws == null || _status != PartyConnectionStatus.connected) return false;
    final frame = Uint8List(PartyRoute.headerSize + payload.length)
      ..[0] = route
      ..[1] = (n >> 24) & 0xFF
      ..[2] = (n >> 16) & 0xFF
      ..[3] = (n >> 8) & 0xFF
      ..[4] = n & 0xFF
      ..setRange(PartyRoute.headerSize, PartyRoute.headerSize + payload.length, payload);
    try {
      ws.add(frame);
      return true;
    } catch (_) {
      return false;
    }
  }

  void kick(int n, {required bool ban}) => _sendControl({'t': 'kick', 'n': n, 'ban': ban});
  void unban(String banId) => _sendControl({'t': 'unban', 'id': banId});
  void approve(String requestId, bool ok) => _sendControl({'t': 'approve', 'r': requestId, 'ok': ok});
  void transferHost(int n) => _sendControl({'t': 'transfer', 'n': n});
  void setSuccessors(List<int> ns) => _sendControl({'t': 'successors', 'ns': ns});

  /// only non null fields are updated, [clearPassword] removes it.
  void setOpts({bool? approval, bool? locked, bool? isPublic, String? password, bool clearPassword = false}) {
    _sendControl({
      't': 'opts',
      'approval': ?approval,
      'locked': ?locked,
      'public': ?isPublic,
      if (clearPassword) 'password': null else 'password': ?password,
    });
  }

  void closeRoom() => _sendControl({'t': 'close'});

  /// what the directory shows for this room, host only.
  void sendSummary({required String name, String? title, String? artist}) {
    _sendControl({'t': 'summary', 'name': name, 'title': title ?? '', 'artist': artist ?? ''});
  }

  Future<void> leave() async {
    _sendControl({'t': 'leave'});
    _teardown();
  }

  void dispose() => _teardown();
}
