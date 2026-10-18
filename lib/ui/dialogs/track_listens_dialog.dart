import 'dart:async';

import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';
import 'package:intl/intl.dart';
import 'package:paged_vertical_calendar/paged_vertical_calendar.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showTrackListensDialog(Track track, {List<int> datesOfListen = const [], Color? colorScheme}) {
  final ogYearDate = track.yearAsDateTime()?.dateFormattedOriginal;
  final subtitle = ogYearDate ?? track.year.yearFormatted;
  final listens = datesOfListen.isNotEmpty ? datesOfListen : HistoryController.inst.topTracksMapListens.value[track] ?? <int>[];
  showListensDialog(
    datesOfListen: listens,
    subtitle: subtitle,
    colorScheme: colorScheme,
    colorSchemeFunction: () => CurrentColor.inst.getTrackDelightnedColor(track, null),
    colorSchemeFunctionSync: () => CurrentColor.inst.getTrackDelightnedColorSync(track, null),
    onListenTap: (listen) => NamidaOnTaps.inst.onHistoryPlaylistTap(initialListen: listen, listensToNavigate: listens),
    onTopListensRangeTap: (customRange) {
      NamidaOnTaps.inst.onMostPlayedPlaylistTap(
        mptr: .custom,
        dateCustom: customRange,
      );
    },
  );
}

void showListensDialog({
  required List<int> datesOfListen,
  required String? subtitle,
  required Future<Color?> Function()? colorSchemeFunction,
  required Color? Function()? colorSchemeFunctionSync,
  required Color? colorScheme,
  required void Function(int listen) onListenTap,
  required void Function(DateRange customRange) onTopListensRangeTap,
}) async {
  if (datesOfListen.isEmpty) return;

  final color = Colors.transparent.obso;

  void onColorsObtained(Color? newColor) {
    if (newColor != null) {
      color.value = newColor;
    }
  }

  onColorsObtained(colorScheme ?? CurrentColor.inst.color);

  if (colorScheme == null) {
    final colorSync = colorSchemeFunctionSync?.call();
    if (colorSync != null) {
      onColorsObtained(colorSync);
    } else {
      colorSchemeFunction
          ?.call()
          .executeWithMinDelay(
            delayMS: NamidaNavigator.kDefaultDialogDurationMS,
          )
          .then(onColorsObtained);
    }
  }

  late final datesMapByDay = <DateTime, List<DateTime>>{};
  late final datesMapByMonth = <DateTime, List<DateTime>>{};
  void initializeDatesCalendarMapIfNeccessary() {
    if (datesMapByDay.isEmpty && datesMapByMonth.isEmpty) {
      datesOfListen.reverseLoop(
        (d) {
          final date = DateTime.fromMillisecondsSinceEpoch(d);
          final dayDate = DateTime(date.year, date.month, date.day);
          final monthDate = DateTime(date.year, date.month);
          datesMapByDay.addForce(dayDate, date);
          datesMapByMonth.addForce(monthDate, date);
        },
      );
    }
  }

  late final firstListen = DateTime.fromMillisecondsSinceEpoch(datesOfListen.first);
  late final lastListen = DateTime.fromMillisecondsSinceEpoch(datesOfListen.last);

  NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      color.close();
    },
    lighterDialogColor: false,
    dialog: ObxO(
      rx: color,
      builder: (context, dialogColor) {
        final theme = AppThemes.inst.getAppTheme(dialogColor, null, false);
        return NTheme(
          data: theme,
          child: CustomBlurryDialog(
            theme: theme,
            normalTitleStyle: true,
            title: lang.totalListens,
            titleWidgetInPadding: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 24.0),
                  child: NDecoratedBox(
                    decoration: (colors) => BoxDecoration(
                      borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                      color: colors.secondaryContainer.withOpacityExt(0.4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      child: NamidaText(
                        '${datesOfListen.length}',
                        style: const NText(.small, weight: FontWeight.w600),
                        color: NColors.primary,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NamidaText(
                        lang.totalListens,
                        style: NText.large,
                      ),
                      if (subtitle != null && subtitle.isNotEmpty)
                        NamidaText(
                          subtitle,
                          style: NText.small,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                ObxO(
                  rx: settings.heatmapListensView,
                  builder: (context, heatmapListensView) => Row(
                    children: [
                      if (!heatmapListensView)
                        ObxO(
                          rx: settings.reverseListensView,
                          builder: (context, reverseListensView) => NamidaIconButton(
                            horizontalPadding: 6.0,
                            icon: reverseListensView ? Broken.arrow_up_3 : Broken.arrow_down_2,
                            iconSize: 20.0,
                            onPressed: () => settings.reverseListensView.save(!settings.reverseListensView.value),
                          ),
                        ),
                      NamidaIconButton(
                        horizontalPadding: 6.0,
                        icon: heatmapListensView ? Broken.row_vertical : Broken.calendar_1,
                        iconSize: heatmapListensView ? 18.0 : 20.0,
                        onPressed: () => settings.heatmapListensView.save(!settings.heatmapListensView.value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            child: SizedBox(
              height: namida.height * 0.5,
              width: namida.width,
              child: ObxO(
                rx: settings.reverseListensView,
                builder: (context, reverseListensView) => ObxO(
                  rx: settings.heatmapListensView,
                  builder: (context, heatmapListensView) {
                    if (heatmapListensView) {
                      initializeDatesCalendarMapIfNeccessary();
                      return Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: PagedVerticalCalendar(
                          minDate: firstListen.subtract(const Duration(days: 8)),
                          maxDate: lastListen.add(const Duration(days: 8)),
                          initialDate: lastListen,
                          invisibleMonthsThreshold: 3,
                          startWeekWithSunday: true,
                          onDayPressed: (value) => datesMapByDay[value] == null ? null : () => onListenTap(value.millisecondsSinceEpoch),
                          monthBuilder: (context, month, year) {
                            final monthDate = DateTime(year, month);
                            final monthListens = datesMapByMonth[monthDate]?.length ?? 0;
                            final monthListensText = monthListens > 0 ? ' ($monthListens)' : '';
                            final dots = (monthListens / 5).ceil();
                            final monthsDateFormatted = DateFormat('MMMM yyyy').format(monthDate);
                            final monthsAgo = TimeAgoController.dateFromNow(monthDate);
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  SmoothSingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.filled(
                                        dots,
                                        Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: CircleAvatar(
                                            backgroundColor: dialogColor,
                                            maxRadius: 5.0,
                                            minRadius: 2.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    monthsDateFormatted,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  NamidaText(
                                    '$monthsAgo$monthListensText',
                                    style: NText.small,
                                  ),
                                ],
                              ),
                            );
                          },
                          dayBuilder: (context, date) {
                            final isToday = date.toDaysSince1970() == DateTime.now().toDaysSince1970();
                            final listens = datesMapByDay[date]?.length ?? 0;
                            return NamidaInkWell(
                              decoration: BoxDecoration(border: isToday ? Border.all(color: dialogColor) : null),
                              margin: const EdgeInsets.all(2.0),
                              bgColor: NColors.fixed(dialogColor.withOpacityExt((listens * 0.02).clampDouble(0.0, 1.0))), // *0.02 since 50 listens a days is already a lot
                              borderRadius: 6.0,
                              onTap: datesMapByDay[date] == null ? null : () => onListenTap(date.millisecondsSinceEpoch),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  NamidaText(
                                    "${date.day}",
                                    style: NText.small,
                                  ),
                                  if (listens > 0) ...[
                                    const SizedBox(height: 2.0),
                                    NamidaText(
                                      "$listens",
                                      style: const NText(.small, size: .s9),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    } else {
                      return NamidaListView(
                        listBottomPadding: 0,
                        itemBuilder: (context, indexPre) {
                          final i = reverseListensView ? datesOfListen.length - indexPre - 1 : indexPre;
                          final t = datesOfListen[i];
                          return SmallListTile(
                            key: ValueKey(i),
                            borderRadius: 14.0,
                            title: t.dateAndClockFormattedOriginal,
                            subtitle: TimeAgoController.dateMSSEFromNow(t),
                            onTap: () => onListenTap(t),
                            leading: NDecoratedBox(
                              decoration: (colors) => BoxDecoration(
                                borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                color: colors.card,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 8.0),
                                  child: Text(
                                    (i + 1).toString(),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            trailing: NamidaIconButton(
                              icon: null,
                              child: const StackedIcon(
                                baseIcon: Broken.award,
                                secondaryIcon: Broken.export_2,
                                secondaryIconSize: 13.0,
                                delightenColors: true,
                              ),
                              onPressed: () {
                                final listenDate = DateTime.fromMillisecondsSinceEpoch(t);
                                const duration = Duration(days: 60);
                                final customDateRange = DateRange(
                                  oldest: listenDate.subtract(duration),
                                  newest: listenDate.add(duration),
                                );
                                onTopListensRangeTap(customDateRange);
                              },
                            ),
                          );
                        },
                        itemCount: datesOfListen.length,
                        itemExtent: null,
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
