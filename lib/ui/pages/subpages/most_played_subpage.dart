import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class MostPlayedItemsPage<T extends ItemWithDate, E> extends StatefulWidget {
  final HistoryManager<T, E> historyController;
  final void Function({required MostPlayedTimeRange? mptr, DateRange? dateCustom, bool? isStartOfDay}) onSavingTimeRange;
  final double itemExtent;
  final Widget? Function(Widget timeRangeChips, double bottomPadding)? header;
  final Widget Function(Widget timeRangeChips, double bottomPadding, double maxWidth)? infoBox;
  final Widget Function(BuildContext context, int i) itemBuilder;
  final int itemsCount;
  final bool isInFullPage;
  final VoidCallback? onTimeRangeChanged;

  const MostPlayedItemsPage({
    super.key,
    required this.historyController,
    required this.onSavingTimeRange,
    required this.itemExtent,
    required this.header,
    required this.infoBox,
    required this.itemBuilder,
    required this.itemsCount,
    required this.isInFullPage,
    this.onTimeRangeChanged,
  });

  @override
  State<MostPlayedItemsPage<T, E>> createState() => _MostPlayedItemsPageState<T, E>();
}

class _MostPlayedItemsPageState<T extends ItemWithDate, E> extends State<MostPlayedItemsPage<T, E>> {
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    if (widget.isInFullPage) _scrollController = NamidaScrollController.create();
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  void _onTimeRangeChanged() {
    widget.onTimeRangeChanged?.call();
    try {
      final sc = _scrollController;
      if (sc != null && sc.hasClients) sc.jumpTo(0);
    } catch (_) {}
  }

  void _onSelectingTimeRange({
    required MostPlayedTimeRange mptr,
    DateRange? dateCustom,
    bool? isStartOfDay,
  }) {
    if (mptr != .custom && dateCustom == null) {
      final now = DateTime.now();
      final oldest = widget.historyController.resolveOldDate(mptr, now, isStartOfDay, null);
      if (oldest != null) {
        dateCustom = DateRange(oldest: oldest, newest: now);
      }
    }
    widget.onSavingTimeRange(mptr: mptr, dateCustom: dateCustom, isStartOfDay: isStartOfDay);
    widget.historyController.updateTempMostPlayedPlaylist(
      mptr: mptr,
      customDateRange: dateCustom,
      isStartOfDay: isStartOfDay,
    );
    _onTimeRangeChanged();
    NamidaNavigator.inst.closeDialog();
  }

  static const _kDayMS = Duration.millisecondsPerDay;
  static final _kMinValidHistoryDate = DateTime(1971);

  int? _oldestValidHistoryMS() {
    final map = widget.historyController.historyMap.value;
    final oldestValidDay = map.lastKeyBefore(_kMinValidHistoryDate.toDaysSince1970()) ?? map.lastKey();
    return oldestValidDay == null ? null : HistoryManager.daysSince1970ToMilliseconds(oldestValidDay);
  }

  DateRange? _resolveDisplayRange(MostPlayedTimeRange mptr, DateRange storedRange) {
    if (mptr == MostPlayedTimeRange.custom) {
      return storedRange.newest.isAfter(storedRange.oldest) ? storedRange : null;
    }
    final now = DateTime.now();
    final oldest = widget.historyController.resolveOldDate(mptr, now, null, null);
    if (oldest == null) return null;
    final oldestValidMS = _oldestValidHistoryMS();
    return DateRange(
      oldest: oldestValidMS != null && oldest.millisecondsSinceEpoch < oldestValidMS ? DateTime.fromMillisecondsSinceEpoch(oldestValidMS) : oldest,
      newest: now,
    );
  }

  Widget _getStartOfDayButton(BuildContext context) {
    return ObxO(
      rx: widget.historyController.mostPlayedCustomIsStartOfDay,
      builder: (context, isStartOfDay) => NamidaPopupWrapper(
        openOnLongPress: false,
        childrenDefault: () {
          final mptr = widget.historyController.currentMostPlayedTimeRange.value;
          final now = DateTime.now();
          return [
            NamidaPopupItem(
              icon: Broken.calendar_1,
              title: lang.day,
              subtitle: widget.historyController.resolveOldDate(mptr, now, true, null)?.dateFormattedOriginal ?? '',
              selected: isStartOfDay,
              onTap: () => _onSelectingTimeRange(mptr: mptr, isStartOfDay: true),
            ),
            NamidaPopupItem(
              icon: Broken.clock,
              title: lang.clock,
              subtitle: widget.historyController.resolveOldDate(mptr, now, false, null)?.dateAndClockFormattedOriginal ?? '',
              selected: !isStartOfDay,
              onTap: () => _onSelectingTimeRange(mptr: mptr, isStartOfDay: false),
            ),
          ];
        },
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(
            Broken.setting_4,
            size: 18.0,
          ),
        ),
      ),
    );
  }

  DateRange _rangeCenteredOnDay(DateTime day, int daysRadius) {
    final centerMS = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch + _kDayMS ~/ 2;
    final radiusMS = daysRadius * _kDayMS;
    return DateRange(
      oldest: DateTime.fromMillisecondsSinceEpoch(centerMS - radiusMS),
      newest: DateTime.fromMillisecondsSinceEpoch(centerMS + radiusMS),
    );
  }

  void _showDaysRadiusPicker({required DateRange currentRange, required int daysRadius, required int maxDaysRadius}) {
    final centerMS = (currentRange.oldest.millisecondsSinceEpoch + currentRange.newest.millisecondsSinceEpoch) ~/ 2;
    final centerDate = DateTime.fromMillisecondsSinceEpoch(centerMS);
    final centerDay = DateTime(centerDate.year, centerDate.month, centerDate.day);
    final daysRadiusRx = daysRadius.obs;
    showCalendarDialog(
      title: lang.custom,
      buttonText: lang.confirm,
      useHistoryDates: true,
      historyController: widget.historyController,
      calendarType: NamidaCalendarDatePickerType.single,
      initialDate: centerDay,
      initialSelection: [centerDay],
      onDisposing: daysRadiusRx.close,
      bottomWidget: Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: ObxO(
          rx: daysRadiusRx,
          builder: (context, radius) => NamidaWheelSlider(
            min: 1,
            max: maxDaysRadius,
            initValue: daysRadius,
            onValueChanged: (val) => daysRadiusRx.value = val,
            text: '± ${radius.displayDayKeyword}',
          ),
        ),
      ),
      onGenerate: (dates) => _onSelectingTimeRange(
        dateCustom: _rangeCenteredOnDay(dates.first, daysRadiusRx.value),
        mptr: .custom,
      ),
    );
  }

  // bool _isCustomChipSelected({
  //   DateRange? dateCustom,
  //   required MostPlayedTimeRange mptr,
  // }) {
  //   if (mptr == .custom && dateCustom != null) {
  //     final now = DateTime.now();
  //     final oldest = widget.historyController.resolveOldDate(mptr, now, null, dateCustom);
  //     if (oldest != null) {
  //       final range = DateRange(oldest: oldest, newest: now);

  //       return dateCustom.oldest.difference(range.oldest) < const Duration(days: 1) && //
  //           dateCustom.newest.difference(range.newest) < const Duration(days: 1);
  //     }
  //   }
  //   return false;
  // }

  void _showCustomRangePicker() {
    showCalendarDialog(
      title: lang.choose,
      buttonText: lang.confirm,
      useHistoryDates: true,
      historyController: widget.historyController,
      onGenerate: (dates) => _onSelectingTimeRange(
        dateCustom: DateRange(oldest: dates.first, newest: dates.last),
        mptr: MostPlayedTimeRange.custom,
      ),
    );
  }

  Widget _getDateButton({
    required BuildContext context,
    required DateTime date,
    required TextStyle? style,
    DateTime? firstDate,
    DateTime? lastDate,
    required void Function(DateTime newDate) onPick,
  }) {
    return NamidaInkWell(
      borderRadius: 4.0,
      bgColor: context.theme.cardColor,
      padding: const EdgeInsetsGeometry.symmetric(horizontal: 6.0, vertical: 4.0),
      onTap: () {
        showCalendarDialog(
          title: lang.choose,
          buttonText: lang.confirm,
          useHistoryDates: true,
          historyController: widget.historyController,
          calendarType: NamidaCalendarDatePickerType.single,
          firstDate: firstDate,
          lastDate: lastDate,
          initialDate: date,
          initialSelection: [DateTime(date.year, date.month, date.day)],
          onGenerate: (dates) => onPick(dates.first),
        );
      },
      child: Text(
        date.dateFormattedOriginal,
        style: style,
        softWrap: false,
        maxLines: 1,
      ),
    );
  }

  Widget getChipsRow(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              const SizedBox(width: 8.0),
              ObxO(
                rx: widget.historyController.currentMostPlayedTimeRange,
                builder: (context, activeRange) => NamidaPopupWrapper(
                  openOnLongPress: false,
                  childrenDefault: () => MostPlayedTimeRange.values.map(
                    (e) => NamidaPopupItem(
                      icon: e.toIcon(),
                      title: e.toText(),
                      selected: e == activeRange,
                      onTap: () => e == MostPlayedTimeRange.custom ? _showCustomRangePicker() : _onSelectingTimeRange(mptr: e),
                    ),
                  ),
                  child: NamidaInkWell(
                    animationDurationMS: 200,
                    borderRadius: 6.0,
                    bgColor: theme.cardTheme.color,
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      border: activeRange == MostPlayedTimeRange.custom ? Border.all(color: CurrentColor.inst.color) : null,
                    ),
                    child: Row(
                      mainAxisSize: .min,
                      children: [
                        Icon(
                          activeRange.toIcon(),
                          size: 18.0,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          activeRange.toText(),
                          style: textTheme.displayMedium,
                        ),
                        const SizedBox(width: 6.0),
                        const Icon(
                          Broken.arrow_down_2,
                          size: 14.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6.0),
              Expanded(
                child: ObxO(
                  rx: widget.historyController.currentMostPlayedTimeRange,
                  builder: (context, mptr) => ObxO(
                    rx: widget.historyController.mostPlayedCustomDateRange,
                    builder: (context, storedRange) {
                      final dateRange = _resolveDisplayRange(mptr, storedRange);
                      if (dateRange == null) return const SizedBox();
                      final dateTextStyle = textTheme.displaySmall?.copyWith(fontSize: 12.0, fontWeight: FontWeight.w600);
                      return FittedBox(
                        fit: .scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: .min,
                          children: [
                            _getDateButton(
                              context: context,
                              date: dateRange.oldest,
                              style: dateTextStyle,
                              lastDate: dateRange.newest,
                              onPick: (newDate) => _onSelectingTimeRange(
                                dateCustom: DateRange(oldest: newDate, newest: dateRange.newest),
                                mptr: MostPlayedTimeRange.custom,
                              ),
                            ),
                            Text(
                              ' → ',
                              style: dateTextStyle,
                            ),
                            _getDateButton(
                              context: context,
                              date: dateRange.newest,
                              style: dateTextStyle,
                              firstDate: dateRange.oldest,
                              onPick: (newDate) => _onSelectingTimeRange(
                                dateCustom: DateRange(oldest: dateRange.oldest, newest: newDate),
                                mptr: MostPlayedTimeRange.custom,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              _getStartOfDayButton(context),
              const SizedBox(width: 4.0),
            ],
          ),
          if (widget.isInFullPage) const SizedBox(height: 2.0),
          if (widget.isInFullPage)
            ObxO(
              rx: widget.historyController.mostPlayedCustomDateRange,
              builder: (context, customRange) => ObxO(
                rx: widget.historyController.currentMostPlayedTimeRange,
                builder: (context, mptr) {
                  final oldestMS = _oldestValidHistoryMS();
                  final newestMS = widget.historyController.newestTrack?.dateAddedMS;
                  if (oldestMS == null || newestMS == null) return const SizedBox();
                  final oldestDay = oldestMS.toDaysSince1970();
                  final newestDay = newestMS.toDaysSince1970();
                  final totalDaysInBetween = newestDay - oldestDay;

                  final effectiveRangePrefferedInterval = switch (mptr) {
                    MostPlayedTimeRange.custom => customRange.toDurationSafe(),
                    MostPlayedTimeRange.day => const Duration(days: 1),
                    MostPlayedTimeRange.day3 => const Duration(days: 3),
                    MostPlayedTimeRange.week => const Duration(days: 7),
                    MostPlayedTimeRange.month => const Duration(days: 30 * 1),
                    MostPlayedTimeRange.month3 => const Duration(days: 30 * 3),
                    MostPlayedTimeRange.month6 => const Duration(days: 30 * 6),
                    MostPlayedTimeRange.year => const Duration(days: 365),
                    MostPlayedTimeRange.allTime => Duration(days: (totalDaysInBetween / 2).ceil()),
                  };

                  final effectiveRangePrefferedIntervalDays = effectiveRangePrefferedInterval.inDays;
                  final rangesCount = totalDaysInBetween <= 0 || effectiveRangePrefferedIntervalDays <= 0 ? 1 : (totalDaysInBetween / effectiveRangePrefferedIntervalDays).ceil();

                  int rangesCurrentIndex() {
                    final intervalMS = effectiveRangePrefferedInterval.inMilliseconds;
                    if (intervalMS <= 0 || rangesCount <= 0) return 0;
                    final diffMS = customRange.oldest.millisecondsSinceEpoch - oldestMS;
                    return (diffMS / intervalMS).round();
                  }

                  DateRange rangeForIndex(int index) {
                    final intervalMS = effectiveRangePrefferedInterval.inMilliseconds;
                    final rangeStartMS = oldestMS + index * intervalMS;
                    return DateRange(
                      oldest: DateTime.fromMillisecondsSinceEpoch(rangeStartMS),
                      newest: DateTime.fromMillisecondsSinceEpoch(rangeStartMS + intervalMS),
                    );
                  }

                  void selectRangeIndex(int index) {
                    final clamped = index.clampInt(0, rangesCount - 1);
                    _onSelectingTimeRange(
                      dateCustom: rangeForIndex(clamped),
                      mptr: .custom,
                    );
                  }

                  var currentIndex = rangesCurrentIndex();
                  final range = rangeForIndex(currentIndex);
                  final isSliderDifferentFromSelected = range != customRange;
                  final effectiveRange = isSliderDifferentFromSelected ? customRange : range;
                  // -- put to the end if different
                  if (isSliderDifferentFromSelected) currentIndex = rangesCount;

                  final rangeDays = effectiveRange.toDurationSafe().inDays ~/ 2;
                  final daysRadius = rangeDays < 1 ? 1 : rangeDays;
                  final maxDaysRadius = totalDaysInBetween.clampInt(2, 365);

                  return Row(
                    children: [
                      const SizedBox(width: 8.0),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 86.0),
                        child: NamidaInkWell(
                          borderRadius: 6.0,
                          bgColor: theme.cardColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          onTap: () => _showDaysRadiusPicker(
                            currentRange: effectiveRange,
                            daysRadius: daysRadius.clampInt(1, maxDaysRadius),
                            maxDaysRadius: maxDaysRadius,
                          ),
                          child: FittedBox(
                            fit: .scaleDown,
                            child: Text(
                              '± ${daysRadius.displayDayKeyword}',
                              style: textTheme.displaySmall?.copyWith(fontSize: 13.0, fontWeight: FontWeight.w600),
                              softWrap: false,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2.0),
                      _getArrowIcon(
                        icon: Broken.arrow_left_2,
                        callback: () => selectRangeIndex(currentIndex - 1),
                      ),
                      Expanded(
                        child: Slider.adaptive(
                          min: 0,
                          max: isSliderDifferentFromSelected ? rangesCount.toDouble() : (rangesCount - 1).toDouble(),
                          value: currentIndex.toDouble(),
                          onChangeStart: (value) {
                            if (isSliderDifferentFromSelected) {
                              selectRangeIndex((value - 1).round());
                            }
                          },
                          onChanged: (v) {
                            // -- floor cuz adding index can offset (when isSliderDifferentFromSelected == true)
                            selectRangeIndex(v.floor());
                          },
                          divisions: rangesCount > 1 ? rangesCount - 1 : null,
                          thumbColor: isSliderDifferentFromSelected ? theme.colorScheme.primary.withOpacityExt(0.4) : null,
                          label:
                              '${effectiveRange.oldest.dateFormattedOriginalNoYears(effectiveRange.newest)} → ${effectiveRange.newest.dateFormattedOriginalNoYears(effectiveRange.oldest)}',
                        ),
                      ),
                      _getArrowIcon(
                        icon: Broken.arrow_right_3,
                        callback: () => selectRangeIndex(currentIndex + 1),
                      ),
                      const SizedBox(width: 12.0),
                    ],
                  );

                  // -- chips design
                  // return SizedBox(
                  //   height: 28.0,
                  //   child: SuperSmoothListView.builder(
                  //     controller: _extraRangesController,
                  //     // reverse: true,
                  //     scrollDirection: Axis.horizontal,
                  //     itemCount: rangesCount,
                  //     padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  //     itemBuilder: (context, index) {
                  //       // final reverseIndex = rangesCount - 1 - index;
                  //       final intervalCount = index;
                  //       final intervalMS = effectiveRangeInterval.inMilliseconds;
                  //       final rangeStartMS = oldestMS + intervalCount * intervalMS;
                  //       final range = DateRange(
                  //         oldest: DateTime.fromMillisecondsSinceEpoch(rangeStartMS),
                  //         newest: DateTime.fromMillisecondsSinceEpoch(rangeStartMS + intervalMS),
                  //       );
                  //       final isActive = customRange == range;
                  //       final textColor = isActive ? const Color.fromARGB(200, 255, 255, 255) : null;
                  //       final chipTextStyle = textTheme.displaySmall?.copyWith(
                  //         color: textColor,
                  //         fontSize: 12.0,
                  //         fontWeight: FontWeight.w600,
                  //       );

                  //       return TapDetector(
                  //         onTap: () => _onSelectingTimeRange(
                  //           dateCustom: range,
                  //           mptr: .custom,
                  //         ),
                  //         child: AnimatedContainer(
                  //           duration: const Duration(milliseconds: 250),
                  //           margin: const EdgeInsets.symmetric(horizontal: 2.0),
                  //           padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  //           decoration: BoxDecoration(
                  //             color: isActive ? CurrentColor.inst.currentColorScheme.withAlpha(160) : theme.cardColor,
                  //             borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                  //           ),
                  //           child: Row(
                  //             children: [
                  //               NamidaInkWell(
                  //                 borderRadius: 4.0,
                  //                 bgColor: theme.cardColor.withOpacityExt(0.2),
                  //                 padding: const EdgeInsetsGeometry.symmetric(horizontal: 4.0, vertical: 2.0),
                  //                 child: Text(
                  //                   range.oldest.dateFormattedOriginalNoYears(range.newest),
                  //                   style: chipTextStyle,
                  //                 ),
                  //               ),
                  //               Text(
                  //                 ' → ',
                  //                 style: chipTextStyle,
                  //               ),
                  //               NamidaInkWell(
                  //                 borderRadius: 4.0,
                  //                 bgColor: theme.cardColor.withOpacityExt(0.2),
                  //                 padding: const EdgeInsetsGeometry.symmetric(horizontal: 4.0, vertical: 2.0),
                  //                 child: Text(
                  //                   range.newest.dateFormattedOriginalNoYears(range.oldest),
                  //                   style: chipTextStyle,
                  //                 ),
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //       );
                  //     },
                  //   ),
                  // );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _getArrowIcon({required IconData icon, required VoidCallback callback}) {
    return NamidaIconButton(
      verticalPadding: 4.0,
      horizontalPadding: 4.0,
      icon: icon,
      iconSize: 20.0,
      onPressed: () {
        callback();
      },
      onLongPressStart: (_) {
        callback();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomWidget = getChipsRow(context);
    if (!widget.isInFullPage) return bottomWidget;

    final theme = context.theme;
    const bottomPadding = 0.0;
    final headerWidget = ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: widget.header?.call(bottomWidget, bottomPadding),
    );

    return BackgroundWrapper(
      child: widget.infoBox == null
          // -- different widget just to put scrollbar under header x.x
          ? Column(
              children: [
                headerWidget,
                Expanded(
                  child: NamidaScrollbar(
                    controller: _scrollController,
                    child: SuperSmoothListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: Dimensions.globalBottomPaddingTotal),
                      itemExtent: widget.itemExtent,
                      itemBuilder: widget.itemBuilder,
                      itemCount: widget.itemsCount,
                    ),
                  ),
                ),
              ],
            )
          : NamidaListViewRaw(
              scrollController: _scrollController,
              infoBox: (maxWidth) => widget.infoBox!(bottomWidget, bottomPadding, maxWidth),
              slivers: [
                SliverMainAxisGroup(
                  slivers: [
                    PinnedHeaderSliver(
                      child: headerWidget,
                    ),
                    SliverFixedExtentList.builder(
                      itemExtent: widget.itemExtent,
                      itemBuilder: widget.itemBuilder,
                      itemCount: widget.itemsCount,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
