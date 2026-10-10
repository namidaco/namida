// by claude
part of 'music_web_server_base.dart';

/// keeps the server of the playing item informed: now playing displays, and the play state jellyfin counts plays from.
/// requests go out one after another, so a quick skip can't reach the server before the start it ends.
class ServerNowPlayingReporter {
  static const _kRequestTimeout = Duration(seconds: 15);

  _NowPlayingSession? _session;
  Timer? _progressTimer;
  Future<void> _lastReport = Future.value();

  void onItemChanged(String? path, {required bool isPlaying, required int positionMS, required int? durationMS}) {
    final session = _session;
    if (session != null && session.path == path) {
      // -- same item published again (artwork, favourite, duration)
      _onPlayingChanged(session, isPlaying, positionMS);
      return;
    }
    end();
    if (path == null) return;
    final newSession = _NowPlayingSession.tryCreate(path, durationMS);
    if (newSession == null) return;
    _session = newSession;
    _onPlayingChanged(newSession, isPlaying, positionMS);
  }

  void onPlayingChanged(bool isPlaying, {required int positionMS}) {
    final session = _session;
    if (session != null) _onPlayingChanged(session, isPlaying, positionMS);
  }

  void end() {
    _progressTimer?.cancel();
    _progressTimer = null;
    final session = _session;
    if (session == null) return;
    _session = null;
    if (!session.didStart) return;
    final positionMS = session.estimatePositionMS(currentTimeMS);
    _send(session, _PlaybackReport.stopped, positionMS);
  }

  void _onPlayingChanged(_NowPlayingSession session, bool isPlaying, int positionMS) {
    final report = session.updateState(isPlaying, positionMS, currentTimeMS);
    if (report == null) return;
    _send(session, report, positionMS);
    _progressTimer?.cancel();
    _progressTimer = null;
    final interval = session.server._playbackProgressInterval;
    if (isPlaying && interval != null) {
      _progressTimer = Timer.periodic(interval, (_) => _sendProgress(session));
    }
  }

  void _sendProgress(_NowPlayingSession session) {
    final positionMS = session.estimatePositionMS(currentTimeMS);
    _send(session, _PlaybackReport.progress, positionMS);
  }

  void _send(_NowPlayingSession session, _PlaybackReport report, int positionMS) {
    _lastReport = _lastReport.then((_) => _sendNow(session, report, positionMS));
  }

  Future<void> _sendNow(_NowPlayingSession session, _PlaybackReport report, int positionMS) async {
    try {
      await session.server._reportPlayback(session.id, report, positionMS).timeout(_kRequestTimeout);
    } catch (_) {
      // -- best effort, the next report replaces a missed one
    }
  }
}

/// play counts for servers with [DirectoryIndexTypeTag.reportsListens]. history is the source, a listen that failed to
/// send is only remembered by its date until the server takes it, so the happy path writes nothing.
class ServerListensReporter {
  static final inst = ServerListensReporter._();
  ServerListensReporter._();

  static const _kBatchSize = 50;
  static const _kMaxPendingPerServer = 2000;
  static const _kRequestTimeout = Duration(seconds: 30);

  late final _pendingFuture = _readPendingFile();
  bool _isFileWithPending = false;
  bool _isFlushing = false;
  bool _shouldFlushAgain = false;
  bool _isWaitingForConnection = false;

  Future<void> onListened(TrackWithDate twd) async {
    if (!settings.reportPlaybackToServers.value) return;
    final dir = DirectoryIndexServer.parseFromEncodedUrlPath(twd.track.path);
    if (!dir.type.check(DirectoryIndexTypeTag.reportsListens)) return;
    final serverKey = dir.toDbKey();
    final pending = await _pendingFuture;
    final dates = pending[serverKey] ??= <int>[];
    dates.add(twd.dateAdded);
    final excess = dates.length - _kMaxPendingPerServer;
    if (excess > 0) dates.removeRange(0, excess);
    await _flushAll();
  }

  Future<void> _flushAll() async {
    if (_isFlushing) {
      _shouldFlushAgain = true;
      return;
    }
    _isFlushing = true;
    try {
      final pending = await _pendingFuture;
      do {
        _shouldFlushAgain = false;
        final serverKeys = pending.keys.toFixedList(); // -- listens can add servers while sending
        for (final serverKey in serverKeys) {
          await _flushServer(serverKey, pending);
        }
        await _savePending(pending);
      } while (_shouldFlushAgain);
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _flushServer(String serverKey, Map<String, List<int>> pending) async {
    final dir = DirectoryIndexServer.parseFromEncodedUrlPath(serverKey);
    final server = dir.toWebServer();
    if (server == null) {
      // -- kept while the server is still configured, it's only missing auth.
      if (!settings.directoriesToScan.value.contains(dir)) pending.remove(serverKey);
      return;
    }
    while (true) {
      final dates = pending[serverKey];
      if (dates == null || dates.isEmpty) return;
      final batchDates = dates.take(_kBatchSize).toSet();
      final listens = _listensFromHistory(batchDates);
      if (listens.isNotEmpty) {
        final result = await server._reportListens(listens).timeout(_kRequestTimeout, onTimeout: () => _ListensReportResult.retryLater);
        if (result == _ListensReportResult.retryLater) {
          _retryOnConnectionRestored();
          return;
        }
      }
      dates.removeWhere(batchDates.contains);
    }
  }

  /// listens removed from history since are dropped.
  List<_ServerListen> _listensFromHistory(Set<int> dates) {
    final history = HistoryController.inst.historyMap.value;
    final listens = <_ServerListen>[];
    for (final dateMS in dates) {
      final day = dateMS.toDaysSince1970();
      final dayTracks = history[day];
      if (dayTracks == null) continue;
      final twd = dayTracks.firstWhereEff((e) => e.dateAdded == dateMS && e.track.isNetwork);
      if (twd == null) continue;
      final id = MusicWebServer.baseUrlToId(twd.track.path);
      if (id == null) continue;
      listens.add((id: id, dateMS: dateMS));
    }
    return listens;
  }

  void _retryOnConnectionRestored() {
    if (_isWaitingForConnection) return;
    _isWaitingForConnection = true;
    ConnectivityController.inst.registerOnConnectionRestored(_onConnectionRestored);
  }

  void _onConnectionRestored() {
    _isWaitingForConnection = false;
    if (settings.reportPlaybackToServers.value) _flushAll();
  }

  Future<Map<String, List<int>>> _readPendingFile() async {
    final pending = <String, List<int>>{};
    final json = await File(AppPaths.SERVERS_PENDING_LISTENS).readAsJson();
    if (json is Map) {
      for (final e in json.entries) {
        try {
          final dates = e.value as List;
          pending[e.key as String] = dates.cast<int>().toList();
        } catch (_) {}
      }
    }
    _isFileWithPending = pending.isNotEmpty;
    return pending;
  }

  Future<void> _savePending(Map<String, List<int>> pending) async {
    pending.removeWhere((_, dates) => dates.isEmpty);
    final hasPending = pending.isNotEmpty;
    if (!hasPending && !_isFileWithPending) return;
    final file = File(AppPaths.SERVERS_PENDING_LISTENS);
    if (hasPending) {
      await file.writeAsJson(pending);
    } else {
      await file.tryDeleting();
    }
    _isFileWithPending = hasPending;
  }
}

class _NowPlayingSession {
  final MusicWebServer server;
  final String id;
  final String path;
  final int? durationMS;

  _NowPlayingSession._(this.server, this.id, this.path, this.durationMS);

  static _NowPlayingSession? tryCreate(String path, int? durationMS) {
    if (!path.startsWith('http')) return null;
    String? id;
    final dir = DirectoryIndexServer.parseFromEncodedUrlPath(path, parseIdCallback: (parsedId) => id = parsedId);
    if (!dir.type.check(DirectoryIndexTypeTag.reportsPlayback)) return null;
    final server = dir.toWebServer();
    final itemId = id;
    if (server == null || itemId == null) return null;
    return _NowPlayingSession._(server, itemId, path, durationMS);
  }

  bool didStart = false;
  bool _isPlaying = false;
  int _positionMS = 0;
  int _positionAtMS = 0;

  /// null when the state didn't change.
  _PlaybackReport? updateState(bool isPlaying, int positionMS, int nowMS) {
    final wasPlaying = _isPlaying;
    _isPlaying = isPlaying;
    _positionMS = positionMS;
    _positionAtMS = nowMS;
    if (isPlaying == wasPlaying) return null;
    if (!isPlaying) return _PlaybackReport.paused;
    final report = didStart ? _PlaybackReport.resumed : _PlaybackReport.started;
    didStart = true;
    return report;
  }

  int estimatePositionMS(int nowMS) {
    final elapsedMS = _isPlaying ? nowMS - _positionAtMS : 0;
    final positionMS = _positionMS + elapsedMS;
    final durationMS = this.durationMS;
    if (durationMS == null || durationMS <= 0) return positionMS;
    return positionMS.withMaximum(durationMS);
  }
}

enum _PlaybackReport {
  started,
  resumed,
  paused,
  progress,
  stopped,
}

enum _ListensReportResult {
  sent,
  rejected,
  retryLater,
  ;

  static const _kTemporaryStatusCodes = {401, 403, 408, 429};

  /// no response, server errors and auth problems can pass later, anything else would fail the same way again.
  static _ListensReportResult fromStatusCode(int? statusCode) {
    if (statusCode == null || statusCode >= 500) return retryLater;
    return _kTemporaryStatusCodes.contains(statusCode) ? retryLater : rejected;
  }
}

typedef _ServerListen = ({String id, int dateMS});
