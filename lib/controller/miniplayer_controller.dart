import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';
import 'package:wakelock/wakelock.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';

class MiniPlayerController {
  static MiniPlayerController get inst => _instance;
  static final MiniPlayerController _instance = MiniPlayerController._internal();
  MiniPlayerController._internal();

  /// Height percentage for miniplayer
  final RxDouble miniplayerHP = 0.0.obs;

  /// Height percentage for miniplayer queue
  final RxDouble miniplayerQueueHP = 0.0.obs;

  /// Used to temporarily hold the seek value.
  RxDouble seekValue = 0.0.obs;

  /// Indicates that play/pause button is currently pressed.
  RxBool isPlayPauseButtonHighlighted = false.obs;

  /// Prevents Listener while reorderding or dismissing items inside queue.
  bool isReorderingQueue = false;

  /// Icon that represents the direction of the current track
  Rx<IconData> arrowIcon = Broken.cd.obs;

  final ScrollController queueScrollController = ScrollController();

  void initialize(TickerProvider ticker) {
    animation = AnimationController(
      vsync: ticker,
      duration: const Duration(milliseconds: 500),
      upperBound: 2.1,
      lowerBound: -0.1,
      value: 0.0,
    );
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      animation.addListener(() {
        final p = animation.value;
        miniplayerHP.value = p.clamp(0.0, 1.0);
        miniplayerQueueHP.value = (p.clamp(1.0, 3.0) - 1.0).clamp(0.0, 1.0);
      });
    });
  }

  void initializeSAnim(TickerProvider ticker) {
    final media = MediaQueryData.fromView(window);
    topInset = media.padding.top;
    bottomInset = media.padding.bottom;
    screenSize = media.size;
    maxOffset = screenSize.height;
    sMaxOffset = screenSize.width;
    sAnim = AnimationController(
      vsync: ticker,
      lowerBound: -1,
      upperBound: 1,
      value: 0.0,
    );
    updateBottomNavBarRelatedDimensions(SettingsController.inst.enableBottomNavBar.value);
  }

  void updateBottomNavBarRelatedDimensions(bool isEnabled) {
    if (isEnabled) {
      _actuationOffset = 100.0;
      _deadSpace = 100.0;
    } else {
      _actuationOffset = 60.0;
      _deadSpace = 60.0;
    }
    animation.reset();
    verticalSnapping();
  }

  late AnimationController animation;
  late Size screenSize;
  late double topInset;
  late double bottomInset;
  late double maxOffset;
  final _velocity = VelocityTracker.withKind(PointerDeviceKind.touch);
  final Cubic _bouncingCurve = const Cubic(0.175, 0.885, 0.32, 1.125);
  double _offset = 0.0;
  double _prevOffset = 0.0;

  final _headRoom = 50.0;
  late double _actuationOffset; // Min distance to snap
  late double _deadSpace; // Distance from bottom to ignore swipes

  /// Horizontal track switching
  late double sMaxOffset;
  late AnimationController sAnim;
  final _sActuationMulti = 1.5;
  double _sOffset = 0.0;
  double _sPrevOffset = 0.0;
  double stParallax = 1.0;
  double siParallax = 1.15;

  bool bounceUp = false;
  bool bounceDown = false;

  void animateQueueToCurrentTrack({bool jump = false}) {
    if (queueScrollController.hasClients) {
      double trackTileItemScrollOffsetInQueue() => Dimensions.inst.trackTileItemExtent * Player.inst.currentIndex.value - screenSize.height * 0.3;

      if (jump) {
        queueScrollController.jumpTo(trackTileItemScrollOffsetInQueue());
      } else {
        queueScrollController.animateTo(
          trackTileItemScrollOffsetInQueue(),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutQuart,
        );
      }
    }
  }

  Future<bool> onWillPop() async {
    bool val = true;
    // final isMini = maxOffset == 0;
    final isExpanded = _offset == maxOffset;
    final isQueue = _offset > maxOffset;
    if (isQueue) {
      snapToExpanded();
      val = false;
    }
    if (isExpanded) {
      snapToMini();
      val = false;
    }

    return val;
  }

  void onPointerDown(PointerDownEvent event) {
    if (isReorderingQueue) return;
    if (event.position.dy >= screenSize.height - _deadSpace) return;

    _velocity.addPosition(event.timeStamp, event.position);

    _prevOffset = _offset;

    bounceUp = false;
    bounceDown = false;
  }

  bool _isInsideQueue() => queueScrollController.positions.isNotEmpty && queueScrollController.positions.first.pixels > 0.0 && _offset >= maxOffset * 2;

  void onPointerMove(PointerMoveEvent event) {
    if (isReorderingQueue) return;
    if (event.position.dy >= screenSize.height - _deadSpace) return;

    _velocity.addPosition(event.timeStamp, event.position);

    if (_offset <= maxOffset) return;
    if (_isInsideQueue()) return;

    _offset -= event.delta.dy;
    _offset = _offset.clamp(-_headRoom, maxOffset * 2);

    animation.animateTo(_offset / maxOffset, duration: Duration.zero);
  }

  void onPointerUp(PointerUpEvent event) {
    if (isReorderingQueue) return;
    if (_offset <= maxOffset || _offset >= (maxOffset * 2)) return;

    if (_isInsideQueue()) return;
    verticalSnapping();
  }

  void gestureDetectorOnTap() {
    if (animation.value < (_actuationOffset / maxOffset)) {
      snapToExpanded();
    }
  }

  void gestureDetectorOnVerticalDragUpdate(DragUpdateDetails details) {
    if (details.globalPosition.dy > screenSize.height - _deadSpace) return;
    if (_offset > maxOffset) return;

    _offset -= details.primaryDelta ?? 0;
    _offset = _offset.clamp(-_headRoom, maxOffset * 2 + _headRoom / 2);

    animation.animateTo(_offset / maxOffset, duration: Duration.zero);
  }

  void gestureDetectorOnHorizontalDragStart(DragStartDetails details) {
    if (_offset > maxOffset) return;
    _sPrevOffset = _sOffset;
  }

  void gestureDetectorOnHorizontalDragUpdate(DragUpdateDetails details) {
    if (_offset > maxOffset) return;
    if (details.globalPosition.dy > screenSize.height - _deadSpace) return;

    _sOffset -= details.primaryDelta ?? 0.0;
    _sOffset = _sOffset.clamp(-sMaxOffset, sMaxOffset);

    sAnim.animateTo(_sOffset / sMaxOffset, duration: Duration.zero);
  }

  void gestureDetectorOnHorizontalDragEnd(DragEndDetails details) {
    if (_offset > maxOffset) return;

    final distance = _sPrevOffset - _sOffset;
    final speed = _velocity.getVelocity().pixelsPerSecond.dx;
    const threshold = 1000.0;

    // speed threshold is an eyeballed value
    // used to actuate on fast flicks too

    if (speed > threshold || distance > _actuationOffset * _sActuationMulti) {
      snapToPrev();
    } else if (-speed > threshold || -distance > _actuationOffset * _sActuationMulti) {
      snapToNext();
    } else {
      _snapToCurrent();
    }
  }

  void verticalSnapping() async {
    final distance = _prevOffset - _offset;
    final speed = _velocity.getVelocity().pixelsPerSecond.dy;
    const threshold = 500.0;

    bool shouldSnapToExpanded = false;
    bool shouldSnapToQueue = false;
    bool shouldSnapToMini = false;

    // speed threshold is an eyeballed value
    // used to actuate on fast flicks too

    if (_prevOffset > maxOffset) {
      // Start from queue
      if (speed > threshold || distance > _actuationOffset) {
        shouldSnapToExpanded = true;
      } else {
        shouldSnapToQueue = true;
      }
    } else if (_prevOffset > maxOffset / 2) {
      // Start from top
      if (speed > threshold || distance > _actuationOffset) {
        shouldSnapToMini = true;
      } else if (-speed > threshold || -distance > _actuationOffset) {
        shouldSnapToQueue = true;
      } else {
        shouldSnapToExpanded = true;
      }
    } else {
      // Start from bottom
      if (-speed > threshold || -distance > _actuationOffset) {
        shouldSnapToExpanded = true;
      } else {
        shouldSnapToMini = true;
      }
    }
    if (shouldSnapToExpanded) {
      snapToExpanded();
      _toggleWakelockOn();
    } else {
      if (true) {
        _toggleWakelockOff();
      }
      if (shouldSnapToMini) snapToMini();
      if (shouldSnapToQueue) snapToQueue();
    }
  }

  void _toggleWakelockOn() {
    if (SettingsController.inst.wakelockMode.value == WakelockMode.expanded) {
      Wakelock.enable();
    }
    if (SettingsController.inst.wakelockMode.value == WakelockMode.expandedAndVideo && VideoController.inst.shouldShowVideo) {
      Wakelock.enable();
    }
  }

  void _toggleWakelockOff() {
    Wakelock.disable();
  }

  void snapToExpanded({bool haptic = true}) {
    _offset = maxOffset;
    if (_prevOffset < maxOffset) bounceUp = true;
    if (_prevOffset > maxOffset) bounceDown = true;
    _snap(haptic: haptic);
  }

  void snapToMini({bool haptic = true}) {
    _offset = 0;
    bounceDown = false;
    _snap(haptic: haptic);
  }

  void _updateScrollPositionInQueue() {
    void updateIcon() {
      final pixels = queueScrollController.position.pixels;
      final sizeInSettings = Dimensions.inst.trackTileItemExtent * Player.inst.currentIndex.value - Get.height * 0.3;
      if (pixels > sizeInSettings) {
        arrowIcon.value = Broken.arrow_up_1;
      }
      if (pixels < sizeInSettings) {
        arrowIcon.value = Broken.arrow_down;
      }
      if (pixels == sizeInSettings) {
        arrowIcon.value = Broken.cd;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      animateQueueToCurrentTrack(jump: true);
      updateIcon();
    });

    queueScrollController.removeListener(() {});
    queueScrollController.addListener(() {
      updateIcon();
    });
  }

  void snapToQueue({bool haptic = true}) async {
    _updateScrollPositionInQueue();
    _offset = maxOffset * 2;
    bounceUp = false;
    _snap(haptic: haptic);
  }

  void _snap({bool haptic = true}) {
    animation
        .animateTo(
      _offset / maxOffset,
      curve: _bouncingCurve,
      duration: const Duration(milliseconds: 300),
    )
        .then((_) {
      bounceUp = false;
    });
    if (haptic && (_prevOffset - _offset).abs() > _actuationOffset) HapticFeedback.lightImpact();
  }

  void snapToPrev() async {
    _sOffset = -sMaxOffset;

    await sAnim.animateTo(-1.0, curve: _bouncingCurve, duration: const Duration(milliseconds: 300)).then((_) {
      _sOffset = 0;
      sAnim.animateTo(0.0, duration: Duration.zero);
    });
    await Player.inst.previous();
    if ((_sPrevOffset - _sOffset).abs() > _actuationOffset) HapticFeedback.lightImpact();
  }

  void _snapToCurrent() {
    _sOffset = 0;
    sAnim.animateTo(0.0, curve: _bouncingCurve, duration: const Duration(milliseconds: 300));
    if ((_sPrevOffset - _sOffset).abs() > _actuationOffset) HapticFeedback.lightImpact();
  }

  void snapToNext() async {
    _sOffset = sMaxOffset;

    await sAnim.animateTo(1.0, curve: _bouncingCurve, duration: const Duration(milliseconds: 300)).then((_) {
      _sOffset = 0;
      sAnim.animateTo(0.0, duration: Duration.zero);
    });
    await Player.inst.next();

    if ((_sPrevOffset - _sOffset).abs() > _actuationOffset) HapticFeedback.lightImpact();
  }
}
