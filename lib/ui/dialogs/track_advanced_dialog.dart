import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/color_m.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/edit_delete_controller.dart';
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
  required QueueSource source,
  required List<(String, String)> albumsUniqued,
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

  final firstTrackExists = File(tracks.first.track.path).existsSync(); // sync is faster

  final reIndexedTracksSuccessful = 0.obs;
  final reIndexedTracksFailed = 0.obs;
  final shouldShowReIndexProgress = false.obs;
  final shouldReIndexEnabled = true.obs;

  final tracksUniqued = tracks.uniqued((element) => element.track);

  final firstTracksDirectoryPath = tracksUniqued.first.track.path.getDirectoryPath;

  void showTrackDeletePermanentlyDialog(List<Selectable> tracks, Color colorScheme) {
    late final isDeleting = false.obs;
    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        isDeleting.close();
      },
      tapToDismiss: () => !isDeleting.value,
      colorScheme: colorScheme,
      dialogBuilder: (theme) => CustomBlurryDialog(
        theme: theme,
        normalTitleStyle: true,
        isWarning: true,
        bodyText: lang.CONFIRM,
        actions: [
          const CancelButton(),
          ObxO(
            rx: isDeleting,
            builder: (context, deleting) => AnimatedEnabled(
              enabled: !deleting,
              child: NamidaButton(
                text: lang.DELETE.toUpperCase(),
                onPressed: () async {
                  isDeleting.value = true;
                  await EditDeleteController.inst.deleteTracksFromStoragePermanently(tracks);
                  isDeleting.value = false;
                  NamidaNavigator.inst.closeDialog(2);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  final videosOnlyCount = tracks.fold(0, (previousValue, element) => previousValue + (element.track is Video ? 1 : 0));
  final tracksOnlyCount = tracks.length - videosOnlyCount;

  final canShowClearDialogRx = true.obs;

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

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      willUpdateArtwork.close();
      reIndexedTracksSuccessful.close();
      reIndexedTracksFailed.close();
      shouldShowReIndexProgress.close();
      shouldReIndexEnabled.close();
      canShowClearDialogRx.close();
    },
    colorScheme: colorScheme,
    dialogBuilder: (theme) => CustomBlurryDialog(
      theme: theme,
      normalTitleStyle: true,
      title: lang.ADVANCED,
      child: Column(
        children: [
          ObxO(
            rx: canShowClearDialogRx,
            builder: (context, canShowClearDialog) => Opacity(
              opacity: canShowClearDialog ? 1.0 : 0.6,
              child: CustomListTile(
                passedColor: colorScheme,
                title: lang.CLEAR,
                subtitle: lang.CHOOSE_WHAT_TO_CLEAR,
                icon: Broken.broom,
                onTap: canShowClearDialog ? () => showTrackClearDialog(tracks, colorScheme) : null,
                trailing: setVideosPriorityChip,
              ),
            ),
          ),
          CustomListTile(
            passedColor: colorScheme,
            title: lang.DELETE,
            subtitle: lang.DELETE_N_TRACKS_FROM_STORAGE.replaceFirst(
                '_NUM_',
                [
                  if (tracksOnlyCount > 0) tracksOnlyCount.displayTrackKeyword,
                  if (videosOnlyCount > 0) videosOnlyCount.displayVideoKeyword,
                ].join(' & ').addDQuotation()),
            icon: Broken.danger,
            onTap: () => showTrackDeletePermanentlyDialog(tracks, colorScheme),
          ),
          if (sourcesMap.isNotEmpty)
            CustomListTile(
              passedColor: colorScheme,
              title: lang.SOURCE,
              subtitle: isSingle ? sourcesMap.keys.first.name : sourcesMap.entries.map((e) => '${e.key.name}: ${e.value.formatDecimal()}').join('\n'),
              icon: Broken.attach_circle,
              onTap: () {},
            ),

          // -- Updating directory path option, only for tracks whithin the same parent directory.
          if (!isSingle && tracksUniqued.every((element) => element.track.path.startsWith(firstTracksDirectoryPath)))
            UpdateDirectoryPathListTile(
              colorScheme: colorScheme,
              oldPath: firstTracksDirectoryPath,
              tracksPaths: tracksUniqued.map((e) => e.track.path),
            ),
          if (NamidaFeaturesVisibility.methodSetMusicAs && isSingle && firstTrackExists)
            CustomListTile(
              visualDensity: VisualDensity.compact,
              passedColor: colorScheme,
              title: lang.SET_AS,
              subtitle: "${lang.RINGTONE}, ${lang.NOTIFICATION}, ${lang.ALARM}",
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
                    title: lang.SET_AS,
                    icon: Broken.volume_high,
                    normalTitleStyle: true,
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: lang.CONFIRM,
                        onPressed: () async {
                          final success = await NamidaChannel.inst.setMusicAs(path: tracks.first.track.path, types: selected.value);
                          if (success) NamidaNavigator.inst.closeDialog();
                        },
                      ),
                    ],
                    child: Column(
                      children: SetMusicAsAction.values
                          .map((e) => Obx(
                                (context) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: ListTileWithCheckMark(
                                    active: selected.contains(e),
                                    title: e.toText(),
                                    onTap: () => selected.addOrRemove(e),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          Obx(
            (context) {
              final shouldShow = shouldShowReIndexProgress.valueR;
              final errors = reIndexedTracksFailed.valueR;
              final secondLine = errors > 0 ? '\n${lang.ERROR}: $errors' : '';
              return CustomListTile(
                enabled: shouldReIndexEnabled.valueR,
                passedColor: colorScheme,
                title: lang.RE_INDEX,
                icon: Broken.direct_inbox,
                subtitle: shouldShow ? "${reIndexedTracksSuccessful.valueR}/${tracksUniqued.length}$secondLine" : null,
                trailingRaw: NamidaInkWell(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
                  bgColor: theme.cardColor,
                  onTap: () => willUpdateArtwork.toggle(),
                  child: Obx((context) => Text('${lang.ARTWORK}  ${willUpdateArtwork.valueR ? '✓' : 'x'}')),
                ),
                onTap: () async {
                  await Indexer.inst.reindexTracks(
                    tracks: tracks.tracks.toList(),
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
              title: lang.REPLACE_ALL_LISTENS_WITH_ANOTHER_TRACK,
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
                          text: lang.CONFIRM,
                          onPressed: () async {
                            await HistoryController.inst.replaceAllTracksInsideHistory(trackWillBeReplaced, newTrack);
                            NamidaNavigator.inst.closeDialog(3);
                          },
                        )
                      ],
                      bodyText: lang.HISTORY_LISTENS_REPLACE_WARNING
                          .replaceFirst('_LISTENS_COUNT_', listens.length.formatDecimal())
                          .replaceFirst('_OLD_TRACK_INFO_', '"${trackWillBeReplaced.originalArtist} - ${trackWillBeReplaced.title}"')
                          .replaceFirst('_NEW_TRACK_INFO_', '"${newTrack.originalArtist} - ${newTrack.title}"'),
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
                  : tracksForColorPalette.take(4).map(
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
                title: lang.COLOR_PALETTE,
                icon: Broken.color_swatch,
                trailingRaw: AnimatedSwitcher(
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
                      for (final track in tracksForColorPalette) {
                        await CurrentColor.inst.reExtractTrackColorPalette(
                          track: track,
                          imagePath: null,
                          newNC: NamidaColor.create(
                            used: color,
                            palette: palette,
                          ),
                        );
                      }
                    },
                    onRestoreDefaults: () async {
                      onAction();
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
    Color? color;
    NamidaNavigator.inst.navigateDialog(
      colorScheme: colorScheme,
      dialogBuilder: (theme) => NamidaColorPickerDialog(
        initialColor: allPaletteColor.value.lastOrNull ?? Colors.black,
        doneText: lang.ADD,
        onColorChanged: (value) => color = value,
        onDonePressed: () {
          if (color != null) {
            allPaletteColor.add(color!);
            didChangeOriginalPalette.value = true;
          }
          NamidaNavigator.inst.closeDialog();
        },
        cancelButton: true,
      ),
    );
  }

  final finalColorToBeUsed = (trackColor?.color).obs;

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
        ...allMixes.map(
          (colors) {
            final mixExtra = NamidaColor.mixIntColors(colors);
            return TapDetector(
              onTap: () => finalColorToBeUsed.value = mixExtra,
              child: getColorWidget(mixExtra),
            );
          },
        ).addSeparators(separator: const SizedBox(width: 4.0)),
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
          ...palette.map((e) => Padding(
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
              )),
          if (additionalWidget != null) additionalWidget,
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
        title: lang.COLOR_PALETTE,
        leftAction: onRestoreDefaults == null
            ? null
            : NamidaIconButton(
                tooltip: () => lang.RESTORE_DEFAULTS,
                onPressed: onRestoreDefaults,
                icon: Broken.refresh,
              ),
        actions: [
          const CancelButton(),
          ObxO(
            rx: finalColorToBeUsed,
            builder: (context, finalColor) => NamidaButton(
              enabled: finalColor != null,
              text: lang.CONFIRM,
              onPressed: () {
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
            getText('- ${lang.COLOR_PALETTE_NOTE_1}'),
            getText('- ${lang.COLOR_PALETTE_NOTE_2}\n'),

            // --- Removed Colors
            Obx(
              (context) => removedColors.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        getText(lang.REMOVED),
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
            getText(lang.PALETTE),
            const SizedBox(height: 8.0),
            Obx(
              (context) => ConstrainedBox(
                constraints: BoxConstraints(maxHeight: context.height * 0.4),
                child: SingleChildScrollView(
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
                          const Icon(Broken.add),
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
                      title: lang.PALETTE_MIX,
                      allMixes: defaultMixes,
                    ),
                  if (didChangeOriginalPalette.valueR)
                    mixWidget(
                      title: lang.PALETTE_NEW_MIX,
                      allMixes: [allPaletteColor.valueR],
                    ),
                  if (selectedColors.isNotEmpty)
                    mixWidget(
                      title: lang.PALETTE_SELECTED_MIX,
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
                getText('${lang.USED} : ', style: namida.textTheme.displayMedium),
                const SizedBox(width: 12.0),
                Expanded(
                  child: ObxO(
                    rx: finalColorToBeUsed,
                    builder: (context, finalColorToBeUsed) => AnimatedSizedBox(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: finalColorToBeUsed,
                        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                      ),
                      width: double.infinity,
                      height: 30.0,
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
              ],
            )
          ],
        ),
      );
    },
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
  final scrollController = ScrollController();
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
      title: lang.CHOOSE,
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
            text: lang.CONFIRM,
            onPressed: () => onChoose(selectedTrack.value!),
          ),
        )
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
                    child: CustomTextFiled(
                      focusNode: focusNode,
                      textFieldController: searchController,
                      textFieldHintText: lang.SEARCH,
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
                  )
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
                  configs: const TrackTilePropertiesConfigs(
                    queueSource: QueueSource.others,
                  ),
                  builder: (properties) => Obx(
                    (context) => ListView.builder(
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

    for (int i = 0; i < segments; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        arcRect,
        startAngle + i * sweep,
        sweep,
        true,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
