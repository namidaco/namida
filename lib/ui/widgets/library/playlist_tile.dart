import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/playlist_tags_chips_row.dart';

class PlaylistTile extends StatelessWidget {
  final String playlistName;
  final void Function()? onTap;
  final void Function()? onLongPress;
  final bool enableHero;
  final bool? checkmarkStatus;
  final String? extraText;

  const PlaylistTile({
    super.key,
    required this.playlistName,
    this.onTap,
    this.onLongPress,
    this.enableHero = true,
    required this.checkmarkStatus,
    this.extraText,
  });

  @override
  Widget build(BuildContext context) {
    final hero = 'playlist_$playlistName';
    final isChecked = checkmarkStatus == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.tileBottomMargin),
      child: NamidaInkWell(
        borderRadius: 0.0,
        onTap: onTap,
        onLongPress: onLongPress ?? () => NamidaDialogs.inst.showPlaylistDialog(playlistName),
        enableSecondaryTap: true,
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: SizedBox(
          height: Dimensions.playlistTileItemExtent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Dimensions.tileVerticalPadding),
            child: _PreferAnimatedDecoratedBox(
              duration: checkmarkStatus != null ? const Duration(milliseconds: 200) : Duration.zero,
              decoration: (colors) {
                if (!isChecked) return const BoxDecoration();
                final borderSide = BorderSide(
                  width: 2.0,
                  color: colors.secondary.withOpacityExt(0.5),
                );
                return BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                  border: Border(
                    left: borderSide,
                    bottom: borderSide,
                  ),
                );
              },
              child: Obx(
                (context) {
                  PlaylistController.inst.playlistsMap.valueR;
                  final playlist = PlaylistController.inst.getPlaylist(playlistName);
                  if (playlist == null) return const SizedBox();
                  final tracksRaw = playlist.tracks.toTracks();

                  final remoteInfo = playlist.getRemoteInfo();
                  final tagsAndMoodsText = playlist.toTagsAndMoodsText();

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
                              child: NamidaText(
                                playlist.name.translatePlaylistName(),
                                style: NText.medium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            NamidaHero(
                              enabled: enableHero,
                              tag: 'line2_$hero',
                              child: NamidaText(
                                [
                                  tracksRaw.displayTrackKeyword,
                                  if (extraText?.isNotEmpty == true) extraText,
                                ].join(' • '),
                                style: const NText(.small, size: .s13p7),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (tagsAndMoodsText.isNotEmpty)
                              NamidaHero(
                                enabled: enableHero,
                                tag: 'line3_$hero',
                                child: Row(
                                  children: [
                                    PlaylistTagsColorDots(
                                      filter: PlaylistController.inst.tagsFilter,
                                      tags: playlist.tags,
                                      trailingGap: 4.0,
                                    ),
                                    Flexible(
                                      child: NamidaText(
                                        tagsAndMoodsText,
                                        style: NText.small,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      if (checkmarkStatus != null) ...[
                        NamidaCheckMark(
                          size: 14.0,
                          active: checkmarkStatus!,
                        ),
                        const SizedBox(width: 6.0),
                      ],
                      NamidaText(
                        tracksRaw.totalDurationFormatted,
                        style: const NText(.small, weight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 4.0),
                      if (playlist.isPinned) ...[
                        NamidaTooltip(
                          message: () => lang.pinned,
                          child: const Icon(
                            Broken.paperclip,
                            size: 18.0,
                          ),
                        ),
                        const SizedBox(
                          width: 2.0,
                        ),
                      ],
                      if (playlist.m3uPath != null) ...[
                        NamidaTooltip(
                          message: () => "${lang.m3uPlaylist}\n${playlist.m3uPath?.formatPath()}",
                          child: const Icon(Broken.music_filter, size: 18.0),
                        ),
                        const SizedBox(width: 2.0),
                      ] else if (remoteInfo != null) ...[
                        NamidaTooltip(
                          message: () => "${lang.readOnlyPlaylist}\n${remoteInfo.$1}",
                          child: remoteInfo.$2 != null
                              ? Image.asset(
                                  remoteInfo.$2!,
                                  height: 16.0,
                                )
                              : const Icon(
                                  Broken.cloud,
                                  size: 18.0,
                                ),
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
  final Decoration Function(NColorsData colors) decoration;
  final Widget child;

  const _PreferAnimatedDecoratedBox({
    required this.duration,
    required this.decoration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (duration == Duration.zero) return child;
    final colors = NColorsData.targetOf(context);
    return AnimatedDecoration(
      decoration: decoration(colors),
      duration: duration,
      child: child,
    );
  }
}
