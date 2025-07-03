import 'package:flutter/services.dart';

import 'package:vibration/vibration.dart';

import 'package:namida/controller/settings_controller.dart';

class VibratorController {
  const VibratorController._();

  static final _intNormal = _VibratorInterfaceNormal._();
  static final _intHaptic = _VibratorInterfaceHapticFeedback._();
  static _VibratorInterface get _interface => settings.hapticFeedbackOverVibration.value ? _intHaptic : _intNormal;

  static Future<void> verylight() => _interface.verylight();
  static Future<void> light() => _interface.light();
  static Future<void> medium() => _interface.medium();
  static Future<void> high() => _interface.high();
  static Future<void> veryhigh() => _interface.veryhigh();
}

class _VibratorInterfaceNormal extends _VibratorInterface {
  const _VibratorInterfaceNormal._();

  @override
  Future<void> verylight() => _vibrate(10, 10);
  @override
  Future<void> light() => _vibrate(10, 20);
  @override
  Future<void> medium() => _vibrate(20, 40);
  @override
  Future<void> high() => _vibrate(20, 50);
  @override
  Future<void> veryhigh() => _vibrate(20, 80);

  Future<void> _vibrate(int duration, int amplitude) async {
    try {
      await Vibration.vibrate(duration: duration, amplitude: amplitude);
    } catch (_) {}
  }
}

class _VibratorInterfaceHapticFeedback extends _VibratorInterface {
  const _VibratorInterfaceHapticFeedback._();

  @override
  Future<void> verylight() => HapticFeedback.lightImpact();
  @override
  Future<void> light() => HapticFeedback.lightImpact();
  @override
  Future<void> medium() => HapticFeedback.mediumImpact();
  @override
  Future<void> high() => HapticFeedback.heavyImpact();
  @override
  Future<void> veryhigh() => HapticFeedback.heavyImpact();
}

abstract class _VibratorInterface {
  const _VibratorInterface();

  Future<void> verylight();
  Future<void> light();
  Future<void> medium();
  Future<void> high();
  Future<void> veryhigh();
}
