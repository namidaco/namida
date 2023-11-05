import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
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
import 'package:namida/ui/widgets/library/track_tile.dart';

class TrackTileCustomization extends StatelessWidget {
  const TrackTileCustomization({super.key});

  void _onSettingsChanged() => TrackTileManager.onTrackItemPropChange();

  @override
  Widget build(BuildContext context) {
    return NamidaExpansionTile(
      initiallyExpanded: settings.useSettingCollapsedTiles.value,
      leading: const StackedIcon(
        baseIcon: Broken.brush,
        secondaryIcon: Broken.music_circle,
      ),
      titleText: lang.TRACK_TILE_CUSTOMIZATION,
      children: [
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.crop,
            title: lang.FORCE_SQUARED_TRACK_THUMBNAIL,
            value: settings.forceSquaredTrackThumbnail.value,
            onChanged: (value) {
              settings.save(forceSquaredTrackThumbnail: !value);
              Player.inst.refreshRxVariables();
              _onSettingsChanged();
              if (!value && settings.trackThumbnailSizeinList.toInt() != settings.trackListTileHeight.toInt()) {
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
                          settings.save(trackThumbnailSizeinList: settings.trackListTileHeight.value);
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
        Obx(
          () => CustomListTile(
            icon: Broken.maximize_3,
            title: lang.TRACK_THUMBNAIL_SIZE_IN_LIST,
            trailingText: "${settings.trackThumbnailSizeinList.toInt()}",
            onTap: () {
              showSettingDialogWithTextField(
                title: lang.TRACK_THUMBNAIL_SIZE_IN_LIST,
                trackThumbnailSizeinList: true,
                icon: Broken.maximize_3,
              );
            },
          ),
        ),
        Obx(
          () => CustomListTile(
            icon: Broken.pharagraphspacing,
            title: lang.HEIGHT_OF_TRACK_TILE,
            trailingText: "${settings.trackListTileHeight.toInt()}",
            onTap: () {
              showSettingDialogWithTextField(
                title: lang.HEIGHT_OF_TRACK_TILE,
                trackListTileHeight: true,
                icon: Broken.pharagraphspacing,
              );
            },
          ),
        ),
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.chart_1,
            rotateIcon: 1,
            title: lang.DISPLAY_THIRD_ROW_IN_TRACK_TILE,
            onChanged: (isTrue) {
              settings.save(displayThirdRow: !isTrue);
              _onSettingsChanged();
            },
            value: settings.displayThirdRow.value,
          ),
        ),
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.coin,
            rotateIcon: 3,
            title: lang.DISPLAY_THIRD_ITEM_IN_ROW_IN_TRACK_TILE,
            onChanged: (isTrue) {
              settings.save(displayThirdItemInEachRow: !isTrue);
              _onSettingsChanged();
            },
            value: settings.displayThirdItemInEachRow.value,
          ),
        ),
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.heart,
            title: lang.DISPLAY_FAVOURITE_ICON_IN_TRACK_TILE,
            onChanged: (isTrue) {
              settings.save(displayFavouriteIconInListTile: !isTrue);
              _onSettingsChanged();
            },
            value: settings.displayFavouriteIconInListTile.value,
          ),
        ),
        Obx(
          () => CustomListTile(
            icon: Broken.minus_square,
            title: lang.TRACK_TILE_ITEMS_SEPARATOR,
            trailingText: settings.trackTileSeparator.value,
            onTap: () => showSettingDialogWithTextField(
              title: lang.TRACK_TILE_ITEMS_SEPARATOR,
              trackTileSeparator: true,
              icon: Broken.minus_square,
            ),
          ),
        ),
        Obx(
          () => Container(
            color: context.theme.cardTheme.color,
            width: context.width,
            height: settings.trackListTileHeight * 1.5,
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
                  width: settings.trackThumbnailSizeinList.value,
                  height: settings.trackThumbnailSizeinList.value,
                  child: ArtworkWidget(
                    thumbnailSize: settings.trackThumbnailSizeinList.value,
                    path: allTracksInLibrary.firstOrNull?.pathToImage,
                    forceSquared: settings.forceSquaredTrackThumbnail.value,
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
                            if (settings.displayThirdItemInEachRow.value) TrackTilePosition.row1Item3,
                          ]
                              .map(
                                (e) => TrackItemSmallBox(
                                  text: settings.trackItem[e]?.label,
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
                            if (settings.displayThirdItemInEachRow.value) TrackTilePosition.row2Item3,
                          ]
                              .map(
                                (e) => TrackItemSmallBox(
                                  text: settings.trackItem[e]?.label,
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
                      if (settings.displayThirdRow.value)
                        FittedBox(
                          child: Row(
                            children: [
                              TrackTilePosition.row3Item1,
                              TrackTilePosition.row3Item2,
                              if (settings.displayThirdItemInEachRow.value) TrackTilePosition.row3Item3,
                            ]
                                .map(
                                  (e) => TrackItemSmallBox(
                                    text: settings.trackItem[e]?.label,
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
                            text: settings.trackItem[e]?.label,
                            onTap: () => _showTrackItemsDialog(e),
                          ),
                        )
                        .addSeparators(separator: const SizedBox(height: 3.0))
                        .toList(),
                    if (settings.displayFavouriteIconInListTile.value) ...[
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

  void _showTrackItemsDialog(TrackTilePosition p) {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.CHOOSE,
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
                  settings.updateTrackItemList(p, trItem);
                  _onSettingsChanged();
                  NamidaNavigator.inst.closeDialog();
                },
                active: settings.trackItem[p] == trItem,
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
