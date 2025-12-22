part of 'window_manager.dart';

class _WindowManagerDesktop extends NamidaWindowManager {
  @override
  bool get usingCustomWindowTitleBar => true;

  @override
  Future<void> init() async {
    await windowManager.ensureInitialized();
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
    windowManager.addListener(_NamidaWindowListener());
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      final bounds = settings.windowBounds;
      if (bounds != null) {
        // -- making sure window is in bounds with the current screen/s max size
        // -- for example: after disconnecting a second screen
        final shiftedBounds = await _ensureBoundsWithinScreenSizeShift(bounds);
        await windowManager.setBounds(shiftedBounds);
      }
      await windowManager.show();
      await windowManager.focus();
    });

    screenRetriever.addListener(_CustomScreenListener(
      listener: (_) async {
        // display-removed or display-added
        final bounds = await windowManager.getBounds();
        final shiftedBounds = await _ensureBoundsWithinScreenSizeShift(bounds);
        if (bounds != shiftedBounds) {
          await windowManager.setBounds(shiftedBounds);
        }
      },
    ));
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
    final newLeft = bounds.left.clamp(
      desktopRect.left,
      desktopRect.right - windowWidth,
    );
    final newTop = bounds.top.clamp(
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

class _NamidaWindowListener with WindowListener {
  Future<void> _saveBounds() async {
    settings.save(windowBounds: await windowManager.getBounds());
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
}

class _CustomScreenListener extends ScreenListener {
  final Function(String eventName) listener;

  _CustomScreenListener({required this.listener});

  @override
  void onScreenEvent(String eventName) => listener(eventName);
}
