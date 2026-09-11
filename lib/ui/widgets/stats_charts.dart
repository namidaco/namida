// by claude
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:history_manager/history_manager.dart';
import 'package:intl/intl.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class ChartPalette {
  ChartPalette._();

  static Color base() => CurrentColor.inst.color;

  static List<Color> series(Color base, int count, Brightness brightness) {
    if (count <= 0) return const [];
    final hsl = HSLColor.fromColor(base);
    final dark = brightness == Brightness.dark;
    final step = count == 1 ? 0.0 : 300.0 / count;
    return List.generate(
      count,
      (i) => hsl.withHue((hsl.hue + i * step) % 360).withSaturation(dark ? 0.40 : 0.46).withLightness(dark ? 0.64 : 0.50).toColor(),
      growable: false,
    );
  }

  static Color soft(Color base, Brightness brightness) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withSaturation(0.35).withLightness(brightness == Brightness.dark ? 0.68 : 0.46).toColor();
  }
}

class ChartTip {
  final Offset position;
  final String text;

  const ChartTip(this.position, this.text);
}

class ChartData {
  final String label;
  final int value;

  const ChartData(this.label, this.value);
}

class _ChartTipOverlay extends StatelessWidget {
  final ValueNotifier<ChartTip?> tip;
  final Widget child;

  const _ChartTipOverlay({required this.tip, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: ValueListenableBuilder(
            valueListenable: tip,
            builder: (context, tip, _) {
              if (tip == null) return const SizedBox();
              return LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth;
                  final left = tip.position.dx.clamp(0.0, math.max(0.0, maxW - 160.0)).toDouble();
                  final top = math.max(0.0, tip.position.dy - 42.0).toDouble();
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: left,
                        top: top,
                        child: IgnorePointer(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 160.0),
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacityExt(0.95),
                              borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.shadowColor.withAlpha(50),
                                  blurRadius: 6.0,
                                ),
                              ],
                            ),
                            child: Text(
                              tip.text,
                              style: theme.textTheme.displaySmall?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

mixin _ChartTipMixin<W extends StatefulWidget> on State<W> {
  final tip = ValueNotifier<ChartTip?>(null);
  Timer? _tipTimer;

  void showTip(ChartTip? t) {
    _tipTimer?.cancel();
    tip.value = t;
    if (t != null) _tipTimer = Timer(const Duration(milliseconds: 2500), () => tip.value = null);
  }

  void disposeTip() {
    _tipTimer?.cancel();
    tip.dispose();
  }
}

mixin _RevealMixin<W extends StatefulWidget> on State<W>, SingleTickerProviderStateMixin<W> {
  late final AnimationController reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> revealCurve = CurvedAnimation(parent: reveal, curve: Curves.easeOutCubic);

  void startReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || reveal.value != 0.0) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        reveal.value = 1.0;
      } else {
        reveal.forward();
      }
    });
  }

  void restartReveal() {
    reveal.value = 0.0;
    startReveal();
  }
}

TextPainter _textPainter(String text, TextStyle style, {double maxWidth = double.infinity, TextAlign align = TextAlign.left}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: ui.TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
    textAlign: align,
  );
  tp.layout(maxWidth: maxWidth);
  return tp;
}

class StatsWatermark extends StatelessWidget {
  final String? text;

  const StatsWatermark({super.key, this.text});

  @override
  Widget build(BuildContext context) {
    final style = context.theme.textTheme.displayMedium;
    final color = style?.color?.withOpacityExt(0.7);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/namida_icon.png',
          width: 20.0,
          height: 20.0,
          cacheWidth: 80,
          cacheHeight: 80,
        ),
        const SizedBox(width: 6.0),
        Text(
          text ?? 'Namida',
          style: style?.copyWith(fontSize: 13.0, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

/// Card wrapper providing png export (share) & raw numbers copy.
class StatsChartCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final String Function()? copyText;
  final EdgeInsetsGeometry childPadding;

  const StatsChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
    this.copyText,
    this.childPadding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
  });

  @override
  State<StatsChartCard> createState() => _StatsChartCardState();
}

class _StatsChartCardState extends State<StatsChartCard> {
  final _boundaryKey = GlobalKey();
  final _exporting = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _exporting.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    if (_exporting.value) return;
    _exporting.value = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      final dir = Directory(FileParts.joinPath(AppDirs.APP_CACHE, 'stats_export'));
      await dir.create(recursive: true);
      final file = File(FileParts.joinPath(dir.path, 'namida_stats_${DateTime.now().millisecondsSinceEpoch}.png'));
      await file.writeAsBytes(Uint8List.sublistView(bytes));
      await NamidaUtils.shareFiles([file.path]);
    } catch (_) {
    } finally {
      _exporting.value = false;
    }
  }

  void _copy() {
    final text = widget.copyText?.call();
    if (text == null || text.isEmpty) return;
    NamidaUtils.copyToClipboard(title: widget.title, content: text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: RepaintBoundary(
        key: _boundaryKey,
        child: ValueListenableBuilder(
          valueListenable: _exporting,
          builder: (context, exporting, child) => DecoratedBox(
            decoration: BoxDecoration(
              color: exporting ? theme.scaffoldBackgroundColor : Colors.transparent,
              borderRadius: BorderRadius.circular(20.0.multipliedRadius),
            ),
            child: child,
          ),
          child: NamidaInkWell(
            borderRadius: 20.0,
            bgColor: theme.cardColor.withOpacityExt(0.6),
            onLongPress: widget.copyText == null ? null : _copy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 6.0),
                  child: Row(
                    children: [
                      Icon(
                        widget.icon,
                        size: 20.0,
                        color: context.defaultIconColor(),
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.subtitle != null)
                              Text(
                                widget.subtitle!,
                                style: textTheme.displaySmall?.copyWith(fontSize: 11.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (widget.trailing != null) widget.trailing!,
                      ValueListenableBuilder(
                        valueListenable: _exporting,
                        builder: (context, exporting, _) => exporting
                            ? const SizedBox(width: 36.0)
                            : NamidaIconButton(
                                icon: Broken.share,
                                iconSize: 18.0,
                                horizontalPadding: 8.0,
                                verticalPadding: 4.0,
                                onPressed: _export,
                              ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: widget.childPadding,
                  child: widget.child,
                ),
                ValueListenableBuilder(
                  valueListenable: _exporting,
                  builder: (context, exporting, _) => exporting
                      ? const Padding(
                          padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 12.0),
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: StatsWatermark(),
                          ),
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================== heatmap ========================================

class ListensHeatmapChart extends StatefulWidget {
  final Int32List values;
  final int firstDay;
  final double cellMaxSize;
  final void Function(int day, int listens)? onDayLongPress;

  const ListensHeatmapChart({
    super.key,
    required this.values,
    required this.firstDay,
    this.cellMaxSize = 14.0,
    this.onDayLongPress,
  });

  static const maxWeeks = 53;

  @override
  State<ListensHeatmapChart> createState() => _ListensHeatmapChartState();
}

class _ListensHeatmapChartState extends State<ListensHeatmapChart> with SingleTickerProviderStateMixin, _RevealMixin, _ChartTipMixin {
  late _HeatmapPainter _painter;

  @override
  void initState() {
    super.initState();
    _painter = _HeatmapPainter(widget: widget, repaint: revealCurve);
    startReveal();
  }

  @override
  void didUpdateWidget(covariant ListensHeatmapChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.values, widget.values) || oldWidget.firstDay != widget.firstDay) {
      _painter = _HeatmapPainter(widget: widget, repaint: revealCurve);
      restartReveal();
    }
  }

  @override
  void dispose() {
    reveal.dispose();
    disposeTip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    _painter.baseColor = ChartPalette.base();
    _painter.emptyColor = theme.colorScheme.onSurface.withOpacityExt(0.07);
    _painter.labelStyle = theme.textTheme.displaySmall!.copyWith(fontSize: 10.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = _painter.heightFor(constraints.maxWidth);
        return _ChartTipOverlay(
          tip: tip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => showTip(_painter.tipAt(d.localPosition)),
            onLongPressStart: widget.onDayLongPress == null
                ? null
                : (d) {
                    final hit = _painter.hitDay(d.localPosition);
                    if (hit != null) widget.onDayLongPress!(hit.$1, hit.$2);
                  },
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(constraints.maxWidth, height),
                painter: _painter,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final ListensHeatmapChart widget;
  final Animation<double> repaint;

  Color baseColor = Colors.blue;
  Color emptyColor = Colors.grey;
  TextStyle labelStyle = const TextStyle(fontSize: 10.0);

  late final int _startIndex;
  late final int _count;
  late final int _firstDay;
  late final int _startWeekday;
  late final int _cols;
  late final int _max;

  double _cell = 0.0;
  double _gap = 2.0;
  double _left = 0.0;
  double _top = 0.0;
  double _width = 0.0;
  List<(int col, TextPainter tp)> _monthLabels = const [];
  List<TextPainter> _dayLabels = const [];

  static const _labelsHeight = 14.0;
  static const _dayLabelsWidth = 22.0;

  _HeatmapPainter({required this.widget, required this.repaint}) : super(repaint: repaint) {
    final values = widget.values;
    final maxDays = ListensHeatmapChart.maxWeeks * 7;
    _startIndex = values.length > maxDays ? values.length - maxDays : 0;
    _count = values.length - _startIndex;
    _firstDay = widget.firstDay + _startIndex;
    _startWeekday = (_firstDay + 4) % 7;
    _cols = ((_startWeekday + _count) / 7).ceil();
    int max = 0;
    for (int i = _startIndex; i < values.length; i++) {
      if (values[i] > max) max = values[i];
    }
    _max = max;
  }

  double heightFor(double width) {
    _layout(width);
    return _top + 7 * (_cell + _gap);
  }

  void _layout(double width) {
    if (_width == width && _cell > 0) return;
    _width = width;
    final available = width - _dayLabelsWidth;
    final cellWithGap = available / _cols;
    _gap = cellWithGap > 8.0 ? 2.0 : 1.0;
    _cell = math.min(widget.cellMaxSize, cellWithGap - _gap).clamp(1.0, widget.cellMaxSize);
    _left = _dayLabelsWidth + (available - _cols * (_cell + _gap)) / 2;
    _top = _labelsHeight + 2.0;

    final labels = <(int, TextPainter)>[];
    int lastMonth = -1;
    final fmt = DateFormat.MMM();
    for (int col = 0; col < _cols; col++) {
      final dayIndex = col * 7 - _startWeekday;
      final day = _firstDay + (dayIndex < 0 ? 0 : dayIndex);
      final date = HistoryManager.daysSince1970ToDate(day);
      if (date.month != lastMonth) {
        if (lastMonth != -1 || col == 0) labels.add((col, _textPainter(fmt.format(date), labelStyle)));
        lastMonth = date.month;
      }
    }
    _monthLabels = labels;
    final dayFmt = DateFormat.E();
    final sunday = DateTime(2024, 1, 7);
    _dayLabels = List.generate(
      7,
      (i) => _textPainter(dayFmt.format(sunday.add(Duration(days: i))).substring(0, 1), labelStyle),
      growable: false,
    );
  }

  (int col, int row)? _cellAt(Offset p) {
    final x = p.dx - _left;
    final y = p.dy - _top;
    if (x < 0 || y < 0) return null;
    final col = x ~/ (_cell + _gap);
    final row = y ~/ (_cell + _gap);
    if (col >= _cols || row >= 7) return null;
    return (col, row);
  }

  (int day, int listens)? hitDay(Offset p) {
    final c = _cellAt(p);
    if (c == null) return null;
    final index = c.$1 * 7 + c.$2 - _startWeekday;
    if (index < 0 || index >= _count) return null;
    return (_firstDay + index, widget.values[_startIndex + index]);
  }

  ChartTip? tipAt(Offset p) {
    final hit = hitDay(p);
    if (hit == null) return null;
    final date = HistoryManager.daysSince1970ToDate(hit.$1);
    return ChartTip(p, '${date.dateFormattedOriginal}\n${lang.countTracks(count: hit.$2)}');
  }

  @override
  void paint(Canvas canvas, Size size) {
    _layout(size.width);
    final progress = repaint.value;
    final paint = Paint();
    final radius = Radius.circular(_cell >= 6 ? 3.0 : 1.5);

    for (final l in _monthLabels) {
      final x = _left + l.$1 * (_cell + _gap);
      if (x + l.$2.width > size.width) continue;
      l.$2.paint(canvas, Offset(x, 0));
    }
    for (int row = 0; row < 7; row += 2) {
      final tp = _dayLabels[row];
      tp.paint(canvas, Offset(0, _top + row * (_cell + _gap) + (_cell - tp.height) / 2));
    }

    final values = widget.values;
    final revealCols = progress * _cols;
    for (int col = 0; col < _cols; col++) {
      final colProgress = (revealCols - col).clamp(0.0, 1.0);
      if (colProgress <= 0) break;
      for (int row = 0; row < 7; row++) {
        final index = col * 7 + row - _startWeekday;
        if (index < 0 || index >= _count) continue;
        final v = values[_startIndex + index];
        Color color;
        if (v <= 0 || _max <= 0) {
          color = emptyColor;
        } else {
          final level = (v / _max * 4).ceil().clampInt(1, 4);
          color = baseColor.withOpacityExt(0.25 + level * 0.1875);
        }
        paint.color = color.withOpacityExt(color.a * colProgress);
        final x = _left + col * (_cell + _gap);
        final y = _top + row * (_cell + _gap);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, _cell, _cell), radius), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) => oldDelegate.widget != widget;
}

// ======================================== clock ========================================

class ListeningClockChart extends StatefulWidget {
  final Int32List hours;
  final double size;

  const ListeningClockChart({
    super.key,
    required this.hours,
    this.size = 200.0,
  });

  @override
  State<ListeningClockChart> createState() => _ListeningClockChartState();
}

class _ListeningClockChartState extends State<ListeningClockChart> with SingleTickerProviderStateMixin, _RevealMixin, _ChartTipMixin {
  late _ClockPainter _painter;

  @override
  void initState() {
    super.initState();
    _painter = _ClockPainter(hours: widget.hours, repaint: revealCurve);
    startReveal();
  }

  @override
  void didUpdateWidget(covariant ListeningClockChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.hours, widget.hours)) {
      _painter = _ClockPainter(hours: widget.hours, repaint: revealCurve);
      restartReveal();
    }
  }

  @override
  void dispose() {
    reveal.dispose();
    disposeTip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    _painter.baseColor = ChartPalette.base();
    _painter.trackColor = theme.colorScheme.onSurface.withOpacityExt(0.07);
    _painter.labelStyle = theme.textTheme.displaySmall!.copyWith(fontSize: 10.5);
    _painter.centerStyle = theme.textTheme.displayLarge!.copyWith(fontSize: 20.0, fontWeight: FontWeight.w700);
    _painter.centerSubStyle = theme.textTheme.displaySmall!.copyWith(fontSize: 10.5);
    _painter.hourFormat12 = settings.hourFormat12.value;
    return _ChartTipOverlay(
      tip: tip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => showTip(_painter.tipAt(d.localPosition)),
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _painter,
          ),
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final Int32List hours;
  final Animation<double> repaint;

  Color baseColor = Colors.blue;
  Color trackColor = Colors.grey;
  TextStyle labelStyle = const TextStyle(fontSize: 10.0);
  TextStyle centerStyle = const TextStyle(fontSize: 20.0);
  TextStyle centerSubStyle = const TextStyle(fontSize: 10.0);
  bool hourFormat12 = false;

  late final int _max;
  late final int _peakHour;
  late final int _total;

  Size _size = Size.zero;
  double _r = 0;
  double _r0 = 0;
  Offset _center = Offset.zero;

  static const _sweep = math.pi * 2 / 24;

  _ClockPainter({required this.hours, required this.repaint}) : super(repaint: repaint) {
    int max = 0;
    int peak = 0;
    int total = 0;
    for (int i = 0; i < hours.length; i++) {
      total += hours[i];
      if (hours[i] > max) {
        max = hours[i];
        peak = i;
      }
    }
    _max = max;
    _peakHour = peak;
    _total = total;
  }

  String formatHour(int h) {
    if (!hourFormat12) return '${h.toString().padLeft(2, '0')}:00';
    final suffix = h < 12 ? 'AM' : 'PM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12 $suffix';
  }

  void _layout(Size size) {
    if (_size == size) return;
    _size = size;
    _center = Offset(size.width / 2, size.height / 2);
    _r = math.min(size.width, size.height) / 2 - 16.0;
    _r0 = _r * 0.46;
  }

  int? _hourAt(Offset p) {
    final d = p - _center;
    final dist = d.distance;
    if (dist < _r0 * 0.9 || dist > _r + 6) return null;
    var angle = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    return (angle / _sweep).floor() % 24;
  }

  ChartTip? tipAt(Offset p) {
    final h = _hourAt(p);
    if (h == null) return null;
    final pct = _total == 0 ? 0 : (hours[h] * 100 / _total).round();
    return ChartTip(p, '${formatHour(h)}\n${lang.countTracks(count: hours[h])} • $pct%');
  }

  Color _hourColor(int h) {
    final isDay = h >= 6 && h < 18;
    final hsl = HSLColor.fromColor(baseColor);
    final shifted = hsl.withHue((hsl.hue + (isDay ? 12 : -18)) % 360).withSaturation(hsl.saturation * 0.85);
    return shifted.toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _layout(size);
    final progress = repaint.value;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final trackWidth = _r - _r0;
    paint
      ..color = trackColor
      ..strokeWidth = trackWidth;
    canvas.drawCircle(_center, _r0 + trackWidth / 2, paint);

    paint.strokeCap = StrokeCap.round;
    for (int h = 0; h < 24; h++) {
      final v = hours[h];
      if (v <= 0 || _max <= 0) continue;
      final hProgress = ((progress * 24 - h) / 4).clamp(0.0, 1.0);
      if (hProgress <= 0) continue;
      final len = (v / _max) * (_r - _r0) * Curves.easeOutCubic.transform(hProgress);
      final start = -math.pi / 2 + h * _sweep + _sweep * 0.12;
      final sweep = _sweep * 0.76;
      final mid = _r0 + len / 2;
      final w = math.max(1.0, len);
      paint
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = w
        ..color = _hourColor(h).withOpacityExt(h == _peakHour ? 1.0 : 0.45 + 0.45 * (v / _max));
      canvas.drawArc(Rect.fromCircle(center: _center, radius: mid), start, sweep, false, paint);
    }

    for (int h = 0; h < 24; h += 6) {
      final tp = _textPainter(hourFormat12 ? formatHour(h) : h.toString().padLeft(2, '0'), labelStyle);
      final angle = -math.pi / 2 + h * _sweep;
      final pos = _center + Offset(math.cos(angle), math.sin(angle)) * (_r + 9.0);
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    if (_total > 0) {
      final tp = _textPainter(formatHour(_peakHour), centerStyle);
      final sub = _textPainter(lang.top, centerSubStyle);
      final totalH = tp.height + sub.height;
      tp.paint(canvas, _center - Offset(tp.width / 2, totalH / 2));
      sub.paint(canvas, _center + Offset(-sub.width / 2, totalH / 2 - sub.height));
    }
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) => !identical(oldDelegate.hours, hours);
}

// ======================================== vertical bars (weekdays / months) ========================================

class VerticalBarsChart extends StatefulWidget {
  final List<ChartData> data;
  final double height;
  final void Function(int index)? onTap;

  const VerticalBarsChart({
    super.key,
    required this.data,
    this.height = 90.0,
    this.onTap,
  });

  @override
  State<VerticalBarsChart> createState() => _VerticalBarsChartState();
}

class _VerticalBarsChartState extends State<VerticalBarsChart> with SingleTickerProviderStateMixin, _RevealMixin, _ChartTipMixin {
  late _VerticalBarsPainter _painter;

  @override
  void initState() {
    super.initState();
    _painter = _VerticalBarsPainter(data: widget.data, repaint: revealCurve);
    startReveal();
  }

  @override
  void didUpdateWidget(covariant VerticalBarsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      _painter = _VerticalBarsPainter(data: widget.data, repaint: revealCurve);
      restartReveal();
    }
  }

  @override
  void dispose() {
    reveal.dispose();
    disposeTip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    _painter.baseColor = ChartPalette.base();
    _painter.labelStyle = theme.textTheme.displaySmall!.copyWith(fontSize: 10.0);
    return _ChartTipOverlay(
      tip: tip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final onTap = widget.onTap;
          if (onTap != null) {
            final i = _painter.indexAt(d.localPosition);
            if (i != null) onTap(i);
          }
          showTip(_painter.tipAt(d.localPosition));
        },
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _painter,
          ),
        ),
      ),
    );
  }
}

class _VerticalBarsPainter extends CustomPainter {
  final List<ChartData> data;
  final Animation<double> repaint;

  Color baseColor = Colors.blue;
  TextStyle labelStyle = const TextStyle(fontSize: 10.0);

  late final int _max;
  late final int _peak;
  Size _size = Size.zero;
  List<TextPainter> _labels = const [];

  static const _labelH = 14.0;

  _VerticalBarsPainter({required this.data, required this.repaint}) : super(repaint: repaint) {
    int max = 0;
    int peak = 0;
    for (int i = 0; i < data.length; i++) {
      if (data[i].value > max) {
        max = data[i].value;
        peak = i;
      }
    }
    _max = max;
    _peak = peak;
  }

  void _layout(Size size) {
    if (_size == size) return;
    _size = size;
    final slot = size.width / data.length;
    _labels = data.map((e) => _textPainter(e.label, labelStyle, maxWidth: slot)).toList(growable: false);
  }

  int? indexAt(Offset p) {
    if (data.isEmpty || _size.isEmpty) return null;
    final i = (p.dx / (_size.width / data.length)).floor();
    if (i < 0 || i >= data.length) return null;
    return i;
  }

  ChartTip? tipAt(Offset p) {
    final i = indexAt(p);
    if (i == null) return null;
    return ChartTip(p, '${data[i].label}\n${lang.countTracks(count: data[i].value)}');
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    _layout(size);
    final progress = repaint.value;
    final slot = size.width / data.length;
    final barW = math.min(slot * 0.6, 28.0);
    final chartH = size.height - _labelH - 4.0;
    final paint = Paint();
    for (int i = 0; i < data.length; i++) {
      final v = data[i].value;
      final x = i * slot + (slot - barW) / 2;
      final h = _max <= 0 ? 0.0 : (v / _max) * chartH * progress;
      paint.color = baseColor.withOpacityExt(i == _peak ? 0.95 : 0.4 + 0.4 * (_max == 0 ? 0 : v / _max));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, chartH - h, barW, h), const Radius.circular(4.0)),
        paint,
      );
      final tp = _labels[i];
      tp.paint(canvas, Offset(i * slot + (slot - tp.width) / 2, chartH + 4.0));
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalBarsPainter oldDelegate) => !identical(oldDelegate.data, data);
}

// ======================================== grid heatmap (rows x cols) ========================================

class GridHeatmapChart extends StatefulWidget {
  final Int32List values;
  final int rows;
  final int cols;
  final List<String> rowLabels;
  final List<String> colLabels;

  /// col labels are drawn every [colLabelStep] columns.
  final int colLabelStep;
  final String Function(int row, int col, int value) tipBuilder;

  const GridHeatmapChart({
    super.key,
    required this.values,
    required this.rows,
    required this.cols,
    required this.rowLabels,
    required this.colLabels,
    this.colLabelStep = 1,
    required this.tipBuilder,
  });

  @override
  State<GridHeatmapChart> createState() => _GridHeatmapChartState();
}

class _GridHeatmapChartState extends State<GridHeatmapChart> with SingleTickerProviderStateMixin, _RevealMixin, _ChartTipMixin {
  late _GridHeatmapPainter _painter;

  @override
  void initState() {
    super.initState();
    _painter = _GridHeatmapPainter(widget: widget, repaint: revealCurve);
    startReveal();
  }

  @override
  void didUpdateWidget(covariant GridHeatmapChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.values, widget.values)) {
      _painter = _GridHeatmapPainter(widget: widget, repaint: revealCurve);
      restartReveal();
    }
  }

  @override
  void dispose() {
    reveal.dispose();
    disposeTip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    _painter.baseColor = ChartPalette.base();
    _painter.emptyColor = theme.colorScheme.onSurface.withOpacityExt(0.07);
    _painter.labelStyle = theme.textTheme.displaySmall!.copyWith(fontSize: 10.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = _painter.heightFor(constraints.maxWidth);
        return _ChartTipOverlay(
          tip: tip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => showTip(_painter.tipAt(d.localPosition)),
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(constraints.maxWidth, height),
                painter: _painter,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GridHeatmapPainter extends CustomPainter {
  final GridHeatmapChart widget;
  final Animation<double> repaint;

  Color baseColor = Colors.blue;
  Color emptyColor = Colors.grey;
  TextStyle labelStyle = const TextStyle(fontSize: 10.0);

  late final int _max;
  double _cellW = 0;
  double _cellH = 0;
  double _left = 0;
  double _width = 0;
  List<TextPainter> _rowLabels = const [];
  List<TextPainter?> _colLabels = const [];

  static const _gap = 2.0;
  static const _labelsHeight = 14.0;
  static const _rowLabelsWidth = 30.0;
  static const _maxCellH = 16.0;

  _GridHeatmapPainter({required this.widget, required this.repaint}) : super(repaint: repaint) {
    int max = 0;
    for (final v in widget.values) {
      if (v > max) max = v;
    }
    _max = max;
  }

  double heightFor(double width) {
    _layout(width);
    return _labelsHeight + 2.0 + widget.rows * (_cellH + _gap);
  }

  void _layout(double width) {
    if (_width == width && _cellW > 0) return;
    _width = width;
    _left = _rowLabelsWidth;
    _cellW = (width - _left) / widget.cols - _gap;
    _cellH = math.min(_maxCellH, _cellW * 1.4);
    _rowLabels = widget.rowLabels.map((e) => _textPainter(e, labelStyle, maxWidth: _rowLabelsWidth - 4.0)).toList(growable: false);
    _colLabels = List.generate(
      widget.cols,
      (i) => i % widget.colLabelStep == 0 ? _textPainter(widget.colLabels[i], labelStyle) : null,
      growable: false,
    );
  }

  (int row, int col)? _cellAt(Offset p) {
    final x = p.dx - _left;
    final y = p.dy - _labelsHeight - 2.0;
    if (x < 0 || y < 0) return null;
    final col = x ~/ (_cellW + _gap);
    final row = y ~/ (_cellH + _gap);
    if (col >= widget.cols || row >= widget.rows) return null;
    return (row, col);
  }

  ChartTip? tipAt(Offset p) {
    final c = _cellAt(p);
    if (c == null) return null;
    return ChartTip(p, widget.tipBuilder(c.$1, c.$2, widget.values[c.$1 * widget.cols + c.$2]));
  }

  @override
  void paint(Canvas canvas, Size size) {
    _layout(size.width);
    final progress = repaint.value;
    final paint = Paint();
    final radius = Radius.circular(_cellW >= 6 ? 3.0 : 1.5);
    final top = _labelsHeight + 2.0;

    for (int col = 0; col < widget.cols; col++) {
      final tp = _colLabels[col];
      if (tp == null) continue;
      tp.paint(canvas, Offset(_left + col * (_cellW + _gap), 0));
    }
    for (int row = 0; row < widget.rows; row++) {
      final tp = _rowLabels[row];
      tp.paint(canvas, Offset(0, top + row * (_cellH + _gap) + (_cellH - tp.height) / 2));
    }

    final revealCols = progress * widget.cols;
    for (int col = 0; col < widget.cols; col++) {
      final colProgress = (revealCols - col).clamp(0.0, 1.0);
      if (colProgress <= 0) break;
      for (int row = 0; row < widget.rows; row++) {
        final v = widget.values[row * widget.cols + col];
        Color color;
        if (v <= 0 || _max <= 0) {
          color = emptyColor;
        } else {
          final level = (v / _max * 4).ceil().clampInt(1, 4);
          color = baseColor.withOpacityExt(0.25 + level * 0.1875);
        }
        paint.color = color.withOpacityExt(color.a * colProgress);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(_left + col * (_cellW + _gap), top + row * (_cellH + _gap), _cellW, _cellH), radius),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridHeatmapPainter oldDelegate) => oldDelegate.widget != widget;
}

// ======================================== donut ========================================

class DonutChart extends StatefulWidget {
  final List<ChartData> data;
  final int otherValue;
  final double size;
  final String? centerLabel;

  const DonutChart({
    super.key,
    required this.data,
    this.otherValue = 0,
    this.size = 150.0,
    this.centerLabel,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> with SingleTickerProviderStateMixin, _RevealMixin {
  final _selected = ValueNotifier<int?>(null);
  late _DonutPainter _painter;

  @override
  void initState() {
    super.initState();
    _painter = _DonutPainter(data: widget.data, otherValue: widget.otherValue, repaint: revealCurve, selected: _selected);
    startReveal();
  }

  @override
  void didUpdateWidget(covariant DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data) || oldWidget.otherValue != widget.otherValue) {
      _selected.value = null;
      _painter = _DonutPainter(data: widget.data, otherValue: widget.otherValue, repaint: revealCurve, selected: _selected);
      restartReveal();
    }
  }

  @override
  void dispose() {
    reveal.dispose();
    _selected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final colors = ChartPalette.series(ChartPalette.base(), widget.data.length, theme.brightness);
    _painter.colors = colors;
    _painter.otherColor = theme.colorScheme.onSurface.withOpacityExt(0.18);
    _painter.centerStyle = textTheme.displayLarge!.copyWith(fontSize: 18.0, fontWeight: FontWeight.w700);
    _painter.centerSubStyle = textTheme.displaySmall!.copyWith(fontSize: 10.5);
    _painter.centerLabel = widget.centerLabel;

    final total = _painter.total;
    final legendCount = widget.data.length + (widget.otherValue > 0 ? 1 : 0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _selected.value = _painter.sliceAt(d.localPosition),
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _painter,
            ),
          ),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: _selected,
            builder: (context, selected, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                legendCount,
                (i) {
                  final isOther = i >= widget.data.length;
                  final label = isOther ? lang.others : widget.data[i].label;
                  final value = isOther ? widget.otherValue : widget.data[i].value;
                  final pct = total == 0 ? 0.0 : value * 100 / total;
                  final color = isOther ? _painter.otherColor : colors[i];
                  final isSelected = selected == i;
                  return TapDetector(
                    onTap: () => _selected.value = isSelected ? null : i,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withOpacityExt(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8.0,
                            height: 8.0,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6.0),
                          Expanded(
                            child: Text(
                              label,
                              style: textTheme.displaySmall?.copyWith(fontSize: 11.5, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            '${pct.roundDecimals(1)}%',
                            style: textTheme.displaySmall?.copyWith(fontSize: 11.0, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<ChartData> data;
  final int otherValue;
  final Animation<double> repaint;
  final ValueNotifier<int?> selected;

  List<Color> colors = const [];
  Color otherColor = Colors.grey;
  TextStyle centerStyle = const TextStyle(fontSize: 18.0);
  TextStyle centerSubStyle = const TextStyle(fontSize: 10.0);
  String? centerLabel;

  late final int total;
  late final List<double> _fractions;

  Size _size = Size.zero;
  Offset _center = Offset.zero;
  double _r = 0;
  double _stroke = 0;

  _DonutPainter({required this.data, required this.otherValue, required this.repaint, required this.selected}) : super(repaint: Listenable.merge([repaint, selected])) {
    int t = otherValue;
    for (final d in data) {
      t += d.value;
    }
    total = t;
    _fractions = List.generate(
      data.length + (otherValue > 0 ? 1 : 0),
      (i) => t == 0 ? 0.0 : (i < data.length ? data[i].value : otherValue) / t,
      growable: false,
    );
  }

  void _layout(Size size) {
    if (_size == size) return;
    _size = size;
    _center = Offset(size.width / 2, size.height / 2);
    _r = math.min(size.width, size.height) / 2 - 8.0;
    _stroke = _r * 0.36;
  }

  int? sliceAt(Offset p) {
    final d = p - _center;
    final dist = d.distance;
    if (dist < _r - _stroke - 4 || dist > _r + 8) return null;
    var angle = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    final f = angle / (math.pi * 2);
    double acc = 0;
    for (int i = 0; i < _fractions.length; i++) {
      acc += _fractions[i];
      if (f <= acc) return selected.value == i ? null : i;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _layout(size);
    final progress = repaint.value;
    final sel = selected.value;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    double start = -math.pi / 2;
    final totalSweep = math.pi * 2 * progress;
    double drawn = 0;
    for (int i = 0; i < _fractions.length; i++) {
      final sweepFull = _fractions[i] * math.pi * 2;
      final remaining = totalSweep - drawn;
      if (remaining <= 0) break;
      final sweep = math.min(sweepFull, remaining);
      final isSel = sel == i;
      final color = i < data.length ? colors[i] : otherColor;
      paint
        ..color = sel == null || isSel ? color : color.withOpacityExt(0.35)
        ..strokeWidth = isSel ? _stroke + 8.0 : _stroke;
      final gap = _fractions.length > 1 ? 0.03 : 0.0;
      final radius = _r - _stroke / 2;
      canvas.drawArc(Rect.fromCircle(center: _center, radius: radius), start + gap / 2, math.max(0, sweep - gap), false, paint);
      start += sweepFull;
      drawn += sweepFull;
    }

    String main;
    String sub;
    if (sel != null && sel < _fractions.length) {
      main = '${(_fractions[sel] * 100).roundDecimals(1)}%';
      sub = sel < data.length ? data[sel].label : lang.others;
    } else {
      main = total.formatDecimalShort();
      sub = centerLabel ?? '';
    }
    final maxW = (_r - _stroke) * 2 - 4;
    final tp = _textPainter(main, centerStyle, maxWidth: maxW);
    final stp = _textPainter(sub, centerSubStyle, maxWidth: maxW);
    final h = tp.height + (sub.isEmpty ? 0 : stp.height);
    tp.paint(canvas, _center - Offset(tp.width / 2, h / 2));
    if (sub.isNotEmpty) stp.paint(canvas, _center + Offset(-stp.width / 2, h / 2 - stp.height));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => !identical(oldDelegate.data, data);
}

// ======================================== horizontal ranking bars ========================================

class RankBarsChart extends StatefulWidget {
  final List<ChartData> data;
  final double rowHeight;
  final void Function(int index)? onTap;

  const RankBarsChart({
    super.key,
    required this.data,
    this.rowHeight = 26.0,
    this.onTap,
  });

  @override
  State<RankBarsChart> createState() => _RankBarsChartState();
}

class _RankBarsChartState extends State<RankBarsChart> with SingleTickerProviderStateMixin, _RevealMixin {
  late _RankBarsPainter _painter;

  @override
  void initState() {
    super.initState();
    _painter = _RankBarsPainter(data: widget.data, rowHeight: widget.rowHeight, repaint: revealCurve);
    startReveal();
  }

  @override
  void didUpdateWidget(covariant RankBarsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      _painter = _RankBarsPainter(data: widget.data, rowHeight: widget.rowHeight, repaint: revealCurve);
      restartReveal();
    }
  }

  @override
  void dispose() {
    reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    _painter.baseColor = ChartPalette.base();
    _painter.trackColor = theme.colorScheme.onSurface.withOpacityExt(0.06);
    _painter.labelStyle = theme.textTheme.displaySmall!.copyWith(fontSize: 12.0, fontWeight: FontWeight.w500);
    _painter.valueStyle = theme.textTheme.displaySmall!.copyWith(fontSize: 11.0, fontWeight: FontWeight.w700);
    _painter.rankStyle = theme.textTheme.displaySmall!.copyWith(fontSize: 10.0, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withOpacityExt(0.5));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: widget.onTap == null
          ? null
          : (d) {
              final i = d.localPosition.dy ~/ widget.rowHeight;
              if (i >= 0 && i < widget.data.length) widget.onTap!(i);
            },
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(double.infinity, widget.rowHeight * widget.data.length),
          painter: _painter,
        ),
      ),
    );
  }
}

class _RankBarsPainter extends CustomPainter {
  final List<ChartData> data;
  final double rowHeight;
  final Animation<double> repaint;

  Color baseColor = Colors.blue;
  Color trackColor = Colors.grey;
  TextStyle labelStyle = const TextStyle(fontSize: 12.0);
  TextStyle valueStyle = const TextStyle(fontSize: 11.0);
  TextStyle rankStyle = const TextStyle(fontSize: 10.0);

  late final int _max;
  Size _size = Size.zero;
  List<TextPainter> _labels = const [];
  List<TextPainter> _values = const [];
  List<TextPainter> _ranks = const [];
  double _labelW = 0;
  double _valueW = 0;

  static const _rankW = 20.0;

  _RankBarsPainter({required this.data, required this.rowHeight, required this.repaint}) : super(repaint: repaint) {
    int max = 0;
    for (final d in data) {
      if (d.value > max) max = d.value;
    }
    _max = max;
  }

  void _layout(Size size) {
    if (_size == size) return;
    _size = size;
    _labelW = (size.width * 0.38).clamp(60.0, 200.0);
    _labels = data.map((e) => _textPainter(e.label, labelStyle, maxWidth: _labelW - 8.0)).toList(growable: false);
    _values = data.map((e) => _textPainter(e.value.formatDecimal(), valueStyle)).toList(growable: false);
    _ranks = List.generate(data.length, (i) => _textPainter('${i + 1}', rankStyle), growable: false);
    double vw = 0;
    for (final v in _values) {
      if (v.width > vw) vw = v.width;
    }
    _valueW = vw + 8.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    _layout(size);
    final progress = repaint.value;
    final paint = Paint();
    final barX = _rankW + _labelW;
    final barMaxW = size.width - barX - _valueW;
    final barH = rowHeight * 0.5;
    final radius = Radius.circular(barH / 2);

    for (int i = 0; i < data.length; i++) {
      final y = i * rowHeight;
      final rowProgress = ((progress * (data.length + 3) - i) / 3).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(rowProgress);
      final rank = _ranks[i];
      rank.paint(canvas, Offset((_rankW - rank.width) / 2, y + (rowHeight - rank.height) / 2));
      final label = _labels[i];
      label.paint(canvas, Offset(_rankW, y + (rowHeight - label.height) / 2));

      final barY = y + (rowHeight - barH) / 2;
      paint.color = trackColor;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barMaxW, barH), radius), paint);

      final w = _max <= 0 ? 0.0 : barMaxW * (data[i].value / _max) * eased;
      paint.color = baseColor.withOpacityExt(i == 0 ? 0.95 : 0.55);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, w, barH), radius), paint);

      final value = _values[i];
      value.paint(canvas, Offset(size.width - value.width, y + (rowHeight - value.height) / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RankBarsPainter oldDelegate) => !identical(oldDelegate.data, data);
}

// ======================================== cumulative lines ========================================

class ChartSeries {
  final String label;
  final Int32List perDay;
  final Color? color;

  const ChartSeries({required this.label, required this.perDay, this.color});
}

class CumulativeLineChart extends StatefulWidget {
  final List<ChartSeries> series;
  final int firstDay;
  final double height;

  const CumulativeLineChart({
    super.key,
    required this.series,
    required this.firstDay,
    this.height = 170.0,
  });

  @override
  State<CumulativeLineChart> createState() => _CumulativeLineChartState();
}

class _CumulativeLineChartState extends State<CumulativeLineChart> with SingleTickerProviderStateMixin, _RevealMixin, _ChartTipMixin {
  late _CumulativeLinePainter _painter;

  @override
  void initState() {
    super.initState();
    _painter = _CumulativeLinePainter(series: widget.series, firstDay: widget.firstDay, repaint: revealCurve);
    startReveal();
  }

  @override
  void didUpdateWidget(covariant CumulativeLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.series, widget.series) || oldWidget.firstDay != widget.firstDay) {
      _painter = _CumulativeLinePainter(series: widget.series, firstDay: widget.firstDay, repaint: revealCurve);
      restartReveal();
    }
  }

  @override
  void dispose() {
    reveal.dispose();
    disposeTip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final base = ChartPalette.base();
    final colors = ChartPalette.series(base, widget.series.length, theme.brightness);
    _painter.colors = List.generate(widget.series.length, (i) => widget.series[i].color ?? colors[i], growable: false);
    _painter.gridColor = theme.colorScheme.onSurface.withOpacityExt(0.08);
    _painter.labelStyle = textTheme.displaySmall!.copyWith(fontSize: 10.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChartTipOverlay(
          tip: tip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => showTip(_painter.tipAt(d.localPosition)),
            onHorizontalDragUpdate: (d) => showTip(_painter.tipAt(d.localPosition)),
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(double.infinity, widget.height),
                painter: _painter,
              ),
            ),
          ),
        ),
        if (widget.series.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 4.0),
            child: Wrap(
              spacing: 12.0,
              children: List.generate(
                widget.series.length,
                (i) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10.0,
                      height: 3.0,
                      decoration: BoxDecoration(color: _painter.colors[i], borderRadius: BorderRadius.circular(2.0)),
                    ),
                    const SizedBox(width: 5.0),
                    Text(
                      '${widget.series[i].label} • ${_painter.totals[i].formatDecimal()}',
                      style: textTheme.displaySmall?.copyWith(fontSize: 11.0, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CumulativeLinePainter extends CustomPainter {
  final List<ChartSeries> series;
  final int firstDay;
  final Animation<double> repaint;

  List<Color> colors = const [];
  Color gridColor = Colors.grey;
  TextStyle labelStyle = const TextStyle(fontSize: 10.0);

  late final int _days;
  late final int _bucketDays;
  late final int _buckets;
  late final List<Int32List> _cumulative;
  late final List<int> totals;
  late final int _max;

  Size _size = Size.zero;
  List<Path> _paths = const [];
  List<Path> _areas = const [];
  List<(double x, TextPainter tp)> _xLabels = const [];
  List<(double y, TextPainter tp)> _yLabels = const [];

  static const _padL = 34.0;
  static const _padR = 8.0;
  static const _padT = 8.0;
  static const _padB = 18.0;
  static const _maxBuckets = 90;

  _CumulativeLinePainter({required this.series, required this.firstDay, required this.repaint}) : super(repaint: repaint) {
    int days = 0;
    for (final s in series) {
      if (s.perDay.length > days) days = s.perDay.length;
    }
    _days = days;
    _bucketDays = math.max(1, (days / _maxBuckets).ceil());
    _buckets = days == 0 ? 0 : (days / _bucketDays).ceil();
    int max = 0;
    totals = List.filled(series.length, 0);
    _cumulative = List.generate(
      series.length,
      (si) {
        final perDay = series[si].perDay;
        final cum = Int32List(_buckets);
        int acc = 0;
        for (int b = 0; b < _buckets; b++) {
          final start = b * _bucketDays;
          final end = math.min(perDay.length, start + _bucketDays);
          for (int d = start; d < end; d++) {
            acc += perDay[d];
          }
          cum[b] = acc;
        }
        totals[si] = acc;
        if (acc > max) max = acc;
        return cum;
      },
      growable: false,
    );
    _max = max;
  }

  double _x(int bucket, double innerW) => _padL + (_buckets <= 1 ? innerW / 2 : bucket / (_buckets - 1) * innerW);
  double _y(int value, double innerH) => _padT + innerH - (_max == 0 ? 0 : value / _max * innerH);

  void _layout(Size size) {
    if (_size == size) return;
    _size = size;
    final innerW = size.width - _padL - _padR;
    final innerH = size.height - _padT - _padB;
    final bottom = _padT + innerH;

    _paths = List.generate(
      series.length,
      (si) {
        final cum = _cumulative[si];
        final p = Path();
        for (int b = 0; b < _buckets; b++) {
          final x = _x(b, innerW);
          final y = _y(cum[b], innerH);
          if (b == 0) {
            p.moveTo(x, y);
          } else {
            p.lineTo(x, y);
          }
        }
        return p;
      },
      growable: false,
    );
    _areas = List.generate(
      series.length,
      (si) {
        if (_buckets == 0) return Path();
        final p = Path.from(_paths[si]);
        p.lineTo(_x(_buckets - 1, innerW), bottom);
        p.lineTo(_x(0, innerW), bottom);
        p.close();
        return p;
      },
      growable: false,
    );

    final yLabels = <(double, TextPainter)>[];
    for (int i = 1; i <= 3; i++) {
      final v = (_max * i / 3).round();
      yLabels.add((_y(v, innerH), _textPainter(v.formatDecimalShort(), labelStyle)));
    }
    _yLabels = yLabels;

    final xLabels = <(double, TextPainter)>[];
    if (_buckets > 0) {
      final labelCount = (innerW / 70).floor().clamp(2, 6);
      final fmt = _days > 400 ? DateFormat.yMMM() : DateFormat.MMMd();
      for (int i = 0; i < labelCount; i++) {
        final b = (i * (_buckets - 1) / (labelCount - 1)).round();
        final date = HistoryManager.daysSince1970ToDate(firstDay + math.min(_days - 1, b * _bucketDays));
        final tp = _textPainter(fmt.format(date), labelStyle);
        final x = (_x(b, innerW) - tp.width / 2).clamp(_padL, size.width - tp.width);
        xLabels.add((x, tp));
      }
    }
    _xLabels = xLabels;
  }

  ChartTip? tipAt(Offset p) {
    if (_buckets == 0 || _size.isEmpty) return null;
    final innerW = _size.width - _padL - _padR;
    final f = ((p.dx - _padL) / innerW).clamp(0.0, 1.0);
    final b = (f * (_buckets - 1)).round();
    final date = HistoryManager.daysSince1970ToDate(firstDay + math.min(_days - 1, b * _bucketDays + _bucketDays - 1));
    final buf = StringBuffer(date.dateFormattedOriginal);
    for (int si = 0; si < series.length; si++) {
      buf.write('\n${series[si].label}: ${_cumulative[si][b].formatDecimal()}');
    }
    final innerH = _size.height - _padT - _padB;
    return ChartTip(Offset(_x(b, innerW), _y(_cumulative[0][b], innerH)), buf.toString());
  }

  @override
  void paint(Canvas canvas, Size size) {
    _layout(size);
    final progress = repaint.value;
    final innerW = size.width - _padL - _padR;
    final paint = Paint()..style = PaintingStyle.stroke;

    paint
      ..color = gridColor
      ..strokeWidth = 1.0;
    for (final l in _yLabels) {
      canvas.drawLine(Offset(_padL, l.$1), Offset(size.width - _padR, l.$1), paint);
      l.$2.paint(canvas, Offset(_padL - l.$2.width - 4.0, l.$1 - l.$2.height / 2));
    }
    for (final l in _xLabels) {
      l.$2.paint(canvas, Offset(l.$1, size.height - _padB + 4.0));
    }

    if (_buckets == 0) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, _padL + innerW * progress + 2.0, size.height));
    final fill = Paint()..style = PaintingStyle.fill;
    for (int si = series.length - 1; si >= 0; si--) {
      fill.color = colors[si].withOpacityExt(0.10);
      canvas.drawPath(_areas[si], fill);
    }
    paint
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (int si = 0; si < series.length; si++) {
      paint.color = colors[si];
      canvas.drawPath(_paths[si], paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CumulativeLinePainter oldDelegate) => !identical(oldDelegate.series, series);
}

// ======================================== gauge ========================================

class GaugeChart extends StatefulWidget {
  final double fraction;
  final String valueText;
  final String? subText;
  final double size;

  const GaugeChart({
    super.key,
    required this.fraction,
    required this.valueText,
    this.subText,
    this.size = 150.0,
  });

  @override
  State<GaugeChart> createState() => _GaugeChartState();
}

class _GaugeChartState extends State<GaugeChart> with SingleTickerProviderStateMixin, _RevealMixin {
  @override
  void initState() {
    super.initState();
    startReveal();
  }

  @override
  void didUpdateWidget(covariant GaugeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fraction != widget.fraction) restartReveal();
  }

  @override
  void dispose() {
    reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.size, widget.size * 0.72),
        painter: _GaugePainter(
          fraction: widget.fraction.clamp(0.0, 1.0),
          repaint: revealCurve,
          baseColor: ChartPalette.base(),
          trackColor: theme.colorScheme.onSurface.withOpacityExt(0.08),
          valueText: widget.valueText,
          subText: widget.subText,
          valueStyle: theme.textTheme.displayLarge!.copyWith(fontSize: 18.0, fontWeight: FontWeight.w700),
          subStyle: theme.textTheme.displaySmall!.copyWith(fontSize: 10.5),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Animation<double> repaint;
  final Color baseColor;
  final Color trackColor;
  final String valueText;
  final String? subText;
  final TextStyle valueStyle;
  final TextStyle subStyle;

  static const _start = math.pi * 0.8;
  static const _total = math.pi * 1.4;

  _GaugePainter({
    required this.fraction,
    required this.repaint,
    required this.baseColor,
    required this.trackColor,
    required this.valueText,
    required this.subText,
    required this.valueStyle,
    required this.subStyle,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width / 2, size.height / 1.25) - 10.0;
    final center = Offset(size.width / 2, size.height * 0.62);
    final rect = Rect.fromCircle(center: center, radius: r);
    final stroke = r * 0.22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    paint.color = trackColor;
    canvas.drawArc(rect, _start, _total, false, paint);

    final sweep = _total * fraction * repaint.value;
    if (sweep > 0) {
      paint.color = baseColor;
      canvas.drawArc(rect, _start, sweep, false, paint);
    }

    final tp = _textPainter(valueText, valueStyle, maxWidth: (r - stroke) * 2);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2 + 4));
    if (subText != null) {
      final stp = _textPainter(subText!, subStyle, maxWidth: (r - stroke) * 2);
      stp.paint(canvas, center + Offset(-stp.width / 2, tp.height / 2 - 2));
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.fraction != fraction || oldDelegate.valueText != valueText;
}
