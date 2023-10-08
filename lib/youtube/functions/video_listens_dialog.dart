import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/yt_utils.dart';

void showVideoListensDialog(String videoId, {List<int>? datesOfListen, Color? colorScheme}) async {
  datesOfListen ??= YoutubeHistoryController.inst.topTracksMapListens[videoId] ?? [];

  if (datesOfListen.isEmpty) return;
  datesOfListen.sortByReverse((e) => e);

  NamidaNavigator.inst.navigateDialog(
    colorScheme: colorScheme,
    lighterDialogColor: false,
    dialogBuilder: (theme) => CustomBlurryDialog(
      theme: theme,
      normalTitleStyle: true,
      title: lang.TOTAL_LISTENS,
      trailingWidgets: [
        Text(
          '${datesOfListen!.length}',
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
                    color: theme.cardColor,
                  ),
                  child: Text((datesOfListen.length - i).toString())),
              onTap: () async {
                final scrollInfo = YoutubeHistoryController.inst.getListenScrollPosition(
                  listenMS: t,
                  extraItemsOffset: 2,
                );

                final totalItemsExtent = scrollInfo.itemsToScroll * Dimensions.youtubeCardItemExtent;
                final totalDaysExtent = scrollInfo.daysToScroll * kYoutubeHistoryDayHeaderHeightWithPadding;

                YTUtils.onYoutubeHistoryPlaylistTap(
                  indexToHighlight: scrollInfo.indexOfSmallList,
                  dayOfHighLight: scrollInfo.dayToHighLight,
                  initialScrollOffset: totalItemsExtent + totalDaysExtent,
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
