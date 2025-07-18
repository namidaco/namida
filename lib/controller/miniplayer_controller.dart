import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/wakelock_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/mp.dart';
import 'package:namida/youtube/class/youtube_id.dart';

class MiniPlayerController {
  static MiniPlayerController get inst => _instance;
  static final MiniPlayerController _instance = MiniPlayerController._internal();
  MiniPlayerController._internal();

  bool get _immersiveModeEnabled => settings.hideStatusBarInExpandedMiniplayer.value;
  bool get _defaultShouldDismissMiniplayer => settings.dismissibleMiniplayer.value;

  final ytMiniplayerKey = GlobalKey<NamidaYTMiniplayerState>();

  bool get isInQueue => animation.value > 1.0;
  bool get isMinimized => animation.value < 1.0;

  /// Used to temporarily hold the seek value.
  final seekValue = 0.obs;

  /// Indicates that play/pause button is currently pressed.
  final isPlayPauseButtonHighlighted = false.obs;

  /// Prevents Listener while reorderding or dismissing items inside queue.
  bool get _isModifyingQueue => Player.inst.isModifyingQueue;

  /// Icon that represents the direction of the current track
  final arrowIcon = Broken.cd.obso;

  bool get _miniplayerIsWideScreen => Dimensions.inst.miniplayerIsWideScreen;

  late final ScrollController queueScrollController = ScrollController()..addListener(_updateIcon);

  Future<void> _onMiniplayerDismiss() async => await Player.inst.clearQueue();

  AnimationController initialize(TickerProvider ticker) {
    animation = AnimationController(
      vsync: ticker,
      duration: const Duration(milliseconds: 500),
      upperBound: 2.03,
      lowerBound: -0.2,
      value: 0.0,
    );
    return animation;
  }

  AnimationController initializeSAnim(TickerProvider ticker) {
    sAnim = AnimationController(
      vsync: ticker,
      lowerBound: -1,
      upperBound: 1,
      value: 0.0,
    );
    updateBottomNavBarRelatedDimensions(settings.enableBottomNavBar.value);
    return sAnim;
  }

  void updateScreenValuesInitial() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final viewPadding = EdgeInsets.fromViewPadding(view.padding, view.devicePixelRatio);
    return _updateScreenValuesInternal(view.physicalSize, viewPadding);
  }

  void updateScreenValues(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    return _updateScreenValuesInternal(mediaSize, viewPadding);
  }

  void _updateScreenValuesInternal(Size mediaSize, EdgeInsets viewPadding) {
    if (NamidaChannel.inst.isInPip.value || NamidaNavigator.inst.isInFullScreen) return; // messes up things so we ignore

    topInset = viewPadding.top;
    bottomInset = viewPadding.bottom;
    rightInset = viewPadding.right / 2;

    final miniplayerDetails = _getPlayerDetails(
      screenWidth: mediaSize.width,
      screenHeight: mediaSize.height,
    );
    final isWidescreen = miniplayerDetails.isWidescreen;
    double maxWidth = miniplayerDetails.maxWidth;
    if (isWidescreen) maxWidth += rightInset;

    screenSize = Size(maxWidth, mediaSize.height);
    maxOffset = screenSize.height;
    sMaxOffset = maxWidth;

    if (isWidescreen && !Dimensions.inst.miniplayerIsWideScreen) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (animation.value <= 1) {
            // -- make sure its not minimized when its widescreen
            this.ytMiniplayerKey.currentState?.animateToState(true, dur: Duration.zero);
            this.snapToExpanded();
          } else {
            this.snapToQueue();
          }
        },
      );

      // -- its widescreen, so immersive mode is always on
      setImmersiveMode(settings.hideStatusBarInExpandedMiniplayer.value, isWidescreen: isWidescreen);
    } else if (!isWidescreen && Dimensions.inst.miniplayerIsWideScreen) {
      // -- to fix various issues (_offset and animation mismatch)
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (isInQueue) {
            this.snapToQueue();
          } else {
            this.snapToMini();
            this.ytMiniplayerKey.currentState?.animateToState(false, dur: Duration.zero, bypassEnforceExpanded: true);
          }
        },
      );

      // now portrait. do immersive mode if its expanded.
      setImmersiveMode(settings.hideStatusBarInExpandedMiniplayer.value, isWidescreen: isWidescreen);
    }

    Dimensions.inst.miniplayerMaxWidth = maxWidth;
    Dimensions.inst.sideInfoMaxWidth = (mediaSize.width * 0.2).withMaximum(324.0);
    Dimensions.inst.availableAppContentWidth = mediaSize.width - (isWidescreen ? maxWidth : 0);
    Dimensions.inst.miniplayerIsWideScreen = isWidescreen;
  }

  void updateBottomNavBarRelatedDimensions(bool isEnabled) {
    if (isEnabled) {
      _actuationOffset = 100.0;
      _deadSpace = 12.0;
    } else {
      _actuationOffset = 60.0;
      _deadSpace = 12.0;
    }
    animation.reset();
    if (this.ytMiniplayerKey.currentState == null) verticalSnapping();
  }

  static ({double maxWidth, bool isWidescreen}) _getPlayerDetails({required double screenWidth, required double screenHeight}) {
    if (Player.inst.currentItem.value == null) {
      return (maxWidth: 0, isWidescreen: false);
    }

    double maxWidth = screenWidth;
    bool isWidescreen = false;
    if (screenWidth / screenHeight > 1) {
      double fixedW = 400.0;
      if (screenWidth / screenHeight > 1.5) {
        fixedW = screenWidth.withMaximum(screenHeight) * 0.68;
      }
      fixedW = fixedW.withMaximum(screenWidth * 0.4);
      maxWidth = maxWidth.withMaximum(fixedW);
      isWidescreen = true;
    }
    return (maxWidth: maxWidth, isWidescreen: isWidescreen);
  }

  late AnimationController animation;
  late Size screenSize;
  late double topInset;
  late double bottomInset;
  late double rightInset;
  late double maxOffset;
  final _velocity = VelocityTracker.withKind(PointerDeviceKind.touch);
  static const _bouncingCurve = Cubic(0.175, 0.885, 0.32, 1.125);
  static const _bouncingCurveSoft = Cubic(0.150, 0.96, 0.28, 1.04);
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
  static const double kStParallax = 1.0;
  static const double kSiParallax = 1.15;

  bool bounceUp = false;
  bool bounceDown = false;

  double get _currentItemExtent => Player.inst.currentItem.value is YoutubeID ? Dimensions.youtubeCardItemExtent : Dimensions.inst.trackTileItemExtent;

  void animateQueueToCurrentTrack({bool jump = false, bool minZero = false}) {
    if (queueScrollController.hasClients) {
      final trackTileItemScrollOffsetInQueue = _currentItemExtent * Player.inst.currentIndex.value - screenSize.height * 0.3;
      if (queueScrollController.positions.lastOrNull?.pixels == trackTileItemScrollOffsetInQueue) {
        return;
      }
      final finalOffset = minZero ? trackTileItemScrollOffsetInQueue.withMinimum(0) : trackTileItemScrollOffsetInQueue;
      try {
        if (jump) {
          queueScrollController.jumpTo(finalOffset);
        } else {
          queueScrollController.animateToEff(
            finalOffset,
            duration: const Duration(milliseconds: 600),
            curve: Curves.fastEaseInToSlowEaseOut,
          );
        }
      } catch (_) {}
    }
  }

  bool onWillPop() {
    if (_offset > maxOffset) {
      // -- isQueue
      snapToExpanded();
      return false;
    } else if (_offset == maxOffset && !_miniplayerIsWideScreen) {
      // -- isExpanded
      snapToMini();
      return false;
    }

    return true;
  }

  void onPointerDown(PointerDownEvent event) {
    if (_isModifyingQueue) return;
    if (event.position.dy >= screenSize.height - _deadSpace) return;

    _velocity.addPosition(event.timeStamp, event.position);

    _prevOffset = _offset;

    bounceUp = false;
    bounceDown = false;
  }

  bool _isInsideQueue() => _offset >= maxOffset * 2 && (queueScrollController.positions.isNotEmpty && queueScrollController.positions.first.pixels > 0.0);

  bool _canMiniminzeMiniplayer(double dy) {
    if (_miniplayerIsWideScreen && animation.value <= 1 && dy > 0) {
      // -- moving down while miniplayer is always shown
      return false;
    }
    return true;
  }

  void onPointerMove(PointerMoveEvent event) {
    if (_isModifyingQueue) return;
    if (event.position.dy >= screenSize.height - _deadSpace) return;

    if (!_canMiniminzeMiniplayer(event.delta.dy)) return;

    _velocity.addPosition(event.timeStamp, event.position);

    if (_offset <= maxOffset) return;
    // a rough estimation of the top bar when inside queue.
    if (_isInsideQueue() && event.position.dy > screenSize.height * 0.15) return;

    _offset -= event.delta.dy;
    _offset = _offset.clampDouble(-_headRoom, maxOffset * 2);

    animateMiniplayer(_offset / maxOffset);
  }

  void onPointerUp(PointerUpEvent event) {
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
    if (_isModifyingQueue) return;
    if (details.globalPosition.dy > screenSize.height - _deadSpace) return;
    if (_offset > maxOffset) return;
    if (!_canMiniminzeMiniplayer(details.delta.dy)) return;

    _offset -= details.primaryDelta ?? 0;
    _offset = _offset.clampDouble(-_headRoom, maxOffset * 2 + _headRoom / 2);

    animateMiniplayer(_offset / maxOffset);
  }

  void gestureDetectorOnHorizontalDragStart(DragStartDetails details) {
    if (_offset > maxOffset) return;
    _sPrevOffset = _sOffset;
  }

  void gestureDetectorOnHorizontalDragUpdate(DragUpdateDetails details) {
    if (_offset > maxOffset) return;
    if (details.globalPosition.dy > screenSize.height - _deadSpace) return;

    _sOffset -= details.primaryDelta ?? 0.0;
    _sOffset = _sOffset.clampDouble(-sMaxOffset, sMaxOffset);

    sAnim.animateTo(_sOffset / sMaxOffset * 1.25, duration: Duration.zero);
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

    if (distance == _headRoom) {
      if (_defaultShouldDismissMiniplayer) {
        snapToMini();
        _onMiniplayerDismiss();
        return;
      }
    }

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
    } else {
      if (shouldSnapToMini) snapToMini();
      if (shouldSnapToQueue) snapToQueue(animateScrollController: _offset < maxOffset * 1.8);
    }
  }

  void snapToExpanded({bool haptic = true}) async {
    WakelockController.inst.updateMiniplayerStatus(true);
    ScrollSearchController.inst.unfocusKeyboard();

    _offset = maxOffset;
    if (_prevOffset < maxOffset) bounceUp = true;
    if (_prevOffset > maxOffset) bounceDown = true;
    await _snap(haptic: haptic, curve: Curves.fastEaseInToSlowEaseOut);
    if (_immersiveModeEnabled) setImmersiveMode(true);
  }

  void snapToMini({bool haptic = true}) async {
    if (_miniplayerIsWideScreen) return;

    WakelockController.inst.updateMiniplayerStatus(false);
    _offset = 0;
    bounceDown = false;
    await _snap(haptic: haptic, curve: _bouncingCurve);
    if (_immersiveModeEnabled) setImmersiveMode(false);
  }

  /// set [enabled] to null to refresh based on default values.
  Future<void> setImmersiveMode(bool? enabled, {bool? isWidescreen}) async {
    if (NamidaNavigator.inst.isInFullScreen) return;
    if ((enabled ?? _immersiveModeEnabled) && ((isWidescreen ?? Dimensions.inst.miniplayerIsWideScreen) || _isLocalMiniplayerOnlyExpanded())) {
      return await NamidaNavigator.setSystemUIImmersiveMode(true);
    } else {
      return await NamidaNavigator.setSystemUIImmersiveMode(false);
    }
  }

  bool _isLocalMiniplayerOnlyExpanded() {
    // if (this.ytMiniplayerKey.currentState != null) return false; // -- lets include this guy
    return animation.value >= 1;
  }

  void _updateIcon() {
    final sizeInSettings = _currentItemExtent * Player.inst.currentIndex.value - maxOffset * 0.3;
    double pixels;
    try {
      pixels = queueScrollController.positions.first.pixels;
    } catch (_) {
      pixels = sizeInSettings;
    }
    if (pixels > sizeInSettings) {
      arrowIcon.value = Broken.arrow_up_1;
    } else if (pixels < sizeInSettings) {
      arrowIcon.value = Broken.arrow_down;
    } else if (pixels == sizeInSettings) {
      arrowIcon.value = Broken.cd;
    }
  }

  Future<void> snapToQueue({bool animateScrollController = true, bool haptic = true}) async {
    if (isInQueue && _offset >= maxOffset * 2) return;

    WakelockController.inst.updateMiniplayerStatus(false);
    _offset = maxOffset * 2;
    bounceUp = false;

    // prevents scrolling when user is already inside queue, like failed snapping to expanded.
    if (animateScrollController) {
      // updating scroll before snapping makes a nice effect.
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        animateQueueToCurrentTrack(jump: true);
      });
    }
    await _snap(haptic: haptic, curve: _bouncingCurveSoft);
  }

  Future<void> animateMiniplayer(
    double target, {
    Duration duration = Duration.zero,
    Curve curve = Curves.linear,
  }) async {
    await animation.animateTo(
      target,
      curve: curve,
      duration: duration,
    );
    VideoController.inst.updateShouldShowControls(animation.value);
  }

  Future<void> _snap({bool haptic = true, required Curve curve}) async {
    await animateMiniplayer(
      _offset / maxOffset,
      curve: curve,
      duration: const Duration(milliseconds: 300),
    );
    bounceUp = false;
    if (haptic && (_prevOffset - _offset).abs() > _actuationOffset) VibratorController.interfaceHapticOrNull?.verylight();
  }

  Future<void> snapToPrev() async {
    if (Player.inst.canJumpToPrevious) {
      _sOffset = -sMaxOffset;
      _sOffset = 0;
      // await sAnim.animateTo(-1.0, curve: _bouncingCurve, duration: const Duration(milliseconds: 300));
      sAnim.animateTo(0.0, duration: Duration.zero);

      if ((_sPrevOffset - _sOffset).abs() > _actuationOffset) VibratorController.interfaceHapticOrNull?.verylight();
      Player.inst.previous();
    }
  }

  void _snapToCurrent() {
    _sOffset = 0;
    sAnim.animateTo(0.0, curve: _bouncingCurve, duration: const Duration(milliseconds: 300));
    if ((_sPrevOffset - _sOffset).abs() > _actuationOffset) VibratorController.interfaceHapticOrNull?.verylight();
  }

  Future<void> snapToNext() async {
    if (Player.inst.canJumpToNext) {
      _sOffset = sMaxOffset;
      _sOffset = 0;
      // await sAnim.animateTo(1.0, curve: _bouncingCurve, duration: const Duration(milliseconds: 300));
      sAnim.animateTo(0.0, duration: Duration.zero);

      if ((_sPrevOffset - _sOffset).abs() > _actuationOffset) VibratorController.interfaceHapticOrNull?.verylight();
      Player.inst.next();
    }
  }
}
