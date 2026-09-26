// by claude
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class ZoomableImage extends StatefulWidget {
  final ImageProvider imageProvider;
  final Widget? placeholder;
  final Object? heroTag;
  final VoidCallback? onTap;
  final Axis? pagingAxis;
  final FilterQuality filterQuality;

  const ZoomableImage({
    super.key,
    required this.imageProvider,
    this.placeholder,
    this.heroTag,
    this.onTap,
    this.pagingAxis,
    this.filterQuality = FilterQuality.medium,
  });

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> with TickerProviderStateMixin {
  static const _kImageKey = ValueKey('image');

  final _transform = _ZoomTransform();
  _ImageLevels? _levels;
  bool _hasImage = false;
  bool _hasContentSize = false;

  @override
  void initState() {
    super.initState();
    _transform.onViewportChanged = _updateLevel;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final view = View.of(context);
    _transform.devicePixelRatio = view.devicePixelRatio;
    if (_levels == null) _acquireLevels(view.physicalSize);
  }

  @override
  void didUpdateWidget(ZoomableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      _releaseLevels();
      _transform.reset();
      _hasImage = false;
      _hasContentSize = false;
      final view = View.of(context);
      _acquireLevels(view.physicalSize);
    }
  }

  @override
  void dispose() {
    _zoomAnimation.dispose();
    _flingAnimation.dispose();
    _releaseLevels();
    _transform.dispose();
    super.dispose();
  }

  void _acquireLevels(Size baseTargetPx) {
    final levels = _ImageLevels.acquire(widget.imageProvider, baseTargetPx);
    levels.addListener(_onLevelsChanged);
    _levels = levels;
    _syncFromLevels();
    _hasImage = _transform.image != null;
    _hasContentSize = !_transform.contentSize.isEmpty;
  }

  void _releaseLevels() {
    final levels = _levels;
    if (levels == null) return;
    levels.removeListener(_onLevelsChanged);
    levels.release();
    _levels = null;
  }

  void _onLevelsChanged() {
    _syncFromLevels();
    final hasImage = _transform.image != null;
    final hasContentSize = !_transform.contentSize.isEmpty;
    if (hasImage == _hasImage && hasContentSize == _hasContentSize) return;
    setState(() {
      _hasImage = hasImage;
      _hasContentSize = hasContentSize;
    });
  }

  void _syncFromLevels() {
    final levels = _levels;
    if (levels == null) return;
    final preview = levels.preview;
    if (levels.nativeWidth > 0) {
      final nativeSize = Size(levels.nativeWidth.toDouble(), levels.nativeHeight.toDouble());
      _transform.setContent(nativeSize, isNative: true);
    } else if (preview != null) {
      final previewSize = Size(preview.width.toDouble(), preview.height.toDouble());
      _transform.setContent(previewSize, isNative: false);
    }
    _updateLevel();
  }

  int _levelFor(double scale) {
    final t = _transform;
    final requiredWidthPx = t.contentSize.width * scale * t.devicePixelRatio;
    return _levels!.levelForWidthPx(requiredWidthPx);
  }

  void _updateLevel() {
    final levels = _levels;
    if (levels == null || _transform.contentSize.isEmpty) return;
    final level = _levelFor(_transform.scale);
    levels.ensureLevel(level);
    final leveledImage = level == 0 ? levels.base : levels.highest;
    _transform.image = leveledImage ?? levels.preview;
  }

  late final AnimationController _zoomAnimation = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..addListener(_onZoomTick);
  double _zoomFromScale = 1.0;
  double _zoomToScale = 1.0;
  Offset _zoomFromTranslation = Offset.zero;
  Offset _zoomToTranslation = Offset.zero;

  void _animateTo(double scale, Offset translation) {
    _flingAnimation.stop();
    _zoomFromScale = _transform.scale;
    _zoomFromTranslation = _transform.translation;
    _zoomToScale = scale;
    _zoomToTranslation = translation;
    _levels?.ensureLevel(_levelFor(scale));
    _zoomAnimation.forward(from: 0.0);
  }

  void _onZoomTick() {
    final progress = Curves.easeOutCubic.transform(_zoomAnimation.value);
    final scale = ui.lerpDouble(_zoomFromScale, _zoomToScale, progress)!;
    final translation = Offset.lerp(_zoomFromTranslation, _zoomToTranslation, progress)!;
    _transform.set(scale, translation);
    _updateLevel();
  }

  late final AnimationController _flingAnimation = AnimationController.unbounded(vsync: this)..addListener(_onFlingTick);
  Offset _flingStart = Offset.zero;
  Offset _flingDirection = Offset.zero;

  void _onFlingTick() {
    final t = _transform;
    final unclamped = _flingStart + _flingDirection * _flingAnimation.value;
    final clamped = t.clampTranslation(unclamped, t.scale);
    t.set(t.scale, clamped);
    final isBlockedX = _flingDirection.dx == 0.0 || clamped.dx != unclamped.dx;
    final isBlockedY = _flingDirection.dy == 0.0 || clamped.dy != unclamped.dy;
    if (isBlockedX && isBlockedY) _flingAnimation.stop();
  }

  double _gestureStartScale = 1.0;
  Offset _gestureStartFocal = Offset.zero;
  Offset _gestureStartTranslation = Offset.zero;

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAnimation.stop();
    _flingAnimation.stop();
    _gestureStartScale = _transform.scale;
    _gestureStartFocal = details.localFocalPoint;
    _gestureStartTranslation = _transform.translation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final t = _transform;
    if (t.contentSize.isEmpty) return;
    final minScale = t.minScale;
    final maxScale = t.maxScale;
    double scale = _gestureStartScale * details.scale;
    if (scale < minScale) {
      scale = minScale * math.pow(scale / minScale, 0.4);
    } else if (scale > maxScale) {
      scale = maxScale * math.pow(scale / maxScale, 0.4);
    }
    final translation = t.anchoredTranslation(
      anchorPosition: _gestureStartFocal,
      fromScale: _gestureStartScale,
      fromTranslation: _gestureStartTranslation,
      toScale: scale,
      toPosition: details.localFocalPoint,
    );
    t.set(scale, translation);
    _updateLevel();
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final t = _transform;
    if (t.contentSize.isEmpty) return;
    final scale = t.scale;
    final clampedScale = scale.clampDouble(t.minScale, t.maxScale);
    if (clampedScale != scale) {
      final translation = t.clampTranslation(t.translation * (clampedScale / scale), clampedScale);
      _animateTo(clampedScale, translation);
      return;
    }
    if (scale != _gestureStartScale) return;
    final velocity = details.velocity.pixelsPerSecond;
    final speed = velocity.distance;
    if (speed < 300.0) return;
    _flingStart = t.translation;
    _flingDirection = velocity / speed;
    _flingAnimation.animateWith(FrictionSimulation(0.135, 0.0, speed));
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0.0 || _transform.contentSize.isEmpty) return;
    GestureBinding.instance.pointerSignalResolver.register(event, _onScrollZoom);
  }

  void _onScrollZoom(PointerSignalEvent event) {
    final t = _transform;
    _zoomAnimation.stop();
    _flingAnimation.stop();
    final scrollDelta = (event as PointerScrollEvent).scrollDelta.dy;
    final zoomFactor = math.exp(scrollDelta * -0.002);
    final scale = (t.scale * zoomFactor).clampDouble(t.minScale, t.maxScale);
    final position = event.localPosition;
    final translation = t.anchoredTranslation(
      anchorPosition: position,
      fromScale: t.scale,
      fromTranslation: t.translation,
      toScale: scale,
      toPosition: position,
    );
    t.set(scale, translation);
    _updateLevel();
  }

  Offset _doubleTapPosition = Offset.zero;

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void _onDoubleTap() {
    final t = _transform;
    if (t.contentSize.isEmpty) return;
    if (t.scale > t.minScale * 1.02) {
      _animateTo(t.minScale, Offset.zero);
      return;
    }
    final zoomedScale = math.max(t.coverScale, t.minScale * 2.5);
    final target = zoomedScale.clampDouble(t.minScale, t.maxScale);
    final translation = t.anchoredTranslation(
      anchorPosition: _doubleTapPosition,
      fromScale: t.scale,
      fromTranslation: t.translation,
      toScale: target,
      toPosition: _doubleTapPosition,
    );
    _animateTo(target, translation);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _ZoomableImageRenderWidget(
      transform: _transform,
      filterQuality: widget.filterQuality,
    );
    final heroTag = widget.heroTag;
    if (heroTag != null) {
      child = NamidaHero(
        tag: heroTag,
        child: child,
      );
    }
    final placeholder = widget.placeholder;
    if (placeholder != null) {
      final contentSize = _transform.contentSize;
      final placeholderWidget = !_hasContentSize
          ? placeholder
          : AspectRatio(
              aspectRatio: contentSize.aspectRatio,
              child: FittedBox(
                fit: BoxFit.contain,
                child: placeholder,
              ),
            );
      child = Stack(
        alignment: Alignment.center,
        children: [
          if (!_hasImage) placeholderWidget,
          KeyedSubtree(
            key: _kImageKey,
            child: child,
          ),
        ],
      );
    }

    final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    final onTap = widget.onTap;
    final gestures = <Type, GestureRecognizerFactory>{
      if (onTap != null)
        TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(debugOwner: this),
          (instance) => instance
            ..onTap = onTap
            ..gestureSettings = gestureSettings,
        ),
      DoubleTapGestureRecognizer: GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
        () => DoubleTapGestureRecognizer(debugOwner: this),
        (instance) => instance
          ..onDoubleTapDown = _onDoubleTapDown
          ..onDoubleTap = _onDoubleTap
          ..gestureSettings = gestureSettings,
      ),
      _ZoomGestureRecognizer: GestureRecognizerFactoryWithHandlers<_ZoomGestureRecognizer>(
        () => _ZoomGestureRecognizer(transform: _transform, debugOwner: this),
        (instance) => instance
          ..pagingAxis = widget.pagingAxis
          ..dragStartBehavior = DragStartBehavior.start
          ..onStart = _onScaleStart
          ..onUpdate = _onScaleUpdate
          ..onEnd = _onScaleEnd
          ..gestureSettings = gestureSettings,
      ),
    };

    return Listener(
      onPointerSignal: _onPointerSignal,
      child: RawGestureDetector(
        gestures: gestures,
        child: child,
      ),
    );
  }
}

class _ZoomableImageRenderWidget extends LeafRenderObjectWidget {
  final _ZoomTransform transform;
  final FilterQuality filterQuality;

  const _ZoomableImageRenderWidget({
    required this.transform,
    required this.filterQuality,
  });

  @override
  _RenderZoomableImage createRenderObject(BuildContext context) => _RenderZoomableImage(transform, filterQuality);

  @override
  void updateRenderObject(BuildContext context, _RenderZoomableImage renderObject) {
    renderObject
      ..transform = transform
      ..filterQuality = filterQuality;
  }
}

class _RenderZoomableImage extends RenderBox {
  _RenderZoomableImage(this._transform, this._filterQuality);

  static const _kNearestSamplingMinPhysicalPxPerImagePx = 2.0;

  final _paint = Paint();

  _ZoomTransform _transform;
  set transform(_ZoomTransform value) {
    if (identical(_transform, value)) return;
    if (attached) {
      _transform.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _transform = value;
    markNeedsPaint();
  }

  FilterQuality _filterQuality;
  set filterQuality(FilterQuality value) {
    if (_filterQuality == value) return;
    _filterQuality = value;
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _transform.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _transform.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    _transform.setViewport(size);
  }

  @override
  bool hitTestSelf(Offset position) => _transform.imageRect().contains(position);

  @override
  void paint(PaintingContext context, Offset offset) {
    final image = _transform.image;
    if (image == null) return;
    final dst = _transform.imageRect();
    final visible = dst.intersect(Offset.zero & size);
    if (visible.isEmpty) return;
    final srcPerDstX = image.width / dst.width;
    final srcPerDstY = image.height / dst.height;
    final src = Rect.fromLTRB(
      (visible.left - dst.left) * srcPerDstX,
      (visible.top - dst.top) * srcPerDstY,
      (visible.right - dst.left) * srcPerDstX,
      (visible.bottom - dst.top) * srcPerDstY,
    );
    final physicalPxPerImagePx = _transform.devicePixelRatio / srcPerDstX;
    final isNativeLevel = _transform.isContentNative && image.width == _transform.contentSize.width;
    final shouldSampleNearest = isNativeLevel && physicalPxPerImagePx >= _kNearestSamplingMinPhysicalPxPerImagePx;
    _paint.filterQuality = shouldSampleNearest ? FilterQuality.none : _filterQuality;
    context.canvas.drawImageRect(image, src, visible.shift(offset), _paint);
  }
}

class _ZoomGestureRecognizer extends ScaleGestureRecognizer {
  _ZoomGestureRecognizer({required this.transform, super.debugOwner});

  final _ZoomTransform transform;
  Axis? pagingAxis;

  final _pointers = <int, Offset>{};

  @override
  void handleEvent(PointerEvent event) {
    final axis = pagingAxis;
    if (axis != null) {
      if (event is PointerMoveEvent) {
        if (!event.synthesized) {
          final previousFocal = _focalPoint();
          _pointers[event.pointer] = event.position;
          final focalDelta = _focalPoint() - previousFocal;
          final shouldAccept = _pointers.length > 1 || transform.canPan(focalDelta, axis);
          if (shouldAccept) acceptGesture(event.pointer);
        }
      } else if (event is PointerDownEvent) {
        _pointers[event.pointer] = event.position;
      } else if (event is PointerUpEvent || event is PointerCancelEvent) {
        _pointers.remove(event.pointer);
      }
    }
    super.handleEvent(event);
  }

  Offset _focalPoint() {
    if (_pointers.isEmpty) return Offset.zero;
    var sum = Offset.zero;
    for (final position in _pointers.values) {
      sum += position;
    }
    return sum / _pointers.length.toDouble();
  }

  @override
  void rejectGesture(int pointer) {
    _pointers.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointers.clear();
    super.didStopTrackingLastPointer(pointer);
  }
}

class _ZoomTransform extends ChangeNotifier {
  static const _kMaxPhysicalPxPerImagePx = 32.0;

  double devicePixelRatio = 1.0;
  VoidCallback? onViewportChanged;

  Size _viewport = Size.zero;
  Size _contentSize = Size.zero;
  double _minScale = 1.0;
  double _maxScale = 1.0;
  double _coverScale = 1.0;
  double _scale = 1.0;
  Offset _translation = Offset.zero;
  ui.Image? _image;
  bool _didFit = false;
  bool _isContentNative = false;

  Size get contentSize => _contentSize;
  bool get isContentNative => _isContentNative;
  double get minScale => _minScale;
  double get maxScale => _maxScale;
  double get coverScale => _coverScale;
  double get scale => _scale;
  Offset get translation => _translation;
  Offset get viewportCenter => _viewport.center(Offset.zero);

  ui.Image? get image => _image;
  set image(ui.Image? value) {
    if (identical(_image, value)) return;
    _image = value;
    notifyListeners();
  }

  void setContent(Size size, {required bool isNative}) {
    if (_contentSize == size && _isContentNative == isNative) return;
    final wasAtMin = _scale <= _minScale;
    if (!_contentSize.isEmpty) _scale *= _contentSize.width / size.width;
    _contentSize = size;
    _isContentNative = isNative;
    _recomputeBounds(shouldRefit: !_didFit || wasAtMin);
    notifyListeners();
  }

  void setViewport(Size size) {
    if (_viewport == size) return;
    final wasAtMin = _scale <= _minScale;
    _viewport = size;
    _recomputeBounds(shouldRefit: !_didFit || wasAtMin);
    onViewportChanged?.call();
  }

  void reset() {
    _contentSize = Size.zero;
    _image = null;
    _scale = 1.0;
    _translation = Offset.zero;
    _didFit = false;
    _isContentNative = false;
    notifyListeners();
  }

  void set(double scale, Offset translation) {
    if (_scale == scale && _translation == translation) return;
    _scale = scale;
    _translation = translation;
    notifyListeners();
  }

  void _recomputeBounds({required bool shouldRefit}) {
    if (_contentSize.isEmpty || _viewport.isEmpty) return;
    final fitWidth = _viewport.width / _contentSize.width;
    final fitHeight = _viewport.height / _contentSize.height;
    _minScale = math.min(fitWidth, fitHeight);
    _coverScale = math.max(fitWidth, fitHeight);
    final pixelZoomScale = _kMaxPhysicalPxPerImagePx / devicePixelRatio;
    final maxScale = math.max(_minScale * 4.0, pixelZoomScale);
    _maxScale = maxScale.withMinimum(_coverScale);
    if (shouldRefit) {
      _didFit = true;
      _scale = _minScale;
      _translation = Offset.zero;
    } else {
      _scale = _scale.clampDouble(_minScale, _maxScale);
      _translation = clampTranslation(_translation, _scale);
    }
  }

  Offset _maxTranslation(double scale) {
    final overflowX = (_contentSize.width * scale - _viewport.width) / 2;
    final overflowY = (_contentSize.height * scale - _viewport.height) / 2;
    return Offset(overflowX.withMinimum(0.0), overflowY.withMinimum(0.0));
  }

  Offset clampTranslation(Offset translation, double scale) {
    final max = _maxTranslation(scale);
    return Offset(
      translation.dx.clampDouble(-max.dx, max.dx),
      translation.dy.clampDouble(-max.dy, max.dy),
    );
  }

  Offset anchoredTranslation({
    required Offset anchorPosition,
    required double fromScale,
    required Offset fromTranslation,
    required double toScale,
    required Offset toPosition,
  }) {
    final center = viewportCenter;
    final anchor = (anchorPosition - center - fromTranslation) / fromScale;
    return clampTranslation((toPosition - center) - anchor * toScale, toScale);
  }

  bool canPan(Offset delta, Axis axis) {
    final max = _maxTranslation(_scale);
    final double move;
    final double limit;
    final double current;
    if (axis == Axis.horizontal) {
      move = delta.dx;
      limit = max.dx;
      current = _translation.dx;
    } else {
      move = delta.dy;
      limit = max.dy;
      current = _translation.dy;
    }
    if (move == 0.0 || limit <= 0.0) return false;
    return move > 0.0 ? current < limit - 0.5 : current > -limit + 0.5;
  }

  Rect imageRect() {
    return Rect.fromCenter(
      center: viewportCenter + _translation,
      width: _contentSize.width * _scale,
      height: _contentSize.height * _scale,
    );
  }
}

class _ImageLevels extends ChangeNotifier {
  static final _cache = <ImageProvider, _ImageLevels>{};

  static _ImageLevels acquire(ImageProvider provider, Size baseTargetPx) {
    final existing = _cache[provider];
    if (existing != null) {
      existing._refCount++;
      return existing;
    }
    final levels = _ImageLevels._(provider, baseTargetPx);
    _cache[provider] = levels;
    levels._load();
    return levels;
  }

  _ImageLevels._(this._provider, this._baseTargetPx);

  final ImageProvider _provider;
  final Size _baseTargetPx;

  int _refCount = 1;
  bool _isReleased = false;
  bool _isLoadingBase = false;
  bool _isDecoding = false;
  int _wantedLevel = 0;

  ImageStream? _baseStream;
  late final _baseListener = ImageStreamListener(_onBase, onError: _onError);
  late final _previewListener = ImageStreamListener(_onPreview);
  ui.ImmutableBuffer? _buffer;
  ui.ImageDescriptor? _descriptor;

  int nativeWidth = 0;
  int nativeHeight = 0;
  int baseWidth = 0;
  int maxLevel = 0;

  ui.Image? preview;
  ui.Image? base;
  ui.Image? highest;
  int highestLevel = 0;
  Object? error;

  void release() {
    _refCount--;
    if (_refCount > 0) return;
    _cache.remove(_provider);
    _isReleased = true;
    preview?.dispose();
    base?.dispose();
    if (highestLevel != 0) highest?.dispose();
    preview = null;
    base = null;
    highest = null;
    _disposeNativeIfIdle();
    dispose();
  }

  void _disposeNativeIfIdle() {
    if (!_isReleased || _isLoadingBase || _isDecoding) return;
    _descriptor?.dispose();
    _buffer?.dispose();
    _descriptor = null;
    _buffer = null;
  }

  void _load() {
    _takeCachedPreview();
    _isLoadingBase = true;
    final provider = _LevelsImageProvider(_provider, _decodeBase);
    final stream = provider.resolve(ImageConfiguration.empty);
    _baseStream = stream;
    stream.addListener(_baseListener);
  }

  void _takeCachedPreview() {
    final cachedProvider = ArtworkWidget.fullQualityImage(_provider);
    Object? resolvedKey;
    cachedProvider.obtainKey(ImageConfiguration.empty).then((key) => resolvedKey = key);
    final cacheKey = resolvedKey;
    if (cacheKey == null) return;
    final imageCache = PaintingBinding.instance.imageCache;
    final status = imageCache.statusForKey(cacheKey);
    final isDecoded = !status.pending && (status.keepAlive || status.live);
    if (!isDecoded) return;
    final completer = imageCache.putIfAbsent(cacheKey, () => throw StateError('cached image entry vanished'));
    if (completer == null) return;
    completer.addListener(_previewListener);
    completer.removeListener(_previewListener);
  }

  void _onPreview(ImageInfo info, bool synchronousCall) {
    if (!synchronousCall || preview != null) {
      info.image.dispose();
      return;
    }
    preview = info.image;
  }

  void _stopLoadingBase() {
    _isLoadingBase = false;
    _baseStream?.removeListener(_baseListener);
    _baseStream = null;
  }

  Future<ui.Codec> _decodeBase(ui.ImmutableBuffer buffer, {ui.TargetImageSizeCallback? getTargetSize}) async {
    _buffer = buffer;
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    _descriptor = descriptor;
    nativeWidth = descriptor.width;
    nativeHeight = descriptor.height;
    if (!_isReleased) notifyListeners();
    final targetPx = _baseTargetPx;
    final fitWidth = targetPx.width / nativeWidth;
    final fitHeight = targetPx.height / nativeHeight;
    final fit = targetPx.isEmpty ? 1.0 : math.min(fitWidth, fitHeight).withMaximum(1.0);
    baseWidth = (nativeWidth * fit).round().withMinimum(1);
    final baseHeight = (nativeHeight * fit).round().withMinimum(1);
    int level = 0;
    for (int width = baseWidth; width < nativeWidth; width <<= 1) {
      level++;
    }
    maxLevel = level;
    return descriptor.instantiateCodec(targetWidth: baseWidth, targetHeight: baseHeight);
  }

  void _onBase(ImageInfo info, bool synchronousCall) {
    _stopLoadingBase();
    if (_isReleased) {
      info.image.dispose();
      _disposeNativeIfIdle();
      return;
    }
    base = info.image;
    highest = base;
    highestLevel = 0;
    preview?.dispose();
    preview = null;
    notifyListeners();
    if (_wantedLevel > 0) _decodeWanted();
  }

  void _onError(Object e, StackTrace? st) {
    _stopLoadingBase();
    if (_isReleased) {
      _disposeNativeIfIdle();
      return;
    }
    error = e;
    notifyListeners();
  }

  int levelForWidthPx(double requiredPx) {
    int level = 0;
    for (int width = baseWidth; level < maxLevel && width * 1.1 < requiredPx; width <<= 1) {
      level++;
    }
    return level;
  }

  void ensureLevel(int level) {
    if (level > maxLevel) level = maxLevel;
    _wantedLevel = level;
    if (base == null || _isDecoding || level <= highestLevel) return;
    _decodeWanted();
  }

  Future<void> _decodeWanted() async {
    final descriptor = _descriptor;
    if (descriptor == null) return;
    _isDecoding = true;
    while (!_isReleased && _wantedLevel > highestLevel) {
      final level = _wantedLevel;
      final width = math.min(nativeWidth, baseWidth << level);
      final scaledHeight = (nativeHeight * width / nativeWidth).round().withMinimum(1);
      final height = width == nativeWidth ? nativeHeight : scaledHeight;
      final ui.Image image;
      try {
        final codec = await descriptor.instantiateCodec(targetWidth: width, targetHeight: height);
        final frame = await codec.getNextFrame();
        codec.dispose();
        image = frame.image;
      } catch (_) {
        maxLevel = highestLevel;
        break;
      }
      if (_isReleased) {
        image.dispose();
        break;
      }
      if (highestLevel != 0) highest?.dispose();
      highest = image;
      highestLevel = level;
      notifyListeners();
    }
    _isDecoding = false;
    _disposeNativeIfIdle();
  }
}

class _LevelsImageProvider extends ImageProvider<Object> {
  final ImageProvider _inner;
  final ImageDecoderCallback _decode;

  const _LevelsImageProvider(this._inner, this._decode);

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) => _inner.obtainKey(configuration);

  @override
  void resolveStreamForKey(ImageConfiguration configuration, ImageStream stream, Object key, ImageErrorListener handleError) {
    stream.setCompleter(_inner.loadImage(key, _decode));
  }
}
