import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/setting_dialog_with_text_field.dart';

class AlbumTileCustomization extends StatelessWidget {
  final Color? currentTrackColor;
  const AlbumTileCustomization({super.key, this.currentTrackColor});

  @override
  Widget build(BuildContext context) {
    return NamidaExpansionTile(
      initiallyExpanded: settings.useSettingCollapsedTiles.value,
      leading: const StackedIcon(
        baseIcon: Broken.brush,
        secondaryIcon: Broken.music_dashboard,
      ),
      titleText: lang.ALBUM_TILE_CUSTOMIZATION,
      children: [
        /// Track Number in a small Box
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.card_remove,
            title: lang.DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE,
            subtitle: lang.DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE_SUBTITLE,
            value: settings.displayTrackNumberinAlbumPage.value,
            onChanged: (p0) => settings.save(displayTrackNumberinAlbumPage: !p0),
          ),
        ),

        /// Album Card Top Right Date
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.notification_status,
            title: lang.DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE,
            subtitle: lang.DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE_SUBTITLE,
            onChanged: (p0) => settings.save(albumCardTopRightDate: !p0),
            value: settings.albumCardTopRightDate.value,
          ),
        ),

        /// Force Squared Album Thumbnail
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.crop,
            title: lang.FORCE_SQUARED_ALBUM_THUMBNAIL,
            value: settings.forceSquaredAlbumThumbnail.value,
            onChanged: (p0) {
              settings.save(forceSquaredAlbumThumbnail: !p0);
              if (!p0 && settings.albumThumbnailSizeinList.toInt() != settings.albumListTileHeight.toInt()) {
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    normalTitleStyle: true,
                    isWarning: true,
                    bodyText: lang.FORCE_SQUARED_THUMBNAIL_NOTE,
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: lang.CONFIRM,
                        onPressed: () {
                          settings.save(albumThumbnailSizeinList: settings.albumListTileHeight.value);
                          NamidaNavigator.inst.closeDialog();
                        },
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
            title: lang.STAGGERED_ALBUM_GRID_VIEW,
            value: settings.useAlbumStaggeredGridView.value,
            onChanged: (p0) => settings.save(useAlbumStaggeredGridView: !p0),
          ),
        ),

        /// Album Thumbnail Size in List
        Obx(
          () => CustomListTile(
            icon: Broken.maximize_3,
            title: lang.ALBUM_THUMBNAIL_SIZE_IN_LIST,
            trailingText: "${settings.albumThumbnailSizeinList.toInt()}",
            onTap: () {
              showSettingDialogWithTextField(
                title: lang.ALBUM_THUMBNAIL_SIZE_IN_LIST,
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
            title: lang.HEIGHT_OF_ALBUM_TILE,
            trailingText: "${settings.albumListTileHeight.toInt()}",
            onTap: () {
              showSettingDialogWithTextField(
                title: lang.HEIGHT_OF_ALBUM_TILE,
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
