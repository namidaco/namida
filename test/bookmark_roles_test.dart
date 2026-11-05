// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/bookmarks_controller.dart';

void main() {
  const start = PlayableBookmarkRole.start;
  const end = PlayableBookmarkRole.end;

  PlayableBookmark bookmarkAt(int positionMS, {PlayableBookmarkRole? role, String? title}) => PlayableBookmark(positionMS: positionMS, title: title, role: role);

  Map<int, PlayableBookmarkRole?> rolesOf(List<PlayableBookmark>? bookmarks) => {for (final e in bookmarks!) e.positionMS: e.role};

  group('storage', () {
    test('role round trips by name', () {
      final json = bookmarkAt(5000, role: end, title: 'outro').toJson();
      expect(json, {'p': 5000, 't': 'outro', 'r': 'end'});
      final parsed = PlayableBookmark.fromJson(json);
      expect(parsed.positionMS, 5000);
      expect(parsed.title, 'outro');
      expect(parsed.role, end);
    });

    test('bookmarks without a role keep the old shape', () {
      expect(bookmarkAt(5000).toJson(), {'p': 5000});
      expect(PlayableBookmark.fromJson({'p': 5000, 't': 'x'}).role, isNull);
    });

    test('an unknown role reads as none', () {
      expect(PlayableBookmark.fromJson({'p': 5000, 'r': 'middle'}).role, isNull);
    });

    test('stats keep the roles', () {
      final stats = PlayableItemStats.fromJson({
        'bm': [
          {'p': 2000, 'r': 'start'},
          {'p': 9000},
          {'p': 50000, 'r': 'end'},
        ],
      });
      expect(PlayableBookmark.findRolePositionMS(stats.bookmarks, start), 2000);
      expect(PlayableBookmark.findRolePositionMS(stats.bookmarks, end), 50000);
      final reparsed = PlayableItemStats.fromJson(stats.toJson()!);
      expect(rolesOf(reparsed.bookmarks), {2000: start, 9000: null, 50000: end});
    });

    test('no bookmarks or no roles find nothing', () {
      expect(PlayableBookmark.findRolePositionMS(null, start), isNull);
      expect(PlayableBookmark.findRolePositionMS([bookmarkAt(1000)], start), isNull);
    });
  });

  group('toggling roles', () {
    final plain = [bookmarkAt(10000), bookmarkAt(20000), bookmarkAt(30000)];

    test('sets and clears a role', () {
      final withStart = BookmarksController.toggledRole(plain, 10000, start);
      expect(rolesOf(withStart), {10000: start, 20000: null, 30000: null});
      final cleared = BookmarksController.toggledRole(withStart!, 10000, start);
      expect(rolesOf(cleared), {10000: null, 20000: null, 30000: null});
    });

    test('start and end live together when start comes first', () {
      final withStart = BookmarksController.toggledRole(plain, 10000, start)!;
      final withBoth = BookmarksController.toggledRole(withStart, 30000, end);
      expect(rolesOf(withBoth), {10000: start, 20000: null, 30000: end});
    });

    test('a role moves to the newly picked bookmark', () {
      final withStart = BookmarksController.toggledRole(plain, 10000, start)!;
      final moved = BookmarksController.toggledRole(withStart, 20000, start);
      expect(rolesOf(moved), {10000: null, 20000: start, 30000: null});
    });

    test('an end before the start drops the start', () {
      final withStart = BookmarksController.toggledRole(plain, 20000, start)!;
      final withEnd = BookmarksController.toggledRole(withStart, 10000, end);
      expect(rolesOf(withEnd), {10000: end, 20000: null, 30000: null});
    });

    test('a start after the end drops the end', () {
      final withEnd = BookmarksController.toggledRole(plain, 20000, end)!;
      final withStart = BookmarksController.toggledRole(withEnd, 30000, start);
      expect(rolesOf(withStart), {10000: null, 20000: null, 30000: start});
    });

    test('switching a bookmark from start to end', () {
      final withStart = BookmarksController.toggledRole(plain, 20000, start)!;
      final switched = BookmarksController.toggledRole(withStart, 20000, end);
      expect(rolesOf(switched), {10000: null, 20000: end, 30000: null});
    });

    test('titles stay', () {
      final titled = [bookmarkAt(10000, title: 'verse'), bookmarkAt(20000, title: 'chorus', role: end)];
      final toggled = BookmarksController.toggledRole(titled, 10000, start)!;
      expect(toggled.map((e) => e.title), ['verse', 'chorus']);
      expect(rolesOf(toggled), {10000: start, 20000: end});
    });

    test('a missing bookmark changes nothing', () {
      expect(BookmarksController.toggledRole(plain, 15000, start), isNull);
    });
  });
}
