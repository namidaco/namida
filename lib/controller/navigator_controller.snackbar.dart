// merge groups by claude

part of 'navigator_controller.dart';

final _snackbarsStackManager = _SnackbarStackManager();

final _mergedSnackbars = <_SnackbarMergeKey, _MergedSnackbar>{};

const _kSnackbarDismissHintMaxCount = 3;

SnackbarController snackyy({
  IconData? icon,
  Widget? iconWidget,
  String title = '',
  required String message,
  bool top = true,
  void Function(SnackbarStatus status)? onStatusChanged,
  EdgeInsetsGeometry margin = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
  bool altDesign = false,
  int animationDurationMS = 600,
  SnackDisplayDuration displayDuration = SnackDisplayDuration.medium,
  double borderRadius = 12.0,
  Color? leftBarIndicatorColor,
  Color? borderColor,
  SnackbarButton? button,
  bool? isError,
  int? maxLinesMessage,
  SnackbarType? type,
  SnackbarMerge? merge,
}) {
  final visibleMergedSnackbar = merge == null ? null : _mergedSnackbars[merge._key];
  if (merge != null && visibleMergedSnackbar != null) {
    visibleMergedSnackbar.addCount(merge.count);
    return visibleMergedSnackbar.controller;
  }
  final mergedSnackbar = merge == null ? null : _MergedSnackbar(merge);

  isError ??= title == lang.error;
  final context = namida.context;
  final view = context?.view ?? namida.platformView;
  final backgroundColor = context?.theme.scaffoldBackgroundColor.withOpacityExt(0.3) ?? Colors.black54;
  final itemsColor = context?.theme.colorScheme.onSurface.withOpacityExt(0.7) ?? Colors.white54;
  final accentColor = context?.theme.colorScheme.primary ?? itemsColor;
  final hasAction = button != null;
  final isShortDisplay = displayDuration.milliseconds <= SnackDisplayDuration.mediumLow.milliseconds;
  final isReducedAnimations = WidgetsBinding.instance.disableAnimations;
  final shouldShowCountdown = hasAction && !isShortDisplay && !isReducedAnimations;

  final dismissHintEndMS = animationDurationMS + NamSnackBar.kDismissHintDuration.inMilliseconds;
  final dismissHintCount = settings.tutorial.snackbarDismissHintCount.value;
  final shouldHintDismiss = dismissHintCount < _kSnackbarDismissHintMaxCount && displayDuration.milliseconds >= dismissHintEndMS;
  if (shouldHintDismiss) settings.tutorial.snackbarDismissHintCount.save(dismissHintCount + 1);

  final displayDurationEffective = Duration(milliseconds: displayDuration.milliseconds);
  final animationDuration = Duration(milliseconds: animationDurationMS);

  TextStyle getTextStyle(FontWeight fontWeight, double size, {bool action = false}) => TextStyle(
    fontWeight: fontWeight,
    fontSize: size,
    height: 1.25,
    color: action ? null : itemsColor,
    fontFamily: AppThemes.fontFamily,
    fontFamilyFallback: AppThemes.fontFamilyFallback,
  );

  // -- currently has no effects cuz it looks dogshit
  // if (altDesign) {
  //   borderRadius = 0;
  //   margin = EdgeInsets.zero;
  // }

  late SnackbarController snackbarController;

  final EdgeInsets paddingInsets;
  if (button != null) {
    if (title.isNotEmpty && message.isNotEmpty) {
      paddingInsets = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
    } else {
      paddingInsets = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
    }
  } else if (icon != null || iconWidget != null || title != '') {
    paddingInsets = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  } else {
    paddingInsets = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0);
  }

  bool alreadyTappedButton = false;

  double? snackWidth = view == null ? null : view.physicalSize.shortestSide / (view.devicePixelRatioWithScale);
  if (snackWidth != null && Dimensions.inst.miniplayerIsWideScreen) {
    snackWidth = snackWidth.withMaximum(Dimensions.inst.availableAppContentWidth - margin.horizontal * 2 - kFABSize);
  }
  final desktopTopMargin = WindowController.instance?.windowTitleBarHeightIfActive ?? 0.0;
  if (desktopTopMargin > 0) {
    margin = margin.add(EdgeInsetsGeometry.only(top: desktopTopMargin));
  }

  final messageStyle = title != '' ? getTextStyle(FontWeight.w400, 13.0) : getTextStyle(FontWeight.w600, 14.0);
  final latestCountStyle = messageStyle.copyWith(fontWeight: FontWeight.w700, color: accentColor);
  final messageWidget = mergedSnackbar == null
      ? Text(
          message,
          style: messageStyle,
          maxLines: maxLinesMessage,
          overflow: maxLinesMessage == null ? null : TextOverflow.ellipsis,
        )
      : _SnackbarMergedMessage(
          mergedSnackbar: mergedSnackbar,
          initialMessage: message,
          style: messageStyle,
          latestCountStyle: latestCountStyle,
        );

  final content = Theme(
    data: context?.theme ?? material.ThemeData(),
    child: Padding(
      padding: paddingInsets,
      child: SizedBox(
        width: snackWidth,
        child: Row(
          children: [
            if (iconWidget != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: iconWidget,
              )
            else if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(icon, color: itemsColor),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != '')
                    Text(
                      title,
                      style: getTextStyle(FontWeight.w700, 16),
                    ),
                  messageWidget,
                ],
              ),
            ),
            if (button != null) const SizedBox(width: 8.0),
            if (button != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: snackWidth == null ? double.infinity : snackWidth * 0.4),
                child: button.icon != null
                    ? IconButton(
                        tooltip: button.text,
                        onPressed: button.function,
                        icon: Icon(
                          button.icon!,
                          size: 20.0,
                        ),
                      )
                    : NamidaButton(
                        colors: .mid,
                        onTap: () {
                          if (alreadyTappedButton) return;
                          alreadyTappedButton = true;
                          button.function();
                          snackbarController.close();
                        },
                        icon: button.icon,
                        tooltip: () => button.text,
                        text: button.icon != null ? null : button.text,
                      ),
              ),
          ],
        ),
      ),
    ),
  );
  final contentWithIndicator = leftBarIndicatorColor != null
      ? DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: leftBarIndicatorColor, width: 4.5)),
          ),
          child: content,
        )
      : content;

  final Widget snackbarBody;
  if (shouldShowCountdown) {
    final countdownBaseColor = isError ? itemsColor : leftBarIndicatorColor ?? accentColor;
    final countdownColor = countdownBaseColor.withOpacityExt(0.35);
    snackbarBody = Stack(
      children: [
        contentWithIndicator,
        Positioned(
          left: 0.0,
          right: 0.0,
          bottom: 0.0,
          height: 2.0,
          child: _SnackbarCountdownLine(
            color: countdownColor,
            fadeInDelay: animationDuration,
          ),
        ),
      ],
    );
  } else {
    snackbarBody = contentWithIndicator;
  }

  final snackbar = NamSnackBar(
    margin: margin,
    duration: displayDurationEffective,
    animationDuration: animationDuration,
    alignment: Alignment.centerLeft,
    top: top,
    forwardAnimationCurve: Curves.fastLinearToSlowEaseIn,
    reverseAnimationCurve: Curves.easeInOutQuart,
    dismissHint: shouldHintDismiss,
    onStatusChanged: onStatusChanged,
    child: Material(
      color: Colors.transparent,
      type: MaterialType.transparency,
      child: NamidaBgBlurClipped(
        blur: 12.0,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius == 0 ? null : BorderRadius.circular(borderRadius.multipliedRadius),
          border: isError
              ? Border.all(
                  color: borderColor ?? Colors.red.withOpacityExt(0.2),
                  width: 1.5,
                )
              : Border.all(
                  color: borderColor ?? Colors.grey.withOpacityExt(0.5),
                  width: 0.5,
                ),
          boxShadow: isError
              ? [
                  BoxShadow(
                    color: Colors.red.withAlpha(15),
                    blurRadius: 16.0,
                  ),
                ]
              : null,
        ),
        child: snackbarBody,
      ),
    ),
  );

  snackbarController = SnackbarController(snackbar);
  _snackbarsStackManager.add(type, snackbarController);
  if (mergedSnackbar != null) {
    mergedSnackbar.controller = snackbarController;
    _mergedSnackbars[mergedSnackbar.merge._key] = mergedSnackbar;
  }
  snackbarController.show().whenComplete(
    () {
      _snackbarsStackManager.remove(snackbarController);
      if (mergedSnackbar != null) {
        _mergedSnackbars.remove(mergedSnackbar.merge._key);
        mergedSnackbar.dispose();
      }
    },
  );
  return snackbarController;
}

class _SnackbarStackManager {
  final _topStack = <_StackedSnackbar>[];
  final _bottomStack = <_StackedSnackbar>[];

  List<_StackedSnackbar> _getStack(SnackbarController controller) => controller.snackbar.top ? _topStack : _bottomStack;

  void add(SnackbarType? type, SnackbarController controller) {
    final stack = _getStack(controller);

    // -- X close previous snackbars of the same type (null excluded)
    // -- but sadly can result in snackbars instantly nuked,
    // -- main issue is better solved inside [_refreshCovered]
    // if (type != null) {
    //   for (final s in stack) {
    //     if (s.type == type) s.controller.close();
    //   }
    // }
    stack.add((type: type, controller: controller));
    _refreshCovered(stack);
  }

  void remove(SnackbarController controller) {
    final stack = _getStack(controller);
    stack.removeWhere((s) => s.controller == controller);
    _refreshCovered(stack);
  }

  void _refreshCovered(List<_StackedSnackbar> stack) {
    final lastIndex = stack.length - 1;
    for (int i = 0; i <= lastIndex; i++) {
      final s = stack[i];
      final waitsWhileCovered = s.type == null;
      if (!waitsWhileCovered) continue;
      final isCovered = i != lastIndex;
      s.controller.setCovered(isCovered);
    }
  }
}

class _MergedSnackbar extends ChangeNotifier {
  final SnackbarMerge merge;
  int total;
  int latestCount = 0;
  late final SnackbarController controller;

  _MergedSnackbar(this.merge) : total = merge.count;

  void addCount(int count) {
    total += count;
    latestCount = count;
    notifyListeners();
    controller.restartDuration();
  }
}

class _SnackbarMergedMessage extends StatefulWidget {
  final _MergedSnackbar mergedSnackbar;
  final String initialMessage;
  final TextStyle style;
  final TextStyle latestCountStyle;

  const _SnackbarMergedMessage({
    required this.mergedSnackbar,
    required this.initialMessage,
    required this.style,
    required this.latestCountStyle,
  });

  @override
  State<_SnackbarMergedMessage> createState() => _SnackbarMergedMessageState();
}

class _SnackbarMergedMessageState extends State<_SnackbarMergedMessage> with SingleTickerProviderStateMixin {
  static final _latestCountFadeIn = Tween(begin: 0.0, end: 1.0);
  static final _latestCountFadeOut = Tween(begin: 1.0, end: 0.0);
  static final _latestCountOpacityTween = TweenSequence<double>([
    TweenSequenceItem(tween: _latestCountFadeIn, weight: 15.0),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 50.0),
    TweenSequenceItem(tween: _latestCountFadeOut, weight: 35.0),
  ]);

  late final _latestCountController = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );
  late final _latestCountOpacity = _latestCountOpacityTween.animate(_latestCountController);

  late String _message = widget.initialMessage;
  String _latestCountText = '';

  @override
  void initState() {
    super.initState();
    widget.mergedSnackbar.addListener(_onCountAdded);
  }

  @override
  void dispose() {
    widget.mergedSnackbar.removeListener(_onCountAdded);
    _latestCountController.dispose();
    super.dispose();
  }

  void _onCountAdded() {
    final mergedSnackbar = widget.mergedSnackbar;
    refreshState(() {
      _message = mergedSnackbar.merge.toMessage(mergedSnackbar.total);
      _latestCountText = '+${mergedSnackbar.latestCount}';
    });
    _latestCountController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            _message,
            style: widget.style,
          ),
        ),
        const SizedBox(width: 6.0),
        FadeTransition(
          opacity: _latestCountOpacity,
          child: Text(
            _latestCountText,
            style: widget.latestCountStyle,
          ),
        ),
      ],
    );
  }
}

class _SnackbarCountdownLine extends StatefulWidget {
  final Color color;
  final Duration fadeInDelay;

  const _SnackbarCountdownLine({
    required this.color,
    required this.fadeInDelay,
  });

  @override
  State<_SnackbarCountdownLine> createState() => _SnackbarCountdownLineState();
}

class _SnackbarCountdownLineState extends State<_SnackbarCountdownLine> with SingleTickerProviderStateMixin {
  static const _kFadeInDuration = Duration(milliseconds: 1200);

  late final AnimationController _fadeInController;
  late final CurvedAnimation _fadeIn;

  @override
  void initState() {
    super.initState();
    final fadeInDelay = widget.fadeInDelay;
    final totalDuration = fadeInDelay + _kFadeInDuration;
    final fadeInStart = fadeInDelay.inMicroseconds / totalDuration.inMicroseconds;
    final fadeInCurve = Interval(fadeInStart, 1.0, curve: Curves.easeIn);
    _fadeInController = AnimationController(duration: totalDuration, vsync: this);
    _fadeIn = CurvedAnimation(parent: _fadeInController, curve: fadeInCurve);
    _fadeInController.forward();
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    _fadeInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snackbarController = SnackbarScope.of(context);
    final countdown = snackbarController.remainingTimeFraction;
    final textDirection = Directionality.of(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SnackbarCountdownPainter(
          countdown: countdown,
          fadeIn: _fadeIn,
          color: widget.color,
          textDirection: textDirection,
        ),
      ),
    );
  }
}

class _SnackbarCountdownPainter extends CustomPainter {
  final Animation<double> countdown;
  final Animation<double> fadeIn;
  final Color color;
  final TextDirection textDirection;

  _SnackbarCountdownPainter({
    required this.countdown,
    required this.fadeIn,
    required this.color,
    required this.textDirection,
  }) : super(repaint: Listenable.merge([countdown, fadeIn]));

  final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = fadeIn.value;
    if (opacity == 0.0) return;
    final paintColor = opacity == 1.0 ? color : color.withOpacityExt(color.a * opacity);
    _paint.color = paintColor;
    final remainingWidth = size.width * countdown.value;
    final startX = textDirection == TextDirection.ltr ? 0.0 : size.width - remainingWidth;
    final rect = Rect.fromLTWH(startX, 0.0, remainingWidth, size.height);
    canvas.drawRect(rect, _paint);
  }

  @override
  bool shouldRepaint(_SnackbarCountdownPainter oldDelegate) {
    return countdown != oldDelegate.countdown || fadeIn != oldDelegate.fadeIn || color != oldDelegate.color || textDirection != oldDelegate.textDirection;
  }
}

class SnackbarMerge {
  final SnackbarMergeGroup group;
  final String id;
  final int count;
  final String Function(int total) toMessage;
  final _SnackbarMergeKey _key;

  const SnackbarMerge({
    required this.group,
    this.id = '',
    required this.count,
    required this.toMessage,
  }) : _key = (group, id);
}

class SnackbarButton {
  final String text;
  final IconData? icon;
  final FutureOr<void> Function() function;

  const SnackbarButton({
    required this.text,
    this.icon,
    required this.function,
  });
}

enum SnackDisplayDuration {
  flash(500),
  short(1000),
  mediumLow(1500),
  medium(2000),
  mediumHigh(2500),
  long(3000),
  veryLong(4000),
  eternal(5000),
  tutorial(8000),
  ;

  final int milliseconds;
  const SnackDisplayDuration(this.milliseconds);
}

enum SnackbarType {
  playerInfo,
}

enum SnackbarMergeGroup {
  queueAddTracks,
  queueInsertTracks,
  queueAddVideos,
  queueInsertVideos,
  playlistAddTracks,
  playlistAddVideos,
}

typedef _SnackbarMergeKey = (SnackbarMergeGroup, String);

typedef _StackedSnackbar = ({SnackbarType? type, SnackbarController controller});
