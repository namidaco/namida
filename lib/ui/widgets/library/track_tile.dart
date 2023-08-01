import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/trackitem.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/track_info_dialog.dart';

class TrackTile extends StatelessWidget {
  final int index;
  final Selectable trackOrTwd;
  final bool displayRightDragHandler;
  final bool draggableThumbnail;
  final Color? bgColor;
  final Widget? trailingWidget;
  final void Function()? onTap;
  final String? playlistName;
  final String thirdLineText;
  final bool displayTrackNumber;

  /// Disable if you want to have priority to hold & reorder instead of selecting.
  final bool selectable;
  final QueueSource queueSource;
  final void Function()? onRightAreaTap;

  const TrackTile({
    super.key,
    required this.trackOrTwd,
    this.displayRightDragHandler = false,
    this.draggableThumbnail = true,
    this.bgColor,
    this.onTap,
    this.trailingWidget,
    this.playlistName,
    required this.index,
    this.thirdLineText = '',
    this.displayTrackNumber = false,
    this.selectable = true,
    required this.queueSource,
    this.onRightAreaTap,
  });

  bool get _isFromQueue => queueSource == QueueSource.playerQueue;

  Track get _tr => trackOrTwd.track;
  TrackWithDate? get _twd => trackOrTwd.trackWithDate;

  void _triggerTrackDialog() => NamidaDialogs.inst.showTrackDialog(
        _tr,
        playlistName: playlistName,
        index: index,
        comingFromQueue: _isFromQueue,
        trackWithDate: trackOrTwd.trackWithDate,
      );

  void _triggerTrackInfoDialog() => showTrackInfoDialog(_tr, true, comingFromQueue: _isFromQueue, index: index);

  void _selectTrack() => SelectedTracksController.inst.selectOrUnselect(trackOrTwd, queueSource, playlistName);

  @override
  Widget build(BuildContext context) {
    final track = _tr;
    final trackWithDate = _twd;
    final comingFromQueue = _isFromQueue;
    final canHaveDuplicates = comingFromQueue ||
        queueSource == QueueSource.playlist ||
        queueSource == QueueSource.queuePage ||
        queueSource == QueueSource.playerQueue ||
        queueSource == QueueSource.history;
    final isInSelectedTracksPreview = queueSource == QueueSource.selectedTracks;

    final willSleepAfterThis = queueSource == QueueSource.playerQueue && Player.inst.isSleepingTrack(index);

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        Obx(
          () {
            final TrackItem tritem = SettingsController.inst.trackItem.value;
            final double thumbnailSize = SettingsController.inst.trackThumbnailSizeinList.value;
            final double trackTileHeight = SettingsController.inst.trackListTileHeight.value;
            final bool isTrackSelected = SelectedTracksController.inst.isTrackSelected(trackOrTwd);
            final bool isTrackSame = track == CurrentColor.inst.currentPlayingTrack.value?.track;
            final bool isRightHistoryList = queueSource == QueueSource.history ? trackWithDate == CurrentColor.inst.currentPlayingTrack.value?.trackWithDate : true;
            final bool isRightIndex = canHaveDuplicates ? index == CurrentColor.inst.currentPlayingIndex.value : true;
            final bool isTrackCurrentlyPlaying = isRightIndex && isTrackSame && isRightHistoryList;

            final textColor = isTrackCurrentlyPlaying && !isTrackSelected ? Colors.white : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: Dimensions.tileBottomMargin),
              child: NamidaInkWell(
                borderRadius: 0.0,
                bgColor: bgColor ??
                    Color.alphaBlend(
                      isTrackSelected & !isInSelectedTracksPreview ? context.theme.focusColor : Colors.transparent,
                      isTrackCurrentlyPlaying ? CurrentColor.inst.color : context.theme.cardTheme.color!,
                    ),
                onTap: onTap ??
                    () async {
                      if (SelectedTracksController.inst.selectedTracks.isNotEmpty && !isInSelectedTracksPreview) {
                        _selectTrack();
                      } else {
                        if (queueSource == QueueSource.search) {
                          ScrollSearchController.inst.unfocusKeyboard();
                          await Player.inst.playOrPause(
                            SettingsController.inst.trackPlayMode.value.shouldBeIndex0 ? 0 : index,
                            SettingsController.inst.trackPlayMode.value.getQueue(track),
                            queueSource,
                          );
                        } else {
                          await Player.inst.playOrPause(
                            index,
                            queueSource.toTracks(null, trackWithDate?.dateAdded.toDaysSinceEpoch()),
                            queueSource,
                          );
                        }
                      }
                    },
                onLongPress: !selectable || onTap != null
                    ? null
                    : () {
                        if (!isInSelectedTracksPreview) {
                          _selectTrack();
                        }
                      },
                child: SizedBox(
                  height: Dimensions.inst.trackTileItemExtent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Dimensions.tileVerticalPadding),
                    child: Row(
                      children: [
                        const SizedBox(width: 12.0),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedScale(
                              duration: const Duration(milliseconds: 400),
                              scale: isTrackCurrentlyPlaying ? 0.96 : 1.0,
                              curve: Curves.easeInOut,
                              child: SizedBox(
                                width: thumbnailSize,
                                height: thumbnailSize,
                                child: NamidaHero(
                                  tag: '$comingFromQueue${index}_sussydialogs_${track.path}',
                                  child: ArtworkWidget(
                                    key: Key(trackOrTwd.hashCode.toString()),
                                    track: track,
                                    thumbnailSize: thumbnailSize,
                                    path: track.pathToImage,
                                    forceSquared: SettingsController.inst.forceSquaredTrackThumbnail.value,
                                    useTrackTileCacheHeight: true,
                                    onTopWidgets: [
                                      if (displayTrackNumber)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: NamidaBlurryContainer(
                                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                                            borderRadius: BorderRadius.only(topLeft: Radius.circular(4.0.multipliedRadius)),
                                            child: Text(
                                              (track.trackNo).toString(),
                                              style: context.textTheme.displaySmall,
                                            ),
                                          ),
                                        ),
                                      if (willSleepAfterThis)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2.0),
                                            decoration: BoxDecoration(
                                              color: context.theme.colorScheme.background.withAlpha(160),
                                              borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                                            ),
                                            child: const Icon(
                                              Broken.timer_1,
                                              size: 16.0,
                                            ),
                                          ),
                                        )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (draggableThumbnail)
                              NamidaReordererableListener(
                                durationMs: 80,
                                isInQueue: queueSource == QueueSource.playerQueue,
                                index: index,
                                child: Container(
                                  color: Colors.transparent,
                                  height: trackTileHeight,
                                  width: thumbnailSize,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // check if first row isnt empty
                              if (tritem.row1Item1 != TrackTileItem.none || tritem.row1Item2 != TrackTileItem.none || tritem.row1Item3 != TrackTileItem.none)
                                Text(
                                  _joinTrackItems(tritem.row1Item1, tritem.row1Item2, tritem.row1Item3, track),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: context.textTheme.displayMedium!.copyWith(
                                    color: textColor?.withAlpha(170),
                                  ),
                                ),

                              // check if second row isnt empty
                              if (tritem.row2Item1 != TrackTileItem.none || tritem.row2Item2 != TrackTileItem.none || tritem.row2Item3 != TrackTileItem.none)
                                Text(
                                  _joinTrackItems(tritem.row2Item1, tritem.row2Item2, tritem.row2Item3, track),
                                  style: context.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: textColor?.withAlpha(140),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                              // check if third row isnt empty
                              if (thirdLineText == '' && SettingsController.inst.displayThirdRow.value)
                                if (tritem.row3Item1 != TrackTileItem.none || tritem.row3Item2 != TrackTileItem.none || tritem.row3Item3 != TrackTileItem.none)
                                  Text(
                                    _joinTrackItems(tritem.row3Item1, tritem.row3Item2, tritem.row3Item3, track),
                                    style: context.textTheme.displaySmall?.copyWith(
                                      color: textColor?.withAlpha(130),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                              if (thirdLineText != '')
                                Text(
                                  thirdLineText,
                                  style: context.textTheme.displaySmall?.copyWith(color: textColor?.withAlpha(130)),
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
                                  _getChoosenTrackTileItem(tritem.rightItem1, track),
                                  style: context.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: textColor?.withAlpha(170),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (tritem.rightItem2 != TrackTileItem.none)
                                Text(
                                  _getChoosenTrackTileItem(tritem.rightItem2, track),
                                  style: context.textTheme.displaySmall?.copyWith(
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
                          const SizedBox(width: 8.0),
                          NamidaReordererableListener(
                            durationMs: 20,
                            isInQueue: queueSource == QueueSource.playerQueue,
                            index: index,
                            child: FittedBox(
                              child: Icon(
                                Broken.menu_1,
                                color: textColor?.withAlpha(160),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 2.0),
                        MoreIcon(
                          padding: 6.0,
                          iconColor: textColor?.withAlpha(160),
                          onPressed: _triggerTrackDialog,
                          onLongPress: _triggerTrackInfoDialog,
                        ),
                        if (trailingWidget == null) const SizedBox(width: 4.0),
                        if (trailingWidget != null) ...[
                          trailingWidget!,
                          const SizedBox(width: 10.0),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        GestureDetector(
          onTap: onRightAreaTap ?? _triggerTrackDialog,
          onLongPress: _triggerTrackInfoDialog,
          child: Container(
            width: 36.0,
            color: Colors.transparent,
          ),
        )
      ],
    );
  }
}

String _getChoosenTrackTileItem(TrackTileItem trackItem, Track trackPre) {
  final track = trackPre.toTrackExt();
  final finalDate = track.dateModified.dateFormatted;
  final finalClock = track.dateModified.clockFormatted;
  final trackItemPlaceV = [
    if (trackItem == TrackTileItem.none) '',
    if (trackItem == TrackTileItem.title) track.title.overflow,
    if (trackItem == TrackTileItem.artists) track.originalArtist.overflow,
    if (trackItem == TrackTileItem.album) track.album.overflow,
    if (trackItem == TrackTileItem.albumArtist) track.albumArtist.overflow,
    if (trackItem == TrackTileItem.genres) track.genresList.take(4).join(', ').overflow,
    if (trackItem == TrackTileItem.duration) track.duration.secondsLabel,
    if (trackItem == TrackTileItem.year) track.year.yearFormatted,
    if (trackItem == TrackTileItem.trackNumber) track.trackNo,
    if (trackItem == TrackTileItem.discNumber) track.discNo,
    if (trackItem == TrackTileItem.fileNameWOExt) trackPre.filenameWOExt.overflow,
    if (trackItem == TrackTileItem.extension) trackPre.extension,
    if (trackItem == TrackTileItem.fileName) trackPre.filename.overflow,
    if (trackItem == TrackTileItem.folder) trackPre.folderName.overflow,
    if (trackItem == TrackTileItem.path) track.path.formatPath(),
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

    /// stats
    if (trackItem == TrackTileItem.rating) "${track.stats.rating}%",
    if (trackItem == TrackTileItem.moods) track.stats.moods.join(', '),
    if (trackItem == TrackTileItem.tags) track.stats.tags.join(', '),
  ].join('');

  return trackItemPlaceV;
}

String _joinTrackItems(TrackTileItem? trackItem1, TrackTileItem? trackItem2, TrackTileItem? trackItem3, Track track) {
  final i1 = _getChoosenTrackTileItem(trackItem1 ?? TrackTileItem.none, track);
  final i2 = _getChoosenTrackTileItem(trackItem2 ?? TrackTileItem.none, track);
  final i3 = _getChoosenTrackTileItem(trackItem3 ?? TrackTileItem.none, track);
  return [
    if (i1 != '') i1,
    if (i2 != '') i2,
    if (i3 != '' && SettingsController.inst.displayThirdItemInEachRow.value) i3,
  ].join(' ${SettingsController.inst.trackTileSeparator} ');
}
