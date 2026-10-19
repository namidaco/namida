import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/shortcut_data.dart';
import 'package:namida/controller/platform/shortcuts_manager/shortcuts_manager.dart';

void main() {
  ShortcutKeyActivator activator(LogicalKeyboardKey key, {bool control = false, bool alt = false, bool shift = false}) {
    return ShortcutKeyActivator(
      category: ShortcutCategory.others,
      title: () => '',
      key: key,
      control: control,
      alt: alt,
      shift: shift,
      callback: () {},
    );
  }

  KeyDownEvent down(LogicalKeyboardKey key, String? character) {
    return KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: key,
      character: character,
      timeStamp: Duration.zero,
    );
  }

  Future<void> pumpField(WidgetTester tester, {required bool focused}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: TextField(
            autofocus: focused,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('canTypeText', () {
    test('windows: plain, shift & AltGr (ctrl+alt) type, ctrl or alt alone dont', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(const ShortcutKeyData(key: LogicalKeyboardKey.keyP).canTypeText(), true);
      expect(const ShortcutKeyData(key: LogicalKeyboardKey.keyP, shift: true).canTypeText(), true);
      expect(const ShortcutKeyData(key: LogicalKeyboardKey.digit1, ctrl: true, alt: true).canTypeText(), true);
      expect(const ShortcutKeyData(key: LogicalKeyboardKey.keyP, ctrl: true).canTypeText(), false);
      expect(const ShortcutKeyData(key: LogicalKeyboardKey.keyP, alt: true).canTypeText(), false);
      expect(const ShortcutKeyData(key: LogicalKeyboardKey.keyP, meta: true).canTypeText(), false);
    });

    test('linux: AltGr is its own key, ctrl+alt never types', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(const ShortcutKeyData(key: LogicalKeyboardKey.space).canTypeText(), true);
      expect(const ShortcutKeyData(key: LogicalKeyboardKey.digit1, ctrl: true, alt: true).canTypeText(), false);
      expect(const ShortcutKeyData(key: LogicalKeyboardKey.keyH, ctrl: true).canTypeText(), false);
    });

    test('macos: option types text', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(const ShortcutKeyData(key: LogicalKeyboardKey.digit1, alt: true).canTypeText(), true);
      expect(const ShortcutKeyData(key: LogicalKeyboardKey.digit1, ctrl: true, alt: true).canTypeText(), false);
    });

    test('non character keys never type', () {
      for (final platform in const [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(const ShortcutKeyData(key: LogicalKeyboardKey.escape).canTypeText(), false);
        expect(const ShortcutKeyData(key: LogicalKeyboardKey.f11).canTypeText(), false);
        expect(const ShortcutKeyData(key: LogicalKeyboardKey.arrowLeft).canTypeText(), false);
        expect(const ShortcutKeyData(key: LogicalKeyboardKey.numpadAdd, ctrl: true).canTypeText(), false);
        expect(const ShortcutKeyData().canTypeText(), false);
      }
    });
  });

  group('yieldsToTyping', () {
    testWidgets('windows AltGr+1 typing | goes to the focused text field', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await pumpField(tester, focused: true);
      expect(ShortcutsManager.isTextFieldFocused(), true);

      final rating = activator(LogicalKeyboardKey.digit1, control: true, alt: true);
      expect(rating.yieldsToTyping(down(LogicalKeyboardKey.digit1, '|')), true);
      // -- real ctrl+alt on a layout without AltGr text: no character, shortcut runs
      expect(rating.yieldsToTyping(down(LogicalKeyboardKey.digit1, null)), false);

      final playPause = activator(LogicalKeyboardKey.space);
      expect(playPause.yieldsToTyping(down(LogicalKeyboardKey.space, ' ')), true);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('command shortcuts and non character keys keep working while typing', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await pumpField(tester, focused: true);

      // -- linux reports the keyval character even with ctrl held
      final favourite = activator(LogicalKeyboardKey.keyH, control: true);
      expect(favourite.yieldsToTyping(down(LogicalKeyboardKey.keyH, 'h')), false);

      final back = activator(LogicalKeyboardKey.escape);
      expect(back.yieldsToTyping(down(LogicalKeyboardKey.escape, '\x1b')), false);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('nothing yields without a focused text field or an open dialog', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await pumpField(tester, focused: false);
      expect(ShortcutsManager.isTextFieldFocused(), false);

      final rating = activator(LogicalKeyboardKey.digit1, control: true, alt: true);
      expect(rating.yieldsToTyping(down(LogicalKeyboardKey.digit1, '|')), false);
      final playPause = activator(LogicalKeyboardKey.space);
      expect(playPause.yieldsToTyping(down(LogicalKeyboardKey.space, ' ')), false);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
