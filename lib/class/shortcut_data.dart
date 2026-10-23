import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/shortcuts_manager/shortcuts_manager.dart';
import 'package:namida/core/extensions.dart';

class ShortcutKeyData {
  final LogicalKeyboardKey? key;
  final bool ctrl;
  final bool shift;
  final bool alt;
  final bool meta;

  const ShortcutKeyData({
    this.key,
    this.ctrl = false,
    this.shift = false,
    this.meta = false,
    this.alt = false,
  });

  bool canTypeText() {
    final key = this.key;
    return key != null && _canTypeText(key, control: ctrl, alt: alt, meta: meta);
  }

  bool isSimilarTo(ShortcutKeyData other) {
    return this == other;
  }

  Map<String, dynamic>? toMap() {
    if (key == null) return null;
    return <String, dynamic>{
      'key': key?.keyId,
      if (ctrl) 'ctrl': ctrl,
      if (shift) 'shift': shift,
      if (alt) 'alt': alt,
      if (meta) 'meta': meta,
    };
  }

  factory ShortcutKeyData.fromMap(Map<String, dynamic> map) {
    return ShortcutKeyData(
      key: map['key'] != null ? LogicalKeyboardKey(map['key']) : null,
      ctrl: map['ctrl'] as bool? ?? false,
      shift: map['shift'] as bool? ?? false,
      alt: map['alt'] as bool? ?? false,
      meta: map['meta'] as bool? ?? false,
    );
  }
  factory ShortcutKeyData.fromShortcutKeyActivator(ShortcutKeyActivator e) {
    return ShortcutKeyData(
      key: e.key,
      ctrl: e.control,
      shift: e.shift,
      meta: e.meta,
      alt: e.alt,
    );
  }

  static final _shortKeyLabels = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.space: 'Space', LogicalKeyboardKey.escape: 'Esc', //
    LogicalKeyboardKey.arrowLeft: '←', LogicalKeyboardKey.arrowRight: '→', LogicalKeyboardKey.arrowUp: '↑', LogicalKeyboardKey.arrowDown: '↓', //
    LogicalKeyboardKey.numpadAdd: '+', LogicalKeyboardKey.numpadSubtract: '-', //
  };

  /// apple keyboards print symbols on their modifier keys.
  List<String> buildModifierLabels() {
    final isAppleKeyboard = HardwareKeyboardUtils.isPrimaryModifierMeta;
    return [
      if (ctrl) isAppleKeyboard ? '⌃' : 'Ctrl',
      if (shift) isAppleKeyboard ? '⇧' : 'Shift',
      if (meta) '⌘',
      if (alt) isAppleKeyboard ? '⌥' : 'Alt',
    ];
  }

  String? buildKeyText() {
    final key = this.key;
    if (key == null) return null;
    return _shortKeyLabels[key] ?? key.keyLabel;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ShortcutKeyData) return false;

    return other.key == key && other.ctrl == ctrl && other.shift == shift && other.alt == alt && other.meta == meta;
  }

  @override
  int get hashCode {
    return Object.hash(key, ctrl, shift, alt, meta);
  }
}

class ShortcutKeyActivator extends SingleActivator {
  final HotkeyAction? action;
  final ShortcutCategory category;
  final String Function() title;
  final LogicalKeyboardKey key;
  final void Function() callback;

  /// [control] is the primary modifier, cmd on apple keyboards.
  /// [isControlLiteral] keeps ctrl there, for keys where cmd belongs to the system (quit, hide, spotlight, app switcher).
  ShortcutKeyActivator({
    this.action,
    required this.category,
    required this.title,
    required this.key,
    bool control = false,
    bool isControlLiteral = false,
    super.shift = false,
    bool meta = false,
    super.alt = false,
    super.includeRepeats = false,
    required this.callback,
  }) : super(
         key,
         control: control && !_isControlMappedToMeta(control, isControlLiteral),
         meta: meta || _isControlMappedToMeta(control, isControlLiteral),
       );

  static bool _isControlMappedToMeta(bool control, bool isControlLiteral) => control && !isControlLiteral && HardwareKeyboardUtils.isPrimaryModifierMeta;

  /// better alternative to [SingleActivator.accepts]. the main key itself should be matched outside
  bool acceptsMatchedTrigger(KeyEvent event, HardwareKeyboard state) {
    if (event is! KeyDownEvent && !(includeRepeats && event is KeyRepeatEvent)) return false;
    return control == state.isControlPressed && shift == state.isShiftPressed && alt == state.isAltPressed && meta == state.isMetaPressed;
  }

  /// ex: `AltGr+1` types `|` on some layouts, but windows reports it as `Ctrl+Alt+1`.
  bool yieldsToTyping(KeyEvent event) {
    if (event.character == null) return false;
    if (!_canTypeText(key, control: control, alt: alt, meta: meta)) return false;
    if (ShortcutsManager.isTextFieldFocused()) return true;

    // -- dialogs & sheets are mostly typing, a field that lost focus there shouldn't turn AltGr text into an action
    final isModifiedCharacter = control || alt;
    if (!isModifiedCharacter) return false;
    final navigator = NamidaNavigator.inst;
    return navigator.openedDialogsCount > 0 || navigator.openedSheetsCount > 0;
  }
}

bool _canTypeText(LogicalKeyboardKey key, {required bool control, required bool alt, required bool meta}) {
  final isCharacterKey = (key.keyId & LogicalKeyboardKey.planeMask) == LogicalKeyboardKey.unicodePlane;
  if (!isCharacterKey || meta) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows => control == alt, // -- AltGr is reported as Ctrl+Alt
    TargetPlatform.macOS || TargetPlatform.iOS => !control, // -- Option types text
    TargetPlatform.linux || TargetPlatform.android || TargetPlatform.fuchsia => !control && !alt,
  };
}

enum ShortcutCategory {
  playback,
  track,
  others,
  lyrics,
}
