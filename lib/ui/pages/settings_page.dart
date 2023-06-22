import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/advanced_settings.dart';
import 'package:namida/ui/widgets/settings/backup_restore_settings.dart';
import 'package:namida/ui/widgets/settings/customization_settings.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings/indexer_settings.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/settings/playback_settings.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(seconds: 4),
      child: Stack(
        children: [
          Container(
            height: context.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.theme.appBarTheme.backgroundColor ?? CurrentColor.inst.color.value.withAlpha(context.isDarkMode ? 0 : 25),
                  CurrentColor.inst.color.value.withAlpha(context.isDarkMode ? 40 : 60),
                ],
              ),
            ),
          ),
          SettingsController.inst.useSettingCollapsedTiles.value
              ? const CollapsedSettingTiles()
              : ListView(
                  children: const [
                    ThemeSetting(),
                    IndexerSettings(),
                    PlaybackSettings(),
                    CustomizationSettings(),
                    ExtrasSettings(),
                    BackupAndRestore(),
                    AdvancedSettings(),
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
    return Stack(
      children: [
        Container(
          height: context.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.theme.appBarTheme.backgroundColor ?? CurrentColor.inst.color.value.withAlpha(context.isDarkMode ? 0 : 25),
                CurrentColor.inst.color.value.withAlpha(context.isDarkMode ? 40 : 60),
              ],
            ),
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
    );
  }
}

class CollapsedSettingTiles extends StatelessWidget {
  const CollapsedSettingTiles({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        CustomCollapsedListTile(
          title: Language.inst.THEME_SETTINGS,
          subtitle: Language.inst.THEME_SETTINGS_SUBTITLE,
          icon: Broken.brush_2,
          page: const ThemeSetting(),
        ),
        CustomCollapsedListTile(
          title: Language.inst.INDEXER,
          subtitle: Language.inst.INDEXER_SUBTITLE,
          icon: Broken.component,
          page: const IndexerSettings(),
          trailing: const IndexingPercentage(size: 32.0),
        ),
        CustomCollapsedListTile(
          title: Language.inst.PLAYBACK_SETTING,
          subtitle: Language.inst.PLAYBACK_SETTING_SUBTITLE,
          icon: Broken.play_cricle,
          page: const PlaybackSettings(),
        ),
        CustomCollapsedListTile(
          title: Language.inst.CUSTOMIZATIONS,
          subtitle: Language.inst.CUSTOMIZATIONS_SUBTITLE,
          icon: Broken.brush_1,
          page: const CustomizationSettings(),
        ),
        CustomCollapsedListTile(
          title: Language.inst.EXTRAS,
          subtitle: Language.inst.EXTRAS_SUBTITLE,
          icon: Broken.command_square,
          page: const ExtrasSettings(),
        ),
        CustomCollapsedListTile(
          title: Language.inst.BACKUP_AND_RESTORE,
          subtitle: Language.inst.BACKUP_AND_RESTORE_SUBTITLE,
          icon: Broken.refresh_circle,
          page: const BackupAndRestore(),
          trailing: const ParsingJsonPercentage(size: 32.0),
        ),
        CustomCollapsedListTile(
          title: Language.inst.ADVANCED_SETTINGS,
          subtitle: Language.inst.ADVANCED_SETTINGS_SUBTITLE,
          icon: Broken.hierarchy_3,
          page: const AdvancedSettings(),
        ),
        const CollapsedSettingTileWidget(),
        kBottomPaddingWidget,
      ],
    );
  }
}

class CustomCollapsedListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget page;
  final IconData? icon;
  final Widget? trailing;

  const CustomCollapsedListTile({super.key, required this.title, required this.subtitle, required this.page, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      largeTitle: true,
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: Row(
        children: [
          if (trailing != null) ...[trailing!, const SizedBox(width: 8.0)],
          const Icon(
            Broken.arrow_right_3,
          ),
        ],
      ),
      onTap: () => NamidaNavigator.inst.navigateTo(
        SettingsSubPage(
          title: title,
          child: page,
        ),
      ),
    );
  }
}
