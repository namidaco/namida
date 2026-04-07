import 'package:flutter/material.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

Future<void> showSettingDialogWithTextField({
  Widget? topWidget,
  String title = '',
  IconData? icon,
  bool trackThumbnailSizeinList = false,
  bool trackListTileHeight = false,
  bool albumThumbnailSizeinList = false,
  bool albumListTileHeight = false,
  bool borderRadiusMultiplier = false,
  bool fontScaleFactor = false,
  bool dateTimeFormat = false,
  bool trackTileSeparator = false,
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
  }) {
    snackyy(
      title: title ?? '',
      message: "${lang.resetToDefault}: $message",
      animationDurationMS: 400,
      icon: icon,
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
          IconButton(
            tooltip: lang.restoreDefaults,
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
            text: lang.save,
            onTap: () {
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

                NamidaNavigator.inst.closeDialog();
                Player.inst.refreshRxVariables();
              }
            },
          ),
        ],
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            ?topWidget,
            Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: CustomTagTextField(
                keyboardType: dateTimeFormat || trackTileSeparator ? TextInputType.text : TextInputType.number,
                controller: controller,
                hintText: lang.value,
                labelText: '',
                validator: (value) {
                  if (fontScaleFactor) {
                    if ((double.parse(value!) < 50 || double.parse(value) > 200)) {
                      return lang.valueBetween50200;
                    }
                  }
                  if (borderRadiusMultiplier) {
                    if ((double.parse(value!) < 0 || double.parse(value) > 5)) {
                      return '0.0-5.0';
                    }
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
