import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:palette_generator/palette_generator.dart';

import 'package:namida/class/color_m.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

Color get playerStaticColor => Color(SettingsController.inst.staticColor.value);

class CurrentColor {
  static CurrentColor get inst => _instance;
  static final CurrentColor _instance = CurrentColor._internal();
  CurrentColor._internal();

  Rx<Color> get color => namidaColor.value.color.obs;
  RxList<Color> get palette => namidaColor.value.palette.obs;

  Rx<NamidaColor> namidaColor = NamidaColor(playerStaticColor, playerStaticColor, [playerStaticColor]).obs;

  Rx<Color> get currentColorScheme => (_colorSchemeOfSubPages.value ?? color.value).obs;
  final Rxn<Color> _colorSchemeOfSubPages = Rxn<Color>();

  RxList<Color> paletteFirstHalf = <Color>[].obs;
  RxList<Color> paletteSecondHalf = <Color>[].obs;

  /// Same fields exists in [Player] class, they can be used but these ones ensure updating the color only after extracting.
  final RxString currentPlayingTrackPath = ''.obs;
  final RxInt currentPlayingIndex = 0.obs;

  /// Used for history playlist where same track can exist in more than one list.
  final Rxn<int> currentPlayingTrackDateAdded = Rxn<int>();

  final RxBool generatingAllColorPalettes = false.obs;

  Map<String, NamidaColor> colorsMap = {};

  Timer? _colorsSwitchTimer;

  int get colorAlpha => Get.isDarkMode ? 200 : 120;

  void switchColorPalettes(bool isPlaying) {
    _colorsSwitchTimer?.cancel();
    _colorsSwitchTimer = null;
    final durms = isPlaying ? 500 : 2000;
    _colorsSwitchTimer = Timer.periodic(Duration(milliseconds: durms), (timer) {
      if (SettingsController.inst.enablePartyModeColorSwap.value) {
        if (paletteFirstHalf.isEmpty) return;

        final lastItem1 = paletteFirstHalf.last;
        paletteFirstHalf.remove(lastItem1);
        paletteFirstHalf.insertSafe(0, lastItem1);

        if (paletteSecondHalf.isEmpty) return;
        final lastItem2 = paletteSecondHalf.last;
        paletteSecondHalf.remove(lastItem2);
        paletteSecondHalf.insertSafe(0, lastItem2);
      }
    });
  }

  void updateCurrentColorSchemeOfSubPages([Color? color, bool customAlpha = true]) async {
    final colorWithAlpha = customAlpha ? color?.withAlpha(colorAlpha) : color;
    _colorSchemeOfSubPages.value = colorWithAlpha;
    updateThemeAndRefresh();
  }

  Future<void> updatePlayerColorFromTrack(Track track, int index, {int? dateAdded}) async {
    if (SettingsController.inst.autoColor.value) {
      await setPlayerColor(track);
      updateThemeAndRefresh();
    }
    currentPlayingTrackPath.value = track.path;
    currentPlayingIndex.value = index;
    currentPlayingTrackDateAdded.value = dateAdded;
  }

  void updatePlayerColorFromColor(Color color, [bool customAlpha = true]) async {
    final colorWithAlpha = customAlpha ? color.withAlpha(colorAlpha) : color;
    namidaColor.value = NamidaColor(colorWithAlpha, colorWithAlpha, [colorWithAlpha]);
    updateThemeAndRefresh();
  }

  Future<void> setPlayerColor(Track track) async {
    namidaColor.value = await getTrackColors(track);
  }

  Future<NamidaColor> getTrackColors(Track track) async {
    final nc = colorsMap[track.path.getFilename] ?? await extractColorsFromImage(track.pathToImage);
    return NamidaColor(nc.color.withAlpha(colorAlpha), nc.mix, nc.palette);
  }

  Future<NamidaColor> extractColorsFromImage(String pathofimage) async {
    final paletteFile = File("$k_DIR_PALETTES${pathofimage.getFilenameWOExt}.palette");

    if (!await File(pathofimage).exists()) {
      return NamidaColor(playerStaticColor, playerStaticColor, [playerStaticColor]);
    }

    NamidaColor? nc;

    try {
      nc = NamidaColor.fromJson(await paletteFile.readAsJson());
      _updateInColorMap(pathofimage.getFilenameWOExt, nc);
      debugPrint("COLORRRR READ FROM FILE");
      return nc;
    } catch (e) {
      await paletteFile.deleteIfExists();
      debugPrint(e.toString());
    }

    final result = await PaletteGenerator.fromImageProvider(FileImage(File(pathofimage)));
    final pcolors = result.colors.toList();
    nc = NamidaColor(null, generateDelightnedColorFromPalette(pcolors).withAlpha(colorAlpha), pcolors);

    await paletteFile.writeAsJson(nc.toJson());
    Indexer.inst.updateColorPalettesSizeInStorage(paletteFile);
    debugPrint("COLORRRRR EXTRACTED");

    _updateInColorMap(pathofimage.getFilenameWOExt, nc);
    return nc;
  }

  Future<void> generateAllColorPalettes() async {
    await Directory(k_DIR_PALETTES).create();

    generatingAllColorPalettes.value = true;
    for (int i = 0; i < allTracksInLibrary.length; i++) {
      // stops extracting
      if (!generatingAllColorPalettes.value) break;
      await getTrackColors(allTracksInLibrary[i]);
      await Future.delayed(Duration.zero);
    }

    generatingAllColorPalettes.value = false;
  }

  void stopGeneratingColorPalettes() => generatingAllColorPalettes.value = false;

  /// Equivalent to calling [getTrackColors] and [generateDelightnedColorFromPalette].
  Future<Color> getTrackDelightnedColor(Track track) async {
    final nc = await getTrackColors(track);
    return generateDelightnedColorFromPalette(nc.palette).withAlpha(Get.isDarkMode ? 200 : 120);
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
    final intpalette = finalpalette.palette.map((e) => e.value).toList();
    return mixIntColors(intpalette);
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

  void updateThemeAndRefresh() {}

  Future<void> prepareColors() async {
    await for (final f in Directory(k_DIR_PALETTES).list()) {
      f as File;
      final didExecute = await f.readAsJsonAnd(
        (response) async {
          final nc = NamidaColor.fromJson(response);
          _updateInColorMap(f.path.getFilenameWOExt, nc);
        },
        onError: () async => await f.deleteIfExists(),
      );
      if (!didExecute) continue;
    }
  }

  void _updateInColorMap(String filenameWoExt, NamidaColor nc) {
    colorsMap[filenameWoExt] = nc;
    final halfIndex = (nc.palette.length - 1) / 3;
    paletteFirstHalf.clear();
    paletteSecondHalf.clear();

    nc.palette.loop((c, i) {
      if (i <= halfIndex) {
        paletteFirstHalf.add(c);
      } else {
        paletteSecondHalf.add(c);
      }
    });
  }
}
