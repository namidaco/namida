import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_volume_controller/flutter_volume_controller.dart' show FlutterVolumeController;
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:youtipie/class/result_wrapper/playlist_result_base.dart';
import 'package:youtipie/class/streams/endscreens/endscreen_item_base.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings/youtube_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';
import 'package:namida/youtube/functions/yt_playlist_utils.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/seek_ready_widget.dart';
import 'package:namida/youtube/widgets/sponsor_block_button.dart';
import 'package:namida/youtube/widgets/video_info_dialog.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class NamidaVideoControls extends StatefulWidget {
  final bool showControls;
  final double? disableControlsUnderPercentage;
  final VoidCallback? onMinimizeTap;
  final bool isFullScreen;
  final bool isLocal;
  final bool forceEnableSponsorBlock;

  const NamidaVideoControls({
    super.key,
    required this.showControls,
    this.disableControlsUnderPercentage,
    required this.onMinimizeTap,
    required this.isFullScreen,
    required this.isLocal,
    this.forceEnableSponsorBlock = true,
  });

  @override
  State<NamidaVideoControls> createState() => NamidaVideoControlsState();
}

class NamidaVideoControlsState extends State<NamidaVideoControls> with TickerProviderStateMixin {
  bool _isVisible = false;
  double _maxWidth = 0.0;
  double _maxHeight = 0.0;
  final hideDuration = const Duration(seconds: 3);
  final hoverHideDuration = const Duration(seconds: 1);
  final volumeHideDuration = const Duration(milliseconds: 500);
  final brightnessHideDuration = const Duration(milliseconds: 500);
  final transitionDuration = const Duration(milliseconds: 300);
  final doubleTapSeekReset = const Duration(milliseconds: 900);

  Timer? _hideTimer;
  void _resetTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _startTimer({Duration? duration}) {
    _resetTimer();
    if (_isVisible) {
      _hideTimer = Timer(duration ?? hideDuration, () {
        setControlsVisibily(false);
      });
    }
  }

  void setControlsVisibily(bool visible, {bool? maintainStatusBar}) {
    if (visible && NamidaChannel.inst.isInPip.value) return; // dont show if in pip
    if (visible == _isVisible) return;
    if (mounted) setState(() => _isVisible = visible);

    if (mounted && (maintainStatusBar ?? widget.isFullScreen)) {
      if (visible) {
        // -- show status bar
        NamidaNavigator.setSystemUIImmersiveMode(false, overlays: [SystemUiOverlay.top]);
      } else {
        // -- hide status bar
        NamidaNavigator.setSystemUIImmersiveMode(true);
      }
    }
  }

  Timer? _isEndCardsVisibleTimer;
  final _isEndCardsVisible = true.obs;

  void showControlsBriefly() {
    setControlsVisibily(true, maintainStatusBar: false);
    _startTimer();
  }

  Widget _getBuilder({
    required Widget child,
  }) {
    final shouldShow = _isVisible;
    return IgnorePointer(
      ignoring: !shouldShow,
      child: AnimatedOpacity(
        duration: transitionDuration,
        opacity: shouldShow ? 1.0 : 0.0,
        child: child,
      ),
    );
  }

  void _onTap() {
    _currentDeviceVolume.value = null; // hide volume slider
    _canShowBrightnessSlider.value = false; // hide brightness slider
    if (_shouldSeekOnTap) return;
    if (_isVisible) {
      setControlsVisibily(false);
    } else {
      if (_canShowControls) {
        setControlsVisibily(true);
      }
    }
    _startTimer();
  }

  void _onEdgeHoverEnter() {
    _currentDeviceVolume.value = null; // hide volume slider
    _canShowBrightnessSlider.value = false; // hide brightness slider

    if (_canShowControls) {
      setControlsVisibily(true);
    }

    _resetTimer();
  }

  void _onEdgeHoverExit() {
    _startTimer(duration: hoverHideDuration);
  }

  bool _shouldSeekOnTap = false;
  Timer? _doubleSeekTimer;
  void _startSeekTimer(bool forward) {
    _shouldSeekOnTap = true;
    _doubleSeekTimer?.cancel();
    _doubleSeekTimer = Timer(doubleTapSeekReset, () {
      _shouldSeekOnTap = false;
      _seekSecondsRx.value = 0;
    });
  }

  final _seekSecondsRx = 0.obs;

  /// This prevents mixing up forward seek seconds with backward ones.
  bool _lastSeekWasForward = true;

  void _onDoubleTap(Offset position) async {
    final totalWidth = _maxWidth;
    final halfScreen = totalWidth / 2;
    final middleAmmountToIgnore = totalWidth / 6;
    final pos = position.dx - halfScreen;
    if (pos.abs() > middleAmmountToIgnore) {
      if (pos.isNegative) {
        // -- Seeking Backwards
        animateSeekControllers(false);
        _startSeekTimer(false);
        Player.inst.seekSecondsBackward(
          onSecondsReady: (finalSeconds) {
            if (_shouldSeekOnTap && !_lastSeekWasForward) {
              // only increase if not at the start
              if (Player.inst.nowPlayingPosition.value > 0) {
                _seekSecondsRx.value += finalSeconds;
              }
            } else {
              _seekSecondsRx.value = finalSeconds;
            }
          },
        );
        _lastSeekWasForward = false;
      } else {
        // -- Seeking Forwards
        animateSeekControllers(true);
        _startSeekTimer(true);
        Player.inst.seekSecondsForward(
          onSecondsReady: (finalSeconds) {
            if (_shouldSeekOnTap && _lastSeekWasForward) {
              // only increase if not at the end
              if (Player.inst.nowPlayingPosition.value < (Player.inst.currentItemDuration.value?.inMilliseconds ?? 0)) {
                _seekSecondsRx.value += finalSeconds;
              }
            } else {
              _seekSecondsRx.value = finalSeconds;
            }
          },
        );
        _lastSeekWasForward = true;
      }
    }
  }

  void animateSeekControllers(bool isForward) async {
    if (isForward) {
      // -- first container
      _animateAfterDelayMS(controller: seekAnimationForward1, delay: 0, target: 1.0);
      _animateAfterDelayMS(controller: seekAnimationForward1, delay: 500, target: 0.0);

      // -- second container
      _animateAfterDelayMS(controller: seekAnimationForward2, delay: 200, target: 1.0);
      _animateAfterDelayMS(controller: seekAnimationForward2, delay: 600, target: 0.0);
    } else {
      // -- first container
      _animateAfterDelayMS(controller: seekAnimationBackward1, delay: 0, target: 1.0);
      _animateAfterDelayMS(controller: seekAnimationBackward1, delay: 500, target: 0.0);

      // -- second container
      _animateAfterDelayMS(controller: seekAnimationBackward2, delay: 200, target: 1.0);
      _animateAfterDelayMS(controller: seekAnimationBackward2, delay: 600, target: 0.0);
    }
  }

  Future<void> _animateAfterDelayMS({
    required AnimationController controller,
    required int delay,
    required double target,
  }) async {
    await Future.delayed(Duration(milliseconds: delay));
    await controller.animateTo(target);
  }

  /// disables controls entirely when specified. for example when minplayer is minimized & controls should't be there.
  void _disableControlsListener() {
    if (!mounted) return;
    final value = MiniPlayerController.inst.animation.value;
    final hideUnder = widget.disableControlsUnderPercentage!;
    final shouldShow = value >= hideUnder;
    if (shouldShow != _isControlsEnabled) {
      setState(() => _isControlsEnabled = shouldShow);
    }
  }

  @override
  void initState() {
    super.initState();
    const dur = Duration(milliseconds: 200);
    const dur2 = Duration(milliseconds: 200);
    seekAnimationForward1 = AnimationController(
      vsync: this,
      duration: dur,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    seekAnimationForward2 = AnimationController(
      vsync: this,
      duration: dur2,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    seekAnimationBackward1 = AnimationController(
      vsync: this,
      duration: dur,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    seekAnimationBackward2 = AnimationController(
      vsync: this,
      duration: dur2,
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    if (widget.isFullScreen) {
      Player.inst.onVolumeChangeAddListener(
        _volumeListenerKey,
        (mv) async {
          if (_canShowControls) {
            _currentDeviceVolume.value = mv;
            if (!_isPointerDown) _startVolumeSwipeTimer(); // only start timer if not handled by pointer down/up
          }
        },
      );
    }

    if (widget.disableControlsUnderPercentage != null) {
      _disableControlsListener();
      MiniPlayerController.inst.animation.addListener(_disableControlsListener);
    }

    if (widget.isFullScreen && NamidaFeaturesVisibility.changeApplicationBrightness) {
      ScreenBrightness.instance.system.then((value) => _currentBrigthnessDim.value = 1.0 + value);
      _systemBrightnessStreamSub = ScreenBrightness.instance.onSystemScreenBrightnessChanged.listen(
        (event) {
          if (event > 0) {
            _currentBrigthnessDim.value = 1.0 + event;
            _setScreenBrightness(event);
          }
        },
      );
    }
    if (widget.isFullScreen && _deviceOrientationCommunicatorStreamSub == null) _setupDeviceOrientationListener();
  }

  void _setScreenBrightness(double value) async {
    value = value.clampDouble(0.01, 1.0); // -- below 0.01 treats it as 0 and disables it making it jump to system brightness
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value);
    } catch (_) {}
  }

  StreamSubscription<double>? _systemBrightnessStreamSub;

  final _volumeListenerKey = 'video_widget';

  final _isLongPressActive = false.obs;
  double get defaultLongPressSpeed => settings.player.longPressSpeed.value;

  void _startLongPressAction() {
    Player.inst.setPlayerSpeed(defaultLongPressSpeed);
    _isLongPressActive.value = true;
  }

  void _endLongPressAction() {
    Player.inst.setPlayerSpeed(settings.player.speed.value);
    _isLongPressActive.value = false;
  }

  @override
  void dispose() {
    seekAnimationForward1.dispose();
    seekAnimationForward2.dispose();
    seekAnimationBackward1.dispose();
    seekAnimationBackward2.dispose();
    _currentDeviceVolume.close();
    _canShowBrightnessSlider.close();
    _seekSecondsRx.close();
    _isEndCardsVisible.close();
    _isLongPressActive.close();
    Player.inst.onVolumeChangeRemoveListener(_volumeListenerKey);
    MiniPlayerController.inst.animation.removeListener(_disableControlsListener);
    _systemBrightnessStreamSub?.cancel();
    if (widget.isFullScreen && NamidaFeaturesVisibility.changeApplicationBrightness) {
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    }
    _deviceOrientationCommunicatorStreamSub?.cancel();
    super.dispose();
  }

  late AnimationController seekAnimationForward1;
  late AnimationController seekAnimationForward2;
  late AnimationController seekAnimationBackward1;
  late AnimationController seekAnimationBackward2;

  Widget _getSeekAnimatedContainer({
    required AnimationController controller,
    required bool isForward,
    required bool isSecondary,
  }) {
    final seekContainerSize = _maxWidth;
    final offsetPercentage = isSecondary ? 0.7 : 0.55;
    final finalOffset = -(seekContainerSize * offsetPercentage);
    return Positioned(
      right: isForward ? finalOffset : null,
      left: isForward ? null : finalOffset,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          child: SizedBox(
            width: seekContainerSize,
            height: seekContainerSize,
          ),
          builder: (context, child) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: (controller.value / 3).clampDouble(0, 1)),
                shape: BoxShape.circle,
              ),
              child: child!,
            );
          },
        ),
      ),
    );
  }

  Widget getSeekTextWidget({
    required AnimationController controller,
    required bool isForward,
  }) {
    final textTheme = context.textTheme;
    final seekContainerSize = _maxWidth;
    final finalOffset = seekContainerSize * 0.05;
    const forwardIcons = <int, IconData>{
      5: Broken.forward_5_seconds,
      10: Broken.forward_10_seconds,
      15: Broken.forward_15_seconds,
    };
    const backwardIcons = <int, IconData>{
      5: Broken.backward_5_seconds,
      10: Broken.backward_10_seconds,
      15: Broken.backward_15_seconds,
    };
    const color = Color.fromRGBO(222, 222, 222, 0.8);
    const strokeWidth = 1.8;
    const strokeColor = Color.fromRGBO(20, 20, 20, 0.5);
    const shadowBR = 5.0;
    const outlineShadow = <Shadow>[
      // bottomLeft
      Shadow(offset: Offset(-strokeWidth, -strokeWidth), color: strokeColor, blurRadius: shadowBR),
      // bottomRight
      Shadow(offset: Offset(strokeWidth, -strokeWidth), color: strokeColor, blurRadius: shadowBR),
      // topRight
      Shadow(offset: Offset(strokeWidth, strokeWidth), color: strokeColor, blurRadius: shadowBR),
      // topLeft
      Shadow(offset: Offset(-strokeWidth, strokeWidth), color: strokeColor, blurRadius: shadowBR),
    ];
    return Positioned(
      right: isForward ? finalOffset : null,
      left: isForward ? null : finalOffset,
      child: FadeIgnoreTransition(
        completelyKillWhenPossible: true,
        opacity: controller,
        child: ObxO(
          rx: _seekSecondsRx,
          builder: (context, ss) => Column(
            children: [
              Icon(
                isForward ? forwardIcons[ss] ?? Broken.forward : backwardIcons[ss] ?? Broken.backward,
                color: color,
                shadows: outlineShadow,
              ),
              const SizedBox(height: 8.0),
              Text(
                '$ss ${lang.SECONDS}',
                style: textTheme.displayMedium?.copyWith(
                  color: color,
                  shadows: outlineShadow,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _getQualityChip({
    required String title,
    String? subtitle,
    String? thirdLine,
    IconData? icon,
    required void Function(bool isSelected) onPlay,
    required bool selected,
    required bool isCached,
    Widget? trailing,
    bool popOnTap = true,
  }) {
    final textTheme = context.textTheme;
    return NamidaInkWell(
      onTap: () {
        _startTimer();
        if (popOnTap) NamidaNavigator.inst.popMenu();
        onPlay(selected);
      },
      decoration: const BoxDecoration(),
      borderRadius: 6.0,
      bgColor: selected ? CurrentColor.inst.miniplayerColor.withAlpha(100) : null,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      padding: const EdgeInsets.all(6.0),
      child: Row(
        children: [
          Icon(icon ?? (isCached ? Broken.tick_circle : Broken.story), size: 20.0),
          const SizedBox(width: 4.0),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: textTheme.displayMedium?.copyWith(fontSize: 13.0),
                  ),
                  if (subtitle != null && subtitle != '')
                    Text(
                      subtitle,
                      style: textTheme.displaySmall?.copyWith(fontSize: 12.0),
                    ),
                ],
              ),
              if (thirdLine != null && thirdLine != '')
                Text(
                  thirdLine,
                  style: textTheme.displaySmall?.copyWith(fontSize: 12.0),
                ),
            ],
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  double _volumeThreshold = 0.0;
  final _volumeMinDistance = 10.0;
  final _currentDeviceVolume = Rxn<double>();

  Timer? _volumeSwipeTimer;
  void _startVolumeSwipeTimer() {
    _volumeSwipeTimer?.cancel();
    _volumeSwipeTimer = Timer(volumeHideDuration, () {
      _currentDeviceVolume.value = null;
    });
  }

  double _brightnessDimThreshold = 0.0;
  final _brightnessMinDistance = 2.0;
  final _canShowBrightnessSlider = false.obs;
  Timer? _brightnessDimTimer;
  void _startBrightnessDimTimer() {
    _brightnessDimTimer?.cancel();
    _brightnessDimTimer = Timer(brightnessHideDuration, () {
      _canShowBrightnessSlider.value = false;
    });
  }

  bool _canSlideVolume(BuildContext context, double globalHeight) {
    final minimumVerticalDistanceToIgnoreSwipes = _maxHeight * 0.1;

    final isSafeFromDown = globalHeight > minimumVerticalDistanceToIgnoreSwipes;
    final isSafeFromUp = globalHeight < _maxHeight - minimumVerticalDistanceToIgnoreSwipes;
    return isSafeFromDown && isSafeFromUp;
  }

  /// used to disable slider if user swiped too close to the edge.
  bool _disableSliders = false;

  /// used to hide slider if wasnt handled by pointer down/up.
  bool _isPointerDown = false;

  bool _isDraggingSeekBar = false;

  Rx<double> get _currentBrigthnessDim => VideoController.inst.currentBrigthnessDim;

  final _maxBrightnessValue = NamidaFeaturesVisibility.changeApplicationBrightness ? 2.0 : 1.0;

  Widget _getVerticalSliderWidget(String key, double? perc, IconData icon, ui.FlutterView view, {double max = 1.0}) {
    final textTheme = context.textTheme;
    final totalHeight = view.physicalSize.shortestSide / view.devicePixelRatio * 0.75;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: perc == null || _isDraggingSeekBar
          ? SizedBox(key: Key('$key.hidden'))
          : Material(
              key: Key('$key.visible'),
              type: MaterialType.transparency,
              child: Container(
                width: 42.0,
                decoration: BoxDecoration(
                  color: context.theme.cardColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12.0),
                    Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                          ),
                          width: 4.0,
                          height: totalHeight * 0.4,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: CurrentColor.inst.miniplayerColor,
                            borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                          ),
                          width: 4.0,
                          height: totalHeight * 0.4 * (perc / max),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      "${(perc * 100).round()}%",
                      style: textTheme.displaySmall,
                    ),
                    const SizedBox(height: 6.0),
                    Icon(icon, size: 20.0),
                    const SizedBox(height: 12.0),
                  ],
                ),
              ),
            ),
    );
  }

  final borr = BorderRadius.circular(10.0.multipliedRadius);
  final borr8 = BorderRadius.circular(8.0.multipliedRadius);

  bool _pointerDownedOnRight = true;

  bool _doubleTapFirstPress = false;
  Timer? _doubleTapTimer;
  void _onFinishingDoubleTapTimer() {
    _doubleTapFirstPress = false;
    _doubleTapTimer?.cancel();
    _doubleTapTimer = null;
  }

  late bool _isControlsEnabled = widget.showControls;
  bool get _canShowControls => _isControlsEnabled && !NamidaChannel.inst.isInPip.value;

  EdgeInsets _deviceInsets = EdgeInsets.zero;

  final _videoConstraintsKey = GlobalKey();

  StreamSubscription<NativeDeviceOrientation>? _deviceOrientationCommunicatorStreamSub;
  void _setupDeviceOrientationListener() {
    if (Platform.isAndroid || Platform.isIOS) {
      _deviceOrientationCommunicatorStreamSub?.cancel();
      final stream = NativeDeviceOrientationCommunicator().onOrientationChanged();
      _deviceOrientationCommunicatorStreamSub = stream.listen(
        (event) {
          if (mounted) {
            setState(() => _deviceInsets = EdgeInsets.zero);
          }
        },
      );
    }
  }

  bool _didDeviceInsetsChange(EdgeInsets newDeviceInsets) {
    return newDeviceInsets.left > _deviceInsets.left ||
        newDeviceInsets.right > _deviceInsets.right ||
        newDeviceInsets.top > _deviceInsets.top ||
        newDeviceInsets.bottom > _deviceInsets.bottom;
  }

  void toggleGlowBehindVideo() {
    final newValueEnabled = !settings.enableGlowBehindVideo.value;
    settings.save(enableGlowBehindVideo: newValueEnabled);
    if (newValueEnabled) {
      snackyy(title: lang.WARNING, message: lang.PERFORMANCE_NOTE, icon: Broken.danger);
    }
  }

  void _onPointerUpCancel() {
    _isPointerDown = false;
    _disableSliders = false;
    _startVolumeSwipeTimer();
    _startBrightnessDimTimer();
    _isEndCardsVisibleTimer?.cancel();
    _isEndCardsVisible.value = true;
  }

  late final _seekReadyKey = widget.isFullScreen ? SeekReadyWidget.fullscreenKey : SeekReadyWidget.normalKey;
  SeekReadyWidgetState? get _seekReady => _seekReadyKey.currentState;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final newDeviceInsets = MediaQuery.viewPaddingOf(context);
    if (_deviceInsets == EdgeInsets.zero || _didDeviceInsetsChange(newDeviceInsets)) {
      if (newDeviceInsets != EdgeInsets.zero) _deviceInsets = newDeviceInsets;
    }

    final maxWidth = _maxWidth = widget.isFullScreen ? context.width : context.width.withMaximum(Dimensions.inst.miniplayerMaxWidth);
    final maxHeight = _maxHeight = context.height;

    final inLandscape = NamidaNavigator.inst.isInLanscape;

    final videoBoxMaxConstraints = inLandscape
        ? BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: maxHeight * 16 / 9,
          )
        : BoxConstraints(
            maxHeight: maxWidth * 9 / 16,
            maxWidth: maxWidth,
          );

    final finalVideoWidget = ObxO(
      rx: Player.inst.videoPlayerInfo,
      builder: (context, info) {
        if (info != null && info.isInitialized) {
          return NamidaAspectRatio(
            aspectRatio: info.aspectRatio,
            child: ObxO(
              rx: VideoController.inst.videoZoomAdditionalScale,
              builder: (context, pinchInZoom) => AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: 1.0 + pinchInZoom * 0.02,
                child: Texture(textureId: info.textureId),
              ),
            ),
          );
        }
        if (widget.isLocal && !widget.isFullScreen) {
          return Container(
            key: const Key('dummy_container'),
            color: Colors.transparent,
          );
        }
        // -- fallback images
        return ConstrainedBox(
          constraints: videoBoxMaxConstraints,
          child: LayoutWidthProvider(
            builder: (context, providerMaxWidth) {
              // -- in landscape, the size is calculated based on height, to fit in correctly.
              final fallbackHeight = inLandscape ? maxHeight : maxWidth * 9 / 16;
              final fallbackWidth = (inLandscape ? maxHeight * 16 / 9 : maxWidth).withMaximum(providerMaxWidth);
              return ObxO(
                rx: Player.inst.currentItem,
                builder: (context, item) {
                  if (item is YoutubeID) {
                    final vidId = item.id;
                    return YoutubeThumbnail(
                      type: ThumbnailType.video,
                      key: Key(vidId),
                      isImportantInCache: true,
                      width: fallbackWidth,
                      height: fallbackHeight,
                      borderRadius: 0,
                      blur: 0,
                      disableBlurBgSizeShrink: true,
                      videoId: vidId,
                      displayFallbackIcon: false,
                      compressed: false,
                      preferLowerRes: false,
                      fit: BoxFit.cover, // never change this lil bro
                    );
                  }
                  final track = item is Selectable ? item.track : null;
                  return ArtworkWidget(
                    key: ValueKey(track?.path),
                    track: track,
                    path: track?.pathToImage,
                    thumbnailSize: fallbackWidth,
                    width: fallbackWidth,
                    height: fallbackHeight,
                    borderRadius: 0,
                    blur: 0,
                    disableBlurBgSizeShrink: true,
                    compressed: false,
                    fit: BoxFit.cover, // never change this my friend
                  );
                },
              );
            },
          ),
        );
      },
    );

    final horizontalControlsPadding = widget.isFullScreen
        ? inLandscape
            ? EdgeInsets.only(left: 12.0 + _deviceInsets.left, right: 12.0 + _deviceInsets.right) // lanscape videos
            : EdgeInsets.only(left: 12.0 + _deviceInsets.left, right: 12.0 + _deviceInsets.right) // vertical videos
        : const EdgeInsets.symmetric(horizontal: 2.0);

    final safeAreaPadding = widget.isFullScreen
        ? inLandscape
            ? EdgeInsets.only(left: _deviceInsets.left, right: _deviceInsets.right)
            : EdgeInsets.zero // bcz we hide status bar and nav bar
        : EdgeInsets.zero;

    final bottomPadding = widget.isFullScreen
        ? inLandscape
            ? 12.0 + _deviceInsets.bottom // lanscape videos
            : 12.0 + 0.35 * _deviceInsets.bottom // vertical videos
        : 2.0;
    final topPadding = widget.isFullScreen
        ? inLandscape
            ? 12.0 + _deviceInsets.top // lanscape videos
            : 12.0 + _deviceInsets.top // vertical videos
        : 2.0;
    final itemsColor = Colors.white.withAlpha(200);
    final shouldShowSliders = _canShowControls && widget.isFullScreen;
    final shouldShowSeekBar = widget.isFullScreen;
    final view = View.of(context);

    final mainButtonSize = 40.0.withMaximum(maxWidth * 0.1);
    final mainButtonPadding = EdgeInsets.all(14.0.withMaximum(maxWidth * 0.035));

    final mainBufferIconSize = mainButtonSize * 1.3; // 40 => 52

    final secondaryButtonSize = 30.0.withMaximum(maxWidth * 0.06);
    final secondaryButtonPadding = EdgeInsets.all(10.0.withMaximum(maxWidth * 0.025));

    final skipSponsorButton = ObxO(
      rx: settings.youtube.sponsorBlockSettings,
      builder: (context, sponsorblock) => sponsorblock.enabled
          ? Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: EdgeInsetsDirectional.only(bottom: bottomPadding + 2.0),
                child: SkipSponsorButton(
                  itemsColor: itemsColor,
                ),
              ),
            )
          : const SizedBox(),
    );

    late final queueOrderChip = Obx(
      (context) {
        final queueL = Player.inst.currentQueue.valueR.length;
        if (queueL <= 1) return const SizedBox();
        return NamidaBgBlurClipped(
          blur: 3.0,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: borr8,
          ),
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Obx(
              (context) => Text(
                "${Player.inst.currentIndex.valueR + 1}/$queueL",
                style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600, color: itemsColor),
              ),
            ),
          ),
        );
      },
    );

    final currentSegmentsChip = ObxO(
      rx: YoutubeInfoController.current.currentVideoPage,
      builder: (context, page) {
        final streamSegments = page?.streamSegments;
        if (streamSegments != null && streamSegments.isNotEmpty) {
          return ObxO(
            rx: Player.inst.nowPlayingPosition,
            builder: (context, currentPositionMS) {
              final currentSegment = streamSegments.findByMillisecond(currentPositionMS);
              if (currentSegment != null && currentSegment.title.isNotEmpty) {
                return NamidaBgBlurClipped(
                  blur: 3.0,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: borr8,
                  ),
                  child: TapDetector(
                    onTap: () async {
                      final startSeconds = currentSegment.startSeconds;
                      if (startSeconds != null) {
                        YoutubeMiniplayerUiController.inst.ensureSegmentsVisible();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Text(
                        currentSegment.title,
                        style: textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 11.0,
                          color: itemsColor,
                        ),
                        softWrap: false,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          );
        }
        return const SizedBox();
      },
    );

    Widget videoControlsWidget = Listener(
      onPointerDown: (event) {
        _pointerDownedOnRight = event.position.dx > maxWidth / 2;
        _isPointerDown = true;
        if (_shouldSeekOnTap) {
          _onDoubleTap(event.position);
          _startTimer();
        }
        _disableSliders = !_canSlideVolume(context, event.position.dy);
        _isEndCardsVisibleTimer = Timer(Duration(milliseconds: 200), () {
          _isEndCardsVisible.value = false;
        });
      },
      onPointerUp: (_) {
        _onPointerUpCancel();
      },
      onPointerCancel: (_) {
        _onPointerUpCancel();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPressStart: !_isControlsEnabled ? null : (_) => _startLongPressAction(),
        onLongPressEnd: (_) => _endLongPressAction(),
        onLongPressCancel: () => _endLongPressAction(),
        onHorizontalDragStart: !_isControlsEnabled ? null : (details) => _seekReady?.onHorizontalDragStartSimple(),
        onHorizontalDragUpdate: !_isControlsEnabled ? null : (event) => _seekReady?.onHorizontalDragUpdateSimple(event),
        onHorizontalDragEnd: !_isControlsEnabled ? null : _seekReady?.onHorizontalDragEnd,
        onHorizontalDragCancel: !_isControlsEnabled ? null : _seekReady?.onHorizontalDragCancel,
        onVerticalDragUpdate: !shouldShowSliders
            ? null
            : (event) async {
                if (_disableSliders) return;
                if (_isDraggingSeekBar) return;
                final d = event.delta.dy;
                if (_pointerDownedOnRight) {
                  // -- volume
                  _volumeThreshold += d;
                  if (_volumeThreshold >= _volumeMinDistance) {
                    _volumeThreshold = 0.0;
                    await FlutterVolumeController.lowerVolume(null);
                  } else if (_volumeThreshold <= -_volumeMinDistance) {
                    _volumeThreshold = 0.0;
                    await FlutterVolumeController.raiseVolume(null);
                  }
                } else {
                  _brightnessDimThreshold += d;
                  if (_brightnessDimThreshold >= _brightnessMinDistance) {
                    _brightnessDimThreshold = 0.0;
                    _canShowBrightnessSlider.value = true;
                    _currentBrigthnessDim.value = (_currentBrigthnessDim.value - 0.01).withMinimum(0.1);
                  } else if (_brightnessDimThreshold <= -_brightnessMinDistance) {
                    _brightnessDimThreshold = 0.0;
                    _canShowBrightnessSlider.value = true;
                    _currentBrigthnessDim.value = (_currentBrigthnessDim.value + 0.01).withMaximum(_maxBrightnessValue);
                  }
                  if (NamidaFeaturesVisibility.changeApplicationBrightness) {
                    if (_currentBrigthnessDim.value > 1.0) {
                      // -- settings to 0 just disables it, thats why only `> 1.0`
                      _setScreenBrightness(_currentBrigthnessDim.value - 1.0);
                    }
                  }
                }
              },
        onTapUp: _canShowControls
            ? (event) {
                if (_isDraggingSeekBar) return;

                if (_doubleTapFirstPress && _doubleTapTimer?.isActive == true) {
                  // -- pressed again within 200ms.
                  _onDoubleTap(event.localPosition);
                  setControlsVisibily(false);
                  _doubleTapTimer?.cancel();
                  _doubleTapTimer = Timer(const Duration(milliseconds: 200), () {
                    _doubleTapFirstPress = false;
                    _onFinishingDoubleTapTimer();
                  });
                } else {
                  _onTap();
                  _doubleTapFirstPress = true;
                  _doubleTapTimer?.cancel();
                  _doubleTapTimer = Timer(const Duration(milliseconds: 200), () {
                    _doubleTapFirstPress = false;
                  });
                }
              }
            : null,
        onTapCancel: () {
          _onFinishingDoubleTapTimer();
        },
        child: Stack(
          fit: StackFit.passthrough,
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: safeAreaPadding,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ObxO(
                      key: _videoConstraintsKey,
                      rx: settings.enableGlowBehindVideo,
                      builder: (context, enableGlowBehindVideo) => ObxO(
                        rx: NamidaChannel.inst.isInPip,
                        builder: (context, inPip) => _DropShadowWrapper(
                          enabled: widget.isFullScreen && !inPip && enableGlowBehindVideo,
                          child: finalVideoWidget,
                        ),
                      ),
                    ),
                    if (_canShowControls)
                      ObxO(
                        rx: settings.youtube.showVideoEndcards,
                        builder: (context, userEnabledVideoEndCards) => !userEnabledVideoEndCards
                            ? const SizedBox()
                            : ConstrainedBox(
                                constraints: videoBoxMaxConstraints,
                                child: ObxO(
                                  rx: _isEndCardsVisible,
                                  builder: (context, endcardsvisible) => _YTVideoEndcards(
                                    visible: endcardsvisible,
                                    inFullScreen: widget.isFullScreen,
                                  ),
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ),
            // ---- Brightness Mask -----
            Positioned.fill(
              child: ObxO(
                rx: _currentBrigthnessDim,
                builder: (context, brightness) => brightness < 1.0
                    ? IgnorePointer(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 1 - brightness),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // -- seek ready cant have expanded hit test otherwise it would block bottom controls here
            // -- this widgets adds extra horizontal drag detection behind controls
            if (!widget.isFullScreen && _isControlsEnabled)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SeekReadyWidget.normalKey.currentState?.createHitTestWidget(
                      expandHitTest: true,
                      allowTapping: false,
                      maxWidth: maxWidth,
                    ) ??
                    const SizedBox(),
              ),

            if (widget.showControls)
              IgnorePointer(
                ignoring: !_canShowControls,
                child: Opacity(
                  opacity: _canShowControls ? 1.0 : 0,
                  child: Stack(
                    fit: StackFit.passthrough,
                    alignment: Alignment.center,
                    children: [
                      if (NamidaFeaturesVisibility.showVideoControlsOnHover)
                        Center(
                          child: LayoutWidthHeightProvider(
                            builder: (context, maxWidth, maxHeight) {
                              // final leftPortion = maxWidth * 0.1;
                              // final rightPortion = maxWidth * 0.9;
                              final topPortion = maxHeight * 0.1;
                              final bottomPortion = maxHeight * 0.8;

                              final allowBottom = widget.isFullScreen;

                              return MouseRegion(
                                opaque: false,
                                onHover: (event) {
                                  // final dx = event.position.dx;
                                  final dy = event.position.dy;
                                  final allowVertical = (dy < topPortion || (allowBottom && dy > bottomPortion));
                                  const allowHorizontal = false;
                                  // final allowHorizontal = (dx < leftPortion || dx > rightPortion);
                                  if (allowVertical || allowHorizontal) {
                                    if (_isVisible == false) {
                                      _onEdgeHoverEnter();
                                    }
                                  } else {
                                    if (_isVisible == true && _hideTimer == null) {
                                      _onEdgeHoverExit();
                                    }
                                  }
                                },
                              );
                            },
                          ),
                        ),

                      // ---- Mask -----
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _getBuilder(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                      ),

                      // ---- Top Row ----
                      Padding(
                        padding: horizontalControlsPadding + EdgeInsets.only(top: topPadding),
                        child: TapDetector(
                          onTap: () {},
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: _getBuilder(
                              child: Row(
                                children: [
                                  if (widget.isFullScreen || widget.onMinimizeTap != null)
                                    NamidaIconButton(
                                      horizontalPadding: 12.0,
                                      verticalPadding: 6.0,
                                      onPressed: widget.isFullScreen ? NamidaNavigator.inst.exitFullScreen : widget.onMinimizeTap,
                                      icon: Broken.arrow_down_2,
                                      iconColor: itemsColor,
                                      iconSize: 20.0,
                                    ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: widget.isFullScreen
                                        ? Material(
                                            type: MaterialType.transparency,
                                            child: _VideoTitleSubtitleWidget(
                                              isLocal: widget.isLocal,
                                            ),
                                          )
                                        : const SizedBox(),
                                  ),
                                  const SizedBox(width: 4.0),

                                  // ==== Reset Brightness ====
                                  ObxO(
                                    rx: _currentBrigthnessDim,
                                    builder: (context, brigthnessDim) => AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      child: brigthnessDim < 1.0
                                          ? NamidaIconButton(
                                              key: const Key('brightnesseto_ok'),
                                              tooltip: () => lang.RESET_BRIGHTNESS,
                                              icon: Broken.sun_1,
                                              iconColor: itemsColor.withValues(alpha: 0.8),
                                              verticalPadding: 4.0,
                                              horizontalPadding: 8.0,
                                              iconSize: 18.0,
                                              onPressed: () => _currentBrigthnessDim.value = 1.0,
                                            )
                                          : const SizedBox(
                                              key: Key('brightnesseto_no'),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 4.0),

                                  // ===== Speed Chip =====
                                  NamidaPopupWrapper(
                                    onPop: _startTimer,
                                    onTap: () {
                                      _resetTimer();
                                      setControlsVisibily(true);
                                    },
                                    children: () => [
                                      ...settings.player.speeds.map(
                                        (speed) => ObxO(
                                          rx: Player.inst.currentSpeed,
                                          builder: (context, selectedSpeed) {
                                            final isSelected = selectedSpeed == speed;
                                            return NamidaInkWell(
                                              onTap: () {
                                                _startTimer();
                                                final isSelected = Player.inst.currentSpeed.value == speed;
                                                if (!isSelected) {
                                                  Player.inst.setPlayerSpeed(speed);
                                                  settings.player.save(speed: speed);
                                                  NamidaNavigator.inst.popMenu();
                                                }
                                              },
                                              decoration: const BoxDecoration(),
                                              borderRadius: 6.0,
                                              bgColor: isSelected ? CurrentColor.inst.miniplayerColor.withAlpha(100) : null,
                                              margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                              padding: const EdgeInsets.all(6.0),
                                              child: Row(
                                                children: [
                                                  const Icon(Broken.play_cricle, size: 20.0),
                                                  const SizedBox(width: 12.0),
                                                  Text(
                                                    "${speed}x",
                                                    style: textTheme.displayMedium?.copyWith(fontSize: 13.0),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      NamidaInkWell(
                                        onTap: () {
                                          _startTimer();
                                          NamidaNavigator.inst.popMenu();
                                          NamidaNavigator.inst.navigateDialog(dialog: const _SpeedsEditorDialog());
                                        },
                                        decoration: const BoxDecoration(),
                                        borderRadius: 6.0,
                                        bgColor: null,
                                        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                        padding: const EdgeInsets.all(6.0),
                                        child: Row(
                                          children: [
                                            const Icon(Broken.add_circle, size: 20.0),
                                            const SizedBox(width: 12.0),
                                            Text(
                                              lang.ADD,
                                              style: textTheme.displayMedium?.copyWith(fontSize: 13.0),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: NamidaBgBlurClipped(
                                        blur: 3.0,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                          child: Obx(
                                            (context) {
                                              final speed = Player.inst.currentSpeed.valueR;
                                              return Row(
                                                children: [
                                                  Icon(
                                                    Broken.play_cricle,
                                                    size: 16.0,
                                                    color: itemsColor,
                                                  ),
                                                  const SizedBox(width: 4.0).animateEntrance(showWhen: speed != 1.0, allCurves: Curves.easeInOutQuart),
                                                  Text(
                                                    "${speed}x",
                                                    style: textTheme.displaySmall?.copyWith(
                                                      color: itemsColor,
                                                      fontSize: 12.0,
                                                    ),
                                                  ).animateEntrance(showWhen: speed != 1.0, allCurves: Curves.easeInOutQuart),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // ===== Audio Language Chip =====
                                  ObxO(
                                      rx: YoutubeInfoController.current.currentYTStreams,
                                      builder: (context, streams) {
                                        final streamsMap = streams?.audioStreamsOrganizedByLanguage;
                                        if (streamsMap == null || streamsMap.keys.length <= 1) return const SizedBox();

                                        return NamidaPopupWrapper(
                                          openOnTap: true,
                                          onPop: _startTimer,
                                          onTap: () {
                                            _resetTimer();
                                            setControlsVisibily(true);
                                          },
                                          children: () => streamsMap.values
                                              .map(
                                                (element) => Obx(
                                                  (context) {
                                                    bool isSelected = false;
                                                    final audioTrack = element.audioTrack;
                                                    final langCode = audioTrack?.langCode;
                                                    if (langCode != null) {
                                                      if (langCode == Player.inst.currentCachedAudio.valueR?.langaugeCode) {
                                                        isSelected = true;
                                                      } else if (langCode == Player.inst.currentAudioStream.valueR?.audioTrack?.langCode) {
                                                        isSelected = true;
                                                      }
                                                    }
                                                    final id = Player.inst.currentVideoR?.id;
                                                    return _getQualityChip(
                                                      title: audioTrack?.displayName ?? '?',
                                                      subtitle: " • ${audioTrack?.langCode ?? 0}",
                                                      onPlay: (isSelected) {
                                                        if (!isSelected || Player.inst.videoPlayerInfo.value?.isInitialized == true) {
                                                          Player.inst.onItemPlayYoutubeIDSetAudio(
                                                            stream: element,
                                                            mainStreams: streams,
                                                            cachedFile: null,
                                                            useCache: true,
                                                            videoId: Player.inst.currentVideo?.id ?? '',
                                                          );
                                                        }
                                                      },
                                                      selected: isSelected,
                                                      isCached: element.getCachedFileSync(id) != null,
                                                    );
                                                  },
                                                ),
                                              )
                                              .toList(),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: NamidaBgBlurClipped(
                                              blur: 3.0,
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                                child: Obx(
                                                  (context) {
                                                    final displayName =
                                                        Player.inst.currentAudioStream.valueR?.audioTrack?.displayName ?? Player.inst.currentCachedAudio.valueR?.langaugeName;
                                                    return Text(
                                                      displayName ?? '?',
                                                      style: textTheme.displaySmall?.copyWith(color: itemsColor),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                  // ===== Quality Chip =====
                                  NamidaPopupWrapper(
                                    openOnTap: true,
                                    onPop: _startTimer,
                                    onTap: () {
                                      _resetTimer();
                                      setControlsVisibily(true);
                                    },
                                    refreshListenable: widget.isLocal ? VideoController.inst.currentVideoConfig.currentYTStreams : YoutubeInfoController.current.currentYTStreams,
                                    children: () {
                                      VideoStreamsResult? streams;
                                      Selectable? currentSelectable;
                                      String? currentLocalVideoId;
                                      if (widget.isLocal) {
                                        streams = VideoController.inst.currentVideoConfig.currentYTStreams.value;
                                        final currentItem = Player.inst.currentItem.value;
                                        if (currentItem is Selectable) {
                                          currentSelectable = currentItem;
                                          currentLocalVideoId = currentItem.track.youtubeID;
                                        }
                                      } else {
                                        streams = YoutubeInfoController.current.currentYTStreams.value;
                                      }
                                      final ytQualities =
                                          streams?.videoStreams.withoutWebmIfNeccessaryOrExperimentalCodecs(allowExperimentalCodecs: settings.youtube.allowExperimentalCodecs);
                                      final cachedQualitiesAll = widget.isLocal
                                          ? VideoController.inst.currentVideoConfig.currentPossibleLocalVideos
                                          : YoutubeInfoController.current.currentCachedQualities;
                                      final cachedQualities = List<NamidaVideo>.from(cachedQualitiesAll.value);
                                      final videoId = Player.inst.currentVideoR?.id;
                                      if (ytQualities != null && ytQualities.isNotEmpty) {
                                        cachedQualities.removeWhere(
                                          (cq) {
                                            return ytQualities.any((ytq) {
                                              if (widget.isLocal) return ytq.height == cq.height && ytq.bitrate == cq.bitrate;
                                              final cachePath = videoId == null ? null : ytq.cachePath(videoId);
                                              if (cachePath == cq.path) return true;
                                              if (ytq.sizeInBytes == cq.sizeInBytes) return true;
                                              final sameRes = cq.resolution.toString().startsWith(ytq.qualityLabel); // 720p.startsWith(720p60).
                                              if (!sameRes) return false;
                                              final sameFrames = ytq.fps == cq.framerate;
                                              if (!sameFrames) return false;
                                              return true; // same res && same frames
                                            });
                                          },
                                        );
                                      }
                                      return [
                                        Obx(
                                          (context) {
                                            final hasHighConnection = ConnectivityController.inst.hasHighConnection;
                                            final rx = hasHighConnection ? settings.youtube.dataSaverMode : settings.youtube.dataSaverModeMobile;
                                            final value = rx.valueR;
                                            final isOff = value == DataSaverMode.off;
                                            return _getQualityChip(
                                              title: lang.DATA_SAVER,
                                              onPlay: (isSelected) => YoutubeSettings.openDataSaverConfigureDialog(),
                                              selected: false,
                                              isCached: false,
                                              thirdLine: isOff ? null : value.toText(),
                                              icon: Broken.blur,
                                            );
                                          },
                                        ),
                                        Obx(
                                          (context) => _getQualityChip(
                                            title: lang.AUDIO_ONLY,
                                            onPlay: (isSelected) {
                                              Player.inst.setAudioOnlyPlayback(true);
                                              VideoController.inst.currentVideo.value = null;
                                              settings.save(enableVideoPlayback: false);
                                            },
                                            selected: (widget.isLocal ? VideoController.inst.currentVideo.valueR == null : settings.youtube.isAudioOnlyMode.valueR),
                                            isCached: false,
                                            icon: Broken.musicnote,
                                          ),
                                        ),
                                        if (currentSelectable != null)
                                          if (currentLocalVideoId == null || currentLocalVideoId.isEmpty)
                                            _getQualityChip(
                                              title: lang.SEARCH,
                                              icon: Broken.search_normal,
                                              selected: false,
                                              isCached: false,
                                              popOnTap: false,
                                              onPlay: (isSelected) {
                                                showSetYTLinkCommentDialog(
                                                  [currentSelectable!.track],
                                                  CurrentColor.inst.miniplayerColor,
                                                  autoOpenSearch: true,
                                                );
                                              },
                                            )
                                          else
                                            ObxO(
                                              rx: VideoController.inst.currentVideoConfig.isLoadingCurrentYTStreams,
                                              builder: (context, isLoadingMore) => _getQualityChip(
                                                title: lang.CHECK_FOR_MORE,
                                                icon: Broken.chart,
                                                trailing: isLoadingMore ? const LoadingIndicator() : null,
                                                selected: false,
                                                isCached: false,
                                                popOnTap: false,
                                                onPlay: (_) => VideoController.inst.fetchYTQualitiesForCurrent(currentSelectable!.track),
                                              ),
                                            ),
                                        ...cachedQualities.map(
                                          (element) => Obx(
                                            (context) => _getQualityChip(
                                              title: '${element.resolution}p${element.framerateText()}',
                                              subtitle: " • ${element.sizeInBytes.fileSizeFormatted}",
                                              onPlay: (isSelected) {
                                                // sometimes video is not initialized so we need the second check
                                                if (!isSelected || Player.inst.videoPlayerInfo.value?.isInitialized != true) {
                                                  Player.inst.onItemPlayYoutubeIDSetQuality(
                                                    mainStreams: streams,
                                                    stream: null,
                                                    cachedFile: File(element.path),
                                                    videoItem: element,
                                                    useCache: true,
                                                    videoId: Player.inst.currentVideo?.id ?? '',
                                                  );
                                                  if (widget.isLocal) {
                                                    VideoController.inst.currentVideo.value = element;
                                                    settings.save(enableVideoPlayback: true);
                                                  }
                                                }
                                              },
                                              selected: widget.isLocal
                                                  ? VideoController.inst.currentVideo.valueR?.path == element.path
                                                  : settings.youtube.isAudioOnlyMode.valueR
                                                      ? false
                                                      : Player.inst.currentCachedVideo.valueR?.path == element.path,
                                              isCached: true,
                                            ),
                                          ),
                                        ),
                                        ...?ytQualities?.map((element) {
                                          return Obx(
                                            (context) {
                                              if (widget.isLocal) {
                                                final id = Player.inst.currentVideoR?.id;
                                                final selectedVideo = VideoController.inst.currentVideo.valueR;
                                                final isSelected = element.height == selectedVideo?.height && element.bitrate == selectedVideo?.bitrate;

                                                var codecIdentifier = element.codecInfo.codecIdentifierIfCustom();
                                                var codecIdentifierText = codecIdentifier != null ? ' (${codecIdentifier.toUpperCase()})' : '';

                                                return _getQualityChip(
                                                  title: element.qualityLabel,
                                                  subtitle: " • ${element.sizeInBytes.fileSizeFormatted}",
                                                  thirdLine: "${element.bitrateText()}$codecIdentifierText",
                                                  onPlay: (isSelected) {
                                                    if (!isSelected || Player.inst.videoPlayerInfo.value?.isInitialized != true) {
                                                      Player.inst.onItemPlayYoutubeIDSetQuality(
                                                        mainStreams: streams,
                                                        stream: element,
                                                        cachedFile: null,
                                                        useCache: true,
                                                        videoId: id ?? '',
                                                      );
                                                    }
                                                  },
                                                  selected: isSelected,
                                                  isCached: isSelected,
                                                );
                                              } else {
                                                final id = Player.inst.currentVideoR?.id;
                                                final cachedFile = id == null ? null : element.getCachedFileSync(id);
                                                bool isSelected = false;
                                                if (settings.youtube.isAudioOnlyMode.valueR) {
                                                  isSelected = false;
                                                } else {
                                                  final currentVS = Player.inst.currentVideoStream.valueR;
                                                  if (currentVS != null) {
                                                    isSelected = element.itag == currentVS.itag;
                                                  } else {
                                                    final currentCachedV = Player.inst.currentCachedVideo.valueR;
                                                    if (currentCachedV != null && cachedFile != null) {
                                                      isSelected = cachedFile.path == currentCachedV.path;
                                                    }
                                                  }
                                                }

                                                var codecIdentifier = element.codecInfo.codecIdentifierIfCustom();
                                                var codecIdentifierText = codecIdentifier != null ? ' (${codecIdentifier.toUpperCase()})' : '';

                                                return _getQualityChip(
                                                  title: element.qualityLabel,
                                                  subtitle: " • ${element.sizeInBytes.fileSizeFormatted}",
                                                  thirdLine: "${element.bitrateText()}$codecIdentifierText",
                                                  onPlay: (isSelected) {
                                                    if (!isSelected || Player.inst.videoPlayerInfo.value?.isInitialized != true) {
                                                      Player.inst.onItemPlayYoutubeIDSetQuality(
                                                        mainStreams: streams,
                                                        stream: element,
                                                        cachedFile: cachedFile,
                                                        useCache: true,
                                                        videoId: id ?? '',
                                                      );
                                                    }
                                                  },
                                                  selected: isSelected,
                                                  isCached: cachedFile != null,
                                                );
                                              }
                                            },
                                          );
                                        }),
                                      ];
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: NamidaBgBlurClipped(
                                        blur: 3.0,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                          child: Obx(
                                            (context) {
                                              final isAudio = widget.isLocal ? VideoController.inst.currentVideo.valueR == null : settings.youtube.isAudioOnlyMode.valueR;

                                              String? qt;
                                              IconData icon;
                                              IconData? secondaryIcon;
                                              if (isAudio) {
                                                icon = Broken.musicnote;
                                              } else {
                                                icon = Broken.setting;

                                                if (widget.isLocal) {
                                                  final video = VideoController.inst.currentVideo.valueR;
                                                  qt = video == null ? null : '${video.resolution}p${video.framerateText()}';
                                                } else {
                                                  qt = Player.inst.currentVideoStream.valueR?.qualityLabel;
                                                  if (qt == null) {
                                                    final cached = Player.inst.currentCachedVideo.valueR;
                                                    if (cached != null) qt = "${cached.resolution}p${cached.framerateText()}";
                                                  }

                                                  final dataSaverMode = ConnectivityController.inst.hasHighConnectionR
                                                      ? settings.youtube.dataSaverMode.valueR
                                                      : settings.youtube.dataSaverModeMobile.valueR;
                                                  if (Player.inst.currentVideoStream.valueR == null &&
                                                      Player.inst.currentCachedVideo.valueR == null &&
                                                      !dataSaverMode.canFetchNetworkVideoStream) {
                                                    secondaryIcon = Broken.blur;
                                                  }
                                                }
                                              }

                                              return Row(
                                                children: [
                                                  if (qt != null) ...[
                                                    Text(
                                                      qt,
                                                      style: textTheme.displaySmall?.copyWith(color: itemsColor),
                                                    ),
                                                    const SizedBox(width: 4.0),
                                                  ],
                                                  secondaryIcon == null
                                                      ? Icon(
                                                          icon,
                                                          color: itemsColor,
                                                          size: 16.0,
                                                        )
                                                      : StackedIcon(
                                                          baseIcon: icon,
                                                          secondaryIcon: secondaryIcon,
                                                          margin: 0.0,
                                                          iconSize: 16.0,
                                                          secondaryIconSize: 8.0,
                                                          baseIconColor: itemsColor,
                                                          secondaryIconColor: itemsColor,
                                                          shadowColor: itemsColor.invert(),
                                                        ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  if (widget.isFullScreen)
                                    NamidaPopupWrapper(
                                      openOnTap: true,
                                      onPop: _startTimer,
                                      onTap: () {
                                        _resetTimer();
                                        setControlsVisibily(true);
                                      },
                                      childrenDefault: () => [
                                        NamidaPopupItem(
                                          icon: Broken.sun_1,
                                          secondaryIcon: Broken.drop,
                                          title: lang.ENABLE_GLOW_EFFECT,
                                          onTap: toggleGlowBehindVideo,
                                          trailing: ObxO(
                                            rx: settings.enableGlowBehindVideo,
                                            builder: (context, active) => CustomSwitch(
                                              active: active,
                                              width: 37.0,
                                              height: 20.0,
                                            ),
                                          ),
                                        ),
                                        if (!widget.isLocal)
                                          NamidaPopupItem(
                                            icon: Broken.card_tick,
                                            title: lang.SHOW_VIDEO_ENDCARDS,
                                            onTap: () => settings.youtube.save(showVideoEndcards: !settings.youtube.showVideoEndcards.value),
                                            trailing: ObxO(
                                              rx: settings.youtube.showVideoEndcards,
                                              builder: (context, active) => CustomSwitch(
                                                active: active,
                                                width: 37.0,
                                                height: 20.0,
                                              ),
                                            ),
                                          ),
                                        if (!widget.isLocal)
                                          NamidaPopupItem(
                                            icon: Broken.profile_circle,
                                            secondaryIcon: Broken.drop,
                                            title: lang.SHOW_CHANNEL_WATERMARK_IN_FULLSCREEN,
                                            onTap: () => settings.youtube.save(showChannelWatermarkFullscreen: !settings.youtube.showChannelWatermarkFullscreen.value),
                                            trailing: ObxO(
                                              rx: settings.youtube.showChannelWatermarkFullscreen,
                                              builder: (context, active) => CustomSwitch(
                                                active: active,
                                                width: 37.0,
                                                height: 20.0,
                                              ),
                                            ),
                                          ),
                                      ],
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: NamidaBgBlurClipped(
                                          blur: 3.0,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                          ),
                                          child: NamidaTooltip(
                                            message: () => lang.CONFIGURE,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                              child: Icon(
                                                Broken.setting_4,
                                                size: 16.0,
                                                color: itemsColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // ---- Bottom Row ----
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          skipSponsorButton,
                          Padding(
                            padding: horizontalControlsPadding + EdgeInsets.only(bottom: bottomPadding),
                            child: TapDetector(
                              onTap: () {},
                              child: _getBuilder(
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (shouldShowSeekBar)
                                        SizedBox(
                                          width: maxWidth,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                            child: SeekReadyWidget(
                                              key: SeekReadyWidget.fullscreenKey,
                                              isFullscreen: widget.isFullScreen,
                                              showPositionCircle: widget.isFullScreen,
                                              isLocal: widget.isLocal,
                                              canDrag: () {
                                                return _currentDeviceVolume.value == null && !_canShowBrightnessSlider.value;
                                              },
                                              onDraggingChange: (isDragging) {
                                                if (isDragging) {
                                                  _isDraggingSeekBar = true;
                                                  _resetTimer();
                                                  setControlsVisibily(true);
                                                } else {
                                                  _isDraggingSeekBar = false;
                                                  _startTimer();
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      Row(
                                        children: [
                                          NamidaBgBlurClipped(
                                            blur: 3.0,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.2),
                                              borderRadius: borr8,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(6.0),
                                              child: TapDetector(
                                                behavior: HitTestBehavior.translucent,
                                                onTap: () {
                                                  settings.player.save(displayRemainingDurInsteadOfTotal: !settings.player.displayRemainingDurInsteadOfTotal.value);
                                                },
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Obx(
                                                      (context) => Text(
                                                        "${Player.inst.nowPlayingPositionR.milliSecondsLabel}/",
                                                        style: textTheme.displayMedium?.copyWith(
                                                          fontSize: 13.5,
                                                          color: itemsColor,
                                                        ),
                                                      ),
                                                    ),
                                                    Obx(
                                                      (context) {
                                                        int totalDurMs = Player.inst.getCurrentVideoDurationR.inMilliseconds;
                                                        String prefix = '';
                                                        if (settings.player.displayRemainingDurInsteadOfTotal.valueR) {
                                                          totalDurMs = totalDurMs - Player.inst.nowPlayingPositionR;
                                                          prefix = '-';
                                                        }

                                                        return Text(
                                                          "$prefix${totalDurMs.milliSecondsLabel}",
                                                          style: textTheme.displayMedium?.copyWith(
                                                            fontSize: 13.5,
                                                            color: itemsColor,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4.0),
                                          if (widget.isFullScreen) ...[
                                            // -- queue order
                                            queueOrderChip,
                                            const SizedBox(width: 4.0),
                                          ],
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: currentSegmentsChip,
                                            ),
                                          ),
                                          const SizedBox(width: 4.0),
                                          NamidaBgBlurClipped(
                                            blur: 3.0,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.2),
                                              borderRadius: borr8,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(6.0),
                                              child: Row(
                                                children: [
                                                  const SizedBox(width: 2.0),
                                                  if (NamidaFeaturesVisibility.showRotateScreenInFullScreen && widget.isFullScreen)
                                                    // -- rotate screen button
                                                    NamidaIconButton(
                                                      verticalPadding: 2.0,
                                                      horizontalPadding: 4.0,
                                                      padding: EdgeInsets.zero,
                                                      iconSize: 20.0,
                                                      icon: Broken.rotate_left_1,
                                                      iconColor: itemsColor,
                                                      onPressed: () {
                                                        _startTimer();
                                                        NamidaNavigator.inst.setDeviceOrientations(!NamidaNavigator.inst.isInLanscape);
                                                      },
                                                    ),
                                                  if (widget.isFullScreen) const SizedBox(width: 10.0),
                                                  RepeatModeIconButton(
                                                    compact: true,
                                                    color: itemsColor,
                                                    onPressed: () {
                                                      _startTimer();
                                                    },
                                                  ),
                                                  if (widget.isFullScreen) const SizedBox(width: 10.0) else const SizedBox(width: 8.0),
                                                  SoundControlButton(
                                                    compact: true,
                                                    color: itemsColor,
                                                    onPressed: () {
                                                      _startTimer();
                                                    },
                                                  ),
                                                  if (widget.isFullScreen) const SizedBox(width: 10.0) else const SizedBox(width: 8.0),
                                                  NamidaIconButton(
                                                    verticalPadding: 2.0,
                                                    horizontalPadding: 4.0,
                                                    padding: EdgeInsets.zero,
                                                    iconSize: 20.0,
                                                    icon: Broken.copy,
                                                    iconColor: itemsColor,
                                                    onPressed: () {
                                                      _startTimer();
                                                      final id = Player.inst.currentVideo?.id;
                                                      if (id != null) const YTUtils().copyCurrentVideoUrl(id, withTimestamp: false);
                                                    },
                                                    onLongPress: () {
                                                      _startTimer();
                                                      final id = Player.inst.currentVideo?.id;
                                                      if (id != null) YTUtils.showCopyItemsDialog(id);
                                                    },
                                                  ),
                                                  if (widget.isFullScreen) const SizedBox(width: 10.0) else const SizedBox(width: 8.0),
                                                  NamidaIconButton(
                                                    verticalPadding: 2.0,
                                                    horizontalPadding: 4.0,
                                                    padding: EdgeInsets.zero,
                                                    iconSize: 20.0,
                                                    icon: Broken.maximize_2,
                                                    iconColor: itemsColor,
                                                    onPressed: () {
                                                      _startTimer();
                                                      VideoController.inst.toggleFullScreenVideoView(isLocal: widget.isLocal);
                                                    },
                                                  ),
                                                  const SizedBox(width: 2.0),
                                                ],
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                      if (shouldShowSeekBar && !inLandscape) const SizedBox(height: 24.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ---- Middle Actions ----
                      Padding(
                        padding: safeAreaPadding,
                        child: _getBuilder(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const SizedBox(),
                              ObxO(
                                rx: Player.inst.currentIndex,
                                builder: (context, currentIndex) {
                                  final shouldShowPrev = currentIndex != 0;
                                  return IgnorePointer(
                                    ignoring: !shouldShowPrev,
                                    child: Opacity(
                                      opacity: shouldShowPrev ? 1.0 : 0.0,
                                      child: NamidaBgBlurClipped(
                                        blur: 2,
                                        shape: BoxShape.circle,
                                        child: ColoredBox(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          child: NamidaIconButton(
                                            icon: null,
                                            padding: secondaryButtonPadding,
                                            onPressed: () {
                                              Player.inst.previous();
                                              _startTimer();
                                            },
                                            child: Icon(
                                              Broken.previous,
                                              size: secondaryButtonSize,
                                              color: itemsColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              NamidaBgBlurClipped(
                                blur: 2.5,
                                shape: BoxShape.circle,
                                child: ColoredBox(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  child: NamidaIconButton(
                                    icon: null,
                                    padding: mainButtonPadding,
                                    onPressed: () {
                                      Player.inst.togglePlayPause();
                                      _startTimer();
                                    },
                                    child: ObxO(
                                      rx: Player.inst.playWhenReady,
                                      builder: (context, playWhenReady) => AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        child: playWhenReady
                                            ? Icon(
                                                Broken.pause,
                                                size: mainButtonSize,
                                                color: itemsColor,
                                                key: const Key('paused'),
                                              )
                                            : Icon(
                                                Broken.play,
                                                size: mainButtonSize,
                                                color: itemsColor,
                                                key: const Key('playing'),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              ObxO(
                                rx: Player.inst.currentIndex,
                                builder: (context, currentIndex) {
                                  return ObxO(
                                    rx: Player.inst.currentQueue,
                                    builder: (context, ytqueue) {
                                      final shouldShowNext = currentIndex != ytqueue.length - 1;
                                      return IgnorePointer(
                                        ignoring: !shouldShowNext,
                                        child: Opacity(
                                          opacity: shouldShowNext ? 1.0 : 0.0,
                                          child: NamidaBgBlurClipped(
                                            blur: 2,
                                            shape: BoxShape.circle,
                                            child: ColoredBox(
                                              color: Colors.black.withValues(alpha: 0.2),
                                              child: NamidaIconButton(
                                                icon: null,
                                                padding: secondaryButtonPadding,
                                                onPressed: () {
                                                  Player.inst.next();
                                                  _startTimer();
                                                },
                                                child: Icon(
                                                  Broken.next,
                                                  size: secondaryButtonSize,
                                                  color: itemsColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(),
                            ],
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: Padding(
                          padding: safeAreaPadding,
                          child: Obx(
                            (context) => Player.inst.shouldShowLoadingIndicatorR
                                ? ThreeArchedCircle(
                                    color: itemsColor,
                                    size: mainBufferIconSize,
                                  )
                                : const SizedBox(),
                          ),
                        ),
                      ),

                      // ===== Seek Animators ====

                      Positioned.fill(
                        child: Padding(
                          padding: safeAreaPadding,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // -- left --
                              _getSeekAnimatedContainer(
                                controller: seekAnimationBackward1,
                                isForward: false,
                                isSecondary: false,
                              ),
                              _getSeekAnimatedContainer(
                                controller: seekAnimationBackward2,
                                isForward: false,
                                isSecondary: true,
                              ),

                              // -- right --
                              _getSeekAnimatedContainer(
                                controller: seekAnimationForward1,
                                isForward: true,
                                isSecondary: false,
                              ),
                              _getSeekAnimatedContainer(
                                controller: seekAnimationForward2,
                                isForward: true,
                                isSecondary: true,
                              ),

                              // ===========
                              getSeekTextWidget(
                                controller: seekAnimationBackward2,
                                isForward: false,
                              ),
                              getSeekTextWidget(
                                controller: seekAnimationForward2,
                                isForward: true,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ========= Sliders ==========
                      if (shouldShowSliders) ...[
                        Positioned.fill(
                          child: Padding(
                            padding: safeAreaPadding,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // ======= Brightness Slider ========
                                Positioned(
                                  left: maxWidth * 0.15,
                                  child: Obx(
                                    (context) {
                                      final bri = _canShowBrightnessSlider.valueR ? _currentBrigthnessDim.valueR : null;
                                      return _getVerticalSliderWidget(
                                        'brightness',
                                        bri,
                                        max: _maxBrightnessValue,
                                        Broken.sun_1,
                                        view,
                                      );
                                    },
                                  ),
                                ),
                                // ======= Volume Slider ========
                                Positioned(
                                  right: maxWidth * 0.15,
                                  child: ObxO(
                                    rx: _currentDeviceVolume,
                                    builder: (context, vol) => _getVerticalSliderWidget(
                                      'volume',
                                      vol,
                                      Broken.volume_high,
                                      view,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      Positioned(
                        top: 0,
                        child: ObxO(
                          rx: _isLongPressActive,
                          builder: (context, isLongPress) => AnimatedSwitcher(
                            duration: const Duration(milliseconds: 100),
                            child: isLongPress
                                ? Padding(
                                    key: const Key('longpress_active'),
                                    padding: EdgeInsets.only(top: 24.0 + topPadding),
                                    child: NamidaBgBlurClipped(
                                      blur: 2.5,
                                      child: NamidaInkWell(
                                        borderRadius: 8.0,
                                        bgColor: Colors.black.withValues(alpha: 0.3),
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Broken.forward,
                                              size: 20.0,
                                            ),
                                            const SizedBox(width: 6.0),
                                            Text(
                                              "${lang.SPEED} ${defaultLongPressSpeed}x",
                                              style: context.textTheme.displayMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox(
                                    key: Key('longpress_inactive'),
                                  ),
                          ),
                        ),
                      ),

                      if (widget.isFullScreen && _canShowControls)
                        ObxO(
                          rx: settings.youtube.showChannelWatermarkFullscreen,
                          builder: (context, showChannelWatermarkFullscreen) {
                            if (!showChannelWatermarkFullscreen) return const SizedBox();

                            return Positioned(
                              right: 12.0,
                              bottom: 12.0,
                              child: Padding(
                                padding: safeAreaPadding,
                                child: _YTChannelOverlayThumbnail(
                                  ignoreTouches: _isVisible,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              )
            else if (widget.forceEnableSponsorBlock)
              skipSponsorButton,
          ],
        ),
      ),
    );

    if (settings.youtube.whiteVideoBGInLightMode && context.isDarkMode == false) {
      videoControlsWidget = ColoredBox(
        color: context.theme.scaffoldBackgroundColor,
        child: videoControlsWidget,
      );
    }

    return videoControlsWidget;
  }
}

class _SpeedsEditorDialog extends StatefulWidget {
  const _SpeedsEditorDialog();

  @override
  State<_SpeedsEditorDialog> createState() => __SpeedsEditorDialogState();
}

class __SpeedsEditorDialogState extends State<_SpeedsEditorDialog> {
  final speedsController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    speedsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: CustomBlurryDialog(
        title: lang.CONFIGURE,
        actions: [
          TextButton(
            onPressed: NamidaNavigator.inst.closeDialog,
            child: NamidaButtonText(lang.DONE),
          ),
          NamidaButton(
            text: lang.ADD,
            onPressed: () {
              formKey.currentState?.validate();
            },
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              children: settings.player.speeds
                  .map(
                    (e) => IgnorePointer(
                      ignoring: e == 1.0,
                      child: Opacity(
                        opacity: e == 1.0 ? 0.5 : 1.0,
                        child: Container(
                          margin: const EdgeInsets.all(4.0),
                          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
                          decoration: BoxDecoration(
                            color: context.theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                          ),
                          child: InkWell(
                            onTap: () {
                              if (e == 1.0) {
                                snackyy(message: lang.ERROR); // we already ignore tap but uh
                                return;
                              }
                              if (settings.player.speeds.length <= 4) return showMinimumItemsSnack(4);

                              settings.player.speeds
                                ..remove(e)
                                ..sort();
                              settings.player.save(speeds: settings.player.speeds);
                              setState(() {});
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(e.toString()),
                                const SizedBox(width: 6.0),
                                const Icon(
                                  Broken.close_circle,
                                  size: 18.0,
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: CustomTagTextField(
                controller: speedsController,
                hintText: lang.VALUE,
                labelText: lang.SPEED,
                isNumeric: true,
                validator: (value) {
                  value ??= '';
                  if (value.isEmpty) return lang.EMPTY_VALUE;
                  final sp = double.parse(speedsController.text);
                  if (settings.player.speeds.contains(sp)) return lang.ERROR;
                  settings.player.speeds
                    ..add(sp)
                    ..sort();
                  settings.player.save(speeds: settings.player.speeds);
                  speedsController.clear();
                  setState(() {});
                  return null;
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _YTChannelOverlayThumbnail extends StatefulWidget {
  final bool ignoreTouches;
  const _YTChannelOverlayThumbnail({required this.ignoreTouches});

  @override
  State<_YTChannelOverlayThumbnail> createState() => __YTChannelOverlayThumbnailState();
}

class __YTChannelOverlayThumbnailState extends State<_YTChannelOverlayThumbnail> {
  bool _isHighlighted = false;

  String? _channelOverlayUrl;

  @override
  void initState() {
    _updateChannelOverlayUrl();
    YoutubeInfoController.current.currentYTStreams.addListener(_updateChannelOverlayUrl);
    super.initState();
  }

  @override
  void dispose() {
    YoutubeInfoController.current.currentYTStreams.removeListener(_updateChannelOverlayUrl);
    super.dispose();
  }

  void _updateChannelOverlayUrl() {
    refreshState(
      () {
        _channelOverlayUrl = YoutubeInfoController.current.currentYTStreams.value?.overlay?.overlays.pick()?.url;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final channelOverlayUrl = _channelOverlayUrl;
    return IgnorePointer(
      ignoring: widget.ignoreTouches,
      child: TapDetector(
        onTap: null,
        initializer: (instance) {
          instance
            ..onTapDown = (d) {
              if (mounted) setState(() => _isHighlighted = true);
            }
            ..onTapUp = (d) {
              if (mounted) setState(() => _isHighlighted = false);
            }
            ..onTapCancel = () {
              if (mounted) setState(() => _isHighlighted = false);
            };
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _isHighlighted ? 1 : 0.35,
          child: YoutubeThumbnail(
            key: ValueKey(channelOverlayUrl),
            width: 38.0,
            isImportantInCache: true,
            borderRadius: 0,
            type: ThumbnailType.channel,
            customUrl: channelOverlayUrl,
            displayFallbackIcon: false,
          ),
        ),
      ),
    );
  }
}

class _YTVideoEndcards extends StatefulWidget {
  final bool visible;
  final bool inFullScreen;
  const _YTVideoEndcards({required this.visible, required this.inFullScreen});

  @override
  State<_YTVideoEndcards> createState() => _YTVideoEndcardsState();
}

class _YTVideoEndcardsState extends State<_YTVideoEndcards> {
  List<EndScreenItemBase>? _currentEndcards;
  int? _firstEndCardTimestamp;
  int? _lastEndCardTimestamp;
  bool _canShowAnyEndcard = false;
  late final _fetchedPlaylistsCompleters = <String, Completer<void>?>{};
  late final _fetchedPlaylistsControllers = <String, PopupMenuController?>{};
  late final _fetchedPlaylists = <String, YoutiPiePlaylistResultBase?>{};

  void _onEndcardsChanged() {
    final streamRes = YoutubeInfoController.current.currentYTStreams.value;
    final newEndcards = streamRes?.endscreens;
    if (newEndcards != _currentEndcards) {
      setState(() {
        _currentEndcards = newEndcards;

        _firstEndCardTimestamp = newEndcards?.reduceOrNull((value, element) => element.startMs > value.startMs ? value : element)?.startMs;
        _lastEndCardTimestamp = newEndcards?.reduceOrNull((value, element) => element.endMs > value.endMs ? element : value)?.endMs;
      });
    }
  }

  @override
  void initState() {
    _onEndcardsChanged();
    _onPlayerPositionChange();
    YoutubeInfoController.current.currentYTStreams.addListener(_onEndcardsChanged);
    Player.inst.nowPlayingPosition.addListener(_onPlayerPositionChange);
    super.initState();
  }

  @override
  void dispose() {
    YoutubeInfoController.current.currentYTStreams.removeListener(_onEndcardsChanged);
    Player.inst.nowPlayingPosition.removeListener(_onPlayerPositionChange);
    super.dispose();
  }

  void _onPlayerPositionChange() {
    bool newCanShowAnyEndcard = false;
    final firstEndCardTimestamp = _firstEndCardTimestamp;
    final lastEndCardTimestamp = _lastEndCardTimestamp;
    if (firstEndCardTimestamp != null && lastEndCardTimestamp != null) {
      final currPos = Player.inst.nowPlayingPosition.value;
      newCanShowAnyEndcard = currPos > firstEndCardTimestamp && currPos < lastEndCardTimestamp;
    }

    if (_canShowAnyEndcard != newCanShowAnyEndcard) {
      if (mounted) {
        setState(() => _canShowAnyEndcard = newCanShowAnyEndcard);
      }
    }
  }

  void _exitFullScreenIfNeeded() {
    if (widget.inFullScreen) {
      NamidaNavigator.inst.exitFullScreen();
    }
  }

  List<Widget> _getCustomChildrenVideo(EndScreenItemVideo e) {
    final videoId = e.videoId;
    String? title = e.title;
    String? subtitle = e.viewsCount?.formatDecimalShort() ?? e.viewsCountText;

    final textTheme = context.textTheme;
    return [
      NamidaInkWell(
        onTap: videoId == null
            ? null
            : () {
                NamidaNavigator.inst.navigateDialog(
                  dialog: VideoInfoDialog(
                    videoId: videoId,
                  ),
                );
              },
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Broken.info_circle,
              size: 20.0,
            ),
            const SizedBox(width: 6.0),
            SizedBox(
              width: 168.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.displaySmall,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.displaySmall?.copyWith(
                        fontSize: 10.0,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const NamidaContainerDivider(),
    ];
  }

  FutureOr<List<NamidaPopupItem>> _getItemChildren(EndScreenItemBase item) async {
    switch (item) {
      case EndScreenItemVideo():
        final videoId = item.videoId;
        if (videoId == null) return [];
        return YTUtils.getVideoCardMenuItems(
          queueSource: QueueSourceYoutubeID.videoEndCard,
          downloadIndex: null,
          totalLength: null,
          streamInfoItem: null,
          videoId: videoId,
          channelID: null,
          playlistID: null,
          showInfoTile: false,
          idsNamesLookup: {videoId: item.title},
          isInFullScreen: widget.inFullScreen,
        );
      case EndScreenItemChannel():
        final channelId = item.channelId;
        final channelTitle = item.title;
        return [
          if (channelId != null && channelId.isNotEmpty)
            NamidaPopupItem(
              icon: Broken.user,
              title: lang.GO_TO_CHANNEL,
              subtitle: channelTitle ?? '',
              onTap: () {
                _exitFullScreenIfNeeded();
                YTChannelSubpage(channelID: channelId).navigate();
              },
            ),
        ];
      case EndScreenItemPlaylist():
        final fetchedPlaylistC = _fetchedPlaylistsCompleters[item.basicInfo.id];
        if (fetchedPlaylistC == null) {
          final completer = _fetchedPlaylistsCompleters[item.basicInfo.id] = Completer<void>();
          final cachedPlaylist = await YoutiPie.cacheBuilder.forPlaylistVideos(playlistId: item.basicInfo.id).read();
          if (cachedPlaylist != null) {
            _fetchedPlaylists[item.basicInfo.id] = cachedPlaylist;
            completer.complete();
          } else {
            YoutubeInfoController.playlist.fetchPlaylist(playlistId: item.basicInfo.id).then(
              (fetchedPlaylist) {
                _fetchedPlaylists[item.basicInfo.id] = fetchedPlaylist;
                completer.complete();
                _fetchedPlaylistsControllers[item.basicInfo.id]?.reOpenMenu();
              },
            );
          }
        }

        final fetchedPlaylist = _fetchedPlaylists[item.basicInfo.id];
        if (fetchedPlaylist == null) {
          return [
            NamidaPopupItem(
              icon: Broken.export_2,
              title: lang.OPEN,
              onTap: () {
                _exitFullScreenIfNeeded();
                YTHostedPlaylistSubpage.fromId(
                  playlistId: item.basicInfo.id,
                  userPlaylist: null,
                ).navigate();
              },
            ),
          ];
        } else {
          return item.basicInfo.getPopupMenuItems(
            queueSource: QueueSourceYoutubeID.videoEndCard,
            displayOpenPlaylist: true,
            showProgressSheet: true,
            playlistToFetch: fetchedPlaylist,
            userPlaylist: null,
            isInFullScreen: widget.inFullScreen,
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEndcards = _currentEndcards;
    if (currentEndcards == null || currentEndcards.isEmpty) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: !(_canShowAnyEndcard && widget.visible)
          ? null
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final maxHeight = constraints.maxHeight;

                return ObxO(
                  rx: Player.inst.nowPlayingPosition,
                  builder: (context, playerPosition) => Stack(
                    alignment: Alignment.center,
                    children: currentEndcards.map(
                      (e) {
                        if (playerPosition < e.startMs || playerPosition > e.endMs) {
                          return const SizedBox.shrink();
                        }

                        double leftPadding = e.display.left * maxWidth;
                        double topPadding = e.display.top * maxHeight;

                        final isAvatarShaped = e.type == VideoEndScreenItemType.channel;
                        final url = e.thumbnails.pick()?.url;
                        final width = e.display.width * maxWidth;

                        final controller = e is EndScreenItemPlaylist ? _fetchedPlaylistsControllers[e.basicInfo.id] ??= PopupMenuController() : null;

                        return Positioned(
                          left: leftPadding,
                          top: topPadding,
                          child: NamidaPopupWrapper(
                            controller: controller,
                            openOnTap: true,
                            openOnLongPress: true,
                            children: e is EndScreenItemVideo ? () => _getCustomChildrenVideo(e) : null,
                            childrenDefault: () => _getItemChildren(e),
                            childrenAfterChildrenDefault: false,
                            child: YoutubeThumbnail(
                              key: ValueKey(url),
                              width: width,
                              height: width / e.display.aspectRatio,
                              customUrl: url,
                              isImportantInCache: false,
                              isCircle: isAvatarShaped,
                              forceSquared: !isAvatarShaped,
                              borderRadius: 6.0,
                              type: switch (e.type) {
                                VideoEndScreenItemType.video => ThumbnailType.video,
                                VideoEndScreenItemType.playlist => ThumbnailType.playlist,
                                VideoEndScreenItemType.channel => ThumbnailType.channel,
                                VideoEndScreenItemType.unknown => ThumbnailType.other,
                              },
                              onTopWidgets: e is EndScreenItemPlaylist
                                  ? (_) => [
                                        Positioned(
                                          bottom: 2.0,
                                          right: 2.0,
                                          child: YtThumbnailOverlayBox(
                                            text: e.basicInfo.videosCount?.toString() ?? e.basicInfo.videosCountText,
                                            icon: Broken.play_cricle,
                                          ),
                                        ),
                                      ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                );
              },
            ),
    );
  }
}

class _VideoTitleSubtitleWidget extends StatefulWidget {
  final bool isLocal;

  const _VideoTitleSubtitleWidget({
    required this.isLocal,
  });

  @override
  State<_VideoTitleSubtitleWidget> createState() => _VideoIdToTitleWidgetState();
}

class _VideoIdToTitleWidgetState extends State<_VideoTitleSubtitleWidget> {
  String? _videoName;
  String? _channelName;

  @override
  void initState() {
    super.initState();
    if (widget.isLocal) {
      _onLocalChange();
      Player.inst.currentItem.addListener(_onLocalChange);
    } else {
      _onYTChange();
      Player.inst.currentItem.addListener(_onYTChange);
      YoutubeInfoController.current.currentVideoPage.addListener(_onYTChange);
      YoutubeInfoController.current.currentYTStreams.addListener(_onYTChange);
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (widget.isLocal) {
      Player.inst.currentItem.removeListener(_onLocalChange);
    } else {
      Player.inst.currentItem.removeListener(_onYTChange);
      YoutubeInfoController.current.currentVideoPage.removeListener(_onYTChange);
      YoutubeInfoController.current.currentYTStreams.removeListener(_onYTChange);
    }
  }

  void _onLocalChange() async {
    final item = Player.inst.currentItem.value;
    if (item is! Selectable) return;
    final track = item.track;
    _videoName = track.title;
    _channelName = track.originalArtist;

    refreshState();
  }

  void _onYTChange() async {
    final item = Player.inst.currentItem.value;
    if (item is! YoutubeID) return;
    final vidId = item.id;

    String? videoName = YoutubeInfoController.current.currentVideoPage.value?.videoInfo?.title;
    if (videoName == null || videoName.isEmpty) videoName = YoutubeInfoController.current.currentYTStreams.value?.info?.title;
    if (videoName == null || videoName.isEmpty) videoName = await YoutubeInfoController.utils.getVideoName(vidId);

    String? channelName = YoutubeInfoController.current.currentVideoPage.value?.channelInfo?.title;
    if (channelName == null || channelName.isEmpty) channelName = YoutubeInfoController.current.currentYTStreams.value?.info?.channelName;
    if (channelName == null || channelName.isEmpty) channelName = await YoutubeInfoController.utils.getVideoChannelName(vidId);

    if (videoName != _videoName || channelName != _channelName) {
      _videoName = videoName;
      _channelName = channelName;
      refreshState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final videoName = _videoName;
    final channelName = _channelName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (videoName != null && videoName.isNotEmpty)
          Text(
            videoName,
            style: textTheme.displayLarge?.copyWith(color: const Color.fromRGBO(255, 255, 255, 0.85)),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        if (channelName != null && channelName.isNotEmpty)
          Text(
            channelName,
            style: textTheme.displaySmall?.copyWith(color: const Color.fromRGBO(255, 255, 255, 0.7)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _DropShadowWrapper extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _DropShadowWrapper({
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: Duration(milliseconds: 800),
          reverseDuration: Duration(milliseconds: 500),
          child: enabled
              ? DropShadow(
                  blurRadius: 40,
                  offset: const Offset(0, 0.0),
                  bgSizePercentage: 1.1,
                  sizePercentage: 1.0,
                  child: child,
                )
              : const SizedBox(
                  key: ValueKey('video_bg_blur_disabled'),
                ),
        ),
        child
      ],
    );
  }
}

extension _ListExt<E> on List<E> {
  E? reduceOrNull(E Function(E value, E element) combine) {
    if (isEmpty) return null;
    E value = this.first;
    for (final current in this) {
      value = combine(value, current);
    }
    return value;
  }
}
