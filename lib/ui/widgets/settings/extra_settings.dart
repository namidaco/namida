import 'dart:io';

import 'package:flutter/material.dart';

import 'package:modern_titlebar_buttons/modern_titlebar_buttons.dart' as mtb;

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/now_playing_broadcaster.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/romanizer/romanizer.dart';
import 'package:namida/controller/romanizer/romanizer_engine.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/jellyfish.dart';
import 'package:namida/ui/widgets/lyrics_karaoke_text.dart';
import 'package:namida/ui/widgets/reorderable_active_items_list.dart';
import 'package:namida/ui/widgets/settings/effects_tiles.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

part 'extra_settings.lyrics_effects.dart';

class ExtrasSettings extends SettingSubpageProvider {
  const ExtrasSettings({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.extra;

  @override
  List<List<SettingEntry>> get sections => _sections;

  static final libraryTabs = SettingCustom(
    title: () => lang.libraryTabs,
    keys: [settings.libraryTabs],
    onReset: _LibraryTabsTile._ensureSelectedTabExists,
    tile: (args) => _LibraryTabsTile(
      bgColor: args.bgColor,
    ),
  );

  static final _sections = <List<SettingEntry>>[
    [
      SettingExpansion(
        icon: Broken.link_21,
        title: () => lang.integrations,
        aliases: () => ['Webhook', 'Tasker', 'Subsonic', 'Jellyfin', 'Android Auto', 'Wear OS', 'Status bar lyrics'],
        initiallyExpandedWhen: () => true,
        trailingBuilder: (arrow) => _IntegrationsTrailing(
          arrow: arrow,
        ),
        children: [
          SettingToggleGroup(
            settings.discordPresence,
            availability: const NamidaFeaturesAvailablityGroup(
              items: [NamidaFeaturesAvailablity.android, NamidaFeaturesAvailablity.windows, NamidaFeaturesAvailablity.linux],
            ),
            icon: Broken.game,
            title: () => lang.discordRichPresence,
            onChanged: (isEnabled) => _DiscordAccountTile.onPresenceToggled(isEnabled),
            children: [
              SettingCustom(
                title: () => lang.signOut,
                tile: (args) => _DiscordAccountTile(
                  bgColor: args.bgColor,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    [
      // SettingCustom(
      //   title: () => lang.useCollapsedSettingTiles,
      //   keys: [settings.useSettingCollapsedTiles],
      //   tile: (args) => CollapsedSettingTileWidget(
      //     bgColor: args.bgColor,
      //   ),
      // ),
      SettingToggle(
        settings.enableBottomNavBar,
        icon: Broken.direct,
        title: () => lang.enableBottomNavBar,
        subtitle: () => lang.enableBottomNavBarSubtitle,
        enabledWhen: () => !Dimensions.inst.showNavigationAtSide,
        onChanged: (isEnabled) => MiniPlayerController.inst.updateBottomNavBarRelatedDimensions(isEnabled),
      ),
      SettingToggle(
        settings.enablePip,
        availability: NamidaFeaturesAvailablity.android,
        icon: Broken.screenmirroring,
        title: () => lang.enablePictureInPicture,
        onChanged: (isEnabled) => NamidaChannel.inst.setCanEnterPip(isEnabled),
      ),
      SettingChoice(
        settings.floatingActionButton,
        values: FABType.values,
        valueToText: (e) => e.toText(),
        valueToIcon: (e) => e.toIcon(),
        icon: Broken.safe_home,
        title: () => lang.floatingActionButton,
      ),
    ],
    [
      SettingCustom(
        title: () => lang.defaultLibraryTab,
        keys: [settings.extra.autoLibraryTab, settings.extra.staticLibraryTab],
        tile: (args) => _DefaultLibraryTabTile(
          bgColor: args.bgColor,
        ),
      ),
      libraryTabs,
    ],
    [
      SettingCustom(
        title: () => lang.filterTracksBy,
        keys: [settings.trackSearchFilterDefault, settings.trackSearchFilterPresets],
        onReset: SearchSortController.inst.onTrackSearchFilterChanged,
        tile: (args) => _FilterTracksByTile(
          bgColor: args.bgColor,
        ),
      ),
      SettingCustom(
        title: () => lang.ignoreCommonPrefixesWhileSorting,
        keys: [settings.ignoreCommonPrefixForTypes, settings.commonPrefixes],
        tile: (args) => _CommonPrefixesTile(
          bgColor: args.bgColor,
        ),
      ),
      SettingToggle(
        settings.enableSearchCleanup,
        icon: Broken.document_filter,
        title: () => lang.enableSearchCleanup,
        subtitle: () => lang.enableSearchCleanupSubtitle,
        onChanged: (_) => SearchSortController.inst.disposeResources(),
      ),
      SettingCustom(
        title: () => lang.romanization,
        aliases: () => [lang.dictionary],
        keys: [settings.romanizeLyrics, settings.romanizeSorting, settings.romanizationDisabledScripts],
        tile: (args) => _RomanizationTile(
          bgColor: args.bgColor,
        ),
      ),
    ],
    [
      SettingToggleGroup(
        settings.enableLyrics,
        leading: const StackedIcon(
          baseIcon: Broken.document,
          secondaryIcon: Broken.cpu,
          secondaryIconSize: 13.0,
        ),
        title: () => lang.lyrics,
        onChanged: (_) => _refreshCurrentLyrics(),
        children: [
          SettingChoice(
            settings.lyricsSource,
            values: LyricsSource.values,
            valueToText: (e) => e.toText(),
            icon: Broken.document_cloud,
            title: () => lang.lyricsSource,
          ),
          SettingChoice(
            settings.embeddedLyricsPriority,
            values: EmbeddedLyricsPriority.values,
            valueToText: (e) => e.toText(),
            icon: Broken.mobile_programming,
            title: () => lang.prioritizeEmbeddedLyrics,
          ),
          SettingToggle(
            settings.stretchLyricsDuration,
            icon: Broken.arrange_square,
            title: () => lang.stretchLyricsDuration,
            subtitle: () => 'spedup/slowed/nightcore',
          ),
          SettingToggle(
            settings.enableSimpleLyricsLine,
            icon: Broken.text,
            title: () => lang.simpleLyricsLine,
            subtitle: () => lang.simpleLyricsLineSubtitle,
            onChanged: (_) => _refreshCurrentLyrics(),
          ),
          SettingCustom(
            title: () => lang.lyricsFolders,
            aliases: () => [lang.lyricsFoldersSubtitle],
            keys: [settings.lyricsFolders],
            tile: (args) => _LyricsFoldersTile(
              args: args,
            ),
            children: [
              SettingCustom(
                title: () => lang.lyricsSaveLocation,
                aliases: () => [lang.lyricsSaveLocationSubtitle, lang.lyricsDeleteWithTrack],
                keys: [settings.lyricsSaveLocation, settings.lyricsDeleteWithTrackIn],
                tile: (args) => _LyricsSaveLocationTile(
                  bgColor: args.bgColor,
                ),
              ),
            ],
          ),
        ],
      ),
      SettingExpansion(
        leading: const StackedIcon(
          baseIcon: Broken.image,
          secondaryIcon: Broken.cpu,
          secondaryIconSize: 13.0,
        ),
        title: () => lang.imageSource,
        children: [
          SettingCustom(
            title: () => lang.albums,
            aliases: () => [lang.album],
            keys: [settings.imageSourceAlbum],
            tile: (args) => _ImageSourceTile(
              bgColor: args.bgColor,
              setting: settings.imageSourceAlbum,
              update: settings.imageSourceAlbum.update,
              title: lang.albums,
              icon: LibraryTab.albums.toIcon(),
            ),
          ),
          SettingCustom(
            title: () => lang.artists,
            aliases: () => [lang.artist],
            keys: [settings.imageSourceArtist],
            tile: (args) => _ImageSourceTile(
              bgColor: args.bgColor,
              setting: settings.imageSourceArtist,
              update: settings.imageSourceArtist.update,
              title: lang.artists,
              icon: LibraryTab.artists.toIcon(),
            ),
          ),
        ],
      ),
    ],
    [
      SettingToggle(
        settings.hideStatusBarInExpandedMiniplayer,
        availability: NamidaFeaturesAvailablity.android,
        icon: Broken.external_drive,
        title: () => lang.immersiveMode,
        subtitle: () => lang.immersiveModeSubtitle,
        onChanged: (isEnabled) => MiniPlayerController.inst.setImmersiveMode(isEnabled),
      ),
      SettingToggle(
        settings.swipeableDrawer,
        icon: Broken.sidebar_right,
        title: () => lang.swipeToOpenDrawer,
        onChanged: (isEnabled) => NamidaNavigator.inst.innerDrawerKey.currentState?.toggleCanSwipe(isEnabled),
      ),
      SettingToggle(
        settings.alwaysExpandedSearchbar,
        leading: const StackedIcon(
          baseIcon: Broken.scroll,
          secondaryIcon: Broken.search_normal,
          secondaryIconSize: 12.0,
        ),
        title: () => lang.alwaysExpandedSearchbar,
        onChanged: (isEnabled) => ScrollSearchController.inst.searchBarKey.currentState?.setAlwaysExpanded(isEnabled),
      ),
      SettingToggle(
        settings.enableClipboardMonitoring,
        icon: Broken.clipboard_export,
        title: () => lang.enableClipboardMonitoring,
        subtitle: () => lang.enableClipboardMonitoringSubtitle,
      ),
      SettingCustom(
        availability: NamidaFeaturesAvailablity.android,
        title: () => lang.vibrationType,
        aliases: () => [lang.vibration, lang.hapticFeedback],
        keys: [settings.vibrationType],
        tile: (args) => _VibrationTypeTile(
          bgColor: args.bgColor,
        ),
      ),
    ],
    [
      SettingCustom(
        title: () => lang.extractAllColorPalettes,
        tile: (args) => _ExtractAllPalettesTile(
          bgColor: args.bgColor,
        ),
      ),
    ],
  ];

  static void _refreshCurrentLyrics() {
    final currentItem = Player.inst.currentItem.value;
    if (currentItem != null) Lyrics.inst.updateLyrics(currentItem);
  }

  void _showExtrasFlagsDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.flag,
        title: lang.configure,
        normalTitleStyle: true,
        horizontalInset: 32.0,
        actions: [
          NamidaButton(
            text: lang.done,
            onTap: NamidaNavigator.inst.closeDialog,
          ),
        ],
        child: const _ExtrasFlagsOptions(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.extras,
      subtitle: lang.extrasSubtitle,
      icon: Broken.command_square,
      trailing: NamidaIconButton(
        icon: Broken.flag,
        tooltip: () => lang.configure,
        iconColor: NColors.defaultIcon(),
        onPressed: _showExtrasFlagsDialog,
      ),
      child: SettingSectionsColumn(
        page: this,
      ),
    );
  }
}

class LoadingIndicator extends StatefulWidget {
  final Color? circleColor;
  final double? width;
  final double? height;
  final double? boxWidth;
  final double? boxHeight;
  final int durationInMillisecond;

  const LoadingIndicator({
    super.key,
    this.circleColor,
    this.width = 5.0,
    this.height = 5.0,
    this.durationInMillisecond = 300,
    this.boxWidth = 20.0,
    this.boxHeight = 5.0,
  });

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final _alignmentTween = Tween<AlignmentGeometry>(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationInMillisecond),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.boxWidth,
      height: widget.boxHeight,
      child: AlignTransition(
        alignment: _alignmentTween.animate(_controller),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.circleColor ?? NText.medium.of(context).color,
            borderRadius: BorderRadius.circular(30.0),
          ),
        ),
      ),
    );
  }
}

class _ExtrasFlagsOptions extends StatelessWidget {
  const _ExtrasFlagsOptions();

  static Iterable<Widget> _getTitlebarIconsTypeChildren() {
    const buttonWidth = 18.0;
    const buttonHeight = 18.0;
    return DesktopTitlebarIconsType.values.map(
      (e) {
        void onTap() {
          settings.desktopTitlebarType.save(e);
          NamidaNavigator.inst.popMenu();
        }

        final buttonsType = e.toThemeType();
        final row = buttonsType == null
            ? Text(
                lang.none,
                textAlign: TextAlign.center,
              )
            : buttonsType == mtb.ThemeType.auto
            ? Text(
                lang.auto,
                textAlign: TextAlign.center,
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  mtb.DecoratedMinimizeButton(
                    width: buttonWidth,
                    height: buttonHeight,
                    type: buttonsType,
                    onPressed: () {},
                  ),
                  const SizedBox(width: 2.0),
                  mtb.DecoratedMaximizeButton(
                    width: buttonWidth,
                    height: buttonHeight,
                    type: buttonsType,
                    onPressed: () {},
                  ),
                  const SizedBox(width: 2.0),
                  mtb.DecoratedCloseButton(
                    width: buttonWidth,
                    height: buttonHeight,
                    type: buttonsType,
                    onPressed: () {},
                  ),
                ],
              );
        return ObxO(
          rx: settings.desktopTitlebarType,
          builder: (context, value) => NamidaInkWell(
            margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
            borderRadius: 6.0,
            bgColor: value == e ? NColors.card : null,
            onTap: onTap,
            child: row,
          ),
        );
      },
    );
  }

  static Iterable<NamidaPopupItem> _getSearchTypeChildren([void Function()? onSave]) {
    return SearchType.values.map(
      (e) => NamidaPopupItem(
        icon: Broken.cd,
        title: e.name,
        selected: e == settings.preferredSearchType.value,
        onTap: () {
          settings.preferredSearchType.save(e);
          onSave?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const divider = NamidaContainerDivider(
      margin: EdgeInsets.symmetric(vertical: 4.0),
    );
    return SizedBox(
      width: context.width,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: context.height * 0.6),
        child: NamidaScrollbarWithController(
          showOnStart: true,
          child: (c) => SuperSmoothListView(
            controller: c,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [
              if (kAllowJellysInvasion) const JellysFlagsTiles(),
              ObxO(
                rx: settings.gradientTiles,
                builder: (context, gradientTiles) => CustomSwitchListTile(
                  icon: Broken.colors_square,
                  value: gradientTiles,
                  onChanged: (isTrue) => settings.gradientTiles.save(!isTrue),
                  title: 'gradient_tiles_and_cards'.toUpperCase(),
                ),
              ),
              const BackgroundImagesFlagTile(),
              if (NamidaFeaturesVisibility.floatingArtworkEffect)
                ObxO(
                  rx: settings.extra.floatingArtworkEffect,
                  builder: (context, floatingArtworkEffect) => CustomSwitchListTile(
                    icon: Broken.recovery_convert,
                    value: floatingArtworkEffect ?? false,
                    onChanged: (isTrue) => settings.extra.floatingArtworkEffect.save(!isTrue),
                    title: 'floating_artwork_effect'.toUpperCase(),
                    subtitle: "${lang.performanceNote}.\nMight affect battery usage.",
                  ),
                ),
              if (NamidaFeaturesVisibility.tiltingCardsEffect)
                ObxO(
                  rx: settings.extra.tiltingCardsEffect,
                  builder: (context, tiltingCardsEffect) => CustomSwitchListTile(
                    icon: Broken.d_rotate,
                    value: tiltingCardsEffect ?? false,
                    onChanged: (isTrue) => settings.extra.tiltingCardsEffect.save(!isTrue),
                    title: 'tilting_cards_effect'.toUpperCase(),
                    subtitle: "${lang.performanceNote}.\nMight affect battery usage.",
                  ),
                ),
              const _SubpageInfoStyleTile(),
              const _ArtworkCollageStyleTile(),
              const _LyricsEffectsTile(),
              // ObxO(
              //   rx: settings.extra.reduceAnimations,
              //   builder: (context, reduceAnimations) => CustomSwitchListTile(
              //     icon: Broken.flash_1,
              //     value: reduceAnimations ?? false,
              //     onChanged: (isTrue) => settings.extra.reduceAnimations.save(!isTrue),
              //     title: 'reduce_animations'.toUpperCase(),
              //     subtitle: 'Transitions and animations finish almost instantly.',
              //   ),
              // ),
              if (NamidaFeaturesVisibility.mediaWaveHaptic)
                ObxO(
                  rx: settings.mediaWaveHaptic,
                  builder: (context, mediaWaveHaptic) => CustomSwitchListTile(
                    icon: Broken.watch_status,
                    value: mediaWaveHaptic ?? false,
                    onChanged: (isTrue) => settings.mediaWaveHaptic.save(!isTrue),
                    title: 'media_wave_haptic'.toUpperCase(),
                    subtitle: 'Haptic feedback following the rhythm.\nMight affect battery usage.',
                  ),
                ),
              divider,
              if (NamidaFeaturesVisibility.smoothScrolling)
                ObxO(
                  rx: settings.smoothScrolling,
                  builder: (context, smoothScrolling) => CustomSwitchListTile(
                    icon: Broken.coin,
                    rotateIcon: 2,
                    value: smoothScrolling ?? true,
                    onChanged: (isTrue) => settings.smoothScrolling.save(!isTrue),
                    title: 'smooth_scrolling'.toUpperCase(),
                  ),
                ),
              ObxO(
                rx: settings.scrollbarThumbLabel,
                builder: (context, scrollbarThumbLabel) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.row_vertical,
                    secondaryIcon: Broken.text,
                    secondaryIconSize: 12.0,
                  ),
                  value: scrollbarThumbLabel ?? false,
                  onChanged: (isTrue) => settings.scrollbarThumbLabel.save(!isTrue),
                  title: 'scrollbar_thumb_label'.toUpperCase(),
                  subtitle: 'show the current letter/section next to the scrollbar while dragging it',
                ),
              ),
              ObxO(
                rx: settings.enhancedDragToScroll,
                builder: (context, enhancedDragToScroll) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.row_vertical,
                    secondaryIcon: Broken.arrow_swap,
                    secondaryIconSize: 12.0,
                  ),
                  value: enhancedDragToScroll ?? true,
                  onChanged: (isTrue) => settings.enhancedDragToScroll.save(!isTrue),
                  title: 'enhanced_drag_to_scroll'.toUpperCase(),
                  subtitle: 'drag anywhere on the scroll track to scroll',
                ),
              ),
              ObxO(
                rx: settings.easyScrollbarGrab,
                builder: (context, easyScrollbarGrab) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.row_vertical,
                    secondaryIcon: Broken.flash,
                    secondaryIconSize: 12.0,
                  ),
                  value: easyScrollbarGrab ?? false,
                  onChanged: (isTrue) => settings.easyScrollbarGrab.save(!isTrue),
                  title: 'easy_scrollbar_grab'.toUpperCase(),
                  subtitle: 'drag the scrollbar thumb instantly and from a wider area',
                ),
              ),
              ObxO(
                rx: settings.tapToScroll,
                builder: (context, tapToScroll) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.row_vertical,
                    secondaryIcon: Broken.cd,
                    secondaryIconSize: 12.0,
                  ),
                  value: tapToScroll ?? false,
                  onChanged: (isTrue) => settings.tapToScroll.save(!isTrue),
                  title: 'tap_to_scroll'.toUpperCase(),
                  subtitle: 'tap anywhere on the scroll track to scroll',
                ),
              ),
              if (isDesktop) ...[
                divider,
                ObxO(
                  rx: settings.desktopTitlebar,
                  builder: (context, desktopTitlebar) => CustomSwitchListTile(
                    icon: Broken.card_tick_1,
                    value: desktopTitlebar,
                    onChanged: (isTrue) => settings.desktopTitlebar.save(!isTrue),
                    title: 'show_desktop_title_bar'.toUpperCase(),
                  ),
                ),
                if (!Platform.isWindows)
                  NamidaPopupWrapper(
                    children: _getTitlebarIconsTypeChildren,
                    child: CustomListTile(
                      icon: Broken.close_circle,
                      title: 'desktop_title_bar_icons_type'.toUpperCase(),
                      trailing: NamidaPopupWrapper(
                        children: _getTitlebarIconsTypeChildren,
                        child: ObxO(
                          rx: settings.desktopTitlebarType,
                          builder: (context, type) => NamidaText(
                            type.name,
                            style: NText.medium,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
              divider,
              ObxO(
                rx: settings.visualDelayMS,
                builder: (context, visualDelayMS) => CustomListTile(
                  icon: Broken.clock,
                  title: 'visual_to_audio_delay'.toUpperCase(),
                  subtitle: 'delay certain ui animations (ex. lyrics) to match with bluetooth audio delay',
                  trailing: NamidaWheelSlider(
                    initValue: visualDelayMS ~/ 10,
                    max: 200,
                    onValueChanged: (val) {
                      final ms = val * 10;
                      settings.visualDelayMS.save(ms);
                    },
                    text: '$visualDelayMS ms',
                  ),
                ),
              ),
              ObxO(
                rx: settings.resumeUIEnabled,
                builder: (context, resumeUIEnabled) => CustomSwitchListTile(
                  icon: Broken.play_circle,
                  value: resumeUIEnabled,
                  onChanged: (isTrue) => settings.resumeUIEnabled.save(!isTrue),
                  title: 'resume_ui'.toUpperCase(),
                  subtitle: 'shows the resume button & highlights the last played item in pages like albums & playlists',
                ),
              ),
              ObxO(
                rx: settings.extra.recentSearchesEnabled,
                builder: (context, recentSearchesEnabled) => CustomSwitchListTile(
                  icon: Broken.search_status,
                  value: recentSearchesEnabled ?? false,
                  onChanged: (isTrue) => settings.extra.setRecentSearchesEnabled(!isTrue),
                  title: 'recent_searches'.toUpperCase(),
                  subtitle: 'saves searches and shows them in the search page',
                ),
              ),
              NamidaPopupWrapper(
                childrenDefault: _getSearchTypeChildren,
                child: CustomListTile(
                  icon: Broken.search_favorite,
                  title: 'preferred_search_tab'.toUpperCase(),
                  trailing: NamidaPopupWrapper(
                    childrenDefault: _getSearchTypeChildren,
                    child: ObxO(
                      rx: settings.preferredSearchType,
                      builder: (context, type) => NamidaText(
                        type.name,
                        style: NText.medium,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                ),
              ),
              ObxO(
                rx: settings.ytStyleButtonSwitcher,
                builder: (context, ytStyleButtonSwitcher) => CustomSwitchListTile(
                  icon: Broken.video_octagon,
                  value: ytStyleButtonSwitcher ?? false,
                  onChanged: (isTrue) => settings.ytStyleButtonSwitcher.save(!isTrue),
                  title: 'yt_style_player_button_switcher'.toUpperCase(),
                  subtitle: 'shows a button to switch between local style player and youtube style player',
                ),
              ),
              ObxO(
                rx: settings.keepVideoFrameOnSwitch,
                builder: (context, keepVideoFrameOnSwitch) => CustomSwitchListTile(
                  icon: Broken.video_play,
                  value: keepVideoFrameOnSwitch ?? false,
                  onChanged: (isTrue) => settings.keepVideoFrameOnSwitch.save(!isTrue),
                  title: 'keep_video_frame_on_switch'.toUpperCase(),
                  subtitle: 'Keep the last video frame while switching to an item whose video is already downloaded, instead of flashing the artwork in between.',
                ),
              ),
              ObxO(
                rx: settings.askBeforeReplacingQueue,
                builder: (context, askBeforeReplacingQueue) => CustomSwitchListTile(
                  icon: Broken.row_vertical,
                  value: askBeforeReplacingQueue,
                  onChanged: (isTrue) => settings.askBeforeReplacingQueue.save(!isTrue),
                  title: 'ask_before_replacing_queue'.toUpperCase(),
                  subtitle: 'when playing something else while manually queued items are still pending',
                ),
              ),
              ObxO(
                rx: settings.timeCapsuleYears,
                builder: (context, timeCapsuleYears) {
                  timeCapsuleYears ??= 0;
                  final now = DateTime.now();
                  const preferredYear = 2018;

                  const int maxYears = 100 * 5;
                  const int offset = maxYears ~/ 2;
                  return CustomListTile(
                    icon: Broken.calendar,
                    title: 'time_capsule_years'.toUpperCase(),
                    subtitle:
                        "you think it's ${now.year}? $preferredYear was ${now.year - preferredYear} years ago? except that it's not. this capsule can send u back in time or far into the future, use carefully.",
                    trailing: NamidaWheelSlider(
                      initValue: timeCapsuleYears + offset,
                      max: maxYears,
                      onValueChanged: (val) {
                        final actualYears = val - offset;
                        settings.timeCapsuleYears.save(actualYears);
                      },
                      text: timeCapsuleYears > 0 ? '+$timeCapsuleYears' : '$timeCapsuleYears',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubpageInfoStyleTile extends StatelessWidget {
  const _SubpageInfoStyleTile();

  static const _kTypes = [MediaType.album, MediaType.artist, MediaType.genre, MediaType.playlist];

  void _openDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: 'Subpage Header Style',
        normalTitleStyle: true,
        icon: Broken.gallery,
        actions: const [
          DoneButton(),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in _kTypes) _SubpageInfoStyleRow(type: type),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.subpageInfoStyles,
      builder: (context, styles) {
        final customizedCount = styles.values.where((style) => style != SubpageInfoStyle.compact).length;
        return CustomListTile(
          icon: Broken.gallery,
          title: 'subpage_header_style'.toUpperCase(),
          subtitle: 'Album, artist, genre & playlist pages.',
          trailingText: '$customizedCount',
          onTap: _openDialog,
        );
      },
    );
  }
}

class _SubpageInfoStyleRow extends StatelessWidget {
  final MediaType type;

  const _SubpageInfoStyleRow({
    required this.type,
  });

  void _save(SubpageInfoStyle style) {
    settings.subpageInfoStyles.update((styles) => styles[type] = style);
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.subpageInfoStyles,
      builder: (context, styles) {
        final current = styles[type] ?? SubpageInfoStyle.compact;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Row(
                  children: [
                    Expanded(
                      child: NamidaText(
                        type.toText(),
                        style: NText.medium,
                      ),
                    ),
                    NamidaText(
                      current.toText(),
                      style: NText.small,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6.0),
              Row(
                children: [
                  for (final style in SubpageInfoStyle.values) ...[
                    if (style != SubpageInfoStyle.values.first) const SizedBox(width: 4.0),
                    Expanded(
                      child: NamidaToggleCard(
                        icon: style.toIcon(),
                        title: style.toText(),
                        active: style == current,
                        onTap: () => _save(style),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArtworkCollageStyleTile extends StatelessWidget {
  const _ArtworkCollageStyleTile();

  static Iterable<NamidaPopupItem> _getChildren() {
    final current = settings.artworkCollageStyle.value;
    return ArtworkCollageStyle.values.map(
      (e) => NamidaPopupItem(
        icon: e.toIcon(),
        title: e.toText(),
        selected: e == current,
        onTap: () => settings.artworkCollageStyle.save(e),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      childrenDefault: _getChildren,
      child: CustomListTile(
        icon: Broken.picture_frame,
        title: 'artwork_collage_style'.toUpperCase(),
        subtitle: 'Covers built from several tracks.',
        trailing: NamidaPopupWrapper(
          childrenDefault: _getChildren,
          child: ObxO(
            rx: settings.artworkCollageStyle,
            builder: (context, style) => NamidaText(
              style.toText(),
              style: NText.medium,
              textAlign: TextAlign.end,
            ),
          ),
        ),
      ),
    );
  }
}

class JellysFlagsTiles extends StatelessWidget {
  const JellysFlagsTiles({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ObxO(
          rx: settings.extra.jellysInvasion,
          builder: (context, jellysInvasion) => CustomSwitchListTile(
            leading: const JellyMascot(height: 30.0),
            value: jellysInvasion ?? false,
            onChanged: (isTrue) => NamidaJellys.setInvasion(!isTrue, paletteFollows: true),
            title: 'jellys_invasion'.toUpperCase(),
            subtitle: 'Let jellyfishes drift around the app.\n${lang.performanceNote}.\nby ${NamidaAppIcons.jellyda.authorInfoText}',
          ),
        ),
        ObxO(
          rx: settings.extra.jellysPalette,
          builder: (context, jellysPalette) => CustomSwitchListTile(
            icon: Broken.color_swatch,
            value: jellysPalette ?? false,
            onChanged: (isTrue) => NamidaJellys.setPaletteHijack(!isTrue),
            title: 'jellys_color_palette'.toUpperCase(),
          ),
        ),
      ],
    );
  }
}

class _DefaultLibraryTabTile extends StatelessWidget {
  final Color? bgColor;

  const _DefaultLibraryTabTile({required this.bgColor});

  static void _onAutoTap() {
    settings.extra.autoLibraryTab.save(true);
    NamidaNavigator.inst.popMenu();
  }

  static void _onTabTap(LibraryTab tab) {
    settings.extra.transaction(() {
      settings.extra.setSelectedLibraryTab(tab);
      settings.extra.staticLibraryTab.save(tab);
      settings.extra.autoLibraryTab.save(false);
    });
    NamidaNavigator.inst.popMenu();
  }

  static Iterable<NamidaPopupItem> _getMenuItems() sync* {
    final isAuto = settings.extra.autoLibraryTab.value;
    final staticTab = settings.extra.staticLibraryTab.value;
    yield NamidaPopupItem(
      icon: Broken.recovery_convert,
      title: lang.auto,
      selected: isAuto,
      onTap: _onAutoTap,
    );
    for (final tab in settings.libraryTabs.value) {
      yield NamidaPopupItem(
        icon: tab.toIcon(),
        title: tab.toText(),
        selected: !isAuto && staticTab == tab,
        onTap: () => _onTabTap(tab),
      );
    }
  }

  void _showMenu(BuildContext context) {
    const menu = NamidaPopupWrapper(
      childrenDefault: _getMenuItems,
    );
    menu.showPopupMenu(context);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final valueText = settings.extra.autoLibraryTab.valueR ? lang.auto : settings.extra.staticLibraryTab.valueR.toText();
        return CustomListTile(
          bgColor: bgColor,
          icon: Broken.receipt_1,
          title: lang.defaultLibraryTab,
          trailing: NamidaPopupWrapper(
            childrenDefault: _getMenuItems,
            child: NamidaText(
              valueText,
              style: NText.medium,
              color: const NColors(.onSurface, opacity: 0.78),
              maxLines: 1,
            ),
          ),
          onTap: () => _showMenu(context),
        );
      },
    );
  }
}

class _LibraryTabsTile extends StatelessWidget {
  final Color? bgColor;

  const _LibraryTabsTile({required this.bgColor});

  static void _ensureSelectedTabExists() {
    final tabs = settings.libraryTabs.value;
    final selectedGroup = settings.extra.selectedLibraryTab.value.group;
    if (!tabs.contains(selectedGroup)) settings.extra.setSelectedLibraryTab(tabs.first);
  }

  void _onChanged(List<LibraryTab> activeItems) {
    final didRemove = activeItems.length < settings.libraryTabs.value.length;
    settings.libraryTabs.replace(activeItems);
    if (!didRemove) return;
    final firstTab = settings.libraryTabs.value.first;
    settings.extra.setSelectedLibraryTab(firstTab);
  }

  void _showDialog(List<LibraryTab> libraryTabs) {
    final groupHeads = LibraryTab.values.where((e) => e.isGroupHead).toFixedList();
    NamidaNavigator.inst.navigateDialog(
      scale: 1.0,
      dialog: CustomBlurryDialog(
        title: "${lang.libraryTabs} (${lang.reorderable})",
        actions: const [
          DoneButton(),
        ],
        child: SizedBox(
          width: namida.width,
          height: namida.height * 0.5,
          child: NamidaReorderableActiveItemsList(
            items: groupHeads,
            activeItems: libraryTabs,
            toText: (item) => item.toText(),
            toIcon: (item) => item.toIcon(),
            minimumItems: 2,
            onChanged: _onChanged,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.libraryTabs,
      builder: (context, libraryTabs) {
        final tabsText = libraryTabs.map((e) => e.toText()).join(', ');
        return CustomListTile(
          bgColor: bgColor,
          icon: Broken.color_swatch,
          title: lang.libraryTabs,
          subtitle: tabsText,
          trailingText: "${libraryTabs.length}",
          onTap: () => _showDialog(libraryTabs),
        );
      },
    );
  }
}

class _FilterTracksByTile extends StatelessWidget {
  final Color? bgColor;

  const _FilterTracksByTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.trackSearchFilter,
      builder: (context, trackSearchFilter) => CustomListTile(
        bgColor: bgColor,
        icon: Broken.filter_search,
        title: lang.filterTracksBy,
        trailingText: "${trackSearchFilter.length}",
        onTap: NamidaOnTaps.inst.onTrackSearchFilterTap,
      ),
    );
  }
}

class _CommonPrefixesTile extends StatelessWidget {
  final Color? bgColor;

  const _CommonPrefixesTile({required this.bgColor});

  static const _kUnsortableTypes = {
    TrackSearchFilter.comment, TrackSearchFilter.description, TrackSearchFilter.year, //
    TrackSearchFilter.moods, TrackSearchFilter.tags, TrackSearchFilter.lyrics, //
  };

  void _onTypeTap(TrackSearchFilter type) {
    if (settings.ignoreCommonPrefixForTypes.value.contains(type)) {
      settings.ignoreCommonPrefixForTypes.update((list) => list.remove(type));
    } else {
      settings.ignoreCommonPrefixForTypes.update((list) => list.addNoDuplicates(type));
    }
  }

  void _onPrefixRemoveTap(String prefix) {
    if (settings.commonPrefixes.value.length <= 1) return showMinimumItemsSnack(1);

    settings.commonPrefixes.update((prefixes) => prefixes.remove(prefix));
  }

  void _onRestorePrefixesTap() {
    settings.commonPrefixes.reset();
    NamidaNavigator.inst.closeDialog();
  }

  void _showAddPrefixDialog() {
    final controller = TextEditingController();
    void onAdd(String value) {
      settings.commonPrefixes.update((list) => list.addNoDuplicates(value.toLowerCase()));
      NamidaNavigator.inst.closeDialog();
    }

    NamidaNavigator.inst.navigateDialog(
      onDisposing: controller.dispose,
      dialog: CustomBlurryDialog(
        title: lang.add,
        actions: [
          IconButton(
            tooltip: lang.restoreDefaults,
            onPressed: _onRestorePrefixesTap,
            icon: const Icon(Broken.refresh),
          ),
          const CancelButton(),
          NamidaButton(
            text: lang.save,
            onTap: () => onAdd(controller.text),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.only(top: 14.0),
          child: CustomTagTextField(
            controller: controller,
            onFieldSubmitted: onAdd,
            hintText: '',
            labelText: lang.value,
          ),
        ),
      ),
    );
  }

  void _showDialog(ThemeData theme) {
    final original = List<TrackSearchFilter>.from(settings.ignoreCommonPrefixForTypes.value);
    final types = TrackSearchFilter.values.where((e) => !_kUnsortableTypes.contains(e)).toFixedList();
    final chipColor = theme.cardTheme.color;
    final addChipColor = chipColor?.withOpacityExt(1.0);

    void resortIfNecessary() {
      final didChange = settings.ignoreCommonPrefixForTypes.value.didChangeFrom(original);
      if (didChange) Indexer.inst.resortAllAfterSortKeysChange();
    }

    NamidaNavigator.inst.navigateDialog(
      onDismissing: resortIfNecessary,
      dialog: CustomBlurryDialog(
        title: lang.ignoreCommonPrefixesWhileSorting,
        actions: [
          IconButton(
            icon: const Icon(Broken.refresh),
            tooltip: lang.restoreDefaults,
            onPressed: settings.ignoreCommonPrefixForTypes.reset,
          ),
          DoneButton(
            additional: resortIfNecessary,
          ),
        ],
        child: SmoothSingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ObxO(
                rx: settings.commonPrefixes,
                builder: (context, commonPrefixes) => Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...commonPrefixes.map(
                      (e) => _PrefixChip(
                        text: e,
                        icon: Broken.close_circle,
                        color: chipColor,
                        onTap: () => _onPrefixRemoveTap(e),
                      ),
                    ),
                    const NamidaContainerDivider(
                      height: 24.0,
                      width: 1.5,
                      margin: EdgeInsets.symmetric(horizontal: 2.0),
                    ),
                    _PrefixChip(
                      text: lang.add,
                      icon: Broken.add_circle,
                      color: addChipColor,
                      onTap: _showAddPrefixDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4.0),
              const NamidaContainerDivider(),
              ...types.map(
                (e) => Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Obx(
                    (context) => ListTileWithCheckMark(
                      title: e.toText(),
                      onTap: () => _onTypeTap(e),
                      active: settings.ignoreCommonPrefixForTypes.valueR.contains(e),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final prefixesText = settings.commonPrefixes.valueR.map((e) => e.addDQuotation()).join(', ');
        final typesCount = settings.ignoreCommonPrefixForTypes.valueR.length;
        return CustomListTile(
          bgColor: bgColor,
          icon: Broken.message_remove,
          title: lang.ignoreCommonPrefixesWhileSorting,
          subtitle: prefixesText,
          trailingText: "$typesCount",
          onTap: () => _showDialog(context.theme),
        );
      },
    );
  }
}

class _PrefixChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;
  final void Function() onTap;

  const _PrefixChip({
    required this.text,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2.0),
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16.0.multipliedRadius),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NamidaText(
              text,
              style: NText.medium,
            ),
            const SizedBox(width: 6.0),
            Icon(
              icon,
              size: 18.0,
            ),
          ],
        ),
      ),
    );
  }
}

class _RomanizationTile extends StatelessWidget {
  final Color? bgColor;

  const _RomanizationTile({required this.bgColor});

  void _showDialog() {
    final originalDisabledScripts = settings.romanizationDisabledScripts.value;
    final disabledScriptsRx = Rx<List<RomanizationScript>>(originalDisabledScripts);

    // -- once the dialog is gone, any way it was closed
    void saveIfChanged() {
      final newDisabledScripts = disabledScriptsRx.value;
      disabledScriptsRx.close();
      final didChange = newDisabledScripts.didChangeFrom(originalDisabledScripts);
      if (didChange) settings.romanizationDisabledScripts.replace(newDisabledScripts);
    }

    NamidaNavigator.inst.navigateDialog(
      onDisposing: saveIfChanged,
      dialog: CustomBlurryDialog(
        title: lang.romanization,
        actions: const [
          DoneButton(),
        ],
        child: SuperSmoothListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            ObxO(
              rx: settings.romanizeLyrics,
              builder: (context, romanizeLyrics) => CustomSwitchListTile(
                icon: Broken.document,
                title: '${lang.romanization}: ${lang.lyrics}',
                value: romanizeLyrics,
                onChanged: (isTrue) => Romanizer.inst.setLyricsEnabled(!isTrue),
              ),
            ),
            ObxO(
              rx: settings.romanizeSorting,
              builder: (context, romanizeSorting) => CustomSwitchListTile(
                icon: Broken.sort,
                title: '${lang.romanization}: ${lang.sortBy}',
                value: romanizeSorting,
                onChanged: (isTrue) => Romanizer.inst.setSortingEnabled(!isTrue),
              ),
            ),
            _RomanizationScriptsWrap(
              disabledScriptsRx: disabledScriptsRx,
            ),
            const NamidaContainerDivider(
              margin: EdgeInsets.symmetric(vertical: 4.0),
            ),
            const _RomanizationDictionaryTile(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
      icon: Broken.translate,
      title: lang.romanization,
      trailing: const Icon(
        Broken.arrow_right_3,
        size: 16.0,
      ),
      onTap: _showDialog,
    );
  }
}

class _RomanizationDictionaryTile extends StatelessWidget {
  const _RomanizationDictionaryTile();

  void _onTap(bool isDictionaryInstalled, double? downloadProgress) {
    if (downloadProgress != null) {
      Romanizer.inst.cancelDownload();
    } else if (isDictionaryInstalled) {
      Romanizer.inst.deleteDictionary();
    } else {
      Romanizer.inst.downloadDictionary(enableLyrics: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Romanizer.inst.isDictionaryInstalled,
      builder: (context, isDictionaryInstalled) => ObxO(
        rx: Romanizer.inst.downloadProgress,
        builder: (context, downloadProgress) {
          final trailingText = downloadProgress != null
              ? '${(downloadProgress * 100).round()}%'
              : isDictionaryInstalled
              ? lang.delete
              : lang.download;
          return CustomListTile(
            icon: Broken.book,
            title: lang.dictionary,
            subtitle: '日本語 (漢字) • 中文',
            trailingText: trailingText,
            onTap: () => _onTap(isDictionaryInstalled, downloadProgress),
          );
        },
      ),
    );
  }
}

class _RomanizationScriptsWrap extends StatelessWidget {
  final Rx<List<RomanizationScript>> disabledScriptsRx;

  const _RomanizationScriptsWrap({required this.disabledScriptsRx});

  void _toggle(RomanizationScript script) {
    final disabledScripts = disabledScriptsRx.value;
    final isDisabled = disabledScripts.contains(script);
    disabledScriptsRx.value = isDisabled ? disabledScripts.where((e) => e != script).toFixedList() : [...disabledScripts, script];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: ObxO(
        rx: disabledScriptsRx,
        builder: (context, disabledScripts) => Wrap(
          spacing: 4.0,
          runSpacing: 4.0,
          children: RomanizationScript.values
              .map(
                (e) => NamidaToggleCard(
                  title: e.toText(),
                  active: !disabledScripts.contains(e),
                  onTap: () => _toggle(e),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                ),
              )
              .toFixedList(),
        ),
      ),
    );
  }
}

class _LyricsSaveLocationTile extends StatelessWidget {
  final Color? bgColor;

  const _LyricsSaveLocationTile({required this.bgColor});

  void _onLocationTap(LyricsSaveLocation location) async {
    if (location != LyricsSaveLocation.cache) {
      final hasPermission = await requestManageStoragePermission();
      if (!hasPermission) return;
    }
    final needsFolder = location == LyricsSaveLocation.customFolder && settings.lyricsFolders.value.isEmpty;
    if (needsFolder) {
      NamidaNavigator.inst.closeDialog();
      final didAdd = await _addLyricsFolder();
      if (!didAdd) return;
    }
    settings.lyricsSaveLocation.save(location);
  }

  void _openLocationsDialog() {
    final saveFolder = settings.lyricsFolders.value.firstOrNull ?? '';
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.lyricsSaveLocation,
        normalTitleStyle: true,
        actions: const [
          DoneButton(),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...LyricsSaveLocation.values.map(
              (e) => _LyricsSaveLocationOption(
                location: e,
                subtitle: e == LyricsSaveLocation.customFolder ? saveFolder : '',
                onTap: () => _onLocationTap(e),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.lyricsSaveLocation,
      builder: (context, saveLocation) => CustomListTile(
        bgColor: bgColor,
        icon: Broken.document_download,
        title: lang.lyricsSaveLocation,
        subtitle: lang.lyricsSaveLocationSubtitle,
        trailingText: saveLocation.toText(),
        onTap: _openLocationsDialog,
      ),
    );
  }
}

class _LyricsSaveLocationOption extends StatelessWidget {
  final LyricsSaveLocation location;
  final String subtitle;
  final void Function() onTap;

  const _LyricsSaveLocationOption({
    required this.location,
    required this.subtitle,
    required this.onTap,
  });

  void _onDeleteWithTrackTap() {
    settings.lyricsDeleteWithTrackIn.update((deleteIn) {
      final wasEnabled = deleteIn.remove(location);
      if (!wasEnabled) deleteIn.add(location);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: Row(
        children: [
          Expanded(
            child: ObxO(
              rx: settings.lyricsSaveLocation,
              builder: (context, saveLocation) => ListTileWithCheckMark(
                active: saveLocation == location,
                title: location.toText(),
                subtitle: subtitle,
                onTap: onTap,
              ),
            ),
          ),
          const SizedBox(width: 4.0),
          ObxO(
            rx: settings.lyricsDeleteWithTrackIn,
            builder: (context, deleteIn) {
              final isEnabled = deleteIn.contains(location);
              final colors = NColorsData.of(context);
              return NamidaIconButton(
                tooltip: () => '${lang.lyricsDeleteWithTrack}\n${lang.lyricsDeleteWithTrackSubtitle}',
                icon: Broken.trash,
                iconSize: 20.0,
                iconColor: NColors.fixed(isEnabled ? Colors.red : colors.disabled),
                onPressed: _onDeleteWithTrackTap,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LyricsFoldersTile extends StatelessWidget {
  final SettingTileArgs args;

  const _LyricsFoldersTile({required this.args});

  void _onRemoveTap(String folder) {
    settings.lyricsFolders.update((list) => list.remove(folder));
    final isSaveFolderGone = settings.lyricsFolders.value.isEmpty && settings.lyricsSaveLocation.value == LyricsSaveLocation.customFolder;
    if (isSaveFolderGone) settings.lyricsSaveLocation.save(LyricsSaveLocation.cache);
  }

  @override
  Widget build(BuildContext context) {
    final page = args.page;
    final isTargetWithin = page?.isTargetWithin(args.entry) == true;
    final entryChildren = args.entry.children
        .map(
          (e) => SettingEntryTile(
            entry: e,
            page: page,
          ),
        )
        .toFixedList();
    return Obx(
      (context) {
        final lyricsFolders = settings.lyricsFolders.valueR;
        final isSavingInFolder = settings.lyricsSaveLocation.valueR == LyricsSaveLocation.customFolder;
        final saveFolder = isSavingInFolder ? lyricsFolders.firstOrNull : null;
        return NamidaExpansionTile(
          bgColor: args.bgColor,
          initiallyExpanded: isTargetWithin,
          icon: Broken.folder_2,
          titleText: lang.lyricsFolders,
          subtitleText: lang.lyricsFoldersSubtitle,
          trailingBuilder: (iconWidget) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NamidaButton(
                icon: Broken.folder_add,
                text: lang.add,
                opaqueBG: true,
                onTap: _addLyricsFolder,
              ),
              iconWidget,
            ],
          ),
          children: [
            ...entryChildren,
            ...lyricsFolders.map(
              (e) => CustomListTile(
                extraDense: true,
                icon: Broken.folder,
                title: e,
                subtitle: e == saveFolder ? lang.lyricsSaveLocation : null,
                trailingRaw: NamidaTextButton(
                  minHeight: NamidaTextButton.kDefaultMinHeight * 0.8,
                  onTap: () => _onRemoveTap(e),
                  text: lang.remove.toUpperCase(),
                  fontSizeMultiplier: 0.92,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ImageSourceTile extends StatelessWidget {
  final Color? bgColor;
  final SettingsKey<List<LibraryImageSource>> setting;
  final void Function(void Function(List<LibraryImageSource> sources) fn) update;
  final String title;
  final IconData icon;

  const _ImageSourceTile({
    required this.bgColor,
    required this.setting,
    required this.update,
    required this.title,
    required this.icon,
  });

  void _onSourceTap(LibraryImageSource source) {
    final sources = setting.value;
    if (!sources.contains(source)) {
      update((list) => list.insertSafe(0, source));
    } else if (sources.length <= 1) {
      showMinimumItemsSnack(1);
    } else {
      update((list) => list.remove(source));
    }
  }

  void _addMissingSources() {
    for (final source in LibraryImageSource.values) {
      if (setting.value.contains(source)) continue;
      update((list) => list.insertSafe(0, source));
    }
  }

  void _showDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: title,
        actions: [
          IconButton(
            onPressed: _addMissingSources,
            icon: const Icon(Broken.refresh),
          ),
          const DoneButton(),
        ],
        child: ObxO(
          rx: setting,
          builder: (context, imageSources) => SuperSmoothListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [
              ...LibraryImageSource.values.map(
                (e) => Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: ListTileWithCheckMark(
                    active: imageSources.contains(e),
                    icon: e.toIcon(),
                    title: e.toText(),
                    onTap: () => _onSourceTap(e),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: setting,
      builder: (context, sources) {
        final sourcesText = LibraryImageSource.values.where((element) => sources.contains(element)).map((e) => e.toText()).join(', ');
        return CustomListTile(
          bgColor: bgColor,
          title: title,
          icon: icon,
          borderR: 16.0,
          subtitle: sourcesText,
          extraDense: true,
          onTap: _showDialog,
        );
      },
    );
  }
}

class _VibrationTypeTile extends StatelessWidget {
  final Color? bgColor;

  const _VibrationTypeTile({required this.bgColor});

  static Iterable<NamidaPopupItem> _getChildren() {
    return VibrationType.values.map(
      (e) {
        void onTap() {
          settings.vibrationType.save(e);
          NamidaNavigator.inst.popMenu();
        }

        return NamidaPopupItem(
          onTap: onTap,
          icon: e.toIcon(),
          title: e.toText(),
          selected: e == settings.vibrationType.value,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
      leading: const StackedIcon(
        baseIcon: Broken.alarm,
        secondaryIcon: Broken.wind_2,
        secondaryIconSize: 13.0,
      ),
      title: lang.vibrationType,
      trailing: NamidaPopupWrapper(
        childrenDefault: _getChildren,
        child: ObxO(
          rx: settings.vibrationType,
          builder: (context, vibrationType) => NamidaText(
            vibrationType.toText(),
            style: NText.small,
            textAlign: TextAlign.end,
          ),
        ),
      ),
    );
  }
}

class _ExtractAllPalettesTile extends StatelessWidget {
  final Color? bgColor;

  const _ExtractAllPalettesTile({required this.bgColor});

  void _onStopTap() {
    CurrentColor.inst.stopGeneratingColorPalettes();
    NamidaNavigator.inst.closeDialog();
  }

  void _onExtractTap() {
    CurrentColor.inst.generateAllColorPalettes();
    NamidaNavigator.inst.closeDialog();
  }

  Future<void> _onTap() async {
    final isGenerating = CurrentColor.inst.allColorPalettesGeneratingTotal.value > 0;
    if (isGenerating) {
      NamidaNavigator.inst.navigateDialog(
        dialog: CustomBlurryDialog(
          title: lang.note,
          bodyText: lang.forceStopColorPaletteGeneration,
          actions: [
            const CancelButton(),
            NamidaButton(
              text: lang.stop,
              onTap: _onStopTap,
            ),
          ],
        ),
      );
    } else {
      final remainingCount = await CurrentColor.inst.getRemainingColorsToExtractCount(allTracksInLibrary);
      NamidaNavigator.inst.navigateDialog(
        dialog: CustomBlurryDialog(
          title: lang.note,
          bodyText: lang.extractAllColorPalettesSubtitle(number: remainingCount),
          actions: [
            const CancelButton(),
            NamidaButton(
              text: lang.extract,
              onTap: _onExtractTap,
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final genProgress = CurrentColor.inst.allColorPalettesGeneratingProgress.valueR;
        final genTotal = CurrentColor.inst.allColorPalettesGeneratingTotal.valueR;
        final isGenerating = genTotal > 0;
        return CustomListTile(
          bgColor: bgColor,
          icon: Broken.colorfilter,
          title: lang.extractAllColorPalettes,
          trailing: isGenerating
              ? Column(
                  children: [
                    NamidaText(
                      "$genProgress/$genTotal",
                      style: NText.small,
                    ),
                    const LoadingIndicator(),
                  ],
                )
              : null,
          onTap: _onTap,
        );
      },
    );
  }
}

Future<bool> _addLyricsFolder() async {
  final hasPermission = await requestManageStoragePermission();
  if (!hasPermission) return false;
  final path = await NamidaFileBrowser.getDirectory(note: lang.lyricsFolders);
  if (path == null) return false;
  settings.lyricsFolders.update((list) => list.addNoDuplicates(path));
  return true;
}

class _DiscordAccountTile extends StatefulWidget {
  final Color? bgColor;

  const _DiscordAccountTile({required this.bgColor});

  static Future<void> onPresenceToggled(bool isEnabled) async {
    if (!isEnabled) return;
    try {
      final isLoggedIn = await NowPlayingBroadcaster.inst.ensureDiscordLogin();
      if (isLoggedIn) return;
      settings.discordPresence.save(false);
      snackyy(message: lang.signInCanceled);
    } catch (e, st) {
      settings.discordPresence.save(false);
      logger.error('discord sign in failed', e: e, st: st);
      snackyy(title: lang.signInFailed, message: e.toString(), isError: true);
    }
  }

  @override
  State<_DiscordAccountTile> createState() => _DiscordAccountTileState();
}

class _DiscordAccountTileState extends State<_DiscordAccountTile> {
  @override
  void initState() {
    super.initState();
    NowPlayingBroadcaster.inst.refreshDiscordStatus();
  }

  @override
  Widget build(BuildContext context) {
    final broadcaster = NowPlayingBroadcaster.inst;
    final signOutButton = Platform.isAndroid
        ? NamidaIconButton(
            icon: Broken.logout,
            tooltip: () => lang.signOut,
            onPressed: broadcaster.logOutOfDiscord,
          )
        : null;
    return Obx(
      (context) {
        final account = broadcaster.discordAccount.valueR;
        final status = broadcaster.discordStatus.valueR;
        final avatarWidget = account == null
            ? null
            : YoutubeThumbnail(
                key: ValueKey(account.avatarUrl),
                type: ThumbnailType.channel,
                width: 28.0,
                customUrl: account.avatarUrl,
                isImportantInCache: true,
                isCircle: true,
              );
        return CustomListTile(
          bgColor: widget.bgColor,
          icon: avatarWidget == null ? Broken.profile_circle : null,
          leading: avatarWidget,
          title: account?.name ?? 'Discord',
          subtitle: status.toText(),
          trailing: signOutButton,
        );
      },
    );
  }
}

/// reminds that the playing track is visible on the discord profile.
class DiscordSharingDotWrapper extends StatelessWidget {
  final Widget child;

  const DiscordSharingDotWrapper({super.key, required this.child});

  static const _kDiscordColor = Color(0xFF5865F2);

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: NowPlayingBroadcaster.inst.isDiscordSharing,
      builder: (context, isSharing) => Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (isSharing)
            Positioned(
              bottom: 0.0,
              right: 0.0,
              child: NDecoratedBox(
                decoration: (colors) => BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kDiscordColor,
                  border: Border.all(
                    color: colors.scaffold,
                    width: 1.0,
                  ),
                ),
                child: const SizedBox(
                  width: 7.0,
                  height: 7.0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntegrationsTrailing extends StatelessWidget {
  final Widget arrow;

  const _IntegrationsTrailing({required this.arrow});

  void _showFlagsDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.flag,
        title: lang.integrations,
        normalTitleStyle: true,
        horizontalInset: 32.0,
        actions: const [
          DoneButton(),
        ],
        child: const _IntegrationsFlagsOptions(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NamidaIconButton(
          icon: Broken.flag,
          tooltip: () => lang.configure,
          iconSize: 20.0,
          iconColor: NColors.defaultIcon(),
          onPressed: _showFlagsDialog,
        ),
        const SizedBox(
          width: 4.0,
        ),
        arrow,
        const SizedBox(
          width: 12.0,
        ),
      ],
    );
  }
}

class _IntegrationsFlagsOptions extends StatelessWidget {
  const _IntegrationsFlagsOptions();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (NamidaFeaturesVisibility.showAndroidIntegrations) ...[
            ObxO(
              rx: settings.mediaBrowserQueue,
              builder: (context, enabled) => CustomSwitchListTile(
                icon: Broken.car,
                title: 'android_auto_and_wear'.toUpperCase(),
                value: enabled,
                onChanged: (isTrue) => settings.mediaBrowserQueue.save(!isTrue),
              ),
            ),
            ObxO(
              rx: settings.nowPlayingBroadcast,
              builder: (context, enabled) => CustomSwitchListTile(
                icon: Broken.radar_2,
                title: 'now_playing_broadcast'.toUpperCase(),
                subtitle: 'Intents for Tasker & automation apps',
                value: enabled,
                onChanged: (isTrue) => settings.nowPlayingBroadcast.save(!isTrue),
              ),
            ),
            const _LyricsIntegrationsListTile(),
          ],
          const _WebhookListTile(),
          ObxO(
            rx: settings.reportPlaybackToServers,
            builder: (context, enabled) => CustomSwitchListTile(
              icon: Broken.cloud_change,
              title: 'server_playback_reports'.toUpperCase(),
              subtitle: 'Subsonic & Jellyfin: now playing, play counts',
              value: enabled,
              onChanged: (isTrue) => settings.reportPlaybackToServers.save(!isTrue),
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricsIntegrationsListTile extends StatelessWidget {
  const _LyricsIntegrationsListTile();

  void _toggle(LyricsIntegration integration) {
    settings.lyricsIntegrations.update((value) {
      if (!value.remove(integration)) value.add(integration);
    });
  }

  List<NamidaPopupItem> _items() {
    final enabled = settings.lyricsIntegrations.value;
    return LyricsIntegration.values
        .map(
          (e) => NamidaPopupItem(
            selected: enabled.contains(e),
            icon: e.toIcon(),
            title: e.toText(),
            subtitle: e.sendsPerLine ? lang.performanceNote : '',
            onTap: () => _toggle(e),
          ),
        )
        .toFixedList();
  }

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      childrenDefault: _items,
      refreshListenable: settings.lyricsIntegrations,
      child: ObxO(
        rx: settings.lyricsIntegrations,
        builder: (context, enabled) => CustomListTile(
          icon: Broken.message_text,
          title: 'status_bar_lyrics'.toUpperCase(),
          trailing: NamidaText(
            '${enabled.length}/${LyricsIntegration.values.length}',
            style: NText.medium,
          ),
        ),
      ),
    );
  }
}

class _WebhookListTile extends StatelessWidget {
  const _WebhookListTile();

  void _openDialog() {
    final urlController = TextEditingController(text: settings.webhookUrl.value);
    final formKey = GlobalKey<FormState>();
    final savedEvents = settings.webhookEvents.value;
    final draftEvents = {for (final e in WebhookEvent.values) e: savedEvents.contains(e).obs};

    void onSave() {
      final isValid = formKey.currentState?.validate() ?? false;
      if (!isValid) return;
      final url = urlController.text.trim();
      final events = <WebhookEvent>{
        for (final e in WebhookEvent.values)
          if (draftEvents[e]!.value) e,
      };
      settings.transaction(() {
        settings.webhookUrl.save(url);
        settings.webhookEvents.replace(events);
      });
      NamidaNavigator.inst.closeDialog();
    }

    final eventsListenable = Listenable.merge(draftEvents.values.toList());

    List<NamidaPopupItem> eventItems() {
      return WebhookEvent.values.map(
        (e) {
          final rx = draftEvents[e]!;
          return NamidaPopupItem(
            selected: rx.value,
            icon: e.toIcon(),
            title: e.toText(),
            onTap: () => rx.value = !rx.value,
          );
        },
      ).toFixedList();
    }

    String? validateUrl(String? value) {
      value ??= '';
      if (value.trim().isEmpty) return null;
      final uri = NowPlayingBroadcaster.parseWebhookUrl(value);
      return uri == null ? 'Invalid URL' : null;
    }

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        urlController.dispose();
        for (final rx in draftEvents.values) {
          rx.close();
        }
      },
      dialog: Form(
        key: formKey,
        child: CustomBlurryDialog(
          title: 'webhook'.toUpperCase(),
          normalTitleStyle: true,
          icon: Broken.link_2,
          actions: [
            const CancelButton(),
            NamidaButton(
              text: lang.save,
              onTap: onSave,
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12.0),
              CustomTagTextField(
                controller: urlController,
                hintText: 'https://',
                labelText: 'URL',
                keyboardType: TextInputType.url,
                validator: validateUrl,
              ),
              const SizedBox(height: 12.0),
              NamidaPopupWrapper(
                childrenDefault: eventItems,
                refreshListenable: eventsListenable,
                child: CustomListTile(
                  icon: Broken.notification_status,
                  title: 'Events',
                  trailing: Obx(
                    (context) {
                      int activeCount = 0;
                      for (final rx in draftEvents.values) {
                        if (rx.valueR) activeCount++;
                      }
                      return NamidaText(
                        '$activeCount/${WebhookEvent.values.length}',
                        style: NText.medium,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.webhookUrl,
      builder: (context, url) => CustomListTile(
        icon: Broken.link_2,
        title: 'webhook'.toUpperCase(),
        subtitle: url.isEmpty ? null : url,
        onTap: _openDialog,
      ),
    );
  }
}
