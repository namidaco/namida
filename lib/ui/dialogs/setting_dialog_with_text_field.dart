import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

Future<void> showSettingDialogWithTextField({
  Widget? topWidget,
  String title = '',
  Widget? iconWidgets,
  IconData? icon,
  bool trackThumbnailSizeinList = false,
  bool trackListTileHeight = false,
  bool albumThumbnailSizeinList = false,
  bool albumListTileHeight = false,
  bool borderRadiusMultiplier = false,
  bool fontScaleFactor = false,
  bool dateTimeFormat = false,
  bool trackTileSeparator = false,
  bool addNewPlaylist = false,
}) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  if (dateTimeFormat) {
    controller.text = settings.dateTimeFormat.value;
  }
  void showResetToDefaultSnackBar(
    String message, {
    String? title,
    Duration? duration,
    Widget? iconWidget,
  }) {
    snackyy(
      title: title ?? '',
      message: "${lang.RESET_TO_DEFAULT}: $message",
      animationDurationMS: 400,
      icon: icon,
      iconWidget: iconWidget,
    );
  }

  void onTTSetChange() {}
  void onTIPropChange() => TrackTileManager.onTrackItemPropChange();

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      controller.dispose();
    },
    dialog: Form(
      key: formKey,
      child: CustomBlurryDialog(
        title: title,
        actions: [
          if (!addNewPlaylist)
            IconButton(
              tooltip: lang.RESTORE_DEFAULTS,
              onPressed: () {
                if (trackThumbnailSizeinList) {
                  settings.save(trackThumbnailSizeinList: 70.0);
                  showResetToDefaultSnackBar("${settings.trackThumbnailSizeinList.value}", title: title);
                  onTTSetChange();
                }
                if (trackListTileHeight) {
                  settings.save(trackListTileHeight: 70.0);
                  showResetToDefaultSnackBar("${settings.trackListTileHeight.value}", title: title);
                  Dimensions.inst.updateTrackTileDimensions();
                  onTTSetChange();
                }
                if (albumThumbnailSizeinList) {
                  settings.save(albumThumbnailSizeinList: 90.0);
                  showResetToDefaultSnackBar("${settings.albumThumbnailSizeinList.value}", title: title);
                }
                if (albumListTileHeight) {
                  settings.save(albumListTileHeight: 90.0);
                  showResetToDefaultSnackBar("${settings.albumListTileHeight.value}", title: title);
                  Dimensions.inst.updateAlbumTileDimensions();
                }

                if (borderRadiusMultiplier) {
                  settings.save(borderRadiusMultiplier: 1.0);
                  showResetToDefaultSnackBar("${settings.borderRadiusMultiplier.value}", title: title);
                }
                if (fontScaleFactor) {
                  settings.save(fontScaleFactor: 0.9);
                  showResetToDefaultSnackBar("${settings.fontScaleFactor.value.toInt() * 100}%", title: title);
                }
                if (dateTimeFormat) {
                  settings.save(dateTimeFormat: 'MMM yyyy');
                  showResetToDefaultSnackBar("${settings.dateTimeFormat}", title: title);
                  onTIPropChange();
                }
                if (trackTileSeparator) {
                  settings.save(trackTileSeparator: '•');
                  showResetToDefaultSnackBar("${settings.trackTileSeparator}", title: title);
                  onTTSetChange();
                  onTIPropChange();
                }

                NamidaNavigator.inst.closeDialog();
                Player.inst.refreshRxVariables();
              },
              icon: const Icon(Broken.refresh),
            ),
          const CancelButton(),
          NamidaButton(
            text: lang.SAVE,
            onPressed: () {
              if (formKey.currentState!.validate()) {
                if (trackThumbnailSizeinList) {
                  settings.save(trackThumbnailSizeinList: double.parse(controller.text));
                  onTTSetChange();
                }
                if (trackListTileHeight) {
                  settings.save(trackListTileHeight: double.parse(controller.text));
                  Dimensions.inst.updateTrackTileDimensions();
                  onTTSetChange();
                }
                if (albumThumbnailSizeinList) {
                  settings.save(albumThumbnailSizeinList: double.parse(controller.text));
                }
                if (albumListTileHeight) {
                  settings.save(albumListTileHeight: double.parse(controller.text));
                  Dimensions.inst.updateAlbumTileDimensions();
                }

                if (borderRadiusMultiplier) {
                  settings.save(borderRadiusMultiplier: double.parse(controller.text));
                }
                if (fontScaleFactor) {
                  settings.save(fontScaleFactor: double.parse(controller.text) / 100);
                }
                if (dateTimeFormat) {
                  settings.save(dateTimeFormat: controller.text);
                  onTTSetChange();
                  onTIPropChange();
                }
                if (trackTileSeparator) {
                  settings.save(trackTileSeparator: controller.text);
                  onTTSetChange();
                  onTIPropChange();
                }
                if (addNewPlaylist) {
                  PlaylistController.inst.addNewPlaylist(controller.text);
                }

                NamidaNavigator.inst.closeDialog();
                Player.inst.refreshRxVariables();
              }
            },
          ),
        ],
        child: Stack(
          alignment: Alignment.bottomCenter,
          // mainAxisSize: MainAxisSize.min,
          children: [
            if (topWidget != null) topWidget,
            Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: TextFormField(
                style: Get.textTheme.displaySmall?.copyWith(fontSize: 16.0.multipliedFontScale, fontWeight: FontWeight.w600),
                autofocus: true,
                keyboardType: dateTimeFormat || trackTileSeparator || addNewPlaylist ? TextInputType.text : TextInputType.number,
                controller: controller,
                textAlign: TextAlign.left,
                decoration: InputDecoration(
                  isDense: true,
                  errorMaxLines: 3,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.0.multipliedRadius),
                    borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 2.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                    borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 1.0),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                    borderSide: BorderSide(color: Colors.brown.withAlpha(200), width: 2.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                    borderSide: BorderSide(color: Colors.brown.withAlpha(200), width: 2.0),
                  ),
                  hintText: addNewPlaylist ? lang.NAME : lang.VALUE,
                ),
                validator: (value) {
                  if (fontScaleFactor) {
                    if ((double.parse(value!) < 50 || double.parse(value) > 200)) {
                      return lang.VALUE_BETWEEN_50_200;
                    }
                  }
                  if (addNewPlaylist) {
                    return PlaylistController.inst.validatePlaylistName(value);
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
