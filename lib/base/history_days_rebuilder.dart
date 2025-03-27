import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

mixin HistoryDaysRebuilderMixin<T extends StatefulWidget, E extends ItemWithDate, S> on State<T> {
  HistoryManager<E, S> get historyManager;

  List<int> get historyDays => _historyDays;
  List<int> get historyYears => _historyYears;
  int? get currentActiveYear => _currentActiveYear;

  Iterable<E> getHistoryTracks(Map<int, List<E>> history) sync* {
    final map = history;
    for (final trs in map.values) {
      yield* trs;
    }
  }

  int dayToMillis(int day) => HistoryManager.dayToMilliseconds(day);

  var _historyDays = <int>[];
  var _historyYears = <int>[];
  int? _currentActiveYear;

  @override
  void initState() {
    _updateDays();
    historyManager.modifiedDays.addListener(_updateDaysAndRefresh);
    super.initState();
  }

  @override
  void dispose() {
    historyManager.modifiedDays.removeListener(_updateDaysAndRefresh);
    super.dispose();
  }

  void _updateDaysAndRefresh() {
    if (mounted) {
      setState(_updateDays);
    }
  }

  void _updateDays() {
    _historyDays = historyManager.historyMap.value.keys.toList();
    _historyYears = historyManager.getHistoryYears();
  }

  void onYearTap(int year, double itemExtent, double dayHeaderExtent, {required bool addJumpPadding}) {
    setState(() => _currentActiveYear = year);

    final dayJumper = HistoryJumpToDayIcon(
      controller: historyManager,
      considerInfoBoxPadding: addJumpPadding,
      itemExtentAndDayHeaderExtent: () => (dayHeaderExtent: dayHeaderExtent, itemExtent: itemExtent),
    );
    final currentDate = dayJumper.getCurrentDateFromScrollPosition();
    final newDate = currentDate?.copyWith(year: year);
    if (newDate != null) dayJumper.scrollToDate(newDate);
  }

  double get yearsRowHeight => 32.0;

  Widget getYearsRowWidget(BuildContext context, void Function(int year) onYearTap) {
    return SizedBox(
      height: yearsRowHeight,
      width: context.width,
      child: ColoredBox(
        color: context.theme.scaffoldBackgroundColor,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                ...historyYears.map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: TapDetector(
                      onTap: () => onYearTap(e),
                      child: AnimatedDecoration(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          color: currentActiveYear == e ? CurrentColor.inst.currentColorScheme.withAlpha(160) : context.theme.cardColor,
                          borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          child: Text(
                            '$e',
                            style: context.textTheme.displaySmall?.copyWith(
                              color: currentActiveYear == e ? Colors.white.withAlpha(240) : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? listenOrderWidget(ItemWithDate watch, S subitem, TextStyle? smallTextStyle) {
    final listens = historyManager.topTracksMapListens[subitem];
    Widget? topRightWidget;
    if (listens != null) {
      final listensLength = listens.length;
      final watchMS = watch.dateAddedMS;
      if (listensLength > 1) {
        final firstListen = listens.firstOrNull;
        if (watchMS == firstListen) {
          topRightWidget = const Icon(
            Broken.cake,
            size: 12.0,
          );
        } else {
          final watchOrder = listens.indexOf(watchMS) + 1;
          topRightWidget = Text(
            '$watchOrder',
            style: smallTextStyle,
          );
        }
      }
    }

    if (topRightWidget != null) {
      topRightWidget = NamidaBlurryContainer(
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6.0.multipliedRadius)),
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        child: topRightWidget,
      );
    }
    return topRightWidget;
  }
}
