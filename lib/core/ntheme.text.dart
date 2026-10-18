part of 'ntheme.dart';

/// A text style a widget asks for: one of the theme's display styles with an optional size and weight.
/// Resolved from the theme's localized text theme, so script specific geometry (height, baseline) is kept.
final class NText {
  final NTextRole role;
  final NTextSize? size;
  final FontWeight? weight;

  const NText(this.role, {this.size, this.weight});

  static const large = NText(.large);
  static const medium = NText(.medium);
  static const small = NText(.small);

  static final _variantsOfBase = Expando<Map<NText, TextStyle>>();

  TextStyle of(BuildContext context) {
    final textTheme = _NTextScope._maybeOf(context)?.textTheme ?? Theme.of(context).textTheme;
    final base = role._readFrom(textTheme);
    if (size == null && weight == null) return base;
    final variants = _variantsOfBase[base] ??= <NText, TextStyle>{};
    return variants[this] ??= base.copyWith(fontSize: size?.value, fontWeight: weight);
  }

  @override
  bool operator ==(Object other) => other is NText && other.role == role && other.size == size && other.weight == weight;

  @override
  int get hashCode => Object.hash(role, size, weight);
}

/// A [Text] whose color follows the nearest [NTheme], interpolated when the theme changes.
class NamidaText extends StatelessWidget {
  final String data;
  final NText style;
  final NColors? color;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;

  const NamidaText(
    this.data, {
    super.key,
    required this.style,
    this.color,
    this.strutStyle,
    this.textAlign,
    this.softWrap,
    this.overflow,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = style.of(context);
    final colors = NColorsData.of(context);
    final colorDescriptor = color ?? style.role.color;
    final textColor = colorDescriptor.resolve(colors);
    final coloredTextStyle = textColor == textStyle.color ? textStyle : textStyle.copyWith(color: textColor);
    return Text(
      data,
      style: coloredTextStyle,
      strutStyle: strutStyle,
      textAlign: textAlign,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}

enum NTextRole {
  large(color: NColors.textLarge),
  medium(color: NColors.textMedium),
  small(color: NColors.textSmall),
  ;

  final NColors color;

  const NTextRole({required this.color});

  TextStyle _readFrom(TextTheme textTheme) => switch (this) {
    large => textTheme.displayLarge!,
    medium => textTheme.displayMedium!,
    small => textTheme.displaySmall!,
  };
}

enum NTextSize {
  s9(9.0),
  s10(10.0),
  s10p5(10.5),
  s11(11.0),
  s11p5(11.5),
  s12(12.0),
  s12p5(12.5),
  s13(13.0),
  s13p5(13.5),
  s13p7(13.7),
  s14(14.0),
  s15(15.0),
  s15p5(15.5),
  s16(16.0),
  s17(17.0),
  s17p5(17.5),
  s18(18.0),
  s20(20.0),
  s21(21.0),
  s22(22.0),
  s26(26.0),
  s28(28.0),
  s32(32.0),
  ;

  final double value;

  const NTextSize(this.value);
}
