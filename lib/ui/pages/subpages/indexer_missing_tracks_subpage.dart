import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/generators_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

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
  final _missingTracksSuggestions = <String, String?>{}.obs;
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
    _scrollController = ScrollController();
    Future.delayed(Duration.zero, _fetchMissingTracks);
  }

  @override
  void dispose() {
    _missingTracksSuggestions.close();
    _selectedTracksToUpdate.close();
    _scrollController.dispose();
    _loadingProgressOnGoing.close();
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
    _missingTracksSuggestions.value = {};
    _selectedTracksToUpdate.value = {};
  }

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
      final allTracks = <String, bool>{};
      indicesProgressMap[allTracks.length] = _LoadingProgress.findingHistoryTracks;
      void addTracksCountToStep(_LoadingProgress step) {
        final alreadyExistedCount = _loadingProgressActualTracksCount.value.values.fold(0, (previousValue, element) => previousValue + element);
        _loadingProgressActualTracksCount[step] = allTracks.length - alreadyExistedCount;
      }

      // -- history first to be sorted & has no duplicates
      for (final track in HistoryController.inst.topTracksMapListens.keys) {
        allTracks[track.path] = true;
      }
      addTracksCountToStep(_LoadingProgress.findingHistoryTracks);

      indicesProgressMap[allTracks.length] = _LoadingProgress.findingLibraryTracks;
      for (final path in Indexer.inst.allTracksMappedByPath.keys) {
        allTracks[path] ??= true;
      }
      addTracksCountToStep(_LoadingProgress.findingLibraryTracks);

      indicesProgressMap[allTracks.length - 1] = _LoadingProgress.findingPlaylistTracks;
      for (final p in PlaylistController.inst.playlistsMap.value.values) {
        p.tracks.loop((e) {
          allTracks[e.track.path] ??= true;
        });
      }
      addTracksCountToStep(_LoadingProgress.findingPlaylistTracks);

      final params = (audioFiles, allTracks, indicesProgressMap, _portLoadingProgress!.sendPort, _resultPort!.sendPort, _portSublistsLoadingProgress!.sendPort);
      _isolate = await Isolate.spawn(_fetchMissingTracksIsolate, params);

      final res = await _resultPort!.first as (List<String>, Map<String, String?>);

      _missingTracksPaths = res.$1;
      _missingTracksSuggestions.value = res.$2;

      _resultPort?.close();
      _portLoadingProgress?.close();
      portLoadingProgressSub.cancel();
      portSublistsLoadingProgressSub.cancel();
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  static void _fetchMissingTracksIsolate((Set<String>, Map<String, bool>, Map<int, _LoadingProgress>, SendPort, SendPort, SendPort) params) {
    final allAudioFiles = params.$1;
    final allTracks = params.$2;
    final indicesProgressMap = params.$3;
    final progressPort = params.$4;
    final resultsPort = params.$5;
    final subProgressPort = params.$6;

    String? getSuggestion(String path) {
      final all = NamidaGenerator.getHighMatcheFilesFromFilename(allAudioFiles, path.getFilename);
      for (final p in all) {
        if (File(p).existsSync()) return p;
      }
      return null;
    }

    final missingTracksPaths = <String>[];
    final missingTracksSuggestions = <String, String?>{};

    // ignore: no_leading_underscores_for_local_identifiers
    void _onAdd(String path) {
      final exists = File(path).existsSync();
      if (!exists) {
        missingTracksPaths.add(path);
        missingTracksSuggestions[path] = getSuggestion(path);
      }
    }

    final int totalIndices = allTracks.length - 1;
    int index = 0;
    for (final path in allTracks.keys) {
      if (index % 10 == 0) subProgressPort.send(index / totalIndices);

      _onAdd(path);
      final progress = indicesProgressMap[index];
      if (progress != null) progressPort.send(progress);
      index++;
    }

    resultsPort.send((missingTracksPaths, missingTracksSuggestions));
  }

  void _pickNewPathFor(String path) async {
    final file = await NamidaFileBrowser.pickFile(note: lang.UPDATE);
    final newPath = file?.path;
    _missingTracksSuggestions[path] = newPath;
    if (newPath != null) _selectedTracksToUpdate[path] = true;
  }

  Future<void> _onUpdating() async {
    if (_selectedTracksToUpdate.isEmpty) return;
    setState(() => _isUpdatingPaths = true);
    try {
      final newPaths = <String, String>{};
      for (final e in _selectedTracksToUpdate.entries) {
        if (e.value) {
          final sugg = _missingTracksSuggestions[e.key];
          if (sugg != null) newPaths[e.key] = sugg;
        }
      }
      await EditDeleteController.inst.updateTrackPathInEveryPartOfNamidaBulk(newPaths);
      snackyy(title: lang.NOTE, message: "${lang.DONE}: ${newPaths.length.displayTrackKeyword}", top: false);
    } catch (e) {
      snackyy(title: lang.ERROR, message: '$e', top: false, isError: true);
    }

    for (final k in _selectedTracksToUpdate.keys) {
      _missingTracksPaths.remove(k);
      _missingTracksSuggestions.remove(k);
    }
    _selectedTracksToUpdate.clear();
    setState(() => _isUpdatingPaths = false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final cardColor = context.theme.cardColor;
    final borderColor = context.theme.colorScheme.secondary.withValues(alpha: 0.6);

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
                              ThreeArchedCircle(
                                size: 56.0,
                                color: context.theme.colorScheme.secondary,
                              ),
                              ObxO(
                                rx: _subLoadingProgress,
                                builder: (context, subProgress) => Text(
                                  "${(subProgress * 100).toStringAsFixed(2)}%",
                                  style: context.textTheme.displaySmall,
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
                                    child: Text(
                                      val,
                                      style: context.textTheme.displaySmall?.copyWith(
                                        color: context.textTheme.displaySmall?.color?.withValues(alpha: opacity),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                )
              : Listener(
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
                  child: NamidaScrollbar(
                    controller: _scrollController,
                    child: AnimatedEnabled(
                      enabled: !_isUpdatingPaths,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.only(bottom: Dimensions.inst.globalBottomPaddingEffectiveR + 56.0 + 4.0),
                        itemCount: _missingTracksPaths.length,
                        itemBuilder: (context, index) {
                          final path = _missingTracksPaths[index];
                          return Padding(
                            padding: const EdgeInsets.all(3.0),
                            child: Obx(
                              (context) {
                                final suggestion = _missingTracksSuggestions[path];
                                final isSelected = _selectedTracksToUpdate[path] == true;
                                final leftColor = context.theme.colorScheme.secondary.withValues(alpha: 0.3);
                                return NamidaInkWell(
                                  animationDurationMS: 300,
                                  borderRadius: 12.0,
                                  bgColor: cardColor,
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
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                                        child: Row(
                                          children: [
                                            const SizedBox(width: 12.0),
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: leftColor,
                                                borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 2.0),
                                                child: Text(
                                                  '${(HistoryController.inst.topTracksMapListens.value[Track.explicit(path)] ?? HistoryController.inst.topTracksMapListens.value[Video.explicit(path)])?.length ?? 0}',
                                                  style: textTheme.displaySmall,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12.0),
                                            Expanded(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    path,
                                                    style: textTheme.displayMedium,
                                                  ),
                                                  if (suggestion != null)
                                                    Text(
                                                      " --> $suggestion",
                                                      style: textTheme.displaySmall,
                                                    )
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
                                                  onPressed: () => _pickNewPathFor(path),
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
                                          padding: const EdgeInsets.only(top: 2.0, right: 8.0, left: 6.0, bottom: 2.0),
                                          child: Text(
                                            "${index + 1}",
                                            style: context.textTheme.displaySmall,
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
          pullToRefreshWidget,
          Positioned(
            bottom: Dimensions.inst.globalBottomPaddingTotalR,
            right: 12.0,
            child: _isUpdatingPaths
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                      color: context.theme.cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: context.theme.shadowColor,
                          blurRadius: 6.0,
                          offset: const Offset(0, 4.0),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ThreeArchedCircle(
                        size: 36.0,
                        color: context.theme.colorScheme.secondary,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Obx(
                        (context) {
                          final allSelected =
                              _selectedTracksToUpdate.isNotEmpty && _missingTracksPaths.every((e) => _missingTracksSuggestions[e] == null || _selectedTracksToUpdate[e] == true);
                          return FloatingActionButton.small(
                            heroTag: 'indexer_missing_tracks_fab_hero_small',
                            tooltip: lang.SELECT_ALL,
                            backgroundColor: allSelected ? CurrentColor.inst.color.withValues(alpha: 1.0) : context.theme.disabledColor.withValues(alpha: 1.0),
                            child: Icon(
                              allSelected ? Broken.tick_square : Broken.task_square,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            onPressed: () {
                              final allSelected = _selectedTracksToUpdate.isNotEmpty &&
                                  _missingTracksPaths.every((e) => _missingTracksSuggestions[e] == null || _selectedTracksToUpdate[e] == true);
                              if (allSelected) {
                                _selectedTracksToUpdate.clear();
                              } else {
                                _missingTracksPaths.loop((e) {
                                  if (_missingTracksSuggestions[e] != null) _selectedTracksToUpdate[e] = true;
                                });
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 8.0),
                      Obx(
                        (context) {
                          final totalLength = _selectedTracksToUpdate.length;
                          return FloatingActionButton.extended(
                            heroTag: 'indexer_missing_tracks_fab_hero_extended',
                            backgroundColor: (totalLength <= 0 ? context.theme.disabledColor : CurrentColor.inst.color).withValues(alpha: 1.0),
                            extendedPadding: const EdgeInsets.symmetric(horizontal: 12.0),
                            onPressed: () async {
                              final isUpdating = false.obs;
                              NamidaNavigator.inst.navigateDialog(
                                onDisposing: () {
                                  isUpdating.close();
                                },
                                tapToDismiss: () => !isUpdating.value,
                                dialog: CustomBlurryDialog(
                                  isWarning: true,
                                  normalTitleStyle: true,
                                  bodyText: "${lang.UPDATE} ${_selectedTracksToUpdate.length.displayTrackKeyword}?",
                                  actions: [
                                    const CancelButton(),
                                    const SizedBox(width: 8.0),
                                    ObxO(
                                      rx: isUpdating,
                                      builder: (context, updating) => AnimatedEnabled(
                                        enabled: !updating,
                                        child: NamidaButton(
                                          text: lang.UPDATE.toUpperCase(),
                                          onPressed: () async {
                                            isUpdating.value = true;
                                            await _onUpdating();
                                            isUpdating.value = false;
                                            NamidaNavigator.inst.closeDialog();
                                          },
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                            label: Row(children: [
                              Icon(
                                Broken.pen_add,
                                size: 20.0,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 12.0),
                              Text(
                                "${lang.UPDATE} ($totalLength)",
                                style: context.textTheme.displayMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
