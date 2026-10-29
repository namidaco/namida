// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/base/tracks_search_wrapper.dart';

void main() {
  final albums = [
    (album: 'Pinkerton', albumArtist: 'Weezer'),
    (album: 'The Wall', albumArtist: 'Pink Floyd'),
    (album: 'Wish', albumArtist: 'The Cure'),
    (album: 'Animals', albumArtist: 'Pink Floyd'),
  ];

  final wrapper = KeysSearchWrapper.init(
    albums,
    title: (a) => a.album,
    subtitle: (a) => a.albumArtist,
    weights: (listensCounts: const [0, 0, 0, 0], tracksCounts: const [12, 26, 10, 5]),
    cleanup: true,
  );

  test('exact album artist counts as much as an exact album name', () {
    final byArtist = wrapper.filterRelevantFirst('Pink Floyd');
    final byName = wrapper.filterRelevantFirst('The Wall');
    expect(byArtist.bestScore, byName.bestScore);
  });

  test('relevant matches come first, the rest keep their order after them', () {
    final r = wrapper.filterRelevantFirst('Pink Floyd');
    expect(r.relevantCount, 2);
    expect(r.results.take(2), [albums[1], albums[3]]);
    expect(r.results.skip(2), [albums[0]]);
    expect(r.results.toSet(), wrapper.filter('Pink Floyd').toSet());
  });

  test('no matches', () {
    final r = wrapper.filterRelevantFirst('zzzz');
    expect(r.results, isEmpty);
    expect(r.relevantCount, 0);
    expect(r.bestScore, 0);
  });
}
