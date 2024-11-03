import 'package:flutter/material.dart';

import 'package:youtipie/core/http.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';
import 'package:namida/youtube/pages/user/youtube_account_manage_page.dart';

enum _YoutubeSettingKeys {
  manageYourAccounts,
  youtubeStyleMiniplayer,
  rememberAudioOnly,
  showShortsIn,
  showMixesIn,
  topComments,
  preferNewComments,
  showChannelWatermarkFullscreen,
  showVideoEndcards,
  autoStartRadio,
  dimMiniplayerAfter,
  dimIntensity,
  downloadsMetadataTags,
  downloadLocation,
  onOpeningYTLink,
  seekbar,
}

class YoutubeSettings extends SettingSubpageProvider {
  const YoutubeSettings({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.youtube;

  @override
  Map<Enum, List<String>> get lookupMap => {
        _YoutubeSettingKeys.manageYourAccounts: [lang.MANAGE_YOUR_ACCOUNTS],
        _YoutubeSettingKeys.youtubeStyleMiniplayer: [lang.YOUTUBE_STYLE_MINIPLAYER],
        _YoutubeSettingKeys.rememberAudioOnly: [lang.REMEMBER_AUDIO_ONLY_MODE],
        _YoutubeSettingKeys.showShortsIn: [lang.SHOW_SHORT_VIDEOS_IN],
        _YoutubeSettingKeys.showMixesIn: [lang.SHOW_MIX_PLAYLISTS_IN],
        _YoutubeSettingKeys.topComments: [lang.TOP_COMMENTS, lang.TOP_COMMENTS_SUBTITLE],
        _YoutubeSettingKeys.preferNewComments: [lang.YT_PREFER_NEW_COMMENTS, lang.YT_PREFER_NEW_COMMENTS_SUBTITLE],
        _YoutubeSettingKeys.showChannelWatermarkFullscreen: [lang.SHOW_CHANNEL_WATERMARK_IN_FULLSCREEN],
        _YoutubeSettingKeys.showVideoEndcards: [lang.SHOW_VIDEO_ENDCARDS],
        _YoutubeSettingKeys.autoStartRadio: [lang.AUTO_START_RADIO, lang.AUTO_START_RADIO_SUBTITLE],
        _YoutubeSettingKeys.dimMiniplayerAfter: [lang.DIM_MINIPLAYER_AFTER_SECONDS],
        _YoutubeSettingKeys.dimIntensity: [lang.DIM_INTENSITY],
        _YoutubeSettingKeys.seekbar: [lang.SEEKBAR, lang.TAP_TO_SEEK, lang.DRAG_TO_SEEK],
        _YoutubeSettingKeys.downloadsMetadataTags: [lang.DOWNLOADS_METADATA_TAGS, lang.DOWNLOADS_METADATA_TAGS_SUBTITLE],
        _YoutubeSettingKeys.downloadLocation: [lang.DEFAULT_DOWNLOAD_LOCATION],
        _YoutubeSettingKeys.onOpeningYTLink: [lang.ON_OPENING_YOUTUBE_LINK],
      };

  void _showYTFlagsDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.flag,
        title: lang.CONFIGURE,
        normalTitleStyle: true,
        actions: [
          NamidaButton(
            text: lang.DONE,
            onPressed: NamidaNavigator.inst.closeDialog,
          ),
        ],
        child: const _YTFlagsOptions(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.YOUTUBE,
      subtitle: lang.YOUTUBE_SETTINGS_SUBTITLE,
      icon: Broken.video,
      trailing: NamidaIconButton(
        icon: Broken.flag,
        tooltip: () => lang.REFRESH_LIBRARY,
        onPressed: _showYTFlagsDialog,
      ),
      child: Column(
        children: [
          getItemWrapper(
            key: _YoutubeSettingKeys.manageYourAccounts,
            child: CustomListTile(
              bgColor: getBgColor(_YoutubeSettingKeys.manageYourAccounts),
              icon: Broken.user_edit,
              title: lang.MANAGE_YOUR_ACCOUNTS,
              trailing: const Icon(Broken.arrow_right_3),
              onTap: const YoutubeAccountManagePage().navigate,
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.youtubeStyleMiniplayer,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.youtubeStyleMiniplayer),
                icon: Broken.video_octagon,
                title: lang.YOUTUBE_STYLE_MINIPLAYER,
                value: settings.youtube.youtubeStyleMiniplayer.valueR,
                onChanged: (isTrue) {
                  settings.youtube.save(youtubeStyleMiniplayer: !isTrue);
                  Player.inst.tryGenerateWaveform(Player.inst.currentVideo);
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.rememberAudioOnly,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.rememberAudioOnly),
                icon: Broken.musicnote,
                title: lang.REMEMBER_AUDIO_ONLY_MODE,
                value: settings.youtube.rememberAudioOnly.valueR,
                onChanged: (isTrue) => settings.youtube.save(rememberAudioOnly: !isTrue),
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.topComments,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.topComments),
                leading: const StackedIcon(
                  baseIcon: Broken.document,
                  secondaryIcon: Broken.arrow_circle_up,
                  secondaryIconSize: 12.0,
                ),
                title: lang.TOP_COMMENTS,
                subtitle: lang.TOP_COMMENTS_SUBTITLE,
                value: settings.youtube.topComments.valueR,
                onChanged: (isTrue) {
                  settings.youtube.save(topComments: !isTrue);
                  YoutubeMiniplayerUiController.inst.resetGlowUnderVideo();

                  // -- pop comments subpage in case was inside.
                  if (settings.youtube.topComments.value == false) {
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
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.preferNewComments,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.preferNewComments),
                leading: const StackedIcon(
                  baseIcon: Broken.document,
                  secondaryIcon: Broken.global_refresh,
                  secondaryIconSize: 12.0,
                ),
                title: lang.YT_PREFER_NEW_COMMENTS,
                subtitle: lang.YT_PREFER_NEW_COMMENTS_SUBTITLE,
                value: settings.youtube.preferNewComments.valueR,
                onChanged: (isTrue) => settings.youtube.save(preferNewComments: !isTrue),
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.showChannelWatermarkFullscreen,
            child: ObxO(
              rx: settings.youtube.showChannelWatermarkFullscreen,
              builder: (context, showChannelWatermarkFullscreen) => CustomSwitchListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.showChannelWatermarkFullscreen),
                leading: const StackedIcon(
                  baseIcon: Broken.profile_circle,
                  secondaryIcon: Broken.drop,
                  secondaryIconSize: 12.0,
                ),
                title: lang.SHOW_CHANNEL_WATERMARK_IN_FULLSCREEN,
                value: showChannelWatermarkFullscreen,
                onChanged: (isTrue) => settings.youtube.save(showChannelWatermarkFullscreen: !isTrue),
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.showVideoEndcards,
            child: ObxO(
              rx: settings.youtube.showVideoEndcards,
              builder: (context, showVideoEndcards) => CustomSwitchListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.showVideoEndcards),
                icon: Broken.card_tick,
                title: '${lang.SHOW_VIDEO_ENDCARDS} (${lang.BETA})', // beta cuz its available only in some clients like web & web_music
                value: showVideoEndcards,
                onChanged: (isTrue) => settings.youtube.save(showVideoEndcards: !isTrue),
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.autoStartRadio,
            child: ObxO(
              rx: settings.youtube.autoStartRadio,
              builder: (context, autoStartRadio) => CustomSwitchListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.autoStartRadio),
                leading: const StackedIcon(
                  baseIcon: Broken.radar_1,
                  secondaryIcon: Broken.next,
                  secondaryIconSize: 12.0,
                ),
                title: lang.AUTO_START_RADIO,
                subtitle: lang.AUTO_START_RADIO_SUBTITLE,
                value: autoStartRadio,
                onChanged: (isTrue) => settings.youtube.save(autoStartRadio: !isTrue),
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.showShortsIn,
            child: _ShowItemInListTile(
              bgColor: getBgColor(_YoutubeSettingKeys.showShortsIn),
              title: lang.SHOW_SHORT_VIDEOS_IN,
              icon: Broken.video_vertical,
              activeMapRx: settings.youtube.ytVisibleShorts,
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
          getItemWrapper(
            key: _YoutubeSettingKeys.showMixesIn,
            child: _ShowItemInListTile(
              bgColor: getBgColor(_YoutubeSettingKeys.showMixesIn),
              title: lang.SHOW_MIX_PLAYLISTS_IN,
              icon: Broken.radar_1,
              activeMapRx: settings.youtube.ytVisibleMixes,
              getValues: () => YTVisibleMixesPlaces.values,
              toText: (item) => item.toText(),
              getIconsLookup: () => {
                YTVisibleMixesPlaces.homeFeed: Broken.home,
                YTVisibleMixesPlaces.relatedVideos: Broken.activity,
                YTVisibleMixesPlaces.search: Broken.search_favorite,
              },
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.dimMiniplayerAfter,
            child: ObxO(
              rx: settings.youtube.ytMiniplayerDimAfterSeconds,
              builder: (context, ytMiniplayerDimAfterSeconds) => CustomListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.dimMiniplayerAfter),
                leading: const StackedIcon(
                  baseIcon: Broken.moon,
                  secondaryIcon: Broken.clock,
                  secondaryIconSize: 12.0,
                ),
                title: lang.DIM_MINIPLAYER_AFTER_SECONDS.replaceFirst(
                  '_SECONDS_',
                  "$ytMiniplayerDimAfterSeconds",
                ),
                trailing: NamidaWheelSlider(
                  totalCount: 120,
                  initValue: ytMiniplayerDimAfterSeconds,
                  text: "${ytMiniplayerDimAfterSeconds}s",
                  onValueChanged: (val) {
                    settings.youtube.save(ytMiniplayerDimAfterSeconds: val);
                  },
                ),
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.dimIntensity,
            child: ObxO(
              rx: settings.youtube.ytMiniplayerDimAfterSeconds,
              builder: (context, ytMiniplayerDimAfterSeconds) => CustomListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.dimIntensity),
                enabled: ytMiniplayerDimAfterSeconds > 0,
                leading: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Broken.devices,
                      size: 24.0,
                      color: context.defaultIconColor(),
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
                    Obx(
                      (context) {
                        const multiplier = 4.5;
                        const minus = multiplier / 2;
                        const height = 7.0;
                        const origin = height / 2;
                        return Transform.rotate(
                          origin: const Offset(0, origin),
                          angle: (settings.youtube.ytMiniplayerDimOpacity.valueR * multiplier) - minus,
                          child: Container(
                            width: 2.0,
                            height: height,
                            decoration: BoxDecoration(
                              color: context.defaultIconColor(),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        );
                      },
                    )
                  ],
                ),
                title: lang.DIM_INTENSITY,
                trailing: ObxO(
                  rx: settings.youtube.ytMiniplayerDimOpacity,
                  builder: (context, ytMiniplayerDimOpacity) => NamidaWheelSlider(
                    totalCount: 100,
                    initValue: (ytMiniplayerDimOpacity * 100).round(),
                    text: "${(ytMiniplayerDimOpacity * 100).round()}%",
                    onValueChanged: (val) {
                      settings.youtube.save(ytMiniplayerDimOpacity: val / 100);
                    },
                  ),
                ),
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.seekbar,
            child: NamidaExpansionTile(
              bgColor: getBgColor(_YoutubeSettingKeys.seekbar),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
              iconColor: context.defaultIconColor(),
              icon: Broken.candle_2,
              titleText: lang.SEEKBAR,
              children: [
                CustomListTile(
                  icon: Broken.mouse_circle,
                  title: lang.TAP_TO_SEEK,
                  trailing: NamidaPopupWrapper(
                    childrenDefault: () => YTSeekActionMode.values
                        .map(
                          (e) => NamidaPopupItem(
                            icon: Broken.external_drive,
                            title: e.toText(),
                            onTap: () {
                              settings.youtube.save(tapToSeek: e);
                            },
                          ),
                        )
                        .toList(),
                    child: Obx(
                      (context) => Text(
                        settings.youtube.tapToSeek.valueR.toText(),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                ),
                CustomListTile(
                  icon: Broken.arrow_swap_horizontal,
                  title: lang.DRAG_TO_SEEK,
                  trailing: NamidaPopupWrapper(
                    childrenDefault: () => YTSeekActionMode.values
                        .map(
                          (e) => NamidaPopupItem(
                            icon: Broken.external_drive,
                            title: e.toText(),
                            onTap: () {
                              settings.youtube.save(dragToSeek: e);
                            },
                          ),
                        )
                        .toList(),
                    child: Obx(
                      (context) => Text(
                        settings.youtube.dragToSeek.valueR.toText(),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.downloadsMetadataTags,
            child: Obx(
              (context) => CustomSwitchListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.downloadsMetadataTags),
                leading: const StackedIcon(
                  baseIcon: Broken.import,
                  secondaryIcon: Broken.tick_circle,
                  secondaryIconSize: 12.0,
                ),
                title: lang.DOWNLOADS_METADATA_TAGS,
                subtitle: lang.DOWNLOADS_METADATA_TAGS_SUBTITLE,
                value: settings.youtube.autoExtractVideoTagsFromInfo.valueR,
                onChanged: (isTrue) => settings.youtube.save(autoExtractVideoTagsFromInfo: !isTrue),
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.downloadLocation,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.downloadLocation),
                title: lang.DEFAULT_DOWNLOAD_LOCATION,
                icon: Broken.folder_favorite,
                subtitle: settings.youtube.ytDownloadLocation.valueR,
                onTap: () async {
                  final path = await NamidaFileBrowser.getDirectory(note: lang.DEFAULT_DOWNLOAD_LOCATION);
                  if (path != null) settings.youtube.save(ytDownloadLocation: path);
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.onOpeningYTLink,
            child: Obx(
              (context) => CustomListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.onOpeningYTLink),
                icon: Broken.import_1,
                title: lang.ON_OPENING_YOUTUBE_LINK,
                trailingText: settings.youtube.onYoutubeLinkOpen.valueR.toText(),
                onTap: () {
                  NamidaNavigator.inst.navigateDialog(
                    dialog: CustomBlurryDialog(
                      title: lang.CHOOSE,
                      actions: const [
                        DoneButton(),
                      ],
                      child: Column(
                        children: [
                          ...OnYoutubeLinkOpenAction.values.map(
                            (e) => Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: ObxO(
                                rx: settings.youtube.onYoutubeLinkOpen,
                                builder: (context, onYoutubeLinkOpen) => ListTileWithCheckMark(
                                  icon: e.toIcon(),
                                  title: e.toText(),
                                  active: onYoutubeLinkOpen == e,
                                  onTap: () {
                                    settings.youtube.save(onYoutubeLinkOpen: e);
                                  },
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
          ),
        ],
      ),
    );
  }
}

class _ShowItemInListTile<E extends Enum> extends StatelessWidget {
  final Color? bgColor;
  final String title;
  final IconData icon;
  final RxMap<Enum, bool> activeMapRx;
  final List<E> Function() getValues;
  final String Function(E item) toText;
  final Map<Enum, IconData> Function() getIconsLookup;

  const _ShowItemInListTile({
    super.key,
    required this.bgColor,
    required this.title,
    required this.icon,
    required this.activeMapRx,
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
            bool didModify = false;
            final iconsLookup = getIconsLookup();
            NamidaNavigator.inst.navigateDialog(
              dialog: PopScope(
                onPopInvoked: (didPop) {
                  if (!didPop) return;
                  if (didModify) settings.youtube.save();
                },
                child: CustomBlurryDialog(
                  icon: icon,
                  normalTitleStyle: true,
                  title: title,
                  actions: [
                    NamidaButton(
                      text: lang.DONE,
                      onPressed: NamidaNavigator.inst.closeDialog,
                    )
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
                                onTap: () {
                                  didModify = true;
                                  activeMapRx[e] = !(activeMapRx[e] ?? true);
                                },
                              ),
                            );
                          },
                        ).toList(),
                      ),
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

class _YTFlagsOptions extends StatefulWidget {
  const _YTFlagsOptions();

  @override
  State<_YTFlagsOptions> createState() => __YTFlagsOptionsState();
}

class __YTFlagsOptionsState extends State<_YTFlagsOptions> {
  bool didRefreshJsPlayer = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.width,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: context.height * 0.6),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            CustomSwitchListTile(
              leading: StackedIcon(
                baseIcon: Broken.video,
                secondaryIcon: Broken.tick_circle,
                secondaryIconSize: 12.0,
              ),
              value: settings.youtube.markVideoWatched,
              onChanged: (isTrue) => setState(() => settings.youtube.save(markVideoWatched: !isTrue)),
              title: 'mark_video_watched'.toUpperCase(),
            ),
            CustomListTile(
              icon: Broken.cpu,
              title: 'innertube_client'.toUpperCase(),
              trailing: NamidaPopupWrapper(
                  childrenDefault: () => [
                        NamidaPopupItem(
                          icon: Broken.video_horizontal,
                          title: lang.DEFAULT,
                          onTap: () {
                            setState(() => settings.youtube.save(setDefaultInnertubeClient: true));
                          },
                        ),
                        ...{
                          InnertubeClients.mweb,
                          InnertubeClients.web,
                          InnertubeClients.ios,
                          InnertubeClients.android,
                          InnertubeClients.tv,
                          InnertubeClients.tv_embedded,
                          InnertubeClients.web_embedded,
                          InnertubeClients.web_creator,
                          InnertubeClients.web_music,
                          InnertubeClients.web_safari,
                          InnertubeClients.ios_creator,
                          InnertubeClients.ios_music,
                          InnertubeClients.android_creator,
                          InnertubeClients.android_music,
                          InnertubeClients.android_producer,
                          InnertubeClients.android_testsuite,
                          InnertubeClients.android_vr,
                          InnertubeClients.mediaconnect,
                        }.map(
                          (e) => NamidaPopupItem(
                            icon: Broken.video_octagon,
                            title: e.name,
                            onTap: () {
                              setState(() => settings.youtube.save(innertubeClient: e));
                            },
                          ),
                        ),
                      ],
                  child: Text(settings.youtube.innertubeClient?.name ?? lang.DEFAULT)),
              onTap: () {},
            ),
            CustomSwitchListTile(
              icon: Broken.sun_1,
              value: settings.youtube.whiteVideoBGInLightMode,
              onChanged: (isTrue) => setState(() => settings.youtube.save(whiteVideoBGInLightMode: !isTrue)),
              title: 'white_video_bg_in_light_mode'.toUpperCase(),
            ),
            CustomSwitchListTile(
              leading: StackedIcon(
                baseIcon: Broken.sun_1,
                secondaryIcon: Broken.moon,
                secondaryIconSize: 12.0,
              ),
              value: settings.youtube.enableDimInLightMode,
              onChanged: (isTrue) => setState(() => settings.youtube.save(enableDimInLightMode: !isTrue)),
              title: 'enable_dim_in_light_mode'.toUpperCase(),
            ),
            CustomListTile(
              leading: StackedIcon(
                baseIcon: Broken.code_1,
                secondaryIcon: Broken.refresh,
                secondaryIconSize: 12.0,
              ),
              enabled: !didRefreshJsPlayer,
              title: 'refresh_js_player'.toUpperCase(),
              onTap: () {
                setState(() => didRefreshJsPlayer = true);
                YoutubeInfoController.video.forceRefreshJSPlayer();
              },
            ),
            CustomListTile(
              icon: Broken.hierarchy_square,
              title: 'copy_yt_history_to_local_history'.toUpperCase(),
              onTap: () {
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    isWarning: true,
                    normalTitleStyle: true,
                    bodyText: lang.CONFIRM,
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: lang.CONFIRM.toUpperCase(),
                        onPressed: () async {
                          await NamidaNavigator.inst.closeDialog(2);
                          final count = await JsonToHistoryParser.inst.copyYTHistoryContentToLocalHistory(matchAll: true);
                          snackyy(message: '${lang.ADDED.capitalizeFirst()}: ${count.displayTrackKeyword}');
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
    );
  }
}
