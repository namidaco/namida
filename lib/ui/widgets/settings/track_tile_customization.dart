import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
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
                  dialog: CustomBlurryDialog(
                    normalTitleStyle: true,
                    isWarning: true,
                    bodyText: Language.inst.FORCE_SQUARED_THUMBNAIL_NOTE,
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: Language.inst.CONFIRM,
                        onPressed: () {
                          stg.save(trackThumbnailSizeinList: stg.trackListTileHeight.value);
                          NamidaNavigator.inst.closeDialog();
                        },
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
            height: stg.trackListTileHeight * 1.5,
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
                    thumbnailSize: SettingsController.inst.trackThumbnailSizeinList.value,
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
                            TrackTilePosition.row1Item1,
                            TrackTilePosition.row1Item2,
                            if (SettingsController.inst.displayThirdItemInEachRow.value) TrackTilePosition.row1Item3,
                          ]
                              .map(
                                (e) => TrackItemSmallBox(
                                  text: SettingsController.inst.trackItem[e]?.label,
                                  onTap: () => _showTrackItemsDialog(e),
                                ),
                              )
                              .addSeparators(separator: const SizedBox(width: 6.0))
                              .toList(),
                        ),
                      ),
                      const SizedBox(
                        height: 4.0,
                      ),
                      FittedBox(
                        child: Row(
                          children: [
                            TrackTilePosition.row2Item1,
                            TrackTilePosition.row2Item2,
                            if (SettingsController.inst.displayThirdItemInEachRow.value) TrackTilePosition.row2Item3,
                          ]
                              .map(
                                (e) => TrackItemSmallBox(
                                  text: SettingsController.inst.trackItem[e]?.label,
                                  onTap: () => _showTrackItemsDialog(e),
                                ),
                              )
                              .addSeparators(separator: const SizedBox(width: 6.0))
                              .toList(),
                        ),
                      ),
                      const SizedBox(
                        height: 4.0,
                      ),
                      if (SettingsController.inst.displayThirdRow.value)
                        FittedBox(
                          child: Row(
                            children: [
                              TrackTilePosition.row3Item1,
                              TrackTilePosition.row3Item2,
                              if (SettingsController.inst.displayThirdItemInEachRow.value) TrackTilePosition.row3Item3,
                            ]
                                .map(
                                  (e) => TrackItemSmallBox(
                                    text: SettingsController.inst.trackItem[e]?.label,
                                    onTap: () => _showTrackItemsDialog(e),
                                  ),
                                )
                                .addSeparators(separator: const SizedBox(width: 6.0))
                                .toList(),
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
                    ...[
                      TrackTilePosition.rightItem1,
                      TrackTilePosition.rightItem2,
                    ]
                        .map(
                          (e) => TrackItemSmallBox(
                            text: SettingsController.inst.trackItem[e]?.label,
                            onTap: () => _showTrackItemsDialog(e),
                          ),
                        )
                        .addSeparators(separator: const SizedBox(height: 3.0))
                        .toList(),
                    if (SettingsController.inst.displayFavouriteIconInListTile.value) ...[
                      const SizedBox(height: 3.0),
                      const NamidaLikeButton(
                        track: null,
                        size: 20,
                      ),
                    ]
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

  _showTrackItemsDialog(TrackTilePosition p) {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
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
                active: SettingsController.inst.trackItem[p] == trItem,
              );
            },
            itemCount: TrackTileItem.values.length,
            itemExtents: null,
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
