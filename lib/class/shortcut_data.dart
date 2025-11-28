// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:super_hot_key/super_hot_key.dart';

import 'package:namida/controller/platform/shortcuts_manager/shortcuts_manager.dart';

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

  static final _createdHotkeys = <LogicalKeyboardKey, HotKey>{};

  Future<void> createHotkey(VoidCallback onPressed) async {
    final key = this.key;
    if (key != null) {
      final createdHotkey = await HotKey.create(
        definition: HotKeyDefinition(
          key: key,
          control: ctrl,
          shift: shift,
          meta: meta,
          alt: alt,
        ),
        onPressed: onPressed,
      );
      if (createdHotkey != null) {
        _createdHotkeys[key] = createdHotkey;
      }
    }
  }

  Future<void> disposeHotkey() async {
    final key = this.key;
    if (key != null) {
      final oldHotkey = _createdHotkeys.remove(key);
      oldHotkey?.dispose();
    }
  }

  static Future<void> disposeAllHotkeys() async {
    final copies = _createdHotkeys.values.toList();
    _createdHotkeys.clear();
    for (final h in copies) {
      h.dispose();
    }
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

  String buildKeyLabel() {
    String label = key?.keyLabel ?? '';
    if (label == LogicalKeyboardKey.space.keyLabel) {
      label = 'Space';
    }
    if (alt) {
      label = 'Alt + $label';
    }
    if (meta) {
      label = '⌘ + $label';
    }
    if (shift) {
      label = 'Shift + $label';
    }
    if (ctrl) {
      label = 'Ctrl + $label';
    }
    return label;
  }

  @override
  bool operator ==(covariant ShortcutKeyData other) {
    if (identical(this, other)) return true;

    return other.key == key && other.ctrl == ctrl && other.shift == shift && other.alt == alt && other.meta == meta;
  }

  @override
  int get hashCode {
    return key.hashCode ^ ctrl.hashCode ^ shift.hashCode ^ alt.hashCode ^ meta.hashCode;
  }
}

class ShortcutKeyActivator extends SingleActivator {
  final HotkeyAction? action;
  final String title;
  final LogicalKeyboardKey key;
  final void Function() callback;

  const ShortcutKeyActivator({
    this.action,
    required this.title,
    required this.key,
    super.control = false,
    super.shift = false,
    super.meta = false,
    super.alt = false,
    super.includeRepeats = false,
    required this.callback,
  }) : super(key);
}
