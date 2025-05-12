part of 'window_manager.dart';

class _WindowManagerDesktop extends NamidaWindowManager {
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
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.addListener(_NamidaWindowListener());
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      final bounds = settings.windowBounds;
      if (bounds != null) await windowManager.setBounds(settings.windowBounds);
      await windowManager.show();
      await windowManager.focus();
    });
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
