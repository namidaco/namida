// all effects logic by claude
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_storage/namida_storage.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/spectrum_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/floating_image.dart';
import 'package:namida/ui/widgets/waveform.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

part 'effects.backdrops.dart';
part 'effects.field.dart';
part 'effects.scenery.dart';
part 'effects.seasons.dart';
part 'effects.sprites.dart';
part 'effects.themes.dart';
part 'effects.visualizers.dart';

abstract class NamidaEffects {
  static const _pace = 0.4;
  static const _backgroundOpacity = 0.5;
  static const _overlayOpacity = 0.3;

  static final season = Rxn<EffectTheme>(_Seasons.themeAt(DateTime.now()));

  static void refreshSeason() {
    season.value = _Seasons.themeAt(DateTime.now());
  }

  static void announceSeason() {
    final theme = season.value;
    if (theme == null) return;
    final isBackgroundFollowing = settings.effectsBackground.value == EffectTheme.auto;
    final followsSeason = isBackgroundFollowing || settings.effectsOverlay.value == EffectTheme.auto;
    if (!followsSeason) return;
    final seasonId = _Seasons.idAt(DateTime.now());
    if (seasonId == null || settings.extra.effectsSeasonAnnounced.value == seasonId) return;
    settings.extra.effectsSeasonAnnounced.save(seasonId);
    snackyy(
      icon: theme.toIcon(),
      title: theme.toText(),
      message: isBackgroundFollowing ? lang.backgroundEffect : lang.overlayEffect,
      displayDuration: SnackDisplayDuration.tutorial,
      button: SnackbarButton(
        text: lang.disable,
        function: _stopFollowingSeason,
      ),
    );
  }

  static void _stopFollowingSeason() {
    settings.transaction(() {
      if (settings.effectsBackground.value == EffectTheme.auto) settings.effectsBackground.save(EffectTheme.none);
      if (settings.effectsOverlay.value == EffectTheme.auto) settings.effectsOverlay.save(EffectTheme.none);
    });
  }
}

class NamidaEffectsLayer extends StatelessWidget {
  final _Layer _layer;

  const NamidaEffectsLayer.background({super.key}) : _layer = _Layer.background;
  const NamidaEffectsLayer.overlay({super.key}) : _layer = _Layer.overlay;

  @override
  Widget build(BuildContext context) {
    final layer = _layer;
    final choiceRx = layer == _Layer.background ? settings.effectsBackground : settings.effectsOverlay;
    return ObxO(
      rx: choiceRx,
      builder: (context, choice) => ObxO(
        rx: NamidaEffects.season,
        builder: (context, season) {
          final theme = choice == EffectTheme.auto ? season : choice;
          final preset = theme == null ? null : _presetOf(theme, layer);
          if (preset == null) return const SizedBox();
          return IgnorePointer(
            child: _EffectFieldView(
              preset: preset,
              opacity: layer == _Layer.background ? NamidaEffects._backgroundOpacity : NamidaEffects._overlayOpacity,
            ),
          );
        },
      ),
    );
  }
}

List<Color> _vividColorsOf(List<Color> palette, List<Color> fallback) {
  const maxColors = 4;
  const minHueDistance = 28.0;
  final vivid = <Color>[];
  final hues = <double>[];
  for (final color in palette) {
    final hsl = HSLColor.fromColor(color);
    final isDull = hsl.saturation < 0.3 || hsl.lightness < 0.22 || hsl.lightness > 0.9;
    if (isDull) continue;
    final hue = hsl.hue;
    final isRepeated = hues.any((picked) {
      final distance = (picked - hue).abs();
      return distance < minHueDistance || distance > 360 - minHueDistance;
    });
    if (isRepeated) continue;
    final saturation = hsl.saturation.withMinimum(0.6);
    final lightness = hsl.lightness.clampDouble(0.5, 0.75);
    final brightened = hsl.withSaturation(saturation).withLightness(lightness);
    hues.add(hue);
    vivid.add(brightened.toColor());
    if (vivid.length == maxColors) break;
  }
  return vivid.isEmpty ? fallback : vivid;
}

enum _Layer {
  background,
  overlay,
}
