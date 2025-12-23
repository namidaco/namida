import 'dart:async';

import 'package:flutter/material.dart';

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
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showTrackListensDialog(Track track, {List<int> datesOfListen = const [], Color? colorScheme}) {
  final ogYearDate = DateTime.tryParse(track.year.toString())?.millisecondsSinceEpoch.dateFormattedOriginal;
  final subtitle = ogYearDate ?? track.year.yearFormatted;
  showListensDialog(
    datesOfListen: datesOfListen.isNotEmpty ? datesOfListen : HistoryController.inst.topTracksMapListens.value[track] ?? [],
    subtitle: subtitle,
    colorScheme: colorScheme,
    colorSchemeFunction: () => CurrentColor.inst.getTrackDelightnedColor(track, null, useIsolate: true),
    colorSchemeFunctionSync: () => CurrentColor.inst.getTrackDelightnedColorSync(track, null, useIsolate: true),
    onListenTap: (listen) => NamidaOnTaps.inst.onHistoryPlaylistTap(initialListen: listen),
  );
}

void showListensDialog({
  required List<int> datesOfListen,
  required String? subtitle,
  required Future<Color?> Function()? colorSchemeFunction,
  required Color? Function()? colorSchemeFunctionSync,
  required Color? colorScheme,
  required void Function(int listen) onListenTap,
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
          return AnimatedThemeOrTheme(
            data: theme,
            child: CustomBlurryDialog(
              theme: theme,
              normalTitleStyle: true,
              title: lang.TOTAL_LISTENS,
              titleWidgetInPadding: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.TOTAL_LISTENS,
                    style: theme.textTheme.displayLarge,
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: theme.textTheme.displaySmall,
                    ),
                ],
              ),
              trailingWidgets: [
                Text(
                  '${datesOfListen.length}',
                  style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8.0),
                ObxO(
                  rx: settings.heatmapListensView,
                  builder: (context, heatmapListensView) => NamidaIconButton(
                    icon: heatmapListensView ? Broken.row_vertical : Broken.calendar_1,
                    iconSize: heatmapListensView ? 18.0 : 20.0,
                    onPressed: () => settings.save(heatmapListensView: !settings.heatmapListensView.value),
                  ),
                ),
              ],
              child: SizedBox(
                height: namida.height * 0.5,
                width: namida.width,
                child: ObxO(
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
                                    Text(
                                      '$monthsAgo$monthListensText',
                                      style: theme.textTheme.displaySmall,
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
                                bgColor: dialogColor.withAlpha((listens * 5).clampInt(0, 255)), // *5 since 50 listens a days is already a lot
                                borderRadius: 6.0,
                                onTap: datesMapByDay[date] == null ? null : () => onListenTap(date.millisecondsSinceEpoch),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("${date.day}", style: theme.textTheme.displaySmall),
                                    if (listens > 0) ...[
                                      const SizedBox(height: 2.0),
                                      Text("$listens", style: theme.textTheme.displaySmall?.copyWith(fontSize: 9.0)),
                                    ]
                                  ],
                                ),
                              );
                            },
                          ));
                    } else {
                      return NamidaListView(
                        listBottomPadding: 0,
                        itemBuilder: (context, indexPre) {
                          final i = datesOfListen.length - indexPre - 1;
                          final t = datesOfListen[i];
                          return SmallListTile(
                            key: ValueKey(i),
                            borderRadius: 14.0,
                            title: t.dateAndClockFormattedOriginal,
                            subtitle: TimeAgoController.dateMSSEFromNow(t),
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                                color: theme.cardColor,
                              ),
                              child: Text((i + 1).toString()),
                            ),
                            onTap: () => onListenTap(t),
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
          );
        }),
  );
}
