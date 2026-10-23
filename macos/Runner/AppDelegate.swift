import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// the tray keeps namida running, closing the window is decided on the dart side.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// clicking the dock icon brings back a window hidden to the tray.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      mainFlutterWindow?.makeKeyAndOrderFront(nil)
    }
    return true
  }
}
