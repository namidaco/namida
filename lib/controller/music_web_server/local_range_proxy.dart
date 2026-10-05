// by claude
part of 'music_web_server_base.dart';

/// serves byte ranges of files from servers that don't speak http (smb, sftp) on localhost,
/// so taglib and ffmpeg can read only the parts they need instead of the whole file.
class _LocalRangeProxy {
  static final inst = _LocalRangeProxy._();
  _LocalRangeProxy._();

  final _servers = <String, _FileTransferServer>{};
  late final _token = _generateToken();
  Future<HttpServer>? _httpServerFuture;

  static String _generateToken() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      final byte = random.nextInt(256);
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// [path] goes last so the url keeps the file extension, which taglib uses to pick the format.
  Future<String> urlFor(_FileTransferServer server, String path, int size) async {
    final httpServerFuture = _httpServerFuture ??= _start();
    final httpServer = await httpServerFuture;
    final serverKey = server.authDetails.dir.toDbKey();
    _servers[serverKey] = server;
    final uri = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: httpServer.port,
      pathSegments: [_token, serverKey, '$size', path],
    );
    return uri.toString();
  }

  Future<HttpServer> _start() async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    httpServer.listen(_onRequest);
    return httpServer;
  }

  Future<void> _onRequest(HttpRequest request) async {
    final response = request.response;

    Future<void> reject(int statusCode) {
      response.statusCode = statusCode;
      return response.close();
    }

    final segments = request.uri.pathSegments;
    if (segments.length != 4 || segments[0] != _token) return reject(HttpStatus.forbidden);

    final server = _servers[segments[1]];
    final size = int.tryParse(segments[2]);
    final path = segments[3];
    if (server == null || size == null) return reject(HttpStatus.notFound);

    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    final range = _parseRange(rangeHeader, size);
    if (range == null) return reject(HttpStatus.requestedRangeNotSatisfiable);

    final start = range.start;
    final end = range.end;
    final endExclusive = end + 1;
    final Uint8List bytes;
    try {
      bytes = await _readRange(server, path, start, endExclusive);
    } catch (e, st) {
      logger.error('Local range proxy failed to read $path', e: e, st: st);
      return reject(HttpStatus.badGateway);
    }

    response.statusCode = HttpStatus.partialContent;
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$size');
    response.contentLength = bytes.length;
    response.add(bytes);
    await response.close().ignoreError();
  }

  /// the whole range is read before responding, so a failed read is retried once instead of leaving the client with a short body.
  static Future<Uint8List> _readRange(_FileTransferServer server, String path, int start, int end) async {
    try {
      return await _readRangeOnce(server, path, start, end);
    } catch (e, st) {
      logger.error('Local range proxy read failed, retrying: $path', e: e, st: st);
      return await _readRangeOnce(server, path, start, end);
    }
  }

  static Future<Uint8List> _readRangeOnce(_FileTransferServer server, String path, int start, int end) async {
    final stream = await server._openRead(path, start, end);
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    final expectedLength = end - start;
    if (bytes.length != expectedLength) throw Exception('Short read: ${bytes.length}/$expectedLength');
    return bytes;
  }

  /// whole file when [header] is missing, ranges are inclusive.
  static ({int start, int end})? _parseRange(String? header, int size) {
    final lastByte = size - 1;
    if (lastByte < 0) return null;
    if (header == null) return (start: 0, end: lastByte);
    if (!header.startsWith('bytes=')) return null;

    final parts = header.substring(6).split('-');
    final start = int.tryParse(parts[0]);
    if (start == null || start > lastByte) return null;

    int end = lastByte;
    if (parts.length > 1) {
      final endRequested = int.tryParse(parts[1]);
      if (endRequested != null) end = endRequested.withMaximum(lastByte);
    }
    if (end < start) return null;
    return (start: start, end: end);
  }
}
