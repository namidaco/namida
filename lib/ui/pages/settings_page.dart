import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/advanced.dart';
import 'package:namida/ui/widgets/settings/backup_restore.dart';
import 'package:namida/ui/widgets/settings/customizations.dart';
import 'package:namida/ui/widgets/settings/extras.dart';
import 'package:namida/ui/widgets/settings/indexer.dart';
import 'package:namida/ui/widgets/settings/indexing_percentage.dart';
import 'package:namida/ui/widgets/settings/playback.dart';
import 'package:namida/ui/widgets/settings/theme_setting.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return MainPageWrapper(
      title: Text(Language.inst.SETTINGS),
      actions: const [],
      child: AnimatedContainer(
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
                    CurrentColor.inst.color.value.withAlpha(context.isDarkMode ? 0 : 25),
                    CurrentColor.inst.color.value.withAlpha(context.isDarkMode ? 55 : 110),
                  ],
                ),
              ),
            ),
            SettingsController.inst.useSettingCollapsedTiles.value
                ? const CollapsedSettingTiles()
                : ListView(
                    children: [
                      const ThemeSetting(),
                      IndexerSettings(),
                      const PlaybackSettings(),
                      CustomizationSettings(),
                      const ExtrasSettings(),
                      const BackupAndRestore(),
                      AdvancedSettings(),
                      kBottomPaddingWidget,
                    ],
                  ),
          ],
        ),
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
    return MainPageWrapper(
      title: Text(title),
      actions: const [],
      child: AnimatedContainer(
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
                    CurrentColor.inst.color.value.withAlpha(context.isDarkMode ? 0 : 25),
                    CurrentColor.inst.color.value.withAlpha(context.isDarkMode ? 55 : 110),
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
        ),
      ),
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
          page: IndexerSettings(),
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
          page: CustomizationSettings(),
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
        ),
        CustomCollapsedListTile(
          title: Language.inst.ADVANCED_SETTINGS,
          subtitle: Language.inst.ADVANCED_SETTINGS_SUBTITLE,
          icon: Broken.hierarchy_3,
          page: AdvancedSettings(),
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
      onTap: () => Get.to(
        () => SettingsSubPage(
          title: title,
          child: page,
        ),
      ),
    );
  }
}
