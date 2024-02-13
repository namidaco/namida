// ignore_for_file: unused_element

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/base/loading_items_delay.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
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
  final Track? track;
  final double thumbnailSize;
  final bool forceSquared;
  final bool staggered;
  final bool compressed;
  final int fadeMilliSeconds;
  final int cacheHeight;
  final double? width;
  final double? height;
  final double? iconSize;
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
  final bool isCircle;
  final VoidCallback? onError;
  final bool fallbackToFolderCover;

  const ArtworkWidget({
    required super.key,
    this.path,
    this.bytes,
    this.track,
    this.compressed = true,
    this.fadeMilliSeconds = 300,
    required this.thumbnailSize,
    this.forceSquared = false,
    this.child,
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
    this.forceEnableGlow = false,
    this.displayIcon = true,
    this.icon = Broken.musicnote,
    this.isCircle = false,
    this.onError,
    this.fallbackToFolderCover = true,
  });

  @override
  State<ArtworkWidget> createState() => _ArtworkWidgetState();
}

class _ArtworkWidgetState extends State<ArtworkWidget> with LoadingItemsDelayMixin {
  String? _imagePath;
  late Uint8List? bytes = widget.bytes ?? Indexer.inst.artworksMap[widget.path];
  late bool _imageObtainedBefore = Indexer.inst.imageObtainedBefore(widget.path ?? '');

  bool _triedDeleting = false;

  @override
  void initState() {
    if (widget.path != null && File(widget.path!).existsSync()) {
      _imagePath = widget.path;
    } else {
      Future.delayed(Duration.zero, _extractArtwork);
    }
    super.initState();
  }

  void _extractArtwork() async {
    final wPath = widget.path;
    if (wPath != null && _imagePath == null) {
      if (!await canStartLoadingItems()) return;

      if (widget.compressed == false) {
        final resPath = await Indexer.inst
            .getArtwork(
              imagePath: wPath,
              compressed: false,
              checkFileFirst: false,
              size: widget.useTrackTileCacheHeight ? 240 : null,
            )
            .then((value) => value.$1?.path);
        if (mounted) {
          if (resPath != null || !_imageObtainedBefore) {
            setState(() {
              if (resPath != null) _imagePath = resPath;
              if (!_imageObtainedBefore) _imageObtainedBefore = true;
            });
          }
        }
      } else if (bytes == null) {
        final resBytes = await Indexer.inst
            .getArtwork(
              imagePath: wPath,
              compressed: widget.compressed,
              checkFileFirst: false,
              size: widget.useTrackTileCacheHeight ? 240 : null,
            )
            .then((value) => value.$2);
        if (mounted) {
          if (resBytes != null || !_imageObtainedBefore) {
            setState(() {
              if (resBytes != null) bytes = resBytes;
              if (!_imageObtainedBefore) _imageObtainedBefore = true;
            });
          }
        }
      }

      if (_imagePath == null && widget.track != null && widget.fallbackToFolderCover) {
        String folderPath = widget.track!.folderPath;
        String? cover = Indexer.inst.allFolderCovers[folderPath];
        if (cover == null && folderPath.endsWith(Platform.pathSeparator)) {
          try {
            folderPath = folderPath.substring(0, folderPath.length - 1);
            cover = Indexer.inst.allFolderCovers[folderPath];
          } catch (_) {}
        }
        if (cover != null) setState(() => _imagePath = cover);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = this.bytes;
    final key = Key("${widget.path}_${bytes?.length}");
    final isValidBytes = bytes?.isNotEmpty == true;
    final canDisplayImage = _imagePath != null || isValidBytes;
    final thereMightBeImageSoon = !canDisplayImage && !widget.forceDummyArtwork && Indexer.inst.backupMediaStoreIDS[widget.path] != null && !_imageObtainedBefore;

    final realWidthAndHeight = widget.forceSquared ? context.width : null;

    int? finalCache;
    if (widget.compressed || widget.useTrackTileCacheHeight) {
      final pixelRatio = context.mediaQuery.devicePixelRatio;
      final cacheMultiplier = (pixelRatio * settings.artworkCacheHeightMultiplier.value).round();
      finalCache = widget.useTrackTileCacheHeight ? 60 * cacheMultiplier : widget.cacheHeight * cacheMultiplier;
    }

    final borderR = widget.isCircle || settings.borderRadiusMultiplier.value == 0 ? null : BorderRadius.circular(widget.borderRadius.multipliedRadius);
    final shape = widget.isCircle ? BoxShape.circle : BoxShape.rectangle;

    final boxWidth = widget.width ?? widget.thumbnailSize;
    final boxHeight = widget.height ?? widget.thumbnailSize;

    // -- dont display stock widget if image can be obtained.
    if (thereMightBeImageSoon) {
      return SizedBox(
        key: key,
        width: widget.staggered ? null : boxWidth,
        height: widget.staggered ? null : boxHeight,
      );
    }
    Widget getStockWidget({
      final Color? bgc,
      required final bool stackWithOnTopWidgets,
    }) {
      final icon = Icon(
        widget.displayIcon ? widget.icon : null,
        size: widget.iconSize ?? widget.thumbnailSize / 2,
      );
      return Container(
        key: key,
        width: boxWidth,
        height: boxHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: widget.bgcolor ?? Color.alphaBlend(context.theme.cardColor.withAlpha(100), context.theme.scaffoldBackgroundColor),
          borderRadius: borderR,
          shape: shape,
          boxShadow: widget.boxShadow,
        ),
        child: stackWithOnTopWidgets
            ? Stack(
                alignment: Alignment.center,
                children: [
                  icon,
                  ...widget.onTopWidgets,
                ],
              )
            : icon,
      );
    }

    return !canDisplayImage || widget.forceDummyArtwork
        ? getStockWidget(
            stackWithOnTopWidgets: true,
            bgc: widget.bgcolor ?? Color.alphaBlend(context.theme.cardColor.withAlpha(100), context.theme.scaffoldBackgroundColor),
          )
        : SizedBox(
            key: key,
            width: widget.staggered ? null : boxWidth,
            height: widget.staggered ? null : boxHeight,
            child: Align(
              child: _DropShadowWrapper(
                enabled: widget.forceEnableGlow || (settings.enableGlowEffect.value && widget.blur != 0.0),
                borderRadius: borderR,
                blur: widget.blur,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: borderR,
                    shape: shape,
                    boxShadow: widget.boxShadow,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (canDisplayImage)
                        Image(
                          image: ResizeImage.resizeIfNeeded(
                            null,
                            finalCache,
                            (_imagePath != null ? FileImage(File(_imagePath!)) : MemoryImage(bytes!)) as ImageProvider,
                          ),
                          gaplessPlayback: true,
                          fit: BoxFit.cover,
                          filterQuality: widget.compressed ? FilterQuality.low : FilterQuality.high,
                          width: realWidthAndHeight,
                          height: realWidthAndHeight,
                          frameBuilder: ((context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded) return child;
                            if (_imagePath != null && bytes != null && bytes.isNotEmpty) return child;
                            if (frame == null) return child;

                            return TweenAnimationBuilder(
                              tween: Tween<double>(begin: 1.0, end: 0.0),
                              duration: Duration(milliseconds: widget.fadeMilliSeconds),
                              child: child,
                              builder: (context, value, child) {
                                return Stack(
                                  children: [
                                    child!,
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: ColoredBox(color: context.theme.cardColor.withOpacity(value)),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          }),
                          errorBuilder: (context, error, stackTrace) {
                            if (!_triedDeleting) {
                              _triedDeleting = true;
                              if (error.toString().contains('Invalid image data')) {
                                final fp = widget.path;
                                if (fp != null && widget.fallbackToFolderCover && (fp.startsWith(AppDirs.APP_CACHE) || fp.startsWith(AppDirs.USER_DATA))) {
                                  // -- fallbackToFolderCover should be always true for app cached images.
                                  // -- we are allowed to delete only if specified image is app-generated.
                                  File(fp).tryDeleting();
                                  FileImage(File(fp)).evict();
                                }
                              }
                              widget.onError?.call();
                            }
                            return getStockWidget(
                              stackWithOnTopWidgets: false,
                            );
                          },
                        ),
                      ...widget.onTopWidgets
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}

class _DropShadowWrapper extends StatelessWidget {
  final bool enabled;
  final Widget child;
  final double blur;
  final Offset offset;
  final BorderRadius? borderRadius;

  const _DropShadowWrapper({
    required this.enabled,
    required this.child,
    this.offset = const Offset(0, 1),
    this.borderRadius,
    this.blur = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return enabled
        ? DropShadow(
            borderRadius: borderRadius,
            blurRadius: blur,
            spread: 0.8,
            offset: const Offset(0, 1),
            child: child,
          )
        : child;
  }
}

class MultiArtworks extends StatelessWidget {
  final List<Track> tracks;
  final double thumbnailSize;
  final Color? bgcolor;
  final double borderRadius;
  final Object heroTag;
  final bool disableHero;
  final double iconSize;
  final bool fallbackToFolderCover;

  const MultiArtworks({
    super.key,
    required this.tracks,
    required this.thumbnailSize,
    this.bgcolor,
    this.borderRadius = 8.0,
    required this.heroTag,
    this.disableHero = false,
    this.iconSize = 29.0,
    this.fallbackToFolderCover = true,
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
            return tracks.isEmpty
                ? ArtworkWidget(
                    key: const Key(''),
                    track: null,
                    thumbnailSize: thumbnailSize,
                    path: null,
                    forceSquared: true,
                    blur: 0,
                    forceDummyArtwork: true,
                    bgcolor: bgcolor,
                    borderRadius: borderRadius,
                    iconSize: iconSize,
                    width: c.maxWidth,
                    height: c.maxHeight,
                    fallbackToFolderCover: fallbackToFolderCover,
                  )
                : tracks.length == 1
                    ? ArtworkWidget(
                        key: Key(tracks[0].pathToImage),
                        thumbnailSize: thumbnailSize,
                        track: tracks[0],
                        path: tracks[0].pathToImage,
                        forceSquared: true,
                        blur: 0,
                        borderRadius: 0,
                        compressed: false,
                        width: c.maxWidth,
                        height: c.maxHeight,
                        fallbackToFolderCover: fallbackToFolderCover,
                      )
                    : tracks.length == 2
                        ? Row(
                            children: [
                              ArtworkWidget(
                                key: Key("0_${tracks[0].pathToImage}"),
                                thumbnailSize: thumbnailSize / 2,
                                track: tracks[0],
                                path: tracks[0].pathToImage,
                                forceSquared: true,
                                blur: 0,
                                borderRadius: 0,
                                iconSize: iconSize - 2.0,
                                width: c.maxWidth / 2,
                                height: c.maxHeight,
                                fallbackToFolderCover: fallbackToFolderCover,
                              ),
                              ArtworkWidget(
                                key: Key("1_${tracks[1].pathToImage}"),
                                thumbnailSize: thumbnailSize / 2,
                                track: tracks[1],
                                path: tracks[1].pathToImage,
                                forceSquared: true,
                                blur: 0,
                                borderRadius: 0,
                                iconSize: iconSize - 2.0,
                                width: c.maxWidth / 2,
                                height: c.maxHeight,
                                fallbackToFolderCover: fallbackToFolderCover,
                              ),
                            ],
                          )
                        : tracks.length == 3
                            ? Row(
                                children: [
                                  Column(
                                    children: [
                                      ArtworkWidget(
                                        key: Key("0_${tracks[0].pathToImage}"),
                                        thumbnailSize: thumbnailSize / 2,
                                        track: tracks[0],
                                        path: tracks[0].pathToImage,
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 2.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                        fallbackToFolderCover: fallbackToFolderCover,
                                      ),
                                      ArtworkWidget(
                                        key: Key("1_${tracks[1].pathToImage}"),
                                        thumbnailSize: thumbnailSize / 2,
                                        track: tracks[1],
                                        path: tracks[1].pathToImage,
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 2.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                        fallbackToFolderCover: fallbackToFolderCover,
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      ArtworkWidget(
                                        key: Key("2_${tracks[2].pathToImage}"),
                                        thumbnailSize: thumbnailSize / 2,
                                        track: tracks[2],
                                        path: tracks[2].pathToImage,
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight,
                                        fallbackToFolderCover: fallbackToFolderCover,
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
                                        key: Key("0_${tracks[0].pathToImage}"),
                                        thumbnailSize: thumbnailSize / 2,
                                        track: tracks[0],
                                        path: tracks[0].pathToImage,
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 3.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                        fallbackToFolderCover: fallbackToFolderCover,
                                      ),
                                      ArtworkWidget(
                                        key: Key("1_${tracks[1].pathToImage}"),
                                        thumbnailSize: thumbnailSize / 2,
                                        track: tracks[1],
                                        path: tracks[1].pathToImage,
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 3.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                        fallbackToFolderCover: fallbackToFolderCover,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      ArtworkWidget(
                                        key: Key("2_${tracks[2].pathToImage}"),
                                        thumbnailSize: thumbnailSize / 2,
                                        track: tracks[2],
                                        path: tracks[2].pathToImage,
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 3.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                        fallbackToFolderCover: fallbackToFolderCover,
                                      ),
                                      ArtworkWidget(
                                        key: Key("3_${tracks[3].pathToImage}"),
                                        thumbnailSize: thumbnailSize / 2,
                                        track: tracks[3],
                                        path: tracks[3].pathToImage,
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 3.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                        fallbackToFolderCover: fallbackToFolderCover,
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
