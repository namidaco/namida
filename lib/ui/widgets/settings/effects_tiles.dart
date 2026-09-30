import 'package:flutter/material.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/effects/effects.dart';

void _leaveHighPerformanceMode() {
  if (settings.performanceMode.value != PerformanceMode.highPerformance) return;
  settings.performanceMode.save(PerformanceMode.custom);
}

class EffectThemeTile extends StatelessWidget {
  final Color? bgColor;
  final bool _isOverlay;

  const EffectThemeTile.background({super.key, this.bgColor}) : _isOverlay = false;
  const EffectThemeTile.overlay({super.key, this.bgColor}) : _isOverlay = true;

  void _save(EffectTheme theme) {
    final key = _isOverlay ? settings.effectsOverlay : settings.effectsBackground;
    settings.transaction(() {
      key.save(theme);
      if (theme != EffectTheme.none) _leaveHighPerformanceMode();
    });
  }

  void _onSelected(EffectTheme theme) {
    if (!theme.isForSupporters()) return _save(theme);
    SussyBaka.monetize(onEnable: () => _save(theme));
  }

  Iterable<NamidaPopupItem> _getItems() {
    final key = _isOverlay ? settings.effectsOverlay : settings.effectsBackground;
    final current = key.value;
    return EffectTheme.values.map(
      (e) => NamidaPopupItem(
        selected: e == current,
        icon: e.toIcon(),
        title: e.toText(),
        onTap: () => _onSelected(e),
        trailing: e.isForSupporters() ? const _SupportersMark() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final key = _isOverlay ? settings.effectsOverlay : settings.effectsBackground;
    final subtitle = _isOverlay ? lang.overlayEffectSubtitle : lang.seasonalEffectsSubtitle;
    return NamidaPopupWrapper(
      childrenDefault: _getItems,
      child: CustomListTile(
        bgColor: bgColor,
        icon: _isOverlay ? Broken.layer : Broken.magic_star,
        title: _isOverlay ? lang.overlayEffect : lang.backgroundEffect,
        subtitle: '$subtitle\n${lang.performanceNote}',
        trailing: NamidaPopupWrapper(
          childrenDefault: _getItems,
          child: ObxO(
            rx: key,
            builder: (context, theme) => Text(
              theme.toText(),
              style: textTheme.displayMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ),
      ),
    );
  }
}

class VisualizerTile extends StatelessWidget {
  final Color? bgColor;

  const VisualizerTile({super.key, this.bgColor});

  void _toggleParticles() {
    final willEnable = !settings.enableMiniplayerParticles.value;
    settings.transaction(() {
      settings.enableMiniplayerParticles.save(willEnable);
      if (willEnable) _leaveHighPerformanceMode();
    });
  }

  void _toggleArtworkColors() {
    final willEnable = !settings.visualizerArtworkColors.value;
    settings.visualizerArtworkColors.save(willEnable);
  }

  void _enable(MiniplayerVisualizer style) {
    settings.transaction(() {
      settings.miniplayerVisualizers.update((styles) {
        if (style.isMainStyle()) styles.removeWhere((e) => e.isMainStyle());
        styles.add(style);
      });
      _leaveHighPerformanceMode();
    });
  }

  void _toggle(MiniplayerVisualizer style) {
    final isEnabled = settings.miniplayerVisualizers.value.contains(style);
    if (isEnabled) return settings.miniplayerVisualizers.update((styles) => styles.remove(style));
    if (!style.isForSupporters()) return _enable(style);
    SussyBaka.monetize(onEnable: () => _enable(style));
  }

  void _disableAll() {
    settings.transaction(() {
      settings.enableMiniplayerParticles.save(false);
      settings.miniplayerVisualizers.reset();
    });
  }

  NamidaPopupItem _toMainItem(MiniplayerVisualizer style, {required bool isEnabled, required bool hasDividerAbove}) {
    return NamidaPopupItem(
      selected: isEnabled,
      hasDividerAbove: hasDividerAbove,
      icon: style.toIcon(),
      title: style.toText(),
      onTap: () => _toggle(style),
      trailing: style.isForSupporters() ? const _SupportersMark() : null,
    );
  }

  NamidaPopupItem _toExtraItem(MiniplayerVisualizer style, {required bool isEnabled}) {
    return NamidaPopupItem(
      icon: style.toIcon(),
      title: style.toText(),
      onTap: () => _toggle(style),
      trailing: _ExtraSwitch(
        isActive: isEnabled,
        isForSupporters: style.isForSupporters(),
      ),
    );
  }

  List<NamidaPopupItem> _getItems() {
    final hasParticles = settings.enableMiniplayerParticles.value;
    final enabled = settings.miniplayerVisualizers.value;
    const styles = MiniplayerVisualizer.values;
    final mainStyles = styles.where((e) => e.isMainStyle());
    final extras = styles.where((e) => !e.isMainStyle());
    final firstMainStyle = mainStyles.first;
    return [
      NamidaPopupItem(
        selected: !hasParticles && enabled.isEmpty,
        icon: Broken.slash,
        title: lang.disableAll,
        onTap: _disableAll,
      ),
      ...mainStyles.map(
        (e) => _toMainItem(
          e,
          isEnabled: enabled.contains(e),
          hasDividerAbove: e == firstMainStyle,
        ),
      ),
      NamidaPopupItem(
        hasDividerAbove: true,
        icon: Broken.buy_crypto,
        title: lang.particles,
        onTap: _toggleParticles,
        trailing: _ExtraSwitch(
          isActive: hasParticles,
          isForSupporters: false,
        ),
      ),
      ...extras.map(
        (e) => _toExtraItem(
          e,
          isEnabled: enabled.contains(e),
        ),
      ),
      NamidaPopupItem(
        hasDividerAbove: true,
        icon: Broken.colorfilter,
        title: lang.colorPalette,
        onTap: _toggleArtworkColors,
        trailing: _ExtraSwitch(
          isActive: settings.visualizerArtworkColors.value,
          isForSupporters: false,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final refreshListenable = Listenable.merge([settings.enableMiniplayerParticles, settings.miniplayerVisualizers, settings.visualizerArtworkColors]);
    return NamidaPopupWrapper(
      childrenDefault: _getItems,
      refreshListenable: refreshListenable,
      child: CustomListTile(
        bgColor: bgColor,
        icon: Broken.buy_crypto,
        title: lang.visualizer,
        subtitle: lang.performanceNote,
        trailing: NamidaPopupWrapper(
          childrenDefault: _getItems,
          refreshListenable: refreshListenable,
          child: const _EnabledVisualizersText(),
        ),
      ),
    );
  }
}

class PlayerBackgroundTile extends StatelessWidget {
  final Color? bgColor;

  const PlayerBackgroundTile({super.key, this.bgColor});

  void _openOptions() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.playerBackground,
        normalTitleStyle: true,
        icon: Broken.gallery,
        actions: const [
          DoneButton(),
        ],
        child: const _PlayerBackgroundOptions(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return CustomListTile(
      bgColor: bgColor,
      icon: Broken.gallery,
      title: lang.playerBackground,
      subtitle: lang.performanceNote,
      onTap: _openOptions,
      trailing: ObxO(
        rx: settings.playerBackground,
        builder: (context, source) => Text(
          source.toText(),
          style: textTheme.displayMedium,
          textAlign: TextAlign.end,
        ),
      ),
    );
  }
}

class AppWallpaperTile extends StatelessWidget {
  final Color? bgColor;

  const AppWallpaperTile({super.key, this.bgColor});

  void _openOptions() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.wallpaper,
        normalTitleStyle: true,
        icon: Broken.gallery,
        actions: const [
          DoneButton(),
        ],
        child: const _AppWallpaperOptions(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return ObxO(
      rx: settings.extra.backgroundImages,
      builder: (context, backgroundImages) {
        if (backgroundImages != true) return const SizedBox();
        return CustomListTile(
          bgColor: bgColor,
          icon: Broken.gallery,
          title: lang.wallpaper,
          onTap: _openOptions,
          trailing: ObxO(
            rx: settings.appWallpaper,
            builder: (context, path) => Text(
              path == null ? lang.none : lang.custom,
              style: textTheme.displayMedium,
              textAlign: TextAlign.end,
            ),
          ),
        );
      },
    );
  }
}

class BackgroundImagesFlagTile extends StatelessWidget {
  const BackgroundImagesFlagTile({super.key});

  void _toggle(bool wasEnabled) {
    if (!wasEnabled) return settings.extra.backgroundImages.save(true);
    settings.transaction(() {
      settings.extra.backgroundImages.save(false);
      if (settings.playerBackground.value == PlayerBackground.image) settings.playerBackground.save(PlayerBackground.none);
      _AppWallpaperOptions._removeImage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.extra.backgroundImages,
      builder: (context, backgroundImages) => CustomSwitchListTile(
        icon: Broken.gallery,
        value: backgroundImages ?? false,
        onChanged: _toggle,
        title: 'background_images'.toUpperCase(),
        subtitle: '${lang.wallpaper} & ${lang.playerBackground}',
      ),
    );
  }
}

class _PlayerBackgroundOptions extends StatelessWidget {
  const _PlayerBackgroundOptions();

  Future<bool> _pickImage() async {
    final previousPath = settings.playerBackgroundImage.value;
    final storedPath = await NamidaBackdrops.importImage(replacing: previousPath);
    if (storedPath == null) return false;
    settings.playerBackgroundImage.save(storedPath);
    return true;
  }

  void _save(PlayerBackground source) {
    settings.transaction(() {
      settings.playerBackground.save(source);
      if (source != PlayerBackground.none) _leaveHighPerformanceMode();
    });
  }

  Future<void> _selectImage() async {
    final isImageMissing = settings.playerBackgroundImage.value == null;
    if (isImageMissing) {
      final didPick = await _pickImage();
      if (!didPick) return;
    }
    _save(PlayerBackground.image);
  }

  void _onSourceSelected(PlayerBackground source) {
    if (source != PlayerBackground.image) return _save(source);
    SussyBaka.monetize(onEnable: _selectImage);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final source = settings.playerBackground.valueR;
        final imagePath = settings.playerBackgroundImage.valueR;
        final backgroundImages = settings.extra.backgroundImages.valueR == true;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...PlayerBackground.values.where((e) => backgroundImages || e != PlayerBackground.image).map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: ListTileWithCheckMark(
                  active: e == source,
                  icon: e.toIcon(),
                  title: e.toText(),
                  titleWidget: e == PlayerBackground.image ? _SupportersTitle(title: e.toText()) : null,
                  onTap: () => _onSourceSelected(e),
                ),
              ),
            ),
            if (source == PlayerBackground.image)
              CustomListTile(
                icon: Broken.gallery_add,
                title: lang.pickFromStorage,
                subtitle: imagePath?.getFilename,
                maxSubtitleLines: 1,
                onTap: _pickImage,
              ),
            if (source != PlayerBackground.none) ...[
              const SizedBox(height: 8.0),
              _PercentageTile(
                icon: Broken.blur,
                title: lang.blur,
                min: NamidaBackdrops.minBlur,
                percentage: settings.playerBackgroundBlur.valueR,
                onChanged: settings.playerBackgroundBlur.save,
              ),
              _PercentageTile(
                icon: Broken.eye,
                title: lang.dimIntensity,
                min: NamidaBackdrops.minDim,
                percentage: settings.playerBackgroundDim.valueR,
                onChanged: settings.playerBackgroundDim.save,
              ),
              CustomSwitchListTile(
                icon: Broken.mask,
                title: lang.vignette,
                value: settings.playerBackgroundVignette.valueR,
                onChanged: (isTrue) => settings.playerBackgroundVignette.save(!isTrue),
              ),
              CustomSwitchListTile(
                icon: Broken.activity,
                title: lang.animated,
                value: settings.playerBackgroundAnimated.valueR,
                onChanged: (isTrue) => settings.playerBackgroundAnimated.save(!isTrue),
              ),
            ],
            CustomSwitchListTile(
              icon: Broken.colorfilter,
              title: lang.colorWhenExpanded,
              value: settings.playerColorWhenExpanded.valueR,
              onChanged: (isTrue) => settings.playerColorWhenExpanded.save(!isTrue),
            ),
          ],
        );
      },
    );
  }
}

class _AppWallpaperOptions extends StatelessWidget {
  const _AppWallpaperOptions();

  Future<void> _pickImage() async {
    final previousPath = settings.appWallpaper.value;
    final storedPath = await NamidaBackdrops.importImage(replacing: previousPath);
    if (storedPath != null) settings.appWallpaper.save(storedPath);
  }

  void _onPickTap() {
    SussyBaka.monetize(onEnable: _pickImage);
  }

  static void _removeImage() {
    final path = settings.appWallpaper.value;
    if (path == null) return;
    settings.appWallpaper.reset();
    NamidaBackdrops.removeImage(path);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final imagePath = settings.appWallpaper.valueR;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomListTile(
              icon: Broken.gallery_add,
              title: lang.pickFromStorage,
              subtitle: imagePath?.getFilename,
              maxSubtitleLines: 1,
              onTap: _onPickTap,
              trailing: const _SupportersMark(),
            ),
            if (imagePath != null) ...[
              CustomListTile(
                icon: Broken.gallery_slash,
                title: lang.remove,
                onTap: _removeImage,
              ),
              _PercentageTile(
                icon: Broken.blur,
                title: lang.blur,
                min: NamidaBackdrops.minBlur,
                percentage: settings.appWallpaperBlur.valueR,
                onChanged: settings.appWallpaperBlur.save,
              ),
              _PercentageTile(
                icon: Broken.eye,
                title: lang.dimIntensity,
                min: NamidaBackdrops.minDim,
                percentage: settings.appWallpaperDim.valueR,
                onChanged: settings.appWallpaperDim.save,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _EnabledVisualizersText extends StatelessWidget {
  const _EnabledVisualizersText();

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Obx(
      (context) {
        final hasParticles = settings.enableMiniplayerParticles.valueR;
        final enabled = settings.miniplayerVisualizers.valueR;
        final firstStyle = enabled.firstOrNull;
        final firstName = hasParticles ? lang.particles : firstStyle?.toText();
        final othersCount = enabled.length + (hasParticles ? 1 : 0) - 1;
        final text = firstName == null
            ? lang.none
            : othersCount > 0
            ? '$firstName +$othersCount'
            : firstName;
        return Text(
          text,
          style: textTheme.displayMedium,
          textAlign: TextAlign.end,
        );
      },
    );
  }
}

class _SupportersMark extends StatelessWidget {
  const _SupportersMark();

  @override
  Widget build(BuildContext context) {
    final iconColor = context.theme.iconTheme.color;
    final markColor = iconColor?.withOpacityExt(0.6);
    return Icon(
      Broken.crown_1,
      size: 14.0,
      color: markColor,
    );
  }
}

class _SupportersTitle extends StatelessWidget {
  final String title;

  const _SupportersTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            style: textTheme.displayMedium,
          ),
        ),
        const SizedBox(width: 6.0),
        const _SupportersMark(),
      ],
    );
  }
}

class _ExtraSwitch extends StatelessWidget {
  final bool isActive;
  final bool isForSupporters;

  const _ExtraSwitch({
    required this.isActive,
    required this.isForSupporters,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isForSupporters) ...[
          const _SupportersMark(),
          const SizedBox(width: 6.0),
        ],
        CustomSwitch(
          active: isActive,
          width: 30.0,
          height: 16.0,
        ),
      ],
    );
  }
}

class _PercentageTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final int min;
  final int percentage;
  final void Function(int percentage) onChanged;

  const _PercentageTile({
    required this.icon,
    required this.title,
    this.min = 0,
    required this.percentage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final percentageInRange = percentage.withMinimum(min);
    return CustomListTile(
      icon: icon,
      title: title,
      trailing: NamidaWheelSlider(
        min: min,
        max: 100,
        initValue: percentageInRange,
        onValueChanged: onChanged,
        text: '$percentageInRange%',
      ),
    );
  }
}

extension _EffectThemeAccess on EffectTheme {
  bool isForSupporters() => switch (this) {
    EffectTheme.starfield || EffectTheme.galaxy || EffectTheme.aurora || EffectTheme.fireworks || EffectTheme.deepOcean => true,
    EffectTheme.auto || //
    EffectTheme.none || //
    EffectTheme.particles || //
    EffectTheme.halloween || //
    EffectTheme.christmas || //
    EffectTheme.ramadan || //
    EffectTheme.sakura || //
    EffectTheme.rain || //
    EffectTheme.fireflies => false,
  };
}

extension _MiniplayerVisualizerAccess on MiniplayerVisualizer {
  bool isForSupporters() => switch (this) {
    MiniplayerVisualizer.mirroredBars || MiniplayerVisualizer.glow || MiniplayerVisualizer.outline || MiniplayerVisualizer.edgeLights => true,
    MiniplayerVisualizer.bars || MiniplayerVisualizer.waves || MiniplayerVisualizer.beatRings || MiniplayerVisualizer.reactiveParticles => false,
  };

  /// only one of them is on at a time, the rest go along with any.
  bool isMainStyle() => switch (this) {
    MiniplayerVisualizer.bars || MiniplayerVisualizer.mirroredBars || MiniplayerVisualizer.waves || MiniplayerVisualizer.outline => true,
    MiniplayerVisualizer.edgeLights || MiniplayerVisualizer.glow || MiniplayerVisualizer.beatRings || MiniplayerVisualizer.reactiveParticles => false,
  };
}
