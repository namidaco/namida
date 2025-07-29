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

  Future<void> showToast({required String message, required SnackDisplayDuration duration});

  Future<int> getPlatformSdk();

  Future<bool> setMusicAs({required String path, required List<SetMusicAsAction> types});

  Future<bool> openSystemEqualizer(int? sessionId);

  Future<bool> openNamidaSync(String backupFolder, String musicFoldersJoined);

  final _onResume = <FutureOr<void> Function()>[];
  final _onSuspending = <FutureOr<void> Function()>[];
  final _onDestroy = <FutureOr<void> Function()>[];

  void addOnDestroy(FutureOr<void> Function() fn) {
    _onDestroy.add(fn);
  }

  void addOnResume(FutureOr<void> Function() fn) {
    _onResume.add(fn);
  }

  void addOnSuspending(FutureOr<void> Function() fn) {
    _onSuspending.add(fn);
  }

  void removeOnDestroy(FutureOr<void> Function() fn) {
    _onDestroy.remove(fn);
  }

  void removeOnResume(FutureOr<void> Function() fn) {
    _onResume.remove(fn);
  }

  void removeOnSuspending(FutureOr<void> Function() fn) {
    _onSuspending.remove(fn);
  }
}
