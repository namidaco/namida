// by claude, no mistakes.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:namida/controller/text_suggestions_provider.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

/// Wraps a text field with a suggestions dropdown, values are fetched & filtered only while focused.
class TextFieldSuggestionsDropdown extends StatefulWidget {
  final TextSuggestionsProvider provider;
  final TextSuggestionsSource source;
  final TextEditingController controller;
  final void Function(String value)? onChanged;
  final Widget Function(BuildContext context, FocusNode focusNode) builder;
  final double maxHeight;

  const TextFieldSuggestionsDropdown({
    super.key,
    required this.provider,
    required this.source,
    required this.controller,
    required this.builder,
    this.onChanged,
    this.maxHeight = 224.0,
  });

  @override
  State<TextFieldSuggestionsDropdown> createState() => _TextFieldSuggestionsDropdownState();
}

class _TextFieldSuggestionsDropdownState extends State<TextFieldSuggestionsDropdown> {
  static const _itemExtent = 32.0;
  static const _verticalPadding = 6.0;
  static const _fieldGap = 6.0;

  final _portalController = OverlayPortalController();
  final _focusNode = FocusNode();
  final _results = ValueNotifier<List<String>>(const []);

  late RegExp? _separatorsRegex;

  TextSuggestionsValues? _values;
  String? _lastText;
  String? _lastQuery;

  @override
  void initState() {
    super.initState();
    _fillSourceConfig();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant TextFieldSuggestionsDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _fillSourceConfig();
      _values = null;
      _lastText = null;
      _lastQuery = null;
      if (_focusNode.hasFocus) _refresh(force: true);
    }
    if (oldWidget.controller != widget.controller && _focusNode.hasFocus) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _refresh(force: true);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _results.dispose();
    super.dispose();
  }

  void _fillSourceConfig() {
    final source = widget.source;
    _separatorsRegex = source.isMultiValue ? TextSuggestionsMatcher.buildSeparatorsRegex(source.buildSeparators()) : null;
  }

  void _show() {
    if (!_portalController.isShowing) _portalController.show();
  }

  void _hide() {
    if (_portalController.isShowing) _portalController.hide();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      widget.controller.addListener(_onTextChanged);
      _refresh(force: true);
    } else {
      widget.controller.removeListener(_onTextChanged);
      _hide();
      _results.value = const [];
      _lastText = null;
      _lastQuery = null;
    }
  }

  void _onTextChanged() => _refresh();

  void _onTapOutside(PointerDownEvent event) => _hide();

  void _onTapInside(PointerDownEvent event) {
    if (!_portalController.isShowing && _focusNode.hasFocus) _refresh(force: true);
  }

  void _refresh({bool force = false}) {
    final value = widget.controller.value;
    final parsed = TextSuggestionsMatcher.parse(value, _separatorsRegex);
    if (!force && parsed.query == _lastQuery && value.text == _lastText) return;
    _lastQuery = parsed.query;
    _lastText = value.text;

    // -- library values are computed only once a field is actually used.
    final values = _values ??= widget.provider.valuesFor(widget.source);

    final results = TextSuggestionsMatcher.filter(
      values: values,
      query: parsed.query,
      excludeLowercased: parsed.excludeLowercased,
    );
    _results.value = results;
    results.isEmpty ? _hide() : _show();
  }

  void _onSelect(String suggestion) {
    widget.controller.value = TextSuggestionsMatcher.applySuggestion(
      current: widget.controller.value,
      suggestion: suggestion,
      separatorsRegex: _separatorsRegex,
    );
    widget.onChanged?.call(widget.controller.text);
  }

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo layoutInfo) {
    if (layoutInfo.childPaintTransform.determinant() == 0.0) return const SizedBox.shrink(); // -- field isnt visible

    final fieldSize = layoutInfo.childSize;
    final invertTransform = layoutInfo.childPaintTransform.clone()..invert();
    final overlayRect = MediaQuery.paddingOf(context).deflateRect(
      MediaQuery.viewInsetsOf(context).deflateRect(Offset.zero & layoutInfo.overlaySize),
    );
    final overlayRectInField = MatrixUtils.transformRect(invertTransform, overlayRect);

    final spaceAbove = -overlayRectInField.top - _fieldGap;
    final spaceBelow = overlayRectInField.bottom - fieldSize.height - _fieldGap;
    final opensUp = spaceBelow < spaceAbove;
    final maxHeight = math.min(widget.maxHeight, math.max(opensUp ? spaceAbove : spaceBelow, 0.0));
    if (maxHeight < _itemExtent) return const SizedBox.shrink();

    return ValueListenableBuilder(
      valueListenable: _results,
      builder: (context, results, _) {
        if (results.isEmpty) return const SizedBox.shrink();
        final height = math.min(maxHeight, results.length * _itemExtent + _verticalPadding * 2);
        final originY = opensUp ? -height - _fieldGap : fieldSize.height + _fieldGap;
        return Transform(
          transform: layoutInfo.childPaintTransform.clone()..translateByDouble(0.0, originY, 0.0, 1.0),
          child: Align(
            alignment: Alignment.topLeft,
            child: TapRegion(
              groupId: this,
              child: TextFieldTapRegion(
                child: _SuggestionsList(
                  width: fieldSize.width,
                  height: height,
                  itemExtent: _itemExtent,
                  verticalPadding: _verticalPadding,
                  suggestions: results,
                  onTap: _onSelect,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portalController,
      overlayChildBuilder: _buildOverlay,
      // -- the field & the dropdown share the group, tapping anywhere else dismisses it.
      child: TapRegion(
        groupId: this,
        onTapOutside: _onTapOutside,
        onTapInside: _onTapInside,
        child: widget.builder(context, _focusNode),
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  final double width;
  final double height;
  final double itemExtent;
  final double verticalPadding;
  final List<String> suggestions;
  final void Function(String suggestion) onTap;

  const _SuggestionsList({
    required this.width,
    required this.height,
    required this.itemExtent,
    required this.verticalPadding,
    required this.suggestions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final borderRadius = BorderRadius.circular(10.0.multipliedRadius);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Color.alphaBlend(theme.cardColor, theme.scaffoldBackgroundColor),
        borderRadius: borderRadius,
        border: Border.all(color: theme.dividerColor.withOpacityExt(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacityExt(0.2),
            blurRadius: 12.0,
            offset: const Offset(0, 4.0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SuperSmoothListView.builder(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          itemCount: suggestions.length,
          itemExtent: itemExtent,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return NamidaInkWell(
              width: width,
              borderRadius: 6.0,
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              alignment: Alignment.centerLeft,
              onTap: () => onTap(suggestion),
              child: Text(
                suggestion,
                style: context.textTheme.displaySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ),
    );
  }
}

class TextSuggestionsChipsRow extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String suggestion) onTap;
  final EdgeInsetsGeometry? padding;

  const TextSuggestionsChipsRow({
    super.key,
    required this.suggestions,
    required this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = context.theme.colorScheme.secondaryContainer.withOpacityExt(0.25);
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: SizedBox(
        height: 28.0,
        child: SuperSmoothListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return NamidaInkWell(
              margin: const EdgeInsets.only(right: 6.0),
              borderRadius: 99.0,
              bgColor: bgColor,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              onTap: () => onTap(suggestion),
              child: Align(
                alignment: Alignment.center,
                widthFactor: 1.0,
                child: Text(
                  suggestion,
                  style: context.textTheme.displaySmall,
                  maxLines: 1,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
