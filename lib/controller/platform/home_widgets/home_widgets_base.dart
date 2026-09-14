part of 'home_widgets.dart';

abstract class HomeWidgets {
  static HomeWidgets? platform() {
    return NamidaPlatformBuilder.init(
      android: () => _HomeWidgetsMobile(),
      ios: () => _HomeWidgetsMobile(),
      windows: () => null,
      linux: () => null,
    );
  }

  Future<bool?> init();
  Future<void> updateIsPlaying(bool isPlaying);
  Future<void> updateIsFavourite(bool isFavourite);
  Future<void> updateRepeatMode(PlayerRepeatMode repeatMode, int repeatCount);
  Future<void> updateShuffle(bool shuffle);
  Future<void> updateAll({
    required String title,
    required String? message,
    required Uri? imageFileUri,
    required bool isPlaying,
    required bool isFavourite,
    required PlayerRepeatMode repeatMode,
    required int repeatCount,
    required bool shuffle,
  });
}

enum _HomeWidgetKey {
  title,
  message,
  image,
  playing,
  favourite,
  repeat,
  repeatCount,
  shuffle,
}
