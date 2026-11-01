// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/core/constants.dart';

void main() {
  final tagged = kDummyExtendedTrack.copyWith(
    path: '/storage/Music/modus/08 Stay With You.flac',
    title: '  Stay With You ',
    originalArtist: 'MODUS',
    originalAlbum: 'REGNUM ULTRA',
    albumArtist: 'modus',
    originalGenre: 'Synthwave',
    originalMood: 'Calm',
    composer: 'Comp',
    label: 'Label',
    language: 'eng',
    trackNo: 8,
    trackTo: 12,
    discNo: 1,
    discTo: 2,
    year: 2026,
    durationMS: 245678,
    isVideo: false,
    generatePathHash: false,
  );
  final untagged = kDummyExtendedTrack.copyWith(
    path: r'C:\Videos\clip.mp4',
    title: 'Ünïcödé 日本 ♪',
    originalArtist: '',
    originalAlbum: '',
    albumArtist: '',
    originalGenre: '',
    originalMood: '',
    composer: '',
    label: '',
    language: '',
    trackNo: 0,
    trackTo: 0,
    discNo: 0,
    discTo: 0,
    year: 0,
    durationMS: 999,
    isVideo: true,
    generatePathHash: false,
  );

  // -- made by older versions, other devices running them still send these
  const taggedFull = 294403383007665;
  const taggedCore = 1795730624976528;
  const untaggedFull = 3385421931935331;
  const untaggedCore = 8253176874157555;

  setUp(() => Indexer.inst.allTracksMappedByPath = {tagged.path: tagged, untagged.path: untagged});

  test('hashes stay the same as older versions', () async {
    expect(SyncTrackFingerprint.coreOf(tagged), taggedCore);
    expect(SyncTrackFingerprint.coreOf(untagged), untaggedCore);

    final entries = await SyncPathResolver.buildLocalEntries();
    expect(entries, [
      [tagged.path, taggedFull, taggedCore],
      [untagged.path, untaggedFull, untaggedCore],
    ]);
  });

  test('the local index matches tracks by their hashes and is reused until the library changes', () async {
    final core = await SyncPathResolver.localCoreIndex();
    expect(core, {taggedCore: tagged.asTrack(), untaggedCore: untagged.asTrack()});
    expect(core[untaggedCore], isA<Video>());
    expect(identical(await SyncPathResolver.localCoreIndex(), core), true);

    Indexer.inst.allTracksMappedByPath = {tagged.path: tagged};
    final rebuilt = await SyncPathResolver.localCoreIndex();
    expect(rebuilt, {taggedCore: tagged.asTrack()});
  });
}
