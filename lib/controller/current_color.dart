// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:queue/queue.dart' as qs;

import 'package:namida/class/color_m.dart';
import 'package:namida/class/file_parts.dart';
import 'package:namida/class/func_execute_limiter.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/network_artwork.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

Color get playerStaticColor => namida.isDarkMode ? playerStaticColorDark : playerStaticColorLight;
Color get playerStaticColorLight => Color(settings.staticColor.valueR);
Color get playerStaticColorDark => Color(settings.staticColorDark.valueR);

class CurrentColor {
  static CurrentColor get inst => _instance;
  static final CurrentColor _instance = CurrentColor._internal();
  CurrentColor._internal();

  bool get _canAutoUpdateColor => settings.autoColor.value || settings.forceMiniplayerTrackColor.value;
  bool get _shouldUpdateFromDeviceWallpaper => settings.pickColorsFromDeviceWallpaper.value;

  Color get miniplayerColor => settings.forceMiniplayerTrackColor.valueR ? _namidaColorMiniplayer.valueR?.color ?? color : color;
  NamidaColor get miniplayerColorM =>
      settings.forceMiniplayerTrackColor.valueR ? _namidaColorMiniplayer.valueR ?? _namidaColor.valueR ?? _defaultNamidaColor : _namidaColor.valueR ?? _defaultNamidaColor;
  Color get color => _namidaColor.valueR?.color ?? _defaultNamidaColor.color;
  List<Color> get palette => _namidaColor.valueR?.palette ?? _defaultNamidaColor.palette;
  Color get currentColorScheme => _colorSchemeOfSubPages.valueR ?? color;
  int get colorAlpha => namida.isDarkMode ? 200 : 120;

  final _namidaColorMiniplayer = Rxn<NamidaColor>();

  final _namidaColor = Rxn<NamidaColor>();

  NamidaColor get _defaultNamidaColor => NamidaColor.single(playerStaticColor);

  final _colorSchemeOfSubPages = Rxn<Color>();

  final paletteFirstHalf = <Color>[].obs;
  final paletteSecondHalf = <Color>[].obs;

  /// Same fields exists in [Player] class, they can be used but these ones ensure updating the color only after extracting.
  final currentPlayingTrack = Rxn<Selectable>();
  final currentPlayingIndex = 0.obs;

  YoutubeID? _currentPlayingVideo;

  Color? _deviceWallpaperColorAccent;

  final allColorPalettesGeneratingProgress = 0.obs;
  final allColorPalettesGeneratingTotal = 0.obs;

  void refreshhh() {
    _namidaColor.refresh();
    _namidaColorMiniplayer.refresh();
  }

  final _colorsMap = <String, NamidaColor>{};
  final _colorsMapYTID = <String, NamidaColor>{};

  Timer? _colorsSwitchTimer;
  void switchColorPalettes({bool? playWhenReady, Playable? item, bool? swapEnabled}) {
    _colorsSwitchTimer?.cancel();

    if ((item ?? Player.inst.currentItem.value) == null || //
        (swapEnabled ?? settings.enablePartyModeColorSwap.value) == false) {
      return;
    }

    final isPlaying = playWhenReady ?? Player.inst.playWhenReady.value;
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
      final nc = _namidaColor.value ?? _defaultNamidaColor;
      _namidaColor.set(NamidaColor(
        used: nc.used?.withAlpha(colorAlpha),
        // mix: nc.mix,
        mix2: nc.mix2,
        palette: nc.palette,
      ));
    } else {
      final nc = playerStaticColor.lighter;
      _namidaColor.set(NamidaColor.single(nc));
    }
    _namidaColor.refresh();
  }

  void updatePlayerColorFromColor(Color color, [bool customAlpha = true]) async {
    final colorWithAlpha = customAlpha ? color.withAlpha(colorAlpha) : color;
    _namidaColor.value = NamidaColor.single(colorWithAlpha);
  }

  Future<void> refreshColorsAfterResumeApp() async {
    if (settings.autoColor.value && _shouldUpdateFromDeviceWallpaper) {
      final namidaColor = await getPlayerColorFromDeviceWallpaper(forceCheck: true);
      if (namidaColor != null) {
        _namidaColor.set(namidaColor);
        _namidaColor.refresh();
        _updateCurrentPaletteHalfs(namidaColor);
      }
    }
  }

  Future<Color?> _getDeviceWallpaperColorAccent({bool forceCheck = false}) async {
    if (_deviceWallpaperColorAccent == null || forceCheck) {
      Color? accentColor = await DynamicColorPlugin.getAccentColor();
      if (accentColor == null) {
        final palette = await DynamicColorPlugin.getCorePalette();
        if (palette != null) accentColor = Color(palette.primary.get(60));
      }
      _deviceWallpaperColorAccent = accentColor;
      return accentColor;
    } else {
      return _deviceWallpaperColorAccent;
    }
  }

  Future<NamidaColor?> getPlayerColorFromDeviceWallpaper({bool forceCheck = false, bool customAlpha = true}) async {
    final accentColor = await _getDeviceWallpaperColorAccent(forceCheck: forceCheck);
    if (accentColor != null) {
      final colorWithAlpha = customAlpha ? accentColor.withAlpha(colorAlpha) : accentColor;
      return NamidaColor.single(colorWithAlpha);
    }
    return null;
  }

  void updatePlayerColorFromTrack(Selectable? track, int? index, {bool updateIndexOnly = false}) async {
    if (!updateIndexOnly && track != null) {
      _updatePlayerColorFromItem(
        getColorPalette: () async => await getTrackColors(track.track, networkArtworkInfo: null),
        stillPlaying: () => track.track == Player.inst.currentTrack?.track,
      );
    }
    if (track != null) {
      currentPlayingTrack
        ..set(null) // nullifying to re-assign safely if subtype has changed
        ..set(track)
        ..refresh();
    }
    if (index != null) {
      currentPlayingIndex.value = index;
    }
  }

  void updatePlayerColorFromYoutubeID(YoutubeID ytIdItem) async {
    final id = ytIdItem.id;
    if (id == '') return;

    if (_currentPlayingVideo == ytIdItem) return;
    _currentPlayingVideo = ytIdItem;

    // -- only extract if same item is still playing, i.e. user didn't skip.
    bool stillPlaying() => ytIdItem == Player.inst.currentItem.value;

    _updatePlayerColorFromItem(
      getColorPalette: () async {
        if (_colorsMapYTID[id] != null) return _colorsMapYTID[id]!;

        final image = await ThumbnailManager.inst.getYoutubeThumbnailAndCache(id: id, type: ThumbnailType.video);
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
        if (trColors != _namidaColorMiniplayer.value) _namidaColorMiniplayer.value = trColors;

        if (settings.autoColor.value) {
          if (_shouldUpdateFromDeviceWallpaper) {
            namidaColor = await getPlayerColorFromDeviceWallpaper();
          } else {
            namidaColor = trColors;
          }
          if (namidaColor != null && namidaColor != _namidaColor.value) {
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
    _currentPlayingVideo = null;
  }

  bool _checkDummyColor(NamidaColor value) => value.palette.isEmpty || (value.palette.length == 1 && value.color == value.palette.first && value.color == value.palette.last);

  NamidaColor _maybeDelightned(NamidaColor? nc, {required bool delightnedAndAlpha, required bool fallbackToPlayerStaticColor}) {
    if (nc == null || _checkDummyColor(nc)) {
      // the value is null or dummy color, fetching with current [playerStaticColor].
      final c = fallbackToPlayerStaticColor ? playerStaticColor : currentColorScheme;
      return NamidaColor.single(c.lighter);
    } else {
      // the value is a normal color
      return NamidaColor(
        used: delightnedAndAlpha ? nc.used?.withAlpha(colorAlpha).delightned : nc.used,
        // mix: delightnedAndAlpha ? nc.mix.withAlpha(colorAlpha).delightned : nc.mix,
        mix2: delightnedAndAlpha ? nc.mix2.withAlpha(colorAlpha).delightned : nc.mix2,
        palette: nc.palette,
      );
    }
  }

  NamidaColor? getTrackColorsSync(
    Track track, {
    required NetworkArtworkInfo? networkArtworkInfo,
    bool fallbackToPlayerStaticColor = true,
    bool delightnedAndAlpha = true,
    bool useIsolate = _defaultUseIsolate,
  }) {
    final filename = networkArtworkInfo?.toArtworkIfExistsAndEnabled()?.path ?? track.cacheKey;

    final valInMap = _colorsMap[filename];

    if (valInMap != null) {
      return _maybeDelightned(
        valInMap,
        delightnedAndAlpha: delightnedAndAlpha,
        fallbackToPlayerStaticColor: fallbackToPlayerStaticColor,
      );
    }
    return null;
  }

  Future<NamidaColor> getTrackColors(
    Track track, {
    required NetworkArtworkInfo? networkArtworkInfo,
    bool fallbackToPlayerStaticColor = true,
    bool delightnedAndAlpha = true,
    bool useIsolate = _defaultUseIsolate,
    bool forceReCheck = false,
  }) async {
    if (!forceReCheck) {
      final cached = getTrackColorsSync(track, networkArtworkInfo: networkArtworkInfo);

      if (cached != null) return cached;
    }

    final networkArtwork = networkArtworkInfo?.toArtworkIfExistsAndEnabled()?.path;

    NamidaColor? nc = await extractPaletteFromImage(
      networkArtwork ?? track.pathToImage,
      track: networkArtwork != null ? null : track,
      useIsolate: useIsolate,
    );

    final filename = networkArtwork ?? track.cacheKey;

    final finalnc = _maybeDelightned(
      nc,
      delightnedAndAlpha: delightnedAndAlpha,
      fallbackToPlayerStaticColor: fallbackToPlayerStaticColor,
    );
    if (networkArtwork == null || nc != null) _updateInColorMap(filename, finalnc);
    return finalnc;
  }

  /// Equivalent to calling [getTrackColors] with [delightnedAndAlpha == true]
  Future<Color> getTrackDelightnedColor(Track track, NetworkArtworkInfo? networkArtworkInfo,
      {bool fallbackToPlayerStaticColor = false, bool useIsolate = _defaultUseIsolate}) async {
    final nc = await getTrackColors(
      track,
      networkArtworkInfo: networkArtworkInfo,
      fallbackToPlayerStaticColor: fallbackToPlayerStaticColor,
      delightnedAndAlpha: true,
      useIsolate: useIsolate,
    );
    return nc.color;
  }

  Color? getTrackDelightnedColorSync(Track track, NetworkArtworkInfo? networkArtworkInfo, {bool fallbackToPlayerStaticColor = false, bool useIsolate = _defaultUseIsolate}) {
    final nc = getTrackColorsSync(
      track,
      networkArtworkInfo: networkArtworkInfo,
      fallbackToPlayerStaticColor: fallbackToPlayerStaticColor,
      delightnedAndAlpha: true,
      useIsolate: useIsolate,
    );
    return nc?.color;
  }

  void updateCurrentColorSchemeOfSubPages([Color? color, bool customAlpha = true]) async {
    final colorWithAlpha = customAlpha ? color?.withAlpha(colorAlpha) : color;
    _colorSchemeOfSubPages.value = colorWithAlpha;
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

    final filename = track != null ? track.cacheKey : imagePath.getFilenameWOExt;

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
      pcolors.addAll(await _colorGenerationTasks.add(() async => await _extractPaletteGenerator(imagePath, track: track, useIsolate: useIsolate)));
    } catch (_) {}
    final nc = NamidaColor.create(palette: pcolors);
    await paletteFile.writeAsJson(nc.toJson()); // writing the file bothways, to prevent reduntant re-extraction.
    // Indexer.inst.updateColorPalettesSizeInStorage(newPalettePath: paletteFile.path);
    _printie("Color Extracted From Image (${pcolors.length})");
    return pcolors.isEmpty ? null : nc;
  }

  final _colorGenerationTasks = qs.Queue(parallel: 1);

  Future<void> reExtractTrackColorPalette({required Track track, required NamidaColor? newNC, required String? imagePath, bool useIsolate = true}) async {
    assert(newNC != null || imagePath != null, 'a color or imagePath must be provided');

    final key = track.cacheKey;
    final paletteFile = FileParts.join(AppDirs.PALETTES, "$key.palette");
    if (newNC != null) {
      await paletteFile.writeAsJson(newNC.toJson());
      _updateInColorMap(key, newNC);
    } else if (imagePath != null) {
      final nc = await extractPaletteFromImage(imagePath, track: track, forceReExtract: true, useIsolate: useIsolate);
      _updateInColorMap(key, nc);
    }
    if (Player.inst.currentTrack?.track == track) {
      updatePlayerColorFromTrack(Player.inst.currentTrack, null);
    }
  }

  Future<void> reExtractNetworkArtworkColorPalette({required NetworkArtworkInfo networkArtworkInfo, required NamidaColor? newNC, bool useIsolate = true}) async {
    final imagePath = networkArtworkInfo.toArtworkIfExistsAndValidAndEnabled()?.path;
    if (imagePath == null || !await File(imagePath).exists()) return;

    final filenameKeyInMaps = imagePath;
    final filenamePalette = networkArtworkInfo.name;
    final paletteFile = FileParts.join(AppDirs.PALETTES, "$filenamePalette.palette");
    if (newNC != null) {
      await paletteFile.writeAsJson(newNC.toJson());
      _updateInColorMap(filenameKeyInMaps, newNC);
    } else {
      final nc = await extractPaletteFromImage(imagePath, forceReExtract: true, useIsolate: useIsolate);
      _updateInColorMap(filenameKeyInMaps, nc);
    }

    final currentRoute = NamidaNavigator.inst.currentRoute;
    final currentRouteType = currentRoute?.route;
    switch (currentRouteType) {
      case RouteType.SUBPAGE_albumArtistTracks ||
            RouteType.SUBPAGE_albumTracks ||
            RouteType.SUBPAGE_artistTracks ||
            RouteType.SUBPAGE_albumArtistTracks ||
            RouteType.SUBPAGE_composerTracks ||
            RouteType.SUBPAGE_genreTracks:
        currentRoute?.updateColorScheme();
      default:
        null;
    }
  }

  Future<Iterable<Color>> _extractPaletteGenerator(String imagePath, {required Track? track, bool useIsolate = _defaultUseIsolate}) async {
    Uint8List? bytes;
    File? imageFile;

    if (await File(imagePath).exists()) {
      imageFile = File(imagePath);
    } else {
      final res = await Indexer.inst.getArtwork(
        imagePath: imagePath,
        track: track,
        compressed: true,
        size: 200,
      );
      imageFile = res.file;
      bytes = res.bytes;
      if (bytes?.isEmpty == true) bytes = null;
    }

    if (imageFile == null && bytes == null) {
      if (track != null) {
        final id = track.youtubeID;
        final ytImg = await ThumbnailManager.inst.getYoutubeThumbnailFromCache(type: ThumbnailType.video, id: id, isTemp: false);
        if (ytImg != null) imageFile = File(ytImg.path);

        if (imageFile == null) {
          final cover = Indexer.inst.getFallbackFolderArtworkPath(folder: track.folder);
          if (cover != null) imageFile = File(cover);
        }
      }
    }

    if (imageFile == null && bytes == null) return [];

    const defaultTimeout = Duration(seconds: 5);
    final imageProvider = ResizeImage(
      (bytes == null ? FileImage(imageFile!) : MemoryImage(bytes)) as ImageProvider,
      height: 240,
    );
    if (!useIsolate) {
      final result = await PaletteGenerator.fromImageProvider(
        imageProvider,
        filters: const [],
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
      return colorValues;
    }
  }

  static Future<List<Color>> _extractPaletteGeneratorCompute(EncodedImage encimg) async {
    final result = await PaletteGenerator.fromByteData(encimg, filters: const [], maximumColorCount: 28);
    return result.colors.toList();
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

    final alltracks = allTracksInLibrary;

    allColorPalettesGeneratingProgress.value = 0;
    allColorPalettesGeneratingTotal.value = alltracks.length;

    try {
      for (int i = 0; i < alltracks.length; i++) {
        if (allColorPalettesGeneratingTotal.value == -1) {
          break; // stops extracting
        }
        allColorPalettesGeneratingProgress.value++;
        await getTrackColors(alltracks[i], networkArtworkInfo: null, useIsolate: true, forceReCheck: true);
      }
    } catch (_) {
      // concurrent modifiation maybe
    }

    allColorPalettesGeneratingProgress.value = 0;
    allColorPalettesGeneratingTotal.value = 0;
  }

  void stopGeneratingColorPalettes() => allColorPalettesGeneratingTotal.value = -1;

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
  bool _isNearWhiteOrBlack() {
    final luminance = computeLuminance();
    return luminance <= 0.1 || luminance >= 0.9;
  }

  Color get delightned {
    if (_isNearWhiteOrBlack()) return this;

    final hslColor = HSLColor.fromColor(this);
    final modifiedColor = hslColor.withLightness(0.4).toColor();
    return modifiedColor;
  }

  Color get lighter {
    if (_isNearWhiteOrBlack()) return this;
    final hslColor = HSLColor.fromColor(this);
    final modifiedColor = hslColor.withLightness(0.64).toColor();
    return modifiedColor;
  }

  Color invert() {
    final c = this;
    return Color.from(
      alpha: c.a,
      red: 1.0 - c.r,
      green: 1.0 - c.g,
      blue: 1.0 - c.b,
    );
  }
}
