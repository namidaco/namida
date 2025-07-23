import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/count_per_row.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/setting_dialog_with_text_field.dart';
import 'package:namida/ui/pages/queues_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/multi_artwork_card.dart';
import 'package:namida/ui/widgets/library/playlist_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

/// By Default, sending tracks to add (i.e: addToPlaylistDialog) will:
/// 1. Hide Default Playlists.
/// 2. Hide Grid Widget.
/// 3. Disable bottom padding.
/// 4. Disable Scroll Controller.
class PlaylistsPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_playlists;

  final List<Track>? tracksToAdd;
  final CountPerRow countPerRow;
  final bool animateTiles;
  final bool enableHero;

  const PlaylistsPage({
    super.key,
    this.tracksToAdd,
    required this.countPerRow,
    this.animateTiles = true,
    required this.enableHero,
  });

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> with TickerProviderStateMixin, PullToRefreshMixin {
  bool get _shouldAnimate => widget.animateTiles && LibraryTab.playlists.shouldAnimateTiles;

  void _closeDialog() => NamidaNavigator.inst.closeDialog();

  Future<void> _importPlaylists({required bool keepSynced, required bool pickFolder}) async {
    Set<String> playlistsFilesPath;
    if (pickFolder) {
      final dirs = await NamidaFileBrowser.pickDirectories(note: "${lang.IMPORT} (${lang.FOLDERS})");
      playlistsFilesPath = {};
      for (final d in dirs) {
        final subfiles = await d.listAllIsolate(recursive: true);
        subfiles.loop(
          (f) {
            if (f is File) {
              var path = f.path;
              if (NamidaFileExtensionsWrapper.m3u.isPathValid(path)) {
                playlistsFilesPath.add(path);
              }
            }
          },
        );
      }
    } else {
      final playlistsFiles = await NamidaFileBrowser.pickFiles(note: lang.IMPORT, allowedExtensions: NamidaFileExtensionsWrapper.m3u);
      playlistsFilesPath = playlistsFiles.map((f) => f.path).toSet();
    }
    if (playlistsFilesPath.isNotEmpty) {
      final importedCount = await PlaylistController.inst.prepareM3UPlaylists(forPaths: playlistsFilesPath, addAsM3U: keepSynced);
      PlaylistController.inst.sortPlaylists();
      String countText;
      bool hadError;
      if (importedCount != null) {
        if (importedCount < playlistsFilesPath.length) {
          hadError = true;
          countText = '${importedCount.formatDecimal()}/${playlistsFilesPath.length.formatDecimal()}';
        } else {
          hadError = false;
          countText = importedCount.formatDecimal();
        }
        snackyy(
          message: lang.IMPORTED_N_PLAYLISTS_SUCCESSFULLY.replaceFirst(
            '_NUM_',
            countText,
          ),
          borderColor: (hadError ? Colors.orange : Colors.green).withValues(alpha: 0.6),
        );
      } else {
        snackyy(
          message: lang.ERROR,
          isError: true,
        );
      }
    }
  }

  void _onAddPlaylistsTap() {
    NamidaNavigator.inst.navigateDialog(
      dialogBuilder: (theme) => CustomBlurryDialog(
        theme: theme,
        normalTitleStyle: true,
        title: lang.CHOOSE,
        actions: const [
          CancelButton(),
        ],
        child: Column(
          children: [
            CustomListTile(
              visualDensity: VisualDensity.compact,
              icon: Broken.shuffle,
              title: lang.RANDOM,
              subtitle: lang.GENERATE_RANDOM_PLAYLIST,
              onTap: () {
                _closeDialog();
                final numbers = PlaylistController.inst.generateRandomPlaylist();
                if (numbers == 0) {
                  snackyy(title: lang.ERROR, message: lang.NO_ENOUGH_TRACKS);
                }
              },
            ),
            CustomListTile(
              visualDensity: VisualDensity.compact,
              icon: Broken.import_1,
              title: lang.IMPORT,
              subtitle: lang.PLAYLISTS_IMPORT_M3U_NATIVE,
              trailing: NamidaIconButton(
                tooltip: () => lang.FOLDER,
                icon: Broken.folder_2,
                onPressed: () {
                  _closeDialog();
                  _importPlaylists(keepSynced: false, pickFolder: true);
                },
              ),
              onTap: () async {
                _closeDialog();
                _importPlaylists(keepSynced: false, pickFolder: false);
              },
            ),
            CustomListTile(
              visualDensity: VisualDensity.compact,
              icon: Broken.add_circle,
              title: lang.CREATE,
              subtitle: lang.CREATE_NEW_PLAYLIST,
              onTap: () {
                _closeDialog();
                showSettingDialogWithTextField(
                  title: lang.CREATE_NEW_PLAYLIST,
                  addNewPlaylist: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onPlaylistButtonConfigTap() {
    NamidaNavigator.inst.navigateDialog(
      dialogBuilder: (theme) => CustomBlurryDialog(
        theme: theme,
        normalTitleStyle: true,
        title: lang.CONFIGURE,
        actions: const [
          CancelButton(),
        ],
        child: Column(
          children: [
            ObxO(
              rx: settings.enableM3USyncStartup,
              builder: (context, m3usyncstartup) => CustomSwitchListTile(
                visualDensity: VisualDensity.compact,
                leading: const StackedIcon(
                  baseIcon: Broken.music_library_2,
                  secondaryIcon: Broken.refresh_square_2,
                  secondaryIconSize: 12.0,
                ),
                title: lang.PLAYLISTS_IMPORT_M3U_SYNCED_AUTO_IMPORT,
                subtitle: lang.PLAYLISTS_IMPORT_M3U_SYNCED,
                onChanged: (isTrue) => settings.save(enableM3USyncStartup: !isTrue),
                value: m3usyncstartup,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onAddToPlaylist({required LocalPlaylist playlist, required bool allTracksExist, required bool allowAddingEverything}) {
    if (allTracksExist == true) {
      final indexes = <int>[];
      playlist.tracks.loopAdv((e, index) {
        if (widget.tracksToAdd!.contains(e.track)) {
          indexes.add(index);
        }
      });
      NamidaNavigator.inst.navigateDialog(
        dialog: CustomBlurryDialog(
          isWarning: true,
          normalTitleStyle: true,
          bodyText: "${lang.REMOVE_FROM_PLAYLIST} ${playlist.name.addDQuotation()}?",
          actions: [
            const CancelButton(),
            const SizedBox(width: 6.0),
            NamidaButton(
              text: lang.REMOVE.toUpperCase(),
              onPressed: () {
                NamidaNavigator.inst.closeDialog();
                PlaylistController.inst.removeTracksFromPlaylist(playlist, indexes);
              },
            )
          ],
        ),
      );
    } else {
      final duplicateActions = allowAddingEverything ? PlaylistAddDuplicateAction.valuesForAdd : PlaylistAddDuplicateAction.valuesForAddExcludingAddEverything;
      PlaylistController.inst.addTracksToPlaylist(
        playlist,
        widget.tracksToAdd!,
        duplicationActions: duplicateActions,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracksToAdd = widget.tracksToAdd;
    final isInsideDialog = tracksToAdd != null;
    final enableHero = !isInsideDialog;
    final scrollController = isInsideDialog ? null : LibraryTab.playlists.scrollController;
    final defaultCardHorizontalPadding = Dimensions.inst.availableAppContentWidth * 0.045;
    final defaultCardHorizontalPaddingCenter = Dimensions.inst.availableAppContentWidth * 0.035;
    final countPerRowResolved = widget.countPerRow.resolve(context);

    return BackgroundWrapper(
      child: Listener(
        onPointerMove: (event) {
          final c = scrollController;
          if (c != null) onPointerMove(c, event);
        },
        onPointerUp: (event) => onRefresh(PlaylistController.inst.prepareM3UPlaylists),
        onPointerCancel: (event) => onVerticalDragFinish(),
        child: NamidaScrollbar(
          controller: scrollController,
          child: AnimationLimiter(
            child: Column(
              children: [
                Obx(
                  (context) => ExpandableBox(
                    enableHero: widget.enableHero && enableHero,
                    gridWidget: isInsideDialog
                        ? null
                        : const ChangeGridCountWidget(
                            tab: LibraryTab.playlists,
                          ),
                    isBarVisible: LibraryTab.playlists.isBarVisible.valueR,
                    showSearchBox: LibraryTab.playlists.isSearchBoxVisible.valueR,
                    leftText: SearchSortController.inst.playlistSearchList.length.displayPlaylistKeyword,
                    onFilterIconTap: () => ScrollSearchController.inst.switchSearchBoxVisibilty(LibraryTab.playlists),
                    onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(LibraryTab.playlists),
                    sortByMenuWidget: SortByMenu(
                      title: settings.playlistSort.valueR.toText(),
                      popupMenuChild: () => const SortByMenuPlaylist(),
                      isCurrentlyReversed: settings.playlistSortReversed.valueR,
                      onReverseIconTap: () => SearchSortController.inst.sortMedia(MediaType.playlist, reverse: !settings.playlistSortReversed.value),
                    ),
                    textField: () => CustomTextFiled(
                      textFieldController: LibraryTab.playlists.textSearchController,
                      textFieldHintText: lang.FILTER_PLAYLISTS,
                      onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, MediaType.playlist),
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          if (!isInsideDialog)
                            SliverToBoxAdapter(
                              child: NamidaHero(
                                enabled: enableHero,
                                tag: 'PlaylistPage_TopRow',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      const SizedBox(width: 12.0),
                                      Expanded(
                                        child: ObxO(
                                          rx: PlaylistController.inst.playlistsMap,
                                          builder: (context, playlistsMap) => Text(
                                            playlistsMap.length.displayPlaylistKeyword,
                                            style: context.textTheme.displayLarge,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12.0),
                                      NamidaButton(
                                        icon: Broken.add,
                                        text: lang.ADD,
                                        onPressed: _onAddPlaylistsTap,
                                      ),
                                      const SizedBox(width: 8.0),
                                      NamidaButton(
                                        icon: Broken.setting_4,
                                        iconSize: 20.0,
                                        onPressed: _onPlaylistButtonConfigTap,
                                      ),
                                      const SizedBox(width: 8.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SliverPadding(padding: EdgeInsets.only(top: 6.0)),

                          /// Default Playlists.
                          if (!isInsideDialog)
                            SliverToBoxAdapter(
                              child: SizedBox(
                                width: context.width,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(height: defaultCardHorizontalPadding * 0.5),
                                    Row(
                                      children: [
                                        SizedBox(width: defaultCardHorizontalPadding),
                                        Expanded(
                                          child: NamidaHero(
                                            enabled: enableHero,
                                            tag: 'DPC_history',
                                            child: ObxO(
                                              rx: HistoryController.inst.totalHistoryItemsCount,
                                              builder: (context, count) => DefaultPlaylistCard(
                                                colorScheme: Colors.grey,
                                                icon: Broken.refresh,
                                                title: lang.HISTORY,
                                                displayLoadingIndicator: count == -1,
                                                text: count.formatDecimal(),
                                                onTap: NamidaOnTaps.inst.onHistoryPlaylistTap,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: defaultCardHorizontalPaddingCenter),
                                        Expanded(
                                          child: NamidaHero(
                                            enabled: enableHero,
                                            tag: 'DPC_mostplayed',
                                            child: Obx(
                                              (context) => DefaultPlaylistCard(
                                                colorScheme: Colors.green,
                                                icon: Broken.award,
                                                title: lang.MOST_PLAYED,
                                                displayLoadingIndicator: HistoryController.inst.isLoadingHistoryR,
                                                text: HistoryController.inst.topTracksMapListens.length.formatDecimal(),
                                                onTap: () => NamidaOnTaps.inst.onMostPlayedPlaylistTap(),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: defaultCardHorizontalPadding),
                                      ],
                                    ),
                                    SizedBox(height: 12.0),
                                    Row(
                                      children: [
                                        SizedBox(width: defaultCardHorizontalPadding),
                                        Expanded(
                                          child: NamidaHero(
                                            enabled: enableHero,
                                            tag: 'DPC_favs',
                                            child: ObxOClass(
                                              rx: PlaylistController.inst.favouritesPlaylist,
                                              builder: (context, favouritesPlaylist) => DefaultPlaylistCard(
                                                colorScheme: Colors.red,
                                                icon: Broken.heart,
                                                title: lang.FAVOURITES,
                                                text: favouritesPlaylist.value.tracks.length.formatDecimal(),
                                                onTap: () => NamidaOnTaps.inst.onNormalPlaylistTap(k_PLAYLIST_NAME_FAV),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: defaultCardHorizontalPaddingCenter),
                                        Expanded(
                                          child: NamidaHero(
                                            enabled: enableHero,
                                            tag: 'DPC_queues',
                                            child: Obx(
                                              (context) => DefaultPlaylistCard(
                                                colorScheme: Colors.blue,
                                                icon: Broken.driver,
                                                title: lang.QUEUES,
                                                displayLoadingIndicator: QueueController.inst.isLoadingQueues,
                                                text: QueueController.inst.queuesMap.valueR.length.formatDecimal(),
                                                onTap: const QueuesPage().navigate,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: defaultCardHorizontalPadding),
                                      ],
                                    ),
                                    SizedBox(height: defaultCardHorizontalPadding * 0.5),
                                  ],
                                ),
                              ),
                            ),
                          const SliverPadding(padding: EdgeInsets.only(top: 10.0)),
                          if (isInsideDialog)
                            SliverToBoxAdapter(
                              child: ObxOClass(
                                rx: PlaylistController.inst.favouritesPlaylist,
                                builder: (context, favouritesPlaylist) {
                                  bool? allTracksExist;
                                  if (tracksToAdd.isNotEmpty) {
                                    allTracksExist = tracksToAdd.every(favouritesPlaylist.isSubItemFavourite);
                                  }
                                  return PlaylistTile(
                                    enableHero: enableHero,
                                    playlistName: k_PLAYLIST_NAME_FAV,
                                    onTap: () {
                                      _onAddToPlaylist(
                                        playlist: favouritesPlaylist.value,
                                        allTracksExist: allTracksExist == true,
                                        allowAddingEverything: false,
                                      );
                                    },
                                    checkmarkStatus: allTracksExist,
                                  );
                                },
                              ),
                            ),
                          if (isInsideDialog)
                            const SliverToBoxAdapter(
                              child: NamidaContainerDivider(margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0)),
                            ),
                          ObxO(
                            rx: settings.playlistSort,
                            builder: (context, sort) {
                              final sortTextIsUseless = sort == GroupSortType.title || sort == GroupSortType.numberOfTracks || sort == GroupSortType.duration;
                              final extraTextResolver = sortTextIsUseless ? null : SearchSortController.inst.getGroupSortExtraTextResolverPlaylist(sort);

                              return ObxPrefer(
                                enabled: sort.requiresHistory,
                                rx: HistoryController.inst.topTracksMapListens,
                                builder: (context, _) => ObxO(
                                  rx: PlaylistController.inst.playlistsMap,
                                  builder: (context, playlistsMap) => ObxO(
                                    rx: SearchSortController.inst.playlistSearchList,
                                    builder: (context, playlistSearchList) => countPerRowResolved == 1
                                        ? SliverFixedExtentList.builder(
                                            itemCount: playlistSearchList.length,
                                            itemExtent: Dimensions.playlistTileItemExtent,
                                            itemBuilder: (context, i) {
                                              final key = playlistSearchList[i];
                                              final playlist = playlistsMap[key]!;

                                              bool? allTracksExist;
                                              if (tracksToAdd != null && tracksToAdd.isNotEmpty) {
                                                allTracksExist = tracksToAdd.every((trackToAdd) => playlist.tracks.firstWhereEff((e) => e.track == trackToAdd) != null);
                                              }

                                              final extraText = extraTextResolver?.call(playlist);
                                              return AnimatingTile(
                                                position: i,
                                                shouldAnimate: _shouldAnimate,
                                                child: PlaylistTile(
                                                  enableHero: enableHero,
                                                  playlistName: key,
                                                  onTap: tracksToAdd != null
                                                      ? () {
                                                          _onAddToPlaylist(playlist: playlist, allTracksExist: allTracksExist == true, allowAddingEverything: true);
                                                        }
                                                      : () => NamidaOnTaps.inst.onNormalPlaylistTap(key),
                                                  checkmarkStatus: allTracksExist,
                                                  extraText: extraText, // dont fallback to prevent confusion
                                                ),
                                              );
                                            },
                                          )
                                        : countPerRowResolved > 1
                                            ? SliverGrid.builder(
                                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: countPerRowResolved,
                                                  childAspectRatio: 0.8,
                                                  mainAxisSpacing: 8.0,
                                                ),
                                                itemCount: playlistSearchList.length,
                                                itemBuilder: (context, i) {
                                                  final key = playlistSearchList[i];
                                                  final playlist = playlistsMap[key]!;
                                                  final extraText = extraTextResolver?.call(playlist);
                                                  return AnimatingGrid(
                                                    columnCount: playlistSearchList.length,
                                                    position: i,
                                                    shouldAnimate: _shouldAnimate,
                                                    child: MultiArtworkCard(
                                                      enableHero: enableHero,
                                                      heroTag: 'playlist_${playlist.name}',
                                                      tracks: playlist.tracks.toTracks(),
                                                      name: playlist.name.translatePlaylistName(),
                                                      countPerRow: widget.countPerRow,
                                                      showMenuFunction: () => NamidaDialogs.inst.showPlaylistDialog(key),
                                                      onTap: () => NamidaOnTaps.inst.onNormalPlaylistTap(key),
                                                      artworkFile: PlaylistController.inst.getArtworkFileForPlaylist(playlist.name),
                                                      widgetsInStack: [
                                                        if (playlist.m3uPath != null)
                                                          Positioned(
                                                            bottom: 8.0,
                                                            right: 8.0,
                                                            child: NamidaTooltip(
                                                              message: () => "${lang.M3U_PLAYLIST}\n${playlist.m3uPath?.formatPath()}",
                                                              child: const Icon(Broken.music_filter, size: 18.0),
                                                            ),
                                                          ),
                                                        if (extraText != null && extraText.isNotEmpty)
                                                          Positioned(
                                                            top: 0,
                                                            right: 0,
                                                            child: NamidaBlurryContainer(
                                                              child: Text(
                                                                extraText,
                                                                style: context.textTheme.displaySmall?.copyWith(
                                                                  fontSize: 12.0,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                                softWrap: false,
                                                                overflow: TextOverflow.fade,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              )
                                            : const SizedBox(),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (!isInsideDialog) kBottomPaddingWidgetSliver,
                        ],
                      ),
                      pullToRefreshWidget,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
