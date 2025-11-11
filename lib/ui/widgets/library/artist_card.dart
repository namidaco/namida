import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/network_artwork.dart';

class ArtistCard extends StatelessWidget {
  final String name;
  final List<Track> artist;
  final bool displayIcon;
  final String? bottomCenterText;
  final String additionalHeroTag;
  final HomePageItems? homepageItem;
  final MediaType type;

  const ArtistCard({
    super.key,
    required this.name,
    required this.artist,
    this.displayIcon = true,
    this.bottomCenterText,
    this.additionalHeroTag = '',
    this.homepageItem,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final hero = 'artist_$name$additionalHeroTag';
    return NamidaInkWell(
      onTap: () => NamidaOnTaps.inst.onArtistTap(name, type, artist),
      onLongPress: () => NamidaDialogs.inst.showArtistDialog(name, type),
      enableSecondaryTap: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageSize = constraints.maxWidth - 12.0;
          final remainingVerticalSpace = constraints.maxHeight - imageSize;
          double getFontSize(double m) => (remainingVerticalSpace * m).withMaximum(13.0);
          final bottomCenterTextSize = getFontSize(0.5).withMaximum(imageSize * 0.12);
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  NamidaHero(
                    tag: hero,
                    child: ContainerWithBorder(
                      child: NetworkArtwork.orLocal(
                        key: Key(artist.pathToImage),
                        info: NetworkArtworkInfo.artist(name),
                        path: artist.pathToImage,
                        track: artist.trackOfImage,
                        thumbnailSize: imageSize,
                        borderRadius: 0.0,
                        forceSquared: true,
                        blur: 8.0,
                        disableBlurBgSizeShrink: true,
                        isCircle: true,
                        iconSize: 32.0,
                        displayIcon: displayIcon,
                      ),
                    ),
                  ),
                  if (bottomCenterText != null && bottomCenterText!.isNotEmpty && bottomCenterText != name)
                    Positioned(
                      bottom: -5.0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(99.0.multipliedRadius),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: bottomCenterTextSize,
                              minWidth: bottomCenterTextSize.withMaximum(imageSize),
                              maxWidth: imageSize,
                            ),
                            child: Text(
                              bottomCenterText!,
                              style: textTheme.displaySmall?.copyWith(fontSize: bottomCenterTextSize),
                              textAlign: TextAlign.center,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (name.isNotEmpty)
                Positioned(
                  left: 0.0,
                  bottom: 0.0,
                  right: 0.0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: remainingVerticalSpace * 0.1),
                        Flexible(
                          child: NamidaHero(
                            tag: 'line1_$hero',
                            child: Text(
                              name.overflow,
                              style: textTheme.displayMedium?.copyWith(
                                fontSize: getFontSize(0.5),
                                fontWeight: FontWeight.w500,
                              ),
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ),
                        SizedBox(height: remainingVerticalSpace * 0.2),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
