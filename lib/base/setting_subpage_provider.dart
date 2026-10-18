import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

part 'setting_entries.dart';

abstract class SettingSubpageProvider extends StatelessWidget {
  SettingSubpageEnum get settingPage;
  final SettingEntry? initialItem;

  const SettingSubpageProvider({super.key, this.initialItem});

  List<List<SettingEntry>> get sections;

  /// shown outside [sections], ex: a button in the card header.
  List<SettingEntry> get headerEntries => const [];

  AppDocsLinks get docsLink => AppDocsLinks.getForSettingsPage(settingPage);

  Color? getBgColor(SettingEntry entry) {
    return entry == initialItem ? Colors.grey.withOpacityExt(0.31) : null;
  }

  bool isTargetWithin(SettingEntry entry) {
    final target = initialItem;
    if (target == null) return false;
    return entry == target || entry.containsDeep(target);
  }
}

class _SettingTargetHighlight extends StatefulWidget {
  final Widget child;

  const _SettingTargetHighlight({super.key, required this.child});

  @override
  State<_SettingTargetHighlight> createState() => _SettingTargetHighlightState();
}

class _SettingTargetHighlightState extends State<_SettingTargetHighlight> {
  bool _didFinish = false;

  Future<void> _onFadeComplete(AnimationController controller) async {
    if (_didFinish) return;
    _didFinish = true;

    Future<void> oneLap() async {
      await controller.animateTo(controller.upperBound);
      await controller.animateTo(controller.lowerBound);
    }

    await oneLap();
    await oneLap();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child:
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18.0.multipliedRadius),
                    color: Colors.grey.withOpacityExt(0.39),
                  ),
                ).animate(
                  autoPlay: true,
                  onComplete: _onFadeComplete,
                  effects: [
                    const FadeEffect(
                      duration: Duration(milliseconds: 200),
                      delay: Duration(milliseconds: 50),
                    ),
                  ],
                ),
          ),
        ),
      ],
    );
  }
}

/// [page] is null outside settings.
typedef SettingTileArgs = ({SettingEntry entry, SettingSubpageProvider? page, Color? bgColor});
