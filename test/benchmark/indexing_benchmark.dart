// by claude
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

import 'bench_data.dart';

void main() {
  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_indexing_benchmark');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('indexing, tracks db reload, youtube links', () async {
    final runner = BenchRunner('indexing');
    final artistsConfig = ArtistsSplitConfig(addFeatArtist: true, separators: kBenchArtistSeparators, separatorsBlacklist: const []);
    final genresConfig = GenresSplitConfig(separators: kBenchGenreSeparators, separatorsBlacklist: const []);
    final albumConfig = AlbumsSplitConfig(separators: const ['\u00A0'], separatorsBlacklist: const []);
    final splitConfig = SplitArtistGenreConfigsWrapper(
      dbPath: '',
      artistsConfig: artistsConfig,
      genresConfig: genresConfig,
      albumConfig: albumConfig,
      generalConfig: GeneralSplitConfig(),
    );
    final tracks = SyntheticLibrary.generate(kBenchTracksCount);
    final infos = List.generate(tracks.length, (i) => _audioModelOf(tracks[i], i), growable: false);
    final stats = tracks.map((e) => FileStatsAdv(creationDateMS: e.dateAddedMS, modifiedMS: e.dateModifiedMS, size: e.sizeBytes)).toFixedList();

    Future<List<TrackExtended>> indexAll() async {
      final res = <TrackExtended>[];
      for (int i = 0; i < tracks.length; i++) {
        final trExt = await Indexer.convertTagToTrack(
          trackPath: tracks[i].path,
          stats: stats[i],
          trackInfo: infos[i],
          tryExtractingFromFilename: true,
          onMinDurTrigger: () => null,
          onMinSizeTrigger: () => null,
          onError: (err) => throw StateError(err),
          splittersConfigs: splitConfig,
        );
        res.add(trExt!);
      }
      return res;
    }

    final indexed = await indexAll();
    runner.digest('convertTagToTrack', indexed.map(_derivedLine));
    await runner.run('convertTagToTrack x${tracks.length}', indexAll, warmups: 2, iterations: 7);

    List<List<String>> splitArtists() => tracks.map((e) => Indexer.splitArtist(title: e.title, originalArtist: e.artist, config: artistsConfig)).toFixedList();
    List<List<String>> splitGenres() => tracks.map((e) => genresConfig.splitText(e.genre, fallback: UnknownTags.GENRE)).toFixedList();
    List<List<String>> splitAlbums() => tracks.map((e) => albumConfig.splitText(e.album)).toFixedList();

    runner.digest('splitArtist', splitArtists().map((e) => e.join('|')));
    runner.digest('splitGenre', splitGenres().map((e) => e.join('|')));
    runner.digest('splitAlbum', splitAlbums().map((e) => e.join('|')));
    await runner.run('Indexer.splitArtist x${tracks.length}', splitArtists);
    await runner.run('genres splitText x${tracks.length}', splitGenres);
    await runner.run('albums splitText x${tracks.length}', splitAlbums);

    final storedRows = tracks.map((e) => e.toStoredRow()).toFixedList();
    final rowsJson = jsonEncode(storedRows);
    final rowsDecoded = jsonDecode(rowsJson) as List;
    final rows = rowsDecoded.cast<Map<String, dynamic>>();

    List<TrackExtended> reloadAll() {
      final res = <TrackExtended>[];
      for (int i = 0; i < rows.length; i++) {
        res.add(TrackExtended.fromJson(tracks[i].path, rows[i], splitConfig: splitConfig));
      }
      return res;
    }

    Map<String, List<Track>> reloadAllWithYoutubeIds() {
      final allTracksMappedByYTID = <String, List<Track>>{};
      for (int i = 0; i < rows.length; i++) {
        final trExt = TrackExtended.fromJson(tracks[i].path, rows[i], splitConfig: splitConfig);
        final track = trExt.asTrack();
        allTracksMappedByYTID.addForce(trExt.youtubeID, track);
      }
      return allTracksMappedByYTID;
    }

    runner.digest('fromJson', reloadAll().map(_derivedLine));
    await runner.run('TrackExtended.fromJson x${rows.length}', reloadAll, warmups: 2, iterations: 7);
    await runner.run('startup row (fromJson + asTrack + youtubeID) x${rows.length}', reloadAllWithYoutubeIds, warmups: 2, iterations: 7);

    final linkTracks = tracks.map(_linkTrackOf).toFixedList();
    List<String> youtubeLinks() => linkTracks.map((e) => e.youtubeLink).toFixedList();

    runner.digest('youtubeLink', youtubeLinks());
    await runner.run('Track.youtubeLink x${linkTracks.length}', youtubeLinks, warmups: 3, iterations: 15);
    runner.finish();
  }, timeout: Timeout.none);
}

FAudioModel _audioModelOf(SyntheticTrack track, int index) {
  final artwork = FArtwork(size: 0);
  final tags = FTags.edit(
    path: track.path,
    artwork: artwork,
    title: track.title,
    artist: track.artist,
    album: track.album,
    albumArtist: track.albumArtist,
    genre: track.genre,
    year: track.year,
    composer: track.composer,
    comment: track.comment,
    trackNumber: track.trackNumber,
    discNumber: track.discNumber,
  );
  final hasError = track.isUntagged && index.isEven;
  return FAudioModel(tags: tags, durationMS: track.durationMS, bitRate: 320, sampleRate: 44100, bits: 16, format: 'MPEG', channels: 'stereo', hasError: hasError);
}

TrackExtended _linkTrackOf(SyntheticTrack track) {
  final comment = track.comment ?? '';
  return kDummyExtendedTrack.copyWith(path: track.path, comment: comment, generatePathHash: false);
}

String _derivedLine(TrackExtended tr) {
  final wrappers = tr.albumsIdentifiersWrappers.map((e) => '${e.album}/${e.albumArtist}/${e.year}').join(',');
  return [
    tr.path,
    tr.title,
    tr.originalArtist,
    tr.artistsList.join(';'),
    tr.originalAlbum,
    tr.albumsList.join(';'),
    tr.albumArtistsList.join(';'),
    tr.genresList.join(';'),
    tr.composersList.join(';'),
    tr.year,
    tr.yearText,
    tr.trackNo,
    tr.trackTo,
    tr.discNo,
    tr.durationMS,
    wrappers,
  ].join('|');
}
