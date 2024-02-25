import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/namida_channel.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/controller/wakelock_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/widgets/inner_drawer.dart';
import 'package:namida/youtube/widgets/yt_queue_chip.dart';

class NamidaNavigator {
  static NamidaNavigator get inst => _instance;
  static final NamidaNavigator _instance = NamidaNavigator._internal();
  NamidaNavigator._internal();

  final navKey = Get.nestedKey(1);

  final ytLocalSearchNavigatorKey = Get.nestedKey(9);

  final ytMiniplayerCommentsPageKey = Get.nestedKey(11);

  bool isytLocalSearchInFullPage = false;
  bool isInYTCommentsSubpage = false;
  bool isQueueSheetOpen = false;

  final RxList<NamidaRoute> currentWidgetStack = <NamidaRoute>[].obs;
  NamidaRoute? get currentRoute => currentWidgetStack.lastOrNull;
  int _currentDialogNumber = 0;
  int _currentMenusNumber = 0;

  final innerDrawerKey = GlobalKey<NamidaInnerDrawerState>();
  final ytQueueSheetKey = GlobalKey<YTMiniplayerQueueChipState>();
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
      await exitFullScreen();
    } else {
      await enterFullScreen(widget, setOrientations: setOrientations, onWillPop: onWillPop);
    }
  }

  Future<void> setDefaultSystemUI({List<SystemUiOverlay> overlays = SystemUiOverlay.values}) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: overlays);
  }

  void setDefaultSystemUIOverlayStyle({bool semiTransparent = false}) {
    SystemChrome.setSystemUIOverlayStyle(
      semiTransparent
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.black45,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: Colors.black45,
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            ),
    );
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
    WakelockController.inst.updateFullscreenStatus(true);

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

    setDefaultSystemUIOverlayStyle(semiTransparent: true);
    await Future.wait([
      if (setOrientations) _setOrientations(true),
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    ]);
  }

  Future<void> exitFullScreen() async {
    if (!_isInFullScreen) return;
    Get.until((route) => route.isFirst);

    setDefaultSystemUIOverlayStyle();
    await Future.wait([
      if (isInLanscape) _setOrientations(false),
      setDefaultSystemUI(),
    ]);

    _isInFullScreen = false;
    WakelockController.inst.updateFullscreenStatus(false);
  }

  Future<void> navigateTo(
    Widget page, {
    Transition transition = Transition.cupertino,
    int durationInMs = _defaultRouteAnimationDurMS,
  }) async {
    currentWidgetStack.add(page.toNamidaRoute());
    _hideEverything();

    currentRoute?.updateColorScheme();

    await Get.to(
      () => page,
      id: 1,
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
        child: TapDetector(
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
    Transition transition = Transition.cupertino,
    int durationInMs = _defaultRouteAnimationDurMS,
  }) async {
    currentWidgetStack.removeLast();
    currentWidgetStack.add(page.toNamidaRoute());
    _hideEverything();

    currentRoute?.updateColorScheme();

    await Get.off(
      () => page,
      id: 1,
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
    Transition transition = Transition.cupertino,
  }) async {
    currentWidgetStack.value = [page.toNamidaRoute()];
    _hideEverything();

    currentRoute?.updateColorScheme();

    await Get.offAll(
      () => page,
      id: 1,
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

    if (isQueueSheetOpen) {
      ytQueueSheetKey.currentState?.dismissSheet();
      isQueueSheetOpen = false;
      return;
    }
    if (isInYTCommentsSubpage) {
      ytMiniplayerCommentsPageKey?.currentState?.pop();
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
  await NamidaChannel.inst.showToast(
    message: message,
    seconds: seconds,
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
  int? maxLinesMessage,
}) {
  isError ??= title == lang.ERROR;
  final view = Get.context == null ? null : View.of(Get.context!);
  Get.showSnackbar(
    GetSnackBar(
      maxWidth: view == null ? null : view.physicalSize.shortestSide / view.devicePixelRatio,
      alignment: Alignment.centerLeft,
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
        maxLines: maxLinesMessage,
        overflow: TextOverflow.ellipsis,
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
