import 'package:flutter/material.dart';

import 'package:super_sliver_list/super_sliver_list.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/folder_tile.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class FoldersPage<T extends Track, F extends Folder> extends StatelessWidget with NamidaRouteWidget {
  @override
  final RouteType route;
  final FoldersController foldersController;
  final LibraryTab tab;
  final MediaType Function() mediaType;
  final FoldersPageConfig config;
  final QueueSource _queueSource;
  final RxMap<F, List<T>> _foldersMap;

  const FoldersPage._(
    this._queueSource,
    this._foldersMap, {
    super.key,
    required this.route,
    required this.foldersController,
    required this.tab,
    required this.mediaType,
    required this.config,
  });

  factory FoldersPage.tracks({Key? key}) => FoldersPage._(
        QueueSource.folder,
        Indexer.inst.mainMapFolders as RxMap<F, List<T>>,
        key: key,
        route: RouteType.PAGE_folders,
        foldersController: FoldersController.tracks,
        tab: LibraryTab.folders,
        mediaType: () => MediaType.folder,
        config: FoldersPageConfig.tracks(),
      );

  factory FoldersPage.videos({Key? key}) => FoldersPage._(
        QueueSource.folderVideos,
        Indexer.inst.mainMapFoldersVideos as RxMap<F, List<T>>,
        key: key,
        route: RouteType.PAGE_folders_videos,
        foldersController: FoldersController.videos,
        tab: LibraryTab.foldersVideos,
        mediaType: () => MediaType.folderVideo,
        config: FoldersPageConfig.videos(),
      );

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = tab.scrollController;
    final highlighedColor = context.theme.colorScheme.onSurface.withAlpha(40);
    const scrollToIconSize = 24.0;
    const scrollToiconBottomPaddingSliver = SliverPadding(padding: EdgeInsets.only(bottom: scrollToIconSize * 2));
    return BackgroundWrapper(
      child: ObxO(
        rx: foldersController.indexToScrollTo,
        builder: (context, indexToScrollTo) => TrackTilePropertiesProvider(
          configs: TrackTilePropertiesConfigs(
            queueSource: _queueSource,
          ),
          builder: (properties) => Stack(
            children: [
              ObxO(
                rx: config.enableFoldersHierarchy,
                builder: (context, enableFoldersHierarchy) => enableFoldersHierarchy
                    ? Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                            child: ObxO(
                              rx: foldersController.isHome,
                              builder: (context, isHome) => ObxO(
                                rx: foldersController.currentFolder,
                                builder: (context, currentFolder) {
                                  return CustomListTile(
                                    borderR: 16.0,
                                    icon: isHome ? Broken.home_2 : Broken.folder_2,
                                    title: currentFolder?.formattedPath() ?? lang.HOME,
                                    titleStyle: context.textTheme.displaySmall,
                                    onTap: () => foldersController.stepOut(),
                                    trailingRaw: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ObxO(
                                          rx: config.defaultFolderStartupLocation,
                                          builder: (context, defaultFolderStartupLocation) => NamidaIconButton(
                                            horizontalPadding: 8.0,
                                            tooltip: () => lang.SET_AS_DEFAULT,
                                            icon: currentFolder == null || defaultFolderStartupLocation == null || !currentFolder.hasSamePathAs(defaultFolderStartupLocation)
                                                ? Broken.save_2
                                                : Broken.archive_tick,
                                            iconSize: 22.0,
                                            onPressed: () => config.onDefaultStartupFolderChanged(),
                                          ),
                                        ),
                                        const SizedBox(width: 6.0),
                                        NamidaIconButton(
                                          verticalPadding: 8.0,
                                          horizontalPadding: 2.0,
                                          icon: Broken.sort,
                                          onPressed: () {
                                            NamidaOnTaps.inst.onSubPageTracksSortIconTap(mediaType());
                                          },
                                        )
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: NamidaScrollbar(
                              controller: scrollController,
                              child: ObxO(
                                rx: foldersController.isHome,
                                builder: (context, isHome) => ObxO(
                                  rx: foldersController.currentFolder,
                                  builder: (context, currentFolder) {
                                    final folderTracks = currentFolder?.tracks() ?? [];
                                    return CustomScrollView(
                                      controller: scrollController,
                                      slivers: [
                                        ObxO(
                                          rx: foldersController.currentFolderslist,
                                          builder: (context, currentFolderslist) => SuperSliverList.builder(
                                            itemCount: currentFolderslist.length,
                                            itemBuilder: (context, i) {
                                              final folder = currentFolderslist[i];
                                              const isTracksRecursive = true;
                                              final tracks = foldersController.getNodeTracks(folder, recursive: isTracksRecursive);
                                              final dirInsideCount = foldersController.currentNodeFoldersCount(folder, preferRecursiveForRootFolders: true) ?? 0;
                                              return FolderTile(
                                                folder: folder,
                                                controller: foldersController,
                                                tracks: tracks,
                                                isTracksRecursive: isTracksRecursive,
                                                dirInsideCount: dirInsideCount,
                                              );
                                            },
                                          ),
                                        ),
                                        SliverFixedExtentList.builder(
                                          itemCount: folderTracks.length,
                                          itemExtent: Dimensions.inst.trackTileItemExtent,
                                          itemBuilder: (context, i) {
                                            return TrackTile(
                                              properties: properties,
                                              index: i,
                                              trackOrTwd: folderTracks[i],
                                              tracks: folderTracks,
                                              bgColor: i == indexToScrollTo ? highlighedColor : null,
                                            );
                                          },
                                        ),
                                        kBottomPaddingWidgetSliver,
                                        scrollToiconBottomPaddingSliver,
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      )

                    // == All Folders
                    : Column(
                        children: [
                          ListTile(
                            leading: ObxO(
                              rx: foldersController.isHome,
                              builder: (context, isHome) => SizedBox(
                                height: double.infinity,
                                child: Icon(
                                  isHome ? Broken.home_2 : Broken.folder_2,
                                  size: 22.0,
                                ),
                              ),
                            ),
                            title: ObxO(
                              rx: foldersController.currentFolder,
                              builder: (context, currentFolder) => Text(
                                currentFolder?.formattedPath() ?? lang.HOME,
                                style: context.textTheme.displaySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            onTap: () => foldersController.stepOut(),
                          ),
                          Expanded(
                            child: NamidaScrollbar(
                              controller: scrollController,
                              child: ObxO(
                                rx: foldersController.isInside,
                                builder: (context, isInside) => ObxO(
                                  rx: foldersController.currentFolder,
                                  builder: (context, currentFolder) {
                                    final folderTracks = currentFolder?.tracks() ?? [];
                                    return CustomScrollView(
                                      controller: scrollController,
                                      slivers: [
                                        if (!isInside)
                                          ObxO(
                                            rx: _foldersMap,
                                            builder: (context, mainMapFolders) {
                                              final mainMapFoldersKeys = _foldersMap.keys.toList();
                                              return SuperSliverList.builder(
                                                itemCount: mainMapFoldersKeys.length,
                                                itemBuilder: (context, i) {
                                                  final folder = mainMapFoldersKeys[i];
                                                  const isTracksRecursive = false;
                                                  final tracks = foldersController.getNodeTracks(folder, recursive: isTracksRecursive);
                                                  if (tracks.isEmpty) return const SizedBox();
                                                  final dirInsideCount = foldersController.currentNodeFoldersCount(folder) ?? 0;
                                                  return FolderTile(
                                                    folder: folder,
                                                    controller: foldersController,
                                                    subtitle: folder.hasSimilarFolderNames ? folder.parent.formattedPath() : null,
                                                    tracks: tracks,
                                                    isTracksRecursive: isTracksRecursive,
                                                    dirInsideCount: dirInsideCount,
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        SliverFixedExtentList.builder(
                                          itemCount: folderTracks.length,
                                          itemExtent: Dimensions.inst.trackTileItemExtent,
                                          itemBuilder: (context, i) {
                                            final tr = folderTracks[i];
                                            return TrackTile(
                                              properties: properties,
                                              index: i,
                                              trackOrTwd: tr,
                                              tracks: folderTracks,
                                              bgColor: i == indexToScrollTo ? highlighedColor : null,
                                            );
                                          },
                                        ),
                                        kBottomPaddingWidgetSliver,
                                        scrollToiconBottomPaddingSliver,
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              indexToScrollTo != null
                  ? Obx(
                      (context) => Positioned(
                        bottom: Dimensions.inst.globalBottomPaddingEffectiveR + 8.0,
                        right: (Dimensions.inst.shouldHideFABR ? 0.0 : kFABSize) + 12.0 + 8.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.theme.scaffoldBackgroundColor,
                            shape: BoxShape.circle,
                          ),
                          child: _SmolIconFolderScroll(
                            foldersController: foldersController,
                            iconSize: scrollToIconSize,
                            controller: scrollController,
                            indexToScrollTo: indexToScrollTo,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(),
            ],
          ),
        ),
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

class __SmolIconFolderScrollState extends State<_SmolIconFolderScroll> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateIconListener());
    widget.controller.addListener(_updateIconListener);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateIconListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NamidaIconButton(
      padding: const EdgeInsets.all(7.0),
      iconSize: widget.iconSize,
      onPressed: () {
        try {
          widget.controller.animateToEff(
            _getScrollToPosition,
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastEaseInToSlowEaseOut,
          );
        } catch (_) {}
      },
      icon: _arrowIcon,
    );
  }
}
