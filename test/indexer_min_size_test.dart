// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/constants.dart';

void main() {
  late Directory dir;
  late SplitArtistGenreConfigsWrapper splitConfig;
  final sep = Platform.pathSeparator;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_indexer_min_size_test');
    AppDirs.USER_DATA = '${dir.path}$sep';
    splitConfig = SplitArtistGenreConfigsWrapper(
      dbPath: '',
      artistsConfig: ArtistsSplitConfig(addFeatArtist: true, separators: const ['&'], separatorsBlacklist: const []),
      genresConfig: GenresSplitConfig(separators: const ['&'], separatorsBlacklist: const []),
      albumConfig: AlbumsSplitConfig(separators: const [';'], separatorsBlacklist: const []),
      generalConfig: GeneralSplitConfig(),
    );
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  String pathOf(bool isNetwork) => isNetwork ? 'http://server/song.mp3' : '${dir.path}${sep}song.mp3';

  Future<TrackExtended?> index(String path, {required int? size, required int minSize}) {
    return Indexer.convertTagToTrack(
      trackPath: path,
      stats: FileStatsAdv(creationDateMS: null, modifiedMS: null, size: size),
      trackInfo: FAudioModel(tags: FTags.edit(path: path, artwork: FArtwork()), durationMS: 180000),
      didExtractArtwork: false,
      tryExtractingFromFilename: true,
      minSize: minSize,
      onMinDurTrigger: () => null,
      onMinSizeTrigger: () => null,
      onError: (err) => throw StateError(err),
      splittersConfigs: splitConfig,
    );
  }

  group('indexing then final pass', () {
    const cases = <({int? size, int minSize, bool isKept})>[
      (size: null, minSize: 0, isKept: true),
      (size: null, minSize: 100, isKept: true),
      (size: 0, minSize: 0, isKept: true),
      (size: 0, minSize: 100, isKept: false),
      (size: 50, minSize: 0, isKept: true),
      (size: 50, minSize: 100, isKept: false),
      (size: 200, minSize: 0, isKept: true),
      (size: 200, minSize: 100, isKept: true),
    ];
    for (final isNetwork in [false, true]) {
      for (final (:size, :minSize, :isKept) in cases) {
        final kind = isNetwork ? 'network' : 'local';
        test('$kind, size $size, min $minSize: ${isKept ? 'kept' : 'skipped'}', () async {
          final trExt = await index(pathOf(isNetwork), size: size, minSize: minSize);
          expect(trExt != null, isKept);
          if (trExt == null) return;
          expect(trExt.size, size ?? 0);
          final isFilteredLater = Indexer.isIndexedTrackFiltered(
            sizeInB: trExt.size,
            durationMS: trExt.durationMS,
            minSize: minSize,
            minDurMS: 0,
          );
          expect(isFilteredLater, false);
        });
      }
    }
  });

  group('final pass', () {
    const cases = <({int sizeInB, int durationMS, int minSize, int minDurMS, bool isFiltered})>[
      (sizeInB: 0, durationMS: 0, minSize: 0, minDurMS: 0, isFiltered: false),
      (sizeInB: 0, durationMS: 0, minSize: 100, minDurMS: 30000, isFiltered: false),
      (sizeInB: 0, durationMS: 60000, minSize: 100, minDurMS: 30000, isFiltered: false),
      (sizeInB: 0, durationMS: 5000, minSize: 100, minDurMS: 30000, isFiltered: true),
      (sizeInB: 50, durationMS: 0, minSize: 100, minDurMS: 30000, isFiltered: true),
      (sizeInB: 50, durationMS: 60000, minSize: 100, minDurMS: 0, isFiltered: true),
      (sizeInB: 50, durationMS: 60000, minSize: 0, minDurMS: 0, isFiltered: false),
      (sizeInB: 200, durationMS: 0, minSize: 100, minDurMS: 30000, isFiltered: false),
      (sizeInB: 200, durationMS: 5000, minSize: 100, minDurMS: 30000, isFiltered: true),
      (sizeInB: 200, durationMS: 5000, minSize: 100, minDurMS: 0, isFiltered: false),
      (sizeInB: 200, durationMS: 60000, minSize: 100, minDurMS: 30000, isFiltered: false),
      (sizeInB: 100, durationMS: 30000, minSize: 100, minDurMS: 30000, isFiltered: false),
    ];
    for (final (:sizeInB, :durationMS, :minSize, :minDurMS, :isFiltered) in cases) {
      test('size $sizeInB, duration $durationMS, min size $minSize, min duration $minDurMS: ${isFiltered ? 'filtered' : 'kept'}', () {
        final res = Indexer.isIndexedTrackFiltered(
          sizeInB: sizeInB,
          durationMS: durationMS,
          minSize: minSize,
          minDurMS: minDurMS,
        );
        expect(res, isFiltered);
      });
    }
  });
}
