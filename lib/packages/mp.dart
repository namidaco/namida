library miniplayer;

import 'dart:async';

import 'package:flutter/material.dart';

///Type definition for the builder function
typedef MiniplayerBuilder = Widget Function(double height, double percentage);

///Type definition for ondismiss. Will be used in a future version.
typedef DismissCallback = void Function(double percentage);

///Miniplayer class
class Miniplayer extends StatefulWidget {
  ///Required option to set the minimum and maximum height
  final double minHeight, maxHeight;

  ///Option to enable and set elevation for the miniplayer
  final double elevation;

  ///Central API-Element
  ///Provides a builder with useful information
  final MiniplayerBuilder builder;

  ///Option to set the animation curve
  final Curve curve;

  ///Sets the decoration of the miniplayer
  final BoxDecoration? decoration;

  ///Option to set the animation duration
  final Duration duration;

  ///Allows you to use a global ValueNotifier with the current progress.
  ///This can be used to hide the BottomNavigationBar.
  final ValueNotifier<double>? valueNotifier;

  ///Deprecated
  @Deprecated("Migrate ondismiss to ondismissed as ondismiss will be used differently in a future version.")
  final Function? ondismiss;

  ///If ondismissed is set, the miniplayer can be dismissed
  final Function? ondismissed;

  //Allows you to manually control the miniplayer in code
  final MiniplayerController? controller;

  const Miniplayer({
    Key? key,
    required this.minHeight,
    required this.maxHeight,
    required this.builder,
    this.curve = Curves.easeOut,
    this.elevation = 0,
    this.decoration,
    this.valueNotifier,
    this.duration = const Duration(milliseconds: 300),
    this.ondismiss,
    this.ondismissed,
    this.controller,
  }) : super(key: key);

  @override
  State<Miniplayer> createState() => _MiniplayerState();
}

class _MiniplayerState extends State<Miniplayer> with TickerProviderStateMixin {
  late ValueNotifier<double> heightNotifier;
  ValueNotifier<double> dragDownPercentage = ValueNotifier(0);

  ///Temporary variable as long as ondismiss is deprecated. Will be removed in a future version.
  Function? ondismissed;

  ///Current y position of drag gesture
  late double _dragHeight;

  ///Used to determine SnapPosition
  late double _startHeight;

  bool dismissed = false;

  bool animating = false;

  ///Counts how many updates were required for a distance (onPanUpdate) -> necessary to calculate the drag speed
  int updateCount = 0;

  final StreamController<double> _heightController = StreamController<double>.broadcast();
  AnimationController? _animationController;

  void _statusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) _resetAnimationController();
  }

  void _resetAnimationController({Duration? duration}) {
    if (_animationController != null) _animationController!.dispose();
    _animationController = AnimationController(
      vsync: this,
      duration: duration ?? widget.duration,
    );
    _animationController!.addStatusListener(_statusListener);
    animating = false;
  }

  @override
  void initState() {
    if (widget.valueNotifier == null) {
      heightNotifier = ValueNotifier(widget.minHeight);
    } else {
      heightNotifier = widget.valueNotifier!;
    }

    _resetAnimationController();

    _dragHeight = heightNotifier.value;

    if (widget.controller != null) {
      widget.controller!.addListener(controllerListener);
    }

    if (widget.ondismissed != null) {
      ondismissed = widget.ondismissed;
    } else {
      // ignore: deprecated_member_use_from_same_package
      ondismissed = widget.ondismiss;
    }

    super.initState();
  }

  @override
  void dispose() {
    _heightController.close();
    if (_animationController != null) _animationController!.dispose();

    if (widget.controller != null) {
      widget.controller!.removeListener(controllerListener);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (dismissed) return Container();

    return WillPopScope(
      onWillPop: () async {
        if (heightNotifier.value > widget.minHeight) {
          _snapToPosition(PanelState.min);
          return false;
        }
        return true;
      },
      child: ValueListenableBuilder(
        valueListenable: heightNotifier,
        builder: (BuildContext context, double height, Widget? _) {
          var percentage = ((height - widget.minHeight)) / (widget.maxHeight - widget.minHeight);

          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              if (percentage > 0)
                GestureDetector(
                  onTap: () => _animateToHeight(widget.minHeight),
                  child: Opacity(
                    opacity: borderDouble(minRange: 0.0, maxRange: 1.0, value: percentage),
                    child: Container(color: widget.decoration?.color ?? Colors.transparent),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: height,
                  child: GestureDetector(
                    child: ValueListenableBuilder(
                      valueListenable: dragDownPercentage,
                      builder: (BuildContext context, double value, Widget? child) {
                        if (value == 0) return child!;

                        return Opacity(
                          opacity: borderDouble(minRange: 0.0, maxRange: 1.0, value: 1 - value * 0.8),
                          child: Transform.translate(
                            offset: Offset(0.0, widget.minHeight * value * 0.5),
                            child: child,
                          ),
                        );
                      },
                      child: Material(
                        type: MaterialType.transparency,
                        child: Container(
                          constraints: const BoxConstraints.expand(),
                          decoration: widget.decoration,
                          child: widget.builder(height, percentage),
                        ),
                      ),
                    ),
                    onTap: () => _snapToPosition(_dragHeight != widget.maxHeight ? PanelState.max : PanelState.min),
                    onPanStart: (details) {
                      _startHeight = _dragHeight;
                      updateCount = 0;

                      if (animating) _resetAnimationController();
                    },
                    onPanEnd: (details) async {
                      ///Calculates drag speed
                      double speed = (_dragHeight - _startHeight * _dragHeight < _startHeight ? 1 : -1) / updateCount * 100;

                      ///Define the percentage distance depending on the speed with which the widget should snap
                      double snapPercentage = 0.005;
                      if (speed <= 4) {
                        snapPercentage = 0.2;
                      } else if (speed <= 9) {
                        snapPercentage = 0.08;
                      } else if (speed <= 50) {
                        snapPercentage = 0.01;
                      }

                      ///Determine to which SnapPosition the widget should snap
                      PanelState snap = PanelState.min;

                      final percentageMax = percentageFromValueInRange(min: widget.minHeight, max: widget.maxHeight, value: _dragHeight);

                      ///Started from expanded state
                      if (_startHeight > widget.minHeight) {
                        if (percentageMax > 1 - snapPercentage) {
                          snap = PanelState.max;
                        }
                      }

                      ///Started from minified state
                      else {
                        if (percentageMax > snapPercentage) {
                          snap = PanelState.max;
                        } else

                        ///dismissedPercentage > 0.2 -> dismiss
                        if (ondismissed != null && percentageFromValueInRange(min: widget.minHeight, max: 0, value: _dragHeight) > snapPercentage) {
                          snap = PanelState.dismiss;
                        }
                      }

                      ///Snap to position
                      _snapToPosition(snap);
                    },
                    onPanUpdate: (details) {
                      if (dismissed) return;

                      _dragHeight -= details.delta.dy;
                      updateCount++;

                      _handleHeightChange();
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  ///Determines whether the panel should be updated in height or discarded
  void _handleHeightChange({bool animation = false}) {
    ///Drag above minHeight
    if (_dragHeight >= widget.minHeight) {
      if (dragDownPercentage.value != 0) dragDownPercentage.value = 0;

      if (_dragHeight > widget.maxHeight) return;

      heightNotifier.value = _dragHeight;
    }

    ///Drag below minHeight
    else if (ondismissed != null) {
      var percentageDown = borderDouble(minRange: 0.0, maxRange: 1.0, value: percentageFromValueInRange(min: widget.minHeight, max: 0, value: _dragHeight));

      if (dragDownPercentage.value != percentageDown) {
        dragDownPercentage.value = percentageDown;
      }

      if (percentageDown >= 1 && animation && !dismissed) {
        if (ondismissed != null) ondismissed!();
        setState(() {
          dismissed = true;
        });
      }
    }
  }

  ///Animates the panel height according to a SnapPoint
  void _snapToPosition(PanelState snapPosition) {
    switch (snapPosition) {
      case PanelState.max:
        _animateToHeight(widget.maxHeight);
        return;
      case PanelState.min:
        _animateToHeight(widget.minHeight);
        return;
      case PanelState.dismiss:
        _animateToHeight(0);
        return;
    }
  }

  ///Animates the panel height to a specific value
  void _animateToHeight(final double h, {Duration? duration}) {
    if (_animationController == null) return;
    final startHeight = _dragHeight;

    if (duration != null) _resetAnimationController(duration: duration);

    Animation<double> sizeAnimation = Tween(
      begin: startHeight,
      end: h,
    ).animate(CurvedAnimation(parent: _animationController!, curve: widget.curve));

    sizeAnimation.addListener(() {
      if (sizeAnimation.value == startHeight) return;

      _dragHeight = sizeAnimation.value;

      _handleHeightChange(animation: true);
    });

    animating = true;
    _animationController!.forward(from: 0);
  }

  //Listener function for the controller
  void controllerListener() {
    if (widget.controller == null) return;
    if (widget.controller!.value == null) return;

    switch (widget.controller!.value!.height) {
      case -1:
        _animateToHeight(
          widget.minHeight,
          duration: widget.controller!.value!.duration,
        );
        break;
      case -2:
        _animateToHeight(
          widget.maxHeight,
          duration: widget.controller!.value!.duration,
        );
        break;
      case -3:
        _animateToHeight(
          0,
          duration: widget.controller!.value!.duration,
        );
        break;
      default:
        _animateToHeight(
          widget.controller!.value!.height.toDouble(),
          duration: widget.controller!.value!.duration,
        );
        break;
    }
  }
}

///-1 Min, -2 Max, -3 dismiss
enum PanelState { max, min, dismiss }

//ControllerData class. Used for the controller
class ControllerData {
  final int height;
  final Duration? duration;

  const ControllerData(this.height, this.duration);
}

//MiniplayerController class
class MiniplayerController extends ValueNotifier<ControllerData?> {
  MiniplayerController() : super(null);

  //Animates to a given height or state(expanded, dismissed, ...)
  void animateToHeight({double? height, PanelState? state, Duration? duration}) {
    if (height == null && state == null) {
      throw ("Miniplayer: One of the two parameters, height or status, is required.");
    }

    if (height != null && state != null) {
      throw ("Miniplayer: Only one of the two parameters, height or status, can be specified.");
    }

    ControllerData? valBefore = value;

    if (state != null) {
      value = ControllerData(state.heightCode, duration);
    } else {
      if (height! < 0) return;

      value = ControllerData(height.round(), duration);
    }

    if (valBefore == value) notifyListeners();
  }
}

extension SelectedColorExtension on PanelState {
  int get heightCode {
    switch (this) {
      case PanelState.min:
        return -1;
      case PanelState.max:
        return -2;
      case PanelState.dismiss:
        return -3;
      default:
        return -1;
    }
  }
}

///Calculates the percentage of a value within a given range of values
double percentageFromValueInRange({required double min, required double max, required double value}) {
  return (value - min) / (max - min);
}

double borderDouble({required double minRange, required double maxRange, required double value}) {
  if (value > maxRange) return maxRange;
  if (value < minRange) return minRange;
  return value;
}
