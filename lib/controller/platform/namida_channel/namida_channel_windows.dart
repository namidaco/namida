part of 'namida_channel.dart';

class _NamidaChannelWindows extends NamidaChannel {
  _NamidaChannelWindows._internal();

  @override
  Future<void> updatePipRatio({int? width, int? height}) async {
    // -- unsupported
  }

  @override
  Future<void> setCanEnterPip(bool canEnter) async {
    // -- unsupported
  }

  @override
  Future<void> showToast({
    required String message,
    required SnackDisplayDuration duration,
  }) async {
    // -- use in-app toast
    snackyy(message: message, displayDuration: duration);
  }

  @override
  Future<int> getPlatformSdk() async {
    return 0;
  }

  @override
  Future<bool> setMusicAs({required String path, required List<SetMusicAsAction> types}) async {
    // -- unsupported
    return false;
  }

  @override
  Future<bool> openSystemEqualizer(int? sessionId) async {
    // -- unsupported
    return false;
  }
}
