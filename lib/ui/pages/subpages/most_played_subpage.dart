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

class MostPlayedItemsPage<T extends ItemWithDate, E> extends StatelessWidget {
  final HistoryManager<T, E> historyController;
  final void Function({required MostPlayedTimeRange? mptr, DateRange? dateCustom, bool? isStartOfDay}) onSavingTimeRange;
  final double itemExtent;
  final Widget? Function(Widget timeRangeChips, double bottomPadding)? header;
  final Widget Function(Widget timeRangeChips, double bottomPadding, double maxWidth)? infoBox;
  final Widget Function(BuildContext context, int i) itemBuilder;
  final int itemsCount;
  final bool isInFullPage;

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
  });

  void _onSelectingTimeRange({
    required MostPlayedTimeRange mptr,
    DateRange? dateCustom,
    bool? isStartOfDay,
  }) {
    if (mptr != .custom && dateCustom == null) {
      final now = DateTime.now();
      final oldest = historyController.resolveOldDate(mptr, now, isStartOfDay, null);
      if (oldest != null) {
        dateCustom = DateRange(oldest: oldest, newest: now);
      }
    }
    onSavingTimeRange(mptr: mptr, dateCustom: dateCustom, isStartOfDay: isStartOfDay);
    historyController.updateTempMostPlayedPlaylist(
      mptr: mptr,
      customDateRange: dateCustom,
      isStartOfDay: isStartOfDay,
    );
    NamidaNavigator.inst.closeDialog();
  }

  // bool _isCustomChipSelected({
  //   DateRange? dateCustom,
  //   required MostPlayedTimeRange mptr,
  // }) {
  //   if (mptr == .custom && dateCustom != null) {
  //     final now = DateTime.now();
  //     final oldest = historyController.resolveOldDate(mptr, now, null, dateCustom);
  //     if (oldest != null) {
  //       final range = DateRange(oldest: oldest, newest: now);

  //       return dateCustom.oldest.difference(range.oldest) < const Duration(days: 1) && //
  //           dateCustom.newest.difference(range.newest) < const Duration(days: 1);
  //     }
  //   }
  //   return false;
  // }

  Widget _getChipChild({
    required BuildContext context,
    DateRange? dateCustom,
    required MostPlayedTimeRange mptr,
    bool dense = false,
  }) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final dateText = dateCustom == null || dateCustom == DateRange.dummy()
        ? null
        : "${dateCustom.oldest.dateFormattedOriginalNoYears(dateCustom.newest)} → ${dateCustom.newest.dateFormattedOriginalNoYears(dateCustom.oldest)}";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: ObxO(
        rx: historyController.currentMostPlayedTimeRange,
        builder: (context, activeChip) {
          final isActive = activeChip == mptr;
          final textColor = isActive ? const Color.fromARGB(200, 255, 255, 255) : null;
          final chipTextStyle = textTheme.displaySmall?.copyWith(
            color: textColor,
            fontSize: dateText == null
                ? null
                : dense
                ? 11.0
                : 12.0,
            fontWeight: FontWeight.w600,
          );
          return TapDetector(
            onTap: () => _onSelectingTimeRange(
              dateCustom: dateCustom,
              mptr: mptr,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(horizontal: dense ? 8.0 : 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: isActive ? CurrentColor.inst.currentColorScheme.withAlpha(160) : theme.cardColor,
                borderRadius: BorderRadius.circular(dense ? 6.0.multipliedRadius : 8.0.multipliedRadius),
              ),
              child: FittedBox(
                alignment: AlignmentDirectional.centerStart,
                fit: .scaleDown,
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    if (dateCustom == null || dateCustom == DateRange.dummy())
                      Text(
                        mptr.toText(),
                        style: chipTextStyle,
                        softWrap: false,
                      )
                    else ...[
                      NamidaInkWell(
                        borderRadius: 4.0,
                        bgColor: theme.cardColor.withOpacityExt(0.2),
                        padding: const EdgeInsetsGeometry.symmetric(horizontal: 4.0, vertical: 2.0),
                        onTap: () {
                          showCalendarDialog(
                            title: lang.choose,
                            buttonText: lang.confirm,
                            useHistoryDates: true,
                            historyController: historyController,
                            calendarType: NamidaCalendarDatePickerType.single,
                            lastDate: dateCustom.newest,
                            onGenerate: (dates) {
                              final newDate = dates.first;
                              _onSelectingTimeRange(
                                dateCustom: DateRange(oldest: newDate, newest: dateCustom.newest),
                                mptr: MostPlayedTimeRange.custom,
                              );
                            },
                          );
                        },
                        child: Text(
                          dateCustom.oldest.dateFormattedOriginal,
                          style: chipTextStyle,
                          softWrap: false,
                        ),
                      ),
                      Row(
                        mainAxisSize: .min,
                        children: [
                          Text(
                            '⤷ ',
                            style: chipTextStyle,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 1.0),
                            child: NamidaInkWell(
                              borderRadius: 4.0,
                              bgColor: theme.cardColor.withOpacityExt(0.2),
                              padding: const EdgeInsetsGeometry.symmetric(horizontal: 4.0, vertical: 2.0),
                              onTap: () {
                                showCalendarDialog(
                                  title: lang.choose,
                                  buttonText: lang.confirm,
                                  useHistoryDates: true,
                                  historyController: historyController,
                                  calendarType: NamidaCalendarDatePickerType.single,
                                  firstDate: dateCustom.oldest,
                                  onGenerate: (dates) {
                                    final newDate = dates.first;
                                    _onSelectingTimeRange(
                                      dateCustom: DateRange(oldest: dateCustom.oldest, newest: newDate),
                                      mptr: MostPlayedTimeRange.custom,
                                    );
                                  },
                                );
                              },
                              child: Text(
                                dateCustom.newest.dateFormattedOriginal,
                                style: chipTextStyle,
                                softWrap: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget getChipsRow(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final mostplayedOptions = List<MostPlayedTimeRange>.from(MostPlayedTimeRange.values)..remove(MostPlayedTimeRange.custom);

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
                rx: historyController.currentMostPlayedTimeRange,
                builder: (context, activeChip) => NamidaInkWell(
                  animationDurationMS: 200,
                  borderRadius: 6.0,
                  bgColor: theme.cardTheme.color,
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    border: activeChip == MostPlayedTimeRange.custom ? Border.all(color: CurrentColor.inst.color) : null,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Broken.calendar,
                        size: 18.0,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        lang.custom,
                        style: textTheme.displayMedium,
                      ),
                      const SizedBox(width: 4.0),
                      const Icon(
                        Broken.arrow_down_2,
                        size: 14.0,
                      ),
                    ],
                  ),
                  onTap: () {
                    showCalendarDialog(
                      title: lang.choose,
                      buttonText: lang.confirm,
                      useHistoryDates: true,
                      historyController: historyController,
                      onGenerate: (dates) => _onSelectingTimeRange(
                        dateCustom: DateRange(oldest: dates.first, newest: dates.last),
                        mptr: MostPlayedTimeRange.custom,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 4.0),
              Expanded(
                child: SmoothSingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: mostplayedOptions
                        .map(
                          (timeRange) => _getChipChild(
                            context: context,
                            mptr: timeRange,
                          ),
                        )
                        .toFixedList(),
                  ),
                ),
              ),
            ],
          ),
          if (isInFullPage) const SizedBox(height: 2.0),
          if (isInFullPage)
            ObxO(
              rx: historyController.mostPlayedCustomDateRange,
              builder: (context, customRange) => ObxO(
                rx: historyController.currentMostPlayedTimeRange,
                builder: (context, mptr) {
                  final oldestMS = historyController.oldestTrack?.dateAddedMS;
                  final newestMS = historyController.newestTrack?.dateAddedMS;
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
                  final rangesCount = (totalDaysInBetween / effectiveRangePrefferedInterval.inDays).ceil();

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

                  return LayoutWidthProvider(
                    builder: (context, maxWidth) {
                      final customChipWidth = maxWidth * 0.27;
                      final sliderWidth = maxWidth - customChipWidth;
                      return Row(
                        children: [
                          FittedBox(
                            fit: .scaleDown,
                            child: ObxO(
                              rx: historyController.mostPlayedCustomDateRange,
                              builder: (context, dateRange) => SizedBox(
                                width: customChipWidth,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 6.0),
                                  child: _getChipChild(
                                    context: context,
                                    mptr: MostPlayedTimeRange.custom,
                                    dateCustom: dateRange,
                                    dense: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: sliderWidth,
                            child: Row(
                              children: [
                                const SizedBox(width: 12.0),
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
                                    // thumbColor: isSliderDifferentFromSelected ? Colors.transparent : null,
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
                            ),
                          ),
                        ],
                      );
                    },
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
    if (!isInFullPage) return bottomWidget;

    final theme = context.theme;
    const bottomPadding = 0.0;
    final headerWidget = ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: header?.call(bottomWidget, bottomPadding),
    );

    return BackgroundWrapper(
      child: infoBox == null
          // -- different widget just to put scrollbar under header x.x
          ? Column(
              children: [
                headerWidget,
                Expanded(
                  child: NamidaScrollbarWithController(
                    child: (sc) => SuperSmoothListView.builder(
                      controller: sc,
                      padding: const EdgeInsets.only(bottom: Dimensions.globalBottomPaddingTotal),
                      itemExtent: itemExtent,
                      itemBuilder: itemBuilder,
                      itemCount: itemsCount,
                    ),
                  ),
                ),
              ],
            )
          : NamidaListViewRaw(
              infoBox: (maxWidth) => infoBox!(bottomWidget, bottomPadding, maxWidth),
              slivers: [
                SliverMainAxisGroup(
                  slivers: [
                    PinnedHeaderSliver(
                      child: headerWidget,
                    ),
                    SliverFixedExtentList.builder(
                      itemExtent: itemExtent,
                      itemBuilder: itemBuilder,
                      itemCount: itemsCount,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
