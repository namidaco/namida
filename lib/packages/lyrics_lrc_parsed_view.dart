import 'dart:async';

import 'package:flutter/material.dart';

import 'package:lrc/lrc.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/miniplayer.dart';
import 'package:namida/packages/miniplayer_base.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';

class LyricsLRCParsedView extends StatefulWidget {
  final Widget videoOrImage;
  final bool isFullScreenView;
  final bool canShowToggleFullscreenButton;
  final void Function()? onCloseFullscreenButtonTap;
  final bool allowOverflow;
  final bool useSafeArea;
  final double? maxHeight;
  final double? verticalPadding;
  final Widget? bottomPadding;

  const LyricsLRCParsedView({
    super.key,
    required this.videoOrImage,
    this.isFullScreenView = false,
    this.canShowToggleFullscreenButton = false,
    this.onCloseFullscreenButtonTap,
    this.allowOverflow = true,
    this.useSafeArea = true,
    this.maxHeight,
    this.verticalPadding,
    this.bottomPadding,
  });

  @override
  State<LyricsLRCParsedView> createState() => LyricsLRCParsedViewState();
}

class LyricsLRCParsedViewState extends State<LyricsLRCParsedView> {
  void toggleFullscreen() {
    if (widget.isFullScreenView) {
      exitFullScreen();
    } else {
      enterFullScreen();
    }
  }

  void enterFullScreen() {
    NamidaNavigator.inst.navigateToRoot(
      LyricsLRCParsedView(
        key: Lyrics.inst.lrcViewKeyFullscreen,
        videoOrImage: const SizedBox(),
        isFullScreenView: true,
      ),
      transition: Transition.native,
    );
  }

  void exitFullScreen() {
    NamidaNavigator.inst.popRoot();
  }

  late final ListController _listController;
  late final ScrollController _scrollController;

  late final double _paddingVertical = widget.verticalPadding ?? (widget.isFullScreenView ? 32 * 12.0 : 12 * 12.0);
  int? _currentIndex;
  String _currentLine = '';

  static const int _lrcOpacityDurationMS = 500;
  late final bool _updateOpacityForEmptyLines = !widget.isFullScreenView;
  bool _isCurrentLineEmpty = true;

  void _updateIsCurrentLineEmpty(bool empty) {
    if (_isCurrentLineEmpty == empty) return;
    refreshState(() => _isCurrentLineEmpty = empty);
  }

  final _emptyTextRegex = RegExp(r'[^\s]');
  bool _checkIfTextEmpty(String text) {
    final hasAnyChar = _emptyTextRegex.hasMatch(text);
    return !hasAnyChar;
  }

  @override
  void initState() {
    super.initState();
    _listController = ListController();
    _scrollController = NamidaScrollController.create();
    final lrc = Lyrics.inst.currentLyricsLRC.value;
    final txt = Lyrics.inst.currentLyricsText.value;
    fillLists(lrc, txt);
    Player.inst.currentItemDuration.addListener(_itemDurationUpdater);
    Player.inst.nowPlayingPosition.addListener(_playerPositionListener);
  }

  int _itemDurationUpdater() {
    int totalDurMS = Player.inst.currentItemDuration.value?.inMilliseconds ?? 0;
    if (totalDurMS == 0) {
      final current = Player.inst.currentItem.value;
      if (current is Selectable) {
        totalDurMS = current.track.durationMS;
      } else if (current is YoutubeID) {
        totalDurMS = Player.inst.getCurrentVideoDuration.inMilliseconds;
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
    if (!_isCurrentLineEmpty) {
      _updateIsCurrentLineEmpty(true);
    }
    _latestUpdatedLineInfo.value = null;
    _currentIndex = null;
  }

  void fillLists(Lrc? lrc, String? txt) {
    currentLRC = lrc;
    if (lrc == null) {
      highlightTimestampsMap.clear();
      lyrics.clear();
      final isTextEmpty = txt == null ? true : _checkIfTextEmpty(txt);
      _updateIsCurrentLineEmpty(isTextEmpty);
      return;
    } else {
      _updateIsCurrentLineEmpty(_updateOpacityForEmptyLines ? _checkIfTextEmpty(lrc.lyrics.firstOrNull?.lyrics ?? '') : false);
    }
    // -- calculating timestamps multiplier, useful for spedup/slowed/nightcore
    final llength = lrc.length ?? '';
    double cal = 0;
    if (settings.stretchLyricsDuration.value) {
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
    }

    highlightTimestampsMap.clear();
    lyrics.clear();

    final uiInfo = lrc.forUiDisplay(
      cal,
      durationDifferenceToInsertEmptyLine: const Duration(seconds: 1),
      romanize: false,
    );

    lyrics = uiInfo.uiLyricsLines;
    highlightTimestampsMap = uiInfo.highlightTimestampsMap;

    _updateHighlightedLine(Player.inst.nowPlayingPosition.value, jump: true);
  }

  void _playerPositionListener() {
    final position = Player.inst.nowPlayingPosition.value;
    _updateHighlightedLine(position);
  }

  void _updateHighlightedLine(int durMS, {bool force = false, bool forceAnimate = false, bool jump = false}) {
    final lrcDur = lyrics.lastWhereEff((e) => e.timestamp.inMilliseconds <= durMS + 5 && !e.isBGLyrics);
    if (!force && _latestUpdatedLineInfo.value?.$1 == lrcDur?.timestamp) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newLineDuration = lrcDur?.timestamp;
      int? newIndex = newLineDuration == null ? null : highlightTimestampsMap[newLineDuration];
      _latestUpdatedLineInfo.value = (lrcDur?.timestamp, newIndex);
      if (newIndex == null) return;
      if (newIndex + 1 == lyrics.length) {
        final alreadyHighlightingLastLine = _currentIndex == newIndex;
        if (alreadyHighlightingLastLine) {
          return; // overscrolling
        } else {
          newIndex = lyrics.length - 1; // go to last line
        }
      }

      if ((_canAnimateScroll || forceAnimate) && _listController.isAttached) {
        if (newIndex < 0) newIndex = 0;
        if (!force && _currentIndex == newIndex) return;
        _currentIndex = newIndex;
        jump
            ? _listController.jumpToItem(
                scrollController: _scrollController,
                alignment: 0.4,
                index: newIndex,
              )
            : _listController.animateToItem(
                scrollController: _scrollController,
                alignment: 0.4,
                index: newIndex,
                duration: (d) => const Duration(milliseconds: 300),
                curve: (d) => Curves.easeOut,
              );
        try {
          _currentLine = lyrics[newIndex].lyrics;
        } catch (_) {
          _currentLine = '';
        }
        if (_updateOpacityForEmptyLines) {
          final line = _currentLine;
          late final emptyLine = _checkIfTextEmpty(_currentLine);
          if (_isCurrentLineEmpty && !emptyLine) {
            _updateIsCurrentLineEmpty(emptyLine);
          } else {
            if (_isCurrentLineEmpty || emptyLine) {
              final timeToWaitMS = _isCurrentLineEmpty ? 200 : 1200; // execute faster if current one empty (ie: cuz next most likely not empty)
              bool butIsItWorth = true;
              if (newIndex < lyrics.length - 1) {
                try {
                  final diff = lyrics[newIndex + 1].timestamp - lyrics[newIndex].timestamp; // (newIndex) is the empty line
                  if (diff.abs() < const Duration(milliseconds: _lrcOpacityDurationMS * 2 + 1200)) butIsItWorth = false;
                } catch (_) {}
              } else {
                butIsItWorth = true; // last line has nothing next so its always worth ^^
              }

              if (butIsItWorth) {
                Timer(Duration(milliseconds: timeToWaitMS), () {
                  if (line == _currentLine && _isCurrentLineEmpty != emptyLine) {
                    _updateIsCurrentLineEmpty(emptyLine);
                  }
                });
              }
            }
          }
        }
      }
    });
  }

  Timer? _scrollTimer;
  bool _canAnimateScroll = true;

  final _latestUpdatedLineInfo = Rxn<(Duration?, int?)>();

  var lyrics = <LrcLine>[];
  var highlightTimestampsMap = <Duration, int>{}; // timestamp: index

  late double _previousFontMultiplier = widget.isFullScreenView ? settings.fontScaleLRCFull : settings.fontScaleLRC;
  late double _fontMultiplier = widget.isFullScreenView ? settings.fontScaleLRCFull : settings.fontScaleLRC;

  @override
  void dispose() {
    Player.inst.currentItemDuration.removeListener(_itemDurationUpdater);
    Player.inst.nowPlayingPosition.removeListener(_playerPositionListener);

    _latestUpdatedLineInfo.close();
    _currentItemDurationMS.close();
    _listController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onPointerDown(dynamic _) {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _canAnimateScroll = false;
    if (_isCurrentLineEmpty) {
      _updateIsCurrentLineEmpty(false);
    }
  }

  void _onPointerUp(dynamic _) {
    _scrollTimer = Timer(const Duration(seconds: 3), () {
      _canAnimateScroll = true;
      if (Player.inst.playWhenReady.value) {
        _updateHighlightedLine(Player.inst.nowPlayingPosition.value, forceAnimate: true, force: true);
      }
      if (_updateOpacityForEmptyLines && currentLRC != null && _checkIfTextEmpty(_currentLine)) {
        _updateIsCurrentLineEmpty(true);
      }
    });
  }

  // -- mouse scroll
  void _onPointerSignal(dynamic _) {
    _onPointerDown(null);
    _onPointerUp(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final fullscreen = widget.isFullScreenView;
    final initialFontSize = fullscreen ? 25.0 : 15.0;
    final normalTextStyle = textTheme.displayMedium!.copyWith(fontSize: _fontMultiplier * initialFontSize);
    final plainLyricsTextStyle = normalTextStyle.copyWith(height: 1.8);
    final fullscreenIconButton = fullscreen && widget.canShowToggleFullscreenButton
        ? Container(
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  blurRadius: 8.0,
                  color: theme.scaffoldBackgroundColor.withOpacityExt(0.7),
                ),
              ],
            ),
            child: NamidaIconButton(
              icon: Broken.maximize_3,
              iconSize: 24.0,
              onPressed: toggleFullscreen,
            ),
          )
        : null;

    final topInfoWidget = fullscreen
        ? ObxO(
            rx: Player.inst.currentItem,
            builder: (context, item) {
              final textData = item is Selectable
                  ? NamidaMiniPlayerTrack.textBuilder(item)
                  : item is YoutubeID
                  ? NamidaMiniPlayerYoutubeIDState.textBuilder(context, item)
                  : null;
              return ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: context.width, // vip
                  minHeight: 36.0, // eyeballed to match when textData is valid
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: TapDetector(
                    onTap: null,
                    initializer: (instance) {
                      void fn(TapUpDetails d) {
                        if (item is Selectable) {
                          NamidaMiniPlayerTrack.openMenu(item.trackWithDate, item.track);
                        } else if (item is YoutubeID) {
                          NamidaMiniPlayerYoutubeIDState.openMenu(context, item, d);
                        }
                      }

                      instance
                        ..onTapUp = fn
                        ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
                    },
                    child: Stack(
                      alignment: AlignmentGeometry.center,
                      children: [
                        Positioned(
                          left: 10.0,
                          bottom: 0,
                          top: 0,
                          child: NamidaIconButton(
                            tooltip: () => lang.EXIT,
                            icon: Broken.arrow_left_2,
                            iconColor: context.theme.colorScheme.secondary.withOpacityExt(0.6),
                            iconSize: 22.0,
                            onPressed: widget.onCloseFullscreenButtonTap ?? toggleFullscreen,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsGeometry.symmetric(horizontal: 48.0),
                          child: textData == null
                              ? Text(
                                  lang.LYRICS,
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: textTheme.displayLarge,
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (textData.firstLineGood)
                                      Text(
                                        textData.firstLine,
                                        maxLines: textData.secondLine == '' ? 2 : 1,
                                        overflow: TextOverflow.fade,
                                        softWrap: textData.secondLine.isEmpty,
                                        style: textTheme.displayMedium?.copyWith(
                                          fontSize: 17.0,
                                        ),
                                      ),
                                    if (textData.firstLineGood && textData.secondLineGood) const SizedBox(height: 4.0),
                                    if (textData.secondLineGood)
                                      Text(
                                        textData.secondLine,
                                        softWrap: false,
                                        overflow: TextOverflow.fade,
                                        style: textTheme.displayMedium?.copyWith(
                                          fontSize: 15.0,
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        Positioned(
                          right: 10.0,
                          bottom: 0,
                          top: 0,
                          child: NamidaIconButton(
                            tooltip: () => lang.JUMP,
                            icon: Broken.cd,
                            iconColor: context.theme.colorScheme.secondary.withOpacityExt(0.6),
                            iconSize: 20.0,
                            onPressed: () {
                              _updateHighlightedLine(Player.inst.nowPlayingPosition.value, forceAnimate: true, force: true);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        : null;
    final bottomControlsChildren = fullscreen
        ? [
            const WaveformMiniplayer(fixPadding: true),
            const SizedBox(height: 12.0),
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
                      style: textTheme.displaySmall,
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
                  rx: Player.inst.playWhenReady,
                  builder: (context, playWhenReady) => NamidaIconButton(
                    horizontalPadding: 18.0,
                    icon: playWhenReady ? Broken.pause : Broken.play,
                    iconSize: 34.0,
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
                                        style: textTheme.displaySmall,
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
                                      style: textTheme.displaySmall,
                                    );
                                  },
                                );
                              }
                              return Text(
                                milliseconds.milliSecondsLabel,
                                style: textTheme.displaySmall,
                              );
                            },
                          ),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 24.0),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ]
        : null;

    final pagePaddingHorizontal = fullscreen ? 0.0 : 24.0;
    late final mpAnimation = NamidaMiniPlayerBase.clampedAnimationBCP;

    final videoOrImageChild = fullscreen
        ? Positioned.fill(
            child: Obx(
              (context) => ColoredBox(
                color: Color.alphaBlend(
                  // -- careful with making the result non-opaque, it will cause the foreground to dim as well (no idea how :/)
                  CurrentColor.inst.miniplayerColor.withOpacityExt(0.2),
                  context.isDarkMode ? Colors.black.withOpacityExt(0.9) : Colors.white.withOpacityExt(0.9),
                ).withOpacityExt(1.0),
                child: widget.videoOrImage,
              ),
            ),
          )
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: _lrcOpacityDurationMS),
            child: _isCurrentLineEmpty
                ? KeyedSubtree(
                    key: const ValueKey('lyrics_no_builder'),
                    child: widget.videoOrImage,
                  )
                : KeyedSubtree(
                    key: const ValueKey('lyrics_builder'),
                    child: AnimatedBuilder(
                      animation: mpAnimation,
                      builder: (context, child) {
                        final mpAnimationValue = mpAnimation.value;
                        final blur = 12.0 * mpAnimationValue;
                        late final maskColor = mpAnimationValue == 0
                            ? Colors.transparent
                            : theme.scaffoldBackgroundColor.withOpacityExt((fullscreen ? 0.8 : 0.5) * mpAnimationValue);
                        return Stack(
                          children: [
                            NamidaBlur(
                              blur: blur,
                              fixArtifacts: true,
                              child: Stack(
                                children: [
                                  widget.videoOrImage,
                                  Positioned.fill(
                                    child:
                                        !_isCurrentLineEmpty &&
                                            mpAnimationValue ==
                                                1 // animate color only when not animating mp itself
                                        ? AnimatedColoredBox(
                                            duration: const Duration(milliseconds: _lrcOpacityDurationMS),
                                            color: maskColor,
                                          )
                                        : ColoredBox(
                                            color: maskColor,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          );

    final middleLyricsStackWidget = Stack(
      fit: StackFit.loose,
      children: [
        Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerUp,
          onPointerSignal: _onPointerSignal,
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
                        return Align(
                          // -- Align vip to center widget
                          child: SmoothSingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            controller: Lyrics.inst.textScrollController,
                            child: Column(
                              children: [
                                SizedBox(height: _paddingVertical),
                                Text(
                                  text,
                                  style: plainLyricsTextStyle,
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: _paddingVertical),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    }

                    final color = CurrentColor.inst.miniplayerColor;
                    final personCount = currentLRC?.personCount ?? 1;
                    return ObxO(
                      rx: _latestUpdatedLineInfo,
                      builder: (context, selectedInfo) {
                        final selectedIndex = selectedInfo?.$2;
                        final selectedLineTimestamp = selectedInfo?.$1;
                        return SuperSmoothListView.builder(
                          padding: EdgeInsets.symmetric(vertical: _paddingVertical),
                          controller: _scrollController,
                          listController: _listController,
                          itemCount: lyrics.length,
                          itemBuilder: (context, index) {
                            final distanceDiffFromSelected = selectedIndex == null ? null : index - selectedIndex; // -- does not account for empty lines
                            final distanceDiffFromSelectedAbs = distanceDiffFromSelected?.abs();
                            final lrc = lyrics[index];
                            String text = lrc.readableText;
                            final person = lrc.person;
                            final isBGLyrics = lrc.isBGLyrics;

                            final selected = distanceDiffFromSelected == 0 || isBGLyrics || selectedLineTimestamp == lrc.timestamp;
                            final selectedAndEmpty = selected && _checkIfTextEmpty(text);
                            final bgColor = selected && !isBGLyrics
                                ? Color.alphaBlend(color.withAlpha(140), theme.scaffoldBackgroundColor).withOpacityExt(selectedAndEmpty ? 0.1 : 0.5)
                                : null;
                            final vMargin = (selected ? 2.0 : 0.0) + (fullscreen ? 2.0 : 0.0);

                            EdgeInsetsGeometry padding = selectedAndEmpty
                                ? const EdgeInsets.symmetric(
                                    vertical: 3.0,
                                    horizontal: 24.0,
                                  )
                                : const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 8.0,
                                  );

                            TextAlign textAlign = TextAlign.center;
                            AlignmentDirectional alignment = AlignmentDirectional.center;
                            double normalLineColorOpacity = 0.5;
                            (double, FontWeight)? fontModifier;
                            TextStyle textStyle;

                            if (person != null && personCount > 0) {
                              if (personCount == 1) {
                                // -- keep defaults
                              } else if (person == 0) {
                                // -- bg
                                fontModifier = (0.75, FontWeight.w400);
                              } else if (person == 1) {
                                // -- v1
                                textAlign = TextAlign.start;
                                alignment = AlignmentDirectional.centerStart;
                                padding = padding.add(EdgeInsetsDirectional.only(start: 12.0, end: 64.0));
                              } else if (person == 2) {
                                // -- v2
                                textAlign = TextAlign.end;
                                alignment = AlignmentDirectional.centerEnd;
                                padding = padding.add(EdgeInsetsDirectional.only(start: 64.0, end: 12.0));
                              } else if (person == 3) {
                                // -- v3
                                textAlign = TextAlign.center;
                                alignment = AlignmentDirectional.center;
                              }
                              if (selected) {
                                textStyle = normalTextStyle.copyWith(
                                  color: Colors.white.withOpacityExt(0.75),
                                );
                              } else if (distanceDiffFromSelected != null && distanceDiffFromSelected <= 0) {
                                // -- lines before current in word synced lyrics
                                textStyle = normalTextStyle.copyWith(
                                  color: normalTextStyle.color?.withOpacityExt(normalLineColorOpacity) ?? Colors.transparent,
                                );
                              } else {
                                // -- lines after current in word synced lyrics
                                normalLineColorOpacity = 0.2;
                                textStyle = normalTextStyle.copyWith(
                                  color: normalTextStyle.color?.withOpacityExt(normalLineColorOpacity) ?? Colors.transparent,
                                );
                              }
                            } else {
                              // -- lines in normal synced lyrics
                              if (distanceDiffFromSelected != null) {
                                normalLineColorOpacity = distanceDiffFromSelectedAbs == 1
                                    ? 0.5
                                    : distanceDiffFromSelectedAbs == 2
                                    ? 0.4
                                    : 0.25;
                              }

                              if (selected) {
                                textStyle = normalTextStyle;
                              } else {
                                textStyle = normalTextStyle.copyWith(
                                  color: normalTextStyle.color?.withOpacityExt(normalLineColorOpacity) ?? Colors.transparent,
                                );
                              }
                            }
                            if (fontModifier != null) {
                              final size = fontModifier.$1;
                              final weigth = fontModifier.$2;
                              textStyle = textStyle.copyWith(
                                fontSize: size == 1.0 ? null : textStyle.fontSize! * size,
                                fontWeight: weigth,
                              );
                            }

                            final parts = lrc.parts;
                            final textWidget = selected && parts != null && parts.isNotEmpty
                                ? _TextWithFadingProgress(
                                    parts: parts,
                                    textStyle: textStyle,
                                    textAlign: textAlign,
                                  )
                                : Text(
                                    text,
                                    style: textStyle,
                                    textAlign: textAlign,
                                    // softWrap: false, // keep the text steady while animating mp
                                  );

                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: InkWell(
                                      splashFactory: InkSparkle.splashFactory,
                                      onTap: () {
                                        _canAnimateScroll = true;
                                        Player.inst.seek(lrc.timestamp); //  should auto scroll bcz position changes
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
                                        alignment: alignment,
                                        bgColor: bgColor,
                                        borderRadius: selectedAndEmpty ? 5.0 : 8.0,
                                        animationDurationMS: 300,
                                        margin: EdgeInsets.symmetric(vertical: vMargin, horizontal: 4.0),
                                        padding: padding,
                                        child: textWidget,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );

    Widget mainLyricsWidget = Column(
      children: [
        if (topInfoWidget != null) ...[
          const SizedBox(height: 12.0),
          topInfoWidget,
        ],
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: widget.maxHeight != null ? widget.maxHeight! * 0.95 : double.infinity,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: _lrcOpacityDurationMS),
                    opacity: _isCurrentLineEmpty ? 0.0 : 1.0,
                    child: FadeIgnoreTransition(
                      opacity: mpAnimation,
                      child: fullscreen || !widget.allowOverflow
                          ? Padding(
                              padding: EdgeInsets.symmetric(horizontal: pagePaddingHorizontal),
                              child: middleLyricsStackWidget,
                            )
                          : OverflowBox(
                              maxWidth: Dimensions.inst.miniplayerMaxWidth - pagePaddingHorizontal * 2, // keep the text steady while animating mp
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: pagePaddingHorizontal),
                                child: middleLyricsStackWidget,
                              ),
                            ),
                    ),
                  ),
                ),
                if (fullscreenIconButton != null)
                  Positioned(
                    bottom: 8.0,
                    right: 0.0,
                    child: fullscreenIconButton,
                  ),
              ],
            ),
          ),
        ),
        ...?bottomControlsChildren,
        if (widget.bottomPadding != null) widget.bottomPadding!,
      ],
    );
    if (fullscreen && widget.useSafeArea) {
      mainLyricsWidget = SafeArea(
        bottom: false,
        child: mainLyricsWidget,
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        videoOrImageChild,
        mainLyricsWidget,
        Positioned.fill(
          child: ScaleDetector(
            onScaleStart: (details) => _previousFontMultiplier = _fontMultiplier,
            onScaleUpdate: (details) => refreshState(() => _fontMultiplier = (details.scale * _previousFontMultiplier).clampDouble(0.5, 2.0)),
            onScaleEnd: (details) => widget.isFullScreenView ? settings.save(fontScaleLRCFull: _fontMultiplier) : settings.save(fontScaleLRC: _fontMultiplier),
          ),
        ),
      ],
    );
  }
}

class _TextWithFadingProgress extends StatelessWidget {
  final List<LrcLinePart> parts;
  final TextStyle textStyle;
  final TextAlign textAlign;

  const _TextWithFadingProgress({
    required this.parts,
    required this.textStyle,
    required this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Player.inst.playWhenReady,
      builder: (context, playWhenReady) => ObxO(
        rx: Player.inst.nowPlayingPosition,
        builder: (context, currentPosition) => Text.rich(
          TextSpan(
            children: parts.mapIndexed(
              (e, i) {
                final textPart = e.lyrics;
                final normalColor = textStyle.color!;
                final dimmedColor = normalColor.withValues(
                  alpha: 0.25,
                );
                final didReachTimeStampForPart = currentPosition > e.startTimestamp.inMilliseconds;

                final child = RichText(
                  text: TextSpan(
                    text: textPart,
                    style: textStyle, // dont dim here
                  ),
                  textAlign: TextAlign.start, // -- otherwise multi-part word will appear split
                  // -- fixes artifacts with shader
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  // softWrap: false, // keep the text steady while animating mp
                );

                // -- more accurate but position updates are slower, so it feels jittery
                // final eStart = e.startTimestamp.inMilliseconds;
                // final nextStart = e.endTimestamp.inMilliseconds;
                // final total = nextStart - eStart;
                // double progress = (currentPosition - eStart) / total;
                // progress = progress.clamp(0.0, 1.0);

                final animationDuration = Duration(milliseconds: !playWhenReady ? 0 : e.endTimestamp.inMilliseconds - e.startTimestamp.inMilliseconds);
                return WidgetSpan(
                  child: TweenAnimationBuilder(
                    duration: animationDuration,
                    tween: DoubleTween(begin: 0.0, end: didReachTimeStampForPart ? 1.0 : 0.0),
                    builder: (context, value, _) {
                      final progress = value ?? 1.0;
                      // if (progress >= 1.0) return child; // color be mismatching
                      return ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            normalColor,
                            normalColor,
                            dimmedColor,
                          ],
                          stops: [
                            0,
                            progress,
                            progress == 0 ? 0.0 : progress + 0.1,
                          ],
                        ).createShader(bounds),
                        blendMode: BlendMode.dstIn,
                        child: child,
                      );
                    },
                  ),
                );
              },
            ).toList(),
          ),
          textAlign: textAlign,
        ),
      ),
    );
  }
}
