// by claude
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/search_matcher.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/youtube/class/youtube_id.dart';

void main() {
  late Directory dir;
  final ports = <ReceivePort>[];
  final splitConfig = ArtistsSplitConfig(
    addFeatArtist: false,
    separators: const ['&', ',', ';', '//', ' ft. ', ' x '],
    separatorsBlacklist: const [],
  );
  final splittersConfigs = SplitArtistGenreConfigsWrapper(
    dbPath: '',
    artistsConfig: splitConfig,
    genresConfig: GenresSplitConfig(separators: const ['&', ',', ';', '//', ' x '], separatorsBlacklist: const []),
    albumConfig: SimpleSplitConfig(),
    generalConfig: GeneralSplitConfig(),
  );

  setUpAll(() => dir = Directory.systemTemp.createTempSync('namida_history_import_test'));
  tearDownAll(() => dir.deleteSync(recursive: true));
  tearDown(() {
    for (final port in ports) {
      port.close();
    }
    ports.clear();
  });

  SendPort newPort() {
    final port = ReceivePort();
    ports.add(port);
    return port.sendPort;
  }

  int filesCount = 0;
  File writeFile(String extension, String content) {
    final file = File('${dir.path}${Platform.pathSeparator}${filesCount++}.$extension');
    file.writeAsStringSync(content);
    return file;
  }

  String trackPath(String filename) => '${dir.path}${Platform.pathSeparator}$filename';

  _YTTrack ytTrack(String title, String artist, {String album = '', String comment = '', String? filename}) {
    final path = trackPath(filename ?? '$artist - $title.m4a');
    return (title: title, artist: artist, album: album, path: path, comment: comment, isVideo: false);
  }

  Future<_YTTrack> indexedUntaggedTrack(String filename) async {
    final noTags = FTags.edit(path: '', artwork: FArtwork());
    final untaggedInfo = FAudioModel(tags: noTags, hasError: true);
    final trExt = await Indexer.convertTagToTrack(
      trackPath: trackPath(filename),
      stats: const FileStatsAdv(creationDateMS: 0, modifiedMS: 0, size: 0),
      trackInfo: untaggedInfo,
      tryExtractingFromFilename: true,
      onMinDurTrigger: () => null,
      onMinSizeTrigger: () => null,
      onError: (err) => throw StateError(err),
      splittersConfigs: splittersConfigs,
    );
    return (title: trExt!.title, artist: trExt.originalArtist, album: trExt.originalAlbum, path: trExt.path, comment: trExt.comment, isVideo: trExt.isVideo);
  }

  parseYT(
    List<File> files,
    List<_YTTrack> tracks, {
    bool isMatchingTypeLink = false,
    bool isMatchingTypeTitleAndArtist = true,
    bool matchAll = false,
    SplayTreeMap<int, List<TrackWithDate>>? localHistory,
    SplayTreeMap<int, List<YoutubeID>>? ytHistory,
  }) {
    return JsonToHistoryParser.debugParseYTHistory((
      tracks: tracks,
      files: files,
      isMatchingTypeLink: isMatchingTypeLink,
      isMatchingTypeTitleAndArtist: isMatchingTypeTitleAndArtist,
      matchYT: true,
      matchYTMusic: true,
      oldestDay: null,
      newestDay: null,
      matchAll: matchAll,
      artistsSplitConfig: splitConfig,
      portProgressParsed: newPort(),
      portProgressAdded: newPort(),
      portLoadingProgress: newPort(),
      localHistory: localHistory ?? SplayTreeMap(),
      ytHistory: ytHistory ?? SplayTreeMap(),
    ));
  }

  Map<String, Object> jsonWatch(String id, String title, String channel, String time, {String header = 'YouTube', bool isAd = false}) {
    return {
      'header': header,
      'title': 'Watched $title',
      'titleUrl': 'https://www.youtube.com/watch?v=$id',
      'subtitles': [
        {'name': channel, 'url': 'https://www.youtube.com/channel/UC$id'},
      ],
      if (isAd)
        'details': [
          {'name': 'From Google Ads'},
        ],
      'time': time,
      'products': [header],
      'activityControls': ['YouTube watch history'],
    };
  }

  Map<String, Object> removedJsonWatch(String time, {bool isAd = false}) {
    return {
      'header': 'YouTube',
      'title': 'Watched a video that has been removed',
      if (isAd)
        'details': [
          {'name': 'From Google Ads'},
        ],
      'time': time,
      'products': ['YouTube'],
      'activityControls': ['YouTube watch history'],
    };
  }

  File takeoutJson(List<Map<String, Object>> entries) => writeFile('json', jsonEncode(entries));

  String htmlEntry(String body, {String header = 'YouTube', bool isAd = false}) {
    final adDetails = isAd ? '<b>Details:</b><br>&emsp;From Google Ads<br>' : '';
    return '<div class="outer-cell mdl-cell mdl-cell--12-col mdl-shadow--2dp"><div class="mdl-grid">'
        '<div class="header-cell mdl-cell mdl-cell--12-col"><p class="mdl-typography--title">$header<br></p></div>'
        '<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1">$body</div>'
        '<div class="content-cell mdl-cell mdl-cell--6-col mdl-typography--body-1 mdl-typography--text-right"></div>'
        '<div class="content-cell mdl-cell mdl-cell--12-col mdl-typography--caption"><b>Products:</b><br>&emsp;$header<br>$adDetails'
        '<b>Why is this here?</b><br>&emsp;This activity was saved to your Google Account because the following settings were on:&nbsp;YouTube watch history.'
        '&nbsp;You can control these settings &nbsp;<a href="https://myaccount.google.com/activitycontrols">here</a>.</div>'
        '</div></div>';
  }

  String watchedBody(String id, String title, String channel, String date) {
    return 'Watched&nbsp;<a href="https://www.youtube.com/watch?v=$id">$title</a><br><a href="https://www.youtube.com/channel/UC$id">$channel</a><br>$date';
  }

  File takeoutHtml(List<String> entries) {
    return writeFile(
      'html',
      '<html><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"><title>History</title></head>'
          '<body><div class="mdl-grid">${entries.join()}</div></body></html>',
    );
  }

  int utcMS(int year, int month, int day, int hour, int minute, [int second = 0]) => DateTime.utc(year, month, day, hour, minute, second).millisecondsSinceEpoch;

  group('takeout html', () {
    test('an entry gives the id, the unescaped title, the channel and the instant', () async {
      final file = takeoutHtml([
        htmlEntry(watchedBody('dQw4w9WgXcQ', 'Rick &amp; Roll &#39;87', 'Rick Astley', 'Feb 4, 2022, 4:20:56 PM EET')),
      ]);
      final res = await parseYT([file], [], isMatchingTypeTitleAndArtist: false);

      final video = res!.affectedIds!['dQw4w9WgXcQ']!;
      expect(video.title, "Rick & Roll '87");
      expect(video.channel, 'Rick Astley');
      expect(video.channelUrl, 'https://www.youtube.com/channel/UCdQw4w9WgXcQ');
      expect(video.watches, [YTWatch(dateMSNull: utcMS(2022, 2, 4, 14, 20, 56), isYTMusic: false)]);
      expect(res.addedYTHistoryCount, 1);
    });

    test('the narrow no-break space before PM is read as a character or as an entity', () async {
      final file = takeoutHtml([
        htmlEntry(watchedBody('aaaaaaaaaaa', 'A', 'C', 'Feb 4, 2022, 4:20:56\u202fPM EET')),
        htmlEntry(watchedBody('bbbbbbbbbbb', 'B', 'C', 'Feb 4, 2022, 4:20:56&#8239;PM EET')),
      ]);
      final res = await parseYT([file], [], isMatchingTypeTitleAndArtist: false);

      final expectedMS = utcMS(2022, 2, 4, 14, 20, 56);
      expect(res!.affectedIds!['aaaaaaaaaaa']!.watches.single.dateMS, expectedMS);
      expect(res.affectedIds!['bbbbbbbbbbb']!.watches.single.dateMS, expectedMS);
    });

    test('12 AM is midnight and 12 PM is noon', () async {
      final file = takeoutHtml([
        htmlEntry(watchedBody('aaaaaaaaaaa', 'A', 'C', 'Feb 4, 2022, 12:05:00 AM UTC')),
        htmlEntry(watchedBody('bbbbbbbbbbb', 'B', 'C', 'Feb 4, 2022, 12:30:00 PM UTC')),
      ]);
      final res = await parseYT([file], [], isMatchingTypeTitleAndArtist: false);

      expect(res!.affectedIds!['aaaaaaaaaaa']!.watches.single.dateMS, utcMS(2022, 2, 4, 0, 5));
      expect(res.affectedIds!['bbbbbbbbbbb']!.watches.single.dateMS, utcMS(2022, 2, 4, 12, 30));
    });

    test('day-first 24h dates apply their GMT offset', () async {
      final file = takeoutHtml([
        htmlEntry(watchedBody('aaaaaaaaaaa', 'A', 'C', '4 Feb 2022, 16:20:56 GMT+05:30')),
      ]);
      final res = await parseYT([file], [], isMatchingTypeTitleAndArtist: false);

      expect(res!.affectedIds!['aaaaaaaaaaa']!.watches.single.dateMS, utcMS(2022, 2, 4, 10, 50, 56));
    });

    test('the YouTube Music header marks the watch as youtube music', () async {
      final file = takeoutHtml([
        htmlEntry(watchedBody('aaaaaaaaaaa', 'A', 'C', 'Feb 4, 2022, 4:20:56 PM EET'), header: 'YouTube Music'),
      ]);
      final res = await parseYT([file], [], isMatchingTypeTitleAndArtist: false);

      final ytid = res!.ytHistory.values.single.single;
      expect(ytid.watch.isYTMusic, true);
      expect(ytid.sourceNull, TrackSource.youtubeMusic);
    });

    test('ads are skipped, the watches around them are kept', () async {
      final file = takeoutHtml([
        htmlEntry(watchedBody('aaaaaaaaaaa', 'A', 'C', 'Feb 4, 2022, 4:20:56 PM EET')),
        htmlEntry(watchedBody('bbbbbbbbbbb', 'Ad', 'Brand', 'Feb 4, 2022, 4:21:56 PM EET'), isAd: true),
        htmlEntry(watchedBody('ccccccccccc', 'B', 'C', 'Feb 4, 2022, 4:25:56 PM EET')),
      ]);
      final res = await parseYT([file], [], isMatchingTypeTitleAndArtist: false);

      expect(res!.affectedIds!.keys, unorderedEquals(['aaaaaaaaaaa', 'ccccccccccc']));
      expect(res.hasUnreadableHtml, false);
    });

    test('a body that goes on with line breaks or tags after the date still gives the watch', () async {
      final file = takeoutHtml([
        htmlEntry('${watchedBody('aaaaaaaaaaa', 'A', 'C', 'Feb 4, 2022, 4:20:56 PM EET')}<br>'),
        htmlEntry('${watchedBody('bbbbbbbbbbb', 'B', 'C', 'Feb 4, 2022, 4:20:56 PM EET')}<br>\n</span><br>'),
        htmlEntry(watchedBody('ccccccccccc', 'C', 'C', '<span>Feb 4, 2022, 4:20:56 PM EET</span>\n')),
      ]);
      final res = await parseYT([file], [], isMatchingTypeTitleAndArtist: false);

      final expectedMS = utcMS(2022, 2, 4, 14, 20, 56);
      final first = res!.affectedIds!['aaaaaaaaaaa']!;
      expect(first.channel, 'C');
      expect(first.watches.single.dateMS, expectedMS);
      expect(res.affectedIds!['bbbbbbbbbbb']!.watches.single.dateMS, expectedMS);
      expect(res.affectedIds!['ccccccccccc']!.watches.single.dateMS, expectedMS);
    });

    test('removed videos without a channel line are still imported', () async {
      const url = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';
      final file = takeoutHtml([
        htmlEntry('Watched&nbsp;<a href="$url">$url</a><br>Feb 4, 2022, 4:20:56 PM EET'),
      ]);
      final res = await parseYT([file], [], isMatchingTypeTitleAndArtist: false);

      final video = res!.affectedIds!['aaaaaaaaaaa']!;
      expect(video.title, url);
      expect(video.channel, '');
      expect(video.watches.single.dateMS, utcMS(2022, 2, 4, 14, 20, 56));
    });

    test('an entry without a link is a removed video, kept under the null id without the Watched prefix, ads still skipped', () async {
      final file = takeoutHtml([
        htmlEntry('Watched a video that has been removed<br>Feb 4, 2022, 4:20:56 PM EET'),
        htmlEntry('Watched&nbsp;a video that has been removed<br>Feb 5, 2022, 4:20:56 PM EET'),
        htmlEntry('Watched a video that has been removed<br>Feb 6, 2022, 4:20:56 PM EET', isAd: true),
      ]);
      final res = await parseYT([file], [], isMatchingTypeTitleAndArtist: false);

      expect(res!.affectedIds!.keys, ['null']);
      final removed = res.affectedIds!['null']!;
      expect(removed.title, 'a video that has been removed');
      expect(removed.channel, '');
      expect(removed.watches.map((e) => e.dateMS), [utcMS(2022, 2, 4, 14, 20, 56), utcMS(2022, 2, 5, 14, 20, 56)]);
      expect(res.addedYTHistoryCount, 2);
    });

    test('a file whose entries all fail to parse is reported, one with any parsable entry or no entries is not', () async {
      String localizedBody(String id, String date) =>
          '<a href="https://www.youtube.com/watch?v=$id">T</a> angesehen<br><a href="https://www.youtube.com/channel/UC$id">C</a><br>$date';
      final localized = takeoutHtml([
        htmlEntry(localizedBody('aaaaaaaaaaa', '04.02.2022, 16:20:56 MEZ')),
        htmlEntry(localizedBody('bbbbbbbbbbb', '4 févr. 2022, 16:20:56 UTC+1')),
      ]);
      final english = takeoutHtml([htmlEntry(watchedBody('ccccccccccc', 'A', 'C', 'Feb 4, 2022, 4:20:56 PM EET'))]);
      final mixed = takeoutHtml([
        htmlEntry(localizedBody('ddddddddddd', '04.02.2022, 16:20:56 MEZ')),
        htmlEntry(watchedBody('eeeeeeeeeee', 'A', 'C', 'Feb 4, 2022, 4:20:56 PM EET')),
      ]);
      final empty = takeoutHtml([]);

      final localizedRes = await parseYT([english, localized], [], isMatchingTypeTitleAndArtist: false);
      expect(localizedRes!.hasUnreadableHtml, true);
      expect(localizedRes.affectedIds!.keys, ['ccccccccccc']);

      final readableRes = await parseYT([english, mixed, empty], [], isMatchingTypeTitleAndArtist: false);
      expect(readableRes!.hasUnreadableHtml, false);
      expect(readableRes.affectedIds!.keys, ['ccccccccccc', 'eeeeeeeeeee']);
    });
  });

  group('takeout json', () {
    test('ads are skipped', () async {
      final file = takeoutJson([
        jsonWatch('aaaaaaaaaaa', 'A', 'C', '2022-02-04T14:20:56.789Z'),
        jsonWatch('bbbbbbbbbbb', 'Ad', 'Brand', '2022-02-04T14:21:56.789Z', isAd: true),
      ]);
      final res = await parseYT([file], [], isMatchingTypeTitleAndArtist: false);

      expect(res!.affectedIds!.keys, ['aaaaaaaaaaa']);
    });

    test('entries drop the Watched prefix, keep the ytm header and go under the null id without a url', () async {
      final file = writeFile('json', r'''
[{
  "header": "YouTube",
  "title": "Watched Rick Astley - Never Gonna Give You Up (Official Music Video)",
  "titleUrl": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  "subtitles": [{
    "name": "Rick Astley",
    "url": "https://www.youtube.com/channel/UCuAXFkgsw1L7xaCfnd5JJOw"
  }],
  "time": "2022-02-04T14:20:56.789Z",
  "products": ["YouTube"],
  "activityControls": ["YouTube watch history"]
},{
  "header": "YouTube Music",
  "title": "Watched Never Gonna Give You Up",
  "titleUrl": "https://music.youtube.com/watch?v=lYBUbBu4W08",
  "subtitles": [{
    "name": "Rick Astley - Topic",
    "url": "https://www.youtube.com/channel/UCbl3J5Jt2whcDRaGyTrB5DA"
  }],
  "time": "2022-02-05T09:00:00.123Z",
  "products": ["YouTube"],
  "activityControls": ["YouTube watch history"]
},{
  "header": "YouTube",
  "title": "Watched a video that has been removed",
  "time": "2022-02-06T09:00:00.123Z",
  "products": ["YouTube"],
  "activityControls": ["YouTube watch history"]
}]
''');
      final res = await parseYT([file], [], isMatchingTypeTitleAndArtist: false);

      expect(res!.affectedIds!.keys, ['dQw4w9WgXcQ', 'lYBUbBu4W08', 'null']);
      final video = res.affectedIds!['dQw4w9WgXcQ']!;
      expect(video.title, 'Rick Astley - Never Gonna Give You Up (Official Music Video)');
      expect(video.channel, 'Rick Astley');
      expect(video.watches, [YTWatch(dateMSNull: utcMS(2022, 2, 4, 14, 20, 56) + 789, isYTMusic: false)]);
      expect(res.affectedIds!['lYBUbBu4W08']!.watches.single.isYTMusic, true);
      final removed = res.affectedIds!['null']!;
      expect(removed.title, 'a video that has been removed');
      expect(removed.channel, '');
      expect(removed.watches, [YTWatch(dateMSNull: utcMS(2022, 2, 6, 9, 0) + 123, isYTMusic: false)]);
      expect(res.ytHistory.values.expand((e) => e).map((e) => e.id), unorderedEquals(['dQw4w9WgXcQ', 'lYBUbBu4W08', 'null']));
    });

    test('removed videos go to youtube history once, match against what an earlier import stored, and never become local listens', () async {
      final json = takeoutJson([
        removedJsonWatch('2022-02-06T09:00:00.123Z'),
        removedJsonWatch('2022-02-06T09:30:00.123Z', isAd: true),
      ]);
      final html = takeoutHtml([htmlEntry('Watched a video that has been removed<br>Feb 6, 2022, 11:00:00 AM EET')]);
      final untagged = await indexedUntaggedTrack('Removed.m4a');

      final first = await parseYT([json, html], [untagged]);
      expect(first!.ytHistory.values.single.map((e) => e.id), ['null']);
      expect(first.affectedIds!['null']!.watches.map((e) => e.dateMS), [utcMS(2022, 2, 6, 9, 0) + 123]);
      expect(first.addedLocalHistoryCount, 0);
      expect(first.missingEntriesSorted, isEmpty);

      final second = await parseYT([json], [untagged], ytHistory: first.ytHistory);
      expect(second!.addedYTHistoryCount, 0);
    });

    test('the same watch from json and html takeouts is one listen, and importing again adds nothing', () async {
      final json = takeoutJson([jsonWatch('dQw4w9WgXcQ', 'Never Gonna Give You Up', 'Rick Astley', '2022-02-04T14:20:56.789Z')]);
      final html = takeoutHtml([htmlEntry(watchedBody('dQw4w9WgXcQ', 'Never Gonna Give You Up', 'Rick Astley', 'Feb 4, 2022, 4:20:56 PM EET'))]);
      final tracks = [ytTrack('Never Gonna Give You Up', 'Rick Astley')];

      final first = await parseYT([json, html], tracks);
      expect(first!.addedYTHistoryCount, 1);
      expect(first.addedLocalHistoryCount, 1);
      expect(first.affectedIds!['dQw4w9WgXcQ']!.watches.length, 1);

      final second = await parseYT([json, html], tracks, localHistory: first.localHistory, ytHistory: first.ytHistory);
      expect(second!.addedYTHistoryCount, 0);
      expect(second.addedLocalHistoryCount, 0);
    });
  });

  group('takeout matching by title and artist', () {
    Future<List<String>> listenedPaths(String title, String channel, List<_YTTrack> tracks, {bool matchAll = false}) async {
      final file = takeoutJson([jsonWatch('dQw4w9WgXcQ', title, channel, '2022-02-04T14:20:56.789Z')]);
      final res = await parseYT([file], tracks, matchAll: matchAll);
      return res!.localHistory.values.expand((e) => e).map((e) => e.track.path).toList();
    }

    Future<int> listensOf(String title, String channel, List<_YTTrack> tracks, {bool matchAll = false}) async {
      final paths = await listenedPaths(title, channel, tracks, matchAll: matchAll);
      return paths.length;
    }

    test('a library title inside the video title is not a listen without the artist', () async {
      final home = ytTrack('Home', 'Michael Buble');
      expect(await listensOf('How to cook rice at home', 'Chef X', [home]), 0);
      expect(await listensOf('How to cook rice at home', 'Chef X', [home, ytTrack('Something', 'Chef X')]), 0);
    });

    test('the artist can be in the title or the channel, or the album in the channel', () async {
      final tracks = [
        ytTrack('Song A', 'Artist One'),
        ytTrack('Song B', 'Artist Two'),
        ytTrack('Song C', 'Someone', album: 'Nightcore Land'),
      ];
      expect(await listensOf('Artist One - Song A', 'Random Uploads', tracks), 1);
      expect(await listensOf('Song B (Official Video)', 'Artist Two', tracks), 1);
      expect(await listensOf('Nightcore - Song C', 'Nightcore Land', tracks), 1);
    });

    test('a track without artist and album tags matches by its title alone, a tagged one still needs its artist', () async {
      final untagged = await indexedUntaggedTrack('Lonely Melody.m4a');
      expect((untagged.title, untagged.artist, untagged.album), ('Lonely Melody', UnknownTags.ARTIST, UnknownTags.ALBUM));
      expect(await listensOf('Lonely Melody (Official Audio)', 'Some Channel', [untagged]), 1);
      final tagged = ytTrack('Lonely Melody', 'Real Artist');
      expect(await listensOf('Lonely Melody (Official Audio)', 'Some Channel', [tagged]), 0);
    });

    test('the most specific matching title wins, whatever the library order', () async {
      final base = ytTrack('Shape of You', 'Ed Sheeran');
      final acoustic = ytTrack('Shape of You (Acoustic)', 'Ed Sheeran');
      final original = ytTrack('Love Story', 'Taylor Swift');
      final taylorsVersion = ytTrack("Love Story (Taylor's Version)", 'Taylor Swift');
      final libraryOrders = [
        [base, acoustic, original, taylorsVersion],
        [acoustic, base, taylorsVersion, original],
      ];
      for (final tracks in libraryOrders) {
        expect(await listenedPaths('Ed Sheeran - Shape of You (Acoustic)', 'Ed Sheeran', tracks), [acoustic.path]);
        expect(await listenedPaths("Taylor Swift - Love Story (Taylor's Version)", 'Taylor Swift', tracks), [taylorsVersion.path]);
        expect(await listenedPaths('Ed Sheeran - Shape of You', 'Ed Sheeran', tracks), [base.path]);
      }
    });

    test('tags glued to the title still match', () async {
      expect(await listensOf('Artist - Song[MV]', 'Label', [ytTrack('Song', 'Artist')]), 1);
    });

    test('cjk titles match without spaces, but not from scattered characters', () async {
      final tracks = [ytTrack('夜に駆ける', 'YOASOBI'), ytTrack('群青', 'YOASOBI')];
      expect(await listensOf('YOASOBI「夜に駆ける」 Official Music Video', 'Ayase / YOASOBI', tracks), 1);
      expect(await listensOf('YOASOBI夜に駆ける', 'Random Uploads', tracks), 1);
      expect(await listensOf('YOASOBI「青春の群像」', 'YOASOBI', tracks), 0);
    });

    test('matchAll adds every matching track, otherwise only the first', () async {
      final tracks = [ytTrack('Song', 'Artist'), ytTrack('Song', 'Artist', filename: 'copy.m4a')];
      expect(await listenedPaths('Artist - Song', 'Label', tracks), [tracks[0].path]);
      expect(await listensOf('Artist - Song', 'Label', tracks, matchAll: true), 2);
    });
  });

  test('link matching reads the id from the comment, a v= filename or an id in brackets ending the filename, never a bare id filename', () async {
    final tracks = [
      ytTrack('A', 'X', comment: 'https://youtu.be/dQw4w9WgXcQ'),
      ytTrack('B', 'Y', filename: 'B v=lYBUbBu4W08.m4a'),
      ytTrack('C', 'Z', filename: 'Z - C [9bZkp7q19f0].m4a'),
      ytTrack('D', 'Z', filename: 'Z - D [Demo-Take-3].m4a'),
      ytTrack('E', 'Z', filename: 'kJQP7kiw5Fk.webm'),
      ytTrack('F', 'Z', filename: 'Demo-Take-3.m4a'),
    ];
    final file = takeoutJson([
      jsonWatch('dQw4w9WgXcQ', 'Something else', 'Channel', '2022-02-04T14:20:56.789Z'),
      jsonWatch('lYBUbBu4W08', 'Another thing', 'Channel', '2022-02-04T15:20:56.789Z'),
      jsonWatch('9bZkp7q19f0', 'Third thing', 'Channel', '2022-02-04T16:20:56.789Z'),
      jsonWatch('Demo-Take-3', 'Not an id', 'Channel', '2022-02-04T17:20:56.789Z'),
      jsonWatch('kJQP7kiw5Fk', 'Fifth thing', 'Channel', '2022-02-04T18:20:56.789Z'),
    ]);
    final res = await parseYT([file], tracks, isMatchingTypeLink: true, isMatchingTypeTitleAndArtist: false);

    final listenedPaths = res!.localHistory.values.expand((e) => e).map((e) => e.track.path).toSet();
    expect(listenedPaths, {tracks[0].path, tracks[1].path, tracks[2].path});
  });

  _Track track(String title, String artist) => (title: title, artist: artist, path: trackPath('$artist - $title.mp3'), isVideo: false);

  group('lastfm csv', () {
    addLastFm(List<String> lines, List<_Track> tracks, {SplayTreeMap<int, List<TrackWithDate>>? localHistory}) {
      final file = writeFile('csv', lines.join('\n'));
      return JsonToHistoryParser.debugAddLastFmSource((
        tracks: tracks,
        oldestDay: null,
        newestDay: null,
        files: [file],
        matchAll: false,
        artistsSplitConfig: splitConfig,
        portProgressParsed: newPort(),
        portProgressAdded: newPort(),
        portLoadingProgress: newPort(),
        localHistory: localHistory ?? SplayTreeMap(),
      ));
    }

    test('artist, title and the utc date come from the line, importing again adds nothing', () async {
      final tr = track('Never Gonna Give You Up', 'Rick Astley');
      const lines = ['Rick Astley,Whenever You Need Somebody,Never Gonna Give You Up,05 Oct 2026 12:34'];
      final res = await addLastFm(lines, [tr]);

      final twd = res!.localHistory.values.single.single;
      expect(twd.track.path, tr.path);
      expect(twd.dateAdded, utcMS(2026, 10, 5, 12, 34));
      expect(twd.source, TrackSource.lastfm);

      final second = await addLastFm(lines, [tr], localHistory: res.localHistory);
      expect(second!.addedHistoryCount, 0);
    });

    test('quoted fields keep their commas and doubled quotes', () async {
      final tr = track('EARFQUAKE', 'Tyler, The Creator');
      const lines = [
        '"Tyler, The Creator",IGOR,EARFQUAKE,05 Oct 2026 12:34',
        '"Say ""Hi""",Some Album,"Song, Pt. 2",05 Oct 2026 12:40',
      ];
      final res = await addLastFm(lines, [tr]);

      expect(res!.localHistory.values.single.single.track.path, tr.path);
      final missing = res.missingEntriesSorted.keys.single;
      expect(missing.artistOrChannel, 'Say "Hi"');
      expect(missing.title, 'Song, Pt. 2');
      expect(missing.dateMSSE, utcMS(2026, 10, 5, 12, 40));
    });

    test('an unparsable date takes the previous one minus 30 seconds', () async {
      final res = await addLastFm([
        'Artist,Album,First,05 Oct 2026 12:34',
        'Artist,Album,Second,not a date',
      ], []);

      final datesByTitle = {for (final e in res!.missingEntriesSorted.keys) e.title: e.dateMSSE};
      expect(datesByTitle, {'First': utcMS(2026, 10, 5, 12, 34), 'Second': utcMS(2026, 10, 5, 12, 34) - 30000});
    });

    test('lines before any parsable date are skipped instead of landing at the epoch', () async {
      final res = await addLastFm([
        'artist,album,track,date',
        'Artist,Album,First,05 Oct 2026 12:34',
      ], []);

      expect(res!.missingEntriesSorted.keys.map((e) => e.title), ['First']);
    });

    test('a decorated title falls back to the library title, the same title by another artist does not', () async {
      final tr = track('Song', 'Artist');
      const lines = [
        'Artist,Album,Song (Remastered 2011),05 Oct 2026 12:34',
        'Somebody Else,Album,Song,05 Oct 2026 12:40',
      ];
      final res = await addLastFm(lines, [tr]);

      expect(res!.localHistory.values.single.single.dateAdded, utcMS(2026, 10, 5, 12, 34));
      expect(res.missingEntriesSorted.keys.single.artistOrChannel, 'Somebody Else');
    });

    test('a decorated title falls back to the most specific library title it holds, whatever the library order', () async {
      final love = track('Love', 'Taylor Swift');
      final loveStory = track('Love Story', 'Taylor Swift');
      const lines = ["Taylor Swift,Fearless (Taylor's Version),Love Story (Taylor's Version),05 Oct 2026 12:34"];
      for (final tracks in [
        [love, loveStory],
        [loveStory, love],
      ]) {
        final res = await addLastFm(lines, tracks);
        expect(res!.localHistory.values.single.single.track.path, loveStory.path);
      }
    });
  });

  group('spotify json', () {
    addSpotify(List<File> files, List<_Track> tracks) {
      return JsonToHistoryParser.debugAddSpotifySource((
        tracks: tracks,
        oldestDay: null,
        newestDay: null,
        files: files,
        matchAll: false,
        artistsSplitConfig: splitConfig,
        portProgressParsed: newPort(),
        portProgressAdded: newPort(),
        portLoadingProgress: newPort(),
        localHistory: SplayTreeMap(),
      ));
    }

    test('account data entries give artist, title and the utc end time, unplayed ones are skipped', () async {
      final tr = track('Never Gonna Give You Up', 'Rick Astley');
      final file = writeFile('json', r'''
[
  {"endTime": "2023-01-15 14:32", "artistName": "Rick Astley", "trackName": "Never Gonna Give You Up", "msPlayed": 213000},
  {"endTime": "2023-01-15 14:40", "artistName": "Rick Astley", "trackName": "Never Gonna Give You Up", "msPlayed": 0},
  {"endTime": "2023-01-15 15:00", "artistName": "Somebody", "trackName": "Unknown Song", "msPlayed": 1000}
]
''');
      final res = await addSpotify([file], [tr]);

      final twd = res!.localHistory.values.single.single;
      expect(twd.track.path, tr.path);
      expect(twd.dateAdded, utcMS(2023, 1, 15, 14, 32));
      expect(twd.source, TrackSource.spotify);
      final missing = res.missingEntriesSorted.keys.single;
      expect(missing.title, 'Unknown Song');
      expect(missing.dateMSSE, utcMS(2023, 1, 15, 15, 0));
    });

    test('extended entries still import next to account data ones', () async {
      final tr = track('Never Gonna Give You Up', 'Rick Astley');
      final basic = writeFile('json', '[{"endTime": "2023-01-15 14:32", "artistName": "Rick Astley", "trackName": "Never Gonna Give You Up", "msPlayed": 213000}]');
      final extended = writeFile(
        'json',
        '[{"ts": "2023-01-16T10:00:00Z", "master_metadata_track_name": "Never Gonna Give You Up", "master_metadata_album_artist_name": "Rick Astley", "ms_played": 213000}]',
      );
      final res = await addSpotify([basic, extended], [tr]);

      final dates = res!.localHistory.values.expand((e) => e).map((e) => e.dateAdded);
      expect(dates, [utcMS(2023, 1, 15, 14, 32), utcMS(2023, 1, 16, 10, 0)]);
    });

    test('podcast history files are skipped, music and extended ones are kept', () async {
      const names = [
        'StreamingHistory_music_0.json', 'StreamingHistory0.json', 'StreamingHistory_podcast_0.json', //
        'Streaming_History_Audio_2019-2020_0.json', 'endsong_0.json', 'Userdata.json',
      ];
      final files = names.map((e) => File(trackPath(e))).toList();
      final filtered = await JsonToHistoryParser.debugFilterFiles(files, TrackSource.spotify);
      expect(filtered.map((e) => e.path), [files[0].path, files[1].path, files[3].path, files[4].path]);
    });
  });

  test('items added to the reverse matcher match haystacks that hold all of their tokens', () {
    final matcher = ReverseSearchMatcher<String>()
      ..addItem('never gonna', 'Never Gonna')
      ..addItem('give you up', 'Give You Up!')
      ..addItem('let you down', 'Let You Down');

    final matched = matcher.matchContainedIn(SearchMatcher.tokenizeHaystack('Rick Astley - Never Gonna Give You Up'));
    expect(matched.toSet(), {'never gonna', 'give you up'});
  });

  group('youtube stats buckets', () {
    late String statsDirPath;
    setUpAll(() {
      statsDirPath = '${dir.path}${Platform.pathSeparator}stats';
      Directory(statsDirPath).createSync();
    });

    String bucketPath(String name) => '$statsDirPath${Platform.pathSeparator}$name.json';

    void updateStats(Map<String, YoutubeVideoHistory> affectedIds) {
      JsonToHistoryParser.debugUpdateYoutubeStatsDirectory((affectedIds: affectedIds, dirPath: statsDirPath, progressPort: newPort()));
    }

    YoutubeVideoHistory video(String id, List<int> watchesMS) {
      final watches = watchesMS.map((e) => YTWatch(dateMSNull: e, isYTMusic: false)).toList();
      return YoutubeVideoHistory(id: id, title: 'title $id', channel: 'channel', channelUrl: '', watches: watches);
    }

    test('affected videos are merged into their bucket and the rest is kept', () {
      final b1 = video('b1', [1000]);
      final b2 = video('b2', [2000]);
      final b2Again = video('b2', [2000, 3000]);
      final b3 = video('b3', [4000]);
      updateStats({b1.id: b1, b2.id: b2});
      updateStats({b2Again.id: b2Again, b3.id: b3});

      final stored = jsonDecode(File(bucketPath('b')).readAsStringSync()) as List;
      final watchesById = {for (final e in stored) e['id']: (e['watches'] as List).map((w) => w['date']).toList()};
      expect(watchesById, {
        'b1': [1000],
        'b2': [2000, 3000],
        'b3': [4000],
      });
      expect(File('${bucketPath('b')}.tmp').existsSync(), isFalse);
    });

    test('a bucket whose new content cannot be written keeps its old content', () {
      final c1 = video('c1', [1000]);
      updateStats({c1.id: c1});
      final bucket = File(bucketPath('c'));
      final storedBefore = bucket.readAsStringSync();
      Directory('${bucket.path}.tmp').createSync();

      final c2 = video('c2', [2000]);
      updateStats({c2.id: c2});

      expect(bucket.readAsStringSync(), storedBefore);
    });

    test('removed videos are merged into the bucket of the null id like any other id', () async {
      final firstFile = takeoutJson([removedJsonWatch('2022-02-06T09:00:00.123Z')]);
      final secondFile = takeoutJson([removedJsonWatch('2022-02-07T09:00:00.123Z')]);
      final first = await parseYT([firstFile], [], isMatchingTypeTitleAndArtist: false);
      final second = await parseYT([secondFile], [], isMatchingTypeTitleAndArtist: false);
      final other = video('n1', [1000]);
      updateStats(first!.affectedIds!);
      updateStats({...second!.affectedIds!, other.id: other});

      final stored = jsonDecode(File(bucketPath('n')).readAsStringSync()) as List;
      final watchesById = {for (final e in stored) e['id']: (e['watches'] as List).map((w) => w['date']).toList()};
      expect(watchesById, {
        'null': [utcMS(2022, 2, 6, 9, 0) + 123, utcMS(2022, 2, 7, 9, 0) + 123],
        'n1': [1000],
      });
      expect(stored.firstWhere((e) => e['id'] == 'null')['title'], 'a video that has been removed');
    });

    test('a bucket that cannot be read is left untouched', () {
      const truncated = '[{"id":"a1","title":"title a1","watches":[{"date":1000}]},{"id":"a2"';
      final file = File(bucketPath('a'))..writeAsStringSync(truncated);

      final a3 = video('a3', [5000]);
      updateStats({a3.id: a3});

      expect(file.readAsStringSync(), truncated);
    });
  });
}

typedef _YTTrack = ({String title, String artist, String album, String path, String comment, bool isVideo});

typedef _Track = ({String title, String artist, String path, bool isVideo});
