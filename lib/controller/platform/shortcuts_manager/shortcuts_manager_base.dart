// ignore_for_file: constant_identifier_names

part of 'shortcuts_manager.dart';

abstract class ShortcutsManager {
  static ShortcutsManager? platform() {
    return NamidaPlatformBuilder.init(
      android: () => null,
      ios: () => null,
      windows: () => _ShortcutsManagerDesktop(),
      linux: () => _ShortcutsManagerDesktop(),
      macos: () => _ShortcutsManagerDesktop(),
    );
  }

  late final Map<ShortcutKeyActivator, VoidCallback> bindings = Map.fromEntries(_keysToRegister.map(
    (e) => MapEntry(
      e,
      e.callback,
    ),
  ));

  @protected
  List<ShortcutKeyActivator> get _keysToRegister;
  void init();
  void initUserShortcutsFromSettings();
  void setUserShortcut({required HotkeyAction action, required ShortcutKeyData? data});
  void dispose();

  void openPlayerQueue();
}

enum HotkeyAction {
  play_pause,
  seek_backwards,
  seek_forwards,
  volume_up,
  volume_down,
  previous,
  next,
  ;

  void Function() toSimpleCallback() {
    return switch (this) {
      HotkeyAction.play_pause => Player.inst.togglePlayPause,
      HotkeyAction.seek_backwards => Player.inst.seekSecondsBackward,
      HotkeyAction.seek_forwards => Player.inst.seekSecondsForward,
      HotkeyAction.volume_up => Player.inst.volumeUp,
      HotkeyAction.volume_down => Player.inst.volumeDown,
      HotkeyAction.previous => Player.inst.previous,
      HotkeyAction.next => Player.inst.next,
    };
  }
}
