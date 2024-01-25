import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

abstract class SettingSubpageProvider extends StatelessWidget {
  SettingSubpageEnum get settingPage;
  Map<Enum, List<String>> get lookupMap;
  final Enum? initialItem;

  const SettingSubpageProvider({super.key, this.initialItem});

  GlobalKey getSettingWidgetGlobalKey(Enum key) {
    return SettingsSearchController.inst.getSettingWidgetGlobalKey(settingPage, key);
  }

  Color? getBgColor(Enum key) {
    return key == initialItem ? Colors.grey.withAlpha(80) : null;
  }

  Widget getItemWrapper({required Enum key, required Widget child}) {
    return Stack(
      key: getSettingWidgetGlobalKey(key),
      children: [
        child,
        if (key == initialItem)
          () {
            bool finished = false;
            return Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18.0.multipliedRadius),
                    color: Colors.grey.withAlpha(100),
                  ),
                ).animate(
                  autoPlay: true,
                  onComplete: (controller) async {
                    if (!finished) {
                      finished = true;
                      Future<void> oneLap() async {
                        await controller.animateTo(controller.upperBound);
                        await controller.animateTo(controller.lowerBound);
                      }

                      await oneLap();
                      await oneLap();
                    }
                  },
                  effects: [
                    const FadeEffect(
                      duration: Duration(milliseconds: 200),
                      delay: Duration(milliseconds: 50),
                    ),
                  ],
                ),
              ),
            );
          }()
      ],
    );
  }
}
