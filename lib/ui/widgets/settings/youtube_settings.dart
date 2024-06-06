import 'package:flutter/material.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';

enum _YoutubeSettingKeys {
  youtubeStyleMiniplayer,
  rememberAudioOnly,
  topComments,
  preferNewComments,
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
        _YoutubeSettingKeys.youtubeStyleMiniplayer: [lang.YOUTUBE_STYLE_MINIPLAYER],
        _YoutubeSettingKeys.rememberAudioOnly: [lang.REMEMBER_AUDIO_ONLY_MODE],
        _YoutubeSettingKeys.topComments: [lang.TOP_COMMENTS, lang.TOP_COMMENTS_SUBTITLE],
        _YoutubeSettingKeys.preferNewComments: [lang.YT_PREFER_NEW_COMMENTS, lang.YT_PREFER_NEW_COMMENTS_SUBTITLE],
        _YoutubeSettingKeys.dimMiniplayerAfter: [lang.DIM_MINIPLAYER_AFTER_SECONDS],
        _YoutubeSettingKeys.dimIntensity: [lang.DIM_INTENSITY],
        _YoutubeSettingKeys.seekbar: [lang.SEEKBAR, lang.TAP_TO_SEEK, lang.DRAG_TO_SEEK],
        _YoutubeSettingKeys.downloadsMetadataTags: [lang.DOWNLOADS_METADATA_TAGS, lang.DOWNLOADS_METADATA_TAGS_SUBTITLE],
        _YoutubeSettingKeys.downloadLocation: [lang.DEFAULT_DOWNLOAD_LOCATION],
        _YoutubeSettingKeys.onOpeningYTLink: [lang.ON_OPENING_YOUTUBE_LINK],
      };

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.YOUTUBE,
      subtitle: lang.YOUTUBE_SETTINGS_SUBTITLE,
      icon: Broken.video,
      child: Column(
        children: [
          getItemWrapper(
            key: _YoutubeSettingKeys.youtubeStyleMiniplayer,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.youtubeStyleMiniplayer),
                icon: Broken.video_octagon,
                title: lang.YOUTUBE_STYLE_MINIPLAYER,
                value: settings.youtubeStyleMiniplayer.valueR,
                onChanged: (isTrue) {
                  settings.save(youtubeStyleMiniplayer: !isTrue);
                  Player.inst.tryGenerateWaveform(Player.inst.currentVideo);
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.rememberAudioOnly,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.rememberAudioOnly),
                icon: Broken.musicnote,
                title: lang.REMEMBER_AUDIO_ONLY_MODE,
                value: settings.ytRememberAudioOnly.valueR,
                onChanged: (isTrue) => settings.save(ytRememberAudioOnly: !isTrue),
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.topComments,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.topComments),
                leading: const StackedIcon(
                  baseIcon: Broken.document,
                  secondaryIcon: Broken.arrow_circle_up,
                  secondaryIconSize: 12.0,
                ),
                title: lang.TOP_COMMENTS,
                subtitle: lang.TOP_COMMENTS_SUBTITLE,
                value: settings.ytTopComments.valueR,
                onChanged: (isTrue) {
                  settings.save(ytTopComments: !isTrue);
                  YoutubeController.inst.resetGlowUnderVideo();

                  // -- pop comments subpage in case was inside.
                  if (settings.ytTopComments.value == false) {
                    NamidaNavigator.inst.ytMiniplayerCommentsPageKey.currentState?.pop();
                    NamidaNavigator.inst.isInYTCommentsSubpage = false;
                  }
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.preferNewComments,
            child: Obx(
              () => CustomSwitchListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.preferNewComments),
                leading: const StackedIcon(
                  baseIcon: Broken.document,
                  secondaryIcon: Broken.global_refresh,
                  secondaryIconSize: 12.0,
                ),
                title: lang.YT_PREFER_NEW_COMMENTS,
                subtitle: lang.YT_PREFER_NEW_COMMENTS_SUBTITLE,
                value: settings.ytPreferNewComments.valueR,
                onChanged: (isTrue) => settings.save(ytPreferNewComments: !isTrue),
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.dimMiniplayerAfter,
            child: ObxO(
              rx: settings.ytMiniplayerDimAfterSeconds,
              builder: (ytMiniplayerDimAfterSeconds) => CustomListTile(
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
                    settings.save(ytMiniplayerDimAfterSeconds: val);
                  },
                ),
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.dimIntensity,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.dimIntensity),
                enabled: settings.ytMiniplayerDimAfterSeconds.valueR > 0,
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
                      () {
                        const multiplier = 4.5;
                        const minus = multiplier / 2;
                        const height = 7.0;
                        const origin = height / 2;
                        return Transform.rotate(
                          origin: const Offset(0, origin),
                          angle: (settings.ytMiniplayerDimOpacity.valueR * multiplier) - minus,
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
                trailing: NamidaWheelSlider(
                  totalCount: 100,
                  initValue: (settings.ytMiniplayerDimOpacity.valueR * 100).round(),
                  text: "${(settings.ytMiniplayerDimOpacity.valueR * 100).round()}%",
                  onValueChanged: (val) {
                    settings.save(ytMiniplayerDimOpacity: val / 100);
                  },
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
                              settings.save(ytTapToSeek: e);
                            },
                          ),
                        )
                        .toList(),
                    child: Obx(
                      () => Text(
                        settings.ytTapToSeek.valueR.toText(),
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
                              settings.save(ytDragToSeek: e);
                            },
                          ),
                        )
                        .toList(),
                    child: Obx(
                      () => Text(
                        settings.ytDragToSeek.valueR.toText(),
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
              () => CustomSwitchListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.downloadsMetadataTags),
                leading: const StackedIcon(
                  baseIcon: Broken.import,
                  secondaryIcon: Broken.tick_circle,
                  secondaryIconSize: 12.0,
                ),
                title: lang.DOWNLOADS_METADATA_TAGS,
                subtitle: lang.DOWNLOADS_METADATA_TAGS_SUBTITLE,
                value: settings.ytAutoExtractVideoTagsFromInfo.valueR,
                onChanged: (isTrue) => settings.save(ytAutoExtractVideoTagsFromInfo: !isTrue),
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.downloadLocation,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.downloadLocation),
                title: lang.DEFAULT_DOWNLOAD_LOCATION,
                icon: Broken.folder_favorite,
                subtitle: settings.ytDownloadLocation.valueR,
                onTap: () async {
                  final path = await NamidaFileBrowser.getDirectory(note: lang.DEFAULT_DOWNLOAD_LOCATION);
                  if (path != null) settings.save(ytDownloadLocation: path);
                },
              ),
            ),
          ),
          getItemWrapper(
            key: _YoutubeSettingKeys.onOpeningYTLink,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_YoutubeSettingKeys.onOpeningYTLink),
                icon: Broken.import_1,
                title: lang.ON_OPENING_YOUTUBE_LINK,
                trailingText: settings.onYoutubeLinkOpen.valueR.toText(),
                onTap: () {
                  NamidaNavigator.inst.navigateDialog(
                    dialog: CustomBlurryDialog(
                      title: lang.CHOOSE,
                      actions: [
                        NamidaButton(
                          text: lang.DONE,
                          onPressed: NamidaNavigator.inst.closeDialog,
                        )
                      ],
                      child: Column(
                        children: [
                          ...OnYoutubeLinkOpenAction.values.map(
                            (e) => Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: ObxO(
                                rx: settings.onYoutubeLinkOpen,
                                builder: (onYoutubeLinkOpen) => ListTileWithCheckMark(
                                  icon: e.toIcon(),
                                  title: e.toText(),
                                  active: onYoutubeLinkOpen == e,
                                  onTap: () {
                                    settings.save(onYoutubeLinkOpen: e);
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
