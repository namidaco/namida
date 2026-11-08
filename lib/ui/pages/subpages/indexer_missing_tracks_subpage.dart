import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/missing_track_matcher.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';

enum _LoadingProgress {
  initializing('Initializing'),
  preparingFiles('Preparing files'),
  collectingPlaylistTracks('Collecting playlist tracks'),
  findingHistoryTracks('Finding history tracks'),
  findingLibraryTracks('Finding library tracks'),
  findingPlaylistTracks('Finding playlist tracks');

  final String value;
  const _LoadingProgress(this.value);
}

class IndexerMissingTracksSubpage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.SUBPAGE_INDEXER_UPDATE_MISSING_TRACKS;

  const IndexerMissingTracksSubpage({super.key});

  @override
  State<IndexerMissingTracksSubpage> createState() => _IndexerMissingTracksSubpageState();
}

class _IndexerMissingTracksSubpageState extends State<IndexerMissingTracksSubpage> with TickerProviderStateMixin, PullToRefreshMixin {
  var _missingTracksPaths = <String>[];
  List<String>? _filteredPaths;
  final _cleanedPathsLookup = <String, String>{};
  final _searchController = TextEditingController();
  final _missingTracksSuggestions = <String, String?>{}.obs;
  var _missingTracksCandidates = <String, List<String>>{};
  final _selectedTracksToUpdate = <String, bool>{}.obs;

  bool _isLoading = false;
  final _loadingProgressOnGoing = <_LoadingProgress, bool>{_LoadingProgress.initializing: true}.obs;
  final _loadingProgressActualTracksCount = <_LoadingProgress, int>{}.obs;
  final _subLoadingProgress = 0.0.obs;
  final _loadingCountTotalSteps = _LoadingProgress.values.length;

  bool _isUpdatingPaths = false;

  late final ScrollController _scrollController;

  Isolate? _isolate;
  ReceivePort? _resultPort;
  ReceivePort? _portLoadingProgress;
  ReceivePort? _portSublistsLoadingProgress;

  @override
  void initState() {
    super.initState();
    _scrollController = NamidaScrollController.create();
    Timer(Duration.zero, _fetchMissingTracks);
  }

  @override
  void dispose() {
    _missingTracksSuggestions.close();
    _selectedTracksToUpdate.close();
    _scrollController.dispose();
    _searchController.dispose();
    _loadingProgressOnGoing.close();
    _loadingProgressActualTracksCount.close();
    _subLoadingProgress.close();
    _stopPreviousIsolates();
    super.dispose();
  }

  void _stopPreviousIsolates() {
    try {
      _isolate?.kill(priority: Isolate.immediate);
      _resultPort?.close();
      _portLoadingProgress?.close();
      _portSublistsLoadingProgress?.close();
      _isolate = null;
      _resultPort = null;
      _portLoadingProgress = null;
      _portSublistsLoadingProgress = null;
    } catch (_) {}
  }

  void _resetMaps() {
    _missingTracksPaths = [];
    _filteredPaths = null;
    _cleanedPathsLookup.clear();
    _missingTracksSuggestions.value = {};
    _missingTracksCandidates = {};
    _selectedTracksToUpdate.value = {};
    _loadingProgressOnGoing.value = {_LoadingProgress.initializing: true};
    _loadingProgressActualTracksCount.value = {};
    _subLoadingProgress.value = 0.0;
  }

  List<String>? _computeFilteredPaths(String text) {
    if (text.isEmpty) return null;
    final shouldCleanup = settings.enableSearchCleanup.value;
    String cleanText(String value) => shouldCleanup ? value.cleanUpForComparison : value.toLowerCase();
    final queryParts = cleanText(text).split(' ').where((e) => e.isNotEmpty).toFixedList();
    return _missingTracksPaths.where(
      (path) {
        final cleanedPath = _cleanedPathsLookup[path] ??= cleanText(path);
        return queryParts.every(cleanedPath.contains);
      },
    ).toFixedList();
  }

  void _onSearchChanged(String text) {
    setState(() => _filteredPaths = _computeFilteredPaths(text));
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _filteredPaths = null);
  }

  bool _onSearchBoxVisibilityChange(bool newShow) => newShow || _searchController.text.isEmpty;

  Future<void> _fetchMissingTracks() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    _stopPreviousIsolates();

    _loadingProgressOnGoing[_LoadingProgress.preparingFiles] = true;

    late final Set<String> audioFiles;
    await Future.wait([
      Indexer.inst.getAudioFiles().then((value) => audioFiles = value),
      HistoryController.inst.waitForHistoryAndMostPlayedLoad,
      PlaylistController.inst.waitForPlaylistsLoad,
      PlaylistController.inst.waitForFavouritePlaylistLoad,
      PlaylistController.inst.waitForM3UPlaylistsLoad,
    ]);

    _loadingProgressOnGoing[_LoadingProgress.collectingPlaylistTracks] = true;

    _resultPort = ReceivePort();
    _portLoadingProgress = ReceivePort();
    _portSublistsLoadingProgress = ReceivePort();

    try {
      StreamSubscription? portLoadingProgressSub;
      portLoadingProgressSub = _portLoadingProgress!.listen((stepProgress) {
        _loadingProgressOnGoing[stepProgress] = true;
      });

      StreamSubscription? portSublistsLoadingProgressSub;
      portSublistsLoadingProgressSub = _portSublistsLoadingProgress!.listen((subProgress) {
        _subLoadingProgress.value = subProgress as double;
      });

      final indicesProgressMap = <int, _LoadingProgress>{};
      final allTracksSet = <String>{};
      indicesProgressMap[allTracksSet.length] = _LoadingProgress.findingHistoryTracks;
      void addTracksCountToStep(_LoadingProgress step) {
        final alreadyExistedCount = _loadingProgressActualTracksCount.value.values.fold(0, (previousValue, element) => previousValue + element);
        _loadingProgressActualTracksCount[step] = allTracksSet.length - alreadyExistedCount;
      }

      // -- history first to be sorted & has no duplicates
      for (final track in HistoryController.inst.topTracksMapListens.value.keysSortedByValue) {
        allTracksSet.add(track.path);
      }
      addTracksCountToStep(_LoadingProgress.findingHistoryTracks);

      indicesProgressMap[allTracksSet.length] = _LoadingProgress.findingLibraryTracks;
      final fingerprintsByPath = <String, MissingTrackFingerprint>{};
      for (final e in Indexer.inst.allTracksMappedByPath.entries) {
        final path = e.key;
        final trExt = e.value;
        allTracksSet.add(path);
        final fingerprint = MissingTrackMatcher.fingerprintOf(size: trExt.size, durationMS: trExt.durationMS);
        if (fingerprint != null) fingerprintsByPath[path] = fingerprint;
      }
      addTracksCountToStep(_LoadingProgress.findingLibraryTracks);

      indicesProgressMap[allTracksSet.length - 1] = _LoadingProgress.findingPlaylistTracks;
      for (final p in PlaylistController.inst.playlistsMap.value.values) {
        for (final e in p.tracks) {
          allTracksSet.add(e.track.path);
        }
      }
      for (final e in PlaylistController.inst.favouritesPlaylist.value.tracks) {
        allTracksSet.add(e.track.path);
      }
      addTracksCountToStep(_LoadingProgress.findingPlaylistTracks);

      final params = _FetchMissingTracksParams(
        allAudioFiles: audioFiles,
        allTracksSet: allTracksSet,
        fingerprintsByPath: fingerprintsByPath,
        indicesProgressMap: indicesProgressMap,
        progressPort: _portLoadingProgress!.sendPort,
        resultsPort: _resultPort!.sendPort,
        subProgressPort: _portSublistsLoadingProgress!.sendPort,
      );
      _isolate = await Isolate.spawn(_fetchMissingTracksIsolate, params);

      final res = await _resultPort!.first as (List<String>, Map<String, String?>, Map<String, List<String>>);

      _missingTracksPaths = res.$1;
      _filteredPaths = _computeFilteredPaths(_searchController.text);
      _missingTracksSuggestions.value = res.$2;
      _missingTracksCandidates = res.$3;

      _resultPort?.close();
      _portLoadingProgress?.close();
      portLoadingProgressSub.cancel();
      portSublistsLoadingProgressSub.cancel();
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  static void _fetchMissingTracksIsolate(_FetchMissingTracksParams params) {
    final allAudioFiles = params.allAudioFiles;
    final allTracksSet = params.allTracksSet;
    final indicesProgressMap = params.indicesProgressMap;
    final progressPort = params.progressPort;
    final resultsPort = params.resultsPort;
    final subProgressPort = params.subProgressPort;

    final matcher = MissingTrackMatcher(allAudioFiles, fingerprintsByPath: params.fingerprintsByPath);

    final missingTracksPaths = <String>[];
    final missingTracksSuggestions = <String, String?>{};
    final missingTracksCandidates = <String, List<String>>{};

    void checkAndAdd(String rawPath) {
      final tr = Track.explicit(rawPath);
      if (tr.isNetwork) return;
      final exists = tr.existsSync();
      if (!exists) {
        missingTracksPaths.add(rawPath);
        final candidates = matcher.getSuggestions(rawPath);
        missingTracksSuggestions[rawPath] = candidates.firstOrNull;
        if (candidates.isNotEmpty) missingTracksCandidates[rawPath] = candidates;
      }
    }

    final int totalIndices = allTracksSet.length - 1;
    int index = 0;
    for (final rawPath in allTracksSet) {
      if (index % 20 == 0) subProgressPort.send(index / totalIndices);

      checkAndAdd(rawPath);
      final progress = indicesProgressMap[index];
      if (progress != null) progressPort.send(progress);
      index++;
    }

    resultsPort.send((missingTracksPaths, missingTracksSuggestions, missingTracksCandidates));
  }

  void _setNewPathFor(String path, String newPath) {
    _missingTracksSuggestions[path] = newPath;
    _selectedTracksToUpdate[path] = true;
  }

  void _pickNewPathFor(String path) async {
    final file = await NamidaFileBrowser.pickFile(note: lang.update);
    final newPath = file?.path;
    if (newPath == null) return;
    _setNewPathFor(path, newPath);
  }

  void _onRepickTap(String path) {
    final candidates = _missingTracksCandidates[path];
    if (candidates == null) {
      _pickNewPathFor(path);
      return;
    }
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.choose,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.pickFromStorage,
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              _pickNewPathFor(path);
            },
          ),
        ],
        child: Obx(
          (context) {
            final currentPath = _missingTracksSuggestions[path];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NamidaText(
                  path.toDisplayPath(),
                  style: NText.small,
                ),
                const SizedBox(height: 8.0),
                ...candidates.map(
                  (candidate) {
                    final displayPath = candidate.toDisplayPath();
                    final sizeText = File(candidate).fileSizeFormatted();
                    return SmallListTile(
                      borderRadius: 12.0,
                      icon: Broken.medal_star,
                      title: displayPath,
                      subtitle: sizeText,
                      trailing: NamidaCheckMark(
                        size: 18.0,
                        active: candidate == currentPath,
                      ),
                      onTap: () {
                        _setNewPathFor(path, candidate);
                        NamidaNavigator.inst.closeDialog();
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _onUpdating() async {
    if (_selectedTracksToUpdate.isEmpty) return;
    setState(() => _isUpdatingPaths = true);

    final newPaths = <String, String>{};
    for (final e in _selectedTracksToUpdate.entries) {
      if (e.value) {
        final sugg = _missingTracksSuggestions[e.key];
        if (sugg != null) newPaths[e.key] = sugg;
      }
    }

    bool didUpdate = false;
    try {
      await EditDeleteController.inst.updateTrackPathInEveryPartOfNamidaBulk(newPaths, removeOldTracksFromLibrary: true);
      didUpdate = true;
      snackyy(title: lang.note, message: "${lang.done}: ${newPaths.length.displayTrackKeyword}", top: false);
    } catch (e) {
      snackyy(
        title: lang.error,
        message: '$e',
        top: false,
        isError: true,
      );
    }

    if (didUpdate) {
      // -- only clearing what was actually updated
      for (final k in newPaths.keys) {
        _missingTracksPaths.remove(k);
        _missingTracksSuggestions.remove(k);
        _missingTracksCandidates.remove(k);
        _selectedTracksToUpdate.remove(k);
      }
      _filteredPaths = _computeFilteredPaths(_searchController.text);
    }
    setState(() => _isUpdatingPaths = false);
  }

  @override
  Widget build(BuildContext context) {
    final shownPaths = _filteredPaths ?? _missingTracksPaths;
    final totalCountText = _missingTracksPaths.length.displayTrackKeyword;
    final headerLeftText = _filteredPaths == null ? totalCountText : '${shownPaths.length}/$totalCountText';
    final headerWidget = _missingTracksPaths.isEmpty
        ? null
        : ExpandableBox(
            enableHero: false,
            isBarVisible: true,
            leftText: headerLeftText,
            leftTextIcon: Broken.musicnote,
            onSearchBoxVisibilityChange: _onSearchBoxVisibilityChange,
            onCloseButtonPressed: _clearSearch,
            sortByMenuWidget: null,
            textFieldController: _searchController,
            textFieldHintText: lang.search,
            onTextFieldValueChanged: _onSearchChanged,
          );
    return BackgroundWrapper(
      child: Stack(
        children: [
          _isLoading
              ? Center(
                  child: ObxO(
                    rx: _loadingProgressOnGoing,
                    builder: (context, loadingProgressDone) => ObxO(
                      rx: _loadingProgressActualTracksCount,
                      builder: (context, stepTracksCountMap) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              NBuilder(
                                builder: (context, colors) => ThreeArchedCircle(
                                  size: 56.0,
                                  color: colors.secondary,
                                ),
                              ),
                              ObxO(
                                rx: _subLoadingProgress,
                                builder: (context, subProgress) => NamidaText(
                                  "${(subProgress * 100).toStringAsFixed(2)}%",
                                  style: NText.small,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ..._LoadingProgress.values.map(
                                (e) {
                                  String val = '${e.index + 1}. ${e.value}';
                                  final isDone =
                                      loadingProgressDone[e] == true && (loadingProgressDone.length == _loadingCountTotalSteps || loadingProgressDone.keys.lastOrNull != e);
                                  val += isDone ? ' ✓' : '...';
                                  final opacity = isDone ? 0.8 : 0.5;
                                  final trsCount = stepTracksCountMap[e];
                                  if (trsCount != null) val += ' (${trsCount.formatDecimal()})';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                    child: NamidaText(
                                      val,
                                      style: NText.small,
                                      color: NColors(.textSmall, opacity: opacity),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    ?headerWidget,
                    Expanded(
                      child: Listener(
                        onPointerMove: (event) {
                          onPointerMove(_scrollController, event);
                        },
                        onPointerUp: (event) {
                          onRefresh(() async {
                            _resetMaps();
                            return await _fetchMissingTracks();
                          });
                        },
                        onPointerCancel: (event) => onVerticalDragFinish(),
                        child: _missingTracksPaths.isEmpty
                            ? Center(
                                child: Column(
                                  crossAxisAlignment: .center,
                                  mainAxisAlignment: .center,
                                  children: [
                                    const Icon(
                                      Broken.emoji_happy,
                                      size: 48.0,
                                    ),
                                    const SizedBox(height: 8.0),
                                    NamidaText(
                                      lang.noTracksFound,
                                      style: NText.large,
                                    ),
                                  ],
                                ),
                              )
                            : NamidaScrollbar(
                                controller: _scrollController,
                                child: AnimatedEnabled(
                                  enabled: !_isUpdatingPaths,
                                  child: SuperSmoothListView.builder(
                                    controller: _scrollController,
                                    padding: EdgeInsets.only(bottom: Dimensions.inst.globalBottomPaddingEffectiveR + kFABSize + 8.0),
                                    itemCount: shownPaths.length,
                                    itemBuilder: (context, index) {
                                      final path = shownPaths[index];
                                      return Padding(
                                        padding: const EdgeInsets.all(3.0),
                                        child: Obx(
                                          (context) {
                                            final suggestion = _missingTracksSuggestions[path];
                                            final isSelected = _selectedTracksToUpdate[path] == true;
                                            final itemContent = Stack(
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                                  child: Row(
                                                    children: [
                                                      const SizedBox(width: 12.0),
                                                      NDecoratedBox(
                                                        decoration: (colors) => BoxDecoration(
                                                          color: colors.secondary.withOpacityExt(0.3),
                                                          borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                                        ),
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 2.0),
                                                          child: ObxO(
                                                            rx: HistoryController.inst.topTracksMapListens,
                                                            builder: (context, topTracksMapListens) {
                                                              final listens = topTracksMapListens[Track.explicit(path)] ?? topTracksMapListens[Video.explicit(path)];
                                                              final listensCount = listens?.length ?? 0;
                                                              return NamidaText(
                                                                '$listensCount',
                                                                style: NText.small,
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12.0),
                                                      Expanded(
                                                        child: Column(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            NamidaText(
                                                              path.toDisplayPath(),
                                                              style: NText.medium,
                                                            ),
                                                            if (suggestion != null)
                                                              NamidaText(
                                                                " --> ${suggestion.toDisplayPath()}",
                                                                style: NText.small,
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12.0),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.end,
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          _missingTracksSuggestions[path] == null
                                                              ? const SizedBox()
                                                              : NamidaCheckMark(
                                                                  size: 18.0,
                                                                  active: isSelected,
                                                                ),
                                                          const SizedBox(width: 4.0),
                                                          NamidaIconButton(
                                                            verticalPadding: 6.0,
                                                            horizontalPadding: 4.0,
                                                            icon: Broken.repeat_circle,
                                                            onPressed: () => _onRepickTap(path),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(width: 8.0),
                                                    ],
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 0,
                                                  right: 0,
                                                  child: NamidaBlurryContainer(
                                                    borderRadius: BorderRadius.only(
                                                      bottomLeft: Radius.circular(6.0.multipliedRadius),
                                                      topRight: Radius.circular(6.0.multipliedRadius),
                                                    ),
                                                    padding: const EdgeInsets.only(
                                                      top: 2.0,
                                                      right: 8.0,
                                                      left: 6.0,
                                                      bottom: 2.0,
                                                    ),
                                                    child: NamidaText(
                                                      "${index + 1}",
                                                      style: NText.small,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                            return NBuilder(
                                              selfAnimated: true,
                                              builder: (context, colors) {
                                                final borderColor = colors.secondary.withOpacityExt(0.6);
                                                return NamidaInkWell(
                                                  animationDurationMS: 300,
                                                  borderRadius: 12.0,
                                                  bgColor: NColors.card,
                                                  decoration: BoxDecoration(
                                                    border: isSelected
                                                        ? Border.all(
                                                            width: 1.5,
                                                            color: borderColor,
                                                          )
                                                        : null,
                                                  ),
                                                  onTap: () {
                                                    if (_missingTracksSuggestions[path] == null) return;
                                                    final wasUpadting = (_selectedTracksToUpdate[path] ?? false);
                                                    if (wasUpadting) {
                                                      _selectedTracksToUpdate.remove(path);
                                                    } else {
                                                      _selectedTracksToUpdate[path] = true;
                                                    }
                                                  },
                                                  child: itemContent,
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
          pullToRefreshWidget,
          Obx(
            (context) => Positioned(
              bottom: Dimensions.inst.globalBottomPaddingTotalR,
              right: 12.0,
              child: _isUpdatingPaths
                  ? NDecoratedBox(
                      decoration: (colors) => BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                        color: colors.card,
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow,
                            blurRadius: 6.0,
                            offset: const Offset(0, 4.0),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: NBuilder(
                          builder: (context, colors) => ThreeArchedCircle(
                            size: 36.0,
                            color: colors.secondary,
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Obx(
                          (context) {
                            final allSelected =
                                _selectedTracksToUpdate.isNotEmpty && shownPaths.every((e) => _missingTracksSuggestions[e] == null || _selectedTracksToUpdate[e] == true);
                            return NamidaFABButton(
                              tooltip: () => lang.selectAll,
                              icon: allSelected ? Broken.tick_square : Broken.task_square,
                              dim: !allSelected,
                              onTap: () {
                                final allSelected =
                                    _selectedTracksToUpdate.isNotEmpty && shownPaths.every((e) => _missingTracksSuggestions[e] == null || _selectedTracksToUpdate[e] == true);
                                if (allSelected) {
                                  if (_filteredPaths == null) {
                                    _selectedTracksToUpdate.clear();
                                  } else {
                                    for (final e in shownPaths) {
                                      _selectedTracksToUpdate.remove(e);
                                    }
                                  }
                                } else {
                                  for (var e in shownPaths) {
                                    if (_missingTracksSuggestions[e] != null) _selectedTracksToUpdate[e] = true;
                                  }
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 8.0),
                        Obx(
                          (context) {
                            final totalLength = _selectedTracksToUpdate.length;
                            return NamidaFABButton(
                              enabled: totalLength > 0,
                              icon: Broken.pen_add,
                              text: "${lang.update} ($totalLength)",
                              onTap: () async {
                                final isUpdating = false.obs;
                                NamidaNavigator.inst.navigateDialog(
                                  onDisposing: () {
                                    isUpdating.close();
                                  },
                                  tapToDismiss: () => !isUpdating.value,
                                  dialog: CustomBlurryDialog(
                                    isWarning: true,
                                    normalTitleStyle: true,
                                    bodyText: "${lang.update}: ${_selectedTracksToUpdate.length.displayTrackKeyword}?",
                                    actions: [
                                      const CancelButton(),
                                      ObxO(
                                        rx: isUpdating,
                                        builder: (context, updating) => NamidaButton(
                                          enabled: !updating,
                                          isLoading: updating,
                                          text: lang.update.toUpperCase(),
                                          onTap: () async {
                                            isUpdating.value = true;
                                            await _onUpdating();
                                            isUpdating.value = false;
                                            NamidaNavigator.inst.closeDialog();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FetchMissingTracksParams {
  final Set<String> allAudioFiles;
  final Set<String> allTracksSet;
  final Map<String, MissingTrackFingerprint> fingerprintsByPath;
  final Map<int, _LoadingProgress> indicesProgressMap;
  final SendPort progressPort;
  final SendPort resultsPort;
  final SendPort subProgressPort;

  const _FetchMissingTracksParams({
    required this.allAudioFiles,
    required this.allTracksSet,
    required this.fingerprintsByPath,
    required this.indicesProgressMap,
    required this.progressPort,
    required this.resultsPort,
    required this.subProgressPort,
  });
}
