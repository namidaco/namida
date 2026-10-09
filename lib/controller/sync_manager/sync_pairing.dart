// all pairing logic by claude
part of 'sync_manager.dart';

/// one socket from its first byte: handshake replies go back on it only, and its peer passes [_FrameDispatcher] only once trusted here.
class _PairingSession {
  final bool isServerSide;
  final Socket socket;
  final _FrameWriter writer;
  final _FrameReader reader;
  final _Handshake _handshake;

  /// the address the user typed, for a session connected by address. saved for the server once it is trusted.
  final String? _manualAddress;

  /// the address a client session connected to, refreshes the server's saved address once trusted.
  final String? _dialedAddress;

  final bool _isAutoReconnect;

  _PairingSession.server(this.socket)
    : isServerSide = true,
      writer = _FrameWriter(socket),
      reader = _FrameReader(),
      _handshake = _Handshake(_ConnectionEndpoints.read(socket, isServerSide: true)),
      _manualAddress = null,
      _dialedAddress = null,
      _isAutoReconnect = false;

  _PairingSession._client(this.socket, this._peerId, {this._manualAddress, this._dialedAddress, this._isAutoReconnect = false})
    : isServerSide = false,
      writer = _FrameWriter(socket),
      reader = _FrameReader(),
      _handshake = _Handshake(_ConnectionEndpoints.read(socket, isServerSide: false));

  static const _kConnectTimeout = Duration(seconds: 5);

  /// [serverDeviceId] is null when connecting by address, the server's first reply tells it then.
  static Future<_PairingSession> connect(
    String address,
    int port, {
    String? serverDeviceId,
    bool isAutoReconnect = false,
    required void Function(_PairingSession session) onClosed,
  }) async {
    final socket = await Socket.connect(address, port, timeout: _kConnectTimeout);
    final manualAddress = serverDeviceId == null ? address : null;
    final session = _PairingSession._client(socket, serverDeviceId, manualAddress: manualAddress, dialedAddress: address, isAutoReconnect: isAutoReconnect);
    session.listen(onClosed: () => onClosed(session));
    return session;
  }

  String? get peerId => _peerId;
  String? _peerId;

  String get peerName => _peerName;
  String _peerName = '';

  /// the decode gate of [_FrameDispatcher], holds [peerId] once trusted.
  final trustedIds = <String>{};

  bool get isTrusted => trustedIds.isNotEmpty;

  bool get isClosed => _isClosed;
  bool _isClosed = false;

  void listen({required void Function() onClosed}) {
    _SocketWrapper._listen(
      socket,
      reader,
      _FrameDispatcher(this),
      onClosed: () {
        _isClosed = true;
        onClosed();
      },
    );
  }

  /// opens the decode gate, the returned connection is what gets registered as connected.
  _SocketWrapper trust(String deviceId) {
    trustedIds.add(deviceId);
    return _SocketWrapper(deviceId: deviceId, socket: socket, writer: writer, reader: reader);
  }

  Future<void> close() {
    _isClosed = true;
    return writer.closeSocket();
  }

  /// a dead socket cleans up through its `onClosed`, nothing to do here.
  Future<void> send(ConnectionRequestMessage msg) async {
    try {
      await writer.sendMessage(msg);
    } catch (e) {
      if (_kEnableSyncDebug) _debugNotify('X failed to send ${msg.toRawInfo()}: $e', isError: true);
    }
  }

  /// the secret of this socket's role, else the opposite role's: a device paired either way proves that pairing whichever side connects.
  Uint8List? _secretOf(String deviceId) {
    final sync = settings.sync;
    final ownSecrets = isServerSide ? sync.issuedPairSecrets.value : sync.receivedPairSecrets.value;
    final oppositeSecrets = isServerSide ? sync.receivedPairSecrets.value : sync.issuedPairSecrets.value;
    final encodedSecret = ownSecrets[deviceId] ?? oppositeSecrets[deviceId];
    return SyncUtils._tryDecodeBase64(encodedSecret);
  }

  /// this device's addresses, a peer's proof covers the one it sees. listed when a proof first needs checking.
  late final Future<List<Uint8List>> _ownAddresses = _ConnectionEndpoints.listOwnAddresses();

  Future<void> onMessage(ConnectionRequestMessage msg) async {
    if (_isClosed) return;
    final connectionType = msg.connectionType;
    final isMisdirected = connectionType.isReply == isServerSide; // -- a server only takes requests, a client only takes replies
    if (isMisdirected) {
      if (_kEnableSyncDebug) _debugNotify('X Misdirected connection message | ${msg.toRawInfo()}', isError: true);
      return;
    }
    final senderDeviceId = msg.messageInfo.senderDeviceId;
    final boundDeviceId = _peerId;
    if (boundDeviceId != null && boundDeviceId != senderDeviceId) return close(); // -- a socket belongs to a single device
    _peerName = msg.senderDeviceName;
    if (boundDeviceId == null) {
      _peerId = senderDeviceId;
      if (_manualAddress != null) SyncDiscovery.client._onAddressSessionIdentified(this, msg, _manualAddress);
    }

    switch (connectionType) {
      case ConnectionRequestMessageType.connect:
        await _onConnect(msg, senderDeviceId);
      case ConnectionRequestMessageType.proof:
        await _onProof(msg, senderDeviceId);
      case ConnectionRequestMessageType.disconnect:
        await SyncDiscovery.server._onDisconnectRequest(this, senderDeviceId);
      case ConnectionRequestMessageType.challenge:
        await _onChallenge(msg, senderDeviceId);
      case ConnectionRequestMessageType.accepted:
        await _onAccepted(msg, senderDeviceId);
      case ConnectionRequestMessageType.rejected:
        await SyncDiscovery.client._onConnectionRejected(this, msg);
      case ConnectionRequestMessageType.blocked:
        await SyncDiscovery.client._onConnectionBlocked(this, msg);
      case ConnectionRequestMessageType.unblocked:
        await SyncDiscovery.client.onConnectionUnBlocked(msg);
    }
  }

  // ======================== SERVER SIDE ========================

  Future<void> _onConnect(ConnectionRequestMessage msg, String clientDeviceId) async {
    if (isTrusted) return; // -- already accepted on this socket
    if (msg.version != SyncUtils.kSyncVersion) return _rejectVersionMismatch(msg.senderDeviceName);

    final serverDeviceId = await SyncUtils.currentDeviceId;
    final secret = _secretOf(clientDeviceId);
    final hasSecret = secret != null;
    _wasPairedOnConnect = hasSecret;
    final decision = _handshake.onConnect(clientNonce: msg.nonce, hasSecret: hasSecret);
    if (decision == _PairingDecision.prompt) return _askApproval(clientDeviceId);
    final challenge = _handshake.buildChallenge(secret: secret, serverId: serverDeviceId, clientId: clientDeviceId);
    if (challenge == null) return _onClientProofFailed(clientDeviceId, isProofMissing: true);
    final reply = await ConnectionRequestMessage.createForCurrentDevice(.challenge, nonce: challenge.nonce, proof: challenge.proof);
    await send(reply);
  }

  Future<void> _onProof(ConnectionRequestMessage msg, String clientDeviceId) async {
    final serverDeviceId = await SyncUtils.currentDeviceId;
    final ownAddresses = await _ownAddresses;
    if (!_handshake.isAwaitingProof) return; // -- never challenged, or a second answer to the same challenge
    final secret = _secretOf(clientDeviceId);
    final canAutoAccept = settings.sync.autoReconnect.value;
    final decision = _handshake.onProof(
      secret: secret,
      clientProof: msg.proof,
      serverId: serverDeviceId,
      clientId: clientDeviceId,
      ownAddresses: ownAddresses,
      canAutoAccept: canAutoAccept,
    );
    if (decision == _PairingDecision.trust) return SyncDiscovery.server._acceptSession(this, clientDeviceId, shouldIssueSecret: false);
    if (_handshake.isPeerProven) return _askApproval(clientDeviceId);
    return _onClientProofFailed(clientDeviceId, isProofMissing: msg.proof == null);
  }

  /// the client is not allowed on this socket, the user decides unless it impersonates a connected device.
  Future<void> _onClientProofFailed(String clientDeviceId, {required bool isProofMissing}) async {
    SyncDiagnostics._onPairingFailed(this, isProofMissing: isProofMissing);
    if (_isImpostorOfConnectedDevice(clientDeviceId)) return _refuse(clientDeviceId);
    _askApproval(clientDeviceId);
  }

  /// only this socket hears it, the device stays trusted for when both apps match again.
  Future<void> _rejectVersionMismatch(String clientDeviceName) async {
    VibratorController.high();
    final reasonMessage = lang.versionMismatchMakeSureBothAppsAreOnTheSameVersion;
    final reply = await ConnectionRequestMessage.createForCurrentDevice(.rejected, reason: reasonMessage);
    await send(reply);
    await NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        title: '${lang.connectionRejected} - $clientDeviceName',
        bodyText: reasonMessage,
        actions: [
          NamidaButton(
            text: lang.done.toUpperCase(),
            onTap: () {
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
      ),
    );
  }

  // ======================== CLIENT SIDE ========================

  Future<void> sendConnect() async {
    final serverDeviceId = _peerId;
    if (serverDeviceId != null) _wasPairedOnConnect = _secretOf(serverDeviceId) != null;
    final clientNonce = _handshake.start();
    final msg = await ConnectionRequestMessage.createForCurrentDevice(.connect, nonce: clientNonce);
    await writer.sendMessage(msg);
  }

  Future<void> _onChallenge(ConnectionRequestMessage msg, String serverDeviceId) async {
    final clientDeviceId = await SyncUtils.currentDeviceId;
    final ownAddresses = await _ownAddresses;
    if (!_handshake.isAwaitingChallenge) return; // -- one challenge per connect
    final secret = _secretOf(serverDeviceId);
    final clientProof = _handshake.onChallenge(
      secret: secret,
      serverNonce: msg.nonce,
      serverProof: msg.proof,
      serverId: serverDeviceId,
      clientId: clientDeviceId,
      ownAddresses: ownAddresses,
    );
    final isServerFailed = secret != null && clientProof == null;
    if (isServerFailed) SyncDiagnostics._onPairingFailed(this, isProofMissing: msg.proof == null);
    final reply = await ConnectionRequestMessage.createForCurrentDevice(.proof, proof: clientProof);
    await send(reply);
  }

  Future<void> _onAccepted(ConnectionRequestMessage msg, String serverDeviceId) async {
    if (isTrusted) return;
    final wasChallenged = !_handshake.isAwaitingChallenge;
    final hasSecret = _wasPairedOnConnect ?? (_secretOf(serverDeviceId) != null);
    final decision = _handshake.onAccepted(hasSecret: hasSecret, isAutoReconnect: _isAutoReconnect);
    if (decision != _PairingDecision.prompt) return SyncDiscovery.client._onServerTrusted(this, serverDeviceId, msg.secret);

    final isProofMissing = hasSecret && !wasChallenged; // -- a failed challenge is already recorded
    if (isProofMissing) SyncDiagnostics._onPairingFailed(this, isProofMissing: true);
    if (_isImpostorOfConnectedDevice(serverDeviceId)) return _refuse(serverDeviceId);
    _askApproval(serverDeviceId, issuedSecret: msg.secret);
  }

  // ======================== SHARED ========================

  /// whether we held a pair secret for the peer on `connect`, null for a client session connected by address.
  /// one stored after that, by our other role pairing the same device meanwhile, is not what this handshake checked.
  bool? _wasPairedOnConnect;

  /// a device we held a pair secret for that did not prove it on this socket, it may be impersonating the paired one.
  bool _isUnprovenPairedDevice(String peerId) {
    if (_handshake.isPeerProven) return false;
    return _wasPairedOnConnect ?? (_secretOf(peerId) != null);
  }

  /// an unproven paired device while a trusted socket of it is live in either role, a real device reconnecting proves itself.
  bool _isImpostorOfConnectedDevice(String peerId) {
    if (!_isUnprovenPairedDevice(peerId)) return false;
    return SyncDiscovery.server._clientsSockets.containsKey(peerId) || SyncDiscovery.client._connectedServers.containsKey(peerId);
  }

  /// turns down this socket only, the device stays paired & connected on its other sockets.
  Future<void> _refuse(String peerId) {
    if (isServerSide) return SyncDiscovery.server._refuseSession(this);
    return SyncDiscovery.client._refuseSession(this, peerId);
  }

  /// the accept button of the approval prompt, [issuedSecret] is the client's new pair secret from the server's `accepted`.
  /// the real device may have connected while the prompt was open, it stays.
  Future<void> _onApprovalAccepted(String peerId, List<int>? issuedSecret) async {
    if (_isImpostorOfConnectedDevice(peerId)) return _refuse(peerId);
    if (isServerSide) return SyncDiscovery.server._acceptSession(this, peerId, shouldIssueSecret: !_handshake.isPeerProven);
    SyncDiscovery.client._onServerTrusted(this, peerId, issuedSecret);
  }

  /// an unproven paired device gets only this socket refused, the real device stays paired & connected. any other reject keeps its meaning.
  Future<void> _onApprovalRejected(String peerId) {
    if (_isUnprovenPairedDevice(peerId)) return _refuse(peerId);
    if (isServerSide) return SyncDiscovery.server.rejectConnection(peerId);
    return SyncDiscovery.client.disconnectFromServer(peerId);
  }

  /// the approval prompt for a device without a pair secret, also shown when a paired one fails its proof.
  /// that one can't be blocked from here, the real device would be blocked with an impostor.
  void _askApproval(String peerId, {List<int>? issuedSecret}) {
    final isUnprovenPairedDevice = _isUnprovenPairedDevice(peerId);
    final bodyText = _approvalText(isUnprovenPairedDevice);
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: bodyText,
        trailingWidgets: [
          if (!isUnprovenPairedDevice)
            NamidaIconButton(
              icon: Broken.shield_slash,
              tooltip: () => lang.block.toUpperCase(),
              onPressed: () async {
                await SyncDiscovery.server.blockConnection(peerId);
                NamidaNavigator.inst.closeDialog();
              },
            ),
        ],
        actions: [
          NamidaButton(
            text: lang.reject.toUpperCase(),
            onTap: () async {
              await _onApprovalRejected(peerId);
              NamidaNavigator.inst.closeDialog();
            },
          ),
          NamidaButton(
            text: lang.accept.toUpperCase(),
            onTap: () async {
              await _onApprovalAccepted(peerId, issuedSecret);
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
      ),
    );
  }

  /// an unproven paired device gets a warning, its prompt reads like a first pairing otherwise.
  String _approvalText(bool isUnprovenPairedDevice) {
    final question = lang.acceptConnectionFromName(name: '"$_peerName"');
    if (!isUnprovenPairedDevice) return question;
    return '$question\n${lang.thisDeviceCouldNotProveItIsTheOneYouPairedAcceptOnlyIfYouResetIt}';
  }
}

/// the handshake steps of one connection, pure: [_PairingSession] feeds it what arrived and the stored secret, then acts on what it returns.
///
/// - pairing: the server approves the client and sends a fresh secret in `accepted`, both sides store it under the other's device id.
/// - every later connection: client `connect` + nonce -> server `challenge` + nonce & proof -> client verifies, `proof` + proof -> server verifies, `accepted`.
///   the secret never travels again, and a proof covers both fresh nonces, so a recorded one is useless later,
///   and the ends of its connection, so one relayed between two connections fails, see [_ConnectionEndpoints].
class _Handshake {
  static const _kSecretLength = 32;
  static const _kNonceLength = 32;
  static final _random = Random.secure();
  static final _serverTag = utf8.encode('server');
  static final _clientTag = utf8.encode('client');

  /// null when the socket closed before its ends were read, nothing proves then.
  final _ConnectionEndpoints? _endpoints;

  _Handshake(this._endpoints);

  List<int>? _clientNonce;
  List<int>? _serverNonce;

  bool get isPeerProven => _isPeerProven;
  bool _isPeerProven = false;

  /// client, from `connect` until the first `challenge`.
  bool get isAwaitingChallenge => _clientNonce != null;

  /// server, from `challenge` until the first `proof`.
  bool get isAwaitingProof => _serverNonce != null;

  static Uint8List newSecret() => _randomBytes(_kSecretLength);

  // ======================== CLIENT SIDE ========================

  /// the nonce sent with `connect`.
  List<int> start() {
    final clientNonce = _randomBytes(_kNonceLength);
    _clientNonce = clientNonce;
    return clientNonce;
  }

  /// the server proves itself first, the client proof to answer with comes back only then.
  /// null without a secret or when the server failed. the server proof covers the one of [ownAddresses] it sees.
  List<int>? onChallenge({
    required List<int>? secret,
    required List<int>? serverNonce,
    required List<int>? serverProof,
    required String serverId,
    required String clientId,
    required List<Uint8List> ownAddresses,
  }) {
    final clientNonce = _clientNonce;
    _clientNonce = null;
    final validServerNonce = _validNonceOrNull(serverNonce);
    final endpoints = _endpoints;
    if (secret == null || clientNonce == null || validServerNonce == null || endpoints == null) return null;
    List<int> proofOf({required bool isServerProof, required List<int> verifierAddress}) => _computeProof(
      secret,
      isServerProof: isServerProof,
      clientNonce: clientNonce,
      serverNonce: validServerNonce,
      serverId: serverId,
      clientId: clientId,
      verifierAddress: verifierAddress,
      endpoints: endpoints,
    );
    List<int> serverProofFor(List<int> clientAddress) => proofOf(isServerProof: true, verifierAddress: clientAddress);
    final isServerProofValid = _isProofForOwnAddress(serverProof, ownAddresses, endpoints, serverProofFor);
    if (!isServerProofValid) return null;
    _isPeerProven = true;
    return proofOf(isServerProof: false, verifierAddress: endpoints.peerAddress);
  }

  /// a server we hold no secret for pairs on a connection the user started, an automatic one asks first.
  _PairingDecision onAccepted({required bool hasSecret, required bool isAutoReconnect}) {
    if (_isPeerProven) return _PairingDecision.trust;
    if (!hasSecret && !isAutoReconnect) return _PairingDecision.trustAndPair;
    return _PairingDecision.prompt;
  }

  // ======================== SERVER SIDE ========================

  /// a client we hold a secret for has to prove it, any other one is up to the user: an approved id alone proves nothing.
  _PairingDecision onConnect({required List<int>? clientNonce, required bool hasSecret}) {
    _clientNonce = _validNonceOrNull(clientNonce);
    _serverNonce = null;
    _isPeerProven = false;
    if (hasSecret) return _PairingDecision.challenge;
    return _PairingDecision.prompt;
  }

  /// null without a secret, a usable client nonce or the ends of the connection, which counts as a missing proof.
  ({List<int> nonce, List<int> proof})? buildChallenge({required List<int>? secret, required String serverId, required String clientId}) {
    final clientNonce = _clientNonce;
    final endpoints = _endpoints;
    if (secret == null || clientNonce == null || endpoints == null) return null;
    final serverNonce = _randomBytes(_kNonceLength);
    _serverNonce = serverNonce;
    final serverProof = _computeProof(
      secret,
      isServerProof: true,
      clientNonce: clientNonce,
      serverNonce: serverNonce,
      serverId: serverId,
      clientId: clientId,
      verifierAddress: endpoints.peerAddress,
      endpoints: endpoints,
    );
    return (nonce: serverNonce, proof: serverProof);
  }

  /// each challenge takes a single answer. the client proof covers the one of [ownAddresses] it sees.
  _PairingDecision onProof({
    required List<int>? secret,
    required List<int>? clientProof,
    required String serverId,
    required String clientId,
    required List<Uint8List> ownAddresses,
    required bool canAutoAccept,
  }) {
    final clientNonce = _clientNonce;
    final serverNonce = _serverNonce;
    final endpoints = _endpoints;
    _serverNonce = null;
    _isPeerProven = false;
    if (secret == null || clientNonce == null || serverNonce == null || endpoints == null) return _PairingDecision.prompt;
    List<int> clientProofFor(List<int> serverAddress) => _computeProof(
      secret,
      isServerProof: false,
      clientNonce: clientNonce,
      serverNonce: serverNonce,
      serverId: serverId,
      clientId: clientId,
      verifierAddress: serverAddress,
      endpoints: endpoints,
    );
    _isPeerProven = _isProofForOwnAddress(clientProof, ownAddresses, endpoints, clientProofFor);
    if (_isPeerProven && canAutoAccept) return _PairingDecision.trust;
    return _PairingDecision.prompt;
  }

  // ======================== SHARED ========================

  static Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  static List<int>? _validNonceOrNull(List<int>? nonce) => nonce != null && nonce.length == _kNonceLength ? nonce : null;

  /// the peer covered the address it sees this device at, one of [ownAddresses] in the family of the connection.
  static bool _isProofForOwnAddress(
    List<int>? receivedProof,
    List<Uint8List> ownAddresses,
    _ConnectionEndpoints endpoints,
    List<int> Function(List<int> ownAddress) proofFor,
  ) {
    if (receivedProof == null) return false;
    final addressLength = endpoints.peerAddress.length;
    for (final ownAddress in ownAddresses) {
      if (ownAddress.length != addressLength) continue;
      final expectedProof = proofFor(ownAddress);
      if (_isEqualConstantTime(expectedProof, receivedProof)) return true;
    }
    return false;
  }

  /// the server proves `'server' + clientNonce + serverNonce`, the client `'client' + serverNonce + clientNonce`, both followed by both ids,
  /// [verifierAddress] (the checking side's, as the proving socket sees it) and both ports.
  /// every field is length prefixed, so different inputs never share bytes.
  static List<int> _computeProof(
    List<int> secret, {
    required bool isServerProof,
    required List<int> clientNonce,
    required List<int> serverNonce,
    required String serverId,
    required String clientId,
    required List<int> verifierAddress,
    required _ConnectionEndpoints endpoints,
  }) {
    final input = BytesBuilder(copy: false);
    void addField(List<int> bytes) {
      final length = bytes.length;
      input
        ..addByte((length >> 24) & 0xFF)
        ..addByte((length >> 16) & 0xFF)
        ..addByte((length >> 8) & 0xFF)
        ..addByte(length & 0xFF)
        ..add(bytes);
    }

    void addPortField(int port) => addField([(port >> 8) & 0xFF, port & 0xFF]);

    final serverIdBytes = utf8.encode(serverId);
    final clientIdBytes = utf8.encode(clientId);
    addField(isServerProof ? _serverTag : _clientTag);
    addField(isServerProof ? clientNonce : serverNonce);
    addField(isServerProof ? serverNonce : clientNonce);
    addField(serverIdBytes);
    addField(clientIdBytes);
    addField(verifierAddress);
    addPortField(endpoints.clientPort);
    addPortField(endpoints.serverPort);
    final inputBytes = input.takeBytes();
    final hmac = Hmac(sha256, secret);
    final digest = hmac.convert(inputBytes);
    return digest.bytes;
  }

  /// takes the same time wherever the bytes differ.
  static bool _isEqualConstantTime(List<int> expected, List<int>? received) {
    if (received == null || received.length != expected.length) return false;
    int diff = 0;
    for (int i = 0; i < expected.length; i++) {
      diff |= expected[i] ^ received[i];
    }
    return diff == 0;
  }
}

/// a handshake on a connection whose ends read as given on its side, see [_ConnectionEndpoints.read].
@visibleForTesting
// ignore: library_private_types_in_public_api
_Handshake debugCreateHandshake({required InternetAddress peerAddress, required int clientPort, required int serverPort}) {
  final canonicalPeerAddress = _ConnectionEndpoints._canonicalBytesOf(peerAddress);
  final endpoints = _ConnectionEndpoints(canonicalPeerAddress, clientPort: clientPort, serverPort: serverPort);
  return _Handshake(endpoints);
}

@visibleForTesting
// ignore: library_private_types_in_public_api
_PairingSession debugListenAsServer(Socket socket) => SyncDiscovery.server._onClientSocket(socket);

/// a session handshaking with [serverDeviceId], like [_ClientSide.connectToServer] once connected to [dialedAddress].
@visibleForTesting
// ignore: library_private_types_in_public_api
_PairingSession debugListenAsClient(Socket socket, String serverDeviceId, {bool isAutoReconnect = false, String? dialedAddress}) {
  final client = SyncDiscovery.client;
  final session = _PairingSession._client(socket, serverDeviceId, dialedAddress: dialedAddress, isAutoReconnect: isAutoReconnect);
  session.listen(onClosed: () => client._onSessionClosed(session));
  client._setPending(serverDeviceId, session);
  return session;
}

/// a session connected to [host], like [_ClientSide.connectToAddress] once connected.
@visibleForTesting
// ignore: library_private_types_in_public_api
_PairingSession debugListenByAddress(Socket socket, String host) {
  final session = _PairingSession._client(socket, null, manualAddress: host, dialedAddress: host);
  session.listen(onClosed: () => SyncDiscovery.client._onSessionClosed(session));
  return session;
}

/// the addresses the session checks proofs against, listed once.
@visibleForTesting
// ignore: library_private_types_in_public_api
Future<List<Uint8List>> debugOwnAddressesOf(_PairingSession session) => session._ownAddresses;

/// the accept button of the approval prompt, [issuedSecret] is what the server's `accepted` carried.
@visibleForTesting
// ignore: library_private_types_in_public_api
Future<void> debugAcceptApproval(_PairingSession session, {List<int>? issuedSecret}) => session._onApprovalAccepted(session.peerId!, issuedSecret);

/// the reject button of the approval prompt.
@visibleForTesting
// ignore: library_private_types_in_public_api
Future<void> debugRejectApproval(_PairingSession session) => session._onApprovalRejected(session.peerId!);

/// whether the approval prompt has the block button.
@visibleForTesting
// ignore: library_private_types_in_public_api
bool debugCanBlockFromApproval(_PairingSession session) => !session._isUnprovenPairedDevice(session.peerId!);

/// the text of the approval prompt.
@visibleForTesting
// ignore: library_private_types_in_public_api
String debugApprovalText(_PairingSession session) => session._approvalText(session._isUnprovenPairedDevice(session.peerId!));

@visibleForTesting
bool debugIsAutoReconnectSkipped(String serverDeviceId) => SyncDiscovery.client._autoReconnectAttempted.contains(serverDeviceId);

/// what one side of a tcp connection reads of it: both ports, alike on the other side, and the other side's address.
/// dart gives a socket no own address (a client one reports the address it dialed, an accepted one the bound 0.0.0.0),
/// so a proof covers the checking side's address as the proving socket sees it, and that side checks it against [listOwnAddresses].
class _ConnectionEndpoints {
  /// see [_canonicalBytesOf].
  final Uint8List peerAddress;
  final int clientPort;
  final int serverPort;

  const _ConnectionEndpoints(this.peerAddress, {required this.clientPort, required this.serverPort});

  /// null once the socket closed, its getters throw then.
  static _ConnectionEndpoints? read(Socket socket, {required bool isServerSide}) {
    try {
      final peerAddress = _canonicalBytesOf(socket.remoteAddress);
      final localPort = socket.port;
      final remotePort = socket.remotePort;
      if (isServerSide) return _ConnectionEndpoints(peerAddress, clientPort: remotePort, serverPort: localPort);
      return _ConnectionEndpoints(peerAddress, clientPort: localPort, serverPort: remotePort);
    } catch (_) {
      return null;
    }
  }

  /// every address of this device, none when listing fails: no proof checks then.
  static Future<List<Uint8List>> listOwnAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(includeLoopback: true, includeLinkLocal: true);
      return interfaces.expand((e) => e.addresses).map(_canonicalBytesOf).toFixedList();
    } catch (_) {
      return const [];
    }
  }

  /// raw bytes, so the letter case of an ipv6 never matters, and an ipv4-mapped ipv6 (`::ffff:a.b.c.d`, how a dual stack socket reports an ipv4 peer) as its ipv4.
  static Uint8List _canonicalBytesOf(InternetAddress address) {
    final raw = address.rawAddress;
    if (raw.length != 16) return raw;
    for (int i = 0; i < 10; i++) {
      if (raw[i] != 0) return raw;
    }
    if (raw[10] != 0xFF || raw[11] != 0xFF) return raw;
    return Uint8List.sublistView(raw, 12);
  }
}

enum _PairingDecision {
  /// the user decides: a device without a pair secret, a paired one that failed its proof, or auto accepting is off.
  prompt,

  /// a pair secret is stored, the peer must prove it.
  challenge,

  /// the peer proved the pair secret on this socket.
  trust,

  /// a server we hold no secret for, on a connection the user started: trusted without a proof, the client stores the secret it issued.
  trustAndPair,
}
