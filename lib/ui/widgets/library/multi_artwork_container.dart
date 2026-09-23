import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class MultiArtworkContainer extends StatelessWidget {
  final double size;
  final Widget? child;
  final Widget? onTopWidget;
  final List<Track>? tracks;
  final EdgeInsetsGeometry? margin;
  final String heroTag;
  final bool fallbackToFolderCover;
  final bool reduceQuality;
  final bool enableHero;
  final File? artworkFile;
  final IconData? fallbackIcon;
  final int fadeMilliSeconds;
  final bool wrapArtworkFileInFullscreenOpener;

  const MultiArtworkContainer({
    super.key,
    required this.size,
    this.child,
    this.margin,
    this.tracks,
    this.onTopWidget,
    required this.heroTag,
    this.fallbackToFolderCover = true,
    this.reduceQuality = false,
    this.enableHero = true,
    this.artworkFile,
    this.fallbackIcon,
    this.fadeMilliSeconds = ArtworkWidget.kDefaultFadeMilliSeconds,
    this.wrapArtworkFileInFullscreenOpener = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = this.size.withMaximum(constraints.maxWidth).withMaximum(constraints.maxHeight);
        final innerSize = size - 6.0;
        return Container(
          alignment: Alignment.center,
          margin: margin ?? const EdgeInsets.symmetric(horizontal: 12.0),
          padding: const EdgeInsets.all(3.0),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: theme.cardTheme.color?.withAlpha(180),
            borderRadius: BorderRadius.circular(18.0.multipliedRadius),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withAlpha(180),
                blurRadius: 8,
                offset: const Offset(0, 2.0),
              ),
            ],
          ),
          child: NamidaHero(
            enabled: enableHero,
            tag: heroTag,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18.0.multipliedRadius),
              ),
              // -- scales with hero flights, otherwise each side keeps its fixed size mid-flight
              child: FittedBox(
                child: SizedBox.square(
                  dimension: innerSize,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      if (artworkFile != null || tracks != null)
                        MultiArtworks(
                          disableHero: true,
                          heroTag: heroTag,
                          tracks: tracks!,
                          thumbnailSize: innerSize,
                          fallbackToFolderCover: fallbackToFolderCover,
                          reduceQuality: reduceQuality,
                          artworkFile: artworkFile,
                          fallbackIcon: fallbackIcon,
                          fadeMilliSeconds: fadeMilliSeconds,
                          wrapArtworkFileInFullscreenOpener: wrapArtworkFileInFullscreenOpener,
                        ),
                      ?child,
                      ?onTopWidget,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
