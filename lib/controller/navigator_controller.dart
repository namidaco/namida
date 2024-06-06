import 'dart:async';

import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
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
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/inner_drawer.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/widgets/yt_queue_chip.dart';

class NamidaNavigator {
  static NamidaNavigator get inst => _instance;
  static final NamidaNavigator _instance = NamidaNavigator._internal();
  NamidaNavigator._internal();

  GlobalKey<NavigatorState> get _rootNav => namida.rootNavigatorKey;

  final navKey = GlobalKey<NavigatorState>();

  final ytLocalSearchNavigatorKey = GlobalKey<NavigatorState>();

  final ytMiniplayerCommentsPageKey = GlobalKey<NavigatorState>();

  bool isytLocalSearchInFullPage = false;
  bool isInYTCommentsSubpage = false;
  bool isQueueSheetOpen = false;

  final currentWidgetStack = <NamidaRoute>[].obs;
  NamidaRoute? get currentRoute => currentWidgetStack.value.lastOrNull;
  // ignore: avoid_rx_value_getter_outside_obx
  NamidaRoute? get currentRouteR => currentWidgetStack.valueR.lastOrNull;
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

  Future<T?> showMenu<T>({
    required BuildContext context,
    required RelativeRect position,
    required List<PopupMenuEntry<T>> items,
  }) async {
    _currentMenusNumber++;
    _printMenus();
    return material.showMenu(
      useRootNavigator: true,
      context: context,
      position: position,
      items: items,
    );
  }

  void popMenu({bool handleClosing = true}) {
    if (_currentMenusNumber > 0) {
      _currentMenusNumber--;
      if (handleClosing) {
        _rootNav.currentState?.pop();
      }
    }
    _printMenus();
  }

  void popAllMenus() {
    _rootNav.currentState?.popUntil((route) => true);
    _currentMenusNumber = 0;
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
    final finalTab = isSearchTab ? settings.libraryTabs.value.first : initialTab;
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

  bool? _latestIsAppLight;

  /// optimized to set only if its different from the previous value.
  void setSystemUIOverlayStyleCustom(bool isAppLight) {
    if (_latestIsAppLight == isAppLight) return;
    _latestIsAppLight = isAppLight;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarColor: const Color(0x00000000),
        systemNavigationBarDividerColor: const Color(0x00000000),
        systemNavigationBarIconBrightness: isAppLight ? Brightness.dark : Brightness.light,
      ),
    );
  }

  Future<void> setDeviceOrientations(bool lanscape) async {
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

    _rootNav.currentState?.pushPage(
      WillPopScope(
        onWillPop: () async {
          if (onWillPop != null) await onWillPop();
          exitFullScreen();
          return false;
        },
        child: widget,
      ),
      transition: Transition.noTransition,
      durationInMs: 0,
      maintainState: true,
    );

    setDefaultSystemUIOverlayStyle(semiTransparent: true);
    await Future.wait([
      if (setOrientations) setDeviceOrientations(true),
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    ]);
  }

  Future<void> exitFullScreen() async {
    if (!_isInFullScreen) return;
    _rootNav.currentState?.pop();

    setDefaultSystemUIOverlayStyle();
    await Future.wait([
      if (isInLanscape) setDeviceOrientations(false),
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
    final newRoute = page.toNamidaRoute();
    currentWidgetStack.add(newRoute);
    _hideEverything();

    newRoute.updateColorScheme();

    await navKey.currentState?.pushPage(
      page,
      durationInMs: durationInMs,
      transition: transition,
      maintainState: true,
    );
  }

  Future<T?> navigateToRoot<T>(
    Widget page, {
    Transition transition = Transition.cupertino,
    int durationInMs = _defaultRouteAnimationDurMS,
  }) async {
    return await _rootNav.currentState?.pushPage(
      page,
      durationInMs: durationInMs,
      transition: transition,
      maintainState: true,
    );
  }

  Future<void> popRoot<T>([T? result]) async {
    return _rootNav.currentState?.pop<T>(result);
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

    await _rootNav.currentState?.pushPage(
      WillPopScope(
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
      durationInMs: durationInMs,
      opaque: false,
      fullscreenDialog: true,
      transition: Transition.fade,
      maintainState: true,
    );
    if (onDisposing != null) {
      onDisposing.executeAfterDelay(durationMS: durationInMs * 2);
    }
    _printDialogs();
  }

  Future<void> closeDialog([int count = 1]) async {
    if (_currentDialogNumber == 0) return;
    int closeCount = count.withMaximum(_currentDialogNumber);
    while (closeCount > 0) {
      _currentDialogNumber--;
      _rootNav.currentState?.pop();
      closeCount--;
    }
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
    final newRoute = page.toNamidaRoute();
    currentWidgetStack.execute(
      (value) {
        value.removeLast();
        value.add(newRoute);
      },
    );

    _hideEverything();

    newRoute.updateColorScheme();

    await navKey.currentState?.pushPageReplacement(
      page,
      durationInMs: durationInMs,
      transition: transition,
      maintainState: true,
    );
  }

  Future<void> navigateOffAll(
    Widget page, {
    Transition transition = Transition.cupertino,
  }) async {
    final newRoute = page.toNamidaRoute();
    currentWidgetStack.value = [page.toNamidaRoute()];
    _hideEverything();

    newRoute.updateColorScheme();

    navKey.currentState?.popUntil((r) => r.isFirst);

    await navKey.currentState?.pushPageReplacement(
      page,
      durationInMs: 500,
      transition: transition,
      maintainState: true,
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
      ytMiniplayerCommentsPageKey.currentState?.pop();
      isInYTCommentsSubpage = false;
      return;
    }

    if (MiniPlayerController.inst.ytMiniplayerKey.currentState?.isExpanded == true) {
      MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(false);
      return;
    }

    final miniplayerAllowPop = MiniPlayerController.inst.onWillPop();
    if (!miniplayerAllowPop) return;

    final ytsnvks = ytLocalSearchNavigatorKey.currentState;
    if (ytsnvks != null) {
      ytsnvks.pop();
      isytLocalSearchInFullPage = false;
      return;
    }

    if (ScrollSearchController.inst.isGlobalSearchMenuShown.value) {
      _hideSearchMenuAndUnfocus();
      return;
    }
    if (SettingsSearchController.inst.canShowSearch.value) {
      SettingsSearchController.inst.closeSearch();
      return;
    }

    final route = currentRoute?.route;
    if (route != null) {
      if (route == RouteType.PAGE_folders) {
        final canIgoBackPls = Folders.inst.onBackButton();
        if (!canIgoBackPls) return;
      } else if (route == RouteType.SUBPAGE_playlistTracks) {
        PlaylistController.inst.resetCanReorder();
      } else if (route == RouteType.YOUTUBE_PLAYLIST_SUBPAGE) {
        YoutubePlaylistController.inst.resetCanReorder();
      }
    }

    if (_currentMenusNumber > 0) {
      return;
    }

    // pop only if not in root, otherwise show _doubleTapToExit().
    if (currentWidgetStack.length > 1) {
      currentWidgetStack.removeLast();
      navKey.currentState?.pop();
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
        margin: const EdgeInsets.all(12.0),
        animationDurationMS: 500,
        onStatusChanged: (status) {
          // -- resets time
          if (status == SnackbarStatus.closing || status == SnackbarStatus.closed) {
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

SnackbarController? snackyy({
  IconData? icon,
  String title = '',
  required String message,
  bool top = true,
  void Function(SnackbarStatus status)? onStatusChanged,
  EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
  int animationDurationMS = 600,
  int displaySeconds = 2,
  double borderRadius = 12.0,
  Color? leftBarIndicatorColor,
  (String text, FutureOr<void> Function() function)? button,
  bool? isError,
  int? maxLinesMessage,
}) {
  isError ??= title == lang.ERROR;
  final context = namida.context;
  final view = context?.view ?? namida.platformView;
  final backgroundColor = context?.theme.scaffoldBackgroundColor.withOpacity(0.3) ?? Colors.black54;
  final itemsColor = context?.theme.colorScheme.onSurface.withOpacity(0.7) ?? Colors.white54;

  TextStyle getTextStyle(FontWeight fontWeight, double size, {bool action = false}) => TextStyle(
        fontWeight: fontWeight,
        fontSize: size,
        color: action ? null : itemsColor,
        fontFamily: "LexendDeca",
        fontFamilyFallback: const ['sans-serif', 'Roboto'],
      );

  final borderR = borderRadius == 0 ? null : BorderRadius.circular(borderRadius.multipliedRadius);
  SnackbarController? snackbarController;

  final EdgeInsets paddingInsets;
  if (button != null) {
    paddingInsets = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0);
  } else if (icon != null || title != '') {
    paddingInsets = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  } else {
    paddingInsets = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0);
  }

  bool alreadyTappedButton = false;

  final content = Padding(
    padding: paddingInsets,
    child: SizedBox(
      width: view == null ? null : view.physicalSize.shortestSide / view.devicePixelRatio,
      child: Row(
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(icon, color: itemsColor),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != '')
                  Text(
                    title,
                    style: getTextStyle(FontWeight.w700, 16),
                  ),
                Text(
                  message,
                  style: title != '' ? getTextStyle(FontWeight.w400, 13.0) : getTextStyle(FontWeight.w600, 14.0),
                  maxLines: maxLinesMessage,
                  overflow: maxLinesMessage == null ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (button != null)
            TextButton(
              style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () {
                if (alreadyTappedButton) return;
                alreadyTappedButton = true;
                button.$2();
                snackbarController?.close();
              },
              child: NamidaButtonText(
                button.$1,
                style: getTextStyle(FontWeight.bold, 14.0, action: true),
              ),
            ),
        ],
      ),
    ),
  );
  final snackbar = NamSnackBar(
    margin: margin,
    duration: Duration(seconds: displaySeconds),
    animationDuration: Duration(milliseconds: animationDurationMS),
    alignment: Alignment.centerLeft,
    top: top,
    forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
    reverseAnimationCurve: Curves.easeInOutQuart,
    onStatusChanged: onStatusChanged,
    child: Material(
      color: Colors.transparent,
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: borderR ?? BorderRadius.zero,
        child: NamidaBgBlur(
          blur: 12.0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderR,
              border: isError ? Border.all(color: Colors.red.withOpacity(0.2), width: 1.5) : Border.all(color: Colors.grey.withOpacity(0.5), width: 0.5),
              boxShadow: isError
                  ? [
                      BoxShadow(
                        color: Colors.red.withAlpha(15),
                        blurRadius: 16.0,
                      )
                    ]
                  : null,
            ),
            child: leftBarIndicatorColor != null
                ? DecoratedBox(
                    decoration: BoxDecoration(border: Border(left: BorderSide(color: leftBarIndicatorColor, width: 4.5))),
                    child: content,
                  )
                : content,
          ),
        ),
      ),
    ),
  );

  snackbarController = SnackbarController(snackbar);
  snackbarController.show();
  return snackbarController;
}
