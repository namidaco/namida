// by claude
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_taglib/flutter_taglib.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/taglib_res.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/text_suggestions_provider.dart';
import 'package:namida/core/constants.dart';

void main() {
  setUpAll(() {
    const releaseTypes = ['album; compilation', 'album', 'single; remix', 'ep;remix', 'single', ''];
    for (int i = 0; i < releaseTypes.length; i++) {
      final path = '/music/$i.mp3';
      Indexer.inst.allTracksMappedByPath[path] = kDummyExtendedTrack.copyWith(
        path: path,
        releaseType: releaseTypes[i],
        generatePathHash: false,
      );
    }
  });

  test('release type suggestions count each value once, no joined combinations', () {
    final values = TextSuggestionsProvider().valuesFor(.releaseType);
    expect(values.values, ['album', 'remix', 'single', 'compilation', 'ep', 'broadcast', 'other']);
  });

  test('release type field suggests the value at the cursor and skips the typed ones', () {
    const source = TextSuggestionsSource.releaseType;
    final separatorsRegex = TextSuggestionsMatcher.buildSeparatorsRegex(source.buildSeparators());
    const typed = TextEditingValue(
      text: 'album; co',
      selection: TextSelection.collapsed(offset: 9),
    );
    final query = TextSuggestionsMatcher.parse(typed, separatorsRegex);
    expect(query.query, 'co');
    expect(query.excludeLowercased, {'album'});

    final applied = TextSuggestionsMatcher.applySuggestion(current: typed, suggestion: 'compilation', separatorsRegex: separatorsRegex);
    expect(applied.text, 'album; compilation');
  });

  group('files', () {
    const extensions = ['mp3', 'wav', 'aiff', 'tta', 'flac', 'ogg', 'opus', 'm4a', 'wv', 'ape', 'mpc', 'wma', 'mka'];
    const taglibReadsReversedExtensions = {'wma'};

    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('namida_release_type'));
    tearDown(() => dir.deleteSync(recursive: true));

    String copyFixture(String ext, List<String> releaseTypes) {
      final path = '${dir.path}/rating.$ext';
      File('test/fixtures/audio/rating.$ext').copySync(path);
      final file = TagLibFile.open(path)!;
      final properties = file.properties;
      properties[TagLibField.releaseType] = releaseTypes;
      file.setProperties(properties);
      expect(file.save(), isTrue);
      file.close();
      return path;
    }

    String? writeReleaseType(String path, String releaseType) {
      final tags = FTags.edit(path: path, artwork: FArtwork(), releaseType: releaseType);
      return TagLibRes.writeSync(path, newPropertiesMap: tags.toTagLibMap(), ratingPercentage: null, artwork: null, chapters: null);
    }

    Future<List<String>?> readStored(String path) async {
      final res = await TagLibRes.read(path, extractArtwork: false);
      return res!.properties.propertiesMap[TagLibField.releaseType];
    }

    for (final ext in extensions) {
      test('$ext: an edit keeps several stored values separate, a single stored value stays single', () async {
        final multiPath = copyFixture(ext, ['album', 'compilation']);
        expect(await readStored(multiPath), hasLength(2));
        expect(writeReleaseType(multiPath, 'album; live'), isNull);
        final expectedValues = taglibReadsReversedExtensions.contains(ext) ? ['live', 'album'] : ['album', 'live'];
        expect(await readStored(multiPath), expectedValues);

        final singlePath = copyFixture(ext, ['album']);
        expect(writeReleaseType(singlePath, 'album; live'), isNull);
        expect(await readStored(singlePath), ['album; live']);
      });
    }
  });
}
