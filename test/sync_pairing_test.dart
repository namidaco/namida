// by claude
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/base/settings_file_writer.dart';
import 'package:namida/class/lang.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/translations/language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late String ourId;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('namida_sync_pairing_test');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
    await settings.sync.prepareSettingsFile();
    // -- prompts & snackbars need a language, our device id needs the host's device info plugin
    Language.inst.update(language: NamidaLanguage.fromCode('en'));
    if (Platform.isWindows) DeviceInfoPlusWindowsPlugin.registerWith();
    if (Platform.isLinux) DeviceInfoPlusLinuxPlugin.registerWith();
    ourId = await SyncUtils.currentDeviceId;
  });
  tearDownAll(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {} // -- a debounced settings write can still hold the file
  });

  const serverId = 'server-device';
  const clientId = 'client-device';
  final sharedSecret = Uint8List.fromList(List.generate(32, (i) => i));
  final otherSecret = Uint8List.fromList(List.generate(32, (i) => 255 - i));

  /// the addresses of a device the test plays, both ends of a [_FakeSocket] are on loopback.
  final ownAddresses = [InternetAddress.loopbackIPv4.rawAddress];

  /// the test's side of a connection with [_FakeSocket]'s ports, the other end at [peerAddress].
  newHandshake({InternetAddress? peerAddress}) {
    final address = peerAddress ?? InternetAddress.loopbackIPv4;
    return debugCreateHandshake(peerAddress: address, clientPort: _kClientPort, serverPort: _kServerPort);
  }

  ConnectionRequestMessage viaCodec(ConnectionRequestMessage msg) {
    final bytes = msg.encodeBytes();
    return BaseMessage.decodeBytes(bytes, const <String>{}, const <String>{}) as ConnectionRequestMessage;
  }

  /// [name] is the sender's device name, its id by default.
  ConnectionRequestMessage messageOf(
    ConnectionRequestMessageType connectionType,
    String senderId, {
    String? name,
    List<int>? nonce,
    List<int>? proof,
    List<int>? issuedSecret,
  }) {
    return ConnectionRequestMessage(
      connectionType: connectionType,
      senderDeviceName: name ?? senderId,
      version: SyncUtils.kSyncVersion,
      reason: null,
      nonce: nonce,
      proof: proof,
      secret: issuedSecret,
      messageInfo: BaseMessageInfo.connection(senderId),
    );
  }

  /// a fresh client challenged by a server holding [serverSecret], the shared secret by default: `(client, server, challenge)`.
  challengedPair({List<int>? serverSecret}) {
    final client = newHandshake();
    final server = newHandshake();
    final clientNonce = client.start();
    server.onConnect(clientNonce: clientNonce, hasSecret: true);
    final challenge = server.buildChallenge(secret: serverSecret ?? sharedSecret, serverId: serverId, clientId: clientId)!;
    return (client, server, challenge);
  }

  Uint8List jsonFrameOf(BaseMessage msg) {
    final payload = msg.encodeBytes();
    final length = payload.length + 1;
    return Uint8List.fromList([(length >> 24) & 0xFF, (length >> 16) & 0xFF, (length >> 8) & 0xFF, length & 0xFF, 0, ...payload]);
  }

  /// our sessions list their addresses up front in the helpers below, so a proof they check is done here too.
  Future<void> deliver(_FakeSocket socket, BaseMessage msg) async {
    socket.receive(jsonFrameOf(msg));
    await pumpEventQueue();
  }

  /// [peerId] connects to our server: `(session, socket, peer)`, [peer] is their side of the handshake.
  peerConnects(String peerId, {String? name}) async {
    final socket = _FakeSocket(isServerSide: true);
    final session = debugListenAsServer(socket);
    await debugOwnAddressesOf(session);
    final peer = newHandshake();
    await deliver(socket, messageOf(.connect, peerId, name: name, nonce: peer.start()));
    return (session, socket, peer);
  }

  /// [peerId] connects to our server and proves [secret] against our challenge: `(session, socket)`.
  peerConnectsProven(String peerId, List<int> secret, {String? name}) async {
    final (session, socket, peer) = await peerConnects(peerId, name: name);
    final challenge = socket.sent.single;
    final peerProof = peer.onChallenge(secret: secret, serverNonce: challenge.nonce, serverProof: challenge.proof, serverId: ourId, clientId: peerId, ownAddresses: ownAddresses);
    await deliver(socket, messageOf(.proof, peerId, name: name, proof: peerProof));
    return (session, socket);
  }

  /// our client connects to [peerId] like the user picked it, or like an auto reconnect, found at [dialedAddress]: `(session, socket)`.
  weConnect(String peerId, {bool isAutoReconnect = false, String? dialedAddress}) async {
    final socket = _FakeSocket(isServerSide: false);
    final session = debugListenAsClient(socket, peerId, isAutoReconnect: isAutoReconnect, dialedAddress: dialedAddress);
    await debugOwnAddressesOf(session);
    await session.sendConnect();
    return (session, socket);
  }

  /// our client connects to the address [host] the user typed: `(session, socket)`.
  weConnectByAddress(String host) async {
    final socket = _FakeSocket(isServerSide: false);
    final session = debugListenByAddress(socket, host);
    await debugOwnAddressesOf(session);
    await session.sendConnect();
    return (session, socket);
  }

  /// our client connects to [peerId] that proves [secret] then accepts us: `(session, socket)`.
  weConnectProven(String peerId, List<int> secret) async {
    final (session, socket) = await weConnect(peerId);
    final connect = socket.sent.single;
    final peerServer = newHandshake();
    peerServer.onConnect(clientNonce: connect.nonce, hasSecret: true);
    final challenge = peerServer.buildChallenge(secret: secret, serverId: peerId, clientId: ourId)!;
    await deliver(socket, messageOf(.challenge, peerId, nonce: challenge.nonce, proof: challenge.proof));
    final proof = socket.sent.last;
    final decision = peerServer.onProof(secret: secret, clientProof: proof.proof, serverId: peerId, clientId: ourId, ownAddresses: ownAddresses, canAutoAccept: true);
    expect(decision.name, 'trust', reason: 'our client answers with the proof of $peerId');
    await deliver(socket, messageOf(.accepted, peerId));
    return (session, socket);
  }

  void rememberServer(String id, String address) {
    settings.sync.transaction(() {
      settings.sync.allowedServerIds.update((ids) => ids.add(id));
      settings.sync.manualServerAddresses.update((addresses) => addresses[id] = address);
    });
  }

  /// real sockets deliver on their own time.
  Future<void> waitUntil(bool Function() condition) async {
    for (int i = 0; i < 400 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), true);
  }

  group('proofs', () {
    test('a server proof verifies with the same secret, nonces and ids, and the client answers', () {
      final (client, _, challenge) = challengedPair();
      final clientProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );
      expect(clientProof, hasLength(32));
      expect(client.isPeerProven, true);
    });

    test('a client proof verifies on the server that challenged it', () {
      final (client, server, challenge) = challengedPair();
      final clientProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );
      final decision = server.onProof(secret: sharedSecret, clientProof: clientProof, serverId: serverId, clientId: clientId, ownAddresses: ownAddresses, canAutoAccept: true);
      expect(decision.name, 'trust');
      expect(server.isPeerProven, true);
    });

    test('a server holding another secret fails, and the client sends no proof back', () {
      final (client, _, challenge) = challengedPair(serverSecret: otherSecret);
      final clientProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );
      expect(clientProof, isNull);
      expect(client.isPeerProven, false);
    });

    test('a client holding another secret fails', () {
      final (client, server, challenge) = challengedPair();
      final clientProof = client.onChallenge(
        secret: otherSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );
      final decision = server.onProof(secret: sharedSecret, clientProof: clientProof, serverId: serverId, clientId: clientId, ownAddresses: ownAddresses, canAutoAccept: true);
      expect(decision.name, 'prompt');
      expect(server.isPeerProven, false);
    });

    test('a challenge answered with a tampered server nonce fails', () {
      final (client, _, challenge) = challengedPair();
      final tamperedNonce = Uint8List.fromList(challenge.nonce)..[0] ^= 1;
      final clientProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: tamperedNonce,
        serverProof: challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );
      expect(clientProof, isNull);
    });

    test('a challenge recorded for another connect fails (replayed server proof)', () {
      final (_, _, recordedChallenge) = challengedPair();
      final (client, _, _) = challengedPair();
      final clientProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: recordedChallenge.nonce,
        serverProof: recordedChallenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );
      expect(clientProof, isNull);
    });

    test('a client proof recorded earlier fails a new challenge, even with the old client nonce replayed', () {
      final client = newHandshake();
      final server = newHandshake();
      final recordedClientNonce = client.start();
      server.onConnect(clientNonce: recordedClientNonce, hasSecret: true);
      final challenge = server.buildChallenge(secret: sharedSecret, serverId: serverId, clientId: clientId)!;
      final recordedProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );

      final laterServer = newHandshake();
      laterServer.onConnect(clientNonce: recordedClientNonce, hasSecret: true);
      laterServer.buildChallenge(secret: sharedSecret, serverId: serverId, clientId: clientId);
      final decision = laterServer.onProof(
        secret: sharedSecret,
        clientProof: recordedProof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
        canAutoAccept: true,
      );
      expect(decision.name, 'prompt');
      expect(laterServer.isPeerProven, false);
    });

    test('a challenge takes a single answer', () {
      final (client, server, challenge) = challengedPair();
      final clientProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );
      server.onProof(secret: sharedSecret, clientProof: clientProof, serverId: serverId, clientId: clientId, ownAddresses: ownAddresses, canAutoAccept: true);
      expect(server.isAwaitingProof, false);
      expect(client.isAwaitingChallenge, false);
    });

    test('the server proof sent back as the client proof fails (swapped roles)', () {
      final (_, server, challenge) = challengedPair();
      final decision = server.onProof(secret: sharedSecret, clientProof: challenge.proof, serverId: serverId, clientId: clientId, ownAddresses: ownAddresses, canAutoAccept: true);
      expect(decision.name, 'prompt');
      expect(server.isPeerProven, false);
    });

    test('swapped device ids fail on both sides', () {
      final (client, _, challenge) = challengedPair();
      final swappedClientProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: clientId,
        clientId: serverId,
        ownAddresses: ownAddresses,
      );
      expect(swappedClientProof, isNull);

      final (honestClient, server, honestChallenge) = challengedPair();
      final clientProof = honestClient.onChallenge(
        secret: sharedSecret,
        serverNonce: honestChallenge.nonce,
        serverProof: honestChallenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );
      final decision = server.onProof(secret: sharedSecret, clientProof: clientProof, serverId: clientId, clientId: serverId, ownAddresses: ownAddresses, canAutoAccept: true);
      expect(decision.name, 'prompt');
    });

    test('a missing or truncated client proof fails', () {
      final (_, missingServer, _) = challengedPair();
      expect(
        missingServer.onProof(secret: sharedSecret, clientProof: null, serverId: serverId, clientId: clientId, ownAddresses: ownAddresses, canAutoAccept: true).name,
        'prompt',
      );

      final (client, truncatedServer, challenge) = challengedPair();
      final clientProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      )!;
      final truncatedProof = clientProof.sublist(0, clientProof.length - 1);
      expect(
        truncatedServer.onProof(secret: sharedSecret, clientProof: truncatedProof, serverId: serverId, clientId: clientId, ownAddresses: ownAddresses, canAutoAccept: true).name,
        'prompt',
      );
    });

    test('a client nonce of the wrong length leaves no challenge to send', () {
      final server = newHandshake();
      final decision = server.onConnect(clientNonce: List.filled(16, 7), hasSecret: true);
      expect(decision.name, 'challenge');
      expect(server.buildChallenge(secret: sharedSecret, serverId: serverId, clientId: clientId), isNull);
    });
  });

  group('decisions', () {
    test('an unknown device gets the approval prompt', () {
      final server = newHandshake();
      final decision = server.onConnect(clientNonce: List.filled(32, 1), hasSecret: false);
      expect(decision.name, 'prompt');
    });

    test('a device with a stored secret is challenged', () {
      final server = newHandshake();
      final decision = server.onConnect(clientNonce: List.filled(32, 1), hasSecret: true);
      expect(decision.name, 'challenge');
    });

    test('a wrong proof is not allowed and falls back to the prompt', () {
      final (_, server, _) = challengedPair();
      final decision = server.onProof(
        secret: sharedSecret,
        clientProof: List.filled(32, 0),
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
        canAutoAccept: true,
      );
      expect(decision.name, 'prompt');
      expect(server.isPeerProven, false);
    });

    test('a client trusts a proven server, pairs with one it holds no secret for, and prompts for an unproven one it holds a secret for', () {
      final (client, _, challenge) = challengedPair();
      client.onChallenge(secret: sharedSecret, serverNonce: challenge.nonce, serverProof: challenge.proof, serverId: serverId, clientId: clientId, ownAddresses: ownAddresses);
      expect(client.onAccepted(hasSecret: true, isAutoReconnect: true).name, 'trust');

      final unchallengedClient = newHandshake()..start();
      expect(unchallengedClient.onAccepted(hasSecret: false, isAutoReconnect: false).name, 'trustAndPair');
      expect(unchallengedClient.onAccepted(hasSecret: true, isAutoReconnect: false).name, 'prompt');
    });

    test('an auto reconnect prompts for a server it holds no secret for', () {
      final unchallengedClient = newHandshake()..start();
      expect(unchallengedClient.onAccepted(hasSecret: false, isAutoReconnect: true).name, 'prompt');
    });
  });

  group('handshake through the message codec', () {
    test('paired devices prove each other, and the server trusts without issuing a new secret', () {
      final client = newHandshake();
      final server = newHandshake();

      final connect = viaCodec(messageOf(.connect, clientId, nonce: client.start()));
      final connectDecision = server.onConnect(clientNonce: connect.nonce, hasSecret: true);
      expect(connectDecision.name, 'challenge');

      final senderClientId = connect.messageInfo.senderDeviceId;
      final built = server.buildChallenge(secret: sharedSecret, serverId: serverId, clientId: senderClientId)!;
      final challenge = viaCodec(messageOf(.challenge, serverId, nonce: built.nonce, proof: built.proof));
      final senderServerId = challenge.messageInfo.senderDeviceId;
      final clientProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: senderServerId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );
      expect(clientProof, isNotNull);

      final proof = viaCodec(messageOf(.proof, clientId, proof: clientProof));
      final proofDecision = server.onProof(
        secret: sharedSecret,
        clientProof: proof.proof,
        serverId: serverId,
        clientId: senderClientId,
        ownAddresses: ownAddresses,
        canAutoAccept: true,
      );
      expect(proofDecision.name, 'trust');
      expect(client.onAccepted(hasSecret: true, isAutoReconnect: false).name, 'trust');
    });

    test('a client holding another secret answers without a proof and both sides fall back to the prompt', () {
      final client = newHandshake();
      final server = newHandshake();

      final connect = viaCodec(messageOf(.connect, clientId, nonce: client.start()));
      server.onConnect(clientNonce: connect.nonce, hasSecret: true);
      final built = server.buildChallenge(secret: sharedSecret, serverId: serverId, clientId: clientId)!;
      final challenge = viaCodec(messageOf(.challenge, serverId, nonce: built.nonce, proof: built.proof));
      final clientProof = client.onChallenge(
        secret: otherSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );
      expect(clientProof, isNull);

      final proof = viaCodec(messageOf(.proof, clientId, proof: clientProof));
      expect(proof.proof, isNull);
      expect(
        server.onProof(secret: sharedSecret, clientProof: proof.proof, serverId: serverId, clientId: clientId, ownAddresses: ownAddresses, canAutoAccept: true).name,
        'prompt',
      );
      expect(client.onAccepted(hasSecret: true, isAutoReconnect: false).name, 'prompt');
    });

    test('an issued secret reaches the client through accepted', () {
      final accepted = viaCodec(messageOf(.accepted, serverId, issuedSecret: sharedSecret));
      expect(accepted.secret, sharedSecret);
      expect(accepted.nonce, isNull);
      expect(accepted.proof, isNull);
    });

    test('only connection messages decode from a device not trusted on the socket', () {
      final ping = PingMessage(messageInfo: BaseMessageInfo.connection(clientId));
      final pingBytes = ping.encodeBytes();
      expect(() => BaseMessage.decodeBytes(pingBytes, const <String>{}, const <String>{}), throwsA(isA<NonAllowedMessageException>()));
      expect(BaseMessage.decodeBytes(pingBytes, const {clientId}, const <String>{}), isA<PingMessage>());
      final connectBytes = messageOf(.connect, clientId).encodeBytes();
      expect(BaseMessage.decodeBytes(connectBytes, const <String>{}, const <String>{}), isA<ConnectionRequestMessage>());
    });
  });

  group('connection binding', () {
    final relayAddress = InternetAddress('192.0.2.1'); // -- a documentation address, never one of ours

    /// a relay's two connections with matching ports, the client sees it as its server and the server as its client: `(client, server, challenge)`.
    relayedPair() {
      final client = newHandshake(peerAddress: relayAddress);
      final server = newHandshake(peerAddress: relayAddress);
      server.onConnect(clientNonce: client.start(), hasSecret: true);
      final challenge = server.buildChallenge(secret: sharedSecret, serverId: serverId, clientId: clientId)!;
      return (client, server, challenge);
    }

    test('a server proof relayed from another connection fails, even with matching ports', () {
      final (client, _, challenge) = relayedPair();
      final clientProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );
      expect(clientProof, isNull);
      expect(client.isPeerProven, false);
    });

    test('a client proof relayed from another connection fails, even with matching ports', () {
      final (client, server, challenge) = relayedPair();
      final relayOwnAddresses = [relayAddress.rawAddress]; // -- a client taking the relayed challenge as its own
      final clientProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: relayOwnAddresses,
      );
      expect(clientProof, isNotNull);
      final decision = server.onProof(secret: sharedSecret, clientProof: clientProof, serverId: serverId, clientId: clientId, ownAddresses: ownAddresses, canAutoAccept: true);
      expect(decision.name, 'prompt');
      expect(server.isPeerProven, false);
    });

    test('a server proof of a connection with other ports fails', () {
      final client = newHandshake();
      final server = debugCreateHandshake(peerAddress: InternetAddress.loopbackIPv4, clientPort: _kClientPort + 1, serverPort: _kServerPort);
      server.onConnect(clientNonce: client.start(), hasSecret: true);
      final challenge = server.buildChallenge(secret: sharedSecret, serverId: serverId, clientId: clientId)!;
      final clientProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );
      expect(clientProof, isNull);
    });

    test('an address written another way is the same address: ipv4-mapped ipv6, ipv6 letter case', () {
      final client = newHandshake();
      final dualStackServer = newHandshake(peerAddress: InternetAddress('::ffff:127.0.0.1'));
      dualStackServer.onConnect(clientNonce: client.start(), hasSecret: true);
      final challenge = dualStackServer.buildChallenge(secret: sharedSecret, serverId: serverId, clientId: clientId)!;
      final clientProof = client.onChallenge(
        secret: sharedSecret,
        serverNonce: challenge.nonce,
        serverProof: challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
      );
      expect(clientProof, isNotNull);
      final decision = dualStackServer.onProof(
        secret: sharedSecret,
        clientProof: clientProof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: ownAddresses,
        canAutoAccept: true,
      );
      expect(decision.name, 'trust');

      final ipv6Client = newHandshake(peerAddress: InternetAddress('fe80::1'));
      final ipv6Server = newHandshake(peerAddress: InternetAddress('FE80::2'));
      ipv6Server.onConnect(clientNonce: ipv6Client.start(), hasSecret: true);
      final ipv6Challenge = ipv6Server.buildChallenge(secret: sharedSecret, serverId: serverId, clientId: clientId)!;
      final ipv6ClientProof = ipv6Client.onChallenge(
        secret: sharedSecret,
        serverNonce: ipv6Challenge.nonce,
        serverProof: ipv6Challenge.proof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: [InternetAddress('fe80::2').rawAddress],
      );
      expect(ipv6ClientProof, isNotNull);
      final ipv6Decision = ipv6Server.onProof(
        secret: sharedSecret,
        clientProof: ipv6ClientProof,
        serverId: serverId,
        clientId: clientId,
        ownAddresses: [InternetAddress('FE80::1').rawAddress],
        canAutoAccept: true,
      );
      expect(ipv6Decision.name, 'trust');
    });

    /// our own client and server on the two sockets, paired under our own id: `(client, server)`.
    ourSessionsOn(Socket clientSocket, Socket serverSocket) async {
      settings.sync.allowDevice(ourId, issuedSecret: base64Encode(sharedSecret));
      final server = debugListenAsServer(serverSocket);
      final client = debugListenAsClient(clientSocket, ourId);
      await client.sendConnect();
      return (client, server);
    }

    Future<void> closeAndForgetOurselves(List<Socket> sockets) async {
      for (final socket in sockets) {
        socket.destroy();
      }
      await waitUntil(() => !SyncDiscovery.getAllConnectedDeviceIdsSet().contains(ourId));
      await SyncDiscovery.client.disconnectFromServer(ourId);
      settings.sync.forgetDevice(ourId);
    }

    test('our client and server prove each other over a direct connection', () async {
      final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepting = listener.first;
      final clientSocket = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
      final serverSocket = await accepting;

      final (client, server) = await ourSessionsOn(clientSocket, serverSocket);
      await waitUntil(() => client.isTrusted && server.isTrusted);

      await closeAndForgetOurselves([clientSocket, serverSocket]);
      await listener.close();
    });

    test('our client and server both fail a handshake relayed unchanged between two connections', () async {
      final relayListener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final serverListener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final relayAccepting = relayListener.first;
      final serverAccepting = serverListener.first;
      final clientSocket = await Socket.connect(InternetAddress.loopbackIPv4, relayListener.port);
      final relayInbound = await relayAccepting;
      final relayOutbound = await Socket.connect(InternetAddress.loopbackIPv4, serverListener.port);
      final serverSocket = await serverAccepting;
      final relaySubscriptions = [relayInbound.listen(relayOutbound.add), relayOutbound.listen(relayInbound.add)];
      final dialogsCount = NamidaNavigator.inst.openedDialogsCount;

      final (client, server) = await ourSessionsOn(clientSocket, serverSocket);
      await waitUntil(() => NamidaNavigator.inst.openedDialogsCount == dialogsCount + 1); // -- the server got no valid proof
      expect(client.isTrusted, false);
      expect(server.isTrusted, false);

      for (final subscription in relaySubscriptions) {
        await subscription.cancel();
      }
      await closeAndForgetOurselves([clientSocket, relayInbound, relayOutbound, serverSocket]);
      await relayListener.close();
      await serverListener.close();
    });
  });

  group('decode gate', () {
    Uint8List dirFileFrameFrom(String senderId) {
      final msg = DirFileMessage(
        subtype: AppPathsBackupEnum.VIDEOS_CACHE,
        fileName: 'file',
        mtime: 0,
        messageInfo: BaseMessageInfo(action: .add, senderDeviceId: senderId),
      );
      return jsonFrameOf(msg);
    }

    int receivedCountFrom(String deviceId) => SyncActionsLog.inst.entries.where((e) => e.deviceId == deviceId).length;

    test('data from an allowed device id is dropped until its own socket is trusted', () async {
      const senderId = 'allowed-client';
      settings.sync.allowDevice(senderId);
      final socket = _FakeSocket(isServerSide: true);
      final session = debugListenAsServer(socket);

      socket.receive(dirFileFrameFrom(senderId));
      await Future<void>.delayed(Duration.zero);
      expect(receivedCountFrom(senderId), 0);

      session.trust(senderId);
      socket.receive(dirFileFrameFrom(senderId));
      await Future<void>.delayed(Duration.zero);
      expect(receivedCountFrom(senderId), 1);
    });

    test('a trusted socket drops data claiming another allowed device', () async {
      const trustedId = 'trusted-client';
      const impersonatedId = 'impersonated-client';
      settings.sync.allowDevice(impersonatedId);
      final socket = _FakeSocket(isServerSide: true);
      final session = debugListenAsServer(socket);
      session.trust(trustedId);

      socket.receive(dirFileFrameFrom(impersonatedId));
      await Future<void>.delayed(Duration.zero);
      expect(receivedCountFrom(impersonatedId), 0);
    });
  });

  group('approved without a pair secret', () {
    test('a client approved before pair secrets existed gets the approval prompt, then a secret once accepted', () async {
      const peerId = 'approved-client-without-secret';
      settings.sync.allowDevice(peerId);
      final dialogsCount = NamidaNavigator.inst.openedDialogsCount;

      final (session, socket, _) = await peerConnects(peerId);
      expect(session.isTrusted, false);
      expect(socket.sent, isEmpty);
      expect(NamidaNavigator.inst.openedDialogsCount, dialogsCount + 1);

      await debugAcceptApproval(session);
      await pumpEventQueue();
      expect(session.isTrusted, true);
      final accepted = socket.sent.single;
      expect(accepted.connectionType, ConnectionRequestMessageType.accepted);
      expect(settings.sync.issuedPairSecrets.value[peerId], base64Encode(accepted.secret!));
    });

    test('a server approved before pair secrets existed gets the approval prompt on an auto reconnect, then its secret once accepted', () async {
      const peerId = 'approved-server-without-secret';
      final secretFromPeer = Uint8List.fromList(List.generate(32, (i) => 50 + i));
      settings.sync.allowDevice(peerId);
      rememberServer(peerId, '10.0.0.11');
      final dialogsCount = NamidaNavigator.inst.openedDialogsCount;

      final (session, socket) = await weConnect(peerId, isAutoReconnect: true);
      await deliver(socket, messageOf(.accepted, peerId, issuedSecret: secretFromPeer));
      expect(session.isTrusted, false);
      expect(settings.sync.receivedPairSecrets.value.containsKey(peerId), false);
      expect(NamidaNavigator.inst.openedDialogsCount, dialogsCount + 1);

      await debugAcceptApproval(session, issuedSecret: secretFromPeer);
      expect(session.isTrusted, true);
      expect(settings.sync.receivedPairSecrets.value[peerId], base64Encode(secretFromPeer));
    });

    test('a server the user connects to pairs without a prompt', () async {
      const peerId = 'server-picked-by-user';
      final secretFromPeer = Uint8List.fromList(List.generate(32, (i) => 70 + i));
      final dialogsCount = NamidaNavigator.inst.openedDialogsCount;

      final (session, socket) = await weConnect(peerId);
      await deliver(socket, messageOf(.accepted, peerId, issuedSecret: secretFromPeer));
      expect(session.isTrusted, true);
      expect(settings.sync.receivedPairSecrets.value[peerId], base64Encode(secretFromPeer));
      expect(NamidaNavigator.inst.openedDialogsCount, dialogsCount);
    });
  });

  group('pair secrets per role', () {
    test('pairing each other both ways at once keeps one secret per direction', () async {
      const peerId = 'peer-both-ways';
      final secretFromPeer = Uint8List.fromList(List.generate(32, (i) => 100 + i));

      final (ourClient, ourClientSocket) = await weConnect(peerId);
      final (ourServer, ourServerSocket, _) = await peerConnects(peerId);
      await debugAcceptApproval(ourServer);
      await pumpEventQueue();
      final accepted = ourServerSocket.sent.single;
      expect(accepted.connectionType, ConnectionRequestMessageType.accepted);
      final secretToPeer = accepted.secret!;
      await deliver(ourClientSocket, messageOf(.accepted, peerId, issuedSecret: secretFromPeer));
      expect(ourClient.isTrusted, true);
      expect(settings.sync.issuedPairSecrets.value[peerId], base64Encode(secretToPeer));
      expect(settings.sync.receivedPairSecrets.value[peerId], base64Encode(secretFromPeer));

      final (peerAsClient, _) = await peerConnectsProven(peerId, secretToPeer);
      expect(peerAsClient.isTrusted, true);
      final (weAsClient, _) = await weConnectProven(peerId, secretFromPeer);
      expect(weAsClient.isTrusted, true);
    });

    test('a device our client pairs with while its prompt on our server is open is still accepted there as a new device', () async {
      const peerId = 'peer-both-ways-client-first';
      final secretFromPeer = Uint8List.fromList(List.generate(32, (i) => 150 + i));

      final (ourClient, ourClientSocket) = await weConnect(peerId);
      final (ourServer, ourServerSocket, _) = await peerConnects(peerId);
      await deliver(ourClientSocket, messageOf(.accepted, peerId, issuedSecret: secretFromPeer));
      expect(ourClient.isTrusted, true);
      expect(debugCanBlockFromApproval(ourServer), true);

      await debugAcceptApproval(ourServer);
      await pumpEventQueue();
      expect(ourServer.isTrusted, true);
      final accepted = ourServerSocket.sent.single;
      expect(settings.sync.issuedPairSecrets.value[peerId], base64Encode(accepted.secret!));
      expect(settings.sync.receivedPairSecrets.value[peerId], base64Encode(secretFromPeer));
    });

    test('a device paired one way proves that pairing when it connects the other way', () async {
      const peerId = 'peer-paired-one-way';
      settings.sync.allowDevice(peerId, receivedSecret: base64Encode(sharedSecret));

      final (session, socket) = await peerConnectsProven(peerId, sharedSecret);
      expect(session.isTrusted, true);
      expect(socket.sent.last.connectionType, ConnectionRequestMessageType.accepted);
      expect(socket.sent.last.secret, isNull);
      expect(settings.sync.issuedPairSecrets.value.containsKey(peerId), false);
    });
  });

  group('approval prompt', () {
    test('rejecting a paired client that failed its proof refuses that socket only, the device stays paired', () async {
      const peerId = 'paired-client';
      settings.sync.allowDevice(peerId, issuedSecret: base64Encode(sharedSecret));
      final dialogsCount = NamidaNavigator.inst.openedDialogsCount;

      final (impostorSession, impostorSocket, _) = await peerConnects(peerId);
      await deliver(impostorSocket, messageOf(.proof, peerId, proof: List.filled(32, 0)));
      expect(impostorSession.isTrusted, false);
      expect(NamidaNavigator.inst.openedDialogsCount, dialogsCount + 1);
      await debugRejectApproval(impostorSession);
      await pumpEventQueue();

      expect(impostorSocket.sent.last.connectionType, ConnectionRequestMessageType.rejected);
      expect(impostorSocket.isClosed, true);
      expect(settings.sync.allowedDeviceIds.value, contains(peerId));
      expect(settings.sync.issuedPairSecrets.value[peerId], base64Encode(sharedSecret));
    });

    test('a paired client failing its proof while its proven socket is live is refused without a prompt', () async {
      const peerId = 'connected-paired-client';
      settings.sync.allowDevice(peerId, issuedSecret: base64Encode(sharedSecret));
      final (realSession, realSocket) = await peerConnectsProven(peerId, sharedSecret);
      expect(realSession.isTrusted, true);
      final dialogsCount = NamidaNavigator.inst.openedDialogsCount;

      final (impostorSession, impostorSocket, _) = await peerConnects(peerId);
      await deliver(impostorSocket, messageOf(.proof, peerId, proof: List.filled(32, 0)));

      expect(NamidaNavigator.inst.openedDialogsCount, dialogsCount);
      expect(impostorSession.isTrusted, false);
      expect(impostorSocket.sent.last.connectionType, ConnectionRequestMessageType.rejected);
      expect(impostorSocket.isClosed, true);
      expect(realSocket.isClosed, false);
      expect(SyncDiscovery.getAllConnectedDeviceIdsSet(), contains(peerId));
      expect(settings.sync.issuedPairSecrets.value[peerId], base64Encode(sharedSecret));
    });

    test('a paired client failing its proof while the device is connected as our server is refused without a prompt', () async {
      const peerId = 'paired-device-connected-as-server';
      settings.sync.allowDevice(peerId, receivedSecret: base64Encode(sharedSecret));
      final (realSession, realSocket) = await weConnectProven(peerId, sharedSecret);
      expect(realSession.isTrusted, true);
      final dialogsCount = NamidaNavigator.inst.openedDialogsCount;

      final (impostorSession, impostorSocket, _) = await peerConnects(peerId);
      await deliver(impostorSocket, messageOf(.proof, peerId, proof: List.filled(32, 0)));

      expect(NamidaNavigator.inst.openedDialogsCount, dialogsCount);
      expect(impostorSession.isTrusted, false);
      expect(impostorSocket.isClosed, true);
      expect(realSocket.isClosed, false);
      expect(settings.sync.receivedPairSecrets.value[peerId], base64Encode(sharedSecret));
    });

    test('accepting the prompt of a paired client that failed its proof once the real one connected refuses it, the real one stays', () async {
      const peerId = 'paired-client-reconnected';
      settings.sync.allowDevice(peerId, issuedSecret: base64Encode(sharedSecret));
      final (impostorSession, impostorSocket, _) = await peerConnects(peerId);
      await deliver(impostorSocket, messageOf(.proof, peerId, proof: List.filled(32, 0)));
      final (realSession, realSocket) = await peerConnectsProven(peerId, sharedSecret);
      expect(realSession.isTrusted, true);

      await debugAcceptApproval(impostorSession);
      await pumpEventQueue();

      expect(impostorSession.isTrusted, false);
      expect(impostorSocket.isClosed, true);
      expect(realSocket.isClosed, false);
      expect(SyncDiscovery.getAllConnectedDeviceIdsSet(), contains(peerId));
      expect(settings.sync.issuedPairSecrets.value[peerId], base64Encode(sharedSecret));
    });

    test('rejecting a device that has no pair secret still forgets it', () async {
      const peerId = 'legacy-client';
      settings.sync.allowDevice(peerId);

      final (session, socket, _) = await peerConnects(peerId);
      await debugRejectApproval(session);
      await pumpEventQueue();

      expect(settings.sync.allowedDeviceIds.value, isNot(contains(peerId)));
      expect(socket.sent.last.connectionType, ConnectionRequestMessageType.rejected);
      expect(socket.isClosed, true);
    });

    test('rejecting a paired server that failed its proof refuses that socket only, the server stays remembered', () async {
      const peerId = 'paired-server';
      const address = '10.0.0.7';
      settings.sync.allowDevice(peerId, receivedSecret: base64Encode(sharedSecret));
      rememberServer(peerId, address);
      final dialogsCount = NamidaNavigator.inst.openedDialogsCount;

      final (impostorSession, impostorSocket) = await weConnect(peerId);
      await deliver(impostorSocket, messageOf(.accepted, peerId, issuedSecret: otherSecret));
      expect(impostorSession.isTrusted, false);
      expect(NamidaNavigator.inst.openedDialogsCount, dialogsCount + 1);
      await debugRejectApproval(impostorSession);
      await pumpEventQueue();

      expect(impostorSocket.isClosed, true);
      expect(settings.sync.allowedServerIds.value, contains(peerId));
      expect(settings.sync.manualServerAddresses.value[peerId], address);
      expect(settings.sync.receivedPairSecrets.value[peerId], base64Encode(sharedSecret));
    });

    test('a paired server failing its proof while our trusted socket to it is live is refused without a prompt', () async {
      const peerId = 'connected-paired-server';
      const address = '10.0.0.12';
      settings.sync.allowDevice(peerId, receivedSecret: base64Encode(sharedSecret));
      rememberServer(peerId, address);
      final (realSession, realSocket) = await weConnectProven(peerId, sharedSecret);
      expect(realSession.isTrusted, true);
      final dialogsCount = NamidaNavigator.inst.openedDialogsCount;

      final (impostorSession, impostorSocket) = await weConnect(peerId);
      await deliver(impostorSocket, messageOf(.accepted, peerId, issuedSecret: otherSecret));

      expect(NamidaNavigator.inst.openedDialogsCount, dialogsCount);
      expect(impostorSession.isTrusted, false);
      expect(impostorSocket.isClosed, true);
      expect(realSocket.isClosed, false);
      expect(SyncDiscovery.getAllConnectedDeviceIdsSet(), contains(peerId));
      expect(settings.sync.allowedServerIds.value, contains(peerId));
      expect(settings.sync.manualServerAddresses.value[peerId], address);
      expect(settings.sync.receivedPairSecrets.value[peerId], base64Encode(sharedSecret));
    });

    test('the prompt of a paired device that failed its proof has a warning and no block button, the one of a device without a pair secret has the button only', () async {
      final warning = lang.thisDeviceCouldNotProveItIsTheOneYouPairedAcceptOnlyIfYouResetIt;
      const pairedClientId = 'paired-client-without-proof';
      settings.sync.allowDevice(pairedClientId, issuedSecret: base64Encode(sharedSecret));
      final (pairedClientSession, pairedClientSocket, _) = await peerConnects(pairedClientId);
      await deliver(pairedClientSocket, messageOf(.proof, pairedClientId, proof: List.filled(32, 0)));
      expect(debugCanBlockFromApproval(pairedClientSession), false);
      expect(debugApprovalText(pairedClientSession), contains(warning));

      const pairedServerId = 'paired-server-without-proof';
      settings.sync.allowDevice(pairedServerId, receivedSecret: base64Encode(sharedSecret));
      final (pairedServerSession, pairedServerSocket) = await weConnect(pairedServerId, isAutoReconnect: true);
      await deliver(pairedServerSocket, messageOf(.accepted, pairedServerId, issuedSecret: otherSecret));
      expect(debugCanBlockFromApproval(pairedServerSession), false);
      expect(debugApprovalText(pairedServerSession), contains(warning));

      final (unknownClientSession, _, _) = await peerConnects('unknown-client');
      expect(debugCanBlockFromApproval(unknownClientSession), true);
      expect(debugApprovalText(unknownClientSession), isNot(contains(warning)));
      final (unknownServerSession, unknownServerSocket) = await weConnect('unknown-server', isAutoReconnect: true);
      await deliver(unknownServerSocket, messageOf(.accepted, 'unknown-server', issuedSecret: otherSecret));
      expect(debugCanBlockFromApproval(unknownServerSession), true);
      expect(debugApprovalText(unknownServerSession), isNot(contains(warning)));
    });
  });

  group('client sockets', () {
    test('a server cannot send requests on our client socket', () async {
      const peerId = 'peer-sending-requests';
      settings.sync.allowDevice(peerId, issuedSecret: base64Encode(sharedSecret));
      final (_, peerAsClientSocket) = await peerConnectsProven(peerId, sharedSecret);
      expect(SyncDiscovery.getAllConnectedDeviceIdsSet(), contains(peerId));

      final (session, socket) = await weConnect(peerId);
      await deliver(socket, messageOf(.connect, peerId, nonce: List.filled(32, 1)));
      await deliver(socket, messageOf(.disconnect, peerId));

      expect(socket.sent, hasLength(1));
      expect(session.isClosed, false);
      expect(peerAsClientSocket.isClosed, false);
      expect(SyncDiscovery.getAllConnectedDeviceIdsSet(), contains(peerId));
    });

    test('rejected or blocked from a second socket of a connected server cannot drop it', () async {
      const peerId = 'connected-server';
      const address = '10.0.0.8';
      rememberServer(peerId, address);
      final (connectedSession, connectedSocket) = await weConnect(peerId);
      await deliver(connectedSocket, messageOf(.accepted, peerId, issuedSecret: sharedSecret));
      expect(connectedSession.isTrusted, true);

      for (final connectionType in [ConnectionRequestMessageType.rejected, ConnectionRequestMessageType.blocked]) {
        final (_, secondSocket) = await weConnect(peerId);
        await deliver(secondSocket, messageOf(connectionType, peerId));
        expect(secondSocket.isClosed, true, reason: connectionType.name);
      }

      expect(connectedSocket.isClosed, false);
      expect(SyncDiscovery.getAllConnectedDeviceIdsSet(), contains(peerId));
      expect(settings.sync.allowedServerIds.value, contains(peerId));
      expect(settings.sync.manualServerAddresses.value[peerId], address);
    });

    test('rejected or blocked from the handshake of a server only skips its auto reconnect for this run, its approval and address stay', () async {
      for (final connectionType in [ConnectionRequestMessageType.rejected, ConnectionRequestMessageType.blocked]) {
        final peerId = 'unproven-server-${connectionType.name}';
        const address = '10.0.0.9';
        settings.sync.allowDevice(peerId, receivedSecret: base64Encode(sharedSecret));
        rememberServer(peerId, address);
        final (session, socket) = await weConnect(peerId, isAutoReconnect: true);
        await deliver(socket, messageOf(connectionType, peerId));

        final reason = connectionType.name;
        expect(socket.isClosed, true, reason: reason);
        expect(session.isClosed, true, reason: reason);
        expect(debugIsAutoReconnectSkipped(peerId), true, reason: reason);
        expect(settings.sync.allowedServerIds.value, contains(peerId), reason: reason);
        expect(settings.sync.manualServerAddresses.value[peerId], address, reason: reason);
        expect(settings.sync.allowedDeviceIds.value, contains(peerId), reason: reason);
        expect(settings.sync.receivedPairSecrets.value[peerId], base64Encode(sharedSecret), reason: reason);
      }
    });

    test('rejected or blocked from the trusted socket of a server still drops it', () async {
      for (final connectionType in [ConnectionRequestMessageType.rejected, ConnectionRequestMessageType.blocked]) {
        final peerId = 'trusted-server-${connectionType.name}';
        rememberServer(peerId, '10.0.0.10');
        final (session, socket) = await weConnect(peerId);
        await deliver(socket, messageOf(.accepted, peerId, issuedSecret: sharedSecret));
        expect(session.isTrusted, true);
        await deliver(socket, messageOf(connectionType, peerId));

        final reason = connectionType.name;
        expect(socket.isClosed, true, reason: reason);
        expect(SyncDiscovery.getAllConnectedDeviceIdsSet(), isNot(contains(peerId)), reason: reason);
        expect(settings.sync.allowedServerIds.value, isNot(contains(peerId)), reason: reason);
        expect(settings.sync.manualServerAddresses.value.containsKey(peerId), false, reason: reason);
      }
    });
  });

  group('connecting by address', () {
    test('a reply claiming a paired server id leaves its saved address alone', () async {
      const pairedId = 'paired-server-claimed';
      const pairedAddress = '10.0.0.20';
      settings.sync.allowDevice(pairedId, receivedSecret: base64Encode(sharedSecret));
      rememberServer(pairedId, pairedAddress);

      final (session, socket) = await weConnectByAddress('10.0.0.66');
      await deliver(socket, messageOf(.accepted, pairedId, issuedSecret: otherSecret));

      expect(session.isTrusted, false);
      expect(settings.sync.manualServerAddresses.value[pairedId], pairedAddress);
      expect(settings.sync.receivedPairSecrets.value[pairedId], base64Encode(sharedSecret));
    });

    test('a server is saved for auto reconnect at the typed address only once trusted', () async {
      const serverDeviceId = 'server-by-address';
      const host = '10.0.0.21';
      final (session, socket) = await weConnectByAddress(host);
      await deliver(socket, messageOf(.challenge, serverDeviceId, nonce: List.filled(32, 7), proof: List.filled(32, 0)));
      expect(session.peerId, serverDeviceId);
      expect(session.isTrusted, false);
      expect(settings.sync.allowedServerIds.value, isNot(contains(serverDeviceId)));
      expect(settings.sync.manualServerAddresses.value.containsKey(serverDeviceId), false);

      await deliver(socket, messageOf(.accepted, serverDeviceId, issuedSecret: sharedSecret));
      expect(session.isTrusted, true);
      expect(settings.sync.allowedServerIds.value, contains(serverDeviceId));
      expect(settings.sync.manualServerAddresses.value[serverDeviceId], host);
    });
  });

  group('servers saved under an old id', () {
    test('a server trusted at the typed address another id is saved at drops that id, so it is not redialed', () async {
      const oldId = 'old-android-build-id';
      const newId = 'new-android-install-id';
      const address = '10.0.0.30';
      rememberServer(oldId, address);
      settings.sync.updateDeviceName(oldId, 'Old Phone');
      rememberServer('server-elsewhere', '10.0.0.31');

      final (session, socket) = await weConnectByAddress(address);
      await deliver(socket, messageOf(.accepted, newId, issuedSecret: sharedSecret));

      expect(session.isTrusted, true);
      expect(settings.sync.manualServerAddresses.value[newId], address);
      expect(settings.sync.manualServerAddresses.value.containsKey(oldId), false);
      expect(settings.sync.allowedServerIds.value, isNot(contains(oldId)));
      expect(settings.sync.deviceIdNames.value.containsKey(oldId), false);
      expect(settings.sync.manualServerAddresses.value['server-elsewhere'], '10.0.0.31');
      expect(settings.sync.allowedServerIds.value, contains('server-elsewhere'));
    });

    test('a discovered server trusted at the address another id is saved at drops that id too', () async {
      const oldId = 'old-android-build-id-discovered';
      const newId = 'new-android-install-id-discovered';
      const address = '10.0.0.32';
      rememberServer(oldId, address);

      final (session, socket) = await weConnect(newId, dialedAddress: address);
      await deliver(socket, messageOf(.accepted, newId, issuedSecret: sharedSecret));

      expect(session.isTrusted, true);
      expect(settings.sync.manualServerAddresses.value.containsKey(oldId), false);
      expect(settings.sync.allowedServerIds.value, isNot(contains(oldId)));
    });

    test('a discovered server trusted at the address another id is saved at takes that address over, so it is redialed at startup', () async {
      const oldId = 'old-android-build-id-taken-over';
      const newId = 'new-android-install-id-taking-over';
      const address = '10.0.0.34';
      rememberServer(oldId, address);
      expect(settings.sync.manualServerAddresses.value.containsKey(newId), false);

      final (session, socket) = await weConnect(newId, dialedAddress: address);
      await deliver(socket, messageOf(.accepted, newId, issuedSecret: sharedSecret));

      expect(session.isTrusted, true);
      expect(settings.sync.manualServerAddresses.value[newId], address);
      expect(settings.sync.manualServerAddresses.value.containsKey(oldId), false);
    });

    test('a discovered server trusted at an address no other id is saved at is not saved there', () async {
      const newId = 'discovered-server-without-saved-address';
      const address = '10.0.0.35';

      final (session, socket) = await weConnect(newId, dialedAddress: address);
      await deliver(socket, messageOf(.accepted, newId, issuedSecret: sharedSecret));

      expect(session.isTrusted, true);
      expect(settings.sync.manualServerAddresses.value.containsKey(newId), false);
    });

    test('a paired server saved at the address another server is trusted at only loses the address, it still reconnects when discovered', () async {
      const movedId = 'paired-server-moved-away';
      const newId = 'server-given-its-address';
      const address = '10.0.0.33';
      settings.sync.allowDevice(movedId, receivedSecret: base64Encode(sharedSecret));
      rememberServer(movedId, address);
      settings.sync.updateDeviceName(movedId, 'Moved Server');

      final (session, socket) = await weConnect(newId, dialedAddress: address);
      await deliver(socket, messageOf(.accepted, newId, issuedSecret: otherSecret));

      expect(session.isTrusted, true);
      expect(settings.sync.manualServerAddresses.value.containsKey(movedId), false);
      expect(settings.sync.manualServerAddresses.value[newId], address);
      expect(settings.sync.allowedServerIds.value, contains(movedId));
      expect(settings.sync.deviceIdNames.value[movedId], 'Moved Server');
      expect(settings.sync.receivedPairSecrets.value[movedId], base64Encode(sharedSecret));
    });
  });

  group('saved servers', () {
    test('a server the user connects to is saved for auto reconnect only once trusted', () async {
      const peerId = 'server-saved-once-trusted';
      final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final peerSockets = StreamIterator(listener);
      final device = NetworkDevice(name: peerId, address: listener.address.address, port: listener.port, deviceName: peerId, deviceId: peerId);

      await SyncDiscovery.client.connectToServer(device);
      expect(settings.sync.allowedServerIds.value, isNot(contains(peerId)));
      await peerSockets.moveNext();
      final rejectingPeer = peerSockets.current;
      rejectingPeer.add(jsonFrameOf(messageOf(.rejected, peerId)));
      await waitUntil(() => debugIsAutoReconnectSkipped(peerId));
      expect(settings.sync.allowedServerIds.value, isNot(contains(peerId)));

      await SyncDiscovery.client.connectToServer(device);
      await peerSockets.moveNext();
      final acceptingPeer = peerSockets.current;
      acceptingPeer.add(jsonFrameOf(messageOf(.accepted, peerId, issuedSecret: sharedSecret)));
      await waitUntil(() => settings.sync.allowedServerIds.value.contains(peerId));
      expect(SyncDiscovery.getAllConnectedDeviceIdsSet(), contains(peerId));

      await SyncDiscovery.client.disconnectFromServer(peerId);
      rejectingPeer.destroy();
      acceptingPeer.destroy();
      await peerSockets.cancel();
      await listener.close();
    });

    test('a saved address follows a trusted session only, never an unproven one', () async {
      const peerId = 'server-address-follows-trust';
      settings.sync.manualServerAddresses.update((addresses) => addresses[peerId] = '10.0.0.9');
      final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final peerSockets = StreamIterator(listener);
      final device = NetworkDevice(name: peerId, address: listener.address.address, port: listener.port, deviceName: peerId, deviceId: peerId);

      await SyncDiscovery.client.connectToServer(device);
      await peerSockets.moveNext();
      final rejectingPeer = peerSockets.current;
      rejectingPeer.add(jsonFrameOf(messageOf(.rejected, peerId)));
      await waitUntil(() => debugIsAutoReconnectSkipped(peerId));
      expect(settings.sync.manualServerAddresses.value[peerId], '10.0.0.9');

      await SyncDiscovery.client.connectToServer(device);
      await peerSockets.moveNext();
      final acceptingPeer = peerSockets.current;
      acceptingPeer.add(jsonFrameOf(messageOf(.accepted, peerId, issuedSecret: sharedSecret)));
      await waitUntil(() => settings.sync.allowedServerIds.value.contains(peerId));
      expect(settings.sync.manualServerAddresses.value[peerId], listener.address.address);

      await SyncDiscovery.client.disconnectFromServer(peerId);
      rejectingPeer.destroy();
      acceptingPeer.destroy();
      await peerSockets.cancel();
      await listener.close();
    });
  });

  group('device names', () {
    test('a client claiming a paired id cannot rename it, the name is saved once the client is trusted', () async {
      const peerId = 'paired-client-named';
      settings.sync.allowDevice(peerId, issuedSecret: base64Encode(sharedSecret));
      settings.sync.updateDeviceName(peerId, 'Real Phone');

      final (impostorSession, impostorSocket, _) = await peerConnects(peerId, name: 'Impostor');
      await deliver(impostorSocket, messageOf(.proof, peerId, name: 'Impostor', proof: List.filled(32, 0)));
      expect(impostorSession.isTrusted, false);
      expect(impostorSession.peerName, 'Impostor');
      expect(settings.sync.deviceIdNames.value[peerId], 'Real Phone');

      final (realSession, _) = await peerConnectsProven(peerId, sharedSecret, name: 'Renamed Phone');
      expect(realSession.isTrusted, true);
      expect(settings.sync.deviceIdNames.value[peerId], 'Renamed Phone');
    });

    test('a reply by address claiming a paired server id cannot rename it, a trusted server saves its name', () async {
      const pairedId = 'paired-server-named';
      settings.sync.allowDevice(pairedId, receivedSecret: base64Encode(sharedSecret));
      settings.sync.updateDeviceName(pairedId, 'Real Laptop');

      final (impostorSession, impostorSocket) = await weConnectByAddress('10.0.0.67');
      await deliver(impostorSocket, messageOf(.accepted, pairedId, name: 'Impostor', issuedSecret: otherSecret));
      expect(impostorSession.isTrusted, false);
      expect(impostorSession.peerName, 'Impostor');
      expect(settings.sync.deviceIdNames.value[pairedId], 'Real Laptop');

      const newServerId = 'new-server-named';
      final (newSession, newSocket) = await weConnectByAddress('10.0.0.68');
      await deliver(newSocket, messageOf(.accepted, newServerId, name: 'New Laptop', issuedSecret: sharedSecret));
      expect(newSession.isTrusted, true);
      expect(settings.sync.deviceIdNames.value[newServerId], 'New Laptop');
    });
  });

  group('stored secrets', () {
    setUp(() {
      settings.sync.allowDevice('removed', issuedSecret: 'cmVtb3ZlZA==', receivedSecret: 'cmVtb3ZlZDI=');
      settings.sync.allowDevice('kept', issuedSecret: 'a2VwdA==');
    });

    test('rejecting a device deletes its secrets of both roles and its trust, others stay', () async {
      await SyncDiscovery.server.rejectConnection('removed');
      expect(settings.sync.issuedPairSecrets.value.containsKey('removed'), false);
      expect(settings.sync.receivedPairSecrets.value.containsKey('removed'), false);
      expect(settings.sync.allowedDeviceIds.value.contains('removed'), false);
      expect(settings.sync.issuedPairSecrets.value['kept'], 'a2VwdA==');
      expect(settings.sync.allowedDeviceIds.value.contains('kept'), true);
    });

    test('blocking a device deletes its secrets and its trust', () async {
      await SyncDiscovery.server.blockConnection('removed');
      expect(settings.sync.issuedPairSecrets.value.containsKey('removed'), false);
      expect(settings.sync.receivedPairSecrets.value.containsKey('removed'), false);
      expect(settings.sync.allowedDeviceIds.value.contains('removed'), false);
      expect(settings.sync.blockedClientIds.value.contains('removed'), true);
      expect(settings.sync.issuedPairSecrets.value['kept'], 'a2VwdA==');
    });

    test('secrets are masked in redacted settings', () {
      final redacted = settings.sync.redactedJson();
      expect(redacted['issuedPairSecrets'], SettingsFileWriter.kRedactedValue);
      expect(redacted['receivedPairSecrets'], SettingsFileWriter.kRedactedValue);
    });

    test('the single secrets map older builds stored is dropped on load, from the file too', () async {
      const settingsWriteDelay = Duration(milliseconds: 2300);
      await Future<void>.delayed(settingsWriteDelay); // -- a pending write would replace the file below
      final file = File(settings.sync.filePath);
      final oldJson = {
        ...settings.sync.buildJson(),
        'pairSecrets': <String, dynamic>{'old-peer': 'b2xk'},
      };
      file.writeAsStringSync(jsonEncode(oldJson));

      await settings.sync.prepareSettingsFile();
      expect(settings.sync.buildJson().containsKey('pairSecrets'), false);
      expect(settings.sync.issuedPairSecrets.value['kept'], 'a2VwdA==');

      await Future<void>.delayed(settingsWriteDelay);
      final written = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(written.containsKey('pairSecrets'), false);
      expect(written['issuedPairSecrets'], containsPair('kept', 'a2VwdA=='));
    });
  });
}

const _kClientPort = 50123;
const _kServerPort = SyncUtils.kDefaultNamidaPort;

class _FakeSocket extends Stream<Uint8List> implements Socket {
  final _incoming = StreamController<Uint8List>(sync: true);
  final _written = debugCreateFrameReader();

  /// connection messages our side wrote.
  final sent = <ConnectionRequestMessage>[];

  @override
  final int port;

  @override
  final int remotePort;

  @override
  InternetAddress get remoteAddress => InternetAddress.loopbackIPv4;

  /// our server's accepted socket when [isServerSide], else our client's.
  _FakeSocket({required bool isServerSide}) : port = isServerSide ? _kServerPort : _kClientPort, remotePort = isServerSide ? _kClientPort : _kServerPort {
    _written.frames.listen((frame) {
      try {
        final msg = BaseMessage.decodeBytes(frame.$2, const <String>{}, const <String>{});
        if (msg is ConnectionRequestMessage) sent.add(msg);
      } on NonAllowedMessageException catch (_) {}
    });
  }

  bool get isClosed => _isClosed;
  bool _isClosed = false;

  void receive(Uint8List bytes) => _incoming.add(bytes);

  @override
  void add(List<int> data) => _written.addBytes(Uint8List.fromList(data));

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async => destroy();

  @override
  void destroy() {
    if (_isClosed) return;
    _isClosed = true;
    scheduleMicrotask(_incoming.close); // -- a real socket reports done asynchronously
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _incoming.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
