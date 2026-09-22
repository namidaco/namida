import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:namida_party_relay/namida_party_relay.dart';

import 'package:namida/controller/party/party_connection.dart';
import 'package:namida/controller/party/party_controller.dart';
import 'package:namida/controller/party/party_host.dart';
import 'package:namida/controller/party/party_protocol.dart';
import 'package:namida/controller/party/party_state.dart';

/// the wiring [PartyController] does, without the player & app singletons.
class _Peer implements PartyConnectionListener, PartyHostDelegate {
  final String name;
  _Peer(this.name);

  late PartyConnection connection;
  final state = PartyState();
  PartyHost? host;
  int myN = 0;
  int hostN = 0;
  bool synced = false;
  String? fatal;
  final relayMembers = <int, String>{};
  final denied = <PartyMsg>[];
  final welcomed = Completer<void>();

  bool get isHost => myN != 0 && myN == hostN;

  Future<void> connect(int port, String code, {String? token}) {
    connection = PartyConnection(
      roomUri: Uri.parse('ws://127.0.0.1:$port/v1/room/$code'),
      partyVersion: kPartyVersion,
      name: name,
      deviceId: 'did-$name',
      listener: this,
      token: token,
    );
    connection.connect();
    return welcomed.future;
  }

  void send(PartyMsg cmd) {
    final h = host;
    if (h != null) return h.onCommand(myN, cmd);
    connection.sendData(PartyRoute.toHost, cmd.encode());
  }

  @override
  void onWelcome(PartyWelcome welcome) {
    myN = welcome.n;
    hostN = welcome.hostN;
    relayMembers
      ..clear()
      ..addAll(welcome.members);
    if (isHost) {
      synced = true;
      host ??= PartyHost.create(state: state, selfN: myN, selfName: name, roomName: 'room', listening: true, delegate: this);
    } else {
      connection.sendData(PartyRoute.toHost, PartyMsg.hello(listening: true).encode());
    }
    if (!welcomed.isCompleted) welcomed.complete();
  }

  @override
  void onData(int route, int senderN, Uint8List payload) {
    final msg = PartyMsg.decode(payload);
    if (route == PartyRoute.toHost) return host?.onCommand(senderN, msg);
    if (senderN != hostN || isHost) return;
    if (msg.type == PartyMsgType.denied) {
      denied.add(msg);
      return;
    }
    if (!synced && msg.type != PartyMsgType.snapshot && !state.isLoading) return;
    if (state.apply(msg)) {
      synced = true;
    } else if (synced) {
      synced = false;
      connection.sendData(PartyRoute.toHost, const PartyMsg.sync().encode());
    }
  }

  @override
  void onMemberJoined(int n, String name) {
    relayMembers[n] = name;
    host?.onMemberJoined(n, name);
  }

  @override
  void onMemberLeft(int n, String reason) {
    relayMembers.remove(n);
    host?.onMemberLeft(n);
  }

  @override
  void onHostChanged(int n, bool online) {
    final wasHost = isHost;
    hostN = n;
    if (isHost && !wasHost) {
      synced = true;
      host = PartyHost.takeOver(state: state, selfN: myN, connected: Map.of(relayMembers), delegate: this);
    }
  }

  @override
  void onFatal(String code, Map<String, dynamic> details) => fatal = code;

  @override
  void onStatus(PartyConnectionStatus status) {}
  @override
  void onOpts(PartyRoomOpts opts) {}
  @override
  void onJoinRequest(String requestId, String name, String deviceId) {}
  @override
  void onJoinRequestGone(String requestId) {}
  @override
  void onBans(List<PartyBan> bans) {}
  @override
  void onRelayError(String code) {}

  @override
  int nowMS() => connection.nowMS();
  @override
  void broadcast(PartyMsg event) => connection.sendData(PartyRoute.broadcast, event.encode());
  @override
  void sendTo(int n, PartyMsg event) {
    if (n != myN) connection.sendData(PartyRoute.toMember, event.encode(), n: n);
  }

  @override
  void relayKick(int n, {required bool ban}) => connection.kick(n, ban: ban);
  @override
  void relaySuccessors(List<int> ns) => connection.setSuccessors(ns);
  @override
  void resolveFallback(PartyEntry entry) {}
}

PartyEntry _yt(String id) => PartyEntry(id: 0, by: 0, ytId: id, fingerprint: null, title: 't$id', artist: 'a', album: '', durationMS: 200000);

Future<void> _until(FutureOr<bool> Function() test, {String? reason}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!await test()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out: ${reason ?? ''}');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late PartyRelayServer relay;

  setUp(() async {
    relay = await PartyRelayServer.start(
      address: '127.0.0.1',
      config: const PartyRelayConfig(
        hostGrace: Duration(milliseconds: 600),
        createLimit: 100000,
        joinLimit: 100000,
        listLimit: 100000,
        directoryRefreshInterval: Duration.zero,
      ),
    );
  });

  tearDown(() => relay.close());

  test('public rooms are listed with their now playing, unlisted ones are not', () async {
    final server = Uri(scheme: 'http', host: '127.0.0.1', port: relay.port);
    expect(await PartyController.supportsDirectory(server), true);

    final unlisted = relay.createRoom(name: 'hidden host', did: 'did-hidden', pv: kPartyVersion);
    final hiddenHost = _Peer('hidden host');
    await hiddenHost.connect(relay.port, unlisted.code, token: unlisted.token);
    hiddenHost.connection.sendSummary(name: 'hidden room', title: 'nope', artist: 'nope');

    final room = relay.createRoom(name: 'host', did: 'did-host', pv: kPartyVersion, public: true);
    final host = _Peer('host');
    await host.connect(relay.port, room.code, token: room.token);
    host.connection.sendSummary(name: 'my room', title: 'a song', artist: 'an artist');

    await _until(
      () async {
        final page = await PartyController.listRooms(server: server);
        return page != null && page.rooms.any((e) => e.code == room.code);
      },
      reason: 'public room shows up',
    );

    final page = (await PartyController.listRooms(server: server))!;
    expect(page.rooms.any((e) => e.code == unlisted.code), false);
    final listed = page.rooms.firstWhere((e) => e.code == room.code);
    expect(listed.name, 'my room');
    expect(listed.title, 'a song');
    expect(listed.artist, 'an artist');
    expect(listed.members, 1);
    expect(listed.partyVersion, kPartyVersion);
    expect(listed.hasPassword, false);
    expect(listed.ownerId.length, 8);

    host.connection.setOpts(isPublic: false);
    await _until(
      () async {
        final page = await PartyController.listRooms(server: server);
        return page != null && !page.rooms.any((e) => e.code == room.code);
      },
      reason: 'going unlisted removes it',
    );

    host.connection.dispose();
    host.host?.dispose();
    hiddenHost.connection.dispose();
    hiddenHost.host?.dispose();
  });

  test('join, sync, commands, permissions, kick & host takeover over a real relay', () async {
    final room = relay.createRoom(name: 'host', did: 'did-host', pv: kPartyVersion);
    final host = _Peer('host');
    await host.connect(relay.port, room.code, token: room.token);
    expect(host.isHost, true);

    host.send(PartyMsg.add(List.generate(1200, (i) => _yt('v$i'))));

    final guest = _Peer('guest');
    await guest.connect(relay.port, room.code);
    await _until(() => guest.synced && !guest.state.isLoading && guest.state.entries.length == 1200, reason: 'chunked snapshot');
    expect(guest.state.members.keys.toSet(), {host.myN, guest.myN});
    expect(guest.state.anchor.playing, true);

    guest.send(const PartyMsg.pause());
    await _until(() => guest.denied.isNotEmpty, reason: 'guest pause denied');
    expect(host.state.anchor.playing, true);

    guest.send(PartyMsg.add([_yt('fromGuest')]));
    await _until(() => host.state.entries.length == 1201 && guest.state.entries.length == 1201, reason: 'guest add');
    expect(guest.state.entries.last.by, guest.myN);

    host.send(PartyMsg.role(guest.myN, PartyRole.admin));
    await _until(() => guest.state.members[guest.myN]?.role == PartyRole.admin, reason: 'promotion');
    guest.send(const PartyMsg.pause());
    await _until(() => !host.state.anchor.playing && !guest.state.anchor.playing, reason: 'admin pause');
    expect(guest.state.rev, host.state.rev);

    final third = _Peer('third');
    await third.connect(relay.port, room.code);
    await _until(() => third.synced && third.state.entries.length == 1201, reason: 'third synced');
    guest.send(PartyMsg.kick(third.myN, ban: false));
    await _until(() => third.fatal == 'kicked', reason: 'admin kicks guest');
    await _until(() => !guest.state.members.containsKey(third.myN), reason: 'member gone');

    final clockSkew = (guest.connection.nowMS() - host.connection.nowMS()).abs();
    expect(clockSkew < 250, true, reason: 'relay clock offset, got $clockSkew');

    host.connection.dispose();
    host.host!.dispose();
    await _until(() => guest.isHost, reason: 'promotion after host grace');
    expect(guest.state.epoch, 2);
    expect(guest.state.entries.length, 1201);
    guest.send(const PartyMsg.play());
    expect(guest.state.anchor.playing, true);

    final late = _Peer('late');
    await late.connect(relay.port, room.code);
    await _until(() => late.synced && late.state.entries.length == 1201 && late.state.epoch == 2, reason: 'joins the new host');
    expect(late.state.members[guest.myN]?.role, PartyRole.host);

    guest.host!.dispose();
    guest.connection.dispose();
    late.connection.dispose();
  });
}
