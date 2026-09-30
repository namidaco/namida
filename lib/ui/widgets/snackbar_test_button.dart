// by claude

import 'package:flutter/material.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class SnackbarTestAppBarIcon extends StatelessWidget {
  const SnackbarTestAppBarIcon({super.key});

  static const _kMergedAddsCount = 3;
  static const _kMergedAddsInterval = Duration(milliseconds: 1200);
  static const _kStackCount = 3;
  static const _kStackInterval = Duration(milliseconds: 400);

  static const _testButton = SnackbarButton(
    text: 'Action',
    function: _onTestButtonTap,
  );

  static void _onTestButtonTap() {}

  static void _showMergedAdd() {
    snackyy(
      icon: Broken.add_circle,
      message: 'Added 1 item',
      displayDuration: SnackDisplayDuration.veryLong,
      button: _testButton,
      merge: SnackbarMerge(
        group: SnackbarMergeGroup.queueAddTracks,
        id: 'snackbar_test',
        count: 1,
        toMessage: (total) => 'Added $total items',
      ),
    );
  }

  static void _showStacked(int number) {
    snackyy(
      icon: Broken.layer,
      message: 'Stacked $number/$_kStackCount',
      displayDuration: SnackDisplayDuration.long,
      button: _testButton,
    );
  }

  void _openMenu(BuildContext context) {
    final isReducedAnimations = settings.extra.reduceAnimations.value == true;
    NamidaPopupWrapper(
      childrenDefault: () => [
        NamidaPopupItem(
          icon: Broken.info_circle,
          title: 'Info only',
          subtitle: 'no countdown',
          onTap: () => snackyy(
            icon: Broken.info_circle,
            message: 'Info only, nothing to act on',
          ),
        ),
        NamidaPopupItem(
          icon: Broken.timer_1,
          title: 'With action',
          subtitle: 'countdown, pauses on hover/press',
          onTap: () => snackyy(
            icon: Broken.timer_1,
            message: 'Hover or hold to pause the countdown',
            displayDuration: SnackDisplayDuration.veryLong,
            button: _testButton,
          ),
        ),
        NamidaPopupItem(
          icon: Broken.flash_1,
          title: 'With action, short',
          subtitle: 'no countdown',
          onTap: () => snackyy(
            icon: Broken.flash_1,
            message: 'Short snackbar with action',
            displayDuration: SnackDisplayDuration.mediumLow,
            button: _testButton,
          ),
        ),
        NamidaPopupItem(
          icon: Broken.danger,
          title: 'Error with action',
          subtitle: 'neutral countdown color',
          onTap: () => snackyy(
            title: lang.error,
            message: 'Something failed',
            isError: true,
            displayDuration: SnackDisplayDuration.veryLong,
            button: _testButton,
          ),
        ),
        NamidaPopupItem(
          icon: Broken.colors_square,
          title: 'Bar indicator',
          subtitle: 'countdown takes indicator color',
          onTap: () => snackyy(
            icon: Broken.colors_square,
            message: 'Colored left bar',
            displayDuration: SnackDisplayDuration.veryLong,
            leftBarIndicatorColor: Colors.green,
            button: _testButton,
          ),
        ),
        NamidaPopupItem(
          icon: Broken.undo,
          title: 'Icon action',
          onTap: () => snackyy(
            icon: Broken.undo,
            message: 'Action shown as icon',
            displayDuration: SnackDisplayDuration.veryLong,
            button: const SnackbarButton(
              text: 'Undo',
              icon: Broken.undo,
              function: _onTestButtonTap,
            ),
          ),
        ),
        NamidaPopupItem(
          icon: Broken.add_circle,
          title: 'Merged adds',
          subtitle: 'smooth refill on each add',
          onTap: () {
            _showMergedAdd();
            for (int i = 1; i < _kMergedAddsCount; i++) {
              Future.delayed(_kMergedAddsInterval * i, _showMergedAdd);
            }
          },
        ),
        NamidaPopupItem(
          icon: Broken.layer,
          title: 'Stacked',
          subtitle: 'older ones wait while covered',
          onTap: () {
            for (int i = 0; i < _kStackCount; i++) {
              final number = i + 1;
              Future.delayed(_kStackInterval * i, () => _showStacked(number));
            }
          },
        ),
        NamidaPopupItem(
          icon: Broken.arrow_square_down,
          title: 'Bottom',
          onTap: () => snackyy(
            icon: Broken.arrow_square_down,
            message: 'Bottom snackbar with action',
            top: false,
            displayDuration: SnackDisplayDuration.veryLong,
            button: _testButton,
          ),
        ),
        NamidaPopupItem(
          icon: Broken.magicpen,
          title: 'Reduce animations',
          subtitle: 'hides the countdown',
          selected: isReducedAnimations,
          hasDividerAbove: true,
          onTap: () => settings.extra.reduceAnimations.save(!isReducedAnimations),
        ),
      ],
    ).showPopupMenu(context);
  }

  @override
  Widget build(BuildContext context) {
    return NamidaAppBarIcon(
      icon: Broken.message_notif,
      tooltip: () => 'Snackbar tests',
      onPressed: () => _openMenu(context),
    );
  }
}
