import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/lifecycle_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/inner_drawer.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class NamidaNavigator {
  static NamidaNavigator get inst => _instance;
  static final NamidaNavigator _instance = NamidaNavigator._internal();
  NamidaNavigator._internal();

  final navKey = Get.nestedKey(1);

  final ytLocalSearchNavigatorKey = Get.nestedKey(9);

  final ytMiniplayerCommentsPageKey = Get.nestedKey(11);

  bool isytLocalSearchInFullPage = false;
  bool isInYTCommentsSubpage = false;

  final RxList<NamidaRoute> currentWidgetStack = <NamidaRoute>[].obs;
  NamidaRoute? get currentRoute => currentWidgetStack.lastOrNull;
  int _currentDialogNumber = 0;
  int _currentMenusNumber = 0;

  final GlobalKey<InnerDrawerState> innerDrawerKey = GlobalKey<InnerDrawerState>();
  final heroController = HeroController();

  bool _isInLanscape = false;
  bool get isInLanscape => _isInLanscape;
  set isInLanscape(bool val) {
    _isInLanscape = val;
    for (final fn in _onLandscapeEvents.values) {
      fn();
    }
  }

  static const _defaultRouteAnimationDurMS = 500;

  final _onLandscapeEvents = <String, FutureOr<void> Function()>{};

  void addOnLandScapeEvent(String key, FutureOr<void> Function() fn) {
    _onLandscapeEvents[key] = fn;
  }

  void removeOnLandScapeEvent(String key) {
    _onLandscapeEvents.remove(key);
  }

  Future<T?> showMenu<T>(Future? menuFunction) async {
    _currentMenusNumber++;
    _printMenus();
    return await menuFunction;
  }

  void popMenu({bool handleClosing = true}) {
    if (_currentMenusNumber > 0) {
      _currentMenusNumber--;
      if (handleClosing) {
        Get.close(1);
      }
    }
    _printMenus();
  }

  void popAllMenus() {
    if (_currentMenusNumber > 0) {
      Get.until((route) => route.isFirst);
      _currentMenusNumber = 0;
    }
    _printMenus();
  }

  void toggleDrawer() {
    innerDrawerKey.currentState?.toggle();
  }

  void _hideSearchMenuAndUnfocus() => ScrollSearchController.inst.hideSearchMenu();
  void _minimizeMiniplayer() {
    MiniPlayerController.inst.snapToMini();
    MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(false);
  }

  void hideStuff({
    bool searchMenuAndUnfocus = true,
    bool minimizeMiniplayers = true,
    bool closeDialogs = true,
  }) {
    if (searchMenuAndUnfocus) _hideSearchMenuAndUnfocus();
    if (minimizeMiniplayers) _minimizeMiniplayer();
    if (closeDialogs) closeAllDialogs();
  }

  void _hideEverything() {
    _hideSearchMenuAndUnfocus();
    _minimizeMiniplayer();
    closeAllDialogs();
  }

  void onFirstLoad() {
    final initialTab = settings.selectedLibraryTab.value;
    final isSearchTab = initialTab == LibraryTab.search;
    final finalTab = isSearchTab ? settings.libraryTabs.first : initialTab;
    navigateTo(finalTab.toWidget(), durationInMs: 0);
    Dimensions.inst.updateAllTileDimensions();
    if (isSearchTab) ScrollSearchController.inst.animatePageController(initialTab);
  }

  Future<void> toggleFullScreen(Widget widget, {bool setOrientations = true, Future<void> Function()? onWillPop}) async {
    if (_isInFullScreen) {
      await exitFullScreen(setOrientations: setOrientations);
    } else {
      await enterFullScreen(widget, setOrientations: setOrientations, onWillPop: onWillPop);
    }
  }

  Future<void> _setOrientations(bool lanscape) async {
    isInLanscape = lanscape;
    final orientations = lanscape ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : kDefaultOrientations;
    await SystemChrome.setPreferredOrientations(orientations);
  }

  bool get isInFullScreen => _isInFullScreen;
  bool _isInFullScreen = false;
  Future<void> enterFullScreen(Widget widget, {bool setOrientations = true, Future<void> Function()? onWillPop}) async {
    if (_isInFullScreen) return;

    _isInFullScreen = true;

    Get.to(
      () => WillPopScope(
        onWillPop: () async {
          if (onWillPop != null) await onWillPop();
          exitFullScreen();
          return false;
        },
        child: widget,
      ),
      id: null,
      preventDuplicates: true,
      transition: Transition.noTransition,
      curve: Curves.easeOut,
      duration: Duration.zero,
      opaque: true,
      fullscreenDialog: false,
    );

    await Future.wait([
      if (setOrientations) _setOrientations(true),
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    ]);
  }

  Future<void> exitFullScreen({bool setOrientations = true}) async {
    if (!_isInFullScreen) return;
    Get.until((route) => route.isFirst);

    await Future.wait([
      if (setOrientations) _setOrientations(false),
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values),
    ]);

    _isInFullScreen = false;
  }

  Future<void> navigateTo(
    Widget page, {
    bool nested = true,
    Transition transition = Transition.cupertino,
    int durationInMs = _defaultRouteAnimationDurMS,
  }) async {
    currentWidgetStack.add(page.toNamidaRoute());
    _hideEverything();

    currentRoute?.updateColorScheme();

    await Get.to(
      () => page,
      id: nested ? 1 : null,
      preventDuplicates: false,
      transition: transition,
      curve: Curves.easeOut,
      duration: Duration(milliseconds: durationInMs),
      opaque: true,
      fullscreenDialog: false,
    );
  }

  /// Use [dialogBuilder] in case you want to acess the theme generated by [colorScheme].
  Future<void> navigateDialog({
    final Widget? dialog,
    final Widget Function(ThemeData theme)? dialogBuilder,
    final int durationInMs = 300,
    final bool tapToDismiss = true,
    final FutureOr<void> Function()? onDismissing,
    final Color? colorScheme,
    final bool lighterDialogColor = true,
    final double scale = 0.96,
    final bool blackBg = false,
    final void Function()? onDisposing,
  }) async {
    final rootNav = navigator;
    if (rootNav == null) return;

    ScrollSearchController.inst.unfocusKeyboard();
    _currentDialogNumber++;

    Future<bool> onWillPop() async {
      if (!tapToDismiss) return false;
      if (onDismissing != null) await onDismissing();

      if (_currentDialogNumber > 0) {
        closeDialog();
        return false;
      }

      return true;
    }

    final theme = AppThemes.inst.getAppTheme(colorScheme, null, lighterDialogColor);

    await Get.to(
      () => WillPopScope(
        onWillPop: onWillPop,
        child: GestureDetector(
          onTap: onWillPop,
          child: NamidaBgBlur(
            blur: 5.0,
            enabled: _currentDialogNumber == 1,
            child: Container(
              color: Colors.black.withOpacity(blackBg ? 1.0 : 0.45),
              child: Transform.scale(
                scale: scale,
                child: Theme(
                  data: theme,
                  child: dialogBuilder == null ? dialog! : dialogBuilder(theme),
                ),
              ),
            ),
          ),
        ),
      ),
      duration: Duration(milliseconds: durationInMs),
      preventDuplicates: false,
      opaque: false,
      fullscreenDialog: true,
      transition: Transition.fade,
    );
    if (onDisposing != null) {
      onDisposing.executeAfterDelay(durationMS: durationInMs * 2);
    }
    _printDialogs();
  }

  Future<void> closeDialog([int count = 1]) async {
    if (_currentDialogNumber == 0) return;
    final closeCount = count.withMaximum(_currentDialogNumber);
    _currentDialogNumber -= closeCount;
    Get.close(closeCount);
    _printDialogs();
  }

  Future<void> closeAllDialogs() async {
    closeDialog(_currentDialogNumber);
    _printDialogs();
  }

  void _printDialogs() => printy("Current Dialogs: $_currentDialogNumber");
  void _printMenus() => printy("Current Menus: $_currentMenusNumber");

  Future<void> navigateOff(
    Widget page, {
    bool nested = true,
    Transition transition = Transition.cupertino,
    int durationInMs = _defaultRouteAnimationDurMS,
  }) async {
    currentWidgetStack.removeLast();
    currentWidgetStack.add(page.toNamidaRoute());
    _hideEverything();

    currentRoute?.updateColorScheme();

    await Get.off(
      () => page,
      id: nested ? 1 : null,
      preventDuplicates: false,
      transition: transition,
      curve: Curves.easeOut,
      duration: Duration(milliseconds: durationInMs),
      opaque: true,
      fullscreenDialog: false,
    );
  }

  Future<void> navigateOffAll(
    Widget page, {
    bool nested = true,
    Transition transition = Transition.cupertino,
  }) async {
    currentWidgetStack.value = [page.toNamidaRoute()];
    _hideEverything();

    currentRoute?.updateColorScheme();

    await Get.offAll(
      () => page,
      id: nested ? 1 : null,
      transition: transition,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> popPage({bool waitForAnimation = false}) async {
    if (innerDrawerKey.currentState?.isOpened ?? false) {
      innerDrawerKey.currentState?.close();
      return;
    }

    final ytmpcpks = ytMiniplayerCommentsPageKey?.currentState;
    if (isInYTCommentsSubpage && ytmpcpks != null) {
      ytmpcpks.pop();
      isInYTCommentsSubpage = false;
      return;
    }

    if (MiniPlayerController.inst.ytMiniplayerKey.currentState?.isExpanded == true) {
      MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(false);
      return;
    }

    final ytsnvks = ytLocalSearchNavigatorKey?.currentState;
    if (ytsnvks != null) {
      ytsnvks.pop();
      isytLocalSearchInFullPage = false;
      return;
    }

    if (ScrollSearchController.inst.isGlobalSearchMenuShown.value) {
      _hideSearchMenuAndUnfocus();
      return;
    }
    if (SettingsSearchController.inst.canShowSearch) {
      SettingsSearchController.inst.closeSearch();
      return;
    }

    if (currentRoute?.route == RouteType.PAGE_folders) {
      final canIgoBackPls = Folders.inst.onBackButton();
      if (!canIgoBackPls) return;
    }
    if (_currentMenusNumber > 0) {
      return;
    }

    // pop only if not in root, otherwise show _doubleTapToExit().
    if (currentWidgetStack.length > 1) {
      currentWidgetStack.removeLast();
      navKey?.currentState?.pop();
    } else {
      await _doubleTapToExit();
    }
    if (waitForAnimation) await Future.delayed(const Duration(milliseconds: _defaultRouteAnimationDurMS));
    currentRoute?.updateColorScheme();
    _hideSearchMenuAndUnfocus();
  }

  DateTime _currentBackPressTime = DateTime(0);
  Future<bool> _doubleTapToExit() async {
    final now = DateTime.now();
    if (now.difference(_currentBackPressTime) > const Duration(seconds: 2)) {
      _currentBackPressTime = now;

      snackyy(
        icon: Broken.logout,
        message: lang.EXIT_APP_SUBTITLE,
        top: false,
        margin: const EdgeInsets.all(8.0),
        animationDurationMS: 500,
        snackbarStatus: (status) {
          // -- resets time
          if (status == SnackbarStatus.CLOSED) {
            _currentBackPressTime = DateTime(0);
          }
        },
      );

      return false;
    }
    SystemNavigator.pop();
    return true;
  }
}

Future<void> showSystemToast({
  required String message,
  int seconds = 5,
}) async {
  LifeCycleController.inst.namidaChannel.invokeMethod(
    'showToast',
    {
      "text": message,
      "seconds": seconds,
    },
  );
}

void snackyy({
  IconData? icon,
  Widget? iconWidget,
  String title = '',
  required String message,
  bool top = true,
  void Function(SnackbarStatus?)? snackbarStatus,
  EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
  int animationDurationMS = 600,
  int displaySeconds = 2,
  double borderRadius = 12.0,
  Color? leftBarIndicatorColor,
  Widget? button,
  bool? isError,
}) {
  isError ??= title == lang.ERROR;
  Get.showSnackbar(
    GetSnackBar(
      icon: iconWidget ??
          (icon == null
              ? null
              : Center(
                  child: Icon(icon),
                )),
      titleText: title == ''
          ? null
          : Text(
              title,
              style: Get.textTheme.displayLarge,
            ),
      messageText: Text(
        message,
        style: title != '' ? Get.textTheme.displaySmall : Get.textTheme.displayMedium,
      ),
      mainButton: button,
      margin: margin,
      snackPosition: top ? SnackPosition.TOP : SnackPosition.BOTTOM,
      leftBarIndicatorColor: leftBarIndicatorColor,
      borderWidth: 1.5,
      borderColor: isError ? Colors.red.withOpacity(0.2) : null,
      boxShadows: isError
          ? [
              BoxShadow(
                color: Colors.red.withAlpha(15),
                blurRadius: 16.0,
              )
            ]
          : null,
      shouldIconPulse: false,
      backgroundColor: Get.theme.scaffoldBackgroundColor.withOpacity(0.3),
      borderRadius: borderRadius.multipliedRadius,
      barBlur: 12.0,
      animationDuration: Duration(milliseconds: animationDurationMS),
      forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
      reverseAnimationCurve: Curves.easeInOutQuart,
      duration: Duration(seconds: displaySeconds),
      snackbarStatus: snackbarStatus,
    ),
  );
}
