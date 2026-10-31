import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/ui/widgets/history_days_sliver.dart';

const _itemExtent = 50.0;
const _headerExtent = 40.0;
const _topPadding = 6.0;
const _bottomPadding = 12.0;
const _dayBaseExtent = _headerExtent + _topPadding + _bottomPadding;
const _topBoxHeight = 100.0;

void main() {
  late ScrollController controller;
  late List<int> builtItems;
  late List<int> tappedHeaders;

  setUp(() {
    controller = ScrollController();
    builtItems = [];
    tappedHeaders = [];
  });

  tearDown(() => controller.dispose());

  Widget app(List<int> counts) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: CustomScrollView(
        controller: controller,
        slivers: [
          const SliverToBoxAdapter(
            child: SizedBox(
              height: _topBoxHeight,
            ),
          ),
          HistoryDaysSliver(
            daysCount: counts.length,
            dayItemsCount: (dayIndex) => counts[dayIndex],
            itemExtent: _itemExtent,
            headerExtent: _headerExtent,
            itemsTopPadding: _topPadding,
            itemsBottomPadding: _bottomPadding,
            headerBuilder: (context, dayIndex) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => tappedHeaders.add(dayIndex),
              child: Text(
                'h$dayIndex',
              ),
            ),
            itemBuilder: (context, dayIndex, itemIndex) {
              builtItems.add(dayIndex);
              return Text(
                'd$dayIndex i$itemIndex',
              );
            },
          ),
        ],
      ),
    );
  }

  double dayStart(List<int> counts, int dayIndex) {
    final itemsBefore = counts.take(dayIndex).fold(0, (a, b) => a + b);
    return _topBoxHeight + dayIndex * _dayBaseExtent + itemsBefore * _itemExtent;
  }

  double itemStart(List<int> counts, int dayIndex, int itemIndex) {
    return dayStart(counts, dayIndex) + _headerExtent + _topPadding + itemIndex * _itemExtent;
  }

  List<double> headerTops(WidgetTester tester, int dayIndex) {
    return find.text('h$dayIndex').evaluate().map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy).toList();
  }

  final counts = [3, 200, 5, 1, 50];

  testWidgets('scroll extent and item offsets match the history scroll math', (tester) async {
    await tester.pumpWidget(app(counts));
    final totalItems = counts.fold(0, (a, b) => a + b);
    final totalExtent = _topBoxHeight + counts.length * _dayBaseExtent + totalItems * _itemExtent;
    expect(controller.position.maxScrollExtent, totalExtent - 600.0);

    for (final (day, item) in [(0, 0), (1, 0), (1, 137), (2, 4), (3, 0), (4, 49)]) {
      final offset = itemStart(counts, day, item);
      controller.jumpTo((offset - 200.0).clamp(0.0, controller.position.maxScrollExtent));
      await tester.pump();
      final y = tester.getTopLeft(find.text('d$day i$item')).dy;
      expect(y, offset - controller.offset, reason: 'd$day i$item');
      expect(tester.getSize(find.text('d$day i$item')).height, _itemExtent);
    }
  });

  testWidgets('scrolling up step by step keeps offsets right', (tester) async {
    await tester.pumpWidget(app(counts));
    controller.jumpTo(itemStart(counts, 2, 2));
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      controller.jumpTo(controller.offset - 37.0);
      await tester.pump();
      final itemTexts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data!).where((t) => t.startsWith('d'));
      expect(itemTexts, isNotEmpty);
      for (final text in itemTexts) {
        final parts = text.substring(1).split(' i');
        final expectedY = itemStart(counts, int.parse(parts[0]), int.parse(parts[1])) - controller.offset;
        expect(tester.getTopLeft(find.text(text)).dy, expectedY, reason: text);
      }
    }
  });

  testWidgets('builds only visible tiles of a big day', (tester) async {
    await tester.pumpWidget(app(counts));
    controller.jumpTo(itemStart(counts, 1, 100));
    builtItems.clear();
    await tester.pump();
    expect(builtItems.where((d) => d == 1).length, lessThan(30));
  });

  testWidgets('no pinned header before the list reaches the top', (tester) async {
    await tester.pumpWidget(app(counts));
    expect(headerTops(tester, 0), [_topBoxHeight]);
    controller.jumpTo(50.0);
    await tester.pump();
    expect(headerTops(tester, 0), [_topBoxHeight - 50.0]);
  });

  testWidgets('pinned header follows the top day and gets pushed by the next one', (tester) async {
    await tester.pumpWidget(app(counts));

    controller.jumpTo(itemStart(counts, 1, 20));
    await tester.pump();
    expect(headerTops(tester, 1), contains(0.0));

    final nextDayStart = dayStart(counts, 2);
    controller.jumpTo(nextDayStart - _headerExtent + 15.0);
    await tester.pump();
    expect(headerTops(tester, 1), contains(-15.0));
    expect(headerTops(tester, 2), [_headerExtent - 15.0]);

    controller.jumpTo(nextDayStart + 1.0);
    await tester.pump();
    expect(headerTops(tester, 2), contains(0.0));
    expect(find.text('h1'), findsNothing);
  });

  testWidgets('taps hit the pinned header', (tester) async {
    await tester.pumpWidget(app(counts));
    controller.jumpTo(itemStart(counts, 1, 60));
    await tester.pump();
    await tester.tapAt(const Offset(10.0, 10.0));
    expect(tappedHeaders, [1]);
  });

  testWidgets('updates when days change, including empty', (tester) async {
    await tester.pumpWidget(app(counts));
    controller.jumpTo(itemStart(counts, 1, 30));
    await tester.pump();

    final newCounts = [4, ...counts.skip(1)];
    await tester.pumpWidget(app(newCounts));
    final y = tester.getTopLeft(find.text('d1 i30')).dy;
    expect(y, itemStart(newCounts, 1, 30) - controller.offset);

    await tester.pumpWidget(app(const []));
    expect(find.textContaining('d'), findsNothing);
    expect(find.textContaining('h'), findsNothing);

    await tester.pumpWidget(app(counts));
    expect(find.text('h0'), findsWidgets);
  });
}
