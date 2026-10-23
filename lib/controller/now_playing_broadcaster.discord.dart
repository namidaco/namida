// by claude
part of 'now_playing_broadcaster.dart';

class _DiscordPresenceSink extends _NowPlayingSink {
  _DiscordPresenceSink();

  static const _kApplicationId = '1560427410451599420';
  static const _kLargeImageAssetKey = 'namida_icon_full';
  static const _kActivityTypeListening = 2;
  static const _kTextMaxLength = 128;

  final _transport = _DiscordPresenceTransport.platform();
  Timer? _flushTimer;
  _NowPlayingEvent? _latestEvent;
  int _latestEventTimeMS = 0;

  @override
  void send(_NowPlayingEvent event) {
    _latestEvent = event;
    _latestEventTimeMS = DateTime.now().millisecondsSinceEpoch;
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(seconds: 1), _flush);
  }

  void onSeek(int positionMS) {
    final event = _latestEvent;
    if (event == null || !event.isPlaying) return;
    send(_NowPlayingEvent(event.media, event.type, event.isPlaying, positionMS));
  }

  void close() {
    _flushTimer?.cancel();
    _transport.close();
  }

  void probe() => _transport.probe();

  void resend() {
    _flushTimer?.cancel();
    _flush();
  }

  void _flush() {
    final event = _latestEvent;
    if (event == null) return;
    final activity = event.isPlaying ? _buildActivity(event, _latestEventTimeMS, _transport.supportsImageUrls) : null;
    _transport.setActivity(activity);
  }

  static Map<String, dynamic> _buildActivity(_NowPlayingEvent event, int eventTimeMS, bool supportsImageUrls) {
    final media = event.media;
    final startMS = eventTimeMS - event.positionMS;
    final durationMS = media.duration?.inMilliseconds;
    final endMS = durationMS != null && durationMS > 0 ? startMS + durationMS : null;
    final videoId = media.extras?[NowPlayingExtras.videoId] as String?;
    final thumbnailUrl = videoId != null && supportsImageUrls ? 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg' : null;
    final largeImage = thumbnailUrl ?? _kLargeImageAssetKey;
    final videoUrl = videoId == null ? null : 'https://www.youtube.com/watch?v=$videoId';
    final details = _fitText(media.title);
    final state = _fitText(media.artist);
    final largeText = _fitText(media.album);
    return {
      'type': _kActivityTypeListening,
      'details': ?details,
      'details_url': ?videoUrl,
      'state': ?state,
      'timestamps': {'start': startMS, 'end': ?endMS},
      'assets': {'large_image': largeImage, 'large_text': ?largeText},
    };
  }

  /// discord rejects the whole activity when a text is outside 2..128.
  static String? _fitText(String? text) {
    if (text == null || text.length < 2) return null;
    if (text.length <= _kTextMaxLength) return text;
    var end = _kTextMaxLength - 1;
    final isSplittingSurrogatePair = (text.codeUnitAt(end - 1) & 0xFC00) == 0xD800;
    if (isSplittingSurrogatePair) end--;
    return '${text.substring(0, end)}…';
  }
}

abstract class _DiscordPresenceTransport {
  /// arbitrary image urls only resolve through a discord client, a direct gateway session needs uploaded asset keys.
  final bool supportsImageUrls;

  const _DiscordPresenceTransport({required this.supportsImageUrls});

  /// mobile has no discord client to talk to, the gateway session logs in on its own.
  static final usesGateway = Platform.isAndroid || Platform.isIOS;

  static _DiscordPresenceTransport platform() {
    if (usesGateway) return _DiscordGatewayTransport();
    return _DiscordIpcTransport();
  }

  /// null clears the presence.
  void setActivity(Map<String, dynamic>? activity);

  /// refreshes the reported status & account for the settings tile.
  void probe();

  void close();
}

/// the local discord client ipc, the official desktop way: no token, no login.
class _DiscordIpcTransport extends _DiscordPresenceTransport {
  _DiscordIpcTransport() : super(supportsImageUrls: true);

  static const _kConnectRetryCooldownMS = 30 * 1000;

  _DiscordIpcConnection? _connection;
  int _nextConnectAttemptMS = 0;
  Future<void> _pending = Future.value();
  int _nonce = 0;

  @override
  void setActivity(Map<String, dynamic>? activity) => _enqueue(() => _setActivity(activity));

  @override
  void probe() => _enqueue(_connectIfNeeded);

  @override
  void close() => _enqueue(_closeConnection);

  Future<void> _connectIfNeeded() async {
    if (_connection == null) await _connect();
  }

  void _enqueue(FutureOr<void> Function() task) {
    _pending = _pending.then((_) => task()).onError(_onTaskError);
  }

  static void _onTaskError(Object e, StackTrace st) => logger.error('discord presence task failed', e: e, st: st);

  Future<void> _setActivity(Map<String, dynamic>? activity) async {
    if (_connection == null) {
      if (activity == null) return;
      final isCoolingDown = DateTime.now().millisecondsSinceEpoch < _nextConnectAttemptMS;
      if (isCoolingDown) return;
    }
    final nonce = _nonce++;
    final payload = {
      'cmd': 'SET_ACTIVITY',
      'args': {'pid': pid, 'activity': ?activity},
      'nonce': '$nonce',
    };
    final reply = await _command(payload);
    final isRejected = reply?['evt'] == 'ERROR';
    if (isRejected) logger.error('discord presence rejected', e: reply?['data']);
    final didApply = reply != null && !isRejected;
    _DiscordPresenceReport.inst.isSharing.value = didApply && activity != null;
  }

  Future<Map<String, dynamic>?> _command(Map<String, dynamic> payload) async {
    final connection = _connection;
    if (connection != null) {
      final reply = await connection.command(payload);
      if (reply != null) return reply;
      _closeConnection();
    }
    final freshConnection = await _connect();
    return freshConnection?.command(payload);
  }

  Future<_DiscordIpcConnection?> _connect() async {
    final report = _DiscordPresenceReport.inst;
    report.status.value = DiscordPresenceStatus.connecting;
    final connection = await _DiscordIpcConnection.open();
    if (connection == null) {
      _onConnectFailed();
      return null;
    }
    final reply = await connection.handshake(_DiscordPresenceSink._kApplicationId);
    if (reply?['evt'] != 'READY') {
      connection.close();
      logger.error('discord presence handshake failed', e: reply);
      _onConnectFailed();
      return null;
    }
    final ready = reply?['data'] as Map<String, dynamic>?;
    final user = ready?['user'] as Map<String, dynamic>?;
    report.account.value = user == null ? null : DiscordAccount.fromUserJson(user);
    report.status.value = DiscordPresenceStatus.connected;
    return _connection = connection;
  }

  void _onConnectFailed() {
    _DiscordPresenceReport.inst.status.value = DiscordPresenceStatus.unreachable;
    _nextConnectAttemptMS = DateTime.now().millisecondsSinceEpoch + _kConnectRetryCooldownMS;
  }

  void _closeConnection() {
    final connection = _connection;
    if (connection == null) return;
    connection.close();
    _connection = null;
    final report = _DiscordPresenceReport.inst;
    report.status.value = DiscordPresenceStatus.idle;
    report.isSharing.value = false;
  }
}

/// each request gets exactly one reply frame.
abstract class _DiscordIpcConnection {
  static const _kOpHandshake = 0;
  static const _kOpFrame = 1;
  static const _kHeaderLength = 8;
  static const _kPipesCount = 10;
  static const _kReplyTimeout = Duration(seconds: 5);

  static Future<_DiscordIpcConnection?> open() {
    if (Platform.isWindows) return _DiscordWindowsPipe.open();
    return _DiscordUnixSocket.open();
  }

  Future<void> _write(Uint8List bytes);

  Future<Uint8List?> _readChunk(int maxBytes);

  void close();

  Future<Map<String, dynamic>?> handshake(String applicationId) => _request(_kOpHandshake, {'v': 1, 'client_id': applicationId});

  Future<Map<String, dynamic>?> command(Map<String, dynamic> payload) => _request(_kOpFrame, payload);

  Future<Map<String, dynamic>?> _request(int opcode, Map<String, dynamic> payload) async {
    try {
      final frame = _encodeFrame(opcode, payload);
      final reply = _exchange(frame).timeout(_kReplyTimeout);
      return await reply;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _exchange(Uint8List frame) async {
    await _write(frame);
    final header = await _readExactly(_kHeaderLength);
    if (header == null) return null;
    final headerData = ByteData.sublistView(header);
    final bodyLength = headerData.getUint32(4, Endian.little);
    final body = await _readExactly(bodyLength);
    if (body == null) return null;
    final text = utf8.decode(body);
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<Uint8List?> _readExactly(int length) async {
    final builder = BytesBuilder(copy: false);
    while (builder.length < length) {
      final remaining = length - builder.length;
      final chunk = await _readChunk(remaining);
      if (chunk == null) return null;
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static Uint8List _encodeFrame(int opcode, Map<String, dynamic> payload) {
    final json = jsonEncode(payload);
    final body = utf8.encode(json);
    final frame = Uint8List(_kHeaderLength + body.length);
    ByteData.sublistView(frame)
      ..setUint32(0, opcode, Endian.little)
      ..setUint32(4, body.length, Endian.little);
    frame.setRange(_kHeaderLength, frame.length, body);
    return frame;
  }
}

/// requests are sequential since a pending read on a sync pipe handle blocks writes.
class _DiscordWindowsPipe extends _DiscordIpcConnection {
  final RandomAccessFile _file;

  _DiscordWindowsPipe(this._file);

  static Future<_DiscordIpcConnection?> open() async {
    for (int i = 0; i < _DiscordIpcConnection._kPipesCount; i++) {
      try {
        final pipeFile = File('\\\\?\\pipe\\discord-ipc-$i');
        final pipe = await pipeFile.open(mode: FileMode.append);
        return _DiscordWindowsPipe(pipe);
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<void> _write(Uint8List bytes) => _file.writeFrom(bytes);

  @override
  Future<Uint8List?> _readChunk(int maxBytes) async {
    final chunk = await _file.read(maxBytes);
    return chunk.isEmpty ? null : chunk;
  }

  @override
  void close() => _file.close().ignoreError();
}

class _DiscordUnixSocket extends _DiscordIpcConnection {
  final Socket _socket;
  final StreamIterator<Uint8List> _chunks;
  Uint8List? _leftover;

  _DiscordUnixSocket(this._socket) : _chunks = StreamIterator(_socket);

  /// discord uses the first defined of these, flatpak & snap builds nest it.
  static List<String> _getSocketDirectories() {
    final env = Platform.environment;
    final runtimeDirectory = env['XDG_RUNTIME_DIR'] ?? env['TMPDIR'] ?? env['TMP'] ?? env['TEMP'] ?? '/tmp';
    return [runtimeDirectory, '$runtimeDirectory/app/com.discordapp.Discord', '$runtimeDirectory/snap.discord'];
  }

  static final _socketDirectories = _getSocketDirectories();

  static Future<_DiscordIpcConnection?> open() async {
    for (final directory in _socketDirectories) {
      for (int i = 0; i < _DiscordIpcConnection._kPipesCount; i++) {
        try {
          final address = InternetAddress('$directory/discord-ipc-$i', type: InternetAddressType.unix);
          final socket = await Socket.connect(address, 0);
          return _DiscordUnixSocket(socket);
        } catch (_) {}
      }
    }
    return null;
  }

  @override
  Future<void> _write(Uint8List bytes) async {
    _socket.add(bytes);
    await _socket.flush();
  }

  @override
  Future<Uint8List?> _readChunk(int maxBytes) async {
    final chunk = _leftover ?? await _nextChunk();
    if (chunk == null) return null;
    if (chunk.length <= maxBytes) {
      _leftover = null;
      return chunk;
    }
    _leftover = Uint8List.sublistView(chunk, maxBytes);
    return Uint8List.sublistView(chunk, 0, maxBytes);
  }

  Future<Uint8List?> _nextChunk() async {
    final hasNext = await _chunks.moveNext();
    return hasNext ? _chunks.current : null;
  }

  @override
  void close() => _socket.destroy();
}

class _DiscordPresenceReport {
  static final inst = _DiscordPresenceReport._();

  _DiscordPresenceReport._();

  final status = DiscordPresenceStatus.idle.obs;
  final account = Rxn<DiscordAccount>();
  final isSharing = false.obs;
}
