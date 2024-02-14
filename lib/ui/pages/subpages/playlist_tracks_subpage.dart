import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:known_extents_list_view_builder/sliver_known_extents_list.dart';
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

class _HistoryTracksPageState extends State<HistoryTracksPage> {
  @override
  void initState() {
    super.initState();
    HistoryController.inst.canUpdateAllItemsExtentsInHistory = true;
    HistoryController.inst.calculateAllItemsExtentsInHistory();
  }

  @override
  void dispose() {
    HistoryController.inst.canUpdateAllItemsExtentsInHistory = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: CustomScrollView(
        controller: HistoryController.inst.scrollController,
        slivers: [
          Obx(
            () {
              final historyTracks = QueueSource.history.toTracks();
              return SliverToBoxAdapter(
                child: SubpagesTopContainer(
                  source: QueueSource.history,
                  title: k_PLAYLIST_NAME_HISTORY.translatePlaylistName(),
                  subtitle: HistoryController.inst.historyTracksLength.displayTrackKeyword,
                  heroTag: 'playlist_$k_PLAYLIST_NAME_HISTORY',
                  tracks: historyTracks,
                  imageWidget: MultiArtworkContainer(
                    heroTag: 'playlist_$k_PLAYLIST_NAME_HISTORY',
                    size: Get.width * 0.35,
                    tracks: historyTracks.toImageTracks(),
                  ),
                  bottomPadding: 8.0,
                ),
              );
            },
          ),
          Obx(
            () {
              final days = HistoryController.inst.historyDays.toList();
              return SliverKnownExtentsList(
                key: UniqueKey(),
                itemExtents: HistoryController.inst.allItemsExtentsHistory,
                delegate: SliverChildBuilderDelegate(
                  childCount: HistoryController.inst.historyDays.length,
                  (context, index) {
                    final day = days[index];
                    final dayInMs = Duration(days: day).inMilliseconds;
                    final tracks = HistoryController.inst.historyMap.value[day] ?? [];

                    return StickyHeaderBuilder(
                      key: ValueKey(index),
                      builder: (context, stuckAmount) {
                        final reverseStuck = 1 - stuckAmount;
                        return Container(
                          clipBehavior: Clip.antiAlias,
                          width: context.width,
                          height: kHistoryDayHeaderHeight,
                          decoration: BoxDecoration(
                              color: Color.alphaBlend(context.theme.cardTheme.color!.withAlpha(140), context.theme.scaffoldBackgroundColor),
                              boxShadow: [
                                BoxShadow(
                                  offset: Offset(0, 2.0 * reverseStuck),
                                  blurRadius: 4.0,
                                  color:
                                      Color.alphaBlend(context.theme.shadowColor.withAlpha(140), context.theme.scaffoldBackgroundColor).withOpacity(reverseStuck.clamp(0.0, 0.4)),
                                ),
                              ],
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(6.0.multipliedRadius * reverseStuck),
                                bottomRight: Radius.circular(6.0.multipliedRadius * reverseStuck),
                              )),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12.0),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: CurrentColor.inst.color,
                                        width: (4.0 * stuckAmount).withMinimum(3.0),
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    [dayInMs.dateFormattedOriginal, tracks.length.displayTrackKeyword].join('  •  '),
                                    style: context.textTheme.displayMedium,
                                  ),
                                ),
                              ),
                              NamidaIconButton(
                                icon: Broken.more,
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
                              const SizedBox(width: 2.0),
                            ],
                          ),
                        );
                      },
                      content: Obx(
                        () => SizedBox(
                          height: HistoryController.inst.allItemsExtentsHistory[index],
                          width: context.width,
                          child: ListView.builder(
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
                                    ? context.theme.colorScheme.onBackground.withAlpha(40)
                                    : null,
                                draggableThumbnail: false,
                                playlistName: k_PLAYLIST_NAME_HISTORY,
                                thirdLineText: tr.dateAdded.dateAndClockFormattedOriginal,
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
    return Obx(
      () {
        final tracks = QueueSource.mostPlayed.toTracks();
        return MostPlayedItemsPage(
          itemExtents: tracks.toTrackItemExtents(),
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
                size: Get.width * 0.35,
                tracks: tracks.toImageTracks(),
              ),
              tracks: tracks,
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
  @override
  AnimationController get animation2 => _animation2;

  late final _animation2 = AnimationController(
    duration: const Duration(milliseconds: 1200),
    vsync: this,
  );

  late final _scrollController = ScrollController();
  late String? _playlistM3uPath = PlaylistController.inst.getPlaylist(widget.playlistName)?.m3uPath;

  @override
  void dispose() {
    _animation2.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  num get pullNormalizer => 100;

  @override
  Widget build(BuildContext context) {
    final child = Obx(
      () {
        PlaylistController.inst.playlistsMap.entries;
        final playlist = PlaylistController.inst.getPlaylist(widget.playlistName);
        if (playlist == null) return const SizedBox();
        _playlistM3uPath = playlist.m3uPath;

        final tracksWithDate = playlist.tracks;
        if (tracksWithDate.isEmpty) return EmptyPlaylistSubpage(playlist: playlist);

        final tracks = tracksWithDate.toTracks();

        return NamidaListViewRaw(
          scrollController: _scrollController,
          itemCount: tracks.length,
          itemExtents: tracks.toTrackItemExtents(),
          header: SubpagesTopContainer(
            source: playlist.toQueueSource(),
            title: playlist.name.translatePlaylistName(),
            subtitle: [tracks.displayTrackKeyword, playlist.creationDate.dateFormatted].join(' - '),
            thirdLineText: playlist.moods.isNotEmpty ? playlist.moods.join(', ') : '',
            heroTag: 'playlist_${playlist.name}',
            imageWidget: MultiArtworkContainer(
              heroTag: 'playlist_${playlist.name}',
              size: Get.width * 0.35,
              tracks: tracks.toImageTracks(),
            ),
            tracks: tracks,
          ),
          padding: kBottomPaddingInsets,
          onReorder: (oldIndex, newIndex) => PlaylistController.inst.reorderTrack(playlist, oldIndex, newIndex),
          itemBuilder: (context, i) {
            final trackWithDate = tracksWithDate[i];
            final w = Obx(
              () {
                final reorderable = PlaylistController.inst.canReorderTracks.value;
                return FadeDismissible(
                  key: Key("Diss_$i$trackWithDate"),
                  direction: reorderable ? DismissDirection.horizontal : DismissDirection.none,
                  onDismissed: (direction) => NamidaOnTaps.inst.onRemoveTracksFromPlaylist(playlist.name, [trackWithDate]),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      TrackTile(
                        index: i,
                        trackOrTwd: trackWithDate,
                        playlistName: playlist.name,
                        queueSource: playlist.toQueueSource(),
                        draggableThumbnail: reorderable,
                        selectable: !PlaylistController.inst.canReorderTracks.value,
                      ),
                      Obx(() => ThreeLineSmallContainers(enabled: PlaylistController.inst.canReorderTracks.value)),
                    ],
                  ),
                );
              },
            );
            if (widget.disableAnimation) return SizedBox(key: Key(i.toString()), child: w);
            return AnimatingTile(key: ValueKey(i), position: i, child: w);
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
    return BackgroundWrapper(
      child: _playlistM3uPath != null
          ? Listener(
              onPointerMove: (event) {
                if (!_scrollController.hasClients) return;
                final p = _scrollController.position.pixels;
                if (p <= 0 && event.delta.dx < 0.1) onVerticalDragUpdate(event.delta.dy);
              },
              onPointerUp: (event) async {
                final m3uPath = _playlistM3uPath;
                if (m3uPath != null && animation.value == 1) {
                  showRefreshingAnimation(() async {
                    await PlaylistController.inst.prepareM3UPlaylists(forPaths: {m3uPath});
                    PlaylistController.inst.sortPlaylists();
                  });
                }
                onVerticalDragFinish();
              },
              onPointerCancel: (event) => onVerticalDragFinish(),
              child: child,
            )
          : child,
    );
  }
}

class ThreeLineSmallContainers extends StatelessWidget {
  final bool enabled;
  final Color? color;
  const ThreeLineSmallContainers({Key? key, required this.enabled, this.color}) : super(key: key);

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
