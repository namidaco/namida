// by claude
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/search_matcher.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

import 'bench_data.dart';

void main() {
  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_sort_and_match_benchmark');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  final synthetic = SyntheticLibrary.generate(kBenchTracksCount);

  test('track sort comparables', () async {
    final runner = BenchRunner('sorting');
    final random = Random(3);
    final names = SyntheticLibrary(4);
    final tracks = <Track>[];
    for (final s in synthetic) {
      final track = Track.explicit(s.path);
      tracks.add(track);
      final title = s.title ?? s.path.getFilename;
      final artist = s.artist ?? UnknownTags.ARTIST;
      final album = s.album ?? '';
      final albumArtist = s.albumArtist ?? '';
      final composer = s.composer ?? '';
      final hasSortInfo = random.nextDouble() < 0.3;
      final sortInfo = hasSortInfo ? _randomSortInfo(names, random) : null;
      Indexer.inst.allTracksMappedByPath[s.path] = kDummyExtendedTrack.copyWith(
        path: s.path,
        title: title,
        originalArtist: artist,
        artistsList: [artist],
        originalAlbum: album,
        albumsList: album.isEmpty ? const [] : [album],
        albumArtist: albumArtist,
        composer: composer,
        sortInfo: sortInfo,
        generatePathHash: false,
      );
    }
    final shuffled = tracks.toFixedList()..shuffle(Random(9));
    final controller = SearchSortController.inst;

    for (final type in const [SortType.title, SortType.titleSort, SortType.artistSort, SortType.albumSort]) {
      List<Comparable> keys() {
        final comparable = controller.getTracksSortingComparables(type);
        return tracks.map(comparable).toFixedList();
      }

      runner.digest('keys ${type.name}', keys().map((e) => '$e'));
      await runner.run('getTracksSortingComparables(${type.name}) keys x${tracks.length}', keys);
    }

    final list = shuffled.toFixedList();
    void reset() => list.setAll(0, shuffled);
    int sortByTitleSort() {
      final comparable = controller.getTracksSortingComparables(SortType.titleSort);
      list.sortByPrecomputed(comparable);
      return list.length;
    }

    reset();
    sortByTitleSort();
    runner.digest('tracks list sorted by titleSort', list.map((e) => e.path));
    await runner.run('tracks list sort by titleSort x${list.length}', sortByTitleSort, setUp: reset, iterations: 10);
    runner.finish();
  }, timeout: Timeout.none);

  test('local video matching', () async {
    final runner = BenchRunner('video_matching');
    final random = Random(17);
    final names = SyntheticLibrary(18);
    final queries = <_VideoQuery>[];
    for (int i = 0; i < 2000; i++) {
      final s = synthetic[random.nextInt(synthetic.length)];
      final comment = s.comment ?? '';
      final trExt = kDummyExtendedTrack.copyWith(path: s.path, comment: comment, generatePathHash: false);
      final filenameWOExt = s.path.getFilenameWOExt;
      final title = s.title ?? filenameWOExt;
      final firstArtist = _firstPart(s.artist, _artistSeparatorsRegex);
      final firstGenre = _firstPart(s.genre, _genreSeparatorsRegex);
      queries.add((filenameWOExt: filenameWOExt, title: title, artist: firstArtist, genre: firstGenre, ytID: trExt.youtubeID));
    }
    final videoPaths = <String>[];
    for (int i = 0; i < 10000; i++) {
      final isFromLibrary = random.nextDouble() < 0.3;
      final query = queries[random.nextInt(queries.length)];
      final title = isFromLibrary ? query.title : names.phrase(1, 4);
      final queryArtist = isFromLibrary ? query.artist : null;
      final artist = queryArtist ?? names.phrase(1, 2);
      final shouldUseQueryId = isFromLibrary && query.ytID.length == 11;
      final ytID = shouldUseQueryId ? query.ytID : names.youtubeId();
      final roll = random.nextDouble();
      final filename = roll < 0.4
          ? '$artist - $title [$ytID].mp4'
          : roll < 0.7
          ? '$title.mp4'
          : roll < 0.8
          ? '$ytID.mp4'
          : '$title (Official Video) - $artist.webm';
      videoPaths.add('/storage/emulated/0/Movies/Folder ${i % 40}/$filename');
    }

    FilePathMatcher initMatcher() {
      final matcher = FilePathMatcher.init(videoPaths);
      _matchVideos(matcher, queries.first);
      return matcher;
    }

    await runner.run('FilePathMatcher.init + yt index x${videoPaths.length} videos', initMatcher, iterations: 10);
    final matcher = initMatcher();
    List<Iterable<String>> matchAll() => queries.map((q) => _matchVideos(matcher, q)).toFixedList();
    final matchedLines = matchAll().map((e) => (e.toFixedList()..sort()).join('|'));
    runner.digest('matched videos', matchedLines);
    await runner.run('match ${queries.length} tracks against ${videoPaths.length} videos', matchAll, iterations: 10);
    runner.finish();
  }, timeout: Timeout.none);
}

final _artistSeparatorsRegex = RegExp(r'&|,|;|//| ft\. | x ', caseSensitive: false);
final _genreSeparatorsRegex = RegExp(r'&|,|;|//| x |/', caseSensitive: false);

Iterable<String> _matchVideos(FilePathMatcher matcher, _VideoQuery q) {
  return matcher.matchTrackVideos(
    filenameWOExt: q.filenameWOExt,
    title: q.title,
    artist: q.artist,
    genre: q.genre,
    ytID: q.ytID,
    matchingType: LocalVideoMatchingType.auto,
    onlyInDirectory: null,
  );
}

String? _firstPart(String? text, RegExp separatorsRegex) {
  if (text == null) return null;
  final parts = text.split(separatorsRegex);
  return parts.first.trim();
}

FTagsSortInfo? _randomSortInfo(SyntheticLibrary names, Random random) {
  final title = names.phrase(1, 3);
  final artist = names.phrase(1, 2);
  final hasAlbum = random.nextBool();
  final album = hasAlbum ? names.phrase(1, 3) : null;
  return FTagsSortInfo.orNull(title: title, artist: artist, album: album);
}

typedef _VideoQuery = ({String filenameWOExt, String title, String? artist, String? genre, String ytID});
