import 'package:vibration/vibration.dart';

class VibratorController {
  const VibratorController._();

  static verylight() {
    _vibrate(10, 10);
  }

  static light() {
    _vibrate(10, 20);
  }

  static medium() {
    _vibrate(20, 40);
  }

  static high() {
    _vibrate(20, 50);
  }

  static veryhigh() {
    _vibrate(20, 80);
  }

  static _vibrate(int duration, int amplitude) async {
    try {
      await Vibration.vibrate(duration: duration, amplitude: amplitude);
    } catch (_) {}
  }
}
