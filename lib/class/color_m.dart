import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:namida/core/extensions.dart';

class NamidaColor {
  final Color? used;
  final Color mix;
  final List<Color> palette;

  Color get color => used ?? mix;

  const NamidaColor({
    required this.used,
    required this.mix,
    required this.palette,
  });

  factory NamidaColor.fromJson(Map<String, dynamic> json) {
    return NamidaColor(
      used: json['used'] != null ? Color(json['used']) : null,
      mix: Color(json['mix'] ?? 0),
      palette: (json['palette'] as List?)?.map((e) => Color(e as int)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'used': used?.intValue,
      'mix': mix.intValue,
      'palette': palette.mapped((e) => e.intValue),
    };
  }

  @override
  bool operator ==(covariant NamidaColor other) {
    if (identical(this, other)) return true;
    return used == other.used && mix == other.mix && listEquals(palette, other.palette);
  }

  @override
  int get hashCode => used.hashCode ^ mix.hashCode ^ palette.hashCode;
}
