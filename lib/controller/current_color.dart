// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:queue/queue.dart' as qs;

import 'package:namida/class/color_m.dart';
import 'package:namida/class/func_execute_limiter.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_id.dart';

Color get playerStaticColor => namida.isDarkMode ? playerStaticColorDark : playerStaticColorLight;
Color get playerStaticColorLight => Color(settings.staticColor.valueR);
Color get playerStaticColorDark => Color(settings.staticColorDark.valueR);

class CurrentColor {
  static CurrentColor get inst => _instance;
  static final CurrentColor _instance = CurrentColor._internal();
  CurrentColor._internal();

  bool get _canAutoUpdateColor => settings.autoColor.value || settings.forceMiniplayerTrackColor.value;
  bool get _shouldUpdateFromDeviceWallpaper => settings.pickColorsFromDeviceWallpaper.value;

  Color get miniplayerColor => settings.forceMiniplayerTrackColor.valueR ? _namidaColorMiniplayer.valueR ?? color : color;
  Color get color => _namidaColor.valueR.color;
  List<Color> get palette => _namidaColor.valueR.palette;
  Color get currentColorScheme => _colorSchemeOfSubPages.valueR ?? color;
  int get colorAlpha => namida.isDarkMode ? 200 : 120;

  final _namidaColorMiniplayer = Rxn<Color>();

  late final Rx<NamidaColor> _namidaColor = NamidaColor(
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

  ColorScheme? deviceWallpaperColorScheme;

  final isGeneratingAllColorPalettes = false.obs;

  void refreshhh() {
    _namidaColor.refresh();
    _namidaColorMiniplayer.refresh();
  }

  final _colorsMap = <String, NamidaColor>{};
  final _colorsMapYTID = <String, NamidaColor>{};

  Timer? _colorsSwitchTimer;
  void switchColorPalettes(bool isPlaying) {
    _colorsSwitchTimer?.cancel();
    _colorsSwitchTimer = null;
    if (Player.inst.currentItem.value == null) return;
    final durms = isPlaying ? 150 : 2200;
    _colorsSwitchTimer = Timer.periodic(Duration(milliseconds: durms), (timer) {
      if (settings.enablePartyModeColorSwap.value) {
        if (paletteFirstHalf.isEmpty) return;

        final lastItem1 = paletteFirstHalf.value.last;
        paletteFirstHalf.remove(lastItem1);
        paletteFirstHalf.insertSafe(0, lastItem1);

        if (paletteSecondHalf.isEmpty) return;
        final lastItem2 = paletteSecondHalf.value.last;
        paletteSecondHalf.remove(lastItem2);
        paletteSecondHalf.insertSafe(0, lastItem2);
      }
    });
  }

  void initialize() {
    if (_canAutoUpdateColor) return;
    final mode = settings.themeMode.value;
    final isDarkMode = mode == ThemeMode.dark || (mode == ThemeMode.system && SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    updatePlayerColorFromColor(isDarkMode ? playerStaticColorDark : playerStaticColorLight);
  }

  void updateColorAfterThemeModeChange() {
    if (settings.autoColor.value) {
      final nc = _namidaColor.value;
      _namidaColor.value = NamidaColor(
        used: nc.color.withAlpha(colorAlpha),
        mix: nc.mix,
        palette: nc.palette,
      );
    } else {
      final nc = playerStaticColor.lighter;
      _namidaColor.value = NamidaColor(
        used: nc,
        mix: nc,
        palette: [nc],
      );
    }
  }

  void updatePlayerColorFromColor(Color color, [bool customAlpha = true]) async {
    final colorWithAlpha = customAlpha ? color.withAlpha(colorAlpha) : color;
    _namidaColor.value = NamidaColor(
      used: colorWithAlpha,
      mix: colorWithAlpha,
      palette: [colorWithAlpha],
    );
  }

  Future<void> refreshColorsAfterResumeApp() async {
    final namidaColor = await getPlayerColorFromDeviceWallpaper(forceCheck: true);
    if (namidaColor != null && settings.autoColor.value && _shouldUpdateFromDeviceWallpaper) {
      _namidaColor.value = namidaColor;
      _updateCurrentPaletteHalfs(namidaColor);
    }
  }

  Future<ColorScheme?> _getDeviceWallpaperColorScheme({bool forceCheck = false}) async {
    if (deviceWallpaperColorScheme == null || forceCheck) {
      final accentColors = await DynamicColorPlugin.getCorePalette();
      final cs = accentColors?.toColorScheme();
      deviceWallpaperColorScheme = cs;
      return cs;
    } else {
      return deviceWallpaperColorScheme;
    }
  }

  Future<NamidaColor?> getPlayerColorFromDeviceWallpaper({bool forceCheck = false, bool customAlpha = true}) async {
    final accentColorsScheme = await _getDeviceWallpaperColorScheme(forceCheck: forceCheck);
    final accentColor = accentColorsScheme?.secondary;
    if (accentColor != null) {
      final colorWithAlpha = customAlpha ? accentColor.withAlpha(colorAlpha) : accentColor;
      return NamidaColor(
        used: colorWithAlpha,
        mix: colorWithAlpha,
        palette: [colorWithAlpha],
      );
    }
    return null;
  }

  void updatePlayerColorFromTrack(Selectable? track, int? index, {bool updateIndexOnly = false}) async {
    if (!updateIndexOnly && track != null) {
      _updatePlayerColorFromItem(
        getColorPalette: () async => await getTrackColors(track.track),
        stillPlaying: () => track.track == Player.inst.currentTrack?.track,
      );
    }
    if (track != null) {
      currentPlayingTrack.value = null; // nullifying to re-assign safely if subtype has changed
      currentPlayingTrack.value = track;
    }
    if (index != null) {
      currentPlayingIndex.value = index;
    }
  }

  void updatePlayerColorFromYoutubeID(YoutubeID ytIdItem) async {
    final id = ytIdItem.id;
    if (id == '') return;

    // -- only extract if same item is still playing, i.e. user didn't skip.
    bool stillPlaying() => ytIdItem.id == Player.inst.currentVideo?.id;

    _updatePlayerColorFromItem(
      getColorPalette: () async {
        if (_colorsMapYTID[id] != null) return _colorsMapYTID[id]!;

        final image = await ThumbnailManager.inst.getYoutubeThumbnailAndCache(id: id);
        if (image != null && stillPlaying()) {
          final color = await CurrentColor.inst.extractPaletteFromImage(image.path, paletteSaveDirectory: Directory(AppDirs.YT_PALETTES), useIsolate: true);
          if (color != null && stillPlaying()) {
            _colorsMapYTID[id] = color; // saving in memory
            return color;
          }
        }
        return null;
      },
      stillPlaying: stillPlaying,
    );
  }

  final _fnLimiter = FunctionExecuteLimiter();
  void _updatePlayerColorFromItem({
    required Future<NamidaColor?> Function() getColorPalette,
    required bool Function() stillPlaying,
  }) async {
    if (_canAutoUpdateColor) {
      _fnLimiter.execute(() async {
        NamidaColor? namidaColor;

        final trColors = await getColorPalette();
        if (trColors == null || !stillPlaying()) return; // -- check current item
        _namidaColorMiniplayer.value = trColors.color;

        if (settings.autoColor.value) {
          if (_shouldUpdateFromDeviceWallpaper) {
            namidaColor = await getPlayerColorFromDeviceWallpaper();
          } else {
            namidaColor = trColors;
          }
          if (namidaColor != null) {
            _namidaColor.value = namidaColor;
            _updateCurrentPaletteHalfs(
              settings.forceMiniplayerTrackColor.value ? trColors : namidaColor,
            );
          }
        }
      });
    }
  }

  void resetCurrentPlayingTrack() {
    currentPlayingTrack.value = null;
    _namidaColorMiniplayer.value = null;
  }

  Future<NamidaColor> getTrackColors(
    Track track, {
    bool fallbackToPlayerStaticColor = true,
    bool delightnedAndAlpha = true,
    bool useIsolate = _defaultUseIsolate,
    bool forceReCheck = false,
  }) async {
    bool checkDummyColor(NamidaColor value) => value.palette.isEmpty || (value.palette.length == 1 && value.color == value.palette.first && value.color == value.palette.last);

    NamidaColor maybeDelightned(NamidaColor? nc) {
      if (nc == null || checkDummyColor(nc)) {
        // the value is null or dummy color, fetching with current [playerStaticColor].
        final c = fallbackToPlayerStaticColor ? playerStaticColor : currentColorScheme;
        return NamidaColor(
          used: c.lighter,
          mix: c.lighter,
          palette: [c.lighter],
        );
      } else {
        // the value is a normal color
        return NamidaColor(
          used: delightnedAndAlpha ? nc.used?.withAlpha(colorAlpha).delightned : nc.used,
          mix: delightnedAndAlpha ? nc.mix.withAlpha(colorAlpha).delightned : nc.mix,
          palette: nc.palette,
        );
      }
    }

    final filename = settings.groupArtworksByAlbum.value ? track.albumIdentifier : track.filename;

    final valInMap = _colorsMap[filename];
    if (!forceReCheck && valInMap != null) {
      return maybeDelightned(valInMap);
    }

    NamidaColor? nc = await extractPaletteFromImage(
      track.pathToImage,
      track: track,
      useIsolate: useIsolate,
    );

    final finalnc = maybeDelightned(nc);
    _updateInColorMap(filename, finalnc);
    return finalnc;
  }

  /// Equivalent to calling [getTrackColors] with [delightnedAndAlpha == true]
  Future<Color> getTrackDelightnedColor(Track track, {bool fallbackToPlayerStaticColor = false, bool useIsolate = _defaultUseIsolate}) async {
    final nc = await getTrackColors(
      track,
      fallbackToPlayerStaticColor: fallbackToPlayerStaticColor,
      delightnedAndAlpha: true,
      useIsolate: useIsolate,
    );
    return nc.color;
  }

  void updateCurrentColorSchemeOfSubPages([Color? color, bool customAlpha = true]) async {
    final colorWithAlpha = customAlpha ? color?.withAlpha(colorAlpha) : color;
    _colorSchemeOfSubPages.value = colorWithAlpha;
  }

  Color mixIntColors(Iterable<Color> colors) {
    if (colors.isEmpty) return Colors.transparent;
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

  Future<NamidaColor?> extractPaletteFromImage(
    String imagePath, {
    Track? track,
    bool forceReExtract = false,
    bool useIsolate = _defaultUseIsolate,
    Directory? paletteSaveDirectory,
  }) async {
    // if (!forceReExtract && !await File(imagePath).exists()) return null; // _extractPaletteGenerator tries to get artwork from audio

    paletteSaveDirectory ??= Directory(AppDirs.PALETTES);

    final filename = track != null
        ? settings.groupArtworksByAlbum.value
            ? track.albumIdentifier
            : track.filename
        : imagePath.getFilenameWOExt;

    final paletteFile = File("${paletteSaveDirectory.path}$filename.palette");

    // -- try reading the cached file
    if (!forceReExtract) {
      final response = await paletteFile.readAsJson();
      if (response != null) {
        final nc = NamidaColor.fromJson(response);
        _printie("Color Read From File");
        return nc;
      } else {
        await paletteFile.delete().catchError((_) => File(''));
      }
    }

    // -- file doesnt exist or couldn't be read or [forceReExtract==true]
    final pcolors = <Color>[];
    try {
      pcolors.addAll(await _colorGenerationTasks.add(() async => await _extractPaletteGenerator(imagePath, useIsolate: useIsolate)));
    } catch (_) {}
    final nc = NamidaColor(used: null, mix: mixIntColors(pcolors), palette: pcolors.toList());
    await paletteFile.writeAsJson(nc.toJson()); // writing the file bothways, to prevent reduntant re-extraction.
    Indexer.inst.updateColorPalettesSizeInStorage(newPalettePath: paletteFile.path);
    _printie("Color Extracted From Image (${pcolors.length})");
    return pcolors.isEmpty ? null : nc;
  }

  final _colorGenerationTasks = qs.Queue(parallel: 1);

  Future<void> reExtractTrackColorPalette({required Track track, required NamidaColor? newNC, required String? imagePath, bool useIsolate = true}) async {
    assert(newNC != null || imagePath != null, 'a color or imagePath must be provided');

    final filename = settings.groupArtworksByAlbum.value ? track.albumIdentifier : track.filename;
    final paletteFile = File("${AppDirs.PALETTES}$filename.palette");
    if (newNC != null) {
      await paletteFile.writeAsJson(newNC.toJson());
      _updateInColorMap(filename, newNC);
    } else if (imagePath != null) {
      final nc = await extractPaletteFromImage(imagePath, track: track, forceReExtract: true, useIsolate: useIsolate);
      _updateInColorMap(filename, nc);
    }
    if (Player.inst.currentTrack == track) {
      updatePlayerColorFromTrack(Player.inst.currentTrack, null);
    }
  }

  Future<Iterable<Color>> _extractPaletteGenerator(String imagePath, {bool useIsolate = _defaultUseIsolate}) async {
    Uint8List? bytes;
    File? imageFile;

    if (await File(imagePath).exists()) {
      imageFile = File(imagePath);
    } else {
      bytes = await Indexer.inst
          .getArtwork(
            imagePath: imagePath,
            compressed: true,
            size: 200,
          )
          .then((value) => value.$2);
    }

    if (imageFile == null && bytes == null) return [];

    const defaultTimeout = Duration(seconds: 5);
    final imageProvider = (bytes == null ? FileImage(imageFile!) : MemoryImage(bytes)) as ImageProvider;
    if (!useIsolate) {
      final result = await PaletteGenerator.fromImageProvider(
        imageProvider,
        filters: [],
        maximumColorCount: 28,
        timeout: defaultTimeout,
      );
      return result.colors;
    } else {
      final ImageStream stream = imageProvider.resolve(
        const ImageConfiguration(size: null, devicePixelRatio: 1.0),
      );
      final Completer<ui.Image> imageCompleter = Completer<ui.Image>();
      Timer? loadFailureTimeout;
      late ImageStreamListener listener;
      listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
        loadFailureTimeout?.cancel();
        stream.removeListener(listener);
        imageCompleter.complete(info.image);
      });
      if (defaultTimeout != Duration.zero) {
        loadFailureTimeout = Timer(defaultTimeout, () {
          stream.removeListener(listener);
          imageCompleter.completeError(
            TimeoutException('Timeout occurred trying to load from $imageProvider'),
          );
        });
      }
      stream.addListener(listener);
      final ui.Image image = await imageCompleter.future;
      final ByteData? imageData = await image.toByteData();
      if (imageData == null) return [];

      final encimg = EncodedImage(imageData, width: image.width, height: image.height);
      final colorValues = await _extractPaletteGeneratorCompute.thready(encimg);

      return colorValues.map((e) => Color(e));
    }
  }

  static Future<List<int>> _extractPaletteGeneratorCompute(EncodedImage encimg) async {
    final result = await PaletteGenerator.fromByteData(encimg, filters: [avoidRedBlackWhitePaletteFilter], maximumColorCount: 28);
    return result.colors.map((e) => e.value).toList();
  }

  void _updateInColorMap(String filenameWoExt, NamidaColor? nc) {
    if (nc != null) _colorsMap[filenameWoExt] = nc;
  }

  void _updateCurrentPaletteHalfs(NamidaColor nc) {
    final halfIndex = (nc.palette.length - 1) / 3;
    paletteFirstHalf.clear();
    paletteSecondHalf.clear();

    paletteFirstHalf.execute(
      (firstPart) {
        paletteSecondHalf.execute(
          (secondPart) {
            nc.palette.loopAdv((c, i) {
              if (i <= halfIndex) {
                firstPart.add(c);
              } else {
                secondPart.add(c);
              }
            });
          },
        );
      },
    );
  }

  Future<void> generateAllColorPalettes() async {
    await Directory(AppDirs.PALETTES).create();

    isGeneratingAllColorPalettes.value = true;
    final alltracks = allTracksInLibrary;
    for (int i = 0; i < alltracks.length; i++) {
      if (!isGeneratingAllColorPalettes.value) break; // stops extracting
      await getTrackColors(alltracks[i], useIsolate: true, forceReCheck: true);
    }

    isGeneratingAllColorPalettes.value = false;
  }

  void stopGeneratingColorPalettes() => isGeneratingAllColorPalettes.value = false;

  static const _defaultUseIsolate = false;

  void _printie(
    dynamic message, {
    bool isError = false,
    bool dumpshit = false,
  }) {
    if (logsEnabled) printy(message, isError: isError, dumpshit: dumpshit);
  }

  bool logsEnabled = false;
}

extension ColorUtils on Color {
  Color get delightned {
    final hslColor = HSLColor.fromColor(this);
    final modifiedColor = hslColor.withLightness(0.4).toColor();
    return modifiedColor;
  }

  Color get lighter {
    final hslColor = HSLColor.fromColor(this);
    final modifiedColor = hslColor.withLightness(0.64).toColor();
    return modifiedColor;
  }

  Color invert() {
    final c = this;
    return Color.fromARGB((c.opacity * 255).round(), 255 - c.red, 255 - c.green, 255 - c.blue);
  }
}
