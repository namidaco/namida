import 'dart:io';
import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/packages/drop_shadow.dart';

/// Always displays compressed image, if not [compressed] then it will add the full res image on top of it.
class ArtworkWidget extends StatelessWidget {
  final Track track;
  final Uint8List? bytes;
  final String? path;
  final bool compressed;
  final int fadeMilliSeconds;
  final double thumnailSize;
  final bool forceSquared;
  final Widget? child;
  final double scale;
  final double borderRadius;
  final double blur;
  final double? width;
  final double? height;
  final int? cacheHeight;
  final bool forceDummyArtwork;
  final Color? bgcolor;
  final double? iconSize;
  final bool staggered;
  final Widget? onTopWidget;
  final List<BoxShadow>? boxShadow;
  const ArtworkWidget({
    super.key,
    required this.track,
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
    this.forceDummyArtwork = false,
    this.bgcolor,
    this.iconSize,
    this.staggered = false,
    this.onTopWidget,
    this.boxShadow,
    this.path,
  });

  @override
  Widget build(BuildContext context) {
    final extImageChild = FileSystemEntity.typeSync(track.pathToImage) != FileSystemEntityType.notFound && !forceDummyArtwork
        ? Stack(
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
                      File(path ?? track.pathToImage),
                      gaplessPlayback: true,
                      fit: BoxFit.cover,
                      cacheHeight: (cacheHeight ?? 200) * Get.mediaQuery.devicePixelRatio ~/ 1,
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
                    ),
              if (!compressed)
                ExtendedImage.file(
                  File(track.pathToImage),
                  gaplessPlayback: true,
                  fit: BoxFit.cover,
                  clearMemoryCacheWhenDispose: true,
                  filterQuality: FilterQuality.high,
                  width: forceSquared ? context.width : null,
                  height: forceSquared ? context.width : null,
                ),
              if (onTopWidget != null) onTopWidget!,
            ],
          )
        : Container(
            width: width ?? thumnailSize,
            height: height ?? thumnailSize,
            key: const ValueKey("empty"),
            decoration: BoxDecoration(
              color: bgcolor ?? Color.alphaBlend(context.theme.cardColor.withAlpha(100), context.theme.scaffoldBackgroundColor),
              borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
            ),
            child: Icon(
              Broken.musicnote,
              size: iconSize,
            ),
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
  final List<Track> tracks;
  final double thumbnailSize;
  final Color? bgcolor;
  final double borderRadius;
  final Object heroTag;
  final bool disableHero;
  final double iconSize;
  const MultiArtworks(
      {super.key, required this.tracks, required this.thumbnailSize, this.bgcolor, this.borderRadius = 8.0, required this.heroTag, this.disableHero = false, this.iconSize = 29.0});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: thumbnailSize,
      width: thumbnailSize,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(borderRadius.multipliedRadius)),
      child: tracks.isEmpty
          ? ArtworkWidget(
              thumnailSize: thumbnailSize,
              track: Indexer.inst.tracksInfoList.first,
              forceSquared: true,
              blur: 0,
              forceDummyArtwork: true,
              bgcolor: bgcolor,
              borderRadius: borderRadius,
              iconSize: iconSize,
            )
          : tracks.length == 1
              ? ArtworkWidget(
                  thumnailSize: thumbnailSize,
                  track: tracks.elementAt(0),
                  forceSquared: true,
                  blur: 0,
                  borderRadius: 0,
                  compressed: false,
                )
              : tracks.length == 2
                  ? Row(
                      children: [
                        ArtworkWidget(
                          thumnailSize: thumbnailSize / 2,
                          height: thumbnailSize,
                          track: tracks.elementAt(0),
                          forceSquared: true,
                          blur: 0,
                          borderRadius: 0,
                          iconSize: iconSize - 2.0,
                        ),
                        ArtworkWidget(
                          thumnailSize: thumbnailSize / 2,
                          height: thumbnailSize,
                          track: tracks.elementAt(1),
                          forceSquared: true,
                          blur: 0,
                          borderRadius: 0,
                          iconSize: iconSize - 2.0,
                        ),
                      ],
                    )
                  : tracks.length == 3
                      ? Row(
                          children: [
                            Column(
                              children: [
                                ArtworkWidget(
                                  thumnailSize: thumbnailSize / 2,
                                  track: tracks.elementAt(0),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  iconSize: iconSize - 2.0,
                                ),
                                ArtworkWidget(
                                  thumnailSize: thumbnailSize / 2,
                                  track: tracks.elementAt(1),
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
                                  track: tracks.elementAt(2),
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
                                  track: tracks.elementAt(0),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  iconSize: iconSize - 3.0,
                                ),
                                ArtworkWidget(
                                  thumnailSize: thumbnailSize / 2,
                                  track: tracks.elementAt(1),
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
                                  track: tracks.elementAt(2),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  iconSize: iconSize - 3.0,
                                ),
                                ArtworkWidget(
                                  thumnailSize: thumbnailSize / 2,
                                  track: tracks.elementAt(3),
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
