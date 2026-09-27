// by claude
//
// loads real settings files written by the old full-dump format and checks that every key
// decodes to what the old loader produced (`expected/`), survives a save/reload round trip,
// and that a corrupted value only affects its own key.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nampack/nampack.dart';

import 'package:namida/base/settings_file_writer.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';

final _fixturesDir = Directory('test/fixtures/settings');

const _junkValues = <dynamic>[
  null,
  'x',
  1,
  1.5,
  true,
  [],
  {},
  [1, 'a'],
  {'k': 1},
];

/// old nullable fields that now resolve to a default: the old dump wrote null, the new value is the default.
const _resolvedNullables = <String, Set<String>>{
  'namida_settings.json': {'extensionsBlacklist', 'backupItemslist_v2'},
  'namida_settings_youtube.json': {'downloadParallelCount_v2', 'downloadThreadsCount', 'personalizedRelatedVideos'},
};

/// keys whose runtime value is derived from another key after load.
const _dependents = <String, Set<String>>{
  'autoLibraryTab': {'selectedLibraryTab'},
  'staticLibraryTab': {'selectedLibraryTab'},
  'rememberAudioOnly': {'isAudioOnlyMode'},
};

void main() {
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_settings_compat');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  final writers = <String, ({SettingsFileWriter writer, List<RxBase<Object?>> keys})>{
    'namida_settings.json': (writer: settings, keys: settings.allKeys),
    'namida_settings_eq.json': (writer: settings.equalizer, keys: settings.equalizer.allKeys),
    'namida_settings_player.json': (writer: settings.player, keys: settings.player.allKeys),
    'namida_settings_youtube.json': (writer: settings.youtube, keys: settings.youtube.allKeys),
    'namida_settings_extra.json': (writer: settings.extra, keys: settings.extra.allKeys),
    'namida_settings_party.json': (writer: settings.party, keys: settings.party.allKeys),
    'namida_settings_sync.json': (writer: settings.sync, keys: settings.sync.allKeys),
    'namida_settings_tutorial.json': (writer: settings.tutorial, keys: settings.tutorial.allKeys),
    'namida_settings_shortcuts.json': (writer: settings.shortcuts, keys: settings.shortcuts.allKeys),
  };

  Map<String, dynamic> fullJson(SettingsFileWriter writer) => writer.debugFullJson();

  Map<String, dynamic> readJson(File file) => jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  test('generated debug keys list is complete', () {
    final keyRegex = RegExp(r'^  late final \w+\s*=\s*_key\w*\s*[<(]', multiLine: true);
    int declared = 0;
    for (final file in Directory('lib/controller').listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.startsWith('settings') || name == 'settings.debug_keys.dart') continue;
      declared += keyRegex.allMatches(file.readAsStringSync()).length;
    }
    int listed = 0;
    for (final e in writers.values) {
      listed += e.keys.length;
    }
    expect(listed, declared, reason: 'run scripts/gen_settings_debug_keys.py');
  });

  for (final fixtureSet in ['android', 'desktop']) {
    group(fixtureSet, () {
      final setDir = Directory('${_fixturesDir.path}/$fixtureSet');
      final expectedDir = Directory('${setDir.path}/expected');

      Future<void> loadFixtures() async {
        for (final f in dir.listSync().whereType<File>()) {
          f.deleteSync();
        }
        for (final f in setDir.listSync().whereType<File>()) {
          f.copySync('${dir.path}${Platform.pathSeparator}${f.uri.pathSegments.last}');
        }
        await settings.prepareAllSettings();
        // -- legacy files rewrite themselves once, let those writes land before the tests touch the files
        await Future.delayed(const Duration(milliseconds: 2300));
      }

      setUpAll(loadFixtures);

      for (final expectedFile in expectedDir.listSync().whereType<File>()) {
        final name = expectedFile.uri.pathSegments.last;
        final entry = writers[name]!;
        final writer = entry.writer;
        final expected = readJson(expectedFile);

        test('$name decodes like the old loader', () {
          final full = fullJson(writer);
          final resolvedNullables = _resolvedNullables[name] ?? const {};
          for (final e in expected.entries) {
            expect(full.containsKey(e.key), true, reason: 'key ${e.key} is gone');
            if (e.value == null && resolvedNullables.contains(e.key)) continue;
            expect(full[e.key], equals(e.value), reason: e.key);
          }
          expect(writer.buildJson()['_legacy'], null, reason: 'every legacy key should be consumed after all keys loaded');
        });

        test('$name survives a save and reload round trip', () async {
          final full = fullJson(writer);
          File(writer.filePath).writeAsStringSync(jsonEncode(writer.buildJson()));
          await writer.prepareSettingsFile();
          expect(fullJson(writer), equals(full));
        });

        test('$name tolerates a corrupted value per key', () async {
          final migrated = Map<String, dynamic>.of(writer.buildJson());
          final full = fullJson(writer);
          final file = File(writer.filePath);
          for (final key in expected.keys) {
            for (final junk in _junkValues) {
              final corrupted = Map<String, dynamic>.of(migrated);
              corrupted[key] = junk;
              file.writeAsStringSync(jsonEncode(corrupted));
              await writer.prepareSettingsFile();
              final loaded = fullJson(writer);
              final skip = _dependents[key] ?? const {};
              for (final e in full.entries) {
                if (e.key == key || skip.contains(e.key)) continue;
                expect(loaded[e.key], equals(e.value), reason: '$key = $junk broke ${e.key}');
              }
            }
          }
          file.writeAsStringSync(jsonEncode(migrated));
          await writer.prepareSettingsFile();
          expect(fullJson(writer), equals(full));
        });
      }
    });
  }
}
