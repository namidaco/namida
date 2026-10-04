// by claude
part of 'music_web_server_base.dart';

class _SFTPServer extends _FileTransferServer {
  late final _serverInfo = HostServerInfo.fromUrl(authDetails.dir.sourceRaw);
  late final _auth = authDetails.auth.toBasicAuthModel();

  Completer<SftpClient?>? _clientCompleter;
  SSHClient? _ssh;

  _SFTPServer.init(super.authDetails);

  @override
  int get _fetchConcurrency => 4;

  @override
  String get _basePath => _serverInfo.basePath;

  Future<SftpClient> _getClient() async {
    final pending = _clientCompleter;
    if (pending != null) {
      final client = await pending.future;
      if (client != null) return client;
    }

    final completer = _clientCompleter = Completer<SftpClient?>();
    try {
      final socket = await SSHSocket.connect(_serverInfo.host, _serverInfo.port ?? 22, timeout: const Duration(seconds: 20));
      final ssh = SSHClient(
        socket,
        username: _auth.username,
        onPasswordRequest: () => _auth.password,
      );
      final client = await ssh.sftp();
      _ssh = ssh;
      ssh.done.then((_) => _onDisconnected(ssh), onError: (_) => _onDisconnected(ssh));
      completer.complete(client);
      return client;
    } catch (e) {
      completer.complete(null);
      _clientCompleter = null;
      rethrow;
    }
  }

  void _onDisconnected(SSHClient ssh) {
    if (_ssh != ssh) return;
    _ssh = null;
    _clientCompleter = null;
  }

  @override
  Future<List<_RemoteEntry>> _listDir(String dirPath) async {
    final client = await _getClient();
    final names = await client.listdir(dirPath);
    final entries = <_RemoteEntry>[];
    for (final item in names) {
      final name = item.filename;
      if (name == '.' || name == '..') continue;
      final attr = item.attr;
      final modifyTime = attr.modifyTime;
      entries.add(
        _RemoteEntry(
          path: p.posix.join(dirPath, name),
          name: name,
          isDir: attr.isDirectory,
          size: attr.size,
          modifiedMS: modifyTime == null ? null : modifyTime * 1000,
        ),
      );
    }
    return entries;
  }

  @override
  Future<Stream<List<int>>> _openRead(String path, int start) async {
    final client = await _getClient();
    final file = await client.open(path);
    return _closeAfter(file.read(offset: start), file);
  }

  static Stream<List<int>> _closeAfter(Stream<Uint8List> stream, SftpFile file) async* {
    try {
      yield* stream;
    } finally {
      await file.close();
    }
  }

  @override
  Future<MusicWebServerError?> ping() async {
    try {
      final client = await _getClient();
      await client.stat(_basePath);
      return null;
    } catch (e) {
      return MusicWebServerError(code: 0, message: e.toString());
    }
  }

  @override
  void _onFetchError(Object error) {
    if (error is! SSHAuthError) return;
    final dir = authDetails.dir;
    if (dir is DirectoryIndexServer) MusicWebServerAuthDetails.manager.deleteFromDb(dir);
  }

  @override
  void dispose() {
    _ssh?.close();
    _ssh = null;
    _clientCompleter = null;
  }
}
