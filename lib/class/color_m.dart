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
      palette: List<Color>.from(List<int>.from(json['palette'] ?? []).map((e) => Color(e))),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'used': used?.value,
      'mix': mix.value,
      'palette': palette.mapped((e) => e.value),
    };
  }
}
