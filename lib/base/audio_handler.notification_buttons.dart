part of 'audio_handler.dart';

// by claude
mixin _NotificationButtonsMixin<Q extends Playable> on BasicAudioHandler<Q> {
  /// android 13+ places play/pause, previous & next itself, custom buttons only follow them.
  static final _isSystemLayout = NamidaFeaturesAvailablity.android13and_plus.resolve();
  static const _kMaxLegacyLayoutButtons = 5;

  void toggleItemFavourite(Q item);
  PlayerRepeatMode userCycleRepeatMode();
  bool _isItemFavourite(Q item);

  List<NotificationButton> _notificationButtons = const [];

  void _initNotificationButtons() {
    _notificationButtons = _resolveNotificationButtons(settings.notificationButtons.value);
    settings.notificationButtons.addListener(_onNotificationButtonsChanged);
    settings.notificationButtonsPlaylist.addListener(_onNotificationPlaylistsChanged);
    settings.notificationButtonsYTPlaylist.addListener(_onNotificationPlaylistsChanged);
    PlaylistController.inst.playlistsMap.addListener(_onNotificationPlaylistsChanged);
    YoutubePlaylistController.inst.playlistsMap.addListener(_onNotificationPlaylistsChanged);
    settings.player.seekDurationInSeconds.addListener(_onSeekDurationChanged);
    settings.player.isSeekDurationPercentage.addListener(_onSeekDurationChanged);
    sleepTimerConfig.addListener(_onSleepTimerConfigChanged);
    numberOfRepeats.addListener(_onNumberOfRepeatsChanged);
  }

  static List<NotificationButton> _resolveNotificationButtons(List<NotificationButton> configured) {
    if (!_isSystemLayout) {
      final buttons = configured.ensurePlayPause();
      if (buttons.length <= _kMaxLegacyLayoutButtons) return buttons;
      final playPauseIndex = buttons.indexOf(NotificationButton.playPause);
      final start = (playPauseIndex - 2).withMinimum(0).withMaximum(buttons.length - _kMaxLegacyLayoutButtons);
      return buttons.sublist(start, start + _kMaxLegacyLayoutButtons);
    }
    return [
      ...NotificationButton.transportButtons,
      ...configured.where((button) => !button.isTransport),
    ];
  }

  void _onNotificationButtonsChanged() {
    _notificationButtons = _resolveNotificationButtons(settings.notificationButtons.value);
    _refreshNotificationButtons();
  }

  void _refreshNotificationButtonsIfShown(NotificationButton button) {
    if (_notificationButtons.contains(button)) _refreshNotificationButtons();
  }

  void _refreshNotificationButtons() {
    final item = currentItem.value;
    if (item == null) return;
    final isFavourite = _isItemFavourite(item);
    final built = _buildNotificationControls(item, isFavourite);
    final state = playbackState.value.copyWith(controls: built.controls, androidCompactActionIndices: built.compactIndices);
    playbackState.add(state);
  }

  void _onSeekDurationChanged() {
    final buttons = _notificationButtons;
    final isSeekShown = buttons.contains(NotificationButton.seekBackward) || buttons.contains(NotificationButton.seekForward);
    if (isSeekShown) _refreshNotificationButtons();
  }

  void _onNumberOfRepeatsChanged() {
    if (displayRepeatMode == PlayerRepeatMode.forNtimes) _refreshNotificationButtonsIfShown(NotificationButton.repeatMode);
  }

  bool _wasSleepTimerActive = false;

  void _onSleepTimerConfigChanged() {
    final isActive = _isSleepTimerActive();
    if (isActive == _wasSleepTimerActive) return;
    _wasSleepTimerActive = isActive;
    _refreshNotificationButtonsIfShown(NotificationButton.sleepTimer);
  }

  bool _isSleepTimerActive() {
    final config = sleepTimerConfig.value;
    return config.enableSleepAfterMins || config.enableSleepAfterItems;
  }

  PlaybackState _transformEvent(PlaybackEvent event, Playable? item, bool isFavourite, int itemIndex) {
    final built = _buildNotificationControls(item, isFavourite);
    return transformEvent(event, itemIndex, built.controls, built.compactIndices);
  }

  ({List<MediaControl> controls, List<int> compactIndices}) _buildNotificationControls(Playable? item, bool isFavourite) {
    final controls = <MediaControl>[];
    int playPauseIndex = 0;
    for (final button in _notificationButtons) {
      final control = _buttonToControl(button, item, isFavourite);
      if (control == null) continue;
      if (button == NotificationButton.playPause) playPauseIndex = controls.length;
      controls.add(control);
    }
    final compactIndices = _compactIndicesAround(playPauseIndex, controls.length);
    return (controls: controls, compactIndices: compactIndices);
  }

  static const _kCompactIndicesForShortLength = [
    <int>[],
    [0],
    [0, 1],
    [0, 1, 2],
  ];
  static const _kCompactIndicesByStart = [
    [0, 1, 2],
    [1, 2, 3],
    [2, 3, 4],
  ];

  /// the collapsed notification shows the 3 controls around play/pause.
  static List<int> _compactIndicesAround(int centerIndex, int length) {
    if (length <= 3) return _kCompactIndicesForShortLength[length];
    final start = (centerIndex - 1).withMinimum(0).withMaximum(length - 3);
    return _kCompactIndicesByStart[start];
  }

  MediaControl? _buttonToControl(NotificationButton button, Playable? item, bool isFavourite) {
    return switch (button) {
      NotificationButton.previous => MediaControl(androidIcon: 'drawable/previous', label: lang.previous, action: MediaAction.skipToPrevious),
      NotificationButton.playPause => _playPauseControl(),
      NotificationButton.next => MediaControl(androidIcon: 'drawable/next', label: lang.next, action: MediaAction.skipToNext),
      NotificationButton.favourite => _favouriteControl(item, isFavourite),
      NotificationButton.stop => _customControl(button, 'drawable/stop', lang.stop),
      NotificationButton.shuffle => _customControl(button, isQueueShuffled ? 'drawable/shuffle_on' : 'drawable/shuffle', lang.shuffle),
      NotificationButton.repeatMode => _repeatModeControl(),
      NotificationButton.seekBackward => _seekControl(button, 'backward', lang.seekBackward),
      NotificationButton.seekForward => _seekControl(button, 'forward', lang.seekForward),
      NotificationButton.sleepTimer => _sleepTimerControl(),
      NotificationButton.addToPlaylist => _playlistControl(item),
      NotificationButton.bookmark => _customControl(button, 'drawable/bookmark', lang.addBookmark),
    };
  }

  MediaControl _playPauseControl() {
    if (playWhenReady.value) return MediaControl(androidIcon: 'drawable/pause', label: lang.pause, action: MediaAction.pause);
    return MediaControl(androidIcon: 'drawable/play', label: lang.play, action: MediaAction.play);
  }

  MediaControl _sleepTimerControl() {
    final isActive = _isSleepTimerActive();
    final icon = isActive ? 'drawable/timer_1_bold' : 'drawable/timer_1';
    return _customControl(NotificationButton.sleepTimer, icon, lang.sleepTimer);
  }

  static MediaControl _customControl(NotificationButton button, String androidIcon, String label) {
    return MediaControl(
      androidIcon: androidIcon,
      label: label,
      action: MediaAction.custom,
      customAction: CustomMediaAction(name: button.name),
    );
  }

  static MediaControl _favouriteControl(Playable? item, bool isFavourite) {
    final isLike = item is YoutubeID && YtVideoLikeManager.preferLikeOverFavourite;
    final String icon;
    final String label;
    if (isLike) {
      icon = isFavourite ? 'drawable/unlike' : 'drawable/like';
      label = isFavourite ? lang.liked : lang.like;
    } else {
      icon = isFavourite ? 'drawable/unheart' : 'drawable/heart';
      label = isFavourite ? lang.removeFromFavourites : lang.addToFavourites;
    }
    return _customControl(NotificationButton.favourite, icon, label);
  }

  MediaControl _repeatModeControl() {
    final repeatMode = displayRepeatMode;
    final icon = switch (repeatMode) {
      PlayerRepeatMode.none => 'drawable/repeate_music',
      PlayerRepeatMode.one => 'drawable/repeate_one_bold',
      PlayerRepeatMode.forNtimes => _getRepeatCountIcon(),
      PlayerRepeatMode.all => 'drawable/repeat_bold',
      PlayerRepeatMode.allShuffle => 'drawable/repeat_circle_bold',
    };
    final label = repeatMode.buildText(numberOfRepeats: numberOfRepeats.value);
    return _customControl(NotificationButton.repeatMode, icon, label);
  }

  /// numbered icons exist up to 9.
  String _getRepeatCountIcon() {
    final count = numberOfRepeats.value;
    if (count > 9) return 'drawable/repeat_n_9plus';
    final shownCount = count.withMinimum(1);
    return 'drawable/repeat_n_$shownCount';
  }

  static MediaControl _seekControl(NotificationButton button, String direction, String label) {
    final icon = _getSeekIcon(direction);
    return _customControl(button, icon, label);
  }

  /// numbered icons exist only for 5, 10 & 15 seconds.
  static String _getSeekIcon(String direction) {
    if (!settings.player.isSeekDurationPercentage.value) {
      final seconds = settings.player.seekDurationInSeconds.value;
      if (seconds == 5 || seconds == 10 || seconds == 15) return 'drawable/${direction}_${seconds}_seconds';
    }
    return 'drawable/$direction';
  }

  MediaControl? _playlistControl(Playable? item) {
    final membership = _getPlaylistMembership(item);
    if (membership == null) return null;
    final icon = membership.isInside ? 'drawable/music_library_2_bold' : 'drawable/music_library_2';
    return _customControl(NotificationButton.addToPlaylist, icon, membership.name);
  }

  Playable? _playlistMembershipItem;
  _PlaylistMembership? _playlistMembership;
  bool _isPlaylistMembershipStale = true;

  void _onNotificationPlaylistsChanged() {
    _isPlaylistMembershipStale = true;
    _refreshNotificationButtonsIfShown(NotificationButton.addToPlaylist);
  }

  /// cached since checking a playlist scans all of its items.
  _PlaylistMembership? _getPlaylistMembership(Playable? item) {
    if (!_isPlaylistMembershipStale && identical(item, _playlistMembershipItem)) return _playlistMembership;
    _playlistMembershipItem = item;
    _isPlaylistMembershipStale = false;
    return _playlistMembership = item?.execute<_PlaylistMembership?>(
      selectable: (finalItem) {
        final playlist = _getLocalPlaylist();
        if (playlist == null) return null;
        final track = finalItem.track;
        final isInside = playlist.tracks.any((e) => e.track == track);
        return (name: playlist.name, isInside: isInside);
      },
      youtubeID: (finalItem) {
        final playlist = _getYoutubePlaylist();
        if (playlist == null) return null;
        final videoId = finalItem.id;
        final isInside = playlist.tracks.any((e) => e.id == videoId);
        return (name: playlist.name, isInside: isInside);
      },
    );
  }

  static LocalPlaylist? _getLocalPlaylist() {
    final name = settings.notificationButtonsPlaylist.value;
    if (name == null) return null;
    return PlaylistController.inst.getPlaylist(name);
  }

  static YoutubePlaylist? _getYoutubePlaylist() {
    final name = settings.notificationButtonsYTPlaylist.value;
    if (name == null) return null;
    return YoutubePlaylistController.inst.getPlaylist(name);
  }

  /// returns false when [name] isn't a notification button.
  Future<bool> _onNotificationButtonPressed(String name) async {
    final button = NotificationButton.values.getEnum(name);
    if (button == null) return false;
    switch (button) {
      case NotificationButton.previous || NotificationButton.playPause || NotificationButton.next:
        return false;
      case NotificationButton.favourite:
        final item = currentItem.value;
        if (item != null) toggleItemFavourite(item);
      case NotificationButton.stop:
        await stop();
        if (Platform.isAndroid) await AudioService.forceStop();
      case NotificationButton.shuffle:
        final shuffled = !settings.player.shuffleQueue.value;
        settings.player.shuffleQueue.save(shuffled);
      case NotificationButton.repeatMode:
        userCycleRepeatMode();
      case NotificationButton.seekBackward:
        await Player.inst.seekSecondsBackward();
      case NotificationButton.seekForward:
        await Player.inst.seekSecondsForward();
      case NotificationButton.sleepTimer:
        _toggleSleepTimer();
      case NotificationButton.addToPlaylist:
        await _toggleCurrentItemInPlaylist();
      case NotificationButton.bookmark:
        await BookmarksController.inst.addAtCurrentPosition();
    }
    return true;
  }

  /// starts with the first preset since there is no dialog to pick from.
  void _toggleSleepTimer() {
    if (_isSleepTimerActive()) {
      resetSleepTimer();
      return;
    }
    final presets = settings.player.sleepTimerPresetsMin.value;
    if (presets.isEmpty) return;
    updateSleepTimerValues(enableSleepAfterMins: true, sleepAfterMin: presets.first);
  }

  Future<void> _toggleCurrentItemInPlaylist() async {
    await currentItem.value?.executeAsync(
      selectable: (finalItem) async {
        final playlist = _getLocalPlaylist();
        if (playlist != null) await PlaylistController.inst.toggleTrackInPlaylist(playlist, finalItem.track);
      },
      youtubeID: (finalItem) async {
        final playlist = _getYoutubePlaylist();
        if (playlist != null) await YoutubePlaylistController.inst.toggleVideoInPlaylist(playlist, finalItem.id);
      },
    );
  }
}

typedef _PlaylistMembership = ({String name, bool isInside});
