// by claude
part of 'edit_tags_dialog.dart';

/// crop box in image pixels, moved or resized from one corner while the opposite corner stays.
@visibleForTesting
class ArtworkCropBox {
  final Size imageSize;

  /// width / height, null when the box is free.
  double? aspectRatio;
  Rect rect;

  ArtworkCropBox(this.imageSize, {required this.aspectRatio}) : rect = _largestBoxInside(Offset.zero & imageSize, aspectRatio: aspectRatio);

  static const kMinSide = 16.0;

  static Rect _largestBoxInside(Rect area, {required double? aspectRatio}) {
    if (aspectRatio == null) return area;
    final isAreaWider = area.width / area.height > aspectRatio;
    final width = isAreaWider ? area.height * aspectRatio : area.width;
    final height = width / aspectRatio;
    return Rect.fromCenter(center: area.center, width: width, height: height);
  }

  /// the box becomes the largest one of [aspectRatio] in the image, around where it was.
  void setAspectRatio(double? aspectRatio) {
    this.aspectRatio = aspectRatio;
    if (aspectRatio == null) return;
    final largest = _largestBoxInside(Offset.zero & imageSize, aspectRatio: aspectRatio);
    final maxLeft = imageSize.width - largest.width;
    final maxTop = imageSize.height - largest.height;
    final center = rect.center;
    final left = (center.dx - largest.width / 2).withMinimum(0.0).withMaximum(maxLeft);
    final top = (center.dy - largest.height / 2).withMinimum(0.0).withMaximum(maxTop);
    rect = Rect.fromLTWH(left, top, largest.width, largest.height);
  }

  void move(Offset delta) {
    final maxLeft = imageSize.width - rect.width;
    final maxTop = imageSize.height - rect.height;
    final left = (rect.left + delta.dx).withMinimum(0.0).withMaximum(maxLeft);
    final top = (rect.top + delta.dy).withMinimum(0.0).withMaximum(maxTop);
    rect = Rect.fromLTWH(left, top, rect.width, rect.height);
  }

  /// [corner] is one of the 4 corner alignments, [position] is where it was dragged to.
  void dragCorner(Alignment corner, Offset position) {
    final isLeft = corner.x < 0;
    final isTop = corner.y < 0;
    final anchorX = isLeft ? rect.right : rect.left;
    final anchorY = isTop ? rect.bottom : rect.top;
    final maxWidth = isLeft ? anchorX : imageSize.width - anchorX;
    final maxHeight = isTop ? anchorY : imageSize.height - anchorY;
    var width = (position.dx - anchorX).abs().withMinimum(kMinSide).withMaximum(maxWidth);
    var height = (position.dy - anchorY).abs().withMinimum(kMinSide).withMaximum(maxHeight);
    final aspectRatio = this.aspectRatio;
    if (aspectRatio != null) {
      width = math.max(width, height * aspectRatio);
      height = width / aspectRatio;
      if (width > maxWidth) {
        width = maxWidth;
        height = width / aspectRatio;
      }
      if (height > maxHeight) {
        height = maxHeight;
        width = height * aspectRatio;
      }
    }
    final left = isLeft ? anchorX - width : anchorX;
    final top = isTop ? anchorY - height : anchorY;
    rect = Rect.fromLTWH(left, top, width, height);
  }

  static const corners = [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight];

  Offset cornerPosition(Alignment corner) {
    final x = corner.x < 0 ? rect.left : rect.right;
    final y = corner.y < 0 ? rect.top : rect.bottom;
    return Offset(x, y);
  }

  /// the corner closest to [position] within [maxDistance], null when none is.
  Alignment? cornerAt(Offset position, double maxDistance) {
    Alignment? closest;
    var closestDistance = maxDistance;
    for (final corner in corners) {
      final distance = (cornerPosition(corner) - position).distance;
      if (distance > closestDistance) continue;
      closest = corner;
      closestDistance = distance;
    }
    return closest;
  }
}

class _ArtworkCropDialog extends StatefulWidget {
  final ui.Image image;
  final Completer<Uint8List?> completer;

  const _ArtworkCropDialog({required this.image, required this.completer});

  /// png bytes of the chosen box, null when cancelled. [image] is disposed when the dialog closes.
  static Future<Uint8List?> show(ui.Image image) {
    final completer = Completer<Uint8List?>();
    NamidaNavigator.inst.navigateDialog(
      onDisposing: () => completer.completeIfWasnt(null),
      dialog: _ArtworkCropDialog(image: image, completer: completer),
    );
    return completer.future;
  }

  @override
  State<_ArtworkCropDialog> createState() => _ArtworkCropDialogState();
}

class _ArtworkCropDialogState extends State<_ArtworkCropDialog> {
  var _aspectRatio = _CropAspectRatio.square;
  late final _box = ArtworkCropBox(Size(widget.image.width.toDouble(), widget.image.height.toDouble()), aspectRatio: _aspectRatio.ratio);
  double _scale = 1.0;
  Alignment? _draggedCorner;
  bool _isMovingBox = false;
  bool _isCropping = false;

  static const _kCornerTouchRadius = 28.0;

  @override
  void dispose() {
    widget.image.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    final position = details.localPosition / _scale;
    final maxDistance = _kCornerTouchRadius / _scale;
    _draggedCorner = _box.cornerAt(position, maxDistance);
    _isMovingBox = _draggedCorner == null && _box.rect.contains(position);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final draggedCorner = _draggedCorner;
    if (draggedCorner != null) {
      final position = details.localPosition / _scale;
      setState(() => _box.dragCorner(draggedCorner, position));
    } else if (_isMovingBox) {
      final delta = details.delta / _scale;
      setState(() => _box.move(delta));
    }
  }

  void _onAspectRatioSelect(_CropAspectRatio aspectRatio) {
    _aspectRatio = aspectRatio;
    setState(() => _box.setAspectRatio(aspectRatio.ratio));
  }

  List<NamidaPopupItem> _getAspectRatioItems() {
    return _CropAspectRatio.values
        .map(
          (e) => NamidaPopupItem(
            icon: e.toIcon(),
            title: e.toText(),
            selected: e == _aspectRatio,
            onTap: () => _onAspectRatioSelect(e),
          ),
        )
        .toFixedList();
  }

  static Future<Uint8List?> _cropToPng(ui.Image image, Rect box) async {
    final sourceRect = Rect.fromLTRB(box.left.roundToDouble(), box.top.roundToDouble(), box.right.roundToDouble(), box.bottom.roundToDouble());
    final width = sourceRect.width.toInt();
    final height = sourceRect.height.toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final destinationRect = Rect.fromLTWH(0, 0, sourceRect.width, sourceRect.height);
    canvas.drawImageRect(image, sourceRect, destinationRect, Paint());
    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(width, height);
    picture.dispose();
    final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    croppedImage.dispose();
    return byteData?.buffer.asUint8List();
  }

  Future<void> _onConfirm() async {
    setState(() => _isCropping = true);
    final bytes = await _cropToPng(widget.image, _box.rect);
    widget.completer.completeIfWasnt(bytes);
    NamidaNavigator.inst.closeDialog();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final imageWidth = image.width;
    final imageHeight = image.height;
    final boxColor = context.theme.colorScheme.secondary;
    return CustomBlurryDialog(
      title: lang.crop,
      icon: Broken.crop,
      normalTitleStyle: true,
      trailingWidgets: [
        NamidaPopupWrapper(
          childrenDefault: _getAspectRatioItems,
          childBuilder: (openMenu) => NamidaInkWell(
            onTap: openMenu,
            borderRadius: 8.0,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _aspectRatio.toIcon(),
                  size: 18.0,
                ),
                const SizedBox(width: 6.0),
                NamidaText(
                  _aspectRatio.toText(),
                  style: NText.medium,
                ),
                const SizedBox(width: 2.0),
                const Icon(
                  Broken.arrow_down_2,
                  size: 14.0,
                ),
              ],
            ),
          ),
        ),
      ],
      actions: [
        const CancelButton(),
        NamidaButton(
          enabled: !_isCropping,
          isLoading: _isCropping,
          text: lang.confirm,
          onTap: _onConfirm,
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = namida.height * 0.5;
          final scale = math.min(constraints.maxWidth / imageWidth, maxHeight / imageHeight);
          _scale = scale;
          return Center(
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              child: CustomPaint(
                size: Size(imageWidth * scale, imageHeight * scale),
                painter: _ArtworkCropPainter(
                  image: image,
                  box: _box.rect,
                  scale: scale,
                  boxColor: boxColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ArtworkCropPainter extends CustomPainter {
  final ui.Image image;
  final Rect box;
  final double scale;
  final Color boxColor;

  const _ArtworkCropPainter({required this.image, required this.box, required this.scale, required this.boxColor});

  static const _kCornerDotRadius = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final imageRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final displayRect = Offset.zero & size;
    canvas.drawImageRect(image, imageRect, displayRect, Paint()..filterQuality = FilterQuality.medium);

    final displayBox = Rect.fromLTRB(box.left * scale, box.top * scale, box.right * scale, box.bottom * scale);
    final outsidePath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(displayRect)
      ..addRect(displayBox);
    canvas.drawPath(outsidePath, Paint()..color = Colors.black.withOpacityExt(0.55));

    final boxPaint = Paint()
      ..color = boxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(displayBox, boxPaint);

    final dotPaint = Paint()..color = boxColor;
    for (final corner in ArtworkCropBox.corners) {
      final dotCenter = corner.withinRect(displayBox);
      canvas.drawCircle(dotCenter, _kCornerDotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ArtworkCropPainter oldDelegate) {
    return oldDelegate.box != box || oldDelegate.scale != scale || oldDelegate.boxColor != boxColor || oldDelegate.image != image;
  }
}

enum _CropAspectRatio {
  free(null),
  square(1.0),
  landscape4by3(4 / 3),
  portrait3by4(3 / 4),
  landscape16by9(16 / 9),
  portrait9by16(9 / 16),
  ;

  /// width / height, null when free.
  final double? ratio;
  const _CropAspectRatio(this.ratio);

  String toText() => switch (this) {
    free => lang.custom,
    square => '1:1',
    landscape4by3 => '4:3',
    portrait3by4 => '3:4',
    landscape16by9 => '16:9',
    portrait9by16 => '9:16',
  };

  IconData toIcon() => switch (this) {
    free => Broken.maximize_3,
    square => Broken.square,
    landscape4by3 || landscape16by9 => Broken.monitor,
    portrait3by4 || portrait9by16 => Broken.mobile,
  };
}
