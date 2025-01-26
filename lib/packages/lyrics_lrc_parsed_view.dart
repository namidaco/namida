import 'dart:async';

import 'package:flutter/material.dart';

import 'package:lrc/lrc.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/miniplayer_base.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class LyricsLRCParsedView extends StatefulWidget {
  final Lrc? initialLrc;
  final Widget videoOrImage;
  final bool isFullScreenView;

  const LyricsLRCParsedView({
    super.key,
    required this.initialLrc,
    required this.videoOrImage,
    this.isFullScreenView = false,
  });

  @override
  State<LyricsLRCParsedView> createState() => LyricsLRCParsedViewState();
}

class LyricsLRCParsedViewState extends State<LyricsLRCParsedView> {
  void enterFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return LyricsLRCParsedView(
            key: Lyrics.inst.lrcViewKeyFullscreen,
            initialLrc: currentLRC,
            videoOrImage: const SizedBox(),
            isFullScreenView: true,
          );
        },
      ),
    );
  }

  late final ItemScrollController controller;
  late final ItemPositionsListener positionListener;

  late final double _paddingVertical = widget.isFullScreenView ? 32 * 12.0 : 12 * 12.0;
  int _currentIndex = -1;
  String _currentLine = '';

  static const int _lrcOpacityDurationMS = 500;
  late final bool _updateOpacityForEmptyLines = !widget.isFullScreenView;
  late bool _isCurrentLineEmpty = _updateOpacityForEmptyLines ? _checkIfTextEmpty(lyrics.firstOrNull?.lyrics ?? '') : false;

  final _emptyTextRegex = RegExp(r'[^\s]');
  bool _checkIfTextEmpty(String text) {
    final hasAnyChar = _emptyTextRegex.hasMatch(text);
    return !hasAnyChar;
  }

  @override
  void initState() {
    super.initState();
    controller = ItemScrollController();
    positionListener = ItemPositionsListener.create();
    fillLists(widget.initialLrc);
    Player.inst.currentItemDuration.addListener(_itemDurationUpdater);
    Player.inst.nowPlayingPosition.addListener(_playerPositionListener);
  }

  int _itemDurationUpdater() {
    int totalDurMS = Player.inst.currentItemDuration.value?.inMilliseconds ?? 0;
    if (totalDurMS == 0) {
      final current = Player.inst.currentItem.value;
      if (current is Selectable) {
        totalDurMS = current.track.durationMS;
      }
    }
    _currentItemDurationMS.value = totalDurMS;
    return totalDurMS;
  }

  Lrc? currentLRC;

  final _currentItemDurationMS = RxnO<int>();

  void clearLists() {
    highlightTimestampsMap.clear();
    lyrics.clear();
  }

  void fillLists(Lrc? lrc) {
    currentLRC = lrc;

    if (lrc == null) {
      highlightTimestampsMap.clear();
      lyrics.clear();
      if (_isCurrentLineEmpty && !_checkIfTextEmpty(Lyrics.inst.currentLyricsText.value)) {
        refreshState(() => _isCurrentLineEmpty = false);
      }
      return;
    }
    // -- calculating timestamps multiplier, useful for spedup/nightcore
    final llength = lrc.length ?? '';
    double cal = 0;
    if (llength != '') {
      final parts = llength.split(RegExp(r'[:.]'));
      try {
        String? hundreds;
        if (parts.length >= 3) {
          // -- converting whatever here to 6-digit microseconds
          hundreds = parts[2];
          var zerosToAdd = 6 - hundreds.length;
          while (zerosToAdd > 0) {
            hundreds = '${hundreds!}0';
            zerosToAdd--;
          }
        }

        final lyricsDuration = Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
          microseconds: hundreds == null ? 0 : int.tryParse(hundreds) ?? 0,
        );
        final totalDurMS = _itemDurationUpdater();
        final totalDurMicro = totalDurMS * 1000;
        cal = totalDurMicro / lyricsDuration.inMicroseconds;
      } catch (_) {}
    }

    highlightTimestampsMap.clear();
    lyrics.clear();

    lrc.lyrics.loopAdv(
      (item, index) {
        final lineTimeStamp = item.timestamp - Duration(milliseconds: lrc.offset ?? 0);
        final calculatedForSpedUpVersions = cal == 0 ? lineTimeStamp : (lineTimeStamp * cal);
        final newLrcLine = LrcLine(
          timestamp: calculatedForSpedUpVersions,
          lyrics: item.lyrics,
          type: item.type,
          args: item.args,
        );
        highlightTimestampsMap[calculatedForSpedUpVersions] ??= index;
        lyrics.add(newLrcLine);
      },
    );

    _updateHighlightedLine(Player.inst.nowPlayingPosition.value, jump: true);
  }

  void _playerPositionListener() {
    final position = Player.inst.nowPlayingPosition.value;
    _updateHighlightedLine(position);
  }

  void _updateHighlightedLine(int durMS, {bool forceAnimate = false, bool jump = false}) {
    final lrcDur = lyrics.lastWhereEff((e) => e.timestamp.inMilliseconds <= durMS);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _latestUpdatedLine.value = lrcDur?.timestamp;

      int newIndex = highlightTimestampsMap[_latestUpdatedLine.value] ?? -1;
      _latestUpdatedLineIndex.value = newIndex;
      if (newIndex + 1 == lyrics.length) {
        final alreadyHighlightingLastLine = _currentIndex == newIndex;
        if (alreadyHighlightingLastLine) {
          return; // overscrolling
        } else {
          newIndex = lyrics.length - 1; // go to last line
        }
      }

      if ((_canAnimateScroll || forceAnimate) && controller.isAttached) {
        if (newIndex < 0) newIndex = 0;
        if (_currentIndex == newIndex) return;
        _currentIndex = newIndex;
        jump
            ? controller.jumpTo(
                alignment: 0.4,
                index: newIndex,
              )
            : controller.scrollTo(
                alignment: 0.4,
                index: newIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
        try {
          _currentLine = lyrics[newIndex].lyrics;
        } catch (_) {
          _currentLine = '';
        }
        if (_updateOpacityForEmptyLines) {
          final line = _currentLine;
          final emptyLine = _checkIfTextEmpty(_currentLine);
          if (emptyLine || _isCurrentLineEmpty) {
            final timeToWaitMS = _isCurrentLineEmpty ? 200 : 1200; // execute faster if current one empty (ie: cuz next most likely not empty)
            bool butIsItWorth = true;
            try {
              final diff = lyrics[newIndex].timestamp - lyrics[newIndex - 1].timestamp; // (newIndex - 1) is the empty line
              if (diff.abs() < const Duration(milliseconds: _lrcOpacityDurationMS * 2 + 200 + 1200)) butIsItWorth = false;
            } catch (_) {}
            if (butIsItWorth) {
              Timer(Duration(milliseconds: timeToWaitMS), () {
                if (line == _currentLine) {
                  refreshState(() => _isCurrentLineEmpty = emptyLine);
                }
              });
            }
          }
        }
      }
    });
  }

  Timer? _scrollTimer;
  bool _canAnimateScroll = true;

  final _latestUpdatedLineIndex = (-1).obs;
  final _latestUpdatedLine = Rxn<Duration>();

  var lyrics = <LrcLine>[];
  final highlightTimestampsMap = <Duration, int>{}; // timestamp: index

  late double _previousFontMultiplier = widget.isFullScreenView ? settings.fontScaleLRCFull : settings.fontScaleLRC;
  late double _fontMultiplier = widget.isFullScreenView ? settings.fontScaleLRCFull : settings.fontScaleLRC;

  @override
  void dispose() {
    Player.inst.currentItemDuration.removeListener(_itemDurationUpdater);
    Player.inst.nowPlayingPosition.removeListener(_playerPositionListener);
    _latestUpdatedLineIndex.close();
    _latestUpdatedLine.close();
    _currentItemDurationMS.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fullscreen = widget.isFullScreenView;
    final initialFontSize = fullscreen ? 25.0 : 15.0;
    final normalTextStyle = context.textTheme.displayMedium!.copyWith(fontSize: _fontMultiplier * initialFontSize);

    final bottomControlsChildren = fullscreen
        ? [
            const WaveformMiniplayer(fixPadding: true),
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                NamidaHero(
                  enabled: false,
                  tag: 'MINIPLAYER_POSITION',
                  child: ObxO(
                    rx: Player.inst.nowPlayingPosition,
                    builder: (context, currentMS) => Text(
                      currentMS.milliSecondsLabel,
                      style: context.textTheme.displaySmall,
                    ),
                  ),
                ),
                const Spacer(),
                NamidaIconButton(
                  icon: Broken.previous,
                  iconSize: 24.0,
                  onPressed: Player.inst.previous,
                ),
                ObxO(
                  rx: Player.inst.isPlaying,
                  builder: (context, isPlaying) => NamidaIconButton(
                    horizontalPadding: 18.0,
                    icon: isPlaying ? Broken.pause : Broken.play,
                    iconSize: 32.0,
                    onPressed: Player.inst.togglePlayPause,
                  ),
                ),
                NamidaIconButton(
                  icon: Broken.next,
                  iconSize: 24.0,
                  onPressed: Player.inst.next,
                ),
                const Spacer(),
                NamidaHero(
                  enabled: false,
                  tag: 'MINIPLAYER_DURATION',
                  child: ObxO(
                      rx: settings.player.displayRemainingDurInsteadOfTotal,
                      builder: (context, displayRemainingDurInsteadOfTotal) => displayRemainingDurInsteadOfTotal
                          ? ObxO(
                              rx: _currentItemDurationMS,
                              builder: (context, durMS) {
                                int finalDurMS = durMS ?? 0;

                                return ObxO(
                                  rx: Player.inst.currentItem,
                                  builder: (context, currentItem) {
                                    if (finalDurMS == 0 && currentItem is Selectable) {
                                      finalDurMS = currentItem.track.durationMS;
                                    }
                                    return ObxO(
                                      rx: Player.inst.nowPlayingPosition,
                                      builder: (context, toSubtract) {
                                        final msToDisplay = finalDurMS - toSubtract;
                                        return Text(
                                          "- ${msToDisplay.milliSecondsLabel}",
                                          style: context.textTheme.displaySmall,
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            )
                          : ObxO(
                              rx: _currentItemDurationMS,
                              builder: (context, milliseconds) {
                                if (milliseconds == null || milliseconds == 0) {
                                  return ObxO(
                                    rx: Player.inst.currentItem,
                                    builder: (context, currentItem) {
                                      final milliseconds = currentItem is Selectable ? currentItem.track.durationMS : 0;
                                      return Text(
                                        milliseconds.milliSecondsLabel,
                                        style: context.textTheme.displaySmall,
                                      );
                                    },
                                  );
                                }
                                return Text(
                                  milliseconds.milliSecondsLabel,
                                  style: context.textTheme.displaySmall,
                                );
                              },
                            )),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12.0),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ]
        : [];
    return Stack(
      alignment: Alignment.center,
      children: [
        fullscreen
            ? Positioned.fill(
                child: Obx(
                  (context) => Container(
                    color: Color.alphaBlend(
                      CurrentColor.inst.miniplayerColor.withValues(alpha: 0.2),
                      context.isDarkMode ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              )
            : widget.videoOrImage,
        AnimatedOpacity(
          duration: const Duration(milliseconds: _lrcOpacityDurationMS),
          opacity: _isCurrentLineEmpty ? 0.0 : 1.0,
          child: BorderRadiusClip(
            clipBehavior: Clip.hardEdge, // VIP to eliminate thin border effect
            borderRadius: fullscreen ? BorderRadius.zero : BorderRadius.circular(16.0.multipliedRadius),
            child: NamidaBgBlur(
              blur: fullscreen ? 0.0 : 12.0,
              enabled: !fullscreen,
              child: Container(
                color: context.theme.scaffoldBackgroundColor.withValues(alpha: fullscreen ? 0.8 : 0.6),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Listener(
                            onPointerDown: (event) {
                              _scrollTimer?.cancel();
                              _scrollTimer = null;
                              _canAnimateScroll = false;
                              if (_isCurrentLineEmpty) {
                                refreshState(() => _isCurrentLineEmpty = false);
                              }
                            },
                            onPointerUp: (event) {
                              _scrollTimer = Timer(const Duration(seconds: 3), () {
                                _canAnimateScroll = true;
                                if (Player.inst.isPlaying.value) {
                                  _updateHighlightedLine(Player.inst.nowPlayingPosition.value, forceAnimate: true);
                                }
                                if (_updateOpacityForEmptyLines && currentLRC != null && _checkIfTextEmpty(_currentLine)) {
                                  refreshState(() => _isCurrentLineEmpty = true);
                                }
                              });
                            },
                            child: ShaderFadingWidget(
                              biggerValues: fullscreen,
                              child: Builder(
                                builder: (context) {
                                  return Obx(
                                    (context) {
                                      final lrc = Lyrics.inst.currentLyricsLRC.valueR;
                                      if (lrc == null) {
                                        final text = Lyrics.inst.currentLyricsText.valueR;
                                        if (!_checkIfTextEmpty(text)) {
                                          return SingleChildScrollView(
                                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                            controller: Lyrics.inst.textScrollController,
                                            child: Column(
                                              children: [
                                                SizedBox(height: _paddingVertical),
                                                Text(
                                                  text,
                                                  style: normalTextStyle,
                                                ),
                                                SizedBox(height: _paddingVertical),
                                              ],
                                            ),
                                          );
                                        }
                                        return const SizedBox();
                                      }

                                      final color = CurrentColor.inst.miniplayerColor;
                                      return ObxO(
                                        rx: _latestUpdatedLine,
                                        builder: (context, highlightedTimeStamp) => ScrollablePositionedList.builder(
                                          padding: EdgeInsets.symmetric(vertical: _paddingVertical),
                                          itemScrollController: controller,
                                          itemCount: lyrics.length,
                                          itemBuilder: (context, index) {
                                            final lrc = lyrics[index];
                                            final text = lrc.lyrics;
                                            final selected = highlightedTimeStamp == lrc.timestamp;
                                            final selectedAndEmpty = selected && _checkIfTextEmpty(text);
                                            final bgColor = selected
                                                ? Color.alphaBlend(color.withAlpha(140), context.theme.scaffoldBackgroundColor).withValues(alpha: selectedAndEmpty ? 0.1 : 0.5)
                                                : null;
                                            final padding = selected ? 2.0 : 0.0;

                                            return Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Positioned.fill(
                                                  child: Material(
                                                    type: MaterialType.transparency,
                                                    child: InkWell(
                                                      splashFactory: InkSparkle.splashFactory,
                                                      onTap: () {
                                                        Player.inst.seek(lrc.timestamp);
                                                        _updateHighlightedLine(lrc.timestamp.inMilliseconds, forceAnimate: true);
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                IgnorePointer(
                                                  child: NamidaHero(
                                                    tag: 'LYRICS_LINE_${lrc.timestamp}',
                                                    enabled: false,
                                                    child: AnimatedScale(
                                                      duration: const Duration(milliseconds: 400),
                                                      curve: Curves.easeInOutCubicEmphasized,
                                                      scale: selected ? 1.0 : 0.95,
                                                      child: NamidaInkWell(
                                                        bgColor: bgColor,
                                                        borderRadius: selectedAndEmpty ? 5.0 : 8.0,
                                                        animationDurationMS: 300,
                                                        margin: EdgeInsets.symmetric(vertical: padding, horizontal: 4.0),
                                                        padding: selectedAndEmpty
                                                            ? const EdgeInsets.symmetric(vertical: 3.0, horizontal: 24.0)
                                                            : const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                                                        child: Text(
                                                          text,
                                                          style: normalTextStyle.copyWith(
                                                            color: selected
                                                                ? Colors.white.withValues(alpha: 0.7)
                                                                : normalTextStyle.color?.withValues(alpha: 0.5) ?? Colors.transparent,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8.0,
                            right: 0.0,
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              padding: const EdgeInsets.all(4.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 8.0,
                                    color: context.theme.scaffoldBackgroundColor.withValues(alpha: 0.7),
                                  ),
                                ],
                              ),
                              child: NamidaIconButton(
                                icon: Broken.maximize_3,
                                iconSize: 20.0,
                                onPressed: () {
                                  if (fullscreen) {
                                    Navigator.of(context).pop();
                                  } else {
                                    enterFullScreen();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...bottomControlsChildren,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ScaleDetector(
            onScaleStart: (details) => _previousFontMultiplier = _fontMultiplier,
            onScaleUpdate: (details) => refreshState(() => _fontMultiplier = (details.scale * _previousFontMultiplier).clamp(0.5, 2.0)),
            onScaleEnd: (details) => widget.isFullScreenView ? settings.save(fontScaleLRCFull: _fontMultiplier) : settings.save(fontScaleLRC: _fontMultiplier),
          ),
        ),
      ],
    );
  }
}
