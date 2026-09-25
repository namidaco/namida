import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' hide Selectable;
import 'package:flutter/services.dart';

import 'package:lrc/lrc.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/romanizer/romanizer.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/miniplayer.dart';
import 'package:namida/packages/miniplayer_base.dart';
import 'package:namida/ui/dialogs/set_lrc_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/player_transport_controls.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class LyricsLRCParsedView extends StatefulWidget {
  final Widget videoOrImage;
  final bool isFullScreenView;
  final bool canShowToggleFullscreenButton;
  final void Function()? onCloseFullscreenButtonTap;
  final bool allowOverflow;
  final bool useSafeArea;
  final double blurColorMaskOpacity;
  final double? maxWidth;
  final double? maxHeight;
  final double? verticalPadding;
  final Widget? bottomPadding;
  final bool largeText;
  final bool insideMiniplayerCard;
  final bool fadeOnEmptyLine;
  final bool showJumpButton;
  final double? baseFontSize;

  /// receives the overlay's animated visibility, so siblings can match its backdrop.
  final ValueNotifier<double>? visibilityNotifier;

  const LyricsLRCParsedView({
    super.key,
    required this.videoOrImage,
    this.isFullScreenView = false,
    this.canShowToggleFullscreenButton = false,
    this.onCloseFullscreenButtonTap,
    this.allowOverflow = true,
    this.useSafeArea = true,
    this.blurColorMaskOpacity = 0.6,
    this.largeText = false,
    this.insideMiniplayerCard = false,
    this.fadeOnEmptyLine = true,
    this.showJumpButton = false,
    this.baseFontSize,
    this.visibilityNotifier,
    this.maxWidth,
    this.maxHeight,
    this.verticalPadding,
    this.bottomPadding,
  });

  @override
  State<LyricsLRCParsedView> createState() => LyricsLRCParsedViewState();
}

class LyricsLRCParsedViewState extends State<LyricsLRCParsedView> with SingleTickerProviderStateMixin {
  static final _mountedViews = <LyricsLRCParsedViewState>[];
  static Iterable<LyricsLRCParsedViewState> get mountedViews => _mountedViews;

  static final _lengthSplitRegex = RegExp(r'[:.]');

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
        videoOrImage: widget.videoOrImage,
        isFullScreenView: true,
      ),
      transition: Transition.native,
    );
  }

  void exitFullScreen() {
    NamidaNavigator.inst.popRoot();
  }

  _LyricsListState? _list;

  late final double _paddingVertical = widget.verticalPadding ?? (widget.isFullScreenView ? 32 * 12.0 : 12 * 12.0);
  int? _currentIndex;
  String _currentLine = '';

  static const int _lrcOpacityDurationMS = 500;
  late final bool _updateOpacityForEmptyLines = !widget.isFullScreenView && widget.fadeOnEmptyLine;
  bool _isCurrentLineEmpty = true;

  /// the only thing blur, mask & text opacity follow, so they can never disagree or pop.
  late final _visibility = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _lrcOpacityDurationMS),
    value: widget.isFullScreenView ? 1.0 : 0.0,
  );

  void _updateIsCurrentLineEmpty(bool empty) {
    if (_isCurrentLineEmpty == empty) return;
    _isCurrentLineEmpty = empty;
    _visibility.animateTo(empty ? 0.0 : 1.0);
  }

  void _reportVisibility() => widget.visibilityNotifier?.value = _visibility.value;

  final _emptyTextRegex = RegExp(r'[^\s]');
  bool _checkIfTextEmpty(String text) {
    final hasAnyChar = _emptyTextRegex.hasMatch(text);
    return !hasAnyChar;
  }

  @override
  void initState() {
    super.initState();
    _mountedViews.add(this);
    if (widget.visibilityNotifier != null) _visibility.addListener(_reportVisibility);
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

  /// the miniplayer fades its center card to 0 while the cards slide ([_cardSlide] away from 0),
  /// so a fill started there would play its fade-in completely unseen. hold it until the card is back.
  /// clearing isnt held, otherwise the previous item's lines would linger once the card returns.
  static AnimationController get _cardSlide => MiniPlayerController.inst.sAnim;

  void Function()? _pendingCardSettleAction;

  void _whenCardSettled(void Function() action) {
    if (!widget.insideMiniplayerCard || (_cardSlide.value == 0.0 && !_cardSlide.isAnimating)) {
      action();
      return;
    }
    _pendingCardSettleAction = action;
    _cardSlide.removeListener(_onCardSlideTick);
    _cardSlide.addListener(_onCardSlideTick);
  }

  void _onCardSlideTick() {
    if (_cardSlide.value != 0.0 || _cardSlide.isAnimating) return;
    _cardSlide.removeListener(_onCardSlideTick);
    final action = _pendingCardSettleAction;
    _pendingCardSettleAction = null;
    action?.call();
  }

  void fillLists(Lrc? lrc, LrcText? txt) => _whenCardSettled(() => _fillListsNow(lrc, txt));

  void clearLists({bool hide = true}) {
    _pendingCardSettleAction = null;
    highlightTimestampsMap = {};
    lyrics = [];
    if (hide) _updateIsCurrentLineEmpty(true);
    _latestUpdatedLineInfo.value = null;
    _currentIndex = null;
  }

  void _fillListsNow(Lrc? lrc, LrcText? txt) {
    currentLRC = lrc;
    if (lrc == null) {
      highlightTimestampsMap = {};
      lyrics = [];
      final isTextEmpty = txt == null ? true : _checkIfTextEmpty(txt.text);
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
        final parts = llength.split(_lengthSplitRegex);
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

    final uiInfo = lrc.forUiDisplay(
      cal,
      durationDifferenceToInsertEmptyLine: const Duration(seconds: 1),
      extraOffsetDuration: Duration(milliseconds: -settings.visualDelayMS.value),
      romanizer: Romanizer.inst.lyricsRomanizer(lrc),
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
    final lrcDur = lyrics.lastWhereEff((e) => e.timestamp <= Duration(milliseconds: durMS + 5) && !e.isBGLyrics) /* ?? lyrics.firstOrNull */;
    final newLineDuration = lrcDur?.timestamp;

    // -- prefer index checks, cuz duration is used in ui directly to highlight
    // -- and index can be used to force reset (to force scroll to current line) etc
    // if (!force && _latestUpdatedLineInfo.value?.$1 == newLineDuration) return;

    int? newIndexPre = newLineDuration == null ? null : highlightTimestampsMap[newLineDuration]?.firstOrNull;
    if (newIndexPre == null) return;

    if (newIndexPre + 1 == lyrics.length) {
      final alreadyHighlightingLastLine = _currentIndex == newIndexPre;
      if (alreadyHighlightingLastLine) {
        return; // overscrolling
      } else {
        newIndexPre = lyrics.length - 1; // go to last line
      }
    }
    if (newIndexPre < 0) newIndexPre = 0;

    if (!force && _currentIndex == newIndexPre) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      int newIndex = newIndexPre!;
      _latestUpdatedLineInfo.value = (lrcDur?.timestamp, newIndex);

      if (_canAnimateScroll.value || forceAnimate) {
        _currentIndex = newIndex;
        final list = _list;
        if (list != null && list.canScroll) list.scrollToIndex(newIndex, jump: jump);
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

  void _onListInit(_LyricsListState state) {
    _list = state;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = _currentIndex;
      if (index != null && identical(_list, state) && state.canScroll) state.scrollToIndex(index, jump: true);
    });
  }

  void _onListDispose(_LyricsListState state) {
    if (identical(_list, state)) _list = null;
  }

  Timer? _scrollTimer;
  final _canAnimateScroll = true.obs;

  final _scrollTick = _LyricsScrollTick();

  final _latestUpdatedLineInfo = Rxn<(Duration?, int?)>();

  var lyrics = <LrcLine>[];
  var highlightTimestampsMap = <Duration, List<int>>{}; // timestamp: [index]

  late final bool _largeText = widget.isFullScreenView || widget.largeText;
  late double _previousFontMultiplier = _fontMultiplier;
  late double _fontMultiplier = _largeText ? settings.fontScaleLRCFull : settings.fontScaleLRC;

  void _setFontMultiplier(double value) {
    value = value.clampDouble(0.5, 2.0);
    if (value == _fontMultiplier) return;
    refreshState(() => _fontMultiplier = value);
  }

  void _saveFontMultiplier() {
    _largeText ? settings.save(fontScaleLRCFull: _fontMultiplier) : settings.save(fontScaleLRC: _fontMultiplier);
  }

  @override
  void dispose() {
    _mountedViews.remove(this);
    _cardSlide.removeListener(_onCardSlideTick);
    widget.visibilityNotifier?.value = 0.0;
    _visibility.dispose();
    Player.inst.currentItemDuration.removeListener(_itemDurationUpdater);
    Player.inst.nowPlayingPosition.removeListener(_playerPositionListener);

    _latestUpdatedLineInfo.close();
    _currentItemDurationMS.close();
    _canAnimateScroll.close();
    _scrollTick.dispose();
    super.dispose();
  }

  void _onPointerDown(dynamic _) {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    if (currentLRC != null) {
      // -- only if synced
      _canAnimateScroll.value = false;
    }
    if (_isCurrentLineEmpty) {
      _updateIsCurrentLineEmpty(false);
    }
  }

  void _onPointerUp(dynamic _) {
    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(seconds: 3), () {
      if (Player.inst.playWhenReady.value) {
        _canAnimateScroll.value = true;
        _updateHighlightedLine(Player.inst.nowPlayingPosition.value, forceAnimate: true, force: true);
      }
      if (_updateOpacityForEmptyLines && currentLRC != null && _checkIfTextEmpty(_currentLine)) {
        _updateIsCurrentLineEmpty(true);
      }
    });
  }

  // -- mouse scroll
  void _onPointerSignal(dynamic _) {
    if (HardwareKeyboard.instance.isControlPressed) return;
    _onPointerDown(null);
    _onPointerUp(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final fullscreen = widget.isFullScreenView;
    const maxLyricsWidth = 864.0;
    final alignAtStart = fullscreen && context.width < maxLyricsWidth; // -- align at center if screen got too wide
    final initialFontSize = widget.baseFontSize ?? (_largeText ? 26.0 : 15.0);
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
              return ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: context.width, // vip
                  minHeight: 40.0, // eyeballed to match when textData is valid
                ),
                child: NamidaMouseRegion(
                  child: TapDetector(
                    onTap: null,
                    initializer: (instance) {
                      void fn(TapUpDetails d) {
                        if (item is Selectable) {
                          NamidaMiniPlayerTrack.openMenu(item.trackWithDate, item.track);
                        } else if (item is YoutubeID) {
                          NamidaMiniPlayerYoutubeID.openMenu(context, item, d);
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
                          child: IconButton(
                            tooltip: lang.exit,
                            icon: Icon(
                              Broken.arrow_left_2,
                              size: 22.0,
                              color: context.defaultIconColor(),
                            ),
                            onPressed: widget.onCloseFullscreenButtonTap ?? toggleFullscreen,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsGeometry.symmetric(horizontal: 48.0 + 8.0),
                          child: ObxO(
                            rx: YoutubeInfoController.utils.lazyInfoRefresh,
                            builder: (context, _) {
                              final textData = item is Selectable
                                  ? NamidaMiniPlayerTrack.textBuilder(item)
                                  : item is YoutubeID
                                  ? NamidaMiniPlayerYoutubeID.textBuilder(context, item)
                                  : null;
                              return textData == null
                                  ? Text(
                                      lang.lyrics,
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
                                    );
                            },
                          ),
                        ),
                        Positioned(
                          right: 10.0,
                          bottom: 0,
                          top: 0,
                          child: IconButton(
                            tooltip: lang.lyrics,
                            onPressed: () {
                              final currentItem = Player.inst.currentItem.value;
                              if (currentItem == null) return;
                              showLRCSetDialog(currentItem, CurrentColor.inst.miniplayerColor);
                            },
                            icon: NamidaMiniPlayerBase.getLrcButton(
                              theme,
                              color: context.defaultIconColor(),
                              iconSize: 22.0,
                            ),
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
    final bottomControlsChildren = fullscreen ? const [PlayerTransportControls()] : null;

    final pagePaddingHorizontal = fullscreen ? 0.0 : 24.0;
    late final mpAnimation = NamidaMiniPlayerBase.clampedAnimationBCP;

    final videoOrImageChild = fullscreen
        ? Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                ClipRect(
                  child: NamidaBlur(
                    fixArtifacts: true,
                    blur: 60.0,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: ObxO(
                        rx: Player.inst.currentItem,
                        builder: (context, item) {
                          Widget child;
                          if (item is YoutubeID) {
                            final vidId = item.id;
                            child = YoutubeThumbnail(
                              type: ThumbnailType.video,
                              key: Key(vidId),
                              isImportantInCache: true,
                              width: context.width,
                              borderRadius: 0,
                              blur: 0,
                              disableBlurBgSizeShrink: true,
                              videoId: vidId,
                              displayFallbackIcon: false,
                              compressed: true,
                              preferLowerRes: true,
                              forceSquared: true,
                              fit: BoxFit.cover,
                            );
                          } else {
                            final track = item is Selectable ? item.track : null;
                            child = ArtworkWidget(
                              key: ValueKey(track?.path),
                              track: track,
                              path: track?.pathToImage,
                              thumbnailSize: context.width,
                              width: context.width,
                              borderRadius: 0,
                              blur: 0,
                              disableBlurBgSizeShrink: true,
                              compressed: true,
                              forceSquared: true,
                              fit: BoxFit.cover,
                            );
                          }

                          return CustomAnimatedSwitcher(
                            duration: const Duration(milliseconds: 1200),
                            switchInCurve: Curves.easeInOutQuart,
                            switchOutCurve: Curves.easeInOutQuart,
                            child: child,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(
                    color: context.isDarkMode ? Colors.black.withOpacityExt(0.4) : Colors.white.withOpacityExt(0.2),
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(
                    color: context.theme.scaffoldBackgroundColor.withOpacityExt(widget.blurColorMaskOpacity),
                  ),
                ),
                // -- old design, simple color/gradient
                // Positioned.fill(
                //   child: Obx(
                //     (context) {
                //       final miniplayerColor = CurrentColor.inst.miniplayerColor;
                //       return DecoratedBox(
                //         decoration: BoxDecoration(
                //           gradient: LinearGradient(
                //             begin: Alignment.topLeft,
                //             end: Alignment.bottomRight,
                //             // -- careful with making colors non-opaque, it will cause the foreground to dim as well (no idea how :/)
                //             colors: context.isDarkMode
                //                 ? [
                //                     Color.alphaBlend(miniplayerColor.withOpacityExt(0.21), Colors.black).withOpacityExt(0.5),
                //                     Color.alphaBlend(miniplayerColor.withOpacityExt(0.15), Colors.black).withOpacityExt(0.5),
                //                   ]
                //                 : [
                //                     Color.alphaBlend(miniplayerColor.withOpacityExt(0.3), Colors.white.withOpacityExt(0.7)).withOpacityExt(0.5),
                //                     Color.alphaBlend(miniplayerColor.withOpacityExt(0.6), Colors.white.withOpacityExt(0.8)).withOpacityExt(0.5),
                //                   ],
                //           ),
                //         ),
                //         // child: widget.videoOrImage,
                //       );
                //     },
                //   ),
                // ),
              ],
            ),
          )
        : LyricsOverlayBackdrop(
            mpAnimation: mpAnimation,
            visibility: _visibility,
            child: widget.videoOrImage,
          );

    final middleLyricsStackWidget = Stack(
      fit: StackFit.loose,
      alignment: AlignmentGeometry.center,
      children: [
        ShaderFadingWidget(
          biggerValues: fullscreen,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxLyricsWidth),
            child: Builder(
              builder: (context) {
                return Obx(
                  (context) {
                    final lrc = Lyrics.inst.currentLyricsLRC.valueR;
                    Widget? textChild;
                    if (lrc == null) {
                      final textWrapper = Lyrics.inst.currentLyricsText.valueR;
                      if (!_checkIfTextEmpty(textWrapper.text)) {
                        final textDirection = textWrapper.isRTL ? TextDirection.rtl : TextDirection.ltr;
                        textChild = Align(
                          key: ObjectKey(textWrapper),
                          // -- Align vip to center widget
                          child: SmoothSingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            controller: Lyrics.inst.textScrollController,
                            child: Directionality(
                              textDirection: textDirection,
                              child: Column(
                                children: [
                                  SizedBox(height: _paddingVertical),
                                  Text(
                                    textWrapper.text,
                                    style: plainLyricsTextStyle,
                                    textAlign: alignAtStart ? TextAlign.start : TextAlign.center,
                                  ),
                                  SizedBox(height: _paddingVertical),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    }

                    final miniplayerColor = CurrentColor.inst.miniplayerColor;
                    final personCount = currentLRC?.personCount ?? 1;
                    // -- the outgoing list rebuilds its items while it fades, it must keep reading
                    // -- the data it was built with instead of whatever the next track swapped in
                    final lyrics = this.lyrics;
                    final highlightTimestampsMap = this.highlightTimestampsMap;

                    final lrcListChild = ObxO(
                      key: const ValueKey('lrc_list'),
                      rx: _latestUpdatedLineInfo,
                      builder: (context, selectedInfo) {
                        final selectedIndex = selectedInfo?.$2;
                        final selectedLineTimestamp = selectedInfo?.$1;
                        return CustomAnimatedSwitcher(
                          duration: const Duration(milliseconds: 800),
                          reverseDuration: widget.isFullScreenView ? null : Duration.zero, // 0 to make lyrics go instantly on switching animation, otherwise can look bad
                          switchInCurve: Curves.easeInOutQuart,
                          switchOutCurve: Curves.easeInOutQuart,
                          child: lyrics.isEmpty
                              ? const SizedBox(
                                  key: ValueKey('empty_lrc'),
                                )
                              : _LyricsList(
                                  key: ObjectKey(currentLRC),
                                  verticalPadding: _paddingVertical,
                                  scrollTick: _scrollTick,
                                  onInit: _onListInit,
                                  onDispose: _onListDispose,
                                  itemCount: lyrics.length,
                                  itemBuilder: (context, index) {
                                    // -- usually not needed, but helps cuz sometimes gets called on stale index
                                    if (index >= lyrics.length) return const SizedBox.shrink();

                                    final distanceDiffFromSelected = selectedIndex == null ? null : index - selectedIndex; // -- does not account for empty lines
                                    final distanceDiffFromSelectedAbs = distanceDiffFromSelected?.abs();
                                    final lrc = lyrics[index];
                                    String text = lrc.readableText;
                                    final parts = lrc.parts;
                                    final person = lrc.person;
                                    final isBGLyrics = lrc.isBGLyrics;
                                    final indicesForTimestamp = highlightTimestampsMap[lrc.timestamp];
                                    final textDirection = lrc.isRTL == true ? TextDirection.rtl : TextDirection.ltr;

                                    final selected = distanceDiffFromSelected == 0 || isBGLyrics || selectedLineTimestamp == lrc.timestamp;
                                    final selectedAndEmpty = selected && _checkIfTextEmpty(text);
                                    var bgColor = selected && !isBGLyrics
                                        ? Color.alphaBlend(miniplayerColor.withAlpha(140), theme.scaffoldBackgroundColor).withOpacityExt(
                                            selectedAndEmpty
                                                ? 0.1
                                                : fullscreen
                                                ? 0.4
                                                : 0.5,
                                          )
                                        : null;

                                    EdgeInsetsGeometry lineMargin = EdgeInsets.symmetric(
                                      vertical: /* (selected ? 2.0 : 0.0) + */ (fullscreen ? 8.0 : 2.0),
                                      horizontal: fullscreen ? 10.0 : 8.0,
                                    );

                                    EdgeInsetsGeometry padding = selectedAndEmpty
                                        ? const EdgeInsets.symmetric(
                                            vertical: 3.0,
                                            horizontal: 24.0,
                                          )
                                        : fullscreen
                                        ? const EdgeInsets.symmetric(
                                            vertical: 8.0,
                                            horizontal: 8.0,
                                          )
                                        : const EdgeInsets.symmetric(
                                            vertical: 8.0,
                                            horizontal: 8.0,
                                          );

                                    BorderRadius borderRadius = selectedAndEmpty ? BorderRadius.circular(5.0.multipliedRadius) : BorderRadius.circular(8.0.multipliedRadius);

                                    TextAlign textAlign = alignAtStart ? TextAlign.start : TextAlign.center;
                                    AlignmentDirectional alignment = alignAtStart ? AlignmentDirectional.centerStart : AlignmentDirectional.center;
                                    double normalLineColorOpacity = 0.5;
                                    (double, FontWeight)? fontModifier;
                                    TextStyle textStyle;

                                    if (person != null && personCount > 0) {
                                      if (personCount == 1) {
                                        // -- keep defaults
                                      } else if (person == 0) {
                                        // -- bg
                                        textAlign = TextAlign.center;
                                        alignment = AlignmentDirectional.center;
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
                                      } else if (person >= 3) {
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

                                    if (indicesForTimestamp != null && indicesForTimestamp.length > 1) {
                                      final isFirst = index == indicesForTimestamp.first;
                                      final isLast = index == indicesForTimestamp.last;
                                      final isSecondaryLanguageLine = !isFirst;

                                      if (isSecondaryLanguageLine) {
                                        final multiplier = fullscreen ? 0.75 : 0.85;
                                        textStyle = textStyle.copyWith(
                                          fontSize: textStyle.fontSize! * multiplier,
                                        );
                                        if (bgColor != null) {
                                          bgColor = bgColor.withOpacityExt(bgColor.a * 0.75);
                                        }
                                      }

                                      if (!isFirst) {
                                        lineMargin = lineMargin.subtract(
                                          EdgeInsetsDirectional.only(
                                            top: lineMargin.resolve(textDirection).top,
                                          ),
                                        );
                                        padding = padding.subtract(
                                          EdgeInsetsDirectional.only(
                                            top: padding.resolve(textDirection).top * 0.4,
                                          ),
                                        );
                                        borderRadius = borderRadius.copyWith(
                                          topRight: Radius.zero,
                                          topLeft: Radius.zero,
                                        );
                                      }

                                      if (!isLast) {
                                        lineMargin = lineMargin.subtract(
                                          EdgeInsetsDirectional.only(
                                            bottom: lineMargin.resolve(textDirection).bottom,
                                          ),
                                        );
                                        padding = padding.subtract(
                                          EdgeInsetsDirectional.only(
                                            bottom: padding.resolve(textDirection).bottom * 0.4,
                                          ),
                                        );
                                        borderRadius = borderRadius.copyWith(
                                          bottomRight: Radius.zero,
                                          bottomLeft: Radius.zero,
                                        );
                                      }
                                    }

                                    final Widget textWidget;
                                    if (_LyricsEffects.interludeDots && selectedAndEmpty) {
                                      textWidget = _LyricsInterludeDots(
                                        start: lrc.timestamp,
                                        end: index + 1 < lyrics.length ? lyrics[index + 1].timestamp : null,
                                        color: normalTextStyle.color ?? Colors.white,
                                        dotRadius: (normalTextStyle.fontSize ?? 15.0) * 0.16,
                                      );
                                    } else if (selected && parts != null && parts.isNotEmpty) {
                                      textWidget = _TextWithFadingProgress(
                                        parts: parts,
                                        textStyle: textStyle,
                                        textAlign: textAlign,
                                        textDirection: textDirection,
                                        accentColor: miniplayerColor,
                                        isDark: isDark,
                                      );
                                    } else {
                                      textWidget = Text(
                                        text,
                                        style: textStyle,
                                        textAlign: textAlign,
                                        // softWrap: false, // keep the text steady while animating mp
                                      );
                                    }

                                    return Directionality(
                                      textDirection: textDirection,
                                      child: Align(
                                        alignment: alignment, // needed for constraints
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: widget.maxWidth != null ? widget.maxWidth! : double.infinity,
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Positioned.fill(
                                                child: Material(
                                                  type: MaterialType.transparency,
                                                  child: InkWell(
                                                    splashFactory: InkSparkle.splashFactory,
                                                    onTap: () {
                                                      _canAnimateScroll.value = true;
                                                      _currentIndex = null; // reset so that tapping the current line still animates to it
                                                      Player.inst.seek(lrc.timestamp); //  should auto scroll bcz position changes
                                                    },
                                                  ),
                                                ),
                                              ),
                                              IgnorePointer(
                                                child: NamidaHero(
                                                  tag: 'LYRICS_LINE_${lrc.timestamp}',
                                                  enabled: false,
                                                  child: _LyricsFocalEffect(
                                                    alignment: alignment.resolve(textDirection),
                                                    selected: selected,
                                                    scrollTick: _scrollTick,
                                                    child: NamidaInkWell(
                                                      alignment: alignment,
                                                      bgColor: bgColor,
                                                      decoration: BoxDecoration(
                                                        borderRadius: borderRadius,
                                                      ),
                                                      animationDurationMS: 300,
                                                      margin: lineMargin,
                                                      padding: padding,
                                                      child: textWidget,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        );
                      },
                    );
                    return CustomAnimatedSwitcher(
                      duration: const Duration(milliseconds: 800),
                      switchInCurve: Curves.easeInOutQuart,
                      switchOutCurve: Curves.easeInOutQuart,
                      child: textChild ?? lrcListChild,
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: FadeIgnoreTransition(
                  opacity: mpAnimation,
                  child: Listener(
                    onPointerDown: _onPointerDown,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerUp,
                    onPointerSignal: _onPointerSignal,
                    child: FadeTransition(
                      opacity: _visibility,
                      child: _TickerModeWhileVisible(
                        opacity: mpAnimation,
                        secondaryOpacity: _visibility,
                        child: fullscreen || !widget.allowOverflow
                            ? Padding(
                                padding: EdgeInsets.symmetric(horizontal: pagePaddingHorizontal),
                                child: middleLyricsStackWidget,
                              )
                            : OverflowBox(
                                maxWidth: MiniPlayerController.inst.screenSize.width - pagePaddingHorizontal * 2, // keep the text steady while animating mp (virtual panel units)
                                maxHeight: widget.maxHeight, // -- the panel space, not the artwork box which reshapes per item
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: pagePaddingHorizontal),
                                  child: middleLyricsStackWidget,
                                ),
                              ),
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

              if (fullscreen || widget.showJumpButton)
                Positioned(
                  bottom: 12.0,
                  right: 12.0,
                  child: ObxO(
                    rx: _canAnimateScroll,
                    builder: (context, canAnimateScroll) => DelayedAnimatedShow(
                      show: !canAnimateScroll,
                      showDelay: const Duration(milliseconds: 1200),
                      duration: const Duration(milliseconds: 600),
                      child: NamidaInkWell(
                        borderRadius: 10.0,
                        onTap: () {
                          _updateHighlightedLine(Player.inst.nowPlayingPosition.value, forceAnimate: true, force: true);
                          _canAnimateScroll.value = true;
                        },
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        bgColor: context.theme.colorScheme.secondary.withOpacityExt(0.3),
                        child: Row(
                          mainAxisSize: .min,
                          children: [
                            const SizedBox(width: 12.0),
                            Icon(
                              Broken.cd,
                              size: 18.0,
                            ),
                            const SizedBox(width: 6.0),
                            Text(
                              lang.jump,
                              style: context.textTheme.displayMedium,
                            ),
                            const SizedBox(width: 12.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
    Widget finalStack = Stack(
      alignment: Alignment.center,
      children: [
        videoOrImageChild,
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth != null ? widget.maxWidth! : double.infinity,
          ),
          child: mainLyricsWidget,
        ),
        Positioned.fill(
          child: ScaleDetector(
            onScaleStart: (details) => _previousFontMultiplier = _fontMultiplier,
            onScaleUpdate: (details) => _setFontMultiplier(details.scale * _previousFontMultiplier),
            onScaleEnd: (details) => _saveFontMultiplier(),
            onScaleReset: () {
              _setFontMultiplier(1.0);
              _saveFontMultiplier();
            },
          ),
        ),
      ],
    );

    if (fullscreen) {
      finalStack = BackgroundWrapper(
        child: finalStack,
      );
    }

    return finalStack;
  }
}

// class _TextWithFadingProgressOld extends StatelessWidget {
//   final List<LrcLinePart> parts;
//   final TextStyle textStyle;
//   final TextAlign textAlign;
//   final TextDirection textDirection;

//   const _TextWithFadingProgressOld({
//     required this.parts,
//     required this.textStyle,
//     required this.textAlign,
//     required this.textDirection,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return ObxO(
//       rx: Player.inst.playWhenReady,
//       builder: (context, playWhenReady) => ObxO(
//         rx: Player.inst.nowPlayingPosition,
//         builder: (context, currentPosition) => Text.rich(
//           TextSpan(
//             children: parts.mapIndexed(
//               (_, indexPre) {
//                 final indexEffective = switch (textDirection) {
//                   TextDirection.ltr => indexPre,
//                   TextDirection.rtl => parts.length - indexPre - 1,
//                 };
//                 final e = parts[indexEffective];
//                 final textPart = e.lyrics;
//                 final normalColor = textStyle.color!;
//                 final dimmedColor = normalColor.withValues(
//                   alpha: 0.25,
//                 );
//                 final didReachTimeStampForPart = Duration(milliseconds: currentPosition) > e.startTimestamp;

//                 final child = RichText(
//                   text: TextSpan(
//                     text: textPart,
//                     style: textStyle, // dont dim here
//                   ),
//                   // textDirection: textDirection,
//                   textAlign: TextAlign.start, // -- otherwise multi-part word will appear split
//                   // -- fixes artifacts with shader
//                   textHeightBehavior: const TextHeightBehavior(
//                     applyHeightToFirstAscent: false,
//                     applyHeightToLastDescent: false,
//                   ),
//                   // softWrap: false, // keep the text steady while animating mp
//                 );

//                 // -- more accurate but position updates are slower, so it feels jittery
//                 // final eStart = e.startTimestamp.inMilliseconds;
//                 // final nextStart = e.endTimestamp.inMilliseconds;
//                 // final total = nextStart - eStart;
//                 // double progress = (currentPosition - eStart) / total;
//                 // progress = progress.clampDouble(0.0, 1.0);

//                 var animationDuration = !playWhenReady ? Duration.zero : e.endTimestamp - e.startTimestamp;
//                 if (animationDuration <= Duration.zero) animationDuration = const Duration(milliseconds: 10);
//                 return WidgetSpan(
//                   child: TweenAnimationBuilder(
//                     duration: animationDuration,
//                     tween: DoubleTween(begin: 0.0, end: didReachTimeStampForPart ? 1.0 : 0.0),
//                     builder: (context, value, _) {
//                       final progress = value ?? 1.0;
//                       // if (progress >= 1.0) return child; // color be mismatching
//                       return ShaderMask(
//                         shaderCallback: (bounds) => LinearGradient(
//                           begin: AlignmentDirectional.centerStart,
//                           end: AlignmentDirectional.centerEnd,
//                           colors: [
//                             normalColor,
//                             normalColor,
//                             dimmedColor,
//                           ],
//                           stops: [
//                             0,
//                             progress,
//                             progress == 0 ? 0.0 : progress + 0.1,
//                           ],
//                         ).createShader(bounds, textDirection: textDirection),
//                         blendMode: BlendMode.dstIn,
//                         child: ClipRect(
//                           // -- clip is important to avoid artifacts caused by font exisitng outside shader mask area
//                           child: child,
//                         ),
//                       );
//                     },
//                   ),
//                 );
//               },
//             ).toFixedList(),
//           ),
//           textDirection: textDirection,
//           textAlign: textAlign,
//         ),
//       ),
//     );
//   }
// }

/// Generated by claude.ai
/// Reason: no enough experience with deep rendering stuff
///
/// the old version [_TextWithFadingProgressOld] laid out each part with its own shader mask,
/// causing text to jump due to different layout ways (Text vs TextSpan.children)
///
/// Karaoke-style word-synced line.
///
/// Instead of wrapping each timed part in its own [WidgetSpan] (which turns every
/// word into an atomic inline box -> spaces no longer collapse at line breaks and
/// words no longer pack tightly, so the text wraps differently than a plain [Text]),
/// this lays out the whole line as ONE real paragraph via a [TextPainter] and reveals
/// the "sung" region on top of a dimmed base. Because it's a single paragraph, wrapping
/// is identical to [Text] and the reveal flows correctly across any number of lines.
class _TextWithFadingProgress extends StatefulWidget {
  final List<LrcLinePart> parts;
  final TextStyle textStyle;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final Color accentColor;
  final bool isDark;

  const _TextWithFadingProgress({
    required this.parts,
    required this.textStyle,
    required this.textAlign,
    required this.textDirection,
    required this.accentColor,
    required this.isDark,
  });

  @override
  State<_TextWithFadingProgress> createState() => _TextWithFadingProgressState();
}

class _TextWithFadingProgressState extends State<_TextWithFadingProgress> with TickerProviderStateMixin {
  /// position updates arrive every ~200ms, the playback clock is only corrected when it drifts further than this.
  static const _resyncToleranceMicros = 100 * 1000;

  /// unbounded; the playback position in microseconds, ticking linearly towards the line end between position updates.
  late final AnimationController _clock;

  final _sungChars = ValueNotifier<double>(0.0);

  _ShimmerSweep? _shimmer;

  late String _fullText;
  late List<int> _partCharStarts;
  late List<int> _partCharEnds;
  late List<int> _partStartMicros;
  late List<int> _partEndMicros;
  int _totalChars = 0;
  int _activePartHint = 0;

  _KaraokeLayout? _layout;
  _KaraokeLayoutKey? _layoutKey;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController.unbounded(vsync: this);
    _clock.addListener(_updateFill);
    if (_LyricsEffects.karaokeShimmer) _shimmer = _ShimmerSweep(this);
    _computeParts();
    _syncClock();
    _updateFill();
    Player.inst.nowPlayingPosition.addListener(_syncClock);
    Player.inst.playWhenReady.addListener(_syncClock);
    Player.inst.currentSpeed.addListener(_onSpeedChanged);
  }

  void _computeParts() {
    final parts = widget.parts;
    final count = parts.length;
    _partCharStarts = List.filled(count, 0);
    _partCharEnds = List.filled(count, 0);
    _partStartMicros = List.filled(count, 0);
    _partEndMicros = List.filled(count, 0);
    final sb = StringBuffer();
    int offset = 0;
    for (int i = 0; i < count; i++) {
      final part = parts[i];
      final txt = part.lyrics;
      _partCharStarts[i] = offset;
      offset += txt.length;
      _partCharEnds[i] = offset;
      sb.write(txt);
      final startMicros = part.startTimestamp.inMicroseconds;
      final endMicros = part.endTimestamp.inMicroseconds;
      _partStartMicros[i] = startMicros;
      _partEndMicros[i] = endMicros > startMicros ? endMicros : startMicros + 10000; // -- 10ms min
    }
    _fullText = sb.toString();
    _totalChars = offset;
    _activePartHint = 0;
    _layout?.dispose();
    _layout = null;
  }

  @override
  void didUpdateWidget(covariant _TextWithFadingProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.parts, widget.parts)) {
      _computeParts();
      _clock.stop();
      _syncClock();
      _updateFill();
    }
  }

  /// last part whose start has been reached, -1 before the first one.
  int _activePartAt(double micros) {
    final starts = _partStartMicros;
    var i = _activePartHint;
    while (i > 0 && starts[i] > micros) {
      i--;
    }
    while (i + 1 < starts.length && starts[i + 1] <= micros) {
      i++;
    }
    _activePartHint = i;
    return starts[i] <= micros ? i : -1;
  }

  void _updateFill() {
    if (_totalChars == 0) return;
    final micros = _clock.value;
    final active = _activePartAt(micros);
    if (active < 0) {
      _sungChars.value = 0.0;
      return;
    }
    final endMicros = _partEndMicros[active];
    final endChar = _partCharEnds[active];
    if (micros >= endMicros) {
      _sungChars.value = endChar.toDouble();
      return;
    }
    final startMicros = _partStartMicros[active];
    final startChar = _partCharStarts[active];
    _sungChars.value = startChar + (micros - startMicros) / (endMicros - startMicros) * (endChar - startChar);
  }

  void _onSpeedChanged() {
    _clock.stop();
    _syncClock();
  }

  /// the clock keeps running on its own through the whole line, position updates only correct real drift (seeks, stalls).
  void _syncClock() {
    if (_totalChars == 0) return;

    final posMicros = Player.inst.nowPlayingPosition.value * 1000.0;
    final playing = Player.inst.playWhenReady.value;
    final lineEndMicros = _partEndMicros.last;

    if ((posMicros - _clock.value).abs() > _resyncToleranceMicros) _clock.value = posMicros;

    final remainingMicros = lineEndMicros - _clock.value;
    if (playing && remainingMicros > 0) {
      if (!_clock.isAnimating) {
        final speed = Player.inst.currentSpeed.value;
        _clock.animateTo(
          lineEndMicros.toDouble(),
          duration: Duration(microseconds: (remainingMicros / (speed > 0 ? speed : 1.0)).round()),
          curve: Curves.linear,
        );
      }
    } else {
      _clock.stop();
    }

    final shimmer = _shimmer;
    if (shimmer != null) {
      final active = _activePartAt(posMicros);
      final heldNote = active >= 0 && posMicros < _partEndMicros[active] && _partEndMicros[active] - _partStartMicros[active] >= _ShimmerSweep.heldNoteMicros;
      shimmer.setActive(playing && (heldNote || posMicros > lineEndMicros + _ShimmerSweep.holdDelayMicros));
    }
  }

  /// relaid only when an input that affects layout or colors changed, [_KaraokeTextPainter.paint] never lays out.
  _KaraokeLayout _ensureLayout(double maxWidth, TextScaler textScaler) {
    final style = widget.textStyle;
    final key = (
      maxWidth: maxWidth,
      textScaler: textScaler,
      style: style,
      accent: widget.accentColor,
      isDark: widget.isDark,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
    );
    final current = _layout;
    if (current != null && key == _layoutKey) return current;

    current?.dispose();
    final colors = _KaraokeColors.resolve(
      base: style.color ?? const Color(0xFFFFFFFF),
      accent: widget.accentColor,
      isDark: widget.isDark,
    );
    final glowColor = colors.glow;
    final shimmerColor = colors.shimmer;
    final transparentShimmer = shimmerColor.withValues(alpha: 0.0);
    _layoutKey = key;
    return _layout = _KaraokeLayout(
      dim: _layoutPainter(style.copyWith(color: colors.dim), maxWidth, textScaler),
      full: _layoutPainter(style.copyWith(color: colors.sung), maxWidth, textScaler),
      glow: glowColor == null
          ? null
          : _layoutPainter(
              style.copyWith(
                foreground: Paint()
                  ..color = glowColor
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _KaraokeColors.glowSigma),
              ),
              maxWidth,
              textScaler,
            ),
      shimmerColors: [transparentShimmer, shimmerColor, transparentShimmer],
      partStarts: _partCharStarts,
      partEnds: _partCharEnds,
      totalChars: _totalChars,
    );
  }

  TextPainter _layoutPainter(TextStyle style, double maxWidth, TextScaler textScaler) {
    return TextPainter(
      text: TextSpan(
        text: _fullText,
        style: style.copyWith(
          height: 1.5, // -- ensure it clips more for higher glyphs, shouldn't affect anything else even with very high number
        ),
      ),
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      textScaler: textScaler,
      textWidthBasis: TextWidthBasis.parent,
      textHeightBehavior: TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    )..layout(maxWidth: maxWidth);
  }

  @override
  void dispose() {
    Player.inst.nowPlayingPosition.removeListener(_syncClock);
    Player.inst.playWhenReady.removeListener(_syncClock);
    Player.inst.currentSpeed.removeListener(_onSpeedChanged);
    _layout?.dispose();
    _shimmer?.dispose();
    _clock.dispose();
    _sungChars.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity;
        final layout = _ensureLayout(maxWidth, textScaler);
        return RepaintBoundary(
          child: CustomPaint(
            size: layout.full.size,
            painter: _KaraokeTextPainter(
              layout: layout,
              fill: _sungChars,
              shimmer: _shimmer,
            ),
          ),
        );
      },
    );
  }
}

/// Generated by claude.ai
/// Reason: no enough experience with deep rendering stuff
class _KaraokeTextPainter extends CustomPainter {
  final _KaraokeLayout layout;
  final ValueListenable<double> fill;
  final _ShimmerSweep? shimmer;

  static const double _featherPx = 20.0;
  static const _featherColors = [Color(0xFFFFFFFF), Color(0x00FFFFFF)];

  // -- canvas records paint values on each call, so these are safely reused across draws.
  static final _layerPaint = Paint();
  static final _featherMaskPaint = Paint()..blendMode = BlendMode.dstIn;
  static final _clearMaskPaint = Paint()
    ..blendMode = BlendMode.dstIn
    ..color = const Color(0x00000000);
  static final _shimmerPaint = Paint()..blendMode = BlendMode.srcATop;

  _KaraokeTextPainter({
    required this.layout,
    required this.fill,
    required this.shimmer,
  }) : super(repaint: shimmer == null ? fill : Listenable.merge([fill, shimmer.listenable]));

  @override
  void paint(Canvas canvas, Size size) {
    final layout = this.layout;
    final total = layout.totalChars;
    var fillChars = fill.value;
    if (fillChars.isNaN) fillChars = 0.0;
    fillChars = fillChars.clampDouble(0.0, total.toDouble());

    final partial = total > 0 && fillChars > 0 && fillChars < total;
    final sweep = partial ? layout.sweepAt(fillChars) : null;
    final bump = partial && _LyricsEffects.karaokeWordBump ? layout.wordBumpAt(fillChars) : null;

    // -- layer must contain the glow halo, else it gets cut into a visible box around the text
    final bounds = layout.hasGlow ? (Offset.zero & size).inflate(_KaraokeLayout.glowPadding) : Offset.zero & size;
    final shimmer = this.shimmer;
    final shimmerShader = shimmer != null && shimmer.isActive ? shimmer.shader(size.width, layout.shimmerColors) : null;
    if (bump == null) {
      _paintLine(canvas, size, fillChars, sweep, bounds, shimmerShader);
      return;
    }

    // -- everything except the active word, then the word itself scaled on top
    canvas.save();
    canvas.clipRect(bump.rect, clipOp: ui.ClipOp.difference);
    _paintLine(canvas, size, fillChars, sweep, bounds, shimmerShader);
    canvas.restore();

    canvas.save();
    final center = bump.rect.center;
    canvas.translate(center.dx, center.dy);
    canvas.scale(bump.scale);
    canvas.translate(-center.dx, -center.dy);
    canvas.clipRect(bump.rect);
    _paintLine(canvas, size, fillChars, sweep, bump.rect, shimmerShader);
    canvas.restore();
  }

  void _paintLine(Canvas canvas, Size size, double fillChars, _KaraokeSweep? sweep, Rect layerBounds, Shader? shimmerShader) {
    final layout = this.layout;
    final total = layout.totalChars;
    // -- base dimmed layer (whole line)
    layout.dim.paint(canvas, Offset.zero);

    if (total == 0 || fillChars <= 0) return;
    if (fillChars >= total) {
      _paintSungWhole(canvas, size, shimmerShader);
      return;
    }
    if (sweep == null) {
      _paintHardSung(canvas, fillChars.floor()); // -- fallback (e.g. active char is a zero-width glyph)
      return;
    }

    // -- one small saveLayer: paint the full-color line, then carve it down to the sung region
    // -- with a dstIn mask. Lines above the sweep stay opaque, the sweep line feathers, lines below clear.
    canvas.saveLayer(layerBounds, _layerPaint);
    layout.paintGlow(canvas);
    _paintSungText(canvas, layerBounds, shimmerShader);

    final isFirstLine = sweep.top <= 0.5;
    final isLastLine = sweep.bottom >= size.height - 0.5;
    canvas.drawRect(
      Rect.fromLTRB(
        layerBounds.left,
        isFirstLine ? math.min(layerBounds.top, sweep.top) : sweep.top,
        layerBounds.right,
        isLastLine ? math.max(layerBounds.bottom, sweep.bottom) : sweep.bottom,
      ),
      _featherMaskPaint..shader = _featherShader(sweep.boundaryX, sweep.ltr),
    );
    if (!isLastLine) {
      canvas.drawRect(
        Rect.fromLTRB(layerBounds.left, sweep.bottom, layerBounds.right, math.max(layerBounds.bottom, size.height)),
        _clearMaskPaint,
      );
    }
    canvas.restore();
  }

  // -- shimmer gets its own layer holding the glyphs only, otherwise srcATop lights up the glow halo too
  void _paintSungText(Canvas canvas, Rect bounds, Shader? shimmerShader) {
    final full = layout.full;
    if (shimmerShader == null) {
      full.paint(canvas, Offset.zero);
      return;
    }
    canvas.saveLayer(bounds, _layerPaint);
    full.paint(canvas, Offset.zero);
    canvas.drawRect(bounds, _shimmerPaint..shader = shimmerShader);
    canvas.restore();
  }

  void _paintSungWhole(Canvas canvas, Size size, Shader? shimmerShader) {
    layout.paintGlow(canvas);
    _paintSungText(canvas, Offset.zero & size, shimmerShader);
  }

  Shader _featherShader(double boundaryX, bool ltr) {
    return ui.Gradient.linear(
      Offset(boundaryX, 0),
      Offset(ltr ? boundaryX + _featherPx : boundaryX - _featherPx, 0),
      _featherColors,
    );
  }

  void _paintHardSung(Canvas canvas, int n) {
    if (n <= 0) return;
    final full = layout.full;
    final boxes = full.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: n),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    if (boxes.isEmpty) return;
    canvas.save();
    final path = Path();
    for (final b in boxes) {
      path.addRect(b.toRect());
    }
    canvas.clipPath(path);
    layout.paintGlow(canvas);
    full.paint(canvas, Offset.zero);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KaraokeTextPainter old) {
    return old.layout != layout || old.fill != fill || old.shimmer != shimmer;
  }
}

/// a karaoke line laid out once per text/style/width, so a frame never lays out, blurs glyphs or re-queries boxes.
class _KaraokeLayout {
  /// the blur halo reaches ~3 sigma past the glyphs.
  static const glowPadding = _KaraokeColors.glowSigma * 3.0;
  static final _glowPaint = Paint()..filterQuality = FilterQuality.low;

  final TextPainter dim;
  final TextPainter full;
  final List<Color> shimmerColors;
  final int totalChars;
  final List<int> _partStarts;
  final List<int> _partEnds;
  final ui.Image? _glow;

  _KaraokeLayout({
    required this.dim,
    required this.full,
    required TextPainter? glow,
    required this.shimmerColors,
    required this._partStarts,
    required this._partEnds,
    required this.totalChars,
  }) : _glow = glow == null ? null : _rasterizeGlow(glow);

  bool get hasGlow => _glow != null;

  _KaraokeClusters? _clusters;
  int _sweepClusterHint = 0;

  int _bumpPart = -1;
  Rect? _bumpRect;

  /// the glow is a blur, so a logical-pixel image upscaled by the gpu looks the same as blurring the glyphs every frame.
  static ui.Image _rasterizeGlow(TextPainter painter) {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Offset(glowPadding, glowPadding));
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (painter.width + glowPadding * 2).ceil(),
      (painter.height + glowPadding * 2).ceil(),
    );
    picture.dispose();
    painter.dispose();
    return image;
  }

  void paintGlow(Canvas canvas) {
    final glow = _glow;
    if (glow != null) canvas.drawImage(glow, const Offset(-glowPadding, -glowPadding), _glowPaint);
  }

  /// swept per rendered cluster, a single code unit inside a conjunct/matra has no box of its own.
  _KaraokeSweep? sweepAt(double fillChars) {
    final clusters = _clusters ??= _KaraokeClusters.of(full);
    final starts = clusters.starts;
    final count = starts.length;
    if (count == 0) return null;

    var i = _sweepClusterHint;
    while (i > 0 && starts[i] > fillChars) {
      i--;
    }
    while (i + 1 < count && starts[i + 1] <= fillChars) {
      i++;
    }
    _sweepClusterHint = i;

    final start = starts[i];
    final end = i + 1 < count ? starts[i + 1] : totalChars;
    final progress = end > start ? ((fillChars - start) / (end - start)).clampDouble(0.0, 1.0) : 0.0;
    final box = clusters.boxes[i];
    final ltr = box.direction == TextDirection.ltr;
    final advance = progress * (box.right - box.left);
    return (
      top: box.top,
      bottom: box.bottom,
      boundaryX: ltr ? box.left + advance : box.right - advance,
      ltr: ltr,
    );
  }

  _KaraokeWordBump? wordBumpAt(double fillChars) {
    final part = _activePart(fillChars);
    if (part < 0) return null;
    final start = _partStarts[part];
    final end = _partEnds[part];
    final span = end - start;
    if (span <= 0) return null;

    final amount = math.sin(((fillChars - start) / span).clampDouble(0.0, 1.0) * math.pi);
    final step = (amount * _KaraokeWordBump.scaleSteps).round();
    if (step == 0) return null;

    if (part != _bumpPart) {
      _bumpPart = part;
      _bumpRect = _partRect(start, end);
    }
    final rect = _bumpRect;
    if (rect == null) return null;
    return _KaraokeWordBump(rect, 1.0 + _KaraokeWordBump.scaleAmount * step / _KaraokeWordBump.scaleSteps);
  }

  int _activePart(double fillChars) {
    final cached = _bumpPart;
    if (cached >= 0 && fillChars >= _partStarts[cached] && fillChars < _partEnds[cached]) return cached;
    for (int i = 0; i < _partStarts.length; i++) {
      if (fillChars >= _partStarts[i] && fillChars < _partEnds[i]) return i;
    }
    return -1;
  }

  Rect? _partRect(int start, int end) {
    final boxes = full.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    if (boxes.isEmpty) return null;
    var rect = boxes.first.toRect();
    for (int i = 1; i < boxes.length; i++) {
      final other = boxes[i].toRect();
      if ((other.top - rect.top).abs() > 0.5) return null; // -- part wrapped onto another line
      rect = rect.expandToInclude(other);
    }
    if (rect.width <= 0 || rect.height <= 0) return null;
    return rect;
  }

  void dispose() {
    dim.dispose();
    full.dispose();
    _glow?.dispose();
  }
}

/// const switches for every lyrics effect, so disabling one tree-shakes it away.
///
/// all effects below and their implementations by claude
class _LyricsEffects {
  const _LyricsEffects._();

  /// lines scale down continuously the further they are from the current line, following the scroll.
  static const focalTransform = true;

  /// far lines lean back in 3d, above & below tilting opposite ways. needs [focalTransform].
  static const perspectiveTilt = false;

  /// far lines get blurred like a depth of field. costs a gpu blur per far line, first to disable on jank. needs [focalTransform].
  static const depthBlur = true;

  /// the line that just became current pops in with a small overshoot.
  static const springPop = true;

  /// instrumental gaps show three dots filling up until the next line, instead of an empty pill.
  static const interludeDots = true;

  /// sung words are tinted towards the artwork color. word-synced only.
  static const accentTint = true;

  /// soft artwork colored halo behind sung words. costs a text blur per frame. word-synced only.
  static const karaokeGlow = true;

  /// the word being sung grows slightly as the sweep crosses it. word-synced only.
  static const karaokeWordBump = true;

  /// highlight band travelling over the sung text during long held words (>=1s), or a line held after its last word. word-synced only.
  static const karaokeShimmer = true;

  /// far jumps (seeks) scroll slower with an emphasized curve, adjacent lines keep the quick glide.
  static const velocityAwareScroll = true;

  /// where the current line rests inside the viewport, shared by the scroller and the focal effect.
  static const listAlignment = 0.4;
}

/// overshoots then settles instead of easing flatly into place.
class _LyricsSpringCurve extends Curve {
  static const _frequency = 1.65;
  static const _damping = 5.2;

  const _LyricsSpringCurve();

  @override
  double transformInternal(double t) => 1.0 - math.exp(-_damping * t) * math.cos(_frequency * math.pi * t);
}

/// repaint signal fed by the lyrics list scroll position.
class _LyricsScrollTick extends ChangeNotifier {
  void tick() => notifyListeners();
}

/// scroll duration/curve picked from how far the jump is: adjacent lines glide, seeks travel.
class _LyricsScrollPlan {
  static const _shortDuration = Duration(milliseconds: 300);
  static const _longDuration = Duration(milliseconds: 620);
  static const _shortCurve = Curves.easeOut;
  static const _longCurve = Curves.easeInOutCubicEmphasized;
  static const _shortThreshold = 0.25;

  final Duration duration;
  final Curve curve;

  const _LyricsScrollPlan._(this.duration, this.curve);

  factory _LyricsScrollPlan.forDelta(double delta, double viewportHeight) {
    const short = _LyricsScrollPlan._(_shortDuration, _shortCurve);
    if (!_LyricsEffects.velocityAwareScroll || viewportHeight <= 0) return short;
    final t = (delta.abs() / viewportHeight).clampDouble(0.0, 1.0);
    if (t < _shortThreshold) return short;
    return _LyricsScrollPlan._(
      Duration(milliseconds: ui.lerpDouble(_shortDuration.inMilliseconds, _longDuration.inMilliseconds, t)!.round()),
      _longCurve,
    );
  }
}

/// sung/dim/glow/shimmer colors for a karaoke line, tinted towards the player accent.
class _KaraokeColors {
  static const glowSigma = 7.0;
  static const _dimAlpha = 0.25;
  static const _tintStrength = 0.6;
  static const _glowAlpha = 0.85;
  static const _shimmerAlpha = 0.85;
  static const _minSaturation = 0.55;

  final Color dim;
  final Color sung;
  final Color? glow;
  final Color shimmer;

  const _KaraokeColors._(this.dim, this.sung, this.glow, this.shimmer);

  factory _KaraokeColors.resolve({required Color base, required Color accent, required bool isDark}) {
    final baseAlpha = base.a;
    // -- raw artwork colors are often too dark/muted to show as a tint, only the hue is kept
    final hsl = HSLColor.fromColor(accent);
    final vivid = hsl.saturation < 0.08 ? hsl : hsl.withSaturation(math.max(hsl.saturation, _minSaturation));
    return _KaraokeColors._(
      base.withValues(alpha: baseAlpha * _dimAlpha),
      _LyricsEffects.accentTint ? Color.lerp(base, vivid.withLightness(isDark ? 0.78 : 0.32).toColor().withValues(alpha: baseAlpha), _tintStrength)! : base,
      _LyricsEffects.karaokeGlow ? vivid.withLightness(isDark ? 0.6 : 0.5).toColor().withValues(alpha: baseAlpha * _glowAlpha * (isDark ? 1.0 : 0.6)) : null,
      Color.fromRGBO(255, 255, 255, baseAlpha * _shimmerAlpha),
    );
  }
}

/// the boxes glyphs are actually drawn in: graphemes merged when shaping puts them in one box (conjuncts, ligatures),
/// zero-width ones folded into the previous cluster.
class _KaraokeClusters {
  final Int32List starts;
  final List<TextBox> boxes;

  const _KaraokeClusters._(this.starts, this.boxes);

  factory _KaraokeClusters.of(TextPainter painter) {
    final starts = <int>[];
    final boxes = <TextBox>[];
    var start = 0;
    for (final grapheme in painter.plainText.characters) {
      final end = start + grapheme.length;
      final graphemeBoxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      if (graphemeBoxes.isNotEmpty) {
        final box = graphemeBoxes.first;
        if (boxes.isEmpty || !_sameBox(boxes.last, box)) {
          starts.add(start);
          boxes.add(box);
        }
      }
      start = end;
    }
    return _KaraokeClusters._(Int32List.fromList(starts), boxes);
  }

  static bool _sameBox(TextBox a, TextBox b) {
    return (a.left - b.left).abs() < 0.5 && (a.right - b.right).abs() < 0.5 && (a.top - b.top).abs() < 0.5;
  }
}

/// slight scale of the syllable the karaoke sweep is currently crossing.
class _KaraokeWordBump {
  static const scaleAmount = 0.02;

  /// the scale moves in steps too small to see, so glyphs aren't rasterized at a new size every frame.
  static const scaleSteps = 8;

  final Rect rect;
  final double scale;

  const _KaraokeWordBump(this.rect, this.scale);
}

/// travelling highlight band, only ticking during a long held syllable or a line held past its last one.
class _ShimmerSweep {
  static const holdDelayMicros = 1200 * 1000;
  static const heldNoteMicros = 1000 * 1000;
  static const _period = Duration(milliseconds: 1300);
  static const _band = 0.2;
  static const _stops = [0.0, 0.5, 1.0];

  final AnimationController _controller;

  _ShimmerSweep(TickerProvider vsync) : _controller = AnimationController(vsync: vsync, duration: _period);

  Listenable get listenable => _controller;

  bool get isActive => _controller.isAnimating;

  void setActive(bool active) {
    if (active) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  /// [colors] is transparent, highlight, transparent.
  Shader? shader(double width, List<Color> colors) {
    if (width <= 0) return null;
    final center = (-_band + _controller.value * (1.0 + _band * 2)) * width;
    final halfBand = _band * width;
    if (center + halfBand <= 0 || center - halfBand >= width) return null;
    return ui.Gradient.linear(Offset(center - halfBand, 0), Offset(center + halfBand, 0), colors, _stops);
  }

  void dispose() => _controller.dispose();
}

/// continuous scale/tilt/blur driven by the line's live distance to the list focal point,
/// plus a spring pop when it becomes the current line.
class _LyricsFocalEffect extends StatefulWidget {
  final Alignment alignment;
  final bool selected;
  final _LyricsScrollTick scrollTick;
  final Widget child;

  const _LyricsFocalEffect({
    required this.alignment,
    required this.selected,
    required this.scrollTick,
    required this.child,
  });

  @override
  State<_LyricsFocalEffect> createState() => _LyricsFocalEffectState();
}

class _LyricsFocalEffectState extends State<_LyricsFocalEffect> with SingleTickerProviderStateMixin {
  static const _popCurve = _LyricsSpringCurve();
  static const _popDuration = Duration(milliseconds: 520);

  AnimationController? _popController;
  Animation<double>? _pop;

  @override
  void initState() {
    super.initState();
    if (_LyricsEffects.springPop) {
      final controller = AnimationController(vsync: this, duration: _popDuration, value: 1.0);
      _popController = controller;
      _pop = controller.drive(CurveTween(curve: _popCurve));
    }
  }

  @override
  void didUpdateWidget(covariant _LyricsFocalEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) _popController?.forward(from: 0.0);
  }

  @override
  void dispose() {
    _popController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LyricsFocalEffectRenderer(
      alignment: widget.alignment,
      scrollTick: widget.scrollTick,
      pop: _pop,
      child: RepaintBoundary(
        child: widget.child,
      ),
    );
  }
}

class _LyricsFocalEffectRenderer extends SingleChildRenderObjectWidget {
  final Alignment alignment;
  final _LyricsScrollTick scrollTick;
  final Animation<double>? pop;

  const _LyricsFocalEffectRenderer({
    required this.alignment,
    required this.scrollTick,
    required this.pop,
    required super.child,
  });

  @override
  _RenderLyricsFocalEffect createRenderObject(BuildContext context) {
    return _RenderLyricsFocalEffect(alignment, scrollTick, pop);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderLyricsFocalEffect renderObject) {
    renderObject
      ..alignment = alignment
      ..scrollTick = scrollTick
      ..pop = pop;
  }
}

/// Generated by claude.ai
/// Reason: no enough experience with deep rendering stuff
///
/// everything is applied as layers (transform + image filter) around an already rasterized
/// child, so scrolling only re-composites and never re-rasterizes the text.
class _RenderLyricsFocalEffect extends RenderProxyBox {
  static const _falloffFraction = 0.5;
  static const _minScale = 0.92;
  static const _maxTilt = 0.4;
  static const _maxBlurSigma = 1.2;
  static const _minBlurSigma = 0.2;
  static const _popStrength = 0.06;
  static const _perspective = 0.002;

  _RenderLyricsFocalEffect(this._alignment, this._scrollTick, this._pop);

  Alignment _alignment;
  set alignment(Alignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsPaint();
  }

  _LyricsScrollTick _scrollTick;
  set scrollTick(_LyricsScrollTick value) {
    if (identical(_scrollTick, value)) return;
    if (attached) _scrollTick.removeListener(markNeedsPaint);
    _scrollTick = value;
    if (attached) _scrollTick.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Animation<double>? _pop;
  set pop(Animation<double>? value) {
    if (identical(_pop, value)) return;
    if (attached) _pop?.removeListener(markNeedsPaint);
    _pop = value;
    if (attached) _pop?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  RenderBox? _viewport;
  final _blurLayerHandle = LayerHandle<ImageFilterLayer>();
  ui.ImageFilter? _blurFilter;
  double _blurSigma = -1.0;
  final _paintTransform = Matrix4.identity();
  final _innerTransform = Matrix4.identity();

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scrollTick.addListener(markNeedsPaint);
    _pop?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _scrollTick.removeListener(markNeedsPaint);
    _pop?.removeListener(markNeedsPaint);
    _viewport = null;
    super.detach();
  }

  @override
  void dispose() {
    _blurLayerHandle.layer = null;
    super.dispose();
  }

  /// signed -1..1 distance of this line's center from where the current line rests.
  double _focalDistance() {
    var viewport = _viewport;
    if (viewport == null || !viewport.attached) {
      final RenderObject? found = RenderAbstractViewport.maybeOf(this);
      if (found is! RenderBox) return 0.0;
      viewport = _viewport = found;
    }
    if (!viewport.hasSize) return 0.0;
    final viewportHeight = viewport.size.height;
    if (viewportHeight <= 0) return 0.0;
    final halfHeight = size.height * 0.5;
    final centerY = localToGlobal(Offset.zero, ancestor: viewport).dy + halfHeight;
    final focalY = (viewportHeight - size.height) * _LyricsEffects.listAlignment + halfHeight;
    return ((centerY - focalY) / (viewportHeight * _falloffFraction)).clampDouble(-1.0, 1.0);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;

    final signedDistance = _LyricsEffects.focalTransform ? _focalDistance() : 0.0;
    final distance = signedDistance.abs();

    var scale = 1.0 - (1.0 - _minScale) * distance;
    final pop = _pop;
    if (pop != null) scale *= 1.0 + _popStrength * (pop.value - 1.0);

    final tilt = _LyricsEffects.perspectiveTilt ? signedDistance * _maxTilt : 0.0;
    final sigma = _LyricsEffects.depthBlur ? (_maxBlurSigma * distance * distance * 4.0).roundToDouble() * 0.25 : 0.0;
    if (sigma != _blurSigma) {
      _blurSigma = sigma;
      _blurFilter = sigma > _minBlurSigma ? ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal) : null;
    }

    final inner = _innerTransform;
    inner.setIdentity();
    if (tilt != 0.0) {
      inner.setEntry(3, 2, _perspective);
      inner.rotateX(tilt);
    }
    inner.scaleByDouble(scale, scale, 1.0, 1.0);

    final origin = _alignment.alongSize(size);
    final transform = _paintTransform;
    transform.setIdentity();
    transform.translateByDouble(origin.dx, origin.dy, 0.0, 1.0);
    transform.multiply(inner);
    transform.translateByDouble(-origin.dx, -origin.dy, 0.0, 1.0);

    layer = context.pushTransform(
      true,
      offset,
      transform,
      _paintFiltered,
      oldLayer: layer as TransformLayer?,
    );
  }

  void _paintFiltered(PaintingContext context, Offset offset) {
    final filter = _blurFilter;
    if (filter == null) {
      _paintChild(context, offset);
      return;
    }
    final blurLayer = _blurLayerHandle.layer ??= ImageFilterLayer();
    blurLayer.imageFilter = filter;
    context.pushLayer(blurLayer, _paintChild, offset);
  }

  void _paintChild(PaintingContext context, Offset offset) => context.paintChild(child!, offset);

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    transform.multiply(_paintTransform);
  }
}

/// three dots filling across an instrumental gap, pulsing right before the next line lands.
class _LyricsInterludeDots extends StatefulWidget {
  final Duration start;
  final Duration? end;
  final Color color;
  final double dotRadius;

  const _LyricsInterludeDots({
    required this.start,
    required this.end,
    required this.color,
    required this.dotRadius,
  });

  @override
  State<_LyricsInterludeDots> createState() => _LyricsInterludeDotsState();
}

class _LyricsInterludeDotsState extends State<_LyricsInterludeDots> with SingleTickerProviderStateMixin {
  static const _resyncToleranceMicros = 250 * 1000;

  late final _progress = AnimationController.unbounded(vsync: this);

  @override
  void initState() {
    super.initState();
    _sync();
    Player.inst.nowPlayingPosition.addListener(_sync);
    Player.inst.playWhenReady.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant _LyricsInterludeDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start || oldWidget.end != widget.end) _sync();
  }

  @override
  void dispose() {
    Player.inst.nowPlayingPosition.removeListener(_sync);
    Player.inst.playWhenReady.removeListener(_sync);
    _progress.dispose();
    super.dispose();
  }

  void _sync() {
    final end = widget.end;
    if (end == null) return;
    final startMicros = widget.start.inMicroseconds;
    final totalMicros = end.inMicroseconds - startMicros;
    if (totalMicros <= 0) return;

    final posMicros = Player.inst.nowPlayingPosition.value * 1000;
    final exact = ((posMicros - startMicros) / totalMicros).clampDouble(0.0, 1.0);
    if ((exact - _progress.value).abs() * totalMicros > _resyncToleranceMicros) _progress.value = exact;

    final remainingMicros = end.inMicroseconds - posMicros;
    if (Player.inst.playWhenReady.value && remainingMicros > 0 && exact < 1.0) {
      _progress.animateTo(
        1.0,
        duration: Duration(microseconds: remainingMicros),
        curve: Curves.linear,
      );
    } else {
      _progress.stop();
      _progress.value = exact;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.dotRadius;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(radius * 8.0, radius * 3.0),
        painter: _LyricsInterludeDotsPainter(
          progress: _progress,
          color: widget.color,
          dotRadius: radius,
        ),
      ),
    );
  }
}

class _LyricsInterludeDotsPainter extends CustomPainter {
  static const _count = 3;
  static const _pulseStart = 0.88;

  final Animation<double> progress;
  final Color color;
  final double dotRadius;

  _LyricsInterludeDotsPainter({
    required this.progress,
    required this.color,
    required this.dotRadius,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final value = progress.value.clampDouble(0.0, 1.0);
    final pulse = value <= _pulseStart ? 0.0 : math.sin((value - _pulseStart) / (1.0 - _pulseStart) * math.pi);
    final gap = dotRadius * 3.0;
    final firstX = size.width * 0.5 - gap;
    final centerY = size.height * 0.5;
    final baseAlpha = color.a;
    final paint = Paint();
    for (int i = 0; i < _count; i++) {
      final fill = (value * _count - i).clampDouble(0.0, 1.0);
      paint.color = color.withValues(alpha: baseAlpha * (0.25 + 0.75 * fill));
      canvas.drawCircle(
        Offset(firstX + gap * i, centerY),
        dotRadius * (0.55 + 0.45 * fill + 0.28 * pulse),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LyricsInterludeDotsPainter old) => old.color != color || old.dotRadius != dotRadius;
}

/// hidden lyrics would otherwise keep ticking behind a zero opacity, producing frames on whatever page is shown.
class _TickerModeWhileVisible extends StatefulWidget {
  final Animation<double> opacity;
  final Animation<double> secondaryOpacity;
  final Widget child;

  const _TickerModeWhileVisible({
    required this.opacity,
    required this.secondaryOpacity,
    required this.child,
  });

  @override
  State<_TickerModeWhileVisible> createState() => _TickerModeWhileVisibleState();
}

class _TickerModeWhileVisibleState extends State<_TickerModeWhileVisible> {
  late bool _visible = _isVisible();

  bool _isVisible() => widget.opacity.value > 0.0 && widget.secondaryOpacity.value > 0.0;

  void _onOpacityChanged() {
    final visible = _isVisible();
    if (visible != _visible) setState(() => _visible = visible);
  }

  void _listen(_TickerModeWhileVisible widget) {
    widget.opacity.addListener(_onOpacityChanged);
    widget.secondaryOpacity.addListener(_onOpacityChanged);
  }

  void _unlisten(_TickerModeWhileVisible widget) {
    widget.opacity.removeListener(_onOpacityChanged);
    widget.secondaryOpacity.removeListener(_onOpacityChanged);
  }

  @override
  void initState() {
    super.initState();
    _listen(widget);
  }

  @override
  void didUpdateWidget(covariant _TickerModeWhileVisible oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.opacity, widget.opacity) && identical(oldWidget.secondaryOpacity, widget.secondaryOpacity)) return;
    _unlisten(oldWidget);
    _listen(widget);
    _visible = _isVisible();
  }

  @override
  void dispose() {
    _unlisten(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: _visible,
      child: widget.child,
    );
  }
}

class _LyricsList extends StatefulWidget {
  final double verticalPadding;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final _LyricsScrollTick scrollTick;
  final void Function(_LyricsListState state) onInit;
  final void Function(_LyricsListState state) onDispose;

  const _LyricsList({
    super.key,
    required this.verticalPadding,
    required this.itemCount,
    required this.itemBuilder,
    required this.scrollTick,
    required this.onInit,
    required this.onDispose,
  });

  @override
  State<_LyricsList> createState() => _LyricsListState();
}

class _LyricsListState extends State<_LyricsList> {
  final _listController = ListController();
  final _scrollController = NamidaScrollController.create();

  bool get canScroll => _listController.isAttached && _scrollController.hasClients;

  @override
  void initState() {
    super.initState();
    widget.onInit(this);
    _scrollController.addListener(widget.scrollTick.tick);
  }

  @override
  void dispose() {
    widget.onDispose(this);
    _scrollController.removeListener(widget.scrollTick.tick);
    _listController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // -- [ListController.animateToItem] spawns an animation that outlives the list, crashing on unmount.
  // -- [ScrollPosition.animateTo] is cancelled when the position is disposed.
  void scrollToIndex(int index, {required bool jump}) {
    final position = _scrollController.position;
    // ignore: invalid_use_of_visible_for_testing_member
    final offset = _listController.getOffsetToReveal(index, _LyricsEffects.listAlignment).clampDouble(position.minScrollExtent, position.maxScrollExtent);
    if (offset == position.pixels) return;
    if (jump) {
      position.jumpTo(offset);
    } else {
      final plan = _LyricsScrollPlan.forDelta(offset - position.pixels, position.viewportDimension);
      position.animateTo(offset, duration: plan.duration, curve: plan.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LyricsViewportTick(
      scrollTick: widget.scrollTick,
      child: SuperSmoothListView.builder(
        padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
        controller: _scrollController,
        listController: _listController,
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder,
      ),
    );
  }
}

/// lines read the viewport height to place themselves against the focal point, but a height-only
/// change keeps their own constraints identical, so nothing would repaint them. this ticks on it.
class _LyricsViewportTick extends SingleChildRenderObjectWidget {
  final _LyricsScrollTick scrollTick;

  const _LyricsViewportTick({
    required this.scrollTick,
    required super.child,
  });

  @override
  _RenderLyricsViewportTick createRenderObject(BuildContext context) => _RenderLyricsViewportTick(scrollTick);

  @override
  void updateRenderObject(BuildContext context, _RenderLyricsViewportTick renderObject) {
    renderObject.scrollTick = scrollTick;
  }
}

class _RenderLyricsViewportTick extends RenderProxyBox {
  _RenderLyricsViewportTick(this._scrollTick);

  _LyricsScrollTick _scrollTick;
  set scrollTick(_LyricsScrollTick value) {
    if (identical(_scrollTick, value)) return;
    _scrollTick = value;
    markNeedsLayout();
  }

  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    if (_lastSize != size) {
      _lastSize = size;
      _scrollTick.tick();
    }
  }
}

class LyricsOverlayBackdrop extends StatelessWidget {
  final ValueListenable<double> mpAnimation;
  final ValueListenable<double> visibility;
  final Widget child;

  const LyricsOverlayBackdrop({
    super.key,
    required this.mpAnimation,
    required this.visibility,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = context.theme.scaffoldBackgroundColor;
    final animation = Listenable.merge([mpAnimation, visibility]);
    return Obx(
      (context) {
        final maskColor = Color.alphaBlend(CurrentColor.inst.miniplayerColor.withOpacityExt(0.25), bgColor);
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final factor = mpAnimation.value * visibility.value;
            return NamidaBlur(
              blur: 12.0 * factor,
              fixArtifacts: true,
              child: Stack(
                children: [
                  child!,
                  Positioned.fill(
                    child: ColoredBox(
                      color: maskColor.withOpacityExt(0.25 * factor),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// vertical band + x position of the sweep boundary, resolved once per frame.
typedef _KaraokeSweep = ({double top, double bottom, double boundaryX, bool ltr});

typedef _KaraokeLayoutKey = ({double maxWidth, TextScaler textScaler, TextStyle style, Color accent, bool isDark, TextAlign textAlign, TextDirection textDirection});
