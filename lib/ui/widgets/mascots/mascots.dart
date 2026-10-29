// all mascot packs logic by claude
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:namida/class/color_m.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/effects/effects.dart';
import 'package:namida/ui/widgets/floating_image.dart';
import 'package:namida/ui/widgets/jellyfish.dart';

part 'mascots.namiween.dart';

/// Art packs that take over parts of the ui, only one at a time.
///
/// Namiween follows its app icon, the jellys follow their own flag.
/// Only the jellys can take over the player colors, they have a flag for it.
abstract class NamidaMascots {
  static final activeRx = Rxn<NamidaMascot>();

  static NamidaMascot? get active => activeRx.value;

  /// The colors the active mascot paints the player with, null leaves the artwork colors.
  static NamidaMascotPalette? get activePalette => _activePalette;
  static NamidaMascotPalette? _activePalette;

  /// Needs the settings and the enabled app icon loaded.
  static void initialize() {
    final mascot = _resolveActive();
    activeRx.value = mascot;
    _activePalette = _paletteOf(mascot);
    NamidaJellys.enabledRx.addListener(_onSourceChanged);
    settings.extra.jellysPalette.addListener(_onSourceChanged);
    NamidaChannel.inst.enabledAppIcon.addListener(_onSourceChanged);
  }

  static NamidaMascot? _resolveActive() {
    if (NamidaChannel.inst.enabledAppIcon.value == NamidaAppIcons.namiween) return NamidaMascot.namiween;
    if (NamidaJellys.enabled) return NamidaMascot.jellys;
    return null;
  }

  static NamidaMascotPalette? _paletteOf(NamidaMascot? mascot) => switch (mascot) {
    NamidaMascot.jellys => NamidaJellys.enableColorPaletteHijack ? NamidaJellys.palette : null,
    NamidaMascot.namiween || null => null,
  };

  static void _onSourceChanged() {
    final mascot = _resolveActive();
    final palette = _paletteOf(mascot);
    final previousPalette = _activePalette;
    _activePalette = palette;
    activeRx.value = mascot;
    if (palette == previousPalette) return;
    if (palette != null) {
      settings.forceMiniplayerTrackColor.save(false);
      final staticColor = namida.isDarkMode ? palette.dark : palette.light;
      CurrentColor.inst.updatePlayerColorFromColor(staticColor, false);
    } else {
      CurrentColor.inst.refreshColorsOfCurrentItem();
    }
  }

  /// One offer per startup at most, namiween during halloween and the jellys otherwise.
  static void offerOnce() {
    final didOfferNamiween = _Namiween.offerIconOnce();
    if (didOfferNamiween) return;
    NamidaJellys.promptEnableOnce();
  }

  /// `null` if the asset is missing or refuses to decode.
  ///
  /// A failed art is dropped on its own rather than taking the whole load down with it.
  static Future<ui.Image?> decodeAsset(String assetPath, int targetWidth) async {
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: targetWidth);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e, st) {
      logger.error('failed decoding mascot asset $assetPath', e: e, st: st);
      return null;
    }
  }
}

/// The active mascot drifting behind a whole surface.
class NamidaMascotBackground extends StatelessWidget {
  final _MascotBackgroundSpot _spot;

  /// Multiplies the opacity while painting, nothing ticks while it's ~0.
  final ValueListenable<double> fade;

  const NamidaMascotBackground.miniplayer({super.key}) : _spot = _MascotBackgroundSpot.miniplayer, fade = kAlwaysCompleteAnimation;
  const NamidaMascotBackground.panel({super.key, required this.fade}) : _spot = _MascotBackgroundSpot.panel;
  const NamidaMascotBackground.youtubePlayer({super.key}) : _spot = _MascotBackgroundSpot.youtubePlayer, fade = kAlwaysCompleteAnimation;
  const NamidaMascotBackground.settings({super.key}) : _spot = _MascotBackgroundSpot.settings, fade = kAlwaysCompleteAnimation;

  @override
  Widget build(BuildContext context) {
    final spot = _spot;
    return ObxO(
      rx: NamidaMascots.activeRx,
      builder: (context, mascot) => switch (mascot) {
        NamidaMascot.jellys => IgnorePointer(
          child: JellyField(
            count: spot.jellyCount,
            opacity: spot.jellyOpacity,
            minHeight: spot.jellyMinHeight,
            maxHeight: spot.jellyMaxHeight,
            reactToPlayback: spot.reactsToPlayback,
            fade: fade,
            seed: spot.jellySeed,
          ),
        ),
        NamidaMascot.namiween => NamidaThemedField.halloween(
          opacity: spot.halloweenOpacity,
          fade: fade,
        ),
        null => const SizedBox(),
      },
    );
  }
}

/// The active mascot floating in place, for empty states and page headers.
class NamidaMascotFigure extends StatelessWidget {
  final double height;
  final double opacity;

  /// Recolors the jellys, namiween keeps its own colors.
  final Color? tint;

  const NamidaMascotFigure({
    super.key,
    required this.height,
    this.opacity = 1.0,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return switch (NamidaMascots.active) {
      NamidaMascot.jellys => FloatingJelly(
        height: height,
        opacity: opacity,
        tint: tint,
      ),
      NamidaMascot.namiween => _NamiweenFigure(
        height: height,
        opacity: opacity,
      ),
      null => const SizedBox(),
    };
  }
}

/// The active mascot resting at the very bottom of a long list, marking its end.
class NamidaMascotListEnd extends StatelessWidget {
  const NamidaMascotListEnd({super.key});

  @override
  Widget build(BuildContext context) {
    return switch (NamidaMascots.active) {
      NamidaMascot.jellys => const JellyListEnd(),
      NamidaMascot.namiween => const _NamiweenListEnd(),
      null => const SizedBox(),
    };
  }
}

/// A mascot's colors, handed out per track so a track keeps its color across sessions.
class NamidaMascotPalette {
  final List<Color> colors;
  final Color light;
  final Color dark;

  const NamidaMascotPalette({
    required this.colors,
    required this.light,
    required this.dark,
  });

  /// A full color set built around this key's color, for wherever a palette is expected.
  NamidaColor namidaColorFor(String? key, {double? opacity}) {
    if (key == null || key.isEmpty) {
      final color = opacity == null ? light : light.withOpacityExt(opacity);
      return NamidaColor.single(color);
    }
    final index = _hash(key) % colors.length;
    final color = colors[index];
    return NamidaColor.create(
      used: opacity == null ? color : color.withOpacityExt(opacity),
      palette: [
        color,
        colors[(index + 3) % colors.length],
        colors[(index + 5) % colors.length],
      ],
    );
  }

  /// FNV-1a, [String.hashCode] is not guaranteed stable between runs.
  static int _hash(String key) {
    var hash = 0x811C9DC5;
    for (int i = 0; i < key.length; i++) {
      hash = ((hash ^ key.codeUnitAt(i)) * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }
}

enum NamidaMascot {
  jellys,
  namiween,
}

enum _MascotBackgroundSpot {
  miniplayer(jellyCount: 5, jellyOpacity: 0.22, jellyMinHeight: 140.0, jellyMaxHeight: 380.0, jellySeed: 13, reactsToPlayback: true, halloweenOpacity: 0.45),
  panel(jellyCount: 4, jellyOpacity: 0.3, jellyMinHeight: 70.0, jellyMaxHeight: 210.0, jellySeed: 7, reactsToPlayback: true, halloweenOpacity: 0.5),
  youtubePlayer(jellyCount: 4, jellyOpacity: 0.25, jellyMinHeight: 100.0, jellyMaxHeight: 280.0, jellySeed: 17, reactsToPlayback: true, halloweenOpacity: 0.45),
  settings(jellyCount: 6, jellyOpacity: 0.32, jellyMinHeight: 90.0, jellyMaxHeight: 260.0, jellySeed: 0, reactsToPlayback: false, halloweenOpacity: 0.4),
  ;

  final int jellyCount;
  final double jellyOpacity;
  final double jellyMinHeight;
  final double jellyMaxHeight;
  final int jellySeed;
  final bool reactsToPlayback;
  final double halloweenOpacity;

  const _MascotBackgroundSpot({
    required this.jellyCount,
    required this.jellyOpacity,
    required this.jellyMinHeight,
    required this.jellyMaxHeight,
    required this.jellySeed,
    required this.reactsToPlayback,
    required this.halloweenOpacity,
  });
}