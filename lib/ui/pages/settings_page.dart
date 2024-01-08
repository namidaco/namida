import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/advanced_settings.dart';
import 'package:namida/ui/widgets/settings/backup_restore_settings.dart';
import 'package:namida/ui/widgets/settings/customization_settings.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings/indexer_settings.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/settings/playback_settings.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';
import 'package:namida/ui/widgets/settings/youtube_settings.dart';

LinearGradient _bgLinearGradient(BuildContext context) {
  final firstC = context.theme.appBarTheme.backgroundColor ?? CurrentColor.inst.color.withAlpha(context.isDarkMode ? 0 : 25);
  final secondC = CurrentColor.inst.color.withAlpha(context.isDarkMode ? 40 : 60);
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.2, 1.0],
    colors: [
      firstC,
      secondC,
    ],
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Stack(
        children: [
          Container(
            height: context.height,
            decoration: BoxDecoration(
              gradient: _bgLinearGradient(context),
            ),
          ),
          settings.useSettingCollapsedTiles.value
              ? const CollapsedSettingTiles()
              : ListView(
                  children: [
                    const ThemeSetting(),
                    const IndexerSettings(),
                    const PlaybackSettings(),
                    const CustomizationSettings(),
                    const YoutubeSettings(),
                    const ExtrasSettings(),
                    const BackupAndRestore(),
                    const AdvancedSettings(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: AboutPageTileWidget(),
                    ),
                    kBottomPaddingWidget,
                  ],
                ),
        ],
      ),
    );
  }
}

class SettingsSubPage extends StatelessWidget {
  final String title;
  final Widget child;
  const SettingsSubPage({super.key, required this.child, required this.title});
  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Stack(
        children: [
          Container(
            height: context.height,
            decoration: BoxDecoration(
              gradient: _bgLinearGradient(context),
            ),
          ),
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                child,
                kBottomPaddingWidget,
              ],
            ),
          )
        ],
      ),
    );
  }
}

class CollapsedSettingTiles extends StatelessWidget {
  const CollapsedSettingTiles({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        settings.selectedLanguage.value;
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          children: [
            CustomCollapsedListTile(
              title: lang.THEME_SETTINGS,
              subtitle: lang.THEME_SETTINGS_SUBTITLE,
              icon: Broken.brush_2,
              page: const ThemeSetting(),
            ),
            CustomCollapsedListTile(
              title: lang.INDEXER,
              subtitle: lang.INDEXER_SUBTITLE,
              icon: Broken.component,
              page: const IndexerSettings(),
              trailing: const IndexingPercentage(size: 32.0),
            ),
            CustomCollapsedListTile(
              title: lang.PLAYBACK_SETTING,
              subtitle: lang.PLAYBACK_SETTING_SUBTITLE,
              icon: Broken.play_cricle,
              page: const PlaybackSettings(),
            ),
            CustomCollapsedListTile(
              title: lang.CUSTOMIZATIONS,
              subtitle: lang.CUSTOMIZATIONS_SUBTITLE,
              icon: Broken.brush_1,
              page: const CustomizationSettings(),
            ),
            CustomCollapsedListTile(
              title: lang.YOUTUBE,
              subtitle: lang.YOUTUBE_SETTINGS_SUBTITLE,
              icon: Broken.video,
              page: const YoutubeSettings(),
            ),
            CustomCollapsedListTile(
              title: lang.EXTRAS,
              subtitle: lang.EXTRAS_SUBTITLE,
              icon: Broken.command_square,
              page: const ExtrasSettings(),
            ),
            CustomCollapsedListTile(
              title: lang.BACKUP_AND_RESTORE,
              subtitle: lang.BACKUP_AND_RESTORE_SUBTITLE,
              icon: Broken.refresh_circle,
              page: const BackupAndRestore(),
              trailing: const ParsingJsonPercentage(size: 32.0),
            ),
            CustomCollapsedListTile(
              title: lang.ADVANCED_SETTINGS,
              subtitle: lang.ADVANCED_SETTINGS_SUBTITLE,
              icon: Broken.hierarchy_3,
              page: const AdvancedSettings(),
            ),
            const AboutPageTileWidget(),
            const CollapsedSettingTileWidget(),
            kBottomPaddingWidget,
          ],
        );
      },
    );
  }
}

class CustomCollapsedListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget page;
  final IconData? icon;
  final Widget? trailing;
  final bool rawPage;

  const CustomCollapsedListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.page,
    this.icon,
    this.trailing,
    this.rawPage = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      largeTitle: true,
      title: title,
      subtitle: subtitle,
      icon: icon,
      visualDensity: const VisualDensity(horizontal: -1.5, vertical: -1.5),
      trailingRaw: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 8.0),
          if (trailing != null) ...[trailing!, const SizedBox(width: 8.0)],
          const Icon(
            Broken.arrow_right_3,
          ),
        ],
      ),
      onTap: () => NamidaNavigator.inst.navigateTo(
        rawPage
            ? page
            : SettingsSubPage(
                title: title,
                child: page,
              ),
      ),
    );
  }
}
