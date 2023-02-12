import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
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
        body: Container(
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
          child: ListView(
            children: [
              const ThemeSetting(),
              const ExtrasSettings(),
              IndexerSettings(),
              const Stats(),
              CustomizationSettings(),
              AdvancedSettings(),
            ],
          ),
        ),
      ),
    );
  }
}
