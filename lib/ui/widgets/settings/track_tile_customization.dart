import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/setting_dialog_with_text_field.dart';

class TrackTileCustomization extends StatelessWidget {
  TrackTileCustomization({super.key});

  final SettingsController stg = SettingsController.inst;

  @override
  Widget build(BuildContext context) {
    return NamidaExpansionTile(
      initiallyExpanded: SettingsController.inst.useSettingCollapsedTiles.value,
      leading: const StackedIcon(
        baseIcon: Broken.brush,
        secondaryIcon: Broken.music_circle,
      ),
      titleText: Language.inst.TRACK_TILE_CUSTOMIZATION,
      children: [
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.crop,
            title: Language.inst.FORCE_SQUARED_TRACK_THUMBNAIL,
            onChanged: (value) {
              stg.save(forceSquaredTrackThumbnail: !value);
              if (!value && stg.trackThumbnailSizeinList.toInt() != stg.trackListTileHeight.toInt()) {
                NamidaNavigator.inst.navigateDialog(
                  CustomBlurryDialog(
                    normalTitleStyle: true,
                    isWarning: true,
                    bodyText: Language.inst.FORCE_SQUARED_THUMBNAIL_NOTE,
                    actions: [
                      const CancelButton(),
                      ElevatedButton(
                        onPressed: () {
                          stg.save(trackThumbnailSizeinList: stg.trackListTileHeight.value);
                          NamidaNavigator.inst.closeDialog();
                        },
                        child: Text(Language.inst.CONFIRM),
                      ),
                    ],
                  ),
                );
              }
            },
            value: stg.forceSquaredTrackThumbnail.value,
          ),
        ),
        Obx(
          () => CustomListTile(
            icon: Broken.maximize_3,
            title: Language.inst.TRACK_THUMBNAIL_SIZE_IN_LIST,
            trailingText: "${stg.trackThumbnailSizeinList.toInt()}",
            onTap: () {
              showSettingDialogWithTextField(
                title: Language.inst.TRACK_THUMBNAIL_SIZE_IN_LIST,
                trackThumbnailSizeinList: true,
                iconWidget: const Icon(Broken.maximize_3),
              );
            },
          ),
        ),
        Obx(
          () => CustomListTile(
            icon: Broken.pharagraphspacing,
            title: Language.inst.HEIGHT_OF_TRACK_TILE,
            trailingText: "${stg.trackListTileHeight.toInt()}",
            onTap: () {
              showSettingDialogWithTextField(
                title: Language.inst.HEIGHT_OF_TRACK_TILE,
                trackListTileHeight: true,
                iconWidget: const Icon(Broken.pharagraphspacing),
              );
            },
          ),
        ),
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.chart_1,
            rotateIcon: 1,
            title: Language.inst.DISPLAY_THIRD_ROW_IN_TRACK_TILE,
            onChanged: (_) => stg.save(
              displayThirdRow: !stg.displayThirdRow.value,
            ),
            value: stg.displayThirdRow.value,
          ),
        ),
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.coin,
            rotateIcon: 3,
            title: Language.inst.DISPLAY_THIRD_ITEM_IN_ROW_IN_TRACK_TILE,
            onChanged: (_) => stg.save(
              displayThirdItemInEachRow: !stg.displayThirdItemInEachRow.value,
            ),
            value: stg.displayThirdItemInEachRow.value,
          ),
        ),
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.heart,
            title: Language.inst.DISPLAY_FAVOURITE_ICON_IN_TRACK_TILE,
            onChanged: (_) => stg.save(
              displayFavouriteIconInListTile: !stg.displayFavouriteIconInListTile.value,
            ),
            value: stg.displayFavouriteIconInListTile.value,
          ),
        ),
        Obx(
          () => CustomListTile(
            icon: Broken.minus_square,
            title: Language.inst.TRACK_TILE_ITEMS_SEPARATOR,
            trailingText: stg.trackTileSeparator.value,
            onTap: () => showSettingDialogWithTextField(
              title: Language.inst.TRACK_TILE_ITEMS_SEPARATOR,
              trackTileSeparator: true,
              iconWidget: const Icon(Broken.minus_square),
            ),
          ),
        ),
        Obx(
          () => Container(
            color: context.theme.cardTheme.color,
            width: context.width,
            height: stg.trackListTileHeight * 1.4,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 7.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(
                  width: 12.0,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 0.0,
                  ),
                  width: SettingsController.inst.trackThumbnailSizeinList.value,
                  height: SettingsController.inst.trackThumbnailSizeinList.value,
                  child: ArtworkWidget(
                    thumnailSize: SettingsController.inst.trackThumbnailSizeinList.value,
                    track: allTracksInLibrary.firstOrNull,
                    path: allTracksInLibrary.firstOrNull?.pathToImage,
                    forceSquared: stg.forceSquaredTrackThumbnail.value,
                  ),
                ),
                const SizedBox(
                  width: 12.0,
                ),

                /// Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        child: Row(
                          children: [
                            TrackItemSmallBox(
                              text: SettingsController.inst.trackItem.value.row1Item1.label,
                              onTap: () => _showTrackItemsDialog(TrackTilePosition.row1Item1, SettingsController.inst.trackItem.value.row1Item1),
                            ),
                            const SizedBox(
                              width: 6.0,
                            ),
                            TrackItemSmallBox(
                              text: SettingsController.inst.trackItem.value.row1Item2.label,
                              onTap: () => _showTrackItemsDialog(TrackTilePosition.row1Item2, SettingsController.inst.trackItem.value.row1Item2),
                            ),
                            const SizedBox(
                              width: 6.0,
                            ),
                            if (SettingsController.inst.displayThirdItemInEachRow.value)
                              TrackItemSmallBox(
                                text: SettingsController.inst.trackItem.value.row1Item3.label,
                                onTap: () => _showTrackItemsDialog(TrackTilePosition.row1Item3, SettingsController.inst.trackItem.value.row1Item3),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 4.0,
                      ),
                      FittedBox(
                        child: Row(
                          children: [
                            TrackItemSmallBox(
                              text: SettingsController.inst.trackItem.value.row2Item1.label,
                              onTap: () => _showTrackItemsDialog(TrackTilePosition.row2Item1, SettingsController.inst.trackItem.value.row2Item1),
                            ),
                            const SizedBox(
                              width: 6.0,
                            ),
                            TrackItemSmallBox(
                              text: SettingsController.inst.trackItem.value.row2Item2.label,
                              onTap: () => _showTrackItemsDialog(TrackTilePosition.row2Item2, SettingsController.inst.trackItem.value.row2Item2),
                            ),
                            const SizedBox(
                              width: 6.0,
                            ),
                            if (SettingsController.inst.displayThirdItemInEachRow.value)
                              TrackItemSmallBox(
                                text: SettingsController.inst.trackItem.value.row2Item3.label,
                                onTap: () => _showTrackItemsDialog(TrackTilePosition.row2Item3, SettingsController.inst.trackItem.value.row2Item3),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 4.0,
                      ),
                      if (SettingsController.inst.displayThirdRow.value)
                        FittedBox(
                          child: Row(
                            children: [
                              TrackItemSmallBox(
                                text: SettingsController.inst.trackItem.value.row3Item1.label,
                                onTap: () => _showTrackItemsDialog(TrackTilePosition.row3Item1, SettingsController.inst.trackItem.value.row3Item1),
                              ),
                              const SizedBox(
                                width: 6.0,
                              ),
                              TrackItemSmallBox(
                                text: SettingsController.inst.trackItem.value.row3Item2.label,
                                onTap: () => _showTrackItemsDialog(TrackTilePosition.row3Item2, SettingsController.inst.trackItem.value.row3Item2),
                              ),
                              const SizedBox(
                                width: 6.0,
                              ),
                              if (SettingsController.inst.displayThirdItemInEachRow.value)
                                TrackItemSmallBox(
                                  text: SettingsController.inst.trackItem.value.row3Item3.label,
                                  onTap: () => _showTrackItemsDialog(TrackTilePosition.row3Item3, SettingsController.inst.trackItem.value.row3Item3),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6.0),

                /// Right Items
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TrackItemSmallBox(
                      text: SettingsController.inst.trackItem.value.rightItem1.label,
                      onTap: () => _showTrackItemsDialog(TrackTilePosition.rightItem1, SettingsController.inst.trackItem.value.rightItem1),
                    ),
                    const SizedBox(
                      height: 3.0,
                    ),
                    TrackItemSmallBox(
                      text: SettingsController.inst.trackItem.value.rightItem2.label,
                      onTap: () => _showTrackItemsDialog(TrackTilePosition.rightItem2, SettingsController.inst.trackItem.value.rightItem2),
                    ),
                    const SizedBox(
                      height: 3.0,
                    ),
                    if (SettingsController.inst.displayFavouriteIconInListTile.value)
                      const NamidaLikeButton(
                        track: null,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(width: 6.0),
                const MoreIcon(
                  iconSize: 20,
                ),
                const SizedBox(width: 6.0),
              ],
            ),
          ),
        )
      ],
    );
  }

  _showTrackItemsDialog(TrackTilePosition p, TrackTileItem rowItemInSetting) {
    NamidaNavigator.inst.navigateDialog(
      NamidaBgBlur(
        blur: 5.0,
        child: Theme(
          data: AppThemes.inst.getAppTheme(CurrentColor.inst.color.value, !Get.isDarkMode),
          child: CustomBlurryDialog(
            title: Language.inst.CHOOSE,
            normalTitleStyle: true,
            insetPadding: const EdgeInsets.all(64.0),
            child: SizedBox(
              height: Get.height * 0.5,
              width: Get.width,
              child: NamidaListView(
                padding: EdgeInsets.zero,
                itemBuilder: (context, i) {
                  final trItem = TrackTileItem.values[i];
                  return SmallListTile(
                    key: ValueKey(i),
                    title: trItem.toText(),
                    onTap: () {
                      SettingsController.inst.updateTrackItemList(p, trItem);
                      NamidaNavigator.inst.closeDialog();
                    },
                    active: rowItemInSetting == trItem,
                  );
                },
                itemCount: TrackTileItem.values.length,
                itemExtents: null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TrackItemSmallBox extends StatelessWidget {
  final void Function()? onTap;
  final Widget? child;
  final String? text;
  const TrackItemSmallBox({super.key, this.onTap, this.child, this.text});

  @override
  Widget build(BuildContext context) {
    return NamidaInkWell(
      bgColor: context.theme.colorScheme.background.withAlpha(160),
      onTap: onTap,
      borderRadius: 8.0,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: text != null
          ? Text(
              text!,
              style: context.theme.textTheme.displaySmall,
            )
          : child,
    );
  }
}
