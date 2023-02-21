import 'dart:io';

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
  final Positioned? onTopWidget;
  const ArtworkWidget({
    super.key,
    required this.track,
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
  });

  @override
  Widget build(BuildContext context) {
    final finalPath = compressed ? track.pathToImageComp : track.pathToImage;
    final extImageChild = FileSystemEntity.typeSync(finalPath) != FileSystemEntityType.notFound && !forceDummyArtwork
        ? Stack(
            children: [
              Image.file(
                File(track.pathToImageComp),
                gaplessPlayback: true,
                fit: BoxFit.cover,
                cacheHeight: cacheHeight ?? 240,
                filterQuality: FilterQuality.high,
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
                  cacheWidth: 1080,
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
              color: bgcolor ?? Color.alphaBlend(context.theme.cardColor.withAlpha(100), context.theme.colorScheme.background),
              borderRadius: BorderRadius.circular(borderRadius),
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
                      child: child ?? extImageChild,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
                      child: DropShadow(
                        borderRadius: borderRadius.multipliedRadius,
                        blurRadius: blur,
                        spread: 0.8,
                        offset: const Offset(0, 1),
                        child: child ?? extImageChild,
                      ),
                    ),
            ),
          )
        : SizedBox(
            width: staggered ? null : width ?? thumnailSize * scale,
            height: staggered ? null : height ?? thumnailSize * scale,
            child: Center(
              child: SettingsController.inst.borderRadiusMultiplier.value == 0.0
                  ? child ?? extImageChild
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
                      child: child ?? extImageChild,
                    ),
            ),
          );
  }
}

class MultiArtworks extends StatelessWidget {
  final List<Track> tracks;
  final double thumbnailSize;
  final Color? bgcolor;
  final double? borderRadius;
  const MultiArtworks({super.key, required this.tracks, required this.thumbnailSize, this.bgcolor, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thumbnailSize,
      width: thumbnailSize,
      child: tracks.isEmpty
          ? ArtworkWidget(
              thumnailSize: thumbnailSize,
              track: Indexer.inst.tracksInfoList.first,
              forceSquared: true,
              cacheHeight: 480,
              blur: 0,
              forceDummyArtwork: true,
              bgcolor: bgcolor,
              borderRadius: borderRadius ?? 8.0,
              iconSize: 28.0,
            )
          : tracks.length == 1
              ? ArtworkWidget(
                  thumnailSize: thumbnailSize,
                  track: tracks.elementAt(0),
                  forceSquared: true,
                  blur: 0,
                  borderRadius: 0,
                  cacheHeight: 480,
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
                          cacheHeight: 480,
                        ),
                        ArtworkWidget(
                          thumnailSize: thumbnailSize / 2,
                          height: thumbnailSize,
                          track: tracks.elementAt(1),
                          forceSquared: true,
                          blur: 0,
                          borderRadius: 0,
                          cacheHeight: 480,
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
                                ),
                                ArtworkWidget(
                                  thumnailSize: thumbnailSize / 2,
                                  track: tracks.elementAt(1),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
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
                                  cacheHeight: 480,
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
                                ),
                                ArtworkWidget(
                                  thumnailSize: thumbnailSize / 2,
                                  track: tracks.elementAt(1),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
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
                                ),
                                ArtworkWidget(
                                  thumnailSize: thumbnailSize / 2,
                                  track: tracks.elementAt(3),
                                  forceSquared: true,
                                  blur: 0,
                                  borderRadius: 0,
                                  // width: 100,
                                ),
                              ],
                            ),
                          ],
                        ),
    );
  }
}
