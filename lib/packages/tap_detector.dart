// Source: https://github.com/ManuelRohrauer/inkwell_splash

import 'dart:async';

import 'package:flutter/material.dart';

// ignore: must_be_immutable
class TapDetector extends StatelessWidget {
  TapDetector({
    super.key,
    this.child,
    this.onTap,
    this.onDoubleTap,
    this.doubleTapTime = const Duration(milliseconds: 300),
    this.onLongPress,
    this.onTapDown,
    this.onTapCancel,
    this.onHighlightChanged,
    this.onHover,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.splashFactory,
    this.radius,
    this.borderRadius,
    this.customBorder,
    this.enableFeedback = true,
    this.excludeFromSemantics = false,
    this.focusNode,
    this.canRequestFocus = true,
    this.onFocusChange,
    this.autofocus = false,
    this.useGestureDetector = true,
  })  : assert(enableFeedback != null),
        assert(excludeFromSemantics != null),
        assert(autofocus != null),
        assert(canRequestFocus != null);

  final Widget? child;
  final GestureTapDownCallback? onTap;
  final GestureTapDownCallback? onDoubleTap;
  final Duration doubleTapTime;
  final GestureLongPressCallback? onLongPress;
  final GestureTapDownCallback? onTapDown;
  final GestureTapCancelCallback? onTapCancel;
  final ValueChanged<bool>? onHighlightChanged;
  final ValueChanged<bool>? onHover;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? highlightColor;
  final Color? splashColor;
  final InteractiveInkFeatureFactory? splashFactory;
  final double? radius;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final bool? enableFeedback;
  final bool? excludeFromSemantics;
  final FocusNode? focusNode;
  final bool? canRequestFocus;
  final ValueChanged<bool>? onFocusChange;
  final bool? autofocus;
  final bool useGestureDetector;

  Timer? doubleTapTimer;
  bool isPressed = false;
  bool isSingleTap = false;
  bool isDoubleTap = false;

  late TapDownDetails lastTapDetails;

  void _doubleTapTimerElapsed() {
    if (isPressed) {
      isSingleTap = true;
    } else {
      if (onTap != null) onTap!(lastTapDetails);
    }
  }

  void _onTap() {
    isPressed = false;
    if (isSingleTap) {
      isSingleTap = false;
      if (onTap != null) onTap?.call(lastTapDetails); // call user onTap function
    }
    if (isDoubleTap) {
      isDoubleTap = false;
      if (onDoubleTap != null) onDoubleTap!(lastTapDetails);
    }
  }

  void _onTapDown(TapDownDetails details) {
    lastTapDetails = details;
    isPressed = true;
    if (doubleTapTimer?.isActive ?? false) {
      isDoubleTap = true;
      doubleTapTimer?.cancel();
    } else {
      doubleTapTimer = Timer(doubleTapTime, _doubleTapTimerElapsed);
    }
    if (onTapDown != null) onTapDown!(details);
  }

  void _onTapCancel() {
    isPressed = isSingleTap = isDoubleTap = false;
    if (doubleTapTimer?.isActive ?? false) {
      doubleTapTimer?.cancel();
    }
    if (onTapCancel != null) onTapCancel!();
  }

  @override
  Widget build(BuildContext context) {
    return useGestureDetector
        ? GestureDetector(
            key: key,
            onTap: () {
              (onDoubleTap != null) ? _onTap() : onTap?.call(lastTapDetails);
            }, // if onDoubleTap is not used from user, then route further to onTap
            onLongPress: onLongPress,
            onTapDown: (onDoubleTap != null) ? _onTapDown : onTapDown,
            onTapCancel: (onDoubleTap != null) ? _onTapCancel : onTapCancel,
            excludeFromSemantics: excludeFromSemantics ?? false,
            child: child,
          )
        : InkWell(
            key: key,
            onTap: () {
              (onDoubleTap != null) ? _onTap() : onTap?.call(lastTapDetails);
            }, // if onDoubleTap is not used from user, then route further to onTap
            onLongPress: onLongPress,
            onTapDown: (onDoubleTap != null) ? _onTapDown : onTapDown,
            onTapCancel: (onDoubleTap != null) ? _onTapCancel : onTapCancel,
            onHighlightChanged: onHighlightChanged,
            onHover: onHover,
            focusColor: focusColor,
            hoverColor: hoverColor,
            highlightColor: highlightColor,
            splashColor: splashColor,
            splashFactory: splashFactory,
            radius: radius,
            borderRadius: borderRadius,
            customBorder: customBorder,
            enableFeedback: enableFeedback,
            excludeFromSemantics: excludeFromSemantics ?? false,
            focusNode: focusNode,
            canRequestFocus: canRequestFocus ?? true,
            onFocusChange: onFocusChange,
            autofocus: autofocus ?? false,
            child: child,
          );
  }
}
