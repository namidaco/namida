// rewritten by claude, new one sits on _FileTransferServer: shared indexing with mtime diffing, lyrics siblings & server tagging
part of 'music_web_server_base.dart';

class _SMBServer extends _FileTransferServer {
  late final _serverInfo = HostServerInfo.fromUrl(authDetails.dir.sourceRaw);
  late final _auth = authDetails.auth.toBasicAuthModel();

  Completer<SmbConnect?>? _connectionCompleter;

  _SMBServer.init(super.authDetails);

  @override
  int get _fetchConcurrency => 10;

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

  Future<SmbConnect> _getConnection() async {
    final pending = _connectionCompleter;
    if (pending != null) {
      final res = await pending.future;
      if (res != null) return res;
    }

    final completer = _connectionCompleter = Completer<SmbConnect?>();
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
      _connectionCompleter = null;
      rethrow;
    }
  }

  @override
  void dispose() async {
    (await _connectionCompleter?.future)?.close();
    _connectionCompleter = null;
  }

  @override
  Future<List<_RemoteEntry>> _listDir(String dirPath) async {
    final connection = await _getConnection();
    final folder = await connection.file(dirPath);
    final files = await connection.listFiles(folder);
    final entries = <_RemoteEntry>[];
    for (final file in files) {
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
  Future<Stream<List<int>>> _openRead(String path, int start) async {
    final connection = await _getConnection();
    final smbFile = await connection.file(path);
    return connection.openRead(smbFile, start);
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
