/// copyright: google search request is originally from [@netlob](https://github.com/netlob/dart-lyrics), edited to fit Namida.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';

import 'package:lrc/lrc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rhttp/rhttp.dart';

import 'package:namida/base/ports_provider.dart';
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
import 'package:namida/packages/lyrics_lrc_parsed_view.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class Lyrics {
  static Lyrics get inst => _instance;
  static final Lyrics _instance = Lyrics._internal();
  Lyrics._internal();

  final textScrollController = NamidaScrollController.create(keepScrollOffset: true);

  final lrcViewKey = GlobalKey<LyricsLRCParsedViewState>();
  final lrcViewKeyFullscreen = GlobalKey<LyricsLRCParsedViewState>();

  final currentLyricsText = LrcText.empty.obs;
  final currentLyricsLRC = Rxn<Lrc>();
  final lyricsCanBeAvailable = true.obs;

  bool get _lyricsEnabled => settings.enableLyrics.value || settings.enableSimpleLyricsLine.value;
  bool get _lyricsPrioritizeEmbedded => settings.prioritizeEmbeddedLyrics.value;
  LyricsSource get _lyricsSource => settings.lyricsSource.value;

  final _lrcSearchManager = _LRCSearchManager();

  void _updateWidgets(Lrc? lrc, LrcText? txt) {
    WakelockController.inst.updateLRCStatus(lrc != null);
    lrcViewKey.currentState?.fillLists(lrc, txt);
    lrcViewKeyFullscreen.currentState?.fillLists(lrc, txt);
  }

  void resetLyrics() {
    currentLyricsText.value = LrcText.empty;
    currentLyricsLRC.value = null;
    WakelockController.inst.updateLRCStatus(false);
    lrcViewKey.currentState?.clearLists();
    lrcViewKeyFullscreen.currentState?.clearLists();
  }

  Future<void> updateLyrics(Playable item) async {
    await _updateLyrics(item);
    if (settings.tutorial.lyricsLongPressFullScreen) {
      if (currentLyricsLRC.value != null || currentLyricsText.value.text.isNotEmpty) {
        snackyy(
          message: lang.longPressTheLyricsToEnterFullscreen,
          top: false,
          displayDuration: SnackDisplayDuration.tutorial,
          icon: Broken.book_saved,
          button: SnackbarButton(
            text: lang.done,
            function: () => settings.tutorial.save(lyricsLongPressFullScreen: false),
          ),
        );
      }
    }
  }

  String _cleanPlainLyrics(String lyrics) {
    return LrcParser.cleanPlainLyrics(lyrics);
  }

  Future<void> _updateLyrics(Playable item) async {
    resetLyrics();
    bool checkInterrupted() => Player.inst.currentItem.value != item;

    try {
      textScrollController.jumpTo(0);
    } catch (_) {}

    lyricsCanBeAvailable.value = true;
    if (!_lyricsEnabled) return;

    final LrcSearchUtils? lrcUtils = await LrcSearchUtils.fromPlayable(item);

    if (lrcUtils == null) return;
    if (checkInterrupted()) return;

    final embedded = lrcUtils.embeddedLyrics;
    if (embedded.startsWith('IGNORE')) return;

    if (_lyricsPrioritizeEmbedded && embedded != '') {
      final lrc = embedded.parseLRC();
      if (lrc != null && lrc.lyrics.isNotEmpty) {
        currentLyricsLRC.value = lrc;
        _updateWidgets(lrc, null);
      } else {
        final txt = LrcText.fromText(_cleanPlainLyrics(embedded));
        currentLyricsText.value = txt;
        _updateWidgets(null, txt);
      }
      return;
    }

    /// 1. device lrc
    /// 2. cached lrc
    /// 3. track embedded lrc
    /// 4. database.
    final lrcLyrics = await _fetchLRCBasedLyrics(lrcUtils, embedded, _lyricsSource);

    if (checkInterrupted()) return;

    if (lrcLyrics.$1 != null) {
      currentLyricsLRC.value = lrcLyrics.$1;
      _updateWidgets(lrcLyrics.$1, null);
      return;
    } else if (lrcLyrics.$2 != null) {
      final txt = LrcText.fromText(_cleanPlainLyrics(lrcLyrics.$2!));
      currentLyricsText.value = txt;
      _updateWidgets(null, txt);
      return;
    }

    if (checkInterrupted()) return;

    /// 1. cached txt lyrics
    /// 2. track embedded txt
    /// 3. google search
    final textLyrics = await _fetchTextBasedLyrics(lrcUtils, embedded, _lyricsSource);

    if (checkInterrupted()) return;

    if (textLyrics != '') {
      final txt = LrcText.fromText(_cleanPlainLyrics(textLyrics));
      currentLyricsText.value = txt;
      _updateWidgets(null, txt);
    } else {
      lyricsCanBeAvailable.value = false;
    }
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

    return await _lrcSearchManager.search(
      queries: searchTries,
      customQuery: customQuery,
      providers: LyricsProvider.values,
      allProviders: allProviders,
      onPartial: onPartial,
    );
  }

  Future<(Lrc?, String?)> _fetchLRCBasedLyrics(LrcSearchUtils lrcUtils, String trackLyrics, LyricsSource source) async {
    String? lrcContent;

    /// 1. device lrc
    /// 2. cached lrc
    /// 3. track embedded
    if (source != LyricsSource.internet) {
      final syncedInCache = lrcUtils.cachedLRCFile;
      if (await syncedInCache.existsAndValid()) {
        lrcContent = await syncedInCache.readLrcString();
      }

      if (lrcContent == null) {
        final deviceLrcFile = await lrcUtils.firstDeviceLRCFile();
        lrcContent = await deviceLrcFile?.readLrcString();
      }
      if (lrcContent == null && trackLyrics != '') {
        lrcContent = trackLyrics;
      }
      // -- this should be prioritized before searching network again
      // -- if txt is in cache, then either the user has chosen a file or lrc wasn't found
      // -- so it has to be a good reason why this is here
      // -- turning this off will cost time and network each time trynna fetch lyrics
      if (lrcContent == null) {
        final textInCache = lrcUtils.cachedTxtFile;
        if (await textInCache.existsAndValid()) {
          lrcContent = await textInCache.readLrcString();
        }
      }
    }

    /// 4. if still null, fetch from database.
    if (source != LyricsSource.local && lrcContent == null) {
      final lyrics = await searchLRCLyricsFromInternet(lrcUtils: lrcUtils);
      final lyricsModelToUse = lyrics.firstOrNull;
      if (lyricsModelToUse != null && lyricsModelToUse.lyrics.isNotEmpty == true) {
        final parsedLrc = lyricsModelToUse.synced ? lyricsModelToUse.lyrics.parseLRC() : null;
        if (parsedLrc != null) {
          final syncedInCache = lrcUtils.cachedLRCFile;
          await syncedInCache.writeAsString(lyricsModelToUse.lyrics);
          return (parsedLrc, null);
        } else {
          final plainInCache = lrcUtils.cachedTxtFile;
          await plainInCache.writeAsString(lyricsModelToUse.lyrics);
          return (null, lyricsModelToUse.lyrics);
        }
      }
    }

    final lrc = lrcContent?.parseLRC();
    if (lrc != null && lrc.lyrics.isNotEmpty) {
      return (lrc, null);
    } else {
      return (null, lrcContent);
    }
  }

  Future<String> _fetchTextBasedLyrics(LrcSearchUtils lrcUtils, String trackLyrics, LyricsSource source) async {
    final lyricsFile = lrcUtils.cachedTxtFile;

    /// get from storage
    if (source != LyricsSource.internet && await lyricsFile.existsAndValid()) {
      return await lyricsFile.readLrcString();
    } else if (source != LyricsSource.internet && trackLyrics != '') {
      return trackLyrics;
    }
    /// download lyrics
    else if (source != LyricsSource.local) {
      final lyrics = await _fetchLyricsGoogle(lrcUtils.searchQueriesGoogle());
      final regex = RegExp(r'<[^>]*>');
      if (lyrics != '') {
        final formattedText = lyrics.replaceAll(regex, '');
        await lyricsFile.writeAsString(formattedText);
        return formattedText;
      }
    }
    return '';
  }

  Future<String> _fetchLyricsGoogle(List<String> possibleQueries) async {
    if (possibleQueries.isEmpty) return '';
    return await _fetchLyricsGoogleIsolate.thready(possibleQueries);
  }

  static Future<String> _fetchLyricsGoogleIsolate(List<String> searches) async {
    const url = "https://www.google.com/search?client=safari&rls=en&ie=UTF-8&oe=UTF-8&q=";
    const delimiter1 = '</div></div></div></div><div class="hwc"><div class="BNeawe tAd8D AP7Wnd"><div><div class="BNeawe tAd8D AP7Wnd">';
    const delimiter2 = '</div></div></div></div></div><div><span class="hwc"><div class="BNeawe uEec3 AP7Wnd">';

    Future<String> requestQuery(String searchText) async {
      try {
        final res = await Rhttp.get(Uri.encodeFull("$url$searchText")).timeout(const Duration(seconds: 10));
        final body = res.body;
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

  const _LRCSearchResult({
    required this.token,
    required this.lyrics,
    required this.done,
  });
}

class _LRCSearchManager with PortsProvider<SendPort> {
  _LRCSearchManager();

  int _latestToken = 0;
  Completer<List<LyricsModel>>? _completer;
  void Function(List<LyricsModel> lyrics)? _onPartial;

  Future<List<LyricsModel>> search({
    required List<LRCSearchDetails> queries,
    String? customQuery,
    required List<LyricsProvider> providers,
    required bool allProviders,
    void Function(List<LyricsModel> lyrics)? onPartial,
  }) async {
    if (providers.isEmpty) return [];

    final token = ++_latestToken;
    _completer?.completeIfWasnt([]);
    final completer = _completer = Completer<List<LyricsModel>>();
    _onPartial = onPartial;

    if (!isInitialized) await initialize();
    if (token != _latestToken) return [];

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
      _completer?.completeIfWasnt(result.lyrics);
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
      if (PortsProvider.isDisposeMessage(p)) {
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
          sendPort.send(_LRCSearchResult(token: p.token, lyrics: lyrics, done: done));
        }

        final lyrics = await searcher.search(session, onPartial: (lyrics) => send(lyrics, false));
        send(lyrics, true);
        if (identical(activeSession, session)) activeSession = null;
      }
    });

    sendPort.send(null); // prepared
  }
}

class _LRCSearchSession {
  final _LRCSearchRequest request;
  final cancelToken = CancelToken();

  bool _cancelled = false;
  bool _requestIssued = false;

  bool get cancelled => _cancelled;

  _LRCSearchSession(this.request);

  void markRequestIssued() => _requestIssued = true;

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
      } catch (_) {}
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
