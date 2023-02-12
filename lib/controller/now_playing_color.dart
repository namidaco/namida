import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/themes.dart';

class CurrentColor extends GetxController {
  static CurrentColor inst = CurrentColor();

  Rx<Color> color = Color.fromARGB(255, 139, 149, 241).obs;
  RxString currentPlayingTrack = ''.obs;

  // CurrentColor() {}
  setPlayerColor(Track track) async {
    if (await File(track.pathToImageComp).exists()) {
      final result = await PaletteGenerator.fromImageProvider(FileImage(File(track.pathToImageComp)));
      final palette = result.colors.toList();
      color.value = getAlbumColorModifiedModern(palette);
      // color.value = result.darkMutedColor?.color ?? result.dominantColor?.color ?? Colors.red;
      // color.value = mixColors([result.mutedColor?.color ?? result.vibrantColor?.color ?? result.darkMutedColor?.color ?? result.darkMutedColor?.color ?? result.dominantColor?.color ?? Colors.red]);
      print(color);
      Get.changeTheme(AppThemes().getAppTheme(color.value));
      currentPlayingTrack.value = track.path;
      update();
    } else {
      color.value = Color.fromARGB(33, 139, 149, 241);
    }
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
    color = Color.alphaBlend(value?.first.withAlpha(140) ?? Colors.transparent, Color.alphaBlend(value?.elementAt(7).withAlpha(155) ?? Colors.transparent, value?.elementAt(9) ?? Colors.transparent));
  } else {
    color = Color.alphaBlend(value?.last.withAlpha(50) ?? Colors.transparent, value?.first ?? Colors.transparent);
  }
  HSLColor hslColor = HSLColor.fromColor(color);
  Color colorDelightened;
//   if (hslColor.lightness > 0.65) {
//   hslColor = hslColor.withLightness(0.45);
//   colorDelightened = hslColor.toColor();
// } else if (hslColor.lightness < 0.35) {
//   hslColor = hslColor.withLightness(0.55);
//   colorDelightened = hslColor.toColor();
// } else {
//   colorDelightened = color;
// }

  if (hslColor.lightness > 0.65) {
    hslColor = hslColor.withLightness(0.45);
    colorDelightened = hslColor.toColor();
  } else {
    colorDelightened = color;
  }
  // colorDelightened = Color.alphaBlend(Colors.black.withAlpha(10), colorDelightened);
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
  double l = hslColor.lightness;
  double lightnessDiff = hslColor.lightness - 0.5;
  if (lightnessDiff > 0) {
    hslColor = hslColor.withLightness(hslColor.lightness - lightnessDiff);
  } else {
    hslColor = hslColor.withLightness(hslColor.lightness + lightnessDiff);
  }
  colorDelightened = hslColor.toColor();
  // if (l >= 0.0 && l < 0.1) colorDelightened = hslColor.withLightness(0.3).toColor();
  // if (l >= 0.1 && l < 0.2) colorDelightened = hslColor.withLightness(0.2).toColor();
  // if (l >= 0.2 && l < 0.3) colorDelightened = hslColor.withLightness(0.5).toColor();
  // if (l >= 0.3 && l < 0.4) colorDelightened = hslColor.withLightness(0.4).toColor();
  // if (l >= 0.4 && l < 0.5) colorDelightened = hslColor.withLightness(0.3).toColor();
  // if (l >= 0.5 && l < 0.6) colorDelightened = hslColor.withLightness(0.1).toColor();
  // if (l >= 0.6 && l < 0.7) colorDelightened = hslColor.withLightness(0.2).toColor();
  // if (l >= 0.7 && l < 0.8) colorDelightened = hslColor.withLightness(0.2).toColor();
  // if (l >= 0.8 && l < 0.9) colorDelightened = hslColor.withLightness(0.2).toColor();

  // hslColor.withLightness(0.5).toColor();
  // colorDelightened = Color.alphaBlend(Colors.white.withAlpha(20), colorDelightened);
  return colorDelightened;
}
