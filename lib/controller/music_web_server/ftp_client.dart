// by claude
part of 'music_web_server_base.dart';

class _FtpClient {
  static const _kConnectTimeout = Duration(seconds: 15);
  static const _kReplyTimeout = Duration(seconds: 30);
  static const _kAbortReplyTimeout = Duration(seconds: 5);
  static const _kLineFeed = 10;

  final Socket _socket;
  final _replies = Queue<_FtpReply>();
  final _partialLine = BytesBuilder(copy: false);
  final _multiLineText = StringBuffer();
  String? _multiLineCode;
  Completer<void>? _replyWaiter;
  _FtpException? _closedError;

  bool _supportsMlsd = false;
  bool _usesEpsv;
  bool supportsRest = true;

  bool get isClosed => _closedError != null;

  _FtpClient._(Socket socket) : _socket = socket, _usesEpsv = socket.remoteAddress.type == InternetAddressType.IPv6 {
    socket.listen(
      _onData,
      onError: (Object e) => _markClosed('Connection error: $e'),
      onDone: () => _markClosed('Connection closed by server'),
      cancelOnError: true,
    );
  }

  static Future<_FtpClient> connect(String host, int port, {required String username, required String password}) async {
    final socket = await Socket.connect(host, port, timeout: _kConnectTimeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    final client = _FtpClient._(socket);
    try {
      await client._login(username, password);
      await client._negotiate();
    } catch (_) {
      client.close();
      rethrow;
    }
    return client;
  }

  Future<void> _login(String username, String password) async {
    _FtpReply greeting = await _readReply();
    while (greeting.code == 120) {
      greeting = await _readReply(); // -- 120: ready in n minutes, 220 follows
    }
    if (greeting.code != 220) throw _FtpException.reply('Connect', greeting);

    _FtpReply res = await _command('USER $username');
    if (res.code == 331) res = await _command('PASS $password');
    if (!res.isPositive) throw _FtpException.reply('Login', res);
  }

  Future<void> _negotiate() async {
    final feat = await _command('FEAT');
    if (feat.isPositive) {
      final features = _parseFeatures(feat.text);
      _supportsMlsd = features.contains('MLST');
      supportsRest = features.contains('REST');
      if (features.contains('UTF8')) await _command('OPTS UTF8 ON');
    }
    final type = await _command('TYPE I');
    if (!type.isPositive) throw _FtpException.reply('TYPE I', type);
  }

  static Set<String> _parseFeatures(String text) {
    final lines = LineSplitter.split(text).toFixedList();
    final features = <String>{};
    for (int i = 1; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      final feature = line.splitFirst(' ');
      final featureKey = feature.toUpperCase();
      features.add(featureKey);
    }
    return features;
  }

  Future<List<_RemoteEntry>> listDir(String dirPath) async {
    if (_supportsMlsd) {
      try {
        final bytes = await _readTransfer('MLSD $dirPath');
        return _parseMlsd(bytes, dirPath);
      } on _FtpException catch (e) {
        if (!e.isUnsupportedCommand) rethrow;
        _supportsMlsd = false;
      }
    }

    // -- LIST takes no path, some servers treat it as a glob pattern
    final cwd = await _command('CWD $dirPath');
    if (!cwd.isPositive) throw _FtpException.reply('CWD $dirPath', cwd);
    final bytes = await _readTransfer('LIST');
    return _parseList(bytes, dirPath);
  }

  Future<int> fileSize(String path) async {
    final command = 'SIZE $path';
    final res = await _command(command);
    if (res.code != 213) throw _FtpException.reply(command, res);
    final sizeText = res.text.substring(3);
    final size = int.tryParse(sizeText);
    if (size == null) throw _FtpException.reply(command, res);
    return size;
  }

  /// [end] is exclusive.
  Stream<Uint8List> retrieve(String path, {int start = 0, int? end}) async* {
    if (start > 0 && !supportsRest) throw _FtpException('Server can\'t resume transfers: $path');

    final command = 'RETR $path';
    final transfer = await _openTransfer(command, restartAt: start);
    final dataSocket = transfer.socket;
    final dataStream = dataSocket.timeout(_kReplyTimeout);
    int? remaining = end == null ? null : end - start;
    bool didReachEnd = false;
    try {
      await for (final chunk in dataStream) {
        final remainingNow = remaining;
        if (remainingNow == null) {
          yield chunk;
          continue;
        }
        if (chunk.length < remainingNow) {
          remaining = remainingNow - chunk.length;
          yield chunk;
          continue;
        }
        remaining = 0;
        yield Uint8List.sublistView(chunk, 0, remainingNow);
        break;
      }
      didReachEnd = true;
    } finally {
      dataSocket.destroy();
      final wasCut = !didReachEnd || remaining == 0;
      final replyTimeout = wasCut ? _kAbortReplyTimeout : _kReplyTimeout;
      final done = transfer.finalReply ?? await _readReply(timeout: replyTimeout);
      if (!wasCut && !done.isPositive) throw _FtpException.reply(command, done);
    }
  }

  Future<Uint8List> _readTransfer(String command) async {
    final transfer = await _openTransfer(command);
    final dataSocket = transfer.socket;
    final dataStream = dataSocket.timeout(_kReplyTimeout);
    final builder = BytesBuilder(copy: false);
    Object? dataError;
    try {
      await dataStream.forEach(builder.add);
    } catch (e) {
      dataError = e;
    } finally {
      dataSocket.destroy();
    }
    final done = transfer.finalReply ?? await _readReply();
    if (dataError != null) throw _FtpException('$command: data transfer failed, $dataError');
    if (!done.isPositive) throw _FtpException.reply(command, done);
    return builder.takeBytes();
  }

  /// [finalReply] is set when the server finished without a preliminary reply.
  Future<({Socket socket, _FtpReply? finalReply})> _openTransfer(String command, {int restartAt = 0}) async {
    final dataSocket = await _openDataConnection();
    try {
      if (restartAt > 0) {
        final restCommand = 'REST $restartAt';
        final rest = await _command(restCommand);
        if (rest.code != 350) {
          supportsRest = false;
          throw _FtpException.reply(restCommand, rest);
        }
      }
      final res = await _command(command);
      if (res.isPreliminary) return (socket: dataSocket, finalReply: null);
      if (res.isPositive) return (socket: dataSocket, finalReply: res);
      throw _FtpException.reply(command, res);
    } catch (_) {
      dataSocket.destroy();
      rethrow;
    }
  }

  /// the advertised address is ignored, servers behind nat often send their private one.
  Future<Socket> _openDataConnection() async {
    final port = await _requestPassivePort();
    final address = _socket.remoteAddress;
    try {
      return await Socket.connect(address, port, timeout: _kConnectTimeout);
    } on SocketException catch (e) {
      throw _FtpException('Data connection to ${address.address}:$port failed, a firewall might be blocking the server passive ports. ${e.message}');
    }
  }

  Future<int> _requestPassivePort() async {
    final usesEpsv = _usesEpsv;
    final port = await _tryPassiveMode(useEpsv: usesEpsv);
    if (port != null) return port;
    final fallbackPort = await _tryPassiveMode(useEpsv: !usesEpsv);
    if (fallbackPort == null) throw const _FtpException('Server refused passive mode');
    _usesEpsv = !usesEpsv;
    return fallbackPort;
  }

  Future<int?> _tryPassiveMode({required bool useEpsv}) async {
    final res = await _command(useEpsv ? 'EPSV' : 'PASV');
    if (!res.isPositive) return null;
    if (useEpsv) return _parseEpsvPort(res.text);
    return _parsePasvPort(res.text);
  }

  static final _pasvRegex = RegExp(r'(\d{1,3}),(\d{1,3}),(\d{1,3}),(\d{1,3}),(\d{1,3}),(\d{1,3})');
  static final _epsvRegex = RegExp(r'\((.)\1\1(\d+)\1\)');

  static int? _parsePasvPort(String text) {
    final match = _pasvRegex.firstMatch(text);
    if (match == null) return null;
    final high = _parseGroup(match, 5);
    final low = _parseGroup(match, 6);
    return high * 256 + low;
  }

  /// `229 Entering Extended Passive Mode (|||50000|)`
  static int? _parseEpsvPort(String text) {
    final match = _epsvRegex.firstMatch(text);
    final portText = match?.group(2);
    if (portText == null) return null;
    return int.tryParse(portText);
  }

  static int _parseGroup(RegExpMatch match, int group) {
    final text = match.group(group)!;
    return int.parse(text);
  }

  Future<_FtpReply> _command(String command) async {
    final closedError = _closedError;
    if (closedError != null) throw closedError;
    final commandBytes = utf8.encode('$command\r\n');
    _socket.add(commandBytes);
    return _readReply();
  }

  Future<_FtpReply> _readReply({Duration timeout = _kReplyTimeout}) async {
    while (_replies.isEmpty) {
      final closedError = _closedError;
      if (closedError != null) throw closedError;
      final waiter = _replyWaiter ??= Completer<void>();
      try {
        await waiter.future.timeout(timeout);
      } on TimeoutException {
        _markClosed('Server stopped responding');
      }
    }
    return _replies.removeFirst();
  }

  void _onData(Uint8List data) {
    int lineStart = 0;
    for (int i = 0; i < data.length; i++) {
      if (data[i] != _kLineFeed) continue;
      final lineEnd = Uint8List.sublistView(data, lineStart, i);
      _partialLine.add(lineEnd);
      lineStart = i + 1;
      final lineBytes = _partialLine.takeBytes();
      final line = utf8.decode(lineBytes, allowMalformed: true);
      final lineClean = line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
      _onLine(lineClean);
    }
    if (lineStart < data.length) {
      final lineStartPart = Uint8List.sublistView(data, lineStart);
      _partialLine.add(lineStartPart);
    }
  }

  /// rfc 959: a multiline reply starts with `xyz-` and ends with a line starting with `xyz `.
  void _onLine(String line) {
    final multiLineCode = _multiLineCode;
    if (multiLineCode != null) {
      _multiLineText.write('\n');
      _multiLineText.write(line);
      final isLastLine = line.startsWith(multiLineCode) && (line.length == 3 || line[3] == ' ');
      if (!isLastLine) return;
      final code = int.parse(multiLineCode);
      final text = _multiLineText.toString();
      _multiLineCode = null;
      _multiLineText.clear();
      _pushReply(_FtpReply(code, text));
      return;
    }

    if (line.length < 3) return;
    final codeText = line.substring(0, 3);
    final code = int.tryParse(codeText);
    if (code == null) return;
    final isMultiLine = line.length > 3 && line[3] == '-';
    if (isMultiLine) {
      _multiLineCode = codeText;
      _multiLineText.write(line);
      return;
    }
    _pushReply(_FtpReply(code, line));
  }

  void _pushReply(_FtpReply reply) {
    // -- 421: the server is closing the connection
    if (reply.code == 421) {
      _markClosed(reply.text);
      return;
    }
    _replies.add(reply);
    _wakeReplyWaiter();
  }

  void _wakeReplyWaiter() {
    final waiter = _replyWaiter;
    _replyWaiter = null;
    waiter?.complete();
  }

  void _markClosed(String reason) {
    if (_closedError != null) return;
    _closedError = _FtpException(reason);
    _socket.destroy();
    _wakeReplyWaiter();
  }

  void close() {
    if (_closedError != null) return;
    _closedError = const _FtpException('Connection closed');
    final quitBytes = utf8.encode('QUIT\r\n');
    _socket.add(quitBytes);
    _socket.close().ignoreError();
    _wakeReplyWaiter();
  }

  static List<_RemoteEntry> _parseMlsd(Uint8List bytes, String dirPath) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final entries = <_RemoteEntry>[];
    for (final line in LineSplitter.split(text)) {
      final nameIndex = line.indexOf(' ');
      if (nameIndex <= 0) continue;
      final name = line.substring(nameIndex + 1);
      final factsText = line.substring(0, nameIndex);
      String? type;
      int? size;
      int? modifiedMS;
      for (final fact in factsText.split(';')) {
        final valueIndex = fact.indexOf('=');
        if (valueIndex <= 0) continue;
        final keyRaw = fact.substring(0, valueIndex);
        final key = keyRaw.toLowerCase();
        final value = fact.substring(valueIndex + 1);
        switch (key) {
          case 'type':
            type = value.toLowerCase();
          case 'size' || 'sizd':
            size = int.tryParse(value);
          case 'modify':
            modifiedMS = _parseMlsdTimeMS(value);
        }
      }

      final isDir = type == 'dir';
      final isFile = type == 'file';
      final isLink = type != null && type.startsWith('os.unix=');
      if (!isDir && !isFile && !isLink) continue; // -- cdir, pdir

      // -- links are never walked as folders (loops)
      final path = p.posix.join(dirPath, name);
      entries.add(
        _RemoteEntry(
          path: path,
          name: name,
          isDir: isDir,
          size: isFile ? size : null,
          modifiedMS: modifiedMS,
        ),
      );
    }
    return entries;
  }

  /// `20231017164225(.123)`, always utc.
  static int? _parseMlsdTimeMS(String value) {
    if (value.length < 14) return null;
    final isoText = '${value.substring(0, 8)}T${value.substring(8)}Z';
    final date = DateTime.tryParse(isoText);
    return date?.millisecondsSinceEpoch;
  }

  /// size is the number right before the month.
  static final _unixListRegex = RegExp(r'^([\-dl])\S*\s+(?:.*?\s+)?(\d+)\s+(\S+)\s+(\d{1,2})\s+(\d{1,2}:\d{2}|\d{4})\s(.+)$');

  /// `10-17-26  06:42PM       <DIR>          name` (iis)
  static final _dosListRegex = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{2,4})\s+(\d{1,2}):(\d{2})\s*([AaPp][Mm])?\s+(<DIR>|\d+)\s+(.+)$');

  static const _kMonths = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

  static List<_RemoteEntry> _parseList(Uint8List bytes, String dirPath) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final now = DateTime.now().toUtc();
    final entries = <_RemoteEntry>[];
    for (final line in LineSplitter.split(text)) {
      final entry = _parseUnixListLine(line, dirPath, now) ?? _parseDosListLine(line, dirPath);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  static _RemoteEntry? _parseUnixListLine(String line, String dirPath, DateTime now) {
    final match = _unixListRegex.firstMatch(line);
    if (match == null) return null;
    final kind = match.group(1)!;
    final isDir = kind == 'd';
    final isLink = kind == 'l';
    final nameRaw = match.group(6)!;
    final name = isLink ? nameRaw.splitFirst(' -> ') : nameRaw;
    if (name == '.' || name == '..') return null;

    final sizeText = match.group(2)!;
    final size = isLink ? null : int.tryParse(sizeText);
    final month = match.group(3)!;
    final day = match.group(4)!;
    final timeOrYear = match.group(5)!;
    final modifiedMS = _parseUnixListTimeMS(month: month, day: day, timeOrYear: timeOrYear, now: now);
    final path = p.posix.join(dirPath, name);
    return _RemoteEntry(
      path: path,
      name: name,
      isDir: isDir,
      size: size,
      modifiedMS: modifiedMS,
    );
  }

  /// null for localized month names. the server's local time is read as utc, it only needs to stay the same between scans.
  static int? _parseUnixListTimeMS({required String month, required String day, required String timeOrYear, required DateTime now}) {
    if (month.length < 3) return null;
    final monthPrefix = month.substring(0, 3);
    final monthKey = monthPrefix.toLowerCase();
    final monthNumber = _kMonths.indexOf(monthKey) + 1;
    if (monthNumber == 0) return null;
    final dayNumber = int.parse(day);

    final timeParts = timeOrYear.split(':');
    if (timeParts.length != 2) {
      final year = int.parse(timeOrYear);
      final date = DateTime.utc(year, monthNumber, dayNumber);
      return date.millisecondsSinceEpoch;
    }

    // -- no year means within the last 6 months, a date ahead of now is from last year
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final date = DateTime.utc(now.year, monthNumber, dayNumber, hour, minute);
    final latestAllowed = now.add(const Duration(days: 1));
    if (!date.isAfter(latestAllowed)) return date.millisecondsSinceEpoch;
    final lastYearDate = DateTime.utc(now.year - 1, monthNumber, dayNumber, hour, minute);
    return lastYearDate.millisecondsSinceEpoch;
  }

  static _RemoteEntry? _parseDosListLine(String line, String dirPath) {
    final match = _dosListRegex.firstMatch(line);
    if (match == null) return null;
    final name = match.group(8)!;
    if (name == '.' || name == '..') return null;

    final sizeOrDir = match.group(7)!;
    final isDir = sizeOrDir == '<DIR>';
    final size = isDir ? null : int.tryParse(sizeOrDir);
    final modifiedMS = _parseDosListTimeMS(match);
    final path = p.posix.join(dirPath, name);
    return _RemoteEntry(
      path: path,
      name: name,
      isDir: isDir,
      size: size,
      modifiedMS: modifiedMS,
    );
  }

  static int _parseDosListTimeMS(RegExpMatch match) {
    final month = _parseGroup(match, 1);
    final day = _parseGroup(match, 2);
    final yearPre = _parseGroup(match, 3);
    final century = yearPre < 70 ? 2000 : 1900;
    final year = yearPre >= 100 ? yearPre : century + yearPre;
    final hourPre = _parseGroup(match, 4);
    final minute = _parseGroup(match, 5);
    final meridiemRaw = match.group(6);
    final meridiem = meridiemRaw?.toLowerCase();
    final pmOffset = meridiem == 'pm' ? 12 : 0;
    final hour = meridiem == null ? hourPre : hourPre % 12 + pmOffset;
    final date = DateTime.utc(year, month, day, hour, minute);
    return date.millisecondsSinceEpoch;
  }
}

class _FtpReply {
  final int code;
  final String text;

  const _FtpReply(this.code, this.text);

  bool get isPreliminary => code >= 100 && code < 200;
  bool get isPositive => code >= 200 && code < 300;
}

class _FtpException implements Exception {
  final String message;
  final int? code;

  const _FtpException(this.message) : code = null;

  _FtpException.reply(String command, _FtpReply reply) : message = '$command: ${reply.text}', code = reply.code;

  bool get isUnsupportedCommand => code == 500 || code == 502 || code == 504;

  @override
  String toString() => 'FTP: $message';
}
