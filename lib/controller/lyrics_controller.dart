/// copyright: google search request is originally from [@netlob](https://github.com/netlob/dart-lyrics), edited to fit Namida.

// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:lrc/lrc.dart';
import 'package:path/path.dart' as p;

import 'package:namida/class/lyrics.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/wakelock_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/packages/lyrics_lrc_parsed_view.dart';

class Lyrics {
  static Lyrics get inst => _instance;
  static final Lyrics _instance = Lyrics._internal();
  Lyrics._internal();

  GlobalKey<LyricsLRCParsedViewState>? lrcViewKey;
  final lrcViewKeyFullscreen = GlobalKey<LyricsLRCParsedViewState>();

  final currentLyricsText = ''.obs;
  final currentLyricsLRC = Rxn<Lrc>();
  final lyricsCanBeAvailable = true.obs;

  Track? _currentTrack;

  void _updateWidgets(Lrc? lrc) {
    WakelockController.inst.updateLRCStatus(lrc != null);
    lrcViewKey?.currentState?.fillLists(lrc);
    lrcViewKeyFullscreen.currentState?.fillLists(lrc);
  }

  Future<void> updateLyrics(Track track, {bool preferEmbedded = false}) async {
    _currentTrack = track;
    currentLyricsText.value = '';
    currentLyricsLRC.value = null;
    _updateWidgets(null);
    lrcViewKey = GlobalKey<LyricsLRCParsedViewState>();

    lyricsCanBeAvailable.value = true;
    if (!settings.enableLyrics.value) return;

    final embedded = track.lyrics;

    if (settings.prioritizeEmbeddedLyrics.value && embedded != '') {
      final lrc = embedded.parseLRC();
      if (lrc != null) {
        currentLyricsLRC.value = lrc;
        _updateWidgets(lrc);
      } else {
        currentLyricsText.value = embedded;
      }
      return;
    }

    /// 1. device lrc
    /// 2. cached lrc
    /// 3. track embedded lrc
    /// 4. database.
    final lrcLyrics = await _fetchLRCBasedLyrics(track, embedded);

    if (lrcLyrics != null) {
      if (_currentTrack == track) {
        currentLyricsLRC.value = lrcLyrics;
        _updateWidgets(lrcLyrics);
      }
    } else {
      /// 1. cached txt lyrics
      /// 2. track embedded txt
      /// 3. google search
      final textLyrics = await _fetchTextBasedLyrics(track, embedded);
      if (textLyrics != '') {
        if (_currentTrack == track) {
          currentLyricsText.value = textLyrics;
        }
      } else {
        lyricsCanBeAvailable.value = false;
      }
    }
  }

  bool hasLyrics(Track tr) {
    return tr.lyrics != '' || lyricsFileCache(tr).existsSync() || lyricsFilesDevice(tr).any((element) => element.existsSync()) || lyricsFileText(tr).existsSync();
  }

  File lyricsFileText(Track tr) => File(p.join(AppDirs.LYRICS, "${tr.filename}.txt"));
  File lyricsFileCache(Track tr) => File(p.join(AppDirs.LYRICS, "${tr.filename}.lrc"));
  List<File> lyricsFilesDevice(Track tr) => [
        File(p.join(tr.path.getDirectoryPath, "${tr.filename}.lrc")),
        File(p.join(tr.path.getDirectoryPath, "${tr.filenameWOExt}.lrc")),
        File(p.join(tr.path.getDirectoryPath, "${tr.filename}.LRC")),
        File(p.join(tr.path.getDirectoryPath, "${tr.filenameWOExt}.LRC")),
      ];

  Future<void> saveLyricsToCache(Track track, String lyricsText, bool isSynced) async {
    final fc = isSynced ? lyricsFileCache(track) : lyricsFileText(track);
    await fc.create();
    await fc.writeAsString(lyricsText);
  }

  Future<Lrc?> _fetchLRCBasedLyrics(Track track, String trackLyrics) async {
    final fc = lyricsFileCache(track);
    final lyricsFilesLocal = lyricsFilesDevice(track);

    Future<Lrc?> parseLRCFile(File file) async {
      final content = await file.readAsString();
      return content.parseLRC();
    }

    Lrc? lrc;

    /// 1. device lrc
    /// 2. cached lrc
    /// 3. track embedded
    for (final lf in lyricsFilesLocal) {
      if (await lf.existsAndValid()) {
        lrc = await parseLRCFile(lf);
        break;
      }
    }
    if (lrc == null) {
      if (await fc.existsAndValid()) {
        lrc = await parseLRCFile(fc);
      } else if (trackLyrics != '') {
        lrc = trackLyrics.parseLRC();
      }
    }

    /// 4. if still null, fetch from database.
    if (lrc == null) {
      final tries = <(String, String, String)>[]; // title, artist, album
      tries.addAll([
        (track.title, track.originalArtist, ''),
        (track.title, track.originalArtist, track.album),
        (track.title, track.artistsList.first, ''),
        (track.title, track.artistsList.first, track.album),
      ]);

      final lyrics = <LyricsModel>[];
      for (final t in tries) {
        lyrics.addAll(
          await fetchLRCBasedLyricsFromInternet(
            durationInSeconds: track.duration,
            title: t.$1,
            artist: t.$2,
            album: t.$3,
          ),
        );
        if (lyrics.isNotEmpty) break;
      }

      final text = lyrics.firstOrNull?.lyrics;
      if (text != null) await fc.writeAsString(text);
      return text?.parseLRC();
    }
    return lrc;
  }

  Future<List<LyricsModel>> fetchLRCBasedLyricsFromInternet({
    String title = '',
    String artist = '',
    String album = '',
    required int durationInSeconds,
    String customQuery = '',
  }) async {
    String formatTime(int seconds) {
      final duration = Duration(seconds: seconds);
      final min = duration.inMinutes.remainder(60);
      final sec = duration.inSeconds.remainder(60);
      final ms = duration.inMilliseconds.remainder(1000);
      String pad(int n) => n.toString().padLeft(2, '0');
      final formattedTime = '${pad(min)}:${pad(sec)}.${pad(ms)}';
      return formattedTime;
    }

    final params = [
      if (title != '') 'track_name=$title',
      if (artist != '') 'artist_name=${artist.split('(').first.split('[').first}',
      if (album != '') 'album_name=$album',
    ].join('&');
    if (params.isNotEmpty || customQuery != '') {
      final tail = customQuery == '' ? params : 'q=$customQuery';
      final urlPre = "https://lrclib.net/api/search?$tail";
      final url = Uri.parse(Uri.encodeFull(urlPre));
      http.Response? req;
      try {
        req = await http.get(url);
      } catch (_) {
        return [];
      }
      final fetched = <LyricsModel>[];
      final jsonLists = (jsonDecode(req.body) as List<dynamic>?) ?? [];
      for (final jsonRes in jsonLists) {
        final syncedLyrics = jsonRes?["syncedLyrics"] as String? ?? '';
        final plain = jsonRes?["plainLyrics"] as String? ?? '';
        if (syncedLyrics != '') {
          // lrc
          final lines = <String>[];
          if (artist != '') lines.add('[ar:$artist]');
          if (album != '') lines.add('[al:$album]');
          if (title != '') lines.add('[ti:$title]');
          if (durationInSeconds > 0) lines.add('[length:${formatTime(durationInSeconds)}]');
          for (final l in syncedLyrics.split('\n')) {
            lines.add(l);
          }
          final resultedLRC = lines.join('\n');
          fetched.add(LyricsModel(
            lyrics: resultedLRC,
            isInCache: false,
            fromInternet: true,
            synced: true,
            file: null,
            isEmbedded: false,
          ));
        } else if (plain != '') {
          // txt
          fetched.add(LyricsModel(
            lyrics: plain,
            isInCache: false,
            fromInternet: true,
            synced: false,
            file: null,
            isEmbedded: false,
          ));
        }
      }
      fetched.removeDuplicates();
      return fetched;
    }
    return [];
  }

  Future<String> _fetchTextBasedLyrics(Track track, String trackLyrics) async {
    final lyricsFile = lyricsFileText(track);

    /// get from storage
    if (await lyricsFile.existsAndValid()) {
      return await lyricsFile.readAsString();
    } else if (trackLyrics != '') {
      return trackLyrics;
    }

    /// download lyrics
    else {
      final lyrics = await _fetchLyricsGoogle(artist: track.artistsList.first, title: track.title);
      final regex = RegExp(r'<[^>]*>');
      if (lyrics != '') {
        final formattedText = lyrics.replaceAll(regex, '');
        await lyricsFile.writeAsString(formattedText);
        return formattedText;
      }
    }
    return '';
  }

  Future<String> _fetchLyricsGoogle({String title = '', String artist = ''}) async {
    if (title == '' && artist == '') return '';

    const url = "https://www.google.com/search?client=safari&rls=en&ie=UTF-8&oe=UTF-8&q=";
    const delimiter1 = '</div></div></div></div><div class="hwc"><div class="BNeawe tAd8D AP7Wnd"><div><div class="BNeawe tAd8D AP7Wnd">';
    const delimiter2 = '</div></div></div></div></div><div><span class="hwc"><div class="BNeawe uEec3 AP7Wnd">';

    Future<String> requestQuery(String searchText) async {
      http.Response? res;
      try {
        res = await http.get(Uri.parse(Uri.encodeFull(searchText))).timeout(const Duration(seconds: 10));
      } catch (_) {}
      if (res == null) return '';
      final lyricsRes = res.body.split(delimiter1).last.split(delimiter2).first;
      if (lyricsRes.contains('<meta charset="UTF-8">')) return '';
      if (lyricsRes.contains('please enable javascript on your web browser')) return '';
      if (lyricsRes.contains('Error 500 (Server Error)')) return '';
      return lyricsRes;
    }

    String lyrics = '';

    final possibleQueries = [
      '$url$title by $artist lyrics',
      '$url${title.split("-").first} by $artist lyrics',
      '$url$title by $artist song lyrics',
    ];
    for (final q in possibleQueries) {
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
