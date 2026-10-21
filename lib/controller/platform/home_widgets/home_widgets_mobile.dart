part of 'home_widgets.dart';

class _HomeWidgetsMobile extends HomeWidgets {
  @override
  Future<bool?> init() {
    if (Platform.isIOS) {
      try {
        return HomeWidget.setAppGroupId('NAMIDA_ID');
      } on MissingPluginException catch (_) {}
    }
    if (Platform.isAndroid) _initHasWidgets();
    return Future.value(null);
  }

  // -- no widget lifecycle events on ios
  bool _hasWidgets = Platform.isIOS;

  Future<void> _initHasWidgets() async {
    bool hasWidgets;
    try {
      final widgets = await HomeWidget.getInstalledWidgets();
      hasWidgets = widgets.isNotEmpty;
    } catch (_) {
      // -- unknown, keep writing
      hasWidgets = true;
    }
    await setHasWidgets(hasWidgets);
  }

  @override
  Future<void> setHasWidgets(bool hasWidgets) async {
    final hadWidgets = _hasWidgets;
    _hasWidgets = hasWidgets;
    if (hasWidgets && !hadWidgets) await _saveAll();
  }

  String? _lastTitle;
  String? _lastMessage;
  String? _lastImage;
  bool? _lastIsPlaying;
  bool? _lastIsFavourite;
  bool? _lastIsFavouriteAsLike;
  PlayerRepeatMode? _lastRepeatMode;
  int? _lastRepeatCount;
  bool? _lastShuffle;

  @override
  Future<void> updateIsPlaying(bool isPlaying) async {
    if (isPlaying == _lastIsPlaying) return;
    _lastIsPlaying = isPlaying;
    if (!_hasWidgets) return;
    await _saveAndRefresh({_HomeWidgetKey.playing.name: isPlaying});
  }

  @override
  Future<void> updateIsFavourite(bool isFavourite) async {
    if (isFavourite == _lastIsFavourite) return;
    _lastIsFavourite = isFavourite;
    if (!_hasWidgets) return;
    await _saveAndRefresh({_HomeWidgetKey.favourite.name: isFavourite});
  }

  @override
  Future<void> updateRepeatMode(PlayerRepeatMode repeatMode, int repeatCount) async {
    final data = <String, Object?>{
      if (_hasWidgets) ...{
        if (repeatMode != _lastRepeatMode) _HomeWidgetKey.repeat.name: repeatMode.name,
        if (repeatCount != _lastRepeatCount) _HomeWidgetKey.repeatCount.name: repeatCount,
      },
    };
    _lastRepeatMode = repeatMode;
    _lastRepeatCount = repeatCount;
    if (data.isEmpty) return;
    await _saveAndRefresh(data);
  }

  @override
  Future<void> updateShuffle(bool shuffle) async {
    if (shuffle == _lastShuffle) return;
    _lastShuffle = shuffle;
    if (!_hasWidgets) return;
    await _saveAndRefresh({_HomeWidgetKey.shuffle.name: shuffle});
  }

  @override
  Future<void> updateAll({
    required String title,
    required String? message,
    required Uri? imageFileUri,
    required bool isPlaying,
    required bool isFavourite,
    required bool isFavouriteAsLike,
    required PlayerRepeatMode repeatMode,
    required int repeatCount,
    required bool shuffle,
  }) async {
    final image = imageFileUri?.toString();
    final data = <String, Object?>{
      if (_hasWidgets) ...{
        if (title != _lastTitle) _HomeWidgetKey.title.name: title,
        if (message != _lastMessage) _HomeWidgetKey.message.name: message,
        if (image != _lastImage) _HomeWidgetKey.image.name: image,
        if (isPlaying != _lastIsPlaying) _HomeWidgetKey.playing.name: isPlaying,
        if (isFavourite != _lastIsFavourite) _HomeWidgetKey.favourite.name: isFavourite,
        if (isFavouriteAsLike != _lastIsFavouriteAsLike) _HomeWidgetKey.favouriteAsLike.name: isFavouriteAsLike,
        if (repeatMode != _lastRepeatMode) _HomeWidgetKey.repeat.name: repeatMode.name,
        if (repeatCount != _lastRepeatCount) _HomeWidgetKey.repeatCount.name: repeatCount,
        if (shuffle != _lastShuffle) _HomeWidgetKey.shuffle.name: shuffle,
      },
    };
    _lastTitle = title;
    _lastMessage = message;
    _lastImage = image;
    _lastIsPlaying = isPlaying;
    _lastIsFavourite = isFavourite;
    _lastIsFavouriteAsLike = isFavouriteAsLike;
    _lastRepeatMode = repeatMode;
    _lastRepeatCount = repeatCount;
    _lastShuffle = shuffle;
    if (data.isEmpty) return;
    await _saveAndRefresh(data);
  }

  Future<void> _saveAll() async {
    final title = _lastTitle;
    final data = <String, Object?>{
      if (title != null) ...{
        _HomeWidgetKey.title.name: title,
        _HomeWidgetKey.message.name: _lastMessage,
        _HomeWidgetKey.image.name: _lastImage,
        _HomeWidgetKey.favouriteAsLike.name: _lastIsFavouriteAsLike,
      },
      _HomeWidgetKey.playing.name: ?_lastIsPlaying,
      _HomeWidgetKey.favourite.name: ?_lastIsFavourite,
      _HomeWidgetKey.repeat.name: ?_lastRepeatMode?.name,
      _HomeWidgetKey.repeatCount.name: ?_lastRepeatCount,
      _HomeWidgetKey.shuffle.name: ?_lastShuffle,
    };
    if (data.isEmpty) return;
    await _saveAndRefresh(data);
  }

  Future<void> _saveAndRefresh(Map<String, Object?> data) async {
    await HomeWidget.saveWidgetDataBatch(data);
    await _refresh();
  }

  Future<bool?> _refresh() {
    return HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.msob7y.namida.glance.SchwarzReceiver',
    );
  }
}
