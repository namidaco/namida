part of 'effects.dart';

abstract class _SpriteAtlas {
  static const _width = 640;
  static const _height = 512;

  static ui.Image? _image;

  static ui.Image obtain() => _image ??= _paintAtlas();

  static ui.Image _paintAtlas() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final sprite in _Sprite.values) {
      canvas.save();
      final cell = Rect.fromLTWH(0, 0, sprite.width, sprite.height);
      canvas.translate(sprite.left, sprite.top);
      canvas.clipRect(cell);
      switch (sprite) {
        case _Sprite.dot:
          _paintDot(canvas);
        case _Sprite.glow:
          _paintGlow(canvas);
        case _Sprite.flake:
          _paintFlake(canvas);
        case _Sprite.sparkle:
          _paintSparkle(canvas);
        case _Sprite.leaf:
          _paintLeaf(canvas);
        case _Sprite.bulb:
          _paintBulb(canvas);
        case _Sprite.batUp:
          _paintBat(canvas, wingsUp: true);
        case _Sprite.batDown:
          _paintBat(canvas, wingsUp: false);
        case _Sprite.ghost:
          _paintGhost(canvas);
        case _Sprite.pumpkin:
          _paintPumpkin(canvas);
        case _Sprite.lantern:
          _paintLantern(canvas);
        case _Sprite.lanternPanelled:
          _paintPanelledLantern(canvas);
        case _Sprite.crescent:
          _paintCrescent(canvas);
        case _Sprite.skull:
          _paintSkull(canvas);
        case _Sprite.snowman:
          _paintSnowman(canvas);
        case _Sprite.petal:
          _paintPetal(canvas);
        case _Sprite.streak:
          _paintStreak(canvas);
        case _Sprite.bubble:
          _paintBubble(canvas);
        case _Sprite.jellyfish:
          _paintJellyfish(canvas);
        case _Sprite.fishRight:
          _paintFish(canvas, isHeadingRight: true);
        case _Sprite.fishLeft:
          _paintFish(canvas, isHeadingRight: false);
      }
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(_width, _height);
    picture.dispose();
    return image;
  }

  static const _white = Color(0xFFFFFFFF);
  static const _clear = Color(0x00FFFFFF);

  static Paint _radialPaint(Offset center, double radius, List<Color> colors, List<double> stops) {
    return Paint()..shader = ui.Gradient.radial(center, radius, colors, stops);
  }

  static void _paintDot(Canvas canvas) {
    const center = Offset(32, 32);
    final paint = _radialPaint(center, 31, const [_white, _white, _clear], const [0.0, 0.92, 1.0]);
    canvas.drawCircle(center, 31, paint);
  }

  static void _paintGlow(Canvas canvas) {
    const center = Offset(32, 32);
    final paint = _radialPaint(center, 32, const [_white, Color(0x66FFFFFF), _clear], const [0.0, 0.4, 1.0]);
    canvas.drawCircle(center, 32, paint);
  }

  static void _paintFlake(Canvas canvas) {
    const center = Offset(32, 32);
    final paint = Paint()
      ..color = _white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    const armLength = 26.0;
    const branchAt = 0.58;
    const branchLength = 9.0;
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(center, center + direction * armLength, paint);
      final branchStart = center + direction * (armLength * branchAt);
      for (final side in const [-1.0, 1.0]) {
        final branchAngle = angle + side * math.pi / 3;
        final branchDirection = Offset(math.cos(branchAngle), math.sin(branchAngle));
        canvas.drawLine(branchStart, branchStart + branchDirection * branchLength, paint);
      }
    }
  }

  static void _paintSparkle(Canvas canvas) {
    const center = Offset(32, 32);
    final halo = _radialPaint(center, 30, const [Color(0x70FFFFFF), _clear], const [0.0, 1.0]);
    canvas.drawCircle(center, 30, halo);
    const tip = 29.0;
    const waist = 4.5;
    final path = Path()..moveTo(center.dx, center.dy - tip);
    for (int i = 1; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final radius = i.isEven ? tip : waist;
      path.lineTo(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius);
    }
    path.close();
    final fill = Paint()..color = _white;
    canvas.drawPath(path, fill);
  }

  static void _paintLeaf(Canvas canvas) {
    final blade = Path()
      ..moveTo(32, 5)
      ..cubicTo(56, 16, 56, 40, 32, 56)
      ..cubicTo(8, 40, 8, 16, 32, 5)
      ..close();
    final fill = Paint()..color = _white;
    canvas.drawPath(blade, fill);
    final vein = Paint()
      ..color = const Color(0x55000000)
      ..blendMode = BlendMode.dstOut
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(32, 12), const Offset(32, 52), vein);
    canvas.drawLine(const Offset(32, 28), const Offset(43, 20), vein);
    canvas.drawLine(const Offset(32, 38), const Offset(21, 30), vein);
    final stem = Paint()
      ..color = _white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(32, 54), const Offset(32, 62), stem);
  }

  static void _paintBulb(Canvas canvas) {
    const center = Offset(32, 32);
    final halo = _radialPaint(center, 32, const [Color(0x99FFFFFF), Color(0x33FFFFFF), _clear], const [0.0, 0.45, 1.0]);
    final fill = Paint()..color = _white;
    canvas.drawCircle(center, 32, halo);
    canvas.drawCircle(center, 11, fill);
  }

  static void _paintBat(Canvas canvas, {required bool wingsUp}) {
    final paint = Paint()..color = _white;
    final tipY = wingsUp ? 34.0 : 84.0;
    final lift = wingsUp ? -1.0 : 1.0;
    final shoulderY = wingsUp ? 60.0 : 62.0;
    final leadingEdgeY = wingsUp ? 14.0 : 38.0;
    const body = Rect.fromLTRB(54.5, 52, 73.5, 84);
    for (final side in const [-1.0, 1.0]) {
      double x(double fromCenter) => 64 + side * fromCenter;
      final wing = Path()
        ..moveTo(x(5), shoulderY)
        ..quadraticBezierTo(x(30), leadingEdgeY, x(59), tipY)
        ..quadraticBezierTo(x(47), tipY + 8 + 6 * lift, x(44), tipY + 24 + 4 * lift)
        ..quadraticBezierTo(x(35), tipY + 10 + 6 * lift, x(27), tipY + 28 + 4 * lift)
        ..quadraticBezierTo(x(19), tipY + 14 + 8 * lift, x(8), shoulderY + 20)
        ..close();
      canvas.drawPath(wing, paint);
      final ear = Path()
        ..moveTo(x(2), 46)
        ..lineTo(x(9), 30)
        ..lineTo(x(11), 48)
        ..close();
      canvas.drawPath(ear, paint);
    }
    canvas.drawOval(body, paint);
    canvas.drawCircle(const Offset(64, 50), 10, paint);
  }

  static void _paintGhost(Canvas canvas) {
    const cell = Rect.fromLTWH(0, 0, 128, 128);
    final layer = Paint();
    canvas.saveLayer(cell, layer);
    final body = Path()
      ..moveTo(28, 114)
      ..lineTo(28, 58)
      ..cubicTo(28, 6, 100, 6, 100, 58)
      ..lineTo(100, 114)
      ..quadraticBezierTo(88, 96, 76, 114)
      ..quadraticBezierTo(64, 96, 52, 114)
      ..quadraticBezierTo(40, 96, 28, 114)
      ..close();
    const leftEye = Rect.fromLTRB(43.5, 44.5, 56.5, 63.5);
    const rightEye = Rect.fromLTRB(71.5, 44.5, 84.5, 63.5);
    const mouth = Rect.fromLTRB(58.5, 73, 69.5, 87);
    final fill = Paint()..color = _white;
    final hole = Paint()..blendMode = BlendMode.clear;
    canvas.drawPath(body, fill);
    canvas.drawOval(leftEye, hole);
    canvas.drawOval(rightEye, hole);
    canvas.drawOval(mouth, hole);
    canvas.restore();
  }

  static void _paintPumpkin(Canvas canvas) {
    const center = Offset(64, 74);
    final halo = _radialPaint(center, 62, const [Color(0x55FFA63D), Color(0x00FFA63D)], const [0.45, 1.0]);
    canvas.drawCircle(center, 62, halo);

    final stem = Path()
      ..moveTo(58, 40)
      ..quadraticBezierTo(58, 26, 70, 20)
      ..lineTo(76, 27)
      ..quadraticBezierTo(69, 32, 70, 42)
      ..close();
    final stemFill = Paint()..color = const Color(0xFF5E7A2E);
    canvas.drawPath(stem, stemFill);

    const outerLeft = Rect.fromLTRB(14, 45, 58, 107);
    const outerRight = Rect.fromLTRB(70, 45, 114, 107);
    const innerLeft = Rect.fromLTRB(26, 40, 72, 110);
    const innerRight = Rect.fromLTRB(56, 40, 102, 110);
    const middleRib = Rect.fromLTRB(44, 38.5, 84, 111.5);
    final outer = Paint()..color = const Color(0xFFD9651A);
    final inner = Paint()..color = const Color(0xFFEE8125);
    final middle = Paint()..color = const Color(0xFFF79B3A);
    canvas.drawOval(outerLeft, outer);
    canvas.drawOval(outerRight, outer);
    canvas.drawOval(innerLeft, inner);
    canvas.drawOval(innerRight, inner);
    canvas.drawOval(middleRib, middle);

    final face = Paint()..color = const Color(0xFFFFE27A);
    for (final side in const [-1.0, 1.0]) {
      final eye = Path()
        ..moveTo(64 + side * 12, 66)
        ..lineTo(64 + side * 30, 66)
        ..lineTo(64 + side * 20, 50)
        ..close();
      canvas.drawPath(eye, face);
    }
    final mouth = Path()
      ..moveTo(36, 82)
      ..lineTo(46, 88)
      ..lineTo(54, 82)
      ..lineTo(64, 89)
      ..lineTo(74, 82)
      ..lineTo(82, 88)
      ..lineTo(92, 82)
      ..quadraticBezierTo(64, 112, 36, 82)
      ..close();
    canvas.drawPath(mouth, face);
  }

  static void _paintLantern(Canvas canvas) {
    const frameColor = Color(0xFFB07A1E);
    final frame = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final solid = Paint()..color = frameColor;

    frame.strokeWidth = 2.0;
    canvas.drawLine(const Offset(64, 0), const Offset(64, 70), frame);
    frame.strokeWidth = 3.0;
    canvas.drawCircle(const Offset(64, 76), 6, frame);

    const bodyCenter = Offset(64, 152);
    final halo = _radialPaint(bodyCenter, 64, const [Color(0x66FFC65A), Color(0x00FFC65A)], const [0.35, 1.0]);
    canvas.drawCircle(bodyCenter, 64, halo);

    final cap = Path()
      ..moveTo(38, 106)
      ..quadraticBezierTo(44, 84, 64, 82)
      ..quadraticBezierTo(84, 84, 90, 106)
      ..close();
    canvas.drawPath(cap, solid);

    final body = Path()
      ..moveTo(38, 106)
      ..lineTo(90, 106)
      ..lineTo(102, 150)
      ..lineTo(88, 200)
      ..lineTo(40, 200)
      ..lineTo(26, 150)
      ..close();
    final light = _radialPaint(bodyCenter, 56, const [Color(0xFFFFF3C4), Color(0xFFFFC857), Color(0xFFF08A24)], const [0.0, 0.55, 1.0]);
    canvas.drawPath(body, light);
    canvas.drawPath(body, frame);
    canvas.drawLine(const Offset(26, 150), const Offset(102, 150), frame);
    canvas.drawLine(const Offset(64, 106), const Offset(64, 200), frame);
    canvas.drawLine(const Offset(51, 106), const Offset(45, 150), frame);
    canvas.drawLine(const Offset(45, 150), const Offset(52, 200), frame);
    canvas.drawLine(const Offset(77, 106), const Offset(83, 150), frame);
    canvas.drawLine(const Offset(83, 150), const Offset(76, 200), frame);

    final base = Path()
      ..moveTo(40, 200)
      ..lineTo(88, 200)
      ..lineTo(78, 214)
      ..lineTo(50, 214)
      ..close();
    const tassel = Rect.fromLTRB(59.5, 233.5, 68.5, 250.5);
    frame.strokeWidth = 2.0;
    canvas.drawPath(base, solid);
    canvas.drawLine(const Offset(64, 214), const Offset(64, 234), frame);
    canvas.drawOval(tassel, solid);
  }

  static void _paintPanelledLantern(Canvas canvas) {
    const lightColor = Color(0xFFFFE9A8);
    const metalColors = [Color(0xFF9C6B1C), Color(0xFFFFE08A), Color(0xFFD9A441), Color(0xFF9C6B1C)];
    const metalStops = [0.0, 0.35, 0.6, 1.0];
    final metal = ui.Gradient.linear(const Offset(20, 0), const Offset(108, 0), metalColors, metalStops);
    final solid = Paint()..shader = metal;
    final frame = Paint()
      ..shader = metal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final light = Paint()..color = lightColor;

    canvas.drawLine(const Offset(64, 0), const Offset(64, 40), frame);
    frame.strokeWidth = 3.0;
    canvas.drawCircle(const Offset(64, 49), 8, frame);
    canvas.drawCircle(const Offset(64, 61), 3.5, solid);

    const bodyCenter = Offset(64, 162);
    final halo = _radialPaint(bodyCenter, 64, const [Color(0x59FFC65A), Color(0x00FFC65A)], const [0.35, 1.0]);
    canvas.drawCircle(bodyCenter, 64, halo);

    final dome = Path()
      ..moveTo(32, 106)
      ..cubicTo(27, 86, 53, 84, 64, 63)
      ..cubicTo(75, 84, 101, 86, 96, 106)
      ..close();
    final domeCrescent = _crescentAt(const Offset(64, 93), 7);
    canvas.drawPath(dome, solid);
    canvas.drawPath(domeCrescent, light);
    canvas.drawCircle(const Offset(46, 98), 2.4, light);
    canvas.drawCircle(const Offset(82, 98), 2.4, light);

    const rim = Rect.fromLTRB(24, 104, 104, 113);
    final rimShape = RRect.fromRectAndRadius(rim, const Radius.circular(3));
    canvas.drawRRect(rimShape, solid);
    for (int scallop = 0; scallop < 7; scallop++) {
      final center = Offset(30 + scallop * 11.33, 114);
      canvas.drawCircle(center, 4.5, solid);
    }

    const body = Rect.fromLTRB(30, 116, 98, 206);
    const lampAt = Offset(64, 204);
    final glassShade = ui.Gradient.linear(body.topCenter, body.bottomCenter, const [Color(0xFF14204F), Color(0xFF2A4594)]);
    final glass = Paint()..shader = glassShade;
    final lamp = _radialPaint(lampAt, 72, const [Color(0xB3FFC65A), Color(0x00FFC65A)], const [0.0, 1.0]);
    canvas.drawRect(body, glass);
    canvas.save();
    canvas.clipRect(body);
    canvas.drawCircle(lampAt, 72, lamp);
    canvas.restore();

    final panelCrescent = _crescentAt(const Offset(64, 138), 11);
    canvas.drawPath(panelCrescent, light);
    canvas.drawCircle(const Offset(75, 128), 1.8, light);

    const mosqueHall = Rect.fromLTRB(55, 190, 73, 204);
    canvas.drawCircle(const Offset(64, 189), 9, light);
    canvas.drawRect(mosqueHall, light);
    canvas.drawLine(const Offset(64, 174), const Offset(64, 181), frame);
    for (final side in const [-1.0, 1.0]) {
      final minaretX = 64 + side * 14.5;
      final minaret = Path()
        ..moveTo(minaretX - 2, 204)
        ..lineTo(minaretX - 2, 174)
        ..lineTo(minaretX, 167)
        ..lineTo(minaretX + 2, 174)
        ..lineTo(minaretX + 2, 204)
        ..close();
      final sideCrescent = _crescentAt(Offset(64 + side * 25, 146), 5);
      canvas.drawPath(minaret, light);
      canvas.drawPath(sideCrescent, light);
      canvas.drawCircle(Offset(64 + side * 25, 166), 1.8, light);
      canvas.drawCircle(Offset(64 + side * 25, 182), 1.8, light);
    }

    canvas.drawRect(body, frame);
    canvas.drawLine(const Offset(48, 116), const Offset(48, 206), frame);
    canvas.drawLine(const Offset(80, 116), const Offset(80, 206), frame);

    final base = Path()
      ..moveTo(30, 206)
      ..lineTo(98, 206)
      ..lineTo(108, 224)
      ..lineTo(20, 224)
      ..close();
    const plate = Rect.fromLTRB(18, 224, 110, 230);
    final plateShape = RRect.fromRectAndRadius(plate, const Radius.circular(3));
    canvas.drawPath(base, solid);
    canvas.drawRRect(plateShape, solid);
    for (int hole = 0; hole < 8; hole++) {
      final center = Offset(30 + hole * 9.7, 215);
      canvas.drawCircle(center, 2.2, light);
    }
    canvas.drawCircle(const Offset(26, 233), 3.5, solid);
    canvas.drawCircle(const Offset(64, 234), 3.5, solid);
    canvas.drawCircle(const Offset(102, 233), 3.5, solid);
  }

  static Path _crescentAt(Offset center, double radius) {
    final shadeCenter = center.translate(radius * 0.43, radius * -0.24);
    final moonBounds = Rect.fromCircle(center: center, radius: radius);
    final shadeBounds = Rect.fromCircle(center: shadeCenter, radius: radius * 0.905);
    final moon = Path()..addOval(moonBounds);
    final shade = Path()..addOval(shadeBounds);
    return Path.combine(PathOperation.difference, moon, shade);
  }

  static void _paintCrescent(Canvas canvas) {
    const center = Offset(64, 64);
    final halo = _radialPaint(center, 64, const [Color(0x55FFE9A8), Color(0x00FFE9A8)], const [0.4, 1.0]);
    final crescent = _crescentAt(center, 42);
    final fill = Paint()..color = const Color(0xFFFFE9A8);
    canvas.drawCircle(center, 64, halo);
    canvas.drawPath(crescent, fill);
  }

  static void _paintSkull(Canvas canvas) {
    const cell = Rect.fromLTWH(0, 0, 128, 128);
    const jaw = Rect.fromLTRB(42, 70, 86, 114);
    const leftSocket = Rect.fromLTRB(36, 44, 58, 70);
    const rightSocket = Rect.fromLTRB(70, 44, 92, 70);
    final jawShape = RRect.fromRectAndRadius(jaw, const Radius.circular(11));
    final nose = Path()
      ..moveTo(64, 70)
      ..lineTo(71, 84)
      ..lineTo(57, 84)
      ..close();
    final layer = Paint();
    final fill = Paint()..color = _white;
    final hole = Paint()..blendMode = BlendMode.clear;
    final gap = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.saveLayer(cell, layer);
    canvas.drawCircle(const Offset(64, 54), 41, fill);
    canvas.drawRRect(jawShape, fill);
    canvas.drawOval(leftSocket, hole);
    canvas.drawOval(rightSocket, hole);
    canvas.drawPath(nose, hole);
    canvas.drawLine(const Offset(42, 98), const Offset(86, 98), gap);
    canvas.drawLine(const Offset(53, 92), const Offset(53, 114), gap);
    canvas.drawLine(const Offset(64, 92), const Offset(64, 114), gap);
    canvas.drawLine(const Offset(75, 92), const Offset(75, 114), gap);
    canvas.restore();
  }

  static void _paintSnowman(Canvas canvas) {
    const snowColor = Color(0xFFF7FBFF);
    const shadeColor = Color(0xFFB9D3EA);
    const coalColor = Color(0xFF2A2E38);
    const scarfColor = Color(0xFFE5484D);
    final snow = Paint()..color = snowColor;
    final shade = Paint()
      ..color = shadeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final coal = Paint()..color = coalColor;
    final scarf = Paint()..color = scarfColor;
    final carrot = Paint()..color = const Color(0xFFF08A24);
    final twig = Paint()
      ..color = const Color(0xFF8A5A33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(42, 84), const Offset(16, 66), twig);
    canvas.drawLine(const Offset(86, 84), const Offset(112, 66), twig);
    canvas.drawLine(const Offset(24, 72), const Offset(20, 60), twig);
    canvas.drawLine(const Offset(104, 72), const Offset(108, 60), twig);

    const body = Offset(64, 94);
    const head = Offset(64, 50);
    canvas.drawCircle(body, 30, snow);
    canvas.drawCircle(body, 30, shade);
    canvas.drawCircle(head, 21, snow);
    canvas.drawCircle(head, 21, shade);

    const scarfBand = Rect.fromLTRB(45, 64, 83, 74);
    const scarfTail = Rect.fromLTRB(72, 70, 82, 92);
    final scarfBandShape = RRect.fromRectAndRadius(scarfBand, const Radius.circular(5));
    final scarfTailShape = RRect.fromRectAndRadius(scarfTail, const Radius.circular(4));
    canvas.drawRRect(scarfTailShape, scarf);
    canvas.drawRRect(scarfBandShape, scarf);

    const hatTop = Rect.fromLTRB(49, 10, 79, 32);
    const hatBrim = Rect.fromLTRB(40, 29, 88, 35);
    const hatBand = Rect.fromLTRB(49, 25, 79, 30);
    final hatTopShape = RRect.fromRectAndRadius(hatTop, const Radius.circular(3));
    final hatBrimShape = RRect.fromRectAndRadius(hatBrim, const Radius.circular(3));
    canvas.drawRRect(hatTopShape, coal);
    canvas.drawRRect(hatBrimShape, coal);
    canvas.drawRect(hatBand, scarf);

    canvas.drawCircle(const Offset(56, 46), 2.6, coal);
    canvas.drawCircle(const Offset(72, 46), 2.6, coal);
    canvas.drawCircle(const Offset(64, 86), 2.8, coal);
    canvas.drawCircle(const Offset(64, 100), 2.8, coal);
    final nose = Path()
      ..moveTo(63, 50)
      ..lineTo(84, 55)
      ..lineTo(63, 58)
      ..close();
    canvas.drawPath(nose, carrot);
  }

  static void _paintPetal(Canvas canvas) {
    final petal = Path()
      ..moveTo(32, 60)
      ..cubicTo(4, 40, 10, 12, 27, 5)
      ..lineTo(32, 13)
      ..lineTo(37, 5)
      ..cubicTo(54, 12, 60, 40, 32, 60)
      ..close();
    final shade = ui.Gradient.linear(const Offset(32, 5), const Offset(32, 60), const [_white, Color(0xB3FFFFFF)]);
    final fill = Paint()..shader = shade;
    canvas.drawPath(petal, fill);
  }

  static void _paintStreak(Canvas canvas) {
    const tail = Offset(32, 2);
    const head = Offset(32, 62);
    final fade = ui.Gradient.linear(tail, head, const [_clear, _white]);
    final stroke = Paint()
      ..shader = fade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tail, head, stroke);
  }

  static void _paintBubble(Canvas canvas) {
    const center = Offset(32, 32);
    final body = _radialPaint(center, 28, const [Color(0x14FFFFFF), Color(0x40FFFFFF), _white, _clear], const [0.0, 0.78, 0.92, 1.0]);
    final shine = Paint()..color = const Color(0xD9FFFFFF);
    const shineBounds = Rect.fromLTRB(18, 16, 30, 24);
    canvas.drawCircle(center, 28, body);
    canvas.drawOval(shineBounds, shine);
  }

  static void _paintJellyfish(Canvas canvas) {
    const bellCenter = Offset(64, 48);
    final halo = _radialPaint(bellCenter, 62, const [Color(0x59FFFFFF), _clear], const [0.2, 1.0]);
    final bellShade = ui.Gradient.linear(const Offset(64, 14), const Offset(64, 66), const [_white, Color(0x99FFFFFF)]);
    final bellFill = Paint()..shader = bellShade;
    final arm = Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    final bell = Path()
      ..moveTo(24, 62)
      ..cubicTo(24, 2, 104, 2, 104, 62)
      ..quadraticBezierTo(94, 53, 84, 62)
      ..quadraticBezierTo(74, 53, 64, 62)
      ..quadraticBezierTo(54, 53, 44, 62)
      ..quadraticBezierTo(34, 53, 24, 62)
      ..close();
    canvas.drawCircle(bellCenter, 62, halo);
    for (int tentacle = 0; tentacle < 5; tentacle++) {
      final x = 32.0 + tentacle * 16;
      final bend = tentacle.isEven ? 7.0 : -7.0;
      final reach = tentacle.isEven ? 112.0 : 122.0;
      final trail = Path()
        ..moveTo(x, 60)
        ..cubicTo(x - bend, 78, x + bend, 96, x, reach);
      canvas.drawPath(trail, arm);
    }
    canvas.drawPath(bell, bellFill);
  }

  static void _paintFish(Canvas canvas, {required bool isHeadingRight}) {
    const cell = Rect.fromLTWH(0, 0, 128, 64);
    const body = Rect.fromLTRB(30, 14, 122, 50);
    final tail = Path()
      ..moveTo(40, 32)
      ..lineTo(6, 8)
      ..quadraticBezierTo(18, 32, 6, 56)
      ..close();
    final fin = Path()
      ..moveTo(62, 17)
      ..quadraticBezierTo(74, 0, 92, 15)
      ..close();
    final layer = Paint();
    final fill = Paint()..color = _white;
    final hole = Paint()..blendMode = BlendMode.clear;
    canvas.saveLayer(cell, layer);
    if (!isHeadingRight) {
      canvas.translate(128, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawOval(body, fill);
    canvas.drawPath(tail, fill);
    canvas.drawPath(fin, fill);
    canvas.drawCircle(const Offset(104, 28), 3.4, hole);
    canvas.restore();
  }
}

enum _Sprite {
  dot(0, 0, 64, 64),
  glow(64, 0, 64, 64),
  flake(128, 0, 64, 64),
  sparkle(192, 0, 64, 64),
  leaf(256, 0, 64, 64),
  bulb(320, 0, 64, 64),
  batUp(0, 64, 128, 128),
  batDown(128, 64, 128, 128),
  ghost(256, 64, 128, 128),
  pumpkin(384, 64, 128, 128, isTinted: false),
  lantern(0, 192, 128, 256, anchorY: 0.0, isTinted: false),
  lanternPanelled(512, 0, 128, 256, anchorY: 0.0, isTinted: false),
  crescent(128, 192, 128, 128, isTinted: false),
  skull(256, 192, 128, 128),
  snowman(384, 192, 128, 128, isTinted: false),
  petal(384, 0, 64, 64),
  streak(448, 0, 64, 64),
  bubble(256, 448, 64, 64),
  jellyfish(128, 320, 128, 128),
  fishRight(0, 448, 128, 64),
  fishLeft(128, 448, 128, 64),
  ;

  const _Sprite(this.left, this.top, this.width, this.height, {this.anchorY = 0.5, this.isTinted = true});

  final double left;
  final double top;
  final double width;
  final double height;
  final double anchorY;
  final bool isTinted;
}
