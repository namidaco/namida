import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/color_m.dart';
import 'package:namida/class/file_parts.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/track_clear_dialog.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/network_artwork.dart';
import 'package:namida/ui/widgets/settings/advanced_settings.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';

void showTrackAdvancedDialog({
  required List<Selectable> tracks,
  required NetworkArtworkInfo? networkArtworkInfo,
  required Color colorScheme,
  required QueueSourceBase source,
}) async {
  if (tracks.isEmpty) return;
  final isSingle = tracks.length == 1;

  final Map<TrackSource, int> sourcesMap = {};
  final tracksWithYTID = <Track, String>{};
  final tracksForColorPaletteMap = <String, Track>{};
  tracks.loop((e) {
    final twd = e.trackWithDate;
    if (twd != null) {
      sourcesMap.update(twd.source, (value) => value + 1, ifAbsent: () => 1);
    }

    final ytid = e.track.youtubeID;
    if (ytid.isNotEmpty) tracksWithYTID[e.track] ??= ytid;
    tracksForColorPaletteMap[e.track.pathToImage] = e.track;
  });
  // -- makes sense when group artworks by albums enabled, or whatever reason that makes tracks have same image path
  final tracksForColorPalette = tracksForColorPaletteMap.values.toList();

  final willUpdateArtwork = false.obs;

  final reIndexedTracksSuccessful = 0.obs;
  final reIndexedTracksFailed = 0.obs;
  final shouldShowReIndexProgress = false.obs;
  final shouldReIndexEnabled = true.obs;

  final tracksUniquedPhysical = tracks.map((element) => element.track).mapAsPhysical()..removeDuplicates();
  final firstTrackPhysicalExists = tracksUniquedPhysical.firstOrNull?.track.existsSync() ?? false; // sync is faster
  final firstTracksDirectoryPath = tracksUniquedPhysical.firstOrNull?.track.path.getDirectoryPath;

  final videosOnlyCount = tracksUniquedPhysical.fold(0, (previousValue, element) => previousValue + (element.track is Video ? 1 : 0));
  final tracksOnlyCount = tracksUniquedPhysical.length - videosOnlyCount;

  final canShowClearDialogRx = true.obs;

  final isCopyingRx = false.obs;
  final isMovingRx = false.obs;
  final isDeletingRx = false.obs;

  void updateCanShowClearDialog(CacheVideoPriority? cachePriority) async {
    canShowClearDialogRx.value = cachePriority == CacheVideoPriority.VIP ? false : await tracks.hasAnythingCached;
  }

  final setVideosPriorityChip = SetVideosPriorityChip(
    totalCount: tracksWithYTID.length,
    videosId: tracksWithYTID.values,
    countToText: (count) => count.displayTrackKeyword,
    onInitialPriority: updateCanShowClearDialog,
    onChanged: updateCanShowClearDialog,
  );

  void onCopyOrMove({required String title, required bool isMove}) async {
    if (tracksUniquedPhysical.isEmpty) return;
    if (!await requestManageStoragePermission()) return;

    final initialDir = tracksUniquedPhysical.firstOrNull?.folder.path;
    final note =
        "$title (${[
          if (tracksOnlyCount > 0) tracksOnlyCount.displayTrackKeyword,
          if (videosOnlyCount > 0) videosOnlyCount.displayVideoKeyword,
        ].join(' & ')})";
    final destinationDir = await NamidaFileBrowser.pickDirectory(
      note: note,
      initialDirectory: initialDir,
    );

    if (destinationDir == null) {
      snackyy(title: lang.error, message: lang.noFolderChosen, isError: true);
      return;
    }
    if (!destinationDir.existsSync()) {
      snackyy(title: lang.error, message: lang.directoryDoesntExist, isError: true);
      return;
    }

    final rxToEdit = isMove ? isMovingRx : isCopyingRx;

    rxToEdit.value = true;

    bool? overwriteForAll;
    Completer<void>? isAskingCompleter;

    Future<bool> checkCanExecuteOrOverwrite(String path) async {
      if (overwriteForAll != null) return overwriteForAll!;

      final exists = await File(path).exists();
      if (!exists) return true;

      if (isAskingCompleter != null) {
        // wait if previous ask modified overwriteForAll
        await isAskingCompleter?.future;
        if (overwriteForAll != null) return overwriteForAll!;
      }

      isAskingCompleter = Completer<void>();

      final applyForAllRx = false.obs;
      bool overwrite = false;
      await NamidaNavigator.inst.navigateDialog(
        onDisposing: () {
          applyForAllRx.close();
        },
        dialog: CustomBlurryDialog(
          isWarning: true,
          normalTitleStyle: true,
          actions: [
            NamidaButton(
              colorScheme: Colors.green,
              text: lang.skip.toUpperCase(),
              onTap: () async {
                overwrite = false;
                NamidaNavigator.inst.closeDialog();
              },
            ),
            NamidaButton(
              colorScheme: Colors.red,
              text: lang.confirm.toUpperCase(),
              onTap: () async {
                overwrite = true;
                NamidaNavigator.inst.closeDialog();
              },
            ),
          ],
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              const SizedBox(height: 12.0),
              Text(
                "${lang.overrideOldFilesInTheSameFolder}?",
                style: namida.textTheme.displayMedium,
              ),
              const SizedBox(height: 12.0),
              Text(
                path,
                style: namida.textTheme.displaySmall,
              ),
              const SizedBox(height: 12.0),
              const NamidaContainerDivider(
                margin: EdgeInsets.symmetric(horizontal: 2.0, vertical: 6.0),
              ),
              ObxO(
                rx: applyForAllRx,
                builder: (context, forAll) => ListTileWithCheckMark(
                  icon: Broken.message_question,
                  title: lang.dontAskAgain,
                  active: forAll,
                  onTap: applyForAllRx.toggle,
                ),
              ),
            ],
          ),
        ),
      );
      if (applyForAllRx.value) {
        overwriteForAll = overwrite;
      }
      isAskingCompleter?.completeIfWasnt();
      isAskingCompleter = null;
      return overwrite;
    }

    final successPaths = <String, String>{};
    final erroredPaths = <String, Object>{};
    Future<void> doForAllFiles(Future<File?> Function(File file, String newPath) callback) async {
      await Future.wait(
        tracksUniquedPhysical.map((e) async {
          try {
            final newPath = FileParts.joinPath(destinationDir.path, e.filename);
            if (newPath == e.path) {
              // -- same file
              successPaths[e.path] = newPath;
            } else if (await checkCanExecuteOrOverwrite(newPath)) {
              final result = await callback(File(e.path), newPath);
              result != null ? successPaths[e.path] = newPath : erroredPaths[e.path] = '';
            } else {
              erroredPaths[e.path] = lang.fileAlreadyExists;
            }
          } catch (err) {
            erroredPaths[e.path] = err;
          }
        }),
      );
    }

    void openFailedPathsInfo() {
      final pathsKeys = erroredPaths.keys.toList();
      if (pathsKeys.isEmpty) return;

      final separatorWidget = NamidaContainerDivider(
        margin: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 4.0),
      );
      NamidaNavigator.inst.navigateDialog(
        dialog: CustomBlurryDialog(
          title: '${lang.failed}: ${pathsKeys.length.displayFilesKeyword}',
          normalTitleStyle: true,
          actions: [
            const DoneButton(),
          ],
          child: SizedBox(
            height: namida.height * 0.5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ListView.separated(
                separatorBuilder: (context, index) => separatorWidget,
                itemCount: pathsKeys.length,
                itemBuilder: (context, i) {
                  final pathKey = pathsKeys[i];
                  final err = erroredPaths[pathKey];
                  final errText = err.toString();
                  return TapDetector(
                    onTap: () => NamidaUtils.copyToClipboard(content: pathKey),
                    child: Row(
                      mainAxisSize: .min,
                      children: [
                        Icon(
                          Broken.danger,
                          size: 16.0,
                        ),
                        const SizedBox(width: 8.0),
                        Flexible(
                          child: Column(
                            mainAxisSize: .min,
                            crossAxisAlignment: .start,
                            children: [
                              Text(
                                pathKey,
                                style: context.textTheme.displaySmall,
                              ),
                              Text(
                                errText,
                                style: context.textTheme.displaySmall?.copyWith(fontSize: 11.0),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    try {
      if (isMove) {
        await doForAllFiles((file, newPath) => file.move(newPath));
        await EditDeleteController.inst.updateTrackPathInEveryPartOfNamidaBulk(successPaths, removeOldTracksFromLibrary: true);
      } else {
        await doForAllFiles((file, newPath) => file.copy(newPath));
        await Indexer.inst.convertPathsToTracksAndAddToLists(successPaths.values);
      }
    } finally {
      rxToEdit.value = false;

      if (successPaths.isNotEmpty || erroredPaths.isNotEmpty) {
        String? successMessage = successPaths.isNotEmpty ? lang.countFiles(count: successPaths.length) : null;
        String? errorMessage = erroredPaths.isNotEmpty ? lang.countFiles(count: erroredPaths.length) : null;
        if (successMessage != null && errorMessage != null) {
          successMessage = "${lang.succeeded}: $successMessage";
          errorMessage = "${lang.failed}: $errorMessage";
        }
        if (errorMessage != null) {
          String? combinedErrorMsg = erroredPaths.values.firstOrNull?.toString();
          for (final e in erroredPaths.values.skip(1)) {
            if (e.toString() != combinedErrorMsg) {
              combinedErrorMsg = null;
              break;
            }
          }
          if (combinedErrorMsg != null) {
            errorMessage += '\n$combinedErrorMsg';
          }
        }

        snackyy(
          title: "$title: ${erroredPaths.isNotEmpty ? lang.failed : lang.succeeded}",
          message: [
            ?successMessage,
            ?errorMessage,
          ].join('\n'),
          button: erroredPaths.isNotEmpty ? SnackbarButton(text: lang.info, function: openFailedPathsInfo) : null,
          isError: erroredPaths.isNotEmpty,
          borderColor: erroredPaths.isNotEmpty ? Colors.red.withOpacityExt(0.2) : Colors.green.withOpacityExt(0.5),
        );
      }

      if (isMove) {
        NamidaNavigator.inst.closeAllDialogs();
      }
    }
  }

  await NamidaNavigator.inst.navigateDialog(
    tapToDismiss: () => !isDeletingRx.value && !isMovingRx.value && !isCopyingRx.value,
    onDisposing: () {
      willUpdateArtwork.close();
      reIndexedTracksSuccessful.close();
      reIndexedTracksFailed.close();
      shouldShowReIndexProgress.close();
      shouldReIndexEnabled.close();
      canShowClearDialogRx.close();
      isCopyingRx.close();
      isMovingRx.close();
      isDeletingRx.close();
    },
    colorScheme: colorScheme,
    dialogBuilder: (theme) => CustomBlurryDialog(
      theme: theme,
      normalTitleStyle: true,
      title: lang.advanced,
      child: Column(
        children: [
          if (tracksOnlyCount > 0 || videosOnlyCount > 0)
            Row(
              children: [
                Expanded(
                  child: ObxO(
                    rx: isCopyingRx,
                    builder: (context, isLoading) => AnimatedEnabled(
                      enabled: !isLoading,
                      child: AnimatedRotatingBorder(
                        isLoading: isLoading,
                        borderRadius: 16.0.multipliedRadius,
                        colors: [colorScheme.withOpacityExt(0.5)],
                        child: CustomListTile(
                          extraDense: true,
                          maxTitleLines: 1,
                          borderR: 16.0,
                          passedColor: colorScheme,
                          title: lang.copy,
                          icon: Broken.copy,
                          onTap: () => onCopyOrMove(title: lang.copy, isMove: false),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4.0),
                Expanded(
                  child: ObxO(
                    rx: isMovingRx,
                    builder: (context, isLoading) => AnimatedEnabled(
                      enabled: !isLoading,
                      child: AnimatedRotatingBorder(
                        isLoading: isLoading,
                        borderRadius: 16.0.multipliedRadius,
                        colors: [colorScheme.withOpacityExt(0.5)],
                        child: CustomListTile(
                          extraDense: true,
                          maxTitleLines: 1,
                          borderR: 16.0,
                          passedColor: colorScheme,
                          title: lang.move,
                          icon: Broken.blend_2,
                          onTap: () => onCopyOrMove(title: lang.move, isMove: true),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ObxO(
            rx: canShowClearDialogRx,
            builder: (context, canShowClearDialog) => Opacity(
              opacity: canShowClearDialog ? 1.0 : 0.6,
              child: CustomListTile(
                passedColor: colorScheme,
                title: lang.clear,
                subtitle: lang.chooseWhatToClear,
                icon: Broken.broom,
                onTap: canShowClearDialog ? () => showTrackClearDialog(tracks, colorScheme) : null,
                trailing: setVideosPriorityChip,
              ),
            ),
          ),
          if (tracksOnlyCount > 0 || videosOnlyCount > 0)
            ObxO(
              rx: isDeletingRx,
              builder: (context, isLoading) => AnimatedEnabled(
                enabled: !isLoading,
                child: AnimatedRotatingBorder(
                  isLoading: isLoading,
                  borderRadius: 18.0.multipliedRadius,
                  colors: [colorScheme.withOpacityExt(0.5)],
                  child: CustomListTile(
                    extraDense: true,
                    passedColor: colorScheme,
                    title: lang.delete,
                    subtitle: lang.deleteNTracksFromStorage(
                      numberText: [
                        if (tracksOnlyCount > 0) tracksOnlyCount.displayTrackKeyword,
                        if (videosOnlyCount > 0) videosOnlyCount.displayVideoKeyword,
                      ].join(' & ').addDQuotation(),
                    ),
                    icon: Broken.danger,
                    onTap: () => showTrackDeletePermanentlyDialog(
                      tracks,
                      colorScheme,
                      onConfirm: () => NamidaNavigator.inst.closeDialog(),
                      afterDone: () => NamidaNavigator.inst.closeAllDialogs(),
                      isDeletingRx: isDeletingRx,
                    ),
                  ),
                ),
              ),
            ),
          if (sourcesMap.isNotEmpty)
            CustomListTile(
              passedColor: colorScheme,
              title: lang.source,
              subtitle: isSingle ? sourcesMap.keys.first.name : sourcesMap.entries.map((e) => '${e.key.name}: ${e.value.formatDecimal()}').join('\n'),
              icon: Broken.attach_circle,
              onTap: () {},
            ),

          // -- Updating directory path option, only for tracks whithin the same parent directory.
          if (!isSingle && firstTracksDirectoryPath != null && tracksUniquedPhysical.every((element) => element.track.path.startsWith(firstTracksDirectoryPath)))
            UpdateDirectoryPathListTile(
              colorScheme: colorScheme,
              oldPath: firstTracksDirectoryPath,
              tracksPaths: tracksUniquedPhysical.map((e) => e.track.path),
            ),
          if (NamidaFeaturesVisibility.methodSetMusicAs && isSingle && firstTrackPhysicalExists)
            CustomListTile(
              passedColor: colorScheme,
              title: lang.setAs,
              subtitle: "${lang.ringtone}, ${lang.notification}, ${lang.alarm}",
              icon: Broken.volume_high,
              onTap: () {
                NamidaNavigator.inst.closeDialog();

                final selected = <SetMusicAsAction>[].obs;
                NamidaNavigator.inst.navigateDialog(
                  onDisposing: () {
                    selected.close();
                  },
                  colorScheme: colorScheme,
                  dialogBuilder: (theme) => CustomBlurryDialog(
                    title: lang.setAs,
                    icon: Broken.volume_high,
                    normalTitleStyle: true,
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: lang.confirm,
                        onTap: () async {
                          final success = await NamidaChannel.inst.setMusicAs(path: tracks.first.track.path, types: selected.value);
                          if (success) NamidaNavigator.inst.closeDialog();
                        },
                      ),
                    ],
                    child: Column(
                      children: SetMusicAsAction.values
                          .map(
                            (e) => Obx(
                              (context) => Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: ListTileWithCheckMark(
                                  active: selected.contains(e),
                                  title: e.toText(),
                                  onTap: () => selected.addOrRemove(e),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          if (tracksUniquedPhysical.isNotEmpty)
            Obx(
              (context) {
                final shouldShow = shouldShowReIndexProgress.valueR;
                final errors = reIndexedTracksFailed.valueR;
                final secondLine = errors > 0 ? '\n${lang.error}: $errors' : '';
                return CustomListTile(
                  enabled: shouldReIndexEnabled.valueR,
                  passedColor: colorScheme,
                  title: lang.reIndex,
                  icon: Broken.direct_inbox,
                  subtitle: shouldShow ? "${reIndexedTracksSuccessful.valueR}/${tracksUniquedPhysical.length}$secondLine" : null,
                  trailingRaw: NamidaInkWell(
                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
                    bgColor: theme.cardColor,
                    onTap: () => willUpdateArtwork.toggle(),
                    child: Obx((context) => Text('${lang.artwork}  ${willUpdateArtwork.valueR ? '✓' : 'x'}')),
                  ),
                  onTap: () async {
                    await Indexer.inst.reindexTracks(
                      tracks: tracksUniquedPhysical,
                      updateArtwork: willUpdateArtwork.value,
                      tryExtractingFromFilename: false,
                      onProgress: (didExtract) {
                        shouldReIndexEnabled.value = false;
                        shouldShowReIndexProgress.value = true;
                        if (didExtract) {
                          reIndexedTracksSuccessful.value++;
                        } else {
                          reIndexedTracksFailed.value++;
                        }
                      },
                      onFinish: (tracksLength) {},
                    );
                  },
                );
              },
            ),

          if (source == QueueSource.history && isSingle)
            CustomListTile(
              passedColor: colorScheme,
              title: lang.replaceAllListensWithAnotherTrack,
              icon: Broken.convert_card,
              onTap: () async {
                void showWarningAboutTrackListens(Track trackWillBeReplaced, Track newTrack) {
                  final listens = HistoryController.inst.topTracksMapListens.value[trackWillBeReplaced] ?? [];
                  NamidaNavigator.inst.navigateDialog(
                    colorScheme: colorScheme,
                    dialogBuilder: (theme) => CustomBlurryDialog(
                      isWarning: true,
                      normalTitleStyle: true,
                      actions: [
                        const CancelButton(),
                        NamidaButton(
                          text: lang.confirm,
                          onTap: () async {
                            await HistoryController.inst.replaceAllTracksInsideHistory(trackWillBeReplaced, newTrack);
                            NamidaNavigator.inst.closeAllDialogs();
                          },
                        ),
                      ],
                      bodyText: lang.historyListensReplaceWarning(
                        listensCount: listens.length,
                        newTrackInfo: '"${newTrack.originalArtist} - ${newTrack.title}"',
                        oldTrackInfo: '"${trackWillBeReplaced.originalArtist} - ${trackWillBeReplaced.title}"',
                      ),
                    ),
                  );
                }

                showLibraryTracksChooseDialog(
                  onChoose: (choosenTrack) => showWarningAboutTrackListens(tracks.first.track, choosenTrack),
                  colorScheme: colorScheme,
                );
              },
            ),
          FutureBuilder(
            future: Future.wait<NamidaColor>(
              networkArtworkInfo != null
                  ? [
                      CurrentColor.inst.getTrackColors(kDummyTrack, networkArtworkInfo: networkArtworkInfo, delightnedAndAlpha: false, useIsolate: true),
                    ]
                  : tracksForColorPalette
                        .take(4)
                        .map(
                          (e) => CurrentColor.inst.getTrackColors(e, networkArtworkInfo: null, delightnedAndAlpha: false, useIsolate: true),
                        ),
            ),
            builder: (context, snapshot) {
              final trackColors = snapshot.data;
              return CustomListTile(
                enabled: tracksForColorPalette.length == 1
                    ? true // bcz most likely already obtained
                    : snapshot.connectionState == ConnectionState.done,
                passedColor: colorScheme,
                title: lang.colorPalette,
                icon: Broken.color_swatch,
                trailingRaw: CustomAnimatedSwitcher(
                  duration: Duration(milliseconds: 200),
                  child: trackColors == null
                      ? SizedBox(
                          key: Key('color_not_visible'),
                        )
                      : Padding(
                          key: Key('color_visible'),
                          padding: const EdgeInsets.only(right: 12.0),
                          child: CustomPaint(
                            painter: _QuarterCirclePainter(
                              colors: trackColors.map((e) => e.color).toList(),
                              radius: 14.0,
                            ),
                          ),
                        ),
                ),
                onTap: () {
                  void onAction() {
                    NamidaNavigator.inst.closeAllDialogs(); // close all dialogs cuz dialog color should update
                  }

                  _showTrackColorPaletteDialog(
                    colorScheme: colorScheme,
                    trackColor: trackColors?.combine(),
                    onFinalColor: (palette, color) async {
                      onAction();
                      final newNC = NamidaColor.create(
                        used: color,
                        palette: palette,
                      );
                      if (networkArtworkInfo != null) {
                        await CurrentColor.inst.reExtractNetworkArtworkColorPalette(
                          networkArtworkInfo: networkArtworkInfo,
                          newNC: newNC,
                        );
                      }
                      for (final track in tracksForColorPalette) {
                        await CurrentColor.inst.reExtractTrackColorPalette(
                          track: track,
                          imagePath: null,
                          newNC: newNC,
                        );
                      }
                    },
                    onRestoreDefaults: () async {
                      onAction();
                      if (networkArtworkInfo != null) {
                        await CurrentColor.inst.reExtractNetworkArtworkColorPalette(
                          networkArtworkInfo: networkArtworkInfo,
                          newNC: null,
                        );
                      }
                      for (final track in tracksForColorPalette) {
                        await CurrentColor.inst.reExtractTrackColorPalette(
                          track: track,
                          imagePath: track.pathToImage,
                          newNC: null,
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    ),
  );
}

void _showTrackColorPaletteDialog({
  required Color colorScheme,
  required NamidaColor? trackColor,
  required void Function(List<Color> palette, Color color) onFinalColor,
  required void Function()? onRestoreDefaults,
}) async {
  final allPaletteColor = List<Color>.from(trackColor?.palette ?? []).obs;
  final selectedColors = <Color>[].obs;
  final removedColors = <Color>[].obs;
  final didChangeOriginalPalette = false.obs;

  final defaultMixes = trackColor == null
      ? null
      : [
          trackColor.palette,
          trackColor.palette.takeFew(),
          trackColor.palette.getRandomSample(10),
          trackColor.palette.getRandomSample(10),
          trackColor.palette.getRandomSample(10),
          trackColor.palette.getRandomSample(10),
        ];

  void showAddNewColorPaletteDialog() {
    NamidaNavigator.inst.navigateDialog(
      colorScheme: colorScheme,
      dialogBuilder: (theme) => NamidaColorPickerDialog(
        initialColor: allPaletteColor.value.lastOrNull ?? Colors.black,
        doneText: lang.add,
        onDonePressed: (color) {
          allPaletteColor.add(color);
          didChangeOriginalPalette.value = true;
          NamidaNavigator.inst.closeDialog();
        },
        cancelButton: true,
      ),
    );
  }

  final initialColor = trackColor?.color;
  final finalColorToBeUsed = initialColor.obs;

  Widget getText(String text, {TextStyle? style}) {
    return Text(text, style: style ?? namida.textTheme.displaySmall);
  }

  Widget getColorWidget(Color? color, [Widget? child]) => CircleAvatar(
    backgroundColor: color,
    maxRadius: 14.0,
    child: child,
  );

  Widget mixWidget({
    required String title,
    required List<Iterable<Color>> allMixes,
  }) {
    return Row(
      children: [
        getText('$title  '),
        ...allMixes
            .map(
              (colors) {
                final mixExtra = NamidaColor.mixIntColors(colors);
                return TapDetector(
                  onTap: () => finalColorToBeUsed.value = mixExtra,
                  child: getColorWidget(mixExtra),
                );
              },
            )
            .addSeparators(separator: const SizedBox(width: 4.0)),
      ],
    );
  }

  Widget getPalettesWidget({
    required List<Color> palette,
    required void Function(Color color) onColorTap,
    required void Function(Color color) onColorLongPress,
    required bool Function(Color color) displayCheckMark,
    required ThemeData theme,
    Widget? additionalWidget,
  }) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: (namida.isDarkMode ? Colors.black : Colors.white).withAlpha(160),
        border: Border.all(color: theme.shadowColor),
        borderRadius: BorderRadius.circular(12.0.multipliedRadius),
      ),
      child: Wrap(
        runSpacing: 8.0,
        children: [
          ...palette.map(
            (e) => Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: GestureDetector(
                onTap: () => onColorTap(e),
                onLongPress: () => onColorLongPress(e),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    getColorWidget(e),
                    Container(
                      padding: const EdgeInsets.all(2.0),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Text('✓'),
                    ).animateEntrance(
                      showWhen: displayCheckMark(e),
                      allCurves: Curves.easeInOutQuart,
                      durationMS: 100,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ?additionalWidget,
        ],
      ),
    );
  }

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      allPaletteColor.close();
      selectedColors.close();
      removedColors.close();
      didChangeOriginalPalette.close();
      finalColorToBeUsed.close();
    },
    colorScheme: colorScheme,
    dialogBuilder: (theme) {
      return CustomBlurryDialog(
        normalTitleStyle: true,
        title: lang.colorPalette,
        leftAction: onRestoreDefaults == null
            ? null
            : NamidaIconButton(
                tooltip: () => lang.restoreDefaults,
                onPressed: onRestoreDefaults,
                icon: Broken.refresh,
              ),
        actions: [
          const CancelButton(),
          ObxO(
            rx: finalColorToBeUsed,
            builder: (context, finalColor) => NamidaButton(
              enabled: finalColor != null && finalColor != initialColor,
              text: lang.confirm,
              onTap: () {
                if (finalColor != null) {
                  onFinalColor(allPaletteColor.value, finalColor);
                }
              },
            ),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            getText('- ${lang.colorPaletteNote1}'),
            getText('- ${lang.colorPaletteNote2}\n'),

            // --- Removed Colors
            Obx(
              (context) => removedColors.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        getText(lang.removed),
                        const SizedBox(height: 8.0),
                        getPalettesWidget(
                          palette: removedColors.valueR,
                          onColorTap: (color) {},
                          onColorLongPress: (color) {
                            allPaletteColor.add(color);
                            removedColors.remove(color);
                          },
                          displayCheckMark: (color) => false,
                          theme: theme,
                        ),
                        const SizedBox(height: 12.0),
                      ],
                    )
                  : const SizedBox(),
            ),

            // --- Actual Palette
            getText(lang.palette),
            const SizedBox(height: 8.0),
            Obx(
              (context) => ConstrainedBox(
                constraints: BoxConstraints(maxHeight: context.height * 0.4),
                child: SmoothSingleChildScrollView(
                  child: getPalettesWidget(
                    palette: allPaletteColor.valueR,
                    onColorTap: (color) => selectedColors.addOrRemove(color),
                    onColorLongPress: (color) {
                      allPaletteColor.remove(color);
                      selectedColors.remove(color);
                      removedColors.add(color);
                      didChangeOriginalPalette.value = true;
                    },
                    displayCheckMark: (color) => selectedColors.contains(color),
                    theme: theme,
                    additionalWidget: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.shadowColor),
                        shape: BoxShape.circle,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(100.0),
                        onTap: showAddNewColorPaletteDialog,
                        child: getColorWidget(
                          theme.cardColor.withAlpha(200),
                          Icon(
                            Broken.add,
                            color: theme.cardColor.withAlpha(200).invert(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            Obx(
              (context) => Wrap(
                spacing: 12.0,
                runSpacing: 6.0,
                children: [
                  if (defaultMixes != null)
                    mixWidget(
                      title: lang.paletteMix,
                      allMixes: defaultMixes,
                    ),
                  if (didChangeOriginalPalette.valueR)
                    mixWidget(
                      title: lang.paletteNewMix,
                      allMixes: [allPaletteColor.valueR],
                    ),
                  if (selectedColors.isNotEmpty)
                    mixWidget(
                      title: lang.paletteSelectedMix,
                      allMixes: [selectedColors.valueR],
                    ),
                ],
              ),
            ),
            const NamidaContainerDivider(
              height: 4.0,
              margin: EdgeInsets.symmetric(vertical: 10.0),
            ),
            Row(
              children: [
                getText('${lang.used} : ', style: namida.textTheme.displayMedium),
                const SizedBox(width: 12.0),
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    height: 30.0,
                    child: ObxO(
                      rx: finalColorToBeUsed,
                      builder: (context, finalColorToBeUsed) => AnimatedDecoration(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: finalColorToBeUsed,
                          borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
              ],
            ),
          ],
        ),
      );
    },
  );
}

void showTrackDeletePermanentlyDialog(List<Selectable> tracks, Color? colorScheme, {void Function()? afterDone, void Function()? onConfirm, Rx<bool>? isDeletingRx}) {
  final videosOnlyCount = tracks.fold(0, (previousValue, element) => previousValue + (element.track is Video ? 1 : 0));
  final tracksOnlyCount = tracks.length - videosOnlyCount;

  Rx<bool>? isDeletingRxLocal;
  if (isDeletingRx == null) {
    isDeletingRxLocal = false.obs;
  }

  NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      isDeletingRxLocal?.close();
    },
    tapToDismiss: () => isDeletingRxLocal == null || !isDeletingRxLocal.value,
    colorScheme: colorScheme,
    dialogBuilder: (theme) => CustomBlurryDialog(
      theme: theme,
      normalTitleStyle: true,
      isWarning: true,
      bodyText:
          "${lang.deleteNTracksFromStorage(numberText: [
            if (tracksOnlyCount > 0) tracksOnlyCount.displayTrackKeyword,
            if (videosOnlyCount > 0) videosOnlyCount.displayVideoKeyword,
          ].join(' & ').addDQuotation())}?",
      actions: [
        const CancelButton(),
        ObxOrNull(
          rx: isDeletingRxLocal,
          builder: (context, deleting) => NamidaButton(
            enabled: deleting != true,
            isLoading: deleting,
            colorScheme: Colors.red,
            text: lang.delete.toUpperCase(),
            onTap: () async {
              final rx = isDeletingRxLocal ?? isDeletingRx;
              rx?.value = true;
              onConfirm?.call();
              await EditDeleteController.inst.deleteTracksFromStoragePermanently(tracks);
              rx?.value = false;
              afterDone?.call();
            },
          ),
        ),
      ],
    ),
  );
}

void showLibraryTracksChooseDialog({
  required void Function(Track choosenTrack) onChoose,
  String trackName = '',
  Color? colorScheme,
}) async {
  final allTracksListBase = List<Track>.from(allTracksInLibrary);
  final allTracksList = allTracksListBase.obs;
  final selectedTrack = Rxn<Track>();
  final isSearching = false.obs;
  void onTrackTap(Track tr) {
    if (selectedTrack.value == tr) {
      selectedTrack.value = null;
    } else {
      selectedTrack.value = tr;
    }
  }

  final searchController = TextEditingController();
  final scrollController = NamidaScrollController.create();
  final focusNode = FocusNode();
  final searchManager = _TracksSearchTemp(
    (tracks) {
      allTracksList.value = tracks;
      isSearching.value = false;
    },
  );

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      allTracksList.close();
      selectedTrack.close();
      isSearching.close();
      searchController.dispose();
      scrollController.dispose();
      focusNode.dispose();
      searchManager.dispose();
    },
    colorScheme: colorScheme,
    dialogBuilder: (theme) => CustomBlurryDialog(
      title: lang.choose,
      normalTitleStyle: true,
      contentPadding: EdgeInsets.zero,
      horizontalInset: 32.0,
      verticalInset: 32.0,
      actions: [
        const CancelButton(),
        ObxO(
          rx: selectedTrack,
          builder: (context, selectedTr) => NamidaButton(
            enabled: selectedTr != null,
            text: lang.confirm,
            onTap: () => onChoose(selectedTrack.value!),
          ),
        ),
      ],
      child: SizedBox(
        width: namida.width,
        height: namida.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      focusNode: focusNode,
                      textFieldController: searchController,
                      textFieldHintText: lang.search,
                      onTextFieldValueChanged: (value) {
                        if (value.isEmpty) {
                          allTracksList.value = allTracksListBase;
                        } else {
                          isSearching.value = true;
                          searchManager.search(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      NamidaIconButton(
                        icon: Broken.close_circle,
                        onPressed: () {
                          allTracksList.value = allTracksListBase;
                          searchController.clear();
                        },
                      ),
                      ObxO(
                        rx: isSearching,
                        builder: (context, isSearching) => isSearching
                            ? const CircularProgressIndicator.adaptive(
                                strokeWidth: 2.0,
                                strokeCap: StrokeCap.round,
                              )
                            : const SizedBox(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8.0),
            if (trackName != '')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  trackName,
                  style: namida.textTheme.displayMedium,
                ),
              ),
            if (trackName != '') const SizedBox(height: 8.0),
            Expanded(
              child: NamidaScrollbar(
                controller: scrollController,
                child: TrackTilePropertiesProvider(
                  configs: TrackTilePropertiesConfigs(
                    queueSource: QueueSource.others(searchController.text),
                  ),
                  builder: (properties) => Obx(
                    (context) => SuperSmoothListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: allTracksList.length,
                      itemExtent: Dimensions.inst.trackTileItemExtent,
                      itemBuilder: (context, i) {
                        final tr = allTracksList.value[i];
                        return TrackTile(
                          properties: properties,
                          trackOrTwd: tr,
                          index: i,
                          tracks: allTracksList.value,
                          onTap: () => onTrackTap(tr),
                          onRightAreaTap: () => onTrackTap(tr),
                          trailingWidget: ObxO(
                            rx: selectedTrack,
                            builder: (context, selectedTrack) => NamidaCheckMark(
                              size: 22.0,
                              active: selectedTrack == tr,
                            ),
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
      ),
    ),
  );
}

class _TracksSearchTemp with PortsProvider<Map> {
  final void Function(List<Track> tracks) _onResult;
  _TracksSearchTemp(this._onResult);

  void search(String text) async {
    if (!isInitialized) await initialize();
    final p = {'text': text, 'temp': true};
    await sendPort(p);
  }

  @override
  void onResult(dynamic result) {
    if (result == null) return;
    final r = result as (List<Track>, bool, String);
    _onResult(r.$1);
  }

  @override
  IsolateFunctionReturnBuild<Map> isolateFunction(SendPort port) {
    final params = SearchSortController.inst.generateTrackSearchIsolateParams(port);
    return IsolateFunctionReturnBuild(SearchSortController.searchTracksIsolate, params);
  }

  Future<void> dispose() async => await disposePort();
}

class _QuarterCirclePainter extends CustomPainter {
  final double radius;
  final List<Color> colors;

  const _QuarterCirclePainter({
    required this.colors,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(0, 0);
    final Paint paint = Paint()..style = PaintingStyle.fill;

    final int segments = colors.length;
    final double sweep = 2 * math.pi / segments;
    final double startAngle = -math.pi / 2;

    final Rect arcRect = Rect.fromCircle(center: center, radius: radius);

    int index = 0;
    for (final color in colors) {
      paint.color = color;
      canvas.drawArc(
        arcRect,
        startAngle + index * sweep,
        sweep,
        true,
        paint,
      );
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
