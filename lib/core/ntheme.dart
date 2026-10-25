// by claude
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

part 'ntheme.colors.dart';
part 'ntheme.text.dart';

/// Provides [data] as the [Theme], plus its [NColorsData] (interpolated when the theme changes) and text styles.
/// Every theme override in the app goes through this, so the colors always belong to the nearest theme.
class NTheme extends StatefulWidget {
  final ThemeData data;
  final Duration duration;
  final Widget child;

  const NTheme({
    super.key,
    required this.data,
    this.duration = const Duration(milliseconds: kThemeAnimationDurationMS),
    required this.child,
  });

  /// true in the frame a hidden subtree is shown again with a newer theme, widgets animating theme colors jump to them instead.
  static bool isRevealing(BuildContext context) {
    final revealScope = context.getInheritedWidgetOfExactType<_NThemeRevealScope>();
    if (revealScope == null) return false;
    return revealScope.state._isRevealing;
  }

  @override
  State<NTheme> createState() => _NThemeState();
}

class _NThemeState extends State<NTheme> with SingleTickerProviderStateMixin {
  late final _colors = ValueNotifier(NColorsData._fromTheme(widget.data));
  AnimationController? _lerpController;
  ({NColorsData from, NColorsData to})? _lerp;

  @override
  void didUpdateWidget(NTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.data, oldWidget.data)) return;
    final target = NColorsData._fromTheme(widget.data);
    final shouldJump = !settings.animatedTheme.value || NTheme.isRevealing(context);
    if (shouldJump) {
      _lerpController?.stop();
      _lerp = null;
      _colors.value = target;
      return;
    }
    _lerp = (from: _colors.value, to: target);
    final lerpController = _lerpController ??= AnimationController(vsync: this)..addListener(_onLerpTick);
    lerpController.duration = widget.duration;
    lerpController.forward(from: 0.0);
  }

  void _onLerpTick() {
    final lerp = _lerp;
    final lerpController = _lerpController;
    if (lerp == null || lerpController == null) return;
    _colors.value = NColorsData._lerp(lerp.from, lerp.to, lerpController.value);
  }

  @override
  void dispose() {
    _lerpController?.dispose();
    _colors.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _NThemeLayers(
      data: widget.data,
      colors: _colors,
      child: widget.child,
    );
  }
}

/// Holds the last visible theme and colors while [TickerMode] is disabled (covered routes, hidden pages),
/// so hidden subtrees get theme changes once they're visible again instead of rebuilding while hidden.
class NThemeFrozenWhileHidden extends StatefulWidget {
  final Widget child;

  const NThemeFrozenWhileHidden({
    super.key,
    required this.child,
  });

  @override
  State<NThemeFrozenWhileHidden> createState() => _NThemeFrozenWhileHiddenState();
}

class _NThemeFrozenWhileHiddenState extends State<NThemeFrozenWhileHidden> {
  _NThemeScope? _visibleScope;
  ValueNotifier<NColorsData>? _frozenColors;
  bool _isRevealing = false;

  @override
  void dispose() {
    _frozenColors?.dispose();
    super.dispose();
  }

  void _endReveal(Duration _) => _isRevealing = false;

  @override
  Widget build(BuildContext context) {
    final scope = _NThemeScope._of(context);
    final isVisible = TickerMode.valuesOf(context).enabled;
    final visibleScope = _visibleScope;
    if (visibleScope == null || isVisible) {
      final frozenColors = _frozenColors;
      if (frozenColors != null) {
        frozenColors.dispose();
        _frozenColors = null;
        final didThemeChange = !identical(visibleScope?.data, scope.data);
        if (didThemeChange) {
          _isRevealing = true;
          WidgetsBinding.instance.addPostFrameCallback(_endReveal);
        }
      }
      _visibleScope = scope;
      return _NThemeRevealScope(
        state: this,
        child: _NThemeLayers(
          data: scope.data,
          colors: scope.colors,
          child: widget.child,
        ),
      );
    }
    final frozenColors = _frozenColors ??= ValueNotifier(visibleScope.colors.value);
    return _NThemeRevealScope(
      state: this,
      child: _NThemeLayers(
        data: visibleScope.data,
        colors: frozenColors,
        child: widget.child,
      ),
    );
  }
}

class _NThemeLayers extends StatelessWidget {
  final ThemeData data;
  final ValueListenable<NColorsData> colors;
  final Widget child;

  const _NThemeLayers({
    required this.data,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _NThemeScope(
      data: data,
      colors: colors,
      child: Theme(
        data: data,
        child: _NTextScopeProvider(
          child: child,
        ),
      ),
    );
  }
}

class _NThemeRevealScope extends InheritedWidget {
  final _NThemeFrozenWhileHiddenState state;

  const _NThemeRevealScope({
    required this.state,
    required super.child,
  });

  @override
  bool updateShouldNotify(_NThemeRevealScope oldWidget) => false;
}

class _NTextScopeProvider extends StatelessWidget {
  final Widget child;

  const _NTextScopeProvider({required this.child});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _NTextScope(
      textTheme: textTheme,
      child: child,
    );
  }
}

class _NThemeScope extends InheritedTheme {
  final ThemeData data;
  final ValueListenable<NColorsData> colors;

  const _NThemeScope({
    required this.data,
    required this.colors,
    required super.child,
  });

  static _NThemeScope? _maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_NThemeScope>();

  static _NThemeScope _of(BuildContext context) => _maybeOf(context)!;

  @override
  Widget wrap(BuildContext context, Widget child) => _NThemeScope(data: data, colors: colors, child: child);

  @override
  bool updateShouldNotify(_NThemeScope oldWidget) => !identical(data, oldWidget.data) || oldWidget.colors.value != colors.value;

  @override
  InheritedElement createElement() => _NThemeScopeElement(this);
}

class _NThemeScopeElement extends InheritedElement {
  _NThemeScope _scope;
  ValueListenable<NColorsData> _colors;
  bool _didColorsChange = false;

  _NThemeScopeElement(_NThemeScope super.widget) : _scope = widget, _colors = widget.colors {
    _colors.addListener(_onColorsChanged);
  }

  void _onColorsChanged() {
    _didColorsChange = true;
    markNeedsBuild();
  }

  @override
  void update(_NThemeScope newWidget) {
    final newColors = newWidget.colors;
    if (!identical(newColors, _colors)) {
      _colors.removeListener(_onColorsChanged);
      _colors = newColors;
      _colors.addListener(_onColorsChanged);
    }
    _scope = newWidget;
    super.update(newWidget);
  }

  @override
  Widget build() {
    if (_didColorsChange) notifyClients(_scope);
    return super.build();
  }

  @override
  void notifyClients(InheritedWidget oldWidget) {
    super.notifyClients(oldWidget);
    _didColorsChange = false;
  }

  @override
  void unmount() {
    _colors.removeListener(_onColorsChanged);
    super.unmount();
  }
}

class _NTextScope extends InheritedTheme {
  final TextTheme textTheme;

  const _NTextScope({
    required this.textTheme,
    required super.child,
  });

  static _NTextScope? _maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_NTextScope>();

  @override
  Widget wrap(BuildContext context, Widget child) => _NTextScope(textTheme: textTheme, child: child);

  @override
  bool updateShouldNotify(_NTextScope oldWidget) => textTheme != oldWidget.textTheme;
}
