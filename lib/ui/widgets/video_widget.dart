import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart' show FlutterVolumeController;
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
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/functions/yt_playlist_utils.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/seek_ready_widget.dart';
import 'package:namida/youtube/widgets/video_info_dialog.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:youtipie/class/result_wrapper/playlist_result_base.dart';
import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/endscreens/endscreen_item_base.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

class NamidaVideoControls extends StatefulWidget {
  final bool showControls;
  final double? disableControlsUnderPercentage;
  final VoidCallback? onMinimizeTap;
  final bool isFullScreen;
  final bool isLocal;

  const NamidaVideoControls({
    super.key,
    required this.showControls,
    this.disableControlsUnderPercentage,
    required this.onMinimizeTap,
    required this.isFullScreen,
    required this.isLocal,
  });

  @override
  State<NamidaVideoControls> createState() => NamidaVideoControlsState();
}

class NamidaVideoControlsState extends State<NamidaVideoControls> with TickerProviderStateMixin {
  bool _isVisible = false;
  final hideDuration = const Duration(seconds: 3);
  final volumeHideDuration = const Duration(milliseconds: 500);
  final brightnessHideDuration = const Duration(milliseconds: 500);
  final transitionDuration = const Duration(milliseconds: 300);
  final doubleTapSeekReset = const Duration(milliseconds: 900);

  Timer? _hideTimer;
  void _resetTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _startTimer() {
    _resetTimer();
    if (_isVisible) {
      _hideTimer = Timer(hideDuration, () {
        setControlsVisibily(false);
      });
    }
  }

  void setControlsVisibily(bool visible, {bool maintainStatusBar = true}) {
    if (visible && NamidaChannel.inst.isInPip.value) return; // dont show if in pip
    if (visible == _isVisible) return;
    if (mounted) setState(() => _isVisible = visible);

    if (maintainStatusBar) {
      if (visible) {
        // -- show status bar
        NamidaNavigator.inst.setDefaultSystemUI(overlays: widget.isFullScreen ? [SystemUiOverlay.top] : SystemUiOverlay.values);
      } else {
        // -- hide status bar
        if (widget.isFullScreen && mounted) SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    }
  }

  final _isEndCardsVisible = true.obs;

  void showControlsBriefly() {
    setControlsVisibily(true);
    _startTimer();
  }

  Widget _getBuilder({
    required Widget child,
  }) {
    return IgnorePointer(
      ignoring: !_isVisible,
      child: AnimatedOpacity(
        duration: transitionDuration,
        opacity: _isVisible ? 1.0 : 0.0,
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

  bool _shouldSeekOnTap = false;
  Timer? _doubleSeekTimer;
  void _startSeekTimer(bool forward) {
    _shouldSeekOnTap = true;
    _doubleSeekTimer?.cancel();
    _doubleSeekTimer = Timer(doubleTapSeekReset, () {
      _shouldSeekOnTap = false;
      _seekSeconds = 0;
    });
  }

  int _seekSeconds = 0;

  /// This prevents mixing up forward seek seconds with backward ones.
  bool _lastSeekWasForward = true;

  void _onDoubleTap(Offset position) async {
    final totalWidth = context.width;
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
              if (Player.inst.nowPlayingPosition.value != 0) {
                _seekSeconds += finalSeconds;
              }
            } else {
              _seekSeconds = finalSeconds;
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
              if (Player.inst.nowPlayingPosition.value != Player.inst.currentItemDuration.value?.inMilliseconds) {
                _seekSeconds += finalSeconds;
              }
            } else {
              _seekSeconds = finalSeconds;
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
  }

  void _setScreenBrightness(double value) async {
    value = value.clamp(0.01, 1.0); // -- below 0.01 treats it as 0 and disables it making it jump to system brightness
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value);
    } catch (_) {}
  }

  StreamSubscription<double>? _systemBrightnessStreamSub;

  final _volumeListenerKey = 'video_widget';

  @override
  void dispose() {
    seekAnimationForward1.dispose();
    seekAnimationForward2.dispose();
    seekAnimationBackward1.dispose();
    seekAnimationBackward2.dispose();
    _currentDeviceVolume.close();
    _canShowBrightnessSlider.close();
    Player.inst.onVolumeChangeRemoveListener(_volumeListenerKey);
    MiniPlayerController.inst.animation.removeListener(_disableControlsListener);
    _systemBrightnessStreamSub?.cancel();
    if (widget.isFullScreen && NamidaFeaturesVisibility.changeApplicationBrightness) {
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    }
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
    final seekContainerSize = context.width;
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
                color: Colors.white.withValues(alpha: (controller.value / 3).clamp(0, 1)),
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
    final seekContainerSize = context.width;
    final finalOffset = seekContainerSize * 0.05;
    final forwardIcons = <int, IconData>{
      5: Broken.forward_5_seconds,
      10: Broken.forward_10_seconds,
      15: Broken.forward_15_seconds,
    };
    final backwardIcons = <int, IconData>{
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
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final ss = _seekSeconds;
            return NamidaOpacity(
              opacity: controller.value,
              child: RepaintBoundary(
                child: Column(
                  children: [
                    Icon(
                      isForward ? forwardIcons[ss] ?? Broken.forward : backwardIcons[ss] ?? Broken.backward,
                      color: color,
                      shadows: outlineShadow,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      '$ss ${lang.SECONDS}',
                      style: context.textTheme.displayMedium?.copyWith(
                        color: color,
                        shadows: outlineShadow,
                      ),
                    )
                  ],
                ),
              ),
            );
          },
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
  }) {
    return NamidaInkWell(
      onTap: () {
        _startTimer();
        Navigator.of(context).pop();
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
                    style: context.textTheme.displayMedium?.copyWith(fontSize: 13.0),
                  ),
                  if (subtitle != null && subtitle != '')
                    Text(
                      subtitle,
                      style: context.textTheme.displaySmall?.copyWith(fontSize: 12.0),
                    ),
                ],
              ),
              if (thirdLine != null && thirdLine != '')
                Text(
                  thirdLine,
                  style: context.textTheme.displaySmall?.copyWith(fontSize: 12.0),
                ),
            ],
          ),
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
    final minimumVerticalDistanceToIgnoreSwipes = context.height * 0.1;

    final isSafeFromDown = globalHeight > minimumVerticalDistanceToIgnoreSwipes;
    final isSafeFromUp = globalHeight < context.height - minimumVerticalDistanceToIgnoreSwipes;
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
                      style: context.textTheme.displaySmall,
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

  @override
  Widget build(BuildContext context) {
    final maxWidth = context.width;
    final maxHeight = context.height;
    final inLandscape = NamidaNavigator.inst.isInLanscape;

    // -- in landscape, the size is calculated based on height, to fit in correctly.
    final fallbackHeight = inLandscape ? maxHeight : maxWidth * 9 / 16;
    final fallbackWidth = inLandscape ? maxHeight * 16 / 9 : maxWidth;

    final finalVideoWidget = ObxO(
        key: _videoConstraintsKey,
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
                    videoId: vidId,
                    displayFallbackIcon: false,
                    compressed: false,
                    preferLowerRes: false,
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
                  compressed: false,
                );
              });
        });

    final newDeviceInsets = MediaQuery.paddingOf(context);
    if (newDeviceInsets != EdgeInsets.zero) _deviceInsets = newDeviceInsets;

    final horizontalControlsPadding = widget.isFullScreen
        ? inLandscape
            ? EdgeInsets.only(left: 12.0 + _deviceInsets.left, right: 12.0 + _deviceInsets.right) // lanscape videos
            : EdgeInsets.only(left: 12.0 + _deviceInsets.left, right: 12.0 + _deviceInsets.right) // vertical videos
        : const EdgeInsets.symmetric(horizontal: 2.0);
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

    bool showEndcards = settings.youtube.showVideoEndcards.value && _canShowControls;
    String? channelOverlayUrl = widget.isFullScreen && settings.youtube.showChannelWatermarkFullscreen.value && _canShowControls //
        ? YoutubeInfoController.current.currentYTStreams.value?.overlay?.overlays.pick()?.url
        : null;

    Widget videoControlsWidget = Listener(
      onPointerDown: (event) {
        _pointerDownedOnRight = event.position.dx > context.width / 2;
        _isPointerDown = true;
        if (_shouldSeekOnTap) {
          _onDoubleTap(event.position);
          _startTimer();
        }
        _disableSliders = !_canSlideVolume(context, event.position.dy);
      },
      onPointerUp: (event) {
        _isPointerDown = false;
        _disableSliders = false;
        _startVolumeSwipeTimer();
        _startBrightnessDimTimer();
        _isEndCardsVisible.value = true;
      },
      onPointerMove: (event) {
        _isEndCardsVisible.value = false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
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
              child: finalVideoWidget,
            ),
            // ---- Brightness Mask -----
            Positioned.fill(
              child: ObxO(
                rx: _currentBrigthnessDim,
                builder: (context, brightness) => brightness < 1.0
                    ? ColoredBox(
                        color: Colors.black.withValues(alpha: 1 - brightness),
                      )
                    : SizedBox.shrink(),
              ),
            ),

            if (showEndcards)
              ObxO(
                rx: _isEndCardsVisible,
                builder: (context, endcardsvisible) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: endcardsvisible
                      ? _YTVideoEndcards(
                          inFullScreen: widget.isFullScreen,
                          videoConstraintsKey: _videoConstraintsKey,
                        )
                      : null,
                ),
              ),

            if (_canShowControls) ...[
              // ---- Mask -----
              Positioned.fill(
                child: _getBuilder(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.25),
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
                                    child: Obx((context) {
                                      String? videoName;
                                      String? channelName;

                                      if (widget.isLocal) {
                                        final track = Player.inst.currentTrackR?.track;
                                        videoName = track?.title;
                                        channelName = track?.originalArtist;
                                      } else {
                                        videoName = YoutubeInfoController.current.currentVideoPage.valueR?.videoInfo?.title ??
                                            YoutubeInfoController.current.currentYTStreams.valueR?.info?.title;
                                        if (videoName == null) {
                                          final vidId = Player.inst.currentVideoR?.id;
                                          if (vidId != null) videoName = YoutubeInfoController.utils.getVideoName(vidId);
                                        }

                                        channelName = YoutubeInfoController.current.currentVideoPage.valueR?.channelInfo?.title ??
                                            YoutubeInfoController.current.currentYTStreams.valueR?.info?.channelName;
                                        if (channelName == null) {
                                          final vidId = Player.inst.currentVideoR?.id;
                                          if (vidId != null) channelName = YoutubeInfoController.utils.getVideoChannelName(vidId);
                                        }
                                      }
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (videoName != null && videoName != '')
                                            Text(
                                              videoName,
                                              style: context.textTheme.displayLarge?.copyWith(color: const Color.fromRGBO(255, 255, 255, 0.85)),
                                            ),
                                          if (channelName != null && channelName != '')
                                            Text(
                                              channelName,
                                              style: context.textTheme.displaySmall?.copyWith(color: const Color.fromRGBO(255, 255, 255, 0.7)),
                                            ),
                                        ],
                                      );
                                    }),
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
                              ...settings.player.speeds.map((speed) {
                                return ObxO(
                                  rx: Player.inst.currentSpeed,
                                  builder: (context, selectedSpeed) {
                                    final isSelected = selectedSpeed == speed;
                                    return NamidaInkWell(
                                      onTap: () {
                                        _startTimer();
                                        Navigator.of(context).pop();
                                        if (!isSelected) {
                                          Player.inst.setPlayerSpeed(speed);
                                          settings.player.save(speed: speed);
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
                                            style: context.textTheme.displayMedium?.copyWith(fontSize: 13.0),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }),
                              NamidaInkWell(
                                onTap: () {
                                  _startTimer();
                                  Navigator.of(context).pop();
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
                                      style: context.textTheme.displayMedium?.copyWith(fontSize: 13.0),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: BorderRadiusClip(
                                borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                child: NamidaBgBlur(
                                  blur: 3.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                    ),
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
                                              style: context.textTheme.displaySmall?.copyWith(
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
                          ),
                          ObxO(
                              rx: YoutubeInfoController.current.currentYTStreams,
                              builder: (context, streams) {
                                final currentYTAudioStreams = streams?.audioStreams;
                                if (currentYTAudioStreams == null || currentYTAudioStreams.isEmpty) return const SizedBox();
                                final audioStreamsAll = List<AudioStream>.from(currentYTAudioStreams); // check below
                                final streamsMap = <String, AudioStream>{}; // {language: audiostream}
                                audioStreamsAll.sortBy((e) => e.audioTrack?.displayName ?? '');
                                audioStreamsAll.loop((e) {
                                  if (!e.isWebm) {
                                    final langCode = e.audioTrack?.langCode;
                                    if (langCode != null) streamsMap[langCode] = e;
                                  }
                                });
                                if (streamsMap.keys.length <= 1) return const SizedBox();

                                return NamidaPopupWrapper(
                                  openOnTap: true,
                                  onPop: _startTimer,
                                  onTap: () {
                                    _resetTimer();
                                    setControlsVisibily(true);
                                  },
                                  children: () => [
                                    ...streamsMap.values.map(
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
                                            isCached: element.getCachedFile(id) != null,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: BorderRadiusClip(
                                      borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                      child: NamidaBgBlur(
                                        blur: 3.0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                          ),
                                          child: Obx(
                                            (context) {
                                              final displayName =
                                                  Player.inst.currentAudioStream.valueR?.audioTrack?.displayName ?? Player.inst.currentCachedAudio.valueR?.langaugeName;
                                              return displayName == null || displayName == ''
                                                  ? const SizedBox()
                                                  : Text(
                                                      displayName,
                                                      style: context.textTheme.displaySmall?.copyWith(color: itemsColor),
                                                    );
                                            },
                                          ),
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
                            children: () {
                              VideoStreamsResult? streams;
                              if (widget.isLocal) {
                                streams = VideoController.inst.currentYTStreams.value;
                              } else {
                                streams = YoutubeInfoController.current.currentYTStreams.value;
                              }
                              final ytQualities =
                                  streams?.videoStreams.withoutWebmIfNeccessaryOrExperimentalCodecs(allowExperimentalCodecs: settings.youtube.allowExperimentalCodecs);
                              final cachedQualitiesAll = widget.isLocal ? VideoController.inst.currentPossibleLocalVideos : YoutubeInfoController.current.currentCachedQualities;
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
                                        final cachedFile = id == null ? null : element.getCachedFile(id);
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
                              child: BorderRadiusClip(
                                borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                child: NamidaBgBlur(
                                  blur: 3.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                    ),
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
                                              secondaryIcon = Broken.magicpen;
                                            }
                                          }
                                        }

                                        return Row(
                                          children: [
                                            if (qt != null) ...[
                                              Text(
                                                qt,
                                                style: context.textTheme.displaySmall?.copyWith(color: itemsColor),
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // ---- Bottom Row ----
              Padding(
                padding: horizontalControlsPadding + EdgeInsets.only(bottom: bottomPadding),
                child: TapDetector(
                  onTap: () {},
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _getBuilder(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (shouldShowSeekBar)
                              SizedBox(
                                width: context.width,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: SeekReadyWidget(
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
                                BorderRadiusClip(
                                  borderRadius: borr8,
                                  child: NamidaBgBlur(
                                    blur: 3.0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6.0),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        borderRadius: borr8,
                                      ),
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
                                                style: context.textTheme.displayMedium?.copyWith(
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
                                                  style: context.textTheme.displayMedium?.copyWith(
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
                                ),
                                const SizedBox(width: 4.0),
                                if (widget.isFullScreen) ...[
                                  // -- queue order
                                  Obx(
                                    (context) {
                                      final queueL = Player.inst.currentQueue.valueR.length;
                                      if (queueL <= 1) return const SizedBox();
                                      return BorderRadiusClip(
                                        borderRadius: borr8,
                                        child: NamidaBgBlur(
                                          blur: 3.0,
                                          child: Container(
                                            padding: const EdgeInsets.all(6.0),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.2),
                                              borderRadius: borr8,
                                            ),
                                            child: Obx(
                                              (context) => Text(
                                                "${Player.inst.currentIndex.valueR + 1}/$queueL",
                                                style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600, color: itemsColor),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 4.0),
                                ],
                                const Spacer(),
                                const SizedBox(width: 4.0),
                                BorderRadiusClip(
                                  borderRadius: borr8,
                                  child: NamidaBgBlur(
                                    blur: 3.0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6.0),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        borderRadius: borr8,
                                      ),
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
                                          EqualizerIconButton(
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
              ),

              // ---- Middle Actions ----
              _getBuilder(
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
                            child: ClipOval(
                              child: NamidaBgBlur(
                                blur: 2,
                                child: ColoredBox(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  child: NamidaIconButton(
                                    icon: null,
                                    padding: const EdgeInsets.all(10.0),
                                    onPressed: () {
                                      Player.inst.previous();
                                      _startTimer();
                                    },
                                    child: Icon(
                                      Broken.previous,
                                      size: 30.0,
                                      color: itemsColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    ClipOval(
                      child: NamidaBgBlur(
                        blur: 2.5,
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.3),
                          child: NamidaIconButton(
                            icon: null,
                            padding: const EdgeInsets.all(14.0),
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
                                        size: 40.0,
                                        color: itemsColor,
                                        key: const Key('paused'),
                                      )
                                    : Icon(
                                        Broken.play,
                                        size: 40.0,
                                        color: itemsColor,
                                        key: const Key('playing'),
                                      ),
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
                                child: ClipOval(
                                  child: NamidaBgBlur(
                                    blur: 2,
                                    child: ColoredBox(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      child: NamidaIconButton(
                                        icon: null,
                                        padding: const EdgeInsets.all(10.0),
                                        onPressed: () {
                                          Player.inst.next();
                                          _startTimer();
                                        },
                                        child: Icon(
                                          Broken.next,
                                          size: 30.0,
                                          color: itemsColor,
                                        ),
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
              IgnorePointer(
                child: Obx(
                  (context) => Player.inst.shouldShowLoadingIndicatorR
                      ? ThreeArchedCircle(
                          color: itemsColor,
                          size: 52.0,
                        )
                      : const SizedBox(),
                ),
              ),

              // ===== Seek Animators ====

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

              // ========= Sliders ==========
              if (shouldShowSliders) ...[
                // ======= Brightness Slider ========
                Positioned(
                  left: context.width * 0.15,
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
                  right: context.width * 0.15,
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
            ],

            if (channelOverlayUrl != null)
              Positioned(
                right: 12.0,
                bottom: 12.0,
                child: _YTChannelOverlayThumbnail(
                  channelOverlayUrl: channelOverlayUrl,
                  ignoreTouches: _isVisible,
                ),
              ),
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
  final String channelOverlayUrl;
  final bool ignoreTouches;
  const _YTChannelOverlayThumbnail({required this.channelOverlayUrl, required this.ignoreTouches});

  @override
  State<_YTChannelOverlayThumbnail> createState() => __YTChannelOverlayThumbnailState();
}

class __YTChannelOverlayThumbnailState extends State<_YTChannelOverlayThumbnail> {
  bool _isHighlighted = false;

  @override
  Widget build(BuildContext context) {
    final channelOverlayUrl = widget.channelOverlayUrl;
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
          ),
        ),
      ),
    );
  }
}

class _YTVideoEndcards extends StatefulWidget {
  final GlobalKey videoConstraintsKey;
  final bool inFullScreen;
  const _YTVideoEndcards({required this.videoConstraintsKey, required this.inFullScreen});

  @override
  State<_YTVideoEndcards> createState() => _YTVideoEndcardsState();
}

class _YTVideoEndcardsState extends State<_YTVideoEndcards> {
  List<EndScreenItemBase>? _currentEndcards;
  late final _fetchedPlaylistsCompleters = <String, Completer<void>?>{};
  late final _fetchedPlaylists = <String, YoutiPiePlaylistResultBase?>{};

  void _onEndcardsChanged() {
    final streamRes = YoutubeInfoController.current.currentYTStreams.value;
    final newEndcards = streamRes?.endscreens;
    if (newEndcards != _currentEndcards) {
      setState(() {
        _currentEndcards = newEndcards;
      });
    }
  }

  @override
  void initState() {
    _onEndcardsChanged();
    YoutubeInfoController.current.currentYTStreams.addListener(_onEndcardsChanged);
    super.initState();
  }

  @override
  void dispose() {
    YoutubeInfoController.current.currentYTStreams.removeListener(_onEndcardsChanged);
    super.dispose();
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

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: TapDetector(
          onTap: videoId == null
              ? null
              : () {
                  NamidaNavigator.inst.navigateDialog(
                    dialog: VideoInfoDialog(
                      videoId: videoId,
                    ),
                  );
                },
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
                      style: context.textTheme.displaySmall,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.displaySmall?.copyWith(
                          fontSize: 10.0,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const NamidaContainerDivider(),
    ];
  }

  List<NamidaPopupItem> _getItemChildren(EndScreenItemBase item) {
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
          final cachedPlaylist = YoutiPie.cacheBuilder.forPlaylistVideos(playlistId: item.basicInfo.id).read();
          if (cachedPlaylist != null) {
            _fetchedPlaylists[item.basicInfo.id] = cachedPlaylist;
            completer.complete();
          } else {
            YoutubeInfoController.playlist.fetchPlaylist(playlistId: item.basicInfo.id).then(
              (fetchedPlaylist) {
                _fetchedPlaylists[item.basicInfo.id] = fetchedPlaylist;
                completer.complete();
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
            context: context,
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

    final maxWidth = context.width;
    final maxHeight = context.height;
    return LayoutBuilder(builder: (context, constraints) {
      double maxWidthFinal = maxWidth;
      double maxHeightFinal = maxHeight;
      final keyContext = widget.videoConstraintsKey.currentContext;
      if (keyContext != null) {
        try {
          final box = keyContext.findRenderObject() as RenderBox;
          if (box.size.width < maxWidthFinal) maxWidthFinal = box.size.width;
          if (box.size.height < maxHeightFinal) maxHeightFinal = box.size.height;
        } catch (_) {
          // layout error (not laid out yet)
        }
      }
      return Stack(
        alignment: Alignment.center,
        children: currentEndcards.map(
          (e) {
            double leftPadding = e.display.left * maxWidthFinal;
            double topPadding = e.display.top * maxHeightFinal;
            if (widget.inFullScreen) {
              leftPadding += ((maxWidth - maxWidthFinal) / 2);
              topPadding += ((maxHeight - maxHeightFinal) / 2);
            }

            final isAvatarShaped = e.type == VideoEndScreenItemType.channel;
            final url = e.thumbnails.pick()?.url;
            final width = e.display.width * maxWidthFinal;

            return Positioned(
              left: leftPadding,
              top: topPadding,
              child: ObxO(
                rx: Player.inst.nowPlayingPosition,
                builder: (context, playerPosition) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: playerPosition < e.startMs || playerPosition > e.endMs
                        ? const SizedBox.shrink(key: ValueKey(0))
                        : NamidaPopupWrapper(
                            key: const ValueKey(1),
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
              ),
            );
          },
        ).toList(),
      );
    });
  }
}
