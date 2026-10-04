// by claude
part of 'music_web_server_base.dart';

class _FTPServer extends _FileTransferServer {
  late final _serverInfo = HostServerInfo.fromUrl(authDetails.dir.sourceRaw);
  late final _auth = authDetails.auth.toBasicAuthModel();

  FTPConnect? _client;
  Future<void> _queue = Future.value();

  _FTPServer.init(super.authDetails);

  @override
  int get _fetchConcurrency => 1;

  @override
  String get _basePath => _serverInfo.basePath;

  /// one command at a time, the control socket is shared.
  Future<T> _run<T>(Future<T> Function(FTPConnect client) operation) {
    final previous = _queue;
    final completer = Completer<void>();
    _queue = completer.future;
    return previous.then((_) async {
      try {
        return await operation(await _getClient());
      } finally {
        completer.complete();
      }
    });
  }

  Future<FTPConnect> _getClient() async {
    final existing = _client;
    if (existing != null) return existing;

    final username = _auth.username.isEmpty ? 'anonymous' : _auth.username;
    final client = FTPConnect(
      _serverInfo.host,
      port: _serverInfo.port,
      user: username,
      pass: _auth.password,
    );
    final didConnect = await client.connect();
    if (!didConnect) throw Exception('FTP connection failed');
    await client.setTransferType(TransferType.binary);
    return _client = client;
  }

  @override
  Future<List<_RemoteEntry>> _listDir(String dirPath) => _run((client) async {
    final didChange = await client.changeDirectory(dirPath);
    if (!didChange) throw Exception('Directory not found: $dirPath');
    final ftpEntries = await _listCurrentDirectory(client);
    final entries = <_RemoteEntry>[];
    for (final item in ftpEntries) {
      final name = item.name;
      if (name == '.' || name == '..') continue;
      entries.add(
        _RemoteEntry(
          path: p.posix.join(dirPath, name),
          name: name,
          isDir: item.type == FTPEntryType.dir,
          size: item.size,
          modifiedMS: item.modifyTime?.millisecondsSinceEpoch,
        ),
      );
    }
    return entries;
  });

  /// servers without MLSD answer with an error, LIST is the fallback.
  Future<List<FTPEntry>> _listCurrentDirectory(FTPConnect client) async {
    try {
      return await client.listDirectoryContent();
    } catch (_) {
      client.listCommand = ListCommand.list;
      return await client.listDirectoryContent();
    }
  }

  @override
  Future<void> _downloadToFile(String path, File toFile) => _run((client) async {
    await toFile.create(recursive: true);
    final didDownload = await client.downloadFile(path, toFile);
    if (!didDownload) throw Exception('Download failed: $path');
  });

  @override
  Future<Stream<List<int>>> _openRead(String path, int start) async {
    final tempFile = _tempFileFor(path);
    await _downloadToFile(path, tempFile);
    return _readThenDelete(tempFile, start);
  }

  @override
  Future<MusicWebServerError?> ping() async {
    try {
      await _run((client) async {
        final didChange = await client.changeDirectory(_basePath);
        if (!didChange) throw Exception('Directory not found: $_basePath');
      });
      return null;
    } catch (e) {
      return MusicWebServerError(code: 0, message: e.toString());
    }
  }

  @override
  void _onFetchError(Object error) {
    // -- 530: not logged in
    if (error is! FTPConnectException || error.response?.startsWith('530') != true) return;
    final dir = authDetails.dir;
    if (dir is DirectoryIndexServer) MusicWebServerAuthDetails.manager.deleteFromDb(dir);
  }

  @override
  void dispose() {
    _client?.disconnect();
    _client = null;
  }
}
