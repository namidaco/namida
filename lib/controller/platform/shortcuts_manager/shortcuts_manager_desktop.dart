// ignore_for_file: unused_element_parameter

part of 'shortcuts_manager.dart';

class _ShortcutsManagerDesktop extends ShortcutsManager {
  @override
  List<ShortcutKeyData> get _keysToRegister => __keysToRegister;

  late final __keysToRegister = <ShortcutKeyData>[
    // ------------------- playback -------------------
    ShortcutKeyData(
      key: LogicalKeyboardKey.space,
      callback: Player.inst.togglePlayPause,
      title: "${lang.PLAY}/${lang.PAUSE}",
    ),
    ShortcutKeyData(
      key: LogicalKeyboardKey.arrowLeft,
      callback: Player.inst.seekSecondsBackward,
      title: "<- ${lang.SEEKBAR}",
    ),
    ShortcutKeyData(
      key: LogicalKeyboardKey.arrowRight,
      callback: Player.inst.seekSecondsForward,
      title: "${lang.SEEKBAR} ->",
    ),
    ShortcutKeyData(
      key: LogicalKeyboardKey.arrowUp,
      control: true,
      includeRepeats: true,
      callback: () {
        final newVol = Player.inst.volumeUp();
        _showSnack(message: "${lang.VOLUME} ↑: ${newVol.roundDecimals(2)}");
      },
      title: "${lang.VOLUME} ↑",
    ),
    ShortcutKeyData(
      key: LogicalKeyboardKey.arrowDown,
      control: true,
      includeRepeats: true,
      callback: () {
        final newVol = Player.inst.volumeDown();
        _showSnack(message: "${lang.VOLUME} ↓: ${newVol.roundDecimals(2)}");
      },
      title: "${lang.VOLUME} ↓",
    ),
    ShortcutKeyData(
      key: LogicalKeyboardKey.arrowLeft,
      control: true,
      callback: Player.inst.previous,
      title: lang.PREVIOUS,
    ),
    ShortcutKeyData(
      key: LogicalKeyboardKey.arrowRight,
      control: true,
      callback: Player.inst.next,
      title: lang.NEXT,
    ),

    // -------------------
    ShortcutKeyData(
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
    ShortcutKeyData(
      key: LogicalKeyboardKey.keyR,
      control: true,
      callback: Indexer.inst.refreshLibraryAndCheckForDiff,
      title: lang.REFRESH_LIBRARY,
    ),
    ShortcutKeyData(
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
    ShortcutKeyData(
      key: LogicalKeyboardKey.keyQ,
      control: true,
      callback: openPlayerQueue,
      title: lang.OPEN_QUEUE,
    ),
    ShortcutKeyData(
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
    ShortcutKeyData(
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
    ShortcutKeyData(
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
    ShortcutKeyData(
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
    ShortcutKeyData(
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
      ShortcutKeyData(
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
    ShortcutKeyData(
      key: LogicalKeyboardKey.f11,
      callback: () async {
        final isFullscreen = await windowManager.isFullScreen();
        windowManager.setFullScreen(!isFullscreen);
      },
      title: lang.FULLSCREEN,
    ),
    ShortcutKeyData(
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
