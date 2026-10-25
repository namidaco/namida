// rewritten by claude, new one repaints only the parts that change while dragging, applies a color once it settles, and adds tones, recent, suggested and preset swatches

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:material_color_utilities/material_color_utilities.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

part 'color_picker_dialog.render.dart';

class NamidaColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String doneText;
  final void Function(Color color) onDonePressed;
  final bool cancelButton;
  final VoidCallback? onRefreshButtonPressed;

  final ValueChanged<Color>? onColorChangeEnd;
  final bool themeFollowsColor;
  final bool isAlphaAllowed;

  final FutureOr<List<Color>>? suggestedColors;

  const NamidaColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.doneText,
    required this.onDonePressed,
    required this.cancelButton,
    this.onRefreshButtonPressed,
    this.onColorChangeEnd,
    this.themeFollowsColor = false,
    this.isAlphaAllowed = true,
    this.suggestedColors,
  });

  @override
  State<NamidaColorPickerDialog> createState() => _NamidaColorPickerDialogState();
}

class _NamidaColorPickerDialogState extends State<NamidaColorPickerDialog> {
  static const _kDialogMaxWidth = 640.0;

  late final _controller = _ColorPickerController(widget.initialColor, isAlphaAllowed: widget.isAlphaAllowed);
  final _suggestedColors = RxO<List<Color>>(const []);
  final _focusNode = FocusNode(debugLabel: 'color picker');
  late final List<Color> _recentColors;

  @override
  void initState() {
    super.initState();
    _recentColors = settings.extra.recentColors.value.map(Color.new).toFixedList();
    _controller.settledColor.addListener(_onSettled);
    final suggestedColors = widget.suggestedColors;
    if (suggestedColors is List<Color>) {
      _setSuggestedColors(suggestedColors);
    } else if (suggestedColors != null) {
      suggestedColors.then(_setSuggestedColors);
    }
  }

  @override
  void dispose() {
    _controller.settledColor.removeListener(_onSettled);
    _controller.dispose();
    _suggestedColors.close();
    _focusNode.dispose();
    super.dispose();
  }

  void _setSuggestedColors(List<Color> colors) {
    if (!mounted) return;
    _suggestedColors.value = colors.toSet().toFixedList();
  }

  void _onSettled() {
    final color = _controller.settledColor.value;
    widget.onColorChangeEnd?.call(color);
  }

  void _onDonePressed() {
    final color = _controller.color;
    settings.extra.addRecentColor(color.intValue);
    widget.onDonePressed(color);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      if (key == LogicalKeyboardKey.keyC) {
        _controller.copyToClipboard();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyV) {
        _controller.pasteFromClipboard();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final step = keyboard.isShiftPressed ? 0.1 : 0.01;
    final nudge = switch (key) {
      LogicalKeyboardKey.arrowLeft => (saturation: -step, value: 0.0),
      LogicalKeyboardKey.arrowRight => (saturation: step, value: 0.0),
      LogicalKeyboardKey.arrowUp => (saturation: 0.0, value: step),
      LogicalKeyboardKey.arrowDown => (saturation: 0.0, value: -step),
      _ => null,
    };
    if (nudge == null) return KeyEventResult.ignored;
    _controller.nudge(nudge.saturation, nudge.value);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final onRefreshButtonPressed = widget.onRefreshButtonPressed;
    final refreshButton = onRefreshButtonPressed == null
        ? null
        : NamidaIconButton(
            icon: Broken.refresh,
            tooltip: () => lang.restoreDefaults,
            onPressed: onRefreshButtonPressed,
          );
    final dialog = CustomBlurryDialog(
      maxWidth: _kDialogMaxWidth,
      titleWidget: Padding(
        padding: const EdgeInsets.fromLTRB(14.0, 22.0, 14.0, 0.0),
        child: SizedBox(
          height: 40.0,
          child: _ColorComparison(
            controller: _controller,
          ),
        ),
      ),
      leftAction: refreshButton,
      actions: [
        if (widget.cancelButton) const CancelButton(),
        NamidaButton(
          text: widget.doneText,
          onTap: _onDonePressed,
        ),
      ],
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: _ColorPickerBody(
          controller: _controller,
          recentColors: _recentColors,
          suggestedColors: _suggestedColors,
          onPickerPointerDown: _focusNode.requestFocus,
        ),
      ),
    );
    if (!widget.themeFollowsColor) return dialog;
    return _ThemeFollowsColor(
      controller: _controller,
      child: dialog,
    );
  }
}

/// only the theme rebuilds, [child] is the same instance so just its theme dependents update.
class _ThemeFollowsColor extends StatefulWidget {
  final _ColorPickerController controller;
  final Widget child;

  const _ThemeFollowsColor({
    required this.controller,
    required this.child,
  });

  @override
  State<_ThemeFollowsColor> createState() => _ThemeFollowsColorState();
}

class _ThemeFollowsColorState extends State<_ThemeFollowsColor> {
  static const _kThrottleDuration = Duration(milliseconds: 80);

  late Color _themeColor = widget.controller.settledColor.value;
  late ThemeData _theme = AppThemes.inst.getAppTheme(_themeColor);
  Timer? _throttleTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.current.addListener(_onColorChanged);
    widget.controller.settledColor.addListener(_onSettled);
  }

  @override
  void dispose() {
    widget.controller.current.removeListener(_onColorChanged);
    widget.controller.settledColor.removeListener(_onSettled);
    _throttleTimer?.cancel();
    super.dispose();
  }

  void _onColorChanged() {
    if (_throttleTimer != null) return;
    _followCurrentColor();
  }

  void _onThrottleEnd() {
    _throttleTimer = null;
    _followCurrentColor();
  }

  /// built uncached, so drag previews don't fill the app's theme cache.
  void _followCurrentColor() {
    final color = widget.controller.color;
    if (color == _themeColor) return;
    final theme = AppThemes.inst.buildAppThemeUncached(color);
    setState(() {
      _themeColor = color;
      _theme = theme;
    });
    _throttleTimer = Timer(_kThrottleDuration, _onThrottleEnd);
  }

  void _onSettled() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    final settledColor = widget.controller.settledColor.value;
    if (settledColor == _themeColor) return;
    final theme = AppThemes.inst.getAppTheme(settledColor);
    setState(() {
      _themeColor = settledColor;
      _theme = theme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NTheme(
      data: _theme,
      child: widget.child,
    );
  }
}

class _ColorPickerController {
  _ColorPickerController._(this.initialColor, HSVColor initialHsv, {required this.isAlphaAllowed})
    : current = RxO((hsv: initialHsv, color: initialColor)),
      settledColor = RxO(initialColor);

  factory _ColorPickerController(Color initialColorPre, {required bool isAlphaAllowed}) {
    final initialColor = isAlphaAllowed ? initialColorPre : initialColorPre.withOpacityExt(1.0);
    final initialHsv = HSVColor.fromColor(initialColor);
    return _ColorPickerController._(initialColor, initialHsv, isAlphaAllowed: isAlphaAllowed);
  }

  static const _kSettleDelay = Duration(milliseconds: 250);

  final Color initialColor;
  final bool isAlphaAllowed;

  /// changes every drag frame, only painters listen to it.
  final RxO<_PickedColor> current;
  final RxO<Color> settledColor;

  Timer? _settleTimer;

  HSVColor get hsv => current.value.hsv;
  Color get color => current.value.color;

  void dispose() {
    _settleTimer?.cancel();
    current.close();
    settledColor.close();
  }

  void setHsv(HSVColor hsv) {
    final color = hsv.toColor();
    current.value = (hsv: hsv, color: color);
  }

  /// greys and black have no hue, the previous one is kept for the next drag.
  void setColor(Color colorPre, {bool shouldKeepAlpha = false}) {
    final previousHsv = hsv;
    final shouldUsePreviousAlpha = shouldKeepAlpha || !isAlphaAllowed;
    final alpha = shouldUsePreviousAlpha ? previousHsv.alpha : colorPre.a;
    final color = colorPre.withOpacityExt(alpha);
    var newHsv = HSVColor.fromColor(color);
    if (newHsv.value == 0.0) {
      newHsv = newHsv.withHue(previousHsv.hue).withSaturation(previousHsv.saturation);
    } else if (newHsv.saturation == 0.0) {
      newHsv = newHsv.withHue(previousHsv.hue);
    }
    current.value = (hsv: newHsv, color: color);
  }

  void settle() {
    _settleTimer?.cancel();
    settledColor.value = color;
  }

  void settleSoon() {
    _settleTimer?.cancel();
    _settleTimer = Timer(_kSettleDelay, settle);
  }

  void pickColor(Color color, {bool shouldKeepAlpha = false}) {
    setColor(color, shouldKeepAlpha: shouldKeepAlpha);
    settle();
  }

  void pickAlpha(double alpha) {
    final newHsv = hsv.withAlpha(alpha);
    setHsv(newHsv);
    settle();
  }

  void revert() => pickColor(initialColor);

  void nudge(double saturationDelta, double valueDelta) {
    final hsv = this.hsv;
    final saturation = (hsv.saturation + saturationDelta).clampDouble(0.0, 1.0);
    final value = (hsv.value + valueDelta).clampDouble(0.0, 1.0);
    final newHsv = hsv.withSaturation(saturation).withValue(value);
    setHsv(newHsv);
    settleSoon();
  }

  void copyToClipboard() {
    final color = this.color;
    final hexText = color.a < 1.0 ? _ColorCodec.toArgbHex(color) : _ColorCodec.toRgbHex(color);
    NamidaUtils.copyToClipboard(
      content: '#$hexText',
      leftBarIndicatorColor: color,
    );
  }

  Future<void> pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) return;
    final parsed = _ColorCodec.tryParse(text);
    if (parsed == null) return;
    pickColor(parsed.color, shouldKeepAlpha: !parsed.hasAlpha);
  }
}

class _ColorPickerBody extends StatelessWidget {
  final _ColorPickerController controller;
  final List<Color> recentColors;
  final RxO<List<Color>> suggestedColors;
  final VoidCallback onPickerPointerDown;

  const _ColorPickerBody({
    required this.controller,
    required this.recentColors,
    required this.suggestedColors,
    required this.onPickerPointerDown,
  });

  static const _kWideMinWidth = 540.0;

  @override
  Widget build(BuildContext context) {
    return LayoutWidthProvider(
      builder: (context, maxWidth) {
        final isWide = maxWidth >= _kWideMinWidth;
        final pickerWidget = _PickerSection(
          controller: controller,
          onPointerDown: onPickerPointerDown,
        );
        final swatchesWidget = _SwatchesSection(
          controller: controller,
          recentColors: recentColors,
          suggestedColors: suggestedColors,
        );
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: pickerWidget,
              ),
              const SizedBox(
                width: 18.0,
              ),
              Expanded(
                child: swatchesWidget,
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            pickerWidget,
            const SizedBox(
              height: 16.0,
            ),
            swatchesWidget,
          ],
        );
      },
    );
  }
}

class _PickerSection extends StatelessWidget {
  final _ColorPickerController controller;
  final VoidCallback onPointerDown;

  const _PickerSection({
    required this.controller,
    required this.onPointerDown,
  });

  static const _kPlaneAspectRatio = 1.5;
  static const _kPlaneMaxHeight = 220.0;

  @override
  Widget build(BuildContext context) {
    return LayoutWidthProvider(
      builder: (context, maxWidth) {
        final planeHeight = (maxWidth / _kPlaneAspectRatio).withMaximum(_kPlaneMaxHeight);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Listener(
              onPointerDown: (_) => onPointerDown(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: planeHeight,
                    child: _SaturationValuePlane(
                      controller: controller,
                    ),
                  ),
                  const SizedBox(
                    height: 8.0,
                  ),
                  SizedBox(
                    height: _RenderColorSlider.kHeight,
                    child: _ColorSlider(
                      controller: controller,
                      kind: _ColorSliderKind.hue,
                    ),
                  ),
                  if (controller.isAlphaAllowed)
                    SizedBox(
                      height: _RenderColorSlider.kHeight,
                      child: _ColorSlider(
                        controller: controller,
                        kind: _ColorSliderKind.alpha,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(
              height: 12.0,
            ),
            _ColorInputRow(
              controller: controller,
            ),
          ],
        );
      },
    );
  }
}

class _ColorComparison extends StatelessWidget {
  final _ColorPickerController controller;

  const _ColorComparison({required this.controller});

  static const _kRadius = Radius.circular(10.0);

  @override
  Widget build(BuildContext context) {
    final initialColor = controller.initialColor;
    final isInitialLight = initialColor.computeLuminance() > 0.5 || initialColor.a < 0.5;
    final undoIconColor = isInitialLight ? Colors.black.withOpacityExt(0.55) : Colors.white.withOpacityExt(0.8);
    final radius = _kRadius.x.multipliedRadius;
    final scaledRadius = Radius.circular(radius);
    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: controller.revert,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: _ColorPreview(
                    controller: controller,
                    isInitial: true,
                    borderRadius: BorderRadius.horizontal(left: scaledRadius),
                  ),
                ),
                Icon(
                  Broken.undo,
                  size: 16.0,
                  color: undoIconColor,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _ColorPreview(
            controller: controller,
            isInitial: false,
            borderRadius: BorderRadius.horizontal(right: scaledRadius),
          ),
        ),
      ],
    );
  }
}

class _ColorInputRow extends StatefulWidget {
  final _ColorPickerController controller;

  const _ColorInputRow({required this.controller});

  @override
  State<_ColorInputRow> createState() => _ColorInputRowState();
}

class _ColorInputRowState extends State<_ColorInputRow> {
  static _ColorInputMode _lastMode = _ColorInputMode.hex;

  late _ColorInputMode _mode = _lastMode;
  final _hexController = TextEditingController();
  final _channelControllers = List<TextEditingController>.generate(3, (_) => TextEditingController(), growable: false);
  final _alphaController = TextEditingController();

  /// what's being typed in, [_writeFields] leaves it alone.
  Object? _editingSource;

  @override
  void initState() {
    super.initState();
    _writeFields();
    widget.controller.current.addListener(_onColorChanged);
  }

  @override
  void dispose() {
    widget.controller.current.removeListener(_onColorChanged);
    _hexController.dispose();
    for (final c in _channelControllers) {
      c.dispose();
    }
    _alphaController.dispose();
    super.dispose();
  }

  void _onColorChanged() => _writeFields();

  void _writeFields() {
    final controller = widget.controller;
    final color = controller.color;
    if (controller.isAlphaAllowed && !identical(_editingSource, _alphaController)) {
      final alphaPercent = (color.a * 100.0).round();
      _alphaController.text = '$alphaPercent';
    }
    if (_mode == _ColorInputMode.hex) {
      if (!identical(_editingSource, _hexController)) _hexController.text = _ColorCodec.toRgbHex(color);
      return;
    }
    if (identical(_editingSource, _channelControllers)) return;
    final channels = _mode.channelsOf(color);
    for (int i = 0; i < channels.length; i++) {
      _channelControllers[i].text = '${channels[i]}';
    }
  }

  void _applyFromSource(Object source, void Function(_ColorPickerController controller) apply) {
    _editingSource = source;
    apply(widget.controller);
    _editingSource = null;
  }

  void _cycleMode() {
    final mode = _mode.nextMode();
    _lastMode = mode;
    setState(() => _mode = mode);
    _writeFields();
  }

  void _onHexChanged(String text) {
    final parsed = _ColorCodec.tryParse(text);
    if (parsed == null) return;
    _applyFromSource(_hexController, (controller) => controller.pickColor(parsed.color, shouldKeepAlpha: !parsed.hasAlpha));
  }

  void _onAlphaChanged(String text) {
    final alphaPercent = int.tryParse(text);
    if (alphaPercent == null || alphaPercent > 100) return;
    _applyFromSource(_alphaController, (controller) => controller.pickAlpha(alphaPercent / 100.0));
  }

  void _onChannelChanged(String _) {
    final maxValues = _mode.channelMaxValues;
    final channels = <int>[];
    for (int i = 0; i < maxValues.length; i++) {
      final value = int.tryParse(_channelControllers[i].text);
      if (value == null || value > maxValues[i]) return;
      channels.add(value);
    }
    final color = _mode.opaqueColorOfChannels(channels);
    if (color == null) return;
    _applyFromSource(_channelControllers, (controller) => controller.pickColor(color, shouldKeepAlpha: true));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final alphaFieldWidget = controller.isAlphaAllowed
        ? Expanded(
            child: _ColorTextField(
              controller: _alphaController,
              hintText: '100',
              label: 'A',
              isNumeric: true,
              onChanged: _onAlphaChanged,
            ),
          )
        : null;
    final colorFieldWidgets = _mode == _ColorInputMode.hex
        ? [
            Expanded(
              flex: 2,
              child: _ColorTextField(
                controller: _hexController,
                hintText: 'RRGGBB',
                label: null,
                isNumeric: false,
                onChanged: _onHexChanged,
              ),
            ),
          ]
        : _mode.channelLabels.indexed.map(
            (e) => Expanded(
              child: _ColorTextField(
                controller: _channelControllers[e.$1],
                hintText: '0',
                label: e.$2,
                isNumeric: true,
                onChanged: _onChannelChanged,
              ),
            ),
          );
    final fieldsWidget = Row(
      children:
          [
                ...colorFieldWidgets,
                ?alphaFieldWidget,
              ]
              .addSeparators(
                separator: const SizedBox(
                  width: 4.0,
                ),
              )
              .toFixedList(),
    );
    return Row(
      children: [
        NamidaInkWell(
          height: _ColorTextField.kHeight,
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          borderRadius: 10.0,
          bgColor: const NColors(.secondaryContainer, opacity: 0.5),
          onTap: _cycleMode,
          child: Center(
            child: NamidaText(
              _mode.label,
              style: const NText(.small, weight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(
          width: 8.0,
        ),
        Expanded(
          child: fieldsWidget,
        ),
        const SizedBox(
          width: 2.0,
        ),
        NamidaIconButton(
          icon: Broken.copy,
          iconSize: 20.0,
          horizontalPadding: 4.0,
          tooltip: () => lang.copy,
          onPressed: controller.copyToClipboard,
        ),
        NamidaIconButton(
          icon: Broken.clipboard_import,
          iconSize: 20.0,
          horizontalPadding: 4.0,
          tooltip: () => lang.paste,
          onPressed: controller.pasteFromClipboard,
        ),
      ],
    );
  }
}

class _ColorTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? label;
  final bool isNumeric;
  final ValueChanged<String> onChanged;

  const _ColorTextField({
    required this.controller,
    required this.hintText,
    required this.label,
    required this.isNumeric,
    required this.onChanged,
  });

  static const kHeight = 36.0;
  static const _kTextStyle = NText(.small, size: .s13, weight: FontWeight.w600);
  static const _kNumericTextStyle = NText(.small, size: .s12, weight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    final textStyleDescriptor = isNumeric ? _kNumericTextStyle : _kTextStyle;
    final textStyle = textStyleDescriptor.of(context);
    final hintStyle = textStyle.copyWith(color: textStyle.color?.withOpacityExt(0.47));
    final borderRadius = BorderRadius.circular(10.0.multipliedRadius);
    final horizontalPadding = isNumeric ? 2.0 : 10.0;
    final labelWidget = label == null
        ? null
        : Text(
            label,
          );
    return NBuilder(
      builder: (context, colors) {
        final borderColor = colors.onSurface.withOpacityExt(0.39);
        return TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          style: textStyle,
          textAlign: isNumeric ? TextAlign.center : TextAlign.start,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            isDense: true,
            visualDensity: VisualDensity.standard,
            contentPadding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10.0),
            label: labelWidget,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: hintText,
            hintStyle: hintStyle,
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: borderColor, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(color: borderColor, width: 2.0),
            ),
          ),
        );
      },
    );
  }
}

class _SwatchesSection extends StatelessWidget {
  final _ColorPickerController controller;
  final List<Color> recentColors;
  final RxO<List<Color>> suggestedColors;

  const _SwatchesSection({
    required this.controller,
    required this.recentColors,
    required this.suggestedColors,
  });

  static const _kMaterialPresets = <Color>[
    Color(0xFFF44336), Color(0xFFE91E63), Color(0xFF9C27B0), Color(0xFF673AB7), Color(0xFF3F51B5), Color(0xFF2196F3), //
    Color(0xFF03A9F4), Color(0xFF00BCD4), Color(0xFF009688), Color(0xFF4CAF50), Color(0xFF8BC34A), Color(0xFFCDDC39), //
    Color(0xFFFFEB3B), Color(0xFFFFC107), Color(0xFFFF9800), Color(0xFFFF5722), Color(0xFF795548), Color(0xFF607D8B), //
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SwatchRow(
          icon: Broken.blend_2,
          tooltip: () => lang.tones,
          grid: _TonesGrid(
            controller: controller,
          ),
        ),
        if (recentColors.isNotEmpty)
          _SwatchRow(
            icon: Broken.clock,
            tooltip: () => lang.recent,
            grid: _ThemedSwatchGrid(
              controller: controller,
              colors: recentColors,
              maxRows: 1,
              shouldKeepAlpha: false,
            ),
          ),
        ObxO(
          rx: suggestedColors,
          builder: (context, suggestedColors) => suggestedColors.isEmpty
              ? const SizedBox()
              : _SwatchRow(
                  icon: Broken.magic_star,
                  tooltip: () => lang.forYou,
                  grid: _ThemedSwatchGrid(
                    controller: controller,
                    colors: suggestedColors,
                    maxRows: 2,
                    shouldKeepAlpha: false,
                  ),
                ),
        ),
        _SwatchRow(
          icon: Broken.color_swatch,
          tooltip: () => lang.presets,
          grid: _ThemedSwatchGrid(
            controller: controller,
            colors: _kMaterialPresets,
            maxRows: null,
            shouldKeepAlpha: true,
          ),
        ),
      ],
    );
  }
}

class _SwatchRow extends StatelessWidget {
  final IconData icon;
  final String Function() tooltip;
  final Widget grid;

  const _SwatchRow({
    required this.icon,
    required this.tooltip,
    required this.grid,
  });

  static const _kIconCellWidth = 28.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _kIconCellWidth,
            height: _RenderSwatchGrid.kMinSwatchExtent,
            child: NamidaTooltip(
              message: tooltip,
              child: NIcon(
                icon,
                size: 18.0,
                color: const NColors(.icon, opacity: 0.7),
              ),
            ),
          ),
          const SizedBox(
            width: 6.0,
          ),
          Expanded(
            child: grid,
          ),
        ],
      ),
    );
  }
}

class _TonesGrid extends StatelessWidget {
  final _ColorPickerController controller;

  const _TonesGrid({required this.controller});

  static const _kLightestTone = 95;
  static const _kDarkestTone = 10;

  static List<Color> _computeTonesLightToDark(Color color, int count) {
    if (count <= 1) return [color];
    final hct = Hct.fromInt(color.intValue);
    final palette = TonalPalette.of(hct.hue, hct.chroma);
    final toneStep = (_kLightestTone - _kDarkestTone) / (count - 1);
    return List<Color>.generate(
      count,
      (i) {
        final tone = (_kLightestTone - i * toneStep).round();
        return Color(palette.get(tone));
      },
      growable: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutWidthProvider(
      builder: (context, maxWidth) {
        final count = _RenderSwatchGrid.columnsFor(maxWidth);
        return ObxO(
          rx: controller.settledColor,
          builder: (context, settledColor) {
            final tones = _computeTonesLightToDark(settledColor, count);
            return _ThemedSwatchGrid(
              controller: controller,
              colors: tones,
              maxRows: 1,
              shouldKeepAlpha: true,
            );
          },
        );
      },
    );
  }
}

class _ThemedSwatchGrid extends StatelessWidget {
  final _ColorPickerController controller;
  final List<Color> colors;
  final int? maxRows;
  final bool shouldKeepAlpha;

  const _ThemedSwatchGrid({
    required this.controller,
    required this.colors,
    required this.maxRows,
    required this.shouldKeepAlpha,
  });

  @override
  Widget build(BuildContext context) {
    return NBuilder(
      builder: (context, colors) {
        final gridColors = (
          background: colors.dialogBackground,
          outline: colors.onSurface.withOpacityExt(0.18),
          selection: colors.onSurface.withOpacityExt(0.85),
        );
        return _SwatchGrid(
          controller: controller,
          colors: this.colors,
          maxRows: maxRows,
          shouldKeepAlpha: shouldKeepAlpha,
          gridColors: gridColors,
        );
      },
    );
  }
}

abstract final class _ColorCodec {
  static final _hexRegex = RegExp(r'^(?:#|0x)?([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$', caseSensitive: false);
  static final _rgbRegex = RegExp(r'^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*([\d.]+)\s*(%?)\s*)?\)$', caseSensitive: false);

  static String toRgbHex(Color color) {
    final rgb = color.intValue & 0xFFFFFF;
    final hexText = rgb.toRadixString(16).padLeft(6, '0');
    return hexText.toUpperCase();
  }

  static String toArgbHex(Color color) {
    final hexText = color.intValue.toRadixString(16).padLeft(8, '0');
    return hexText.toUpperCase();
  }

  /// accepts `rgb`, `rrggbb` and `aarrggbb` (with or without `#` or `0x`), `rgb(r, g, b)` and `rgba(r, g, b, a)`.
  static _ParsedColor? tryParse(String textPre) {
    final text = textPre.trim();
    final hexMatch = _hexRegex.firstMatch(text);
    if (hexMatch != null) return _parseHexDigits(hexMatch.group(1)!);
    final rgbMatch = _rgbRegex.firstMatch(text);
    if (rgbMatch != null) return _parseRgbMatch(rgbMatch);
    return null;
  }

  static String _expandShortHex(String digits) => digits.split('').map((d) => '$d$d').join();

  static _ParsedColor _parseHexDigits(String digitsPre) {
    final digits = digitsPre.length == 3 ? _expandShortHex(digitsPre) : digitsPre;
    final value = int.parse(digits, radix: 16);
    final hasAlpha = digits.length == 8;
    final argb = hasAlpha ? value : 0xFF000000 | value;
    return (color: Color(argb), hasAlpha: hasAlpha);
  }

  static _ParsedColor? _parseRgbMatch(RegExpMatch match) {
    final red = int.parse(match.group(1)!);
    final green = int.parse(match.group(2)!);
    final blue = int.parse(match.group(3)!);
    if (red > 255 || green > 255 || blue > 255) return null;
    final alphaText = match.group(4);
    if (alphaText == null) return (color: Color.fromARGB(255, red, green, blue), hasAlpha: false);
    final alphaValue = double.tryParse(alphaText);
    if (alphaValue == null) return null;
    final isPercent = match.group(5) == '%';
    final alphaFraction = isPercent ? alphaValue / 100.0 : alphaValue;
    final alpha = alphaFraction.clampDouble(0.0, 1.0);
    return (color: Color.fromRGBO(red, green, blue, alpha), hasAlpha: true);
  }
}

enum _ColorInputMode {
  hex(label: 'HEX', channelLabels: [], channelMaxValues: []),
  rgb(label: 'RGB', channelLabels: ['R', 'G', 'B'], channelMaxValues: [255, 255, 255]),
  hsl(label: 'HSL', channelLabels: ['H', 'S', 'L'], channelMaxValues: [360, 100, 100]),
  ;

  final String label;
  final List<String> channelLabels;
  final List<int> channelMaxValues;

  const _ColorInputMode({
    required this.label,
    required this.channelLabels,
    required this.channelMaxValues,
  });

  _ColorInputMode nextMode() => values[(index + 1) % values.length];

  List<int> channelsOf(Color color) => switch (this) {
    hex => const [],
    rgb => [(color.r * 255.0).round(), (color.g * 255.0).round(), (color.b * 255.0).round()],
    hsl => _hslChannelsOf(color),
  };

  static List<int> _hslChannelsOf(Color color) {
    final hsl = HSLColor.fromColor(color);
    return [hsl.hue.round(), (hsl.saturation * 100.0).round(), (hsl.lightness * 100.0).round()];
  }

  Color? opaqueColorOfChannels(List<int> channels) => switch (this) {
    hex => null,
    rgb => Color.fromARGB(255, channels[0], channels[1], channels[2]),
    hsl => HSLColor.fromAHSL(1.0, channels[0].toDouble(), channels[1] / 100.0, channels[2] / 100.0).toColor(),
  };
}

typedef _PickedColor = ({HSVColor hsv, Color color});
typedef _ParsedColor = ({Color color, bool hasAlpha});
