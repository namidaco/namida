// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'package:namida/controller/window_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/inner_drawer.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/widgets/yt_queue_chip.dart';

class NamidaNavigator {
  static NamidaNavigator get inst => _instance;
  static final NamidaNavigator _instance = NamidaNavigator._internal();
  NamidaNavigator._internal();

  GlobalKey<NavigatorState> get _rootNav => namida.rootNavigatorKey;
  bool get rootNavHasOpenedPages => _rootNav.currentState?.canPop() == true;
  int get openedDialogsCount => _openedNumbersManager._currentDialogNumber;
  int get openedSheetsCount => _openedNumbersManager._currentSheetNumber;
  int get openedMenusCount => _openedNumbersManager._currentMenusNumber;

  bool get _shouldUpdateSubpagesColors => settings.autoColor.value;

  final navKey = GlobalKey<NavigatorState>();

  final ytLocalSearchNavigatorKey = GlobalKey<NavigatorState>();

  final ytMiniplayerCommentsPageKey = GlobalKey<NavigatorState>();

  bool isytLocalSearchInFullPage = false;
  bool isInYTCommentsSubpage = false;
  bool isInYTCommentRepliesSubpage = false;
  bool isQueueSheetOpen = false;

  final currentWidgetStack = <NamidaRoute>[].obs;
  NamidaRoute? get currentRoute => currentWidgetStack.value.lastOrNull;
  // ignore: avoid_rx_value_getter_outside_obx
  NamidaRoute? get currentRouteR => currentWidgetStack.valueR.lastOrNull;

  final _openedNumbersManager = _OpenedNumbersManager();

  final innerDrawerKey = GlobalKey<NamidaInnerDrawerState>();
  final ytQueueSheetKey = GlobalKey<YTMiniplayerQueueChipState>();
  final heroController = HeroController();

  bool _isInLanscape = false;
  bool get isInLanscape => _isInLanscape;

  static const _defaultRouteAnimationDurMS = 400;
  static const kDefaultDialogDurationMS = 300;

  Future<T?> showMenu<T>({required PopupRoute<T> route}) async {
    ScrollSearchController.inst.unfocusKeyboard();
    _openedNumbersManager.incrementMenus();

    return _rootNav.currentState?.push(route);
  }

  void popMenu({bool handleClosing = true}) {
    if (_openedNumbersManager._currentMenusNumber > 0) {
      _openedNumbersManager.decrementMenus();
      if (handleClosing) {
        popRoot();
      }
    }
  }

  void popAllMenus() {
    if (_openedNumbersManager._currentMenusNumber == 0) return;
    while (_openedNumbersManager._currentMenusNumber > 0) {
      _openedNumbersManager.decrementMenus();
      popRoot();
    }
  }

  void toggleDrawer() {
    innerDrawerKey.currentState?.toggle();
  }

  /// hides library search and settings search pages
  void _hideSearchMenusAndUnfocus() {
    ScrollSearchController.inst.hideSearchMenu();
    SettingsSearchController.inst.closeSearch();
  }

  void _minimizeMiniplayer() {
    try {
      MiniPlayerController.inst.snapToMini();
      MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(false);
    } catch (_) {
      // -- could be non initialized
    }
  }

  void hideStuff({
    bool searchMenuAndUnfocus = true,
    bool minimizeMiniplayers = true,
    bool closeDialogs = true,
  }) {
    if (searchMenuAndUnfocus) _hideSearchMenusAndUnfocus();
    if (minimizeMiniplayers) _minimizeMiniplayer();
    if (closeDialogs) closeAllDialogs();
  }

  void _hideEverything() {
    _hideSearchMenusAndUnfocus();
    _minimizeMiniplayer();
    closeAllDialogs();
  }

  void onFirstLoad() {
    Dimensions.inst.updateAllTileDimensions();

    final initialTab = settings.extra.selectedLibraryTab.value;
    final isSearchTab = initialTab == LibraryTab.search;
    final finalTab = isSearchTab ? settings.libraryTabs.value.first : initialTab;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigateTo(finalTab.toWidget(), durationInMs: 0);
      if (isSearchTab) ScrollSearchController.inst.animatePageController(initialTab);
    });
  }

  Future<void> toggleFullScreen(Widget widget, {bool setOrientations = true, Future<void> Function()? onWillPop}) async {
    if (_isInFullScreen) {
      return await exitFullScreen();
    } else {
      return await enterFullScreen(widget, setOrientations: setOrientations, onWillPop: onWillPop);
    }
  }

  /// Raw access to system UI mode. For more accurate results, use [MiniPlayerController.setImmersiveMode].
  static Future<void> setSystemUIImmersiveMode(bool immersive, {List<SystemUiOverlay> overlays = SystemUiOverlay.values}) {
    final mode = immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge;
    return SystemChrome.setEnabledSystemUIMode(mode, overlays: overlays);
  }

  static void setDefaultSystemUIOverlayStyle({bool semiTransparent = false}) {
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
              systemNavigationBarDividerColor: Colors.transparent,
            ),
    );
  }

  bool? _latestIsAppLight;

  /// optimized to set only if its different from the previous value.
  void setSystemUIOverlayStyleCustom(bool isAppLight, {bool forceRefresh = false}) {
    if (_latestIsAppLight == isAppLight && !forceRefresh) return;
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
    _isInLanscape = lanscape;
    final orientations = lanscape ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : DeviceOrientation.values;
    await SystemChrome.setPreferredOrientations(orientations);
  }

  bool get isInFullScreen => _isInFullScreen;
  bool _isInFullScreen = false;
  Future<void> enterFullScreen(Widget widget, {bool setOrientations = true, Future<void> Function()? onWillPop}) async {
    if (_isInFullScreen == true) return;
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
      setSystemUIImmersiveMode(true),
    ]);
  }

  Future<void> exitFullScreen() async {
    if (_isInFullScreen == false) return;
    _isInFullScreen = false;

    await popRoot();

    setDefaultSystemUIOverlayStyle();
    await setDeviceOrientations(false);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async => await MiniPlayerController.inst.setImmersiveMode(null), // let mp decides
    );

    WakelockController.inst.updateFullscreenStatus(false);
  }

  Future<void> navigateTo<W extends NamidaRouteWidget>(
    W page, {
    Transition transition = Transition.cupertino,
    int durationInMs = _defaultRouteAnimationDurMS,
  }) async {
    _hideEverything();
    if (currentRoute != null && page.isSameRouteAs(currentRoute!)) return;
    currentWidgetStack.add(page);

    if (_shouldUpdateSubpagesColors) page.updateColorScheme();

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
    bool opaque = true,
  }) async {
    return await _rootNav.currentState?.pushPage(
      page,
      durationInMs: durationInMs,
      transition: transition,
      maintainState: true,
      opaque: opaque,
    );
  }

  Future<T?> navigateToRootReplacement<T>(
    Widget page, {
    Transition transition = Transition.cupertino,
    int durationInMs = _defaultRouteAnimationDurMS,
    bool opaque = true,
  }) async {
    currentWidgetStack.value = [];
    _hideEverything();

    return await _rootNav.currentState?.pushPageReplacement(
      page,
      durationInMs: durationInMs,
      transition: transition,
      maintainState: true,
      opaque: opaque,
    );
  }

  Future<void> popRoot<T>([T? result]) async {
    final state = _rootNav.currentState;
    if (state == null) return;
    if (!state.canPop()) return;
    return state.pop<T>(result);
  }

  /// Use [dialogBuilder] in case you want to acess the theme generated by [colorScheme].
  Future<T?> navigateDialog<T>({
    final Widget? dialog,
    final Widget Function(ThemeData theme)? dialogBuilder,
    final int durationInMs = NamidaNavigator.kDefaultDialogDurationMS,
    final bool Function()? tapToDismiss,
    final FutureOr<void> Function()? onDismissing,
    final Color? colorScheme,
    ThemeData? theme,
    final bool lighterDialogColor = true,
    final double scale = 0.96,
    final bool blackBg = false,
    final void Function()? onDisposing,
  }) async {
    ScrollSearchController.inst.unfocusKeyboard();
    _openedNumbersManager.incrementDialogs();

    Future<bool> onWillPop() async {
      if (tapToDismiss != null && tapToDismiss() == false) return false;

      if (_openedNumbersManager._currentDialogNumber > 0) {
        closeDialog();
        if (onDismissing != null) await onDismissing(); // this can open new dialog, so we closeDialog() first.
        return false;
      }

      return true;
    }

    theme ??= AppThemes.inst.getAppTheme(colorScheme, null, lighterDialogColor);

    final res = await _rootNav.currentState?.pushPage<T>(
      WillPopScope(
        onWillPop: onWillPop,
        child: material.RepaintBoundary(
          child: NamidaBgBlur(
            blur: 5.0,
            enabled: _openedNumbersManager._currentDialogNumber == 1,
            child: TapDetector(
              onTap: onWillPop,
              child: Container(
                color: Colors.black.withValues(alpha: blackBg ? 1.0 : 0.45),
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

    return res;
  }

  Future<void> closeDialog([int count = 1]) async {
    if (_openedNumbersManager._currentDialogNumber == 0) return;
    int closeCount = count.withMaximum(_openedNumbersManager._currentDialogNumber);
    while (closeCount > 0) {
      _openedNumbersManager.decrementDialogs();
      popRoot();
      closeCount--;
    }
  }

  Future<void> closeAllDialogs() async {
    if (_openedNumbersManager._currentDialogNumber == 0) return;
    closeDialog(_openedNumbersManager._currentDialogNumber);
  }

  Future<T?> showSheet<T>({
    required Widget Function(BuildContext context, double bottomPadding, double maxWidth, double maxHeight) builder,
    BoxDecoration Function(BuildContext context)? decoration,
    double? heightPercentage,
    bool isScrollControlled = false,
    bool isDismissible = true,
    bool? showDragHandle,
    Color? backgroundColor,
  }) async {
    await Future.delayed(Duration.zero); // delay bcz sometimes doesnt show

    final navigator = _rootNav.currentState;
    if (navigator == null) return null;

    _openedNumbersManager.incrementSheets();
    return navigator
        .push(
          _CustomModalBottomSheetRoute<T>(
            backgroundBlur: _openedNumbersManager._currentSheetNumber == 1 ? 3.0 : 0.0,
            isScrollControlled: isScrollControlled,
            showDragHandle: showDragHandle,
            isDismissible: isDismissible,
            backgroundColor: backgroundColor,
            builder: (context) {
              final bottomMargin = MediaQuery.viewInsetsOf(context).bottom;
              final bottomPadding = MediaQuery.paddingOf(context).bottom;
              return material.Padding(
                padding: EdgeInsets.only(bottom: bottomMargin),
                child: DecoratedBox(
                  decoration: decoration?.call(context) ?? const BoxDecoration(),
                  child: SizedBox(
                    height: heightPercentage == null ? null : (context.height * heightPercentage),
                    width: context.width,
                    child: material.Padding(
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      child: LayoutWidthHeightProvider(
                        builder: (context, maxWidth, maxHeight) => builder(
                          context,
                          bottomPadding,
                          maxWidth,
                          maxHeight,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        )
        .whenComplete(_openedNumbersManager.decrementSheets);
  }

  Future<void> navigateOff<W extends NamidaRouteWidget>(
    W page, {
    Transition transition = Transition.cupertino,
    int durationInMs = _defaultRouteAnimationDurMS,
  }) async {
    currentWidgetStack.execute(
      (value) {
        value.removeLast();
        value.add(page);
      },
    );

    _hideEverything();

    if (_shouldUpdateSubpagesColors) page.updateColorScheme();

    await navKey.currentState?.pushPageReplacement(
      page,
      durationInMs: durationInMs,
      transition: transition,
      maintainState: true,
    );
  }

  Future<void> navigateOffAll<W extends NamidaRouteWidget>(
    W page, {
    Transition transition = Transition.cupertino,
    int durationMs = 500,
  }) async {
    currentWidgetStack.value = [page];
    _hideEverything();

    if (_shouldUpdateSubpagesColors) page.updateColorScheme();

    navKey.currentState?.popUntil((r) => r.isFirst);
    try {
      await navKey.currentState?.pushPageReplacement(
        page,
        durationInMs: durationMs,
        transition: transition,
        maintainState: true,
      );
    } on StateError catch (_) {
      // -- no route was there yet, simple push now
      await navKey.currentState?.pushPage(
        page,
        durationInMs: durationMs,
        transition: transition,
        maintainState: true,
      );
    }
  }

  Future<void> back({bool waitForAnimation = false}) async {
    if (this.isInFullScreen) {
      NamidaNavigator.inst.exitFullScreen();
      return;
    }

    if (_openedNumbersManager._currentMenusNumber > 0) {
      this.popMenu();
    } else if (_openedNumbersManager._currentSheetNumber > 0) {
      _rootNav.currentState?.pop();
    } else if (_openedNumbersManager._currentDialogNumber > 0) {
      closeDialog();
    } else {
      popPage();
    }
  }

  Future<void> popPage({bool waitForAnimation = false}) async {
    if (innerDrawerKey.currentState?.isOpened == true) {
      innerDrawerKey.currentState?.close();
      return;
    }

    if (MiniPlayerController.inst.ytMiniplayerKey.currentState?.isExpanded == true) {
      if (isQueueSheetOpen) {
        ytQueueSheetKey.currentState?.dismissSheet();
        isQueueSheetOpen = false;
        return;
      } else if (isInYTCommentRepliesSubpage) {
        ytMiniplayerCommentsPageKey.currentState?.pop();
        isInYTCommentRepliesSubpage = false;
        return;
      } else if (isInYTCommentsSubpage) {
        ytMiniplayerCommentsPageKey.currentState?.pop();
        isInYTCommentsSubpage = false;
        return;
      } else if (!Dimensions.inst.miniplayerIsWideScreen) {
        MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(false);
        return;
      }
    }

    final miniplayerAllowPop = MiniPlayerController.inst.onWillPop();
    if (!miniplayerAllowPop) return;

    if (isytLocalSearchInFullPage) {
      ytLocalSearchNavigatorKey.currentState?.pop();
      isytLocalSearchInFullPage = false;
      return;
    }

    if (ScrollSearchController.inst.isGlobalSearchMenuShown.value || SettingsSearchController.inst.canShowSearch.value) {
      _hideSearchMenusAndUnfocus();
      return;
    }

    final route = currentRoute?.route;
    if (route != null) {
      if (route == RouteType.PAGE_folders) {
        final canIgoBackPls = FoldersController.tracksAndVideos.onBackButton();
        if (!canIgoBackPls) return;
      } else if (route == RouteType.PAGE_folders_music) {
        final canIgoBackPls = FoldersController.tracks.onBackButton();
        if (!canIgoBackPls) return;
      } else if (route == RouteType.PAGE_folders_videos) {
        final canIgoBackPls = FoldersController.videos.onBackButton();
        if (!canIgoBackPls) return;
      } else if (route == RouteType.SUBPAGE_playlistTracks) {
        PlaylistController.inst.resetCanReorder();
      } else if (route == RouteType.YOUTUBE_PLAYLIST_SUBPAGE) {
        YoutubePlaylistController.inst.resetCanReorder();
      }
    }

    // pop only if not in root, otherwise show _doubleTapToExit().
    if (currentWidgetStack.length > 1) {
      currentWidgetStack.removeLast();
      navKey.currentState?.pop();
    } else {
      await _doubleTapToExit();
    }
    if (waitForAnimation) await Future.delayed(const Duration(milliseconds: _defaultRouteAnimationDurMS));
    if (_shouldUpdateSubpagesColors) currentRoute?.updateColorScheme();
    _hideSearchMenusAndUnfocus();
  }

  DateTime _currentBackPressTime = DateTime(0);
  Future<bool> _doubleTapToExit() async {
    if (isDesktop) return false;

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

enum SnackDisplayDuration {
  flash(500),
  short(1000),
  mediumLow(1500),
  medium(2000),
  mediumHigh(2500),
  long(3000),
  veryLong(4000),
  eternal(5000),
  tutorial(8000);

  final int milliseconds;
  const SnackDisplayDuration(this.milliseconds);
}

SnackbarController snackyy({
  IconData? icon,
  String title = '',
  required String message,
  bool top = true,
  void Function(SnackbarStatus status)? onStatusChanged,
  EdgeInsetsGeometry margin = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
  bool altDesign = false,
  int animationDurationMS = 600,
  SnackDisplayDuration displayDuration = SnackDisplayDuration.medium,
  double borderRadius = 12.0,
  Color? leftBarIndicatorColor,
  Color? borderColor,
  (String text, FutureOr<void> Function() function)? button,
  bool? isError,
  int? maxLinesMessage,
}) {
  isError ??= title == lang.ERROR;
  final context = namida.context;
  final view = context?.view ?? namida.platformView;
  final backgroundColor = context?.theme.scaffoldBackgroundColor.withValues(alpha: 0.3) ?? Colors.black54;
  final itemsColor = context?.theme.colorScheme.onSurface.withValues(alpha: 0.7) ?? Colors.white54;

  TextStyle getTextStyle(FontWeight fontWeight, double size, {bool action = false}) => TextStyle(
        fontWeight: fontWeight,
        fontSize: size,
        height: 1.25,
        color: action ? null : itemsColor,
        fontFamily: "LexendDeca",
        fontFamilyFallback: const ['sans-serif', 'Roboto'],
      );

  // -- currently has no effects cuz it looks dogshit
  // if (altDesign) {
  //   borderRadius = 0;
  //   margin = EdgeInsets.zero;
  // }

  late SnackbarController snackbarController;

  final EdgeInsets paddingInsets;
  if (button != null) {
    if (title.isNotEmpty && message.isNotEmpty) {
      paddingInsets = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
    } else {
      paddingInsets = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
    }
  } else if (icon != null || title != '') {
    paddingInsets = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  } else {
    paddingInsets = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0);
  }

  bool alreadyTappedButton = false;

  double? snackWidth = view == null ? null : view.physicalSize.shortestSide / view.devicePixelRatio;
  if (snackWidth != null && Dimensions.inst.miniplayerIsWideScreen) {
    snackWidth = snackWidth.withMaximum(Dimensions.inst.availableAppContentWidth - margin.horizontal * 2 - kFABSize);
  }
  final desktopTopMargin = WindowController.instance?.windowTitleBarHeightIfActive ?? 0.0;
  if (desktopTopMargin > 0) {
    margin = margin.add(EdgeInsetsGeometry.only(top: desktopTopMargin));
  }

  final content = Theme(
    data: context?.theme ?? material.ThemeData(),
    child: Padding(
      padding: paddingInsets,
      child: SizedBox(
        width: snackWidth,
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
                style: ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  maximumSize: snackWidth == null
                      ? null
                      : material.WidgetStatePropertyAll(
                          Size(snackWidth * 0.5, double.infinity),
                        ),
                ),
                onPressed: () {
                  if (alreadyTappedButton) return;
                  alreadyTappedButton = true;
                  button.$2();
                  snackbarController.close();
                },
                child: NamidaButtonText(
                  button.$1,
                  style: getTextStyle(FontWeight.bold, 14.0, action: true),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  final snackbar = NamSnackBar(
    margin: margin,
    duration: Duration(milliseconds: displayDuration.milliseconds),
    animationDuration: Duration(milliseconds: animationDurationMS),
    alignment: Alignment.centerLeft,
    top: top,
    forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
    reverseAnimationCurve: Curves.easeInOutQuart,
    onStatusChanged: onStatusChanged,
    child: Material(
      color: Colors.transparent,
      type: MaterialType.transparency,
      child: NamidaBgBlurClipped(
        blur: 12.0,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius == 0 ? null : BorderRadius.circular(borderRadius.multipliedRadius),
          border: isError
              ? Border.all(
                  color: borderColor ?? Colors.red.withValues(alpha: 0.2),
                  width: 1.5,
                )
              : Border.all(
                  color: borderColor ?? Colors.grey.withValues(alpha: 0.5),
                  width: 0.5,
                ),
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
  );

  snackbarController = SnackbarController(snackbar);
  snackbarController.show();
  return snackbarController;
}

class _OpenedNumbersManager {
  int _currentDialogNumber = 0;
  int _currentSheetNumber = 0;
  int _currentMenusNumber = 0;

  void incrementDialogs() {
    _currentDialogNumber++;
    // _reEvaluate();
    if (kDebugMode) _printDialogs();
  }

  void decrementDialogs() {
    _currentDialogNumber--;
    // _reEvaluate();
    if (kDebugMode) _printDialogs();
  }

  void incrementSheets() {
    _currentSheetNumber++;
    // _reEvaluate();
    if (kDebugMode) _printSheets();
  }

  void decrementSheets() {
    _currentSheetNumber--;
    // _reEvaluate();
    if (kDebugMode) _printSheets();
  }

  void incrementMenus() {
    _currentMenusNumber++;
    // _reEvaluate();
    if (kDebugMode) _printMenus();
  }

  void decrementMenus() {
    _currentMenusNumber--;
    // _reEvaluate();
    if (kDebugMode) _printMenus();
  }

  // void _reEvaluate() {
  //   final blur = _currentDialogNumber > 0
  //       ? 6.0
  //       : _currentSheetNumber > 0
  //           ? 4.0
  //           : 0.0;
  //   _appBlurValue.value = blur;
  // }

  void _printDialogs() => printy("|> Current Dialogs: $_currentDialogNumber");
  void _printSheets() => printy("|> Current Sheets: $_currentSheetNumber");
  void _printMenus() => printy("|> Current Menus: $_currentMenusNumber");
}

class _CustomModalBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  final double backgroundBlur;
  _CustomModalBottomSheetRoute({
    this.backgroundBlur = 0,
    required super.isScrollControlled,
    super.showDragHandle,
    super.isDismissible,
    super.backgroundColor,
    required super.builder,
  });

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final child = super.buildPage(context, animation, secondaryAnimation);
    final animationCompleter = Completer<void>();

    void animationStatusListener(AnimationStatus status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        animation.removeStatusListener(animationStatusListener);
        animationCompleter.completeIfWasnt();
      }
    }

    animationStatusListener(animation.status);
    if (!animationCompleter.isCompleted) {
      animation.addStatusListener(animationStatusListener);
    }

    if (backgroundBlur > 0) {
      return FutureBuilder(
        future: animationCompleter.future,
        builder: (context, snapshot) {
          final didAnimate = snapshot.connectionState == ConnectionState.done;
          return TweenAnimationBuilder(
            duration: const Duration(milliseconds: 300),
            tween: DoubleTween(begin: 0, end: didAnimate ? 1 : 0),
            builder: (context, value, _) => NamidaBgBlur(
              enabled: true,
              disableIfBlur0: false,
              blur: backgroundBlur * (value ?? 0),
              child: child,
            ),
          );
        },
      );
    }
    return child;
  }
}
