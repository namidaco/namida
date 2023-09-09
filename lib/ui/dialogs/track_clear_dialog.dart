import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showTrackClearDialog(List<Selectable> tracksPre, Color colorScheme) {
  final tracks = tracksPre.uniqued((element) => element.track);
  final isSingle = tracks.length == 1;
  NamidaNavigator.inst.navigateDialog(
    dialogBuilder: (theme) => CustomBlurryDialog(
      theme: theme,
      normalTitleStyle: true,
      icon: Broken.trash,
      title: isSingle ? lang.CLEAR_TRACK_ITEM : lang.CLEAR_TRACK_ITEM_MULTIPLE.replaceFirst('_NUMBER_', tracks.length.formatDecimal()),
      child: Column(
        children: [
          if (tracks.hasVideoCached)
            CustomListTile(
              passedColor: colorScheme,
              title: isSingle ? lang.VIDEO_CACHE_FILE : lang.VIDEO_CACHE_FILES,
              icon: Broken.video,
              onTap: () async {
                await EditDeleteController.inst.deleteCachedVideos(tracks);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          if (tracks.hasLyricsCached)
            CustomListTile(
              passedColor: colorScheme,
              title: lang.LYRICS,
              icon: Broken.document,
              onTap: () async {
                await EditDeleteController.inst.deleteLyrics(tracks);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          if (tracks.hasArtworkCached)
            CustomListTile(
              passedColor: colorScheme,
              title: isSingle ? lang.ARTWORK : lang.ARTWORKS,
              icon: Broken.image,
              onTap: () async {
                await EditDeleteController.inst.deleteArtwork(tracks);
                NamidaNavigator.inst.closeDialog();
              },
            ),
        ],
      ),
    ),
  );
}
