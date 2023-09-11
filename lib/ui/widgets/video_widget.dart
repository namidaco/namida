import 'dart:async';

// ignore: implementation_imports
import 'package:better_player/src/video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class NamidaVideoControls extends StatefulWidget {
  final VideoPlayerController? controller;
  final Widget child;
  final bool showControls;
  final VoidCallback? onMinimizeTap;

  const NamidaVideoControls({
    super.key,
    required this.controller,
    required this.child,
    required this.showControls,
    required this.onMinimizeTap,
  });

  @override
  State<NamidaVideoControls> createState() => _NamidaVideoControlsState();
}

class _NamidaVideoControlsState extends State<NamidaVideoControls> {
  Widget _getSliderContainer(
    BuildContext context,
    BoxConstraints constraints,
    double percentage,
    int alpha,
  ) {
    return Container(
      height: 6.0,
      width: constraints.maxWidth * percentage,
      decoration: BoxDecoration(
        color: Color.alphaBlend(Colors.white.withAlpha(100), context.theme.colorScheme.secondary).withAlpha(alpha),
        borderRadius: BorderRadius.circular(6.0.multipliedRadius),
      ),
    );
  }

  bool _isVisible = false;
  final hideDuration = const Duration(seconds: 3);
  final transitionDuration = const Duration(milliseconds: 300);

  Timer? _hideTimer;
  void _resetTimer() {
    _hideTimer?.cancel();
  }

  void _startTimer() {
    _resetTimer();
    if (_isVisible) {
      _hideTimer = Timer(hideDuration, () {
        _isVisible = false;
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vc = widget.controller;
    if (vc == null) return widget.child;
    final itemsColor = Colors.white.withAlpha(220);
    return GestureDetector(
      onTap: () {
        if (_isVisible) {
          _isVisible = false;
        } else {
          if (widget.showControls) {
            _isVisible = true;
          }
        }
        setState(() {});
        _startTimer();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            key: const Key('alwaysVisibleChild'),
            child: widget.child,
          ),
          if (widget.showControls)
            Positioned.fill(
              key: const Key('sussyChild'),
              child: AnimatedOpacity(
                opacity: _isVisible ? 1.0 : 0.0,
                duration: transitionDuration,
                child: Container(
                  color: Colors.black.withOpacity(0.25),
                  child: Column(
                    children: [
                      const SizedBox(height: 4.0),
                      Row(
                        children: [
                          NamidaIconButton(
                            horizontalPadding: 12.0,
                            verticalPadding: 6.0,
                            onPressed: widget.onMinimizeTap,
                            icon: Broken.arrow_down_2,
                            iconColor: itemsColor,
                            iconSize: 20.0,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                          child: TweenAnimationBuilder<double>(
                              duration: transitionDuration,
                              tween: Tween<double>(begin: 0, end: 5.0),
                              builder: (context, value, _) {
                                return NamidaBgBlur(
                                  blur: value,
                                  child: Container(
                                    padding: const EdgeInsets.all(12.0),
                                    decoration: BoxDecoration(
                                      color: Colors.white30,
                                      borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                                    ),
                                    child: () {
                                      ValueNotifier<double> seek = ValueNotifier(0.0);

                                      return ValueListenableBuilder(
                                        valueListenable: vc,
                                        builder: (context, VideoPlayerValue playerController, child) {
                                          return Row(
                                            children: [
                                              NamidaIconButton(
                                                horizontalPadding: 0.0,
                                                padding: EdgeInsets.zero,
                                                iconSize: 20.0,
                                                icon: playerController.isPlaying ? Broken.pause : Broken.play,
                                                iconColor: itemsColor,
                                                onPressed: playerController.isPlaying ? Player.inst.pause : Player.inst.play,
                                              ),
                                              const SizedBox(width: 4.0),
                                              Text(
                                                playerController.position.inSeconds.secondsLabel,
                                                style: context.textTheme.displayMedium?.copyWith(
                                                  color: itemsColor,
                                                ),
                                              ),
                                              const SizedBox(width: 8.0),
                                              Expanded(
                                                child: LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    void onSeekDragUpdate(double deltax) {
                                                      final percentageSwiped = deltax / constraints.maxWidth;
                                                      final newSeek = percentageSwiped * (playerController.duration?.inMilliseconds ?? 0);
                                                      seek.value = newSeek;
                                                    }

                                                    void onSeekEnd() {
                                                      Player.inst.seek(Duration(milliseconds: seek.value.toInt()));
                                                      seek.value = 0;
                                                      _startTimer();
                                                    }

                                                    return GestureDetector(
                                                        onTapDown: (details) {
                                                          onSeekDragUpdate(details.localPosition.dx);
                                                          _resetTimer();
                                                        },
                                                        onTapUp: (details) => onSeekEnd(),
                                                        onTapCancel: () {
                                                          seek.value = 0;
                                                          _startTimer();
                                                        },
                                                        onHorizontalDragStart: (details) => _resetTimer(),
                                                        onHorizontalDragUpdate: (details) => onSeekDragUpdate(details.localPosition.dx),
                                                        onHorizontalDragEnd: (details) => onSeekEnd(),
                                                        child: ValueListenableBuilder(
                                                          valueListenable: seek,
                                                          builder: (_, double seekvaluee, child) {
                                                            final currentSeekValue = seekvaluee == 0 ? playerController.position.inMilliseconds : seekvaluee;

                                                            return Stack(
                                                              children: [
                                                                _getSliderContainer(
                                                                  context,
                                                                  constraints,
                                                                  currentSeekValue / (playerController.duration?.inMilliseconds ?? 1),
                                                                  255,
                                                                ),
                                                                // ...value.buffered.map(
                                                                //   (e) => _getSliderContainer(
                                                                //     context,
                                                                //     constraints,
                                                                //     value.position.inMilliseconds / e.start,
                                                                //     100,
                                                                //   ),
                                                                // ),
                                                                _getSliderContainer(
                                                                  context,
                                                                  constraints,
                                                                  1.0,
                                                                  60,
                                                                ),
                                                              ],
                                                            );
                                                          },
                                                        ));
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8.0),
                                              Text(
                                                playerController.duration?.inSeconds.secondsLabel ?? '00:00',
                                                style: context.textTheme.displayMedium?.copyWith(
                                                  color: itemsColor,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    }(),
                                  ),
                                );
                              }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
