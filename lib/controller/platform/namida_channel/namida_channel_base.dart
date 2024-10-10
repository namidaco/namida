part of 'namida_channel.dart';

abstract class NamidaChannel {
  static final NamidaChannel inst = NamidaChannel._platform();

  static NamidaChannel _platform() {
    return NamidaPlatformBuilder.init(
      android: () => _NamidaChannelAndroid._init(),
      windows: () => _NamidaChannelWindows._internal(),
    );
  }

  final isInPip = false.obs;

  Future<void> updatePipRatio({int? width, int? height});

  Future<void> setCanEnterPip(bool canEnter);

  Future<void> showToast({required String message, int seconds = 5});

  Future<int> getPlatformSdk();

  Future<bool> setMusicAs({required String path, required List<SetMusicAsAction> types});

  Future<bool> openSystemEqualizer(int? sessionId);

  final _onResume = <String, FutureOr<void> Function()>{};
  final _onSuspending = <String, FutureOr<void> Function()>{};
  final _onDestroy = <String, FutureOr<void> Function()>{};

  void addOnDestroy(String key, FutureOr<void> Function() fn) {
    _onDestroy[key] = fn;
  }

  void addOnResume(String key, FutureOr<void> Function() fn) {
    _onResume[key] = fn;
  }

  void addOnSuspending(String key, FutureOr<void> Function() fn) {
    _onSuspending[key] = fn;
  }

  void removeOnDestroy(String key) {
    _onDestroy.remove(key);
  }

  void removeOnResume(String key) {
    _onResume.remove(key);
  }

  void removeOnSuspending(String key) {
    _onSuspending.remove(key);
  }
}
