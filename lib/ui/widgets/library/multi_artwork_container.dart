import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/artwork.dart';

class MultiArtworkContainer extends StatelessWidget {
  final double size;
  final Widget? child;
  final Widget? onTopWidget;
  final List<Track>? tracks;
  final EdgeInsetsGeometry? margin;
  final String heroTag;
  const MultiArtworkContainer({super.key, required this.size, this.child, this.margin, this.tracks, this.onTopWidget, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 12.0),
      padding: const EdgeInsets.all(3.0),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.theme.cardTheme.color?.withAlpha(180),
        borderRadius: BorderRadius.circular(18.0.multipliedRadius),
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2.0),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0.multipliedRadius),
        child: Stack(
          children: [
            if (tracks != null)
              MultiArtworks(
                heroTag: heroTag,
                paths: tracks!.map((e) => e.pathToImage).toList(),
                thumbnailSize: size - 6.0,
              ),
            if (child != null) child!,
            if (onTopWidget != null) onTopWidget!,
          ],
        ),
      ),
    );
  }
}
