part of 'app_single_instance.dart';

class AppSingleInstanceWindows extends AppSingleInstanceBase {
  @override
  Future<void> acquireSingleInstanceOrExit(List<String> args) async {
    // -- will terminate internally automatically
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      "namida_instance",
      bringWindowToFront: true,
      onSecondWindow: _onSecondWindow,
      exitFunction: () async => Namida.terminateProcessWindows(),
    );
  }

  void _onSecondWindow(List<String> args) {
    NamidaReceiveIntentManager.executeReceivedItems(args, (p) => p, (p) => p);
    NamidaTrayManager.showWindow();
  }

  @override
  Future<void> dispose() async {}
}
