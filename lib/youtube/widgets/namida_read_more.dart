import 'package:flutter/material.dart';

class NamidaReadMoreText extends StatefulWidget {
  final String text;
  final int lines;
  final Locale? locale;
  final Widget Function(
    String text,
    int? lines,
    bool isExpanded,
    bool exceededMaxLines,
    void Function() toggle,
  ) builder;

  const NamidaReadMoreText({
    super.key,
    required this.text,
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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final locale = widget.locale ?? Localizations.maybeLocaleOf(context);
        final span = TextSpan(text: widget.text);
        final tp = TextPainter(
          text: span,
          locale: locale,
          maxLines: widget.lines,
          textDirection: Directionality.of(context),
        );
        tp.layout(maxWidth: constraints.maxWidth);
        final exceededMaxLines = tp.didExceedMaxLines;
        tp.dispose();
        return widget.builder(
          widget.text,
          _isTextExpanded || !exceededMaxLines ? null : widget.lines,
          _isTextExpanded,
          exceededMaxLines,
          _onReadMoreClicked,
        );
      },
    );
  }
}
