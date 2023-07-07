import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showTrackListensDialog(Track track, {List<int>? datesOfListen, ThemeData? theme, bool enableBlur = false}) async {
  datesOfListen ??= HistoryController.inst.topTracksMapListens[track] ?? [];
  theme ??= AppThemes.inst.getAppTheme(await CurrentColor.inst.getTrackDelightnedColor(track), !Get.isDarkMode);

  if (datesOfListen.isEmpty) return;
  datesOfListen.sortByReverse((e) => e);

  NamidaNavigator.inst.navigateDialog(
    CustomBlurryDialog(
      normalTitleStyle: true,
      title: Language.inst.TOTAL_LISTENS,
      enableBlur: enableBlur,
      trailingWidgets: [
        Text(
          '${datesOfListen.length}',
          style: Get.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
        ),
      ],
      child: SizedBox(
        height: Get.height * 0.5,
        width: Get.width,
        child: NamidaListView(
          padding: EdgeInsets.zero,
          itemBuilder: (context, i) {
            final t = datesOfListen![i];
            return SmallListTile(
              key: ValueKey(i),
              borderRadius: 14.0,
              title: t.dateAndClockFormattedOriginal,
              leading: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                    color: theme?.cardColor,
                  ),
                  child: Text((datesOfListen.length - i).toString())),
              onTap: () async {
                final daysKeys = HistoryController.inst.historyDays.toList();
                daysKeys.removeWhere((element) => element <= t.toDaysSinceEpoch());
                final daysToScroll = daysKeys.length + 1;
                int tracksToScroll = 0;
                daysKeys.loop((e, index) {
                  tracksToScroll += HistoryController.inst.historyMap.value[e]?.length ?? 0;
                });
                final trackSmallList = HistoryController.inst.historyMap.value[t.toDaysSinceEpoch()]!;
                final indexOfSmallList = trackSmallList.indexWhere((element) => element.dateAdded == t);
                tracksToScroll += indexOfSmallList;
                tracksToScroll -= 2;
                NamidaOnTaps.inst.onHistoryPlaylistTap(
                  indexToHighlight: indexOfSmallList,
                  dayOfHighLight: t.toDaysSinceEpoch(),
                  initialScrollOffset: (tracksToScroll * Dimensions.inst.trackTileItemExtent) + (daysToScroll * kHistoryDayHeaderHeightWithPadding),
                );
              },
            );
          },
          itemCount: datesOfListen.length,
          itemExtents: null,
        ),
      ),
    ),
  );
}
