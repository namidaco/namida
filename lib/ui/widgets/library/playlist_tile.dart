import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

class PlaylistTile extends StatelessWidget {
  final String playlistName;
  final void Function()? onTap;
  final bool enableHero;
  final bool? checkmarkStatus;
  final String? extraText;

  const PlaylistTile({
    super.key,
    required this.playlistName,
    this.onTap,
    this.enableHero = true,
    required this.checkmarkStatus,
    this.extraText,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final hero = 'playlist_$playlistName';
    late final borderSide = BorderSide(
      width: 2.0,
      color: context.theme.colorScheme.secondary.withOpacityExt(0.5),
    );
    final decoration = checkmarkStatus == true
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(12.0.multipliedRadius),
            border: Border(
              left: borderSide,
              bottom: borderSide,
            ),
          )
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.tileBottomMargin),
      child: NamidaInkWell(
        borderRadius: 0.0,
        onTap: onTap,
        onLongPress: () => NamidaDialogs.inst.showPlaylistDialog(playlistName),
        enableSecondaryTap: true,
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: SizedBox(
          height: Dimensions.playlistTileItemExtent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Dimensions.tileVerticalPadding),
            child: _PreferAnimatedDecoratedBox(
              duration: checkmarkStatus != null ? const Duration(milliseconds: 200) : Duration.zero,
              decoration: decoration ?? const BoxDecoration(),
              child: Obx(
                (context) {
                  PlaylistController.inst.playlistsMap.valueR;
                  final playlist = PlaylistController.inst.getPlaylist(playlistName);
                  if (playlist == null) return const SizedBox();
                  final tracksRaw = playlist.tracks.toTracks();

                  return Row(
                    children: [
                      MultiArtworkContainer(
                        heroTag: hero,
                        enableHero: enableHero,
                        size: Dimensions.playlistThumbnailSize,
                        tracks: tracksRaw.toImageTracks(),
                        artworkFile: PlaylistController.inst.getArtworkFileForPlaylist(playlistName),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NamidaHero(
                              enabled: enableHero,
                              tag: 'line1_$hero',
                              child: Text(
                                playlist.name.translatePlaylistName(),
                                style: textTheme.displayMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            NamidaHero(
                              enabled: enableHero,
                              tag: 'line2_$hero',
                              child: Text(
                                [
                                  tracksRaw.displayTrackKeyword,
                                  if (extraText?.isNotEmpty == true) extraText,
                                ].join(' • '),
                                style: textTheme.displaySmall?.copyWith(fontSize: 13.7),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (playlist.moods.isNotEmpty)
                              NamidaHero(
                                enabled: enableHero,
                                tag: 'line3_$hero',
                                child: Text(
                                  playlist.moods.join(', ').overflow,
                                  style: textTheme.displaySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      if (checkmarkStatus != null) ...[
                        NamidaCheckMark(
                          size: 12.0,
                          active: checkmarkStatus!,
                        ),
                        const SizedBox(width: 6.0),
                      ],
                      Text(
                        tracksRaw.totalDurationFormatted,
                        style: textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 2.0),
                      if (playlist.m3uPath != null) ...[
                        NamidaTooltip(
                          message: () => "${lang.M3U_PLAYLIST}\n${playlist.m3uPath?.formatPath()}",
                          child: const Icon(Broken.music_filter, size: 18.0),
                        ),
                        const SizedBox(width: 2.0),
                      ],
                      MoreIcon(
                        iconSize: 20,
                        onPressed: () => NamidaDialogs.inst.showPlaylistDialog(playlistName),
                      ),
                      const SizedBox(width: 8.0),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferAnimatedDecoratedBox extends StatelessWidget {
  final Duration duration;
  final Decoration decoration;
  final Widget child;

  const _PreferAnimatedDecoratedBox({
    required this.duration,
    required this.decoration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (duration == Duration.zero) return child;
    return AnimatedDecoration(
      decoration: decoration,
      duration: duration,
      child: child,
    );
  }
}
