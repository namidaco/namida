import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

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
    final hero = 'artist_$name$additionalHeroTag';
    return NamidaInkWell(
      onTap: () => NamidaOnTaps.inst.onArtistTap(name, type, artist),
      onLongPress: () => NamidaDialogs.inst.showArtistDialog(name, type),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageSize = constraints.maxWidth - 12.0;
          final remainingVerticalSpace = constraints.maxHeight - imageSize;
          double getFontSize(double m) => (remainingVerticalSpace * m).withMaximum(13.0);
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  NamidaHero(
                    tag: hero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Dimensions.gridHorizontalPadding),
                      child: ContainerWithBorder(
                        child: ArtworkWidget(
                          key: Key(artist.pathToImage),
                          track: artist.trackOfImage,
                          thumbnailSize: imageSize,
                          path: artist.pathToImage,
                          borderRadius: 10.0,
                          forceSquared: true,
                          blur: 0,
                          iconSize: 32.0,
                          displayIcon: displayIcon,
                        ),
                      ),
                    ),
                  ),
                  if (bottomCenterText != null)
                    Positioned(
                      bottom: -5.0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.theme.scaffoldBackgroundColor,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Text(
                            bottomCenterText!,
                            style: context.textTheme.displaySmall?.copyWith(fontSize: getFontSize(0.5)),
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
                              style: context.textTheme.displayMedium?.copyWith(
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
