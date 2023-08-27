import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:known_extents_list_view_builder/sliver_known_extents_list.dart';
import 'package:sticky_headers/sticky_headers.dart';

import 'package:namida/class/date_range.dart';
import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
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
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class HistoryTracksPage extends StatelessWidget {
  const HistoryTracksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sc = HistoryController.inst.scrollController;

    return BackgroundWrapper(
      child: CustomScrollView(
        controller: sc,
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
                    paths: historyTracks.toImagePaths(),
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
                itemExtents: Dimensions.inst.allItemsExtentsHistory,
                delegate: SliverChildBuilderDelegate(
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
                          height: Dimensions.inst.allItemsExtentsHistory[index],
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
                  childCount: HistoryController.inst.historyDays.length,
                ),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: kBottomPadding)),
        ],
      ),
    );
  }
}

class MostPlayedTracksPage extends StatelessWidget {
  const MostPlayedTracksPage({super.key});

  void _onSelectingTimeRange({
    required MostPlayedTimeRange? mptr,
    DateRange? dateCustom,
    bool? isStartOfDay,
  }) {
    SettingsController.inst.save(
      mostPlayedTimeRange: mptr,
      mostPlayedCustomDateRange: dateCustom,
      mostPlayedCustomisStartOfDay: isStartOfDay,
    );
    HistoryController.inst.updateTempMostPlayedPlaylist(
      mptr: mptr,
      customDateRange: dateCustom,
      isStartOfDay: isStartOfDay,
    );
    NamidaNavigator.inst.closeDialog();
  }

  bool _isEnabled(MostPlayedTimeRange type) => type == SettingsController.inst.mostPlayedTimeRange.value;

  Widget _getChipChild({
    required BuildContext context,
    DateRange? dateCustom,
    required MostPlayedTimeRange mptr,
    Widget? Function(Color? textColor)? trailing,
  }) {
    final dateText = dateCustom == null || dateCustom == DateRange.dummy()
        ? null
        : "${dateCustom.oldest.millisecondsSinceEpoch.dateFormattedOriginalNoYears(dateCustom.newest)} → ${dateCustom.newest.millisecondsSinceEpoch.dateFormattedOriginalNoYears(dateCustom.oldest)}";

    final textColor = _isEnabled(mptr) ? const Color.fromARGB(200, 255, 255, 255) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: GestureDetector(
        onTap: () => _onSelectingTimeRange(
          dateCustom: dateCustom,
          mptr: mptr,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: _isEnabled(mptr) ? CurrentColor.inst.currentColorScheme.withAlpha(160) : context.theme.cardColor,
            borderRadius: BorderRadius.circular(8.0.multipliedRadius),
          ),
          child: Row(
            children: [
              Text(
                dateText ?? mptr.toText(),
                style: context.textTheme.displaySmall?.copyWith(
                  color: textColor,
                  fontSize: dateText == null ? null : 12.0.multipliedFontScale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (trailing != null) trailing(textColor)!,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Obx(
        () {
          final finalListenMap = HistoryController.inst.currentTopTracksMapListens;
          final tracks = QueueSource.mostPlayed.toTracks();
          final mostplayedOptions = List<MostPlayedTimeRange>.from(MostPlayedTimeRange.values)..remove(MostPlayedTimeRange.custom);
          return NamidaListView(
            itemExtents: tracks.toTrackItemExtents(),
            header: SubpagesTopContainer(
              source: QueueSource.mostPlayed,
              title: k_PLAYLIST_NAME_MOST_PLAYED.translatePlaylistName(),
              subtitle: tracks.displayTrackKeyword,
              heroTag: 'playlist_$k_PLAYLIST_NAME_MOST_PLAYED',
              imageWidget: MultiArtworkContainer(
                heroTag: 'playlist_$k_PLAYLIST_NAME_MOST_PLAYED',
                size: Get.width * 0.35,
                paths: tracks.toImagePaths(),
              ),
              tracks: tracks,
              bottomPadding: 0.0,
              bottomWidget: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const SizedBox(width: 8.0),
                    NamidaInkWell(
                      animationDurationMS: 200,
                      borderRadius: 6.0,
                      bgColor: context.theme.cardTheme.color,
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        border: _isEnabled(MostPlayedTimeRange.custom) ? Border.all(color: CurrentColor.inst.color) : null,
                        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                      ),
                      child: Row(
                        children: [
                          const Icon(Broken.calendar, size: 18.0),
                          const SizedBox(width: 4.0),
                          Text(
                            'Custom',
                            style: context.textTheme.displayMedium,
                          ),
                          const SizedBox(width: 4.0),
                          const Icon(Broken.arrow_down_2, size: 14.0),
                        ],
                      ),
                      onTap: () {
                        showCalendarDialog(
                          title: Language.inst.CHOOSE,
                          buttonText: Language.inst.CONFIRM,
                          useHistoryDates: true,
                          onGenerate: (dates) => _onSelectingTimeRange(
                            dateCustom: DateRange(oldest: dates.first, newest: dates.last),
                            mptr: MostPlayedTimeRange.custom,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4.0),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Obx(
                              () {
                                final dateRange = SettingsController.inst.mostPlayedCustomDateRange.value;
                                return _getChipChild(
                                  context: context,
                                  mptr: MostPlayedTimeRange.custom,
                                  dateCustom: dateRange,
                                  trailing: (textColor) => NamidaIconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Broken.close_circle,
                                    iconSize: 14.0,
                                    iconColor: textColor,
                                    onPressed: () => _onSelectingTimeRange(mptr: MostPlayedTimeRange.allTime, dateCustom: DateRange.dummy()),
                                  ),
                                ).animateEntrance(
                                  showWhen: dateRange.oldest != DateTime(0),
                                  durationMS: 400,
                                  reverseDurationMS: 200,
                                );
                              },
                            ),
                            ...mostplayedOptions.map(
                              (action) => _getChipChild(
                                context: context,
                                mptr: action,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            padding: const EdgeInsets.only(bottom: kBottomPadding),
            itemCount: finalListenMap.length,
            itemBuilder: (context, i) {
              final track = tracks[i];
              final listens = finalListenMap[track] ?? [];

              return AnimatingTile(
                key: ValueKey(i),
                position: i,
                child: TrackTile(
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

class EmptyPlaylistSubpage extends StatelessWidget {
  final Playlist playlist;
  EmptyPlaylistSubpage({super.key, required this.playlist});

  final tracksToAddMap = <Track, bool>{}.obs;
  final isExpanded = false.obs;
  @override
  Widget build(BuildContext context) {
    final randomTracks = List<Track>.from(allTracksInLibrary.take(150));
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Obx(
            () => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: isExpanded.value ? context.height * 0.1 : context.height * 0.3,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.width * 0.15).add(const EdgeInsets.only(bottom: 8.0)),
          sliver: SliverToBoxAdapter(
            child: Theme(
              data: AppThemes.inst.getAppTheme(Colors.red, !context.isDarkMode),
              child: NamidaButton(
                icon: Broken.trash,
                onPressed: () => NamidaDialogs.inst.showDeletePlaylistDialog(playlist),
                text: Language.inst.DELETE_PLAYLIST,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.width * 0.1),
          sliver: SliverToBoxAdapter(
            child: NamidaExpansionTile(
              initiallyExpanded: isExpanded.value,
              titleText: Language.inst.ADD,
              icon: Broken.add_circle,
              onExpansionChanged: (value) => isExpanded.value = value,
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
                    text: '${Language.inst.ADD} ${trl.displayTrackKeyword}',
                    onPressed: () => PlaylistController.inst.addTracksToPlaylist(playlist, tracksToAddMap.keys.toList()),
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

class NormalPlaylistTracksPage extends StatelessWidget {
  final String playlistName;
  final bool disableAnimation;
  const NormalPlaylistTracksPage({super.key, required this.playlistName, this.disableAnimation = false});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Obx(
        () {
          PlaylistController.inst.playlistsMap.entries;
          final playlist = PlaylistController.inst.getPlaylist(playlistName);
          if (playlist == null) return const SizedBox();

          final tracksWithDate = playlist.tracks;
          if (tracksWithDate.isEmpty) return EmptyPlaylistSubpage(playlist: playlist);

          final tracks = tracksWithDate.toTracks();

          return NamidaListView(
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
                paths: tracks.toImagePaths(),
              ),
              tracks: tracks,
            ),
            padding: const EdgeInsets.only(bottom: kBottomPadding),
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
              if (disableAnimation) return SizedBox(key: Key(i.toString()), child: w);
              return AnimatingTile(key: ValueKey(i), position: i, child: w);
            },
          );
        },
      ),
    );
  }
}

class ThreeLineSmallContainers extends StatelessWidget {
  final bool enabled;
  const ThreeLineSmallContainers({Key? key, required this.enabled}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.filled(
        3,
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.bounceIn,
          width: enabled ? 9.0 : 2.0,
          height: 1.2,
          margin: const EdgeInsets.symmetric(vertical: 1),
          color: context.theme.listTileTheme.iconColor?.withAlpha(120),
        ),
      ),
    );
  }
}
