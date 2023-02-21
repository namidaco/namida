import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/advanced.dart';
import 'package:namida/ui/widgets/settings/customizations.dart';
import 'package:namida/ui/widgets/settings/extras.dart';
import 'package:namida/ui/widgets/settings/indexer.dart';
import 'package:namida/ui/widgets/settings/stats.dart';
import 'package:namida/ui/widgets/settings/theme_setting.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(seconds: 4),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Broken.arrow_left_2),
            onPressed: () => Get.back(),
          ),
          title: Text(Language.inst.SETTINGS),
        ),
        body: Stack(
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
                      CustomizationSettings(),
                      const ExtrasSettings(),
                      AdvancedSettings(),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

class SettingsSubPage extends StatelessWidget {
  final Widget child;
  final String title;
  const SettingsSubPage({super.key, required this.child, required this.title});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(seconds: 4),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Broken.arrow_left_2),
            onPressed: () => Get.back(),
          ),
          title: Text(title),
        ),
        body: Stack(
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
            SingleChildScrollView(child: child)
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
          title: Language.inst.ADVANCED_SETTINGS,
          subtitle: Language.inst.ADVANCED_SETTINGS_SUBTITLE,
          icon: Broken.hierarchy_3,
          page: AdvancedSettings(),
        ),
        const CollapsedSettingTileWidget()
      ],
    );
  }
}

class CustomCollapsedListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget page;
  final IconData? icon;

  const CustomCollapsedListTile({super.key, required this.title, required this.subtitle, required this.page, this.icon});

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      largeTitle: true,
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: const Icon(
        Broken.arrow_right_3,
      ),
      onTap: () => Get.to(
        SettingsSubPage(
          title: title,
          child: page,
        ),
      ),
    );
  }
}
