import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:namida/core/extensions.dart';

class NamidaColor {
  final Color? used;
  // final Color mix;
  final Color mix2;
  final List<Color> palette;

  Color get color => used ?? mix2;

  const NamidaColor({
    required this.used,
    // required this.mix,
    required this.mix2,
    required this.palette,
  });

  NamidaColor.single(Color color)
      : this(
          used: null,
          // mix: color,
          mix2: color,
          palette: [color],
        );

  NamidaColor.create({
    Color? used,
    required List<Color> palette,
  }) : this(
          used: used,
          // mix: NamidaColor.mixIntColors(palette),
          mix2: NamidaColor.mixIntColors(palette.takeFew()),
          palette: palette,
        );

  static Color mixIntColors(Iterable<Color> colors) {
    if (colors.isEmpty) return Colors.transparent;
    int red = 0;
    int green = 0;
    int blue = 0;

    for (final color in colors) {
      var colorvalue = color.intValue;
      red += (colorvalue >> 16) & 0xFF;
      green += (colorvalue >> 8) & 0xFF;
      blue += colorvalue & 0xFF;
    }

    red ~/= colors.length;
    green ~/= colors.length;
    blue ~/= colors.length;

    return Color.fromARGB(255, red, green, blue);
  }

  factory NamidaColor.fromJson(Map<String, dynamic> json) {
    final palette = (json['palette'] as List?)?.map((e) => Color(e as int)).toList() ?? [];
    // final mix = Color(json['mix'] ?? 0);
    final mix2 = json['mix2'] is int ? Color(json['mix2'] as int) : NamidaColor.mixIntColors(palette.takeFew());
    return NamidaColor(
      used: json['used'] != null ? Color(json['used']) : null,
      // mix: mix,
      mix2: mix2,
      palette: palette,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'used': used?.intValue,
      // 'mix': mix.intValue,
      'mix2': mix2.intValue,
      'palette': palette.mapped((e) => e.intValue),
    };
  }

  @override
  bool operator ==(covariant NamidaColor other) {
    if (identical(this, other)) return true;
    return used == other.used /* && mix == other.mix */ && mix2 == other.mix2 && listEquals(palette, other.palette);
  }

  @override
  int get hashCode => used.hashCode /* ^ mix.hashCode  */ ^ mix2.hashCode ^ palette.hashCode;
}

extension NamidaColorMExtensions on List<NamidaColor> {
  NamidaColor combine({bool forceGenerateUsed = true}) {
    final palettes = <Color>[];
    final palettesFew = <Color>[];
    final usedAll = <Color>[];
    for (final c in this) {
      palettes.addAll(c.palette);
      palettesFew.addAll(c.palette.takeFew());
      if (forceGenerateUsed) usedAll.add(c.color);
    }
    // final mix = NamidaColor.mixIntColors(palettes);
    final mix2 = NamidaColor.mixIntColors(palettesFew);
    final used = usedAll.isEmpty ? null : NamidaColor.mixIntColors(usedAll);
    return NamidaColor(
      used: used,
      // mix: mix,
      mix2: mix2,
      palette: palettes,
    );
  }
}

extension NamidaColorExtensions on List<Color> {
  List<Color> takeFewList() => takeFew().toList();
  Iterable<Color> takeFew() => this.take(10);
}
