import 'dart:io';

import 'package:drop_shadow/drop_shadow.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';

/// Always displays compressed image, if not [compressed] then it will add the full res image on top of it.
class ArtworkWidget extends StatelessWidget {
  const ArtworkWidget({
    super.key,
    required this.track,
    this.compressed = true,
    this.fadeMilliSeconds = 250,
    required this.thumnailSize,
    this.forceSquared = false,
    this.child,
    this.scale = 1.0,
    this.borderRadius = 8.0,
    this.blur = 1.5,
    this.width,
    this.height,
    this.cacheHeight,
  });

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

  @override
  Widget build(BuildContext context) {
    final finalPath = compressed ? track.pathToImageComp : track.pathToImage;
    final extImageChild = FileSystemEntity.typeSync(finalPath) != FileSystemEntityType.notFound
        ? Stack(
            children: [
              Image.file(
                File(track.pathToImageComp),
                gaplessPlayback: true,
                fit: BoxFit.cover,
                cacheHeight: cacheHeight ?? 240,
                filterQuality: FilterQuality.high,
                width: forceSquared ? MediaQuery.of(context).size.width : null,
                height: forceSquared ? MediaQuery.of(context).size.width : null,
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
                  width: forceSquared ? MediaQuery.of(context).size.width : null,
                  height: forceSquared ? MediaQuery.of(context).size.width : null,
                ),
            ],
          )
        : Container(
            width: width ?? thumnailSize,
            height: height ?? thumnailSize,
            key: const ValueKey("empty"),
            decoration: BoxDecoration(
              color: context.theme.colorScheme.background,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: const Icon(Broken.musicnote),
          );

    return SettingsController.inst.enableGlowEffect.value
        ? SizedBox(
            width: width ?? thumnailSize * scale,
            height: height ?? thumnailSize * scale,
            child: Center(
              child: SettingsController.inst.borderRadiusMultiplier.value == 0.0
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
            width: thumnailSize * scale,
            height: thumnailSize * scale,
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
  const MultiArtworks({super.key, required this.tracks, required this.thumbnailSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: thumbnailSize,
      width: thumbnailSize,
      child: tracks.length == 1
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
