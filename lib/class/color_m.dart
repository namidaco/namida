import 'package:flutter/material.dart';
import 'package:namida/core/extensions.dart';

class NamidaColor {
  Color? used;
  late final Color mix;
  late final List<Color> palette;

  Color get color => used ?? mix;

  NamidaColor(
    this.used,
    this.mix,
    this.palette,
  );
  NamidaColor.fromJson(Map<String, dynamic> json) {
    used = json['used'] != null ? Color(json['used']) : null;
    mix = Color(json['mix'] ?? 0);
    palette = List<Color>.from(List<int>.from(json['palette'] ?? []).mapped((e) => Color(e)));
  }

  Map<String, dynamic> toJson() {
    return {
      'used': used?.value,
      'mix': mix.value,
      'palette': palette.mapped((e) => e.value),
    };
  }
}
