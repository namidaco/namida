// rewritten by claude, new one sits on _FileTransferServer: shared indexing with mtime diffing, lyrics siblings & server tagging
part of 'music_web_server_base.dart';

class _SMBServer extends _FileTransferServer {
  late final _serverInfo = HostServerInfo.fromUrl(authDetails.dir.sourceRaw);
  late final _auth = authDetails.auth.toBasicAuthModel();

  static const _kConnectionsCount = 4; // -- smb_connect sends one request at a time per connection
  final _connectionCompleters = List<Completer<SmbConnect?>?>.filled(_kConnectionsCount, null);

  _SMBServer.init(super.authDetails);

  @override
  int get _fetchConcurrency => 10;

  @override
  bool get _canReadRanges => true;

  @override
  String get _basePath => _serverInfo.basePath;

  Configuration _configBuilder(
    Credentials creds,
    String username,
    String password,
    String domain,
  ) {
    return BaseConfiguration(
      credentials: creds,
      username: username,
      password: password,
      domain: domain,
      port: _serverInfo.port,
      forceSmb1: false,
      minimumVersion: DialectVersion.SMB1,
      maximumVersion: DialectVersion.SMB302, // 3.1 requires preauth hash
      bufferCacheSize: 0x1FFF * 20,
      sendBufferSize: 0xFFFF * 20,
      receiveBufferSize: 0xFFFF * 30,
      transactionBufferSize: 0xFFFF * 30,
      maximumBufferSize: 0x10000 * 30,
      isUseBatching: true,
    );
  }

  Future<SmbConnect> _getConnection([int index = 0]) async {
    final pending = _connectionCompleters[index];
    if (pending != null) {
      final res = await pending.future;
      if (res != null) return res;
    }

    final completer = _connectionCompleters[index] = Completer<SmbConnect?>();
    try {
      final host = _serverInfo.host;
      if (host.isEmpty) throw Exception('SMB host is empty');

      final connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: _auth.username,
        password: _auth.password,
        configBuilder: _configBuilder,
      );

      completer.complete(connection);
      return connection;
    } catch (e) {
      completer.complete(null);
      _connectionCompleters[index] = null;
      rethrow;
    }
  }

  /// a file always goes through the same connection, its open read handle lives there.
  Future<SmbConnect> _getConnectionFor(String path) {
    final index = path.hashCode % _kConnectionsCount;
    return _getConnection(index);
  }

  @override
  void dispose() async {
    for (final entry in _readHandles.values) {
      entry.close();
    }
    _readHandles.clear();
    _listedFiles.clear();
    for (int i = 0; i < _kConnectionsCount; i++) {
      final completer = _connectionCompleters[i];
      _connectionCompleters[i] = null;
      (await completer?.future)?.close();
    }
  }

  static const _kReadHandleIdleTimeout = Duration(seconds: 3);
  final _readHandles = <String, _SmbReadHandleEntry>{};

  /// keeps the file open between the range reads of one file, sparing an open & close round trip for each.
  Future<Uint8List> _readRange(String path, int start, int end) async {
    final entry = _readHandles[path] ??= _SmbReadHandleEntry(_openReadHandle(path));
    entry.idleTimer?.cancel();
    entry.activeReads++;
    try {
      final handle = await entry.handle;
      return await handle.read(start, end - start);
    } catch (_) {
      if (_readHandles[path] == entry) _readHandles.remove(path); // -- reopened on the next read
      rethrow;
    } finally {
      entry.activeReads--;
      if (entry.activeReads == 0) {
        if (_readHandles[path] == entry) {
          entry.idleTimer = Timer(_kReadHandleIdleTimeout, () => _closeReadHandle(path, entry));
        } else {
          entry.close();
        }
      }
    }
  }

  Future<SmbReadHandle> _openReadHandle(String path) async {
    final connection = await _getConnectionFor(path);
    final smbFile = _listedFiles[path] ?? await connection.file(path);
    return connection.openReadHandle(smbFile);
  }

  static const _kListedFilesCacheSize = 2048;
  final _listedFiles = <String, SmbFile>{};

  /// files from the latest listings, sparing a lookup round trip when they're opened right after.
  void _rememberListedFile(SmbFile file) {
    final path = file.path;
    _listedFiles.remove(path);
    if (_listedFiles.length >= _kListedFilesCacheSize) _listedFiles.remove(_listedFiles.keys.first);
    _listedFiles[path] = file;
  }

  void _closeReadHandle(String path, _SmbReadHandleEntry entry) {
    if (_readHandles[path] == entry) _readHandles.remove(path);
    entry.close();
  }

  @override
  Future<List<_RemoteEntry>> _listDir(String dirPath) async {
    final connection = await _getConnection();
    final folder = await connection.file(dirPath);
    final files = await connection.listFiles(folder);
    final entries = <_RemoteEntry>[];
    for (final file in files) {
      if (!file.isDirectory()) _rememberListedFile(file);
      entries.add(
        _RemoteEntry(
          path: file.path,
          name: file.name,
          isDir: file.isDirectory(),
          size: file.size,
          modifiedMS: file.lastModified,
        ),
      );
    }
    return entries;
  }

  @override
  Future<Stream<List<int>>> _openRead(String path, int start, [int? end]) async {
    if (end != null) {
      final bytes = await _readRange(path, start, end);
      return Stream.value(bytes);
    }
    final connection = await _getConnectionFor(path);
    final smbFile = await connection.file(path);
    return connection.openRead(smbFile, start, end);
  }

  @override
  Future<int> _fileSize(String path) async {
    final connection = await _getConnectionFor(path);
    final smbFile = await connection.file(path);
    return smbFile.size;
  }

  @override
  Future<MusicWebServerError?> ping() async {
    try {
      await _getConnection(); // cuz pingConnection can return true even if connection would get rejected later

      final host = _serverInfo.host;
      if (host.isEmpty) {
        return MusicWebServerError(code: 0, message: 'Host is empty');
      }

      final result = await SmbConnect.pingConnection(
        host: host,
        username: _auth.username,
        password: _auth.password,
        domain: '',
        configBuilder: _configBuilder,
      );

      return result ? null : MusicWebServerError(code: 0, message: 'Connection failed');
    } catch (e) {
      return MusicWebServerError(code: 0, message: e.toString());
    }
  }

  @override
  Future<Set<ServerShareWrapper>?> getAvailableShares() async {
    try {
      final connection = await _getConnection();
      final shares = await connection.listShares();
      // -- move shared with $ to the end
      final invalidShares = <SmbFile>[];
      shares.removeWhere(
        (m) {
          if (m.name.contains(r'$')) {
            invalidShares.add(m);
            return true;
          }
          return false;
        },
      );
      shares.addAll(invalidShares);
      return shares.map((e) => ServerShareWrapper.simple(e.name)).toSet();
    } catch (_) {}
    return null;
  }

  @override
  void _onFetchError(Object error) {
    final errorText = error.toString();
    if (error is! SmbAuthException && !errorText.contains('unauthorized') && !errorText.contains('access denied')) return;
    final dir = authDetails.dir;
    if (dir is DirectoryIndexServer) MusicWebServerAuthDetails.manager.deleteFromDb(dir);
  }
}

class _SmbReadHandleEntry {
  final Future<SmbReadHandle> handle;
  int activeReads = 0;
  Timer? idleTimer;

  _SmbReadHandleEntry(this.handle);

  void close() {
    idleTimer?.cancel();
    handle.then((h) => h.close()).ignoreError();
  }
}
