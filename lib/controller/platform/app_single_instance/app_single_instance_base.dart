part of 'app_single_instance.dart';

abstract class AppSingleInstanceBase {
  static final instance = AppSingleInstanceBase.platform();
  static AppSingleInstanceBase? platform() {
    return NamidaPlatformBuilder.init(
      android: () => null,
      ios: () => null,
      windows: AppSingleInstanceWindows.new,
      linux: AppSingleInstanceLinux.new,
      macos: () => null,
    );
  }

  Future<void> acquireSingleInstanceOrExit(List<String> args);

  Future<void> dispose();
}
