// by claude
// artwork glow & backdrop blur, baked once per artwork into tiny pre-blurred images instead of offscreen blur layers every frame.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:dart_extensions/dart_extensions.dart';

/// glow behind [child], and a blur source for [ArtworkBackdropBlur]s inside the nearest [ArtworkBlurScope].
/// [child] must be the box the artwork [image] is painted in, using [fit] and [alignment].
class BakedBlurArtwork extends StatefulWidget {
  final ImageProvider? image;
  final Color? stockGlowColor;
  final double glowBlur;
  final double glowScale;
  final Offset glowOffset;
  final ValueListenable<double>? glowOpacity;
  final bool isBackdropSource;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final bool isCircle;
  final BorderRadius? borderRadius;
  final Widget child;

  const BakedBlurArtwork({
    super.key,
    required this.image,
    required this.stockGlowColor,
    required this.glowBlur,
    required this.glowScale,
    required this.glowOffset,
    this.glowOpacity,
    required this.isBackdropSource,
    required this.fit,
    required this.alignment,
    required this.isCircle,
    required this.borderRadius,
    required this.child,
  });

  @override
  State<BakedBlurArtwork> createState() => _BakedBlurArtworkState();
}

class _BakedBlurArtworkState extends State<BakedBlurArtwork> {
  late final _scrollAwareContext = DisposableBuildContext<State<BakedBlurArtwork>>(this);
  late final _listener = ImageStreamListener(_onImage, onError: _onImageError);
  ImageStream? _stream;
  ImageInfo? _imageInfo;
  ImageStreamCompleter? _imageCompleter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant BakedBlurArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) _resolveImage();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _scrollAwareContext.dispose();
    _imageInfo?.dispose();
    super.dispose();
  }

  void _resolveImage() {
    final image = widget.image;
    if (image == null) {
      _stream?.removeListener(_listener);
      _stream = null;
      _imageInfo?.dispose();
      _imageInfo = null;
      _imageCompleter = null;
      return;
    }
    // -- shares the artwork's decoded image and its deferral while scrolling fast
    final provider = ScrollAwareImageProvider<Object>(context: _scrollAwareContext, imageProvider: image);
    final configuration = createLocalImageConfiguration(context);
    final stream = provider.resolve(configuration);
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream;
    stream.addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final oldInfo = _imageInfo;
    setState(() {
      _imageInfo = info;
      _imageCompleter = _stream?.completer;
    });
    oldInfo?.dispose();
  }

  // -- the artwork reports its own image errors
  void _onImageError(Object error, StackTrace? stackTrace) {}

  @override
  Widget build(BuildContext context) {
    final imageInfo = _imageInfo;
    final glowBlur = widget.glowBlur;
    final _GlowStyle? glow = glowBlur > 0.0
        ? (
            blur: glowBlur,
            scale: widget.glowScale,
            offset: widget.glowOffset,
            stockColor: widget.stockGlowColor,
            isCircle: widget.isCircle,
            borderRadius: widget.borderRadius,
          )
        : null;
    final sources = widget.isBackdropSource ? ArtworkBlurScope.maybeOf(context) : null;
    final textDirection = Directionality.maybeOf(context);
    final alignment = widget.alignment.resolve(textDirection);
    final imageScale = imageInfo?.scale ?? 1.0;
    return _BakedBlurArtworkBox(
      image: imageInfo?.image,
      imageScale: imageScale,
      imageCompleter: _imageCompleter,
      glow: glow,
      glowOpacity: widget.glowOpacity,
      sources: sources,
      fit: widget.fit,
      alignment: alignment,
      child: widget.child,
    );
  }
}

class _BakedBlurArtworkBox extends SingleChildRenderObjectWidget {
  final ui.Image? image;
  final double imageScale;
  final ImageStreamCompleter? imageCompleter;
  final _GlowStyle? glow;
  final ValueListenable<double>? glowOpacity;
  final ArtworkBlurSources? sources;
  final BoxFit fit;
  final Alignment alignment;

  const _BakedBlurArtworkBox({
    required this.image,
    required this.imageScale,
    required this.imageCompleter,
    required this.glow,
    required this.glowOpacity,
    required this.sources,
    required this.fit,
    required this.alignment,
    required super.child,
  });

  @override
  _RenderBakedBlurArtwork createRenderObject(BuildContext context) {
    return _RenderBakedBlurArtwork(
      image: image,
      imageScale: imageScale,
      imageCompleter: imageCompleter,
      glow: glow,
      glowOpacity: glowOpacity,
      sources: sources,
      fit: fit,
      alignment: alignment,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderBakedBlurArtwork renderObject) {
    renderObject
      ..updateImage(image, imageScale, imageCompleter)
      ..glow = glow
      ..glowOpacity = glowOpacity
      ..sources = sources
      ..fit = fit
      ..alignment = alignment;
  }
}

class _RenderBakedBlurArtwork extends RenderProxyBox {
  _RenderBakedBlurArtwork({
    required this._image,
    required this._imageScale,
    required this._imageCompleter,
    required this._glow,
    required this._glowOpacity,
    required this._sources,
    required this._fit,
    required this._alignment,
  });

  /// enough for a smooth bilinear upscale.
  static const _kBakedSigma = 2.0;
  static const _kMinBakedSide = 8.0;
  static const _kMaxBakedSide = 96.0;
  static const _kMaxBakesPerImage = 4;

  /// tied to the decoded image's lifetime in the image cache, so they're dropped together.
  static final _bakesPerImage = Expando<Map<_BakeKey, _Bake>>();
  static final _bakePaint = Paint()..filterQuality = FilterQuality.low;
  static final _fadedBakePaint = Paint()..filterQuality = FilterQuality.low;

  ui.Image? _image;
  double _imageScale;
  ImageStreamCompleter? _imageCompleter;

  void updateImage(ui.Image? image, double imageScale, ImageStreamCompleter? imageCompleter) {
    if (identical(image, _image)) return;
    _image = image;
    _imageScale = imageScale;
    _imageCompleter = imageCompleter;
    markNeedsPaint();
    _sources?._notifyChanged();
  }

  _GlowStyle? _glow;
  set glow(_GlowStyle? value) {
    if (value == _glow) return;
    _glow = value;
    markNeedsPaint();
  }

  ValueListenable<double>? _glowOpacity;
  set glowOpacity(ValueListenable<double>? value) {
    if (identical(value, _glowOpacity)) return;
    if (attached) {
      _glowOpacity?.removeListener(markNeedsPaint);
      value?.addListener(markNeedsPaint);
    }
    _glowOpacity = value;
    markNeedsPaint();
  }

  ArtworkBlurSources? _sources;
  set sources(ArtworkBlurSources? value) {
    if (identical(value, _sources)) return;
    if (attached) {
      _sources?._remove(this);
      value?._add(this);
    }
    _sources = value;
  }

  BoxFit _fit;
  set fit(BoxFit value) {
    if (value == _fit) return;
    _fit = value;
    markNeedsPaint();
    _sources?._notifyChanged();
  }

  Alignment _alignment;
  set alignment(Alignment value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsPaint();
    _sources?._notifyChanged();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _sources?._add(this);
    _glowOpacity?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _sources?._remove(this);
    _glowOpacity?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final glow = _glow;
    if (glow != null) _paintGlow(context.canvas, offset & size, glow);
    super.paint(context, offset);
  }

  void _paintGlow(Canvas canvas, Rect boxRect, _GlowStyle glow) {
    final opacity = _glowOpacity?.value ?? 1.0;
    if (opacity <= 0.0) return;
    final center = boxRect.center;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(glow.scale);
    canvas.translate(glow.offset.dx - center.dx, glow.offset.dy - center.dy);
    final stockColor = glow.stockColor;
    if (stockColor != null) {
      final shape = _shapeOf(boxRect, glow.isCircle, glow.borderRadius);
      final color = stockColor.withValues(alpha: stockColor.a * opacity);
      final paint = Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow.blur);
      canvas.drawRRect(shape, paint);
    } else {
      final bake = _obtainBake(isGlow: true, blur: glow.blur, isCircle: glow.isCircle, borderRadius: glow.borderRadius);
      var paint = _bakePaint;
      if (opacity < 1.0) paint = _fadedBakePaint..color = Color.fromRGBO(0, 0, 0, opacity);
      bake?.paint(canvas, boxRect, paint);
    }
    canvas.restore();
  }

  _Bake? _obtainBake({required bool isGlow, required double blur, required bool isCircle, required BorderRadius? borderRadius}) {
    final image = _image;
    final imageCompleter = _imageCompleter;
    final boxSize = size;
    if (image == null || imageCompleter == null || boxSize.isEmpty) return null;
    final key = (
      isGlow: isGlow,
      width: boxSize.width.round(),
      height: boxSize.height.round(),
      blur: blur,
      fit: _fit,
      alignment: _alignment,
      isCircle: isCircle,
      borderRadius: borderRadius,
    );
    final bakes = _bakesPerImage[imageCompleter] ??= <_BakeKey, _Bake>{};
    final cached = bakes[key];
    if (cached != null) return cached;
    if (bakes.length >= _kMaxBakesPerImage) {
      final oldestKey = bakes.keys.first;
      bakes.remove(oldestKey)?.dispose();
    }
    final bake = _createBake(image: image, imageScale: _imageScale, boxSize: boxSize, key: key);
    bakes[key] = bake;
    return bake;
  }

  static _Bake _createBake({required ui.Image image, required double imageScale, required Size boxSize, required _BakeKey key}) {
    final idealSide = boxSize.longestSide * _kBakedSigma / key.blur;
    final bakedSide = idealSide.withMinimum(_kMinBakedSide).withMaximum(_kMaxBakedSide);
    final scale = bakedSide / boxSize.longestSide;
    final sigma = key.blur * scale;
    final contentWidth = (boxSize.width * scale).ceilToDouble();
    final contentHeight = (boxSize.height * scale).ceilToDouble();
    final padding = key.isGlow ? (sigma * 3.0).ceilToDouble() : 0.0;
    final contentRect = Rect.fromLTWH(padding, padding, contentWidth, contentHeight);
    final bakedWidth = (contentWidth + padding * 2.0).toInt();
    final bakedHeight = (contentHeight + padding * 2.0).toInt();

    // -- glow fades past the edges, backdrop repeats them like a real backdrop does
    final tileMode = key.isGlow ? TileMode.decal : TileMode.clamp;
    final blurFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: tileMode);
    final blurPaint = Paint()..imageFilter = blurFilter;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (key.isGlow) {
      canvas.saveLayer(null, blurPaint);
      final borderRadius = key.borderRadius;
      final scaledBorderRadius = borderRadius == null ? null : borderRadius * scale;
      final shape = _shapeOf(contentRect, key.isCircle, scaledBorderRadius);
      canvas.clipRRect(shape);
    } else {
      canvas.saveLayer(contentRect, blurPaint);
    }
    paintImage(
      canvas: canvas,
      rect: contentRect,
      image: image,
      scale: imageScale,
      fit: key.fit,
      alignment: key.alignment,
      filterQuality: FilterQuality.medium,
    );
    canvas.restore();
    final picture = recorder.endRecording();
    final bakedImage = picture.toImageSync(bakedWidth, bakedHeight);
    picture.dispose();
    return _Bake(image: bakedImage, contentRect: contentRect);
  }

  static RRect _shapeOf(Rect rect, bool isCircle, BorderRadius? borderRadius) {
    if (isCircle) {
      final radius = rect.shortestSide / 2.0;
      final circleRect = Rect.fromCircle(center: rect.center, radius: radius);
      return RRect.fromRectXY(circleRect, radius, radius);
    }
    if (borderRadius != null) return borderRadius.toRRect(rect);
    return RRect.fromRectAndRadius(rect, Radius.zero);
  }
}

/// lets [ArtworkBackdropBlur]s draw the pre-blurred [BakedBlurArtwork]s under them instead of reading back the screen.
class ArtworkBlurScope extends StatefulWidget {
  final Widget child;

  const ArtworkBlurScope({
    super.key,
    required this.child,
  });

  static ArtworkBlurSources? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<_ArtworkBlurSourcesProvider>()?.sources;
  }

  @override
  State<ArtworkBlurScope> createState() => _ArtworkBlurScopeState();
}

class _ArtworkBlurScopeState extends State<ArtworkBlurScope> {
  final _sources = ArtworkBlurSources._();

  @override
  void dispose() {
    _sources.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ArtworkBlurSourcesProvider(
      sources: _sources,
      child: widget.child,
    );
  }
}

class _ArtworkBlurSourcesProvider extends InheritedWidget {
  final ArtworkBlurSources sources;

  const _ArtworkBlurSourcesProvider({
    required this.sources,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ArtworkBlurSourcesProvider oldWidget) => false;
}

/// the [BakedBlurArtwork]s of one [ArtworkBlurScope], notifies when any of them changes.
class ArtworkBlurSources extends ChangeNotifier {
  ArtworkBlurSources._();

  final _artworks = <_RenderBakedBlurArtwork>{};

  void _add(_RenderBakedBlurArtwork artwork) {
    _artworks.add(artwork);
    notifyListeners();
  }

  void _remove(_RenderBakedBlurArtwork artwork) {
    _artworks.remove(artwork);
    notifyListeners();
  }

  void _notifyChanged() => notifyListeners();
}

/// backdrop blur made from the [sources] artworks under it, the rest of the backdrop stays as is.
class ArtworkBackdropBlur extends StatelessWidget {
  final ArtworkBlurSources sources;
  final double blur;
  final Widget child;

  const ArtworkBackdropBlur({
    super.key,
    required this.sources,
    required this.blur,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _ArtworkBackdropBlurBox(
      sources: sources,
      blur: blur,
      child: child,
    );
  }
}

class _ArtworkBackdropBlurBox extends SingleChildRenderObjectWidget {
  final ArtworkBlurSources sources;
  final double blur;

  const _ArtworkBackdropBlurBox({
    required this.sources,
    required this.blur,
    required super.child,
  });

  @override
  _RenderArtworkBackdropBlur createRenderObject(BuildContext context) {
    return _RenderArtworkBackdropBlur(
      sources: sources,
      blur: blur,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderArtworkBackdropBlur renderObject) {
    renderObject
      ..sources = sources
      ..blur = blur;
  }
}

class _RenderArtworkBackdropBlur extends RenderProxyBox {
  _RenderArtworkBackdropBlur({
    required this._sources,
    required this._blur,
  });

  ArtworkBlurSources _sources;
  set sources(ArtworkBlurSources value) {
    if (identical(value, _sources)) return;
    if (attached) {
      _sources.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _sources = value;
    markNeedsPaint();
  }

  double _blur;
  set blur(double value) {
    if (value == _blur) return;
    _blur = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _sources.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _sources.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final clipRect = offset & size;
    for (final artwork in _sources._artworks) {
      final bake = artwork._obtainBake(isGlow: false, blur: _blur, isCircle: false, borderRadius: null);
      if (bake == null) continue;
      final artworkToThis = artwork.getTransformTo(this);
      final artworkRect = Offset.zero & artwork.size;
      canvas.save();
      canvas.clipRect(clipRect);
      canvas.translate(offset.dx, offset.dy);
      canvas.transform(artworkToThis.storage);
      bake.paint(canvas, artworkRect, _RenderBakedBlurArtwork._bakePaint);
      canvas.restore();
    }
    super.paint(context, offset);
  }
}

class _Bake {
  final ui.Image image;

  /// where the artwork box sits inside [image], the rest is blur spill.
  final Rect contentRect;

  const _Bake({
    required this.image,
    required this.contentRect,
  });

  void paint(Canvas canvas, Rect boxRect, Paint paint) {
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();
    final scaleX = boxRect.width / contentRect.width;
    final scaleY = boxRect.height / contentRect.height;
    final source = Rect.fromLTWH(0.0, 0.0, imageWidth, imageHeight);
    final destination = Rect.fromLTRB(
      boxRect.left - contentRect.left * scaleX,
      boxRect.top - contentRect.top * scaleY,
      boxRect.right + (imageWidth - contentRect.right) * scaleX,
      boxRect.bottom + (imageHeight - contentRect.bottom) * scaleY,
    );
    canvas.drawImageRect(image, source, destination, paint);
  }

  void dispose() => image.dispose();
}

typedef _GlowStyle = ({double blur, double scale, Offset offset, Color? stockColor, bool isCircle, BorderRadius? borderRadius});

typedef _BakeKey = ({bool isGlow, int width, int height, double blur, BoxFit fit, Alignment alignment, bool isCircle, BorderRadius? borderRadius});
