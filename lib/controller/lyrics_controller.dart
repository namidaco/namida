/// copyright: google search request is originally from [@netlob](https://github.com/netlob/dart-lyrics), edited to fit Namida.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';

import 'package:lrc/lrc.dart';
import 'package:rhttp/rhttp.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/http_response_wrapper.dart';
import 'package:namida/class/lyrics.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_details.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_base.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/wakelock_controller.dart';
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

  final currentLyricsText = ''.obs;
  final currentLyricsLRC = Rxn<Lrc>();
  final lyricsCanBeAvailable = true.obs;

  Playable? _currentItem;

  bool get _lyricsEnabled => settings.enableLyrics.value;
  bool get _lyricsPrioritizeEmbedded => settings.prioritizeEmbeddedLyrics.value;
  LyricsSource get _lyricsSource => settings.lyricsSource.value;

  final _lrcSearchManager = _LRCSearchManager();

  void _updateWidgets(Lrc? lrc, String? txt) {
    WakelockController.inst.updateLRCStatus(lrc != null);
    lrcViewKey.currentState?.fillLists(lrc, txt);
    lrcViewKeyFullscreen.currentState?.fillLists(lrc, txt);
  }

  void resetLyrics() {
    _currentItem = null;
    currentLyricsText.value = '';
    currentLyricsLRC.value = null;
    WakelockController.inst.updateLRCStatus(false);
    lrcViewKey.currentState?.clearLists();
    lrcViewKeyFullscreen.currentState?.clearLists();
  }

  Future<void> updateLyrics(Playable item) async {
    await _updateLyrics(item);
    if (settings.tutorial.lyricsLongPressFullScreen) {
      if (currentLyricsLRC.value != null || currentLyricsText.value.isNotEmpty) {
        snackyy(
          message: lang.LONG_PRESS_THE_LYRICS_TO_ENTER_FULLSCREEN,
          top: false,
          displayDuration: SnackDisplayDuration.tutorial,
          icon: Broken.book_saved,
          button: (
            lang.DONE,
            () => settings.tutorial.save(lyricsLongPressFullScreen: false),
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
    _currentItem = item;
    bool checkInterrupted() => _currentItem != item;

    try {
      textScrollController.jumpTo(0);
    } catch (_) {}

    lyricsCanBeAvailable.value = true;
    if (!_lyricsEnabled) return;

    final LrcSearchUtils? lrcUtils = await LrcSearchUtils.fromPlayable(item);

    if (lrcUtils == null) return;

    final embedded = lrcUtils.embeddedLyrics;
    if (embedded.startsWith('IGNORE')) return;

    if (_lyricsPrioritizeEmbedded && embedded != '') {
      final lrc = embedded.parseLRC();
      if (lrc != null && lrc.lyrics.isNotEmpty) {
        currentLyricsLRC.value = lrc;
        _updateWidgets(lrc, null);
      } else {
        final txt = _cleanPlainLyrics(embedded);
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
      final txt = _cleanPlainLyrics(lrcLyrics.$2!);
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
      final txt = _cleanPlainLyrics(textLyrics);
      currentLyricsText.value = txt;
      _updateWidgets(null, txt);
    } else {
      lyricsCanBeAvailable.value = false;
    }
  }

  Future<List<LyricsModel>> searchLRCLyricsFromInternet({required LrcSearchUtils lrcUtils, String? customQuery}) async {
    final searchTries = lrcUtils.searchDetailsQueries();
    if (searchTries.isEmpty) {
      customQuery ??= lrcUtils.initialSearchTextHint;
      if (customQuery.isEmpty) return [];
    }

    return await _lrcSearchManager.search(
      queries: searchTries,
      customQuery: customQuery,
    );
  }

  Future<(Lrc?, String?)> _fetchLRCBasedLyrics(LrcSearchUtils lrcUtils, String trackLyrics, LyricsSource source) async {
    String? lrcContent;

    /// 1. device lrc
    /// 2. cached lrc
    /// 3. track embedded
    if (source != LyricsSource.internet) {
      final lyricsFilesLocal = lrcUtils.deviceLRCFiles;
      for (final lf in lyricsFilesLocal) {
        if (await lf.existsAndValid()) {
          lrcContent = await lf.readLrcString();
          break;
        }
      }
      if (lrcContent == null) {
        final syncedInCache = lrcUtils.cachedLRCFile;
        if (await syncedInCache.existsAndValid()) {
          lrcContent = await syncedInCache.readLrcString();
        } else if (trackLyrics != '') {
          lrcContent = trackLyrics;
        }
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

class _LRCSearchManager with PortsProvider<SendPort> {
  _LRCSearchManager();

  Completer<List<LyricsModel>>? _completer;

  Future<List<LyricsModel>> search({
    required List<LRCSearchDetails> queries,
    String? customQuery,
  }) async {
    _completer?.completeIfWasnt([]);
    _completer = Completer<List<LyricsModel>>();

    if (!isInitialized) await initialize();
    final p = customQuery != null && customQuery.isNotEmpty ? customQuery : queries;
    await sendPort(p);
    final res = await _completer?.future ?? [];
    _completer = null;
    return res;
  }

  @override
  void onResult(dynamic result) {
    _completer?.completeIfWasnt(result as List<LyricsModel>);
    _completer = null;
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

    String substringArtist(String artist) {
      int maxIndex = -1;
      maxIndex = artist.indexOf('(');
      if (maxIndex <= 0) maxIndex = artist.indexOf('[');
      return maxIndex <= 0 ? artist : artist.substring(0, maxIndex);
    }

    Future<List<LyricsModel>> fetchLRCBasedLyricsFromInternet({LRCSearchDetails? details, String customQuery = ''}) async {
      if (customQuery == '' && details == null) return [];
      String formatTime(int milliseconds) {
        final duration = Duration(milliseconds: milliseconds);
        final min = duration.inMinutes.remainder(60);
        final sec = duration.inSeconds.remainder(60);
        final ms = milliseconds;
        String pad(int n) => n.toString().padLeft(2, '0');
        final formattedTime = '${pad(min)}:${pad(sec)}.${pad(ms)}';
        return formattedTime;
      }

      String tail = '';
      if (customQuery != '') {
        tail = 'q=$customQuery';
      } else if (details != null) {
        final params = [
          if (details.title != '') 'track_name=${details.title}',
          if (details.artist != '') 'artist_name=${substringArtist(details.artist)}',
          if (details.album != '') 'album_name=${details.album}',
        ].join('&');
        tail = params;
      }

      if (tail != '') {
        final urlPre = "https://lrclib.net/api/search?$tail";
        final url = Uri.encodeFull(urlPre);

        try {
          final response = await mainRequester.getUrl(url, cancelToken: null);
          final jsonLists = (jsonDecode(response.body) as List<dynamic>?) ?? [];
          final fetched = <LyricsModel>[];

          final mainDuration = details?.durationMS ?? 0;
          final isDurationModified = details?.isDurationModified ?? false;
          if (mainDuration > 0 && !isDurationModified) {
            // -- prefer lyrics with closer duration (if info the same)
            jsonLists.sort(
              (a, b) {
                final sameInfo =
                    (a['trackName'] is String && a['trackName'] == b['trackName']) && //
                    (a['artistName'] is String && a['artistName'] == b['artistName']);
                if (sameInfo) {
                  try {
                    final aDurMS = ((a['duration'] as num) * 1000).round(); // ex: 30
                    final bDurMS = ((b['duration'] as num) * 1000).round(); // ex: 20
                    final aDiff = (mainDuration - aDurMS).abs(); // ex: 0 (30-30)
                    final bDiff = (mainDuration - bDurMS).abs(); // ex: 10 (30-20)
                    if (aDiff < bDiff) {
                      return -1;
                    } else if (aDiff > bDiff) {
                      return 1;
                    } else if (aDiff == bDiff) {
                      return 0;
                    }
                  } catch (_) {}
                }
                return 0;
              },
            );
          }

          jsonLists.loop((jsonRes) {
            final syncedLyrics = jsonRes?["syncedLyrics"] as String? ?? '';
            final plain = jsonRes?["plainLyrics"] as String? ?? '';
            if (syncedLyrics != '') {
              // lrc
              final lrcBuffer = StringBuffer();
              final artist = jsonRes['artistName'] ?? details?.artist ?? '';
              final album = jsonRes['albumName'] ?? details?.album ?? '';
              final title = jsonRes['trackName'] ?? details?.title ?? '';
              final durMS = jsonRes['duration'] is num ? ((jsonRes['duration'] as num) * 1000).round() : mainDuration;

              if (artist != '') lrcBuffer.writeln('[ar:$artist]');
              if (album != '') lrcBuffer.writeln('[al:$album]');
              if (title != '') lrcBuffer.writeln('[ti:$title]');
              if (durMS > 0) lrcBuffer.writeln('[length:${formatTime(durMS)}]');
              lrcBuffer.write(syncedLyrics);

              final resultedLRC = lrcBuffer.toString();

              fetched.add(
                LyricsModel(
                  lyrics: resultedLRC,
                  isInCache: false,
                  fromInternet: true,
                  synced: true,
                  file: null,
                  isEmbedded: false,
                ),
              );
            } else if (plain != '') {
              // txt
              fetched.add(
                LyricsModel(
                  lyrics: plain,
                  isInCache: false,
                  fromInternet: true,
                  synced: false,
                  file: null,
                  isEmbedded: false,
                ),
              );
            }
          });
          fetched.removeDuplicates();
          return fetched;
        } catch (_) {}
      }
      return [];
    }

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (PortsProvider.isDisposeMessage(p)) {
        recievePort.close();
        streamSub?.cancel();
        return;
      }

      var lyrics = <LyricsModel>[];
      if (p is List<LRCSearchDetails>) {
        for (final details in p) {
          lyrics = await fetchLRCBasedLyricsFromInternet(details: details);
          if (lyrics.isNotEmpty) break;
        }
      } else if (p is String) {
        lyrics = await fetchLRCBasedLyricsFromInternet(details: null, customQuery: p);
      }
      sendPort.send(lyrics);
    });

    sendPort.send(null); // prepared
  }
}
