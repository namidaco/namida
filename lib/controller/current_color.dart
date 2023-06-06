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

class CurrentColor {
  static final CurrentColor inst = CurrentColor();

  final Rx<Color> color = playerStaticColor.obs;
  final RxList<Color> palette = <Color>[].obs;

  /// Same fields exists in [Player] class, they can be used but these ones ensure updating the color instantly.
  final RxString currentPlayingTrackPath = ''.obs;
  final RxInt currentPlayingIndex = 0.obs;

  final RxBool generatingAllColorPalettes = false.obs;

  Map<String, List<Color>> colorsMap = {};

  Future<void> updatePlayerColor(Track track, int index) async {
    if (SettingsController.inst.autoColor.value) {
      await setPlayerColor(track);
    }
    currentPlayingTrackPath.value = track.path;
    currentPlayingIndex.value = index;
    updateThemeAndRefresh();
  }

  Future<void> setPlayerColor(Track track) async {
    palette.value = await getTrackColors(track);
    color.value = (generateDelightnedColorFromPalette(palette.toList())).withAlpha(Get.isDarkMode ? 200 : 120);
  }

  Future<List<Color>> getTrackColors(Track track) async {
    return colorsMap[track.path.getFilename] ?? await extractColorsFromImage(track.pathToImage);
  }

  Future<List<Color>> extractColorsFromImage(String pathofimage) async {
    final paletteFile = File("$k_DIR_PALETTES${pathofimage.getFilenameWOExt}.palette");
    final paletteFileStat = await paletteFile.stat();
    List<Color> palette = [];
    if (!await File(pathofimage).exists()) {
      return palette;
    }

    if (await paletteFile.exists() && paletteFileStat.size > 2) {
      final content = await paletteFile.readAsString();
      final pl = List<int>.from(json.decode(content));
      palette.addAll(pl.map((e) => Color(e)));
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
    _updateInColorMap(pathofimage.getFilenameWOExt, palette);
    return palette;
  }

  Future<void> generateAllColorPalettes() async {
    if (!await Directory(k_DIR_PALETTES).exists()) {
      Directory(k_DIR_PALETTES).create();
    }
    generatingAllColorPalettes.value = true;

    for (final tr in allTracksInLibrary) {
      if (!generatingAllColorPalettes.value) {
        break;
      }

      await getTrackColors(tr);
    }

    generatingAllColorPalettes.value = false;
  }

  /// Equivalent to calling [getTrackColors] and [generateDelightnedColorFromPalette].
  Future<Color> getTrackDelightnedColor(Track track) async {
    final colors = await getTrackColors(track);
    return generateDelightnedColorFromPalette(colors).withAlpha(Get.isDarkMode ? 200 : 120);
  }

  Color generateDelightnedColorFromPalette(List<Color> palette) {
    if (palette.isEmpty) {
      return playerStaticColor;
    }
    return mixIntColors(palette.map((e) => e.value).toList());
  }

  /// Returns [playerStaticColor] if [pathToImage] doesnt exist.
  Future<Color> generateDelightnedColorFromImage(String pathToImage) async {
    if (!await File(pathToImage).exists()) {
      return playerStaticColor;
    }

    final finalpalette = await extractColorsFromImage(pathToImage);
    final intpalette = finalpalette.map((e) => e.value).toList();
    return mixIntColors(intpalette);
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
  }

  Future<void> prepareColors() async {
    await for (final d in Directory(k_DIR_PALETTES).list()) {
      try {
        final f = d as File;
        final content = await f.readAsString();
        final pl = List<int>.from(json.decode(content));
        _updateInColorMap(f.path.getFilenameWOExt, pl.map((e) => Color(e)).toList());
      } catch (e) {
        continue;
      }
    }
  }

  void _updateInColorMap(String filenameWoExt, List<Color> pl) {
    colorsMap[filenameWoExt] = pl;
  }
}
