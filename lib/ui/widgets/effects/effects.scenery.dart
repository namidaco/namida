part of 'effects.dart';

class _SceneryBrush {
  _SceneryBrush(this.scenery, this.colors);

  final _Scenery scenery;
  final List<Color> colors;

  static const auroraColors = [Color(0xFF4DE8B0), Color(0xFF6A8CFF), Color(0xFFD06AFF)];

  static const _columnWidth = 18.0;
  static const _auroraBands = 3;
  static const _raysCount = 4;
  static const _waterTop = Color(0x40071C3F);
  static const _waterBottom = Color(0xA6010814);
  static const _waterTopLight = Color(0x1A3AA0D8);
  static const _waterBottomLight = Color(0x661F5FA0);
  static const _hasLightRays = false;
  static const _rayRgb = 0xBFE9FF;

  final _paint = Paint();
  final _waterPaint = Paint();
  Size _shadedSize = Size.zero;
  bool _isShadedDark = false;

  Float32List _positions = Float32List(0);
  Int32List _vertexColors = Int32List(0);
  Uint16List _indices = Uint16List(0);
  int _columns = 0;

  late final _rayPositions = Float32List(_raysCount * 8);
  late final _rayColors = Int32List(_raysCount * 4);
  late final _rayIndices = _buildRayIndices();

  void paint(Canvas canvas, Size size, {required double time, required bool isDark, required double opacity}) {
    switch (scenery) {
      case _Scenery.none:
        return;
      case _Scenery.aurora:
        _paintAurora(canvas, size, time, opacity);
      case _Scenery.deepWater:
        _paintWater(canvas, size, isDark, opacity);
        if (_hasLightRays) _paintRays(canvas, size, time, opacity);
    }
  }

  // -- every column is a vertex above, inside and under the band, so it fades out both ways wherever it waves to
  void _paintAurora(Canvas canvas, Size size, double time, double opacity) {
    final width = size.width;
    final height = size.height;
    final columns = (width / _columnWidth).ceil() + 1;
    if (columns != _columns) {
      _columns = columns;
      _positions = Float32List(columns * 6);
      _vertexColors = Int32List(columns * 3);
      _indices = _buildBandIndices(columns);
    }

    final level = _EffectsPulse.level;
    final positions = _positions;
    final vertexColors = _vertexColors;
    final reach = height * 0.30;
    final swell = height * 0.04;
    _paint.color = Color.fromRGBO(255, 255, 255, opacity);

    for (int band = 0; band < _auroraBands; band++) {
      final color = colors[band % colors.length];
      final rgb = color.intValue & 0xFFFFFF;
      final top = height * (0.03 + 0.07 * band);
      final drift = time * (0.30 - 0.06 * band);
      for (int column = 0; column < columns; column++) {
        final x = column * _columnWidth;
        final wave = math.sin(x * 0.010 + drift + band * 1.7) + 0.5 * math.sin(x * 0.023 - drift * 0.7 + band);
        final crest = top + wave * swell;
        final curtain = 0.5 + 0.5 * math.sin(x * 0.017 + time * 0.22 + band * 2.3);
        final brightness = (0.22 + 0.30 * curtain) * (0.7 + 0.3 * level);
        final brightnessByte = (brightness * 255).round();
        final at = column * 6;
        positions[at] = x;
        positions[at + 1] = crest;
        positions[at + 2] = x;
        positions[at + 3] = crest + reach * 0.32;
        positions[at + 4] = x;
        positions[at + 5] = crest + reach * (0.8 + 0.2 * curtain);
        final colorAt = column * 3;
        vertexColors[colorAt] = rgb;
        vertexColors[colorAt + 1] = (brightnessByte << 24) | rgb;
        vertexColors[colorAt + 2] = rgb;
      }
      final vertices = ui.Vertices.raw(ui.VertexMode.triangles, positions, colors: vertexColors, indices: _indices);
      canvas.drawVertices(vertices, BlendMode.modulate, _paint);
      vertices.dispose();
    }
  }

  void _paintWater(Canvas canvas, Size size, bool isDark, double opacity) {
    if (_shadedSize != size || _isShadedDark != isDark) {
      _shadedSize = size;
      _isShadedDark = isDark;
      final bottom = Offset(0, size.height);
      final water = isDark ? const [_waterTop, _waterBottom] : const [_waterTopLight, _waterBottomLight];
      _waterPaint.shader = ui.Gradient.linear(Offset.zero, bottom, water);
    }
    _waterPaint.color = Color.fromRGBO(255, 255, 255, opacity);
    canvas.drawRect(Offset.zero & size, _waterPaint);
  }

  void _paintRays(Canvas canvas, Size size, double time, double opacity) {
    final width = size.width;
    final depth = size.height * 0.72;
    final positions = _rayPositions;
    final rayColors = _rayColors;
    for (int ray = 0; ray < _raysCount; ray++) {
      final sway = math.sin(time * 0.16 + ray * 1.9);
      final shimmer = 0.5 + 0.5 * math.sin(time * 0.4 + ray * 2.7);
      final from = width * ((ray + 0.6) / _raysCount) + sway * width * 0.04;
      final mouth = width * 0.035;
      final spread = width * (0.13 + 0.03 * ray);
      final lean = width * 0.16 + sway * width * 0.03;
      final brightnessByte = ((0.10 + 0.08 * shimmer) * 255).round();
      final at = ray * 8;
      positions[at] = from - mouth;
      positions[at + 1] = 0.0;
      positions[at + 2] = from + mouth;
      positions[at + 3] = 0.0;
      positions[at + 4] = from - lean - spread;
      positions[at + 5] = depth;
      positions[at + 6] = from - lean + spread;
      positions[at + 7] = depth;
      final colorAt = ray * 4;
      rayColors[colorAt] = (brightnessByte << 24) | _rayRgb;
      rayColors[colorAt + 1] = (brightnessByte << 24) | _rayRgb;
      rayColors[colorAt + 2] = _rayRgb;
      rayColors[colorAt + 3] = _rayRgb;
    }
    _paint.color = Color.fromRGBO(255, 255, 255, opacity);
    final vertices = ui.Vertices.raw(ui.VertexMode.triangles, positions, colors: rayColors, indices: _rayIndices);
    canvas.drawVertices(vertices, BlendMode.modulate, _paint);
    vertices.dispose();
  }

  static Uint16List _buildBandIndices(int columns) {
    final indices = Uint16List((columns - 1) * 12);
    int at = 0;
    for (int column = 0; column < columns - 1; column++) {
      final vertex = column * 3;
      final next = vertex + 3;
      for (int row = 0; row < 2; row++) {
        indices[at++] = vertex + row;
        indices[at++] = next + row;
        indices[at++] = vertex + row + 1;
        indices[at++] = next + row;
        indices[at++] = next + row + 1;
        indices[at++] = vertex + row + 1;
      }
    }
    return indices;
  }

  static Uint16List _buildRayIndices() {
    final indices = Uint16List(_raysCount * 6);
    for (int ray = 0; ray < _raysCount; ray++) {
      final vertex = ray * 4;
      final at = ray * 6;
      indices[at] = vertex;
      indices[at + 1] = vertex + 1;
      indices[at + 2] = vertex + 2;
      indices[at + 3] = vertex + 1;
      indices[at + 4] = vertex + 3;
      indices[at + 5] = vertex + 2;
    }
    return indices;
  }
}
