import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:history_manager/history_manager.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class MostPlayedItemsPage<T extends ItemWithDate, E> extends StatelessWidget {
  final HistoryManager<T, E> historyController;
  final bool Function(MostPlayedTimeRange type) isTimeRangeChipEnabled;
  final void Function({required MostPlayedTimeRange? mptr, DateRange? dateCustom, bool? isStartOfDay}) onSavingTimeRange;
  final List<double>? itemExtents;
  final Widget Function(Widget timeRangeChips, double bottomPadding) header;
  final Widget Function(BuildContext context, int i, RxMap<E, List<int>> listensMap) itemBuilder;
  final Rx<DateRange> customDateRange;

  const MostPlayedItemsPage({
    super.key,
    required this.historyController,
    required this.isTimeRangeChipEnabled,
    required this.onSavingTimeRange,
    required this.itemExtents,
    required this.header,
    required this.itemBuilder,
    required this.customDateRange,
  });

  void _onSelectingTimeRange({
    required MostPlayedTimeRange? mptr,
    DateRange? dateCustom,
    bool? isStartOfDay,
  }) {
    onSavingTimeRange(mptr: mptr, dateCustom: dateCustom, isStartOfDay: isStartOfDay);

    historyController.updateTempMostPlayedPlaylist(
      mptr: mptr,
      customDateRange: dateCustom,
      isStartOfDay: isStartOfDay,
    );
    NamidaNavigator.inst.closeDialog();
  }

  bool _isEnabled(MostPlayedTimeRange type) => isTimeRangeChipEnabled(type);

  Widget _getChipChild({
    required BuildContext context,
    DateRange? dateCustom,
    required MostPlayedTimeRange mptr,
    Widget? Function(Color? textColor)? trailing,
  }) {
    final dateText = dateCustom == null || dateCustom == DateRange.dummy()
        ? null
        : "${dateCustom.oldest.millisecondsSinceEpoch.dateFormattedOriginalNoYears(dateCustom.newest)} → ${dateCustom.newest.millisecondsSinceEpoch.dateFormattedOriginalNoYears(dateCustom.oldest)}";

    final textColor = _isEnabled(mptr) ? const Color.fromARGB(200, 255, 255, 255) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: TapDetector(
        onTap: () => _onSelectingTimeRange(
          dateCustom: dateCustom,
          mptr: mptr,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: _isEnabled(mptr) ? CurrentColor.inst.currentColorScheme.withAlpha(160) : context.theme.cardColor,
            borderRadius: BorderRadius.circular(8.0.multipliedRadius),
          ),
          child: Row(
            children: [
              Text(
                dateText ?? mptr.toText(),
                style: context.textTheme.displaySmall?.copyWith(
                  color: textColor,
                  fontSize: dateText == null ? null : 12.0.multipliedFontScale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 2.0),
                trailing(textColor)!,
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget getChipsRow(BuildContext context) {
    final mostplayedOptions = List<MostPlayedTimeRange>.from(MostPlayedTimeRange.values)..remove(MostPlayedTimeRange.custom);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const SizedBox(width: 8.0),
          NamidaInkWell(
            animationDurationMS: 200,
            borderRadius: 6.0,
            bgColor: context.theme.cardTheme.color,
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: _isEnabled(MostPlayedTimeRange.custom) ? Border.all(color: CurrentColor.inst.color) : null,
            ),
            child: Row(
              children: [
                const Icon(Broken.calendar, size: 18.0),
                const SizedBox(width: 4.0),
                Text(
                  lang.CUSTOM,
                  style: context.textTheme.displayMedium,
                ),
                const SizedBox(width: 4.0),
                const Icon(Broken.arrow_down_2, size: 14.0),
              ],
            ),
            onTap: () {
              showCalendarDialog(
                title: lang.CHOOSE,
                buttonText: lang.CONFIRM,
                useHistoryDates: true,
                onGenerate: (dates) => _onSelectingTimeRange(
                  dateCustom: DateRange(oldest: dates.first, newest: dates.last),
                  mptr: MostPlayedTimeRange.custom,
                ),
              );
            },
          ),
          const SizedBox(width: 4.0),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Obx(
                    () {
                      final dateRange = customDateRange.value;
                      return _getChipChild(
                        context: context,
                        mptr: MostPlayedTimeRange.custom,
                        dateCustom: dateRange,
                        trailing: (textColor) => NamidaIconButton(
                          padding: EdgeInsets.zero,
                          icon: Broken.close_circle,
                          iconSize: 14.0,
                          iconColor: textColor,
                          onPressed: () => _onSelectingTimeRange(mptr: MostPlayedTimeRange.allTime, dateCustom: DateRange.dummy()),
                        ),
                      ).animateEntrance(
                        showWhen: dateRange.oldest != DateTime(0),
                        durationMS: 400,
                        reverseDurationMS: 200,
                      );
                    },
                  ),
                  ...mostplayedOptions.map(
                    (action) => _getChipChild(
                      context: context,
                      mptr: action,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomWidget = getChipsRow(context);
    const bottomPadding = 0.0;
    return BackgroundWrapper(
      child: Obx(
        () {
          final finalListenMap = historyController.currentTopTracksMapListens;
          return NamidaListView(
            itemExtents: itemExtents,
            header: header(bottomWidget, bottomPadding),
            padding: kBottomPaddingInsets,
            itemCount: finalListenMap.length,
            itemBuilder: (context, i) => itemBuilder(context, i, finalListenMap),
          );
        },
      ),
    );
  }
}
