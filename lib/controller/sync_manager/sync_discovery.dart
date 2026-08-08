part of 'sync_manager.dart';

class SyncDiscovery {
  SyncDiscovery._();

  static final client = _ClientSide();
  static final server = _ServerSide();

  static Future<void> sendMessage(BaseMessage message, String receiverDeviceId) async {
    // -- useful for message-to-message communication, where in between linking is not clear wether it's from
    // -- a server or a client. could be possible to embed this info but general solution is better ig.
    // -- ex: manifest request (A to B) -> manifest response (B to A) -> data send (A to B)
    // -- after the first step, it's not known if data should be sent to a client or a server (both have different handling)

    final serverSocket = client._connectedServers[receiverDeviceId];
    if (serverSocket != null) {
      await serverSocket.send(message);
      return;
    }

    await server.sendMessageToClient(message, receiverDeviceId);
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
    await stopServer();

    final serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, SyncUtils.kDefaultNamidaPort);
    serverSocket.listen((socket) {
      final reader = _FrameReader();
      reader.frames.listen((data) {
        _SharedSide._onFrameReceivedTrackSocket(data, socket, _clientsSockets);
      });
      socket.listen(
        reader.addBytes,
        onDone: () {
          reader.close();
          _clientsSockets.removeWhere((_, s) => s._socket == socket);
        },
        onError: (_) {
          reader.close();
          _clientsSockets.removeWhere((_, s) => s._socket == socket);
        },
      );
    });

    _serverWrapper = await ServerWrapper.startBroadcast(serverSocket);

    _refresh();
  }

  Future<void> stopServer() async {
    final sw = _serverWrapper;
    _serverWrapper = null;
    _refresh();
    await sw?.stopAll();

    final clients = _clientsSockets.values.toFixedList();
    _clientsSockets.clear();
    for (final wrapper in clients) {
      try {
        final c = wrapper._socket;
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
      _debugNotify('no active socket for client $clientDeviceId, did u connect?\n${_clientsSockets.keys.toFixedList()}', isError: true);
      return;
    }
    try {
      final writer = socketWrapper._writer;
      await writer.sendPayload(message.encodeBytes());
      _debugNotify('sent msg to client $clientDeviceId: ${message._encodeToMap()}');
    } catch (e) {
      _debugNotify('X failed to send msg (${message.runtimeType}) to client $clientDeviceId: $e', isError: true);
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
    // TODO:
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

  Future<void> startSearchForServers({bool allowAutoConnect = false}) async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _allowAutoRetryDiscovery = true;
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

        settings.sync.updateDeviceName(device.deviceId, device.name);
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

  Future<void> connectToServer(NetworkDevice serverDevice, {bool forceReconnect = false}) async {
    final serverDeviceId = serverDevice.deviceId;
    settings.sync.modify(
      (syncSettings) => syncSettings.allowedServerIds.add(serverDeviceId),
    );

    if (forceReconnect) {
      await disconnectFromServer(serverDeviceId);
    }

    final socket = _connectedServers[serverDeviceId] ??= await _SocketWrapper.connect(serverDevice);

    final msg = await ConnectionRequestMessage.createForCurrentDevice(.connect);
    await socket.send(msg);

    _refresh();
  }

  Future<void> disconnectFromServer(String serverDeviceId) async {
    settings.sync.modify(
      (syncSettings) => syncSettings.allowedServerIds.remove(serverDeviceId),
    );

    final msg = await ConnectionRequestMessage.createForCurrentDevice(.disconnect);
    final socket = _connectedServers[serverDeviceId];
    await socket?.send(msg);
    await socket?.dispose();
    _connectedServers.remove(serverDeviceId);

    _refresh();
  }

  Future<void> sendMessageToServer(BaseMessage message, NetworkDevice device) async {
    final serverDeviceId = device.deviceId;
    if (_connectedServers[serverDeviceId] == null) {
      _connectedServers[serverDeviceId] = await _SocketWrapper.connect(device);
      _refresh();
    }
    final socket = _connectedServers[serverDeviceId]!;
    await socket.send(message);
  }

  Future<void> sendMessageToAllConnected(BaseMessage message) async {
    for (final socket in _connectedServers.values) {
      await socket.send(message);
    }
  }

  Future<void> onConnectionAccepted(ConnectionRequestMessage msg) async {
    // -- server just welcomed us
    snackyy(
      icon: Broken.tick_circle,
      title: 'Connection Accepted - ${msg.senderDeviceName}',
      message: 'You can now send and receive data with this device',
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
        reasonMessage = 'Version mismatch, make sure both apps are on the same version';
      }
    }

    VibratorController.high();

    snackyy(
      icon: Broken.warning_2,
      title: 'Connection Rejected - ${msg.senderDeviceName}',
      message: [
        'Server rejected the connection request',
        if (reasonMessage != null) 'Reason: $reasonMessage',
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
        title: 'Connection Blocked - ${msg.senderDeviceName}',
        message: [
          'Server blocked this device',
          if (reasonMessage != null) 'Reason: $reasonMessage',
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

  const _SocketWrapper({
    required this._socket,
    required this._writer,
  });

  _SocketWrapper.simple(this._socket) : _writer = _FrameWriter(_socket);

  static Future<_SocketWrapper> connect(NetworkDevice device) {
    return _connectInternal(
      device.address,
      device.port,
    );
  }

  // static Future<_SocketWrapper> _connectInternal(String address, int port) async {
  //   final socket = await Socket.connect(address, port);
  //   final writer = _FrameWriter(socket);
  //   return _SocketWrapper(
  //     socket: socket,
  //     writer: writer,
  //   );
  // }

  static Future<_SocketWrapper> _connectInternal(String address, int port) async {
    final socket = await Socket.connect(address, port);
    final writer = _FrameWriter(socket);

    final reader = _FrameReader();
    reader.frames.listen(_SharedSide._onFrameReceived);

    socket.listen(
      reader.addBytes,
      onDone: reader.close,
      onError: (_) => reader.close(),
    );

    return _SocketWrapper(
      socket: socket,
      writer: writer,
    );
  }

  Future<void> send(BaseMessage message) async {
    final bytes = message.encodeBytes();
    await _writer.sendPayload(bytes);
  }

  Future<void> dispose() async {
    await _socket.close();
    _socket.destroy();
  }
}

class _SharedSide {
  static void _onFrameReceivedTrackSocket(Uint8List data, Socket socket, Map<String, _SocketWrapper> clientSockets) {
    final msg = _onFrameReceived(data);
    if (msg != null) {
      clientSockets[msg.messageInfo.senderDeviceId] = _SocketWrapper.simple(socket);
    }
  }

  static BaseMessage? _onFrameReceived(Uint8List data) {
    try {
      final msg = BaseMessage.decodeBytes(data, settings.sync.allowedDeviceIds, settings.sync.blockedClientIds);
      msg.executeOnReceived();
      _debugNotify('✔ Received | ${msg.runtimeType}(${data.length.fileSizeFormatted}):\n${msg.toRawInfo()}');
      return msg;
    } on NonAllowedMessageException catch (e) {
      _debugNotify('X Not Allowed | _(${data.length.fileSizeFormatted}): $e');
    } on BlockedMessageException catch (e) {
      _debugNotify('X Blocked | _(${data.length.fileSizeFormatted}): $e');
    } catch (e, st) {
      _debugNotify('X Error | _(${data.length.fileSizeFormatted}): $e');
      logger.error('Error decoding message from frame', e: e, st: st);
    }
    return null;
  }
}

void _debugNotify(String msg, {bool isError = false}) {
  if (isKuru) {
    snackyy(message: msg, isError: isError);
    if (kDebugMode) {
      if (isError) {
        print('--> SYNC ERROR: $msg');
      } else {
        print('--> SYNC INFO: $msg');
      }
    }
  }
}
