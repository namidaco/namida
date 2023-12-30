import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import 'package:paged_vertical_calendar/paged_vertical_calendar.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showTrackListensDialog(Track track, {List<int> datesOfListen = const [], Color? colorScheme}) async {
  showListensDialog(
    datesOfListen: datesOfListen.isNotEmpty ? datesOfListen : HistoryController.inst.topTracksMapListens[track] ?? [],
    colorScheme: colorScheme,
    colorSchemeFunction: () async => await CurrentColor.inst.getTrackDelightnedColor(track, useIsolate: true),
    onListenTap: (listen) {
      final scrollInfo = HistoryController.inst.getListenScrollPosition(
        listenMS: listen,
        extraItemsOffset: 2,
      );
      NamidaOnTaps.inst.onHistoryPlaylistTap(
        indexToHighlight: scrollInfo.indexOfSmallList,
        dayOfHighLight: scrollInfo.dayToHighLight,
        initialScrollOffset: (scrollInfo.itemsToScroll * Dimensions.inst.trackTileItemExtent) + (scrollInfo.daysToScroll * kHistoryDayHeaderHeightWithPadding),
      );
    },
  );
}

void showListensDialog({
  required List<int> datesOfListen,
  required Future<Color?> Function()? colorSchemeFunction,
  required Color? colorScheme,
  required void Function(int listen) onListenTap,
}) async {
  if (datesOfListen.isEmpty) return;
  datesOfListen.sortByReverse((e) => e);

  final color = (colorScheme ?? CurrentColor.inst.color).obs;

  if (colorScheme == null && colorSchemeFunction != null) {
    colorSchemeFunction().executeWithMinDelay(delayMS: 100).then((c) {
      if (c != null && c != color.value) color.value = c;
    });
  }

  final datesMapByDay = <DateTime, List<DateTime>>{};
  final datesMapByMonth = <DateTime, List<DateTime>>{};
  for (final d in datesOfListen) {
    final date = DateTime.fromMillisecondsSinceEpoch(d);
    final dayDate = DateTime(date.year, date.month, date.day);
    final monthDate = DateTime(date.year, date.month);
    datesMapByDay.addForce(dayDate, date);
    datesMapByMonth.addForce(monthDate, date);
  }

  final firstListen = DateTime.fromMillisecondsSinceEpoch(datesOfListen.last);
  final lastListen = DateTime.fromMillisecondsSinceEpoch(datesOfListen.first);

  NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      color.close();
    },
    lighterDialogColor: false,
    dialog: StreamBuilder(
        initialData: color.value,
        stream: color.stream,
        builder: (context, snapshot) {
          final theme = AppThemes.inst.getAppTheme(snapshot.data, null, false);
          return AnimatedTheme(
            data: theme,
            child: CustomBlurryDialog(
              theme: theme,
              normalTitleStyle: true,
              title: lang.TOTAL_LISTENS,
              trailingWidgets: [
                Text(
                  '${datesOfListen.length}',
                  style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8.0),
                Obx(
                  () => NamidaIconButton(
                    icon: settings.heatmapListensView.value ? Broken.row_vertical : Broken.calendar_1,
                    iconSize: settings.heatmapListensView.value ? 18.0 : 20.0,
                    onPressed: () => settings.save(heatmapListensView: !settings.heatmapListensView.value),
                  ),
                ),
              ],
              child: SizedBox(
                height: Get.height * 0.5,
                width: Get.width,
                child: Obx(
                  () => settings.heatmapListensView.value
                      ? Padding(
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
                              final monthsDateJiffy = Jiffy.parseFromDateTime(monthDate);
                              final monthsAgo = monthsDateJiffy.fromNow();
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.filled(
                                          dots,
                                          Padding(
                                            padding: const EdgeInsets.all(2.0),
                                            child: CircleAvatar(
                                              backgroundColor: color.value,
                                              maxRadius: 5.0,
                                              minRadius: 2.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      monthsDateJiffy.format(pattern: 'MMMM yyyy'),
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
                                decoration: BoxDecoration(border: isToday ? Border.all(color: color.value) : null),
                                margin: const EdgeInsets.all(2.0),
                                bgColor: color.value.withAlpha((listens * 5).clamp(0, 255)), // *5 since 50 listens a days is already a lot
                                borderRadius: 6.0,
                                onTap: datesMapByDay[date] == null ? null : () => onListenTap(date.millisecondsSinceEpoch),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("${date.day}", style: theme.textTheme.displaySmall),
                                    if (listens > 0) ...[
                                      const SizedBox(height: 2.0),
                                      Text("$listens", style: theme.textTheme.displaySmall?.copyWith(fontSize: 9.0.multipliedFontScale)),
                                    ]
                                  ],
                                ),
                              );
                            },
                          ))
                      : NamidaListView(
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, i) {
                            final t = datesOfListen[i];
                            return SmallListTile(
                              key: ValueKey(i),
                              borderRadius: 14.0,
                              title: t.dateAndClockFormattedOriginal,
                              subtitle: Jiffy.parseFromMillisecondsSinceEpoch(t).fromNow(),
                              leading: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                                    color: theme.cardColor,
                                  ),
                                  child: Text((datesOfListen.length - i).toString())),
                              onTap: () => onListenTap(t),
                            );
                          },
                          itemCount: datesOfListen.length,
                          itemExtents: null,
                        ),
                ),
              ),
            ),
          );
        }),
  );
}
