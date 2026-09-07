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

  String _lastTitle = '';
  String? _lastMessage;
  String? _lastImage;
  bool? _lastIsPlaying;
  bool? _lastIsFavourite;
  PlayerRepeatMode? _lastRepeatMode;
  int? _lastRepeatCount;

  @override
  Future<void> updateIsPlaying(bool isPlaying) async {
    if (isPlaying == _lastIsPlaying) return;
    _lastIsPlaying = isPlaying;
    await HomeWidget.saveWidgetData<bool>(_HomeWidgetKey.playing.name, isPlaying);
    await _refresh();
  }

  @override
  Future<void> updateIsFavourite(bool isFavourite) async {
    if (isFavourite == _lastIsFavourite) return;
    _lastIsFavourite = isFavourite;
    await HomeWidget.saveWidgetData<bool>(_HomeWidgetKey.favourite.name, isFavourite);
    await _refresh();
  }

  @override
  Future<void> updateRepeatMode(PlayerRepeatMode repeatMode, int repeatCount) async {
    final writes = <Future<bool?>>[
      if (repeatMode != _lastRepeatMode) HomeWidget.saveWidgetData<String>(_HomeWidgetKey.repeat.name, repeatMode.name),
      if (repeatCount != _lastRepeatCount) HomeWidget.saveWidgetData<int>(_HomeWidgetKey.repeatCount.name, repeatCount),
    ];
    if (writes.isEmpty) return;
    _lastRepeatMode = repeatMode;
    _lastRepeatCount = repeatCount;
    await Future.wait(writes);
    await _refresh();
  }

  @override
  Future<void> updateAll(String title, String? message, Uri? imageFileUri, bool isPlaying, bool isFavourite, PlayerRepeatMode repeatMode, int repeatCount) async {
    final image = imageFileUri?.toString();
    final writes = <Future<bool?>>[
      if (title != _lastTitle) HomeWidget.saveWidgetData<String>(_HomeWidgetKey.title.name, title),
      if (message != _lastMessage) HomeWidget.saveWidgetData<String>(_HomeWidgetKey.message.name, message),
      if (image != _lastImage) HomeWidget.saveWidgetData<String>(_HomeWidgetKey.image.name, image),
      if (isPlaying != _lastIsPlaying) HomeWidget.saveWidgetData<bool>(_HomeWidgetKey.playing.name, isPlaying),
      if (isFavourite != _lastIsFavourite) HomeWidget.saveWidgetData<bool>(_HomeWidgetKey.favourite.name, isFavourite),
      if (repeatMode != _lastRepeatMode) HomeWidget.saveWidgetData<String>(_HomeWidgetKey.repeat.name, repeatMode.name),
      if (repeatCount != _lastRepeatCount) HomeWidget.saveWidgetData<int>(_HomeWidgetKey.repeatCount.name, repeatCount),
    ];
    if (writes.isEmpty) return;
    _lastTitle = title;
    _lastMessage = message;
    _lastImage = image;
    _lastIsPlaying = isPlaying;
    _lastIsFavourite = isFavourite;
    _lastRepeatMode = repeatMode;
    _lastRepeatCount = repeatCount;
    await Future.wait(writes);
    await _refresh();
  }

  Future<bool?> _refresh() {
    return HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.msob7y.namida.glance.SchwarzReceiver',
    );
  }
}
