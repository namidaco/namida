part of 'home_widgets.dart';

class _HomeWidgetsMobile extends HomeWidgets {
  @override
  Future<bool?> init() {
    if (Platform.isIOS) {
      try {
        return HomeWidget.setAppGroupId('NAMIDA_ID');
      } on MissingPluginException catch (_) {}
    }
    return Future.value(null);
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
  Future<void> updateRepeatMode(PlayerRepeatMode repeatMode, int repeatCount) async {
    await Future.wait([
      HomeWidget.saveWidgetData<String>(_HomeWidgetKey.repeat.name, repeatMode.name),
      HomeWidget.saveWidgetData<int>(_HomeWidgetKey.repeatCount.name, repeatCount),
    ]);
    await _refresh();
  }

  @override
  Future<void> updateAll(String title, String? message, Uri? imageFileUri, bool isPlaying, bool isFavourite, PlayerRepeatMode repeatMode, int repeatCount) async {
    await Future.wait([
      HomeWidget.saveWidgetData<String>(_HomeWidgetKey.title.name, title),
      HomeWidget.saveWidgetData<String>(_HomeWidgetKey.message.name, message),
      HomeWidget.saveWidgetData<String>(_HomeWidgetKey.image.name, imageFileUri?.toString()),
      HomeWidget.saveWidgetData<bool>(_HomeWidgetKey.playing.name, isPlaying),
      HomeWidget.saveWidgetData<bool>(_HomeWidgetKey.favourite.name, isFavourite),
      HomeWidget.saveWidgetData<String>(_HomeWidgetKey.repeat.name, repeatMode.name),
      HomeWidget.saveWidgetData<int>(_HomeWidgetKey.repeatCount.name, repeatCount),
    ]);
    await _refresh();
  }

  Future<bool?> _refresh() {
    return HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.msob7y.namida.glance.SchwarzReceiver',
    );
  }
}
