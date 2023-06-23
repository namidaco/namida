import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/packages/inner_drawer.dart';

class NamidaNavigator {
  static NamidaNavigator get inst => _instance;
  static final NamidaNavigator _instance = NamidaNavigator._internal();
  NamidaNavigator._internal();

  final navKey = Get.nestedKey(1);

  final RxList<Widget> currentWidgetStack = <Widget>[].obs;
  int currentDialogNumber = 0;

  final GlobalKey<InnerDrawerState> innerDrawerKey = GlobalKey<InnerDrawerState>();
  final heroController = HeroController();

  void toggleDrawer() {
    innerDrawerKey.currentState?.toggle();
  }

  void _hideSearchMenuAndUnfocus() => ScrollSearchController.inst.hideSearchMenu();

  Widget _getNewPageWidget(Widget child) => Material(child: child);

  Future<void> navigateTo(
    Widget page, {
    bool nested = true,
    bool shouldGetOffAll = false,
    Transition transition = Transition.cupertino,
  }) async {
    _hideSearchMenuAndUnfocus();

    page.updateColorScheme();

    closeAllDialogs();

    if (shouldGetOffAll) {
      await navigateOffAll(page, nested: nested, transition: transition);
    } else {
      currentWidgetStack.add(page);
      await Get.to(
        () => _getNewPageWidget(page),
        id: nested ? 1 : null,
        preventDuplicates: false,
        transition: transition,
        curve: Curves.easeOut,
        duration: const Duration(milliseconds: 500),
        opaque: true,
        fullscreenDialog: false,
      );
    }
  }

  void navigateDialog(Widget dialog, {int durationInMs = 400, Future<bool> Function()? onWillPop}) {
    ScrollSearchController.inst.unfocusKeyboard();
    currentDialogNumber++;
    Get.to(
      () => WillPopScope(
        onWillPop: () async {
          if (currentDialogNumber > 0) {
            closeDialog();
            if (onWillPop != null) await onWillPop();
            return false;
          }

          return true;
        },
        child: dialog,
      ),
      preventDuplicates: false,
      transition: Transition.fade,
      duration: Duration(milliseconds: durationInMs),
      opaque: false,
      fullscreenDialog: true,
    );
    debugPrint("Current Dialogs: $currentDialogNumber");
  }

  Future<void> closeDialog([int count = 1]) async {
    if (currentDialogNumber == 0) return;
    final closeCount = count.withMaximum(currentDialogNumber);
    currentDialogNumber -= closeCount;
    Get.close(closeCount);
    debugPrint("Current Dialogs: $currentDialogNumber");
  }

  Future<void> closeAllDialogs() async {
    closeDialog(currentDialogNumber);
    debugPrint("Current Dialogs: $currentDialogNumber");
  }

  Future<void> navigateOff(
    Widget page, {
    bool nested = true,
    Transition transition = Transition.cupertino,
  }) async {
    _hideSearchMenuAndUnfocus();

    currentWidgetStack.removeLast();
    currentWidgetStack.add(page);

    page.updateColorScheme();

    await Get.off(
      () => _getNewPageWidget(page),
      id: nested ? 1 : null,
      preventDuplicates: false,
      transition: transition,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 500),
      opaque: true,
      fullscreenDialog: false,
    );
  }

  Future<void> navigateOffAll(
    Widget page, {
    bool nested = true,
    Transition transition = Transition.cupertino,
  }) async {
    _hideSearchMenuAndUnfocus();

    currentWidgetStack
      ..clear()
      ..add(page);

    page.updateColorScheme();

    await Get.offAll(
      () => _getNewPageWidget(page),
      id: nested ? 1 : null,
      transition: transition,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> popPage() async {
    if (innerDrawerKey.currentState?.isOpened ?? false) {
      innerDrawerKey.currentState?.close();
      return;
    }

    // try popping, if at the root route, show _doubleTapToExit().
    final didPop = await navKey?.currentState?.maybePop() ?? false;
    if (!didPop) await _doubleTapToExit();

    if (currentWidgetStack.length > 1) {
      currentWidgetStack.removeLast();
    }
    currentWidgetStack.lastOrNull?.updateColorScheme();
    _hideSearchMenuAndUnfocus();
  }

  DateTime _currentBackPressTime = DateTime(0);
  Future<bool> _doubleTapToExit() async {
    final now = DateTime.now();
    if (now.difference(_currentBackPressTime) > const Duration(seconds: 3)) {
      _currentBackPressTime = now;
      Get.snackbar(
        Language.inst.EXIT_APP,
        Language.inst.EXIT_APP_SUBTITLE,
        icon: const Icon(Broken.logout),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        animationDuration: const Duration(milliseconds: 500),
        forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
        reverseAnimationCurve: Curves.easeInOutQuart,
        duration: const Duration(seconds: 3),
      );
      return false;
    }
    SystemNavigator.pop();
    return true;
  }
}
