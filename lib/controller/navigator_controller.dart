// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

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
  bool isInYTCommentRepliesSubpage = false;
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

  static const _defaultRouteAnimationDurMS = 400;

  Future<T?> showMenu<T>({
    required BuildContext context,
    required RelativeRect position,
    required List<PopupMenuEntry<T>> items,
  }) async {
    ScrollSearchController.inst.unfocusKeyboard();
    _currentMenusNumber++;
    _printMenus();
    return material.showMenu(
      useRootNavigator: true,
      popUpAnimationStyle: material.AnimationStyle(
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 200),
        curve: material.Curves.easeOutQuart,
        reverseCurve: material.Curves.easeInOutQuad,
      ),
      context: context,
      position: position,
      items: items,
    );
  }

  void popMenu({bool handleClosing = true}) {
    if (_currentMenusNumber > 0) {
      _currentMenusNumber--;
      if (handleClosing) {
        popRoot();
      }
    }
    _printMenus();
  }

  void popAllMenus() {
    if (_currentMenusNumber == 0) return;
    _rootNav.currentState?.popUntil((r) => r.isFirst);
    _currentMenusNumber = 0;
    _printMenus();
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
    MiniPlayerController.inst.snapToMini();
    MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(false);
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
    _isInLanscape = lanscape;
    final orientations = lanscape ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : kDefaultOrientations;
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

    popRoot();

    setDefaultSystemUIOverlayStyle();
    await Future.wait([
      if (isInLanscape) setDeviceOrientations(false),
      MiniPlayerController.inst.setImmersiveMode(null), // let mp decides
    ]);

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

    page.updateColorScheme();

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
    final int durationInMs = 300,
    final bool Function()? tapToDismiss,
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
      if (tapToDismiss != null && tapToDismiss() == false) return false;

      if (_currentDialogNumber > 0) {
        closeDialog();
        if (onDismissing != null) await onDismissing(); // this can open new dialog, so we closeDialog() first.
        return false;
      }

      return true;
    }

    final theme = AppThemes.inst.getAppTheme(colorScheme, null, lighterDialogColor);

    final res = await _rootNav.currentState?.pushPage<T>(
      WillPopScope(
        onWillPop: onWillPop,
        child: TapDetector(
          onTap: onWillPop,
          child: NamidaBgBlur(
            blur: 5.0,
            enabled: _currentDialogNumber == 1,
            child: material.RepaintBoundary(
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
    _printDialogs();
    return res;
  }

  Future<void> closeDialog([int count = 1]) async {
    if (_currentDialogNumber == 0) return;
    int closeCount = count.withMaximum(_currentDialogNumber);
    while (closeCount > 0) {
      _currentDialogNumber--;
      popRoot();
      closeCount--;
    }
    _printDialogs();
  }

  Future<void> closeAllDialogs() async {
    if (_currentDialogNumber == 0) return;
    closeDialog(_currentDialogNumber);
    _printDialogs();
  }

  Future<T?> showSheet<T>({
    required Widget Function(BuildContext context, double bottomPadding, double maxWidth, double maxHeight) builder,
    BoxDecoration Function(BuildContext context)? decoration,
    BuildContext? context,
    double? heightPercentage,
    bool isScrollControlled = false,
    bool isDismissible = true,
    bool? showDragHandle,
    Color? backgroundColor,
  }) async {
    await Future.delayed(Duration.zero); // delay bcz sometimes doesnt show

    context ??= _rootNav.currentContext!;

    return await showModalBottomSheet(
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      context: context,
      isDismissible: isDismissible,
      backgroundColor: backgroundColor,
      useRootNavigator: true,
      builder: (context) {
        final bottomPadding = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
        return DecoratedBox(
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
        );
      },
    );
  }

  void _printDialogs() => printy("Current Dialogs: $_currentDialogNumber");
  void _printMenus() => printy("Current Menus: $_currentMenusNumber");

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

    page.updateColorScheme();

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

    page.updateColorScheme();

    navKey.currentState?.popUntil((r) => r.isFirst);

    await navKey.currentState?.pushPageReplacement(
      page,
      durationInMs: durationMs,
      transition: transition,
      maintainState: true,
    );
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
    currentRoute?.updateColorScheme();
    _hideSearchMenusAndUnfocus();
  }

  DateTime _currentBackPressTime = DateTime(0);
  Future<bool> _doubleTapToExit() async {
    if (Platform.isWindows) return false;

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

SnackbarController? snackyy({
  IconData? icon,
  String title = '',
  required String message,
  bool top = true,
  void Function(SnackbarStatus status)? onStatusChanged,
  EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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

  final borderR = borderRadius == 0 ? null : BorderRadius.circular(borderRadius.multipliedRadius);
  SnackbarController? snackbarController;

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
      child: ClipRRect(
        borderRadius: borderR ?? BorderRadius.zero,
        child: NamidaBgBlur(
          blur: 12.0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderR,
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
      ),
    ),
  );

  snackbarController = SnackbarController(snackbar);
  snackbarController.show();
  return snackbarController;
}
