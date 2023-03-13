import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:palette_generator/palette_generator.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/themes.dart';

Color get playerStaticColor => Color(SettingsController.inst.staticColor.value);

class CurrentColor extends GetxController {
  static final CurrentColor inst = CurrentColor();

  Rx<Color> color = playerStaticColor.obs;
  RxList<Color> palette = <Color>[].obs;
  RxString currentPlayingTrackPath = ''.obs;
  RxInt currentPlayingIndex = 0.obs;
  RxBool generatingAllColorPalettes = false.obs;

  Future<void> updatePlayerColor(Track track, int index) async {
    if (SettingsController.inst.autoColor.value) {
      await setPlayerColor(track);
    }
    currentPlayingTrackPath.value = track.path;
    currentPlayingIndex.value = index;
    updateThemeAndRefresh();
  }

  Future<void> setPlayerColor(Track track) async {
    palette.value = await extractColors(track.pathToImage);
    color.value = (await generateDelightnedColor(track.pathToImage, palette.toList())).withAlpha(Get.isDarkMode ? 200 : 100);
  }

  // Future<Color> extractDelightnedColor(String path) async {
  //   if (await FileSystemEntity.type(path) != FileSystemEntityType.notFound) {
  //     final palette = await extractColors(path);
  //     final color = getAlbumColorModifiedModern(palette);
  //     return color;
  //   } else {
  //     return playerStaticColor;
  //   }
  // }

  Future<List<Color>> extractColors(String pathofimage) async {
    final paletteFile = File("$kPaletteDirPath${pathofimage.getFilename}.palette");
    final paletteFileStat = await paletteFile.stat();
    List<Color> palette = [];
    if (FileSystemEntity.typeSync(pathofimage) == FileSystemEntityType.notFound) {
      return palette;
    }

    if (await paletteFile.exists() && paletteFileStat.size > 2) {
      String content = await paletteFile.readAsString();
      final pl = List<int>.from(json.decode(content));
      palette.assignAll(pl.map((e) => Color(e)));
      debugPrint("COLORRRR READ FROM FILE");
    } else {
      // trying to extract from the image that is being used will freeze the extraction
      // if (Player.inst.nowPlayingTrack.value.path == path) {
      //   return palette;
      // }
      final result = await PaletteGenerator.fromImageProvider(FileImage(File(pathofimage)));
      palette.assignAll(result.colors.toList());
      await paletteFile.create();
      await paletteFile.writeAsString(palette.map((e) => e.value).toList().toString());
      Indexer.inst.updateColorPalettesSizeInStorage();
      debugPrint("COLORRRRR EXTRACTED");
    }

    return palette;
  }

  Future<void> generateAllColorPalettes() async {
    if (!await Directory(kPaletteDirPath).exists()) {
      Directory(kPaletteDirPath).create();
    }
    generatingAllColorPalettes.value = true;

    for (var tr in Indexer.inst.tracksInfoList.toList()) {
      if (!generatingAllColorPalettes.value) {
        break;
      }

      await extractColors(tr.pathToImage);
    }

    generatingAllColorPalettes.value = false;
  }

  /// Returns [playerStaticColor] if [pathToImage] was null.
  Future<Color> generateDelightnedColor([String? pathToImage, List<Color>? palette]) async {
    if (pathToImage == null || !await File(pathToImage).exists()) {
      return playerStaticColor;
    }

    final finalpalette = palette ?? await extractColors(pathToImage);
    final colorDelightened = mixIntColors(finalpalette.map((e) => e.value).toList());
    // colorDelightened = getAlbumColorModifiedModern(finalpalette);

    return colorDelightened;
  }

  Color getAlbumColorModifiedModern(List<Color> value) {
    final Color color;
    // return Color.alphaBlend(value.first.withAlpha(220), value.last);

    if ((value.length) > 9) {
      color = Color.alphaBlend(value.first.withAlpha(140), Color.alphaBlend(value.elementAt(7).withAlpha(155), value.elementAt(9)));
    } else {
      color = Color.alphaBlend(value.last.withAlpha(50), value.first);
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

  Color mixIntColors(List<int> colors) {
    int red = 0;
    int green = 0;
    int blue = 0;

    for (int color in colors) {
      red += (color >> 16) & 0xFF;
      green += (color >> 8) & 0xFF;
      blue += color & 0xFF;
    }

    red ~/= colors.length;
    green ~/= colors.length;
    blue ~/= colors.length;

    final hslColor = HSLColor.fromColor(Color.fromARGB(255, red, green, blue));
    final modifiedColor = hslColor.withLightness(0.4).toColor();
    return modifiedColor;
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

