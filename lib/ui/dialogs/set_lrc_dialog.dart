// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:lrc/lrc.dart';

import 'package:namida/class/lyrics.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showLRCSetDialog(Track track, Color colorScheme) async {
  final fetchingFromInternet = false.obs;
  final availableLyrics = <LyricsModel>[].obs;
  final fetchedLyrics = <LyricsModel>[].obs;

  final embedded = track.lyrics;
  final cachedTxt = Lyrics.inst.lyricsFileText(track);
  final cachedLRC = Lyrics.inst.lyricsFileCache(track);
  final localLRCFiles = Lyrics.inst.lyricsFilesDevice(track);

  if (embedded != '') {
    availableLyrics.add(
      LyricsModel(
        lyrics: embedded,
        synced: embedded.parseLRC() != null,
        fromInternet: false,
        isInCache: false,
        file: null,
        isEmbedded: true,
      ),
    );
  }
  if (cachedTxt.existsSync()) {
    availableLyrics.add(
      LyricsModel(
        lyrics: cachedTxt.readAsStringSync(),
        synced: false,
        fromInternet: false,
        isInCache: true,
        file: cachedTxt,
        isEmbedded: false,
      ),
    );
  }
  if (cachedLRC.existsSync()) {
    availableLyrics.add(
      LyricsModel(
        lyrics: cachedLRC.readAsStringSync(),
        synced: true,
        fromInternet: false,
        isInCache: true,
        file: cachedLRC,
        isEmbedded: false,
      ),
    );
  }
  for (final localLRC in localLRCFiles) {
    if (localLRC.existsSync()) {
      availableLyrics.add(
        LyricsModel(
          lyrics: localLRC.readAsStringSync(),
          synced: true,
          fromInternet: false,
          isInCache: false,
          file: localLRC,
          isEmbedded: false,
        ),
      );
    }
  }

  void updateForCurrentTrack() {
    if (track == Player.inst.nowPlayingTrack) {
      Lyrics.inst.updateLyrics(track);
    }
  }

  void showDeleteLyricsDialog(LyricsModel l) {
    NamidaNavigator.inst.navigateDialog(
      colorScheme: colorScheme,
      dialogBuilder: (theme) => CustomBlurryDialog(
        title: lang.CONFIRM,
        actions: [
          const CancelButton(),
          const SizedBox(width: 6.0),
          NamidaButton(
            text: lang.DELETE.toUpperCase(),
            onPressed: () async {
              if ((await l.file?.tryDeleting()) == true) {
                availableLyrics.remove(l);
              }
              updateForCurrentTrack();
              NamidaNavigator.inst.closeDialog();
            },
          )
        ],
        bodyText: '${lang.DELETE}: "${l.file?.path}"?',
      ),
    );
  }

  void showEditCachedSyncedTimeOffsetDialog(LyricsModel l) async {
    Lrc? lrc;
    int offsetMS = 0;

    lrc = l.lyrics.parseLRC();
    offsetMS = lrc?.offset ?? 0;

    final newOffset = offsetMS.obs;
    Timer? timer;
    void updatey(bool increase) {
      timer?.cancel();
      timer = null;
      timer = Timer.periodic(const Duration(milliseconds: 20), (d) {
        if (increase) {
          newOffset.value += 10;
        } else {
          newOffset.value -= 10;
        }
      });
    }

    Widget getButton(IconData icon, bool increase) {
      return GestureDetector(
        onLongPressStart: (details) {
          updatey(increase);
        },
        onLongPressEnd: (d) {
          timer?.cancel();
        },
        onLongPressCancel: () {
          timer?.cancel();
        },
        onTap: () {
          if (increase) {
            newOffset.value += 10;
          } else {
            newOffset.value -= 10;
          }
        },
        child: Icon(
          icon,
          size: 20.0,
        ),
      );
    }

    final offsetController = TextEditingController();

    await NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        newOffset.close();
        offsetController.dispose();
      },
      colorScheme: colorScheme,
      dialogBuilder: (theme) => CustomBlurryDialog(
        title: lang.CONFIGURE,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          const SizedBox(width: 6.0),
          NamidaButton(
            text: lang.SAVE.toUpperCase(),
            onPressed: () async {
              final ct = offsetController.text;
              final tfoffset = ct == '' ? null : int.tryParse(offsetController.text);
              if (tfoffset != null) newOffset.value = tfoffset;
              if (lrc != null) {
                final newLRC = Lrc(
                  type: lrc.type,
                  lyrics: lrc.lyrics,
                  artist: lrc.artist,
                  album: lrc.album,
                  title: lrc.title,
                  creator: lrc.creator,
                  author: lrc.author,
                  program: lrc.program,
                  version: lrc.version,
                  length: lrc.length,
                  offset: newOffset.value,
                  language: lrc.language,
                );
                final lyricsString = newLRC.format();
                await Lyrics.inst.saveLyricsToCache(track, newLRC.format(), true);
                availableLyrics.remove(l);
                availableLyrics.add(
                  LyricsModel(
                    lyrics: lyricsString,
                    synced: l.synced,
                    isInCache: l.isInCache,
                    fromInternet: l.fromInternet,
                    isEmbedded: l.isEmbedded,
                    file: l.file,
                  ),
                );
                updateForCurrentTrack();
              }

              NamidaNavigator.inst.closeDialog();
            },
          )
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 8.0),
                  const Icon(Broken.timer_1),
                  const SizedBox(width: 8.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.OFFSET,
                        style: Get.textTheme.displayMedium,
                      ),
                      Obx(
                        () {
                          final ms = newOffset.value.remainder(1000).abs().toString();
                          final msText = ms.length > 2 ? ms.substring(0, 2) : ms;
                          final off = newOffset.value;
                          return Text(
                            "${off.milliSecondsLabel}.$msText",
                            style: Get.textTheme.displaySmall,
                          );
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(width: 8.0),
                  getButton(Broken.minus_cirlce, false),
                  const SizedBox(width: 8.0),
                  Obx(
                    () => Text(
                      "${newOffset.value}ms",
                      style: Get.textTheme.displayMedium,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  getButton(Broken.add_circle, true),
                  const SizedBox(width: 8.0),
                ],
              ),
              TextField(
                controller: offsetController,
                keyboardType: TextInputType.number,
                onSubmitted: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) newOffset.value = parsed;
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  final selectedLyrics = Rxn<LyricsModel>();
  final expandedLyrics = Rxn<LyricsModel>();

  final searchController = TextEditingController();

  void onSearchTrigger([String? query]) async {
    fetchingFromInternet.value = true;
    fetchedLyrics.clear();
    final lyrics = await Lyrics.inst.fetchLRCBasedLyricsFromInternet(
      durationInSeconds: track.duration,
      title: track.title,
      artist: track.originalArtist,
      album: track.album,
      customQuery: query ?? searchController.text,
    );
    if (lyrics.isNotEmpty) fetchedLyrics.addAll(lyrics);
    fetchingFromInternet.value = false;
  }

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      fetchingFromInternet.close();
      availableLyrics.close();
      fetchedLyrics.close();
      selectedLyrics.close();
      expandedLyrics.close();
      searchController.dispose();
    },
    colorScheme: colorScheme,
    dialogBuilder: (theme) => CustomBlurryDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 38.0, vertical: 32.0),
      title: lang.LYRICS,
      actions: [
        NamidaButton(
          text: lang.SEARCH,
          onPressed: onSearchTrigger,
        ),
        const CancelButton(),
        const SizedBox(width: 6.0),
        Obx(
          () {
            final selected = selectedLyrics.value;
            return NamidaButton(
              enabled: selected != null && !selected.isInCache && !selected.isEmbedded /* && (selected.file != null || selected.fromInternet == true) */,
              text: lang.SAVE,
              onPressed: () async {
                final selected = selectedLyrics.value;
                if (selected != null) {
                  await Lyrics.inst.saveLyricsToCache(track, selected.lyrics, selected.synced);
                  updateForCurrentTrack();
                }
                NamidaNavigator.inst.closeDialog();
              },
            );
          },
        )
      ],
      child: SizedBox(
        width: Get.width,
        height: Get.height * 0.6,
        child: Column(
          children: [
            CustomTagTextField(
              borderRadius: 12.0,
              controller: searchController,
              hintText: '${track.originalArtist} - ${track.title}',
              labelText: '',
              onFieldSubmitted: (value) {
                onSearchTrigger(value);
              },
            ),
            const SizedBox(height: 6.0),
            Expanded(
              child: Obx(
                () {
                  final both = [...availableLyrics, ...fetchedLyrics];
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: both.length,
                    itemBuilder: (context, index) {
                      final l = both[index];
                      final syncedText = l.synced ? lang.SYNCED : lang.PLAIN;
                      final cacheText = l.file == null
                          ? ''
                          : l.isInCache
                              ? lang.CACHE
                              : lang.LOCAL;
                      return Obx(
                        () => NamidaInkWell(
                          borderRadius: 12.0,
                          animationDurationMS: 200,
                          onTap: () => selectedLyrics.value = l,
                          bgColor: Get.theme.cardColor.withOpacity(0.4),
                          decoration: BoxDecoration(
                            border: selectedLyrics.value == l
                                ? Border.all(
                                    width: 2.0,
                                    color: colorScheme,
                                  )
                                : null,
                          ),
                          padding: const EdgeInsets.all(8.0),
                          margin: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(l.file == null ? Broken.document_download : Broken.document, size: 18.0),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: Text(
                                      cacheText != '' ? "$syncedText ($cacheText)" : syncedText,
                                      style: Get.textTheme.displayMedium,
                                    ),
                                  ),
                                  NamidaIconButton(
                                    horizontalPadding: 0.0,
                                    tooltip: lang.COPY,
                                    icon: Broken.copy,
                                    iconSize: 20.0,
                                    onPressed: () {
                                      final text = l.lyrics;
                                      Clipboard.setData(ClipboardData(text: text));
                                      snackyy(
                                        title: lang.COPIED_TO_CLIPBOARD,
                                        message: text.replaceAll('\n', ' '),
                                        maxLinesMessage: 2,
                                        leftBarIndicatorColor: CurrentColor.inst.color,
                                        margin: EdgeInsets.zero,
                                        top: false,
                                        borderRadius: 0,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 6.0),
                                  if (l.file != null) ...[
                                    if (l.synced && !l.fromInternet)
                                      NamidaIconButton(
                                        horizontalPadding: 0.0,
                                        icon: Broken.timer_1,
                                        iconSize: 20.0,
                                        onPressed: () {
                                          showEditCachedSyncedTimeOffsetDialog(l);
                                        },
                                      ),
                                    const SizedBox(width: 6.0),
                                    NamidaIconButton(
                                      horizontalPadding: 0.0,
                                      icon: Broken.trash,
                                      iconSize: 20.0,
                                      onPressed: () {
                                        showDeleteLyricsDialog(l);
                                      },
                                    ),
                                    const SizedBox(width: 4.0),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              Stack(
                                children: [
                                  NamidaInkWell(
                                    borderRadius: 8.0,
                                    bgColor: Get.theme.cardColor,
                                    padding: const EdgeInsets.all(8.0),
                                    child: NamidaAnimatedSwitcher(
                                      durationMS: 0,
                                      showFirst: expandedLyrics.value == l,
                                      firstChild: Text(
                                        l.lyrics,
                                        style: Get.textTheme.displaySmall,
                                      ),
                                      secondChild: Text(
                                        l.lyrics,
                                        maxLines: 12,
                                        overflow: TextOverflow.fade,
                                        style: Get.textTheme.displaySmall,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 4.0,
                                    right: 4.0,
                                    child: Container(
                                      clipBehavior: Clip.antiAlias,
                                      padding: const EdgeInsets.all(4.0),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 4.0,
                                            color: Get.theme.scaffoldBackgroundColor,
                                          ),
                                        ],
                                      ),
                                      child: NamidaIconButton(
                                        horizontalPadding: 0.0,
                                        icon: Broken.maximize_circle,
                                        iconSize: 14.0,
                                        onPressed: () {
                                          if (expandedLyrics.value == l) {
                                            expandedLyrics.value = null;
                                          } else {
                                            expandedLyrics.value = l;
                                          }
                                        },
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Obx(
              () => fetchingFromInternet.value
                  ? ThreeArchedCircle(
                      color: Get.theme.cardColor,
                      size: 58.0,
                    )
                  : const SizedBox(),
            ),
            const SizedBox(height: 8.0),
            Obx(
              () => CustomListTile(
                visualDensity: VisualDensity.compact,
                icon: Broken.add_circle,
                title: lang.ADD_LRC_FILE,
                trailingText: (availableLyrics.length + fetchedLyrics.length).formatDecimal(),
                onTap: () async {
                  final picked = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['lrc', 'LRC', 'txt', 'TXT'],
                    initialDirectory: track.path.getDirectoryPath,
                  );
                  final path = picked?.files.firstOrNull?.path;
                  if (path != null) {
                    final file = File(path);
                    final ext = path.getExtension;
                    final text = file.readAsStringSync();
                    final lrcModel = LyricsModel(
                      lyrics: text,
                      synced: ext == 'lrc' || ext == 'LRC',
                      isInCache: false,
                      fromInternet: false,
                      file: File(path),
                      isEmbedded: false,
                    );
                    availableLyrics.add(lrcModel);
                    selectedLyrics.value = lrcModel;
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
