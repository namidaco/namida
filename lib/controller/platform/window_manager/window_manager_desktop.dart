part of 'window_manager.dart';

class _WindowManagerDesktop extends NamidaWindowManager {
  _WindowManagerDesktop({super.customRoundedCorners});

  @override
  bool get usingCustomWindowTitleBar => true;

  @override
  Future<void> init() async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
  }

  @override
  Future<void> restorePosition() async {
    final windowOptions = WindowOptions(
      size: Size(428, 812),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: usingCustomWindowTitleBar ? TitleBarStyle.hidden : TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, ensurePositionRestored);

    if (Platform.isLinux) {
      // -- window_manager on linux doesnt support some methods.
      windowManager.addListener(_NamidaWindowListenerEnhanced());
    } else {
      windowManager.addListener(_NamidaWindowListener());
    }

    screenRetriever.addListener(
      _CustomScreenListener(
        listener: (_) async {
          // display-removed or display-added
          final bounds = await windowManager.getBounds();
          final shiftedBounds = await _ensureBoundsWithinScreenSizeShift(bounds);
          if (bounds != shiftedBounds) {
            await windowManager.setBounds(shiftedBounds);
          }
        },
      ),
    );
  }

  @override
  Future<void> ensurePositionRestored({bool isStartup = true}) async {
    // -- sometimes waitUntilReadyToShow is not enough for linux

    if (NamidaWindowManager.isMiniLyricsMode.value) {
      await windowManager.show();
      await windowManager.focus();
      return;
    }

    if (isStartup) {
      final bounds = settings.extra.windowBounds;
      if (bounds != null) {
        // -- making sure window is in bounds with the current screen/s max size
        // -- for example: after disconnecting a second screen
        final shiftedBounds = await _ensureBoundsWithinScreenSizeShift(bounds);
        await windowManager.setBounds(shiftedBounds);
      }
    }

    final isMaximized = await windowManager.isMaximized();
    if (settings.extra.windowMaximized && !isMaximized) {
      await Future.delayed(const Duration(milliseconds: 100));
      await windowManager.maximize();
    } else if (!settings.extra.windowMaximized && isMaximized) {
      await Future.delayed(const Duration(milliseconds: 100));
      await windowManager.unmaximize();
    }

    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> enterMiniLyricsMode() async {
    if (NamidaWindowManager.isMiniLyricsMode.value) return;

    final wasMaximized = await windowManager.isMaximized();
    if (wasMaximized) {
      settings.extra.save(windowMaximized: true);
    } else {
      settings.extra.save(windowMaximized: false, windowBounds: await windowManager.getBounds());
    }

    settings.save(enableLyrics: true);

    NamidaWindowManager.isMiniLyricsMode.value = true;

    if (wasMaximized) await windowManager.unmaximize();
    if (await windowManager.isFullScreen()) await windowManager.setFullScreen(false);

    await windowManager.setMinimumSize(NamidaWindowManager.kMiniLyricsMinSize);
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false).ignoreError();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setBounds(await _resolveMiniLyricsBounds());
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setVisibleOnAllWorkspaces(true).ignoreError();
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> exitMiniLyricsMode() async {
    if (!NamidaWindowManager.isMiniLyricsMode.value) return;

    settings.extra.save(miniLyricsWindowBounds: await windowManager.getBounds());

    NamidaWindowManager.isMiniLyricsMode.value = false;

    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setVisibleOnAllWorkspaces(false).ignoreError();
    await windowManager.setHasShadow(true).ignoreError();
    await windowManager.setMinimumSize(Size.zero);
    await windowManager.setTitleBarStyle(
      usingCustomWindowTitleBar ? TitleBarStyle.hidden : TitleBarStyle.normal,
      windowButtonVisibility: !usingCustomWindowTitleBar,
    );
    await ensurePositionRestored(isStartup: true);
  }

  Future<Rect> _resolveMiniLyricsBounds() async {
    final saved = settings.extra.miniLyricsWindowBounds;
    if (saved != null) return await _ensureBoundsWithinScreenSizeShift(saved);

    const size = NamidaWindowManager.kMiniLyricsDefaultSize;
    Rect bounds;
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      final position = display.visiblePosition ?? Offset.zero;
      final displaySize = display.visibleSize ?? display.size;
      bounds = Rect.fromLTWH(
        position.dx + (displaySize.width - size.width) / 2,
        position.dy + displaySize.height - size.height - 64.0,
        size.width,
        size.height,
      );
    } catch (_) {
      bounds = Rect.fromLTWH(0.0, 0.0, size.width, size.height);
    }
    return await _ensureBoundsWithinScreenSizeShift(bounds);
  }

  Future<Rect> _ensureBoundsWithinScreenSizeShift(Rect bounds) async {
    // virtual desktop area (union of all monitors)
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    final displays = await screenRetriever.getAllDisplays();
    for (final d in displays) {
      final rect = Rect.fromLTWH(
        d.visiblePosition?.dx ?? 0,
        d.visiblePosition?.dy ?? 0,
        d.size.width,
        d.size.height,
      );
      minX = minX < rect.left ? minX : rect.left;
      minY = minY < rect.top ? minY : rect.top;
      maxX = maxX > rect.right ? maxX : rect.right;
      maxY = maxY > rect.bottom ? maxY : rect.bottom;
    }

    if (minX == double.infinity) {
      // -- fallback
      minX = 0;
      minY = 0;
      maxX = namida.width;
      maxY = namida.height;
    }

    final desktopRect = Rect.fromLTRB(minX, minY, maxX, maxY);

    final windowWidth = bounds.width;
    final windowHeight = bounds.height;

    // -- clamp position while keeping size
    final newLeft = bounds.left.clampDouble(
      desktopRect.left,
      desktopRect.right - windowWidth,
    );
    final newTop = bounds.top.clampDouble(
      desktopRect.top,
      desktopRect.bottom - windowHeight,
    );

    final shiftedBounds = Rect.fromLTWH(
      newLeft,
      newTop,
      windowWidth,
      windowHeight,
    );

    return shiftedBounds;
  }
}

class _NamidaWindowListenerEnhanced extends _NamidaWindowListener {
  Timer? _timer;

  void _startSaveTimer(void Function() callback) {
    _timer?.cancel();
    _timer = Timer(
      const Duration(seconds: 2),
      () {
        callback();
        _timer?.cancel();
        _timer = null;
      },
    );
  }

  @override
  void onWindowResize() {
    super.onWindowResize();
    _startSaveTimer(super.onWindowResized);
  }

  @override
  void onWindowMove() {
    super.onWindowMove();
    _startSaveTimer(super.onWindowMoved);
  }
}

class _NamidaWindowListener with WindowListener {
  Future<void> _saveBounds() async {
    final currentBounds = await windowManager.getBounds();
    if (NamidaWindowManager.isMiniLyricsMode.value) {
      if (currentBounds != settings.extra.miniLyricsWindowBounds) {
        settings.extra.save(miniLyricsWindowBounds: currentBounds);
      }
    } else {
      if (currentBounds != settings.extra.windowBounds) {
        settings.extra.save(windowBounds: currentBounds);
      }
    }
  }

  void _saveMaximized({required bool isNowMaximized}) {
    if (NamidaWindowManager.isMiniLyricsMode.value) return;
    if (isNowMaximized != settings.extra.windowMaximized) {
      settings.extra.save(windowMaximized: isNowMaximized);
    }
  }

  @override
  void onWindowResize() async {
    ArtworkWidget.isResizingAppWindow = true;
  }

  @override
  void onWindowResized() async {
    ArtworkWidget.isResizingAppWindow = false;
    await _saveBounds();
  }

  @override
  void onWindowMoved() async {
    await _saveBounds();
  }

  @override
  void onWindowMaximize() {
    _saveMaximized(isNowMaximized: true);
  }

  @override
  void onWindowUnmaximize() {
    _saveMaximized(isNowMaximized: false);
  }

  @override
  Future<void> onWindowClose() async {
    if (NamidaWindowManager.isMiniLyricsMode.value) {
      await WindowController.instance?.exitMiniLyricsMode();
      return;
    }

    if (settings.player.killAfterDismissingApp.value.resolveShouldKill()) {
      await Namida.disposeAllResourcesAndExit();
    } else {
      // -- minimize to tray instead
      await NamidaTrayManager.hideWindow();
    }
  }
}

class _CustomScreenListener extends ScreenListener {
  final Function(String eventName) listener;

  _CustomScreenListener({required this.listener});

  @override
  void onScreenEvent(String eventName) => listener(eventName);
}
