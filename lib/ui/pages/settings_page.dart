// ignore_for_file: prefer_const_constructors_in_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/container.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:get/get.dart';
import 'package:namida/controller/now_playing_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/homepage.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/advanced.dart';
import 'package:namida/ui/widgets/settings/customizations.dart';
import 'package:namida/ui/widgets/settings/extras.dart';
import 'package:namida/ui/widgets/settings/indexer.dart';
import 'package:namida/ui/widgets/settings/stats.dart';
import 'package:namida/ui/widgets/settings/theme_setting.dart';
import 'package:namida/ui/widgets/settings/track_tile_customization.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    // context.theme;
    return AnimatedContainer(
      duration: Duration(seconds: 4),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Broken.arrow_left_2),
            onPressed: () => Get.back(),
          ),
          title: Text(Language.inst.SETTINGS),
        ),
        body: Obx(
          () => AnimatingBackgroundModern(
            currentColor: CurrentColor.inst.color.value,
            currentColorsList: [Colors.red, Colors.black],
            child: ListView(
              children: [
                ThemeSetting(),
                ExtrasSettings(),
                IndexerSettings(),
                Stats(),
                CustomizationSettings(),
                AdvancedSettings(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
