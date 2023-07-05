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

class ArtworkWidget extends StatefulWidget {
  final Track? track;

  /// path of image file.
  final String? path;
  final Uint8List? bytes;
  final double thumbnailSize;
  final bool forceSquared;
  final bool staggered;
  final bool compressed;
  final int fadeMilliSeconds;
  final int? cacheHeight;
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
    this.cacheHeight,
    this.useTrackTileCacheHeight = false,
    this.forceDummyArtwork = false,
    this.bgcolor,
    this.iconSize,
    this.staggered = false,
    this.boxShadow,
    this.onTopWidgets = const <Widget>[],
    this.path,
    required this.track,
  });

  @override
  State<ArtworkWidget> createState() => _ArtworkWidgetState();
}

class _ArtworkWidgetState extends State<ArtworkWidget> {
  Uint8List? _finalBytes;
  late Widget _stockWidget;
  double? _realWidthAndHeight;
  Widget? _finalWidget;
  Track? _lastTrack;
  double? _lastBorderRadius;

  Widget getImagePathWidget() {
    return Image.file(
      File(widget.path!),
      gaplessPlayback: true,
      fit: BoxFit.cover,
      cacheHeight: widget.useTrackTileCacheHeight
          ? SettingsController.inst.trackThumbnailSizeinList.value.toInt() > 120
              ? null
              : 60 * (context.mediaQuery.devicePixelRatio).round()
          : (widget.cacheHeight ?? 100) * (context.mediaQuery.devicePixelRatio).round(),
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

  void fillWidgets() {
    _lastTrack = widget.track;
    _lastBorderRadius = widget.borderRadius;

    _stockWidget = Container(
      width: widget.width ?? widget.thumbnailSize,
      height: widget.height ?? widget.thumbnailSize,
      key: const ValueKey("empty"),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.bgcolor ?? Color.alphaBlend(context.theme.cardColor.withAlpha(100), context.theme.scaffoldBackgroundColor),
        borderRadius: BorderRadius.circular(widget.borderRadius.multipliedRadius),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Broken.musicnote,
            size: widget.iconSize ?? widget.thumbnailSize / 2,
          ),
          if (widget.onTopWidgets.isNotEmpty) ...widget.onTopWidgets,
        ],
      ),
    );
    if (widget.forceDummyArtwork) return;
    if (widget.path == null && widget.bytes == null) return;

    final shouldDisplayMemory = _finalBytes != null && (_finalBytes ?? []).isNotEmpty;
    final shouldDisplayPath = widget.path != null;
    if (!shouldDisplayMemory && !shouldDisplayPath) return;
    // [extImageChild] wont get assigned, leaving [extImageChild==null], i.e. displays [stockWidget] only.

    _realWidthAndHeight = widget.forceSquared ? context.width : null;

    final extImageChild = Stack(
      alignment: Alignment.center,
      children: [
        // if bytes are sent and valid.
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
        if (widget.onTopWidgets.isNotEmpty) ...widget.onTopWidgets,
      ],
    );
    _finalWidget = SettingsController.inst.enableGlowEffect.value && widget.blur != 0.0
        ? SizedBox(
            width: widget.staggered ? null : widget.width ?? widget.thumbnailSize * widget.scale,
            height: widget.staggered ? null : widget.height ?? widget.thumbnailSize * widget.scale,
            child: Center(
              child: SettingsController.inst.borderRadiusMultiplier.value == 0.0 || widget.borderRadius == 0
                  ? DropShadow(
                      borderRadius: widget.borderRadius.multipliedRadius,
                      blurRadius: widget.blur,
                      spread: 0.8,
                      offset: const Offset(0, 1),
                      boxShadow: widget.boxShadow,
                      child: widget.child ?? extImageChild,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(widget.borderRadius.multipliedRadius),
                      child: DropShadow(
                        borderRadius: widget.borderRadius.multipliedRadius,
                        blurRadius: widget.blur,
                        spread: 0.8,
                        offset: const Offset(0, 1),
                        boxShadow: widget.boxShadow,
                        child: widget.child ?? extImageChild,
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
                child: SettingsController.inst.borderRadiusMultiplier.value == 0.0
                    ? widget.child ?? extImageChild
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(widget.borderRadius.multipliedRadius),
                        child: widget.child ?? extImageChild,
                      ),
              ),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    if (_finalWidget == null || widget.track != _lastTrack || widget.borderRadius != _lastBorderRadius) {
      fillWidgets();
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
  const MultiArtworks(
      {super.key, required this.paths, required this.thumbnailSize, this.bgcolor, this.borderRadius = 8.0, required this.heroTag, this.disableHero = false, this.iconSize = 29.0});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: thumbnailSize,
      width: thumbnailSize,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(borderRadius.multipliedRadius)),
      child: paths.isEmpty
          ? ArtworkWidget(
              key: UniqueKey(),
              thumbnailSize: thumbnailSize,
              track: allTracksInLibrary.firstOrNull,
              path: allTracksInLibrary.firstOrNull?.pathToImage,
              forceSquared: true,
              blur: 0,
              forceDummyArtwork: true,
              bgcolor: bgcolor,
              borderRadius: borderRadius,
              iconSize: iconSize,
            )
          : paths.length == 1
              ? ArtworkWidget(
                  key: UniqueKey(),
                  thumbnailSize: thumbnailSize,
                  path: paths.elementAt(0),
                  track: null,
                  forceSquared: true,
                  blur: 0,
                  borderRadius: 0,
                  compressed: false,
                )
              : paths.length == 2
                  ? Row(
                      children: [
                        ArtworkWidget(
                          key: UniqueKey(),
                          track: null,
                          thumbnailSize: thumbnailSize / 2,
                          height: thumbnailSize,
                          path: paths.elementAt(0),
                          forceSquared: true,
                          blur: 0,
                          borderRadius: 0,
                          iconSize: iconSize - 2.0,
                        ),
                        ArtworkWidget(
                          key: UniqueKey(),
                          track: null,
                          thumbnailSize: thumbnailSize / 2,
                          height: thumbnailSize,
                          path: paths.elementAt(1),
                          forceSquared: true,
                          blur: 0,
                          borderRadius: 0,
                          iconSize: iconSize - 2.0,
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
                                  track: null,
                                  thumbnailSize: thumbnailSize / 2,
                                  path: paths.elementAt(0),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  iconSize: iconSize - 2.0,
                                ),
                                ArtworkWidget(
                                  key: UniqueKey(),
                                  track: null,
                                  thumbnailSize: thumbnailSize / 2,
                                  path: paths.elementAt(1),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  iconSize: iconSize - 2.0,
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                ArtworkWidget(
                                  key: UniqueKey(),
                                  track: null,
                                  thumbnailSize: thumbnailSize / 2,
                                  path: paths.elementAt(2),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  height: thumbnailSize,
                                  iconSize: iconSize,
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
                                  track: null,
                                  thumbnailSize: thumbnailSize / 2,
                                  path: paths.elementAt(0),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  iconSize: iconSize - 3.0,
                                ),
                                ArtworkWidget(
                                  key: UniqueKey(),
                                  track: null,
                                  thumbnailSize: thumbnailSize / 2,
                                  path: paths.elementAt(1),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  iconSize: iconSize - 3.0,
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                ArtworkWidget(
                                  key: UniqueKey(),
                                  track: null,
                                  thumbnailSize: thumbnailSize / 2,
                                  path: paths.elementAt(2),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  iconSize: iconSize - 3.0,
                                ),
                                ArtworkWidget(
                                  key: UniqueKey(),
                                  track: null,
                                  thumbnailSize: thumbnailSize / 2,
                                  path: paths.elementAt(3),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  iconSize: iconSize - 3.0,
                                ),
                              ],
                            ),
                          ],
                        ),
    );
    return disableHero
        ? child
        : Hero(
            tag: heroTag,
            child: child,
          );
  }
}
