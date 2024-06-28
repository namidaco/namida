import 'package:flutter/material.dart';

class NamidaReadMoreText extends StatefulWidget {
  final TextSpan span;
  final int lines;
  final Locale? locale;
  final Widget Function(
    TextSpan span,
    int? lines,
    bool isExpanded,
    bool exceededMaxLines,
    void Function() toggle,
  ) builder;

  const NamidaReadMoreText({
    super.key,
    required this.span,
    required this.lines,
    this.locale,
    required this.builder,
  });

  @override
  State<NamidaReadMoreText> createState() => _ReadMoreTextState();
}

class _ReadMoreTextState extends State<NamidaReadMoreText> {
  bool _isTextExpanded = false;
  void _onReadMoreClicked() => setState(() => _isTextExpanded = !_isTextExpanded);

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale ?? Localizations.maybeLocaleOf(context);
    final tp = TextPainter(
      text: widget.span,
      locale: locale,
      maxLines: widget.lines,
      textDirection: Directionality.of(context),
    );
    bool exceededMaxLines = false;
    try {
      tp.layout();
      exceededMaxLines = tp.didExceedMaxLines;
    } catch (_) {}
    tp.dispose();
    return widget.builder(
      widget.span,
      _isTextExpanded || !exceededMaxLines ? null : widget.lines,
      _isTextExpanded,
      exceededMaxLines,
      _onReadMoreClicked,
    );
  }
}
