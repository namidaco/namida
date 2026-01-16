part of 'app_single_instance.dart';

abstract class AppSingleInstanceBase {
  static final instance = AppSingleInstanceBase.platform();
  static AppSingleInstanceBase? platform() {
    return NamidaPlatformBuilder.init(
      android: () => null,
      windows: () => AppSingleInstanceWindows(),
      linux: () => AppSingleInstanceLinux(),
    );
  }

  Future<void> acquireSingleInstanceOrExit(List<String> args);

  Future<void> dispose();
}
