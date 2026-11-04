import 'package:flutter_test/flutter_test.dart';

import 'package:namida/ui/widgets/floating_image.dart';

void main() {
  testWidgets('60hz ticks on every vsync', (tester) async {
    final stats = await _FrameSimulation(tester, refreshRate: 60.0).run(seconds: 2);
    expect(stats.framesPerSecond, closeTo(60.0, 1.0));
    expect(stats.ticksPerSecond, closeTo(60.0, 1.0));
  });

  testWidgets('120hz without other frames ticks at 60fps', (tester) async {
    final stats = await _FrameSimulation(tester, refreshRate: 120.0).run(seconds: 2);
    expect(stats.framesPerSecond, closeTo(60.0, 1.0));
    expect(stats.ticksPerSecond, closeTo(60.0, 1.0));
  });

  testWidgets('144hz without other frames ticks every 2 vsyncs', (tester) async {
    final stats = await _FrameSimulation(tester, refreshRate: 144.0).run(seconds: 2);
    expect(stats.framesPerSecond, closeTo(72.0, 1.0));
    expect(stats.ticksPerSecond, closeTo(72.0, 1.0));
  });

  testWidgets('120hz with a 30fps video out of phase shares its frames', (tester) async {
    final stats = await _FrameSimulation(tester, refreshRate: 120.0, hasOtherFrameAt: (i) => i % 4 == 1).run(seconds: 2);
    expect(stats.framesPerSecond, closeTo(60.0, 1.0));
    expect(stats.ticksPerSecond, closeTo(60.0, 1.0));
  });

  testWidgets('120hz with a 60fps video out of phase shares its frames', (tester) async {
    final stats = await _FrameSimulation(tester, refreshRate: 120.0, hasOtherFrameAt: (i) => i % 2 == 1).run(seconds: 2);
    expect(stats.framesPerSecond, closeTo(60.0, 1.0));
    expect(stats.ticksPerSecond, closeTo(60.0, 1.0));
  });

  testWidgets('120hz with a 24fps video adds no more frames than ticking alone would', (tester) async {
    final stats = await _FrameSimulation(tester, refreshRate: 120.0, hasOtherFrameAt: (i) => i % 5 == 1).run(seconds: 2);
    expect(stats.framesPerSecond, lessThanOrEqualTo(72.0));
  });

  testWidgets('120hz with a 120fps scroll adds no frames and stays at 60 ticks', (tester) async {
    final stats = await _FrameSimulation(tester, refreshRate: 120.0, hasOtherFrameAt: (_) => true).run(seconds: 2);
    expect(stats.framesPerSecond, closeTo(120.0, 1.0));
    expect(stats.ticksPerSecond, closeTo(60.0, 1.0));
  });

  testWidgets('stops requesting frames once nothing paints', (tester) async {
    final stats = await _FrameSimulation(tester, refreshRate: 120.0, paintedTicksLimit: 10).run(seconds: 2);
    expect(stats.framesCount, lessThan(30));
  });

  testWidgets('keeps ticking after frames stop for a while, like a locked screen', (tester) async {
    final stats = await _FrameSimulation(tester, refreshRate: 120.0, isHiddenAt: (i) => i >= 120 && i < 360).run(seconds: 4);
    expect(stats.ticksCount, greaterThan(110));
  });
}

class _FrameSimulation {
  final WidgetTester tester;
  final double refreshRate;

  final bool Function(int vsyncIndex)? hasOtherFrameAt;
  final bool Function(int vsyncIndex)? isHiddenAt;
  final int? paintedTicksLimit;

  const _FrameSimulation(this.tester, {required this.refreshRate, this.hasOtherFrameAt, this.isHiddenAt, this.paintedTicksLimit});

  Future<_FrameStats> run({required int seconds}) async {
    tester.view.display.refreshRate = refreshRate;
    addTearDown(tester.view.display.resetRefreshRate);
    await tester.pump();

    final clock = NamidaFloatClock.instance;
    int ticksCount = 0;
    void onTick() {
      ticksCount++;
      final paintedTicksLimit = this.paintedTicksLimit;
      if (paintedTicksLimit == null || ticksCount <= paintedTicksLimit) clock.markPainted();
    }

    clock.addListener(onTick);
    final vsyncMicros = (Duration.microsecondsPerSecond / refreshRate).round();
    final vsync = Duration(microseconds: vsyncMicros);
    final vsyncsCount = (refreshRate * seconds).round();
    int framesCount = 0;
    for (int i = 0; i < vsyncsCount; i++) {
      await tester.binding.delayed(vsync);
      final isHidden = isHiddenAt?.call(i) ?? false;
      if (isHidden) continue;
      final hasOtherFrame = hasOtherFrameAt?.call(i) ?? false;
      if (hasOtherFrame) tester.binding.scheduleFrame();
      if (!tester.binding.hasScheduledFrame) continue;
      await tester.pump();
      framesCount++;
    }
    clock.removeListener(onTick);
    return _FrameStats(framesCount: framesCount, ticksCount: ticksCount, seconds: seconds);
  }
}

class _FrameStats {
  final int framesCount;
  final int ticksCount;
  final int seconds;

  const _FrameStats({required this.framesCount, required this.ticksCount, required this.seconds});

  double get framesPerSecond => framesCount / seconds;
  double get ticksPerSecond => ticksCount / seconds;
}
