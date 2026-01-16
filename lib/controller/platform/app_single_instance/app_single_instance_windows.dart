part of 'app_single_instance.dart';

class AppSingleInstanceWindows extends AppSingleInstanceBase {
  @override
  Future<void> acquireSingleInstanceOrExit(List<String> args) async {
    // -- will terminate internally automatically
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      "namida_instance",
      bringWindowToFront: true,
      onSecondWindow: (args) => NamidaReceiveIntentManager.executeReceivedItems(args, (p) => p, (p) => p),
    );
  }

  @override
  Future<void> dispose() async {}
}
