// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:namida/base/loading_items_delay.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/network_artwork.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

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
  final int? cacheHeight;
  final double? width;
  final double? height;
  final double? iconSize;
  final double borderRadius;
  final double blur;
  final bool disableBlurBgSizeShrink;
  final bool forceDummyArtwork;
  final Color? bgcolor;
  final Widget? child;
  final List<Widget>? onTopWidgets;
  final List<BoxShadow>? boxShadow;
  final bool? enableGlow;
  final bool displayIcon;
  final IconData? icon;
  final bool isCircle;
  final bool fallbackToFolderCover;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  /// can help skip some checks as its already done by [YoutubeThumbnail] or [NetworkArtwork].
  final bool extractInternally;

  const ArtworkWidget({
    required super.key,
    this.path,
    this.bytes,
    this.track,
    this.compressed = true,
    this.fadeMilliSeconds = kDefaultFadeMilliSeconds,
    required this.thumbnailSize,
    this.forceSquared = false,
    this.child,
    this.borderRadius = 8.0,
    this.blur = 5.0,
    this.disableBlurBgSizeShrink = false,
    this.width,
    this.height,
    this.cacheHeight,
    this.forceDummyArtwork = false,
    this.bgcolor,
    this.iconSize,
    this.staggered = false,
    this.boxShadow,
    this.onTopWidgets,
    this.enableGlow,
    this.displayIcon = true,
    this.icon,
    this.isCircle = false,
    this.fallbackToFolderCover = true,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.extractInternally = true,
  });

  static const kDefaultFadeMilliSeconds = 300;

  /// Prevents re-fade in due to change of cache height caused by window resize.
  static bool isResizingAppWindow = false;

  /// Prevents re-fade in due to change of cache height caused by side nav bar resize.
  static bool isMovingDrawer = false;

  static const kImagePathInitialValue = '';

  @override
  State<ArtworkWidget> createState() => _ArtworkWidgetState();
}

class _ArtworkWidgetState extends State<ArtworkWidget> with LoadingItemsDelayMixin {
  static const _imagePathInitialValue = ArtworkWidget.kImagePathInitialValue;

  String? _imagePath = _imagePathInitialValue;
  late Uint8List? bytes = widget.bytes ?? Indexer.inst.artworksMap[widget.path];
  // late final bool _imageObtainedBefore = Indexer.inst.imageObtainedBefore(widget.path ?? '');

  bool _triedDeleting = false;

  num get _getThumbnailEffectiveCacheHeight => widget.cacheHeight ?? widget.height ?? widget.width ?? widget.thumbnailSize;

  @override
  void initState() {
    super.initState();

    _imagePath = widget.path; // to prevent flashing/etc

    if (widget.extractInternally) {
      _initValues();
    }
  }

  void _initValues() async {
    final wPath = widget.path;
    if (wPath != null && await File(wPath).exists()) {
      if (_imagePath != wPath) refreshState(() => _imagePath = wPath);
      return;
    }
    if (widget.track != null) {
      final id = widget.track!.youtubeID;
      final ytImg = await ThumbnailManager.inst.getYoutubeThumbnailFromCache(type: ThumbnailType.video, id: id, isTemp: false);
      if (ytImg != null) {
        refreshState(() => _imagePath = ytImg.path);
        return;
      }
    }

    if (widget.extractInternally) {
      if (_imagePath != _imagePathInitialValue) refreshState(() => _imagePath = _imagePathInitialValue);
      Timer(Duration.zero, _extractArtwork);
    }
  }

  void _extractArtwork() async {
    final wPath = widget.path;
    if (wPath != null && _imagePath == _imagePathInitialValue) {
      if (!await canStartLoadingItems()) return;

      if (widget.compressed == false) {
        final resPath = await Indexer.inst
            .getArtwork(
              imagePath: wPath,
              trackPath: widget.track?.path,
              compressed: false,
              checkFileFirst: false,
              size: widget.compressed ? _getThumbnailEffectiveCacheHeight.round() : null,
            )
            .then((value) => value.$1?.path);
        if (mounted) {
          if (resPath != null) {
            setState(() => _imagePath = resPath);
          }
        }
      } else if (bytes == null) {
        final resBytes = await Indexer.inst
            .getArtwork(
              imagePath: wPath,
              trackPath: widget.track?.path,
              compressed: widget.compressed,
              checkFileFirst: false,
              size: widget.compressed ? _getThumbnailEffectiveCacheHeight.round() : null,
            )
            .then((value) => value.$2);
        if (mounted) {
          if (resBytes != null) {
            setState(() => bytes = resBytes);
          }
        }
      }

      if (_imagePath == _imagePathInitialValue && widget.track != null && widget.fallbackToFolderCover) {
        final cover = Indexer.inst.getFallbackFolderArtworkPath(folderPath: widget.track!.folderPath);
        if (cover != null && mounted) setState(() => _imagePath = cover);
      }

      if (_imagePath == _imagePathInitialValue) {
        if (mounted) setState(() => _imagePath = null); // null means nothing more to try, display the fallback icon.
      }
    }
  }

  Widget _getStockWidget({
    Key? key,
    required final double? boxWidth,
    required final double? boxHeight,
    final Color? bgc,
    required final bool stackWithOnTopWidgets,
    required final BoxShape shape,
    required final BorderRadiusGeometry? borderRadius,
  }) {
    final theme = context.theme;
    final icon = Icon(
      widget.displayIcon ? widget.icon ?? (widget.track is Video ? Broken.video : Broken.musicnote) : null,
      size: widget.iconSize ?? widget.thumbnailSize * 0.5,
    );
    return Container(
      key: key,
      width: boxWidth,
      height: boxHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.bgcolor ?? Color.alphaBlend(theme.cardColor.withAlpha(100), theme.scaffoldBackgroundColor),
        borderRadius: borderRadius,
        shape: shape,
        boxShadow: widget.boxShadow,
      ),
      child: stackWithOnTopWidgets
          ? Stack(
              alignment: Alignment.center,
              children: [
                icon,
                ...?widget.onTopWidgets,
              ],
            )
          : icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = this.bytes;
    final key = Key("${widget.key}${_imagePath}_${bytes?.length}");
    final isValidBytes = bytes is Uint8List ? bytes.isNotEmpty : false;
    final goodImagePath = _imagePath?.isNotEmpty == true;
    final canDisplayImage = goodImagePath || isValidBytes;
    final thereMightBeImageSoon = (_imagePath == _imagePathInitialValue || (bytes != null && bytes.isEmpty)) && !widget.forceDummyArtwork;
    final boxWidth = widget.width ?? widget.thumbnailSize;
    final boxHeight = widget.height ?? widget.thumbnailSize;

    final dropShadowEnabled = widget.enableGlow ?? (settings.enableGlowEffect.value && widget.blur != 0.0);
    final sizePercentage = widget.disableBlurBgSizeShrink || !dropShadowEnabled ? 1.0 : DropShadow.defaultSizePercentage;

    // -- dont display stock widget if image can be obtained.
    if (thereMightBeImageSoon) {
      final box = SizedBox(
        key: key,
        width: boxWidth,
        height: boxHeight,
        // -- below will cause fallback square to not exist, making staggered image look bad before loading and once loaded (jumps)
        // width: widget.staggered ? null : boxWidth,
        // height: widget.staggered ? null : boxHeight,
      );
      final child = widget.onTopWidgets?.isEmpty ?? true
          ? box
          : Stack(
              alignment: Alignment.center,
              children: [
                box,
                ...?widget.onTopWidgets,
              ],
            );
      return sizePercentage == 1.0
          ? child
          : Transform.scale(
              scale: sizePercentage,
              child: child,
            );
    }

    final realWidthAndHeight = widget.forceSquared ? double.infinity : null;

    int? finalCache;
    if (widget.compressed) {
      final pixelRatio = context.pixelRatio;
      final cacheMultiplier = pixelRatio * settings.artworkCacheHeightMultiplier.value;
      final extraMultiplier = (1 + (0.05 / pixelRatio * 15)); // higher for lower pixel ratio, for example 1=>1.75, 3=>1.25
      final usedHeight = _getThumbnailEffectiveCacheHeight;
      final refined = usedHeight * cacheMultiplier * extraMultiplier;
      finalCache = refined.round();
    }

    final borderR = widget.isCircle || settings.borderRadiusMultiplier.value == 0 ? null : BorderRadius.circular(widget.borderRadius.multipliedRadius);
    final shape = widget.isCircle ? BoxShape.circle : BoxShape.rectangle;
    final theme = context.theme;
    return SizedBox(
      key: key,
      width: widget.staggered ? null : boxWidth,
      height: widget.staggered ? null : boxHeight,
      child: Align(
        child: _DropShadowWrapper(
          enabled: dropShadowEnabled,
          blur: widget.blur,
          sizePercentage: sizePercentage,
          child: !canDisplayImage || widget.forceDummyArtwork
              ? _getStockWidget(
                  key: key,
                  boxWidth: boxWidth,
                  boxHeight: boxHeight,
                  borderRadius: borderR,
                  shape: shape,
                  stackWithOnTopWidgets: true,
                  bgc: widget.bgcolor ?? Color.alphaBlend(theme.cardColor.withAlpha(100), theme.scaffoldBackgroundColor),
                )
              : Container(
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
                            (goodImagePath ? FileImage(File(_imagePath!)) : MemoryImage(bytes!)) as ImageProvider,
                          ),
                          gaplessPlayback: true,
                          fit: widget.fit,
                          alignment: widget.alignment,
                          filterQuality: widget.compressed ? FilterQuality.low : FilterQuality.high,
                          width: realWidthAndHeight,
                          height: realWidthAndHeight,
                          frameBuilder: ((context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded || frame == null) return child;
                            if (ArtworkWidget.isResizingAppWindow || ArtworkWidget.isMovingDrawer) return child;
                            if (widget.fadeMilliSeconds == 0) return child;
                            if (goodImagePath && bytes != null && bytes.isNotEmpty) return child;

                            return TweenAnimationBuilder(
                              tween: Tween<double>(begin: 1.0, end: 0.0),
                              duration: Duration(milliseconds: widget.fadeMilliSeconds),
                              child: child,
                              builder: (context, value, child) {
                                return Stack(
                                  textDirection: TextDirection.ltr,
                                  children: [
                                    child!,
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: ColoredBox(color: theme.cardColor.withValues(alpha: value)),
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
                            }
                            return _getStockWidget(
                              key: key,
                              boxWidth: boxWidth,
                              boxHeight: boxHeight,
                              borderRadius: borderR,
                              shape: shape,
                              stackWithOnTopWidgets: false,
                            );
                          },
                        ),
                      ...?widget.onTopWidgets
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
  final double sizePercentage;
  final Offset offset;

  const _DropShadowWrapper({
    required this.enabled,
    required this.child,
    this.offset = const Offset(0.0, 1.25),
    this.sizePercentage = DropShadow.defaultSizePercentage,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return enabled
        ? DropShadow(
            blurRadius: blur,
            offset: offset,
            sizePercentage: sizePercentage,
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
  final bool reduceQuality;
  final File? artworkFile;
  final int fadeMilliSeconds;

  const MultiArtworks({
    super.key,
    required this.tracks,
    required this.thumbnailSize,
    this.bgcolor,
    this.borderRadius = 8.0,
    required this.heroTag,
    this.disableHero = false,
    this.iconSize = 24.0,
    this.fallbackToFolderCover = true,
    this.reduceQuality = false,
    required this.artworkFile,
    this.fadeMilliSeconds = ArtworkWidget.kDefaultFadeMilliSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final artworkFile = this.artworkFile;
    return NamidaHero(
      tag: heroTag,
      enabled: !disableHero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
        ),
        child: SizedBox(
          height: thumbnailSize,
          width: thumbnailSize,
          child: artworkFile != null && artworkFile.existsSync()
              ? ArtworkWidget(
                  key: ValueKey(artworkFile.path),
                  fadeMilliSeconds: fadeMilliSeconds,
                  thumbnailSize: thumbnailSize,
                  path: artworkFile.path,
                  forceSquared: true,
                  iconSize: iconSize,
                  blur: 0,
                  borderRadius: 0,
                  compressed: false,
                  width: thumbnailSize,
                  height: thumbnailSize,
                  fallbackToFolderCover: fallbackToFolderCover,
                )
              : tracks.isEmpty
                  ? ArtworkWidget(
                      key: const Key(''),
                      fadeMilliSeconds: fadeMilliSeconds,
                      track: null,
                      thumbnailSize: thumbnailSize,
                      path: null,
                      forceSquared: true,
                      blur: 0,
                      forceDummyArtwork: true,
                      bgcolor: bgcolor,
                      borderRadius: borderRadius,
                      iconSize: iconSize,
                      width: thumbnailSize,
                      height: thumbnailSize,
                      fallbackToFolderCover: fallbackToFolderCover,
                    )
                  : LayoutBuilder(
                      builder: (context, c) {
                        return tracks.length == 1
                            ? ArtworkWidget(
                                key: Key(tracks[0].pathToImage),
                                fadeMilliSeconds: fadeMilliSeconds,
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
                                        fadeMilliSeconds: fadeMilliSeconds,
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
                                        cacheHeight: reduceQuality ? 60 : 80,
                                      ),
                                      ArtworkWidget(
                                        key: Key("1_${tracks[1].pathToImage}"),
                                        fadeMilliSeconds: fadeMilliSeconds,
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
                                        cacheHeight: reduceQuality ? 60 : 80,
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
                                                fadeMilliSeconds: fadeMilliSeconds,
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
                                                cacheHeight: reduceQuality ? 40 : 80,
                                              ),
                                              ArtworkWidget(
                                                key: Key("1_${tracks[1].pathToImage}"),
                                                fadeMilliSeconds: fadeMilliSeconds,
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
                                                cacheHeight: reduceQuality ? 40 : 80,
                                              ),
                                            ],
                                          ),
                                          ArtworkWidget(
                                            key: Key("2_${tracks[2].pathToImage}"),
                                            fadeMilliSeconds: fadeMilliSeconds,
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
                                            cacheHeight: reduceQuality ? 40 : 80,
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          Row(
                                            children: [
                                              ArtworkWidget(
                                                key: Key("0_${tracks[0].pathToImage}"),
                                                fadeMilliSeconds: fadeMilliSeconds,
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
                                                cacheHeight: reduceQuality ? 40 : 80,
                                              ),
                                              ArtworkWidget(
                                                key: Key("1_${tracks[1].pathToImage}"),
                                                fadeMilliSeconds: fadeMilliSeconds,
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
                                                cacheHeight: reduceQuality ? 40 : 80,
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              ArtworkWidget(
                                                key: Key("2_${tracks[2].pathToImage}"),
                                                fadeMilliSeconds: fadeMilliSeconds,
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
                                                cacheHeight: reduceQuality ? 40 : 80,
                                              ),
                                              ArtworkWidget(
                                                key: Key("3_${tracks[3].pathToImage}"),
                                                fadeMilliSeconds: fadeMilliSeconds,
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
                                                cacheHeight: reduceQuality ? 40 : 80,
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                      },
                    ),
        ),
      ),
    );
  }
}
