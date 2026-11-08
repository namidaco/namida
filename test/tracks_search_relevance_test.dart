// by claude
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'package:history_manager/history_manager.dart';

import 'package:namida/base/tracks_search_wrapper.dart';
import 'package:namida/class/track.dart';
import 'package:namida/core/enums.dart';

void main() {
  final tracks = [
    Track.explicit('/music/Theodore Shapiro - Alive (Severance Apple TV+ Soundtrack).mp3'),
    Track.explicit('/music/Bad Apple!!.mp3'),
    Track.explicit('/music/nomico - Bad Apple!! (Remix).mp3'),
    Track.explicit('/music/Lemon.mp3'),
  ];

  final receivePort = ReceivePort();
  tearDownAll(receivePort.close);

  final params = TracksSearchWrapper.generateParams(
    receivePort.sendPort,
    tracks,
    ListensSortedMap<Track>(),
    filters: const [TrackSearchFilter.title, TrackSearchFilter.artist, TrackSearchFilter.filename],
  );
  final wrapper = TracksSearchWrapper.init(params);

  test('one word of the query in the filename is less relevant', () {
    final all = wrapper.filterIndicesAsList('bad apple');
    final relevant = wrapper.filterRelevantIndicesAsList('bad apple');
    expect(all.toSet(), {0, 1, 2});
    expect(relevant.toSet(), {1, 2});
  });

  test('weak matches stay when nothing matches better', () {
    final relevant = wrapper.filterRelevantIndicesAsList('severance');
    expect(relevant, [0]);
  });

  test('no matches', () {
    expect(wrapper.filterRelevantIndicesAsList('zzzz'), isEmpty);
  });
}
