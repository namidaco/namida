/// copyright: google search request is originally from [@netlob](https://github.com/netlob/dart-lyrics), edited to fit Namida.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

import 'package:lrc/lrc.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rhttp/rhttp.dart';

import 'package:namida/class/fuzzy_matcher.dart';
import 'package:namida/class/http_response_wrapper.dart';
import 'package:namida/class/lyrics.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_details.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_base.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/wakelock_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/packages/lyrics_lrc_parsed_view.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';

class Lyrics {
  static Lyrics get inst => _instance;
  static final Lyrics _instance = Lyrics._internal();
  Lyrics._internal();

  static final _htmlTagRegex = RegExp(r'<[^>]*>');

  final textScrollController = NamidaScrollController.create(keepScrollOffset: true);

  final lrcViewKey = GlobalKey<LyricsLRCParsedViewState>();

  /// the miniplayer lyrics overlay's animated visibility (0..1).
  final lrcOverlayVisibility = ValueNotifier<double>(0.0);
  final lrcViewKeyFullscreen = GlobalKey<LyricsLRCParsedViewState>();

  final currentLyricsText = LrcText.empty.obs;
  final currentLyricsLRC = Rxn<Lrc>();
  final lyricsCanBeAvailable = true.obs;

  bool get _lyricsEnabled => settings.enableLyrics.value || settings.enableSimpleLyricsLine.value;
  bool get _lyricsPrioritizeEmbedded => settings.prioritizeEmbeddedLyrics.value;
  LyricsSource get _lyricsSource => settings.lyricsSource.value;

  final _lrcSearchManager = _LRCSearchManager();

  /// items that had nothing online, to not search again each time they play.
  final _notFoundOnlineMS = <Object, int>{};
  static const _kNotFoundOnlineRetryMS = 6 * 60 * 60 * 1000;

  static Object _onlineLookupKey(Playable item) {
    if (item is Selectable) return item.track;
    if (item is YoutubeID) return item.id;
    return item;
  }

  bool _wasNotFoundOnlineRecently(Object lookupKey) {
    final notFoundMS = _notFoundOnlineMS[lookupKey];
    if (notFoundMS == null) return false;
    final elapsedMS = DateTime.now().millisecondsSinceEpoch - notFoundMS;
    return elapsedMS < _kNotFoundOnlineRetryMS;
  }

  void _updateWidgets(Lrc? lrc, LrcText? txt) {
    WakelockController.inst.updateLRCStatus(lrc != null);
    for (final view in LyricsLRCParsedViewState.mountedViews) {
      view.fillLists(lrc, txt);
    }
  }

  void resetLyrics({bool hide = true}) {
    currentLyricsText.value = LrcText.empty;
    currentLyricsLRC.value = null;
    WakelockController.inst.updateLRCStatus(false);
    for (final view in LyricsLRCParsedViewState.mountedViews) {
      view.clearLists(hide: hide);
    }
  }

  Future<void> updateLyrics(Playable item) async {
    await _updateLyrics(item);
    if (!settings.tutorial.lyricsFullscreenTipSeen.value) {
      if (currentLyricsLRC.value != null || currentLyricsText.value.text.isNotEmpty) {
        snackyy(
          message: lang.longPressTheLyricsToEnterFullscreen,
          top: false,
          displayDuration: SnackDisplayDuration.tutorial,
          icon: Broken.book_saved,
          button: SnackbarButton(
            text: lang.done,
            function: () => settings.tutorial.lyricsFullscreenTipSeen.save(true),
          ),
        );
      }
    }
  }

  String _cleanPlainLyrics(String lyrics) {
    return LrcParser.cleanPlainLyrics(lyrics);
  }

  /// The view is only hidden once the lookup settles with nothing, otherwise a hide & show would
  /// cross-fade over each other whenever the new lyrics arrive right away (cached/device ones do).
  Future<void> _updateLyrics(Playable item) async {
    resetLyrics(hide: false);
    bool checkInterrupted() => Player.inst.currentItem.value != item;

    try {
      textScrollController.jumpTo(0);
    } catch (_) {}

    lyricsCanBeAvailable.value = true;

    final resolved = await _resolveLyrics(item, checkInterrupted);
    if (resolved == null || checkInterrupted()) return;

    final lrc = resolved.lrc;
    final txt = resolved.txt;
    if (lrc != null) {
      currentLyricsLRC.value = lrc;
    } else if (txt != null) {
      currentLyricsText.value = txt;
    } else if (!resolved.canBeAvailable) {
      lyricsCanBeAvailable.value = false;
    }
    _updateWidgets(lrc, txt);
  }

  static const _LyricsResolveResult _noLyrics = (lrc: null, txt: null, canBeAvailable: true);
  static const _LyricsResolveResult _unavailableLyrics = (lrc: null, txt: null, canBeAvailable: false);

  /// null when interrupted.
  Future<_LyricsResolveResult?> _resolveLyrics(Playable item, bool Function() checkInterrupted) async {
    if (!_lyricsEnabled) return _noLyrics;

    final LrcSearchUtils? lrcUtils = await LrcSearchUtils.fromPlayable(item);

    if (lrcUtils == null) return _noLyrics;
    if (checkInterrupted()) return null;

    final embedded = lrcUtils.embeddedLyrics;
    if (embedded.startsWith('IGNORE')) return _noLyrics;

    final local = await pickLocalLyrics(lrcUtils, embedded);
    final localLyrics = local.isEmbedded ? embedded : await local.file?.readLrcString();
    if (localLyrics != null) return _parseLocalLyrics(localLyrics);

    final source = _lyricsSource;
    final lookupKey = _onlineLookupKey(item);
    final canSearchOnline = source != LyricsSource.local && !_wasNotFoundOnlineRecently(lookupKey);
    if (!canSearchOnline) return _unavailableLyrics;

    // -- nothing local, hide now instead of holding an empty overlay for the whole network request.
    if (checkInterrupted()) return null;
    _updateWidgets(null, null);

    /// 1. database
    /// 2. google search
    final lrcLyrics = await _fetchLRCBasedLyrics(lrcUtils, source);

    if (checkInterrupted()) return null;

    final lrc = lrcLyrics.lrc;
    if (lrc != null) return (lrc: lrc, txt: null, canBeAvailable: true);
    final lrcAsText = lrcLyrics.txt;
    if (lrcAsText != null) return (lrc: null, txt: LrcText.fromText(_cleanPlainLyrics(lrcAsText)), canBeAvailable: true);

    final textLyrics = await _fetchTextBasedLyrics(lrcUtils, source);

    if (checkInterrupted()) return null;

    final text = textLyrics.txt;
    if (text != '') return (lrc: null, txt: LrcText.fromText(_cleanPlainLyrics(text)), canBeAvailable: true);

    final didSearchFail = lrcLyrics.didSearchFail || textLyrics.didSearchFail;
    if (!didSearchFail) _notFoundOnlineMS[lookupKey] = DateTime.now().millisecondsSinceEpoch;
    return _unavailableLyrics;
  }

  static const LocalLyricsPick _noLocalLyrics = (file: null, isEmbedded: false);
  static const LocalLyricsPick _embeddedLocalLyrics = (file: null, isEmbedded: true);

  /// the local lyrics [updateLyrics] shows before searching online, [embedded] can be newer than the ones in [lrcUtils].
  ///
  /// 1. track embedded, when prioritized
  /// 2. cached/device lrc, the location lyrics are saved in goes first
  /// 3. track embedded
  /// 4. cached/device txt
  Future<LocalLyricsPick> pickLocalLyrics(LrcSearchUtils lrcUtils, String embedded) async {
    if (embedded.startsWith('IGNORE')) return _noLocalLyrics;
    final hasEmbedded = embedded != '';
    if (hasEmbedded && _lyricsPrioritizeEmbedded) return _embeddedLocalLyrics;
    if (_lyricsSource == LyricsSource.internet) return _noLocalLyrics;

    final files = await lrcUtils.firstLyricsFiles(includeTxt: !hasEmbedded);
    final lrc = files.lrc;
    if (lrc != null) return (file: lrc, isEmbedded: false);
    if (hasEmbedded) return _embeddedLocalLyrics;
    return (file: files.txt, isEmbedded: false);
  }

  _LyricsResolveResult _parseLocalLyrics(String lyrics) {
    final lrc = lyrics.parseLRC();
    if (lrc != null && lrc.lyrics.isNotEmpty) return (lrc: lrc, txt: null, canBeAvailable: true);
    final cleanLyrics = _cleanPlainLyrics(lyrics);
    final txt = LrcText.fromText(cleanLyrics);
    return (lrc: null, txt: txt, canBeAvailable: true);
  }

  Future<List<LyricsModel>> searchLRCLyricsFromInternet({
    required LrcSearchUtils lrcUtils,
    String? customQuery,
    bool allProviders = false,
    void Function(List<LyricsModel> lyrics)? onPartial,
  }) async {
    final searchTries = lrcUtils.searchDetailsQueries();
    if (searchTries.isEmpty) {
      customQuery ??= lrcUtils.initialSearchTextHint;
      if (customQuery.isEmpty) return [];
    }

    final res = await _searchLRCLyricsFromInternet(
      lrcUtils: lrcUtils,
      customQuery: customQuery,
      allProviders: allProviders,
      onPartial: onPartial,
    );
    return res.lyrics;
  }

  Future<_LRCSearchResult> _searchLRCLyricsFromInternet({
    required LrcSearchUtils lrcUtils,
    String? customQuery,
    bool allProviders = false,
    void Function(List<LyricsModel> lyrics)? onPartial,
  }) async {
    final searchTries = lrcUtils.searchDetailsQueries();
    if (searchTries.isEmpty) {
      customQuery ??= lrcUtils.initialSearchTextHint;
      if (customQuery.isEmpty) return _LRCSearchResult.empty;
    }

    return await _lrcSearchManager.search(
      queries: searchTries,
      customQuery: customQuery,
      providers: LyricsProvider.values,
      allProviders: allProviders,
      onPartial: onPartial,
    );
  }

  /// a save made by the user asks for the storage permission when the location couldn't be written to, before going for the cache.
  Future<File> saveLyricsByUser(LrcSearchUtils lrcUtils, String lyrics, bool isSynced) async {
    File? failedFile;
    File? deviceFile = await lrcUtils.saveLyricsToDevice(lyrics, isSynced, onFailed: (file) => failedFile = file);
    final failed = failedFile;
    if (failed != null) {
      final hasPermission = await requestManageStoragePermission(showError: false);
      if (hasPermission) deviceFile = await lrcUtils.saveLyricsToDevice(lyrics, isSynced);
      if (deviceFile == null) {
        snackyy(
          title: lang.lyricsSaveLocationNotWritable,
          message: failed.path,
          isError: true,
        );
      }
    }
    if (deviceFile != null) return deviceFile;
    return lrcUtils.saveLyricsToCache(lyrics, isSynced);
  }

  /// with [LyricsSource.internet] nothing local was looked up, a lyrics file that is already there must not get replaced.
  Future<void> _saveFetchedLyrics(LrcSearchUtils lrcUtils, String lyrics, bool isSynced, LyricsSource source) async {
    if (source == LyricsSource.internet) {
      await lrcUtils.saveLyricsToCache(lyrics, isSynced);
    } else {
      await lrcUtils.saveLyrics(lyrics, isSynced);
    }
  }

  Future<_LRCFetchResult> _fetchLRCBasedLyrics(LrcSearchUtils lrcUtils, LyricsSource source) async {
    final res = await _searchLRCLyricsFromInternet(lrcUtils: lrcUtils);
    final lyricsModelToUse = res.lyrics.firstOrNull;
    if (lyricsModelToUse != null && lyricsModelToUse.lyrics.isNotEmpty == true) {
      final parsedLrc = lyricsModelToUse.synced ? lyricsModelToUse.lyrics.parseLRC() : null;
      final isSynced = parsedLrc != null;
      await _saveFetchedLyrics(lrcUtils, lyricsModelToUse.lyrics, isSynced, source);
      if (parsedLrc != null) {
        return (lrc: parsedLrc, txt: null, didSearchFail: false);
      } else {
        return (lrc: null, txt: lyricsModelToUse.lyrics, didSearchFail: false);
      }
    }
    return (lrc: null, txt: null, didSearchFail: res.hadFailure);
  }

  Future<_TextFetchResult> _fetchTextBasedLyrics(LrcSearchUtils lrcUtils, LyricsSource source) async {
    // -- [pickLocalLyrics] already returns the txt file and the embedded lyrics, looking again only costs io.
    // final lyricsFile = lrcUtils.cachedTxtFile;
    // if (source != LyricsSource.internet && await lyricsFile.existsAndValid()) {
    //   return await lyricsFile.readLrcString();
    // } else if (source != LyricsSource.internet && trackLyrics != '') {
    //   return trackLyrics;
    // }

    /// download lyrics
    final lyrics = await _fetchLyricsGoogle(lrcUtils.searchQueriesGoogle());
    if (lyrics == null) return (txt: '', didSearchFail: true);
    if (lyrics != '') {
      final formattedText = lyrics.replaceAll(_htmlTagRegex, '');
      await _saveFetchedLyrics(lrcUtils, formattedText, false, source);
      return (txt: formattedText, didSearchFail: false);
    }
    return (txt: '', didSearchFail: false);
  }

  /// null when nothing was found and a request has failed.
  Future<String?> _fetchLyricsGoogle(List<String> possibleQueries) async {
    if (possibleQueries.isEmpty) return '';
    return await _fetchLyricsGoogleIsolate.thready(possibleQueries);
  }

  static Future<String?> _fetchLyricsGoogleIsolate(List<String> searches) async {
    const url = "https://www.google.com/search?client=safari&rls=en&ie=UTF-8&oe=UTF-8&q=";
    const delimiter1 = '</div></div></div></div><div class="hwc"><div class="BNeawe tAd8D AP7Wnd"><div><div class="BNeawe tAd8D AP7Wnd">';
    const delimiter2 = '</div></div></div></div></div><div><span class="hwc"><div class="BNeawe uEec3 AP7Wnd">';

    bool hadFailure = false;

    Future<String> requestQuery(String searchText) async {
      String body;
      try {
        final res = await Rhttp.get(Uri.encodeFull("$url$searchText")).timeout(const Duration(seconds: 10));
        body = res.body;
      } catch (_) {
        hadFailure = true;
        return '';
      }
      try {
        final lyricsRes = body.substring(body.indexOf(delimiter1) + delimiter1.length, body.lastIndexOf(delimiter2));
        if (lyricsRes.contains('<meta charset="UTF-8">')) return '';
        if (lyricsRes.contains('please enable javascript on your web browser')) return '';
        if (lyricsRes.contains('Error 500 (Server Error)')) return '';
        if (lyricsRes.contains('systems have detected unusual traffic from your computer network')) return '';
        return lyricsRes;
      } catch (_) {
        return '';
      }
    }

    String lyrics = '';

    for (final q in searches) {
      lyrics = await requestQuery(q);
      if (lyrics != '') break;
    }

    if (lyrics == '' && hadFailure) return null;

    // final List<String> split = lyrics.split('\n');
    // String result = '';
    // for (int i = 0; i < split.length; i++) {
    //   result = '$result${split[i]}\n';
    // }
    // return result.trim();
    return lyrics;
  }
}

class _LRCSearchRequest {
  final int token;
  final List<LRCSearchDetails> queries;
  final String? customQuery;
  final List<LyricsProvider> providers;
  final bool allProviders;

  const _LRCSearchRequest({
    required this.token,
    required this.queries,
    required this.customQuery,
    required this.providers,
    required this.allProviders,
  });
}

class _LRCSearchResult {
  final int token;
  final List<LyricsModel> lyrics;
  final bool done;

  /// a request has failed, empty [lyrics] don't mean there are none.
  final bool hadFailure;

  const _LRCSearchResult({
    required this.token,
    required this.lyrics,
    required this.done,
    required this.hadFailure,
  });

  static const empty = _LRCSearchResult(token: -1, lyrics: [], done: true, hadFailure: false);
  static const interrupted = _LRCSearchResult(token: -1, lyrics: [], done: true, hadFailure: true);
}

class _LRCSearchManager with PortsProvider<SendPort> {
  _LRCSearchManager();

  int _latestToken = 0;
  Completer<_LRCSearchResult>? _completer;
  void Function(List<LyricsModel> lyrics)? _onPartial;

  Future<_LRCSearchResult> search({
    required List<LRCSearchDetails> queries,
    String? customQuery,
    required List<LyricsProvider> providers,
    required bool allProviders,
    void Function(List<LyricsModel> lyrics)? onPartial,
  }) async {
    if (providers.isEmpty) return _LRCSearchResult.empty;

    final token = ++_latestToken;
    _completer?.completeIfWasnt(_LRCSearchResult.interrupted);
    final completer = _completer = Completer<_LRCSearchResult>();
    _onPartial = onPartial;

    if (!isInitialized) await initialize();
    if (token != _latestToken) return _LRCSearchResult.interrupted;

    final request = _LRCSearchRequest(
      token: token,
      queries: queries,
      customQuery: customQuery,
      providers: providers,
      allProviders: allProviders,
    );
    await sendPort(request);
    return completer.future;
  }

  @override
  void onResult(dynamic result) {
    result as _LRCSearchResult;
    if (result.token != _latestToken) return;
    if (result.done) {
      _completer?.completeIfWasnt(result);
      _completer = null;
      _onPartial = null;
    } else {
      _onPartial?.call(result.lyrics);
    }
  }

  @override
  IsolateFunctionReturnBuild<SendPort> isolateFunction(SendPort port) {
    return IsolateFunctionReturnBuild(_prepareResourcesAndSearch, port);
  }

  static void _prepareResourcesAndSearch(SendPort sendPort) async {
    await Rhttp.init();
    final mainRequester = HttpClientWrapper.createSync();

    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    String appVersion = '';
    try {
      final res = await PackageInfo.fromPlatform();
      appVersion = res.version;
    } catch (_) {}

    final defaultHeaders = {
      'User-Agent': 'namida $appVersion (${AppSocial.GITHUB})',
    };

    final searcher = _LRCProvidersSearcher(mainRequester, defaultHeaders);
    _LRCSearchSession? activeSession;

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (p == PortsProviderMessages.disposed) {
        activeSession?.cancel();
        recievePort.close();
        streamSub?.cancel();
        return;
      }

      if (p is _LRCSearchRequest) {
        activeSession?.cancel();
        final session = activeSession = _LRCSearchSession(p);

        void send(List<LyricsModel> lyrics, bool done) {
          if (session.cancelled) return;
          sendPort.send(_LRCSearchResult(token: p.token, lyrics: lyrics, done: done, hadFailure: session.hadFailure));
        }

        final lyrics = await searcher.search(session, onPartial: (lyrics) => send(lyrics, false));
        send(lyrics, true);
        if (identical(activeSession, session)) activeSession = null;
      }
    });

    sendPort.send(PortsProviderMessages.prepared);
  }
}

class _LRCSearchSession {
  final _LRCSearchRequest request;
  final cancelToken = CancelToken();

  bool _cancelled = false;
  bool _requestIssued = false;
  bool _hadFailure = false;

  bool get cancelled => _cancelled;
  bool get hadFailure => _hadFailure;

  _LRCSearchSession(this.request);

  void markRequestIssued() => _requestIssued = true;
  void markFailure() => _hadFailure = true;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    // -- cancel() never completes if the token was not attached to a request
    if (_requestIssued) cancelToken.cancel().ignore();
  }
}

class _LRCProvidersSearcher {
  final HttpClientWrapper _requester;
  final Map<String, String> _defaultHeaders;

  const _LRCProvidersSearcher(this._requester, this._defaultHeaders);

  static const _requestTimeout = Duration(seconds: 20);

  Future<List<LyricsModel>> search(_LRCSearchSession session, {required void Function(List<LyricsModel> lyrics) onPartial}) async {
    final request = session.request;
    final customQuery = request.customQuery ?? '';
    // -- kugou needs a request per candidate, auto mode only uses the first result anyway.
    final kugouLimit = request.allProviders ? 3 : 1;

    Future<List<LyricsModel>> searchProvider(LyricsProvider provider) async {
      if (customQuery != '') {
        return _fetch(session, provider, details: null, customQuery: customQuery, kugouLimit: kugouLimit);
      }
      for (final details in request.queries) {
        if (session.cancelled) break;
        final fetched = await _fetch(session, provider, details: details, customQuery: '', kugouLimit: kugouLimit);
        if (fetched.isNotEmpty) return fetched;
      }
      return [];
    }

    if (request.allProviders) {
      final all = await Future.wait(
        request.providers.map((provider) async {
          final fetched = await searchProvider(provider);
          if (fetched.isNotEmpty) onPartial(fetched);
          return fetched;
        }),
      );
      final merged = <LyricsModel>[];
      for (final list in all) {
        merged.addAll(list);
      }
      LyricsModel.removeDuplicateLyrics(merged);
      return merged;
    }

    for (final provider in request.providers) {
      if (session.cancelled) break;
      final fetched = await searchProvider(provider);
      if (fetched.isNotEmpty) return fetched;
    }
    return [];
  }

  Future<List<LyricsModel>> _fetch(
    _LRCSearchSession session,
    LyricsProvider provider, {
    required LRCSearchDetails? details,
    required String customQuery,
    required int kugouLimit,
  }) async {
    if (customQuery == '' && details == null) return [];
    if (session.cancelled) return [];
    try {
      return switch (provider) {
        LyricsProvider.lrclib => await _fetchLRCLIB(session, details: details, customQuery: customQuery),
        LyricsProvider.kugou => await _fetchKuGou(session, details: details, customQuery: customQuery, limit: kugouLimit),
      };
    } catch (_) {
      session.markFailure();
      return [];
    }
  }

  Future<dynamic> _getJson(_LRCSearchSession session, Uri uri) async {
    session.markRequestIssued();
    final response = await _requester.getUrl(uri.toString(), headers: _defaultHeaders, cancelToken: session.cancelToken).timeout(_requestTimeout);
    return jsonDecode(response.body);
  }

  static String _substringArtist(String artist) {
    int maxIndex = -1;
    maxIndex = artist.indexOf('(');
    if (maxIndex <= 0) maxIndex = artist.indexOf('[');
    return maxIndex <= 0 ? artist : artist.substring(0, maxIndex);
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  static String _formatLength(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final min = duration.inMinutes;
    final sec = duration.inSeconds.remainder(60);
    final ms = milliseconds.remainder(1000);
    return '${_pad2(min)}:${_pad2(sec)}.${ms.toString().padLeft(3, '0')}';
  }

  static int _targetDurationMS(LRCSearchDetails? details) {
    if (details == null || details.isDurationModified) return 0;
    return details.durationMS;
  }

  static void _rankCandidates(
    List<dynamic> items, {
    required _LyricsMatchScorer? scorer,
    required int targetMS,
    required String? Function(dynamic item) title,
    required String? Function(dynamic item) artist,
    required int? Function(dynamic item) durationMS,
  }) {
    if (items.isEmpty) return;
    const unknownDiff = 1 << 40;
    final ranked = <({int index, double score, int diff})>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final score = scorer?.score(title(item), artist(item)) ?? 1.0;
      if (score < _LyricsMatchScorer.acceptThreshold) continue;
      final d = durationMS(item);
      final diff = targetMS <= 0 || d == null || d <= 0 ? unknownDiff : (targetMS - d).abs();
      ranked.add((index: i, score: score, diff: diff));
    }
    ranked.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      final d = a.diff.compareTo(b.diff);
      return d != 0 ? d : a.index.compareTo(b.index);
    });
    final sorted = ranked.map((r) => items[r.index]).toList();
    items.length = sorted.length;
    items.setAll(0, sorted);
  }

  static String _buildLRC({required String lyrics, required String artist, required String album, required String title, required int durationMS}) {
    final lrcBuffer = StringBuffer();
    if (artist != '') lrcBuffer.writeln('[ar:$artist]');
    if (album != '') lrcBuffer.writeln('[al:$album]');
    if (title != '') lrcBuffer.writeln('[ti:$title]');
    if (durationMS > 0) lrcBuffer.writeln('[length:${_formatLength(durationMS)}]');
    lrcBuffer.write(lyrics);
    return lrcBuffer.toString();
  }

  static LyricsModel _model(String lyrics, bool synced, LyricsProvider provider) {
    return LyricsModel(
      lyrics: lyrics,
      isInCache: false,
      fromInternet: true,
      synced: synced,
      file: null,
      isEmbedded: false,
      provider: provider,
    );
  }

  // ==================== LRCLIB ====================

  Future<List<LyricsModel>> _fetchLRCLIB(_LRCSearchSession session, {required LRCSearchDetails? details, required String customQuery}) async {
    final params = <String, String>{};
    if (customQuery != '') {
      params['q'] = customQuery;
    } else if (details != null) {
      if (details.title != '') params['track_name'] = details.title;
      if (details.artist != '') params['artist_name'] = _substringArtist(details.artist);
      if (details.album != '') params['album_name'] = details.album;
    }
    if (params.isEmpty) return [];

    final jsonLists = (await _getJson(session, Uri.https('lrclib.net', '/api/search', params)) as List<dynamic>?) ?? [];
    if (jsonLists.isEmpty) return [];

    final targetMS = _targetDurationMS(details);
    _rankCandidates(
      jsonLists,
      scorer: details == null ? null : _LyricsMatchScorer(details),
      targetMS: targetMS,
      title: (r) => r['trackName'] as String?,
      artist: (r) => r['artistName'] as String?,
      durationMS: (r) => r['duration'] is num ? ((r['duration'] as num) * 1000).round() : null,
    );

    final fetched = <LyricsModel>[];
    for (var jsonRes in jsonLists) {
      final syncedLyrics = jsonRes?["syncedLyrics"] as String? ?? '';
      final plain = jsonRes?["plainLyrics"] as String? ?? '';
      if (syncedLyrics != '') {
        final durMS = jsonRes['duration'] is num ? ((jsonRes['duration'] as num) * 1000).round() : targetMS;
        final resultedLRC = _buildLRC(
          lyrics: syncedLyrics,
          artist: jsonRes['artistName'] ?? details?.artist ?? '',
          album: jsonRes['albumName'] ?? details?.album ?? '',
          title: jsonRes['trackName'] ?? details?.title ?? '',
          durationMS: durMS,
        );
        fetched.add(_model(resultedLRC, true, LyricsProvider.lrclib));
      } else if (plain != '') {
        fetched.add(_model(plain, false, LyricsProvider.lrclib));
      }
    }
    LyricsModel.removeDuplicateLyrics(fetched);
    return fetched;
  }

  // ==================== KuGou ====================

  Future<List<LyricsModel>> _fetchKuGou(_LRCSearchSession session, {required LRCSearchDetails? details, required String customQuery, required int limit}) async {
    String keyword = customQuery;
    if (keyword == '' && details != null) {
      keyword = [
        if (details.artist != '') _substringArtist(details.artist).trim(),
        if (details.title != '') details.title,
      ].join(' - ');
    }
    if (keyword == '') return [];

    final targetMS = _targetDurationMS(details);
    final searchUri = Uri.https('lyrics.kugou.com', '/search', {
      'ver': '1',
      'man': 'yes',
      'client': 'pc',
      'keyword': keyword,
      'duration': targetMS.toString(),
      'hash': '',
    });
    final searchJson = await _getJson(session, searchUri);
    final candidates = (searchJson?['candidates'] as List<dynamic>?) ?? [];
    if (candidates.isEmpty) return [];

    _rankCandidates(
      candidates,
      scorer: details == null ? null : _LyricsMatchScorer(details),
      targetMS: targetMS,
      title: (c) => c['song'] as String?,
      artist: (c) => c['singer'] as String?,
      durationMS: (c) => c['duration'] is num ? (c['duration'] as num).round() : null,
    );

    // -- kugou returns the same lyrics under multiple ids, each requiring a separate download.
    final seenInfo = <String>{};
    final fetched = <LyricsModel>[];
    for (final c in candidates) {
      if (fetched.length >= limit || session.cancelled) break;
      final id = c['id']?.toString() ?? '';
      final accesskey = c['accesskey']?.toString() ?? '';
      if (id == '' || accesskey == '') continue;
      if (!seenInfo.add('${c['song']}|${c['singer']}|${c['duration']}')) continue;

      final downloadUri = Uri.https('lyrics.kugou.com', '/download', {
        'ver': '1',
        'client': 'pc',
        'id': id,
        'accesskey': accesskey,
        'fmt': 'lrc',
        'charset': 'utf8',
      });
      try {
        final downloadJson = await _getJson(session, downloadUri);
        final content = downloadJson?['content'] as String? ?? '';
        if (content == '') continue;
        final lrc = utf8.decode(base64Decode(content)).trim();
        if (lrc == '') continue;
        final durMS = c['duration'] is num ? (c['duration'] as num).round() : targetMS;
        final lyrics = lrc.contains('[length:') || durMS <= 0 ? lrc : '[length:${_formatLength(durMS)}]\n$lrc';
        fetched.add(_model(lyrics, true, LyricsProvider.kugou));
      } catch (_) {
        session.markFailure();
      }
    }
    LyricsModel.removeDuplicateLyrics(fetched);
    return fetched;
  }
}

// by claude
class _LyricsMatchScorer {
  static const acceptThreshold = 0.7;

  final List<_MatchToken> _titleTokens;
  final List<_MatchToken> _artistTokens;
  final List<_MatchToken> _allTokens;

  /// catches different word splitting, ex: "Nightcall" vs "Night Call".
  late final _MatchToken _joinedTitle = _MatchToken(_titleTokens.map((t) => t.text).join());

  _LyricsMatchScorer._(this._titleTokens, this._artistTokens) : _allTokens = [..._titleTokens, ..._artistTokens];

  factory _LyricsMatchScorer(LRCSearchDetails details) {
    return _LyricsMatchScorer._(
      _MatchToken.tokenize(details.title, ignore: _kTitleNoiseTokens),
      _MatchToken.tokenize(_LRCProvidersSearcher._substringArtist(details.artist)),
    );
  }

  double score(String? title, String? artist) {
    final titleParts = _split(title);
    final artistParts = _split(artist);
    final allParts = artistParts.isEmpty ? titleParts : [...titleParts, ...artistParts];

    double titleScore = 1.0;
    if (_titleTokens.isNotEmpty) {
      titleScore = _coverage(_titleTokens, allParts);
      if (titleScore < 1.0 && (titleParts.length > 1 || _titleTokens.length > 1) && _joinedTitle.matches(titleParts.join())) titleScore = 1.0;
    }

    if (_artistTokens.isEmpty || artistParts.isEmpty) return titleScore;

    // -- either side may list extra artists, ex: "A & B" vs "B"
    final forward = _coverage(_artistTokens, allParts);
    final reverse = _reverseCoverage(_allTokens, artistParts);
    final artistScore = forward > reverse ? forward : reverse;

    return titleScore * 0.7 + artistScore * 0.3;
  }

  /// filler commonly found in video titles, never in lyrics databases.
  static const _kTitleNoiseTokens = {'official', 'video', 'audio', 'lyrics', 'lyric', 'music', 'hd', 'hq', '4k', 'visualizer', 'mv'};

  static List<String> _split(String? text) {
    if (text == null || text.isEmpty) return const [];
    final parts = <String>[];
    for (final p in text.cleanUpForComparison.split(' ')) {
      if (p.isNotEmpty) parts.add(p);
    }
    return parts;
  }

  /// fraction of [tokens] found in [parts].
  static double _coverage(List<_MatchToken> tokens, List<String> parts) {
    if (parts.isEmpty) return 0.0;
    int matched = 0;
    for (final token in tokens) {
      for (final part in parts) {
        if (token.matches(part)) {
          matched++;
          break;
        }
      }
    }
    return matched / tokens.length;
  }

  /// fraction of [parts] matched by any of [tokens].
  static double _reverseCoverage(List<_MatchToken> tokens, List<String> parts) {
    int matched = 0;
    for (final part in parts) {
      for (final token in tokens) {
        if (token.matches(part)) {
          matched++;
          break;
        }
      }
    }
    return matched / parts.length;
  }
}

class _MatchToken {
  final String text;
  final int length;
  final int maxDistance;
  final FuzzyMatcher _fuzzy;

  _MatchToken(this.text) : length = text.length, maxDistance = _maxDistanceFor(text.length), _fuzzy = FuzzyMatcher(text);

  /// [ignore]d words are dropped unless they make up the whole text.
  static List<_MatchToken> tokenize(String text, {Set<String>? ignore}) {
    final tokens = <_MatchToken>[];
    final ignored = <_MatchToken>[];
    for (final p in text.cleanUpForComparison.split(' ')) {
      if (p.isEmpty) continue;
      (ignore != null && ignore.contains(p) ? ignored : tokens).add(_MatchToken(p));
    }
    return tokens.isEmpty ? ignored : tokens;
  }

  /// insert/delete distance allowed, short tokens must match exactly.
  static int _maxDistanceFor(int length) => length >= 7
      ? 2
      : length >= 4
      ? 1
      : 0;

  bool matches(String other) {
    if (other == text) return true;
    if (maxDistance == 0) return false;
    if ((other.length - length).abs() > maxDistance) return false;
    return _fuzzy.distanceTo(other, other.length, maxDistance) <= maxDistance;
  }
}

class LrcText {
  final String text;
  final bool isRTL;

  const LrcText({
    required this.text,
    required this.isRTL,
  });

  static const empty = LrcText(
    text: '',
    isRTL: false,
  );

  factory LrcText.fromText(String text) {
    final textSample = text.substring(0, 100.withMaximum(text.length));
    final isRTL = LrcParser.isLrcLineRTL(textSample);
    return LrcText(
      text: text,
      isRTL: isRTL,
    );
  }
}

typedef LocalLyricsPick = ({File? file, bool isEmbedded});

typedef _LyricsResolveResult = ({Lrc? lrc, LrcText? txt, bool canBeAvailable});
typedef _LRCFetchResult = ({Lrc? lrc, String? txt, bool didSearchFail});
typedef _TextFetchResult = ({String txt, bool didSearchFail});
