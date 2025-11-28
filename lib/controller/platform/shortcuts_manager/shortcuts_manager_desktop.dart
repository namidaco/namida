// ignore_for_file: unused_element_parameter

part of 'shortcuts_manager.dart';

class _ShortcutsManagerDesktop extends ShortcutsManager {
  @override
  List<ShortcutKeyActivator> get _keysToRegister => __keysToRegister;

  late final __keysToRegister = <ShortcutKeyActivator>[
    // ------------------- playback -------------------
    ShortcutKeyActivator(
      action: HotkeyAction.play_pause,
      key: LogicalKeyboardKey.space,
      callback: Player.inst.togglePlayPause,
      title: "${lang.PLAY}/${lang.PAUSE}",
    ),
    ShortcutKeyActivator(
      action: HotkeyAction.seek_backwards,
      key: LogicalKeyboardKey.arrowLeft,
      callback: Player.inst.seekSecondsBackward,
      title: "<- ${lang.SEEKBAR}",
    ),
    ShortcutKeyActivator(
      action: HotkeyAction.seek_forwards,
      key: LogicalKeyboardKey.arrowRight,
      callback: Player.inst.seekSecondsForward,
      title: "${lang.SEEKBAR} ->",
    ),
    ShortcutKeyActivator(
      action: HotkeyAction.volume_up,
      key: LogicalKeyboardKey.arrowUp,
      control: true,
      includeRepeats: true,
      callback: () {
        final newVol = Player.inst.volumeUp();
        _showSnack(message: "${lang.VOLUME} ↑: ${newVol.roundDecimals(2)}");
      },
      title: "${lang.VOLUME} ↑",
    ),
    ShortcutKeyActivator(
      action: HotkeyAction.volume_down,
      key: LogicalKeyboardKey.arrowDown,
      control: true,
      includeRepeats: true,
      callback: () {
        final newVol = Player.inst.volumeDown();
        _showSnack(message: "${lang.VOLUME} ↓: ${newVol.roundDecimals(2)}");
      },
      title: "${lang.VOLUME} ↓",
    ),
    ShortcutKeyActivator(
      action: HotkeyAction.previous,
      key: LogicalKeyboardKey.arrowLeft,
      control: true,
      callback: Player.inst.previous,
      title: lang.PREVIOUS,
    ),
    ShortcutKeyActivator(
      action: HotkeyAction.next,
      key: LogicalKeyboardKey.arrowRight,
      control: true,
      callback: Player.inst.next,
      title: lang.NEXT,
    ),

    // -------------------
    ShortcutKeyActivator(
      key: LogicalKeyboardKey.keyF,
      control: true,
      callback: () {
        if (_isInSettingsPage()) {
          NamidaSettingSearchBar.globalKey.currentState?.open();
        } else {
          ScrollSearchController.inst.toggleSearch(
            forceOpen: ScrollSearchController.inst.searchBarKey.currentState?.focusNode.hasPrimaryFocus != true,
            instant: true,
          );
        }
      },
      title: lang.SEARCH,
    ),
    ShortcutKeyActivator(
      key: LogicalKeyboardKey.keyR,
      control: true,
      callback: Indexer.inst.refreshLibraryAndCheckForDiff,
      title: lang.REFRESH_LIBRARY,
    ),
    ShortcutKeyActivator(
      key: LogicalKeyboardKey.keyE,
      control: true,
      callback: () {
        _executeMiniPlayers(
          (localPlayer, ytPlayer, ytQueueChip) {
            if (ytPlayer != null) {
              if (ytPlayer.isExpanded) {
                ytPlayer.animateToState(false);
              } else {
                ytPlayer.animateToState(true);
              }
            } else {
              if (localPlayer.isMinimized) {
                localPlayer.snapToExpanded();
              } else {
                localPlayer.snapToMini();
              }
            }
          },
        );
      },
      title: lang.OPEN_MINIPLAYER,
    ),
    ShortcutKeyActivator(
      key: LogicalKeyboardKey.keyQ,
      control: true,
      callback: openPlayerQueue,
      title: lang.OPEN_QUEUE,
    ),
    ShortcutKeyActivator(
      key: LogicalKeyboardKey.keyL,
      control: true,
      callback: () {
        settings.save(enableLyrics: !settings.enableLyrics.value);
        final currentItem = Player.inst.currentItem.value;
        if (currentItem != null) {
          Lyrics.inst.updateLyrics(currentItem);
        }
      },
      title: lang.LYRICS,
    ),
    ShortcutKeyActivator(
      key: LogicalKeyboardKey.keyL,
      control: true,
      shift: true,
      callback: () {
        final fullscreenState = Lyrics.inst.lrcViewKeyFullscreen.currentState;
        if (fullscreenState != null) {
          fullscreenState.exitFullScreen();
        } else {
          Lyrics.inst.lrcViewKey.currentState?.enterFullScreen();
        }
      },
      title: "${lang.LYRICS} (${lang.FULLSCREEN})",
    ),
    ShortcutKeyActivator(
      key: LogicalKeyboardKey.keyP,
      control: true,
      shift: true,
      callback: () {
        if (!_isInSettingsPage()) {
          const SettingsPage().navigate();
        }

        Timer(
          Duration(milliseconds: 100),
          () => NamidaSettingSearchBar.globalKey.currentState?.open(),
        );
      },
      title: lang.SETTINGS,
    ),
    ShortcutKeyActivator(
      key: LogicalKeyboardKey.keyS,
      control: true,
      shift: true,
      callback: () {
        final shuffleAll = settings.player.shuffleAllTracks.value;
        Player.inst.shuffleTracks(shuffleAll);
        _showSnack(
          message: "${shuffleAll ? lang.SHUFFLE_ALL : lang.SHUFFLE_NEXT}: ${lang.DONE}",
        );
      },
      title: lang.SHUFFLE,
    ),
    ShortcutKeyActivator(
      key: LogicalKeyboardKey.tab,
      control: true,
      callback: () {
        final e = settings.player.repeatMode.value.nextElement(RepeatMode.values);
        settings.player.save(repeatMode: e);
        _showSnack(
          message: "${lang.REPEAT_MODE}: ${e.buildText()}",
        );
      },
      title: lang.REPEAT_MODE,
    ),
    // -----------------
    for (int i = 1; i <= 9; i++)
      ShortcutKeyActivator(
        key: LogicalKeyboardKey(0x00000000030 + i),
        control: true,
        callback: () {
          try {
            final tab = settings.libraryTabs.value[i - 1];
            ScrollSearchController.inst.animatePageController(tab);
          } catch (_) {
            // -- index larger than tabs length
          }
        },
        title: lang.LIBRARY_TABS,
      ),

    // ================
    ShortcutKeyActivator(
      key: LogicalKeyboardKey.f11,
      callback: () async {
        final isFullscreen = await windowManager.isFullScreen();
        windowManager.setFullScreen(!isFullscreen);
      },
      title: lang.FULLSCREEN,
    ),
    ShortcutKeyActivator(
      key: LogicalKeyboardKey.escape,
      callback: NamidaNavigator.inst.back,
      title: lang.EXIT,
    ),
  ];

  FocusAttachment? _attachment;

  @override
  void init() {
    _attachment = FocusManager.instance.rootScope.attach(
      null,
      onKeyEvent: (node, event) {
        for (final ShortcutActivator activator in bindings.keys) {
          if (activator.accepts(event, HardwareKeyboard.instance)) {
            bindings[activator]!.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void initUserShortcutsFromSettings() async {
    for (final s in settings.shortcuts.shortcuts.value.entries) {
      final data = s.value;
      data?.createHotkey(s.key.toSimpleCallback());
    }
  }

  @override
  void setUserShortcut({required HotkeyAction action, required ShortcutKeyData? data}) {
    final oldShortcut = settings.shortcuts.shortcuts.value[action];
    oldShortcut?.disposeHotkey();

    data?.createHotkey(action.toSimpleCallback());
    settings.shortcuts.save(action: action, data: data);
  }

  @override
  void dispose() {
    _attachment?.detach();
  }

  @override
  void openPlayerQueue() {
    _executeMiniPlayers(
      (localPlayer, ytPlayer, ytQueueChip) {
        if (ytPlayer != null) {
          if (!ytPlayer.isExpanded) ytPlayer.animateToState(true);
          _executeYtQueueSheet(ytQueueChip, (chip) => chip.toggleSheet());
        } else {
          if (localPlayer.isInQueue) {
            localPlayer.snapToExpanded();
          } else {
            localPlayer.snapToQueue();
          }
        }
      },
    );
  }

  void _executeMiniPlayers(
      void Function(
        MiniPlayerController localPlayer,
        NamidaYTMiniplayerState? ytPlayer,
        YTMiniplayerQueueChipState? ytQueueChip,
      ) callback) {
    callback(
      MiniPlayerController.inst,
      MiniPlayerController.inst.ytMiniplayerKey.currentState,
      NamidaNavigator.inst.ytQueueSheetKey.currentState,
    );
  }

  void _executeYtQueueSheet(YTMiniplayerQueueChipState? ytQueueChip, void Function(YTMiniplayerQueueChipState ytQueueChip) callback) {
    final ytQueue = NamidaNavigator.inst.ytQueueSheetKey.currentState;
    if (ytQueue != null) {
      callback(ytQueue);
      return;
    }

    Timer(
      const Duration(milliseconds: 100),
      () {
        final ytQueue = NamidaNavigator.inst.ytQueueSheetKey.currentState;
        if (ytQueue != null) callback(ytQueue);
      },
    );
  }

  void _showSnack({required String message}) {
    snackyy(
      icon: Broken.flash_1,
      title: lang.SHORTCUTS,
      message: message,
      borderColor: Colors.green.withValues(alpha: 0.6),
      top: false,
    );
  }

  bool _isInSettingsPage() {
    final currentRouteType = NamidaNavigator.inst.currentRoute?.route;
    final isInSettings = currentRouteType == RouteType.SETTINGS_page || currentRouteType == RouteType.SETTINGS_subpage;
    return isInSettings;
  }
}
