import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/track_popup_dialog.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final bool displayRightDragHandler;
  final bool draggableThumbnail;
  final bool isInSelectedTracksPreview;
  TrackTile({
    super.key,
    required this.track,
    this.displayRightDragHandler = false,
    this.draggableThumbnail = true,
    this.isInSelectedTracksPreview = false,
  });

  String getChoosenTrackTileItem(TrackTileItem trackItem) {
    final formatDate = DateFormat('${SettingsController.inst.dateTimeFormat}');
    final formatClock = SettingsController.inst.hourFormat12.value ? DateFormat('hh:mm aa') : DateFormat('HH:mm');

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
      if (trackItem == TrackTileItem.dateModified) track.dateModified.dateFormatted,
      if (trackItem == TrackTileItem.dateModifiedClock) formatClock.format(DateTime.fromMillisecondsSinceEpoch(track.dateModified)),
      if (trackItem == TrackTileItem.dateModifiedDate) formatDate.format(DateTime.fromMillisecondsSinceEpoch(track.dateModified)),
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
        double thumnailSize = SettingsController.inst.trackThumbnailSizeinList.value;
        double trackTileHeight = SettingsController.inst.trackListTileHeight.value;
        bool isTrackCurrentlyPlaying = CurrentColor.inst.currentPlayingTrackPath.value == track.path;
        bool isTrackSelected = SelectedTracksController.inst.selectedTracks.contains(track);
        final textColor = isTrackCurrentlyPlaying ? Colors.white : null;
        return Container(
          margin: const EdgeInsets.only(bottom: 4.0),
          child: Material(
            color: Color.alphaBlend(
              isTrackSelected & !isInSelectedTracksPreview ? context.theme.selectedRowColor : Colors.transparent,
              isTrackCurrentlyPlaying ? CurrentColor.inst.color.value : context.theme.cardTheme.color!,
            ),
            child: InkWell(
              highlightColor: const Color.fromARGB(60, 0, 0, 0),
              key: ValueKey(track),
              onLongPress: () {
                if (!isInSelectedTracksPreview) {
                  SelectedTracksController.inst.selectOrUnselect(track);
                }
              },
              onTap: () async {
                if (SelectedTracksController.inst.selectedTracks.isNotEmpty && !isInSelectedTracksPreview) {
                  SelectedTracksController.inst.selectOrUnselect(track);
                } else {
                  Player.inst.play(track);
                  print(track.path);
                }
                await WaveformController.inst.generateWaveform(track);
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
                      children: [
                        Container(
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
                          ),
                        ),
                        if (draggableThumbnail)
                          ReorderableDragStartListener(
                            index: 0,
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
                          if (SettingsController.inst.row1Item1.value != TrackTileItem.none || SettingsController.inst.row1Item2.value != TrackTileItem.none || SettingsController.inst.row1Item3.value != TrackTileItem.none)
                            Text(
                              joinTrackItems(SettingsController.inst.row1Item1.value, SettingsController.inst.row1Item2.value, SettingsController.inst.row1Item3.value),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: context.textTheme.displayMedium!.copyWith(
                                // fontSize: Configuration.instance.trackListTileHeight * 0.2,
                                color: textColor?.withAlpha(170),
                              ),
                            ),

                          // check if second row isnt empty
                          if (SettingsController.inst.row2Item1.value != TrackTileItem.none || SettingsController.inst.row2Item2.value != TrackTileItem.none || SettingsController.inst.row2Item3.value != TrackTileItem.none)
                            Text(
                              joinTrackItems(SettingsController.inst.row2Item1.value, SettingsController.inst.row2Item2.value, SettingsController.inst.row2Item3.value),
                              style: Get.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: textColor?.withAlpha(140),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          // check if third row isnt empty
                          if (SettingsController.inst.displayThirdRow.value && SettingsController.inst.row3Item1.value != TrackTileItem.none || SettingsController.inst.row3Item2.value != TrackTileItem.none || SettingsController.inst.row3Item3.value != TrackTileItem.none)
                            Text(
                              joinTrackItems(SettingsController.inst.row3Item1.value, SettingsController.inst.row3Item2.value, SettingsController.inst.row3Item3.value),
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
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (SettingsController.inst.rightItem1.value != TrackTileItem.none || SettingsController.inst.rightItem2.value != TrackTileItem.none || SettingsController.inst.rightItem3.value != TrackTileItem.none)
                          if (SettingsController.inst.rightItem1.value != TrackTileItem.none)
                            Text(
                              getChoosenTrackTileItem(SettingsController.inst.rightItem1.value),
                              style: Get.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: textColor?.withAlpha(160),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        if (SettingsController.inst.rightItem2.value != TrackTileItem.none)
                          Text(
                            getChoosenTrackTileItem(SettingsController.inst.rightItem2.value),
                            style: Get.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: textColor?.withAlpha(160),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        // if (SettingsController.inst.rightItem3.value != TrackTileItem.none)
                        //   Text(
                        //     getChoosenTrackTileItem(SettingsController.inst.rightItem3.value),
                        //     style: Get.textTheme.displaySmall?.copyWith(
                        //       fontWeight: FontWeight.w500,
                        //       color: textColor?.withAlpha(160),
                        //     ),
                        //     overflow: TextOverflow.ellipsis,
                        //   ),
                      ],
                    ),
                    if (displayRightDragHandler) ...[
                      const SizedBox(
                        width: 8.0,
                      ),
                      ReorderableDragStartListener(
                        index: 0,
                        child: FittedBox(
                          child: Icon(
                            Broken.menu_1,
                            color: Get.textTheme.displayMedium?.color,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(
                      width: 2.0,
                    ),
                    MoreIcon(
                      padding: 6.0,
                      onPressed: () => showTrackDialog(track),
                    ),
                    const SizedBox(
                      width: 4.0,
                    ),
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
