import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showTrackListensDialog(Track track, {List<int>? datesOfListen, ThemeData? theme, bool enableBlur = false}) async {
  // listens ??= namidaHistoryPlaylist.tracks.where((element) => element.track.path == track.path).toList();
  datesOfListen ??= PlaylistController.inst.topTracksMapListens.value[track] ?? [];
  theme ??= AppThemes.inst.getAppTheme(await CurrentColor.inst.getTrackDelightnedColor(track), !Get.isDarkMode);

  if (datesOfListen.isEmpty) return;

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
                final i = namidaHistoryPlaylist.tracks.indexWhere((element) => element.dateAdded == t);
                NamidaOnTaps.inst.onPlaylistTap(
                  namidaHistoryPlaylist,
                  disableAnimation: true,
                  indexToHighlight: i,
                  scrollController: ScrollController(initialScrollOffset: trackTileItemExtent * i),
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
