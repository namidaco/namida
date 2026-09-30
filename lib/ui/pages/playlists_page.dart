import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:path/path.dart' as p;
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/count_per_row.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/create_smart_playlist_dialog.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/dialogs/track_stats_dialog.dart';
import 'package:namida/ui/pages/queues_page.dart';
import 'package:namida/ui/pages/smart_playlists_page.dart';
import 'package:namida/ui/pages/subpages/playlist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/smart_playlist_tracks_subpage.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/multi_artwork_card.dart';
import 'package:namida/ui/widgets/library/playlist_tags_chips_row.dart';
import 'package:namida/ui/widgets/library/playlist_tile.dart';
import 'package:namida/ui/widgets/sliver_cross_axis_extent_builder.dart';
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
    final tagsForPaths = <String, List<String>>{};
    if (pickFolder) {
      final dirs = await NamidaFileBrowser.pickDirectories(note: "${lang.import} (${lang.folders})");
      playlistsFilesPath = {};
      final allSubfiles = await dirs.mapConcurrent((d) => d.listAllIsolate(recursive: true), concurrency: 4);
      for (int i = 0; i < dirs.length; i++) {
        final dirPath = dirs[i].path;
        final dirName = dirPath.getFilename;
        for (var f in allSubfiles[i]) {
          if (f is File) {
            var path = f.path;
            if (NamidaFileExtensionsWrapper.m3u.isPathValid(path)) {
              playlistsFilesPath.add(path);
              final relativeDirPath = p.relative(path.getDirectoryPath, from: dirPath);
              final folderTag = relativeDirPath == '.' ? dirName : p.join(dirName, relativeDirPath);
              final folderTagPath = folderTag.replaceAll(p.separator, PlaylistTagsFilter.separator);
              tagsForPaths[path] = [folderTagPath];
            }
          }
        }
      }
    } else {
      final playlistsFiles = await NamidaFileBrowser.pickFiles(note: lang.import, allowedExtensions: NamidaFileExtensionsWrapper.m3u);
      playlistsFilesPath = playlistsFiles.map((f) => f.path).toSet();
    }
    if (playlistsFilesPath.isNotEmpty) {
      final importedCount = await PlaylistController.inst.prepareM3UPlaylists(forPaths: playlistsFilesPath, addAsM3U: keepSynced, tagsForPaths: tagsForPaths);
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
          message: lang.importedNPlaylistsSuccessfully(number: importedCount, numberText: countText),
          borderColor: (hadError ? Colors.orange : Colors.green).withOpacityExt(0.6),
        );
      } else {
        snackyy(
          message: lang.error,
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
        title: lang.choose,
        actions: const [
          CancelButton(addMargin: false),
        ],
        child: Column(
          children: [
            CustomListTile(
              icon: Broken.shuffle,
              title: lang.random,
              subtitle: lang.generateRandomPlaylist,
              onTap: () {
                _closeDialog();
                final numbers = PlaylistController.inst.generateRandomPlaylist();
                if (numbers == 0) {
                  snackyy(title: lang.error, message: lang.noEnoughTracks);
                }
              },
            ),
            CustomListTile(
              icon: Broken.import_1,
              title: lang.import,
              subtitle: lang.playlistsImportM3uNative,
              trailing: NamidaIconButton(
                tooltip: () => lang.folder,
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
              icon: Broken.add_circle,
              title: lang.create,
              subtitle: lang.createNewPlaylist,
              onTap: () {
                _closeDialog();
                CreatePlaylistButton().promptCreate();
              },
            ),
            CustomListTile(
              icon: Broken.magicpen,
              title: lang.create,
              subtitle: lang.createNewSmartPlaylist,
              onTap: () {
                _closeDialog();
                NamidaNavigator.inst.navigateDialog(
                  dialog: const CreateSmartPlaylistDialog(),
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
        title: lang.configure,
        actions: const [
          CancelButton(addMargin: false),
        ],
        child: Column(
          children: [
            ObxO(
              rx: settings.enableM3USyncStartup,
              builder: (context, m3usyncstartup) => CustomSwitchListTile(
                leading: const StackedIcon(
                  baseIcon: Broken.music_library_2,
                  secondaryIcon: Broken.refresh_square_2,
                  secondaryIconSize: 12.0,
                ),
                title: lang.playlistsImportM3uSyncedAutoImport,
                subtitle: lang.playlistsImportM3uSynced,
                onChanged: (isTrue) => settings.enableM3USyncStartup.save(!isTrue),
                value: m3usyncstartup,
              ),
            ),
            ObxO(
              rx: settings.importServerPlaylists,
              builder: (context, importServerPlaylists) => CustomSwitchListTile(
                leading: const StackedIcon(
                  baseIcon: Broken.cloud,
                  secondaryIcon: Broken.refresh_square_2,
                  secondaryIconSize: 12.0,
                ),
                title: lang.playlistsImportServerAutoImport,
                subtitle: lang.playlistsImportServer,
                onChanged: (isTrue) => settings.importServerPlaylists.save(!isTrue),
                value: importServerPlaylists,
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
          bodyText: "${lang.removeFromPlaylist} ${playlist.name.translatePlaylistName().addDQuotation()}?",
          actions: [
            const CancelButton(),
            NamidaButton(
              colorScheme: Colors.red,
              text: lang.remove.toUpperCase(),
              onTap: () {
                NamidaNavigator.inst.closeDialog();
                PlaylistController.inst.removeTracksFromPlaylist(playlist, indexes);
              },
            ),
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

  bool _isReordering = false;

  void _toggleReordering() async {
    setState(() => _isReordering = !_isReordering);
    if (_isReordering) {
      await PlaylistController.inst.waitForPlaylistsLoad;
      PlaylistController.inst.ensureCustomOrderValid(removeNonExistent: true);
      if (settings.playlistSorts.value.first != GroupSortType.custom || settings.playlistSortReversed.value) {
        // -- for consistent order while enabling/disabling
        settings.updateGroupSortingAll(MediaType.playlist, const [GroupSortType.custom], false);
        PlaylistController.inst.sortPlaylists();
      }
    }
  }

  _PlaylistsSelection? _selection;
  final _collapsedSections = <PlaylistTagKey>{}.obs;

  @override
  void dispose() {
    _selection?.dispose();
    _collapsedSections.close();
    super.dispose();
  }

  void _toggleSelecting() {
    final selection = _selection;
    selection?.dispose();
    setState(() => _selection = selection == null ? _PlaylistsSelection() : null);
  }

  void _toggleSectionCollapsed(PlaylistTagKey key) {
    final collapsedSections = _collapsedSections.value;
    final wasCollapsed = collapsedSections.remove(key);
    if (!wasCollapsed) collapsedSections.add(key);
    _collapsedSections.refresh();
  }

  void _playFiltered({required bool shuffle}) {
    final names = SearchSortController.inst.playlistSearchList.value;
    final tracks = PlaylistController.inst.getUniqueTracksOf(names);
    if (tracks.isEmpty) return;
    final filterText = PlaylistController.inst.tagsFilter.selection.toText();
    Player.inst.playOrPause(0, tracks, QueueSource.playlistTags(filterText), shuffle: shuffle);
  }

  List<NamidaPopupItem> _buildTagsMenuItems() {
    final isGrouped = settings.playlistsGroupByTags.value;
    return [
      NamidaPopupItem(
        icon: Broken.hierarchy_2,
        title: lang.groupByTags,
        selected: isGrouped,
        onTap: () => settings.playlistsGroupByTags.save(!isGrouped),
      ),
    ];
  }

  ScrollbarThumbLabelResolver? _createThumbLabel() {
    if (settings.playlistsGroupByTags.value) return null; // -- sections dont follow the list order
    final playlists = SearchSortController.inst.playlistSearchList.value;
    final labelOf = SearchSortController.inst.getPlaylistsSortLabelResolver();
    return NamidaScrollbar.createListThumbLabel(playlists, labelOf);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final tracksToAdd = widget.tracksToAdd;
    final isInsideDialog = tracksToAdd != null;
    final enableHero = !isInsideDialog;
    const libraryTab = LibraryTab.playlists;
    final scrollController = isInsideDialog ? null : libraryTab.scrollController;
    final defaultCardHorizontalPadding = Dimensions.inst.availableAppContentWidth * 0.045;
    final defaultCardHorizontalPaddingCenter = Dimensions.inst.availableAppContentWidth * 0.035;
    final countPerRowResolved = widget.countPerRow.resolve(context);

    const listHeader = ExpandableBoxEmptyAnimatedPadding(tab: libraryTab);
    final selection = _selection;

    final page = BackgroundWrapper(
      child: Listener(
        onPointerMove: (event) {
          final c = scrollController;
          if (c != null) onPointerMove(c, event);
        },
        onPointerUp: (event) => onRefresh(
          () => Future.wait([
            PlaylistController.inst.prepareM3UPlaylists(),
            Indexer.inst.refreshServerPlaylists(),
          ]),
        ),
        onPointerCancel: (event) => onVerticalDragFinish(),
        child: NamidaScrollbar(
          controller: scrollController,
          thumbLabel: _createThumbLabel,
          child: AnimationLimiter(
            child: ExpandableBoxColumn(
              tab: libraryTab,
              header: Obx(
                (context) {
                  final finalPlaylistsLength = SearchSortController.inst.playlistSearchList.valueR.length;
                  final totalPlaylistsLength = PlaylistController.inst.playlistsMap.valueR.length;
                  String leftText = finalPlaylistsLength != totalPlaylistsLength
                      ? '$finalPlaylistsLength/${totalPlaylistsLength.displayPlaylistKeyword}'
                      : finalPlaylistsLength.displayPlaylistKeyword;

                  return ExpandableBox(
                    enableHero: widget.enableHero && enableHero,
                    gridWidget: isInsideDialog
                        ? null
                        : const ChangeGridCountWidget(
                            tab: libraryTab,
                          ),
                    isBarVisible: libraryTab.isBarVisible.valueR,
                    leftText: leftText,
                    onSearchBoxVisibilityChange: (newShow) => ScrollSearchController.inst.onSearchBoxVisibiltyChange(libraryTab, newShow),
                    onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(libraryTab),
                    disableSorting: tracksToAdd != null && tracksToAdd.isNotEmpty,
                    sortByMenuWidget: SortByMenu(
                      title: settings.playlistSorts.valueR.first.toText(),
                      popupMenuChild: const SortByMenuPlaylist(),
                      isCurrentlyReversed: settings.playlistSortReversed.valueR,
                      onReverseIconTap: () => SearchSortController.inst.sortMedia(MediaType.playlist, reverse: !settings.playlistSortReversed.value),
                    ),
                    textField: CustomTextField(
                      textFieldController: libraryTab.textSearchControllerUI,
                      textFieldHintText: lang.filterPlaylists,
                      onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, MediaType.playlist),
                    ),
                  );
                },
              ),
              page: Stack(
                children: [
                  SmoothCustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(child: listHeader),

                      if (!isInsideDialog)
                        SliverToBoxAdapter(
                          child: NamidaHero(
                            enabled: enableHero,
                            tag: 'PlaylistPage_TopRow',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const SizedBox(width: 12.0),

                                  // Expanded(
                                  //   child: ObxO(
                                  //     rx: PlaylistController.inst.playlistsMap,
                                  //     builder: (context, playlistsMap) => Text(
                                  //       playlistsMap.length.displayPlaylistKeyword,
                                  //       style: textTheme.displayLarge,
                                  //       maxLines: 2,
                                  //       overflow: TextOverflow.ellipsis,
                                  //     ),
                                  //   ),
                                  // ),
                                  // const SizedBox(width: 12.0),
                                  NamidaButton(
                                    icon: Broken.add,
                                    text: lang.add,
                                    iconSize: 20.0,
                                    onTap: _onAddPlaylistsTap,
                                  ),
                                  // const SizedBox(width: 8.0),
                                  // NamidaButton(
                                  //   icon: Broken.pen_add,
                                  //   text: lang.create,
                                  //   iconSize: 19.0,
                                  //   onTap: () {
                                  //     showSettingDialogWithTextField(
                                  //       title: lang.createNewPlaylist,
                                  //       addNewPlaylist: true,
                                  //     );
                                  //   },
                                  // ),
                                  const SizedBox(width: 8.0),
                                  NamidaButton(
                                    icon: Broken.task_square,
                                    iconSize: 20.0,
                                    tooltip: () => lang.selectPlaylists,
                                    onTap: _toggleSelecting,
                                    colorScheme: selection != null ? context.theme.colorScheme.secondaryContainer : null,
                                  ),
                                  const SizedBox(width: 8.0),
                                  NamidaButton(
                                    icon: Broken.edit_2,
                                    iconSize: 20.0,
                                    tooltip: () => _isReordering ? lang.disableReordering : lang.enableReordering,
                                    onTap: _toggleReordering,
                                    colorScheme: _isReordering ? context.theme.colorScheme.secondaryContainer : null,
                                  ),
                                  const SizedBox(width: 8.0),
                                  NamidaButton(
                                    icon: Broken.setting_4,
                                    iconSize: 20.0,
                                    onTap: _onPlaylistButtonConfigTap,
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
                                            title: lang.history,
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
                                            title: lang.mostPlayed,
                                            displayLoadingIndicator: HistoryController.inst.isLoadingHistoryR,
                                            text: HistoryController.inst.topTracksMapListens.valueR.length.formatDecimal(),
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
                                            title: lang.favourites,
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
                                            title: lang.queues,
                                            displayLoadingIndicator: !QueueController.inst.isQueuesLoaded,
                                            text: QueueController.inst.totalQueuesCount.valueR.formatDecimal(),
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
                      if (!isInsideDialog) ...[
                        const SliverPadding(padding: EdgeInsets.only(top: 10.0)),
                        SliverToBoxAdapter(
                          child: ObxO(
                            rx: SmartPlaylistsController.inst.smartPlaylistsList,
                            builder: (context, smartPlaylists) {
                              if (smartPlaylists.isEmpty) return const SizedBox();
                              return SizedBox(
                                height: 48.0,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: NamidaEndEdgeFeather(
                                        child: SuperSmoothListView.builder(
                                          padding: const EdgeInsetsDirectional.only(start: 4.0, end: 16.0),
                                          scrollDirection: Axis.horizontal,
                                          itemCount: smartPlaylists.length,
                                          itemBuilder: (context, index) {
                                            final smplWrapper = smartPlaylists[index];
                                            final imgFile = SmartPlaylistsController.inst.getArtworkFileForPlaylist(smplWrapper.value);
                                            return ConstrainedBox(
                                              constraints: BoxConstraints(maxWidth: context.width * 0.75),
                                              child: NamidaInkWell(
                                                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                                onTap: () {
                                                  SmartPlaylistTracksPage(
                                                    smartPlaylistWrapper: smplWrapper,
                                                  ).navigate();
                                                },
                                                onLongPress: () => NamidaDialogs.inst.showSmartPlaylistDialog(smplWrapper),
                                                borderRadius: 8.0,
                                                bgColor: context.theme.colorScheme.secondary.withOpacityExt(0.12),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const SizedBox(width: 4.0),
                                                    ArtworkWidget(
                                                      key: ValueKey(imgFile),
                                                      track: null,
                                                      thumbnailSize: 48.0,
                                                      path: imgFile.path,
                                                      forceSquared: true,
                                                      icon: Broken.magicpen,
                                                    ),
                                                    const SizedBox(width: 6.0),
                                                    Flexible(
                                                      child: Text(
                                                        smplWrapper.value.name,
                                                        softWrap: false,
                                                        overflow: TextOverflow.fade,
                                                        style: textTheme.displayMedium,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12.0),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6.0),
                                    NamidaButton(
                                      dense: true,
                                      iconSize: 20.0,
                                      borderRadius: 12.0,
                                      isMinimumSquared: true,
                                      colors: .normal,
                                      icon: Broken.export_1,
                                      tooltip: () => lang.viewAll,
                                      onTap: const SmartPlaylistsPage().navigate,
                                    ),
                                    const SizedBox(width: 12.0),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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
                      if (!_isReordering)
                        SliverToBoxAdapter(
                          child: PlaylistTagsChipsRow(
                            manager: PlaylistController.inst,
                            padding: const EdgeInsets.only(bottom: 8.0),
                            onPlay: _playFiltered,
                            extraMenuItems: isInsideDialog ? null : _buildTagsMenuItems,
                          ),
                        ),
                      if (selection != null && !_isReordering)
                        PinnedHeaderSliver(
                          child: _PlaylistsSelectionBar(
                            selection: selection,
                            onClose: _toggleSelecting,
                          ),
                        ),
                      _isReordering
                          ? ObxO(
                              rx: PlaylistController.inst.getCustomIndicesOrderListRx(),
                              builder: (context, customIndicesOrderList) => NamidaSliverReorderableList(
                                itemExtent: Dimensions.playlistTileItemExtent,
                                onReorderStart: (index) => super.enablePullToRefresh = false,
                                onReorderEnd: (index) => super.enablePullToRefresh = true,
                                onReorder: (oldIndex, newIndex) async {
                                  if (settings.playlistSorts.value.first != GroupSortType.custom) {
                                    settings.playlistSorts.replace(const [GroupSortType.custom]);
                                  }
                                  PlaylistController.inst.onPlaylistReorder(oldIndex, newIndex);
                                },
                                itemCount: customIndicesOrderList!.length,
                                itemBuilder: (context, i) {
                                  final name = customIndicesOrderList[i];
                                  return NamidaReordererableListener(
                                    key: ValueKey(i),
                                    durationMs: 100,
                                    index: i,
                                    child: InkWell(
                                      onTap: () {},
                                      child: Row(
                                        children: [
                                          const ThreeLineSmallContainers(
                                            enabled: true,
                                          ),
                                          Expanded(
                                            child: AbsorbPointer(
                                              child: PlaylistTile(
                                                enableHero: enableHero,
                                                playlistName: name,
                                                onTap: null,
                                                checkmarkStatus: null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : ObxO(
                              rx: settings.playlistSorts,
                              builder: (context, sorts) {
                                final sort = sorts.first;
                                final sortTextIsUseless = sort == GroupSortType.title || sort == GroupSortType.numberOfTracks || sort == GroupSortType.duration;
                                final extraTextResolver = sortTextIsUseless ? null : SearchSortController.inst.getGroupSortExtraTextResolverPlaylist(sort);

                                late final existingStatus = <String, bool>{};
                                late final sortedIndices = <String, int>{};

                                return ObxPrefer(
                                  enabled: sort.requiresHistory,
                                  rx: HistoryController.inst.topTracksMapListens,
                                  builder: (context, _) => ObxO(
                                    rx: settings.playlistsGroupByTags,
                                    builder: (context, groupByTags) => ObxO(
                                      rx: PlaylistController.inst.playlistsMap,
                                      builder: (context, playlistsMap) => ObxO(
                                        rx: SearchSortController.inst.playlistSearchList,
                                        builder: (context, playlistSearchListPre) {
                                          List<String> playlistSearchList;
                                          if (tracksToAdd != null && tracksToAdd.isNotEmpty) {
                                            // -- put playlists having the tracks at first
                                            final playlistSearchListSorted = <String>[];
                                            final shouldReSort = existingStatus.isEmpty; // sort only once, so that refresh won't make them jump around

                                            for (final key in playlistSearchListPre) {
                                              final playlist = playlistsMap[key]!;
                                              if (playlist.isReadOnly) continue; // -- can't add tracks to read-only playlists
                                              playlistSearchListSorted.add(key);
                                              final allTracksExist = tracksToAdd.every((trackToAdd) => playlist.tracks.firstWhereEff((e) => e.track == trackToAdd) != null);
                                              existingStatus[key] = allTracksExist;
                                            }
                                            playlistSearchListSorted.sortBy((key) => sortedIndices[key] ?? (existingStatus[key] == true ? -2 : -1));
                                            if (shouldReSort) {
                                              int index = 0;
                                              for (final p in playlistSearchListSorted) {
                                                sortedIndices[p] = index;
                                                index++;
                                              }
                                            }
                                            playlistSearchList = playlistSearchListSorted;
                                          } else {
                                            playlistSearchList = playlistSearchListPre;
                                          }

                                          final onAddTap = tracksToAdd == null
                                              ? null
                                              : (LocalPlaylist playlist, bool allTracksExist) => _onAddToPlaylist(
                                                  playlist: playlist,
                                                  allTracksExist: allTracksExist,
                                                  allowAddingEverything: true,
                                                );

                                          final isGrouped = groupByTags && !isInsideDialog;
                                          if (!isGrouped) {
                                            return _PlaylistsSliver(
                                              names: playlistSearchList,
                                              playlistsMap: playlistsMap,
                                              countPerRow: widget.countPerRow,
                                              countPerRowResolved: countPerRowResolved,
                                              enableHero: enableHero,
                                              shouldAnimate: _shouldAnimate,
                                              extraTextResolver: extraTextResolver,
                                              existingStatus: existingStatus,
                                              onAddTap: onAddTap,
                                              selection: selection,
                                            );
                                          }

                                          final sections = PlaylistController.inst.tagsFilter.groupByTopLevelTag(playlistSearchList);
                                          return ObxO(
                                            rx: _collapsedSections,
                                            builder: (context, collapsedSections) => SliverMainAxisGroup(
                                              slivers: [
                                                for (final section in sections) ...[
                                                  SliverToBoxAdapter(
                                                    child: _TagSectionHeader(
                                                      section: section,
                                                      isCollapsed: collapsedSections.contains(section.key),
                                                      onTap: () => _toggleSectionCollapsed(section.key),
                                                    ),
                                                  ),
                                                  if (!collapsedSections.contains(section.key))
                                                    _PlaylistsSliver(
                                                      names: section.names,
                                                      playlistsMap: playlistsMap,
                                                      countPerRow: widget.countPerRow,
                                                      countPerRowResolved: countPerRowResolved,
                                                      enableHero: false, // -- a playlist can show up in multiple sections
                                                      shouldAnimate: _shouldAnimate,
                                                      extraTextResolver: extraTextResolver,
                                                      existingStatus: existingStatus,
                                                      onAddTap: onAddTap,
                                                      selection: selection,
                                                    ),
                                                ],
                                              ],
                                            ),
                                          );
                                        },
                                      ),
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
          ),
        ),
      ),
    );
    if (selection == null) return page;
    return _SelectionShortcuts(
      selection: selection,
      onClose: _toggleSelecting,
      child: page,
    );
  }
}

// by claude
class _PlaylistsSelection {
  final selectedNames = <String>{}.obs;

  /// the last tapped playlist, where a ranged selection starts.
  String? _anchorName;

  /// [visibleNames] is the list [name] was tapped in.
  void onTap(String name, List<String> visibleNames) {
    if (HardwareKeyboard.instance.isShiftPressed) {
      selectRange(name, visibleNames);
    } else {
      toggle(name);
    }
  }

  void toggle(String name) {
    final names = selectedNames.value;
    final wasSelected = names.remove(name);
    if (!wasSelected) names.add(name);
    _anchorName = name;
    selectedNames.refresh();
  }

  /// selects everything between the last tapped playlist and [name].
  void selectRange(String name, List<String> visibleNames) {
    final anchorName = _anchorName;
    final anchorIndex = anchorName == null ? -1 : visibleNames.indexOf(anchorName);
    final index = visibleNames.indexOf(name);
    if (anchorIndex == -1 || index == -1) return toggle(name);
    final startIndex = anchorIndex < index ? anchorIndex : index;
    final endIndex = anchorIndex < index ? index : anchorIndex;
    final range = visibleNames.getRange(startIndex, endIndex + 1);
    selectedNames.value.addAll(range);
    _anchorName = name;
    selectedNames.refresh();
  }

  void selectAll() {
    final visibleNames = SearchSortController.inst.playlistSearchList.value;
    selectedNames.value.addAll(visibleNames);
    selectedNames.refresh();
  }

  void toggleSelectAll() {
    final visibleNames = SearchSortController.inst.playlistSearchList.value;
    final selected = selectedNames.value;
    final isAllSelected = selected.length >= visibleNames.length && visibleNames.every(selected.contains);
    if (isAllSelected) {
      selected.clear();
    } else {
      selected.addAll(visibleNames);
    }
    selectedNames.refresh();
  }

  void invert() {
    final visibleNames = SearchSortController.inst.playlistSearchList.value;
    final selected = selectedNames.value;
    for (final name in visibleNames) {
      final wasSelected = selected.remove(name);
      if (!wasSelected) selected.add(name);
    }
    selectedNames.refresh();
  }

  void _clear() {
    selectedNames.value.clear();
    selectedNames.refresh();
  }

  int countTracks() {
    final playlists = PlaylistController.inst.playlistsMap.value;
    int count = 0;
    for (final name in selectedNames.value) {
      count += playlists[name]?.tracks.length ?? 0;
    }
    return count;
  }

  void editTags() {
    showSetPlaylistsTagsDialog(
      manager: PlaylistController.inst,
      playlistsNames: selectedNames.value,
    );
  }

  void togglePin() {
    final playlists = PlaylistController.inst.playlistsMap.value;
    final names = selectedNames.value;
    bool areAllPinned = true;
    for (final name in names) {
      if (playlists[name]?.isPinned != true) {
        areAllPinned = false;
        break;
      }
    }
    final edit = PlaylistMetadataEdit(isPinned: !areAllPinned);
    final edits = {for (final name in names) name: edit};
    PlaylistController.inst.updatePlaylistsMetadata(edits);
  }

  void play({required bool shuffle}) {
    final tracks = PlaylistController.inst.getUniqueTracksOf(selectedNames.value);
    if (tracks.isEmpty) return;
    Player.inst.playOrPause(0, tracks, QueueSource.selectedTracks, shuffle: shuffle);
  }

  static int _countM3UPlaylists(List<String> names) {
    final playlists = PlaylistController.inst.playlistsMap.value;
    int count = 0;
    for (final name in names) {
      if (playlists[name]?.m3uPath != null) count++;
    }
    return count;
  }

  void promptMerge() {
    final names = selectedNames.value.toList();
    final m3uCount = _countM3UPlaylists(names);
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final removeMergedRx = false.obs;
    final deleteM3UFilesRx = false.obs;
    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        controller.dispose();
        removeMergedRx.close();
        deleteM3UFilesRx.close();
      },
      dialog: Form(
        key: formKey,
        child: CustomBlurryDialog(
          title: lang.merge,
          normalTitleStyle: true,
          actions: [
            const CancelButton(),
            NamidaButton(
              text: lang.merge,
              onTap: () {
                final isValid = formKey.currentState?.validate() ?? false;
                if (!isValid) return;
                final removeMerged = removeMergedRx.value;
                final deleteM3UFiles = removeMerged && deleteM3UFilesRx.value;
                NamidaNavigator.inst.closeDialog();
                if (removeMerged) _clear();
                PlaylistController.inst.mergePlaylists(names, controller.text, removeMerged: removeMerged, deleteM3UFiles: deleteM3UFiles);
              },
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 12.0,
              ),
              CustomTagTextField(
                controller: controller,
                hintText: names.join(' + '),
                labelText: lang.name,
                validator: PlaylistController.inst.validatePlaylistName,
              ),
              const SizedBox(
                height: 12.0,
              ),
              ListTileWithCheckMark(
                dense: true,
                activeRx: removeMergedRx,
                icon: Broken.trash,
                title: '${lang.delete}: ${names.length.displayPlaylistKeyword}',
                onTap: removeMergedRx.toggle,
              ),
              if (m3uCount > 0) ...[
                const SizedBox(
                  height: 6.0,
                ),
                ObxO(
                  rx: removeMergedRx,
                  builder: (context, removeMerged) => AnimatedEnabled(
                    enabled: removeMerged,
                    child: ListTileWithCheckMark(
                      dense: true,
                      activeRx: deleteM3UFilesRx,
                      icon: Broken.broom,
                      title: '${lang.delete}: ${lang.m3uPlaylist}',
                      subtitle: m3uCount.displayPlaylistKeyword,
                      onTap: deleteM3UFilesRx.toggle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> export() async {
    final names = selectedNames.value.toList();
    final directoryPath = await NamidaFileBrowser.getDirectory(note: lang.export);
    if (directoryPath == null) return;
    if (!await requestManageStoragePermission()) return;
    final exportedCount = await PlaylistController.inst.exportPlaylistsToM3UFiles(names, directoryPath);
    snackyy(message: '${lang.savedIn}: $directoryPath (${exportedCount.displayPlaylistKeyword})');
  }

  void promptDelete() {
    final names = selectedNames.value.toList();
    if (names.isEmpty) return;
    final m3uCount = _countM3UPlaylists(names);
    final deleteM3UFilesRx = false.obs;
    NamidaNavigator.inst.navigateDialog(
      onDisposing: deleteM3UFilesRx.close,
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            colorScheme: Colors.red,
            text: lang.delete.toUpperCase(),
            onTap: () {
              final deleteM3UFiles = deleteM3UFilesRx.value;
              NamidaNavigator.inst.closeDialog();
              _clear();
              PlaylistController.inst.removePlaylists(names, deleteM3UFiles: deleteM3UFiles);
            },
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${lang.delete}: ${names.length.displayPlaylistKeyword}?',
                style: namida.textTheme.displayMedium,
              ),
              if (m3uCount > 0) ...[
                const SizedBox(
                  height: 12.0,
                ),
                ListTileWithCheckMark(
                  dense: true,
                  activeRx: deleteM3UFilesRx,
                  icon: Broken.broom,
                  title: '${lang.delete}: ${lang.m3uPlaylist}',
                  subtitle: m3uCount.displayPlaylistKeyword,
                  onTap: deleteM3UFilesRx.toggle,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void dispose() => selectedNames.close();
}

class _PlaylistsSliver extends StatelessWidget {
  final List<String> names;
  final Map<String, LocalPlaylist> playlistsMap;
  final CountPerRow countPerRow;
  final int countPerRowResolved;
  final bool enableHero;
  final bool shouldAnimate;
  final String? Function(LocalPlaylist playlist)? extraTextResolver;
  final Map<String, bool> existingStatus;
  final void Function(LocalPlaylist playlist, bool allTracksExist)? onAddTap;
  final _PlaylistsSelection? selection;

  const _PlaylistsSliver({
    required this.names,
    required this.playlistsMap,
    required this.countPerRow,
    required this.countPerRowResolved,
    required this.enableHero,
    required this.shouldAnimate,
    required this.extraTextResolver,
    required this.existingStatus,
    required this.onAddTap,
    required this.selection,
  });

  @override
  Widget build(BuildContext context) {
    final selection = this.selection;
    if (countPerRowResolved == 1) {
      return SliverFixedExtentList.builder(
        itemCount: names.length,
        itemExtent: Dimensions.playlistTileItemExtent,
        itemBuilder: (context, i) {
          final key = names[i];
          final playlist = playlistsMap[key]!;
          final extraText = extraTextResolver?.call(playlist);
          final Widget tile;
          if (selection != null) {
            tile = ObxO(
              rx: selection.selectedNames,
              builder: (context, selectedNames) => PlaylistTile(
                enableHero: enableHero,
                playlistName: key,
                onTap: () => selection.onTap(key, names),
                onLongPress: () => selection.selectRange(key, names),
                checkmarkStatus: selectedNames.contains(key),
                extraText: extraText,
              ),
            );
          } else {
            final allTracksExist = existingStatus[key];
            final onAddTap = this.onAddTap;
            tile = PlaylistTile(
              enableHero: enableHero,
              playlistName: key,
              onTap: onAddTap != null ? () => onAddTap(playlist, allTracksExist == true) : () => NamidaOnTaps.inst.onNormalPlaylistTap(key),
              checkmarkStatus: allTracksExist,
              extraText: extraText, // dont fallback to prevent confusion
            );
          }
          return AnimatingTile(
            position: i,
            shouldAnimate: shouldAnimate,
            allowTilting: true,
            child: tile,
          );
        },
      );
    }
    if (countPerRowResolved < 1) return const SliverToBoxAdapter();
    return SliverCrossAxisExtentBuilder(
      builder: (context, crossAxisExtent) {
        const childAspectRatio = 0.8;
        final cardWidth = crossAxisExtent / countPerRowResolved;
        final cardHeight = cardWidth / childAspectRatio;
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: countPerRowResolved,
            childAspectRatio: childAspectRatio,
            mainAxisSpacing: 8.0,
          ),
          itemCount: names.length,
          itemBuilder: (context, i) {
            final key = names[i];
            final playlist = playlistsMap[key]!;
            final extraText = extraTextResolver?.call(playlist);
            final Widget card;
            if (selection != null) {
              card = ObxO(
                rx: selection.selectedNames,
                builder: (context, selectedNames) => _PlaylistGridCard(
                  playlist: playlist,
                  countPerRow: countPerRow,
                  width: cardWidth,
                  height: cardHeight,
                  enableHero: enableHero,
                  extraText: extraText,
                  isSelected: selectedNames.contains(key),
                  onTap: () => selection.onTap(key, names),
                  onLongPress: () => selection.selectRange(key, names),
                ),
              );
            } else {
              card = _PlaylistGridCard(
                playlist: playlist,
                countPerRow: countPerRow,
                width: cardWidth,
                height: cardHeight,
                enableHero: enableHero,
                extraText: extraText,
                isSelected: null,
                onTap: () => NamidaOnTaps.inst.onNormalPlaylistTap(key),
                onLongPress: () => NamidaDialogs.inst.showPlaylistDialog(key),
              );
            }
            return AnimatingGrid(
              countPerRowResolved: countPerRowResolved,
              columnCount: names.length,
              position: i,
              shouldAnimate: shouldAnimate,
              child: card,
            );
          },
        );
      },
    );
  }
}

class _PlaylistGridCard extends StatelessWidget {
  final LocalPlaylist playlist;
  final CountPerRow countPerRow;
  final double width;
  final double height;
  final bool enableHero;
  final String? extraText;
  final bool? isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PlaylistGridCard({
    required this.playlist,
    required this.countPerRow,
    required this.width,
    required this.height,
    required this.enableHero,
    required this.extraText,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final name = playlist.name;
    final remoteInfo = playlist.getRemoteInfo();
    final extraText = this.extraText;
    final isSelected = this.isSelected;
    return MultiArtworkCard(
      enableHero: enableHero,
      heroTag: 'playlist_$name',
      tracks: playlist.tracks.toTracks(),
      name: name.translatePlaylistName(),
      countPerRow: countPerRow,
      width: width,
      height: height,
      showMenuFunction: onLongPress,
      onTap: onTap,
      artworkFile: PlaylistController.inst.getArtworkFileForPlaylist(name),
      widgetsInStack: [
        if (isSelected != null)
          Positioned(
            top: 8.0,
            left: 8.0,
            child: NamidaCheckMark(
              size: 16.0,
              active: isSelected,
            ),
          ),
        Positioned(
          bottom: 8.0,
          left: 8.0,
          child: Row(
            children: [
              if (playlist.isPinned) ...[
                const Icon(
                  Broken.paperclip,
                  size: 18.0,
                ),
                const SizedBox(
                  width: 4.0,
                ),
              ],
              PlaylistTagsColorDots(
                filter: PlaylistController.inst.tagsFilter,
                tags: playlist.tags,
              ),
            ],
          ),
        ),
        if (playlist.m3uPath != null)
          Positioned(
            bottom: 8.0,
            right: 8.0,
            child: NamidaTooltip(
              message: () => "${lang.m3uPlaylist}\n${playlist.m3uPath?.formatPath()}",
              child: const Icon(Broken.music_filter, size: 18.0),
            ),
          )
        else if (remoteInfo != null) ...[
          Positioned(
            bottom: 8.0,
            right: 8.0,
            child: NamidaTooltip(
              message: () => "${lang.readOnlyPlaylist}\n${remoteInfo.$1}",
              child: remoteInfo.$2 != null
                  ? Image.asset(
                      remoteInfo.$2!,
                      height: 16.0,
                    )
                  : const Icon(
                      Broken.cloud,
                      size: 18.0,
                    ),
            ),
          ),
          const SizedBox(width: 2.0),
        ],
        if (extraText != null && extraText.isNotEmpty)
          Positioned(
            top: 0,
            right: 0,
            child: NamidaBlurryContainer(
              child: Text(
                extraText,
                style: textTheme.displaySmall?.copyWith(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                ),
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ),
          ),
      ],
    );
  }
}

class _TagSectionHeader extends StatelessWidget {
  final PlaylistTagSection section;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _TagSectionHeader({
    required this.section,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final key = section.key;
    final color = section.color;
    return NamidaInkWell(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      bgColor: theme.colorScheme.secondaryContainer.withOpacityExt(0.15),
      onTap: onTap,
      child: Row(
        children: [
          if (color != null)
            PlaylistTagColorDot(
              color: Color(color),
              size: 10.0,
            )
          else
            Icon(
              key is PlaylistVirtualTag ? key.toIcon() : Broken.tag,
              size: 16.0,
            ),
          const SizedBox(
            width: 10.0,
          ),
          Expanded(
            child: Text(
              key.toText(),
              style: textTheme.displayMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            section.names.length.displayPlaylistKeyword,
            style: textTheme.displaySmall,
          ),
          const SizedBox(
            width: 6.0,
          ),
          Icon(
            isCollapsed ? Broken.arrow_right_3 : Broken.arrow_down_2,
            size: 16.0,
          ),
        ],
      ),
    );
  }
}

class _PlaylistsSelectionBar extends StatelessWidget {
  final _PlaylistsSelection selection;
  final VoidCallback onClose;

  const _PlaylistsSelectionBar({
    required this.selection,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final barColor = Color.alphaBlend(theme.colorScheme.secondaryContainer.withOpacityExt(0.3), theme.scaffoldBackgroundColor);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        padding: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(16.0.multipliedRadius),
        ),
        child: ObxO(
          rx: selection.selectedNames,
          builder: (context, selectedNames) {
            final selectedCount = selectedNames.length;
            final hasSelection = selectedCount > 0;
            final tracksCount = selection.countTracks();
            return Row(
              children: [
                _SelectionBarButton(
                  icon: Broken.close_circle,
                  tooltip: lang.cancel,
                  onTap: onClose,
                ),
                const SizedBox(
                  width: 10.0,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedCount.displayPlaylistKeyword,
                        style: textTheme.displayMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        tracksCount.displayTrackKeyword,
                        style: textTheme.displaySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _SelectionBarButton(
                  icon: Broken.task_square,
                  tooltip: lang.selectAll,
                  onTap: selection.toggleSelectAll,
                ),
                if (hasSelection) ...[
                  _SelectionBarButton(
                    icon: Broken.tag,
                    tooltip: '${lang.tags}/${lang.moods}',
                    onTap: selection.editTags,
                  ),
                  _SelectionBarButton(
                    icon: Broken.paperclip,
                    tooltip: '${lang.pin}/${lang.unpin}',
                    onTap: selection.togglePin,
                  ),
                  _SelectionBarButton(
                    icon: Broken.play,
                    tooltip: lang.playAll,
                    onTap: () => selection.play(shuffle: false),
                  ),
                ],
                NamidaPopupWrapper(
                  childrenDefault: () => [
                    NamidaPopupItem(
                      icon: Broken.arrange_square,
                      title: lang.invertSelection,
                      onTap: selection.invert,
                    ),
                    if (hasSelection) ...[
                      NamidaPopupItem(
                        icon: Broken.shuffle,
                        title: lang.shuffleAll,
                        onTap: () => selection.play(shuffle: true),
                      ),
                      if (selectedCount > 1)
                        NamidaPopupItem(
                          icon: Broken.convert,
                          title: lang.merge,
                          onTap: selection.promptMerge,
                        ),
                      NamidaPopupItem(
                        icon: Broken.directbox_send,
                        title: '${lang.export} (M3U)',
                        onTap: selection.export,
                      ),
                      NamidaPopupItem(
                        icon: Broken.trash,
                        title: lang.delete,
                        onTap: selection.promptDelete,
                      ),
                    ],
                  ],
                  child: const _SelectionBarButton(
                    icon: Broken.more,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SelectionBarButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;

  const _SelectionBarButton({
    required this.icon,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tooltip = this.tooltip;
    final button = NamidaInkWell(
      width: 38.0,
      height: 38.0,
      margin: const EdgeInsetsDirectional.only(start: 4.0),
      borderRadius: 11.0,
      bgColor: context.theme.colorScheme.secondaryContainer.withOpacityExt(0.45),
      alignment: Alignment.center,
      onTap: onTap,
      child: Icon(
        icon,
        size: 18.0,
      ),
    );
    if (tooltip == null) return button;
    return NamidaTooltip(
      message: () => tooltip,
      child: button,
    );
  }
}

class _SelectionShortcuts extends StatelessWidget {
  final _PlaylistsSelection selection;
  final VoidCallback onClose;
  final Widget child;

  const _SelectionShortcuts({
    required this.selection,
    required this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): selection.selectAll,
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): selection.invert,
        const SingleActivator(LogicalKeyboardKey.delete): selection.promptDelete,
        const SingleActivator(LogicalKeyboardKey.escape): onClose,
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}
