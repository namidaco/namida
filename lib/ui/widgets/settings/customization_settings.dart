import 'package:flutter/material.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/eggs_data.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/setting_dialog_with_text_field.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/jellyfish.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/effects_tiles.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class CustomizationSettings extends SettingSubpageProvider {
  const CustomizationSettings({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.customization;

  @override
  List<List<SettingEntry>> get sections => _sections;

  static final _sections = <List<SettingEntry>>[
    [
      SettingCustom(
        title: () => lang.enableBlurEffect,
        keys: [settings.enableBlurEffect],
        tile: (args) => _PerformanceToggleTile(
          bgColor: args.bgColor,
          setting: settings.enableBlurEffect,
          icon: Broken.drop,
          title: lang.enableBlurEffect,
        ),
      ),
      SettingCustom(
        title: () => lang.enableGlowEffect,
        keys: [settings.enableGlowEffect],
        tile: (args) => _PerformanceToggleTile(
          bgColor: args.bgColor,
          setting: settings.enableGlowEffect,
          icon: Broken.sun_1,
          title: lang.enableGlowEffect,
        ),
      ),
      SettingCustom(
        title: () => lang.enableParallaxEffect,
        keys: [settings.enableMiniplayerParallaxEffect],
        tile: (args) => _PerformanceToggleTile(
          bgColor: args.bgColor,
          setting: settings.enableMiniplayerParallaxEffect,
          icon: Broken.maximize,
          title: lang.enableParallaxEffect,
        ),
      ),
      SettingCustom(
        title: () => lang.backgroundEffect,
        aliases: () => [lang.seasonalEffectsSubtitle, ..._getEffectThemesTexts()],
        keys: [settings.effectsBackground],
        tile: (args) => EffectThemeTile.background(
          bgColor: args.bgColor,
        ),
      ),
      SettingCustom(
        title: () => lang.overlayEffect,
        aliases: () => [lang.overlayEffectSubtitle, ..._getEffectThemesTexts()],
        keys: [settings.effectsOverlay],
        tile: (args) => EffectThemeTile.overlay(
          bgColor: args.bgColor,
        ),
      ),
      SettingCustom(
        visibleWhen: _isBackgroundImagesEnabled,
        title: () => lang.wallpaper,
        aliases: () => [lang.blur, lang.dimIntensity],
        keys: [settings.appWallpaper, settings.appWallpaperBlur, settings.appWallpaperDim],
        tile: (args) => AppWallpaperTile(
          bgColor: args.bgColor,
        ),
      ),
    ],
    [
      SettingCustom(
        title: () => lang.borderRadiusMultiplier,
        keys: [settings.borderRadiusMultiplier],
        tile: (args) => _TextFieldDialogTile(
          bgColor: args.bgColor,
          setting: settings.borderRadiusMultiplier,
          valueToText: (multiplier) => "$multiplier",
          icon: Broken.rotate_left_1,
          title: lang.borderRadiusMultiplier,
          onTap: () => showSettingDialogWithTextField(
            title: lang.borderRadiusMultiplier,
            borderRadiusMultiplier: true,
            icon: Broken.rotate_left_1,
          ),
        ),
      ),
      SettingCustom(
        title: () => lang.fontScale,
        keys: [settings.fontScaleFactor],
        tile: (args) => _TextFieldDialogTile(
          bgColor: args.bgColor,
          setting: settings.fontScaleFactor,
          valueToText: (scale) => "${(scale * 100).toInt()}%",
          icon: Broken.text,
          title: lang.fontScale,
          onTap: () => showSettingDialogWithTextField(
            title: lang.fontScale,
            fontScaleFactor: true,
            icon: Broken.text,
          ),
        ),
      ),
    ],
    [
      SettingToggle(
        settings.hourFormat12,
        icon: Broken.clock,
        title: () => lang.hourFormat12,
        onChanged: _onTrackTilePropChanged,
      ),
      SettingCustom(
        title: () => lang.dateTimeFormat,
        keys: [settings.dateTimeFormat],
        tile: (args) => _TextFieldDialogTile(
          bgColor: args.bgColor,
          setting: settings.dateTimeFormat,
          valueToText: (format) => format,
          icon: Broken.calendar_edit,
          title: lang.dateTimeFormat,
          onTap: () => showSettingDialogWithTextField(
            title: lang.dateTimeFormat,
            icon: Broken.calendar_edit,
            dateTimeFormat: true,
            topWidget: const _DateTimeFormatPresets(),
          ),
        ),
      ),
      SettingToggle(
        settings.player.displayRemainingDurInsteadOfTotal,
        icon: Broken.timer,
        title: () => lang.displayRemainingDurationInsteadOfTotal,
      ),
      SettingToggle(
        settings.player.displayActualPositionWhenSeeking,
        icon: Broken.settings,
        title: () => lang.displayActualPositionInsteadOfDifferenceWhileSeeking,
      ),
    ],
    [
      SettingCustom(
        availability: NamidaFeaturesAvailablity.android,
        title: () => lang.homeScreenWidget,
        tile: (args) => _HomeWidgetTile(
          bgColor: args.bgColor,
        ),
      ),
      SettingExpansion(
        leading: const StackedIcon(
          baseIcon: Broken.brush,
          secondaryIcon: Broken.music_dashboard,
        ),
        title: () => lang.albumTileCustomization,
        initiallyExpandedWhen: _shouldExpandGroups,
        children: [
          SettingToggle(
            settings.displayTrackNumberinAlbumPage,
            icon: Broken.card_remove,
            title: () => lang.displayTrackNumberInAlbumPage,
            subtitle: () => lang.displayTrackNumberInAlbumPageSubtitle,
          ),
          SettingToggle(
            settings.albumCardTopRightDate,
            icon: Broken.notification_status,
            title: () => lang.displayAlbumCardTopRightDate,
            subtitle: () => lang.displayAlbumCardTopRightDateSubtitle,
          ),
          SettingToggle(
            settings.forceSquaredAlbumThumbnail,
            icon: Broken.crop,
            title: () => lang.forceSquaredAlbumThumbnail,
            onChanged: _onForceSquaredAlbumThumbChanged,
          ),
          SettingToggle(
            settings.useAlbumStaggeredGridView,
            icon: Broken.element_4,
            title: () => lang.staggeredAlbumGridView,
          ),
          SettingCustom(
            title: () => lang.albumThumbnailSizeInList,
            keys: [settings.albumThumbnailSizeinList],
            tile: (args) => _TextFieldDialogTile(
              bgColor: args.bgColor,
              setting: settings.albumThumbnailSizeinList,
              valueToText: _toIntText,
              icon: Broken.maximize_3,
              title: lang.albumThumbnailSizeInList,
              onTap: () => showSettingDialogWithTextField(
                title: lang.albumThumbnailSizeInList,
                albumThumbnailSizeinList: true,
                icon: Broken.maximize_3,
              ),
            ),
          ),
          SettingCustom(
            title: () => lang.heightOfAlbumTile,
            keys: [settings.albumListTileHeight],
            tile: (args) => _TextFieldDialogTile(
              bgColor: args.bgColor,
              setting: settings.albumListTileHeight,
              valueToText: _toIntText,
              icon: Broken.pharagraphspacing,
              title: lang.heightOfAlbumTile,
              onTap: () => showSettingDialogWithTextField(
                title: lang.heightOfAlbumTile,
                albumListTileHeight: true,
                icon: Broken.pharagraphspacing,
              ),
            ),
          ),
        ],
      ),
      SettingCustom(
        title: () => lang.trackTileCustomization,
        keys: [settings.trackItem],
        tile: (args) => _TrackTileCustomizationTile(
          args: args,
        ),
        children: [
          SettingToggle(
            settings.forceSquaredTrackThumbnail,
            icon: Broken.crop,
            title: () => lang.forceSquaredTrackThumbnail,
            onChanged: _onForceSquaredTrackThumbChanged,
          ),
          SettingCustom(
            title: () => lang.trackThumbnailSizeInList,
            keys: [settings.trackThumbnailSizeinList],
            tile: (args) => _TextFieldDialogTile(
              bgColor: args.bgColor,
              setting: settings.trackThumbnailSizeinList,
              valueToText: _toIntText,
              icon: Broken.maximize_3,
              title: lang.trackThumbnailSizeInList,
              onTap: () => showSettingDialogWithTextField(
                title: lang.trackThumbnailSizeInList,
                trackThumbnailSizeinList: true,
                icon: Broken.maximize_3,
              ),
            ),
          ),
          SettingCustom(
            title: () => lang.heightOfTrackTile,
            keys: [settings.trackListTileHeight],
            tile: (args) => _TextFieldDialogTile(
              bgColor: args.bgColor,
              setting: settings.trackListTileHeight,
              valueToText: _toIntText,
              icon: Broken.pharagraphspacing,
              title: lang.heightOfTrackTile,
              onTap: () => showSettingDialogWithTextField(
                title: lang.heightOfTrackTile,
                trackListTileHeight: true,
                icon: Broken.pharagraphspacing,
              ),
            ),
          ),
          SettingExpansion(
            icon: Broken.arrow_swap_horizontal,
            title: () => lang.swipeActions,
            aliases: () => [lang.onSwiping],
            initiallyExpandedWhen: _isAlwaysExpanded,
            children: [
              SettingCustom(
                title: () => lang.leftAction,
                aliases: () => [lang.swipeActions],
                keys: [settings.onTrackSwipeLeft],
                tile: (args) => _TrackActionTile(
                  bgColor: args.bgColor,
                  setting: settings.onTrackSwipeLeft,
                  icon: Broken.arrow_left_1,
                  title: lang.leftAction,
                  isForPlayingItem: false,
                ),
              ),
              SettingCustom(
                title: () => lang.rightAction,
                aliases: () => [lang.swipeActions],
                keys: [settings.onTrackSwipeRight],
                tile: (args) => _TrackActionTile(
                  bgColor: args.bgColor,
                  setting: settings.onTrackSwipeRight,
                  icon: Broken.arrow_right,
                  title: lang.rightAction,
                  isForPlayingItem: false,
                ),
              ),
            ],
          ),
          SettingExpansion(
            icon: Broken.gallery,
            title: () => lang.artworkGestures,
            initiallyExpandedWhen: _isAlwaysExpanded,
            children: [
              SettingCustom(
                title: () => lang.tapAction,
                aliases: () => [lang.artwork],
                keys: [settings.thumbnailTapAction],
                tile: (args) => _TrackActionTile(
                  bgColor: args.bgColor,
                  setting: settings.thumbnailTapAction,
                  icon: Broken.cd,
                  title: lang.tapAction,
                  isForPlayingItem: false,
                ),
              ),
              SettingCustom(
                title: () => lang.longPressAction,
                aliases: () => [lang.artwork],
                keys: [settings.thumbnailLongPressAction],
                tile: (args) => _TrackActionTile(
                  bgColor: args.bgColor,
                  setting: settings.thumbnailLongPressAction,
                  icon: Broken.story,
                  title: lang.longPressAction,
                  isForPlayingItem: false,
                ),
              ),
            ],
          ),
          SettingCustom(
            title: () => lang.displayThirdRowInTrackTile,
            keys: [settings.displayThirdRow],
            tile: (args) => _TrackTileToggleTile(
              bgColor: args.bgColor,
              setting: settings.displayThirdRow,
              icon: Broken.chart_1,
              rotateIcon: 1,
              title: lang.displayThirdRowInTrackTile,
            ),
          ),
          SettingCustom(
            title: () => lang.displayThirdItemInRowInTrackTile,
            keys: [settings.displayThirdItemInEachRow],
            tile: (args) => _TrackTileToggleTile(
              bgColor: args.bgColor,
              setting: settings.displayThirdItemInEachRow,
              icon: Broken.coin,
              rotateIcon: 3,
              title: lang.displayThirdItemInRowInTrackTile,
            ),
          ),
          SettingToggle(
            settings.displayFavouriteIconInListTile,
            icon: Broken.heart,
            title: () => lang.displayFavouriteIconInTrackTile,
            onChanged: _onTrackTilePropChanged,
          ),
          SettingCustom(
            title: () => lang.trackTileItemsSeparator,
            keys: [settings.trackTileSeparator],
            tile: (args) => _TextFieldDialogTile(
              bgColor: args.bgColor,
              setting: settings.trackTileSeparator,
              valueToText: (separator) => separator,
              icon: Broken.minus_square,
              title: lang.trackTileItemsSeparator,
              onTap: () => showSettingDialogWithTextField(
                title: lang.trackTileItemsSeparator,
                trackTileSeparator: true,
                icon: Broken.minus_square,
              ),
            ),
          ),
          SettingCustom(
            title: () => lang.trackArtistsDisplaySeparator,
            keys: [settings.trackArtistsDisplaySeparator],
            tile: (args) => _TextFieldDialogTile(
              bgColor: args.bgColor,
              setting: settings.trackArtistsDisplaySeparator,
              valueToText: (separator) => separator.isEmpty ? null : 'A${separator}B',
              icon: Broken.profile_2user,
              title: lang.trackArtistsDisplaySeparator,
              onTap: () => showSettingDialogWithTextField(
                title: lang.trackArtistsDisplaySeparator,
                trackArtistsDisplaySeparator: true,
                icon: Broken.profile_2user,
              ),
            ),
          ),
        ],
      ),
      SettingExpansion(
        leading: const StackedIcon(
          baseIcon: Broken.brush,
          secondaryIcon: Broken.external_drive,
        ),
        title: () => lang.miniplayerCustomization,
        initiallyExpandedWhen: _shouldExpandGroups,
        children: [
          SettingCustom(
            title: () => lang.enablePartyMode,
            aliases: () => [lang.enablePartyModeSubtitle],
            keys: [settings.enablePartyModeInMiniplayer],
            tile: (args) => _PartyModeTile(
              args: args,
            ),
            children: [
              SettingToggle(
                settings.enablePartyModeColorSwap,
                icon: Broken.colors_square,
                title: () => lang.edgeColorsSwitching,
                enabledWhen: _isPartyModeEnabled,
                onChanged: _onEdgeColorsSwitchingChanged,
              ),
            ],
          ),
          SettingCustom(
            title: () => lang.visualizer,
            aliases: () => [lang.enableMiniplayerParticles, ...MiniplayerVisualizer.values.map((e) => e.toText())],
            keys: [settings.miniplayerVisualizers, settings.enableMiniplayerParticles, settings.visualizerArtworkColors],
            tile: (args) => VisualizerTile(
              bgColor: args.bgColor,
            ),
          ),
          SettingCustom(
            title: () => lang.playerBackground,
            aliases: () => [lang.artwork, lang.blur, lang.dimIntensity, lang.colorWhenExpanded],
            keys: [
              settings.playerBackground, settings.playerBackgroundImage, settings.playerBackgroundBlur, settings.playerBackgroundDim, //
              settings.playerBackgroundVignette, settings.playerBackgroundAnimated, settings.playerColorWhenExpanded, //
            ],
            tile: (args) => PlayerBackgroundTile(
              bgColor: args.bgColor,
            ),
          ),
          SettingExpansion(
            icon: Broken.flash,
            title: () => lang.animatingThumbnailIntensity,
            initiallyExpandedWhen: _isAlwaysExpanded,
            children: [
              SettingCustom(
                title: () => lang.expandedMiniplayer,
                aliases: () => [lang.animatingThumbnailIntensity],
                keys: [settings.animatingThumbnailIntensity],
                tile: (args) => _ThumbnailIntensityTile(
                  bgColor: args.bgColor,
                  setting: settings.animatingThumbnailIntensity,
                  icon: Broken.flash,
                  title: lang.expandedMiniplayer,
                ),
              ),
              SettingCustom(
                title: () => lang.lyrics,
                aliases: () => [lang.animatingThumbnailIntensity],
                keys: [settings.animatingThumbnailIntensityLyrics],
                tile: (args) => _ThumbnailIntensityTile(
                  bgColor: args.bgColor,
                  setting: settings.animatingThumbnailIntensityLyrics,
                  leading: const StackedIcon(
                    baseIcon: Broken.flash,
                    secondaryIcon: Broken.document,
                    secondaryIconSize: 10.0,
                  ),
                  title: lang.lyrics,
                ),
              ),
              SettingCustom(
                title: () => lang.minimizedMiniplayer,
                aliases: () => [lang.animatingThumbnailIntensity],
                keys: [settings.animatingThumbnailIntensityMinimized],
                tile: (args) => _ThumbnailIntensityTile(
                  bgColor: args.bgColor,
                  setting: settings.animatingThumbnailIntensityMinimized,
                  leading: const StackedIcon(
                    baseIcon: Broken.flash,
                    secondaryIcon: Broken.arrow_square_down,
                    secondaryIconSize: 11.0,
                  ),
                  title: lang.minimizedMiniplayer,
                ),
              ),
            ],
          ),
          SettingToggle(
            settings.animatingThumbnailInversed,
            icon: Broken.arrange_circle_2,
            title: () => lang.animatingThumbnailInversed,
            subtitle: () => lang.animatingThumbnailInversedSubtitle,
          ),
          SettingCustom(
            title: () => lang.artworkGestures,
            keys: [settings.artworkGestureDoubleTapLRC, settings.animatingThumbnailScaleMultiplier, settings.artworkTapAction, settings.artworkLongPressAction],
            tile: (args) => _ArtworkGesturesTile(
              args: args,
            ),
            children: [
              SettingCustom(
                title: () => lang.scaleMultiplier,
                keys: [settings.animatingThumbnailScaleMultiplier],
                tile: (args) => _ScaleMultiplierTile(
                  bgColor: args.bgColor,
                ),
              ),
              SettingToggle(
                settings.artworkGestureDoubleTapLRC,
                leading: const StackedIcon(
                  baseIcon: Broken.document,
                  secondaryIcon: Broken.blend_2,
                  secondaryIconSize: 12.0,
                ),
                title: () => lang.doubleTapToToggleLyrics,
              ),
              SettingCustom(
                title: () => lang.tapAction,
                aliases: () => [lang.artwork],
                keys: [settings.artworkTapAction],
                tile: (args) => _TrackActionTile(
                  bgColor: args.bgColor,
                  setting: settings.artworkTapAction,
                  icon: Broken.cd,
                  title: lang.tapAction,
                  isForPlayingItem: true,
                ),
              ),
              SettingCustom(
                title: () => lang.longPressAction,
                aliases: () => [lang.artwork],
                keys: [settings.artworkLongPressAction],
                tile: (args) => _TrackActionTile(
                  bgColor: args.bgColor,
                  setting: settings.artworkLongPressAction,
                  icon: Broken.story,
                  title: lang.longPressAction,
                  isForPlayingItem: true,
                ),
              ),
            ],
          ),
          SettingCustom(
            title: () => lang.waveformBarsCount,
            keys: [settings.waveformTotalBars],
            tile: (args) => _WaveformBarsTile(
              bgColor: args.bgColor,
            ),
          ),
          SettingToggle(
            settings.displayAudioInfoMiniplayer,
            icon: Broken.text_block,
            title: () => lang.displayAudioInfoInMiniplayer,
          ),
          SettingToggle(
            settings.displayArtistBeforeTitle,
            icon: Broken.align_left,
            title: () => lang.displayArtistBeforeTitle,
            onChanged: _onDisplayArtistBeforeTitleChanged,
          ),
        ],
      ),
      SettingCustom(
        availability: NamidaFeaturesAvailablity.android,
        title: () => lang.appIcon,
        tile: (args) => _AppIconsTile(
          bgColor: args.bgColor,
        ),
      ),
    ],
  ];

  static List<String> _getEffectThemesTexts() => [
    for (final e in EffectTheme.values)
      if (e != EffectTheme.auto && e != EffectTheme.none) e.toText(),
  ];

  static bool _shouldExpandGroups() => settings.useSettingCollapsedTiles.value;

  static bool _isAlwaysExpanded() => true;

  static bool _isPartyModeEnabled() => settings.enablePartyModeInMiniplayer.valueR;

  static bool _isBackgroundImagesEnabled() => settings.backgroundImages.valueR == true;

  static String _toIntText(double value) => "${value.toInt()}";

  static void _onTrackTilePropChanged(bool _) => TrackTileManager.onTrackItemPropChange();

  static void _onEdgeColorsSwitchingChanged(bool isEnabled) => CurrentColor.inst.switchColorPalettes(swapEnabled: isEnabled);

  static void _onDisplayArtistBeforeTitleChanged(bool _) => Player.inst.refreshRxVariables();

  static void _onForceSquaredAlbumThumbChanged(bool isEnabled) {
    if (!isEnabled) return;
    _promptSquaredThumbnailSize(
      sizeSetting: settings.albumThumbnailSizeinList,
      heightSetting: settings.albumListTileHeight,
    );
  }

  static void _onForceSquaredTrackThumbChanged(bool isEnabled) {
    Player.inst.refreshRxVariables();
    TrackTileManager.onTrackItemPropChange();
    if (!isEnabled) return;
    _promptSquaredThumbnailSize(
      sizeSetting: settings.trackThumbnailSizeinList,
      heightSetting: settings.trackListTileHeight,
    );
  }

  static void _promptSquaredThumbnailSize({required SettingsKey<double> sizeSetting, required SettingsKey<double> heightSetting}) {
    final isAlreadySquared = sizeSetting.value.toInt() == heightSetting.value.toInt();
    if (isAlreadySquared) return;
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        isWarning: true,
        bodyText: lang.forceSquaredThumbnailNote,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.confirm,
            onTap: () {
              sizeSetting.save(heightSetting.value);
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.customizations,
      subtitle: lang.customizationsSubtitle,
      icon: Broken.brush_1,
      child: SettingSectionsColumn(
        page: this,
      ),
    );
  }
}

class _PerformanceToggleTile extends StatelessWidget {
  final Color? bgColor;
  final SettingsKey<bool> setting;
  final IconData icon;
  final String title;

  const _PerformanceToggleTile({
    required this.bgColor,
    required this.setting,
    required this.icon,
    required this.title,
  });

  void _onChanged(bool wasEnabled) {
    settings.transaction(() {
      setting.save(!wasEnabled);
      settings.performanceMode.save(PerformanceMode.custom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: setting,
      builder: (context, isEnabled) => CustomSwitchListTile(
        bgColor: bgColor,
        icon: icon,
        title: title,
        subtitle: lang.performanceNote,
        value: isEnabled,
        onChanged: _onChanged,
      ),
    );
  }
}

class _TextFieldDialogTile<T> extends StatelessWidget {
  final Color? bgColor;
  final SettingsKey<T> setting;
  final String? Function(T value) valueToText;
  final IconData icon;
  final String title;
  final void Function() onTap;

  const _TextFieldDialogTile({
    required this.bgColor,
    required this.setting,
    required this.valueToText,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: setting,
      builder: (context, value) => CustomListTile(
        bgColor: bgColor,
        icon: icon,
        title: title,
        trailingText: valueToText(value),
        onTap: onTap,
      ),
    );
  }
}

class _DateTimeFormatPresets extends StatelessWidget {
  const _DateTimeFormatPresets();

  void _onPresetTap(String format) {
    settings.dateTimeFormat.save(format);
    TrackTileManager.onTrackItemPropChange();
    NamidaNavigator.inst.closeDialog();
  }

  @override
  Widget build(BuildContext context) {
    final currentFormat = settings.dateTimeFormat.value;
    return SizedBox(
      height: namida.height * 0.4,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 58.0),
        child: NamidaScrollbarWithController(
          showOnStart: true,
          child: (c) => SmoothSingleChildScrollView(
            controller: c,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...kDefaultDateTimeStrings.entries.map(
                  (e) => CustomListTile(
                    extraDense: true,
                    title: e.value,
                    subtitle: e.key,
                    icon: e.key == currentFormat ? Broken.arrow_circle_right : Broken.arrow_right_3,
                    onTap: () => _onPresetTap(e.key),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeWidgetTile extends StatelessWidget {
  final Color? bgColor;

  const _HomeWidgetTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
      icon: Broken.element_4,
      title: lang.homeScreenWidget,
      trailingRaw: const Icon(
        Broken.arrow_right_3,
        size: 20.0,
      ),
      onTap: NamidaChannel.inst.openHomeWidgetSettings,
    );
  }
}

class _TrackTileCustomizationTile extends StatelessWidget {
  final SettingTileArgs args;

  const _TrackTileCustomizationTile({required this.args});

  @override
  Widget build(BuildContext context) {
    final page = args.page;
    final isTargetWithin = page?.isTargetWithin(args.entry) == true;
    final initiallyExpanded = settings.useSettingCollapsedTiles.value || isTargetWithin;
    final children = [
      ...args.entry.children.map(
        (e) => SettingEntryTile(
          entry: e,
          page: page,
        ),
      ),
      const _TrackTilePreview(),
    ];
    return NamidaExpansionTile(
      bgColor: args.bgColor,
      initiallyExpanded: initiallyExpanded,
      leading: const StackedIcon(
        baseIcon: Broken.brush,
        secondaryIcon: Broken.music_circle,
      ),
      titleText: lang.trackTileCustomization,
      children: children,
    );
  }
}

class _TrackActionTile extends StatelessWidget {
  final Color? bgColor;
  final SettingsKey<TrackExecuteActions> setting;
  final IconData icon;
  final String title;
  final bool isForPlayingItem;

  const _TrackActionTile({
    required this.bgColor,
    required this.setting,
    required this.icon,
    required this.title,
    required this.isForPlayingItem,
  });

  bool _isAvailable(TrackExecuteActions action) {
    if (isForPlayingItem) return !action.isPlayerAction && action != TrackExecuteActions.delete;
    return !action.isPlayingItemOnly && action != TrackExecuteActions.focus;
  }

  void _onSelected(TrackExecuteActions action) {
    setting.save(action);
    NamidaNavigator.inst.popMenu();
  }

  Iterable<NamidaPopupItem> _getItems() {
    final current = setting.value;
    return TrackExecuteActions.values
        .where(_isAvailable)
        .map(
          (e) => NamidaPopupItem(
            icon: e.toIcon(),
            title: e.toText(),
            selected: e == current,
            onTap: () => _onSelected(e),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      childrenDefault: _getItems,
      child: CustomListTile(
        extraDense: true,
        bgColor: bgColor,
        icon: icon,
        title: title,
        trailing: NamidaPopupWrapper(
          childrenDefault: _getItems,
          child: ObxO(
            rx: setting,
            builder: (context, action) => NamidaText(
              action.toText(),
              style: NText.medium,
              textAlign: TextAlign.end,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackTileToggleTile extends StatelessWidget {
  final Color? bgColor;
  final SettingsKey<bool> setting;
  final IconData icon;
  final int rotateIcon;
  final String title;

  const _TrackTileToggleTile({
    required this.bgColor,
    required this.setting,
    required this.icon,
    required this.rotateIcon,
    required this.title,
  });

  void _onChanged(bool wasEnabled) {
    setting.save(!wasEnabled);
    TrackTileManager.onTrackItemPropChange();
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: setting,
      builder: (context, isEnabled) => CustomSwitchListTile(
        bgColor: bgColor,
        icon: icon,
        rotateIcon: rotateIcon,
        title: title,
        value: isEnabled,
        onChanged: _onChanged,
      ),
    );
  }
}

class _TrackTilePreview extends StatelessWidget {
  const _TrackTilePreview();

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final trackItems = settings.trackItem.valueR;
        final thumbnailSize = settings.trackThumbnailSizeinList.valueR;
        final tileHeight = settings.trackListTileHeight.valueR;
        final isThirdItemShown = settings.displayThirdItemInEachRow.valueR;
        final isThirdRowShown = settings.displayThirdRow.valueR;
        final isFavouriteShown = settings.displayFavouriteIconInListTile.valueR;
        final isForceSquared = settings.forceSquaredTrackThumbnail.valueR;
        final track = allTracksInLibrary.firstOrNull;
        final imagePath = track?.pathToImage;
        final artworkKeyText = imagePath ?? '';
        final rightItems = [TrackTilePosition.rightItem1, TrackTilePosition.rightItem2]
            .map(
              (e) => _TrackItemSmallBox(
                position: e,
                text: trackItems[e]?.label,
              ),
            )
            .addSeparators(
              separator: const SizedBox(
                height: 3.0,
              ),
            );
        return NContainer(
          color: NColors.cardTheme,
          width: context.width,
          height: tileHeight * 1.5,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 7.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              const SizedBox(
                width: 12.0,
              ),
              SizedBox(
                width: thumbnailSize,
                height: thumbnailSize,
                child: ArtworkWidget(
                  key: Key(artworkKeyText),
                  track: track,
                  thumbnailSize: thumbnailSize,
                  path: imagePath,
                  forceSquared: isForceSquared,
                ),
              ),
              const SizedBox(
                width: 12.0,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TrackTilePreviewRow(
                      trackItems: trackItems,
                      positions: [
                        TrackTilePosition.row1Item1,
                        TrackTilePosition.row1Item2,
                        if (isThirdItemShown) TrackTilePosition.row1Item3,
                      ],
                    ),
                    const SizedBox(
                      height: 4.0,
                    ),
                    _TrackTilePreviewRow(
                      trackItems: trackItems,
                      positions: [
                        TrackTilePosition.row2Item1,
                        TrackTilePosition.row2Item2,
                        if (isThirdItemShown) TrackTilePosition.row2Item3,
                      ],
                    ),
                    const SizedBox(
                      height: 4.0,
                    ),
                    if (isThirdRowShown)
                      _TrackTilePreviewRow(
                        trackItems: trackItems,
                        positions: [
                          TrackTilePosition.row3Item1,
                          TrackTilePosition.row3Item2,
                          if (isThirdItemShown) TrackTilePosition.row3Item3,
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(
                width: 6.0,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...rightItems,
                  if (isFavouriteShown) ...[
                    const SizedBox(
                      height: 3.0,
                    ),
                    const NamidaRawLikeButton(
                      size: 20.0,
                      isLiked: null,
                      removeConfirmationAction: null,
                      onTap: null,
                    ),
                  ],
                ],
              ),
              const SizedBox(
                width: 6.0,
              ),
              const MoreIcon(
                iconSize: 20.0,
              ),
              const SizedBox(
                width: 6.0,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrackTilePreviewRow extends StatelessWidget {
  final Map<TrackTilePosition, TrackTileItem> trackItems;
  final List<TrackTilePosition> positions;

  const _TrackTilePreviewRow({
    required this.trackItems,
    required this.positions,
  });

  @override
  Widget build(BuildContext context) {
    final boxes = positions
        .map(
          (e) => _TrackItemSmallBox(
            position: e,
            text: trackItems[e]?.label,
          ),
        )
        .addSeparators(
          separator: const SizedBox(
            width: 6.0,
          ),
        )
        .toFixedList();
    return FittedBox(
      child: Row(
        children: boxes,
      ),
    );
  }
}

class _TrackItemSmallBox extends StatelessWidget {
  final TrackTilePosition position;
  final String? text;

  const _TrackItemSmallBox({
    required this.position,
    required this.text,
  });

  Iterable<Widget> _getChildren() {
    return TrackTileItem.values.map(
      (e) => ObxO(
        rx: settings.trackItem,
        builder: (context, trackItemMap) => SmallListTile(
          borderRadius: 12.0,
          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
          title: e.toText(),
          trailingIcon: e.toIcon(),
          active: trackItemMap[position] == e,
          onTap: () {
            settings.trackItem.update((items) => items[position] = e);
            TrackTileManager.onTrackItemPropChange();
            NamidaNavigator.inst.popMenu();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    return NamidaPopupWrapper(
      children: _getChildren,
      child: NDecoratedBox(
        decoration: (colors) => BoxDecoration(
          color: colors.surface.withOpacityExt(0.63),
          borderRadius: BorderRadius.circular(8.0.multipliedRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: text == null
              ? null
              : NamidaText(
                  text,
                  style: NText.small,
                ),
        ),
      ),
    );
  }
}

class _PartyModeTile extends StatelessWidget {
  final SettingTileArgs args;

  const _PartyModeTile({required this.args});

  void _toggle() {
    final setting = settings.enablePartyModeInMiniplayer;
    if (setting.value) return setting.save(false);
    SussyBaka.monetize(unlockable: EggUnlockable.partyMode, onEnable: () => setting.save(true));
  }

  @override
  Widget build(BuildContext context) {
    final page = args.page;
    final setting = settings.enablePartyModeInMiniplayer;
    final isTargetWithin = page?.isTargetWithin(args.entry) == true;
    final initiallyExpanded = setting.value || isTargetWithin;
    final children = args.entry.children
        .map(
          (e) => SettingEntryTile(
            entry: e,
            page: page,
          ),
        )
        .toFixedList();
    return NamidaExpansionTile(
      bgColor: args.bgColor,
      initiallyExpanded: initiallyExpanded,
      expandedRx: setting,
      onTap: _toggle,
      icon: Broken.slider_horizontal_1,
      titleText: lang.enablePartyMode,
      subtitleText: lang.enablePartyModeSubtitle,
      trailingBuilder: (_) => ObxO(
        rx: setting,
        builder: (context, isEnabled) => CustomSwitch(
          active: isEnabled,
        ),
      ),
      children: children,
    );
  }
}

class _ThumbnailIntensityTile extends StatelessWidget {
  final Color? bgColor;
  final SettingsKey<int> setting;
  final IconData? icon;
  final Widget? leading;
  final String title;

  const _ThumbnailIntensityTile({
    required this.bgColor,
    required this.setting,
    this.icon,
    this.leading,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: setting,
      builder: (context, intensity) {
        final percentageText = (intensity * 4).toStringAsFixed(0);
        return CustomListTile(
          extraDense: true,
          bgColor: bgColor,
          icon: icon,
          leading: leading,
          title: title,
          trailing: NamidaWheelSlider(
            max: 25,
            initValue: intensity,
            onValueChanged: setting.save,
            text: "$percentageText%",
          ),
        );
      },
    );
  }
}

class _ArtworkGesturesTile extends StatelessWidget {
  final SettingTileArgs args;

  const _ArtworkGesturesTile({required this.args});

  void _restoreDefaults() {
    settings.transaction(() {
      settings.artworkGestureDoubleTapLRC.reset();
      settings.animatingThumbnailScaleMultiplier.reset();
      settings.artworkTapAction.reset();
      settings.artworkLongPressAction.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = args.page;
    final children = [
      ...args.entry.children.map(
        (e) => SettingEntryTile(
          entry: e,
          page: page,
        ),
      ),
      const SizedBox(
        height: 6.0,
      ),
    ];
    return NamidaExpansionTile(
      bgColor: args.bgColor,
      icon: Broken.gallery,
      initiallyExpanded: true,
      titleText: lang.artworkGestures,
      trailingBuilder: (arrow) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NamidaIconButton(
            tooltip: () => lang.restoreDefaults,
            icon: Broken.refresh,
            iconSize: 20.0,
            onPressed: _restoreDefaults,
          ),
          const SizedBox(
            width: 4.0,
          ),
          arrow,
          const SizedBox(
            width: 12.0,
          ),
        ],
      ),
      children: children,
    );
  }
}

class _ScaleMultiplierTile extends StatelessWidget {
  final Color? bgColor;

  const _ScaleMultiplierTile({required this.bgColor});

  void _onValueChanged(int valueHundred) => settings.animatingThumbnailScaleMultiplier.save(valueHundred / 100);

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.animatingThumbnailScaleMultiplier,
      builder: (context, multiplier) {
        final valueHundred = (multiplier * 100).round();
        return CustomListTile(
          extraDense: true,
          bgColor: bgColor,
          icon: Broken.maximize,
          title: lang.scaleMultiplier,
          trailing: NamidaWheelSlider(
            min: 50,
            max: 150,
            initValue: valueHundred,
            onValueChanged: _onValueChanged,
            text: "$valueHundred%",
          ),
        );
      },
    );
  }
}

class _WaveformBarsTile extends StatelessWidget {
  final Color? bgColor;

  const _WaveformBarsTile({required this.bgColor});

  void _onValueChanged(int bars) {
    settings.waveformTotalBars.save(bars);
    WaveformController.inst.calculateUIWaveform();
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.waveformTotalBars,
      builder: (context, bars) => CustomListTile(
        bgColor: bgColor,
        icon: Broken.sound,
        title: lang.waveformBarsCount,
        trailing: NamidaWheelSlider(
          width: 80,
          min: 40,
          max: 400,
          initValue: bars,
          onValueChanged: _onValueChanged,
          text: bars.toString(),
        ),
      ),
    );
  }
}

class _AppIconsTile extends StatelessWidget {
  final Color? bgColor;

  const _AppIconsTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NamidaContainerDivider(),
        DecoratedBox(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12.0.multipliedRadius),
          ),
          child: const _AppIconWidgetRow(),
        ),
      ],
    );
  }
}

class _AppIconWidgetRow extends StatefulWidget {
  const _AppIconWidgetRow();

  @override
  State<_AppIconWidgetRow> createState() => _AppIconWidgetRowState();
}

class _AppIconWidgetRowState extends State<_AppIconWidgetRow> {
  NamidaAppIcons? _enabledIcon;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final newEnabledIcon = await NamidaChannel.inst.getEnabledAppIcon();
    if (mounted && _enabledIcon != newEnabledIcon) {
      setState(() {
        _enabledIcon = newEnabledIcon;
      });
    }
  }

  Future<void> _onAddTap() {
    const submitUrl = 'https://discord.com/channels/1156253663803740271/1423484977693327430/1423671224520671362';
    return NamidaLinkUtils.openLink(submitUrl);
  }

  @override
  Widget build(BuildContext context) {
    final enabledIcon = _enabledIcon;
    final enabledIconAuthorInfo = enabledIcon?.authorInfos.firstOrNull;
    final iconsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children:
          <Widget>[
                ...NamidaAppIcons.values.map(
                  (e) {
                    final isEnabled = e == enabledIcon;
                    final iconChild = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          e.assetPath,
                          width: 34.0,
                          height: 35.0,
                          alignment: Alignment.center,
                        ),
                        const SizedBox(height: 1.0),
                        NamidaText(
                          e.name,
                          style: NText.small,
                        ),
                      ],
                    );
                    return NBuilder(
                      selfAnimated: true,
                      builder: (context, colors) {
                        final bgColor = colors.secondaryContainer;
                        return NamidaInkWell(
                          animationDurationMS: 300,
                          borderRadius: 12.0,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          enableSecondaryTap: false,
                          decoration: isEnabled
                              ? BoxDecoration(
                                  color: bgColor.withOpacityExt(0.75),
                                  border: Border.all(
                                    color: bgColor,
                                    width: 1.5,
                                  ),
                                )
                              : BoxDecoration(
                                  color: bgColor.withOpacityExt(0.25),
                                ),
                          onTap: () async {
                            await NamidaChannel.inst.changeAppIcon(e);
                            await _refreshStatus();
                            if (e.isJelly) NamidaJellys.promptEnable('Let jellyfishes invade namida too?');
                          },
                          child: iconChild,
                        );
                      },
                    );
                  },
                ),
                NamidaInkWell(
                  animationDurationMS: 300,
                  borderRadius: 12.0,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  enableSecondaryTap: false,
                  bgColor: const NColors(.secondaryContainer, opacity: 0.25),
                  onTap: _onAddTap,
                  child: NamidaText(
                    lang.add,
                    style: NText.medium,
                  ),
                ),
              ]
              .addSeparators(
                separator: const SizedBox(width: 4.0),
              )
              .toFixedList(),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12.0),
        SizedBox(
          width: context.width,
          child: Row(
            children: [
              const SizedBox(width: 8.0),
              NIcon(
                Broken.attach_square,
                size: 22.0,
                color: NColors.defaultIcon(),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Wrap(
                  runSpacing: 2.0,
                  alignment: WrapAlignment.start,
                  runAlignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    NamidaText(
                      "${lang.appIcon}:",
                      style: NText.medium,
                    ),
                    if (enabledIcon != null) ...[
                      const SizedBox(width: 6.0),
                      NamidaText(
                        enabledIcon.name,
                        style: NText.medium,
                      ),
                      if (enabledIconAuthorInfo != null) ...[
                        const SizedBox(width: 2.0),
                        NamidaText(
                          "(@${enabledIconAuthorInfo.name})",
                          style: NText.small,
                        ),
                        if (enabledIconAuthorInfo.aiModel != null)
                          const NamidaInkWell(
                            bgColor: NColors.card,
                            margin: EdgeInsets.symmetric(horizontal: 2.0),
                            padding: EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
                            borderRadius: 4.0,
                            child: NamidaText(
                              "AI",
                              style: NText(.small, size: .s10),
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8.0),
        SmoothSingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: iconsRow,
        ),
        const SizedBox(height: 8.0),
      ],
    );
  }
}
