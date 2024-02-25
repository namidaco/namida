import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/color_m.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/namida_channel.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/track_clear_dialog.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/advanced_settings.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';

void showTrackAdvancedDialog({
  required List<Selectable> tracks,
  required Color colorScheme,
  required QueueSource source,
  required List<(String, String)> albumsUniqued,
}) async {
  final isSingle = tracks.length == 1;
  final canShowClearDialog = tracks.hasAnythingCached;

  final Map<TrackSource, int> sourcesMap = {};
  tracks.loop((e, index) {
    final twd = e.trackWithDate;
    if (twd != null) {
      sourcesMap.update(twd.source, (value) => value + 1, ifAbsent: () => 1);
    }
  });
  final RxBool willUpdateArtwork = false.obs;

  final trackColor = await CurrentColor.inst.getTrackColors(tracks.first.track, delightnedAndAlpha: false);

  final reIndexedTracksSuccessful = 0.obs;
  final reIndexedTracksFailed = 0.obs;
  final shouldShowReIndexProgress = false.obs;
  final shouldReIndexEnabled = true.obs;

  final tracksUniqued = tracks.uniqued((element) => element.track);

  final firstTracksDirectoryPath = tracksUniqued.first.track.path.getDirectoryPath;

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      willUpdateArtwork.close();
      reIndexedTracksSuccessful.close();
      reIndexedTracksFailed.close();
      shouldShowReIndexProgress.close();
      shouldReIndexEnabled.close();
    },
    colorScheme: colorScheme,
    dialogBuilder: (theme) => CustomBlurryDialog(
      theme: theme,
      normalTitleStyle: true,
      title: lang.ADVANCED,
      child: Column(
        children: [
          NamidaOpacity(
            opacity: canShowClearDialog ? 1.0 : 0.6,
            child: IgnorePointer(
              ignoring: !canShowClearDialog,
              child: CustomListTile(
                passedColor: colorScheme,
                title: lang.CLEAR,
                subtitle: lang.CHOOSE_WHAT_TO_CLEAR,
                icon: Broken.trash,
                onTap: () => showTrackClearDialog(tracks, colorScheme),
              ),
            ),
          ),
          if (sourcesMap.isNotEmpty)
            CustomListTile(
              passedColor: colorScheme,
              title: lang.SOURCE,
              subtitle: isSingle ? sourcesMap.keys.first.convertToString : sourcesMap.entries.map((e) => '${e.key.convertToString}: ${e.value.formatDecimal()}').join('\n'),
              icon: Broken.attach_circle,
              onTap: () {},
            ),

          // -- Updating directory path option, only for tracks whithin the same parent directory.
          if (tracksUniqued.every((element) => element.track.path.startsWith(firstTracksDirectoryPath)))
            UpdateDirectoryPathListTile(
              colorScheme: colorScheme,
              oldPath: firstTracksDirectoryPath,
              tracksPaths: tracksUniqued.map((e) => e.track.path),
            ),
          if (isSingle && File(tracks.first.track.path).existsSync())
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
                          final success = await NamidaChannel.inst.setMusicAs(path: tracks.first.track.path, types: selected);
                          if (success) NamidaNavigator.inst.closeDialog();
                        },
                      ),
                    ],
                    child: Column(
                      children: SetMusicAsAction.values
                          .map((e) => Obx(
                                () => Padding(
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
            () {
              final shouldShow = shouldShowReIndexProgress.value;
              final errors = reIndexedTracksFailed.value;
              final secondLine = errors > 0 ? '\n${lang.ERROR}: $errors' : '';
              return CustomListTile(
                enabled: shouldReIndexEnabled.value,
                passedColor: colorScheme,
                title: lang.RE_INDEX,
                icon: Broken.direct_inbox,
                subtitle: shouldShow ? "${reIndexedTracksSuccessful.value}/${tracksUniqued.length}$secondLine" : null,
                trailingRaw: NamidaInkWell(
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
                  bgColor: theme.cardColor,
                  onTap: () => willUpdateArtwork.value = !willUpdateArtwork.value,
                  child: Obx(() => Text('${lang.ARTWORK}  ${willUpdateArtwork.value ? '✓' : 'x'}')),
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
                  final listens = HistoryController.inst.topTracksMapListens[trackWillBeReplaced] ?? [];
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
                            })
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
          if (isSingle || (albumsUniqued.length == 1 && settings.groupArtworksByAlbum.value))
            CustomListTile(
              passedColor: colorScheme,
              title: lang.COLOR_PALETTE,
              icon: Broken.color_swatch,
              trailing: CircleAvatar(
                backgroundColor: trackColor.used,
                maxRadius: 14.0,
              ),
              onTap: () {
                void onAction() {
                  NamidaNavigator.inst.closeDialog(3);
                }

                _showTrackColorPaletteDialog(
                  colorScheme: colorScheme,
                  trackColor: trackColor,
                  onFinalColor: (palette, color) async {
                    await CurrentColor.inst.reExtractTrackColorPalette(
                      track: tracks.first.track,
                      imagePath: null,
                      newNC: NamidaColor(used: color, mix: _mixColor(palette), palette: palette),
                    );
                    onAction();
                  },
                  onRestoreDefaults: () async {
                    await CurrentColor.inst.reExtractTrackColorPalette(
                      track: tracks.first.track,
                      imagePath: tracks.first.track.pathToImage,
                      newNC: null,
                    );
                    onAction();
                  },
                );
              },
            ),
        ],
      ),
    ),
  );
}

Color _mixColor(Iterable<Color> colors) => CurrentColor.inst.mixIntColors(colors);

void _showTrackColorPaletteDialog({
  required Color colorScheme,
  required NamidaColor trackColor,
  required void Function(List<Color> palette, Color color) onFinalColor,
  required void Function() onRestoreDefaults,
}) async {
  final allPaletteColor = List<Color>.from(trackColor.palette).obs;
  final selectedColors = <Color>[].obs;
  final removedColors = <Color>[].obs;
  final didChangeOriginalPalette = false.obs;

  void showAddNewColorPaletteDialog() {
    Color? color;
    NamidaNavigator.inst.navigateDialog(
      colorScheme: colorScheme,
      dialogBuilder: (theme) => NamidaColorPickerDialog(
        initialColor: allPaletteColor.lastOrNull ?? Colors.black,
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

  final finalColorToBeUsed = trackColor.color.obs;

  Widget getText(String text, {TextStyle? style}) {
    return Text(text, style: style ?? Get.textTheme.displaySmall);
  }

  Widget getColorWidget(Color? color, [Widget? child]) => CircleAvatar(
        backgroundColor: color,
        maxRadius: 14.0,
        child: child,
      );

  Widget mixWidget({required String title, required List<Color> colors}) {
    final mix = _mixColor(colors);
    return Row(
      children: [
        getText('$title  '),
        TapDetector(onTap: () => finalColorToBeUsed.value = mix, child: getColorWidget(mix)),
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
        color: (Get.isDarkMode ? Colors.black : Colors.white).withAlpha(160),
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
        leftAction: NamidaIconButton(
          tooltip: lang.RESTORE_DEFAULTS,
          onPressed: onRestoreDefaults,
          icon: Broken.refresh,
        ),
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.CONFIRM,
            onPressed: () => onFinalColor(allPaletteColor, finalColorToBeUsed.value),
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
              () => removedColors.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        getText(lang.REMOVED),
                        const SizedBox(height: 8.0),
                        getPalettesWidget(
                          palette: removedColors,
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
              () => getPalettesWidget(
                palette: allPaletteColor,
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
            const SizedBox(height: 12.0),
            Obx(
              () => Wrap(
                spacing: 12.0,
                runSpacing: 6.0,
                children: [
                  mixWidget(
                    title: lang.PALETTE_MIX,
                    colors: trackColor.palette,
                  ),
                  if (didChangeOriginalPalette.value)
                    mixWidget(
                      title: lang.PALETTE_NEW_MIX,
                      colors: allPaletteColor,
                    ),
                  if (selectedColors.isNotEmpty)
                    mixWidget(
                      title: lang.PALETTE_SELECTED_MIX,
                      colors: selectedColors,
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
                getText('${lang.USED} : ', style: Get.textTheme.displayMedium),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Obx(
                    () => AnimatedSizedBox(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: finalColorToBeUsed.value,
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
  final allTracksList = List<Track>.from(allTracksInLibrary).obs;
  final selectedTrack = Rxn<Track>();
  void onTrackTap(Track tr) {
    if (selectedTrack.value == tr) {
      selectedTrack.value = null;
    } else {
      selectedTrack.value = tr;
    }
  }

  final searchController = TextEditingController();
  final focusNode = FocusNode();

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      allTracksList.close();
      selectedTrack.close();
      searchController.dispose();
      focusNode.dispose();
    },
    colorScheme: colorScheme,
    dialogBuilder: (theme) => CustomBlurryDialog(
      title: lang.CHOOSE,
      normalTitleStyle: true,
      contentPadding: EdgeInsets.zero,
      insetPadding: const EdgeInsets.all(32.0),
      actions: [
        const CancelButton(),
        Obx(
          () => NamidaButton(
            enabled: selectedTrack.value != null,
            text: lang.CONFIRM,
            onPressed: () => onChoose(selectedTrack.value!),
          ),
        )
      ],
      child: SizedBox(
        width: Get.width,
        height: Get.height * 0.6,
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
                        final matched = allTracksInLibrary.where((element) {
                          final titleMatch = element.title.cleanUpForComparison.contains(value);
                          final artistMatch = element.originalArtist.cleanUpForComparison.contains(value);
                          final albumMatch = element.album.cleanUpForComparison.contains(value);
                          return titleMatch || artistMatch || albumMatch;
                        });
                        allTracksList.value = matched.toList();
                      },
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  NamidaIconButton(
                    icon: Broken.close_circle,
                    onPressed: () {
                      allTracksList
                        ..clear()
                        ..addAll(allTracksInLibrary);
                      searchController.clear();
                    },
                  )
                ],
              ),
            ),
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                trackName,
                style: Get.textTheme.displayMedium,
              ),
            ),
            const SizedBox(height: 8.0),
            Expanded(
              child: Obx(
                () => ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: allTracksList.length,
                  itemBuilder: (context, i) {
                    final tr = allTracksList[i];
                    return Obx(
                      () => TrackTile(
                        trackOrTwd: tr,
                        index: i,
                        queueSource: QueueSource.playlist,
                        onTap: () => onTrackTap(tr),
                        onRightAreaTap: () => onTrackTap(tr),
                        trailingWidget: NamidaCheckMark(
                          size: 22.0,
                          active: selectedTrack.value == tr,
                        ),
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
