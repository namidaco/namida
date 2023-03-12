import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/trackitem.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/common_dialogs.dart';

import 'package:namida/main.dart';

class TrackTile extends StatelessWidget {
  final int index;
  final Track track;
  final List<Track> queue;
  final bool displayRightDragHandler;
  final bool draggableThumbnail;
  final bool isInSelectedTracksPreview;
  final Color? bgColor;
  final Widget? trailingWidget;
  final void Function()? onTap;
  final Playlist? playlist;
  const TrackTile({
    super.key,
    required this.track,
    required this.queue,
    this.displayRightDragHandler = false,
    this.draggableThumbnail = true,
    this.isInSelectedTracksPreview = false,
    this.bgColor,
    this.onTap,
    this.trailingWidget,
    this.playlist,
    required this.index,
  });

  String getChoosenTrackTileItem(TrackTileItem trackItem) {
    final finalDate = track.dateModified.dateFormatted;
    final finalClock = track.dateModified.clockFormatted;
    String trackItemPlaceV = [
      if (trackItem == TrackTileItem.none) '',
      if (trackItem == TrackTileItem.title) track.title.overflow,
      if (trackItem == TrackTileItem.artists) track.artistsList.take(4).join(', ').overflow,
      if (trackItem == TrackTileItem.album) track.album.overflow,
      if (trackItem == TrackTileItem.albumArtist) track.albumArtist.overflow,
      if (trackItem == TrackTileItem.genres) track.genresList.take(4).join(', ').overflow,
      if (trackItem == TrackTileItem.duration) track.duration.milliseconds.label,
      if (trackItem == TrackTileItem.year) track.year.yearFormatted,
      if (trackItem == TrackTileItem.trackNumber) track.track,
      if (trackItem == TrackTileItem.discNumber) track.discNo,
      if (trackItem == TrackTileItem.fileNameWOExt) track.displayNameWOExt.overflow,
      if (trackItem == TrackTileItem.extension) track.fileExtension,
      if (trackItem == TrackTileItem.fileName) track.displayName.overflow,
      if (trackItem == TrackTileItem.folder) track.folderPath.split('/').last.overflow,
      if (trackItem == TrackTileItem.path) track.path.formatPath,
      if (trackItem == TrackTileItem.channels) track.channels.channelToLabel,
      if (trackItem == TrackTileItem.comment) track.comment.overflow,
      if (trackItem == TrackTileItem.composer) track.composer.overflow,
      if (trackItem == TrackTileItem.dateAdded) track.dateAdded.dateFormatted,
      if (trackItem == TrackTileItem.format) track.format,
      if (trackItem == TrackTileItem.sampleRate) '${track.sampleRate}Hz',
      if (trackItem == TrackTileItem.size) track.size.fileSizeFormatted,
      if (trackItem == TrackTileItem.bitrate) "${(track.bitrate)} kps",
      if (trackItem == TrackTileItem.dateModified) '$finalDate, $finalClock',
      if (trackItem == TrackTileItem.dateModifiedClock) finalClock,
      if (trackItem == TrackTileItem.dateModifiedDate) finalDate,
    ].join('');

    return trackItemPlaceV;
  }

  String joinTrackItems(TrackTileItem? trackItem1, TrackTileItem? trackItem2, TrackTileItem? trackItem3) {
    final i1 = getChoosenTrackTileItem(trackItem1 ?? TrackTileItem.none);
    final i2 = getChoosenTrackTileItem(trackItem2 ?? TrackTileItem.none);
    final i3 = getChoosenTrackTileItem(trackItem3 ?? TrackTileItem.none);
    return [
      if (i1 != '') i1,
      if (i2 != '') i2,
      if (i3 != '' && SettingsController.inst.displayThirdItemInEachRow.value) i3,
    ].join(' ${SettingsController.inst.trackTileSeparator} ');
  }

  @override
  Widget build(BuildContext context) {
    context.theme;

    return Obx(
      () {
        final TrackItem tritem = SettingsController.inst.trackItem.value;
        final double thumnailSize = SettingsController.inst.trackThumbnailSizeinList.value;
        final double trackTileHeight = SettingsController.inst.trackListTileHeight.value;
        final bool isTrackSelected = SelectedTracksController.inst.selectedTracks.contains(track);
        bool isTrackSamePath = CurrentColor.inst.currentPlayingTrackPath.value == track.path;
        bool isRightIndex = index == CurrentColor.inst.currentPlayingIndex.value;
        bool isTrackCurrentlyPlaying = isRightIndex && isTrackSamePath;

        final textColor = isTrackCurrentlyPlaying && !isTrackSelected ? Colors.white : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Material(
            color: bgColor ??
                Color.alphaBlend(
                  isTrackSelected & !isInSelectedTracksPreview ? context.theme.selectedRowColor : Colors.transparent,
                  isTrackCurrentlyPlaying ? CurrentColor.inst.color.value : context.theme.cardTheme.color!,
                ),
            child: InkWell(
              highlightColor: const Color.fromARGB(60, 0, 0, 0),
              key: ValueKey(track),
              onLongPress: onTap != null
                  ? null
                  : () {
                      if (!isInSelectedTracksPreview) {
                        SelectedTracksController.inst.selectOrUnselect(track);
                      }
                    },
              onTap: onTap ??
                  () {
                    if (SelectedTracksController.inst.selectedTracks.isNotEmpty && !isInSelectedTracksPreview) {
                      SelectedTracksController.inst.selectOrUnselect(track);
                    } else {
                      Player.inst.playOrPause(index, track, queue: queue);
                      debugPrint(track.path);
                    }
                  },
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                height: trackTileHeight + 4.0 + 4.0,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12.0,
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedScale(
                          duration: const Duration(milliseconds: 400),
                          scale: isTrackCurrentlyPlaying ? 0.94 : 0.97,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 0.0,
                            ),
                            width: thumnailSize,
                            height: thumnailSize,
                            child: ArtworkWidget(
                              blur: 1.5,
                              thumnailSize: thumnailSize,
                              track: track,
                              forceSquared: SettingsController.inst.forceSquaredTrackThumbnail.value,
                              cacheHeight: SettingsController.inst.trackThumbnailSizeinList.value.toInt(),
                            ),
                          ),
                        ),
                        if (draggableThumbnail)
                          CustomReorderableDelayedDragStartListener(
                            index: index,
                            child: Container(
                              color: Colors.transparent,
                              height: trackTileHeight,
                              width: thumnailSize,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(
                      width: 12.0,
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // check if first row isnt empty
                          if (tritem.row1Item1 != TrackTileItem.none || tritem.row1Item2 != TrackTileItem.none || tritem.row1Item3 != TrackTileItem.none)
                            Text(
                              joinTrackItems(tritem.row1Item1, tritem.row1Item2, tritem.row1Item3),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: context.textTheme.displayMedium!.copyWith(
                                color: textColor?.withAlpha(170),
                              ),
                            ),

                          // check if second row isnt empty
                          if (tritem.row2Item1 != TrackTileItem.none || tritem.row2Item2 != TrackTileItem.none || tritem.row2Item3 != TrackTileItem.none)
                            Text(
                              joinTrackItems(tritem.row2Item1, tritem.row2Item2, tritem.row2Item3),
                              style: Get.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: textColor?.withAlpha(140),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                          // check if third row isnt empty
                          if (SettingsController.inst.displayThirdRow.value)
                            if (tritem.row3Item1 != TrackTileItem.none || tritem.row3Item2 != TrackTileItem.none || tritem.row3Item3 != TrackTileItem.none)
                              Text(
                                joinTrackItems(tritem.row3Item1, tritem.row3Item2, tritem.row3Item3),
                                style: Get.textTheme.displaySmall?.copyWith(
                                  color: textColor?.withAlpha(130),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    if (SettingsController.inst.displayFavouriteIconInListTile.value || tritem.rightItem1 != TrackTileItem.none || tritem.rightItem2 != TrackTileItem.none)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (tritem.rightItem1 != TrackTileItem.none)
                            Text(
                              getChoosenTrackTileItem(tritem.rightItem1),
                              style: Get.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: textColor?.withAlpha(170),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (tritem.rightItem2 != TrackTileItem.none)
                            Text(
                              getChoosenTrackTileItem(tritem.rightItem2),
                              style: Get.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: textColor?.withAlpha(170),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (SettingsController.inst.displayFavouriteIconInListTile.value)
                            NamidaLikeButton(
                              track: track,
                              size: 22.0,
                              color: textColor?.withAlpha(140) ?? context.textTheme.displayMedium?.color?.withAlpha(140),
                            ),
                        ],
                      ),
                    if (displayRightDragHandler) ...[
                      const SizedBox(
                        width: 8.0,
                      ),
                      CustomReorderableDelayedDragStartListener(
                        index: index,
                        child: FittedBox(
                          child: Icon(
                            Broken.menu_1,
                            color: textColor?.withAlpha(160),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(
                      width: 2.0,
                    ),
                    MoreIcon(
                      padding: 6.0,
                      iconColor: textColor?.withAlpha(160),
                      onPressed: () => NamidaDialogs.inst.showTrackDialog(track, playlist: playlist),
                    ),
                    if (trailingWidget == null)
                      const SizedBox(
                        width: 4.0,
                      ),
                    if (trailingWidget != null) ...[
                      trailingWidget!,
                      const SizedBox(
                        width: 10.0,
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
