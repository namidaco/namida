// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_tilt/flutter_tilt.dart';

import 'package:namida/base/loading_items_delay.dart';
import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/image_advanced.dart';
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
  final Object? staggeredCacheKey;
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
  final bool displayIcon;
  final IconData? icon;
  final bool isCircle;
  final bool fallbackToFolderCover;
  final bool fallbackToAlbumCover;
  final bool allowFloating;
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
    this.staggeredCacheKey,
    this.boxShadow,
    this.onTopWidgets,
    this.displayIcon = true,
    this.icon,
    this.isCircle = false,
    this.fallbackToFolderCover = true,
    this.fallbackToAlbumCover = false,
    this.allowFloating = false,
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

  /// Decoded `width / height` per image, filled in as images resolve.
  ///
  /// Layout that wants to size a box to the artwork needs the ratio before the image
  /// is in the tree, so it is kept here rather than handed upwards.
  static final _aspectRatios = <Object, double>{};

  /// bumped whenever a new ratio is learned, pair it with a selector so only the
  /// widgets watching that one key rebuild.
  static final aspectRatiosVersion = 0.obs;

  static double? aspectRatioOf(Object? cacheKey) => cacheKey == null ? null : _aspectRatios[cacheKey];

  static bool isWaitingForImage(Element element) {
    final state = element is StatefulElement ? element.state : null;
    return state is _ArtworkWidgetState && state._isWaitingForImage;
  }

  static bool _aspectRatioNotifyScheduled = false;

  static void _cacheAspectRatio(Object? cacheKey, double ratio) {
    if (cacheKey == null || !ratio.isFinite || ratio <= 0) return;
    if (_aspectRatios[cacheKey] == ratio) return;
    if (_aspectRatios.length >= _ArtworkWidgetState._kStaticMapsMaxEntries) _aspectRatios.clear();
    _aspectRatios[cacheKey] = ratio;
    // -- this runs from the image's layout callback, listeners rebuilding on it would
    // -- be setState during build, so tell them after the frame, once for the batch.
    if (_aspectRatioNotifyScheduled) return;
    _aspectRatioNotifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _aspectRatioNotifyScheduled = false;
      aspectRatiosVersion.value++;
    });
  }

  static ({int longest, int shortest})? _fullQualityDecodeBoxCached;
  static bool _isFullQualityDecodeBoxFromDisplay = false;

  /// the largest display as `longest x shortest`, so rotating keeps the same cache key.
  /// while displays are unknown, the largest window seen so far, so split screen/floating windows can't shrink it.
  static ({int longest, int shortest})? get _fullQualityDecodeBox {
    if (_isFullQualityDecodeBoxFromDisplay) return _fullQualityDecodeBoxCached;
    final dispatcher = WidgetsBinding.instance.platformDispatcher;

    final fromDisplays = _largestBoxOf(dispatcher.displays.map((display) => display.size));
    if (fromDisplays != null) {
      _isFullQualityDecodeBoxFromDisplay = true;
      return _fullQualityDecodeBoxCached = fromDisplays;
    }

    final fromViews = _largestBoxOf(dispatcher.views.map((view) => view.physicalSize));
    final cached = _fullQualityDecodeBoxCached;
    if (fromViews == null || cached == null) return _fullQualityDecodeBoxCached ??= fromViews;
    if (fromViews.longest <= cached.longest && fromViews.shortest <= cached.shortest) return cached;
    return _fullQualityDecodeBoxCached = (longest: math.max(fromViews.longest, cached.longest), shortest: math.max(fromViews.shortest, cached.shortest));
  }

  static ({int longest, int shortest})? _largestBoxOf(Iterable<Size> sizes) {
    var longest = 0.0;
    var shortest = 0.0;
    for (final size in sizes) {
      if (size.isEmpty) continue; // -- unknown sizes come as `-1 x -1`, and `longestSide`/`shortestSide` are absolute
      if (size.longestSide > longest) longest = size.longestSide;
      if (size.shortestSide > shortest) shortest = size.shortestSide;
    }
    return shortest > 0 ? (longest: longest.round(), shortest: shortest.round()) : null;
  }

  /// capped to the screen and independent of the drawn size, so every place shares one cache entry.
  /// a crop (like [BoxFit.cover]) longer than the screen's short side ([croppedLongestSide], physical pixels) can need more, so it stays uncapped.
  static ImageProvider fullQualityImage(ImageProvider provider, {double croppedLongestSide = 0}) {
    final box = _fullQualityDecodeBox;
    if (box == null || croppedLongestSide > box.shortest) return provider;
    return ResizeImage(provider, width: box.longest, height: box.shortest, policy: ResizeImagePolicy.fit);
  }

  static Future<void> evictImageFile(File file) async {
    final provider = FileImage(file);
    await provider.evict();
    await fullQualityImage(provider).evict();
  }

  @override
  State<ArtworkWidget> createState() => _ArtworkWidgetState();
}

class _ArtworkWidgetState extends State<ArtworkWidget> with LoadingItemsDelayMixin {
  static final _latestInvalidImagePath = <String?, bool>{};
  static final _staggeredAspectRatios = <Object, double>{};
  static const _kStaticMapsMaxEntries = 4000;

  static void _markInvalidImagePath(String? path) {
    if (_latestInvalidImagePath.length >= _kStaticMapsMaxEntries) _latestInvalidImagePath.clear();
    _latestInvalidImagePath[path] = true;
  }

  Object? get _staggeredCacheKey {
    final key = widget.staggeredCacheKey;
    if (key != null) return key;
    final path = widget.path;
    return path == null || path.isEmpty ? null : path;
  }

  double _staggeredHeight(ImageInfo? info, double boxWidth, double boxHeight) {
    final cacheKey = _staggeredCacheKey;
    if (info != null) {
      final ratio = info.image.width / info.image.height;
      if (cacheKey != null) {
        if (_staggeredAspectRatios.length >= _kStaticMapsMaxEntries) _staggeredAspectRatios.clear();
        _staggeredAspectRatios[cacheKey] = ratio;
      }
      ArtworkWidget._cacheAspectRatio(cacheKey, ratio);
      return boxWidth / ratio;
    }
    final cached = cacheKey == null ? null : _staggeredAspectRatios[cacheKey];
    return cached == null ? boxHeight : boxWidth / cached;
  }

  late final String? _imagePathInitialValue = _latestInvalidImagePath[widget.path] == true ? null : ArtworkWidget.kImagePathInitialValue;

  String? _imagePath;
  late Uint8List? _bytes = widget.bytes ?? Indexer.inst.artworksBytesMap[widget.path];
  // late final bool _imageObtainedBefore = Indexer.inst.imageObtainedBefore(widget.path ?? '');

  bool _triedDeleting = false;

  /// fading again would blink a card colored box on top of the previous image.
  bool _displayedImageBefore = false;

  bool get _isWaitingForImage {
    final imagePath = _imagePath;
    final bytes = _bytes;
    if (imagePath != null && imagePath.isNotEmpty) return false;
    if (bytes != null && bytes.isNotEmpty) return false;
    return ((imagePath != null && imagePath == _imagePathInitialValue) || bytes != null) && !widget.forceDummyArtwork;
  }

  num get _getThumbnailEffectiveCacheHeight {
    return widget.cacheHeight?.validOrNull ?? widget.height?.validOrNull ?? widget.width?.validOrNull ?? widget.thumbnailSize;
  }

  @override
  void initState() {
    super.initState();
    if (_bytes?.isNotEmpty == true) {
      // -- skip
    } else {
      if (_imagePathInitialValue == ArtworkWidget.kImagePathInitialValue) {
        _imagePath = widget.path; // to prevent flashing/etc (only if was not invalid before)
      }
    }

    if (widget.extractInternally) {
      _initValues().whenComplete(
        () {
          if (_imagePath == null) {
            _markInvalidImagePath(widget.path);
          }
        },
      );
    }
  }

  Future<void> _initValues() async {
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
      await Future.delayed(Duration.zero, _extractArtwork);
    }
  }

  Future<void> _extractArtwork() async {
    final wPath = widget.path;
    if (wPath != null && _imagePath == _imagePathInitialValue) {
      if (!await canStartLoadingItems()) return;
      final track = widget.track;

      void updateValues(FArtwork res) {
        if (mounted) {
          final file = res.file;
          final b = res.bytes;
          if (file != null) {
            setState(() => _imagePath = file.path);
          } else if (b != null) {
            setState(() => _bytes = b);
          }
        }
      }

      if (widget.compressed == false) {
        await Indexer.inst
            .getArtwork(
              imagePath: wPath,
              track: track,
              compressed: false,
              checkFileFirst: false,
              size: null,
            )
            .then(updateValues);
      } else if (_bytes == null) {
        await Indexer.inst
            .getArtwork(
              imagePath: wPath,
              track: track,
              compressed: widget.compressed,
              checkFileFirst: false,
              size: widget.compressed ? _getThumbnailEffectiveCacheHeight.round() : null,
            )
            .then(updateValues);
      }

      if (track != null) {
        bool stillInvalid() => _imagePath == _imagePathInitialValue && _bytes == null;

        if (widget.fallbackToFolderCover) {
          if (stillInvalid()) {
            final cover = Indexer.inst.getFallbackFolderArtworkPath(folder: track.folder);
            if (cover != null && mounted) setState(() => _imagePath = cover);
          }
        }

        if (widget.fallbackToAlbumCover) {
          if (stillInvalid()) {
            for (final albumIdentifier in track.albumsIdentifiersModified) {
              final info = NetworkArtworkInfo.albumAutoArtist(albumIdentifier);
              final fallbackImagePath = info.toArtworkIfExistsAndValidAndEnabled()?.path ?? albumIdentifier.getAlbumTracks().trackOfImage?.pathToImage;
              if (!mounted) break;
              if (fallbackImagePath != null) {
                setState(() => _imagePath = fallbackImagePath);
                break;
              }
            }
          }
        }
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
    final bytes = this._bytes;
    // -- stable across image changes, a new key would drop the frame [ImageAdvanced] keeps painting
    final key = ValueKey(widget.key);
    final isValidBytes = bytes is Uint8List ? bytes.isNotEmpty : false;
    final goodImagePath = _imagePath?.isNotEmpty == true;
    final canDisplayImage = goodImagePath || isValidBytes;
    final boxWidth = widget.width ?? widget.thumbnailSize;
    final boxHeight = widget.height ?? widget.thumbnailSize;

    final dropShadowEnabled = settings.enableGlowEffect.value && widget.blur != 0.0;
    final sizePercentage = widget.disableBlurBgSizeShrink || !dropShadowEnabled ? 1.0 : DropShadow.defaultSizePercentage;

    // -- dont display stock widget if image can be obtained.
    if (_isWaitingForImage) {
      final box = SizedBox(
        key: key,
        width: boxWidth,
        height: widget.staggered ? _staggeredHeight(null, boxWidth, boxHeight) : boxHeight,
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

    ImageProvider? image;
    if (canDisplayImage && !widget.forceDummyArtwork) {
      final ImageProvider source = goodImagePath ? FileImage(File(_imagePath!)) : MemoryImage(bytes!);
      if (widget.compressed) {
        final pixelRatio = context.pixelRatio;
        final cacheMultiplier = pixelRatio * settings.artworkCacheHeightMultiplier.value;
        final extraMultiplier = (1 + (0.05 / pixelRatio * 15)); // higher for lower pixel ratio, for example 1=>1.75, 3=>1.25
        final usedHeight = _getThumbnailEffectiveCacheHeight;
        final refined = usedHeight * cacheMultiplier * extraMultiplier;
        image = ResizeImage.resizeIfNeeded(null, refined.round(), source);
      } else {
        final crops = widget.forceSquared && widget.fit != BoxFit.contain && widget.fit != BoxFit.scaleDown;
        image = ArtworkWidget.fullQualityImage(
          source,
          croppedLongestSide: crops ? math.max(boxWidth, boxHeight) * context.pixelRatio : 0,
        );
      }
    }

    final borderR = widget.isCircle || settings.borderRadiusMultiplier.value == 0 ? null : BorderRadius.circular(widget.borderRadius.multipliedRadius);
    final shape = widget.isCircle ? BoxShape.circle : BoxShape.rectangle;
    final theme = context.theme;
    Widget artwork = SizedBox(
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
                      if (image != null)
                        ImageAdvanced(
                          image: image,
                          gaplessPlayback: true,
                          fit: widget.fit,
                          alignment: widget.alignment,
                          // -- low and high, both cause pixelated image lmao
                          // -- but medium also causes delayed rendering especially while animating
                          filterQuality: widget.compressed ? FilterQuality.low : FilterQuality.high,
                          width: (info) {
                            if (widget.staggered) return boxWidth;
                            if (info == null) return realWidthAndHeight;
                            final aspectRatio = info.image.width / info.image.height;
                            ArtworkWidget._cacheAspectRatio(_staggeredCacheKey, aspectRatio);
                            if (widget.forceSquared) return realWidthAndHeight;
                            final fittedWidth = (boxHeight * aspectRatio).clampDouble(0.0, boxWidth);
                            return fittedWidth;
                          },
                          height: (info) => widget.staggered ? _staggeredHeight(info, boxWidth, boxHeight) : realWidthAndHeight,
                          frameBuilder: ((context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded || frame == null) return child;
                            if (_displayedImageBefore) return child;
                            _displayedImageBefore = true;
                            if (ArtworkWidget.isResizingAppWindow || ArtworkWidget.isMovingDrawer) return child;
                            if (widget.fadeMilliSeconds == 0) return child;
                            if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
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
                                        child: ColoredBox(color: theme.cardColor.withOpacityExt(value)),
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
                                  ArtworkWidget.evictImageFile(File(fp));
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
                      ...?widget.onTopWidgets,
                    ],
                  ),
                ),
        ),
      ),
    );

    if (NamidaFeaturesVisibility.floatingArtworkEffect) {
      if (widget.allowFloating) {
        if (settings.extra.floatingArtworkEffect.value == true) {
          artwork = _EncapsulateWithFloatingTilt(
            compressed: widget.compressed,
            child: artwork,
          );
        }
      }
    }

    return artwork;
  }
}

class _EncapsulateWithFloatingTilt extends StatelessWidget {
  final bool compressed;
  final Widget child;
  const _EncapsulateWithFloatingTilt({super.key, required this.compressed, required this.child});

  @override
  Widget build(BuildContext context) {
    final config =
        compressed // (non expanded)
        ? const TiltConfig(
            angle: 2.0,
            sensorFactor: 0.5,
            sensorRevertFactor: 0.1,
            enableGestureTouch: false,
            enableOutsideAreaMove: false,
            enableReverse: true,
            controllerMoveDuration: Duration(milliseconds: 200),
            leaveDuration: Duration(milliseconds: 400),
            moveDuration: Duration(milliseconds: 100),
            sensorMoveDuration: Duration(milliseconds: 50),
            enterDuration: Duration(milliseconds: 800),
            controllerLeaveDuration: Duration(milliseconds: 200),
          )
        : const TiltConfig(
            angle: 8.0,
            sensorFactor: 4.0,
            sensorRevertFactor: 0.02,
            enableGestureTouch: false,
            enableOutsideAreaMove: false,
            enableReverse: true,
            controllerMoveDuration: Duration(milliseconds: 200),
            leaveDuration: Duration(milliseconds: 400),
            moveDuration: Duration(milliseconds: 100),
            sensorMoveDuration: Duration(milliseconds: 50),
            enterDuration: Duration(milliseconds: 800),
            controllerLeaveDuration: Duration(milliseconds: 200),
          );
    return Tilt.base(
      tiltConfig: config,
      fps: 60,
      clipBehavior: Clip.none,
      lightConfig: const LightConfig(disable: true, color: Colors.transparent),
      shadowConfig: const ShadowBaseConfig(disable: true, color: Colors.transparent),
      childLayout: ChildLayout(
        inner: [
          TiltParallax(
            child: child,
          ),
        ],
      ),
      child: const SizedBox(),
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
  final IconData? fallbackIcon;
  final int fadeMilliSeconds;
  final bool opensInFullscreen;

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
    this.fallbackIcon,
    this.fadeMilliSeconds = ArtworkWidget.kDefaultFadeMilliSeconds,
    this.opensInFullscreen = false,
  });

  void _openInFullscreen(int index) {
    final images = <NamidaFullscreenImage>[];
    for (final tr in tracks) {
      final imagePath = tr.pathToImage;
      final placeholder = ArtworkWidget(
        key: Key(imagePath),
        fadeMilliSeconds: 0,
        thumbnailSize: thumbnailSize,
        track: tr,
        path: imagePath,
        forceSquared: true,
        blur: 0,
        borderRadius: 0,
        fallbackToFolderCover: fallbackToFolderCover,
        icon: fallbackIcon,
      );
      images.add(
        NamidaFullscreenImage(
          imageFile: () => File(imagePath),
          fetchImage: () => Indexer.inst.getArtwork(imagePath: imagePath, track: tr, compressed: false, checkFileFirst: false),
          onSave: (_, _) => EditDeleteController.inst.saveTrackArtworkToStorage(tr),
          placeholder: placeholder,
        ),
      );
    }
    NamidaArtworkFullscreen.open(
      images: images,
      initialIndex: index,
      heroTag: heroTag,
      themeColor: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final artworkFile = this.artworkFile;
    Widget? customArtworkWidget;
    if (artworkFile != null && artworkFile.existsSync()) {
      final customArtwork = ArtworkWidget(
        key: ValueKey(artworkFile.path),
        fadeMilliSeconds: fadeMilliSeconds,
        thumbnailSize: thumbnailSize,
        path: artworkFile.path,
        forceSquared: true,
        iconSize: iconSize,
        blur: 0,
        borderRadius: borderRadius,
        compressed: false,
        width: thumbnailSize,
        height: thumbnailSize,
        fallbackToFolderCover: fallbackToFolderCover,
        icon: fallbackIcon,
      );
      customArtworkWidget = opensInFullscreen
          ? _FullscreenImageOpener(
              heroTag: heroTag,
              imageFile: artworkFile,
              child: customArtwork,
            )
          : customArtwork;
    }
    late final imagePaths = [for (final t in tracks) t.pathToImage];
    late final collageWidget = _ArtworkCollage(
      cells: _CollageCells(
        tracks: tracks,
        imagePaths: imagePaths,
        iconSize: iconSize,
        fallbackToFolderCover: fallbackToFolderCover,
        reduceQuality: reduceQuality,
        fallbackIcon: fallbackIcon,
        fadeMilliSeconds: fadeMilliSeconds,
        onCellTap: opensInFullscreen ? _openInFullscreen : null,
      ),
    );
    return NamidaHero(
      tag: heroTag,
      enabled: !disableHero,
      flightBorderRadius: borderRadius.multipliedRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
        ),
        child: SizedBox(
          height: thumbnailSize,
          width: thumbnailSize,
          child:
              customArtworkWidget ??
              (tracks.isEmpty
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
                      icon: fallbackIcon,
                    )
                  : collageWidget),
        ),
      ),
    );
  }
}

/// a wide strip of cropped covers, or one cover when there are too few unique artworks for a strip.
///
/// by claude
class ArtworkStripBanner extends StatelessWidget {
  final Iterable<Selectable> tracks;
  final double width;
  final double height;
  final IconData? fallbackIcon;

  const ArtworkStripBanner({
    super.key,
    required this.tracks,
    required this.width,
    required this.height,
    this.fallbackIcon,
  });

  static const _kMinCells = 4;
  static const _kCellAspectRatio = 0.6;

  @override
  Widget build(BuildContext context) {
    final cellsCount = (width / (height * _kCellAspectRatio)).ceil().withMinimum(_kMinCells);
    final imageTracks = tracks.toImageTracks(cellsCount);
    final uniqueCount = imageTracks.length;
    if (uniqueCount == 0) {
      return ArtworkWidget(
        key: const Key(''),
        thumbnailSize: height,
        path: null,
        track: null,
        forceDummyArtwork: true,
        forceSquared: true,
        blur: 0,
        borderRadius: 0,
        width: width,
        height: height,
        icon: fallbackIcon,
      );
    }
    if (uniqueCount < _kMinCells) {
      final tr = imageTracks.first;
      final imagePath = tr.pathToImage;
      return _FullscreenImageOpener(
        heroTag: null,
        imageFile: File(imagePath),
        child: ArtworkWidget(
          key: Key(imagePath),
          thumbnailSize: height,
          track: tr,
          path: imagePath,
          forceSquared: true,
          blur: 0,
          borderRadius: 0,
          width: width,
          height: height,
          icon: fallbackIcon,
        ),
      );
    }
    final cellWidth = width / uniqueCount;
    final cells = <Widget>[];
    for (int i = 0; i < uniqueCount; i++) {
      final tr = imageTracks[i];
      final imagePath = tr.pathToImage;
      cells.add(
        ArtworkWidget(
          key: Key('${i}_$imagePath'),
          thumbnailSize: height,
          track: tr,
          path: imagePath,
          forceSquared: true,
          blur: 0,
          borderRadius: 0,
          width: cellWidth,
          height: height,
          icon: fallbackIcon,
        ),
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        children: cells,
      ),
    );
  }
}

class _FullscreenImageOpener extends StatelessWidget {
  final Object? heroTag;
  final File imageFile;
  final Widget child;

  const _FullscreenImageOpener({
    required this.heroTag,
    required this.imageFile,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaArtworkExpandableToFullscreen(
      heroTag: heroTag,
      imageFile: () => imageFile,
      fetchImage: () => null,
      onSave: (imgFile, _) => imgFile == null ? null : EditDeleteController.inst.saveImageToStorage(imgFile),
      themeColor: null,
      artwork: child,
    );
  }
}

// by claude
class _ArtworkCollage extends StatelessWidget {
  final _CollageCells cells;

  const _ArtworkCollage({
    required this.cells,
  });

  @override
  Widget build(BuildContext context) {
    final count = cells.tracks.length;
    return ObxO(
      rx: settings.artworkCollageStyle,
      builder: (context, style) => switch (style) {
        ArtworkCollageStyle.denseGrid when count >= 16 => _CollageGrid(cells: cells, perSide: 4),
        ArtworkCollageStyle.denseGrid when count >= 9 => _CollageGrid(cells: cells, perSide: 3),
        ArtworkCollageStyle.mosaic when count >= 6 => _CollageMosaic(cells: cells),
        ArtworkCollageStyle.fanStack when count >= 2 => _CollageFan(cells: cells),
        ArtworkCollageStyle.flow when count >= 3 => _CollageFlow(cells: cells),
        ArtworkCollageStyle.stack when count >= 2 => _CollageStack(cells: cells),
        ArtworkCollageStyle.collage when count >= 2 => _CollageSplit(cells: cells),
        ArtworkCollageStyle.grid ||
        ArtworkCollageStyle.denseGrid ||
        ArtworkCollageStyle.mosaic ||
        ArtworkCollageStyle.fanStack ||
        ArtworkCollageStyle.flow ||
        ArtworkCollageStyle.stack ||
        ArtworkCollageStyle.collage => _CollageClassic(cells: cells),
      },
    );
  }
}

class _CollageClassic extends StatelessWidget {
  final _CollageCells cells;

  const _CollageClassic({
    required this.cells,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final height = c.maxHeight;
        final halfWidth = width / 2;
        final halfHeight = height / 2;
        final iconSize = cells.iconSize;
        return switch (cells.tracks.length) {
          1 => cells.build(0, width, height, compressed: false),
          2 => Row(
            children: [
              cells.build(0, halfWidth, height, iconSize: iconSize - 2.0),
              cells.build(1, halfWidth, height, iconSize: iconSize - 2.0),
            ],
          ),
          3 => Row(
            children: [
              Column(
                children: [
                  cells.build(0, halfWidth, halfHeight, iconSize: iconSize - 2.0),
                  cells.build(1, halfWidth, halfHeight, iconSize: iconSize - 2.0),
                ],
              ),
              cells.build(2, halfWidth, height),
            ],
          ),
          _ => _CollageGrid(cells: cells, perSide: 2),
        };
      },
    );
  }
}

class _CollageGrid extends StatelessWidget {
  final _CollageCells cells;
  final int perSide;

  const _CollageGrid({
    required this.cells,
    required this.perSide,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = perSide == 2 ? cells.iconSize - 3.0 : cells.iconSize - 6.0;
    return LayoutBuilder(
      builder: (context, c) {
        final cellWidth = c.maxWidth / perSide;
        final cellHeight = c.maxHeight / perSide;
        return Column(
          children: [
            for (int row = 0; row < perSide; row++)
              Row(
                children: [
                  for (int col = 0; col < perSide; col++) cells.build(row * perSide + col, cellWidth, cellHeight, iconSize: iconSize),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _CollageMosaic extends StatelessWidget {
  final _CollageCells cells;

  const _CollageMosaic({
    required this.cells,
  });

  @override
  Widget build(BuildContext context) {
    final smallIconSize = cells.iconSize - 6.0;
    return LayoutBuilder(
      builder: (context, c) {
        final smallWidth = c.maxWidth / 3;
        final smallHeight = c.maxHeight / 3;
        return Column(
          children: [
            Row(
              children: [
                cells.build(0, smallWidth * 2, smallHeight * 2),
                Column(
                  children: [
                    cells.build(1, smallWidth, smallHeight, iconSize: smallIconSize),
                    cells.build(2, smallWidth, smallHeight, iconSize: smallIconSize),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                cells.build(3, smallWidth, smallHeight, iconSize: smallIconSize),
                cells.build(4, smallWidth, smallHeight, iconSize: smallIconSize),
                cells.build(5, smallWidth, smallHeight, iconSize: smallIconSize),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CollageFan extends StatelessWidget {
  final _CollageCells cells;

  const _CollageFan({
    required this.cells,
  });

  static const _kMaxCards = 5;
  static const _kAngleStep = 0.13;
  static const _kFitSafety = 0.98;
  static const _kAlignment = Alignment(0.0, -0.3);

  /// the widest the outermost card reaches once rotated around its bottom center, relative to its size.
  static double _rotatedWidthFactor(double angle) => math.cos(angle) + 2 * math.sin(angle);

  @override
  Widget build(BuildContext context) {
    final count = cells.tracks.length.withMaximum(_kMaxCards);
    final maxLevel = count ~/ 2;
    final cardSizePercentage = _kFitSafety / _rotatedWidthFactor(maxLevel * _kAngleStep);
    return LayoutBuilder(
      builder: (context, c) {
        final cardSize = math.min(c.maxWidth, c.maxHeight) * cardSizePercentage;
        final cards = <Widget>[];
        for (int i = count - 1; i >= 0; i--) {
          final level = (i + 1) ~/ 2;
          final angle = i.isOdd ? -level * _kAngleStep : level * _kAngleStep;
          final card = cells.build(i, cardSize, cardSize, borderRadius: 8.0, boxShadow: _CollageCells.flatShadows);
          cards.add(
            Transform.rotate(
              angle: angle,
              alignment: Alignment.bottomCenter,
              child: card,
            ),
          );
        }
        return RepaintBoundary(
          child: Stack(
            alignment: _kAlignment,
            children: cards,
          ),
        );
      },
    );
  }
}

class _CollageFlow extends StatelessWidget {
  final _CollageCells cells;

  const _CollageFlow({
    required this.cells,
  });

  static const _kMaxCards = 7;
  static const _kCardSizePercentage = 0.7;
  static const _kPerspective = 0.0015;
  static const _kLevelOffsets = [0.17, 0.28, 0.36];
  static const _kLevelAngles = [0.5, 0.7, 0.85];
  static const _kLevelScales = [0.8, 0.7, 0.6];

  @override
  Widget build(BuildContext context) {
    final count = cells.tracks.length.withMaximum(_kMaxCards);
    return LayoutBuilder(
      builder: (context, c) {
        final box = math.min(c.maxWidth, c.maxHeight);
        final cardSize = box * _kCardSizePercentage;
        final cards = <Widget>[];
        for (int i = count - 1; i >= 0; i--) {
          final card = cells.build(i, cardSize, cardSize, borderRadius: 6.0, boxShadow: _CollageCells.flatShadows);
          if (i == 0) {
            cards.add(card);
            continue;
          }
          final level = (i - 1) ~/ 2;
          final side = i.isOdd ? 1.0 : -1.0;
          final offset = box * _kLevelOffsets[level] * side;
          final angle = _kLevelAngles[level] * -side;
          final scale = _kLevelScales[level];
          final transform = Matrix4.identity()
            ..setEntry(3, 2, _kPerspective)
            ..translateByDouble(offset, 0.0, 0.0, 1.0)
            ..rotateY(angle)
            ..scaleByDouble(scale, scale, 1.0, 1.0);
          cards.add(
            Transform(
              transform: transform,
              alignment: Alignment.center,
              child: card,
            ),
          );
        }
        return RepaintBoundary(
          child: Stack(
            alignment: Alignment.center,
            children: cards,
          ),
        );
      },
    );
  }
}

class _CollageStack extends StatelessWidget {
  final _CollageCells cells;

  const _CollageStack({
    required this.cells,
  });

  static const _kMaxCards = 3;
  static const _kFrontSizePercentage = 0.9;
  static const _kStepPercentage = 0.035;
  static const _kShrinkPerLevel = 0.08;
  static const _kDimPerLevel = 0.28;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final shadow = BoxShadow(
      color: theme.shadowColor.withAlpha(90),
      blurRadius: 6.0,
      offset: const Offset(0.0, 2.0),
    );
    final count = cells.tracks.length.withMaximum(_kMaxCards);
    return LayoutBuilder(
      builder: (context, c) {
        final box = math.min(c.maxWidth, c.maxHeight);
        final frontSize = box * _kFrontSizePercentage;
        final step = box * _kStepPercentage;
        final frontTop = (box - frontSize) / 2 + (count - 1) * step / 2;
        final cards = <Widget>[];
        for (int i = count - 1; i >= 0; i--) {
          final size = frontSize * (1.0 - i * _kShrinkPerLevel);
          final dim = Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacityExt(i * _kDimPerLevel),
            ),
          );
          final card = cells.build(i, size, size, borderRadius: 8.0, boxShadow: [shadow], onTopWidgets: i == 0 ? null : [dim]);
          cards.add(
            Positioned(
              top: frontTop - i * step,
              child: card,
            ),
          );
        }
        return Stack(
          alignment: Alignment.center,
          children: cards,
        );
      },
    );
  }
}

class _CollageSplit extends StatelessWidget {
  final _CollageCells cells;

  const _CollageSplit({
    required this.cells,
  });

  static const _kMaxCovers = 3;

  /// corners in box fractions. the main cut runs from (0.55, 0) down to (0.35, 1) so the right cover stays the biggest,
  /// the left part is cut again from (0, 0.45) to the main cut's middle.
  static const _kRightPart = [Offset(0.55, 0.0), Offset(1.0, 0.0), Offset(1.0, 1.0), Offset(0.35, 1.0)];
  static const _kLeftPart = [Offset(0.0, 0.0), Offset(0.55, 0.0), Offset(0.35, 1.0), Offset(0.0, 1.0)];
  static const _kTopLeftPart = [Offset(0.0, 0.0), Offset(0.55, 0.0), Offset(0.45, 0.5), Offset(0.0, 0.45)];
  static const _kBottomLeftPart = [Offset(0.0, 0.45), Offset(0.45, 0.5), Offset(0.35, 1.0), Offset(0.0, 1.0)];

  @override
  Widget build(BuildContext context) {
    final count = cells.tracks.length.withMaximum(_kMaxCovers);
    final regions = count == 2 ? const [_kRightPart, _kLeftPart] : const [_kRightPart, _kTopLeftPart, _kBottomLeftPart];
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final height = c.maxHeight;
        return Stack(
          children: [
            for (int i = 0; i < count; i++)
              ClipPath(
                clipper: _PolygonClipper(regions[i]),
                child: cells.build(i, width, height),
              ),
          ],
        );
      },
    );
  }
}

class _PolygonClipper extends CustomClipper<Path> {
  final List<Offset> fractions;

  const _PolygonClipper(this.fractions);

  @override
  Path getClip(Size size) {
    final path = Path();
    final first = fractions.first;
    path.moveTo(first.dx * size.width, first.dy * size.height);
    for (int i = 1; i < fractions.length; i++) {
      final point = fractions[i];
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_PolygonClipper oldClipper) => !identical(fractions, oldClipper.fractions);
}

class _CollageCells {
  final List<Track> tracks;
  final List<String> imagePaths;
  final double iconSize;
  final bool fallbackToFolderCover;
  final bool reduceQuality;
  final IconData? fallbackIcon;
  final int fadeMilliSeconds;
  final void Function(int index)? onCellTap;

  const _CollageCells({
    required this.tracks,
    required this.imagePaths,
    required this.iconSize,
    required this.fallbackToFolderCover,
    required this.reduceQuality,
    required this.fallbackIcon,
    required this.fadeMilliSeconds,
    required this.onCellTap,
  });

  static const _kMinCacheHeight = 80.0;

  /// unblurred, for rotated or perspective cards. a blurred shadow there misses the rect fast path and gets re-blurred every frame.
  static const flatShadows = [
    BoxShadow(color: Color(0x30000000), spreadRadius: 2.0),
    BoxShadow(color: Color(0x50000000), spreadRadius: 0.75),
  ];

  Widget build(
    int index,
    double width,
    double height, {
    double? iconSize,
    double borderRadius = 0.0,
    bool compressed = true,
    List<BoxShadow>? boxShadow,
    List<Widget>? onTopWidgets,
  }) {
    final cellSize = math.min(width, height);
    final qualityCacheHeight = cellSize.withMinimum(_kMinCacheHeight).round();
    final cacheHeight = reduceQuality ? 40 : qualityCacheHeight;
    final artwork = ArtworkWidget(
      key: Key("${index}_${imagePaths[index]}"),
      fadeMilliSeconds: fadeMilliSeconds,
      thumbnailSize: cellSize,
      track: tracks[index],
      path: imagePaths[index],
      forceSquared: true,
      blur: 0,
      borderRadius: borderRadius,
      compressed: compressed,
      iconSize: iconSize,
      width: width,
      height: height,
      fallbackToFolderCover: fallbackToFolderCover,
      cacheHeight: compressed ? cacheHeight : null,
      boxShadow: boxShadow,
      onTopWidgets: onTopWidgets,
      icon: fallbackIcon,
    );
    final onCellTap = this.onCellTap;
    if (onCellTap == null) return artwork;
    return TapDetector(
      onTap: () => onCellTap(index),
      child: artwork,
    );
  }
}

extension<T extends num> on T {
  T? get validOrNull => this.isFinite ? this : null;
}
