import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/core/ntheme.dart';
import 'package:namida/ui/widgets/reorderable_active_items_list.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

enum _T { a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t }

class _Harness {
  final WidgetTester tester;
  final active = ValueNotifier<List<_T>>([]);
  final rebuild = ValueNotifier(0);
  final changes = <List<_T>>[];
  double rowHeight = 0.0;

  _Harness(this.tester);

  Future<void> pump({
    required List<_T> items,
    required List<_T> activeItems,
    double height = 600.0,
    bool Function(_T item)? isLocked,
    bool Function(_T item)? canActivate,
  }) async {
    active.value = activeItems;
    await tester.pumpWidget(
      MaterialApp(
        home: NTheme(
          data: ThemeData(),
          child: Material(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: height,
                child: ListenableBuilder(
                  listenable: Listenable.merge([active, rebuild]),
                  builder: (context, _) => NamidaReorderableActiveItemsList<_T>(
                    items: items,
                    activeItems: active.value,
                    toText: (e) => e.name,
                    toIcon: (e) => Icons.abc,
                    isLocked: isLocked,
                    canActivate: canActivate,
                    onChanged: (items) {
                      changes.add(items);
                      active.value = items;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tops = _builtTiles().map((e) => e.top).toList()..sort();
    rowHeight = tops[1] - tops[0];
  }

  List<({String title, double top})> _builtTiles() {
    final tiles = tester.widgetList<ListTileWithCheckMark>(find.byType(ListTileWithCheckMark));
    return tiles.map((t) => (title: t.title!, top: tester.getTopLeft(find.byWidget(t)).dy)).toList();
  }

  /// built tiles top to bottom, after checking they sit exactly one row apart with no duplicates.
  List<String> shownOrder() {
    final tiles = _builtTiles()..sort((a, b) => a.top.compareTo(b.top));
    final titles = tiles.map((e) => e.title).toList();
    expect(titles.toSet().length, titles.length, reason: 'duplicate tiles: $titles');
    for (int i = 1; i < tiles.length; i++) {
      final gap = tiles[i].top - tiles[i - 1].top;
      expect(gap, moreOrLessEquals(rowHeight, epsilon: 0.5), reason: 'overlap or gap between ${tiles[i - 1].title} and ${tiles[i].title}: $titles');
    }
    return titles;
  }

  List<String> visibleOrder(double height) {
    final tiles = _builtTiles().where((e) => e.top >= 0.0 && e.top + rowHeight <= height).toList()..sort((a, b) => a.top.compareTo(b.top));
    return tiles.map((e) => e.title).toList();
  }

  /// numbered tiles must be 1..n in a row and match what the parent got.
  void expectConsistentFromTop() {
    final titles = shownOrder();
    final numbered = <String>[];
    for (final title in titles) {
      final match = RegExp(r'^(\d+)\. (\w+)$').firstMatch(title);
      if (match == null) break;
      expect(int.parse(match[1]!), numbered.length + 1, reason: '$titles');
      numbered.add(match[2]!);
    }
    for (final title in titles.skip(numbered.length)) {
      expect(title.contains('.'), isFalse, reason: 'numbered tile below inactive ones: $titles');
    }
    expect(numbered, active.value.map((e) => e.name).toList(), reason: '$titles');
  }

  Future<void> tap(String title, {Duration settle = Duration.zero}) async {
    await tester.tap(find.text(title), warnIfMissed: false);
    await tester.pump();
    if (settle != Duration.zero) await tester.pump(settle);
  }

  Future<void> drag(String title, double rows) async {
    final gesture = await tester.startGesture(tester.getCenter(find.text(title)));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    final steps = (rows.abs() * 2).ceil() + 1;
    final stepOffset = Offset(0.0, rows * rowHeight / steps);
    for (int i = 0; i < steps; i++) {
      await gesture.moveBy(stepOffset);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
  }

  void jumpTo(double offset) {
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    position.jumpTo(offset);
  }
}

List<_T> _first(int count) => _T.values.take(count).toList();

void main() {
  testWidgets('taps move items to the edge, slide there and keep tile state', (tester) async {
    final h = _Harness(tester);
    await h.pump(items: _first(6), activeItems: [_T.c, _T.a]);
    expect(h.shownOrder(), ['1. c', '2. a', 'b', 'd', 'e', 'f']);

    final dTopBefore = tester.getTopLeft(find.text('d')).dy;
    final checkFinder = find.descendant(of: find.ancestor(of: find.text('d'), matching: find.byType(ListTileWithCheckMark)), matching: find.byType(NamidaCheckMark));
    final checkStateBefore = tester.state(checkFinder);

    await h.tap('d');
    expect(h.changes.last, [_T.c, _T.a, _T.d]);
    expect(tester.getTopLeft(find.text('3. d')).dy, moreOrLessEquals(dTopBefore, epsilon: 0.5));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getTopLeft(find.text('3. d')).dy, lessThan(dTopBefore - 1.0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('3. d')).dy, moreOrLessEquals(dTopBefore - h.rowHeight, epsilon: 0.5));
    final checkStateAfter = tester.state(find.descendant(of: find.ancestor(of: find.text('3. d'), matching: find.byType(ListTileWithCheckMark)), matching: find.byType(NamidaCheckMark)));
    expect(identical(checkStateAfter, checkStateBefore), isTrue);
    h.expectConsistentFromTop();

    await h.tap('1. c');
    await tester.pumpAndSettle();
    expect(h.shownOrder(), ['1. a', '2. d', 'c', 'b', 'e', 'f']);
    h.expectConsistentFromTop();
  });

  testWidgets('taps while animations run settle exactly', (tester) async {
    final h = _Harness(tester);
    await h.pump(items: _first(8), activeItems: [_T.a]);
    await h.tap('h', settle: const Duration(milliseconds: 40));
    await h.tap('1. a', settle: const Duration(milliseconds: 40));
    await h.tap('g', settle: const Duration(milliseconds: 40));
    await tester.pumpAndSettle();
    h.expectConsistentFromTop();
    expect(h.active.value, [_T.h, _T.g]);
  });

  testWidgets('drag reorders active ones and toggles across the edge', (tester) async {
    final h = _Harness(tester);
    await h.pump(items: _first(8), activeItems: [_T.a, _T.b, _T.c]);

    await h.drag('3. c', -2);
    expect(h.active.value, [_T.c, _T.a, _T.b]);
    h.expectConsistentFromTop();

    await h.drag('f', -4);
    expect(h.active.value, [_T.c, _T.f, _T.a, _T.b]);
    h.expectConsistentFromTop();

    await h.drag('1. c', 5);
    expect(h.active.value, [_T.f, _T.a, _T.b]);
    expect(h.shownOrder().indexOf('c'), 5);
    h.expectConsistentFromTop();

    final changesBefore = h.changes.length;
    await h.drag('h', -2);
    expect(h.changes.length, changesBefore, reason: 'reordering inactive ones changes nothing');
    expect(h.active.value, [_T.f, _T.a, _T.b]);
    h.expectConsistentFromTop();

    // -- dropped right below the last active one activates it
    final edgeDistance = h.shownOrder().indexOf('e') - 3;
    await h.drag('e', -edgeDistance.toDouble());
    expect(h.active.value, [_T.f, _T.a, _T.b, _T.e]);
    h.expectConsistentFromTop();
  });

  testWidgets('locked and blocked items bounce back to their side', (tester) async {
    final h = _Harness(tester);
    await h.pump(
      items: _first(8),
      activeItems: [_T.a, _T.b],
      isLocked: (e) => e == _T.b,
      canActivate: (e) => e != _T.e,
    );

    await h.tap('2. b');
    await tester.pumpAndSettle();
    expect(h.active.value, [_T.a, _T.b]);

    await h.drag('2. b', 3);
    expect(h.active.value, [_T.a, _T.b]);
    expect(h.shownOrder().take(2), ['1. a', '2. b']);
    h.expectConsistentFromTop();

    await h.drag('2. b', -1);
    expect(h.active.value, [_T.b, _T.a]);
    h.expectConsistentFromTop();

    await h.tap('e');
    await tester.pumpAndSettle();
    expect(h.active.value, [_T.b, _T.a]);

    await h.drag('e', -4);
    expect(h.active.value, [_T.b, _T.a]);
    expect(h.shownOrder()[2], 'e');
    h.expectConsistentFromTop();
  });

  testWidgets('external changes animate, in place mutations included', (tester) async {
    final h = _Harness(tester);
    await h.pump(items: _first(8), activeItems: [_T.a, _T.b]);

    h.active.value = [_T.g, _T.c, _T.a];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(h.shownOrder().take(4), ['1. g', '2. c', '3. a', 'b']);
    h.expectConsistentFromTop();

    h.active.value.remove(_T.c);
    h.rebuild.value++;
    await tester.pumpAndSettle();
    expect(h.shownOrder().take(3), ['1. g', '2. a', 'c']);
    h.expectConsistentFromTop();
  });

  testWidgets('long scrolled list: moves to and from offscreen positions', (tester) async {
    final h = _Harness(tester);
    await h.pump(items: _T.values, activeItems: [_T.a, _T.b], height: 260.0);

    h.jumpTo(h.rowHeight * 10);
    await tester.pumpAndSettle();
    final target = h.visibleOrder(260.0).firstWhere((e) => !e.contains('.'));
    await h.tap(target);
    await tester.pumpAndSettle();
    h.shownOrder();
    expect(h.active.value.last.name, target);

    await h.drag(h.visibleOrder(260.0)[1], 1.5);
    h.shownOrder();

    h.jumpTo(0.0);
    await tester.pumpAndSettle();
    h.expectConsistentFromTop();

    await h.tap('1. a');
    await tester.pumpAndSettle();
    h.expectConsistentFromTop();

    h.jumpTo(h.rowHeight * 14);
    await tester.pumpAndSettle();
    h.shownOrder();
    h.jumpTo(0.0);
    await tester.pumpAndSettle();
    h.expectConsistentFromTop();
  });

  testWidgets('hot reload mid animation and mid drag', (tester) async {
    final h = _Harness(tester);
    await h.pump(items: _first(8), activeItems: [_T.a, _T.b]);

    await h.tap('f', settle: const Duration(milliseconds: 80));
    unawaited(tester.binding.reassembleApplication());
    await tester.pumpAndSettle();
    h.expectConsistentFromTop();

    final gesture = await tester.startGesture(tester.getCenter(find.text('3. f')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    for (int i = 0; i < 4; i++) {
      await gesture.moveBy(Offset(0.0, -h.rowHeight / 2));
      await tester.pump(const Duration(milliseconds: 16));
    }
    unawaited(tester.binding.reassembleApplication());
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    h.expectConsistentFromTop();
    expect(h.active.value, [_T.f, _T.a, _T.b]);

    unawaited(tester.binding.reassembleApplication());
    await tester.pumpAndSettle();
    h.expectConsistentFromTop();
  });

  for (final seed in [7, 21, 99]) {
    testWidgets('random taps, drags and external changes stay consistent (seed $seed)', (tester) async {
      await _fuzz(tester, seed);
    });
  }
}

Future<void> _fuzz(WidgetTester tester, int seed) async {
  final h = _Harness(tester);
  final items = _first(10);
  await h.pump(items: items, activeItems: [_T.a, _T.b, _T.c]);
  final random = Random(seed);

  for (int step = 0; step < 80; step++) {
    final titles = h.shownOrder();
    final roll = random.nextInt(10);
    if (roll < 5) {
      final burst = 1 + random.nextInt(3);
      for (int b = 0; b < burst; b++) {
        final current = h._builtTiles();
        final title = current[random.nextInt(current.length)].title;
        await h.tap(title, settle: Duration(milliseconds: random.nextInt(120)));
      }
      await tester.pumpAndSettle();
    } else if (roll < 9) {
      final position = random.nextInt(titles.length);
      final rows = (random.nextInt(9) - 4) + (random.nextBool() ? 0.3 : -0.3);
      final clampedRows = (position + rows).clamp(0.0, titles.length - 1.0) - position;
      await h.drag(titles[position], clampedRows);
    } else {
      final shuffled = items.toList()..shuffle(random);
      h.active.value = shuffled.take(1 + random.nextInt(5)).toList();
      await tester.pump();
      await tester.pump(Duration(milliseconds: random.nextInt(200)));
      await tester.pumpAndSettle();
    }
    h.expectConsistentFromTop();
  }
}
