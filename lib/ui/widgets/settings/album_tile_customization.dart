import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/setting_dialog.dart';

class AlbumTileCustomization extends StatelessWidget {
  final Color? currentTrackColor;
  AlbumTileCustomization({super.key, this.currentTrackColor});

  final SettingsController stg = SettingsController.inst;
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ExpansionTile(
        leading: const StackedIcon(
          baseIcon: Broken.brush,
          secondaryIcon: Broken.music_dashboard,
        ),
        title: Text(
          Language.inst.ALBUM_TILE_CUSTOMIZATION,
          style: context.textTheme.displayMedium,
        ),
        trailing: const Icon(
          Broken.arrow_down_2,
        ),
        children: [
          // Track Number in a small Box

          CustomSwitchListTile(
            icon: Broken.card_remove,
            title: Language.inst.DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE,
            subtitle: Language.inst.DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE_SUBTITLE,
            value: stg.displayTrackNumberinAlbumPage.value,
            onChanged: (p0) => stg.displayTrackNumberinAlbumPage.value = !p0,
          ),
          CustomSwitchListTile(
            icon: Broken.notification_status,
            title: Language.inst.DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE,
            subtitle: Language.inst.DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE_SUBTITLE,
            onChanged: (p0) => stg.albumCardTopRightDate.value = !p0,
            value: stg.albumCardTopRightDate.value,
          ),
          CustomSwitchListTile(
            icon: Broken.crop,
            title: Language.inst.FORCE_SQUARED_ALBUM_THUMBNAIL,
            value: stg.forceSquaredAlbumThumbnail.value,
            onChanged: (p0) => stg.forceSquaredAlbumThumbnail.value = !p0,
          ),
          CustomSwitchListTile(
            icon: Broken.element_4,
            title: Language.inst.STAGGERED_ALBUM_GRID_VIEW,
            value: stg.useAlbumStaggeredGridView.value,
            onChanged: (p0) => stg.useAlbumStaggeredGridView.value = !p0,
          ),
          // Album Thumbnail Size in List
          CustomListTile(
            icon: Broken.maximize_3,
            title: Language.inst.ALBUM_THUMBNAIL_SIZE_IN_LIST,
            trailing: Text(
              "${stg.albumThumbnailSizeinList.toInt()}",
              style: context.textTheme.displayMedium?.copyWith(color: Colors.grey[500]),
            ),
            onTap: () {
              showSettingDialogWithTextField(title: Language.inst.ALBUM_THUMBNAIL_SIZE_IN_LIST, albumThumbnailSizeinList: true);
            },
          ),
          // Album Tile Height
          CustomListTile(
            icon: Broken.pharagraphspacing,
            title: Language.inst.HEIGHT_OF_ALBUM_TILE,
            trailing: Text(
              "${stg.albumListTileHeight.toInt()}",
              style: context.textTheme.displayMedium?.copyWith(color: Colors.grey[500]),
            ),
            onTap: () {
              showSettingDialogWithTextField(
                title: Language.inst.HEIGHT_OF_ALBUM_TILE,
                albumListTileHeight: true,
              );
            },
          ),
        ],
      ),
    );
  }
}
