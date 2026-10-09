// by claude
// ignore_for_file: avoid_print

import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:history_manager/history_manager.dart';

import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

import 'bench_data.dart';

void main() {
  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_history_benchmark');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  final library = SyntheticLibrary.generate(10000, seed: 43);
  final anchorMS = DateTime(2026, 6, 1).millisecondsSinceEpoch;
  const dayMS = Duration.millisecondsPerDay;

  test('yt takeout history import matching', () async {
    final runner = BenchRunner('history_import');
    final random = Random(11);
    final names = SyntheticLibrary(12);
    final tracks = library.map(_ytTrackOf).toFixedList();
    final watches = <Map<String, Object>>[];
    for (int i = 0; i < 20000; i++) {
      final roll = random.nextDouble();
      final ageMS = (random.nextDouble() * 3 * 365 * dayMS).floor();
      final timeMS = anchorMS - ageMS;
      final timeUtc = DateTime.fromMillisecondsSinceEpoch(timeMS, isUtc: true);
      final time = timeUtc.toIso8601String();
      final header = random.nextDouble() < 0.2 ? 'YouTube Music' : 'YouTube';
      if (roll < 0.4) {
        final track = tracks[random.nextInt(tracks.length)];
        final trackYtId = _youtubeIdOf(track);
        final shouldUseTrackId = trackYtId != null && random.nextDouble() < 0.5;
        final id = shouldUseTrackId ? trackYtId : names.youtubeId();
        final title = _watchTitleOf(track, random);
        final channelRoll = random.nextDouble();
        final channel = channelRoll < 0.5 ? '${track.artist} - Topic' : (channelRoll < 0.8 ? track.artist : names.phrase(1, 3));
        watches.add(_jsonWatch(id, title, channel, time, header));
      } else {
        final id = names.youtubeId();
        final title = names.phrase(2, 6);
        final channel = names.phrase(1, 3);
        watches.add(_jsonWatch(id, title, channel, time, header));
      }
    }
    final file = File('${dir.path}${Platform.pathSeparator}watch-history.json');
    file.writeAsJsonSync(watches);
    final splitConfig = ArtistsSplitConfig(addFeatArtist: true, separators: kBenchArtistSeparators, separatorsBlacklist: const []);

    Future<int> parse({required bool link, required bool titleAndArtist, List<String>? lines}) async {
      final portsParsed = ReceivePort();
      final portsAdded = ReceivePort();
      final portsLoading = ReceivePort();
      final localHistory = SplayTreeMap<int, List<TrackWithDate>>((date1, date2) => date2.compareTo(date1));
      final ytHistory = SplayTreeMap<int, List<YoutubeID>>((date1, date2) => date2.compareTo(date1));
      final res = await JsonToHistoryParser.debugParseYTHistory((
        tracks: tracks,
        files: [file],
        isMatchingTypeLink: link,
        isMatchingTypeTitleAndArtist: titleAndArtist,
        matchYT: true,
        matchYTMusic: true,
        oldestDay: null,
        newestDay: null,
        matchAll: false,
        artistsSplitConfig: splitConfig,
        portProgressParsed: portsParsed.sendPort,
        portProgressAdded: portsAdded.sendPort,
        portLoadingProgress: portsLoading.sendPort,
        localHistory: localHistory,
        ytHistory: ytHistory,
      ));
      portsParsed.close();
      portsAdded.close();
      portsLoading.close();
      final addedLocalHistoryCount = res!.addedLocalHistoryCount;
      if (lines != null) {
        lines.add('local=$addedLocalHistoryCount yt=${res.addedYTHistoryCount} missing=${res.missingEntriesSorted.length}');
        lines.addAll(_historyLines(res.localHistory));
      }
      return addedLocalHistoryCount;
    }

    for (final mode in const [(link: true, titleAndArtist: true), (link: false, titleAndArtist: true), (link: true, titleAndArtist: false)]) {
      final name = 'link=${mode.link} titleAndArtist=${mode.titleAndArtist}';
      final lines = <String>[];
      await parse(link: mode.link, titleAndArtist: mode.titleAndArtist, lines: lines);
      print('INFO|history_import|$name|${lines.first}');
      runner.digest(name, lines);
      await runner.run('takeout ${watches.length} watches vs ${tracks.length} tracks, $name', () => parse(link: mode.link, titleAndArtist: mode.titleAndArtist), warmups: 1, iterations: 5);
    }
    runner.finish();
  }, timeout: Timeout.none);

  test('history load', () async {
    final runner = BenchRunner('history_load');
    final random = Random(21);
    final historyDirPath = '${dir.path}${Platform.pathSeparator}history${Platform.pathSeparator}';
    final libraryTracks = library.map((e) => Track.explicit(e.path)).toFixedList();
    const daysCount = 3 * 365;
    const listensPerDay = 50;
    final today = DateTime.now();
    for (int d = 0; d < daysCount; d++) {
      final dayStart = DateTime(today.year, today.month, today.day - d);
      final dayStartMS = dayStart.millisecondsSinceEpoch;
      final listens = List.generate(listensPerDay, (_) => dayStartMS + random.nextInt(dayMS), growable: false);
      listens.sortByReverse((e) => e);
      final isUnsorted = random.nextDouble() < 0.1;
      if (isUnsorted) listens.shuffle(random);
      final dayKey = dayStartMS.toDaysSince1970();
      final json = <Map<String, dynamic>>[];
      for (final listenMS in listens) {
        final track = libraryTracks[random.nextInt(libraryTracks.length)];
        final twd = TrackWithDate(dateAdded: listenMS, track: track, source: TrackSource.local);
        json.add(twd.toJson());
      }
      File('$historyDirPath$dayKey.json').writeAsJsonSync(json);
    }

    Future<HistoryPrepareInfo<TrackWithDate, Track>> load() => HistoryController.inst.prepareAllHistoryFilesFunction(historyDirPath);

    final info = await load();
    runner.digest('historyMap', _historyLines(info.historyMap));
    final topItemsLines = info.topItems.entriesSortedByValue.map((e) => '${e.key.path}|${e.value.join(',')}').toFixedList();
    runner.digest('topItems order', topItemsLines);
    final topItemsLinesSorted = topItemsLines.toFixedList()..sort();
    runner.digest('topItems content', topItemsLinesSorted);
    await runner.run('read ${info.historyMap.length} day files / ${info.totalItemsCount} listens (isolate + IO)', load, iterations: 10);

    final historyWithDuplicates = <int, List<TrackWithDate>>{};
    int duplicatesCount = 0;
    for (final e in info.historyMap.entries) {
      final dayListens = e.value.toList();
      for (final twd in e.value) {
        if (random.nextDouble() >= 0.05) continue;
        final delayMS = 1000 * (5 + random.nextInt(200));
        final duplicate = TrackWithDate(dateAdded: twd.dateAdded + delayMS, track: twd.track, source: TrackSource.youtube);
        dayListens.add(duplicate);
        duplicatesCount++;
      }
      dayListens.sortByReverse((e) => e.dateAdded);
      historyWithDuplicates[e.key] = dayListens;
    }

    void resetHistoryWithDuplicates() {
      final history = SplayTreeMap<int, List<TrackWithDate>>((date1, date2) => date2.compareTo(date1));
      for (final e in historyWithDuplicates.entries) {
        history[e.key] = e.value.toList();
      }
      HistoryController.inst.historyMap.value = history;
    }

    resetHistoryWithDuplicates();
    final removedCount = HistoryController.inst.removeDuplicatedItems();
    print('INFO|history_load|removeDuplicatedItems|added=$duplicatesCount removed=$removedCount');
    runner.digest('history after removeDuplicatedItems', _historyLines(HistoryController.inst.historyMap.value));
    await runner.run('removeDuplicatedItems all days (+$duplicatesCount duplicates)', HistoryController.inst.removeDuplicatedItems, setUp: resetHistoryWithDuplicates, iterations: 10);

    HistoryController.inst.historyMap.value = info.historyMap;
    for (final mptr in const [MostPlayedTimeRange.month, MostPlayedTimeRange.year, MostPlayedTimeRange.allTime]) {
      ListensSortedMap<Track> mostListens() => HistoryController.inst.getMostListensInTimeRange(mptr: mptr, isStartOfDay: false, mainItemToSubItem: (e) => e.track);
      final mostListensLines = mostListens().entriesSortedByValue.map((e) => '${e.key.path}|${e.value.length}');
      runner.digest('mostListens ${mptr.name}', mostListensLines);
      await runner.run('getMostListensInTimeRange ${mptr.name}', mostListens, iterations: 10);
    }

    int randomPastMS() {
      final ageSeconds = random.nextInt(1000 * dayMS ~/ 1000);
      return anchorMS - ageSeconds * 1000;
    }

    final listensByTrack = <Track, List<int>>{};
    for (final track in libraryTracks) {
      final count = 1 + random.nextInt(30);
      listensByTrack[track] = List.generate(count, (_) => randomPastMS(), growable: false);
    }
    final newListens = <(Track, int)>[];
    int latestMS = anchorMS;
    for (int i = 0; i < 10000; i++) {
      final skew = pow(random.nextDouble(), 2);
      final track = libraryTracks[(libraryTracks.length * skew).floor()];
      final isOlder = random.nextDouble() < 0.1;
      latestMS += random.nextInt(300000);
      final listenMS = isOlder ? randomPastMS() : latestMS;
      newListens.add((track, listenMS));
    }

    final sortedMap = ListensSortedMap<Track>();
    void assignAll() {
      final copy = {for (final e in listensByTrack.entries) e.key: e.value.toList()};
      sortedMap.assignAll(copy);
    }

    await runner.run('ListensSortedMap.assignAll ${listensByTrack.length} keys', () {
      assignAll();
      return sortedMap.length;
    }, iterations: 10);

    int addAll() {
      for (final e in newListens) {
        sortedMap.addElement(e.$1, e.$2);
      }
      return sortedMap.length;
    }

    assignAll();
    addAll();
    final sortedMapLines = sortedMap.entriesSortedByValue.map((e) => '${e.key.path}|${e.value.join(',')}');
    runner.digest('ListensSortedMap after addElement', sortedMapLines);
    await runner.run('ListensSortedMap.addElement x${newListens.length}', addAll, setUp: assignAll, iterations: 10);
    runner.finish();
  }, timeout: Timeout.none);

  test('youtube history load', () async {
    final runner = BenchRunner('yt_history_load');
    final random = Random(23);
    final names = SyntheticLibrary(24);
    final ids = List.generate(8000, (_) => names.youtubeId(), growable: false);
    final ytHistoryDirPath = '${dir.path}${Platform.pathSeparator}yt_history${Platform.pathSeparator}';
    final today = DateTime.now();
    for (int d = 0; d < 3 * 365; d++) {
      final dayStart = DateTime(today.year, today.month, today.day - d);
      final dayStartMS = dayStart.millisecondsSinceEpoch;
      final watches = List.generate(30, (_) => dayStartMS + random.nextInt(dayMS), growable: false);
      watches.sortByReverse((e) => e);
      final isUnsorted = random.nextDouble() < 0.1;
      if (isUnsorted) watches.shuffle(random);
      final dayKey = dayStartMS.toDaysSince1970();
      final json = <Map<String, dynamic>>[];
      for (final watchMS in watches) {
        final watch = YTWatch(dateMSNull: watchMS, isYTMusic: random.nextDouble() < 0.2);
        final id = ids[random.nextInt(ids.length)];
        final video = YoutubeID(id: id, watchNull: watch, playlistID: null);
        json.add(video.toJson());
      }
      File('$ytHistoryDirPath$dayKey.json').writeAsJsonSync(json);
    }

    Future<HistoryPrepareInfo<YoutubeID, String>> load() => YoutubeHistoryController.inst.prepareAllHistoryFilesFunction(ytHistoryDirPath);

    final info = await load();
    final historyLines = info.historyMap.entries.map((e) => '${e.key}|${e.value.map((e) => '${e.dateAddedMS}:${e.id}').join(',')}');
    runner.digest('historyMap', historyLines);
    final topItemsLines = info.topItems.entriesSortedByValue.map((e) => '${e.key}|${e.value.join(',')}').toFixedList()..sort();
    runner.digest('topItems content', topItemsLines);
    await runner.run('read ${info.historyMap.length} yt day files / ${info.totalItemsCount} watches (isolate + IO)', load, iterations: 10);
    runner.finish();
  }, timeout: Timeout.none);
}

final _ytIdInTextRegex = RegExp(r'(?:v=|youtu\.be/|\[)([\w-]{11})');

Iterable<String> _historyLines(Map<int, List<TrackWithDate>> history) {
  return history.entries.map((e) => '${e.key}|${e.value.map((e) => '${e.dateAdded}:${e.track.path}').join(',')}');
}

_YTTrack _ytTrackOf(SyntheticTrack e) {
  final title = e.title ?? e.path.getFilenameWOExt;
  final artist = e.artist ?? '';
  final album = e.album ?? '';
  final comment = e.comment ?? '';
  return (title: title, artist: artist, album: album, path: e.path, comment: comment, isVideo: false);
}

String? _youtubeIdOf(_YTTrack track) {
  final inComment = _ytIdInTextRegex.firstMatch(track.comment)?.group(1);
  if (inComment != null) return inComment;
  return _ytIdInTextRegex.firstMatch(track.path)?.group(1);
}

String _watchTitleOf(_YTTrack track, Random random) {
  final roll = random.nextDouble();
  if (roll < 0.35) return '${track.artist} - ${track.title}';
  if (roll < 0.6) return '${track.title} (Official Video)';
  if (roll < 0.8) return '${track.artist} - ${track.title} [Lyrics]';
  return '${track.title} | ${track.artist}';
}

Map<String, Object> _jsonWatch(String id, String title, String channel, String time, String header) {
  return {
    'header': header,
    'title': 'Watched $title',
    'titleUrl': 'https://www.youtube.com/watch?v=$id',
    'subtitles': [
      {'name': channel, 'url': 'https://www.youtube.com/channel/UC$id'},
    ],
    'time': time,
    'products': [header],
    'activityControls': ['YouTube watch history'],
  };
}

typedef _YTTrack = ({String title, String artist, String album, String path, String comment, bool isVideo});
