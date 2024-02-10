import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:namida/class/track.dart';

import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

class PlaylistTile extends StatelessWidget {
  final String playlistName;
  final void Function()? onTap;

  const PlaylistTile({
    super.key,
    required this.playlistName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hero = 'playlist_$playlistName';
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.tileBottomMargin),
      child: NamidaInkWell(
        borderRadius: 0.0,
        onTap: onTap,
        onLongPress: () => NamidaDialogs.inst.showPlaylistDialog(playlistName),
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: SizedBox(
          height: Dimensions.playlistTileItemExtent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Dimensions.tileVerticalPadding),
            child: Obx(
              () {
                final playlist = PlaylistController.inst.getPlaylist(playlistName);
                if (playlist == null) return const SizedBox();
                final tracksRaw = playlist.tracks.toTracks();

                return Row(
                  children: [
                    MultiArtworkContainer(
                      heroTag: hero,
                      size: Dimensions.playlistThumbnailSize,
                      tracks: tracksRaw.toImageTracks(),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NamidaHero(
                            tag: 'line1_$hero',
                            child: Text(
                              playlist.name.translatePlaylistName(),
                              style: context.textTheme.displayMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          NamidaHero(
                            tag: 'line2_$hero',
                            child: Text(
                              [tracksRaw.displayTrackKeyword, playlist.creationDate.dateFormatted].join(' • '),
                              style: context.textTheme.displaySmall?.copyWith(fontSize: 13.7.multipliedFontScale),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (playlist.moods.isNotEmpty)
                            NamidaHero(
                              tag: 'line3_$hero',
                              child: Text(
                                playlist.moods.join(', ').overflow,
                                style: context.textTheme.displaySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Text(
                      tracksRaw.totalDurationFormatted,
                      style: context.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 2.0),
                    if (playlist.m3uPath != null) ...[
                      Tooltip(
                        message: "${lang.M3U_PLAYLIST}\n${playlist.m3uPath?.formatPath()}",
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
    );
  }
}
