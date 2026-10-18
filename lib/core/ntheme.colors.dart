part of 'ntheme.dart';

/// A color a widget asks for: a theme role, resolved from the [NColorsData] where it's drawn, or a fixed color.
sealed class NColors {
  const NColors._();

  const factory NColors(NColorRole role, {double? opacity}) = _ThemedNColors;

  /// null stays null, so an optional color param keeps its default.
  static NColors? fixed(Color? color) => color == null ? null : _FixedNColors(color);

  /// a color computed from several roles, ex. an alpha blend.
  static NColors custom(Color Function(NColorsData colors) resolve) => _CustomNColors(resolve);

  /// the default icon color: [mainColor] (the current color by default) tinting [secondaryColor] (onSurface by default).
  static NColors defaultIcon({Color? mainColor, Color? secondaryColor, double? opacity}) => _CustomNColors((colors) {
    final mainColorFinal = mainColor ?? CurrentColor.inst.color;
    final secondaryColorFinal = secondaryColor ?? colors.onSurface;
    final color = Color.alphaBlend(mainColorFinal.withOpacityExt(0.47), secondaryColorFinal);
    return opacity == null ? color : color.withOpacityExt(opacity);
  });

  static const NColors card = _ThemedNColors(.card);
  static const NColors cardTheme = _ThemedNColors(.cardTheme);
  static const NColors scaffold = _ThemedNColors(.scaffold);
  static const NColors surface = _ThemedNColors(.surface);
  static const NColors surfaceContainer = _ThemedNColors(.surfaceContainer);
  static const NColors onSurface = _ThemedNColors(.onSurface);
  static const NColors primary = _ThemedNColors(.primary);
  static const NColors onPrimary = _ThemedNColors(.onPrimary);
  static const NColors primaryContainer = _ThemedNColors(.primaryContainer);
  static const NColors secondary = _ThemedNColors(.secondary);
  static const NColors onSecondary = _ThemedNColors(.onSecondary);
  static const NColors secondaryContainer = _ThemedNColors(.secondaryContainer);
  static const NColors onSecondaryContainer = _ThemedNColors(.onSecondaryContainer);
  static const NColors tertiary = _ThemedNColors(.tertiary);
  static const NColors error = _ThemedNColors(.error);
  static const NColors shadow = _ThemedNColors(.shadow);
  static const NColors highlight = _ThemedNColors(.highlight);
  static const NColors focus = _ThemedNColors(.focus);
  static const NColors divider = _ThemedNColors(.divider);
  static const NColors disabled = _ThemedNColors(.disabled);
  static const NColors secondaryHeader = _ThemedNColors(.secondaryHeader);
  static const NColors dialogBackground = _ThemedNColors(.dialogBackground);
  static const NColors listTileIcon = _ThemedNColors(.listTileIcon);
  static const NColors listTileText = _ThemedNColors(.listTileText);
  static const NColors icon = _ThemedNColors(.icon);
  static const NColors textLarge = _ThemedNColors(.textLarge);
  static const NColors textMedium = _ThemedNColors(.textMedium);
  static const NColors textSmall = _ThemedNColors(.textSmall);

  Color resolve(NColorsData colors);
}

/// Every [NColorRole] of one theme. Read it with [of], which follows the nearest [NTheme] and its interpolation.
final class NColorsData {
  static final _ofTheme = Expando<NColorsData>();

  static NColorsData of(BuildContext context) {
    final scope = _NThemeScope._maybeOf(context);
    if (scope != null) return scope.colors.value;
    return targetOf(context);
  }

  /// The colors the theme animation heads to, changing once per theme change. For widgets that animate color changes
  /// themselves (AnimatedContainer, NamidaInkWell with a duration): following [of] would restart their animation every frame.
  static NColorsData targetOf(BuildContext context) {
    final theme = Theme.of(context);
    return _ofTheme[theme] ??= NColorsData._fromTheme(theme);
  }

  final Color card;
  final Color cardTheme;
  final Color scaffold;
  final Color surface;
  final Color surfaceContainer;
  final Color onSurface;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color error;
  final Color shadow;
  final Color highlight;
  final Color focus;
  final Color divider;
  final Color disabled;
  final Color secondaryHeader;
  final Color dialogBackground;
  final Color listTileIcon;
  final Color listTileText;
  final Color icon;
  final Color textLarge;
  final Color textMedium;
  final Color textSmall;

  NColorsData._fromTheme(ThemeData theme)
    : card = theme.cardColor,
      cardTheme = theme.cardTheme.color ?? theme.cardColor,
      scaffold = theme.scaffoldBackgroundColor,
      surface = theme.colorScheme.surface,
      surfaceContainer = theme.colorScheme.surfaceContainer,
      onSurface = theme.colorScheme.onSurface,
      primary = theme.colorScheme.primary,
      onPrimary = theme.colorScheme.onPrimary,
      primaryContainer = theme.colorScheme.primaryContainer,
      secondary = theme.colorScheme.secondary,
      onSecondary = theme.colorScheme.onSecondary,
      secondaryContainer = theme.colorScheme.secondaryContainer,
      onSecondaryContainer = theme.colorScheme.onSecondaryContainer,
      tertiary = theme.colorScheme.tertiary,
      error = theme.colorScheme.error,
      shadow = theme.shadowColor,
      highlight = theme.highlightColor,
      focus = theme.focusColor,
      divider = theme.dividerColor,
      disabled = theme.disabledColor,
      secondaryHeader = theme.secondaryHeaderColor,
      dialogBackground = theme.dialogTheme.backgroundColor ?? theme.colorScheme.surfaceContainerHigh,
      listTileIcon = theme.listTileTheme.iconColor ?? theme.colorScheme.onSurfaceVariant,
      listTileText = theme.listTileTheme.textColor ?? theme.colorScheme.onSurface,
      icon = theme.iconTheme.color ?? theme.colorScheme.onSurface,
      textLarge = theme.textTheme.displayLarge?.color ?? theme.colorScheme.onSurface,
      textMedium = theme.textTheme.displayMedium?.color ?? theme.colorScheme.onSurface,
      textSmall = theme.textTheme.displaySmall?.color ?? theme.colorScheme.onSurface;

  NColorsData._lerp(NColorsData a, NColorsData b, double t)
    : card = Color.lerp(a.card, b.card, t)!,
      cardTheme = Color.lerp(a.cardTheme, b.cardTheme, t)!,
      scaffold = Color.lerp(a.scaffold, b.scaffold, t)!,
      surface = Color.lerp(a.surface, b.surface, t)!,
      surfaceContainer = Color.lerp(a.surfaceContainer, b.surfaceContainer, t)!,
      onSurface = Color.lerp(a.onSurface, b.onSurface, t)!,
      primary = Color.lerp(a.primary, b.primary, t)!,
      onPrimary = Color.lerp(a.onPrimary, b.onPrimary, t)!,
      primaryContainer = Color.lerp(a.primaryContainer, b.primaryContainer, t)!,
      secondary = Color.lerp(a.secondary, b.secondary, t)!,
      onSecondary = Color.lerp(a.onSecondary, b.onSecondary, t)!,
      secondaryContainer = Color.lerp(a.secondaryContainer, b.secondaryContainer, t)!,
      onSecondaryContainer = Color.lerp(a.onSecondaryContainer, b.onSecondaryContainer, t)!,
      tertiary = Color.lerp(a.tertiary, b.tertiary, t)!,
      error = Color.lerp(a.error, b.error, t)!,
      shadow = Color.lerp(a.shadow, b.shadow, t)!,
      highlight = Color.lerp(a.highlight, b.highlight, t)!,
      focus = Color.lerp(a.focus, b.focus, t)!,
      divider = Color.lerp(a.divider, b.divider, t)!,
      disabled = Color.lerp(a.disabled, b.disabled, t)!,
      secondaryHeader = Color.lerp(a.secondaryHeader, b.secondaryHeader, t)!,
      dialogBackground = Color.lerp(a.dialogBackground, b.dialogBackground, t)!,
      listTileIcon = Color.lerp(a.listTileIcon, b.listTileIcon, t)!,
      listTileText = Color.lerp(a.listTileText, b.listTileText, t)!,
      icon = Color.lerp(a.icon, b.icon, t)!,
      textLarge = Color.lerp(a.textLarge, b.textLarge, t)!,
      textMedium = Color.lerp(a.textMedium, b.textMedium, t)!,
      textSmall = Color.lerp(a.textSmall, b.textSmall, t)!;

  Color get(NColorRole role) => switch (role) {
    .card => card,
    .cardTheme => cardTheme,
    .scaffold => scaffold,
    .surface => surface,
    .surfaceContainer => surfaceContainer,
    .onSurface => onSurface,
    .primary => primary,
    .onPrimary => onPrimary,
    .primaryContainer => primaryContainer,
    .secondary => secondary,
    .onSecondary => onSecondary,
    .secondaryContainer => secondaryContainer,
    .onSecondaryContainer => onSecondaryContainer,
    .tertiary => tertiary,
    .error => error,
    .shadow => shadow,
    .highlight => highlight,
    .focus => focus,
    .divider => divider,
    .disabled => disabled,
    .secondaryHeader => secondaryHeader,
    .dialogBackground => dialogBackground,
    .listTileIcon => listTileIcon,
    .listTileText => listTileText,
    .icon => icon,
    .textLarge => textLarge,
    .textMedium => textMedium,
    .textSmall => textSmall,
  };

  @override
  bool operator ==(Object other) =>
      other is NColorsData && //
      other.card == card && //
      other.cardTheme == cardTheme && //
      other.scaffold == scaffold && //
      other.surface == surface && //
      other.surfaceContainer == surfaceContainer && //
      other.onSurface == onSurface && //
      other.primary == primary && //
      other.onPrimary == onPrimary && //
      other.primaryContainer == primaryContainer && //
      other.secondary == secondary && //
      other.onSecondary == onSecondary && //
      other.secondaryContainer == secondaryContainer && //
      other.onSecondaryContainer == onSecondaryContainer && //
      other.tertiary == tertiary && //
      other.error == error && //
      other.shadow == shadow && //
      other.highlight == highlight && //
      other.focus == focus && //
      other.divider == divider && //
      other.disabled == disabled && //
      other.secondaryHeader == secondaryHeader && //
      other.dialogBackground == dialogBackground && //
      other.listTileIcon == listTileIcon && //
      other.listTileText == listTileText && //
      other.icon == icon && //
      other.textLarge == textLarge && //
      other.textMedium == textMedium && //
      other.textSmall == textSmall;

  @override
  int get hashCode => Object.hashAll([
    card,
    cardTheme,
    scaffold,
    surface,
    surfaceContainer,
    onSurface,
    primary,
    onPrimary,
    primaryContainer,
    secondary,
    onSecondary,
    secondaryContainer,
    onSecondaryContainer,
    tertiary,
    error,
    shadow,
    highlight,
    focus,
    divider,
    disabled,
    secondaryHeader,
    dialogBackground,
    listTileIcon,
    listTileText,
    icon,
    textLarge,
    textMedium,
    textSmall,
  ]);
}

/// Builds a [DecoratedBox] whose decoration takes theme colors, so only this box rebuilds when they change.
class NDecoratedBox extends StatelessWidget {
  final Decoration Function(NColorsData colors) decoration;
  final Widget? child;

  const NDecoratedBox({
    super.key,
    required this.decoration,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.of(context);
    return DecoratedBox(
      decoration: decoration(colors),
      child: child,
    );
  }
}

/// For widgets that take plain colors: only this builder rebuilds when the colors change, keep heavy children out of it.
class NBuilder extends StatelessWidget {
  /// the built widget animates color changes itself, so it gets [NColorsData.targetOf].
  final bool selfAnimated;
  final Widget Function(BuildContext context, NColorsData colors) builder;

  const NBuilder({
    super.key,
    this.selfAnimated = false,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = selfAnimated ? NColorsData.targetOf(context) : NColorsData.of(context);
    return builder(context, colors);
  }
}

/// A [Container] whose colors follow the nearest [NTheme], so only this container rebuilds when they change.
class NContainer extends StatelessWidget {
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final NColors? color;
  final Decoration Function(NColorsData colors)? decoration;
  final Decoration Function(NColorsData colors)? foregroundDecoration;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? margin;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;
  final Clip clipBehavior;
  final Widget? child;

  const NContainer({
    super.key,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.foregroundDecoration,
    this.width,
    this.height,
    this.constraints,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.clipBehavior = Clip.none,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.of(context);
    return Container(
      alignment: alignment,
      padding: padding,
      color: color?.resolve(colors),
      decoration: decoration?.call(colors),
      foregroundDecoration: foregroundDecoration?.call(colors),
      width: width,
      height: height,
      constraints: constraints,
      margin: margin,
      transform: transform,
      transformAlignment: transformAlignment,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

class NColoredBox extends StatelessWidget {
  final NColors color;
  final Widget? child;

  const NColoredBox({
    super.key,
    required this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.of(context);
    return ColoredBox(
      color: color.resolve(colors),
      child: child,
    );
  }
}

class NIcon extends StatelessWidget {
  final IconData? icon;
  final double? size;
  final NColors? color;
  final String? semanticLabel;

  const NIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.of(context);
    return Icon(
      icon,
      size: size,
      color: color?.resolve(colors),
      semanticLabel: semanticLabel,
    );
  }
}

final class _ThemedNColors extends NColors {
  final NColorRole role;
  final double? opacity;

  const _ThemedNColors(this.role, {this.opacity}) : super._();

  @override
  Color resolve(NColorsData colors) {
    final color = colors.get(role);
    final opacity = this.opacity;
    if (opacity != null) return color.withOpacityExt(opacity);
    return color;
  }
}

final class _CustomNColors extends NColors {
  final Color Function(NColorsData colors) _resolve;

  const _CustomNColors(this._resolve) : super._();

  @override
  Color resolve(NColorsData colors) => _resolve(colors);
}

final class _FixedNColors extends NColors {
  final Color color;

  const _FixedNColors(this.color) : super._();

  @override
  Color resolve(NColorsData colors) => color;
}

enum NColorRole {
  card,
  cardTheme,
  scaffold,
  surface,
  surfaceContainer,
  onSurface,
  primary,
  onPrimary,
  primaryContainer,
  secondary,
  onSecondary,
  secondaryContainer,
  onSecondaryContainer,
  tertiary,
  error,
  shadow,
  highlight,
  focus,
  divider,
  disabled,
  secondaryHeader,
  dialogBackground,
  listTileIcon,
  listTileText,
  icon,
  textLarge,
  textMedium,
  textSmall,
}
