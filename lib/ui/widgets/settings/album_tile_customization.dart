import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/setting_dialog_with_text_field.dart';

class AlbumTileCustomization extends StatelessWidget {
  final Color? currentTrackColor;
  AlbumTileCustomization({super.key, this.currentTrackColor});

  final SettingsController stg = SettingsController.inst;
  @override
  Widget build(BuildContext context) {
    return NamidaExpansionTile(
      initiallyExpanded: SettingsController.inst.useSettingCollapsedTiles.value,
      leading: const StackedIcon(
        baseIcon: Broken.brush,
        secondaryIcon: Broken.music_dashboard,
      ),
      titleText: Language.inst.ALBUM_TILE_CUSTOMIZATION,
      children: [
        /// Track Number in a small Box
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.card_remove,
            title: Language.inst.DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE,
            subtitle: Language.inst.DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE_SUBTITLE,
            value: stg.displayTrackNumberinAlbumPage.value,
            onChanged: (p0) => stg.save(displayTrackNumberinAlbumPage: !p0),
          ),
        ),

        /// Album Card Top Right Date
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.notification_status,
            title: Language.inst.DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE,
            subtitle: Language.inst.DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE_SUBTITLE,
            onChanged: (p0) => stg.save(albumCardTopRightDate: !p0),
            value: stg.albumCardTopRightDate.value,
          ),
        ),

        /// Force Squared Album Thumbnail
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.crop,
            title: Language.inst.FORCE_SQUARED_ALBUM_THUMBNAIL,
            value: stg.forceSquaredAlbumThumbnail.value,
            onChanged: (p0) {
              stg.save(forceSquaredAlbumThumbnail: !p0);
              if (!p0 && stg.albumThumbnailSizeinList.toInt() != stg.albumListTileHeight.toInt()) {
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    normalTitleStyle: true,
                    isWarning: true,
                    bodyText: Language.inst.FORCE_SQUARED_THUMBNAIL_NOTE,
                    actions: [
                      const CancelButton(),
                      ElevatedButton(
                        onPressed: () {
                          stg.save(albumThumbnailSizeinList: stg.albumListTileHeight.value);
                          NamidaNavigator.inst.closeDialog();
                        },
                        child: Text(Language.inst.CONFIRM),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),

        /// Staggered Album Gridview
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.element_4,
            title: Language.inst.STAGGERED_ALBUM_GRID_VIEW,
            value: stg.useAlbumStaggeredGridView.value,
            onChanged: (p0) => stg.save(useAlbumStaggeredGridView: !p0),
          ),
        ),

        /// Album Thumbnail Size in List
        Obx(
          () => CustomListTile(
            icon: Broken.maximize_3,
            title: Language.inst.ALBUM_THUMBNAIL_SIZE_IN_LIST,
            trailingText: "${stg.albumThumbnailSizeinList.toInt()}",
            onTap: () {
              showSettingDialogWithTextField(
                title: Language.inst.ALBUM_THUMBNAIL_SIZE_IN_LIST,
                albumThumbnailSizeinList: true,
                iconWidget: const Icon(Broken.maximize_3),
              );
            },
          ),
        ),

        /// Album Tile Height
        Obx(
          () => CustomListTile(
            icon: Broken.pharagraphspacing,
            title: Language.inst.HEIGHT_OF_ALBUM_TILE,
            trailingText: "${stg.albumListTileHeight.toInt()}",
            onTap: () {
              showSettingDialogWithTextField(
                title: Language.inst.HEIGHT_OF_ALBUM_TILE,
                albumListTileHeight: true,
                iconWidget: const Icon(Broken.pharagraphspacing),
              );
            },
          ),
        ),
      ],
    );
  }
}
