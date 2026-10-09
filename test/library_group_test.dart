// by claude
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/library_group.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';

void main() {
  late Directory dir;
  late SplitArtistGenreConfigsWrapper splitConfig;
  final sep = Platform.pathSeparator;
  const albumIdentifiers = [AlbumIdentifier.albumName, AlbumIdentifier.albumArtist];

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_library_group_test');
    AppDirs.USER_DATA = '${dir.path}$sep';
    splitConfig = SplitArtistGenreConfigsWrapper(
      dbPath: '',
      artistsConfig: ArtistsSplitConfig(addFeatArtist: true, separators: const ['&', ',', ';', '//', ' ft. ', ' x '], separatorsBlacklist: const []),
      genresConfig: GenresSplitConfig(separators: const ['&', ',', ';', '//', ' x '], separatorsBlacklist: const []),
      albumConfig: SimpleSplitConfig(),
      generalConfig: GeneralSplitConfig(),
    );
  });
  tearDownAll(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {} // -- the tracks db written in the background by a reindex can still hold the folder
  });

  String pathOf(String relativePath) => '${dir.path}$sep$relativePath';

  TrackExtended trackOf(
    String path, {
    String artist = 'A',
    String album = 'Alb',
    String albumArtist = '',
    String composer = '',
    String genre = 'Rock',
    String style = '',
    String language = '',
  }) {
    return TrackExtended.derive(
      splitConfig: splitConfig,
      mbAlbumId: '',
      mbAlbumArtistId: '',
      title: 'Title',
      originalArtist: artist,
      originalAlbum: album,
      albumArtist: albumArtist,
      originalGenre: genre,
      originalStyle: style,
      originalMood: '',
      composer: composer,
      trackNo: 0,
      trackTo: 0,
      durationMS: 0,
      year: 0,
      yearText: '',
      size: 0,
      dateAdded: 0,
      dateModified: 0,
      path: path,
      comment: '',
      description: '',
      synopsis: '',
      bitrate: 0,
      sampleRate: 0,
      bits: 0,
      isLossless: null,
      format: '',
      channels: '',
      discNo: 0,
      discTo: 0,
      language: language,
      lyrics: '',
      label: '',
      releaseType: '',
      bpm: null,
      musicalKey: '',
      rating: 0.0,
      originalTags: null,
      gainData: null,
      sortInfo: null,
      hashKey: null,
      extraTags: null,
      chapters: null,
      isVideo: path.endsWith('.mp4'),
      server: null,
      serverFolder: null,
    );
  }

  LibraryGroup<Track> filled(List<TrackExtended> tracks) {
    final byPath = {for (final e in tracks) e.path: e};
    final allTracks = tracks.map((e) => e.asTrack()).toList();
    return LibraryGroup<Track>()..fillAll(allTracks, (tr) => byPath[tr.path]!, albumIdentifiers);
  }

  void expectSameAsFreshFill(LibraryGroup<Track> group, List<TrackExtended> tracks, {String reason = ''}) {
    final fresh = filled(tracks);
    void compare<K>(String media, Map<K, List<Track>> actual, Map<K, List<Track>> expected) {
      expect(actual.length, expected.length, reason: '$reason $media keys ${actual.keys} vs ${expected.keys}');
      for (final e in expected.entries) {
        final expectedList = e.value;
        expect(expectedList.length, expectedList.toSet().length, reason: '$reason fresh $media ${e.key} has duplicates');
        final list = actual[e.key];
        expect(list?.toSet(), expectedList.toSet(), reason: '$reason $media ${e.key}');
        expect(list?.length, expectedList.length, reason: '$reason $media ${e.key} has duplicates');
      }
    }

    compare('album', group.mainMapAlbums.value, fresh.mainMapAlbums.value);
    compare('artist', group.mainMapArtists.value, fresh.mainMapArtists.value);
    compare('albumArtist', group.mainMapAlbumArtists.value, fresh.mainMapAlbumArtists.value);
    compare('composer', group.mainMapComposer.value, fresh.mainMapComposer.value);
    compare('genre', group.mainMapGenres.value, fresh.mainMapGenres.value);
    compare('style', group.mainMapStyles.value, fresh.mainMapStyles.value);
    compare('language', group.mainMapLanguages.value, fresh.mainMapLanguages.value);
    compare('folder', group.mainMapFoldersTracksAndVideos.value, fresh.mainMapFoldersTracksAndVideos.value);
    compare('folderMusic', group.mainMapFoldersTracks.value, fresh.mainMapFoldersTracks.value);
    compare('folderVideo', group.mainMapFoldersVideos.value, fresh.mainMapFoldersVideos.value);
  }

  test('random edits, moves and additions end up like a fresh fill', () {
    final random = math.Random(42);
    const artists = ['Queen', 'queen', 'Muse', 'A & B', 'b & C', 'Muse x QUEEN'];
    const albums = ['First', 'first', 'First; Second', 'Second; Third', 'Rock; rock', ''];
    const albumArtists = ['', 'Band', 'band'];
    const composers = ['', 'Comp', 'Comp, Other'];
    const genres = ['Rock', 'rock', 'Pop; Rock', 'Jazz', ''];
    const styles = ['', 'Indie', 'indie; Lo-fi'];
    const languages = ['', 'eng', 'eng; jpn', 'jpn'];
    const folders = ['m1', 'm2', 'm3'];
    E pick<E>(List<E> items) => items[random.nextInt(items.length)];
    String randomPath(int id, {required bool isVideo}) => pathOf('${pick(folders)}$sep$id.${isVideo ? 'mp4' : 'mp3'}');
    TrackExtended randomTrack(String path) => trackOf(
      path,
      artist: pick(artists),
      album: pick(albums),
      albumArtist: pick(albumArtists),
      composer: pick(composers),
      genre: pick(genres),
      style: pick(styles),
      language: pick(languages),
    );

    for (int round = 0; round < 80; round++) {
      final tracksCount = round.isEven ? 20 : 150;
      final oldTracks = [for (int id = 0; id < tracksCount; id++) randomTrack(randomPath(id, isVideo: random.nextInt(4) == 0))];
      final group = filled(oldTracks);

      final newOldTracks = <TrackExtended, TrackExtended?>{};
      final newTracks = <TrackExtended>[];
      for (int id = 0; id < oldTracks.length; id++) {
        final old = oldTracks[id];
        final action = random.nextInt(4);
        if (action == 0) {
          newTracks.add(old);
          continue;
        }
        final path = action == 3 ? randomPath(id, isVideo: old.isVideo) : old.path;
        final edited = randomTrack(path);
        newOldTracks[edited] = old;
        newTracks.add(edited);
      }
      for (int id = 1000; id < 1003; id++) {
        final added = randomTrack(randomPath(id, isVideo: random.nextBool()));
        newOldTracks[added] = null;
        newTracks.add(added);
      }

      group.updateTracksSync(newOldTracks, albumIdentifiers);
      expectSameAsFreshFill(group, newTracks, reason: 'round $round');
    }
  });

  test('an album edit moves the track and drops the emptied album', () {
    final t1 = trackOf(pathOf('m1${sep}t1.mp3'), album: 'Old');
    final t2 = trackOf(pathOf('m1${sep}t2.mp3'), album: 'Kept');
    final group = filled([t1, t2]);
    final t1Edited = trackOf(t1.path, album: 'New; Kept');
    group.updateTracksSync({t1Edited: t1}, albumIdentifiers);

    final albums = group.mainMapAlbums.value;
    expect(albums.keys.map((e) => e.album), unorderedEquals(['Kept', 'New']));
    expect(albums.entries.firstWhere((e) => e.key.album == 'Kept').value, unorderedEquals([t1.asTrack(), t2.asTrack()]));
    expectSameAsFreshFill(group, [t1Edited, t2]);
  });

  test('a case only artist rename keeps the track listed', () {
    final t1 = trackOf(pathOf('m1${sep}t1.mp3'), artist: 'Queen');
    final t2 = trackOf(pathOf('m1${sep}t2.mp3'), artist: 'Queen');
    final group = filled([t1, t2]);
    final t1Edited = trackOf(t1.path, artist: 'queen');
    group.updateTracksSync({t1Edited: t1}, albumIdentifiers);
    expect(group.mainMapArtists.value['QUEEN'], unorderedEquals([t1.asTrack(), t2.asTrack()]));

    final single = trackOf(pathOf('m1${sep}single.mp3'), artist: 'muse');
    final singleGroup = filled([single]);
    singleGroup.updateTracksSync({trackOf(single.path, artist: 'Muse'): single}, albumIdentifiers);
    expect(singleGroup.mainMapArtists.value.keys, ['Muse']);
  });

  test('a new track joins each of its medias once and reports its new folder', () {
    final group = filled([trackOf(pathOf('m1${sep}t1.mp3'))]);
    final added = trackOf(pathOf('m2${sep}new.mp3'), album: 'A; B', artist: 'X & Y');
    final changes = group.updateTracksSync({added: null}, albumIdentifiers);

    expect(changes.hasNewKeys(MediaType.folder), true);
    expect(changes.hasNewKeys(MediaType.folderMusic), true);
    expect(changes.hasNewKeys(MediaType.folderVideo), false);
    final albumsWithTrack = group.mainMapAlbums.value.entries.where((e) => e.value.contains(added.asTrack())).map((e) => e.key.album);
    expect(albumsWithTrack, unorderedEquals(['A', 'B']));
    expect(group.mainMapArtists.value['X'], [added.asTrack()]);
    expect(group.mainMapArtists.value['Y'], [added.asTrack()]);
  });

  test('an untouched edit changes nothing', () {
    final t1 = trackOf(pathOf('m1${sep}t1.mp3'), album: 'A; B', artist: 'X & Y');
    final group = filled([t1]);
    final changes = group.updateTracksSync({trackOf(t1.path, album: 'A; B', artist: 'X & Y'): t1}, albumIdentifiers);
    expect(changes.changedMedias, isEmpty);
  });

  test('changed lists are sorted by their own media sorters', () {
    final tracks = [
      for (final name in ['b', 'd', 'a']) trackOf(pathOf('m1$sep$name.mp3'), artist: 'X', album: 'Alb', albumArtist: 'AA'),
    ];
    final group = filled(tracks);
    final added = trackOf(pathOf('m1${sep}c.mp3'), artist: 'X', album: 'Alb', albumArtist: 'AA');
    final changes = group.updateTracksSync({added: null}, albumIdentifiers);

    Comparable<dynamic> byPath(Track tr) => tr.path;
    final sorters = {
      for (final e in changes.changedMedias) e: [byPath],
    };
    group.sortChangedSync(changes, sorters, const {MediaType.albumArtist: true});

    List<String> namesOf(List<Track> list) => list.map((e) => e.path.split(sep).last).toList();
    expect(namesOf(group.mainMapAlbums.value.values.single), ['a.mp3', 'b.mp3', 'c.mp3', 'd.mp3']);
    expect(namesOf(group.mainMapArtists.value.values.single), ['a.mp3', 'b.mp3', 'c.mp3', 'd.mp3']);
    expect(namesOf(group.mainMapAlbumArtists.value.values.single), ['d.mp3', 'c.mp3', 'b.mp3', 'a.mp3']);
  });

  group('long lists', () {
    late TrackExtended template;
    late List<Track> listed;

    setUpAll(() {
      template = trackOf(pathOf('m1${sep}template.mp3'));
      listed = List.generate(30000, (i) => _CountingTrack(pathOf('m1$sep$i.mp3')), growable: false);
    });

    test('a new track joins them without scanning them', () {
      final group = LibraryGroup<Track>()..fillAll(listed, (_) => template, albumIdentifiers);
      final added = trackOf(pathOf('m1${sep}new.mp3'));
      _CountingTrack.equalityChecks = 0;
      group.updateTracksSync({added: null}, albumIdentifiers);

      expect(_CountingTrack.equalityChecks, 0);
      final composerTracks = group.mainMapComposer.value[UnknownTags.COMPOSER]!;
      expect(composerTracks.length, listed.length + 1);
      expect(composerTracks.last, added.asTrack());
    });

    test('a batch edit moving tracks into one checks it once, not per track', () {
      final withComposer = List.generate(500, (i) => trackOf(pathOf('m2${sep}c$i.mp3'), composer: 'Comp'), growable: false);
      final byPath = {for (final e in withComposer) e.path: e};
      final allTracks = [...listed, ...withComposer.map((e) => e.asTrack())];
      final group = LibraryGroup<Track>()..fillAll(allTracks, (tr) => byPath[tr.path] ?? template, albumIdentifiers);
      final composerCleared = {for (final e in withComposer) trackOf(e.path): e};
      _CountingTrack.equalityChecks = 0;
      group.updateTracksSync(composerCleared, albumIdentifiers);

      expect(_CountingTrack.equalityChecks, lessThan(listed.length));
      final composerTracks = group.mainMapComposer.value[UnknownTags.COMPOSER]!;
      expect(composerTracks.length, allTracks.length);
      expect(composerTracks.toSet().length, allTracks.length);
      expect(group.mainMapComposer.value['Comp'], isNull);
    });

    test('a list that shrank under the limit in the same batch still lists a track once', () {
      final inLang = List.generate(32, (i) => trackOf(pathOf('m2${sep}l$i.mp3'), language: 'Klingonish'), growable: false);
      final joining = trackOf(pathOf('m2${sep}joining.mp3'));
      final collapsing = trackOf(pathOf('m2${sep}collapsing.mp3'));
      final group = filled([...inLang, joining, collapsing]);

      final joiningEdited = trackOf(joining.path, language: 'Klingonish');
      final leaving1 = trackOf(inLang[0].path);
      final leaving2 = trackOf(inLang[1].path);
      final collapsingEdited = trackOf(collapsing.path, language: 'Klingonish; klingonish');
      group.updateTracksSync({joiningEdited: joining, leaving1: inLang[0], leaving2: inLang[1], collapsingEdited: collapsing}, albumIdentifiers);

      final langTracks = group.mainMapLanguages.value['Klingonish']!;
      expect(langTracks.where((e) => e == collapsing.asTrack()).length, 1);
      expectSameAsFreshFill(group, [leaving1, leaving2, ...inLang.skip(2), joiningEdited, collapsingEdited]);
    });

    test('a path listed meanwhile, added as an edit of itself, stays listed once', () {
      final group = LibraryGroup<Track>()..fillAll(listed, (_) => template, albumIdentifiers);
      final first = trackOf(pathOf('m1${sep}race.mp3'), composer: 'Comp');
      group.updateTracksSync({first: null}, albumIdentifiers);
      final second = trackOf(first.path);
      group.updateTracksSync({second: first}, albumIdentifiers);

      final composerTracks = group.mainMapComposer.value[UnknownTags.COMPOSER]!;
      expect(composerTracks.where((e) => e.path == first.path).length, 1);
      expect(group.mainMapComposer.value['Comp'], isNull);
      expect(group.mainMapFoldersTracks.value.values.single.length, listed.length + 1);
    });
  });

  test('a track is listed once when its keys collapse into one list', () {
    const albumArtistOnly = [AlbumIdentifier.albumArtist];
    final collapsing = trackOf(pathOf('m1${sep}collapse.mp3'), album: 'A; B', albumArtist: 'AA', language: 'Klingonish; klingonish');
    final track = collapsing.asTrack();

    final fresh = LibraryGroup<Track>()..fillAll([track], (_) => collapsing, albumArtistOnly);
    expect(fresh.mainMapAlbums.value.values.single, [track]);
    expect(fresh.mainMapLanguages.value.values.single, [track]);

    final incremental = LibraryGroup<Track>();
    incremental.updateTracksSync({collapsing: null}, albumArtistOnly);
    expect(incremental.mainMapAlbums.value.values.single, [track]);
    expect(incremental.mainMapLanguages.value.values.single, [track]);
  });

  test('a path passed twice or inside a passed folder is added once', () async {
    final folder = Directory(pathOf('passed'))..createSync();
    final file = File('${folder.path}${sep}song.mp3')..writeAsBytesSync(const []);
    Indexer.inst.allTracksMappedByPath[file.path] = trackOf(file.path);

    final tracks = await Indexer.inst.convertPathsToTracksAndAddToLists([file.path, folder.path, file.path]);
    expect(tracks, [Track.explicit(file.path)]);
  });

  test('a reindexed track not in the library is listed once when a library refresh lands before the reindex ends', () async {
    final indexer = Indexer.inst;
    final folder = Directory(pathOf('reindexed'))..createSync();
    final file = File('${folder.path}${sep}song.wav')..writeAsBytesSync(_silentWavBytes());
    final track = PhysicalMedia.fromTrack(Track.explicit(file.path));
    expect(indexer.allTracksMappedByPath.containsKey(file.path), false);

    void refreshLibrary() => indexer.mainMapsGroup.fillAll(indexer.tracksInfoList.value, (tr) => tr.toTrackExt(), albumIdentifiers);
    int extractedCount = 0;
    await indexer.reindexTracks(
      tracks: [track],
      onProgress: (didExtract) {
        if (didExtract) extractedCount++;
        refreshLibrary();
      },
      onFinish: (_) {},
    );

    expect(extractedCount, 1);
    expect(indexer.tracksInfoList.value.where((e) => e.path == file.path).length, 1);
    final folderTracks = indexer.mainMapFoldersTracks.value.entries.firstWhere((e) => e.key.path == folder.path).value;
    expect(folderTracks.where((e) => e.path == file.path).length, 1);
    final artistTracks = indexer.mainMapArtists.value.values.expand((e) => e).where((e) => e.path == file.path);
    expect(artistTracks.length, 1);
  });
}

/// a second of 8 kHz 16 bit mono silence, readable without tags.
Uint8List _silentWavBytes() {
  const sampleRate = 8000;
  const dataLength = sampleRate * 2;
  final bytes = ByteData(44 + dataLength);
  void ascii(int offset, String text) {
    for (int i = 0; i < text.length; i++) {
      bytes.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);
  return bytes.buffer.asUint8List();
}

class _CountingTrack extends Track {
  static int equalityChecks = 0;

  _CountingTrack(super.path) : super.explicit();

  @override
  bool operator ==(Object other) {
    equalityChecks++;
    return super == other;
  }

  @override
  int get hashCode => path.hashCode;
}
