part of 'sync_manager.dart';

class SyncDiscovery {
  SyncDiscovery._();

  static final client = _ClientSide();
  static final server = _ServerSide();

  static final anyDeviceConnected = false.obs;

  static final anySessionDevice = false.obs;

  static final serverRunning = false.obs;

  /// progress of the batches we are sending, keyed by receiver device id.
  /// maintained by [SyncBatch], which owns the state.
  static final batchProgressOutgoingRx = <String, BatchInfoMessage?>{}.obs;

  /// progress of the batches being sent to us, keyed by sender device id.
  /// it's just the last snapshot received, see [BatchInfoMessage].
  static final batchProgressIncomingRx = <String, BatchInfoMessage?>{}.obs;

  static void clearProgressFor(String deviceId) {
    batchProgressOutgoingRx[deviceId] = null;
    batchProgressIncomingRx[deviceId] = null;
  }

  static void _updateConnectionFlags() {
    anyDeviceConnected.value = client._connectedServers.isNotEmpty || server._clientsSockets.isNotEmpty;
  }

  /// android drops multicast packets unless a lock is held, needed while advertising or discovering.
  static void _updateMulticastLock() {
    final needed = serverRunning.value || client._isDiscovering || client._allowAutoRetryDiscovery;
    NamidaChannel.inst.setMulticastLock(needed);
  }

  static void autoRestoreOnStartup() async {
    if (!settings.sync.autoReconnect.value) return;
    if (settings.sync.serverWasRunning.value) {
      try {
        await server.startServer();
      } catch (e, st) {
        logger.error('failed to auto start sync server', e: e, st: st);
      }
    }
    if (settings.sync.allowedServerIds.value.isNotEmpty) {
      client.startSearchForServers(onlyOnce: true);
    }
  }

  static Future<void> sendMessage(BaseMessage message, String receiverDeviceId) async {
    // -- useful for message-to-message communication, where in between linking is not clear wether it's from
    // -- a server or a client. could be possible to embed this info but general solution is better ig.
    // -- ex: manifest request (A to B) -> manifest response (B to A) -> data send (A to B)
    // -- after the first step, it's not known if data should be sent to a client or a server (both have different handling)

    final serverSocket = client._connectedServers[receiverDeviceId];
    if (serverSocket != null) {
      try {
        final sentBytes = await serverSocket.send(message);
        SyncActionsLog.inst.onMessageActivity(.sent, message, receiverDeviceId, sentBytes);
      } catch (e) {
        SyncActionsLog.inst.markFailed(.sent, receiverDeviceId);
        rethrow;
      }
      return;
    }

    if (server._clientsSockets[receiverDeviceId] == null) {
      throw DeviceNotConnectedException(receiverDeviceId);
    }

    await server.sendMessageToClient(message, receiverDeviceId);
  }

  /// ids of all connected devices, both servers we connected to & clients connected to our server.
  static Set<String> getAllConnectedDeviceIdsSet() => {
    ...client._connectedServers.keys,
    ...server._clientsSockets.keys,
  };

  /// devices that connected at some point during this session, kept even after
  /// disconnecting so they can be reconnected.
  static final sessionDevices = <String, SyncDeviceView>{};

  static void _recordSessionDevice(
    String deviceId, {
    NetworkDevice? networkDevice,
    String? remoteAddress,
    bool asClient = false,
    bool asServer = false,
  }) {
    final info = sessionDevices[deviceId] ??= SyncDeviceView(deviceId);
    if (networkDevice != null) info.networkDevice = networkDevice;
    if (remoteAddress != null) info.remoteAddress = remoteAddress;
    if (asClient) info.asClient = true;
    if (asServer) info.asServer = true;
    anySessionDevice.value = true;
  }

  /// receive progress `(received, total)` of the socket connected to [deviceId].
  static RxBaseCore<(int, int)?>? receiveProgressOf(String deviceId) {
    final clientSideRx = client._connectedServers[deviceId]?._reader?.currentProgress;
    if (clientSideRx != null) return clientSideRx;
    return server._clientsSockets[deviceId]?._reader?.currentProgress;
  }
}

class _ServerSide extends RxNotifier {
  ServerWrapper? get serverWrapper => _serverWrapper;

  ServerWrapper? _serverWrapper;

  void _refresh() => super.refresh();

  bool isDeviceAllowed(NetworkDevice device) => settings.sync.allowedDeviceIds.value.contains(device.deviceId);
  bool isDeviceBlocked(NetworkDevice device) => settings.sync.blockedClientIds.value.contains(device.deviceId);

  /// trusted clients only, see [_PairingSession].
  final _clientsSockets = <String, _SocketWrapper>{};

  /// every open client socket, trusted or still in its handshake.
  final _sessions = <_PairingSession>{};

  Future<void> startServer() async {
    await stopServer(andRefresh: false);

    final serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, SyncUtils.kDefaultNamidaPort);
    serverSocket.listen(_onClientSocket);

    _serverWrapper = await ServerWrapper.startBroadcast(serverSocket);
    SyncDiscovery.serverRunning.value = true;
    SyncDiscovery._updateMulticastLock();

    if (!settings.sync.serverWasRunning.value) {
      settings.sync.serverWasRunning.save(true);
    }

    _refresh();
  }

  _PairingSession _onClientSocket(Socket socket) {
    final session = _PairingSession.server(socket);
    _sessions.add(session);
    session.listen(onClosed: () => _onSessionClosed(session));
    return session;
  }

  void _onSessionClosed(_PairingSession session) {
    _sessions.remove(session);
    _removeClientBySocket(session.socket);
  }

  void _removeClientBySocket(Socket socket) {
    final removedIds = <String>[];
    _clientsSockets.removeWhere((id, s) {
      if (s._socket == socket) {
        removedIds.add(id);
        return true;
      }
      return false;
    });
    if (removedIds.isNotEmpty) {
      removedIds.loop(SyncSender.inst.onDeviceDisconnected);
      SyncDiscovery._updateConnectionFlags();
      _refresh();
    }
  }

  Future<void> stopServer({bool andRefresh = true}) async {
    if (settings.sync.serverWasRunning.value) {
      settings.sync.serverWasRunning.save(false);
    }
    final sw = _serverWrapper;
    _serverWrapper = null;
    SyncDiscovery.serverRunning.value = false;
    SyncDiscovery._updateMulticastLock();
    if (andRefresh) _refresh();
    await sw?.stopAll();

    final clientIds = _clientsSockets.keys.toFixedList();
    final sessions = _sessions.toFixedList();
    _clientsSockets.clear();
    _sessions.clear();
    SyncDiscovery._updateConnectionFlags();
    if (andRefresh) _refresh();
    clientIds.loop(SyncSender.inst.onDeviceDisconnected);
    for (final session in sessions) {
      try {
        final c = session.socket;
        await c.close();
        c.destroy();
      } catch (_) {}
    }
  }

  Future<void> sendMessageToClient(BaseMessage message, String clientDeviceId) async {
    final socketWrapper = _clientsSockets[clientDeviceId];

    if (socketWrapper == null) {
      // -- attempt to send a message without being connected. the clients needs to send
      // -- a connection request and we need to accept it before communicating
      if (_kEnableSyncDebug) _debugNotify('no active socket for client $clientDeviceId, did u connect?\n${_clientsSockets.keys.toFixedList()}', isError: true);
      return;
    }
    try {
      final sentBytes = await socketWrapper._writer.sendMessage(message);
      SyncActionsLog.inst.onMessageActivity(.sent, message, clientDeviceId, sentBytes);
      if (_kEnableSyncDebug) _debugNotify('sent msg to client $clientDeviceId: ${message._encodeToMap()}');
    } catch (e) {
      SyncActionsLog.inst.markFailed(.sent, clientDeviceId);
      if (_kEnableSyncDebug) _debugNotify('X failed to send msg (${message.runtimeType}) to client $clientDeviceId: $e', isError: true);
    }
  }

  /// trusts the client on this socket, its data messages pass [_FrameDispatcher] now.
  /// [shouldIssueSecret] pairs it anew, the only time a pair secret travels.
  Future<void> _acceptSession(_PairingSession session, String clientDeviceId, {required bool shouldIssueSecret}) async {
    final secret = shouldIssueSecret ? _Handshake.newSecret() : null;
    final msg = await ConnectionRequestMessage.createForCurrentDevice(.accepted, secret: secret);
    if (session.isClosed || session.isTrusted) return;
    final encodedSecret = secret == null ? null : base64Encode(secret);
    settings.sync.transaction(() {
      settings.sync.allowDevice(clientDeviceId, issuedSecret: encodedSecret);
      settings.sync.updateDeviceName(clientDeviceId, session.peerName);
    });
    final wrapper = session.trust(clientDeviceId);
    final sending = session.send(msg); // -- queued ahead of anything sent once registered
    final existing = _clientsSockets[clientDeviceId];
    _clientsSockets[clientDeviceId] = wrapper;
    if (existing != null) {
      // -- device reconnected on a new socket while the old one never closed
      // -- (ex: abrupt app kill), treat as a fresh connection: clears sent
      // -- fingerprints tracking & completes stale log entries.
      SyncSender.inst.onDeviceDisconnected(clientDeviceId);
      try {
        existing._socket.destroy();
      } catch (_) {}
    }
    SyncDiscovery._recordSessionDevice(clientDeviceId, remoteAddress: wrapper.remoteAddressSafe, asServer: true);
    SyncDiscovery._updateConnectionFlags();
    _refresh();
    await sending;
  }

  /// forgets the device with its pair secret, it has to be approved again. its sockets are told & closed.
  Future<void> rejectConnection(String deviceId, {String? reason}) async {
    settings.sync.forgetDevice(deviceId);
    _refresh();
    await _closeSessionsOf(deviceId, .rejected, reason: reason);
  }

  /// turns down this socket only, the device stays paired & connected on its other sockets.
  Future<void> _refuseSession(_PairingSession session) async {
    final msg = await ConnectionRequestMessage.createForCurrentDevice(.rejected);
    await session.send(msg);
    await session.close();
  }

  /// blocks & forgets the device, both as a client of ours and as a server we connected to.
  Future<void> blockConnection(String deviceId) async {
    settings.sync.transaction(() {
      settings.sync.blockedClientIds.update((ids) => ids.add(deviceId));
      settings.sync.forgetDevice(deviceId);
    });
    _refresh();
    await _closeSessionsOf(deviceId, .blocked);
    await SyncDiscovery.client.disconnectFromServer(deviceId);
  }

  /// remove client device id from blocked
  Future<void> unblockConnection(String senderDeviceId) async {
    settings.sync.blockedClientIds.update((ids) => ids.remove(senderDeviceId));
    _refresh();

    final msg = await ConnectionRequestMessage.createForCurrentDevice(.unblocked);
    await sendMessageToClient(msg, senderDeviceId);
  }

  /// client is just telling us they will be gone.. (most likely we kicked them hehe)
  Future<void> disconnectConnection(String senderDeviceId) async {
    SyncDiscovery.clearProgressFor(senderDeviceId);
    final wrapper = _clientsSockets.remove(senderDeviceId);
    if (wrapper == null) return;
    SyncSender.inst.onDeviceDisconnected(senderDeviceId);
    SyncDiscovery._updateConnectionFlags();
    _refresh();
    try {
      await wrapper._socket.close();
      wrapper._socket.destroy();
    } catch (_) {}
  }

  /// the client leaves this socket only, a newer socket of the same device stays.
  Future<void> _onDisconnectRequest(_PairingSession session, String clientDeviceId) async {
    final isRegistered = _clientsSockets[clientDeviceId]?._socket == session.socket;
    if (isRegistered) return disconnectConnection(clientDeviceId);
    await session.close();
  }

  /// every socket of [deviceId] gets [connectionType] then closes, the trusted one included.
  Future<void> _closeSessionsOf(String deviceId, ConnectionRequestMessageType connectionType, {String? reason}) async {
    final sessions = _sessions.where((e) => e.peerId == deviceId).toFixedList();
    if (sessions.isEmpty) return;
    final msg = await ConnectionRequestMessage.createForCurrentDevice(connectionType, reason: reason);
    for (final session in sessions) {
      await session.send(msg);
    }
    await disconnectConnection(deviceId);
    for (final session in sessions) {
      await session.close();
    }
  }
}

class _ClientSide extends RxNotifier {
  List<NetworkDevice> get availableServers => _availableServers;
  bool get isDiscovering => _isDiscovering;
  bool get allowAutoRetryDiscovery => _allowAutoRetryDiscovery;
  int get connectedDevicesCount => _connectedServers.length;
  Object? get lastDiscoveryError => _lastDiscoveryError;

  bool isConnectedToServer(NetworkDevice device) => _connectedServers.containsKey(device.deviceId);

  void _refresh() => super.refresh();

  var _availableServers = <NetworkDevice>[];
  bool _isDiscovering = false;
  bool _allowAutoRetryDiscovery = true;
  Object? _lastDiscoveryError;
  final _connectedServers = <String, _SocketWrapper>{};

  /// servers whose handshake is still running, see [_PairingSession].
  final _pendingServers = <String, _PairingSession>{};

  Timer? _autoDiscoveryTimer;

  // ======================== CLIENT SIDE ========================

  /// [onlyOnce] runs one scan without scheduling auto retries (used at app startup)
  Future<void> startSearchForServers({bool onlyOnce = false}) async {
    if (_isDiscovering) {
      // -- convert an ongoing onlyOnce scan to a retrying one
      if (!onlyOnce && !_allowAutoRetryDiscovery) {
        _allowAutoRetryDiscovery = true;
        _refresh();
      }
      return;
    }
    _isDiscovering = true;
    _allowAutoRetryDiscovery = !onlyOnce;
    SyncDiscovery._updateMulticastLock();
    _refresh();

    _reconnectManualServers();

    final newAvailableServers = <NetworkDevice>[];
    void onFinish([Object? error]) {
      _autoDiscoveryTimer?.cancel();
      if (_allowAutoRetryDiscovery) {
        _autoDiscoveryTimer = Timer(
          newAvailableServers.isEmpty ? const Duration(seconds: 2) : const Duration(seconds: 8),
          startSearchForServers,
        );
      }

      if (_isDiscovering) {
        _isDiscovering = false;
        _availableServers = newAvailableServers;
        _lastDiscoveryError = error;
        SyncDiscovery._updateMulticastLock();
        _refresh();
      }
    }

    late final localeInterfacesSet = SyncUtils.getLocalInterfaceAddresses();
    Future<bool> isSelf(NetworkDevice s) async {
      if (kDebugMode && isKuru && Platform.isWindows) return false;
      final discoveredAddress = s.address;
      final interfacesSet = await localeInterfacesSet;
      if (interfacesSet.contains(discoveredAddress)) return true;
      return false;
    }

    final Stream<ServiceEntry> stream;
    try {
      stream = await SyncUtils._queryServers(await SyncUtils.getPreferredInterface());
    } catch (e) {
      onFinish(e);
      return;
    }
    stream.listen(
      (service) async {
        final device = NetworkDevice.fromService(service);
        if (device == null) return;
        if (await isSelf(device)) return;
        newAvailableServers.add(device);

        // -- just extra to make server appear faster for most cases
        if (_availableServers.isEmpty) {
          _availableServers.add(device);
          _refresh();
        }

        // -- keep reconnect info fresh in case the device address changed, the saved address follows once trusted
        SyncDiscovery.sessionDevices[device.deviceId]?.networkDevice = device;

        _autoReconnectIfKnown(device);
      },
      onDone: onFinish,
      onError: onFinish,
    );
  }

  void _reconnectManualServers() {
    for (final e in settings.sync.manualServerAddresses.value.entries) {
      _autoReconnectIfKnown(NetworkDevice._fromAddress(e.value, deviceId: e.key));
    }
  }

  Future<void> connectToAddress(String host) async {
    final session = await _PairingSession.connect(host, SyncUtils.kDefaultNamidaPort, onClosed: _onSessionClosed);
    await session.sendConnect();
  }

  /// the server and its name are saved only once trusted, see [_onServerTrusted]. until then they are just a claim.
  void _onAddressSessionIdentified(_PairingSession session, ConnectionRequestMessage reply, String host) {
    final serverDeviceId = reply.messageInfo.senderDeviceId;
    _setPending(serverDeviceId, session);
    final networkDevice = NetworkDevice._fromAddress(host, deviceId: serverDeviceId, deviceName: reply.senderDeviceName);
    SyncDiscovery._recordSessionDevice(serverDeviceId, networkDevice: networkDevice, asClient: true);
    _refresh();
  }

  /// a newer attempt replaces an unfinished one.
  void _setPending(String serverDeviceId, _PairingSession session) {
    final stale = _pendingServers[serverDeviceId];
    _pendingServers[serverDeviceId] = session;
    stale?.close();
  }

  Future<void> stopSearch() async {
    _autoDiscoveryTimer?.cancel();
    _allowAutoRetryDiscovery = false;
    _isDiscovering = false;
    SyncDiscovery._updateMulticastLock();
    _refresh();
  }

  final _autoReconnectAttempted = <String>{};

  void _autoReconnectIfKnown(NetworkDevice device) {
    if (!settings.sync.autoReconnect.value) return;
    final deviceId = device.deviceId;
    if (_connectedServers.containsKey(deviceId) || _pendingServers.containsKey(deviceId)) return;
    if (!settings.sync.allowedServerIds.value.contains(deviceId)) return;
    if (!_autoReconnectAttempted.add(deviceId)) return;
    _connectToServer(device, forceReconnect: false, isAutoReconnect: true).catchError((_) {
      _autoReconnectAttempted.remove(deviceId); // -- can retry on next discovery
    });
  }

  /// socket died without an explicit disconnect (server stopped, network lost, we got kicked..)
  void _onSessionClosed(_PairingSession session) {
    final serverDeviceId = session.peerId;
    if (serverDeviceId == null) return;
    if (_pendingServers[serverDeviceId] == session) {
      _pendingServers.remove(serverDeviceId);
      _autoReconnectAttempted.remove(serverDeviceId); // -- can auto reconnect when discovered again
      _refresh();
      return;
    }
    if (_connectedServers[serverDeviceId]?._socket != session.socket) return; // -- already replaced by a newer socket
    _autoReconnectAttempted.remove(serverDeviceId); // -- can auto reconnect when discovered again
    _connectedServers.remove(serverDeviceId);
    SyncSender.inst.onDeviceDisconnected(serverDeviceId);
    SyncDiscovery._updateConnectionFlags();
    _refresh();
  }

  Future<void> connectToServer(NetworkDevice serverDevice, {bool forceReconnect = false}) {
    return _connectToServer(serverDevice, forceReconnect: forceReconnect, isAutoReconnect: false);
  }

  /// the server is saved for auto reconnect only once trusted, see [_onServerTrusted].
  Future<void> _connectToServer(NetworkDevice serverDevice, {required bool forceReconnect, required bool isAutoReconnect}) async {
    final serverDeviceId = serverDevice.deviceId;
    if (forceReconnect) {
      await disconnectFromServer(serverDeviceId, removeFromAutoReconnect: false);
    } else if (_connectedServers.containsKey(serverDeviceId)) {
      return;
    }

    final session = await _PairingSession.connect(
      serverDevice.address,
      serverDevice.port,
      serverDeviceId: serverDeviceId,
      isAutoReconnect: isAutoReconnect,
      onClosed: _onSessionClosed,
    );
    _setPending(serverDeviceId, session);
    SyncDiscovery._recordSessionDevice(serverDeviceId, networkDevice: serverDevice, asClient: true);
    _refresh();
    await session.sendConnect();
  }

  Future<void> disconnectFromServer(String serverDeviceId, {bool removeFromAutoReconnect = true}) async {
    _autoReconnectAttempted.remove(serverDeviceId);
    if (removeFromAutoReconnect) {
      settings.sync.transaction(() {
        settings.sync.allowedServerIds.update((ids) => ids.remove(serverDeviceId));
        settings.sync.manualServerAddresses.update((addresses) => addresses.remove(serverDeviceId));
      });
    }

    SyncDiscovery.clearProgressFor(serverDeviceId);

    final pending = _pendingServers.remove(serverDeviceId);
    if (pending != null) await pending.close();

    final socket = _connectedServers.remove(serverDeviceId);
    if (socket != null) {
      SyncSender.inst.onDeviceDisconnected(serverDeviceId);
      SyncDiscovery._updateConnectionFlags();
      try {
        final msg = await ConnectionRequestMessage.createForCurrentDevice(.disconnect);
        await socket.send(msg);
      } catch (_) {}
      await socket.dispose();
    }

    _refresh();
  }

  Future<void> sendMessageToServer(BaseMessage message, NetworkDevice device) async {
    final socket = _connectedServers[device.deviceId];
    if (socket == null) throw DeviceNotConnectedException(device.deviceId);
    await socket.send(message);
  }

  Future<void> sendMessageToAllConnected(BaseMessage message) async {
    for (final socket in _connectedServers.values) {
      await socket.send(message);
    }
  }

  /// the server proved its pair secret or the user trusts it, its data messages pass [_FrameDispatcher] now.
  /// [issuedSecret] is a new pair secret from the server.
  void _onServerTrusted(_PairingSession session, String serverDeviceId, List<int>? issuedSecret) {
    if (session.isClosed || session.isTrusted) return;
    if (_pendingServers[serverDeviceId] == session) _pendingServers.remove(serverDeviceId);
    final wasAllowed = settings.sync.allowedDeviceIds.value.contains(serverDeviceId);
    final encodedSecret = issuedSecret == null ? null : base64Encode(issuedSecret);
    final manualAddress = session._manualAddress;
    settings.sync.transaction(() {
      settings.sync.allowDevice(serverDeviceId, receivedSecret: encodedSecret);
      settings.sync.updateDeviceName(serverDeviceId, session.peerName);
      if (!settings.sync.allowedServerIds.value.contains(serverDeviceId)) settings.sync.allowedServerIds.update((ids) => ids.add(serverDeviceId));
      final dialedAddress = session._dialedAddress;
      if (manualAddress != null) {
        settings.sync.manualServerAddresses.update((addresses) => addresses[serverDeviceId] = manualAddress);
      } else if (dialedAddress != null) {
        settings.sync.updateManualServerAddress(serverDeviceId, dialedAddress);
      }
      if (dialedAddress != null) settings.sync.takeOverServerAddress(serverDeviceId, dialedAddress);
    });
    final wrapper = session.trust(serverDeviceId);
    final existing = _connectedServers[serverDeviceId];
    _connectedServers[serverDeviceId] = wrapper;
    if (existing != null) {
      // -- the server replaces its side with the newest socket, so the old one is dead anyway
      SyncSender.inst.onDeviceDisconnected(serverDeviceId);
      existing._socket.destroy();
    }
    SyncDiscovery._updateConnectionFlags();
    _refresh();
    if (wasAllowed) return; // -- routine reconnect, no need to announce
    snackyy(
      icon: Broken.tick_circle,
      title: '${lang.connectionAccepted} - ${session.peerName}',
      message: lang.youCanNowSendAndReceiveDataWithThisDevice,
      borderColor: Colors.green.withOpacityExt(0.4),
      isError: false,
    );
  }

  /// closes this socket only, the saved server & its trusted socket stay.
  /// auto reconnect skips the server for this run, else every discovery would connect again.
  Future<void> _refuseSession(_PairingSession session, String serverDeviceId) async {
    if (_pendingServers[serverDeviceId] == session) {
      _pendingServers.remove(serverDeviceId);
      _autoReconnectAttempted.add(serverDeviceId);
      _refresh();
    }
    await session.close();
  }

  /// the socket that speaks for [serverDeviceId]: its trusted one, else the pending handshake.
  bool _isCurrentSession(_PairingSession session, String serverDeviceId) {
    final connected = _connectedServers[serverDeviceId];
    if (connected != null) return connected._socket == session.socket;
    return _pendingServers[serverDeviceId] == session;
  }

  /// only the trusted socket drops the saved server, an unproven one may be anyone claiming its id, so it only pauses auto reconnect for this run.
  Future<void> _onTurnedDown(_PairingSession session, String serverDeviceId) {
    if (session.isTrusted) return disconnectFromServer(serverDeviceId);
    return _refuseSession(session, serverDeviceId);
  }

  Future<void> _onConnectionRejected(_PairingSession session, ConnectionRequestMessage msg) async {
    // -- server just kicked us
    final serverDeviceId = msg.messageInfo.senderDeviceId;
    if (!_isCurrentSession(session, serverDeviceId)) return session.close();
    final version = msg.version;

    String? reasonMessage = msg.reason;
    if (reasonMessage == null) {
      if (version != SyncUtils.kSyncVersion) {
        reasonMessage = lang.versionMismatchMakeSureBothAppsAreOnTheSameVersion;
      }
    }

    VibratorController.high();

    snackyy(
      icon: Broken.warning_2,
      title: '${lang.connectionRejected} - ${msg.senderDeviceName}',
      message: [
        lang.serverRejectedTheConnectionRequest,
        if (reasonMessage != null) '${lang.reason}: $reasonMessage',
      ].join('\n'),
      borderColor: Colors.red.withOpacityExt(0.4),
      isError: true,
    );

    await _onTurnedDown(session, serverDeviceId);
  }

  Future<void> _onConnectionBlocked(_PairingSession session, ConnectionRequestMessage msg) async {
    // -- server just blocked us
    final serverDeviceId = msg.messageInfo.senderDeviceId;
    if (!_isCurrentSession(session, serverDeviceId)) return session.close();

    if (kDebugMode || isKuru) {
      String? reasonMessage = msg.reason;
      snackyy(
        icon: Broken.warning_2,
        title: '${lang.connectionBlocked} - ${msg.senderDeviceName}',
        message: [
          lang.serverBlockedThisDevice,
          if (reasonMessage != null) '${lang.reason}: $reasonMessage',
        ].join('\n'),
        borderColor: Colors.red.withOpacityExt(0.4),
        isError: true,
      );
    }

    await _onTurnedDown(session, serverDeviceId);
  }

  Future<void> onConnectionUnBlocked(ConnectionRequestMessage msg) async {
    // -- do nothing
  }
}

class _SocketWrapper {
  final String deviceId;
  final Socket _socket;
  final _FrameWriter _writer;
  final _FrameReader? _reader;

  const _SocketWrapper({
    required this.deviceId,
    required this._socket,
    required this._writer,
    this._reader,
  });

  String? get remoteAddressSafe => _remoteAddressOf(_socket);

  static String? _remoteAddressOf(Socket socket) {
    try {
      return socket.remoteAddress.address;
    } catch (_) {
      return null;
    }
  }

  static void _listen(Socket socket, _FrameReader reader, _FrameDispatcher dispatcher, {required void Function() onClosed}) {
    reader.frames.listen(
      dispatcher.onFrame,
      onError: (_) {
        // -- malformed/desynced stream, nothing more can be read off this socket.
        try {
          socket.destroy();
        } catch (_) {}
      },
    );
    socket.listen(
      reader.addBytes,
      onDone: () {
        reader.close();
        onClosed();
      },
      onError: (_) {
        reader.close();
        onClosed();
      },
    );
  }

  /// returns the total bytes written, see [_FrameWriter.sendMessage].
  Future<int> send(BaseMessage message) {
    return _writer.sendMessage(message);
  }

  Future<void> dispose() async {
    await _writer.closeSocket();
    SyncDiscovery.clearProgressFor(deviceId);
  }
}

/// per-connection frame dispatcher: decodes json frames, and attaches raw
/// binary frames to their preceding [BinaryPayloadMessage] before executing it.
/// connection messages always go to the socket's [_PairingSession], anything else only once it trusts the sender.
class _FrameDispatcher {
  final _PairingSession _session;

  _FrameDispatcher(this._session);

  BinaryPayloadMessage? _pendingBinaryMessage;

  void onFrame((int, Uint8List) frame) {
    final (kind, bytes) = frame;
    if (kind == _FrameWriter.kFrameKindJson) return _onJsonFrame(bytes);
    if (kind == _FrameWriter.kFrameKindBinary) return _onBinaryFrame(bytes);
    if (_kEnableSyncDebug) _debugNotify('X Unknown frame kind $kind (${bytes.length.fileSizeFormatted})', isError: true);
  }

  void _onJsonFrame(Uint8List data) {
    try {
      final msg = BaseMessage.decodeBytes(data, _session.trustedIds, settings.sync.blockedClientIds.value);
      if (msg is ConnectionRequestMessage) {
        _session.onMessage(msg).catchError((e, st) {
          logger.error('Error handling connection message', e: e, st: st);
        });
        return;
      }
      SyncActionsLog.inst.onMessageActivity(.received, msg, msg.messageInfo.senderDeviceId, _FrameWriter.kFrameHeaderSize + data.length);
      if (msg is BinaryPayloadMessage) {
        // -- execution is deferred until its binary payload frame arrives
        _pendingBinaryMessage = msg;
      } else if (msg.type.carriesSenderPaths && !SyncPathResolver.hasFingerprintsFor(msg.messageInfo.senderDeviceId)) {
        // -- we can't translate their paths yet (ex: we restarted while they
        // -- still think we have their fingerprints), request & defer execution
        SyncPathResolver.stashUntilFingerprints(msg);
      } else {
        msg.executeOnReceivedWithQueue().catchError((e, st) {
          logger.error('Error executing json payload message', e: e, st: st);
        });
      }
      if (_kEnableSyncDebug) _debugNotify('✔ Received | ${msg.runtimeType}(${data.length.fileSizeFormatted}):\n${msg.toRawInfo()}');
    } on NonAllowedMessageException catch (e) {
      if (_kEnableSyncDebug) _debugNotify('X Not Allowed | _(${data.length.fileSizeFormatted}): $e');
    } on BlockedMessageException catch (e) {
      if (_kEnableSyncDebug) _debugNotify('X Blocked | _(${data.length.fileSizeFormatted}): $e');
    } catch (e, st) {
      if (_kEnableSyncDebug) _debugNotify('X Error | _(${data.length.fileSizeFormatted}): $e');
      logger.error('Error decoding message from frame', e: e, st: st);
    }
  }

  void _onBinaryFrame(Uint8List data) {
    final pending = _pendingBinaryMessage;
    _pendingBinaryMessage = null;
    if (pending == null) {
      // -- owning message got rejected or never sent, drop the payload
      if (_kEnableSyncDebug) _debugNotify('X Binary frame with no owning message (${data.length.fileSizeFormatted})', isError: true);
      return;
    }
    SyncActionsLog.inst.onMessageActivity(.received, pending, pending.messageInfo.senderDeviceId, _FrameWriter.kFrameHeaderSize + data.length, isExtraPayload: true);
    // -- no copy needed, the reader detaches its buffer for binary frames
    pending.binaryPayload = data;

    pending.executeOnReceivedWithQueue().catchError((e, st) {
      logger.error('Error executing binary payload message', e: e, st: st);
    });

    if (_kEnableSyncDebug) _debugNotify('✔ Received binary payload (${data.length.fileSizeFormatted}) for ${pending.runtimeType}');
  }
}

void _debugNotify(String msg, {bool isError = false}) {
  if (kDebugMode) {
    if (isError) {
      print('--> SYNC ERROR: $msg');
    } else {
      print('--> SYNC INFO: $msg');
    }
  }
}

const _kEnableSyncDebug = false;
