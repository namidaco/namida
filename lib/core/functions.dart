import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:history_manager/history_manager.dart';
import 'package:namico_subscription_manager/core/enum.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:playlist_manager/playlist_manager.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/core/extensions.dart' show ThumbnailPickerExt;

import 'package:namida/class/folder.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/queue_insertion.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/generators_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/pages/equalizer_page.dart';
import 'package:namida/ui/pages/subpages/album_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/artist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/genre_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/playlist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/queue_tracks_subpage.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/yt_generators_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class NamidaOnTaps {
  static NamidaOnTaps get inst => _instance;
  static final NamidaOnTaps _instance = NamidaOnTaps._internal();
  NamidaOnTaps._internal();

  Future<void> onArtistTap(String name, MediaType type, [List<Track>? tracksPre]) async {
    final tracks = tracksPre ?? name.getArtistTracksFor(type);

    final albumIdsMap = <String, List<Track>>{};
    for (final tr in tracks) {
      final album = tr.albumIdentifier;
      albumIdsMap[album] ??= album.getAlbumTracks();
    }
    final albumIdsFinalList = albumIdsMap.entries.toList();
    SearchSortController.inst.sortAlbumsListRaw(albumIdsFinalList, settings.albumSort.value, settings.albumSortReversed.value);
    final albumIds = albumIdsFinalList.map((e) => e.key).toList();

    ArtistTracksPage(
      name: name,
      tracks: tracks,
      albumIdentifiers: albumIds,
      type: type,
    ).navigate();
  }

  Future<void> onAlbumTap(String albumIdentifier) async {
    final tracks = albumIdentifier.getAlbumTracks();

    AlbumTracksPage(
      albumIdentifier: albumIdentifier,
      tracks: tracks,
    ).navigate();
  }

  Future<void> onGenreTap(String name) async {
    GenreTracksPage(
      name: name,
      tracks: name.getGenresTracks(),
    ).navigate();
  }

  Future<void> onNormalPlaylistTap(
    String playlistName, {
    bool disableAnimation = false,
  }) async {
    return NormalPlaylistTracksPage(
      playlistName: playlistName,
      disableAnimation: disableAnimation,
    ).navigate();
  }

  Future<void> onHistoryPlaylistTap({int? initialListen}) async {
    bool shouldNavigate = true;
    if (initialListen != null) {
      shouldNavigate = jumpToListen(
        HistoryController.inst,
        initialListen,
        Dimensions.inst.trackTileItemExtent,
        kHistoryDayHeaderHeightWithPadding,
      );
    }
    if (shouldNavigate) await HistoryTracksPage().navigate();
  }

  /// returns wether the page is most likely not rendered and thus should be navigated to.
  static bool jumpToListen(HistoryManager historyManager, int listen, double itemHeight, double headerHeight) {
    final scrollInfo = historyManager.getListenScrollPosition(
      listenMS: listen,
      extraItemsOffset: 2,
    );

    historyManager.highlightedItem.value = scrollInfo;

    void jump() {
      if (historyManager.scrollController.hasClients) {
        final p = historyManager.scrollController.positions.firstOrNull;
        if (p != null && p.hasContentDimensions) {
          historyManager.scrollController.jumpTo(scrollInfo.toScrollOffset(itemHeight, headerHeight));
        }
      }
    }

    NamidaNavigator.inst.hideStuff();

    if (historyManager.scrollController.hasClients) {
      jump();
      return false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
      return true;
    }
  }

  Future<void> onMostPlayedPlaylistTap() async {
    return const MostPlayedTracksPage().navigate();
  }

  Future<void> onFolderTapNavigate(Folder folder, {Track? trackToScrollTo}) async {
    if (folder is VideoFolder) {
      ScrollSearchController.inst.animatePageController(LibraryTab.foldersVideos);
      Folders.videos.stepIn(folder, trackToScrollTo: trackToScrollTo);
    } else {
      ScrollSearchController.inst.animatePageController(LibraryTab.folders);
      Folders.tracks.stepIn(folder, trackToScrollTo: trackToScrollTo);
    }
  }

  Future<void> onQueueTap(Queue queue) async {
    QueueTracksPage(queue: queue).navigate();
  }

  Future<void> onQueueDelete(Queue queue) async {
    final oldQueue = queue;
    QueueController.inst.removeQueue(oldQueue);
    snackyy(
      title: lang.UNDO_CHANGES,
      message: lang.UNDO_CHANGES_DELETED_QUEUE,
      displayDuration: SnackDisplayDuration.long,
      button: (
        lang.UNDO,
        () async => await QueueController.inst.reAddQueue(oldQueue),
      ),
    );
  }

  Future<void> onRemoveTracksFromPlaylist(String name, List<TrackWithDate> tracksWithDates) async {
    void showSnacky({required void Function() whatDoYouWant}) {
      snackyy(
        title: lang.UNDO_CHANGES,
        message: lang.UNDO_CHANGES_DELETED_TRACK,
        displayDuration: SnackDisplayDuration.long,
        button: (
          lang.UNDO,
          whatDoYouWant,
        ),
      );
    }

    final bool isHistory = name == k_PLAYLIST_NAME_HISTORY;

    if (isHistory) {
      final tempList = List<TrackWithDate>.from(tracksWithDates);
      await HistoryController.inst.removeTracksFromHistory(tempList);
      showSnacky(
        whatDoYouWant: () async {
          final daysToSave = HistoryController.inst.addTracksToHistoryOnly(tempList, preventDuplicate: true);
          HistoryController.inst.updateMostPlayedPlaylist(tempList);
          HistoryController.inst.sortHistoryTracks(tempList.mapped((e) => e.dateAdded.toDaysSince1970()));
          await HistoryController.inst.saveHistoryToStorage(daysToSave);
        },
      );
    } else {
      final playlist = PlaylistController.inst.getPlaylist(name);
      if (playlist == null) return;

      final Map<TrackWithDate, int> twdAndIndexes = {};
      tracksWithDates.loop((twd) {
        final index = playlist.tracks.indexOf(twd);
        if (index > -1) twdAndIndexes[twd] = index;
      });

      await PlaylistController.inst.removeTracksFromPlaylist(playlist, twdAndIndexes.values.toList());
      showSnacky(
        whatDoYouWant: () async {
          PlaylistController.inst.insertTracksInPlaylistWithEachIndex(
            playlist,
            twdAndIndexes,
          );
        },
      );
    }
  }

  void onSubPageTracksSortIconTap(MediaType media) {
    const defaultSorts = <MediaType, List<SortType>>{
      MediaType.album: [SortType.trackNo, SortType.year, SortType.title],
      MediaType.artist: [SortType.year, SortType.title],
      MediaType.genre: [SortType.year, SortType.title],
      MediaType.folder: [SortType.filename],
      MediaType.folderVideo: [SortType.filename],
    };
    return _onSubPageSortIconTap<SortType>(
      minimumItems: 1,
      allSortsList: List<SortType>.from(SortType.values),
      sortToText: (sort) => sort.toText(),
      defaultSorts: defaultSorts[media] ?? [SortType.year],
      currentSorts: settings.mediaItemsTrackSorting.value[media] ?? [],
      currentReverse: settings.mediaItemsTrackSortingReverse.value[media] ?? false,
      allowCustom: false,
      onSortChange: (activeSorters) {
        settings.updateMediaItemsTrackSorting(media, activeSorters);
      },
      onSortReverseChange: (reverse) {
        settings.updateMediaItemsTrackSortingReverse(media, reverse);
      },
      onDone: () {
        Indexer.inst.sortMediaTracksSubLists([media]);
      },
    );
  }

  void onPlaylistSubPageTracksSortIconTap<T extends PlaylistItemWithDate, E, S>(
    String playlistName,
    PlaylistManager<T, E, S> playlistManager,
    List<S> allSorts,
    String Function(S sort) sortToText,
  ) {
    final initialpl = playlistManager.getPlaylist(playlistName);
    List<S>? newSorts;
    bool? newSortReverse;

    void onFinalUpdatePropertySort(List<S> sorts, bool? reverse) {
      playlistManager.updatePropertyInPlaylist(playlistName, itemsSortType: sorts, itemsSortReverse: reverse);
      playlistManager.resetCanReorder();
    }

    return _onSubPageSortIconTap<S>(
      minimumItems: 0,
      defaultSorts: [],
      allSortsList: List<S>.from(allSorts),
      sortToText: sortToText,
      currentSorts: initialpl?.sortsType ?? [],
      currentReverse: initialpl?.sortReverse ?? false,
      allowCustom: false,
      onSortChange: (activeSorters) {
        newSorts = activeSorters;
      },
      onSortReverseChange: (reverse) {
        newSortReverse = reverse;
        final pl = playlistManager.getPlaylist(playlistName);
        if (pl != null && pl.sortReverse != reverse) {
          playlistManager.updatePropertyInPlaylist(playlistName, itemsSortReverse: reverse);
        }
      },
      onDone: () {
        final pl = playlistManager.getPlaylist(playlistName);
        if (pl != null && newSorts != null) {
          if (!listEquals(pl.sortsType, newSorts)) {
            if ((pl.sortsType?.isEmpty ?? true) && newSorts!.isNotEmpty) {
              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  isWarning: true,
                  normalTitleStyle: true,
                  bodyText: lang.YOUR_CUSTOM_ORDER_WILL_BE_LOST,
                  actions: [
                    const CancelButton(),
                    NamidaButton(
                      text: lang.CONFIRM,
                      onPressed: () {
                        onFinalUpdatePropertySort(newSorts!, newSortReverse);
                        NamidaNavigator.inst.closeDialog();
                      },
                    )
                  ],
                ),
              );
            } else {
              onFinalUpdatePropertySort(newSorts!, newSortReverse);
            }
          }
        }
      },
    );
  }

  void _onSubPageSortIconTap<S>({
    required List<S> currentSorts,
    required List<S> allSortsList,
    required bool currentReverse,
    required List<S> defaultSorts,
    required int minimumItems,
    required String Function(S sort) sortToText,
    required bool allowCustom,
    required void Function(List<S> activeSorters) onSortChange,
    required void Function(bool reverse) onSortReverseChange,
    required void Function() onDone,
  }) {
    final sorters = List<S>.from(currentSorts).obs;
    final isReverse = currentReverse.obs;

    final allSorts = allSortsList.obs;

    void resortVisualItems() => allSorts.sortByReverse((e) {
          final active = sorters.contains(e);
          return active ? sorters.length - sorters.value.indexOf(e) : sorters.value.indexOf(e);
        });

    resortVisualItems();

    void resortMedia() {
      onSortChange(sorters.value);
      onDone();
    }

    NamidaNavigator.inst.navigateDialog(
      scale: 1.0,
      onDisposing: () {
        sorters.close();
        allSorts.close();
      },
      onDismissing: resortMedia,
      dialog: CustomBlurryDialog(
        title: "${lang.SORT_BY} (${lang.REORDERABLE})",
        actions: [
          IconButton(
            icon: const Icon(Broken.refresh),
            tooltip: lang.RESTORE_DEFAULTS,
            onPressed: () {
              sorters.value = defaultSorts;
              onSortChange(defaultSorts);
            },
          ),
          DoneButton(additional: resortMedia),
        ],
        child: SizedBox(
          width: namida.width,
          height: namida.height * 0.4,
          child: Column(
            children: [
              ObxO(
                rx: isReverse,
                builder: (context, reverse) => ListTileWithCheckMark(
                  title: lang.REVERSE_ORDER,
                  active: reverse,
                  onTap: () {
                    onSortReverseChange(!reverse);
                    isReverse.value = !reverse;
                  },
                ),
              ),
              const SizedBox(height: 12.0),
              Expanded(
                child: Obx(
                  (context) => NamidaListView(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    itemCount: allSorts.length,
                    itemExtent: null,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex -= 1;
                      allSorts.value.move(oldIndex, newIndex);
                      allSorts.refresh();

                      final activeSorts = allSorts.where((element) => sorters.contains(element)).toList();
                      sorters.value = activeSorts;
                      onSortChange(activeSorts);
                    },
                    itemBuilder: (context, i) {
                      final sorting = allSorts[i];
                      return Padding(
                        key: ValueKey(i),
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                        child: Obx(
                          (context) {
                            final isActive = sorters.contains(sorting);
                            return ListTileWithCheckMark(
                              title: "${i + 1}. ${sortToText(sorting)}",
                              active: isActive,
                              onTap: () {
                                if (isActive && sorters.length <= minimumItems) {
                                  showMinimumItemsSnack(minimumItems);
                                  return;
                                }
                                if (sorters.contains(sorting)) {
                                  sorters.remove(sorting);
                                } else {
                                  sorters.insertSafe(i, sorting);
                                }
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openEqualizer() {
    NamidaNavigator.inst.navigateToRoot(const EqualizerPage());
  }

  static Map<int, int> _getQueuesSize(String dir) {
    final map = <int, int>{};
    Directory(dir).listSync().loop((e) {
      try {
        if (e is File) map[int.parse(e.path.getFilenameWOExt)] = e.lengthSync();
      } catch (_) {}
    });
    return map;
  }

  void onQueuesClearIconTap() {
    final sizesLookupMap = <int, int>{}.obs;
    _getQueuesSize.thready(AppDirs.QUEUES).then((value) => sizesLookupMap.value = value);
    String getSubtitle(Map<int, int> lookup, List<int> datesList) {
      int total = 0;
      String? suffix;
      datesList.loop((e) {
        final size = lookup[e];
        if (size != null) {
          total += size;
        } else {
          suffix ??= '?';
        }
      });
      return "${total.fileSizeFormatted}${suffix ?? ''}";
    }

    final selectedToClear = <QueueSource>[].obs;
    final selectedHomepageItemToClear = <HomePageItems>[].obs;
    final values = List<QueueSource>.from(QueueSource.values);
    values.remove(QueueSource.homePageItem);

    final lookup = <QueueSourceBase, List<int>>{};
    final lookupHomepageItem = <HomePageItems, List<int>>{};
    final lookupNonFavourites = <int, bool>{};
    final map = QueueController.inst.queuesMap.value;
    for (final e in map.entries) {
      final queue = e.value;
      final date = queue.date;
      lookupNonFavourites[date] = !queue.isFav;
      final hpi = queue.homePageItem;
      if (hpi != null) {
        lookupHomepageItem.addForce(hpi, date);
      } else {
        lookup.addForce(queue.source, date);
      }
    }
    final nonFavourites = false.obs;

    final totalToRemove = 0.obs;
    void updateTotalToRemove() {
      int total = 0;
      if (nonFavourites.value) {
        total += lookupNonFavourites.values.where((v) => v).length;
        selectedToClear.loop((e) {
          total += lookup[e]?.where((element) => lookupNonFavourites[element] != true).length ?? 0;
        });
        selectedHomepageItemToClear.loop((e) {
          total += lookupHomepageItem[e]?.where((element) => lookupNonFavourites[element] != true).length ?? 0;
        });
      } else {
        selectedToClear.loop((e) {
          total += lookup[e]?.length ?? 0;
        });
        selectedHomepageItemToClear.loop((e) {
          total += lookupHomepageItem[e]?.length ?? 0;
        });
      }

      totalToRemove.value = total;
    }

    final isRemoving = false.obs;

    final nonFavouritesList = lookupNonFavourites.keys.where((v) => lookupNonFavourites[v] == true).toList();

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        selectedToClear.close();
        selectedHomepageItemToClear.close();
        nonFavourites.close();
        totalToRemove.close();
        isRemoving.close();
      },
      dialog: CustomBlurryDialog(
        title: lang.CLEAR,
        actions: [
          const CancelButton(),
          const SizedBox(width: 8.0),
          Obx(
            (context) => NamidaButton(
              enabled: !isRemoving.valueR && totalToRemove.valueR > 0,
              textWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRemoving.valueR) ...[
                    const LoadingIndicator(),
                    const SizedBox(width: 8.0),
                  ],
                  Text("${lang.DELETE} (${totalToRemove.valueR})"),
                ],
              ),
              onPressed: () async {
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    isWarning: true,
                    normalTitleStyle: true,
                    bodyText: "${lang.DELETE} ${totalToRemove.value}?",
                    actions: [
                      const CancelButton(),
                      const SizedBox(width: 8.0),
                      NamidaButton(
                        text: lang.DELETE.toUpperCase(),
                        onPressed: () async {
                          NamidaNavigator.inst.closeDialog();
                          isRemoving.value = true;
                          if (nonFavourites.value) {
                            await QueueController.inst.removeQueues(nonFavouritesList);
                          }
                          for (final s in selectedToClear.value) {
                            final queues = lookup[s];
                            if (queues != null) await QueueController.inst.removeQueues(queues);
                          }
                          for (final s in selectedHomepageItemToClear.value) {
                            final queues = lookupHomepageItem[s];
                            if (queues != null) await QueueController.inst.removeQueues(queues);
                          }
                          isRemoving.value = false;
                          NamidaNavigator.inst.closeDialog();
                        },
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        child: SizedBox(
          height: namida.height * 0.6,
          width: namida.width,
          child: Obx(
            (context) {
              final sizesLookup = sizesLookupMap.valueR;
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: ListTileWithCheckMark(
                      dense: true,
                      icon: Broken.heart_slash,
                      title: '${lang.NON_FAVOURITES} (${nonFavouritesList.length})',
                      subtitle: getSubtitle(sizesLookup, nonFavouritesList),
                      active: nonFavourites.valueR,
                      onTap: () {
                        nonFavourites.toggle();
                        updateTotalToRemove();
                      },
                    ),
                  ),
                  const NamidaContainerDivider(margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0)),
                  ...values.map(
                    (e) {
                      final list = lookup[e];
                      return list != null && list.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(3.0),
                              child: ListTileWithCheckMark(
                                dense: true,
                                title: "${e.toText()} (${list.length})",
                                subtitle: getSubtitle(sizesLookup, list),
                                active: selectedToClear.contains(e),
                                onTap: () {
                                  selectedToClear.addOrRemove(e);
                                  updateTotalToRemove();
                                },
                              ),
                            )
                          : const SizedBox();
                    },
                  ),
                  const NamidaContainerDivider(margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0)),
                  ...HomePageItems.values.map(
                    (e) {
                      final list = lookupHomepageItem[e];
                      return list != null && list.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(3.0),
                              child: ListTileWithCheckMark(
                                dense: true,
                                title: "${e.toText()} (${list.length})",
                                subtitle: getSubtitle(sizesLookup, list),
                                active: selectedHomepageItemToClear.contains(e),
                                onTap: () {
                                  selectedHomepageItemToClear.addOrRemove(e);
                                  updateTotalToRemove();
                                },
                              ),
                            )
                          : const SizedBox();
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<PlaylistAddDuplicateAction?> showDuplicatedDialogAction(
    List<PlaylistAddDuplicateAction> duplicationActions, {
    bool displayTitle = true,
    PlaylistAddDuplicateAction? initiallySelected,
  }) async {
    final actionRx = Rxn<PlaylistAddDuplicateAction>(initiallySelected);
    PlaylistAddDuplicateAction? actionToUse;
    await NamidaNavigator.inst.navigateDialog(
      onDismissing: () {
        actionRx.close();
      },
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: lang.CONFIRM,
        actions: [
          TextButton(
            onPressed: NamidaNavigator.inst.closeDialog,
            child: NamidaButtonText(lang.CANCEL),
          ),
          ObxO(
            rx: actionRx,
            builder: (context, action) => NamidaButton(
              enabled: action != null,
              text: lang.CONFIRM,
              onPressed: () {
                actionToUse = actionRx.value;
                NamidaNavigator.inst.closeDialog();
              },
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (displayTitle)
                Text(
                  lang.DUPLICATED_ITEMS_ADDING,
                  style: namida.textTheme.displayMedium,
                ),
              if (displayTitle) const SizedBox(height: 12.0),
              Column(
                children: duplicationActions
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: ObxO(
                          rx: actionRx,
                          builder: (context, act) => ListTileWithCheckMark(
                            active: act == e,
                            title: e.toText(),
                            onTap: () => actionRx.value = e,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
    return actionToUse;
  }
}

Future<void> showCalendarDialog<T extends ItemWithDate, E>({
  required String title,
  required String buttonText,
  CalendarDatePicker2Type calendarType = CalendarDatePicker2Type.range,
  DateTime? firstDate,
  DateTime? lastDate,
  required bool useHistoryDates,
  HistoryManager<T, E>? historyController,
  void Function(List<DateTime> dates)? onChanged,
  required void Function(List<DateTime> dates) onGenerate,
  DateTime? initialDate,
}) async {
  historyController ??= HistoryController.inst as HistoryManager<T, E>;

  final dates = <DateTime>[];

  final daysNumber = 0.obs;
  final canGenerate = false.obs;

  void calculateDaysNumber() {
    if (canGenerate.value) {
      if (dates.length == 2) {
        daysNumber.value = dates[0].difference(dates[1]).inDays.abs() + 1;
      }
    } else {
      daysNumber.value = 0;
    }
  }

  void reEvaluateCanGenerate() {
    switch (calendarType) {
      case CalendarDatePicker2Type.range:
        canGenerate.value = dates.length == 2;
      case CalendarDatePicker2Type.single:
        canGenerate.value = dates.length == 1;
      case CalendarDatePicker2Type.multi:
        canGenerate.value = true;
    }
  }

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      daysNumber.close();
      canGenerate.close();
    },
    scale: 0.90,
    dialog: CustomBlurryDialog(
      titleWidgetInPadding: Obx(
        (context) => Text(
          '$title ${daysNumber.valueR == 0 ? '' : "(${daysNumber.valueR.displayDayKeyword})"}',
          style: namida.textTheme.displayLarge,
        ),
      ),
      normalTitleStyle: true,
      horizontalInset: 28.0,
      actions: [
        const CancelButton(),
        Obx(
          (context) => NamidaButton(
            enabled: canGenerate.valueR,
            onPressed: () => onGenerate(dates),
            text: buttonText,
          ),
        ),
      ],
      child: CalendarDatePicker2(
        displayedMonthDate: initialDate,
        onValueChanged: (value) {
          final dts = value.whereType<DateTime>().toList();
          dates.assignAll(dts);

          if (onChanged != null) onChanged(dts);

          reEvaluateCanGenerate();
          calculateDaysNumber();
        },
        config: CalendarDatePicker2Config(
          calendarType: calendarType,
          currentDate: initialDate,
          firstDate: useHistoryDates ? historyController.oldestTrack?.dateAddedMS.milliSecondsSinceEpoch : firstDate,
          lastDate: useHistoryDates ? historyController.newestTrack?.dateAddedMS.milliSecondsSinceEpoch : lastDate,
        ),
        value: const [],
      ),
    ),
  );
}

class BottomSheetTextFieldConfig {
  final String? initalControllerText;
  final String hintText;
  final String labelText;
  final int? maxLength;
  final String? Function(String? value)? validator;

  const BottomSheetTextFieldConfig({
    this.initalControllerText,
    required this.hintText,
    required this.labelText,
    this.maxLength,
    required this.validator,
  });
}

class BottomSheetTextFieldConfigWC extends BottomSheetTextFieldConfig {
  final TextEditingController controller;

  const BottomSheetTextFieldConfigWC({
    required this.controller,
    required super.hintText,
    required super.labelText,
    super.maxLength,
    required super.validator,
  }) : super(initalControllerText: null);
}

Future<String?> showNamidaBottomSheetWithTextField({
  required BuildContext context,
  bool isScrollControlled = true,
  bool useRootNavigator = true,
  bool showDragHandle = true,
  required String title,
  String? subtitle,
  required BottomSheetTextFieldConfig textfieldConfig,
  List<BottomSheetTextFieldConfigWC>? extraTextfieldsConfig,
  required String buttonText,
  TextStyle? buttonTextStyle,
  Color? buttonColor,
  required FutureOr<bool> Function(String text) onButtonTap,
  Widget Function(FormState formState)? extraItemsBuilder,
  Widget Function(FormState formState)? extraPreItemsBuilder,
  Rx<bool>? isInitiallyLoading,
  bool displayAccountThumbnail = false,
}) async {
  final localController = textfieldConfig is BottomSheetTextFieldConfigWC ? textfieldConfig.controller : TextEditingController(text: textfieldConfig.initalControllerText);
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final focusNode = FocusNode();
  focusNode.requestFocus();

  String? finalText;

  await Future.delayed(Duration.zero); // delay bcz sometimes doesnt show
  await showModalBottomSheet(
    // ignore: use_build_context_synchronously
    context: context,
    useRootNavigator: useRootNavigator,
    showDragHandle: showDragHandle,
    isScrollControlled: isScrollControlled,
    builder: (context) {
      final bottomPadding = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
      final child = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0).add(EdgeInsets.only(bottom: 18.0 + bottomPadding)),
        child: Form(
          key: formKey,
          child: NamidaLoadingSwitcher(
            builder: (loadingController) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: context.textTheme.displayLarge,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: context.textTheme.displaySmall,
                    ),
                  if (subtitle != null) const SizedBox(height: 6.0),
                  const SizedBox(height: 18.0),
                  if (extraPreItemsBuilder != null) extraPreItemsBuilder(formKey.currentState!),
                  Row(
                    children: [
                      if (displayAccountThumbnail)
                        ObxO(
                          rx: YoutubeAccountController.current.activeAccountChannel,
                          builder: (context, acc) => acc == null
                              ? const SizedBox()
                              : YoutubeThumbnail(
                                  type: ThumbnailType.channel,
                                  key: Key(acc.id),
                                  width: 32.0,
                                  forceSquared: false,
                                  isImportantInCache: true,
                                  customUrl: acc.thumbnails.pick()?.url,
                                  isCircle: true,
                                ),
                        ),
                      if (displayAccountThumbnail) const SizedBox(width: 12.0),
                      Expanded(
                        child: CustomTagTextField(
                          focusNode: focusNode,
                          controller: localController,
                          hintText: textfieldConfig.hintText,
                          labelText: textfieldConfig.labelText,
                          validator: textfieldConfig.validator,
                          maxLength: textfieldConfig.maxLength,
                        ),
                      ),
                    ],
                  ),
                  ...?extraTextfieldsConfig?.map(
                    (e) {
                      return CustomTagTextField(
                        controller: e.controller,
                        hintText: e.hintText,
                        labelText: e.labelText,
                        validator: e.validator,
                        maxLength: e.maxLength,
                      );
                    },
                  ),
                  if (extraItemsBuilder != null) extraItemsBuilder(formKey.currentState!),
                  const SizedBox(height: 18.0),
                  Row(
                    children: [
                      SizedBox(width: context.width * 0.1),
                      CancelButton(onPressed: context.safePop),
                      SizedBox(width: context.width * 0.1),
                      Expanded(
                        child: NamidaInkWell(
                          borderRadius: 12.0,
                          padding: const EdgeInsets.all(12.0),
                          height: 48.0,
                          bgColor: buttonColor ?? CurrentColor.inst.color,
                          decoration: const BoxDecoration(),
                          child: Center(
                            child: Text(
                              buttonText,
                              style: buttonTextStyle ?? context.textTheme.displayMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                            ),
                          ),
                          onTap: () async {
                            if (formKey.currentState!.validate()) {
                              loadingController.startLoading();
                              final didAgree = await onButtonTap(localController.text);
                              loadingController.stopLoading();
                              if (didAgree) {
                                finalText = localController.text;
                                if (context.mounted) context.safePop();
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return isInitiallyLoading != null
          ? ObxO(
              rx: isInitiallyLoading,
              builder: (context, initiallyLoading) {
                return Stack(
                  children: [
                    AnimatedEnabled(
                      enabled: !initiallyLoading,
                      child: child,
                    ),
                    if (initiallyLoading)
                      const Positioned(
                        top: 0,
                        right: 32.0,
                        child: SizedBox(
                          width: 32.0,
                          height: 32.0,
                          child: CircularProgressIndicator(strokeWidth: 4.0),
                        ),
                      ),
                  ],
                );
              },
            )
          : child;
    },
  );
  Future.delayed(const Duration(milliseconds: 2000), () {
    if (localController.runtimeType == BottomSheetTextFieldConfig) localController.dispose();
    focusNode.dispose();
  });
  return finalText;
}

// Returns a [0-1] scale representing how much similar both are.
double checkIfListsSimilar<E>(List<E> q1, List<E> q2, {bool fullyFunctional = false}) {
  if (fullyFunctional) {
    if (q1.isEmpty && q2.isEmpty) {
      return 1.0;
    }
    final finallength = q1.length > q2.length ? q2.length : q1.length;
    int trueconditions = 0;
    for (int i = 0; i < finallength; i++) {
      if (q1[i] == q2[i]) trueconditions++;
    }
    return trueconditions / finallength;
  } else {
    return q1.isEqualTo(q2) ? 1.0 : 0.0;
  }
}

/// **takes:**
/// ```
/// {
///   'allAvailableDirectories': <Directory, bool>{},
///   'directoriesToExclude': <String>[],
///   'extensions': <String>{},
///   'imageExtensions': <String>{},
///   'respectNoMedia': bool ?? true,
/// }
/// ```
///
/// **returns:**
/// ```
/// {
/// 'allPaths': <String>{},
/// 'pathsExcludedByNoMedia': <String>{},
/// 'folderCovers': <String, String>{},
/// }
/// ```
Map<String, Object> getFilesTypeIsolate(Map parameters) {
  final allAvailableDirectories = parameters['allAvailableDirectories'] as Map<Directory, bool>;
  final directoriesToExclude = parameters['directoriesToExclude'] as List<String>? ?? [];
  final extensions = parameters['extensions'] as NamidaFileExtensionsWrapper;
  final imageExtensions = parameters['imageExtensions'] as NamidaFileExtensionsWrapper?;
  final respectNoMedia = parameters['respectNoMedia'] as bool? ?? true;

  final allPaths = <String>{};
  final excludedByNoMedia = <String>{};
  final folderCovers = <String, String>{};

  final coversNames = imageExtensions != null && imageExtensions.extensions.isNotEmpty
      ? {
          "folder": true,
          "front": true,
          "cover": true,
          "thumbnail": true,
          "thumb": true,
          "album": true,
          "albumart": true,
          "albumartsmall": true,
        }
      : null;
  final fillFolderCovers = imageExtensions != null && coversNames != null;

  allAvailableDirectories.keys.toList().loop((d) {
    final hasNoMedia = allAvailableDirectories[d] ?? false;
    try {
      final allFiles = d.listSyncSafe();
      final allFilesLength = allFiles.length;
      for (int i = 0; i < allFilesLength; i++) {
        var systemEntity = allFiles[i];
        if (systemEntity is File) {
          final path = systemEntity.path;

          if (fillFolderCovers) {
            final dirPath = d.path;
            if (folderCovers[dirPath] == null) {
              if (imageExtensions.isPathValid(path)) {
                final filenameCleaned = path.getFilenameWOExt.toLowerCase();
                final isValidCover = coversNames[filenameCleaned] == true;
                if (isValidCover) folderCovers[dirPath] = path;

                continue;
              }
            }
          }

          // -- skips if the file is included in one of the excluded folders.
          if (directoriesToExclude.any((exc) => path.startsWith(exc))) {
            continue;
          }

          // -- skip if not in extensions
          if (!extensions.isPathValid(path)) {
            continue;
          }

          // -- skip if hidden
          if (path.getFilename.startsWith('.')) continue;

          // -- skip if in nomedia folder & specified to exclude
          if (respectNoMedia && hasNoMedia) {
            excludedByNoMedia.add(path);
            continue;
          }

          allPaths.add(path);
        }
      }
    } catch (_) {}
  });
  return {
    'allPaths': allPaths,
    'pathsExcludedByNoMedia': excludedByNoMedia,
    'folderCovers': folderCovers,
  };
}

class TracksAddOnTap {
  void onAddTracksTap(BuildContext context) {
    final currentTrackS = Player.inst.currentItem.value;
    if (currentTrackS is! Selectable) return;
    final currentTrack = currentTrackS.track;
    showAddItemsToQueueDialog(
      onDisposing: null,
      context: context,
      disabledSorts: null,
      tiles: (getAddTracksTile) {
        return [
          getAddTracksTile(
            title: lang.NEW_TRACKS_RANDOM,
            subtitle: lang.NEW_TRACKS_RANDOM_SUBTITLE,
            icon: Broken.format_circle,
            insertionType: QueueInsertionType.random,
            onTap: (insertionType) {
              final config = insertionType.toQueueInsertion();
              final count = config.numberOfTracks;
              final rt = NamidaGenerator.inst.getRandomTracks(exclude: currentTrack, min: count - 1, max: count);
              Player.inst.addToQueue(rt, insertionType: insertionType, emptyTracksMessage: lang.NO_ENOUGH_TRACKS).closeDialog();
            },
          ),
          getAddTracksTile(
            title: lang.GENERATE_FROM_DATES,
            subtitle: lang.GENERATE_FROM_DATES_SUBTITLE,
            icon: Broken.calendar,
            insertionType: QueueInsertionType.listenTimeRange,
            onTap: (insertionType) {
              NamidaNavigator.inst.closeDialog();
              final historyTracks = HistoryController.inst.historyTracks;
              if (historyTracks.isEmpty) {
                snackyy(title: lang.NOTE, message: lang.NO_TRACKS_IN_HISTORY);
                return;
              }
              showCalendarDialog(
                title: lang.GENERATE_FROM_DATES,
                buttonText: lang.GENERATE,
                useHistoryDates: true,
                onGenerate: (dates) {
                  final tracks = NamidaGenerator.inst.generateItemsFromHistoryDates(dates.firstOrNull, dates.lastOrNull);
                  Player.inst
                      .addToQueue(
                        tracks,
                        insertionType: insertionType,
                        emptyTracksMessage: lang.NO_TRACKS_FOUND_BETWEEN_DATES,
                      )
                      .closeDialog();
                },
              );
            },
          ),
          getAddTracksTile(
            title: lang.NEW_TRACKS_MOODS,
            subtitle: lang.NEW_TRACKS_MOODS_SUBTITLE,
            icon: Broken.emoji_happy,
            insertionType: QueueInsertionType.mood,
            onTap: (insertionType) async {
              NamidaNavigator.inst.closeDialog();

              // -- moods from playlists.
              final allAvailableMoodsPlaylists = <String, List<Track>>{};
              for (final pl in PlaylistController.inst.playlistsMap.value.entries) {
                pl.value.moods.loop((mood) {
                  allAvailableMoodsPlaylists.addAllNoDuplicatesForce(mood, pl.value.tracks.tracks);
                });
              }
              // -- moods from tracks.
              final allAvailableMoodsTracks = <String, List<Track>>{};
              for (final tr in Indexer.inst.trackStatsMap.value.entries) {
                tr.value.moods?.loop((mood) {
                  allAvailableMoodsTracks.addNoDuplicatesForce(mood, tr.key);
                });
              }

              // -- moods from track embedded tag
              allTracksInLibrary.loop((tr) {
                tr.moodList.loop((mood) {
                  allAvailableMoodsTracks.addNoDuplicatesForce(mood, tr);
                });
              });

              if (allAvailableMoodsPlaylists.isEmpty && allAvailableMoodsTracks.isEmpty) {
                snackyy(title: lang.ERROR, message: lang.NO_MOODS_AVAILABLE);
                return;
              }

              final playlistsAllMoods = allAvailableMoodsPlaylists.keys.toList();
              final tracksAllMoods = allAvailableMoodsTracks.keys.toList();

              final selectedmoodsPlaylists = <String>[].obs;
              final selectedmoodsTracks = <String>[].obs;

              List<Widget> getListy({
                required String title,
                required List<String> moodsList,
                required Map<String, List<Track>> allAvailableMoods,
                required RxList<String> selectedList,
              }) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text("$title (${moodsList.length})", style: context.textTheme.displayMedium),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Wrap(
                      children: [
                        ...moodsList.map(
                          (m) {
                            final tracksCount = allAvailableMoods[m]?.length ?? 0;
                            return NamidaInkWell(
                              borderRadius: 6.0,
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                              margin: const EdgeInsets.all(2.0),
                              bgColor: context.theme.cardColor,
                              onTap: () => selectedList.addOrRemove(m),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "$m ($tracksCount)",
                                    style: context.textTheme.displayMedium,
                                  ),
                                  const SizedBox(width: 8.0),
                                  Obx(
                                    (context) => NamidaCheckMark(
                                      size: 12.0,
                                      active: selectedList.valueR.contains(m),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ];
              }

              await NamidaNavigator.inst.navigateDialog(
                onDisposing: () {
                  selectedmoodsPlaylists.close();
                  selectedmoodsTracks.close();
                },
                dialog: CustomBlurryDialog(
                  normalTitleStyle: true,
                  horizontalInset: 48.0,
                  title: lang.MOODS,
                  actions: [
                    const CancelButton(),
                    NamidaButton(
                      text: lang.GENERATE,
                      onPressed: () {
                        final finalTracks = <Track>[];
                        selectedmoodsPlaylists.loop((m) {
                          finalTracks.addAll(allAvailableMoodsPlaylists[m] ?? []);
                        });
                        selectedmoodsTracks.loop((m) {
                          finalTracks.addAll(allAvailableMoodsTracks[m] ?? []);
                        });
                        Player.inst.addToQueue(
                          finalTracks.uniqued(),
                          insertionType: insertionType,
                        );
                        NamidaNavigator.inst.closeDialog();
                      },
                    ),
                  ],
                  child: SizedBox(
                    height: context.height * 0.4,
                    width: context.width,
                    child: CustomScrollView(
                      slivers: [
                        // -- Tracks moods (embedded & custom)
                        ...getListy(
                          title: lang.TRACKS,
                          moodsList: tracksAllMoods,
                          allAvailableMoods: allAvailableMoodsTracks,
                          selectedList: selectedmoodsTracks,
                        ),
                        // -- Playlist moods
                        ...getListy(
                          title: lang.PLAYLISTS,
                          moodsList: playlistsAllMoods,
                          allAvailableMoods: allAvailableMoodsPlaylists,
                          selectedList: selectedmoodsPlaylists,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          getAddTracksTile(
            title: lang.NEW_TRACKS_RATINGS,
            subtitle: lang.NEW_TRACKS_RATINGS_SUBTITLE,
            icon: Broken.happyemoji,
            insertionType: QueueInsertionType.rating,
            onTap: (insertionType) async {
              NamidaNavigator.inst.closeDialog();

              final minRating = 80.obs;
              final maxRating = 100.obs;
              await NamidaNavigator.inst.navigateDialog(
                onDisposing: () {
                  minRating.close();
                  maxRating.close();
                },
                dialog: CustomBlurryDialog(
                  normalTitleStyle: true,
                  title: lang.NEW_TRACKS_RATINGS,
                  actions: [
                    const CancelButton(),
                    NamidaButton(
                      text: lang.GENERATE,
                      onPressed: () {
                        if (minRating.value > maxRating.value) {
                          snackyy(title: lang.ERROR, message: lang.MIN_VALUE_CANT_BE_MORE_THAN_MAX);
                          return;
                        }
                        final tracks = NamidaGenerator.inst.generateTracksFromRatings(
                          minRating.value,
                          maxRating.value,
                        );
                        Player.inst.addToQueue(tracks, insertionType: insertionType);
                        NamidaNavigator.inst.closeDialog();
                      },
                    ),
                  ],
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(lang.MINIMUM),
                              const SizedBox(height: 24.0),
                              NamidaWheelSlider(
                                max: 100,
                                initValue: minRating.value,
                                onValueChanged: (val) => minRating.value = val,
                              ),
                              const SizedBox(height: 2.0),
                              Obx(
                                (context) => Text(
                                  '${minRating.valueR}%',
                                  style: context.textTheme.displaySmall,
                                ),
                              )
                            ],
                          ),
                          Column(
                            children: [
                              Text(lang.MAXIMUM),
                              const SizedBox(height: 24.0),
                              NamidaWheelSlider(
                                max: 100,
                                initValue: maxRating.value,
                                onValueChanged: (val) => maxRating.value = val,
                              ),
                              const SizedBox(height: 2.0),
                              Obx(
                                (context) => Text(
                                  '${maxRating.valueR}%',
                                  style: context.textTheme.displaySmall,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 4.0)),
          getAddTracksTile(
            title: lang.NEW_TRACKS_SIMILARR_RELEASE_DATE,
            subtitle: lang.NEW_TRACKS_SIMILARR_RELEASE_DATE_SUBTITLE.replaceFirst(
              '_CURRENT_TRACK_',
              currentTrack.title.addDQuotation(),
            ),
            icon: Broken.calendar_1,
            insertionType: QueueInsertionType.sameReleaseDate,
            onTap: (insertionType) {
              final year = currentTrack.year;
              if (year == 0) {
                snackyy(title: lang.ERROR, message: lang.NEW_TRACKS_UNKNOWN_YEAR);
                return;
              }
              final tracks = NamidaGenerator.inst.generateTracksFromSameEra(year, currentTrack: currentTrack);
              Player.inst
                  .addToQueue(
                    tracks,
                    insertionType: insertionType,
                    emptyTracksMessage: lang.NO_TRACKS_FOUND_BETWEEN_DATES,
                  )
                  .closeDialog();
            },
          ),
          getAddTracksTile(
            title: lang.NEW_TRACKS_RECOMMENDED,
            subtitle: lang.NEW_TRACKS_RECOMMENDED_SUBTITLE.replaceFirst(
              '_CURRENT_TRACK_',
              currentTrack.title.addDQuotation(),
            ),
            icon: Broken.bezier,
            insertionType: QueueInsertionType.algorithm,
            onTap: (insertionType) {
              final gentracks = NamidaGenerator.inst.generateRecommendedTrack(currentTrack);

              Player.inst
                  .addToQueue(
                    gentracks,
                    insertionType: insertionType,
                    insertNext: true,
                    emptyTracksMessage: lang.NO_TRACKS_IN_HISTORY,
                  )
                  .closeDialog();
            },
          ),
        ];
      },
    );
  }

  void onAddVideosTap(BuildContext context) {
    final currentVideo = Player.inst.currentVideo;
    if (currentVideo == null) return;
    final currentVideoId = currentVideo.id;
    final currentVideoName = YoutubeInfoController.utils.getVideoName(currentVideoId) ?? currentVideoId;

    final isLoadingVideoDate = false.obs;
    final isLoadingMixPlaylist = false.obs;

    NamidaYTGenerator.inst.initialize();
    showAddItemsToQueueDialog(
      onDisposing: () {
        isLoadingVideoDate.close();
        isLoadingMixPlaylist.close();
      },
      disabledSorts: () => [
        InsertionSortingType.rating, // cuz we have no rating system for yt
      ],
      context: context,
      tiles: (getAddTracksTile) {
        return [
          Obx(
            (context) {
              final isLoading = NamidaYTGenerator.inst.didPrepareResources.valueR == false;
              return AnimatedEnabled(
                enabled: !isLoading,
                child: getAddTracksTile(
                  title: lang.NEW_TRACKS_RANDOM,
                  subtitle: lang.NEW_TRACKS_RANDOM_SUBTITLE,
                  icon: Broken.format_circle,
                  insertionType: QueueInsertionType.random,
                  onTap: (insertionType) async {
                    final config = insertionType.toQueueInsertion();
                    final count = config.numberOfTracks;
                    final rt = await NamidaYTGenerator.inst.getRandomVideos(exclude: currentVideoId, min: count - 1, max: count);
                    Player.inst.addToQueue(rt, insertionType: insertionType, emptyTracksMessage: lang.NO_ENOUGH_TRACKS).closeDialog();
                  },
                  trailingRaw: isLoading ? const LoadingIndicator() : null,
                ),
              );
            },
          ),
          getAddTracksTile(
            title: lang.GENERATE_FROM_DATES,
            subtitle: lang.GENERATE_FROM_DATES_SUBTITLE,
            icon: Broken.calendar,
            insertionType: QueueInsertionType.listenTimeRange,
            onTap: (insertionType) {
              NamidaNavigator.inst.closeDialog();
              final historyTracks = YoutubeHistoryController.inst.historyTracks;
              if (historyTracks.isEmpty) {
                snackyy(title: lang.NOTE, message: lang.NO_TRACKS_IN_HISTORY);
                return;
              }
              showCalendarDialog(
                title: lang.GENERATE_FROM_DATES,
                buttonText: lang.GENERATE,
                useHistoryDates: true,
                historyController: YoutubeHistoryController.inst,
                onGenerate: (dates) {
                  final videos = NamidaYTGenerator.inst.generateItemsFromHistoryDates(dates.firstOrNull, dates.lastOrNull);
                  Player.inst
                      .addToQueue(
                        videos,
                        insertionType: insertionType,
                        emptyTracksMessage: lang.NO_TRACKS_FOUND_BETWEEN_DATES,
                      )
                      .closeDialog();
                },
              );
            },
          ),
          ObxO(
            rx: isLoadingMixPlaylist,
            builder: (context, isLoading) => AnimatedEnabled(
              enabled: !isLoading,
              child: getAddTracksTile(
                title: lang.MIX,
                subtitle: lang.MIX_PLAYLIST_GENERATED_BY_YOUTUBE,
                icon: Broken.radar_1,
                insertionType: QueueInsertionType.mix,
                onTap: (insertionType) async {
                  isLoadingMixPlaylist.value = true;
                  final mixPlaylist = await YoutubeInfoController.playlist.getMixPlaylist(
                    videoId: currentVideoId,
                    details: ExecuteDetails.forceRequest(),
                  );
                  isLoadingMixPlaylist.value = false;

                  if (Player.inst.currentVideo?.id != currentVideoId) return;

                  final playlistId = mixPlaylist?.mixId;
                  final items = mixPlaylist?.items;
                  if (items != null && items.isNotEmpty) {
                    final videos = (items.firstOrNull?.id == currentVideoId ? items.skip(1) : items).map(
                      (e) => YoutubeID(id: e.id, playlistID: playlistId == null ? null : PlaylistID(id: playlistId)),
                    );
                    Player.inst
                        .addToQueue(
                          videos,
                          insertNext: true,
                          insertionType: insertionType,
                          emptyTracksMessage: lang.FAILED,
                        )
                        .closeDialog();
                  }
                },
                trailingRaw: isLoading ? const LoadingIndicator() : null,
              ),
            ),
          ),
          const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 4.0)),
          Obx(
            (context) {
              final isLoading = isLoadingVideoDate.valueR || NamidaYTGenerator.inst.didPrepareResources.valueR == false;
              return AnimatedEnabled(
                enabled: !isLoading,
                child: getAddTracksTile(
                  title: lang.NEW_TRACKS_SIMILARR_RELEASE_DATE,
                  subtitle: lang.NEW_TRACKS_SIMILARR_RELEASE_DATE_SUBTITLE.replaceFirst(
                    '_CURRENT_TRACK_',
                    currentVideoName.addDQuotation(),
                  ),
                  icon: Broken.calendar_1,
                  insertionType: QueueInsertionType.sameReleaseDate,
                  onTap: (insertionType) async {
                    DateTime? date = YoutubeInfoController.utils.getVideoReleaseDate(currentVideoId);
                    if (date == null) {
                      isLoadingVideoDate.value = true;
                      final info = await YoutubeInfoController.video.fetchVideoStreams(currentVideoId, forceRequest: false);
                      date = info?.info?.publishedAt.accurateDate ?? info?.info?.publishDate.accurateDate;
                      date ??= info?.info?.publishedAt.date ?? info?.info?.publishDate.date;
                      isLoadingVideoDate.value = false;
                    }
                    if (date == null) {
                      snackyy(message: 'failed to fetch video date', isError: true, title: lang.ERROR);
                      return;
                    }
                    final videos = await NamidaYTGenerator.inst.generateVideoFromSameEra(currentVideoId, date, videoToRemove: currentVideoId);
                    Player.inst
                        .addToQueue(
                          videos,
                          insertionType: insertionType,
                          emptyTracksMessage: lang.NO_TRACKS_FOUND_BETWEEN_DATES,
                        )
                        .closeDialog();
                  },
                  trailingRaw: isLoading ? const LoadingIndicator() : null,
                ),
              );
            },
          ),
          getAddTracksTile(
            title: lang.NEW_TRACKS_RECOMMENDED,
            subtitle: lang.NEW_TRACKS_RECOMMENDED_SUBTITLE.replaceFirst(
              '_CURRENT_TRACK_',
              currentVideoName.addDQuotation(),
            ),
            icon: Broken.bezier,
            insertionType: QueueInsertionType.algorithm,
            onTap: (insertionType) {
              final genvideos = NamidaYTGenerator.inst.generateRecommendedVideos(currentVideo);

              Player.inst
                  .addToQueue(
                    genvideos,
                    insertionType: insertionType,
                    insertNext: true,
                    emptyTracksMessage: lang.NO_TRACKS_IN_HISTORY,
                  )
                  .closeDialog();
            },
          ),
        ];
      },
    );
  }

  Future<void> showAddItemsToQueueDialog({
    required BuildContext context,
    required void Function()? onDisposing,
    required List<InsertionSortingType> Function()? disabledSorts,
    required List<Widget> Function(
            Widget Function({
              required String title,
              required String subtitle,
              required IconData icon,
              required QueueInsertionType insertionType,
              required void Function(QueueInsertionType insertionType) onTap,
              Widget? trailingRaw,
            }) addTracksTile)
        tiles,
  }) async {
    final shouldShowConfigureIcon = false.obs;

    void openQueueInsertionConfigure(QueueInsertionType insertionType, String title) async {
      final qinsertion = insertionType.toQueueInsertion();
      final tracksNo = qinsertion.numberOfTracks.obs;
      final insertN = qinsertion.insertNext.obs;
      final sortBy = qinsertion.sortBy.obs;
      final maxCount = 200.withMaximum(allTracksInLibrary.length);
      await NamidaNavigator.inst.navigateDialog(
        onDisposing: () {
          tracksNo.close();
          insertN.close();
          sortBy.close();
        },
        dialog: CustomBlurryDialog(
          title: lang.CONFIGURE,
          actions: [
            const CancelButton(),
            NamidaButton(
              text: lang.SAVE,
              onPressed: () {
                settings.updateQueueInsertion(
                  insertionType,
                  QueueInsertion(
                    numberOfTracks: tracksNo.value,
                    insertNext: insertN.value,
                    sortBy: sortBy.value,
                  ),
                );
                NamidaNavigator.inst.closeDialog();
              },
            )
          ],
          child: Column(
            children: [
              NamidaInkWell(
                borderRadius: 10.0,
                bgColor: context.theme.cardColor,
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Text(title, style: context.textTheme.displayLarge),
              ),
              const SizedBox(height: 24.0),
              CustomListTile(
                icon: Broken.computing,
                title: lang.NUMBER_OF_TRACKS,
                subtitle: "${lang.UNLIMITED}-$maxCount",
                trailing: Obx(
                  (context) => NamidaWheelSlider(
                    max: maxCount,
                    initValue: tracksNo.valueR,
                    onValueChanged: (val) => tracksNo.value = val,
                    text: tracksNo.valueR == 0 ? lang.UNLIMITED : '${tracksNo.valueR}',
                  ),
                ),
              ),
              Obx(
                (context) => CustomSwitchListTile(
                  icon: Broken.next,
                  title: lang.PLAY_NEXT,
                  value: insertN.valueR,
                  onChanged: (isTrue) => insertN.value = !isTrue,
                ),
              ),
              CustomListTile(
                icon: Broken.sort,
                title: lang.SORT_BY,
                trailingRaw: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: 0, maxWidth: context.width * 0.34),
                  child: FittedBox(
                    child: PopupMenuButton<InsertionSortingType>(
                      child: Obx(
                        (context) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(sortBy.valueR.toIcon(), size: 18.0),
                            const SizedBox(width: 8.0),
                            Text(sortBy.valueR.toText()),
                          ],
                        ),
                      ),
                      itemBuilder: (context) {
                        final disabledOnes = disabledSorts != null ? disabledSorts() : null;
                        final iterables = disabledOnes == null || disabledOnes.isEmpty
                            ? InsertionSortingType.values
                            : InsertionSortingType.values.where((element) => !disabledOnes.contains(element));
                        return iterables
                            .map(
                              (e) => PopupMenuItem(
                                value: e,
                                child: Row(
                                  children: [
                                    Icon(e.toIcon(), size: 20.0),
                                    const SizedBox(width: 8.0),
                                    Text(e.toText()),
                                  ],
                                ),
                              ),
                            )
                            .toList();
                      },
                      onSelected: (value) => sortBy.value = value,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget getAddTracksTile({
      required String title,
      required String subtitle,
      required IconData icon,
      required QueueInsertionType insertionType,
      required void Function(QueueInsertionType insertionType) onTap,
      Widget? trailingRaw,
    }) {
      return CustomListTile(
        title: title,
        subtitle: subtitle,
        icon: icon,
        maxSubtitleLines: 22,
        visualDensity: VisualDensity.compact,
        onTap: () => onTap(insertionType),
        trailingRaw: trailingRaw ??
            Obx(
              (context) => NamidaIconButton(
                icon: Broken.setting_4,
                onPressed: () => openQueueInsertionConfigure(insertionType, title),
              ).animateEntrance(
                showWhen: shouldShowConfigureIcon.valueR,
                durationMS: 200,
              ),
            ),
      );
    }

    await NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        onDisposing?.call();
        shouldShowConfigureIcon.close();
      },
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: lang.NEW_TRACKS_ADD,
        trailingWidgets: [
          NamidaIconButton(
            icon: Broken.setting_3,
            tooltip: () => lang.CONFIGURE,
            onPressed: shouldShowConfigureIcon.toggle,
          ),
        ],
        child: Column(children: tiles(getAddTracksTile)),
      ),
    );
  }
}

class SussyBaka {
  static void monetize({required void Function() onEnable}) {
    if (settings.didSupportNamida) return onEnable();
    final membership = YoutubeAccountController.membership.userMembershipTypeGlobal.value;
    if (membership != null && membership.index >= MembershipType.cutie.index) return onEnable();
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: 'uwu',
        actions: const [NamidaSupportButton()],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DoubleTapDetector(
              onDoubleTap: () => settings.save(didSupportNamida: true),
              child: const Text('a- ano...'),
            ),
            const Text(
              'this one is actually supposed to be for supporters, if you don\'t mind u can support namida and get the power to unleash this cool feature',
            ),
            TapDetector(
              onTap: () {
                NamidaNavigator.inst.closeDialog();
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    normalTitleStyle: true,
                    title: '!!',
                    bodyText: "EH? YOU DON'T WANT TO SUPPORT?",
                    actions: [
                      NamidaSupportButton(title: lang.YES),
                      NamidaButton(
                        text: lang.NO,
                        onPressed: () {
                          NamidaNavigator.inst.closeDialog();
                          NamidaNavigator.inst.navigateDialog(
                            dialog: CustomBlurryDialog(
                              title: 'kechi',
                              bodyText: 'hidoii ಥ_ಥ here use it as much as u can, dw im not upset or anything ^^, or am i?',
                              actions: [
                                NamidaButton(
                                  text: lang.UNLOCK.toUpperCase(),
                                  onPressed: () {
                                    NamidaNavigator.inst.closeDialog();
                                    onEnable();
                                  },
                                ),
                                NamidaButton(
                                  text: lang.SUPPORT.toUpperCase(),
                                  onPressed: () {
                                    NamidaNavigator.inst.closeDialog();
                                    NamidaLinkUtils.openLink(AppSocial.DONATE_BUY_ME_A_COFFEE);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
              child: const Text('or you just wanna use it like that? mattaku'),
            )
          ],
        ),
      ),
    );
  }
}
