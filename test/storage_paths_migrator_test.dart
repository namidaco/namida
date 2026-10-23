// by claude
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:namida/controller/platform/namida_storage/namida_storage.dart';

void main() {
  const oldRoot = '/var/mobile/Containers/Data/Application/11111111-1111-1111-1111-111111111111';
  const newRoot = '/var/mobile/Containers/Data/Application/22222222-2222-2222-2222-222222222222';
  const oldPicked = '/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Music';
  const newPicked = '/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Music Library';

  const containerMoves = {
    oldRoot: newRoot,
    '/private$oldRoot': newRoot,
  };

  String? rewrite(String text, [Map<String, String> moves = containerMoves]) => NamidaStorage.debugRewriteMovedPaths(text, moves);

  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('namida_paths_migrator_');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  ({int changedCount, List<String> failedFiles}) migrate([Map<String, String> moves = containerMoves, Set<String> skippedDirectories = const {}]) {
    return NamidaStorage.debugMigrateMovedPaths(dir.path, moves, skippedDirectories: skippedDirectories);
  }

  File writeText(String relativePath, String text) {
    final file = File(p.join(dir.path, relativePath))..createSync(recursive: true);
    file.writeAsStringSync(text);
    return file;
  }

  Database createKeyValueDb(String relativePath) {
    final path = p.join(dir.path, relativePath);
    Directory(p.dirname(path)).createSync(recursive: true);
    final db = sqlite3.open(path);
    db.execute('CREATE TABLE IF NOT EXISTS t (key TEXT NOT NULL UNIQUE, value TEXT, PRIMARY KEY (key))');
    return db;
  }

  Map<String, String?> readKeyValueDb(String relativePath) {
    final db = sqlite3.open(p.join(dir.path, relativePath));
    try {
      return {for (final row in db.select('SELECT key, value FROM t')) row['key'] as String: row['value'] as String?};
    } finally {
      db.close();
    }
  }

  group('rewriteText', () {
    test('rewrites every occurrence of the old prefix', () {
      final text = jsonEncode({
        'a': '$oldRoot/Documents/Music/a.mp3',
        'list': ['$oldRoot/Documents/b.flac', '/somewhere/else/c.mp3'],
      });
      final rewritten = rewrite(text)!;
      expect(rewritten, isNot(contains(oldRoot)));
      final decoded = jsonDecode(rewritten) as Map<String, dynamic>;
      expect(decoded['a'], '$newRoot/Documents/Music/a.mp3');
      expect(decoded['list'], ['$newRoot/Documents/b.flac', '/somewhere/else/c.mp3']);
    });

    test('returns null when nothing matches', () {
      expect(rewrite('{"a": "/var/mobile/other/x.mp3"}'), isNull);
    });

    test('a prefix contained in a longer one leaves no leftover of the longer one', () {
      const text = '"/private$oldRoot/Documents/a.mp3" "$oldRoot/Documents/b.mp3"';
      expect(rewrite(text), '"$newRoot/Documents/a.mp3" "$newRoot/Documents/b.mp3"');
    });

    test('moves to the same place are dropped', () {
      expect(rewrite(oldRoot, {oldRoot: oldRoot}), isNull);
      expect(migrate({oldRoot: oldRoot}).changedCount, 0);
    });

    test('empty, relative and root moves are dropped', () {
      const text = '"/a/b.mp3" "c.mp3"';
      expect(rewrite(text, {'': newRoot}), isNull);
      expect(rewrite(text, {'/': newRoot}), isNull);
      expect(rewrite(text, {'a': newRoot}), isNull);
      expect(rewrite(text, {'/a': ''}), isNull);
      expect(rewrite(text, {'/a/': newRoot}), isNull);
    });

    test('several moves apply together', () {
      const text = '$oldRoot/Documents/a.mp3\n$oldPicked/b.mp3\n';
      expect(rewrite(text, {oldRoot: newRoot, oldPicked: newPicked}), '$newRoot/Documents/a.mp3\n$newPicked/b.mp3\n');
    });

    test('only whole folder names match', () {
      const text = '"/x/Music/a.mp3" "/x/Music Videos/b.mp4" "/x/Musicals/c.mp3" "/x/Music" "/x/Music\\"" "/x/Music\r\n';
      expect(
        rewrite(text, {'/x/Music': '/x/Songs'}),
        '"/x/Songs/a.mp3" "/x/Music Videos/b.mp4" "/x/Musicals/c.mp3" "/x/Songs" "/x/Songs\\"" "/x/Songs\r\n',
      );
    });

    test('a move into a longer name is safe to run twice', () {
      const text = '"$oldPicked/a.mp3"';
      final once = rewrite(text, {oldPicked: newPicked})!;
      expect(once, '"$newPicked/a.mp3"');
      expect(rewrite(once, {oldPicked: newPicked}), isNull);
    });

    test('a moved folder is never moved again by another move', () {
      expect(rewrite('"/a/x.mp3" "/b/y.mp3"', {'/a': '/b', '/b': '/c'}), '"/b/x.mp3" "/c/y.mp3"');
    });
  });

  group('migrateDirectorySync', () {
    test('rewrites json & m3u files, nested too, and leaves other files alone', () {
      final settings = writeText(
        'namida_settings.json',
        jsonEncode({
          'directoriesToScan': ['$oldRoot/Documents'],
        }),
      );
      final history = writeText(
        'History/1700000000000.json',
        jsonEncode([
          {'track': '$oldRoot/Documents/a.mp3'},
        ]),
      );
      final m3u = writeText('M3U Backup/pl.m3u', '#EXTM3U\n$oldRoot/Documents/a.mp3\n');
      final lyrics = writeText('Lyrics/x.txt', 'lyrics mentioning $oldRoot');
      final noExtension = writeText('login/secret', '$oldRoot/x');
      final untouched = writeText('Playlists/other.json', jsonEncode({'a': '/elsewhere/a.mp3'}));
      final untouchedBefore = untouched.readAsStringSync();

      final result = migrate();

      expect(result.changedCount, 3);
      expect(result.failedFiles, isEmpty);
      expect(settings.readAsStringSync(), contains('$newRoot/Documents'));
      expect(history.readAsStringSync(), contains('$newRoot/Documents/a.mp3'));
      expect(m3u.readAsStringSync(), '#EXTM3U\n$newRoot/Documents/a.mp3\n');
      expect(lyrics.readAsStringSync(), contains(oldRoot));
      expect(noExtension.readAsStringSync(), contains(oldRoot));
      expect(untouched.readAsStringSync(), untouchedBefore);
      final leftovers = dir.listSync(recursive: true).whereType<File>().where((e) => e.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);
    });

    test('skipped directories are never read', () {
      final artworksDirectory = '${p.join(dir.path, 'Artworks')}${Platform.pathSeparator}';
      final skipped = writeText('Artworks/a.json', '"$oldRoot/Documents/a.mp3"');
      final nestedSkipped = writeText('Artworks/nested/b.json', '"$oldRoot/Documents/b.mp3"');
      final migrated = writeText('Artworks Albums/c.json', '"$oldRoot/Documents/c.mp3"');

      final result = migrate(containerMoves, {artworksDirectory});

      expect(result.changedCount, 1);
      expect(skipped.readAsStringSync(), contains(oldRoot));
      expect(nestedSkipped.readAsStringSync(), contains(oldRoot));
      expect(migrated.readAsStringSync(), contains(newRoot));
    });

    test('rewrites keys & values in sqlite dbs, text columns only', () {
      final db = createKeyValueDb('tracks.db');
      db.execute('INSERT INTO t (key, value) VALUES (?, ?)', [
        '$oldRoot/Documents/a.mp3',
        jsonEncode({'path': '$oldRoot/Documents/a.mp3', 'title': 'a'}),
      ]);
      db.execute('INSERT INTO t (key, value) VALUES (?, ?)', [
        '/elsewhere/b.mp3',
        jsonEncode({'title': 'b'}),
      ]);
      db.execute('CREATE TABLE typed (key TEXT NOT NULL UNIQUE, path TEXT, count INTEGER, PRIMARY KEY (key))');
      db.execute('INSERT INTO typed (key, path, count) VALUES (?, ?, ?)', ['k', '$oldRoot/Documents/c.mp3', 7]);
      db.close();

      expect(migrate().changedCount, 1);

      final rows = readKeyValueDb('tracks.db');
      expect(rows.keys, containsAll(['$newRoot/Documents/a.mp3', '/elsewhere/b.mp3']));
      expect(rows.keys, isNot(contains('$oldRoot/Documents/a.mp3')));
      expect(rows['$newRoot/Documents/a.mp3'], contains('$newRoot/Documents/a.mp3'));

      final check = sqlite3.open(p.join(dir.path, 'tracks.db'));
      final typed = check.select('SELECT path, count FROM typed').single;
      check.close();
      expect(typed['path'], '$newRoot/Documents/c.mp3');
      expect(typed['count'], 7);
    });

    test('db rows only match whole folder names', () {
      final db = createKeyValueDb('tracks.db');
      db.execute('INSERT INTO t (key, value) VALUES (?, ?)', ['/x/Music Videos/a.mp4', '/x/Music Videos/a.mp4']);
      db.execute('INSERT INTO t (key, value) VALUES (?, ?)', ['/x/Music/b.mp3', '/x/Music/b.mp3']);
      db.close();

      expect(migrate({'/x/Music': '/x/Songs'}).changedCount, 1);
      expect(readKeyValueDb('tracks.db'), {
        '/x/Music Videos/a.mp4': '/x/Music Videos/a.mp4',
        '/x/Songs/b.mp3': '/x/Songs/b.mp3',
      });
      expect(migrate({'/x/Music': '/x/Songs'}).changedCount, 0);
    });

    test('swapped folder names keep every row', () {
      const moves = {'/x/Music': '/x/Music2', '/x/Music New': '/x/Music'};
      final db = createKeyValueDb('tracks_stats.db');
      db.execute('INSERT INTO t (key, value) VALUES (?, ?)', ['/x/Music New/a.mp3', 'stats of new']);
      db.execute('INSERT INTO t (key, value) VALUES (?, ?)', ['/x/Music/a.mp3', 'stats of old']);
      db.close();
      final settings = writeText('namida_settings.json', '["/x/Music/a.mp3", "/x/Music New/a.mp3"]');

      expect(migrate(moves).changedCount, 2);
      expect(readKeyValueDb('tracks_stats.db'), {
        '/x/Music/a.mp3': 'stats of new',
        '/x/Music2/a.mp3': 'stats of old',
      });
      expect(settings.readAsStringSync(), '["/x/Music2/a.mp3", "/x/Music/a.mp3"]');
    });

    test('the moved row replaces one already at the new path', () {
      final db = createKeyValueDb('tracks_stats.db');
      db.execute('INSERT INTO t (key, value) VALUES (?, ?)', ['$oldRoot/Documents/a.mp3', 'with stats']);
      db.execute('INSERT INTO t (key, value) VALUES (?, ?)', ['$newRoot/Documents/a.mp3', 'reindexed']);
      db.close();

      migrate();

      expect(readKeyValueDb('tracks_stats.db'), {'$newRoot/Documents/a.mp3': 'with stats'});
    });

    test('an unreadable file is reported without stopping the others', () {
      final brokenPath = p.join(dir.path, 'broken.db');
      File(brokenPath).writeAsBytesSync(List.generate(4096, (i) => i % 251));
      final settings = writeText('namida_settings.json', '"$oldRoot/Documents"');

      final result = migrate();

      expect(result.changedCount, 1);
      expect(result.failedFiles, [brokenPath]);
      expect(settings.readAsStringSync(), '"$newRoot/Documents"');
    });

    test('running again changes nothing', () {
      writeText('namida_settings.json', '"$oldRoot/Documents"');
      final db = createKeyValueDb('tracks.db');
      db.execute('INSERT INTO t (key, value) VALUES (?, ?)', ['$oldRoot/a.mp3', '$oldRoot/a.mp3']);
      db.close();

      expect(migrate().changedCount, 2);
      expect(migrate().changedCount, 0);
    });

    test('a missing directory changes nothing', () {
      final result = NamidaStorage.debugMigrateMovedPaths(p.join(dir.path, 'missing'), containerMoves);
      expect(result.changedCount, 0);
      expect(result.failedFiles, isEmpty);
    });
  });
}
