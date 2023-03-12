/// copyright: credit goes for (@netlob)[https://github.com/netlob/dart-lyrics]
/// this file is originally from @netlob, edited to fit Namida.

// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class Lyrics {
  static final Lyrics inst = Lyrics();

  RxString currentLyrics = ''.obs;
  RxBool lyricsAvailable = true.obs;

  Future<void> updateLyrics(Track track) async {
    currentLyrics.value = '';
    if (SettingsController.inst.enableLyrics.value) {
      final lyricsFile = File("$kLyricsDirPath${track.filename}.txt");
      final lyricsFileStat = await lyricsFile.stat();

      /// get from storage
      if (await lyricsFile.exists() && lyricsFileStat.size > 2) {
        currentLyrics.value = await lyricsFile.readAsString();
      }

      /// download lyrics
      else {
        final String lyrics = await Lyrics.inst.getLyrics(artist: track.artistsList.first, track: track.title);
        RegExp exp = RegExp(r'<[^>]*>');
        if (lyrics != '') {
          String formattedText = lyrics.replaceAll(exp, '');
          currentLyrics.value = formattedText;
          await lyricsFile.writeAsString(formattedText);
        } else {
          lyricsAvailable.value = false;
          return;
        }
      }
      lyricsAvailable.value = true;
    }
  }

  final String _url = "https://www.google.com/search?client=safari&rls=en&ie=UTF-8&oe=UTF-8&q=";
  String _delimiter1 = '</div></div></div></div><div class="hwc"><div class="BNeawe tAd8D AP7Wnd"><div><div class="BNeawe tAd8D AP7Wnd">';
  String _delimiter2 = '</div></div></div></div></div><div><span class="hwc"><div class="BNeawe uEec3 AP7Wnd">';

  Lyrics({delimiter1, delimiter2}) {
    setDelimiters(delimiter1: delimiter1, delimiter2: delimiter2);
  }

  void setDelimiters({String? delimiter1, String? delimiter2}) {
    _delimiter1 = delimiter1 ?? _delimiter1;
    _delimiter2 = delimiter2 ?? _delimiter2;
  }

  Future<String> getLyrics({String? track, String? artist}) async {
    if (track == null || artist == null) {
      throw Exception("track and artist must not be null");
    }

    String lyrics;

    // try multiple queries
    try {
      lyrics = (await http.get(Uri.parse(Uri.encodeFull('$_url$track by $artist lyrics'))).timeout(const Duration(seconds: 10))).body;
      lyrics = lyrics.split(_delimiter1).last;
      lyrics = lyrics.split(_delimiter2).first;
      if (lyrics.contains('<meta charset="UTF-8">')) throw Error();
    } catch (_) {
      try {
        lyrics = (await http.get(Uri.parse(Uri.encodeFull('$_url$track by $artist song lyrics'))).timeout(const Duration(seconds: 10)).then((value) => value.body));
        lyrics = lyrics.split(_delimiter1).last;
        lyrics = lyrics.split(_delimiter2).first;
        if (lyrics.contains('<meta charset="UTF-8">')) throw Error();
      } catch (_) {
        try {
          lyrics = (await http.get(Uri.parse(Uri.encodeFull('$_url${track.split("-").first} by $artist lyrics'))).timeout(const Duration(seconds: 10)).then((value) => value.body));
          lyrics = lyrics.split(_delimiter1).last;
          lyrics = lyrics.split(_delimiter2).first;
          if (lyrics.contains('<meta charset="UTF-8">')) throw Error();
        } catch (_) {
          return '';
        }
      }
    }

    final List<String> split = lyrics.split('\n');
    String result = '';
    for (var i = 0; i < split.length; i++) {
      result = '$result${split[i]}\n';
    }
    return result.trim();
  }
}
