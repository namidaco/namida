// thank you claude
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/network_artwork.dart';

part 'artists_map_page.layout.dart';

const _kCellExtent = 100.0;
const _kTileInset = 4.0;
const _kTileMinWidth = _kCellExtent - _kTileInset * 2;
const _kRingWidth = 3.0;
const _kArtworkExtent = 58.0;
const _kTileLabelExtent = 17.0;
const _kAnchor = Offset(_kTileInset + _kTileMinWidth / 2, _kTileInset + _kArtworkExtent / 2 + _kRingWidth);

const _kTilesEnterScale = 0.45;
const _kTilesExitScale = 0.4;
const _kMaxTiles = 550;
const _kMaxTilesExit = 700;
const _kFocusScale = 1.0;
const _kMaxScale = 2.0;

class ArtistsMapPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_artistsMap;

  @override
  String? get name => focusArtist;

  final MediaType type;
  final String? focusArtist;

  const ArtistsMapPage({super.key, required this.type, this.focusArtist});

  @override
  State<ArtistsMapPage> createState() => _ArtistsMapPageState();
}

class _ArtistsMapData {
  final ({MediaType type, int mapIdentity, int length}) signature;
  final List<String> names;
  final _ArtistsMapLayout grid;
  final _ArtistsMapLayout graph;

  const _ArtistsMapData({required this.signature, required this.names, required this.grid, required this.graph});

  int indexOf(String? name) {
    if (name == null) return -1;
    final lower = name.toLowerCase();
    return names.indexWhere((e) => e.toLowerCase() == lower);
  }
}

class _ArtistsMapPageState extends State<ArtistsMapPage> {
  /// reopening stays instant until the library changes.
  static _ArtistsMapData? _cached;

  _ArtistsMapData? _data;
  bool _isEmpty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final type = widget.type;
    final artistsMap = Indexer.inst.getArtistMapFor(type).value;
    if (artistsMap.isEmpty) {
      _isEmpty = true;
      return;
    }

    final signature = (type: type, mapIdentity: identityHashCode(artistsMap), length: artistsMap.length);
    final cached = _cached;
    if (cached != null && cached.signature == signature) {
      _data = cached;
      return;
    }

    final names = artistsMap.keys.toList();
    final input = await _extractArtistsMapInput(
      names: names,
      tracksPerArtist: artistsMap.values.toList(),
      isCancelled: () => !mounted,
    );
    if (input == null) return;

    final layouts = await _computeArtistsMapLayouts.thready(input);
    final data = _ArtistsMapData(signature: signature, names: names, grid: layouts.grid, graph: layouts.graph);
    _cached = data;
    if (mounted) setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return BackgroundWrapper(
      child: _isEmpty
          ? Center(
              child: Text(
                lang.noTracksFound,
                style: context.textTheme.displayMedium,
              ),
            )
          : data == null
          ? Center(
              child: ThreeArchedCircle(
                color: context.theme.colorScheme.secondary.withOpacityExt(0.5),
                size: 48.0,
              ),
            )
          : _ArtistsMapView(
              data: data,
              type: widget.type,
              focusArtist: widget.focusArtist,
            ),
    );
  }
}

class _ArtistsMapView extends StatefulWidget {
  final _ArtistsMapData data;
  final MediaType type;
  final String? focusArtist;

  const _ArtistsMapView({required this.data, required this.type, required this.focusArtist});

  @override
  State<_ArtistsMapView> createState() => _ArtistsMapViewState();
}

class _ArtistsMapViewState extends State<_ArtistsMapView> with SingleTickerProviderStateMixin {
  final _paintState = _MapPaintState();
  late final _pinned = ValueNotifier<int>(widget.data.indexOf(widget.focusArtist));
  late final _flyController = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))..addListener(_onFlyTick);
  Offset _flyFromCenter = Offset.zero;
  Offset _flyToCenter = Offset.zero;
  double _flyFromScale = 1.0;
  double _flyToScale = 1.0;

  bool _graphMode = settings.extra.artistsMapGraphLayout ?? true;
  TransformationController? _controller;
  Size _viewport = Size.zero;
  double _fitScale = 1.0;
  double _minScale = 0.1;

  ThemeData? _theme;
  late _MapColors _colors;
  List<TextPainter> _labels = const [];
  Widget? _paintLayer;

  Widget? _world;
  var _tiles = <int, Widget>{};
  bool _tilesMode = false;
  int _left = 0;
  int _top = 0;
  int _right = -1;
  int _bottom = -1;

  _ArtistsMapLayout get _layout => _graphMode ? widget.data.graph : widget.data.grid;
  double get _worldWidth => _layout.width;
  double get _worldHeight => _layout.height;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = context.theme;
    if (identical(theme, _theme)) return;
    _theme = theme;
    _colors = _MapColors.of(theme);

    final textDirection = Directionality.of(context);
    _disposeLabels();
    _labels = [
      for (final node in _layout.capitals) _labelPainter(widget.data.names[node], textDirection),
    ];
    _paintState.setHovered(-1, null);
    _rebuildPaintLayer();
  }

  void _rebuildPaintLayer() {
    _paintLayer = Positioned.fill(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ArtistsMapPainter(
            layout: _layout,
            state: _paintState,
            pinned: _pinned,
            colors: _colors,
            labels: _labels,
          ),
        ),
      ),
    );
    _world = null;
  }

  /// keeps looking at the same artist (or the same area) since both layouts share the global arrangement.
  void _toggleLayout() {
    final previous = _layout;
    final center = _toWorld(_viewport.center(Offset.zero));
    final scale = _paintState.scale;
    setState(() {
      _graphMode = !_graphMode;
      _tiles = {};
      _tilesMode = false;
      _rebuildPaintLayer();
    });
    _paintState.setHovered(-1, null);
    final layout = _layout;
    final pinned = _pinned.value;
    final target = pinned >= 0 ? layout.anchorOf(pinned) : Offset(center.dx / previous.width * layout.width, center.dy / previous.height * layout.height);
    _controller?.value = _matrixCentering(target, scale);
    settings.extra.save(artistsMapGraphLayout: _graphMode);
  }

  @override
  void dispose() {
    _flyController.dispose();
    _controller?.dispose();
    _paintState.dispose();
    _pinned.dispose();
    _disposeLabels();
    super.dispose();
  }

  TextPainter _labelPainter(String text, TextDirection textDirection) {
    return TextPainter(
      text: TextSpan(text: text, style: _colors.labelStyle),
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 180.0);
  }

  void _disposeLabels() {
    for (final label in _labels) {
      label.dispose();
    }
  }

  Matrix4 _matrixCentering(Offset world, double scale) {
    final s = scale.clamp(_minScale, _kMaxScale);
    return Matrix4.identity()
      ..translateByDouble(_viewport.width / 2 - world.dx * s, _viewport.height / 2 - world.dy * s, 0.0, 1.0)
      ..scaleByDouble(s, s, s, 1.0);
  }

  Offset _toWorld(Offset local) {
    final storage = _controller!.value.storage;
    final scale = _paintState.scale;
    return Offset((local.dx - storage[12]) / scale, (local.dy - storage[13]) / scale);
  }

  TransformationController _createController() {
    final pinned = _pinned.value;
    final matrix = pinned >= 0
        ? _matrixCentering(_layout.anchorOf(pinned), _kFocusScale)
        : _matrixCentering(Offset(_worldWidth / 2, _worldHeight / 2), math.min(_fitScale, _kFocusScale));
    _paintState.scale = matrix.getMaxScaleOnAxis();
    return TransformationController(matrix)..addListener(_onTransform);
  }

  void _onTransform() {
    _paintState.scale = _controller!.value.getMaxScaleOnAxis();
  }

  void _flyTo(Offset world, double scale) {
    final controller = _controller;
    if (controller == null) return;
    _flyFromCenter = _toWorld(_viewport.center(Offset.zero));
    _flyFromScale = controller.value.getMaxScaleOnAxis();
    _flyToCenter = world;
    _flyToScale = scale.clamp(_minScale, _kMaxScale);
    _flyController.forward(from: 0.0);
  }

  void _onFlyTick() {
    final t = Curves.easeInOutCubic.transform(_flyController.value);
    final center = Offset.lerp(_flyFromCenter, _flyToCenter, t)!;
    final scale = _flyFromScale * math.pow(_flyToScale / _flyFromScale, t);
    _controller?.value = _matrixCentering(center, scale);
  }

  void _fitAll() => _flyTo(Offset(_worldWidth / 2, _worldHeight / 2), _fitScale);

  void _onHover(PointerHoverEvent event) {
    if (_controller == null) return;
    final node = _layout.nodeAt(_toWorld(event.localPosition));
    if (node == _paintState.hovered) return;
    _paintState.setHovered(node, node >= 0 ? _labelPainter(widget.data.names[node], Directionality.of(context)) : null);
  }

  void _onTapUp(TapUpDetails details) {
    final world = _toWorld(details.localPosition);
    final node = _layout.nodeAt(world);
    _pinned.value = node;
    if (!_paintState.tilesMode) _flyTo(node >= 0 ? _layout.anchorOf(node) : world, _kFocusScale);
  }

  /// called on every transform change, returns the very same widget unless the visible buckets changed.
  Widget _worldForViewport() {
    final layout = _layout;
    final buckets = layout.buckets;
    int left = 0;
    int top = 0;
    int right = -1;
    int bottom = -1;
    bool showTiles = false;
    if (_paintState.scale >= (_tilesMode ? _kTilesExitScale : _kTilesEnterScale)) {
      final topLeft = _toWorld(Offset.zero);
      final bottomRight = _toWorld(_viewport.bottomRight(Offset.zero));
      left = math.max(0, buckets.columnOf(topLeft.dx) - 1);
      top = math.max(0, buckets.rowOf(topLeft.dy) - 1);
      right = math.min(buckets.columns - 1, buckets.columnOf(bottomRight.dx) + 1);
      bottom = math.min(buckets.rows - 1, buckets.rowOf(bottomRight.dy) + 1);
      final world = _world;
      if (_tilesMode && world != null && left == _left && top == _top && right == _right && bottom == _bottom) return world;
      showTiles = buckets.countIn(left, top, right, bottom) <= (_tilesMode ? _kMaxTilesExit : _kMaxTiles);
    }
    _paintState.tilesMode = showTiles;

    if (!showTiles) {
      if (_tilesMode) {
        _tilesMode = false;
        _tiles = {};
        _world = null;
      }
      return _world ??= _MapWorld(
        width: _worldWidth,
        height: _worldHeight,
        paintLayer: _paintLayer!,
        tiles: const [],
      );
    }

    _tilesMode = true;
    _left = left;
    _top = top;
    _right = right;
    _bottom = bottom;

    // -- row major over absolute buckets keeps the relative order of tiles that stay visible, so their elements are reused as is.
    final previous = _tiles;
    final tiles = <int, Widget>{};
    final names = widget.data.names;
    for (int row = top; row <= bottom; row++) {
      for (int column = left; column <= right; column++) {
        final bucket = row * buckets.columns + column;
        for (int k = buckets.offsets[bucket]; k < buckets.offsets[bucket + 1]; k++) {
          final node = buckets.nodes[k];
          tiles[node] =
              previous[node] ??
              Positioned.fromRect(
                key: ValueKey(node),
                rect: layout.tileRectOf(node),
                child: _MapTile(
                  name: names[node],
                  type: widget.type,
                  artworkExtent: layout.classRadii[layout.sizeClasses[node]] * 2,
                ),
              );
        }
      }
    }
    _tiles = tiles;
    return _world = _MapWorld(
      width: _worldWidth,
      height: _worldHeight,
      paintLayer: _paintLayer!,
      tiles: tiles.values.toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewport = constraints.biggest;
              _viewport = viewport;
              _fitScale = math.min(viewport.width / _worldWidth, viewport.height / _worldHeight) * 0.92;
              _minScale = math.min(_fitScale * 0.8, _kTilesExitScale * 0.5);
              final controller = _controller ??= _createController();
              return MouseRegion(
                onHover: _onHover,
                onExit: (_) => _paintState.setHovered(-1, null),
                child: GestureDetector(
                  onTapUp: _onTapUp,
                  child: InteractiveViewer.builder(
                    transformationController: controller,
                    minScale: _minScale,
                    maxScale: _kMaxScale,
                    boundaryMargin: EdgeInsets.all(math.max(viewport.width, viewport.height) / _minScale),
                    onInteractionStart: (_) => _flyController.stop(),
                    builder: (context, _) => _worldForViewport(),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 8.0,
          left: 8.0,
          child: _OverlayPill(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            child: Text(
              lang.countArtists(count: widget.data.names.length),
              style: context.textTheme.displaySmall,
            ),
          ),
        ),
        Positioned(
          top: 8.0,
          right: 8.0,
          child: _OverlayPill(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NamidaIconButton(
                  icon: _graphMode ? Broken.grid_2 : Broken.hierarchy_3,
                  iconSize: 20.0,
                  onPressed: _toggleLayout,
                ),
                ValueListenableBuilder(
                  valueListenable: _pinned,
                  builder: (context, pinned, _) => pinned < 0
                      ? const SizedBox()
                      : NamidaIconButton(
                          icon: Broken.gps,
                          iconSize: 20.0,
                          onPressed: () => _flyTo(_layout.anchorOf(pinned), _kFocusScale),
                        ),
                ),
                NamidaIconButton(
                  icon: Broken.maximize_3,
                  iconSize: 20.0,
                  onPressed: _fitAll,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapWorld extends StatelessWidget {
  final double width;
  final double height;
  final Widget paintLayer;
  final List<Widget> tiles;

  const _MapWorld({required this.width, required this.height, required this.paintLayer, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            paintLayer,
            ...tiles,
          ],
        ),
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _OverlayPill({required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.theme.cardColor.withOpacityExt(0.85),
        borderRadius: BorderRadius.circular(12.0.multipliedRadius),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  final String name;
  final MediaType type;
  final double artworkExtent;

  const _MapTile({required this.name, required this.type, required this.artworkExtent});

  @override
  Widget build(BuildContext context) {
    final tracks = name.getArtistTracksFor(type);
    final pathToImage = tracks.pathToImage;
    return NamidaInkWell(
      onTap: () => NamidaOnTaps.inst.onArtistTap(name, type, tracks),
      onLongPress: () => NamidaDialogs.inst.showArtistDialog(name, type),
      enableSecondaryTap: true,
      borderRadius: 0.0,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(_kRingWidth),
            child: NetworkArtwork.orLocal(
              key: Key(pathToImage),
              info: NetworkArtworkInfo.artist(name),
              path: pathToImage,
              track: tracks.trackOfImage,
              thumbnailSize: artworkExtent,
              borderRadius: 0.0,
              forceSquared: true,
              blur: 0.0,
              isCircle: true,
              iconSize: 22.0,
            ),
          ),
          const SizedBox(
            height: 3.0,
          ),
          Expanded(
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: context.textTheme.displaySmall?.copyWith(fontSize: 10.0),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapColors {
  final Color line;
  final Color labelBackground;
  final TextStyle labelStyle;

  /// one per cluster color slot, the last one for unclustered artists.
  final List<Color> slots;

  const _MapColors._({required this.line, required this.labelBackground, required this.labelStyle, required this.slots});

  factory _MapColors.of(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final slots = List<Color>.generate(
      _kPaletteSize + 1,
      (slot) {
        if (slot == _kPaletteSize) return theme.colorScheme.onSurface.withOpacityExt(0.22);
        final hue = (slot * 137.508) % 360.0;
        final color = HSLColor.fromAHSL(1.0, hue, isDark ? 0.45 : 0.55, isDark ? 0.62 : 0.5).toColor();
        return Color.lerp(color, primary, 0.2)!;
      },
      growable: false,
    );
    return _MapColors._(
      line: primary,
      labelBackground: theme.scaffoldBackgroundColor.withOpacityExt(0.8),
      labelStyle: (theme.textTheme.displaySmall ?? const TextStyle()).copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
      slots: slots,
    );
  }
}

class _MapPaintState extends ChangeNotifier {
  double _scale = 1.0;
  double _paintedScale = 1.0;
  bool _tilesMode = false;
  int _hovered = -1;
  TextPainter? _hoveredLabel;

  double get scale => _scale;
  bool get tilesMode => _tilesMode;
  int get hovered => _hovered;
  TextPainter? get hoveredLabel => _hoveredLabel;

  /// tiles keep a fixed ring size, so they only repaint once the line widths drift visibly.
  set scale(double value) {
    if (value == _scale) return;
    _scale = value;
    if (_tilesMode && (value / _paintedScale - 1.0).abs() < 0.25) return;
    _paintedScale = value;
    notifyListeners();
  }

  set tilesMode(bool value) {
    if (value == _tilesMode) return;
    _tilesMode = value;
    _paintedScale = _scale;
    notifyListeners();
  }

  void setHovered(int node, TextPainter? label) {
    _hoveredLabel?.dispose();
    _hoveredLabel = label;
    if (node == _hovered) return;
    _hovered = node;
    notifyListeners();
  }

  @override
  void dispose() {
    _hoveredLabel?.dispose();
    super.dispose();
  }
}

class _ArtistsMapPainter extends CustomPainter {
  final _ArtistsMapLayout layout;
  final _MapPaintState state;
  final ValueListenable<int> pinned;
  final _MapColors colors;
  final List<TextPainter> labels;

  final _linePaint = Paint();
  final _glowPaint = Paint();
  final _corePaint = Paint();
  final _dotPaint = Paint()..strokeCap = StrokeCap.round;
  final _ringPaint = Paint()..style = PaintingStyle.stroke;
  final _labelBackgroundPaint = Paint();

  _ArtistsMapPainter({
    required this.layout,
    required this.state,
    required this.pinned,
    required this.colors,
    required this.labels,
  }) : super(repaint: Listenable.merge([state, pinned]));

  @override
  void paint(Canvas canvas, Size size) {
    final scale = state.scale;
    final pixel = 1.0 / scale;
    final pinnedNode = pinned.value;
    final hovered = state.hovered;
    final focused = hovered >= 0 ? hovered : pinnedNode;
    final tilesMode = state.tilesMode;

    final linePaint = _linePaint;
    final dimming = focused >= 0 ? 0.5 : 1.0;
    final edgeLines = layout.edgeLines;
    for (int b = 0; b < edgeLines.length; b++) {
      final lines = edgeLines[b];
      if (lines.isEmpty) continue;
      linePaint
        ..strokeWidth = (0.8 + 0.5 * b) * pixel
        ..color = colors.line.withValues(alpha: (0.12 + 0.45 * (b + 1) / edgeLines.length) * dimming);
      canvas.drawRawPoints(ui.PointMode.lines, lines, linePaint);
    }
    if (focused >= 0) _paintFocusedLinks(canvas, focused, pixel);

    final dotPaint = _dotPaint;
    final dotPoints = layout.dotPoints;
    final classRadii = layout.classRadii;
    for (int group = 0; group < dotPoints.length; group++) {
      final points = dotPoints[group];
      if (points.isEmpty) continue;
      dotPaint
        ..strokeWidth = _dotExtent(classRadii[group % classRadii.length] + _kRingWidth, tilesMode, pixel)
        ..color = colors.slots[group ~/ classRadii.length];
      canvas.drawRawPoints(ui.PointMode.points, points, dotPaint);
    }

    if (pinnedNode >= 0) {
      final ringPaint = _ringPaint
        ..strokeWidth = 2.0 * pixel
        ..color = colors.line;
      canvas.drawCircle(layout.anchorOf(pinnedNode), _dotExtent(layout.ringRadiusOf(pinnedNode), tilesMode, pixel) / 2 + 3.0 * pixel, ringPaint);
    }

    if (!tilesMode) _paintLabels(canvas, scale, pixel);
  }

  double _dotExtent(double ringRadius, bool tilesMode, double pixel) {
    final ringExtent = ringRadius * 2;
    return tilesMode ? ringExtent : math.min(math.max(ringExtent, 2.5 * pixel), layout.maxDotExtent);
  }

  void _paintFocusedLinks(Canvas canvas, int node, double pixel) {
    final links = layout.links;
    final from = layout.anchorOf(node);
    final glowPaint = _glowPaint..strokeWidth = 4.0 * pixel;
    final corePaint = _corePaint..strokeWidth = 1.8 * pixel;
    for (int e = links.offsets[node]; e < links.offsets[node + 1]; e++) {
      final to = layout.anchorOf(links.neighbours[e]);
      final strength = links.weights[e];
      glowPaint.color = colors.line.withValues(alpha: 0.22 * strength);
      corePaint.color = colors.line.withValues(alpha: 0.35 + 0.6 * strength);
      canvas.drawLine(from, to, glowPaint);
      canvas.drawLine(from, to, corePaint);
    }
  }

  void _paintLabels(Canvas canvas, double scale, double pixel) {
    final hoveredLabel = state.hoveredLabel;
    if (labels.isEmpty && hoveredLabel == null) return;

    final taken = <Rect>[];
    final background = _labelBackgroundPaint..color = colors.labelBackground;

    void paintLabel(TextPainter label, int node, {required bool force}) {
      final anchor = layout.anchorOf(node) * scale;
      final dotRadius = _dotExtent(layout.ringRadiusOf(node), false, pixel) * scale / 2;
      final width = label.width + 12.0;
      final height = label.height + 4.0;
      final rect = Rect.fromLTWH(anchor.dx - width / 2, anchor.dy - dotRadius - height - 3.0, width, height);
      if (!force && taken.any(rect.overlaps)) return;
      taken.add(rect);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8.0)), background);
      label.paint(canvas, Offset(rect.left + 6.0, rect.top + 2.0));
    }

    canvas.save();
    canvas.scale(1.0 / scale);
    final hovered = state.hovered;
    if (hoveredLabel != null && hovered >= 0) paintLabel(hoveredLabel, hovered, force: true);
    final capitals = layout.capitals;
    for (int i = 0; i < labels.length; i++) {
      if (capitals[i] != hovered) paintLabel(labels[i], capitals[i], force: false);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArtistsMapPainter oldDelegate) {
    return oldDelegate.layout != layout || oldDelegate.colors != colors || oldDelegate.labels != labels || oldDelegate.state != state || oldDelegate.pinned != pinned;
  }
}
