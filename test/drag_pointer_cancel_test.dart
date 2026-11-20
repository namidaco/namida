// by claude
// -- the miniplayers and the yt queue chip rely on this order to tell a system cancel from a lift
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final events = <String>[];
  bool wasPointerCancelled = false;

  Widget buildApp() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Listener(
        onPointerDown: (_) => wasPointerCancelled = false,
        onPointerCancel: (_) => wasPointerCancelled = true,
        child: GestureDetector(
          onVerticalDragEnd: (_) => events.add('vertical end, cancelled: $wasPointerCancelled'),
          onHorizontalDragEnd: (_) => events.add('horizontal end, cancelled: $wasPointerCancelled'),
          child: const ColoredBox(
            color: Color(0xFF000000),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  Future<void> drag(WidgetTester tester, Offset step, {required bool cancel}) async {
    final gesture = await tester.startGesture(const Offset(200.0, 300.0));
    for (int i = 0; i < 4; i++) {
      await gesture.moveBy(step);
      await tester.pump(const Duration(milliseconds: 8));
    }
    if (cancel) {
      await gesture.cancel();
    } else {
      await gesture.up();
    }
  }

  setUp(events.clear);

  testWidgets('accepted vertical drag that gets cancelled still fires onEnd, after the listener saw the cancel', (tester) async {
    await tester.pumpWidget(buildApp());
    await drag(tester, const Offset(0.0, -20.0), cancel: true);
    await drag(tester, const Offset(0.0, -20.0), cancel: false);
    expect(events, ['vertical end, cancelled: true', 'vertical end, cancelled: false']);
  });

  testWidgets('accepted horizontal drag that gets cancelled still fires onEnd, after the listener saw the cancel', (tester) async {
    await tester.pumpWidget(buildApp());
    await drag(tester, const Offset(-20.0, 0.0), cancel: true);
    await drag(tester, const Offset(-20.0, 0.0), cancel: false);
    expect(events, ['horizontal end, cancelled: true', 'horizontal end, cancelled: false']);
  });
}
