import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:extended_image/extended_image.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/packages/drop_shadow.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class ArtworkWidget extends StatefulWidget {
  /// path of image file.
  final String? path;
  final Uint8List? bytes;
  final double thumbnailSize;
  final bool forceSquared;
  final bool staggered;
  final bool compressed;
  final int fadeMilliSeconds;
  final int cacheHeight;
  final double? width;
  final double? height;
  final double? iconSize;
  final double scale;
  final double borderRadius;
  final double blur;
  final bool useTrackTileCacheHeight;
  final bool forceDummyArtwork;
  final Color? bgcolor;
  final Widget? child;
  final List<Widget> onTopWidgets;
  final List<BoxShadow>? boxShadow;
  final bool forceEnableGlow;
  final bool displayIcon;
  final IconData icon;

  const ArtworkWidget({
    super.key,
    this.bytes,
    this.compressed = true,
    this.fadeMilliSeconds = 300,
    required this.thumbnailSize,
    this.forceSquared = false,
    this.child,
    this.scale = 1.0,
    this.borderRadius = 8.0,
    this.blur = 1.5,
    this.width,
    this.height,
    this.cacheHeight = 100,
    this.useTrackTileCacheHeight = false,
    this.forceDummyArtwork = false,
    this.bgcolor,
    this.iconSize,
    this.staggered = false,
    this.boxShadow,
    this.onTopWidgets = const <Widget>[],
    this.path,
    this.forceEnableGlow = false,
    this.displayIcon = true,
    this.icon = Broken.musicnote,
  });

  @override
  State<ArtworkWidget> createState() => _ArtworkWidgetState();
}

class _ArtworkWidgetState extends State<ArtworkWidget> {
  Uint8List? _finalBytes;
  late Widget _stockWidget;
  double? _realWidthAndHeight;
  Widget? _extImageChild;
  Widget? _finalWidget;
  String? _lastPath;
  Color? _lastCardColor;
  double? _lastBorderRadius;

  Widget getImagePathWidget() {
    final pixelRatio = context.mediaQuery.devicePixelRatio;
    final cacheMultiplier = (pixelRatio * settings.artworkCacheHeightMultiplier.value).round();
    return Image.file(
      File(widget.path!),
      gaplessPlayback: true,
      fit: BoxFit.cover,
      cacheHeight: widget.useTrackTileCacheHeight ? 60 * cacheMultiplier : widget.cacheHeight * cacheMultiplier,
      filterQuality: FilterQuality.medium,
      width: _realWidthAndHeight,
      height: _realWidthAndHeight,
      frameBuilder: ((context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: Duration(milliseconds: widget.fadeMilliSeconds),
          child: frame != null ? child : const SizedBox(),
        );
      }),
      errorBuilder: (context, error, stackTrace) {
        return _stockWidget;
      },
    );
  }

  @override
  void initState() {
    _finalBytes = widget.bytes;
    super.initState();
  }

  void fillStockWidget() {
    _stockWidget = Container(
      width: widget.width ?? widget.thumbnailSize,
      height: widget.height ?? widget.thumbnailSize,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.bgcolor ?? Color.alphaBlend(context.theme.cardColor.withAlpha(100), context.theme.scaffoldBackgroundColor),
        borderRadius: BorderRadius.circular(widget.borderRadius.multipliedRadius),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.displayIcon)
            Icon(
              widget.icon,
              size: widget.iconSize ?? widget.thumbnailSize / 2,
            ),
          ...widget.onTopWidgets,
        ],
      ),
    );
  }

  void fillWidgets() {
    _lastPath = widget.path;

    if (widget.forceDummyArtwork) return;
    if (widget.path == null && widget.bytes == null) return;

    final shouldDisplayMemory = _finalBytes != null && (_finalBytes ?? []).isNotEmpty; // if bytes are sent and valid.
    final shouldDisplayPath = widget.path != null;
    if (!shouldDisplayMemory && !shouldDisplayPath) return;
    // -- [extImageChild] wont get assigned, leaving [extImageChild==null], i.e. displays [stockWidget] only.

    _realWidthAndHeight = widget.forceSquared ? context.width : null;

    _extImageChild = Stack(
      alignment: Alignment.center,
      children: [
        if (shouldDisplayMemory)
          ExtendedImage.memory(
            _finalBytes!,
            gaplessPlayback: true,
            fit: BoxFit.cover,
            clearMemoryCacheWhenDispose: true,
            filterQuality: FilterQuality.high,
            width: _realWidthAndHeight,
            height: _realWidthAndHeight,
          ),
        if (shouldDisplayPath) ...[
          widget.compressed
              ? getImagePathWidget()
              : ExtendedImage.file(
                  File(widget.path!),
                  gaplessPlayback: true,
                  fit: BoxFit.cover,
                  clearMemoryCacheWhenDispose: true,
                  filterQuality: FilterQuality.high,
                  width: _realWidthAndHeight,
                  height: _realWidthAndHeight,
                  enableLoadState: true,
                  loadStateChanged: (state) {
                    if (state.extendedImageLoadState != LoadState.completed) {
                      return getImagePathWidget();
                    }
                    return null;
                  },
                ),
        ],
        ...widget.onTopWidgets,
      ],
    );
  }

  void rebuildSpecs() {
    _lastCardColor = context.theme.cardColor;
    _lastBorderRadius = widget.borderRadius;
    final finalWidget = widget.child ?? _extImageChild ?? _stockWidget;
    _finalWidget = widget.forceEnableGlow || (settings.enableGlowEffect.value && widget.blur != 0.0)
        ? SizedBox(
            width: widget.staggered ? null : widget.width ?? widget.thumbnailSize * widget.scale,
            height: widget.staggered ? null : widget.height ?? widget.thumbnailSize * widget.scale,
            child: Center(
              child: settings.borderRadiusMultiplier.value == 0.0 || widget.borderRadius == 0
                  ? DropShadow(
                      borderRadius: widget.borderRadius.multipliedRadius,
                      blurRadius: widget.blur,
                      spread: 0.8,
                      offset: const Offset(0, 1),
                      boxShadow: widget.boxShadow,
                      child: finalWidget,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(widget.borderRadius.multipliedRadius),
                      child: DropShadow(
                        borderRadius: widget.borderRadius.multipliedRadius,
                        blurRadius: widget.blur,
                        spread: 0.8,
                        offset: const Offset(0, 1),
                        boxShadow: widget.boxShadow,
                        child: finalWidget,
                      ),
                    ),
            ),
          )
        : SizedBox(
            width: widget.staggered ? null : widget.width ?? widget.thumbnailSize * widget.scale,
            height: widget.staggered ? null : widget.height ?? widget.thumbnailSize * widget.scale,
            child: Center(
              child: Container(
                decoration: BoxDecoration(boxShadow: widget.boxShadow),
                child: settings.borderRadiusMultiplier.value == 0.0
                    ? finalWidget
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(widget.borderRadius.multipliedRadius),
                        child: finalWidget,
                      ),
              ),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    if (_finalWidget == null || _lastPath != widget.path || _lastCardColor != context.theme.cardColor) {
      fillStockWidget();
      fillWidgets();
      rebuildSpecs();
    } else if (_lastBorderRadius != widget.borderRadius) {
      fillStockWidget();
      rebuildSpecs();
    }
    return _finalWidget ?? _stockWidget;
  }
}

class MultiArtworks extends StatelessWidget {
  final List<String> paths;
  final double thumbnailSize;
  final Color? bgcolor;
  final double borderRadius;
  final Object heroTag;
  final bool disableHero;
  final double iconSize;

  const MultiArtworks({
    super.key,
    required this.paths,
    required this.thumbnailSize,
    this.bgcolor,
    this.borderRadius = 8.0,
    required this.heroTag,
    this.disableHero = false,
    this.iconSize = 29.0,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaHero(
      tag: heroTag,
      enabled: !disableHero,
      child: Container(
        height: thumbnailSize,
        width: thumbnailSize,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(borderRadius.multipliedRadius)),
        child: LayoutBuilder(
          builder: (context, c) {
            return paths.isEmpty
                ? ArtworkWidget(
                    key: UniqueKey(),
                    thumbnailSize: thumbnailSize,
                    path: allTracksInLibrary.firstOrNull?.pathToImage,
                    forceSquared: true,
                    blur: 0,
                    forceDummyArtwork: true,
                    bgcolor: bgcolor,
                    borderRadius: borderRadius,
                    iconSize: iconSize,
                    width: c.maxWidth,
                    height: c.maxHeight,
                  )
                : paths.length == 1
                    ? ArtworkWidget(
                        key: UniqueKey(),
                        thumbnailSize: thumbnailSize,
                        path: paths.elementAt(0),
                        forceSquared: true,
                        blur: 0,
                        borderRadius: 0,
                        compressed: false,
                        width: c.maxWidth,
                        height: c.maxHeight,
                      )
                    : paths.length == 2
                        ? Row(
                            children: [
                              ArtworkWidget(
                                key: UniqueKey(),
                                thumbnailSize: thumbnailSize / 2,
                                path: paths.elementAt(0),
                                forceSquared: true,
                                blur: 0,
                                borderRadius: 0,
                                iconSize: iconSize - 2.0,
                                width: c.maxWidth / 2,
                                height: c.maxHeight,
                              ),
                              ArtworkWidget(
                                key: UniqueKey(),
                                thumbnailSize: thumbnailSize / 2,
                                path: paths.elementAt(1),
                                forceSquared: true,
                                blur: 0,
                                borderRadius: 0,
                                iconSize: iconSize - 2.0,
                                width: c.maxWidth / 2,
                                height: c.maxHeight,
                              ),
                            ],
                          )
                        : paths.length == 3
                            ? Row(
                                children: [
                                  Column(
                                    children: [
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(0),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 2.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                      ),
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(1),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 2.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(2),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight,
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Row(
                                    children: [
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(0),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 3.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                      ),
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(1),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 3.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(2),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 3.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                      ),
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(3),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 3.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                      ),
                                    ],
                                  ),
                                ],
                              );
          },
        ),
      ),
    );
  }
}
