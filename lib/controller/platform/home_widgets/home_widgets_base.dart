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
  Future<void> updateAll(String title, String? message, Uri? imageFileUri, bool isPlaying, bool isFavourite);
}

enum _HomeWidgetKey {
  title,
  message,
  image,
  playing,
  favourite,
}
