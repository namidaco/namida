import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
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
  });

  bool _isFanCollage(ArtworkCollageStyle collageStyle, bool hasCustomArtwork) {
    if (collageStyle != ArtworkCollageStyle.fanStack) return false;
    if (hasCustomArtwork) return false;
    final tracksCount = tracks?.length ?? 0;
    return tracksCount >= 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scope = ArtworkContainerScope.maybeOf(context);
    final artworkFile = this.artworkFile;
    final hasCustomArtwork = artworkFile != null && artworkFile.existsSync();
    final existingArtworkFile = hasCustomArtwork ? artworkFile : null;
    return ObxO(
      rx: settings.artworkCollageStyle,
      builder: (context, collageStyle) {
        final isFan = _isFanCollage(collageStyle, hasCustomArtwork);
        final isBareFan = scope != null && scope.bareForFan && isFan;
        final isBare = scope != null && (scope.frameless || isBareFan);
        final fanScale = isBareFan ? scope.bareFanScale : 1.0;
        final frameRadius = 18.0.multipliedRadius;
        final frameDecoration = isBare
            ? null
            : BoxDecoration(
                color: theme.cardTheme.color?.withAlpha(180),
                borderRadius: BorderRadius.circular(frameRadius),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withAlpha(180),
                    blurRadius: 8,
                    offset: const Offset(0, 2.0),
                  ),
                ],
              );
        final framePadding = isBare ? EdgeInsets.zero : const EdgeInsets.all(3.0);
        final frameInset = isBare ? 0.0 : 6.0;
        final frameMargin = isBare ? EdgeInsets.zero : margin ?? const EdgeInsets.symmetric(horizontal: 12.0);
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = this.size.withMaximum(constraints.maxWidth).withMaximum(constraints.maxHeight);
            final drawnSize = size * fanScale;
            final innerSize = drawnSize - frameInset;
            final container = Container(
              alignment: Alignment.center,
              margin: frameMargin,
              padding: framePadding,
              width: drawnSize,
              height: drawnSize,
              decoration: frameDecoration,
              child: NamidaHero(
                enabled: enableHero,
                tag: heroTag,
                flightBorderRadius: isBare ? null : frameRadius,
                child: Container(
                  clipBehavior: isBare ? Clip.none : Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(frameRadius),
                  ),
                  // -- scales with hero flights, otherwise each side keeps its fixed size mid-flight
                  child: FittedBox(
                    child: SizedBox.square(
                      dimension: innerSize,
                      child: Stack(
                        clipBehavior: isBare ? Clip.none : Clip.hardEdge,
                        children: [
                          if (artworkFile != null || tracks != null)
                            MultiArtworks(
                              disableHero: true,
                              heroTag: heroTag,
                              tracks: tracks!,
                              thumbnailSize: innerSize,
                              fallbackToFolderCover: fallbackToFolderCover,
                              reduceQuality: reduceQuality,
                              artworkFile: existingArtworkFile,
                              fallbackIcon: fallbackIcon,
                              fadeMilliSeconds: fadeMilliSeconds,
                              opensSingleImageInFullscreen: scope?.opensSingleImageInFullscreen ?? false,
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
            if (fanScale == 1.0) return container;
            return SizedBox.square(
              dimension: size,
              child: OverflowBox(
                maxWidth: drawnSize,
                maxHeight: drawnSize,
                child: container,
              ),
            );
          },
        );
      },
    );
  }
}

/// how a [MultiArtworkContainer] below draws itself: [frameless] drops the card frame and margins always,
/// [bareForFan] only for a fan of cards, which then draws at [bareFanScale] past its box. [opensSingleImageInFullscreen] makes a lone image tappable.
///
/// by claude
class ArtworkContainerScope extends InheritedWidget {
  final bool bareForFan;
  final double bareFanScale;
  final bool frameless;
  final bool opensSingleImageInFullscreen;

  const ArtworkContainerScope({
    super.key,
    this.bareForFan = false,
    this.bareFanScale = 1.0,
    this.frameless = false,
    this.opensSingleImageInFullscreen = false,
    required super.child,
  });

  static ArtworkContainerScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ArtworkContainerScope>();

  @override
  bool updateShouldNotify(ArtworkContainerScope oldWidget) =>
      bareForFan != oldWidget.bareForFan ||
      bareFanScale != oldWidget.bareFanScale ||
      frameless != oldWidget.frameless ||
      opensSingleImageInFullscreen != oldWidget.opensSingleImageInFullscreen;
}
