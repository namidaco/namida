// by claude
import 'dart:io';

import 'package:flutter_taglib/flutter_taglib.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/taglib_res.dart';

void main() {
  const artistId1 = '11111111-1111-1111-1111-111111111111';
  const artistId2 = '22222222-2222-2222-2222-222222222222';
  const albumArtistId = '33333333-3333-3333-3333-333333333333';
  const recordingId = '44444444-4444-4444-4444-444444444444';

  group('picking', () {
    test('artist ids keep every value, other ids keep the first', () {
      final picked = FTags.pickExtraTags({
        TagLibField.MUSICBRAINZ_ARTISTID: ['', artistId1, artistId2],
        TagLibField.MUSICBRAINZ_ALBUMARTISTID: [albumArtistId],
        TagLibField.MUSICBRAINZ_TRACKID: ['', recordingId, 'other'],
        TagLibField.isrc: ['ISRC1', 'ISRC2'],
      });
      expect(picked, {
        TagLibField.MUSICBRAINZ_ARTISTID: '$artistId1; $artistId2',
        TagLibField.MUSICBRAINZ_ALBUMARTISTID: albumArtistId,
        TagLibField.MUSICBRAINZ_TRACKID: recordingId,
        TagLibField.isrc: 'ISRC1',
      });
    });

    test('a value stored already joined is kept as stored', () {
      final picked = FTags.pickExtraTags({
        TagLibField.MUSICBRAINZ_ARTISTID: ['$artistId1/$artistId2'],
      });
      expect(picked, {TagLibField.MUSICBRAINZ_ARTISTID: '$artistId1/$artistId2'});
    });

    test('empty values are not tag ids', () {
      final picked = FTags.pickExtraTags({
        TagLibField.MUSICBRAINZ_ARTISTID: ['', ''],
        TagLibField.MUSICBRAINZ_TRACKID: [''],
        TagLibField.MUSICBRAINZ_ALBUMARTISTID: [],
      });
      expect(picked, isNull);
    });
  });

  group('files', () {
    const extensions = ['mp3', 'wav', 'aiff', 'tta', 'flac', 'ogg', 'opus', 'm4a', 'wv', 'ape', 'mpc', 'wma', 'mka'];
    const taglibReadsReversedExtensions = {'wma'};

    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('namida_extra_tags'));
    tearDown(() => dir.deleteSync(recursive: true));

    for (final ext in extensions) {
      test('$ext: every stored artist id is read', () async {
        final path = '${dir.path}/rating.$ext';
        File('test/fixtures/audio/rating.$ext').copySync(path);
        final file = TagLibFile.open(path)!;
        final properties = file.properties;
        properties[TagLibField.MUSICBRAINZ_ARTISTID] = [artistId1, artistId2];
        properties[TagLibField.MUSICBRAINZ_ALBUMARTISTID] = [albumArtistId];
        properties[TagLibField.MUSICBRAINZ_TRACKID] = [recordingId];
        file.setProperties(properties);
        expect(file.save(), isTrue);
        file.close();

        final res = await TagLibRes.read(path, extractArtwork: false);
        final readArtistIds = res!.properties.propertiesMap[TagLibField.MUSICBRAINZ_ARTISTID];
        final extraTags = res.toFAudioModel(artwork: null).tags.extraTags;
        final expectedArtistIds = taglibReadsReversedExtensions.contains(ext) ? [artistId2, artistId1] : [artistId1, artistId2];
        expect(readArtistIds, expectedArtistIds);
        expect(extraTags, {
          TagLibField.MUSICBRAINZ_ARTISTID: expectedArtistIds.join('; '),
          TagLibField.MUSICBRAINZ_ALBUMARTISTID: albumArtistId,
          TagLibField.MUSICBRAINZ_TRACKID: recordingId,
        });
      });
    }
  });
}
