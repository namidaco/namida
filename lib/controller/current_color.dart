import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:palette_generator/palette_generator.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/controller/settings_controller.dart';

Color get playerStaticColor => Color(SettingsController.inst.staticColor.value);

class CurrentColor extends GetxController {
  static CurrentColor inst = CurrentColor();

  Rx<Color> color = playerStaticColor.obs;
  RxString currentPlayingTrackPath = ''.obs;

  Future<void> updatePlayerColor(Track track) async {
    // Checking here will not require restart for changes to take effect
    if (SettingsController.inst.autoColor.value) {
      await setPlayerColor(track);
    }
    currentPlayingTrackPath.value = track.path;
    updateThemeAndRefresh();
  }

  Future<void> setPlayerColor(Track track) async {
    if (await FileSystemEntity.type(track.pathToImageComp) != FileSystemEntityType.notFound) {
      final result = await PaletteGenerator.fromImageProvider(FileImage(File(track.pathToImageComp)));
      final palette = result.colors.toList();
      color.value = getAlbumColorModifiedModern(palette);
      // color.value = result.darkMutedColor?.color ?? result.dominantColor?.color ?? Colors.red;
      // color.value = mixColors([result.mutedColor?.color ?? result.vibrantColor?.color ?? result.darkMutedColor?.color ?? result.darkMutedColor?.color ?? result.dominantColor?.color ?? Colors.red]);
      print(color);
    } else {
      color.value = playerStaticColor;
    }
  }

  void updateThemeAndRefresh() {
    Get.changeTheme(AppThemes.inst.getAppTheme(color.value));
    update();
  }

  @override
  void onClose() {
    Get.delete();
    super.onClose();
  }
}

Color getAlbumColorModifiedModern(List<Color>? value) {
  final Color color;
  if ((value?.length ?? 0) > 9) {
    color = Color.alphaBlend(
        value?.first.withAlpha(140) ?? Colors.transparent, Color.alphaBlend(value?.elementAt(7).withAlpha(155) ?? Colors.transparent, value?.elementAt(9) ?? Colors.transparent));
  } else {
    color = Color.alphaBlend(value?.last.withAlpha(50) ?? Colors.transparent, value?.first ?? Colors.transparent);
  }
  HSLColor hslColor = HSLColor.fromColor(color);
  Color colorDelightened;
  if (hslColor.lightness > 0.65) {
    hslColor = hslColor.withLightness(0.55);
    colorDelightened = hslColor.toColor();
  } else {
    colorDelightened = color;
  }
  colorDelightened = Color.alphaBlend(Colors.white.withAlpha(20), colorDelightened);
  return colorDelightened;
}

// Color getAlbumColorModifiedModern(List<Color>? value) {
//   final Color color;
//   if ((value?.length ?? 0) > 9) {
//     color = Color.alphaBlend(value?.first.withAlpha(140) ?? Colors.transparent, Color.alphaBlend(value?.elementAt(7).withAlpha(155) ?? Colors.transparent, value?.elementAt(9) ?? Colors.transparent));
//   } else {
//     color = Color.alphaBlend(value?.last.withAlpha(50) ?? Colors.transparent, value?.first ?? Colors.transparent);
//   }
//   HSLColor hslColor = HSLColor.fromColor(color);
//   Color colorDelightened;
// //   if (hslColor.lightness > 0.65) {
// //   hslColor = hslColor.withLightness(0.45);
// //   colorDelightened = hslColor.toColor();
// // } else if (hslColor.lightness < 0.35) {
// //   hslColor = hslColor.withLightness(0.55);
// //   colorDelightened = hslColor.toColor();
// // } else {
// //   colorDelightened = color;
// // }

//   if (hslColor.lightness > 0.65) {
//     hslColor = hslColor.withLightness(0.45);
//     colorDelightened = hslColor.toColor();
//   } else {
//     colorDelightened = color;
//   }
//   // colorDelightened = Color.alphaBlend(Colors.black.withAlpha(10), colorDelightened);
//   return colorDelightened;
// }
/// Returns [playerStaticColor] if both was null.
Future<Color> generateDelightnedColor([Track? track, String? pathToImage]) async {
  Color colorDelightened;
  if (track == null && pathToImage == null) {
    return playerStaticColor;
  }
  final finalPath = track?.pathToImageComp ?? pathToImage;
  if (await File(finalPath!).exists()) {
    final palette = await PaletteGenerator.fromImageProvider(FileImage(File(finalPath)));
    colorDelightened = getAlbumColorModifiedModern(palette.colors.toList());
  } else {
    colorDelightened = playerStaticColor;
  }
  return colorDelightened;
}

Color mixColors(List<Color> colors) {
  Color mixedColor = colors[0];
  for (int i = 1; i < colors.length; i++) {
    mixedColor = Color.lerp(mixedColor, colors[i], 0.5) ?? Colors.transparent;
  }
  HSLColor hslColor = HSLColor.fromColor(mixedColor);
  if (hslColor.lightness > 0.65) {
    mixedColor = hslColor.withLightness(0.55).toColor();
  }
  return mixedColor;
}

Color? delightnedColor(Color? color) {
  if (color == null) return null;

  Color colorDelightened;
  HSLColor hslColor = HSLColor.fromColor(color);
  double lightnessDiff = hslColor.lightness - 0.5;
  if (lightnessDiff > 0) {
    hslColor = hslColor.withLightness(hslColor.lightness - lightnessDiff);
  } else {
    hslColor = hslColor.withLightness(hslColor.lightness + lightnessDiff);
  }
  colorDelightened = hslColor.toColor();
  return colorDelightened;
}
