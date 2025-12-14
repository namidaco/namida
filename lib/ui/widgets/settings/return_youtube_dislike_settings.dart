import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/class/return_youtube_dislike.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

class ReturnYoutubeDislikeSettingsPage extends StatelessWidget with NamidaRouteWidget {
  const ReturnYoutubeDislikeSettingsPage({super.key});

  @override
  RouteType get route => RouteType.YOUTUBE_RETURN_YOUTUBE_DISLIKE_SUBPAGE;

  ReturnYoutubeDislikeSettings get _currentConfigValue => settings.youtube.ryd.value;
  RxBaseCore<ReturnYoutubeDislikeSettings> get _currentConfig => settings.youtube.ryd;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.RETURN_YOUTUBE_DISLIKE,
      subtitle: null,
      icon: Broken.dislike,
      child: Column(
        children: [
          Obx(
            (context) {
              final isEnabled = _currentConfig.valueR.enabled;
              return CustomSwitchListTile(
                icon: isEnabled ? Broken.dislike_filled : Broken.dislike,
                title: lang.ENABLE_RETURN_YOUTUBE_DISLIKE,
                value: isEnabled,
                onChanged: (isTrue) {
                  final newConfigs = _currentConfigValue.copyWith(enabled: !isTrue);
                  settings.youtube.save(ryd: newConfigs);

                  if (newConfigs.enabled) {
                    final currentItem = Player.inst.currentItem.value;
                    if (currentItem is YoutubeID) {
                      YoutubeInfoController.current.fetchAndUpdateDislikeCount(currentItem.id);
                      return;
                    }
                  }
                  YoutubeInfoController.current.clearCurrentDislikeCount();
                },
              );
            },
          ),
          CustomListTile(
            icon: Broken.info_circle,
            title: lang.ABOUT,
            subtitle:
                "${lang.DATA_IS_PROVIDED_BY_NAME.replaceFirst('_NAME_', _currentConfigValue.defaultWebsiteUrl.replaceFirst('https://', '').addDQuotation())}. ${lang.LEARN_MORE}",
            trailing: Icon(
              Broken.export_1,
              size: 18.0,
            ),
            onTap: () => NamidaLinkUtils.openLink(_currentConfigValue.defaultWebsiteUrl),
          ),
        ],
      ),
    );
  }
}
