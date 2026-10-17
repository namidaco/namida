part of 'screenshots_driver.dart';

// by claude
/// a lan party hosted by this device, guests join it over loopback through the real relay protocol. nothing leaves the
/// device, the room only lives for one scene.
class _ScreenshotsParty {
  final _guests = <String, _ScreenshotsPartyGuest>{};
  String? _roomCode;

  static const _kWaitTimeoutMS = 10000;
  static const _kWaitPollMS = 50;

  Future<void> host(Map<String, dynamic> step, Track? Function(String? title) findTrack) async {
    final party = PartyController.inst;
    final roomName = step['room'] as String? ?? '';
    final error = await party.createLanRoom(roomName: roomName, listening: true);
    if (error != null) throw StateError('party room failed: $error');
    await _waitFor(() => party.isHost && party.status.value == PartyConnectionStatus.connected, 'host');
    _roomCode = party.code;

    final roomUri = party.server!.replace(scheme: 'ws', path: '/v1/room/${party.code}');
    final guests = (step['guests'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    for (final guest in guests) {
      final name = guest['name'] as String;
      final partyGuest = _ScreenshotsPartyGuest(roomUri, name, 'screenshots-guest-${_guests.length}');
      _guests[name] = partyGuest;
      await partyGuest.connection.connect();
      final n = await partyGuest.memberN.timeout(const Duration(milliseconds: _kWaitTimeoutMS));
      final isListening = guest['listening'] as bool? ?? true;
      partyGuest.send(PartyMsg.hello(listening: isListening));
      await _waitFor(() => party.state.members.containsKey(n), 'guest $name');
      final isAdmin = guest['admin'] as bool? ?? false;
      if (isAdmin) party.setRole(n, PartyRole.admin);
    }

    final adds = (step['add'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    for (final add in adds) {
      final track = findTrack(add['track'] as String?);
      if (track == null) throw ArgumentError.value(add['track'], 'track', 'not in the library');
      final entriesCount = party.state.entries.length;
      _guests[add['from'] as String]!.send(PartyMsg.add([PartyPlayerBinder.entryOf(track)], afterId: -1));
      await _waitFor(() => party.state.entries.length > entriesCount, 'add ${track.title}');
    }

    final skips = step['skip'] as int? ?? 0;
    for (var i = 0; i < skips; i++) {
      final historyCount = party.playedHistory.length;
      party.sendCommand(const PartyMsg.next());
      await _waitFor(() => party.playedHistory.length > historyCount, 'skip');
    }

    final messages = (step['chat'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    for (final message in messages) {
      final text = message['text'] as String;
      final from = message['from'] as String?;
      final chatCount = party.state.chat.length;
      if (from == null) {
        party.sendChat(text);
      } else {
        _guests[from]!.send(PartyMsg.chat(text));
      }
      await _waitFor(() => party.state.chat.length > chatCount, 'chat');
    }
  }

  Future<void> react(Map<String, dynamic> step) async {
    final party = PartyController.inst;
    final reactionsCount = party.reactionTick.value;
    _guests[step['from'] as String]!.send(PartyMsg.react(step['emoji'] as String));
    await _waitFor(() => party.reactionTick.value > reactionsCount, 'reaction');
  }

  Future<void> leave() async {
    final code = _roomCode;
    if (code == null) return;
    for (final guest in _guests.values) {
      await guest.connection.leave();
    }
    _guests.clear();
    await PartyController.inst.leave();
    settings.party.recentRooms.update((stored) => stored.removeWhere((e) => e['c'] == code));
    _roomCode = null;
  }

  static Future<void> _waitFor(bool Function() isDone, String what) async {
    var waitedMS = 0;
    while (!isDone()) {
      if (waitedMS >= _kWaitTimeoutMS) throw TimeoutException('party $what timed out');
      await Future.delayed(const Duration(milliseconds: _kWaitPollMS));
      waitedMS += _kWaitPollMS;
    }
  }
}

class _ScreenshotsPartyGuest implements PartyConnectionListener {
  late final connection = PartyConnection(roomUri: _roomUri, partyVersion: kPartyVersion, name: _name, deviceId: _deviceId, listener: this);
  final Uri _roomUri;
  final String _name;
  final String _deviceId;
  final _welcomeCompleter = Completer<int>();

  _ScreenshotsPartyGuest(this._roomUri, this._name, this._deviceId);

  Future<int> get memberN => _welcomeCompleter.future;

  void send(PartyMsg message) => connection.sendData(PartyRoute.toHost, message.encode());

  @override
  void onWelcome(PartyWelcome welcome) => _welcomeCompleter.completeIfWasnt(welcome.n);

  @override
  void onStatus(PartyConnectionStatus status) {}

  @override
  void onMemberJoined(int n, String name) {}

  @override
  void onMemberLeft(int n, String reason) {}

  @override
  void onHostChanged(int n, bool online) {}

  @override
  void onOpts(PartyRoomOpts opts) {}

  @override
  void onJoinRequest(String requestId, String name, String deviceId) {}

  @override
  void onJoinRequestGone(String requestId) {}

  @override
  void onBans(List<PartyBan> bans) {}

  @override
  void onData(int route, int senderN, Uint8List payload) {}

  @override
  void onRelayError(String code) {}

  @override
  void onFatal(String code, Map<String, dynamic> details) {}
}
