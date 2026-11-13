// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/media_info.dart';
import 'package:namida/class/taglib_res.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/namida_converter_ext.dart';

void main() {
  test('tag values', () {
    expect(ExplicitStatus.fromTagValue('1'), ExplicitStatus.explicit);
    expect(ExplicitStatus.fromTagValue('4'), ExplicitStatus.explicit);
    expect(ExplicitStatus.fromTagValue(' 2 '), ExplicitStatus.clean);
    for (final value in [null, '', '0', '3', 'explicit']) {
      expect(ExplicitStatus.fromTagValue(value), isNull, reason: '$value');
    }
    for (final status in ExplicitStatus.values) {
      expect(ExplicitStatus.fromTagValue(status.toTagValue()), status);
    }
    expect(ExplicitStatus.fromOpenSubsonic('explicit'), ExplicitStatus.explicit);
    expect(ExplicitStatus.fromOpenSubsonic('clean'), ExplicitStatus.clean);
    expect(ExplicitStatus.fromOpenSubsonic(''), isNull);
  });

  test('edits map to tag values, empty removes the tag', () {
    Map<String, List<String>> mapOf(String? itunesAdvisory) => FTags.edit(path: '', artwork: FArtwork(), itunesAdvisory: itunesAdvisory).toTagLibMap();
    expect(mapOf('1')[TagLibField.itunesAdvisory], ['1']);
    expect(mapOf('')[TagLibField.itunesAdvisory], isEmpty);
    expect(mapOf(null).containsKey(TagLibField.itunesAdvisory), isFalse);
  });

  test('ffprobe tags: mp4 lowercase rating is the rtng atom, freeform RATING stays a rating', () {
    FTags tagsOf(Map<String, dynamic> formatTags) {
      final info = MediaInfo.fromMap({
        'path': '',
        'format': {'tags': formatTags},
      });
      return info.toFAudioModel(artwork: null).tags;
    }

    const mp4Brand = {'major_brand': 'M4A '};
    final mp4Rtng = tagsOf({...mp4Brand, 'rating': '1'});
    expect(mp4Rtng.itunesAdvisory, '1');
    expect(mp4Rtng.ratingPercentage, isNull);

    final mp4Freeform = tagsOf({...mp4Brand, 'RATING': '80', 'ITUNESADVISORY': '2'});
    expect(mp4Freeform.itunesAdvisory, '2');
    expect(mp4Freeform.ratingPercentage, 0.8);

    final mp3 = tagsOf({'rating': '80', 'ITUNESADVISORY': '1'});
    expect(mp3.itunesAdvisory, '1');
    expect(mp3.ratingPercentage, 0.8);

    final flacLowercase = tagsOf({'itunesadvisory': '2'});
    expect(flacLowercase.itunesAdvisory, '2');
    expect(flacLowercase.ratingPercentage, isNull);
  });

  group('files', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('namida_explicit'));
    tearDown(() => dir.deleteSync(recursive: true));

    String? write(String path, String itunesAdvisory) {
      final tags = FTags.edit(path: path, artwork: FArtwork(), itunesAdvisory: itunesAdvisory);
      return TagLibRes.writeSync(path, newPropertiesMap: tags.toTagLibMap(), ratingPercentage: null, artwork: null, chapters: null);
    }

    Future<FTags> read(String path) async {
      final res = await TagLibRes.read(path, extractArtwork: false);
      return res!.toFAudioModel(artwork: null).tags;
    }

    for (final ext in ['mp3', 'wav', 'aiff', 'tta', 'flac', 'ogg', 'opus', 'm4a', 'wv', 'ape', 'mpc', 'mka']) {
      test('$ext: write, change, keep through other edits and clear', () async {
        final path = '${dir.path}/explicit.$ext';
        File('test/fixtures/audio/rating.$ext').copySync(path);
        final title = (await read(path)).title;

        expect(write(path, '1'), isNull);
        expect((await read(path)).itunesAdvisory, '1');

        expect(write(path, '2'), isNull);
        expect((await read(path)).itunesAdvisory, '2');

        final otherEdit = FTags.edit(path: path, artwork: FArtwork(), comment: 'edited');
        expect(TagLibRes.writeSync(path, newPropertiesMap: otherEdit.toTagLibMap(), ratingPercentage: null, artwork: null, chapters: null), isNull);
        final afterOtherEdit = await read(path);
        expect(afterOtherEdit.itunesAdvisory, '2');
        expect(afterOtherEdit.title, title);

        expect(write(path, ''), isNull);
        expect((await read(path)).itunesAdvisory, isNull);
      });
    }

    test('wma has no field for it', () async {
      final path = '${dir.path}/explicit.wma';
      File('test/fixtures/audio/rating.wma').copySync(path);
      write(path, '1');
      expect((await read(path)).itunesAdvisory, isNull);
    });
  });
}
