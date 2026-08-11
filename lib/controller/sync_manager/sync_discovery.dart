part of 'sync_manager.dart';

class SyncDiscovery {
  SyncDiscovery._();

  static final client = _ClientSide();
  static final server = _ServerSide();

  static final anyDeviceConnected = false.obs;

  static final anySessionDevice = false.obs;

  static final serverRunning = false.obs;

  static void _updateConnectionFlags() {
    anyDeviceConnected.value = client._connectedServers.isNotEmpty || server._clientsSockets.isNotEmpty;
  }

  static void autoRestoreOnStartup() async {
    if (!settings.sync.autoReconnect.valueF) return;
    if (settings.sync.serverWasRunning) {
      try {
        await server.startServer();
      } catch (e, st) {
        logger.error('failed to auto start sync server', e: e, st: st);
      }
    }
    if (settings.sync.allowedServerIds.isNotEmpty) {
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

  bool isDeviceAllowed(NetworkDevice device) => settings.sync.allowedDeviceIds.contains(device.deviceId);
  bool isDeviceBlocked(NetworkDevice device) => settings.sync.blockedClientIds.contains(device.deviceId);

  final _clientsSockets = <String, _SocketWrapper>{};

  Future<void> startServer() async {
    await stopServer(andRefresh: false);

    final serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, SyncUtils.kDefaultNamidaPort);
    serverSocket.listen((socket) {
      final reader = _FrameReader();
      final dispatcher = _FrameDispatcher();
      reader.frames.listen((frame) {
        final msg = dispatcher.onFrame(frame);
        if (msg != null) {
          final senderDeviceId = msg.messageInfo.senderDeviceId;
          final existing = _clientsSockets[senderDeviceId];
          if (existing == null || existing._socket != socket) {
            if (existing != null) {
              // -- device reconnected on a new socket while the old one never closed
              // -- (ex: abrupt app kill), treat as a fresh connection: clears sent
              // -- fingerprints tracking & completes stale log entries.
              SyncSender.inst.onDeviceDisconnected(senderDeviceId);
              try {
                existing._socket.destroy();
              } catch (_) {}
            }
            final wrapper = _SocketWrapper.simple(socket, reader);
            _clientsSockets[senderDeviceId] = wrapper;
            SyncDiscovery._recordSessionDevice(senderDeviceId, remoteAddress: wrapper.remoteAddressSafe, asServer: true);
            SyncDiscovery._updateConnectionFlags();
            _refresh();
          }
        }
      });
      socket.listen(
        reader.addBytes,
        onDone: () {
          reader.close();
          _removeClientBySocket(socket);
        },
        onError: (_) {
          reader.close();
          _removeClientBySocket(socket);
        },
      );
    });

    _serverWrapper = await ServerWrapper.startBroadcast(serverSocket);
    SyncDiscovery.serverRunning.value = true;

    if (!settings.sync.serverWasRunning) {
      settings.sync.modify((syncSettings) => syncSettings.serverWasRunning = true);
    }

    _refresh();
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
    if (settings.sync.serverWasRunning) {
      settings.sync.modify((syncSettings) => syncSettings.serverWasRunning = false);
    }
    final sw = _serverWrapper;
    _serverWrapper = null;
    SyncDiscovery.serverRunning.value = false;
    if (andRefresh) _refresh();
    await sw?.stopAll();

    final clients = _clientsSockets.entries.toFixedList();
    _clientsSockets.clear();
    SyncDiscovery._updateConnectionFlags();
    if (andRefresh) _refresh();
    for (final e in clients) {
      SyncSender.inst.onDeviceDisconnected(e.key);
      try {
        final c = e.value._socket;
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

  /// mark client device id as trusted, [BaseMessage.decodeBytes] will accept it now
  Future<void> acceptConnection(String senderDeviceId) async {
    settings.sync.modify(
      (syncSettings) => syncSettings.allowedDeviceIds.add(senderDeviceId),
    );
    _refresh();

    final msg = await ConnectionRequestMessage.createForCurrentDevice(.accepted);
    await sendMessageToClient(msg, senderDeviceId);
  }

  /// remove client device id from trusted, [BaseMessage.decodeBytes] will throw
  Future<void> rejectConnection(String senderDeviceId, {String? reason}) async {
    settings.sync.modify(
      (syncSettings) => syncSettings.allowedDeviceIds.remove(senderDeviceId),
    );
    _refresh();

    final msg = await ConnectionRequestMessage.createForCurrentDevice(.rejected, reason: reason);
    await sendMessageToClient(msg, senderDeviceId);
  }

  /// add client device id to blocked, [BaseMessage.decodeBytes] will throw
  Future<void> blockConnection(String senderDeviceId) async {
    settings.sync.modify(
      (syncSettings) => syncSettings.blockedClientIds.add(senderDeviceId),
    );
    _refresh();

    final msg = await ConnectionRequestMessage.createForCurrentDevice(.blocked);
    await sendMessageToClient(msg, senderDeviceId);
    await disconnectConnection(senderDeviceId);
  }

  /// remove client device id from blocked
  Future<void> unblockConnection(String senderDeviceId) async {
    settings.sync.modify(
      (syncSettings) => syncSettings.blockedClientIds.remove(senderDeviceId),
    );
    _refresh();

    final msg = await ConnectionRequestMessage.createForCurrentDevice(.unblocked);
    await sendMessageToClient(msg, senderDeviceId);
  }

  /// client is just telling us they will be gone.. (most likely we kicked them hehe)
  Future<void> disconnectConnection(String senderDeviceId) async {
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
}

class _ClientSide extends RxNotifier {
  List<NetworkDevice> get availableServers => _availableServers;
  bool get isDiscovering => _isDiscovering;
  bool get allowAutoRetryDiscovery => _allowAutoRetryDiscovery;
  int get connectedDevicesCount => _connectedServers.length;

  bool isConnectedToServer(NetworkDevice device) => _connectedServers.containsKey(device.deviceId);

  void _refresh() => super.refresh();

  var _availableServers = <NetworkDevice>[];
  bool _isDiscovering = false;
  bool _allowAutoRetryDiscovery = true;
  final _connectedServers = <String, _SocketWrapper>{};

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
    _refresh();

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
        _refresh();
      }
    }

    late final localeInterfacesSet = SyncUtils.getLocalInterfaceAddresses();
    Future<bool> isSelf(NetworkDevice s) async {
      if (kDebugMode || isKuru) return false; // TODO: testing only
      final discoveredAddress = s.address;
      final interfacesSet = await localeInterfacesSet;
      if (interfacesSet.contains(discoveredAddress)) return true;
      return false;
    }

    final preferredInterface = await SyncUtils.getPreferredInterface();
    final params = QueryParams(
      service: SyncUtils.kDefaultServiceType,
      timeout: const Duration(seconds: 3),
      networkInterface: preferredInterface,
    );
    final stream = await MDNSClient.query(params);
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

        settings.sync.updateDeviceName(device.deviceId, device.deviceName);

        // -- keep reconnect info fresh in case the device address changed
        SyncDiscovery.sessionDevices[device.deviceId]?.networkDevice = device;

        _autoReconnectIfKnown(device);
      },
      onDone: onFinish,
      onError: onFinish,
    );
  }

  Future<void> stopSearch() async {
    _autoDiscoveryTimer?.cancel();
    _allowAutoRetryDiscovery = false;
    _isDiscovering = false;
    _refresh();
  }

  final _autoReconnectAttempted = <String>{};

  void _autoReconnectIfKnown(NetworkDevice device) {
    if (!settings.sync.autoReconnect.valueF) return;
    final deviceId = device.deviceId;
    if (_connectedServers.containsKey(deviceId)) return;
    if (!settings.sync.allowedServerIds.contains(deviceId)) return;
    if (!_autoReconnectAttempted.add(deviceId)) return;
    connectToServer(device).catchError((_) {
      _autoReconnectAttempted.remove(deviceId); // -- can retry on next discovery
    });
  }

  Future<_SocketWrapper> _getOrConnect(NetworkDevice serverDevice) async {
    final serverDeviceId = serverDevice.deviceId;
    final existing = _connectedServers[serverDeviceId];
    if (existing != null) return existing;

    final wrapper = await _SocketWrapper.connect(
      serverDevice,
      onClosed: () => _onSocketClosed(serverDeviceId),
    );
    _connectedServers[serverDeviceId] = wrapper;
    SyncDiscovery._recordSessionDevice(serverDeviceId, networkDevice: serverDevice, asClient: true);
    SyncDiscovery._updateConnectionFlags();
    _refresh();
    return wrapper;
  }

  /// socket died without an explicit disconnect (server stopped, network lost, we got kicked..)
  void _onSocketClosed(String serverDeviceId) {
    _autoReconnectAttempted.remove(serverDeviceId); // -- can auto reconnect when discovered again
    final removed = _connectedServers.remove(serverDeviceId);
    if (removed != null) {
      SyncSender.inst.onDeviceDisconnected(serverDeviceId);
      SyncDiscovery._updateConnectionFlags();
      _refresh();
    }
  }

  Future<void> connectToServer(NetworkDevice serverDevice, {bool forceReconnect = false}) async {
    final serverDeviceId = serverDevice.deviceId;
    if (!settings.sync.allowedServerIds.contains(serverDeviceId)) {
      settings.sync.modify(
        (syncSettings) => syncSettings.allowedServerIds.add(serverDeviceId),
      );
    }

    if (forceReconnect) {
      await disconnectFromServer(serverDeviceId);
    }

    final socket = await _getOrConnect(serverDevice);

    final msg = await ConnectionRequestMessage.createForCurrentDevice(.connect);
    await socket.send(msg);

    _refresh();
  }

  Future<void> disconnectFromServer(String serverDeviceId) async {
    _autoReconnectAttempted.remove(serverDeviceId);
    settings.sync.modify(
      (syncSettings) => syncSettings.allowedServerIds.remove(serverDeviceId),
    );

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
    final socket = await _getOrConnect(device);
    await socket.send(message);
  }

  Future<void> sendMessageToAllConnected(BaseMessage message) async {
    for (final socket in _connectedServers.values) {
      await socket.send(message);
    }
  }

  Future<void> onConnectionAccepted(ConnectionRequestMessage msg) async {
    // -- server just welcomed us. trust it so its data messages pass [BaseMessage.decodeBytes]
    final senderDeviceId = msg.messageInfo.senderDeviceId;
    if (settings.sync.allowedDeviceIds.contains(senderDeviceId)) return; // -- routine reconnect, no need to announce
    settings.sync.modify(
      (syncSettings) => syncSettings.allowedDeviceIds.add(senderDeviceId),
    );
    snackyy(
      icon: Broken.tick_circle,
      title: '${lang.connectionAccepted} - ${msg.senderDeviceName}',
      message: lang.youCanNowSendAndReceiveDataWithThisDevice,
      borderColor: Colors.green.withOpacityExt(0.4),
      isError: false,
    );
    // -- already connected
  }

  Future<void> onConnectionRejected(ConnectionRequestMessage msg) async {
    // -- server just kicked us
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

    await disconnectFromServer(msg.messageInfo.senderDeviceId);
  }

  Future<void> onConnectionBlocked(ConnectionRequestMessage msg) async {
    // -- server just blocked us

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

    await disconnectFromServer(msg.messageInfo.senderDeviceId);
  }

  Future<void> onConnectionUnBlocked(ConnectionRequestMessage msg) async {}
}

class _SocketWrapper {
  final Socket _socket;
  final _FrameWriter _writer;
  final _FrameReader? _reader;

  const _SocketWrapper({
    required this._socket,
    required this._writer,
    this._reader,
  });

  _SocketWrapper.simple(this._socket, [this._reader]) : _writer = _FrameWriter(_socket);

  String? get remoteAddressSafe {
    try {
      return _socket.remoteAddress.address;
    } catch (_) {
      return null;
    }
  }

  static Future<_SocketWrapper> connect(NetworkDevice device, {void Function()? onClosed}) {
    return _connectInternal(device, onClosed);
  }

  static Future<_SocketWrapper> _connectInternal(NetworkDevice device, void Function()? onClosed) async {
    final socket = await Socket.connect(device.address, device.port);
    final writer = _FrameWriter(socket);

    final reader = _FrameReader();
    final dispatcher = _FrameDispatcher();
    reader.frames.listen(dispatcher.onFrame);

    socket.listen(
      reader.addBytes,
      onDone: () {
        reader.close();
        onClosed?.call();
      },
      onError: (_) {
        reader.close();
        onClosed?.call();
      },
    );

    return _SocketWrapper(
      socket: socket,
      writer: writer,
      reader: reader,
    );
  }

  /// returns the total bytes written, see [_FrameWriter.sendMessage].
  Future<int> send(BaseMessage message) {
    return _writer.sendMessage(message);
  }

  Future<void> dispose() async {
    await _socket.close();
    _socket.destroy();
  }
}

/// per-connection frame dispatcher: decodes json frames, and attaches raw
/// binary frames to their preceding [BinaryPayloadMessage] before executing it.
class _FrameDispatcher {
  BinaryPayloadMessage? _pendingBinaryMessage;

  /// returns the decoded message for json frames only.
  BaseMessage? onFrame((int, Uint8List) frame) {
    final (kind, bytes) = frame;
    if (kind == _FrameWriter.kFrameKindJson) return _onJsonFrame(bytes);
    if (kind == _FrameWriter.kFrameKindBinary) return _onBinaryFrame(bytes);
    if (_kEnableSyncDebug) _debugNotify('X Unknown frame kind $kind (${bytes.length.fileSizeFormatted})', isError: true);
    return null;
  }

  BaseMessage? _onJsonFrame(Uint8List data) {
    try {
      final msg = BaseMessage.decodeBytes(data, settings.sync.allowedDeviceIds, settings.sync.blockedClientIds);
      SyncActionsLog.inst.onMessageActivity(.received, msg, msg.messageInfo.senderDeviceId, _FrameWriter.kFrameHeaderSize + data.length);
      if (msg is BinaryPayloadMessage) {
        // -- execution is deferred until its binary payload frame arrives
        _pendingBinaryMessage = msg;
      } else if (msg.type.carriesSenderPaths && !SyncPathResolver.hasFingerprintsFor(msg.messageInfo.senderDeviceId)) {
        // -- we can't translate their paths yet (ex: we restarted while they
        // -- still think we have their fingerprints), request & defer execution
        SyncPathResolver.stashUntilFingerprints(msg);
      } else {
        msg.executeOnReceived();
      }
      if (_kEnableSyncDebug) _debugNotify('✔ Received | ${msg.runtimeType}(${data.length.fileSizeFormatted}):\n${msg.toRawInfo()}');
      return msg;
    } on NonAllowedMessageException catch (e) {
      if (_kEnableSyncDebug) _debugNotify('X Not Allowed | _(${data.length.fileSizeFormatted}): $e');
    } on BlockedMessageException catch (e) {
      if (_kEnableSyncDebug) _debugNotify('X Blocked | _(${data.length.fileSizeFormatted}): $e');
    } catch (e, st) {
      if (_kEnableSyncDebug) _debugNotify('X Error | _(${data.length.fileSizeFormatted}): $e');
      logger.error('Error decoding message from frame', e: e, st: st);
    }
    return null;
  }

  BaseMessage? _onBinaryFrame(Uint8List data) {
    final pending = _pendingBinaryMessage;
    _pendingBinaryMessage = null;
    if (pending == null) {
      // -- owning message got rejected or never sent, drop the payload
      if (_kEnableSyncDebug) _debugNotify('X Binary frame with no owning message (${data.length.fileSizeFormatted})', isError: true);
      return null;
    }
    SyncActionsLog.inst.onMessageActivity(.received, pending, pending.messageInfo.senderDeviceId, _FrameWriter.kFrameHeaderSize + data.length, isExtraPayload: true);
    // -- no copy needed, the reader detaches its buffer for binary frames
    pending.binaryPayload = data;
    try {
      pending.executeOnReceived();
    } catch (e, st) {
      logger.error('Error executing binary payload message', e: e, st: st);
    }
    if (_kEnableSyncDebug) _debugNotify('✔ Received binary payload (${data.length.fileSizeFormatted}) for ${pending.runtimeType}');
    return null;
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
