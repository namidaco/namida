import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class MultiArtworkContainer extends StatefulWidget {
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

  @override
  State<MultiArtworkContainer> createState() => _MultiArtworkContainerState();
}

class _MultiArtworkContainerState extends State<MultiArtworkContainer> {
  late bool _hasCustomArtwork = _checkCustomArtwork();

  bool _checkCustomArtwork() => widget.artworkFile?.existsSync() == true;

  void _onArtworkFileChanged() => refreshState(() => _hasCustomArtwork = _checkCustomArtwork());

  @override
  void initState() {
    super.initState();
    final artworkPath = widget.artworkFile?.path;
    if (artworkPath != null) ArtworkWidget.addImageFileListener(artworkPath, _onArtworkFileChanged);
  }

  @override
  void didUpdateWidget(MultiArtworkContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldArtworkPath = oldWidget.artworkFile?.path;
    final artworkPath = widget.artworkFile?.path;
    if (oldArtworkPath == artworkPath) return;
    if (oldArtworkPath != null) ArtworkWidget.removeImageFileListener(oldArtworkPath, _onArtworkFileChanged);
    if (artworkPath != null) ArtworkWidget.addImageFileListener(artworkPath, _onArtworkFileChanged);
    _hasCustomArtwork = _checkCustomArtwork();
  }

  @override
  void dispose() {
    final artworkPath = widget.artworkFile?.path;
    if (artworkPath != null) ArtworkWidget.removeImageFileListener(artworkPath, _onArtworkFileChanged);
    super.dispose();
  }

  bool _isFanCollage(ArtworkCollageStyle collageStyle, bool hasCustomArtwork) {
    if (collageStyle != ArtworkCollageStyle.fanStack) return false;
    if (hasCustomArtwork) return false;
    final tracksCount = widget.tracks?.length ?? 0;
    return tracksCount >= 2;
  }

  @override
  Widget build(BuildContext context) {
    final scope = ArtworkContainerScope.maybeOf(context);
    final artworkFile = widget.artworkFile;
    final tracks = widget.tracks;
    final hasCustomArtwork = _hasCustomArtwork;
    final existingArtworkFile = hasCustomArtwork ? artworkFile : null;
    return ObxO(
      rx: settings.artworkCollageStyle,
      builder: (context, collageStyle) {
        final isFan = _isFanCollage(collageStyle, hasCustomArtwork);
        final isBareFan = scope != null && scope.bareForFan && isFan;
        final isBare = scope != null && (scope.frameless || isBareFan);
        final fanScale = isBareFan ? scope.bareFanScale : 1.0;
        final frameRadius = 18.0.multipliedRadius;
        final Decoration Function(NColorsData colors)? frameDecoration = isBare
            ? null
            : (colors) => BoxDecoration(
                color: colors.cardTheme.withOpacityExt(0.71),
                borderRadius: BorderRadius.circular(frameRadius),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withOpacityExt(0.71),
                    blurRadius: 8,
                    offset: const Offset(0, 2.0),
                  ),
                ],
              );
        final framePadding = isBare ? EdgeInsets.zero : const EdgeInsets.all(3.0);
        final frameInset = isBare ? 0.0 : 6.0;
        final frameMargin = isBare ? EdgeInsets.zero : widget.margin ?? const EdgeInsets.symmetric(horizontal: 12.0);
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = widget.size.withMaximum(constraints.maxWidth).withMaximum(constraints.maxHeight);
            final drawnSize = size * fanScale;
            final innerSize = drawnSize - frameInset;
            final container = NContainer(
              alignment: Alignment.center,
              margin: frameMargin,
              padding: framePadding,
              width: drawnSize,
              height: drawnSize,
              decoration: frameDecoration,
              child: NamidaHero(
                enabled: widget.enableHero,
                tag: widget.heroTag,
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
                              heroTag: widget.heroTag,
                              tracks: tracks!,
                              thumbnailSize: innerSize,
                              fallbackToFolderCover: widget.fallbackToFolderCover,
                              reduceQuality: widget.reduceQuality,
                              existingArtworkFile: existingArtworkFile,
                              fallbackIcon: widget.fallbackIcon,
                              fadeMilliSeconds: widget.fadeMilliSeconds,
                              opensInFullscreen: scope?.opensInFullscreen ?? false,
                            ),
                          ?widget.child,
                          ?widget.onTopWidget,
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
/// [bareForFan] only for a fan of cards, which then draws at [bareFanScale] past its box. [opensInFullscreen] opens the tapped image in a swipeable viewer.
///
/// by claude
class ArtworkContainerScope extends InheritedWidget {
  final bool bareForFan;
  final double bareFanScale;
  final bool frameless;
  final bool opensInFullscreen;

  const ArtworkContainerScope({
    super.key,
    this.bareForFan = false,
    this.bareFanScale = 1.0,
    this.frameless = false,
    this.opensInFullscreen = false,
    required super.child,
  });

  static ArtworkContainerScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ArtworkContainerScope>();

  @override
  bool updateShouldNotify(ArtworkContainerScope oldWidget) =>
      bareForFan != oldWidget.bareForFan || //
      bareFanScale != oldWidget.bareFanScale ||
      frameless != oldWidget.frameless ||
      opensInFullscreen != oldWidget.opensInFullscreen;
}
