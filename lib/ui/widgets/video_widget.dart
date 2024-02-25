import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';
import 'package:namida/youtube/yt_utils.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/namida_channel.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/seek_ready_widget.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class NamidaVideoControls extends StatefulWidget {
  final bool showControls;
  final VoidCallback? onMinimizeTap;
  final bool isFullScreen;
  final bool isLocal;

  const NamidaVideoControls({
    super.key,
    required this.showControls,
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
  void _resetTimer({bool hideControls = false}) {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (hideControls) setControlsVisibily(false);
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

  void showControlsBriefly() {
    setControlsVisibily(true);
    _startTimer();
  }

  final userSeekMS = 0.obs;

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
              if (Player.inst.nowPlayingPosition != 0) {
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
              if (Player.inst.nowPlayingPosition != Player.inst.currentItemDuration?.inMilliseconds) {
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
  }

  final _volumeListenerKey = 'video_widget';

  @override
  void dispose() {
    seekAnimationForward1.dispose();
    seekAnimationForward2.dispose();
    seekAnimationBackward1.dispose();
    seekAnimationBackward2.dispose();
    userSeekMS.close();
    _currentDeviceVolume.close();
    _canShowBrightnessSlider.close();
    Player.inst.onVolumeChangeRemoveListener(_volumeListenerKey);
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
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity((controller.value / 3).clamp(0, 1)),
                shape: BoxShape.circle,
              ),
              width: seekContainerSize,
              height: seekContainerSize,
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
    const strokeColor = Color.fromRGBO(20, 20, 20, 0.8);
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
            );
          },
        ),
      ),
    );
  }

  Widget _getQualityChip({
    required String title,
    String subtitle = '',
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
      bgColor: selected ? CurrentColor.inst.color.withAlpha(100) : null,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      padding: const EdgeInsets.all(6.0),
      child: Row(
        children: [
          Icon(icon ?? (isCached ? Broken.tick_circle : Broken.story), size: 20.0),
          const SizedBox(width: 4.0),
          Text(
            title,
            style: context.textTheme.displayMedium?.copyWith(fontSize: 13.0.multipliedFontScale),
          ),
          if (subtitle != '')
            Text(
              subtitle,
              style: context.textTheme.displaySmall?.copyWith(fontSize: 12.0.multipliedFontScale),
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

  bool get _showLoadingIndicator {
    final isLoading = Player.inst.isBuffering || Player.inst.isLoading;
    return isLoading && !Player.inst.isPlaying;
  }

  RxDouble get _currentBrigthnessDim => VideoController.inst.currentBrigthnessDim;

  Widget _getVerticalSliderWidget(String key, double? perc, IconData icon, ui.FlutterView view) {
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
                  color: context.theme.cardColor.withOpacity(0.5),
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
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                          ),
                          width: 4.0,
                          height: totalHeight * 0.4,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: CurrentColor.inst.color,
                            borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                          ),
                          width: 4.0,
                          height: totalHeight * 0.4 * perc,
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

  bool get _canShowControls => widget.showControls && !NamidaChannel.inst.isInPip.value;

  @override
  Widget build(BuildContext context) {
    final fallbackChild = widget.isLocal && !widget.isFullScreen
        ? Container(
            key: const Key('dummy_container'),
            color: Colors.transparent,
          )
        : Obx(
            () {
              if (widget.isLocal) {
                final track = Player.inst.nowPlayingTrack;
                if (File(track.pathToImage).existsSync()) {
                  return ArtworkWidget(
                    key: Key(track.path),
                    track: track,
                    path: track.pathToImage,
                    thumbnailSize: context.width,
                    width: context.width,
                    height: context.width * 9 / 16,
                    borderRadius: 0,
                    blur: 0,
                    compressed: false,
                  );
                }
              }
              final vidId = Player.inst.nowPlayingVideoID?.id ?? (YoutubeController.inst.currentYoutubeMetadataVideo.value ?? Player.inst.currentVideoInfo)?.id;
              return YoutubeThumbnail(
                key: Key(vidId ?? ''),
                isImportantInCache: true,
                width: context.width,
                height: context.width * 9 / 16,
                borderRadius: 0,
                blur: 0,
                videoId: vidId,
                displayFallbackIcon: false,
                compressed: false,
                preferLowerRes: false,
              );
            },
          );
    final inLandscape = NamidaNavigator.inst.isInLanscape;
    final horizontalControlsPadding = widget.isFullScreen
        ? inLandscape
            ? const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0) // lanscape videos
            : const EdgeInsets.symmetric(horizontal: 12.0, vertical: 24.0) // vertical videos
        : const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0);
    final itemsColor = Colors.white.withAlpha(200);
    final shouldShowSliders = _canShowControls && widget.isFullScreen;
    final shouldShowSeekBar = widget.isFullScreen;
    final view = View.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanEnd: (event) {
        _isPointerDown = false;
        _disableSliders = false;
        _startVolumeSwipeTimer();
        _startBrightnessDimTimer();
      },
      onPanDown: (event) {
        _pointerDownedOnRight = event.globalPosition.dx > context.width / 2;
        _isPointerDown = true;
        if (_shouldSeekOnTap) {
          _onDoubleTap(event.globalPosition);
          _startTimer();
        }
        _disableSliders = !_canSlideVolume(context, event.globalPosition.dy);
      },
      onVerticalDragCancel: () {
        _isPointerDown = false;
        _disableSliders = false;
        _startVolumeSwipeTimer();
        _startBrightnessDimTimer();
      },
      onVerticalDragEnd: (details) {
        _isPointerDown = false;
        _disableSliders = false;
        _startVolumeSwipeTimer();
        _startBrightnessDimTimer();
      },
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
                  _currentBrigthnessDim.value = (_currentBrigthnessDim.value + 0.01).withMaximum(1.0);
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
          Stack(
            alignment: Alignment.center,
            children: [
              Obx(() {
                final info = Player.inst.videoPlayerInfo;
                return info != null && info.isInitialized
                    ? NamidaAspectRatio(
                        aspectRatio: info.aspectRatio,
                        child: Obx(
                          () => AnimatedScale(
                            duration: const Duration(milliseconds: 200),
                            scale: 1.0 + VideoController.inst.videoZoomAdditionalScale.value * 0.02,
                            child: Texture(textureId: info.textureId),
                          ),
                        ),
                      )
                    : SizedBox(
                        height: context.height,
                        width: context.height * 16 / 9,
                        child: fallbackChild,
                      );
              })
            ],
          ),
          // ---- Brightness Mask -----
          Positioned.fill(
            child: Obx(
              () => Container(
                color: Colors.black.withOpacity(1 - _currentBrigthnessDim.value),
              ),
            ),
          ),

          if (_canShowControls) ...[
            // ---- Mask -----
            Positioned.fill(
              child: _getBuilder(
                child: Container(
                  color: Colors.black.withOpacity(0.25),
                ),
              ),
            ),

            // ---- Top Row ----
            SafeArea(
              left: false,
              right: false,
              child: Padding(
                padding: horizontalControlsPadding,
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
                                    child: Obx(() {
                                      final videoName = widget.isLocal
                                          ? Player.inst.nowPlayingTrack.title
                                          : YoutubeController.inst.currentYoutubeMetadataVideo.value?.name ?? Player.inst.currentVideoInfo?.name ?? '';
                                      final channelName = widget.isLocal
                                          ? Player.inst.nowPlayingTrack.originalArtist
                                          : YoutubeController.inst.currentYoutubeMetadataChannel.value?.name ?? Player.inst.currentVideoInfo?.uploaderName ?? '';
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (videoName != '')
                                            Text(
                                              videoName,
                                              style: context.textTheme.displayLarge?.copyWith(color: const Color.fromRGBO(255, 255, 255, 0.85)),
                                            ),
                                          if (channelName != '')
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
                          const SizedBox(width: 8.0),
                          // ==== Reset Brightness ====
                          Obx(
                            () => AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _currentBrigthnessDim.value < 1.0
                                  ? NamidaIconButton(
                                      key: const Key('brightnesseto_ok'),
                                      tooltip: lang.RESET_BRIGHTNESS,
                                      icon: Broken.sun_1,
                                      iconColor: itemsColor.withOpacity(0.8),
                                      horizontalPadding: 0.0,
                                      iconSize: 18.0,
                                      onPressed: () => _currentBrigthnessDim.value = 1.0,
                                    )
                                  : const SizedBox(
                                      key: Key('brightnesseto_no'),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          // ===== Speed Chip =====
                          NamidaPopupWrapper(
                            onPop: _startTimer,
                            onTap: () {
                              _resetTimer();
                              setControlsVisibily(true);
                            },
                            children: () => [
                              ...[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
                                return Obx(
                                  () {
                                    final isSelected = Player.inst.currentSpeed == speed;
                                    return NamidaInkWell(
                                      onTap: () {
                                        _startTimer();
                                        Navigator.of(context).pop();
                                        if (!isSelected) {
                                          Player.inst.setPlayerSpeed(speed);
                                        }
                                      },
                                      decoration: const BoxDecoration(),
                                      borderRadius: 6.0,
                                      bgColor: isSelected ? CurrentColor.inst.color.withAlpha(100) : null,
                                      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                      padding: const EdgeInsets.all(6.0),
                                      child: Row(
                                        children: [
                                          const Icon(Broken.play_cricle, size: 20.0),
                                          const SizedBox(width: 12.0),
                                          Text(
                                            "$speed",
                                            style: context.textTheme.displayMedium?.copyWith(fontSize: 13.0.multipliedFontScale),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                child: NamidaBgBlur(
                                  blur: 3.0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                    ),
                                    child: Obx(
                                      () => Row(
                                        children: [
                                          Icon(
                                            Broken.play_cricle,
                                            size: 16.0,
                                            color: itemsColor,
                                          ),
                                          const SizedBox(width: 4.0).animateEntrance(showWhen: Player.inst.currentSpeed != 1.0, allCurves: Curves.easeInOutQuart),
                                          Text(
                                            "${Player.inst.currentSpeed}",
                                            style: context.textTheme.displaySmall?.copyWith(
                                              color: itemsColor,
                                              fontSize: 12.0,
                                            ),
                                          ).animateEntrance(showWhen: Player.inst.currentSpeed != 1.0, allCurves: Curves.easeInOutQuart),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Obx(() {
                            final audioStreamsAll = List<AudioOnlyStream>.from(YoutubeController.inst.currentYTAudioStreams);
                            final streamsMap = <String, AudioOnlyStream>{}; // {language: audiostream}
                            audioStreamsAll.sortBy((e) => e.displayLanguage ?? '');
                            audioStreamsAll.loop((e, index) {
                              if (e.language != null && e.formatSuffix != 'webm') {
                                streamsMap[e.language!] = e;
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
                                    () {
                                      final isSelected1 = element.language == Player.inst.currentCachedAudio?.langaugeCode;
                                      final isSelected2 = element.language == Player.inst.currentAudioStream?.language;
                                      final isSelected = isSelected1 || isSelected2;
                                      final id = Player.inst.nowPlayingVideoID?.id;
                                      return _getQualityChip(
                                        title: '${element.displayLanguage}',
                                        subtitle: " • ${element.language ?? 0}",
                                        onPlay: (isSelected) {
                                          if (!isSelected) {
                                            Player.inst.onItemPlayYoutubeIDSetAudio(
                                              stream: element,
                                              cachedFile: null,
                                              useCache: true,
                                              videoId: Player.inst.nowPlayingVideoID?.id ?? '',
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
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                  child: NamidaBgBlur(
                                    blur: 3.0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                      ),
                                      child: Obx(
                                        () {
                                          final currentStream = Player.inst.currentAudioStream;
                                          final currentCached = Player.inst.currentCachedAudio;
                                          final qt = currentStream?.displayLanguage ?? currentCached?.langaugeName;
                                          return qt == null
                                              ? const SizedBox()
                                              : Text(
                                                  qt,
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
                          Obx(
                            () {
                              final ytQualities =
                                  (widget.isLocal ? VideoController.inst.currentYTQualities : YoutubeController.inst.currentYTQualities).where((s) => s.formatSuffix != 'webm');
                              final cachedQualitiesAll = widget.isLocal ? VideoController.inst.currentPossibleVideos : YoutubeController.inst.currentCachedQualities;
                              final cachedQualities = List<NamidaVideo>.from(cachedQualitiesAll);
                              final videoId = Player.inst.nowPlayingVideoID?.id;
                              cachedQualities.removeWhere(
                                (cq) {
                                  return ytQualities.any((ytq) {
                                    if (widget.isLocal) return ytq.height == cq.height;
                                    final cachePath = videoId == null ? null : ytq.cachePath(videoId);
                                    if (cachePath == cq.path) return true;
                                    if (ytq.sizeInBytes == cq.sizeInBytes) return true;
                                    final sameRes = ytq.resolution == null ? false : cq.resolution.toString().startsWith(ytq.resolution!); // 720p.startsWith(720p60).
                                    final sameFrames = ytq.fps == null ? true : ytq.fps == cq.framerate;
                                    return sameRes && sameFrames;
                                  });
                                },
                              );
                              return NamidaPopupWrapper(
                                openOnTap: true,
                                onPop: _startTimer,
                                onTap: () {
                                  _resetTimer();
                                  setControlsVisibily(true);
                                },
                                children: () => [
                                  Obx(
                                    () => _getQualityChip(
                                      title: lang.AUDIO_ONLY,
                                      onPlay: (isSelected) {
                                        Player.inst.setAudioOnlyPlayback(true);
                                        VideoController.inst.currentVideo.value = null;
                                        settings.save(enableVideoPlayback: false);
                                      },
                                      selected: (widget.isLocal ? VideoController.inst.currentVideo.value == null : Player.inst.isAudioOnlyPlayback),
                                      isCached: false,
                                      icon: Broken.musicnote,
                                    ),
                                  ),
                                  ...cachedQualities.map(
                                    (element) => Obx(
                                      () => _getQualityChip(
                                        title: '${element.resolution}p${element.framerateText()}',
                                        subtitle: " • ${element.sizeInBytes.fileSizeFormatted}",
                                        onPlay: (isSelected) {
                                          // sometimes video is not initialized so we need the second check
                                          if (!isSelected || !Player.inst.videoInitialized) {
                                            Player.inst.onItemPlayYoutubeIDSetQuality(
                                              stream: null,
                                              cachedFile: File(element.path),
                                              videoItem: element,
                                              useCache: true,
                                              videoId: Player.inst.nowPlayingVideoID?.id ?? '',
                                            );
                                            if (widget.isLocal) {
                                              VideoController.inst.currentVideo.value = element;
                                              settings.save(enableVideoPlayback: true);
                                            }
                                          }
                                        },
                                        selected: (widget.isLocal ? VideoController.inst.currentVideo.value : Player.inst.currentCachedVideo)?.path == element.path,
                                        isCached: true,
                                      ),
                                    ),
                                  ),
                                  ...ytQualities.map((element) {
                                    final sizeInBytes = element.sizeInBytes;
                                    return Obx(
                                      () {
                                        if (widget.isLocal) {
                                          final id = Player.inst.nowPlayingVideoID?.id;
                                          final isSelected = element.height == VideoController.inst.currentVideo.value?.height;

                                          return _getQualityChip(
                                            title: element.resolution ?? '',
                                            subtitle: sizeInBytes == null ? '' : " • ${sizeInBytes.fileSizeFormatted}",
                                            onPlay: (isSelected) {
                                              if (!isSelected) {
                                                Player.inst.onItemPlayYoutubeIDSetQuality(
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
                                          final id = Player.inst.nowPlayingVideoID?.id;
                                          final cachedFile = id == null ? null : element.getCachedFile(id);
                                          final isSelected = (element.resolution == Player.inst.currentVideoStream?.resolution ||
                                              (Player.inst.currentCachedVideo != null && cachedFile?.path == Player.inst.currentCachedVideo?.path));

                                          return _getQualityChip(
                                            title: element.resolution ?? '',
                                            subtitle: sizeInBytes == null ? '' : " • ${sizeInBytes.fileSizeFormatted}",
                                            onPlay: (isSelected) {
                                              if (!isSelected) {
                                                Player.inst.onItemPlayYoutubeIDSetQuality(
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
                                  }).toList(),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                    child: NamidaBgBlur(
                                      blur: 3.0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                        ),
                                        child: Obx(
                                          () {
                                            String? qt;
                                            if (widget.isLocal) {
                                              final video = VideoController.inst.currentVideo.value;
                                              qt = video == null ? null : '${video.resolution}p${video.framerateText()}';
                                            } else {
                                              qt = Player.inst.currentVideoStream?.resolution;
                                              if (qt == null) {
                                                final c = Player.inst.currentCachedVideo;
                                                qt = c == null ? null : '${c.resolution}p${c.framerateText()}';
                                              }
                                            }

                                            final isAudio = widget.isLocal ? VideoController.inst.currentVideo.value == null : Player.inst.isAudioOnlyPlayback;

                                            return Row(
                                              children: [
                                                if (qt != null) ...[
                                                  Text(
                                                    qt,
                                                    style: context.textTheme.displaySmall?.copyWith(color: itemsColor),
                                                  ),
                                                  const SizedBox(width: 4.0),
                                                ],
                                                Icon(
                                                  isAudio ? Broken.musicnote : Broken.setting,
                                                  color: itemsColor,
                                                  size: 16.0,
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
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
            ),
            // ---- Bottom Row ----
            Padding(
              padding: horizontalControlsPadding,
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
                              ClipRRect(
                                borderRadius: borr8,
                                child: NamidaBgBlur(
                                  blur: 3.0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6.0),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.2),
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
                                            () => Text(
                                              "${Player.inst.nowPlayingPosition.milliSecondsLabel}/",
                                              style: context.textTheme.displayMedium?.copyWith(
                                                fontSize: 13.5.multipliedFontScale,
                                                color: itemsColor,
                                              ),
                                            ),
                                          ),
                                          Obx(
                                            () {
                                              int totalDurMs = Player.inst.getCurrentVideoDuration.inMilliseconds;
                                              String prefix = '';
                                              if (settings.player.displayRemainingDurInsteadOfTotal.value) {
                                                totalDurMs = totalDurMs - Player.inst.nowPlayingPosition;
                                                prefix = '-';
                                              }

                                              return Text(
                                                "$prefix${totalDurMs.milliSecondsLabel}",
                                                style: context.textTheme.displayMedium?.copyWith(
                                                  fontSize: 13.5.multipliedFontScale,
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
                                  () {
                                    final queueL = (widget.isLocal ? Player.inst.currentQueue : Player.inst.currentQueueYoutube).length;
                                    if (queueL <= 1) return const SizedBox();
                                    return ClipRRect(
                                      borderRadius: borr8,
                                      child: NamidaBgBlur(
                                        blur: 3.0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6.0),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.2),
                                            borderRadius: borr8,
                                          ),
                                          child: Obx(
                                            () => Text(
                                              "${Player.inst.currentIndex + 1}/$queueL",
                                              style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
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
                              ClipRRect(
                                borderRadius: borr8,
                                child: NamidaBgBlur(
                                  blur: 3.0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6.0),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.2),
                                      borderRadius: borr8,
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 2.0),
                                        RepeatModeIconButton(
                                          compact: true,
                                          color: itemsColor,
                                          onPressed: () {
                                            _startTimer();
                                          },
                                        ),
                                        SizedBox(width: widget.isFullScreen ? 12.0 : 10.0),
                                        EqualizerIconButton(
                                          compact: true,
                                          color: itemsColor,
                                          onPressed: () {
                                            _startTimer();
                                          },
                                        ),
                                        SizedBox(width: widget.isFullScreen ? 12.0 : 10.0),
                                        NamidaIconButton(
                                          horizontalPadding: 0.0,
                                          padding: EdgeInsets.zero,
                                          iconSize: 20.0,
                                          icon: Broken.copy,
                                          iconColor: itemsColor,
                                          onPressed: () {
                                            _startTimer();
                                            YTUtils().copyVideoUrl(Player.inst.getCurrentVideoId);
                                          },
                                        ),
                                        SizedBox(width: widget.isFullScreen ? 12.0 : 10.0),
                                        NamidaIconButton(
                                          horizontalPadding: 0.0,
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
                  Obx(
                    () {
                      final shouldShowPrev = Player.inst.currentIndex != 0;
                      return IgnorePointer(
                        ignoring: !shouldShowPrev,
                        child: Opacity(
                          opacity: shouldShowPrev ? 1.0 : 0.0,
                          child: ClipOval(
                            child: NamidaBgBlur(
                              blur: 2,
                              child: ColoredBox(
                                color: Colors.black.withOpacity(0.2),
                                child: NamidaIconButton(
                                    icon: null,
                                    horizontalPadding: 0.0,
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      Player.inst.previous();
                                      _resetTimer(hideControls: true);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Icon(
                                        Broken.previous,
                                        size: 30.0,
                                        color: itemsColor,
                                      ),
                                    )),
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
                        color: Colors.black.withOpacity(0.3),
                        child: Obx(
                          () {
                            if (_showLoadingIndicator) {
                              return Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: ThreeArchedCircle(
                                  color: itemsColor,
                                  size: 40.0,
                                ),
                              );
                            }
                            final currentPosition = Player.inst.nowPlayingPosition;
                            final currentTotalDur = Player.inst.currentItemDuration?.inMilliseconds ?? 0;
                            final reachedLastPosition = currentPosition != 0 && (currentPosition - currentTotalDur).abs() < 100; // 100ms allowance

                            return reachedLastPosition
                                ? NamidaIconButton(
                                    icon: null,
                                    horizontalPadding: 0.0,
                                    padding: EdgeInsets.zero,
                                    onPressed: () async {
                                      await Player.inst.seek(Duration.zero);
                                      await Player.inst.play();
                                      _startTimer();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Icon(
                                        Broken.refresh,
                                        size: 40.0,
                                        color: itemsColor,
                                        key: const Key('replay'),
                                      ),
                                    ),
                                  )
                                : NamidaIconButton(
                                    icon: null,
                                    horizontalPadding: 0.0,
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      Player.inst.togglePlayPause();
                                      _startTimer();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Obx(
                                        () => AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 200),
                                          child: Player.inst.isPlaying
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
                                  );
                          },
                        ),
                      ),
                    ),
                  ),
                  Obx(
                    () {
                      final shouldShowNext = Player.inst.currentIndex != Player.inst.currentQueueYoutube.length - 1;
                      return IgnorePointer(
                        ignoring: !shouldShowNext,
                        child: Opacity(
                          opacity: shouldShowNext ? 1.0 : 0.0,
                          child: ClipOval(
                            child: NamidaBgBlur(
                              blur: 2,
                              child: ColoredBox(
                                color: Colors.black.withOpacity(0.2),
                                child: NamidaIconButton(
                                    icon: null,
                                    horizontalPadding: 0.0,
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      Player.inst.next();
                                      _resetTimer(hideControls: true);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Icon(
                                        Broken.next,
                                        size: 30.0,
                                        color: itemsColor,
                                      ),
                                    )),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(),
                ],
              ),
            ),
            Obx(
              () => _showLoadingIndicator
                  ? ThreeArchedCircle(
                      color: itemsColor,
                      size: 40.0,
                    )
                  : const SizedBox(),
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
                  () {
                    final bri = _canShowBrightnessSlider.value ? _currentBrigthnessDim.value : null;
                    return _getVerticalSliderWidget(
                      'brightness',
                      bri,
                      Broken.sun_1,
                      view,
                    );
                  },
                ),
              ),
              // ======= Volume Slider ========
              Positioned(
                right: context.width * 0.15,
                child: Obx(
                  () {
                    final vol = _currentDeviceVolume.value;
                    return _getVerticalSliderWidget(
                      'volume',
                      vol,
                      Broken.volume_high,
                      view,
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
