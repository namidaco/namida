// by claude
import 'dart:io';

import 'package:flutter_taglib/flutter_taglib.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/tag_rating.dart';
import 'package:namida/class/taglib_res.dart';

void main() {
  final starsMappings = [
    (name: 'popm', fromPercent: TagRating.popmFromPercent, toPercent: TagRating.percentFromPopm, stars: const [1, 64, 128, 196, 255]),
    (name: 'asf', fromPercent: TagRating.asfSharedUserRatingFromPercent, toPercent: TagRating.percentFromAsfSharedUserRating, stars: const [1, 25, 50, 75, 99]),
  ];

  for (final mapping in starsMappings) {
    group('${mapping.name} mapping', () {
      final maxValue = mapping.stars.last;

      test('whole stars use the values other players use', () {
        for (var i = 0; i < mapping.stars.length; i++) {
          final percent = (i + 1) * 20;
          final value = mapping.stars[i];
          expect(mapping.fromPercent(percent), value);
          expect(mapping.toPercent(value), percent);
        }
        expect(mapping.fromPercent(0), 0);
        expect(mapping.toPercent(0), 0);
        expect(mapping.toPercent(maxValue + 50), 100);
      });

      test('every percent from 20 survives a round trip', () {
        for (var percent = 20; percent <= 100; percent++) {
          final value = mapping.fromPercent(percent);
          expect(mapping.toPercent(value), percent, reason: 'percent $percent -> $value');
        }
      });

      test('a rated percent below 20 is never written as unrated', () {
        for (var percent = 1; percent < 20; percent++) {
          expect(mapping.fromPercent(percent), 1);
        }
      });

      test('both directions only go up', () {
        for (var percent = 1; percent <= 100; percent++) {
          expect(mapping.fromPercent(percent), greaterThanOrEqualTo(mapping.fromPercent(percent - 1)));
        }
        for (var value = 1; value <= maxValue; value++) {
          expect(mapping.toPercent(value), greaterThanOrEqualTo(mapping.toPercent(value - 1)));
        }
      });
    });
  }

  group('popularimeters', () {
    test('the first rated frame wins', () {
      const popularimeters = [
        TagLibPopularimeter(email: 'a', rating: 0, counter: 5),
        TagLibPopularimeter(email: 'b', rating: 128),
        TagLibPopularimeter(email: 'c', rating: 255),
      ];
      expect(TagRating.percentFromPopularimeters(popularimeters), 60);
      expect(TagRating.percentFromPopularimeters(const []), isNull);
      expect(TagRating.percentFromPopularimeters(const [TagLibPopularimeter(email: '', rating: 0)]), isNull);
    });
  });

  group('text fields', () {
    test('scale is picked like namida always read it', () {
      expect(TagRating.percentFromText('0.8'), 80);
      expect(TagRating.percentFromText('1.0'), 100);
      expect(TagRating.percentFromText('0.05'), 5);
      expect(TagRating.percentFromText('4'), 80);
      expect(TagRating.percentFromText('1'), 20);
      expect(TagRating.percentFromText('2.7'), 54);
      expect(TagRating.percentFromText('80'), 80);
      expect(TagRating.percentFromText('100'), 100);
      expect(TagRating.percentFromText(' 60 '), 60);
    });

    test('FMPS_RATING is always 0.0-1.0', () {
      expect(TagRating.percentFromText('1', field: TagRating.kFmpsField), 100);
      expect(TagRating.percentFromText('0.6', field: TagRating.kFmpsField), 60);
    });

    test('no rating, garbage and out of range values', () {
      expect(TagRating.percentFromText('0'), isNull);
      expect(TagRating.percentFromText('0.0'), isNull);
      expect(TagRating.percentFromText(''), isNull);
      expect(TagRating.percentFromText('abc'), isNull);
      expect(TagRating.percentFromText('-3'), isNull);
      expect(TagRating.percentFromText('0.001'), isNull);
      expect(TagRating.percentFromText('150'), 100);
    });

    test('RATING and FMPS_RATING come first, then other RATING fields, skipping empty ones', () {
      expect(
        TagRating.percentFromFields({
          'RATING': ['80'],
          'FMPS_RATING': ['0.2'],
        }),
        80,
      );
      expect(
        TagRating.percentFromFields({
          'RATING': ['0'],
          'FMPS_RATING': ['0.2'],
        }),
        20,
      );
      expect(
        TagRating.percentFromFields({
          'RATING WMP': ['3'],
          'FMPS_RATING': ['0.2'],
        }),
        20,
      );
      expect(
        TagRating.percentFromFields({
          'RATING:USER@MAIL': ['0.4'],
          'TITLE': ['x'],
        }),
        40,
      );
      expect(
        TagRating.percentFromFields({
          'RATING': ['abc'],
          'RATING MM': ['100'],
        }),
        100,
      );
      expect(
        TagRating.percentFromFields({
          'FMPS_RATING_AMAROK_SCORE': ['90'],
          '_CUSTOM_RATING': ['10'],
        }),
        isNull,
      );
      expect(TagRating.percentFromFields({'RATING': []}), isNull);
    });
  });

  group('applyToFields', () {
    void apply(int percent, Map<String, List<String>> properties, {TagLibTagType tagType = TagLibTagType.xiphComment}) {
      TagRating.applyToFields(percent: percent, properties: properties, tagType: tagType);
    }

    test('a file with no rating gets RATING as 0-100', () {
      for (final tagType in [TagLibTagType.xiphComment, TagLibTagType.mp4, TagLibTagType.ape, TagLibTagType.unknown]) {
        final properties = {
          'TITLE': ['x'],
        };
        apply(80, properties, tagType: tagType);
        expect(properties, {
          'TITLE': ['x'],
          'RATING': ['80'],
        }, reason: tagType.name);
      }
    });

    test('matroska gets RATING as 0-5, per its spec', () {
      final properties = {
        'TITLE': ['x'],
      };
      apply(80, properties, tagType: TagLibTagType.matroska);
      expect(properties, {
        'TITLE': ['x'],
        'RATING': ['4'],
      });
    });

    test('tags with a dedicated rating field get no RATING', () {
      for (final tagType in [TagLibTagType.id3v2, TagLibTagType.asf, TagLibTagType.mod]) {
        final properties = {
          'TITLE': ['x'],
        };
        apply(80, properties, tagType: tagType);
        expect(properties, {
          'TITLE': ['x'],
        }, reason: tagType.name);
      }
    });

    test('each existing field keeps its scale', () {
      final properties = {
        'RATING': ['100'],
        'FMPS_RATING': ['0.2'],
        'RATING:USER@MAIL': ['0.4'],
        'RATING WMP': ['2'],
        'FMPS_RATING_AMAROK_SCORE': ['90'],
        '_CUSTOM_RATING': ['10'],
      };
      apply(60, properties);
      expect(properties, {
        'RATING': ['60'],
        'FMPS_RATING': ['0.6'],
        'RATING:USER@MAIL': ['0.6'],
        'RATING WMP': ['3'],
        'FMPS_RATING_AMAROK_SCORE': ['90'],
        '_CUSTOM_RATING': ['10'],
      });
    });

    test('an existing other field is enough, no RATING is added', () {
      final properties = {
        'FMPS_RATING': ['0.2'],
      };
      apply(85, properties);
      expect(properties, {
        'FMPS_RATING': ['0.85'],
      });
    });

    test('RATING written as 0.0-1.0 by older namida moves to the tag default', () {
      final properties = {
        'RATING': ['0.8'],
      };
      apply(60, properties);
      expect(properties, {
        'RATING': ['60'],
      });

      final matroska = {
        'RATING': ['0.8'],
      };
      apply(60, matroska, tagType: TagLibTagType.matroska);
      expect(matroska, {
        'RATING': ['3'],
      });

      final garbage = {
        'RATING': ['abc'],
      };
      apply(60, garbage);
      expect(garbage, {
        'RATING': ['60'],
      });
    });

    test('stars never round down to unrated', () {
      final properties = {
        'RATING': ['4'],
      };
      apply(5, properties);
      expect(properties, {
        'RATING': ['1'],
      });
    });

    test('clearing removes every rating field', () {
      final properties = {
        'TITLE': ['x'],
        'RATING': ['80'],
        'FMPS_RATING': ['0.8'],
        'RATING MM': ['4'],
      };
      apply(0, properties);
      expect(properties, {
        'TITLE': ['x'],
      });
    });

    test('clearing a file with no rating adds nothing', () {
      final properties = {
        'TITLE': ['x'],
      };
      apply(0, properties);
      expect(properties, {
        'TITLE': ['x'],
      });
    });

    test('with ID3v2, the 0.0-1.0 RATING from older namida is dropped, other fields stay in sync', () {
      final properties = {
        'RATING': ['0.8'],
        'FMPS_RATING': ['0.8'],
      };
      apply(60, properties, tagType: TagLibTagType.id3v2);
      expect(properties, {
        'FMPS_RATING': ['0.6'],
      });

      final foobar = {
        'RATING': ['4'],
      };
      apply(60, foobar, tagType: TagLibTagType.id3v2);
      expect(foobar, {
        'RATING': ['3'],
      });
    });
  });

  group('popularimetersWith', () {
    test('a new frame holds the rating', () {
      expect(TagRating.popularimetersWith(80, const []), const [TagLibPopularimeter(email: TagRating.kPopularimeterEmail, rating: 196)]);
    });

    test('existing frames keep their email & counter', () {
      const old = [
        TagLibPopularimeter(email: '', rating: 80, counter: 3),
        TagLibPopularimeter(email: 'MusicBee', rating: 255),
      ];
      expect(TagRating.popularimetersWith(60, old), const [
        TagLibPopularimeter(email: '', rating: 128, counter: 3),
        TagLibPopularimeter(email: 'MusicBee', rating: 128),
      ]);
    });

    test('clearing keeps play counts only', () {
      const old = [
        TagLibPopularimeter(email: 'a', rating: 196, counter: 7),
        TagLibPopularimeter(email: 'b', rating: 196),
      ];
      expect(TagRating.popularimetersWith(0, old), const [TagLibPopularimeter(email: 'a', rating: 0, counter: 7)]);
    });
  });

  group('files', () {
    const tagTypes = {
      'mp3': TagLibTagType.id3v2, 'wav': TagLibTagType.id3v2, 'aiff': TagLibTagType.id3v2, 'tta': TagLibTagType.id3v2, //
      'flac': TagLibTagType.xiphComment, 'ogg': TagLibTagType.xiphComment, 'opus': TagLibTagType.xiphComment, //
      'm4a': TagLibTagType.mp4, 'wv': TagLibTagType.ape, 'ape': TagLibTagType.ape, 'mpc': TagLibTagType.ape, //
      'wma': TagLibTagType.asf, 'mka': TagLibTagType.matroska, //
    };

    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('namida_tag_rating'));
    tearDown(() => dir.deleteSync(recursive: true));

    String copyFixture(String ext) {
      final path = '${dir.path}/rating.$ext';
      File('test/fixtures/audio/rating.$ext').copySync(path);
      return path;
    }

    String? write(String path, double? ratingPercentage, {Map<String, List<String>>? newProperties}) {
      return TagLibRes.writeSync(path, newPropertiesMap: newProperties ?? {}, ratingPercentage: ratingPercentage, artwork: null, chapters: null);
    }

    Future<TagLibPropertiesWrapper> read(String path) async {
      final res = await TagLibRes.read(path, extractArtwork: false);
      return res!.properties;
    }

    for (final e in tagTypes.entries) {
      final ext = e.key;
      final tagType = e.value;

      test('$ext: rate, re-rate, edit other tags and clear', () async {
        final path = copyFixture(ext);
        final file = TagLibFile.open(path)!;
        expect(file.getTagType(), tagType);
        file.close();

        final before = await read(path);
        expect(before.computeRatingPercentage(), isNull);

        Future<void> expectRating(int percent) async {
          final info = await read(path);
          expect(info.title, before.title);
          final ratingFields = info.propertiesMap.keys.where(TagRating.isRatingField);
          switch (tagType) {
            case TagLibTagType.id3v2:
              expect(info.computeRatingPercentage(), percent / 100);
              expect(info.popularimeters, [TagLibPopularimeter(email: TagRating.kPopularimeterEmail, rating: TagRating.popmFromPercent(percent))]);
              expect(ratingFields, isEmpty);
            case TagLibTagType.asf:
              expect(info.computeRatingPercentage(), percent / 100);
              expect(info.asfSharedUserRating, TagRating.asfSharedUserRatingFromPercent(percent));
              expect(ratingFields, isEmpty);
            case TagLibTagType.matroska:
              final stars = (percent / 20).round();
              expect(info.computeRatingPercentage(), stars * 20 / 100);
              expect(info.propertiesMap[TagRating.kDefaultField], ['$stars']);
            default:
              expect(info.computeRatingPercentage(), percent / 100);
              expect(info.propertiesMap[TagRating.kDefaultField], ['$percent']);
          }
          if (tagType != TagLibTagType.id3v2) expect(info.popularimeters, isEmpty);
          if (tagType != TagLibTagType.asf) expect(info.asfSharedUserRating, isNull);
        }

        expect(write(path, 0.8), isNull);
        await expectRating(80);

        expect(write(path, 0.55), isNull);
        await expectRating(55);

        expect(
          write(
            path,
            null,
            newProperties: {
              'ALBUM': ['New Album'],
            },
          ),
          isNull,
        );
        await expectRating(55);
        expect((await read(path)).album, 'New Album');

        expect(write(path, 0.0), isNull);
        final cleared = await read(path);
        expect(cleared.computeRatingPercentage(), isNull);
        expect(cleared.popularimeters, isEmpty);
        expect(cleared.asfSharedUserRating ?? 0, 0);
        expect(cleared.propertiesMap.keys.where(TagRating.isRatingField), isEmpty);
        expect(cleared.title, before.title);
      });
    }

    test('wma rated by another player is read', () async {
      final path = copyFixture('wma');
      final file = TagLibFile.open(path)!;
      file.setAsfSharedUserRating(50);
      file.save();
      file.close();
      expect((await read(path)).computeRatingPercentage(), 0.6);
    });

    test('mp3 rated by older namida and another player reads as before, then syncs', () async {
      final path = copyFixture('mp3');
      final file = TagLibFile.open(path)!;
      final properties = file.properties;
      properties['RATING'] = ['0.8'];
      properties['FMPS_PLAYCOUNT'] = ['1'];
      file.setProperties(properties);
      file.setPopularimeters(const [TagLibPopularimeter(email: '', rating: 80, counter: 3)]);
      expect(file.save(), isTrue);
      file.close();

      expect((await read(path)).computeRatingPercentage(), 0.8);

      expect(write(path, 0.8), isNull);
      final info = await read(path);
      expect(info.computeRatingPercentage(), 0.8);
      expect(info.popularimeters, const [TagLibPopularimeter(email: '', rating: 196, counter: 3)]);
      expect(info.propertiesMap['RATING'], isNull);
      expect(info.propertiesMap['FMPS_PLAYCOUNT'], ['1']);
    });

    test('flac rated by older namida becomes 0-100', () async {
      final path = copyFixture('flac');
      final file = TagLibFile.open(path)!;
      final properties = file.properties;
      properties['RATING'] = ['0.8'];
      file.setProperties(properties);
      expect(file.save(), isTrue);
      file.close();

      expect((await read(path)).computeRatingPercentage(), 0.8);

      expect(write(path, 0.6), isNull);
      final info = await read(path);
      expect(info.computeRatingPercentage(), 0.6);
      expect(info.propertiesMap['RATING'], ['60']);
    });

    test('ratings other players wrote are read', () async {
      final mp3 = copyFixture('mp3');
      final mp3File = TagLibFile.open(mp3)!;
      mp3File.setPopularimeters(const [TagLibPopularimeter(email: TagRating.kPopularimeterEmail, rating: 128)]);
      mp3File.save();
      mp3File.close();
      expect((await read(mp3)).computeRatingPercentage(), 0.6);

      final flac = copyFixture('flac');
      final flacFile = TagLibFile.open(flac)!;
      final properties = flacFile.properties;
      properties['FMPS_RATING'] = ['0.4'];
      flacFile.setProperties(properties);
      flacFile.save();
      flacFile.close();
      expect((await read(flac)).computeRatingPercentage(), 0.4);
    });
  });
}
