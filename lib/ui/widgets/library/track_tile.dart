import 'package:flutter/material.dart';

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
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/track_info_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class TrackTilePropertiesProvider extends StatelessWidget {
  final TrackTilePropertiesConfigs configs;
  final Widget Function(TrackTileProperties properties) builder;

  const TrackTilePropertiesProvider({
    super.key,
    required this.builder,
    required this.configs,
  });

  @override
  Widget build(BuildContext context) {
    var queueSource = configs.queueSource;
    final comingFromQueue = queueSource == QueueSource.playerQueue;
    final canHaveDuplicates = comingFromQueue ||
        queueSource == QueueSource.playlist ||
        queueSource == QueueSource.queuePage ||
        queueSource == QueueSource.playerQueue ||
        queueSource == QueueSource.history;

    final backgroundColorNotPlaying = context.theme.cardTheme.color ?? Colors.transparent;
    final selectionColorLayer = context.theme.focusColor;

    return ObxO(
      rx: settings.forceSquaredTrackThumbnail,
      builder: (forceSquaredThumbnails) => ObxO(
        rx: settings.displayThirdRow,
        builder: (displayThirdRow) => ObxO(
          rx: settings.displayFavouriteIconInListTile,
          builder: (displayFavouriteIconInListTile) => ObxO(
            rx: settings.trackThumbnailSizeinList,
            builder: (thumbnailSize) => ObxO(
              rx: settings.trackListTileHeight,
              builder: (trackTileHeight) => ObxO(
                rx: SelectedTracksController.inst.existingTracksMap,
                builder: (selectedTracksMap) => ObxO(
                  rx: CurrentColor.inst.currentPlayingTrack,
                  builder: (currentPlayingTrack) => ObxO(
                    rx: CurrentColor.inst.currentPlayingIndex,
                    builder: (currentPlayingIndex) => Obx(
                      () {
                        int? sleepingIndex;
                        if (queueSource == QueueSource.playerQueue) {
                          final sleepconfig = Player.inst.sleepTimerConfig.valueR;
                          if (sleepconfig.enableSleepAfterItems) sleepingIndex = Player.inst.sleepingItemIndex(sleepconfig.sleepAfterItems, Player.inst.currentIndex.valueR);
                        }

                        final backgroundColorPlaying = comingFromQueue ? CurrentColor.inst.miniplayerColor : CurrentColor.inst.currentColorScheme;

                        final properties = TrackTileProperties(
                          backgroundColorPlaying: backgroundColorPlaying,
                          backgroundColorNotPlaying: backgroundColorNotPlaying,
                          selectionColorLayer: selectionColorLayer,
                          thumbnailSize: thumbnailSize,
                          trackTileHeight: trackTileHeight,
                          forceSquaredThumbnails: forceSquaredThumbnails,
                          sleepingIndex: sleepingIndex,
                          displayThirdRow: displayThirdRow,
                          displayFavouriteIconInListTile: displayFavouriteIconInListTile,
                          comingFromQueue: comingFromQueue,
                          configs: configs,
                          canHaveDuplicates: canHaveDuplicates,
                          currentPlayingTrack: currentPlayingTrack,
                          currentPlayingIndex: currentPlayingIndex,
                          isTrackSelected: (trOrTwd) => selectedTracksMap[trOrTwd.track] != null,
                        );
                        return builder(properties);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TrackTilePropertiesConfigs {
  final QueueSource queueSource;

  /// Disable if you want to have priority to hold & reorder instead of selecting.
  final bool Function()? selectable;
  final bool draggableThumbnail;
  final bool displayRightDragHandler;
  final bool displayTrackNumber;
  final String? playlistName;

  const TrackTilePropertiesConfigs({
    required this.queueSource,
    this.selectable,
    this.draggableThumbnail = true,
    this.displayRightDragHandler = false,
    this.displayTrackNumber = false,
    this.playlistName,
  });
}

class TrackTileProperties {
  final TrackTilePropertiesConfigs configs;
  final Color backgroundColorPlaying;
  final Color backgroundColorNotPlaying;
  final Color selectionColorLayer;

  final double thumbnailSize;
  final double trackTileHeight;
  final bool forceSquaredThumbnails;
  final int? sleepingIndex;
  final bool displayThirdRow;
  final bool displayFavouriteIconInListTile;
  final bool comingFromQueue;
  final bool canHaveDuplicates;
  final Selectable? currentPlayingTrack;
  final int? currentPlayingIndex;
  final Function(Selectable trOrTwd) isTrackSelected;

  const TrackTileProperties({
    required this.configs,
    required this.backgroundColorPlaying,
    required this.backgroundColorNotPlaying,
    required this.selectionColorLayer,
    required this.thumbnailSize,
    required this.trackTileHeight,
    required this.forceSquaredThumbnails,
    required this.sleepingIndex,
    required this.displayThirdRow,
    required this.displayFavouriteIconInListTile,
    required this.comingFromQueue,
    required this.canHaveDuplicates,
    required this.currentPlayingTrack,
    required this.currentPlayingIndex,
    required this.isTrackSelected,
  });
}

class TrackTile extends StatelessWidget {
  final int index;
  final Selectable trackOrTwd;
  final TrackTileProperties properties;
  final VoidCallback? onTap;
  final VoidCallback? onPlaying;

  final Color? bgColor;
  final double cardColorOpacity;
  final double fadeOpacity;
  final void Function()? onRightAreaTap;
  final Widget? trailingWidget;
  final String? thirdLineText;

  const TrackTile({
    super.key,
    required this.properties,
    required this.trackOrTwd,
    this.onTap,
    this.onPlaying,
    required this.index,
    this.bgColor,
    this.cardColorOpacity = 0.9,
    this.fadeOpacity = 0.0,
    this.onRightAreaTap,
    this.trailingWidget,
    this.thirdLineText,
  });

  Track get _tr => trackOrTwd.track;
  TrackWithDate? get _twd => trackOrTwd.trackWithDate;
  bool get _isFromQueue => properties.configs.queueSource == QueueSource.playerQueue;

  void _triggerTrackDialog() => NamidaDialogs.inst.showTrackDialog(
        _tr,
        playlistName: properties.configs.playlistName,
        index: index,
        comingFromQueue: _isFromQueue,
        trackWithDate: trackOrTwd.trackWithDate,
        source: properties.configs.queueSource,
        additionalHero: additionalHero,
      );

  void _triggerTrackInfoDialog() => showTrackInfoDialog(
        _tr,
        true,
        comingFromQueue: _isFromQueue,
        index: index,
        queueSource: properties.configs.queueSource,
        additionalHero: additionalHero,
      );

  void _selectTrack() => SelectedTracksController.inst.selectOrUnselect(trackOrTwd, properties.configs.queueSource, properties.configs.playlistName);

  String? get additionalHero => trackOrTwd.trackWithDate?.dateAdded.toString();

  @override
  Widget build(BuildContext context) {
    final queueSource = properties.configs.queueSource;
    final track = _tr;
    final trackWithDate = _twd;
    final isInSelectedTracksPreview = queueSource == QueueSource.selectedTracks;
    final additionalHero = this.additionalHero;
    final thirdLineText = this.thirdLineText;
    final row1Text = TrackTileManager.joinTrackItems(TrackTilePosition.row1Item1, TrackTilePosition.row1Item2, TrackTilePosition.row1Item3, track);
    final row2Text = TrackTileManager.joinTrackItems(TrackTilePosition.row2Item1, TrackTilePosition.row2Item2, TrackTilePosition.row2Item3, track);
    final row3Text = thirdLineText != null && thirdLineText.isNotEmpty
        ? thirdLineText
        : properties.displayThirdRow
            ? TrackTileManager.joinTrackItems(TrackTilePosition.row3Item1, TrackTilePosition.row3Item2, TrackTilePosition.row3Item3, track)
            : null;
    final rightItem1Text = TrackTileManager.getChoosenTrackTileItem(TrackTilePosition.rightItem1, track);
    final rightItem2Text = TrackTileManager.getChoosenTrackTileItem(TrackTilePosition.rightItem2, track);

    final willSleepAfterThis = properties.sleepingIndex == index;

    final bool isTrackSelected = properties.isTrackSelected(trackOrTwd);
    final bool isTrackSame = track == properties.currentPlayingTrack?.track;
    final bool isRightHistoryList = queueSource == QueueSource.history ? trackWithDate == properties.currentPlayingTrack?.trackWithDate : true;
    final bool isRightIndex = properties.canHaveDuplicates ? index == properties.currentPlayingIndex : true;
    final bool isTrackCurrentlyPlaying = isRightIndex && isTrackSame && isRightHistoryList;

    final textColor = isTrackCurrentlyPlaying && !isTrackSelected ? Colors.white : null;

    Color backgroundColor;
    if (bgColor != null) {
      backgroundColor = bgColor!;
    } else {
      backgroundColor = isTrackCurrentlyPlaying ? properties.backgroundColorPlaying : properties.backgroundColorNotPlaying.withOpacity(cardColorOpacity);
      if (isTrackSelected && queueSource != QueueSource.selectedTracks) {
        backgroundColor = Color.alphaBlend(
          properties.selectionColorLayer,
          backgroundColor,
        );
      }
    }

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Dimensions.tileBottomMargin),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap ??
                  () async {
                    if (SelectedTracksController.inst.selectedTracks.value.isNotEmpty && !isInSelectedTracksPreview) {
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
                          settings.trackPlayMode.value.generateQueue(track),
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
              onLongPress: onTap != null
                  ? null
                  : () {
                      var selectable = properties.configs.selectable;
                      if (selectable != null && selectable() == false) return;
                      if (isInSelectedTracksPreview) return;

                      ScrollSearchController.inst.unfocusKeyboard();
                      _selectTrack();
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
                                width: properties.thumbnailSize,
                                height: properties.thumbnailSize,
                                child: NamidaHero(
                                  tag: '${properties.comingFromQueue}${index}_sussydialogs_${track.path}$additionalHero',
                                  child: ArtworkWidget(
                                    key: Key("$willSleepAfterThis${trackOrTwd.hashCode}"),
                                    track: track,
                                    thumbnailSize: properties.thumbnailSize,
                                    path: track.pathToImage,
                                    forceSquared: properties.forceSquaredThumbnails,
                                    useTrackTileCacheHeight: true,
                                    onTopWidgets: [
                                      if (properties.configs.displayTrackNumber)
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
                                              color: context.theme.colorScheme.surface.withAlpha(160),
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
                            if (properties.configs.draggableThumbnail)
                              NamidaReordererableListener(
                                durationMs: 80,
                                index: index,
                                child: Container(
                                  color: Colors.transparent,
                                  height: properties.trackTileHeight,
                                  width: properties.thumbnailSize,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: trackOrTwd.track.toTrackExtOrNull() == null
                              ? Text(
                                  trackOrTwd.track.path,
                                  style: context.textTheme.displaySmall?.copyWith(
                                    color: textColor?.withAlpha(170),
                                  ),
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
                                    if (row3Text != null && row3Text != '')
                                      Text(
                                        row3Text,
                                        style: context.textTheme.displaySmall?.copyWith(
                                          color: textColor?.withAlpha(130),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(width: 6.0),
                        if (properties.displayFavouriteIconInListTile || rightItem1Text != '' || rightItem2Text != '')
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
                              if (properties.displayFavouriteIconInListTile)
                                NamidaLocalLikeButton(
                                  track: track,
                                  size: 22.0,
                                  color: textColor?.withAlpha(140) ?? context.textTheme.displayMedium?.color?.withAlpha(140),
                                ),
                            ],
                          ),
                        if (properties.configs.displayRightDragHandler) ...[
                          const SizedBox(width: 8.0),
                          NamidaReordererableListener(
                            durationMs: 20,
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
                        if (trailingWidget == null)
                          const SizedBox(width: 4.0)
                        else ...[
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

  static void onTrackItemPropChange() {
    _infoMap.clear();
    _separator = _buildSeparator();
  }

  static String _separator = _buildSeparator();
  static String _buildSeparator() => ' ${settings.trackTileSeparator.value} ';

  static String joinTrackItems(TrackTilePosition? p1, TrackTilePosition? p2, TrackTilePosition? p3, Track track) {
    var buffer = StringBuffer();
    bool needsSeparator = false;
    if (p1 != null) {
      var info = getChoosenTrackTileItem(p1, track);
      if (info.isNotEmpty) {
        buffer.write(info);
        needsSeparator = true;
      }
    }
    if (p2 != null) {
      var info = getChoosenTrackTileItem(p2, track);
      if (info.isNotEmpty) {
        if (needsSeparator) buffer.write(_separator);
        buffer.write(info);
        needsSeparator = true;
      }
    }
    if (p3 != null && settings.displayThirdItemInEachRow.value) {
      var info = getChoosenTrackTileItem(p3, track);
      if (info.isNotEmpty) {
        if (needsSeparator) buffer.write(_separator);
        buffer.write(info);
        needsSeparator = true;
      }
    }
    return buffer.toString();
  }

  static String getChoosenTrackTileItem(TrackTilePosition itemPosition, Track trackPre) {
    final inf = _infoMap[trackPre]?[itemPosition];
    if (inf != null) return inf;

    String val;

    final trackItem = settings.trackItem.value[itemPosition];
    if (trackItem == null || trackItem == TrackTileItem.none) {
      val = '';
    } else {
      final fn = _lookup[trackItem];
      if (fn != null) {
        final track = trackPre.toTrackExt();
        val = fn(track);
      } else {
        val = '';
      }
    }

    _infoMap[trackPre] ??= {};
    _infoMap[trackPre]![itemPosition] = val;

    return val;
  }

  static final _lookup = <TrackTileItem, String Function(TrackExtended track)>{
    TrackTileItem.title: (track) => track.title.overflow,
    TrackTileItem.artists: (track) => track.originalArtist.overflow,
    TrackTileItem.album: (track) => track.album.overflow,
    TrackTileItem.albumArtist: (track) => track.albumArtist.overflow,
    TrackTileItem.genres: (track) => track.originalGenre.overflow,
    TrackTileItem.duration: (track) => track.duration.secondsLabel,
    TrackTileItem.year: (track) => track.year.yearFormatted,
    TrackTileItem.trackNumber: (track) => track.trackNo.toString(),
    TrackTileItem.discNumber: (track) => track.discNo.toString(),
    TrackTileItem.fileNameWOExt: (track) => track.filenameWOExt.overflow,
    TrackTileItem.extension: (track) => track.extension,
    TrackTileItem.fileName: (track) => track.filename.overflow,
    TrackTileItem.folder: (track) => track.folderName.overflow,
    TrackTileItem.path: (track) => track.path.formatPath(),
    TrackTileItem.channels: (track) => track.channels.channelToLabel ?? '',
    TrackTileItem.comment: (track) => track.comment.overflow,
    TrackTileItem.composer: (track) => track.composer.overflow,
    TrackTileItem.dateAdded: (track) => track.dateAdded.dateFormatted,
    TrackTileItem.format: (track) => track.format,
    TrackTileItem.sampleRate: (track) => '${track.sampleRate}Hz',
    TrackTileItem.size: (track) => track.size.fileSizeFormatted,
    TrackTileItem.bitrate: (track) => "${(track.bitrate)} kps",
    TrackTileItem.dateModified: (track) {
      final finalDate = track.dateModified.dateFormatted;
      final finalClock = track.dateModified.clockFormatted;
      return '$finalDate, $finalClock';
    },
    TrackTileItem.dateModifiedClock: (track) {
      final finalClock = track.dateModified.clockFormatted;
      return finalClock;
    },
    TrackTileItem.dateModifiedDate: (track) {
      final finalDate = track.dateModified.dateFormatted;
      return finalDate;
    },
    // -- stats
    TrackTileItem.rating: (track) => "${track.stats.rating}%",
    TrackTileItem.moods: (track) => track.stats.moods.join(', '),
    TrackTileItem.tags: (track) => track.stats.tags.join(', '),
  };
}
