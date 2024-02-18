import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lrc/lrc.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/packages/miniplayer.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class LyricsLRCParsedView extends StatefulWidget {
  final double cp;
  final Lrc? lrc;
  final Widget videoOrImage;
  final bool isFullScreenView;
  final Duration totalDuration;

  const LyricsLRCParsedView({
    super.key,
    required this.cp,
    required this.lrc,
    required this.videoOrImage,
    this.isFullScreenView = false,
    required this.totalDuration,
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
            totalDuration: widget.totalDuration,
            cp: widget.cp,
            lrc: currentLRC,
            videoOrImage: const SizedBox(),
            isFullScreenView: true,
          );
        },
      ),
    );
  }

  late final ItemScrollController controller;
  late final ItemPositionsListener positionListener;

  late final int topDummyItems;
  late final int bottomDummyItems;

  @override
  void initState() {
    super.initState();
    topDummyItems = widget.isFullScreenView ? 32 : 12;
    bottomDummyItems = widget.isFullScreenView ? 32 : 12;
    controller = ItemScrollController();
    positionListener = ItemPositionsListener.create();
    fillLists(widget.lrc);
  }

  Lrc? currentLRC;

  void fillLists(Lrc? lrc) {
    currentLRC = lrc;
    if (lrc == null) {
      timestampsMap.clear();
      lyrics.clear();
      return;
    }
    // -- calculating timestamps multiplier, useful for spedup/nightcore
    final llength = lrc.length ?? '';
    double cal = 0;
    if (llength != '') {
      final parts = llength.split(RegExp(r'[:.]'));
      try {
        final lyricsDuration = Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
          milliseconds: int.parse("${parts[2]}0"), // aditional 0 to convert to millis
        );
        cal = widget.totalDuration.inMicroseconds / lyricsDuration.inMicroseconds;
      } catch (_) {}
    }

    timestampsMap
      ..clear()
      ..addEntries(
        lrc.lyrics.asMap().entries.map(
          (e) {
            final lineTimeStamp = e.value.timestamp + Duration(milliseconds: lrc.offset ?? 0);
            final calculatedForSpedUpVersions = cal == 0 ? lineTimeStamp : (lineTimeStamp * cal);
            final newLrcLine = LrcLine(
              timestamp: calculatedForSpedUpVersions,
              lyrics: e.value.lyrics,
              type: e.value.type,
              args: e.value.args,
            );
            return MapEntry(
              calculatedForSpedUpVersions,
              (e.key, newLrcLine),
            );
          },
        ),
      );
    lyrics = timestampsMap.values.map((e) => e.$2).toList();
    _listenForPosition();
    _updateHighlightedLine(Player.inst.nowPlayingPosition.milliseconds, jump: true);
  }

  StreamSubscription? _streamSub;
  void _listenForPosition() {
    _streamSub = Player.inst.positionStream.asBroadcastStream().listen((ms) {
      _updateHighlightedLine(ms.milliseconds);
    });
  }

  void _updateHighlightedLine(Duration dur, {bool forceAnimate = false, bool jump = false}) {
    final lrcDur = lyrics.lastWhereEff((e) {
      return e.timestamp <= dur;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _latestUpdatedLine.value = lrcDur?.timestamp;

      final newIndex = timestampsMap[_latestUpdatedLine.value]?.$1 ?? -1;
      _latestUpdatedLineIndex.value = newIndex;

      if ((_canAnimateScroll || forceAnimate) && controller.isAttached) {
        final index = (newIndex + topDummyItems).toIf(0, -1);
        jump
            ? controller.jumpTo(
                alignment: 0.4,
                index: index,
              )
            : controller.scrollTo(
                alignment: 0.4,
                index: index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
      }
    });
  }

  // ignore: unused_field
  Timer? _scrollTimer;
  bool _canAnimateScroll = true;

  final _latestUpdatedLineIndex = (-1).obs;
  final _latestUpdatedLine = Rxn<Duration>();

  var lyrics = <LrcLine>[];
  final timestampsMap = <Duration, (int, LrcLine)>{};

  double _previousFontMultiplier = settings.fontScaleLRC;
  double _fontMultiplier = settings.fontScaleLRC;

  @override
  void dispose() {
    _latestUpdatedLineIndex.close();
    _latestUpdatedLine.close();
    _streamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fullscreen = widget.isFullScreenView;
    final initialFontSize = fullscreen ? 25.0 : 15.0;
    final normalTextStyle = context.textTheme.displayMedium!.copyWith(fontSize: _fontMultiplier * initialFontSize.multipliedFontScale);

    return Stack(
      alignment: Alignment.center,
      children: [
        fullscreen
            ? Positioned.fill(
                child: Obx(
                  () => Container(
                    color: Color.alphaBlend(
                      CurrentColor.inst.color.withOpacity(0.2),
                      context.isDarkMode ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              )
            : widget.videoOrImage,

        // NamidaOpacity causes rebuilds
        Opacity(
          opacity: widget.cp,
          child: ClipRRect(
            borderRadius: fullscreen ? BorderRadius.zero : BorderRadius.circular(16.0.multipliedRadius),
            child: NamidaBgBlur(
              blur: fullscreen ? 0.0 : 14.0,
              enabled: true,
              child: Container(
                color: context.theme.scaffoldBackgroundColor.withOpacity(fullscreen ? 0.8 : 0.6),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Listener(
                            onPointerMove: (event) {
                              _scrollTimer?.cancel();
                              _scrollTimer = null;
                              _canAnimateScroll = false;
                            },
                            onPointerUp: (event) {
                              _scrollTimer = Timer(const Duration(seconds: 3), () {
                                _canAnimateScroll = true;
                                if (Player.inst.isPlaying) {
                                  _updateHighlightedLine(Player.inst.nowPlayingPosition.milliseconds, forceAnimate: true);
                                }
                              });
                            },
                            child: ShaderFadingWidget(
                              biggerValues: fullscreen,
                              child: Builder(
                                builder: (context) {
                                  return Obx(
                                    () {
                                      final lrc = Lyrics.inst.currentLyricsLRC.value;
                                      if (lrc == null) {
                                        final text = Lyrics.inst.currentLyricsText.value;
                                        if (text != '') {
                                          return SingleChildScrollView(
                                            child: Column(
                                              children: [
                                                SizedBox(height: context.height * 0.3),
                                                Text(
                                                  text,
                                                  style: normalTextStyle,
                                                ),
                                                SizedBox(height: context.height * 0.3),
                                              ],
                                            ),
                                          );
                                        }
                                        return const SizedBox();
                                      }

                                      final color = CurrentColor.inst.color;
                                      final highlighted = timestampsMap[_latestUpdatedLine.value]?.$2;
                                      return PageStorage(
                                        bucket: PageStorageBucket(),
                                        child: ScrollablePositionedList.builder(
                                          key: PageStorageKey(widget.key),
                                          // initialAlignment: 0.4,
                                          itemScrollController: controller,
                                          itemCount: lyrics.length + topDummyItems + bottomDummyItems,
                                          itemBuilder: (context, indexBefore) {
                                            if (indexBefore < topDummyItems) return const SizedBox(height: 12.0);
                                            if (indexBefore >= (lyrics.length + topDummyItems)) return const SizedBox(height: 12.0);

                                            final index = indexBefore - topDummyItems;
                                            final lrc = lyrics[index];
                                            final selected = highlighted?.timestamp == lrc.timestamp;
                                            final text = lrc.lyrics;
                                            final bgColor =
                                                selected && text != '' ? Color.alphaBlend(color.withAlpha(140), context.theme.scaffoldBackgroundColor).withOpacity(0.5) : null;

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
                                                        _updateHighlightedLine(lrc.timestamp, forceAnimate: true);
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
                                                        borderRadius: 8.0,
                                                        animationDurationMS: 300,
                                                        margin: EdgeInsets.symmetric(vertical: padding, horizontal: 4.0),
                                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                                                        child: Text(
                                                          text,
                                                          style: normalTextStyle.copyWith(
                                                            color: selected ? Colors.white.withOpacity(0.7) : normalTextStyle.color?.withOpacity(0.5) ?? Colors.transparent,
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
                                    color: Get.theme.scaffoldBackgroundColor.withOpacity(0.7),
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
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) {
                                          return LyricsLRCParsedView(
                                            key: Lyrics.inst.lrcViewKeyFullscreen,
                                            totalDuration: widget.totalDuration,
                                            cp: widget.cp,
                                            lrc: currentLRC,
                                            videoOrImage: const SizedBox(),
                                            isFullScreenView: true,
                                          );
                                        },
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (fullscreen) ...[
                      const WaveformMiniplayer(fixPadding: true),
                      const SizedBox(height: 8.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),
                          NamidaHero(
                            enabled: false,
                            tag: 'MINIPLAYER_POSITION',
                            child: Obx(
                              () => Text(
                                Player.inst.nowPlayingPosition.milliSecondsLabel,
                                style: context.textTheme.displaySmall,
                              ),
                            ),
                          ),
                          const Spacer(),
                          NamidaIconButton(
                            icon: Broken.previous,
                            iconSize: 24.0,
                            onPressed: () {
                              Player.inst.previous();
                            },
                          ),
                          Obx(
                            () => NamidaIconButton(
                              horizontalPadding: 18.0,
                              icon: Player.inst.isPlaying ? Broken.pause : Broken.play,
                              iconSize: 32.0,
                              onPressed: () {
                                Player.inst.togglePlayPause();
                              },
                            ),
                          ),
                          NamidaIconButton(
                            icon: Broken.next,
                            iconSize: 24.0,
                            onPressed: () {
                              Player.inst.next();
                            },
                          ),
                          const Spacer(),
                          NamidaHero(
                            enabled: false,
                            tag: 'MINIPLAYER_DURATION',
                            child: Obx(
                              () => Text(
                                Player.inst.nowPlayingTrack.duration.secondsLabel,
                                style: context.textTheme.displaySmall,
                              ),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 12.0),
                      SizedBox(height: MediaQuery.paddingOf(context).bottom),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ScaleDetector(
            onScaleStart: (details) => _previousFontMultiplier = _fontMultiplier,
            onScaleUpdate: (details) => setState(() => _fontMultiplier = (details.scale * _previousFontMultiplier).clamp(0.5, 2.0)),
            onScaleEnd: (details) => settings.save(fontScaleLRC: _fontMultiplier),
          ),
        ),
      ],
    );
  }
}
