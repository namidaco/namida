import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NamidaBackgroundWork.shared.registerContinuedTask()
    // -- flutter forwards notification events to plugins only as the delegate, without it notifications are dropped while the app is open
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let registry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: registry)
    if let registrar = registry.registrar(forPlugin: "NamidaPlugin") {
      NamidaPlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "NamidaStoragePlugin") {
      NamidaStoragePlugin.register(with: registrar)
    }
    if let registrar = registry.registrar(forPlugin: "NamidaBonjourPlugin") {
      NamidaBonjourPlugin.register(with: registrar)
    }
    #if NAMIDA_WIDGETS
    if let registrar = registry.registrar(forPlugin: "NamidaWidgetsPlugin") {
      NamidaWidgetsPlugin.register(with: registrar)
    }
    #endif
  }
}
