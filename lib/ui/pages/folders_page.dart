import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'package:namida/base/tracks_search_widget_mixin.dart';
import 'package:namida/base/tracks_search_wrapper.dart';
import 'package:namida/class/folder.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/sort_chain.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/folder_tile.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/library_tab_variant_chip.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class FoldersPage<T extends Track, F extends Folder> extends StatefulWidget with NamidaRouteWidget {
  @override
  String? get name => foldersController.currentFolder.value?.path;

  @override
  final RouteType route;
  final FoldersController foldersController;
  final LibraryTab tab;
  final MediaType Function() mediaType;
  final FoldersPageConfig config;
  final QueueSource Function(String? name) _queueSource;

  const FoldersPage._(
    this._queueSource, {
    super.key,
    required this.route,
    required this.foldersController,
    required this.tab,
    required this.mediaType,
    required this.config,
  });

  factory FoldersPage.tracksAndVideos({Key? key}) => FoldersPage._(
    QueueSource.folder,
    key: key,
    route: RouteType.PAGE_folders,
    foldersController: FoldersController.tracksAndVideos,
    tab: LibraryTab.folders,
    mediaType: () => MediaType.folder,
    config: FoldersPageConfig.tracksAndVideos(),
  );

  factory FoldersPage.tracks({Key? key}) => FoldersPage._(
    QueueSource.folderMusic,
    key: key,
    route: RouteType.PAGE_folders_music,
    foldersController: FoldersController.tracks,
    tab: LibraryTab.foldersMusic,
    mediaType: () => MediaType.folderMusic,
    config: FoldersPageConfig.tracks(),
  );

  factory FoldersPage.videos({Key? key}) => FoldersPage._(
    QueueSource.folderVideos,
    key: key,
    route: RouteType.PAGE_folders_videos,
    foldersController: FoldersController.videos,
    tab: LibraryTab.foldersVideos,
    mediaType: () => MediaType.folderVideo,
    config: FoldersPageConfig.videos(),
  );

  @override
  State<FoldersPage<T, F>> createState() => _FoldersPageState<T, F>();
}

class _FoldersPageState<T extends Track, F extends Folder> extends State<FoldersPage<T, F>> with PortsProvider<TracksSearchParams>, TracksSearchWidgetMixin<FoldersPage<T, F>> {
  List<Folder>? _visibleFolders;
  KeysSearchWrapper<Folder>? _foldersSearchWrapper;
  List<Folder>? _filteredFolders;

  @override
  ScrollController? get providedScrollController => widget.tab.scrollController;

  @override
  List<Selectable> getSearchableTracks() {
    return widget.foldersController.currentFolderTracksList ?? const <Track>[];
  }

  @override
  RxBaseCore listChangesListenerRx() => widget.foldersController.currentFolder;

  @override
  void initState() {
    super.initState();
    widget.foldersController.currentFolder.addListener(_onFoldersChanged);
    widget.config.enableFoldersHierarchy.addListener(_onFoldersChanged);
  }

  @override
  void dispose() {
    widget.foldersController.currentFolder.removeListener(_onFoldersChanged);
    widget.config.enableFoldersHierarchy.removeListener(_onFoldersChanged);
    super.dispose();
  }

  void _onFoldersChanged() {
    _visibleFolders = null;
    _foldersSearchWrapper = null;
    final isFiltering = _filteredFolders != null || isSearching || textEditingController.text.isNotEmpty;
    if (!isFiltering) return;
    clearSearch();
    setState(() => _filteredFolders = null);
  }

  void _onSearchChanged(String text) {
    searchTracks(text);
    _filterFolders(text);
  }

  void _onSearchClosed() {
    clearSearch();
    _filterFolders('');
  }

  void _filterFolders(String text) {
    List<Folder>? filteredFolders;
    if (text.isNotEmpty) {
      final searchWrapper = _foldersSearchWrapper ??= _createFoldersSearchWrapper();
      filteredFolders = searchWrapper.filter(text);
    }
    setState(() => _filteredFolders = filteredFolders);
  }

  KeysSearchWrapper<Folder> _createFoldersSearchWrapper() {
    final visibleFolders = _getVisibleFolders();
    final cleanup = settings.enableSearchCleanup.value;
    return KeysSearchWrapper.init(visibleFolders, title: (folder) => folder.folderNameRaw, cleanup: cleanup);
  }

  List<Folder> _getVisibleFolders() => _visibleFolders ??= _computeVisibleFolders();

  List<Folder> _computeVisibleFolders() {
    final foldersController = widget.foldersController;
    if (widget.config.enableFoldersHierarchy.value) return foldersController.currentFolderslist.value;
    if (foldersController.isInside.value) return const [];
    final foldersMap = foldersController.foldersMap.value;
    return foldersMap.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toFixedList();
  }

  String _getHeaderLabel(List<Track> folderTracks) {
    final visibleFolders = _getVisibleFolders();
    final shownFoldersCount = _filteredFolders?.length;
    final foldersText = visibleFolders.isEmpty ? null : _countText(shownFoldersCount, visibleFolders.length, (count) => count.displayFolderKeyword);
    if (foldersText != null && folderTracks.isEmpty) return foldersText;
    final shownTracksCount = searchResults?.length;
    final isVideos = widget.tab.isVideoFilter == true;
    String tracksCountToText(int count) => isVideos ? count.displayVideoKeyword : count.displayTrackKeyword;
    final tracksText = _countText(shownTracksCount, folderTracks.length, tracksCountToText);
    if (foldersText == null) return tracksText;
    return '$foldersText - $tracksText';
  }

  static String _countText(int? shownCount, int totalCount, String Function(int count) countToText) {
    final totalText = countToText(totalCount);
    if (shownCount == null || shownCount == totalCount) return totalText;
    return '$shownCount/$totalText';
  }

  @override
  Widget build(BuildContext context) {
    final foldersController = widget.foldersController;
    final config = widget.config;
    final tab = widget.tab;
    final mediaType = widget.mediaType();
    final ScrollController scrollController = tab.scrollController;
    const scrollToIconSize = 24.0;
    const scrollToiconBottomPaddingSliver = SliverPadding(padding: EdgeInsets.only(bottom: scrollToIconSize * 2));
    final filteredFolders = _filteredFolders;
    final searchResults = this.searchResults;
    final rangeOrder = searchResults == null ? null : FilteredRangeOrder(searchResults);

    return BackgroundWrapper(
      child: ObxO(
        rx: foldersController.indexToScrollTo,
        builder: (context, indexToScrollTo) => ObxO(
          rx: foldersController.lastVisitedFolderMap,
          builder: (context, lastVisitedFolderMap) => ObxO(
            rx: foldersController.currentFolder,
            builder: (context, currentFolder) {
              final folderTracks = foldersController.folderToTracks(currentFolder) ?? [];
              final highlightedFolder = lastVisitedFolderMap[currentFolder];
              final headerLabel = _getHeaderLabel(folderTracks);
              final jumpIndex = searchResults == null ? indexToScrollTo : null;
              return TrackTilePropertiesProvider(
                configs: TrackTilePropertiesConfigs(
                  queueSource: widget._queueSource(currentFolder?.path),
                ),
                builder: (properties) => Stack(
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                          child: _FoldersHeaderTile(
                            foldersController: foldersController,
                            config: config,
                            currentFolder: currentFolder,
                          ),
                        ),
                        _FoldersExpandableBox(
                          tab: tab,
                          mediaType: mediaType,
                          label: headerLabel,
                          textEditingController: textEditingController,
                          focusNode: focusNode,
                          onSearchBoxVisibilityChange: onSearchBoxVisibilityChange,
                          onCloseButtonPressed: _onSearchClosed,
                          onSearchChanged: _onSearchChanged,
                        ),
                        Expanded(
                          child: NamidaScrollbar(
                            controller: scrollController,
                            child: SmoothCustomScrollView(
                              controller: scrollController,
                              slivers: [
                                SliverToBoxAdapter(
                                  child: ExpandableBoxEmptyAnimatedPadding(
                                    tab: tab,
                                  ),
                                ),
                                ObxO(
                                  rx: config.enableFoldersHierarchy,
                                  builder: (context, enableFoldersHierarchy) => enableFoldersHierarchy
                                      ? _HierarchyFoldersSliver(
                                          foldersController: foldersController,
                                          highlightedFolder: highlightedFolder,
                                          filteredFolders: filteredFolders,
                                        )
                                      : _AllFoldersSliver(
                                          foldersController: foldersController,
                                          highlightedFolder: highlightedFolder,
                                          filteredFolders: filteredFolders,
                                        ),
                                ),
                                SliverFixedExtentList.builder(
                                  itemCount: searchResults?.length ?? folderTracks.length,
                                  itemExtent: Dimensions.inst.trackTileItemExtent,
                                  itemBuilder: (context, i) {
                                    final index = searchResults == null ? i : searchResults[i];
                                    return TrackTile(
                                      properties: properties,
                                      index: index,
                                      trackOrTwd: folderTracks[index],
                                      tracks: folderTracks,
                                      rangeOrder: rangeOrder,
                                      isJumpHighlighted: index == indexToScrollTo,
                                    );
                                  },
                                ),
                                kBottomPaddingWidgetSliver,
                                scrollToiconBottomPaddingSliver,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    jumpIndex != null
                        ? Obx(
                            (context) => Positioned(
                              bottom: Dimensions.inst.globalBottomPaddingEffectiveR + 6.0,
                              right: (Dimensions.inst.shouldHideFABR ? 0.0 : kFABSize) + 12.0 + 8.0,
                              child: _SmolIconFolderScroll(
                                foldersController: foldersController,
                                iconSize: scrollToIconSize,
                                controller: scrollController,
                                indexToScrollTo: jumpIndex,
                              ),
                            ),
                          )
                        : const SizedBox(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FoldersExpandableBox extends StatelessWidget {
  final LibraryTab tab;
  final MediaType mediaType;
  final String label;
  final TextEditingController textEditingController;
  final FocusNode? focusNode;
  final bool Function(bool newShow) onSearchBoxVisibilityChange;
  final VoidCallback onCloseButtonPressed;
  final void Function(String value) onSearchChanged;

  const _FoldersExpandableBox({
    required this.tab,
    required this.mediaType,
    required this.label,
    required this.textEditingController,
    required this.focusNode,
    required this.onSearchBoxVisibilityChange,
    required this.onCloseButtonPressed,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final sorting = settings.mediaItemsTrackSorting.valueR[mediaType] ?? const SortChain<SortType>([]);
        final sortReverse = sorting.reverse;
        final presetName = settings.mediaItemsTrackSortingPresets.valueR[mediaType]?.activePreset?.name;
        final sortTitle = presetName ?? sorting.firstType?.toText() ?? lang.custom;
        final variants = tab.availableVariants(settings.includeVideos.valueR);
        final variantChip = variants.isEmpty
            ? null
            : LibraryTabVariantChip(
                tab: tab,
                variants: variants,
                label: label,
              );
        return ExpandableBox(
          enableHero: false,
          isBarVisible: tab.isBarVisible.valueR,
          leftText: variantChip == null ? label : '',
          leftTextIcon: tab.toIcon(),
          leftWidgets: [
            ?variantChip,
          ],
          onSearchBoxVisibilityChange: onSearchBoxVisibilityChange,
          onCloseButtonPressed: onCloseButtonPressed,
          sortByMenuWidget: SortByMenu(
            title: sortTitle,
            popupMenuChild: SortByMenuTracks(media: mediaType),
            isCurrentlyReversed: sortReverse,
            onReverseIconTap: () => SearchSortController.inst.sortMedia(mediaType, reverse: !sortReverse),
          ),
          textField: CustomTextField(
            focusNode: focusNode,
            textFieldController: textEditingController,
            textFieldHintText: lang.search,
            onTextFieldValueChanged: onSearchChanged,
          ),
        );
      },
    );
  }
}

class _FoldersHeaderTile extends StatefulWidget {
  final FoldersController foldersController;
  final FoldersPageConfig config;
  final Folder? currentFolder;

  const _FoldersHeaderTile({
    required this.foldersController,
    required this.config,
    required this.currentFolder,
  });

  @override
  State<_FoldersHeaderTile> createState() => _FoldersHeaderTileState();
}

class _FoldersHeaderTileState extends State<_FoldersHeaderTile> {
  @override
  Widget build(BuildContext context) {
    final currentFolder = widget.currentFolder;
    final config = widget.config;
    return ObxO(
      rx: widget.foldersController.isHome,
      builder: (context, isHome) {
        String title = lang.home;
        String? titleSuffix;
        String? subtitle;
        Widget? subtitleWidget;
        IconData icon = isHome ? Broken.home_2 : Broken.folder_2;
        if (!isHome && currentFolder != null) {
          final server = currentFolder.parseNetworkServer();
          title = server != null && currentFolder.isNetworkRoot ? server.toSourceInfo() : currentFolder.folderNameRaw;
          final extraInfo = currentFolder.getExtraInfoOrFetch(refreshState);
          if (extraInfo != null && extraInfo.isNotEmpty) titleSuffix = ' - ($extraInfo)';
          subtitle = currentFolder.formattedParentPath();
          if (server != null) {
            icon = server.type.toIcon();
            subtitleWidget = _ServerFolderSubtitle(
              server: server,
              parentPath: subtitle,
            );
          }
        }
        return CustomListTile(
          borderR: 16.0,
          icon: icon,
          title: title,
          titleSuffix: titleSuffix,
          subtitle: subtitle,
          subtitleWidget: subtitleWidget,
          subtitleAbove: true,
          onTap: () => widget.foldersController.stepOut(),
          trailingRaw: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FoldersHierarchyButton(
                config: config,
              ),
              ObxO(
                rx: config.enableFoldersHierarchy,
                builder: (context, enableFoldersHierarchy) => !enableFoldersHierarchy
                    ? const SizedBox()
                    : ObxO(
                        rx: config.defaultFolderStartupLocation,
                        builder: (context, defaultFolderStartupLocation) {
                          final isDefaultFolderEmpty = defaultFolderStartupLocation == null || defaultFolderStartupLocation.isEmpty;
                          return NamidaIconButton(
                            verticalPadding: 8.0,
                            horizontalPadding: 6.0,
                            tooltip: () => lang.setAsDefault,
                            icon: (isDefaultFolderEmpty && isHome)
                                ? Broken.archive_tick
                                : currentFolder == null || isDefaultFolderEmpty || !currentFolder.hasSamePathAs(defaultFolderStartupLocation)
                                ? Broken.save_2
                                : Broken.archive_tick,
                            iconSize: 22.0,
                            onPressed: () => config.onDefaultStartupFolderChanged(),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HierarchyFoldersSliver extends StatelessWidget {
  final FoldersController foldersController;
  final Folder? highlightedFolder;
  final List<Folder>? filteredFolders;

  const _HierarchyFoldersSliver({
    required this.foldersController,
    required this.highlightedFolder,
    required this.filteredFolders,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: foldersController.isHome,
      builder: (context, isHome) => ObxO(
        rx: foldersController.currentFolderslist,
        builder: (context, currentFolderslist) {
          final folders = filteredFolders ?? currentFolderslist;
          return SuperSliverList.builder(
            itemCount: folders.length,
            itemBuilder: (context, i) {
              final folder = folders[i];
              const isTracksRecursive = true;
              final tracks = foldersController.getNodeTracks(folder, recursive: isTracksRecursive);
              final dirInsideCount = foldersController.currentNodeFoldersCount(folder, preferRecursiveForRootFolders: true) ?? 0;
              return FolderTile(
                folder: folder,
                highlightedFolder: highlightedFolder,
                controller: foldersController,
                tracks: tracks,
                isTracksRecursive: isTracksRecursive,
                dirInsideCount: dirInsideCount,
                isHome: isHome,
              );
            },
          );
        },
      ),
    );
  }
}

class _AllFoldersSliver extends StatelessWidget {
  final FoldersController foldersController;
  final Folder? highlightedFolder;
  final List<Folder>? filteredFolders;

  const _AllFoldersSliver({
    required this.foldersController,
    required this.highlightedFolder,
    required this.filteredFolders,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: foldersController.isInside,
      builder: (context, isInside) => isInside
          ? const SliverToBoxAdapter()
          : ObxO(
              rx: foldersController.foldersMap,
              builder: (context, mainMap) {
                final mainMapFoldersKeys = filteredFolders ?? mainMap.keys.toFixedList();
                return SuperSliverList.builder(
                  itemCount: mainMapFoldersKeys.length,
                  itemBuilder: (context, i) {
                    final folder = mainMapFoldersKeys[i];
                    const isTracksRecursive = false;
                    final tracks = foldersController.getNodeTracks(folder, recursive: isTracksRecursive);
                    if (tracks.isEmpty) return const SizedBox();
                    return FolderTile(
                      folder: folder,
                      highlightedFolder: highlightedFolder,
                      controller: foldersController,
                      title: folder.folderNameAvoidingConflicts(),
                      tracks: tracks,
                      isTracksRecursive: isTracksRecursive,
                      dirInsideCount: 0,
                      isHome: true,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _SmolIconFolderScroll extends StatefulWidget {
  final FoldersController foldersController;
  final double iconSize;
  final int indexToScrollTo;
  final ScrollController controller;
  const _SmolIconFolderScroll({required this.foldersController, required this.iconSize, required this.indexToScrollTo, required this.controller});

  @override
  State<_SmolIconFolderScroll> createState() => __SmolIconFolderScrollState();
}

class __SmolIconFolderScrollState extends State<_SmolIconFolderScroll> with TickerProviderStateMixin {
  late AnimationController _danceController;
  late Animation<double> _danceAnimation;

  double get _getScrollToPosition => Dimensions.inst.trackTileItemExtent * (widget.indexToScrollTo + widget.foldersController.currentFolderslist.value.length - 2);

  IconData _arrowIcon = Broken.cd;
  void _updateIcon(IconData icon) {
    if (icon != _arrowIcon) refreshState(() => _arrowIcon = icon);
  }

  void _updateIconListener() {
    final sizeInSettings = _getScrollToPosition;
    double pixels;
    try {
      pixels = widget.controller.positions.first.pixels;
    } catch (_) {
      pixels = sizeInSettings;
    }
    if (pixels > sizeInSettings) {
      _updateIcon(Broken.arrow_circle_up);
    } else if (pixels < sizeInSettings) {
      _updateIcon(Broken.arrow_circle_down);
    } else if (pixels == sizeInSettings) {
      _updateIcon(Broken.cd);
    }
  }

  @override
  void initState() {
    _danceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _danceAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _danceController,
        curve: Curves.easeOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateIconListener();
      _startDancing(delay: true);
    });
    widget.controller.addListener(_updateIconListener);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _SmolIconFolderScroll oldWidget) {
    if (oldWidget.indexToScrollTo != widget.indexToScrollTo || oldWidget.foldersController != widget.foldersController) {
      _startDancing(delay: true);
    } else {
      _startDancing();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _danceController.dispose();
    widget.controller.removeListener(_updateIconListener);
    super.dispose();
  }

  void _startDancing({bool delay = false}) async {
    _danceController.reset();
    if (delay) await Future.delayed(const Duration(milliseconds: 100));
    _danceController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _danceController,
      child: NDecoratedBox(
        decoration: (colors) => BoxDecoration(
          color: colors.scaffold,
          shape: BoxShape.circle,
        ),
        child: NamidaIconButton(
          tooltip: () => lang.jump,
          padding: const EdgeInsets.all(8.0),
          iconSize: widget.iconSize,
          onPressed: () => widget.controller.animateToEff(
            _getScrollToPosition,
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastEaseInToSlowEaseOut,
          ),
          icon: _arrowIcon,
        ),
      ),
      builder: (context, child) {
        final offset = _arrowIcon == Broken.arrow_circle_up ? -4.0 * math.sin(_danceAnimation.value * 2 * math.pi) : 4.0 * math.sin(_danceAnimation.value * 2 * math.pi);
        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
    );
  }
}

class _FoldersHierarchyButton extends StatelessWidget {
  final FoldersPageConfig config;

  const _FoldersHierarchyButton({
    required this.config,
  });

  List<Widget> _getMenuChildren() {
    return [
      Padding(
        padding: const EdgeInsets.all(3.0),
        child: ListTileWithCheckMark(
          dense: true,
          icon: Broken.hierarchy_square_2,
          title: lang.enableFoldersHierarchy,
          activeRx: config.enableFoldersHierarchy,
          onTap: config.toggleFoldersHierarchy,
        ),
      ),
      ObxO(
        rx: config.enableFoldersHierarchy,
        builder: (context, enableFoldersHierarchy) => AnimatedShow(
          show: enableFoldersHierarchy,
          child: Padding(
            padding: const EdgeInsets.all(3.0),
            child: ListTileWithCheckMark(
              dense: true,
              icon: Broken.forward,
              title: lang.skipSingleSubfolders,
              activeRx: config.skipSingleSubfolder,
              onTap: config.toggleSkipSingleSubfolder,
            ),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      children: _getMenuChildren,
      childBuilder: (openMenu) => NamidaIconButton(
        verticalPadding: 8.0,
        horizontalPadding: 6.0,
        tooltip: () => lang.enableFoldersHierarchy,
        icon: Broken.hierarchy_square_2,
        iconSize: 23.0,
        onPressed: openMenu,
      ),
    );
  }
}

class _ServerFolderSubtitle extends StatelessWidget {
  final DirectoryIndexServer server;
  final String parentPath;

  const _ServerFolderSubtitle({
    required this.server,
    required this.parentPath,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = NText.small.of(context);
    final parentPathWidget = parentPath.isEmpty
        ? null
        : Text(
            parentPath,
            style: subtitleStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          server.toTypeAndUserInfo(),
          style: subtitleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        ?parentPathWidget,
      ],
    );
  }
}
