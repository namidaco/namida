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
import 'package:namida/ui/widgets/lyrics_karaoke_text.dart';
import 'package:namida/ui/widgets/player_transport_controls.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class LyricsLRCParsedView extends StatefulWidget {
  static const minFontScale = 0.5;
  static const maxFontScale = 2.0;

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
    settings.fontScaleLRC.addListener(_onFontScaleSettingChanged);
    if (_largeText) settings.fontScaleLRCFull.addListener(_onFontScaleSettingChanged);
    final lrc = Lyrics.inst.currentLyricsLRC.value;
    final txt = Lyrics.inst.currentLyricsText.value;
    fillLists(lrc, txt);
    Player.inst.nowPlayingPosition.addListener(_playerPositionListener);
  }

  Lrc? currentLRC;

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
    _lineResolver = LrcLineResolver.empty;
    _lineEndsMS = Int32List(0);
    _overlapEndMS = _kNoOverlapEndMS;
    if (hide) _updateIsCurrentLineEmpty(true);
    _latestUpdatedLineInfo.value = null;
    _currentIndex = null;
  }

  void _fillListsNow(Lrc? lrc, LrcText? txt) {
    currentLRC = lrc;
    if (lrc == null) {
      highlightTimestampsMap = {};
      lyrics = [];
      _lineResolver = LrcLineResolver.empty;
      _lineEndsMS = Int32List(0);
      _overlapEndMS = _kNoOverlapEndMS;
      final isTextEmpty = txt == null ? true : _checkIfTextEmpty(txt.text);
      _updateIsCurrentLineEmpty(isTextEmpty);
      return;
    } else {
      _updateIsCurrentLineEmpty(_updateOpacityForEmptyLines ? _checkIfTextEmpty(lrc.lyrics.firstOrNull?.lyrics ?? '') : false);
    }

    final stretchMultiplier = Lyrics.inst.getStretchMultiplier(lrc);
    final uiInfo = lrc.forUiDisplay(
      stretchMultiplier,
      durationDifferenceToInsertEmptyLine: const Duration(seconds: 1),
      extraOffsetDuration: Duration(milliseconds: settings.visualDelayMS.value),
      romanizer: Romanizer.inst.lyricsRomanizer(lrc),
    );

    lyrics = uiInfo.uiLyricsLines;
    highlightTimestampsMap = uiInfo.highlightTimestampsMap;
    _lineResolver = uiInfo.lineResolver;
    _lineEndsMS = _computeLineEndsMS(lyrics);
    _overlapEndMS = _kNoOverlapEndMS;

    _updateHighlightedLine(Player.inst.nowPlayingPosition.value, jump: true);
  }

  /// last word end, the original's end for romanized copies, next line start for plain lines, -1 for bg lines.
  static Int32List _computeLineEndsMS(List<LrcLine> lyrics) {
    final length = lyrics.length;
    final ends = Int32List(length);
    for (int i = 0; i < length; i++) {
      final line = lyrics[i];
      if (line.isBGLyrics) {
        ends[i] = -1;
        continue;
      }
      final parts = line.parts;
      if (parts != null && parts.isNotEmpty) {
        ends[i] = parts.last.endTimestamp.inMilliseconds;
      } else if (i > 0 && lyrics[i - 1].timestamp == line.timestamp) {
        ends[i] = ends[i - 1];
      } else {
        ends[i] = i + 1 < length ? lyrics[i + 1].timestamp.inMilliseconds : -1;
      }
    }
    return ends;
  }

  /// earliest end among the lines before [currentIndex] whose words still run past [positionMS].
  int _nextOverlapEndMS(int currentIndex, int positionMS) {
    final ends = _lineEndsMS;
    var earliest = _kNoOverlapEndMS;
    for (int i = currentIndex - 1; i >= 0; i--) {
      final endMS = ends[i];
      if (endMS > positionMS && endMS < earliest) earliest = endMS;
    }
    return earliest;
  }

  void _playerPositionListener() {
    final position = Player.inst.nowPlayingPosition.value;
    _updateHighlightedLine(position);
  }

  void _updateHighlightedLine(int durMS, {bool force = false, bool forceAnimate = false, bool jump = false}) {
    final newIndex = _lineResolver.indexAt(durMS);
    if (newIndex < 0) return;
    final newLineDuration = lyrics[newIndex].timestamp;

    // -- prefer index checks, cuz duration is used in ui directly to highlight
    // -- and index can be used to force reset (to force scroll to current line) etc
    // if (!force && _latestUpdatedLineInfo.value?.$1 == newLineDuration) return;

    if (newIndex + 1 == lyrics.length) {
      final alreadyHighlightingLastLine = _currentIndex == newIndex;
      if (alreadyHighlightingLastLine) return; // overscrolling
    }

    final didOverlapEnd = durMS >= _overlapEndMS;
    if (!force && !didOverlapEnd && _currentIndex == newIndex) return;

    // -- stable per highlight state, so repeated ticks don't refresh the list
    final positionMS = didOverlapEnd ? _overlapEndMS : newLineDuration.inMilliseconds;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlapEndMS = _nextOverlapEndMS(newIndex, positionMS);
      _latestUpdatedLineInfo.value = (newLineDuration, newIndex, positionMS);

      if (_canAnimateScroll.value || forceAnimate) {
        _currentIndex = newIndex;
        final list = _list;
        if (list != null && list.canScrollTo(newIndex)) list.scrollToIndex(newIndex, jump: jump);
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
      if (index != null && identical(_list, state) && state.canScrollTo(index)) state.scrollToIndex(index, jump: true);
    });
  }

  void _onListDispose(_LyricsListState state) {
    if (identical(_list, state)) _list = null;
  }

  Timer? _scrollTimer;
  final _canAnimateScroll = true.obs;

  final _scrollTick = _LyricsScrollTick();

  final _latestUpdatedLineInfo = Rxn<(Duration? timestamp, int? index, int positionMS)>();

  var lyrics = <LrcLine>[];
  var highlightTimestampsMap = <Duration, List<int>>{}; // timestamp: [index]
  var _lineResolver = LrcLineResolver.empty;
  var _lineEndsMS = Int32List(0);

  static const _kNoOverlapEndMS = 1 << 62;

  /// position at which an earlier, still highlighted line ends and needs the highlight recomputed
  int _overlapEndMS = _kNoOverlapEndMS;

  late final bool _largeText = widget.isFullScreenView || widget.largeText;
  late double _previousFontMultiplier = _fontMultiplier;
  late double _fontMultiplier = _getFontMultiplierSetting();

  double _getFontMultiplierSetting() {
    final normalMultiplier = settings.fontScaleLRC.value;
    if (!_largeText) return normalMultiplier;
    return settings.fontScaleLRCFull.value ?? normalMultiplier;
  }

  void _onFontScaleSettingChanged() => _setFontMultiplier(_getFontMultiplierSetting());

  void _setFontMultiplier(double value) {
    value = value.clampDouble(LyricsLRCParsedView.minFontScale, LyricsLRCParsedView.maxFontScale);
    if (value == _fontMultiplier) return;
    refreshState(() => _fontMultiplier = value);
  }

  void _saveFontMultiplier() {
    _largeText ? settings.fontScaleLRCFull.save(_fontMultiplier) : settings.fontScaleLRC.save(_fontMultiplier);
  }

  @override
  void dispose() {
    _mountedViews.remove(this);
    settings.fontScaleLRC.removeListener(_onFontScaleSettingChanged);
    if (_largeText) settings.fontScaleLRCFull.removeListener(_onFontScaleSettingChanged);
    _cardSlide.removeListener(_onCardSlideTick);
    widget.visibilityNotifier?.value = 0.0;
    _visibility.dispose();
    Player.inst.nowPlayingPosition.removeListener(_playerPositionListener);

    _latestUpdatedLineInfo.close();
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
                    final lineEndsMS = _lineEndsMS;

                    final lrcListChild = ObxO(
                      key: const ValueKey('lrc_list'),
                      rx: _latestUpdatedLineInfo,
                      builder: (context, selectedInfo) {
                        final selectedIndex = selectedInfo?.$2;
                        final selectedLineTimestamp = selectedInfo?.$1;
                        final positionMS = selectedInfo?.$3 ?? 0;
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
                                    final hasParts = parts != null && parts.isNotEmpty;
                                    final person = lrc.person;
                                    final isBGLyrics = lrc.isBGLyrics;
                                    final indicesForTimestamp = highlightTimestampsMap[lrc.timestamp];
                                    final textDirection = lrc.isRTL == true ? TextDirection.rtl : TextDirection.ltr;

                                    final isEarlierLineStillRunning = distanceDiffFromSelected != null && distanceDiffFromSelected < 0 && lineEndsMS[index] > positionMS;
                                    final selected = distanceDiffFromSelected == 0 || isBGLyrics || selectedLineTimestamp == lrc.timestamp || isEarlierLineStillRunning;
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
                                    } else if (selected && (hasParts || (!isBGLyrics && !selectedAndEmpty))) {
                                      final lastIndexForTimestamp = indicesForTimestamp?.last ?? index;
                                      final nextLineIndex = lastIndexForTimestamp + 1;
                                      final lineEnd = nextLineIndex < lyrics.length ? lyrics[nextLineIndex].timestamp : null;
                                      textWidget = LyricsKaraokeText(
                                        line: lrc,
                                        lineEnd: lineEnd,
                                        textStyle: textStyle,
                                        textAlign: textAlign,
                                        textDirection: textDirection,
                                        accentColor: miniplayerColor,
                                        isDark: isDark,
                                        effects: _LyricsEffects.karaoke,
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

  /// the current line's karaoke sweep, lines without word timing get a short reveal or a whole-line sweep.
  static const karaoke = LyricsKaraokeEffects(
    accentTint: true,
    glow: true,
    wordBump: true,
    shimmer: true,
    feather: true,
    untimedLineSweep: false,
  );

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

  // -- the list may still be the previous track's while the new lyrics are already swapped in
  bool canScrollTo(int index) => index < widget.itemCount && _listController.isAttached && _scrollController.hasClients;

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
      return;
    }
    final plan = _LyricsScrollPlan.forDelta(offset - position.pixels, position.viewportDimension);
    if (position is ScrollPositionWithSingleContext) {
      final activity = _TappableDrivenScrollActivity(
        position,
        from: position.pixels,
        to: offset,
        duration: plan.duration,
        curve: plan.curve,
        vsync: position.context.vsync,
      );
      position.beginActivity(activity);
    } else {
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

// by claude
/// [DrivenScrollActivity] ignores pointers, so a line tapped while the list glides to the next one would miss.
class _TappableDrivenScrollActivity extends DrivenScrollActivity {
  _TappableDrivenScrollActivity(
    super.delegate, {
    required super.from,
    required super.to,
    required super.duration,
    required super.curve,
    required super.vsync,
  });

  @override
  bool get shouldIgnorePointer => false;
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
