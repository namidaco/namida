import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:history_manager/history_manager.dart';
import 'package:namida/base/history_days_rebuilder.dart';
import 'package:namida/core/utils.dart';
import 'package:sticky_headers/sticky_headers.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/general_popup_dialog.dart';
import 'package:namida/ui/dialogs/track_listens_dialog.dart';
import 'package:namida/ui/pages/subpages/most_played_subpage.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class HistoryTracksPage extends StatefulWidget {
  const HistoryTracksPage({super.key});

  @override
  State<HistoryTracksPage> createState() => _HistoryTracksPageState();
}

class _HistoryTracksPageState extends State<HistoryTracksPage> with HistoryDaysRebuilderMixin<HistoryTracksPage, TrackWithDate, Track> {
  @override
  HistoryManager<TrackWithDate, Track> get historyManager => HistoryController.inst;

  @override
  Widget build(BuildContext context) {
    final trackTileExtent = Dimensions.inst.trackTileItemExtent;
    const dayHeaderExtent = kHistoryDayHeaderHeightWithPadding;

    const dayHeaderHeight = kHistoryDayHeaderHeight;
    final dayHeaderBgColor = Color.alphaBlend(context.theme.cardTheme.color!.withAlpha(140), context.theme.scaffoldBackgroundColor);
    final dayHeaderSideColor = CurrentColor.inst.color;
    final dayHeaderShadowColor = Color.alphaBlend(context.theme.shadowColor.withAlpha(140), context.theme.scaffoldBackgroundColor).withOpacity(0.4);

    final daysLength = historyDays.length;

    return BackgroundWrapper(
      child: CustomScrollView(
        controller: HistoryController.inst.scrollController,
        slivers: [
          ObxO(
            rx: HistoryController.inst.totalHistoryItemsCount,
            builder: (totalHistoryItemsCount) {
              final lengthDummy = totalHistoryItemsCount == -1;
              return SliverToBoxAdapter(
                child: SubpagesTopContainer(
                  source: QueueSource.history,
                  title: k_PLAYLIST_NAME_HISTORY.translatePlaylistName(),
                  subtitle: lengthDummy ? '?' : totalHistoryItemsCount.displayTrackKeyword,
                  heroTag: 'playlist_$k_PLAYLIST_NAME_HISTORY',
                  tracksFn: () => HistoryController.inst.historyTracks,
                  imageWidget: ObxO(
                    rx: HistoryController.inst.historyMap,
                    builder: (historyMap) => MultiArtworkContainer(
                      heroTag: 'playlist_$k_PLAYLIST_NAME_HISTORY',
                      size: context.width * 0.35,
                      tracks: getHistoryTracks(historyMap).toImageTracks(),
                    ),
                  ),
                  bottomPadding: 8.0,
                ),
              );
            },
          ),
          ObxO(
            rx: HistoryController.inst.historyMap,
            builder: (history) {
              // -- refresh sublist when history change
              return SliverVariedExtentList.builder(
                key: ValueKey(daysLength), // rebuild after adding/removing day
                itemExtentBuilder: (index, dimensions) {
                  final day = historyDays[index];
                  return HistoryController.inst.dayToSectionExtent(day, trackTileExtent, dayHeaderExtent);
                },
                itemCount: daysLength,
                itemBuilder: (context, index) {
                  final day = historyDays[index];
                  final dayInMs = super.dayToMillis(day);
                  final tracks = history[day] ?? [];

                  return StickyHeader(
                    key: ValueKey(index),
                    header: NamidaHistoryDayHeaderBox(
                      height: dayHeaderHeight,
                      title: [
                        dayInMs.dateFormattedOriginal,
                        tracks.length.displayTrackKeyword,
                      ].join('  •  '),
                      sideColor: dayHeaderSideColor,
                      bgColor: dayHeaderBgColor,
                      shadowColor: dayHeaderShadowColor,
                      menu: NamidaIconButton(
                        icon: Broken.more,
                        horizontalPadding: 8.0,
                        iconSize: 22.0,
                        onPressed: () {
                          showGeneralPopupDialog(
                            tracks.toTracks(),
                            dayInMs.dateFormattedOriginal,
                            tracks.length.displayTrackKeyword,
                            QueueSource.history,
                            tracksWithDates: tracks,
                            playlistName: k_PLAYLIST_NAME_HISTORY,
                          );
                        },
                      ),
                    ),
                    content: ListView.builder(
                      padding: const EdgeInsets.only(bottom: kHistoryDayListBottomPadding, top: kHistoryDayListTopPadding),
                      primary: false,
                      itemExtent: Dimensions.inst.trackTileItemExtent,
                      itemCount: tracks.length,
                      itemBuilder: (context, i) {
                        final tr = tracks[i];
                        return TrackTile(
                          trackOrTwd: tr,
                          index: i,
                          queueSource: QueueSource.history,
                          bgColor: day == HistoryController.inst.dayOfHighLight.value && i == HistoryController.inst.indexToHighlight.value
                              ? context.theme.colorScheme.onSurface.withAlpha(40)
                              : null,
                          draggableThumbnail: false,
                          playlistName: k_PLAYLIST_NAME_HISTORY,
                          thirdLineText: tr.dateAdded.dateAndClockFormattedOriginal,
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          kBottomPaddingWidgetSliver,
        ],
      ),
    );
  }
}

class MostPlayedTracksPage extends StatelessWidget {
  const MostPlayedTracksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: Obx(
        () {
          final tracks = QueueSource.mostPlayed.toTracks();
          return MostPlayedItemsPage(
            itemExtent: Dimensions.inst.trackTileItemExtent,
            historyController: HistoryController.inst,
            customDateRange: settings.mostPlayedCustomDateRange,
            isTimeRangeChipEnabled: (type) => type == settings.mostPlayedTimeRange.value,
            onSavingTimeRange: ({dateCustom, isStartOfDay, mptr}) {
              settings.save(
                mostPlayedTimeRange: mptr,
                mostPlayedCustomDateRange: dateCustom,
                mostPlayedCustomisStartOfDay: isStartOfDay,
              );
            },
            header: (timeRangeChips, bottomPadding) {
              return SubpagesTopContainer(
                source: QueueSource.mostPlayed,
                title: k_PLAYLIST_NAME_MOST_PLAYED.translatePlaylistName(),
                subtitle: tracks.displayTrackKeyword,
                heroTag: 'playlist_$k_PLAYLIST_NAME_MOST_PLAYED',
                imageWidget: MultiArtworkContainer(
                  heroTag: 'playlist_$k_PLAYLIST_NAME_MOST_PLAYED',
                  size: context.width * 0.35,
                  tracks: tracks.toImageTracks(),
                ),
                tracksFn: () => HistoryController.inst.currentMostPlayedTracks,
                bottomPadding: bottomPadding,
                bottomWidget: timeRangeChips,
              );
            },
            itemBuilder: (context, i, listensMap) {
              final track = tracks[i];
              final listens = listensMap[track] ?? [];

              return AnimatingTile(
                key: Key("${track}_$i"),
                position: i,
                child: TrackTile(
                  key: Key("${track}_$i"),
                  draggableThumbnail: false,
                  index: i,
                  trackOrTwd: tracks[i],
                  queueSource: QueueSource.mostPlayed,
                  playlistName: k_PLAYLIST_NAME_MOST_PLAYED,
                  onRightAreaTap: () => showTrackListensDialog(track.track, datesOfListen: listens),
                  trailingWidget: Container(
                    padding: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(
                      color: context.theme.scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      listens.length.formatDecimal(),
                      style: context.textTheme.displaySmall,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class EmptyPlaylistSubpage extends StatefulWidget {
  final Playlist playlist;
  const EmptyPlaylistSubpage({super.key, required this.playlist});

  @override
  State<EmptyPlaylistSubpage> createState() => _EmptyPlaylistSubpageState();
}

class _EmptyPlaylistSubpageState extends State<EmptyPlaylistSubpage> {
  late List<Track> randomTracks;
  final tracksToAddMap = <Track, bool>{}.obs;
  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    randomTracks = List<Track>.from(allTracksInLibrary.take(150));
  }

  @override
  void dispose() {
    tracksToAddMap.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: isExpanded ? context.height * 0.1 : context.height * 0.3,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.width * 0.15).add(const EdgeInsets.only(bottom: 8.0)),
          sliver: SliverToBoxAdapter(
            child: Theme(
              data: AppThemes.inst.getAppTheme(Colors.red, !context.isDarkMode),
              child: NamidaButton(
                icon: Broken.trash,
                onPressed: () => NamidaDialogs.inst.showDeletePlaylistDialog(widget.playlist),
                text: lang.DELETE_PLAYLIST,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.width * 0.1),
          sliver: SliverToBoxAdapter(
            child: NamidaExpansionTile(
              initiallyExpanded: isExpanded,
              titleText: lang.ADD,
              icon: Broken.add_circle,
              onExpansionChanged: (value) => setState(() => isExpanded = value),
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  height: context.height * 0.5,
                  width: context.width,
                  decoration: BoxDecoration(
                    color: context.theme.cardColor,
                    borderRadius: BorderRadius.circular(18.0.multipliedRadius),
                  ),
                  child: ListView.builder(
                    itemExtent: Dimensions.inst.trackTileItemExtent,
                    itemCount: randomTracks.length,
                    itemBuilder: (context, i) {
                      final tr = randomTracks[i];
                      return TrackTile(
                        trackOrTwd: tr,
                        index: i,
                        queueSource: QueueSource.playlist,
                        onTap: () => tracksToAddMap[tr] = !(tracksToAddMap[tr] ?? false),
                        onRightAreaTap: () => tracksToAddMap[tr] = !(tracksToAddMap[tr] ?? false),
                        trailingWidget: Obx(
                          () => NamidaCheckMark(
                            size: 22.0,
                            active: tracksToAddMap[tr] == true,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(top: 12.0)),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.width * 0.2),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              height: 42.0,
              child: Obx(
                () {
                  final trl = tracksToAddMap.entries.where((element) => element.value).length;
                  return NamidaButton(
                    enabled: trl > 0,
                    icon: Broken.add,
                    text: '${lang.ADD} ${trl.displayTrackKeyword}',
                    onPressed: () => PlaylistController.inst.addTracksToPlaylist(widget.playlist, tracksToAddMap.keys.toList()),
                  );
                },
              ),
            ),
          ),
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: context.height * 0.2)),
      ],
    );
  }
}

class NormalPlaylistTracksPage extends StatefulWidget {
  final String playlistName;
  final bool disableAnimation;
  const NormalPlaylistTracksPage({super.key, required this.playlistName, this.disableAnimation = false});

  @override
  State<NormalPlaylistTracksPage> createState() => _NormalPlaylistTracksPageState();
}

class _NormalPlaylistTracksPageState extends State<NormalPlaylistTracksPage> with TickerProviderStateMixin, PullToRefreshMixin {
  late final _scrollController = ScrollController();
  late String? _playlistM3uPath = PlaylistController.inst.getPlaylist(widget.playlistName)?.m3uPath;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threeC = ObxO(
      rx: PlaylistController.inst.canReorderTracks,
      builder: (reorderable) => ThreeLineSmallContainers(enabled: reorderable),
    );
    final child = Obx(
      () {
        PlaylistController.inst.playlistsMap.valueR.entries;
        final playlist = PlaylistController.inst.getPlaylist(widget.playlistName);
        if (playlist == null) return const SizedBox();
        _playlistM3uPath = playlist.m3uPath;

        final tracksWithDate = playlist.tracks;
        if (tracksWithDate.isEmpty) return EmptyPlaylistSubpage(playlist: playlist);

        final tracks = tracksWithDate.toTracks();

        return NamidaListViewRaw(
          scrollController: _scrollController,
          itemCount: tracks.length,
          itemExtent: Dimensions.inst.trackTileItemExtent,
          header: SubpagesTopContainer(
            source: playlist.toQueueSource(),
            title: playlist.name.translatePlaylistName(),
            subtitle: [tracks.displayTrackKeyword, playlist.creationDate.dateFormatted].join(' - '),
            thirdLineText: playlist.moods.isNotEmpty ? playlist.moods.join(', ') : '',
            heroTag: 'playlist_${playlist.name}',
            imageWidget: MultiArtworkContainer(
              heroTag: 'playlist_${playlist.name}',
              size: context.width * 0.35,
              tracks: tracks.toImageTracks(),
            ),
            tracksFn: () => tracks,
          ),
          padding: kBottomPaddingInsets,
          onReorderStart: (index) => super.enablePullToRefresh = false,
          onReorderEnd: (index) => super.enablePullToRefresh = true,
          onReorder: (oldIndex, newIndex) => PlaylistController.inst.reorderTrack(playlist, oldIndex, newIndex),
          itemBuilder: (context, i) {
            final trackWithDate = tracksWithDate[i];

            return FadeDismissible(
              key: Key("Diss_$i$trackWithDate"),
              draggableRx: PlaylistController.inst.canReorderTracks,
              onDismissed: (direction) => NamidaOnTaps.inst.onRemoveTracksFromPlaylist(playlist.name, [trackWithDate]),
              onTopWidget: Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: threeC,
              ),
              child: ObxO(
                  rx: PlaylistController.inst.canReorderTracks,
                  builder: (reorderable) {
                    return AnimatingTile(
                      key: ValueKey(i),
                      position: i,
                      shouldAnimate: !(reorderable || widget.disableAnimation),
                      child: TrackTile(
                        index: i,
                        trackOrTwd: trackWithDate,
                        playlistName: playlist.name,
                        queueSource: playlist.toQueueSource(),
                        draggableThumbnail: reorderable,
                        selectable: () => !PlaylistController.inst.canReorderTracks.value,
                      ),
                    );
                  }),
            );
          },
          listBuilder: (list) {
            return Stack(
              children: [
                list,
                pullToRefreshWidget,
              ],
            );
          },
        );
      },
    );
    return AnimationLimiter(
      child: BackgroundWrapper(
        child: _playlistM3uPath != null
            ? Listener(
                onPointerMove: (event) {
                  onPointerMove(_scrollController, event);
                },
                onPointerUp: (event) async {
                  final m3uPath = _playlistM3uPath;
                  if (m3uPath != null) {
                    onRefresh(() async {
                      await PlaylistController.inst.prepareM3UPlaylists(forPaths: {m3uPath});
                      PlaylistController.inst.sortPlaylists();
                    });
                  } else {
                    onVerticalDragFinish();
                  }
                },
                onPointerCancel: (event) => onVerticalDragFinish(),
                child: child,
              )
            : child,
      ),
    );
  }
}

class ThreeLineSmallContainers extends StatelessWidget {
  final bool enabled;
  final Color? color;

  const ThreeLineSmallContainers({
    super.key,
    required this.enabled,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.filled(
        3,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: AnimatedSizedBox(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastEaseInToSlowEaseOut,
            width: enabled ? 9.0 : 2.0,
            height: 1.2,
            animateHeight: false,
            decoration: BoxDecoration(
              color: color ?? context.theme.listTileTheme.iconColor?.withAlpha(120),
            ),
          ),
        ),
      ),
    );
  }
}
