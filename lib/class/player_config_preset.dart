import 'package:basic_audio_handler/basic_audio_handler.dart';

class PlayerConfigPreset {
  final String name;
  final PlayerConfig config;

  const PlayerConfigPreset({
    required this.name,
    required this.config,
  });

  PlayerConfigPreset copyWith({String? name, PlayerConfig? config}) {
    return PlayerConfigPreset(name: name ?? this.name, config: config ?? this.config);
  }

  static PlayerConfigPreset? fromMap(Map<String, dynamic> map) {
    final name = map['name'];
    final config = map['config'];
    if (name is! String || config is! Map<String, dynamic>) return null;
    return PlayerConfigPreset(name: name, config: PlayerConfig.fromMap(config));
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'config': config.toMap(),
  };
}
