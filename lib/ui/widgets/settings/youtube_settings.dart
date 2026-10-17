import 'package:flutter/material.dart';

import 'package:youtipie/core/http.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings/return_youtube_dislike_settings.dart';
import 'package:namida/ui/widgets/settings/sponsorblock_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';
import 'package:namida/youtube/pages/user/youtube_account_manage_page.dart';

class YoutubeSettings extends SettingSubpageProvider {
  const YoutubeSettings({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.youtube;

  @override
  List<List<SettingEntry>> get sections => _sections;

  static final autoStartRadio = SettingToggle(
    settings.youtube.autoStartRadio,
    leading: const StackedIcon(
      baseIcon: Broken.radar_1,
      secondaryIcon: Broken.next,
      secondaryIconSize: 12.0,
    ),
    title: () => lang.autoStartRadio,
    subtitle: () => lang.autoStartRadioSubtitle,
    onChanged: (_) => Player.inst.tryAddingMixPlaylist(),
  );

  static final _sections = <List<SettingEntry>>[
    [
      SettingCustom(
        title: () => lang.manageYourAccounts,
        tile: (args) => _NavigationTile(
          bgColor: args.bgColor,
          icon: Broken.user_edit,
          title: lang.manageYourAccounts,
          onTap: const YoutubeAccountManagePage().navigate,
        ),
      ),
      SettingCustom(
        title: () => lang.sponsorblock,
        aliases: () => [lang.skipSponsorSegmentsInVideos],
        keys: [settings.youtube.sponsorBlockSettings],
        tile: (args) => _NavigationTile(
          bgColor: args.bgColor,
          icon: Broken.shield_slash,
          title: lang.sponsorblock,
          onTap: _openSponsorBlockPage,
        ),
      ),
      SettingCustom(
        title: () => lang.returnYoutubeDislike,
        keys: [settings.youtube.ryd],
        tile: (args) => _NavigationTile(
          bgColor: args.bgColor,
          icon: Broken.dislike,
          title: lang.returnYoutubeDislike,
          onTap: _openReturnYoutubeDislikePage,
        ),
      ),
    ],
    [
      SettingToggle(
        settings.youtube.youtubeStyleMiniplayer,
        leading: const StackedIcon(
          baseIcon: Broken.external_drive,
          secondaryIcon: Broken.video_octagon,
          secondaryIconSize: 14.0,
        ),
        title: () => lang.youtubeStyleMiniplayer,
        onChanged: (_) => Player.inst.tryGenerateWaveform(Player.inst.currentVideo),
      ),
      SettingToggle(
        settings.youtube.rememberAudioOnly,
        icon: Broken.musicnote,
        title: () => lang.rememberAudioOnlyMode,
      ),
      SettingToggle(
        settings.youtube.topComments,
        leading: const StackedIcon(
          baseIcon: Broken.document,
          secondaryIcon: Broken.arrow_circle_up,
          secondaryIconSize: 12.0,
        ),
        title: () => lang.topComments,
        subtitle: () => lang.topCommentsSubtitle,
        onChanged: _onTopCommentsToggle,
      ),
      SettingToggle(
        settings.youtube.preferNewComments,
        leading: const StackedIcon(
          baseIcon: Broken.document,
          secondaryIcon: Broken.global_refresh,
          secondaryIconSize: 12.0,
        ),
        title: () => lang.ytPreferNewComments,
        subtitle: () => lang.ytPreferNewCommentsSubtitle,
      ),
      SettingToggle(
        settings.youtube.showChannelWatermarkFullscreen,
        leading: const StackedIcon(
          baseIcon: Broken.profile_circle,
          secondaryIcon: Broken.drop,
          secondaryIconSize: 12.0,
        ),
        title: () => lang.showChannelWatermarkInFullscreen,
      ),
      SettingToggle(
        settings.youtube.showVideoEndcards,
        icon: Broken.card_tick,
        title: () => lang.showVideoEndcards,
      ),
    ],
    [
      autoStartRadio,
      SettingToggle(
        settings.youtube.personalizedRelatedVideos,
        leading: const StackedIcon(
          baseIcon: Broken.video_square,
          secondaryIcon: Broken.profile_circle,
          secondaryIconSize: 12.0,
        ),
        title: () => lang.personalizedRelatedVideos,
        subtitle: () => lang.personalizedRelatedVideosSubtitle,
        onChanged: _onPersonalizedRelatedVideosToggle,
      ),
      SettingToggle(
        settings.youtube.personalizedMixPlaylists,
        leading: const StackedIcon(
          baseIcon: Broken.video_square,
          secondaryIcon: Broken.music_playlist,
          secondaryIconSize: 12.0,
        ),
        title: () => lang.personalizedMixPlaylists,
        onChanged: _onPersonalizedMixPlaylistsToggle,
      ),
      SettingToggle(
        settings.youtube.searchCleanup,
        icon: Broken.document_filter,
        title: () => lang.enableSearchCleanup,
      ),
      SettingCustom(
        title: () => lang.showShortVideosIn,
        keys: [settings.youtube.ytVisibleShorts],
        tile: (args) => _ShowItemInListTile(
          bgColor: args.bgColor,
          title: lang.showShortVideosIn,
          icon: Broken.video_vertical,
          activeMapRx: settings.youtube.ytVisibleShorts,
          onToggle: (item) => settings.youtube.ytVisibleShorts.update((map) => map[item] = !(map[item] ?? true)),
          getValues: () => YTVisibleShortPlaces.values,
          toText: (item) => item.toText(),
          getIconsLookup: () => {
            YTVisibleShortPlaces.homeFeed: Broken.home,
            YTVisibleShortPlaces.relatedVideos: Broken.activity,
            YTVisibleShortPlaces.history: Broken.refresh,
            YTVisibleShortPlaces.search: Broken.search_favorite,
          },
        ),
      ),
      SettingCustom(
        title: () => lang.showMixPlaylistsIn,
        keys: [settings.youtube.ytVisibleMixes],
        tile: (args) => _ShowItemInListTile(
          bgColor: args.bgColor,
          title: lang.showMixPlaylistsIn,
          icon: Broken.radar_1,
          activeMapRx: settings.youtube.ytVisibleMixes,
          onToggle: (item) => settings.youtube.ytVisibleMixes.update((map) => map[item] = !(map[item] ?? true)),
          getValues: () => YTVisibleMixesPlaces.values,
          toText: (item) => item.toText(),
          getIconsLookup: () => {
            YTVisibleMixesPlaces.homeFeed: Broken.home,
            YTVisibleMixesPlaces.relatedVideos: Broken.activity,
            YTVisibleMixesPlaces.search: Broken.search_favorite,
          },
        ),
      ),
    ],
    [
      SettingCustom(
        title: () => _DimAfterTile._getTitle(settings.youtube.ytMiniplayerDimAfterSeconds.value),
        aliases: () => [lang.dimMiniplayerAfterSeconds(seconds: 0)],
        keys: [settings.youtube.ytMiniplayerDimAfterSeconds],
        tile: (args) => _DimAfterTile(
          bgColor: args.bgColor,
        ),
      ),
      SettingCustom(
        title: () => lang.dimIntensity,
        keys: [settings.youtube.ytMiniplayerDimOpacity],
        tile: (args) => _DimIntensityTile(
          bgColor: args.bgColor,
        ),
      ),
      SettingExpansion(
        icon: Broken.candle_2,
        title: () => lang.seekbar,
        children: [
          SettingCustom(
            title: () => lang.tapToSeek,
            keys: [settings.youtube.tapToSeek],
            tile: (args) => _SeekModeTile(
              bgColor: args.bgColor,
              setting: settings.youtube.tapToSeek,
              values: YTSeekActionMode.values,
              valueToText: (e) => e.toText(),
              icon: Broken.mouse_circle,
              title: lang.tapToSeek,
            ),
          ),
          SettingCustom(
            title: () => lang.dragToSeek,
            keys: [settings.youtube.dragToSeek],
            tile: (args) => _SeekModeTile(
              bgColor: args.bgColor,
              setting: settings.youtube.dragToSeek,
              values: YTSeekActionMode.values,
              valueToText: (e) => e.toText(),
              icon: Broken.arrow_swap_horizontal,
              title: lang.dragToSeek,
            ),
          ),
          SettingCustom(
            title: () => "${lang.dragToSeek} (${lang.video})",
            keys: [settings.youtube.horizontalDrag],
            tile: (args) => _SeekModeTile(
              bgColor: args.bgColor,
              setting: settings.youtube.horizontalDrag,
              values: YTHorizontalDragMode.values,
              valueToText: (e) => e.toText(),
              icon: Broken.video_horizontal,
              title: "${lang.dragToSeek} (${lang.video})",
            ),
          ),
        ],
      ),
    ],
    [
      SettingToggle(
        settings.youtube.autoExtractVideoTagsFromInfo,
        leading: const StackedIcon(
          baseIcon: Broken.import,
          secondaryIcon: Broken.tick_circle,
          secondaryIconSize: 12.0,
        ),
        title: () => lang.downloadsMetadataTags,
        subtitle: () => lang.downloadsMetadataTagsSubtitle,
      ),
      SettingCustom(
        title: () => lang.defaultDownloadLocation,
        keys: [settings.youtube.ytDownloadLocation],
        tile: (args) => _DownloadLocationTile(
          bgColor: args.bgColor,
        ),
      ),
      SettingChoice(
        settings.youtube.downloadNotifications,
        availability: const NamidaFeaturesAvailablityGroup(items: [NamidaFeaturesAvailablity.windows, NamidaFeaturesAvailablity.linux]),
        values: DownloadNotifications.values,
        valueToText: (e) => e.toText(),
        icon: Broken.notification_bing,
        title: () => '${lang.downloads} -> ${lang.notifications}',
        aliases: () => [lang.notifications, lang.downloads],
      ),
    ],
    [
      SettingChoice(
        settings.youtube.onYoutubeLinkOpen,
        values: OnYoutubeLinkOpenAction.values,
        valueToText: (e) => e.toText(),
        valueToIcon: (e) => e.toIcon(),
        icon: Broken.import_1,
        title: () => lang.onOpeningYoutubeLink,
      ),
    ],
  ];

  static void _openSponsorBlockPage() {
    SettingsSubPage(
      title: () => lang.sponsorblock,
      docsLink: AppDocsLinks.SETTINGS_SPONSORBLOCK,
      child: const SponsorBlockSettingsPage(),
    ).navigate();
  }

  static void _openReturnYoutubeDislikePage() {
    SettingsSubPage(
      title: () => lang.returnYoutubeDislike,
      docsLink: AppDocsLinks.SETTINGS_RETURN_YOUTUBE_DISLIKE,
      child: const ReturnYoutubeDislikeSettingsPage(),
    ).navigate();
  }

  static void _onTopCommentsToggle(bool isEnabled) {
    YoutubeMiniplayerUiController.inst.resetGlowUnderVideo();
    if (isEnabled) return;

    // -- pop comments subpage in case was inside.
    if (NamidaNavigator.inst.isInYTCommentRepliesSubpage) {
      NamidaNavigator.inst.ytMiniplayerCommentsPageKey.currentState?.pop();
      NamidaNavigator.inst.isInYTCommentRepliesSubpage = false;
    }
    // we need to pop both if required
    if (NamidaNavigator.inst.isInYTCommentsSubpage) {
      NamidaNavigator.inst.ytMiniplayerCommentsPageKey.currentState?.pop();
      NamidaNavigator.inst.isInYTCommentsSubpage = false;
    }
  }

  static void _onPersonalizedRelatedVideosToggle(bool isEnabled) {
    if (settings.youtube.preferMixRelatedVideos.value) return;
    YoutubeInfoController.current.onPersonalizedRelatedVideosChanged(personalized: isEnabled, preferMix: null);
  }

  static void _onPersonalizedMixPlaylistsToggle(bool isEnabled) {
    if (!settings.youtube.preferMixRelatedVideos.value) return;
    YoutubeInfoController.current.onPersonalizedRelatedVideosChanged(personalized: isEnabled, preferMix: null);
  }

  void _showYTFlagsDialog() {
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
        child: const _YTFlagsOptions(),
      ),
    );
  }

  static void openDataSaverConfigureDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.blur,
        title: lang.dataSaver,
        normalTitleStyle: true,
        actions: const [
          DoneButton(),
        ],
        child: Builder(
          builder: (context) {
            return SizedBox(
              width: context.width,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: context.height * 0.6),
                child: SuperSmoothListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    NamidaPopupWrapper(
                      child: NamidaPopupWrapper(
                        childrenDefault: _YTFlagsOptions._dataSaverChildren,
                        child: CustomListTile(
                          icon: Broken.wifi_square,
                          title: lang.dataSaverMode,
                          trailing: NamidaPopupWrapper(
                            childrenDefault: _YTFlagsOptions._dataSaverChildren,
                            child: ObxO(
                              rx: settings.youtube.dataSaverMode,
                              builder: (context, dataSaverMode) => Text(
                                dataSaverMode.toText(),
                                style: CustomListTile.getTrailingTextStyle(context.theme),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    NamidaPopupWrapper(
                      child: NamidaPopupWrapper(
                        childrenDefault: _YTFlagsOptions._dataSaverMobileChildren,
                        child: CustomListTile(
                          icon: Broken.chart_1,
                          title: '${lang.dataSaverMode} (${lang.mobile})',
                          trailing: NamidaPopupWrapper(
                            childrenDefault: _YTFlagsOptions._dataSaverMobileChildren,
                            child: ObxO(
                              rx: settings.youtube.dataSaverModeMobile,
                              builder: (context, dataSaverModeMobile) => Text(
                                dataSaverModeMobile.toText(),
                                style: CustomListTile.getTrailingTextStyle(context.theme),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static Widget getNotificationsExtractorFlagWidget({void Function()? afterChanged}) => ObxO(
    rx: settings.youtube.useNewNotificationExtractor,
    builder: (context, value) => CustomSwitchListTile(
      icon: Broken.notification_1,
      value: value,
      onChanged: (isTrue) {
        settings.youtube.useNewNotificationExtractor.save(!isTrue);
        afterChanged?.call();
      },
      title: 'use_new_notifications_extractor'.toUpperCase(),
      subtitle: 'use if you don\'t see new notifications. order might not be accurate if enabled',
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.youtube,
      subtitle: lang.youtubeSettingsSubtitle,
      icon: Broken.video,
      trailing: NamidaIconButton(
        icon: Broken.flag,
        tooltip: () => lang.configure,
        iconColor: context.defaultIconColor(),
        onPressed: _showYTFlagsDialog,
      ),
      child: SettingSectionsColumn(
        page: this,
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  final Color? bgColor;
  final IconData icon;
  final String title;
  final void Function() onTap;

  const _NavigationTile({
    required this.bgColor,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
      icon: icon,
      title: title,
      trailing: const Icon(
        Broken.arrow_right_3,
      ),
      onTap: onTap,
    );
  }
}

class _ShowItemInListTile<E extends Enum> extends StatelessWidget {
  final Color? bgColor;
  final String title;
  final IconData icon;
  final RxBaseCore<Map<Enum, bool>> activeMapRx;
  final void Function(E item) onToggle;
  final List<E> Function() getValues;
  final String Function(E item) toText;
  final Map<Enum, IconData> Function() getIconsLookup;

  const _ShowItemInListTile({
    super.key,
    required this.bgColor,
    required this.title,
    required this.icon,
    required this.activeMapRx,
    required this.onToggle,
    required this.getValues,
    required this.toText,
    required this.getIconsLookup,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: activeMapRx,
      builder: (context, activeMap) {
        final activeElements = getValues().where((element) => activeMap[element] ?? true).map((e) => toText(e));
        return CustomListTile(
          bgColor: bgColor,
          icon: icon,
          title: title,
          subtitle: activeElements.join(', '),
          onTap: () {
            final iconsLookup = getIconsLookup();
            NamidaNavigator.inst.navigateDialog(
              dialog: CustomBlurryDialog(
                icon: icon,
                normalTitleStyle: true,
                title: title,
                actions: [
                  NamidaButton(
                    text: lang.done,
                    onTap: NamidaNavigator.inst.closeDialog,
                  ),
                ],
                child: ObxO(
                  rx: activeMapRx,
                  builder: (context, activeMap) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: getValues().map(
                        (e) {
                          return Padding(
                            padding: const EdgeInsets.all(3.0),
                            child: ListTileWithCheckMark(
                              title: toText(e),
                              icon: iconsLookup[e],
                              active: activeMap[e] ?? true,
                              onTap: () => onToggle(e),
                            ),
                          );
                        },
                      ).toFixedList(),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DimAfterTile extends StatelessWidget {
  final Color? bgColor;

  const _DimAfterTile({required this.bgColor});

  static String _getTitle(int seconds) {
    return seconds == 0
        ? lang.alwaysDim
        : seconds <= -1
        ? lang.dontDim
        : lang.dimMiniplayerAfterSeconds(seconds: seconds);
  }

  static void _onSecondsChanged(int seconds) {
    settings.youtube.ytMiniplayerDimAfterSeconds.save(seconds);
    YoutubeMiniplayerUiController.inst.startDimTimer();
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.youtube.ytMiniplayerDimAfterSeconds,
      builder: (context, seconds) {
        final valueText = seconds <= -1 ? '' : "${seconds}s";
        return CustomListTile(
          bgColor: bgColor,
          leading: const StackedIcon(
            baseIcon: Broken.moon,
            secondaryIcon: Broken.clock,
            secondaryIconSize: 12.0,
          ),
          title: _getTitle(seconds),
          trailing: NamidaWheelSlider(
            max: 120,
            initValue: seconds,
            extraValue: true,
            text: valueText,
            onValueChanged: _onSecondsChanged,
          ),
        );
      },
    );
  }
}

class _DimIntensityTile extends StatelessWidget {
  final Color? bgColor;

  const _DimIntensityTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.youtube.ytMiniplayerDimAfterSeconds,
      builder: (context, dimAfterSeconds) => CustomListTile(
        bgColor: bgColor,
        enabled: dimAfterSeconds >= 0,
        leading: const _DimIntensityIcon(),
        title: lang.dimIntensity,
        trailing: ObxO(
          rx: settings.youtube.ytMiniplayerDimOpacity,
          builder: (context, dimOpacity) {
            final percentage = (dimOpacity * 100).round();
            return NamidaWheelSlider(
              max: 100,
              initValue: percentage,
              text: "$percentage%",
              onValueChanged: (val) => settings.youtube.ytMiniplayerDimOpacity.save(val / 100),
            );
          },
        ),
      ),
    );
  }
}

class _DimIntensityIcon extends StatelessWidget {
  const _DimIntensityIcon();

  @override
  Widget build(BuildContext context) {
    const multiplier = 4.5;
    const minus = multiplier / 2;
    const height = 7.0;
    const origin = height / 2;
    final iconColor = context.defaultIconColor();
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Broken.devices,
          size: 24.0,
          color: iconColor,
        ),
        // -- hide middle part
        Container(
          width: 7.0,
          height: 7.0,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: context.theme.scaffoldBackgroundColor,
                blurRadius: 1.0,
                offset: const Offset(0, 2.0),
              ),
            ],
          ),
        ),
        // -- needle
        ObxO(
          rx: settings.youtube.ytMiniplayerDimOpacity,
          builder: (context, dimOpacity) {
            final angle = (dimOpacity * multiplier) - minus;
            return Transform.rotate(
              origin: const Offset(0, origin),
              angle: angle,
              child: Container(
                width: 2.0,
                height: height,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SeekModeTile<E extends Enum> extends StatelessWidget {
  final Color? bgColor;
  final SettingsKey<E> setting;
  final List<E> values;
  final String Function(E value) valueToText;
  final IconData icon;
  final String title;

  const _SeekModeTile({
    required this.bgColor,
    required this.setting,
    required this.values,
    required this.valueToText,
    required this.icon,
    required this.title,
  });

  Iterable<NamidaPopupItem> _getMenuItems() {
    return values.map(
      (e) => NamidaPopupItem(
        icon: Broken.external_drive,
        title: valueToText(e),
        selected: e == setting.value,
        onTap: () => setting.save(e),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
      icon: icon,
      title: title,
      trailing: NamidaPopupWrapper(
        childrenDefault: _getMenuItems,
        child: ObxO(
          rx: setting,
          builder: (context, value) => Text(
            valueToText(value),
            style: CustomListTile.getTrailingTextStyle(context.theme),
            textAlign: TextAlign.end,
          ),
        ),
      ),
    );
  }
}

class _DownloadLocationTile extends StatelessWidget {
  final Color? bgColor;

  const _DownloadLocationTile({required this.bgColor});

  Future<void> _pickDirectory() async {
    final path = await NamidaFileBrowser.getDirectory(note: lang.defaultDownloadLocation);
    if (path != null) settings.youtube.ytDownloadLocation.save(path);
  }

  void _openInFileExplorer() {
    final path = settings.youtube.ytDownloadLocation.value;
    NamidaChannel.inst.openFileInExplorer(path, isDirectory: true);
  }

  @override
  Widget build(BuildContext context) {
    final openInFileExplorerButton = NamidaChannel.inst.canOpenFileInExplorer
        ? IconButton(
            tooltip: lang.openInFileExplorer,
            onPressed: _openInFileExplorer,
            icon: const Icon(
              Broken.export_1,
              size: 20.0,
            ),
          )
        : null;
    return ObxO(
      rx: settings.youtube.ytDownloadLocation,
      builder: (context, downloadLocation) => CustomListTile(
        bgColor: bgColor,
        title: lang.defaultDownloadLocation,
        icon: Broken.folder_favorite,
        subtitle: downloadLocation,
        onTap: _pickDirectory,
        trailingRaw: openInFileExplorerButton,
      ),
    );
  }
}

class _YTFlagsOptions extends StatelessWidget {
  const _YTFlagsOptions();

  static List<NamidaPopupItem> _innertubeChildren() => [
    NamidaPopupItem(
      icon: Broken.video_horizontal,
      title: lang.defaultLabel,
      selected: null == settings.youtube.innertubeClient.value,
      onTap: settings.youtube.innertubeClient.reset,
    ),
    ...InnertubeClients.values.map(
      (e) => NamidaPopupItem(
        icon: Broken.video_octagon,
        title: e.name,
        selected: e == settings.youtube.innertubeClient.value,
        onTap: () => settings.youtube.innertubeClient.save(e),
      ),
    ),
  ];

  static Iterable<NamidaPopupItem> _dataSaverChildren([void Function()? onSave]) {
    return DataSaverMode.values.map(
      (e) => NamidaPopupItem(
        icon: Broken.cd,
        title: e.toText(),
        selected: e == settings.youtube.dataSaverMode.value,
        onTap: () {
          settings.youtube.dataSaverMode.save(e);
          onSave?.call();
        },
      ),
    );
  }

  static List<NamidaPopupItem> _dataSaverMobileChildren([void Function()? onSave]) => [
    ...DataSaverMode.values.map(
      (e) => NamidaPopupItem(
        icon: Broken.cd,
        title: e.toText(),
        selected: e == settings.youtube.dataSaverModeMobile.value,
        onTap: () {
          settings.youtube.dataSaverModeMobile.save(e);
          onSave?.call();
        },
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
              ObxO(
                rx: settings.youtube.markVideoWatched,
                builder: (context, markVideoWatched) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.video,
                    secondaryIcon: Broken.tick_circle,
                    secondaryIconSize: 12.0,
                  ),
                  value: markVideoWatched,
                  onChanged: (isTrue) => settings.youtube.markVideoWatched.save(!isTrue),
                  title: 'mark_video_watched'.toUpperCase(),
                ),
              ),
              ObxO(
                rx: settings.youtube.fallbackExtractInfoDescription,
                builder: (context, fallbackExtractInfoDescription) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.document_text_1,
                    secondaryIcon: Broken.export_1,
                    secondaryIconSize: 12.0,
                  ),
                  value: fallbackExtractInfoDescription,
                  onChanged: (isTrue) => settings.youtube.fallbackExtractInfoDescription.save(!isTrue),
                  title: 'try_extract_tags_info_from_description'.toUpperCase(),
                ),
              ),
              NamidaPopupWrapper(
                child: NamidaPopupWrapper(
                  childrenDefault: _innertubeChildren,
                  child: CustomListTile(
                    icon: Broken.cpu,
                    title: 'innertube_client'.toUpperCase(),
                    trailing: NamidaPopupWrapper(
                      childrenDefault: _innertubeChildren,
                      child: ObxO(
                        rx: settings.youtube.innertubeClient,
                        builder: (context, innertubeClient) => Text(
                          innertubeClient?.name ?? lang.defaultLabel,
                          style: context.textTheme.displayMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ObxO(
                rx: settings.youtube.whiteVideoBGInLightMode,
                builder: (context, whiteVideoBGInLightMode) => CustomSwitchListTile(
                  icon: Broken.sun_1,
                  value: whiteVideoBGInLightMode,
                  onChanged: (isTrue) => settings.youtube.whiteVideoBGInLightMode.save(!isTrue),
                  title: 'white_video_bg_in_light_mode'.toUpperCase(),
                ),
              ),
              ObxO(
                rx: settings.youtube.enableDimInLightMode,
                builder: (context, enableDimInLightMode) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.sun_1,
                    secondaryIcon: Broken.moon,
                    secondaryIconSize: 12.0,
                  ),
                  value: enableDimInLightMode,
                  onChanged: (isTrue) {
                    settings.youtube.enableDimInLightMode.save(!isTrue);
                    YoutubeMiniplayerUiController.inst.startDimTimer();
                  },
                  title: 'enable_dim_in_light_mode'.toUpperCase(),
                ),
              ),
              ObxO(
                rx: settings.youtube.allowExperimentalCodecs,
                builder: (context, allowExperimentalCodecs) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.story,
                    secondaryIcon: Broken.cpu_charge,
                    secondaryIconSize: 12.0,
                  ),
                  value: allowExperimentalCodecs,
                  onChanged: (isTrue) => settings.youtube.allowExperimentalCodecs.save(!isTrue),
                  title: 'allow_experimental_codecs'.toUpperCase(),
                  subtitle: 'av1 & vp9',
                ),
              ),
              ObxO(
                rx: settings.youtube.preferOpusFormat,
                builder: (context, preferOpusFormat) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.audio_square,
                    secondaryIcon: Broken.cpu_charge,
                    secondaryIconSize: 12.0,
                  ),
                  value: preferOpusFormat,
                  onChanged: (isTrue) => settings.youtube.preferOpusFormat.save(!isTrue),
                  title: 'prefer_opus_format'.toUpperCase(),
                  subtitle: 'opus/webm',
                ),
              ),
              ObxO(
                rx: settings.youtube.enableGifThumbnails,
                builder: (context, enableGifThumbnails) => CustomSwitchListTile(
                  icon: Broken.video_horizontal,
                  value: enableGifThumbnails,
                  onChanged: (isTrue) => settings.youtube.enableGifThumbnails.save(!isTrue),
                  title: 'enable_gif_thumbnails'.toUpperCase(),
                ),
              ),
              ObxO(
                rx: settings.youtube.enableStreamSegments,
                builder: (context, enableStreamSegments) => CustomSwitchListTile(
                  icon: Broken.weight_1,
                  value: enableStreamSegments,
                  onChanged: (isTrue) => settings.youtube.enableStreamSegments.save(!isTrue),
                  title: 'enable_stream_segments'.toUpperCase(),
                ),
              ),
              ObxO(
                rx: settings.youtube.enableHeatMap,
                builder: (context, enableHeatMap) => CustomSwitchListTile(
                  icon: Broken.wind_2,
                  value: enableHeatMap,
                  onChanged: (isTrue) => settings.youtube.enableHeatMap.save(!isTrue),
                  title: 'enable_seek_heatmap'.toUpperCase(),
                ),
              ),
              ObxO(
                rx: settings.youtube.preferMixRelatedVideos,
                builder: (context, preferMixRelatedVideos) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.video_square,
                    secondaryIcon: Broken.music_playlist,
                    secondaryIconSize: 12.0,
                  ),
                  value: preferMixRelatedVideos,
                  onChanged: (isTrue) {
                    settings.youtube.preferMixRelatedVideos.save(!isTrue);
                    YoutubeInfoController.current.onPersonalizedRelatedVideosChanged(personalized: null, preferMix: !isTrue);
                  },
                  title: 'prefer_mix_playlist_as_related_videos'.toUpperCase(),
                ),
              ),
              ObxO(
                rx: settings.youtube.showLikeStatusOnCards,
                builder: (context, showLikeStatusOnCards) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.card,
                    secondaryIcon: Broken.like_1,
                    secondaryIconSize: 12.0,
                  ),
                  value: showLikeStatusOnCards,
                  onChanged: (isTrue) {
                    settings.youtube.showLikeStatusOnCards.save(!isTrue);
                  },
                  title: 'show_like_status_on_cards'.toUpperCase(),
                  subtitle: 'can increase data usage',
                ),
              ),
              ObxO(
                rx: settings.youtube.preferLikeButtonOverFavourite,
                builder: (context, preferLikeButtonOverFavourite) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.heart,
                    secondaryIcon: Broken.like_1,
                    secondaryIconSize: 12.0,
                  ),
                  value: preferLikeButtonOverFavourite,
                  onChanged: (isTrue) => settings.youtube.preferLikeButtonOverFavourite.save(!isTrue),
                  title: 'prefer_like_button_over_favourite'.toUpperCase(),
                  subtitle: 'show like instead of heart in notification, widgets, etc. when signed in',
                ),
              ),
              ObxO(
                rx: settings.youtube.linkLikeButtonWithFavourites,
                builder: (context, linkLikeButtonWithFavourites) => CustomSwitchListTile(
                  leading: const StackedIcon(
                    baseIcon: Broken.like_1,
                    secondaryIcon: Broken.heart,
                    secondaryIconSize: 12.0,
                  ),
                  value: linkLikeButtonWithFavourites,
                  onChanged: (isTrue) => settings.youtube.linkLikeButtonWithFavourites.save(!isTrue),
                  title: 'link_like_button_with_favourites'.toUpperCase(),
                  subtitle: 'liking adds to local favourites, unliking/disliking removes',
                ),
              ),
              YoutubeSettings.getNotificationsExtractorFlagWidget(),
              ObxO(
                rx: settings.youtube.maxPageCacheDurationMin,
                builder: (context, maxPageCacheDurationMin) => CustomListTile(
                  icon: Broken.driver_refresh,
                  title: 'max_page_cache_duration_validity'.toUpperCase(),
                  onTap: () {
                    NamidaNavigator.inst.navigateDialog(
                      dialog: _MaxPageCacheDurationDialog(
                        icon: Broken.driver_refresh,
                        title: 'max_page_cache_duration_validity'.toUpperCase(),
                        onSave: settings.youtube.maxPageCacheDurationMin.save,
                      ),
                    );
                  },
                  trailingText: maxPageCacheDurationMin < 0
                      ? 'always valid'
                      : maxPageCacheDurationMin > settings.youtube.kMinutesInMaxDaysForPageCache
                      ? 'always invalid'
                      : maxPageCacheDurationMin > 24 * 60
                      ? '${(maxPageCacheDurationMin / 24 / 60).toStringAsFixed(1)} days'
                      : maxPageCacheDurationMin > 60
                      ? '${(maxPageCacheDurationMin / 60).toStringAsFixed(1)} hours'
                      : '$maxPageCacheDurationMin min',
                ),
              ),
              const _ResetYoutubeSessionTile(),
              CustomListTile(
                icon: Broken.hierarchy_square,
                title: 'copy_yt_history_to_local_history'.toUpperCase(),
                onTap: () {
                  NamidaNavigator.inst.navigateDialog(
                    dialog: CustomBlurryDialog(
                      isWarning: true,
                      normalTitleStyle: true,
                      bodyText: lang.confirm,
                      actions: [
                        const CancelButton(),
                        NamidaButton(
                          text: lang.confirm.toUpperCase(),
                          onTap: () async {
                            await NamidaNavigator.inst.closeDialog(2);
                            final totalAndActual = await JsonToHistoryParser.inst.copyYTHistoryContentToLocalHistory(matchAll: true);
                            final total = totalAndActual.$1;
                            final actual = totalAndActual.$2;
                            snackyy(
                              message: '${lang.totalTracks.capitalizeFirst()}: ${total.displayTrackKeyword} | ${lang.added.capitalizeFirst()}: ${actual.displayTrackKeyword}',
                            );
                          },
                        ),
                      ],
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

class _ResetYoutubeSessionTile extends StatefulWidget {
  const _ResetYoutubeSessionTile();

  @override
  State<_ResetYoutubeSessionTile> createState() => _ResetYoutubeSessionTileState();
}

class _ResetYoutubeSessionTileState extends State<_ResetYoutubeSessionTile> {
  bool _isResetting = false;
  late String _subtitle = _getSubtitle();

  String _getSubtitle() {
    final jsPlayerVersion = YoutubeInfoController.video.getJSPlayerVersion() ?? '?';
    final lastReset = YoutubeInfoController.video.getLastSessionReset();
    final lastResetText = lastReset?.dateAndClockFormatted ?? 'never';
    return 'js player: $jsPlayerVersion | last reset: $lastResetText';
  }

  Future<void> _reset() async {
    setState(() => _isResetting = true);
    await YoutubeInfoController.video.resetSession();
    if (!mounted) return;
    setState(() {
      _isResetting = false;
      _subtitle = _getSubtitle();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      leading: const StackedIcon(
        baseIcon: Broken.code_1,
        secondaryIcon: Broken.refresh,
        secondaryIconSize: 12.0,
      ),
      enabled: !_isResetting,
      title: 'reset_youtube_session'.toUpperCase(),
      subtitle: _subtitle,
      trailing: _isResetting ? const LoadingIndicator() : null,
      onTap: _reset,
    );
  }
}

class _MaxPageCacheDurationDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final void Function(int minutesTotal) onSave;

  const _MaxPageCacheDurationDialog({
    required this.title,
    required this.icon,
    required this.onSave,
  });

  @override
  State<_MaxPageCacheDurationDialog> createState() => _MaxPageCacheDurationDialogState();
}

class _MaxPageCacheDurationDialogState extends State<_MaxPageCacheDurationDialog> {
  static int get maxDays => settings.youtube.kMaxDaysForPageCacheDuration;
  static const maxHours = 24;
  static const maxMinutes = 60;

  final daysRx = 0.obs;
  final hoursRx = 0.obs;
  final minutesRx = 0.obs;

  @override
  void initState() {
    final int initial = settings.youtube.maxPageCacheDurationMin.value;
    if (initial < 0) {
      minutesRx.value = -1;
    } else {
      if (initial > settings.youtube.kMinutesInMaxDaysForPageCache) {
        // -- keep hours and mins at 0
        daysRx.value = _MaxPageCacheDurationDialogState.maxDays + 1;
      } else {
        daysRx.value = (initial / (24 * 60)).floor();
        hoursRx.value = ((initial % (24 * 60)) / 60).floor();
        minutesRx.value = (initial % 60).floor();
      }
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final maxDays = _MaxPageCacheDurationDialogState.maxDays;
    return CustomBlurryDialog(
      title: widget.title,
      icon: widget.icon,
      normalTitleStyle: true,
      actions: [
        const CancelButton(),
        NamidaButton(
          text: lang.save,
          onTap: () {
            final minutesTotal = daysRx.value > _MaxPageCacheDurationDialogState.maxDays
                ? settings.youtube.kMinutesInMaxDaysForPageCache + 1
                : minutesRx.value < 0
                ? -1
                : (minutesRx.value) + (hoursRx.value * 60) + (daysRx.value * 60 * 24);
            widget.onSave(minutesTotal);
            NamidaNavigator.inst.closeDialog();
          },
        ),
      ],
      child: SmoothSingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 32.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Days',
                  style: context.textTheme.displayMedium,
                ),
                const SizedBox(width: 12.0),
                ObxO(
                  rx: daysRx,
                  builder: (context, days) => NamidaWheelSlider(
                    max: maxDays + 1,
                    stepper: 1,
                    initValue: days,
                    onValueChanged: (val) => daysRx.value = val,
                    text: days > maxDays ? 'always invalid' : "$days days",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hours',
                  style: context.textTheme.displayMedium,
                ),
                const SizedBox(width: 12.0),
                ObxO(
                  rx: hoursRx,
                  builder: (context, hours) => NamidaWheelSlider(
                    max: maxHours,
                    stepper: 1,
                    initValue: hours,
                    onValueChanged: (val) => hoursRx.value = val,
                    text: "$hours hours",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Minutes',
                  style: context.textTheme.displayMedium,
                ),
                const SizedBox(width: 12.0),
                ObxO(
                  rx: minutesRx,
                  builder: (context, minutes) => NamidaWheelSlider(
                    max: maxMinutes + 1,
                    stepper: 1,
                    initValue: minutes < 0 ? 0 : minutes,
                    onValueChanged: (val) => minutesRx.value = val - 1,
                    text: minutes < 0 ? 'always valid' : "$minutes min",
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
