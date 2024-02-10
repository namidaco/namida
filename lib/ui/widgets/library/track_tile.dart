import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
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
  final VoidCallback? onTap;
  final VoidCallback? onPlaying;
  final String? playlistName;
  final String thirdLineText;
  final bool displayTrackNumber;

  /// Disable if you want to have priority to hold & reorder instead of selecting.
  final bool selectable;
  final QueueSource queueSource;
  final void Function()? onRightAreaTap;
  final double cardColorOpacity;
  final double fadeOpacity;

  const TrackTile({
    super.key,
    required this.trackOrTwd,
    this.displayRightDragHandler = false,
    this.draggableThumbnail = true,
    this.bgColor,
    this.onTap,
    this.onPlaying,
    this.trailingWidget,
    this.playlistName,
    required this.index,
    this.thirdLineText = '',
    this.displayTrackNumber = false,
    this.selectable = true,
    required this.queueSource,
    this.onRightAreaTap,
    this.cardColorOpacity = 0.9,
    this.fadeOpacity = 0.0,
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
        source: queueSource,
        additionalHero: additionalHero,
      );

  void _triggerTrackInfoDialog() => showTrackInfoDialog(
        _tr,
        true,
        comingFromQueue: _isFromQueue,
        index: index,
        queueSource: queueSource,
        additionalHero: additionalHero,
      );

  void _selectTrack() => SelectedTracksController.inst.selectOrUnselect(trackOrTwd, queueSource, playlistName);

  String? get additionalHero => trackOrTwd.trackWithDate?.dateAdded.toString();

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
    final additionalHero = this.additionalHero;
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        Obx(
          () {
            final willSleepAfterThis = queueSource == QueueSource.playerQueue && Player.inst.enableSleepAfterTracks && Player.inst.sleepingTrackIndex == index;

            final double thumbnailSize = settings.trackThumbnailSizeinList.value;
            final double trackTileHeight = settings.trackListTileHeight.value;
            final bool isTrackSelected = SelectedTracksController.inst.isTrackSelected(trackOrTwd);
            final bool isTrackSame = track == CurrentColor.inst.currentPlayingTrack.value?.track;
            final bool isRightHistoryList = queueSource == QueueSource.history ? trackWithDate == CurrentColor.inst.currentPlayingTrack.value?.trackWithDate : true;
            final bool isRightIndex = canHaveDuplicates ? index == CurrentColor.inst.currentPlayingIndex.value : true;
            final bool isTrackCurrentlyPlaying = isRightIndex && isTrackSame && isRightHistoryList;

            final textColor = isTrackCurrentlyPlaying && !isTrackSelected ? Colors.white : null;
            final row1Text = TrackTileManager.joinTrackItems(TrackTilePosition.row1Item1, TrackTilePosition.row1Item2, TrackTilePosition.row1Item3, track);
            final row2Text = TrackTileManager.joinTrackItems(TrackTilePosition.row2Item1, TrackTilePosition.row2Item2, TrackTilePosition.row2Item3, track);
            final row3Text = TrackTileManager.joinTrackItems(TrackTilePosition.row3Item1, TrackTilePosition.row3Item2, TrackTilePosition.row3Item3, track);
            final rightItem1Text = TrackTileManager.getChoosenTrackTileItem(TrackTilePosition.rightItem1, track);
            final rightItem2Text = TrackTileManager.getChoosenTrackTileItem(TrackTilePosition.rightItem2, track);

            final backgroundColor = bgColor ??
                Color.alphaBlend(
                  isTrackSelected & !isInSelectedTracksPreview ? context.theme.focusColor : Colors.transparent,
                  isTrackCurrentlyPlaying
                      ? comingFromQueue
                          ? CurrentColor.inst.miniplayerColor
                          : CurrentColor.inst.color
                      : context.theme.cardTheme.color!.withOpacity(cardColorOpacity),
                );

            return Padding(
              padding: const EdgeInsets.only(bottom: Dimensions.tileBottomMargin),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap ??
                      () async {
                        if (SelectedTracksController.inst.selectedTracks.isNotEmpty && !isInSelectedTracksPreview) {
                          _selectTrack();
                        } else {
                          if (onPlaying != null) {
                            onPlaying!();
                            return;
                          }
                          if (queueSource == QueueSource.search) {
                            ScrollSearchController.inst.unfocusKeyboard();
                            await Player.inst.playOrPause(
                              settings.trackPlayMode.value.shouldBeIndex0 ? 0 : index,
                              settings.trackPlayMode.value.getQueue(track),
                              queueSource,
                            );
                          } else {
                            await Player.inst.playOrPause(
                              index,
                              queueSource.toTracks(null, trackWithDate?.dateAdded.toDaysSince1970()),
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
                  child: ColoredBox(
                    color: backgroundColor,
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
                                      tag: '$comingFromQueue${index}_sussydialogs_${track.path}$additionalHero',
                                      child: ArtworkWidget(
                                        key: Key("$willSleepAfterThis${trackOrTwd.hashCode}"),
                                        track: track,
                                        thumbnailSize: thumbnailSize,
                                        path: track.pathToImage,
                                        forceSquared: settings.forceSquaredTrackThumbnail.value,
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
                              child: trackOrTwd.track.toTrackExtOrNull() == null
                                  ? Text(
                                      trackOrTwd.track.path,
                                      style: context.textTheme.displaySmall,
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // check if first row isnt empty
                                        if (row1Text != '')
                                          Text(
                                            row1Text,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: context.textTheme.displayMedium!.copyWith(
                                              color: textColor?.withAlpha(170),
                                            ),
                                          ),

                                        // check if second row isnt empty
                                        if (row2Text != '')
                                          Text(
                                            row2Text,
                                            style: context.textTheme.displaySmall?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: textColor?.withAlpha(140),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),

                                        // check if third row isnt empty
                                        if (thirdLineText == '' && settings.displayThirdRow.value)
                                          if (row3Text != '')
                                            Text(
                                              row3Text,
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
                            if (settings.displayFavouriteIconInListTile.value || rightItem1Text != '' || rightItem2Text != '')
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (rightItem1Text != '')
                                    Text(
                                      rightItem1Text,
                                      style: context.textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: textColor?.withAlpha(170),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (rightItem2Text != '')
                                    Text(
                                      rightItem2Text,
                                      style: context.textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: textColor?.withAlpha(170),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (settings.displayFavouriteIconInListTile.value)
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
                ),
              ),
            );
          },
        ),
        if (fadeOpacity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: context.theme.scaffoldBackgroundColor.withOpacity(fadeOpacity),
              ),
            ),
          ),
        GestureDetector(
          onTap: onRightAreaTap ?? _triggerTrackDialog,
          onLongPress: _triggerTrackInfoDialog,
          child: Container(
            width: 36.0,
            color: Colors.transparent,
          ),
        ),
      ],
    );
  }
}

class TrackTileManager {
  static final _infoMap = <Track, Map<TrackTilePosition, String>>{};

  static void onTrackItemPropChange() => _infoMap.clear();

  static String joinTrackItems(TrackTilePosition? p1, TrackTilePosition? p2, TrackTilePosition? p3, Track track) {
    final i1 = getChoosenTrackTileItem(p1, track);
    final i2 = getChoosenTrackTileItem(p2, track);
    final i3 = settings.displayThirdItemInEachRow.value ? getChoosenTrackTileItem(p3, track) : '';
    return [
      if (i1 != '') i1,
      if (i2 != '') i2,
      if (i3 != '') i3,
    ].join(' ${settings.trackTileSeparator} ');
  }

  static String getChoosenTrackTileItem(TrackTilePosition? itemPosition, Track trackPre) {
    if (itemPosition == null) return '';
    final inf = _infoMap[trackPre]?[itemPosition];
    if (_infoMap[trackPre]?[itemPosition] != null) return inf!;

    final trackItem = settings.trackItem[itemPosition] ?? TrackTileItem.none;

    final val = _getTrackItemValue(trackItem, trackPre);

    _infoMap[trackPre] ??= {};
    _infoMap[trackPre]![itemPosition] = val;

    return val;
  }

  static String _getTrackItemValue(TrackTileItem trackItem, Track trackPre) {
    final track = trackPre.toTrackExt();
    final finalDate = track.dateModified.dateFormatted;
    final finalClock = track.dateModified.clockFormatted;
    switch (trackItem) {
      case TrackTileItem.title:
        return track.title.overflow;
      case TrackTileItem.artists:
        return track.originalArtist.overflow;
      case TrackTileItem.album:
        return track.album.overflow;
      case TrackTileItem.albumArtist:
        return track.albumArtist.overflow;
      case TrackTileItem.genres:
        return track.genresList.take(4).join(', ').overflow;
      case TrackTileItem.duration:
        return track.duration.secondsLabel;
      case TrackTileItem.year:
        return track.year.yearFormatted;
      case TrackTileItem.trackNumber:
        return track.trackNo.toString();
      case TrackTileItem.discNumber:
        return track.discNo.toString();
      case TrackTileItem.fileNameWOExt:
        return trackPre.filenameWOExt.overflow;
      case TrackTileItem.extension:
        return trackPre.extension;
      case TrackTileItem.fileName:
        return trackPre.filename.overflow;
      case TrackTileItem.folder:
        return trackPre.folderName.overflow;
      case TrackTileItem.path:
        return track.path.formatPath();
      case TrackTileItem.channels:
        return track.channels.channelToLabel ?? '';
      case TrackTileItem.comment:
        return track.comment.overflow;
      case TrackTileItem.composer:
        return track.composer.overflow;
      case TrackTileItem.dateAdded:
        return track.dateAdded.dateFormatted;
      case TrackTileItem.format:
        return track.format;
      case TrackTileItem.sampleRate:
        return '${track.sampleRate}Hz';
      case TrackTileItem.size:
        return track.size.fileSizeFormatted;
      case TrackTileItem.bitrate:
        return "${(track.bitrate)} kps";
      case TrackTileItem.dateModified:
        return '$finalDate, $finalClock';
      case TrackTileItem.dateModifiedClock:
        return finalClock;
      case TrackTileItem.dateModifiedDate:
        return finalDate;
      // -- stats
      case TrackTileItem.rating:
        return "${track.stats.rating}%";
      case TrackTileItem.moods:
        return track.stats.moods.join(', ');
      case TrackTileItem.tags:
        return track.stats.tags.join(', ');
      default:
        return '';
    }
  }
}
