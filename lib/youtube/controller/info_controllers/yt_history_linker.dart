part of '../youtube_info_controller.dart';

class _YoutubeHistoryLinker {
  final String? Function() activeAccId;
  _YoutubeHistoryLinker(this.activeAccId);

  late String _dbDirectory;
  void init(String directory) {
    _dbDirectory = directory;
    _ensureDBOpened();
    ConnectivityController.inst.registerOnConnectionRestored(_onConnectionRestored);
  }

  void _onConnectionRestored() {
    if (_hasPendingRequests) executePendingRequests();
  }

  String? _dbOpenedAccId;
  void _ensureDBOpened() {
    final accId = activeAccId();
    if (accId == _dbOpenedAccId) return; // if both null, means no db will be opened, meaning db operations will not execute.. keikaku dori

    _dbOpenedAccId = accId;
    _pendingRequestsDBIdle?.close();
    _pendingRequestsDBIdle = DBWrapper.open(_dbDirectory, 'pending_history_$accId');
    _pendingRequestsCompleter?.completeIfWasnt();
    _pendingRequestsCompleter = null;
    executePendingRequests();
  }

  DBWrapper? _pendingRequestsDBIdle;
  DBWrapper? get _pendingRequestsDB {
    _ensureDBOpened();
    return _pendingRequestsDBIdle;
  }

  bool get _hasConnection => ConnectivityController.inst.hasConnection;

  bool _hasPendingRequests = true;

  Completer<void>? _pendingRequestsCompleter;

  void _addPendingRequest({required String videoId, required VideoStreamsResult? streamResult}) {
    _hasPendingRequests = true;
    final db = _pendingRequestsDB;
    if (db == null) return;

    final vId = streamResult?.videoId ?? videoId;
    final key = "${vId}_${DateTime.now().millisecondsSinceEpoch}";
    final map = {
      'videoId': vId,
      'statsPlaybackUrl': streamResult?.statsPlaybackUrl,
      'statsWatchtimeUrl': streamResult?.statsWatchtimeUrl,
    };
    db.putAsync(key, map);
  }

  List<String> getPendingRequestsSync() {
    final list = <String>[];
    _pendingRequestsDB?.loadEverythingKeyed(
      (key, value) {
        list.add(key);
      },
    );
    return list;
  }

  void executePendingRequests() async {
    if (!_hasConnection) return null;

    if (_pendingRequestsCompleter != null) {
      // -- already executing
      return;
    }

    _pendingRequestsCompleter ??= Completer<void>();

    final queue = Queue(parallel: 1);

    bool hadError = false;

    int itemsAddedToQueue = 0;

    final db = _pendingRequestsDB;

    db?.loadEverythingKeyed(
      (key, value) {
        if (hadError) return;
        if (!_hasConnection) {
          hadError = true;
          return;
        }

        itemsAddedToQueue++;

        queue.add(
          () async {
            if (hadError) return;
            if (!_hasConnection) {
              hadError = true;
              return;
            }

            bool added = false;
            try {
              String? statsPlaybackUrl = value['statsPlaybackUrl'];
              String? statsWatchtimeUrl = value['statsWatchtimeUrl'];
              if (statsPlaybackUrl == null && _hasConnection) {
                final videoId = value['videoId'] ?? key.substring(0, 11);
                final streamsRes = await YoutubeInfoController.video.fetchVideoStreams(videoId, forceRequest: true);
                statsPlaybackUrl = streamsRes?.statsPlaybackUrl;
                statsWatchtimeUrl ??= streamsRes?.statsWatchtimeUrl;
              }
              if (statsPlaybackUrl != null) {
                // -- we check beforehand to supress internal error
                final res = await YoutiPie.history.addVideoToHistory(
                  statsPlaybackUrl: statsPlaybackUrl,
                  statsWatchtimeUrl: statsWatchtimeUrl,
                );
                added = res.$1;
              }
            } catch (_) {}
            if (added || _hasConnection) {
              // had connection but didnt mark. idc
              db.deleteAsync(key);
            } else {
              hadError = true; // no connection, will not proceed anymore
            }
          },
        );
      },
    );

    if (itemsAddedToQueue > 0) await queue.onComplete;

    if (!hadError) _hasPendingRequests = false;

    _pendingRequestsCompleter?.completeIfWasnt();
    _pendingRequestsCompleter = null;
  }

  Future<bool?> markVideoWatched({required String videoId, required VideoStreamsResult? streamResult, bool errorOnMissingParam = true}) async {
    if (_hasPendingRequests) {
      executePendingRequests();
    }

    if (_pendingRequestsCompleter != null) {
      await _pendingRequestsCompleter!.future;
    }

    bool added = false;

    if (_hasConnection && !_hasPendingRequests) {
      String? statsPlaybackUrl = streamResult?.statsPlaybackUrl;
      String? statsWatchtimeUrl = streamResult?.statsWatchtimeUrl;
      if (statsPlaybackUrl == null) {
        final streamsRes = await YoutubeInfoController.video.fetchVideoStreams(videoId, forceRequest: false);
        statsPlaybackUrl = streamsRes?.statsPlaybackUrl;
        statsWatchtimeUrl ??= streamsRes?.statsWatchtimeUrl;
      }
      if (statsPlaybackUrl != null || errorOnMissingParam) {
        final res = await YoutiPie.history.addVideoToHistory(
          statsPlaybackUrl: statsPlaybackUrl,
          statsWatchtimeUrl: statsWatchtimeUrl,
        );
        added = res.$1;
      }
    }
    if (added) {
      return added;
    } else {
      _addPendingRequest(videoId: videoId, streamResult: streamResult);
      return null;
    }
  }

  Future<YoutiPieHistoryResult?> fetchHistory({ExecuteDetails? details}) {
    return YoutiPie.history.fetchHistory(details: details);
  }

  YoutiPieHistoryResult? fetchHistorySync() {
    final cache = YoutiPie.cacheBuilder.forHistoryVideos();
    return cache.read();
  }
}
