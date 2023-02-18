import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/class/playlist.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:restart_app/restart_app.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showSettingDialogWithTextField({
  Widget? topWidget,
  String title = '',
  Widget? iconWidget,
  bool? trackThumbnailSizeinList,
  bool? trackListTileHeight,
  bool? albumThumbnailSizeinList,
  bool? albumListTileHeight,
  bool? queueSheetMinHeight,
  bool? queueSheetMaxHeight,
  bool? nowPlayingImageContainerHeight,
  bool? borderRadiusMultiplier,
  bool? fontScaleFactor,
  bool? dateTimeFormat,
  bool? trackTileSeparator,
  bool? addNewPlaylist,
}) async {
  SettingsController stg = SettingsController.inst;
  TextEditingController controller = TextEditingController();
  ScrollController scrollController = ScrollController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  void showSnackBarWithTitle(
    String message, {
    String? title,
    Duration? duration,
    Widget? iconWidget,
  }) {
    Get.snackbar(
      '',
      '',
      titleText: Text(
        title ?? '',
        style: Get.textTheme.displayLarge,
      ),
      messageText: Text(
        "${Language.inst.RESET_TO_DEFAULT}: $message",
        style: Get.textTheme.displayMedium,
      ),
      duration: duration ?? const Duration(seconds: 2),
      animationDuration: const Duration(milliseconds: 400),
      borderRadius: 16.0 * stg.borderRadiusMultiplier.value,
      padding: const EdgeInsets.fromLTRB(18.0, 18.0, 24.0, 18.0),
      icon: iconWidget,
      shouldIconPulse: false,
    );
  }

  void restartToApplyChangesSnackBar(
    String title,
    String? message, {
    Duration? duration,
    Widget? iconWidget,
  }) {
    Get.snackbar(
      '',
      '',
      titleText: Text(
        title,
        style: Get.textTheme.displayLarge,
      ),
      messageText: Text(
        "$message${Language.inst.RESTART_TO_APPLY_CHANGES}",
        style: Get.textTheme.displayMedium,
      ),
      duration: const Duration(seconds: 4),
      animationDuration: const Duration(milliseconds: 400),
      borderRadius: 16.0 * stg.borderRadiusMultiplier.value,
      icon: iconWidget,
      padding: const EdgeInsets.fromLTRB(18.0, 18.0, 24.0, 18.0),
      mainButton: TextButton(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(
            Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(150), Get.theme.colorScheme.primary),
          ),
        ),
        onPressed: () => Restart.restartApp(),
        child: Text(
          Language.inst.RESTART,
          style: Get.theme.textTheme.bodyMedium,
        ),
      ),
      shouldIconPulse: false,
    );
  }

  await Get.dialog(
    Form(
      key: formKey,
      child: CustomBlurryDialog(
        title: title,
        actions: [
          if (addNewPlaylist == null)
            IconButton(
              tooltip: Language.inst.RESTORE_DEFAULTS,
              onPressed: () {
                if (trackThumbnailSizeinList != null) {
                  stg.save(
                    trackThumbnailSizeinList: 70.0,
                  );
                  showSnackBarWithTitle("${stg.trackThumbnailSizeinList.value}", title: title, iconWidget: iconWidget);
                }
                if (trackListTileHeight != null) {
                  stg.save(
                    trackListTileHeight: 70.0,
                  );
                  showSnackBarWithTitle("${stg.trackListTileHeight.value}", title: title, iconWidget: iconWidget);
                }
                if (albumThumbnailSizeinList != null) {
                  stg.save(
                    albumThumbnailSizeinList: 90.0,
                  );
                  showSnackBarWithTitle("${stg.albumThumbnailSizeinList.value}", title: title, iconWidget: iconWidget);
                }
                if (albumListTileHeight != null) {
                  stg.save(
                    albumListTileHeight: 90.0,
                  );
                  showSnackBarWithTitle("${stg.albumListTileHeight.value}", title: title, iconWidget: iconWidget);
                }
                if (queueSheetMinHeight != null) {
                  stg.save(
                    queueSheetMinHeight: 25.0,
                  );
                  showSnackBarWithTitle("${stg.queueSheetMinHeight.value}", title: title, iconWidget: iconWidget);
                }
                if (queueSheetMaxHeight != null) {
                  stg.save(
                    queueSheetMaxHeight: 500.0,
                  );
                  showSnackBarWithTitle("${stg.queueSheetMaxHeight.value}", title: title, iconWidget: iconWidget);
                }
                if (nowPlayingImageContainerHeight != null) {
                  stg.save(
                    nowPlayingImageContainerHeight: 400.0,
                  );
                  showSnackBarWithTitle("${stg.nowPlayingImageContainerHeight.value}", title: title, iconWidget: iconWidget);
                }
                if (borderRadiusMultiplier != null) {
                  stg.save(
                    borderRadiusMultiplier: 1.0,
                  );
                  showSnackBarWithTitle("${stg.borderRadiusMultiplier.value}", title: title, iconWidget: iconWidget);
                }
                if (fontScaleFactor != null) {
                  stg.save(
                    fontScaleFactor: 1.0,
                  );
                  restartToApplyChangesSnackBar(title, "${Language.inst.RESET_TO_DEFAULT}: ${stg.fontScaleFactor.value.toInt() * 100}%, ", iconWidget: iconWidget);
                }
                if (dateTimeFormat != null) {
                  stg.save(
                    dateTimeFormat: 'MMM yyyy',
                  );
                  showSnackBarWithTitle("${stg.dateTimeFormat}", title: title, iconWidget: iconWidget);
                }
                if (trackTileSeparator != null) {
                  stg.save(
                    trackTileSeparator: '•',
                  );
                  showSnackBarWithTitle("${stg.trackTileSeparator}", title: title, iconWidget: iconWidget);
                }
                Get.close(1);
              },
              icon: const Icon(Broken.refresh),
            ),
          const CancelButton(),
          ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  if (trackThumbnailSizeinList != null) {
                    stg.save(
                      trackThumbnailSizeinList: double.parse(controller.text),
                    );
                  }
                  if (trackListTileHeight != null) {
                    stg.save(
                      trackListTileHeight: double.parse(controller.text),
                    );
                  }
                  if (albumThumbnailSizeinList != null) {
                    stg.save(
                      albumThumbnailSizeinList: double.parse(controller.text),
                    );
                  }
                  if (albumListTileHeight != null) {
                    stg.save(
                      albumListTileHeight: double.parse(controller.text),
                    );
                  }
                  if (queueSheetMinHeight != null) {
                    // handling the case where the user enters a min value higher than the max
                    if (double.parse(controller.text) > stg.queueSheetMaxHeight.value) {
                      stg.save(
                        queueSheetMinHeight: stg.queueSheetMaxHeight.value,
                      );
                      showSnackBarWithTitle(
                        "${stg.queueSheetMinHeight}, Minimum value can't be less than the maximum",
                        duration: const Duration(seconds: 4),
                        title: title,
                      );
                    } else {
                      stg.save(
                        queueSheetMinHeight: double.parse(controller.text),
                      );
                    }
                  }
                  if (queueSheetMaxHeight != null) {
                    if (double.parse(controller.text) < stg.queueSheetMinHeight.value) {
                      stg.save(
                        queueSheetMaxHeight: stg.queueSheetMinHeight.value,
                      );
                      showSnackBarWithTitle("${stg.queueSheetMaxHeight}, Maximum value can't be more than the minimum", duration: const Duration(seconds: 4), title: title);
                    } else {
                      stg.save(
                        queueSheetMaxHeight: double.parse(controller.text),
                      );
                    }
                  }
                  if (nowPlayingImageContainerHeight != null) {
                    stg.save(
                      nowPlayingImageContainerHeight: double.parse(controller.text),
                    );
                  }
                  if (borderRadiusMultiplier != null) {
                    stg.save(
                      borderRadiusMultiplier: double.parse(controller.text),
                    );
                  }
                  if (fontScaleFactor != null) {
                    stg.save(
                      fontScaleFactor: double.parse(controller.text) / 100,
                    );
                    restartToApplyChangesSnackBar(title, '');
                  }
                  if (dateTimeFormat != null) {
                    stg.save(
                      dateTimeFormat: controller.text,
                    );
                  }
                  if (trackTileSeparator != null) {
                    stg.save(
                      trackTileSeparator: controller.text,
                    );
                  }
                  if (addNewPlaylist != null) {
                    PlaylistController.inst.addNewPlaylist(controller.text);
                  }

                  Get.close(1);
                }
              },
              child: Text(Language.inst.SAVE))
        ],
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 0.0,
                ),
                topWidget != null
                    ? Stack(
                        children: [
                          SingleChildScrollView(controller: scrollController, child: topWidget),
                          Positioned(
                            bottom: 20,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(0.0),
                              decoration: BoxDecoration(color: Get.theme.cardTheme.color, shape: BoxShape.circle),
                              child: IconButton(
                                icon: const Icon(Broken.arrow_circle_down),
                                onPressed: () {
                                  scrollController.position.animateTo(scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                                },
                              ),
                            ),
                          )
                        ],
                      )
                    : const SizedBox.shrink(),
                Padding(
                  padding: const EdgeInsets.only(top: 14.0),
                  child: TextFormField(
                    autofocus: true,
                    keyboardType: dateTimeFormat != null || trackTileSeparator != null || addNewPlaylist != null ? TextInputType.text : TextInputType.number,
                    controller: controller,
                    textAlign: TextAlign.left,
                    decoration: InputDecoration(
                      errorMaxLines: 3,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.0 * stg.borderRadiusMultiplier.value),
                        borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 2.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18.0 * stg.borderRadiusMultiplier.value),
                        borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 1.0),
                      ),
                      hintText: addNewPlaylist != null ? Language.inst.NAME : Language.inst.VALUE,
                    ),
                    validator: (value) {
                      if (fontScaleFactor != null && (double.parse(value!) < 50 || double.parse(value) > 200)) {
                        return Language.inst.VALUE_BETWEEN_50_200;
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    barrierColor: Colors.black.withAlpha(80),
  );
}
