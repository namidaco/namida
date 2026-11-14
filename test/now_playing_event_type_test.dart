// by claude
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/controller/now_playing_broadcaster.dart';
import 'package:namida/core/enums.dart';

void main() {
  MediaItem mediaOf({
    String id = '/music/a.m4a',
    String title = 'title',
    Duration? duration = const Duration(minutes: 3),
    bool? isFavourite = false,
    int queueIndex = 0,
    Uri? artUri,
  }) {
    final rating = isFavourite == null ? null : Rating.newHeartRating(isFavourite);
    return MediaItem(
      id: id,
      title: title,
      artist: 'artist',
      album: 'album',
      genre: 'genre',
      duration: duration,
      rating: rating,
      artUri: artUri,
      extras: {
        NowPlayingExtras.path: id,
        NowPlayingExtras.queueIndex: queueIndex,
        NowPlayingExtras.queueLength: 10,
        '${NowPlayingExtras.tagIdPrefix}MUSICBRAINZ_TRACKID': 'abc',
      },
    );
  }

  WebhookEvent? typeOf(MediaItem? previous, MediaItem media) => NowPlayingBroadcaster.getItemEventType(previous, media);

  test('a new item is a track change', () {
    expect(typeOf(null, mediaOf()), WebhookEvent.trackChanged);
    expect(typeOf(mediaOf(), mediaOf(id: '/music/b.m4a')), WebhookEvent.trackChanged);
    expect(typeOf(mediaOf(id: 'dQw4w9WgXcQ'), mediaOf(id: 'jNQXAC9IVRw')), WebhookEvent.trackChanged);
  });

  test('the same item published again with nothing new sends nothing', () {
    expect(typeOf(mediaOf(), mediaOf()), isNull);
    expect(typeOf(mediaOf(), mediaOf(artUri: Uri.file('/art.png'))), isNull);
    expect(typeOf(mediaOf(isFavourite: true), mediaOf(isFavourite: true)), isNull);
    expect(typeOf(mediaOf(isFavourite: null), mediaOf(isFavourite: null)), isNull);
  });

  test('favourite toggles in both directions', () {
    expect(typeOf(mediaOf(isFavourite: false), mediaOf(isFavourite: true)), WebhookEvent.favouriteChanged);
    expect(typeOf(mediaOf(isFavourite: true), mediaOf(isFavourite: false)), WebhookEvent.favouriteChanged);
    expect(typeOf(mediaOf(isFavourite: true), mediaOf(isFavourite: false, title: 'new')), WebhookEvent.favouriteChanged);
  });

  test('info arriving later is sent again as a track change', () {
    expect(typeOf(mediaOf(title: ''), mediaOf(title: 'real title')), WebhookEvent.trackChanged);
    expect(typeOf(mediaOf(duration: Duration.zero), mediaOf()), WebhookEvent.trackChanged);
    expect(typeOf(mediaOf(duration: null), mediaOf()), WebhookEvent.trackChanged);
    expect(typeOf(mediaOf(queueIndex: 0), mediaOf(queueIndex: 1)), WebhookEvent.trackChanged);
  });

  test('a remote love is a heart, a remote unlove is an unrated heart', () {
    expect(const Rating.newHeartRating(true).hasHeart(), isTrue);
    expect(const Rating.newUnratedRating(RatingStyle.heart).hasHeart(), isFalse);
  });
}
