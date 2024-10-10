import 'dart:io';

class NamidaPlatformBuilder {
  static T init<T>({required T Function() android, required T Function() windows}) {
    return switch (Platform.operatingSystem) {
      'windows' => windows(),
      'android' => android(),
      _ => throw UnimplementedError(),
    };
  }
}
