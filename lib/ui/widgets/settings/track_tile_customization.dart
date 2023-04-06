import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
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
    return ExpansionTile(
      initiallyExpanded: SettingsController.inst.useSettingCollapsedTiles.value,
      leading: const StackedIcon(
        baseIcon: Broken.brush,
        secondaryIcon: Broken.music_circle,
      ),
      title: Text(
        Language.inst.TRACK_TILE_CUSTOMIZATION,
        style: context.textTheme.displayMedium,
      ),
      trailing: const Icon(Broken.arrow_down_2),
      children: [
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.crop,
            title: Language.inst.FORCE_SQUARED_TRACK_THUMBNAIL,
            onChanged: (value) {
              stg.save(forceSquaredTrackThumbnail: !value);
              if (!value && stg.trackThumbnailSizeinList.toInt() != stg.trackListTileHeight.toInt()) {
                Get.dialog(
                  CustomBlurryDialog(
                    normalTitleStyle: true,
                    isWarning: true,
                    bodyText: Language.inst.FORCE_SQUARED_THUMBNAIL_NOTE,
                    actions: [
                      const CancelButton(),
                      ElevatedButton(
                        onPressed: () {
                          stg.save(trackThumbnailSizeinList: stg.trackListTileHeight.value);
                          Get.close(1);
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
                    path: allTracksInLibrary.isEmpty ? null : allTracksInLibrary.first.pathToImage,
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
                      NamidaLikeButton(
                        track: kDummyTrack,
                        size: 20,
                        isDummy: true,
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

  _showTrackItemsDialog(TrackTilePosition p, TrackTileItem rowItemInSetting) async {
    await Get.dialog(
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Theme(
          data: AppThemes.inst.getAppTheme(CurrentColor.inst.color.value, !Get.isDarkMode),
          child: Dialog(
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.all(64.0),
            child: ListView(
              children: [
                const SizedBox(height: 8.0),
                SmallListTile(
                  title: Language.inst.NONE,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.none);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.none,
                ),
                SmallListTile(
                  title: Language.inst.TITLE,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.title);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.title,
                ),
                SmallListTile(
                  title: Language.inst.ARTISTS,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.artists);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.artists,
                ),
                SmallListTile(
                  title: Language.inst.ALBUM,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.album);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.album,
                ),
                SmallListTile(
                  title: Language.inst.ALBUM_ARTIST,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.albumArtist);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.albumArtist,
                ),
                SmallListTile(
                  title: Language.inst.GENRES,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.genres);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.genres,
                ),
                SmallListTile(
                  title: Language.inst.COMPOSER,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.composer);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.composer,
                ),
                SmallListTile(
                  title: Language.inst.YEAR,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.year);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.year,
                ),
                SmallListTile(
                  title: Language.inst.BITRATE,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.bitrate);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.bitrate,
                ),
                SmallListTile(
                  title: Language.inst.CHANNELS,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.channels);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.channels,
                ),
                SmallListTile(
                  title: Language.inst.COMMENT,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.comment);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.comment,
                ),
                SmallListTile(
                  title: Language.inst.DATE_ADDED,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.dateAdded);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.dateAdded,
                ),
                SmallListTile(
                  title: Language.inst.DATE_MODIFIED,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.dateModified);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.dateModified,
                ),
                SmallListTile(
                  title: "${Language.inst.DATE_MODIFIED} (${Language.inst.CLOCK})",
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.dateModifiedClock);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.dateModifiedClock,
                ),
                SmallListTile(
                  title: "${Language.inst.DATE_MODIFIED} (${Language.inst.DATE})",
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.dateModifiedDate);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.dateModifiedDate,
                ),
                SmallListTile(
                  title: Language.inst.DISC_NUMBER,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.discNumber);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.discNumber,
                ),
                SmallListTile(
                  title: Language.inst.TRACK_NUMBER,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.trackNumber);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.trackNumber,
                ),
                SmallListTile(
                  title: Language.inst.DURATION,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.duration);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.duration,
                ),
                SmallListTile(
                  title: Language.inst.FILE_NAME,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.fileName);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.fileName,
                ),
                SmallListTile(
                  title: Language.inst.FILE_NAME_WO_EXT,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.fileNameWOExt);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.fileNameWOExt,
                ),
                SmallListTile(
                  title: Language.inst.EXTENSION,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.extension);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.extension,
                ),
                SmallListTile(
                  title: Language.inst.FOLDER_NAME,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.folder);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.folder,
                ),
                SmallListTile(
                  title: Language.inst.FORMAT,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.format);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.format,
                ),
                SmallListTile(
                  title: Language.inst.PATH,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.path);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.path,
                ),
                SmallListTile(
                  title: Language.inst.SAMPLE_RATE,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.sampleRate);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.sampleRate,
                ),
                SmallListTile(
                  title: Language.inst.SIZE,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.size);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.size,
                ),
                SmallListTile(
                  title: Language.inst.YEAR,
                  onTap: () {
                    SettingsController.inst.updateTrackItemList(p, TrackTileItem.year);
                    Get.close(1);
                  },
                  active: rowItemInSetting == TrackTileItem.year,
                ),
                const SizedBox(height: 8.0),
              ],
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
    return Material(
      color: context.theme.colorScheme.background.withAlpha(160),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0.multipliedRadius)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: text != null
              ? Text(
                  text!,
                  style: context.theme.textTheme.displaySmall,
                )
              : child,
        ),
      ),
    );
  }
}
