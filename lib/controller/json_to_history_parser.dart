import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class JsonToHistoryParser {
  static final JsonToHistoryParser inst = JsonToHistoryParser();

  final RxInt parsedHistoryJson = 0.obs;
  final RxInt totalJsonToParse = 0.obs;
  final RxInt addedHistoryJsonToPlaylist = 0.obs;
  final RxBool isParsing = false.obs;
  final RxBool isLoadingFile = false.obs;
  final Rx<TrackSource> currentParsingSource = TrackSource.local.obs;

  void showParsingProgressDialog() {
    Get.dialog(
      Obx(
        () => CustomBlurryDialog(
          normalTitleStyle: true,
          title: isParsing.value ? Language.inst.EXTRACTING_INFO : Language.inst.DONE,
          actions: [
            TextButton(
              child: Text(Language.inst.CONFIRM),
              onPressed: () => Get.close(1),
            )
          ],
          bodyText:
              "${Language.inst.LOADING_FILE}... ${isLoadingFile.value ? '' : Language.inst.DONE}\n\n${parsedHistoryJson.value.formatDecimal(true)} / ${totalJsonToParse.value.formatDecimal(true)} ${Language.inst.PARSED} \n\n${addedHistoryJsonToPlaylist.value.formatDecimal(true)} ${Language.inst.ADDED}",
        ),
      ),
    );
  }

  Future<dynamic> readJSONFile(String path) async {
    final contents = await File(path).readAsString();
    if (contents.isNotEmpty) {
      final jsonResponse = jsonDecode(contents);
      return jsonResponse;
    }
    return null;
  }

  Future<void> parseYTHistoryJson(File file) async {
    _resetValues();
    isParsing.value = true;
    isLoadingFile.value = true;
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      String contents = await file.readAsString();
      if (contents.isNotEmpty) {
        final jsonResponse = jsonDecode(contents);
        final list = <YoutubeVideoHistory>[];

        for (final p in jsonResponse) {
          final link = utf8.decode((p['titleUrl']).toString().codeUnits);
          final id = link.length >= 11 ? link.substring(link.length - 11) : link;
          final z = List<Map<String, dynamic>>.from((p['subtitles'] ?? []));

          final obj = list.firstWhereOrNull((element) => element.id == id);
          if (obj == null) {
            list.add(
              YoutubeVideoHistory(
                id,
                (p['title'] as String).replaceFirst('Watched ', ''),
                z.isNotEmpty ? z.first['name'] : '',
                z.isNotEmpty ? utf8.decode((z.first['url']).toString().codeUnits) : '',
                [YTWatch(DateTime.parse(p['time'] ?? 0).millisecondsSinceEpoch, p['header'] == "YouTube Music")],
              ),
            );
          } else {
            obj.watches.add(YTWatch(DateTime.parse(p['time'] ?? 0).millisecondsSinceEpoch, p['header'] == "YouTube Music"));
          }
          parsedHistoryJson.value++;
        }
        await File(kYoutubeStatsFilePath).writeAsString(jsonEncode(list));
      }
    } catch (e) {
      printError(info: e.toString());
      Get.snackbar(Language.inst.ERROR, Language.inst.CORRUPTED_FILE);
    }

    isParsing.value = false;
    isLoadingFile.value = false;
  }

  void _resetValues() {
    totalJsonToParse.value = 0;
    parsedHistoryJson.value = 0;
    addedHistoryJsonToPlaylist.value = 0;
  }

  Future<void> addFileSourceToNamidaHistory(File file, TrackSource source, {bool isMatchingTypeLink = true, bool matchYT = true, bool matchYTMusic = true}) async {
    _resetValues();
    isParsing.value = true;

    await PlaylistController.inst.backupHistoryPlaylist();

    /// Removing previous source tracks.
    final isytsource = source == TrackSource.youtube || source == TrackSource.youtubeMusic;
    if (isytsource) {
      PlaylistController.inst.removeSourceTracksFromHistory(TrackSource.youtube);
      PlaylistController.inst.removeSourceTracksFromHistory(TrackSource.youtubeMusic);
    } else {
      PlaylistController.inst.removeSourceTracksFromHistory(source);
    }
    await Future.delayed(const Duration(milliseconds: 300));

    if (isytsource) {
      currentParsingSource.value = TrackSource.youtube;
      await _addYoutubeSource(file, isMatchingTypeLink, matchYT, matchYTMusic);
    }
    if (source == TrackSource.lastfm) {
      currentParsingSource.value = TrackSource.lastfm;
      await _addLastFmSource(file);
    }
    isParsing.value = false;
    PlaylistController.inst.sortHistoryAndSave();
  }

  Future<void> _addYoutubeSource(File file, bool isMatchingTypeLink, bool matchYT, bool matchYTMusic) async {
    final jsonResponse = jsonDecode(await file.readAsString()) as List;
    totalJsonToParse.value = jsonResponse.length;

    /// Adding tracks that their link matches.
    for (final p in jsonResponse) {
      parsedHistoryJson.value++;
      // forgive me
      await Future.delayed(Duration.zero);

      final vh = YoutubeVideoHistory.fromJson(p);

      final tr = Indexer.inst.tracksInfoList.firstWhereOrNull((element) {
        return isMatchingTypeLink
            ? element.youtubeID == vh.id

            /// matching has to meet 2 conditons:
            /// 1. [json title] contains [track.title]
            /// 2. - [json title] contains [track.artistsList.first]
            ///     or
            ///    - [json channel] contains [track.album]
            ///    (useful for nightcore channels, album has to be the channel name)
            : vh.title.cleanUpForComparison.contains(element.title.cleanUpForComparison) &&
                (vh.title.cleanUpForComparison.contains(element.artistsList.first.cleanUpForComparison) ||
                    vh.channel.cleanUpForComparison.contains(element.album.cleanUpForComparison));
      });
      if (tr != null) {
        for (final d in vh.watches) {
          /// sussy checks
          // if the type is youtube music, but the user dont want ytm.
          if (d.isYTMusic && !matchYTMusic) continue;

          // if the type is youtube, but the user dont want yt.
          if (!d.isYTMusic && !matchYT) continue;

          PlaylistController.inst.addTrackToHistory([TrackWithDate(d.date, tr, d.isYTMusic ? TrackSource.youtubeMusic : TrackSource.youtube)], sortAndSave: false);
          addedHistoryJsonToPlaylist.value++;
        }
      }
    }
  }

  Future<void> _addLastFmSource(File file) async {
    totalJsonToParse.value = file.readAsLinesSync().length;
    final stream = file.openRead();
    final lines = stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      parsedHistoryJson.value++;

      // pls forgive me
      await Future.delayed(Duration.zero);

      /// artist, album, title, (dd MMM yyyy HH:mm);
      final pieces = line.split(',');

      /// matching has to meet 2 conditons:
      /// [csv artist] contains [track.artistsList.first]
      /// [csv title] contains [track.title]
      final tr = Indexer.inst.tracksInfoList.firstWhereOrNull(
        (tr) => pieces.first.cleanUpForComparison.contains(tr.artistsList.first.cleanUpForComparison) && pieces[2].cleanUpForComparison.contains(tr.title.cleanUpForComparison),
      );
      if (tr != null) {
        PlaylistController.inst
            .addTrackToHistory([TrackWithDate(DateFormat('dd MMM yyyy HH:mm').parse(pieces.last).millisecondsSinceEpoch, tr, TrackSource.lastfm)], sortAndSave: false);
        addedHistoryJsonToPlaylist.value++;
      }
    }
  }
}
