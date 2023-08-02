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

  Color get color => _namidaColor.value.color;
  List<Color> get palette => _namidaColor.value.palette;
  Color get currentColorScheme => _colorSchemeOfSubPages.value ?? color;
  int get colorAlpha => Get.isDarkMode ? 200 : 120;

  final Rx<NamidaColor> _namidaColor = NamidaColor(
    used: playerStaticColor,
    mix: playerStaticColor,
    palette: [playerStaticColor],
  ).obs;

  final _colorSchemeOfSubPages = Rxn<Color>();

  final paletteFirstHalf = <Color>[].obs;
  final paletteSecondHalf = <Color>[].obs;

  /// Same fields exists in [Player] class, they can be used but these ones ensure updating the color only after extracting.
  final currentPlayingTrack = Rxn<Selectable>();
  final currentPlayingIndex = 0.obs;

  final isGeneratingAllColorPalettes = false.obs;

  final colorsMap = <String, NamidaColor>{};

  Timer? _colorsSwitchTimer;
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

  void updateColorAfterThemeModeChange() {
    final nc = _namidaColor.value;
    _namidaColor.value = NamidaColor(
      used: nc.color.withAlpha(colorAlpha),
      mix: nc.mix,
      palette: nc.palette,
    );
  }

  void updatePlayerColorFromColor(Color color, [bool customAlpha = true]) async {
    final colorWithAlpha = customAlpha ? color.withAlpha(colorAlpha) : color;
    _namidaColor.value = NamidaColor(
      used: colorWithAlpha,
      mix: colorWithAlpha,
      palette: [colorWithAlpha],
    );
  }

  Future<void> updatePlayerColorFromTrack(Selectable track, int? index, {bool updateIndexOnly = false}) async {
    if (!updateIndexOnly && SettingsController.inst.autoColor.value) {
      final color = await getTrackColors(track.track);
      _namidaColor.value = color;
      _updateCurrentPaletteHalfs(color);
    }
    if (index != null) {
      currentPlayingTrack.value = null; // nullifying to re-assign safely if subtype has changed
      currentPlayingTrack.value = track;
      currentPlayingIndex.value = index;
    }
  }

  Future<NamidaColor> getTrackColors(Track track, {bool fallbackToPlayerStaticColor = true, bool delightnedAndAlpha = true}) async {
    NamidaColor maybeDelightned(NamidaColor nc) {
      final used = delightnedAndAlpha ? nc.color.delightned.withAlpha(colorAlpha) : nc.color;
      final mix = delightnedAndAlpha ? nc.mix.delightned.withAlpha(colorAlpha) : nc.color;
      return NamidaColor(
        used: used,
        mix: mix,
        palette: nc.palette,
      );
    }

    final valInMap = colorsMap[track.path.getFilename];
    if (valInMap != null) return maybeDelightned(valInMap);

    final nc = await _extractPaletteFromImage(
      track.pathToImage,
      fallbackToPlayerStaticColor: fallbackToPlayerStaticColor,
    );
    _updateInColorMap(track.filename, nc);
    return maybeDelightned(nc);
  }

  /// Equivalent to calling [getTrackColors] with [delightnedAndAlpha == true]
  Future<Color> getTrackDelightnedColor(Track track, {bool fallbackToPlayerStaticColor = false}) async {
    final nc = await getTrackColors(track, fallbackToPlayerStaticColor: fallbackToPlayerStaticColor, delightnedAndAlpha: true);
    return nc.color;
  }

  void updateCurrentColorSchemeOfSubPages([Color? color, bool customAlpha = true]) async {
    final colorWithAlpha = customAlpha ? color?.withAlpha(colorAlpha) : color;
    _colorSchemeOfSubPages.value = colorWithAlpha;
  }

  Color mixIntColors(Iterable<Color> colors) {
    int red = 0;
    int green = 0;
    int blue = 0;

    for (final color in colors) {
      red += (color.value >> 16) & 0xFF;
      green += (color.value >> 8) & 0xFF;
      blue += color.value & 0xFF;
    }

    red ~/= colors.length;
    green ~/= colors.length;
    blue ~/= colors.length;

    return Color.fromARGB(255, red, green, blue);
  }

  Future<NamidaColor> _extractPaletteFromImage(String imagePath, {bool fallbackToPlayerStaticColor = true, bool forceReExtract = false}) async {
    if (!forceReExtract && !await File(imagePath).exists()) {
      final c = fallbackToPlayerStaticColor ? playerStaticColor : currentColorScheme;
      return NamidaColor(
        used: c,
        mix: c,
        palette: [c],
      );
    }

    final paletteFile = File("$k_DIR_PALETTES${imagePath.getFilenameWOExt}.palette");

    // -- try reading the cached file
    if (!forceReExtract) {
      try {
        final nc = NamidaColor.fromJson(await paletteFile.readAsJson());
        printy("Color Read From File");
        return nc;
      } catch (e) {
        await paletteFile.deleteIfExists();
        printy(e, isError: true);
      }
    }

    // -- file doesnt exist or couldn't be read or [forceReExtract==true]
    final pcolors = await _extractPaletteGenerator(imagePath);
    final nc = NamidaColor(used: null, mix: mixIntColors(pcolors), palette: pcolors.toList());
    await paletteFile.writeAsJson(nc.toJson());
    Indexer.inst.updateColorPalettesSizeInStorage(paletteFile);
    printy("Color Extracted From Image");
    return nc;
  }

  Future<void> reExtractTrackColorPalette({required Track track, required NamidaColor? newNC, required String? imagePath}) async {
    final paletteFile = File("$k_DIR_PALETTES${track.filename}.palette");
    if (newNC != null) {
      await paletteFile.writeAsJson(newNC.toJson());
      _updateInColorMap(track.filename, newNC);
      return;
    } else if (imagePath != null) {
      final nc = await _extractPaletteFromImage(imagePath, forceReExtract: true);
      _updateInColorMap(imagePath.getFilenameWOExt, nc);
      return;
    }
    throw Exception('Please Provide at least 1 parameter');
  }

  Future<Iterable<Color>> _extractPaletteGenerator(String imagePath) async {
    final result = await PaletteGenerator.fromImageProvider(FileImage(File(imagePath)), filters: [], maximumColorCount: 28);
    return result.colors;
  }

  void _updateInColorMap(String filenameWoExt, NamidaColor nc) {
    colorsMap[filenameWoExt] = nc;
  }

  void _updateCurrentPaletteHalfs(NamidaColor nc) {
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

  Future<void> generateAllColorPalettes() async {
    await Directory(k_DIR_PALETTES).create();

    isGeneratingAllColorPalettes.value = true;
    for (int i = 0; i < allTracksInLibrary.length; i++) {
      // stops extracting
      if (!isGeneratingAllColorPalettes.value) break;
      await getTrackColors(allTracksInLibrary[i]);
      await Future.delayed(Duration.zero);
    }

    isGeneratingAllColorPalettes.value = false;
  }

  void stopGeneratingColorPalettes() => isGeneratingAllColorPalettes.value = false;
}

extension ColorUtils on Color {
  Color get delightned {
    final hslColor = HSLColor.fromColor(this);
    final modifiedColor = hslColor.withLightness(0.4).toColor();
    return modifiedColor;
  }
}
