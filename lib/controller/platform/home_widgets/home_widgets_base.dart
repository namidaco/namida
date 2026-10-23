part of 'home_widgets.dart';

abstract class HomeWidgets {
  static HomeWidgets? platform() {
    return NamidaPlatformBuilder.init(
      android: _HomeWidgetsAndroid.new,
      ios: _HomeWidgetsIOS.new,
      windows: () => null,
      linux: () => null,
      macos: () => null,
    );
  }

  Future<bool?> init();

  /// what the platform's widgets show, the rest is never sent.
  Set<_HomeWidgetKey> get _shownKeys;

  Future<void> _saveAndRefresh(Map<String, Object?> data);

  bool _hasWidgets = false;

  Future<void> setHasWidgets(bool hasWidgets) async {
    final hadWidgets = _hasWidgets;
    _hasWidgets = hasWidgets;
    if (hasWidgets && !hadWidgets) await _saveAll();
  }

  /// widget buttons pressed before the player was ready (ex: they launched the app) wait for it.
  Future<void> onPlayerReady(Future<void> Function(HomeWidgetMediaAction action) performMediaAction) async {}

  /// false when live activities aren't available at all, the sink then stops sending.
  Future<bool> updateLiveActivity({required String title, required String? artist, required String? line}) async => false;

  Future<void> endLiveActivity() async {}

  String? _lastTitle;
  String? _lastMessage;
  String? _lastImage;
  bool? _lastIsPlaying;
  bool? _lastIsFavourite;
  bool? _lastIsFavouriteAsLike;
  PlayerRepeatMode? _lastRepeatMode;
  int? _lastRepeatCount;
  bool? _lastShuffle;

  Future<void> updateIsPlaying(bool isPlaying) async {
    if (isPlaying == _lastIsPlaying) return;
    _lastIsPlaying = isPlaying;
    await _sendChanges({_HomeWidgetKey.playing: isPlaying});
  }

  Future<void> updateIsFavourite(bool isFavourite) async {
    if (isFavourite == _lastIsFavourite) return;
    _lastIsFavourite = isFavourite;
    await _sendChanges({_HomeWidgetKey.favourite: isFavourite});
  }

  Future<void> updateRepeatMode(PlayerRepeatMode repeatMode, int repeatCount) async {
    final changes = <_HomeWidgetKey, Object?>{
      if (repeatMode != _lastRepeatMode) _HomeWidgetKey.repeat: repeatMode.name,
      if (repeatCount != _lastRepeatCount) _HomeWidgetKey.repeatCount: repeatCount,
    };
    _lastRepeatMode = repeatMode;
    _lastRepeatCount = repeatCount;
    await _sendChanges(changes);
  }

  Future<void> updateShuffle(bool shuffle) async {
    if (shuffle == _lastShuffle) return;
    _lastShuffle = shuffle;
    await _sendChanges({_HomeWidgetKey.shuffle: shuffle});
  }

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
    final changes = <_HomeWidgetKey, Object?>{
      if (title != _lastTitle) _HomeWidgetKey.title: title,
      if (message != _lastMessage) _HomeWidgetKey.message: message,
      if (image != _lastImage) _HomeWidgetKey.image: image,
      if (isPlaying != _lastIsPlaying) _HomeWidgetKey.playing: isPlaying,
      if (isFavourite != _lastIsFavourite) _HomeWidgetKey.favourite: isFavourite,
      if (isFavouriteAsLike != _lastIsFavouriteAsLike) _HomeWidgetKey.favouriteAsLike: isFavouriteAsLike,
      if (repeatMode != _lastRepeatMode) _HomeWidgetKey.repeat: repeatMode.name,
      if (repeatCount != _lastRepeatCount) _HomeWidgetKey.repeatCount: repeatCount,
      if (shuffle != _lastShuffle) _HomeWidgetKey.shuffle: shuffle,
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
    await _sendChanges(changes);
  }

  Future<void> _saveAll() async {
    final title = _lastTitle;
    final changes = <_HomeWidgetKey, Object?>{
      if (title != null) ...{
        _HomeWidgetKey.title: title,
        _HomeWidgetKey.message: _lastMessage,
        _HomeWidgetKey.image: _lastImage,
        _HomeWidgetKey.favouriteAsLike: _lastIsFavouriteAsLike,
      },
      _HomeWidgetKey.playing: ?_lastIsPlaying,
      _HomeWidgetKey.favourite: ?_lastIsFavourite,
      _HomeWidgetKey.repeat: ?_lastRepeatMode?.name,
      _HomeWidgetKey.repeatCount: ?_lastRepeatCount,
      _HomeWidgetKey.shuffle: ?_lastShuffle,
    };
    await _sendChanges(changes);
  }

  Future<void> _sendChanges(Map<_HomeWidgetKey, Object?> changes) async {
    if (!_hasWidgets) return;
    final shownKeys = _shownKeys;
    final data = <String, Object?>{
      for (final change in changes.entries)
        if (shownKeys.contains(change.key)) change.key.name: change.value,
    };
    if (data.isEmpty) return;
    await _saveAndRefresh(data);
  }
}

/// names shared with the ios widgets.
enum HomeWidgetMediaAction {
  playPause,
  next,
  previous,
  favourite,
}

enum _HomeWidgetKey {
  title,
  message,
  image,
  playing,
  favourite,
  favouriteAsLike,
  repeat,
  repeatCount,
  shuffle,
}
