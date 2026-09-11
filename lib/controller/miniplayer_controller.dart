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
import 'package:namida/controller/window_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ui_scale.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/mp.dart';
import 'package:namida/packages/scroll_physics_modified.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/widgets/yt_queue_chip.dart';

class MiniPlayerController {
  static MiniPlayerController get inst => _instance;
  static final MiniPlayerController _instance = MiniPlayerController._internal();
  MiniPlayerController._internal();

  bool get _immersiveModeEnabled => settings.hideStatusBarInExpandedMiniplayer.value;
  bool get _defaultShouldDismissMiniplayer => settings.dismissibleMiniplayer.value;

  final ytMiniplayerKey = GlobalKey<NamidaYTMiniplayerState>();

  bool get shouldCompressArtwork => !(animation.value > 0 && animation.value < 2);

  bool get isInQueue => animation.value > 1.0;
  bool get isMinimized => animation.value < 1.0;
  bool get isExpanded => animation.value >= 0.95;

  /// Used to temporarily hold the seek value.
  final seekValue = Rxn<int>();

  /// Indicates that play/pause button is currently pressed.
  final isPlayPauseButtonHighlighted = false.obs;

  /// Prevents Listener while reorderding or dismissing items inside queue.
  bool get _isModifyingQueue => Player.inst.isModifyingQueue;

  /// Icon that represents the direction of the current track
  final arrowIcon = Broken.cd.obso;

  bool get _miniplayerIsWideScreen => Dimensions.inst.miniplayerIsWideScreen;

  late final ScrollController queueScrollController = NamidaScrollController.create()..addListener(_updateIcon);

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
    final devicePixelRatio = view.devicePixelRatioWithScale;
    final viewPadding = EdgeInsets.fromViewPadding(view.padding, devicePixelRatio);
    return _updateScreenValuesInternal(view.physicalSize / devicePixelRatio, viewPadding);
  }

  void updateScreenValues(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    return _updateScreenValuesInternal(mediaSize, viewPadding);
  }

  void _updateScreenValuesInternal(Size mediaSize, EdgeInsets viewPadding) {
    if (NamidaChannel.inst.isInPip.value || NamidaNavigator.inst.isInFullScreen) return; // messes up things so we ignore

    final newTopInset = viewPadding.top;
    final newBottomInset = viewPadding.bottom;
    final newRightInset = viewPadding.right / 2;

    final mediaSizeHeight = mediaSize.height - (WindowController.instance?.windowTitleBarHeightIfActive ?? 0.0);

    final miniplayerDetails = _getPlayerDetails(
      screenWidth: mediaSize.width,
      screenHeight: mediaSizeHeight,
    );
    final isWidescreen = miniplayerDetails.isWidescreen;
    double maxWidth = miniplayerDetails.maxWidth;
    if (isWidescreen) maxWidth += newRightInset;

    // -- the player's own layout is laid out in a virtual box at least as big as the
    // -- reference the size builders expect, then scaled down to fit the real panel.
    // -- keeps [Dimensions.miniplayerMaxWidth] real, that one drives the layout padding.
    // -- not gated to widescreen: the app wide scale already brings normal phones up to
    // -- the reference, so this resolves to ~1.0 there and only bites where it's needed.
    final newPanelScale = _resolvePanelScale(maxWidth, mediaSizeHeight);
    panelScale = newPanelScale;

    final newScreenSize = Size(maxWidth / newPanelScale, mediaSizeHeight / newPanelScale);

    final didChange =
        !_screenValuesInitialized || //
        newScreenSize != screenSize ||
        newTopInset != topInset ||
        newBottomInset != bottomInset ||
        newRightInset != rightInset;
    _screenValuesInitialized = true;

    topInset = newTopInset / newPanelScale;
    bottomInset = newBottomInset / newPanelScale;
    rightInset = newRightInset / newPanelScale;
    screenSize = newScreenSize;
    maxOffset = newScreenSize.height;
    sMaxOffset = newScreenSize.width;

    if (didChange) screenValuesVersion.value++;

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
      // -- if a menu was opened in widescreen, then now player is expanded in portrait
      // -- so pop them to avoid getting stuck
      NamidaNavigator.inst.popAllMenus();

      // -- to fix various issues (_offset and animation mismatch)
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (isInQueue) {
            this.snapToQueue();
          } else {
            this.snapToExpanded();
            this.ytMiniplayerKey.currentState?.animateToState(true, dur: Duration.zero);
          }
        },
      );

      // now portrait. do immersive mode if its expanded.
      setImmersiveMode(settings.hideStatusBarInExpandedMiniplayer.value, isWidescreen: isWidescreen);
    }

    Dimensions.inst.miniplayerMaxWidth = maxWidth;
    Dimensions.inst.availableAppContentWidth = mediaSize.width - (isWidescreen ? maxWidth : 0);
    Dimensions.inst.miniplayerIsWideScreen = isWidescreen;

    Dimensions.inst.sideInfoMaxWidth = (mediaSize.width * 0.2).withMaximum(324.0);
    Dimensions.inst.showSubpageInfoAtSide = Dimensions.inst.availableAppContentWidth > 524.0;
    if (Dimensions.inst.sideInfoMaxWidth < 164.0) {
      if (Dimensions.inst.showSubpageInfoAtSide) {
        Dimensions.inst.sideInfoMaxWidth = 164.0;
        Dimensions.inst.showSubpageInfoAtSide = true;
      } else {
        Dimensions.inst.sideInfoMaxWidth = 0;
        Dimensions.inst.showSubpageInfoAtSide = false;
      }
    }
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

  final screenValuesVersion = 0.obs;
  bool _screenValuesInitialized = false;

  double panelScale = 1.0;

  static const _panelReferenceWidth = 360.0;
  static const _panelReferenceHeight = 540.0;

  static double _resolvePanelScale(double width, double height) {
    if (width <= 0 || height <= 0) return 1.0;
    final scale = (width / _panelReferenceWidth).withMaximum(height / _panelReferenceHeight);
    return scale.clampDouble(0.7, 1.0);
  }

  double fromRootToPanel(double value) => NamidaUIScale.fromRoot(value) / panelScale;
  Offset fromRootToPanelOffset(Offset value) => NamidaUIScale.fromRootOffset(value) / panelScale;

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

  /// [sAnim] is driven slightly past the actuation distance while dragging, so that a full
  /// swipe reaches the bounds before the finger crosses the whole screen.
  static const double _kSDragOvershoot = 1.25;

  /// frozen prev/current/next indices while a horizontal transition is in flight.
  final displayIndicesOverride = Rxn<MiniplayerDisplayIndices>();
  int _snapGeneration = 0;
  int? _pendingSnapDir;
  Future<void>? _pendingIndexChange;

  bool bounceUp = false;
  bool bounceDown = false;

  double get _currentItemExtent => Player.inst.currentItem.value is YoutubeID ? Dimensions.youtubeCardItemExtent : Dimensions.inst.trackTileItemExtent;

  void animateQueueToCurrentTrack({bool jump = false, bool minZero = false}) {
    if (queueScrollController.hasClients) {
      final trackTileItemScrollOffsetInQueue = _currentItemExtent * Player.inst.currentIndex.value - screenSize.height * 0.2;
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
    if (fromRootToPanel(event.position.dy) >= screenSize.height - _deadSpace) return;

    _velocity.addPosition(event.timeStamp, fromRootToPanelOffset(event.position));

    _prevOffset = _offset;

    bounceUp = false;
    bounceDown = false;
  }

  bool _isInsideQueue() => _offset >= maxOffset * 2 && (queueScrollController.positions.isNotEmpty && queueScrollController.positions.first.pixels > 0.0);

  bool _canMinimizeMiniplayer(double dy) {
    if (_miniplayerIsWideScreen && animation.value <= 1 && dy > 0) {
      // -- moving down while miniplayer is always shown
      return false;
    }
    return true;
  }

  void onPointerMove(PointerMoveEvent event) {
    if (_isModifyingQueue) return;
    if (fromRootToPanel(event.position.dy) >= screenSize.height - _deadSpace) return;

    if (!_canMinimizeMiniplayer(event.localDelta.dy)) return;

    _velocity.addPosition(event.timeStamp, fromRootToPanelOffset(event.position));

    if (_offset <= maxOffset) return;

    if (!isKuru) {
      if (isScrollbarThumbDragging && isInQueue) {
        return;
      }
    }

    if (_isInsideQueue()) {
      // a rough estimation of the top area when inside queue.
      if (fromRootToPanel(event.position.dy) >
          ((WindowController.instance?.windowTitleBarHeightIfActive ?? 0) + 100 + _deadSpace + topInset + 12.0 + QueueChipHeaderRow.minHeight)) {
        return;
      }
    }

    _offset -= event.localDelta.dy;
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
    if (fromRootToPanel(details.globalPosition.dy) > screenSize.height - _deadSpace) return;
    if (_offset > maxOffset) return;
    if (!_canMinimizeMiniplayer(details.delta.dy)) return;

    _offset -= details.primaryDelta ?? 0;
    _offset = _offset.clampDouble(-_headRoom, maxOffset * 2 + _headRoom / 2);

    animateMiniplayer(_offset / maxOffset);
  }

  void gestureDetectorOnHorizontalDragStart(DragStartDetails details) {
    if (_offset > maxOffset) return;

    if (sAnim.isAnimating || _pendingSnapDir != null) {
      // -- a transition is still running (or done but waiting for the player to catch up), take over
      // -- from where it visually is, otherwise the first drag update would teleport [sAnim] back to
      // -- the stale [_sOffset] of the previous snap.
      _snapGeneration++; // -- the running snap no longer owns the animation, dont let it reset us
      sAnim.stop();
      _sOffset = sAnim.value * sMaxOffset / _kSDragOvershoot;
    }

    _sPrevOffset = _sOffset;
  }

  void gestureDetectorOnHorizontalDragUpdate(DragUpdateDetails details) {
    if (_offset > maxOffset) return;
    if (fromRootToPanel(details.globalPosition.dy) > screenSize.height - _deadSpace) return;

    _sOffset -= details.primaryDelta ?? 0.0;
    _sOffset = _sOffset.clampDouble(-sMaxOffset, sMaxOffset);

    sAnim.animateTo(_sOffset / sMaxOffset * _kSDragOvershoot, duration: Duration.zero);
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

    if (distance == _headRoom) {
      if (_defaultShouldDismissMiniplayer) {
        snapToMini();
        _onMiniplayerDismiss();
        return;
      }
    }

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
    } else if (shouldSnapToMini) {
      snapToMini();
    } else if (shouldSnapToQueue) {
      snapToQueue(animateScrollController: _offset < maxOffset * 1.8);
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
      await NamidaNavigator.setSystemUIImmersiveMode(true);
    } else {
      await NamidaNavigator.setSystemUIImmersiveMode(false);
      NamidaNavigator.setDefaultSystemUIOverlayStyle();
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

  Future<void> snapToPrev() => _snapToAdjacent(forward: false);

  void _snapToCurrent() {
    // -- if a transition is in flight then "current" is the item it was heading to,
    // -- the player already jumped there, so settling back to `0.0` would show a stale item.
    final target = _pendingSnapDir?.toDouble() ?? 0.0;
    _sOffset = target * sMaxOffset / _kSDragOvershoot;

    final gen = ++_snapGeneration;
    sAnim
        .animateTo(
          target,
          curve: Curves.fastLinearToSlowEaseIn,
          duration: const Duration(milliseconds: 600),
        )
        .whenComplete(() => _settleIndexAnimation(gen));

    if ((_sPrevOffset - _sOffset).abs() > _actuationOffset) VibratorController.interfaceHapticOrNull?.verylight();
  }

  Future<void> snapToNext() => _snapToAdjacent(forward: true);

  MiniplayerDisplayIndices _indicesAround(int current) => (
    prev: Player.inst.previousIndexFor(current),
    current: current,
    next: Player.inst.nextIndexFor(current),
  );

  void _resetIndexAnimation() {
    sAnim.stop();
    sAnim.value = 0.0;
    _sOffset = 0; // -- keep it in sync with [sAnim], otherwise the next drag would jump
    displayIndicesOverride.value = null;
    _pendingSnapDir = null;
    _pendingIndexChange = null;
  }

  /// Drops the frozen index once the transition settled. The player is jumped to asynchronously,
  /// so we wait for it to actually report the new index first, otherwise clearing the override
  /// would fall back to the stale index and flash the old item for a frame.
  void _settleIndexAnimation(int gen) {
    if (gen != _snapGeneration) return;

    final dir = _pendingSnapDir;
    final indices = displayIndicesOverride.value;
    final pendingIndexChange = _pendingIndexChange;
    if (dir == null || indices == null || pendingIndexChange == null || Player.inst.currentIndex.value == indices.towards(dir)) {
      _resetIndexAnimation();
      return;
    }

    pendingIndexChange.whenComplete(
      () {
        if (gen == _snapGeneration) _resetIndexAnimation();
      },
    );
  }

  Future<void> _snapToAdjacent({required bool forward}) async {
    if (!(forward ? Player.inst.canJumpToNext : Player.inst.canJumpToPrevious)) {
      _snapToCurrent(); // -- snap back if was dragged, settling on whatever is still in flight
      return;
    }

    final gen = ++_snapGeneration;
    final dir = forward ? 1 : -1;

    _sOffset = 0;
    if ((_sPrevOffset - _sOffset).abs() > _actuationOffset) VibratorController.interfaceHapticOrNull?.verylight();

    final pendingDir = _pendingSnapDir;
    final pendingIndices = displayIndicesOverride.value;
    sAnim.stop();
    if (pendingDir != null && pendingIndices != null) {
      displayIndicesOverride.value = _indicesAround(pendingIndices.towards(pendingDir));
      sAnim.value = (sAnim.value - pendingDir).clampDouble(-1.0, 1.0);
    } else {
      displayIndicesOverride.value = _indicesAround(Player.inst.currentIndex.value);
    }
    _pendingSnapDir = dir;

    final indexChangeFuture = forward ? Player.inst.next() : Player.inst.previous();
    _pendingIndexChange = indexChangeFuture;

    try {
      await sAnim.animateTo(
        dir.toDouble(),
        curve: Curves.fastLinearToSlowEaseIn,
        duration: const Duration(milliseconds: 600),
      );
    } finally {
      _settleIndexAnimation(gen);
    }
  }
}

typedef MiniplayerDisplayIndices = ({int prev, int current, int next});

extension MiniplayerDisplayIndicesUtils on MiniplayerDisplayIndices {
  int towards(int dir) => dir > 0 ? next : prev;
  bool isValidFor(int queueLength) => prev < queueLength && current < queueLength && next < queueLength;
}
