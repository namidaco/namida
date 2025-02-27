part of 'home_widgets.dart';

class _HomeWidgetsMobile extends HomeWidgets {
  @override
  FutureOr<bool?> init() {
    if (Platform.isIOS) {
      try {
        return HomeWidget.setAppGroupId('NAMIDA_ID');
      } on MissingPluginException catch (_) {}
    }
    return null;
  }

  @override
  Future<void> updateIsPlaying(bool isPlaying) async {
    await HomeWidget.saveWidgetData<bool>(_HomeWidgetKey.playing.name, isPlaying);
    await _refresh();
  }

  @override
  Future<void> updateIsFavourite(bool isFavourite) async {
    await HomeWidget.saveWidgetData<bool>(_HomeWidgetKey.favourite.name, isFavourite);
    await _refresh();
  }

  @override
  Future<void> updateAll(String title, String? message, Uri? imageFileUri, bool isPlaying, bool isFavourite) async {
    await Future.wait([
      HomeWidget.saveWidgetData<String>(_HomeWidgetKey.title.name, title),
      HomeWidget.saveWidgetData<String>(_HomeWidgetKey.message.name, message),
      HomeWidget.saveWidgetData<String>(_HomeWidgetKey.image.name, imageFileUri?.toFilePath()),
      HomeWidget.saveWidgetData<bool>(_HomeWidgetKey.playing.name, isPlaying),
      HomeWidget.saveWidgetData<bool>(_HomeWidgetKey.favourite.name, isFavourite),
    ]);
    await _refresh();
  }

  Future<bool?> _refresh() {
    return HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.msob7y.namida.glance.SchwarzReceiver',
    );
  }
}
