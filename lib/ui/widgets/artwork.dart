import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:extended_image/extended_image.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/packages/drop_shadow.dart';

/// Always displays compressed image, if not [compressed] then it will add the full res image on top of it.
class ArtworkWidget extends StatelessWidget {
  final String? path;
  final Uint8List? bytes;
  final double thumnailSize;
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
  final Widget? onTopWidget;
  final List<Widget>? onTopWidgets;
  final List<BoxShadow>? boxShadow;
  const ArtworkWidget({
    super.key,
    this.bytes,
    this.compressed = true,
    this.fadeMilliSeconds = 300,
    required this.thumnailSize,
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
    this.onTopWidget,
    this.boxShadow,
    this.onTopWidgets,
    this.path,
  });

  @override
  Widget build(BuildContext context) {
    final stockWidget = Container(
      width: width ?? thumnailSize,
      height: height ?? thumnailSize,
      key: const ValueKey("empty"),
      decoration: BoxDecoration(
        color: bgcolor ?? Color.alphaBlend(context.theme.cardColor.withAlpha(100), context.theme.scaffoldBackgroundColor),
        borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
      ),
      child: Icon(
        Broken.musicnote,
        size: iconSize ?? thumnailSize / 2,
      ),
    );
    if (forceDummyArtwork) {
      return stockWidget;
    }
    if (path == null && bytes == null) {
      return stockWidget;
    }
    // if path is sent but not valid.
    // or bytes are sent but not valid.
    if ((path != null && path != '' && FileSystemEntity.typeSync(path!) == FileSystemEntityType.notFound) || (bytes != null && (bytes ?? []).isEmpty)) {
      return stockWidget;
    }
    final extImageChild = Stack(
      alignment: Alignment.center,
      children: [
        bytes != null
            ? ExtendedImage.memory(
                bytes!,
                gaplessPlayback: true,
                fit: BoxFit.cover,
                clearMemoryCacheWhenDispose: true,
                filterQuality: FilterQuality.high,
                width: forceSquared ? context.width : null,
                height: forceSquared ? context.width : null,
              )
            : Image.file(
                File(path!),
                gaplessPlayback: true,
                fit: BoxFit.cover,
                cacheHeight: useTrackTileCacheHeight
                    ? SettingsController.inst.trackThumbnailSizeinList.value.toInt() > 120
                        ? null
                        : 60 * (Get.mediaQuery.devicePixelRatio).round()
                    : (cacheHeight ?? 100) * (Get.mediaQuery.devicePixelRatio).round(),
                filterQuality: FilterQuality.medium,
                width: forceSquared ? context.width : null,
                height: forceSquared ? context.width : null,
                frameBuilder: ((context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedSwitcher(
                    duration: Duration(milliseconds: fadeMilliSeconds),
                    child: frame != null ? child : const SizedBox(),
                  );
                }),
                errorBuilder: (context, error, stackTrace) {
                  return stockWidget;
                },
              ),
        if (!compressed)
          ExtendedImage.file(
            File(path!),
            gaplessPlayback: true,
            fit: BoxFit.cover,
            clearMemoryCacheWhenDispose: true,
            filterQuality: FilterQuality.high,
            width: forceSquared ? context.width : null,
            height: forceSquared ? context.width : null,
          ),
        if (onTopWidget != null) onTopWidget!,
        if (onTopWidgets != null) ...onTopWidgets!,
      ],
    );

    return SettingsController.inst.enableGlowEffect.value && blur != 0.0
        ? SizedBox(
            width: staggered ? null : width ?? thumnailSize * scale,
            height: staggered ? null : height ?? thumnailSize * scale,
            child: Center(
              child: SettingsController.inst.borderRadiusMultiplier.value == 0.0 || borderRadius == 0
                  ? DropShadow(
                      borderRadius: borderRadius.multipliedRadius,
                      blurRadius: blur,
                      spread: 0.8,
                      offset: const Offset(0, 1),
                      boxShadow: boxShadow,
                      child: child ?? extImageChild,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
                      child: DropShadow(
                        borderRadius: borderRadius.multipliedRadius,
                        blurRadius: blur,
                        spread: 0.8,
                        offset: const Offset(0, 1),
                        boxShadow: boxShadow,
                        child: child ?? extImageChild,
                      ),
                    ),
            ),
          )
        : SizedBox(
            width: staggered ? null : width ?? thumnailSize * scale,
            height: staggered ? null : height ?? thumnailSize * scale,
            child: Center(
              child: Container(
                decoration: BoxDecoration(boxShadow: boxShadow),
                child: SettingsController.inst.borderRadiusMultiplier.value == 0.0
                    ? child ?? extImageChild
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
                        child: child ?? extImageChild,
                      ),
              ),
            ),
          );
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
              thumnailSize: thumbnailSize,
              path: allTracksInLibrary.first.pathToImage,
              forceSquared: true,
              blur: 0,
              forceDummyArtwork: true,
              bgcolor: bgcolor,
              borderRadius: borderRadius,
              iconSize: iconSize,
            )
          : paths.length == 1
              ? ArtworkWidget(
                  thumnailSize: thumbnailSize,
                  path: paths.elementAt(0),
                  forceSquared: true,
                  blur: 0,
                  borderRadius: 0,
                  compressed: false,
                )
              : paths.length == 2
                  ? Row(
                      children: [
                        ArtworkWidget(
                          thumnailSize: thumbnailSize / 2,
                          height: thumbnailSize,
                          path: paths.elementAt(0),
                          forceSquared: true,
                          blur: 0,
                          borderRadius: 0,
                          iconSize: iconSize - 2.0,
                        ),
                        ArtworkWidget(
                          thumnailSize: thumbnailSize / 2,
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
                                  thumnailSize: thumbnailSize / 2,
                                  path: paths.elementAt(0),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  iconSize: iconSize - 2.0,
                                ),
                                ArtworkWidget(
                                  thumnailSize: thumbnailSize / 2,
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
                                  thumnailSize: thumbnailSize / 2,
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
                                  thumnailSize: thumbnailSize / 2,
                                  path: paths.elementAt(0),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  iconSize: iconSize - 3.0,
                                ),
                                ArtworkWidget(
                                  thumnailSize: thumbnailSize / 2,
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
                                  thumnailSize: thumbnailSize / 2,
                                  path: paths.elementAt(2),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  iconSize: iconSize - 3.0,
                                ),
                                ArtworkWidget(
                                  thumnailSize: thumbnailSize / 2,
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
