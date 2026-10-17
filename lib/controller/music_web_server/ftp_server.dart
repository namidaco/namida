// rewritten by claude, new one runs on _FtpClient: streamed & ranged reads, ping checks the data connection
part of 'music_web_server_base.dart';

class _FTPServer extends _FileTransferServer {
  late final _serverInfo = HostServerInfo.fromUrl(authDetails.dir.sourceRaw);
  late final _auth = authDetails.auth.toBasicAuthModel();

  _FtpClient? _client;
  Future<void> _queue = Future.value();

  _FTPServer.init(super.authDetails);

  @override
  int get _fetchConcurrency => 1;

  @override
  bool get _canReadRanges => _client?.supportsRest ?? true;

  @override
  String get _basePath => _serverInfo.basePath;

  /// one transfer at a time, the control connection is shared.
  Future<void Function()> _acquire() {
    final previous = _queue;
    final completer = Completer<void>();
    _queue = completer.future;
    return previous.then((_) => completer.complete);
  }

  Future<T> _run<T>(Future<T> Function(_FtpClient client) operation) async {
    final release = await _acquire();
    try {
      final client = await _getClient();
      return await operation(client);
    } finally {
      release();
    }
  }

  /// the connection is held until the stream is done, a stream that's never listened to never takes it.
  Stream<Uint8List> _runStream(Stream<Uint8List> Function(_FtpClient client) open) async* {
    final release = await _acquire();
    try {
      final client = await _getClient();
      yield* open(client);
    } finally {
      release();
    }
  }

  Future<_FtpClient> _getClient() async {
    final existing = _client;
    if (existing != null && !existing.isClosed) return existing;

    final username = _auth.username.isEmpty ? 'anonymous' : _auth.username;
    final port = _serverInfo.port ?? 21;
    final client = await _FtpClient.connect(_serverInfo.host, port, username: username, password: _auth.password);
    _client = client;
    return client;
  }

  @override
  Future<List<_RemoteEntry>> _listDir(String dirPath) => _run((client) => client.listDir(dirPath));

  @override
  Future<Stream<List<int>>> _openRead(String path, int start, [int? end]) async {
    return _runStream((client) => client.retrieve(path, start: start, end: end));
  }

  @override
  Future<int> _fileSize(String path) => _run((client) => client.fileSize(path));

  @override
  Future<MusicWebServerError?> ping() async {
    try {
      // -- a listing checks the data connection too, passive ports are often blocked while the control port is open
      await _listDir(_basePath);
      return null;
    } catch (e) {
      return MusicWebServerError(code: 0, message: e.toString());
    }
  }

  @override
  void _onFetchError(Object error) {
    // -- 530: not logged in
    if (error is! _FtpException || error.code != 530) return;
    final dir = authDetails.dir;
    if (dir is DirectoryIndexServer) MusicWebServerAuthDetails.manager.deleteFromDb(dir);
  }

  @override
  void dispose() {
    _client?.close();
    _client = null;
  }
}
