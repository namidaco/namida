import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:lrc/lrc.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:namida/class/lyrics.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_base.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/packages/lyrics_lrc_parsed_view.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showLRCSetDialog(Playable item, Color colorScheme) async {
  final LrcSearchUtils? lrcUtils = await LrcSearchUtils.fromPlayable(item);
  if (lrcUtils == null) return;

  final fetchingFromInternet = Rxn<bool>();
  final availableLyrics = <LyricsModel>[].obs;
  final fetchedLyrics = <LyricsModel>[].obs;
  final trackDurationMSRx = Rxn<int>();
  bool requiresUpdatingLyrics = false;

  lrcUtils.getItemDurationMS().then((value) {
    trackDurationMSRx.value = value;
  });

  String embedded = lrcUtils.embeddedLyrics;
  final cachedTxt = lrcUtils.cachedTxtFile;
  final cachedLRC = lrcUtils.cachedLRCFile;

  if (embedded != '') {
    availableLyrics.add(
      LyricsModel(
        lyrics: embedded,
        synced: embedded.isValidLRC(),
        fromInternet: false,
        isInCache: false,
        file: null,
        isEmbedded: true,
      ),
    );
  }
  if (await cachedTxt.exists()) {
    availableLyrics.add(
      LyricsModel(
        lyrics: await cachedTxt.readLrcString(),
        synced: false,
        fromInternet: false,
        isInCache: true,
        file: cachedTxt,
        isEmbedded: false,
      ),
    );
  }
  if (await cachedLRC.exists()) {
    availableLyrics.add(
      LyricsModel(
        lyrics: await cachedLRC.readLrcString(),
        synced: true,
        fromInternet: false,
        isInCache: true,
        file: cachedLRC,
        isEmbedded: false,
      ),
    );
  }

  final deviceLyricsFiles = await lrcUtils.allDeviceLyricsFiles();
  for (final deviceFile in deviceLyricsFiles) {
    final deviceLyrics = await deviceFile.readLrcString();
    availableLyrics.add(
      LyricsModel(
        lyrics: deviceLyrics,
        synced: deviceLyrics.isValidLRC(),
        fromInternet: false,
        isInCache: false,
        file: deviceFile,
        isEmbedded: false,
      ),
    );
  }

  final inUseRx = Rxn<LocalLyricsPick>();

  Future<LocalLyricsPick> refreshInUse() async {
    final inUse = await Lyrics.inst.pickLocalLyrics(lrcUtils, embedded);
    inUseRx.value = inUse;
    return inUse;
  }

  refreshInUse();

  bool isLyricsInUse(LyricsModel l, LocalLyricsPick inUse) {
    if (l.isEmbedded) return inUse.isEmbedded;
    final file = l.file;
    return file != null && file.path == inUse.file?.path;
  }

  Future<LocalLyricsPick> markRequiresUpdating() {
    // -- mark dirty instead, otherwise can interfere with the selection process
    requiresUpdatingLyrics = true;
    return refreshInUse();
  }

  void onPrioritizeEmbeddedChanged(bool prioritize) {
    settings.prioritizeEmbeddedLyrics.save(prioritize);
    markRequiresUpdating();
  }

  // -- saving again writes to the same file
  void addSavedLyrics(LyricsModel l) {
    final savedPath = l.file?.path;
    availableLyrics.value.removeWhere((element) => element.file?.path == savedPath);
    availableLyrics.value.add(l);
    availableLyrics.refresh();
    markRequiresUpdating();
  }

  void updateEditLyrics(LyricsModel l, LyricsModel newL) {
    final indexOfLrc = availableLyrics.value.indexOf(l);
    if (indexOfLrc >= 0) {
      availableLyrics[indexOfLrc] = newL;
      markRequiresUpdating();
      return;
    }
    final indexOfLrc2 = fetchedLyrics.value.indexOf(l);
    if (indexOfLrc2 >= 0) {
      fetchedLyrics[indexOfLrc2] = newL;
      markRequiresUpdating();
      return;
    }
  }

  void showDeleteLyricsDialog(LyricsModel l) {
    NamidaNavigator.inst.navigateDialog(
      colorScheme: colorScheme,
      dialogBuilder: (theme) => CustomBlurryDialog(
        title: lang.confirm,
        actions: [
          const CancelButton(),
          NamidaButton(
            colorScheme: Colors.red,
            text: lang.delete.toUpperCase(),
            onTap: () async {
              if ((await l.file?.tryDeleting()) == true) {
                availableLyrics.remove(l);
              }
              markRequiresUpdating();
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
        bodyText: '${lang.delete}: "${l.file?.path}"?',
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
        title: lang.configure,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.save.toUpperCase(),
            onTap: () async {
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
                final file = await Lyrics.inst.saveLyricsByUser(lrcUtils, lyricsString, true);
                final newLModel = LyricsModel(
                  lyrics: lyricsString,
                  synced: l.synced,
                  isInCache: lrcUtils.isCacheFile(file),
                  fromInternet: l.fromInternet,
                  isEmbedded: l.isEmbedded,
                  file: file,
                );
                updateEditLyrics(l, newLModel);
              }

              NamidaNavigator.inst.closeDialog();
            },
          ),
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
                        lang.offset,
                        style: namida.textTheme.displayMedium,
                      ),
                      Obx(
                        (context) {
                          final off = newOffset.valueR;
                          final ms = off.remainder(1000).abs().toString();
                          String msText = ms.padLeft(3, '0');
                          if (msText.endsWith('0')) msText = msText.substring(0, 2);
                          final secondsText = off.abs().milliSecondsLabel;
                          final prefix = off < 0 ? '-' : '';
                          return Text(
                            "$prefix$secondsText.$msText",
                            style: namida.textTheme.displaySmall,
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
                    (context) => Text(
                      "${newOffset.valueR}ms",
                      style: namida.textTheme.displayMedium,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  final selectedLyrics = Rxn<LyricsModel>();
  final expandedLyrics = Rxn<LyricsModel>();

  void onLyricsTap(LyricsModel l) {
    selectedLyrics.value = l;
    final inUse = inUseRx.value;
    if (inUse == null || isLyricsInUse(l, inUse)) return;
    final isEmbeddedPrioritized = inUse.isEmbedded && settings.prioritizeEmbeddedLyrics.value;
    if (l.isEmbedded && inUse.file != null) {
      final message = lang.lyricsFilesArePrioritized(setting: lang.prioritizeEmbeddedLyrics);
      snackyy(title: lang.note, message: message, icon: Broken.info_circle);
    } else if (l.file != null && isEmbeddedPrioritized) {
      final message = lang.embeddedLyricsArePrioritized(setting: lang.prioritizeEmbeddedLyrics);
      snackyy(title: lang.note, message: message, icon: Broken.info_circle);
    }
  }

  final embeddableTrack = item is Selectable ? item.track.asPhysical() : null;
  final isEmbeddingRx = false.obs;

  void onEmbedTap(LyricsModel l) async {
    final track = embeddableTrack;
    if (track == null) return;
    final hasPermission = await requestManageStoragePermission(directoryToCreate: AppDirs.INTERNAL_STORAGE);
    if (!hasPermission) return;

    isEmbeddingRx.value = true;
    bool didEmbed = false;
    await NamidaTaggerController.inst
        .updateTracksMetadata(
          tracks: [track],
          editedTags: {TagField.lyrics: l.lyrics},
          onEdit: (didUpdate, error, _) {
            didEmbed = didUpdate;
            if (didUpdate) return;
            final message = error ?? 'Unknown Error';
            snackyy(title: lang.metadataEditFailed, message: message, isError: true);
          },
        )
        .ignoreError();
    isEmbeddingRx.value = false;
    if (!didEmbed) return;

    embedded = l.lyrics;
    final embeddedModel = LyricsModel(
      lyrics: l.lyrics,
      synced: l.synced,
      fromInternet: false,
      isInCache: false,
      file: null,
      isEmbedded: true,
    );
    availableLyrics.value.removeWhere((element) => element.isEmbedded);
    availableLyrics.value.insert(0, embeddedModel);
    availableLyrics.refresh();
    selectedLyrics.value = embeddedModel;
    markRequiresUpdating();
  }

  void onCopyLyricsTap(LyricsModel l) {
    final text = l.lyrics;
    final message = text.replaceAll('\n', ' ');
    NamidaUtils.copyToClipboard(
      content: text,
      message: message,
      maxLinesMessage: 2,
      altDesign: true,
    );
  }

  List<NamidaPopupItem> getLyricsMenuItems(LyricsModel l) {
    return [
      NamidaPopupItem(
        icon: Broken.copy,
        title: lang.copy,
        onTap: () => onCopyLyricsTap(l),
      ),
      if (embeddableTrack != null && !l.isEmbedded)
        NamidaPopupItem(
          icon: Broken.document_code,
          title: lang.embed,
          enabled: !isEmbeddingRx.value,
          onTap: () => onEmbedTap(l),
        ),
      if (l.file != null)
        NamidaPopupItem(
          icon: Broken.trash,
          title: lang.delete,
          onTap: () => showDeleteLyricsDialog(l),
        ),
    ];
  }

  final searchController = TextEditingController();

  final initialSearchTextHint = lrcUtils.initialSearchTextHint;

  void onSearchExternallyTap() {
    final query = Uri.encodeComponent('$initialSearchTextHint lyrics');
    final url = "https://www.google.com/search?q=$query";
    NamidaLinkUtils.openLink(url, preferredMode: LaunchMode.externalApplication);
  }

  void sortFetchedLyrics(List<LyricsModel> lyrics, int? trackDurationMS) {
    if (lyrics.length < 2) return;
    const unknownDiff = 1 << 40;
    final targetMS = trackDurationMS ?? 0;
    final keyed = List.generate(lyrics.length, (i) {
      final l = lyrics[i];
      final durMS = l.durationMS;
      final diff = targetMS > 0 && durMS != null && durMS > 0 ? (targetMS - durMS).abs() : unknownDiff;
      return (index: i, synced: l.synced ? 0 : 1, diff: diff);
    });
    keyed.sort((a, b) {
      final s = a.synced.compareTo(b.synced);
      if (s != 0) return s;
      final d = a.diff.compareTo(b.diff);
      return d != 0 ? d : a.index.compareTo(b.index);
    });
    final sorted = keyed.map((k) => lyrics[k.index]).toList();
    lyrics.setAll(0, sorted);
  }

  int searchId = 0;

  void onSearchTrigger([String? query]) async {
    final id = ++searchId;
    fetchingFromInternet.value = true;
    fetchedLyrics.clear();
    final lyrics = await Lyrics.inst.searchLRCLyricsFromInternet(
      lrcUtils: lrcUtils,
      customQuery: query ?? searchController.text,
      allProviders: true,
      onPartial: fetchedLyrics.addAll,
    );
    if (id != searchId) return;
    sortFetchedLyrics(lyrics, trackDurationMSRx.value);
    fetchedLyrics.value = lyrics;
    fetchingFromInternet.value = false;
  }

  void onAddLRCFileTap() async {
    final picked = await NamidaFileBrowser.pickFile(
      note: lang.addLrcFile,
      allowedExtensions: NamidaFileExtensionsWrapper.lrcOrTxt,
      initialDirectory: lrcUtils.pickFileInitialDirectory,
    );
    final path = picked?.path;
    if (path != null) {
      final text = await File(path).readLrcString();
      final synced = text.isValidLRC();
      final file = await Lyrics.inst.saveLyricsByUser(lrcUtils, text, synced);
      final lrcModel = LyricsModel(
        lyrics: text,
        synced: synced,
        isInCache: lrcUtils.isCacheFile(file),
        fromInternet: false,
        file: file,
        isEmbedded: false,
      );
      addSavedLyrics(lrcModel);
      // selectedLyrics.value = lrcModel;
    }
  }

  void onAddLRCPasteTap() async {
    final pasteTextController = TextEditingController();
    final clipboardTextRx = ''.obs;
    void savePastedLRC([String? text]) async {
      text ??= pasteTextController.text;
      final synced = text.isValidLRC();

      final file = await Lyrics.inst.saveLyricsByUser(lrcUtils, text, synced);

      final lrcModel = LyricsModel(
        lyrics: text,
        synced: synced,
        isInCache: lrcUtils.isCacheFile(file),
        fromInternet: false,
        file: file,
        isEmbedded: false,
      );
      addSavedLyrics(lrcModel);
      // selectedLyrics.value = lrcModel;

      NamidaNavigator.inst.closeDialog();
    }

    Clipboard.getData(Clipboard.kTextPlain).then(
      (value) => clipboardTextRx.value = value?.text ?? '',
    );

    await NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        pasteTextController.dispose();
        clipboardTextRx.close();
      },
      colorScheme: colorScheme,
      dialogBuilder: (theme) => CustomBlurryDialog(
        icon: Broken.additem,
        title: lang.add,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.add.toUpperCase(),
            onTap: savePastedLRC,
          ),
        ],
        trailingWidgets: [
          NamidaIconButton(
            icon: Broken.export_1,
            tooltip: () => '${lang.search}: Google',
            iconSize: 22.0,
            onPressed: onSearchExternallyTap,
          ),
        ],
        child: SizedBox(
          width: namida.width,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: ObxO(
              rx: clipboardTextRx,
              builder: (context, clipboardText) => Column(
                children: [
                  if (clipboardText.isNotEmpty) ...[
                    CustomListTile(
                      icon: Broken.clipboard_tick,
                      title: lang.copiedToClipboard,
                      subtitle: clipboardText,
                      maxSubtitleLines: 6,
                      onTap: () {
                        savePastedLRC(clipboardText);
                      },
                    ),
                    const SizedBox(height: 24.0),
                  ],
                  CustomTagTextField(
                    borderRadius: 12.0,
                    controller: pasteTextController,
                    hintText: lang.lyrics,
                    maxLines: 6,
                    labelText: '',
                    onFieldSubmitted: (value) {
                      savePastedLRC(value);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void onEditLyricsTap(LyricsModel l) async {
    final editTextController = TextEditingController(text: l.lyrics);
    void saveEditedLRC() async {
      final text = editTextController.text;
      final synced = text.isValidLRC();

      final file = await Lyrics.inst.saveLyricsByUser(lrcUtils, text, synced);

      final lrcModel = LyricsModel(
        lyrics: text,
        synced: synced,
        isInCache: lrcUtils.isCacheFile(file),
        fromInternet: l.fromInternet,
        file: file,
        isEmbedded: l.isEmbedded,
      );
      updateEditLyrics(l, lrcModel);

      NamidaNavigator.inst.closeDialog();
    }

    await NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        editTextController.dispose();
      },
      colorScheme: colorScheme,
      dialogBuilder: (theme) => CustomBlurryDialog(
        icon: Broken.edit_2,
        title: lang.edit,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.save.toUpperCase(),
            onTap: saveEditedLRC,
          ),
        ],
        child: SizedBox(
          width: namida.width,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              children: [
                CustomTagTextField(
                  borderRadius: 12.0,
                  controller: editTextController,
                  hintText: lang.lyrics,
                  maxLines: 24,
                  labelText: '',
                  onFieldSubmitted: (value) {
                    saveEditedLRC();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void updateLyricsIfRequired() {
    if (requiresUpdatingLyrics) {
      if (item == Player.inst.currentItem.value) {
        Lyrics.inst.updateLyrics(item);
      }
    }
  }

  await NamidaNavigator.inst.navigateDialog(
    onDismissing: updateLyricsIfRequired,
    onDisposing: () {
      fetchingFromInternet.close();
      availableLyrics.close();
      fetchedLyrics.close();
      selectedLyrics.close();
      expandedLyrics.close();
      inUseRx.close();
      isEmbeddingRx.close();
      searchController.dispose();
    },
    colorScheme: colorScheme,
    dialogBuilder: (theme) => CustomBlurryDialog(
      horizontalInset: 38.0,
      normalTitleStyle: true,
      title: lang.lyrics,
      titleWidgetInPadding: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 24.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                color: theme.cardColor,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                child: Obx(
                  (context) => Text(
                    (availableLyrics.length + fetchedLyrics.length).formatDecimal(),
                    style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              lang.lyrics,
              style: theme.textTheme.displayLarge,
            ),
          ),
          const SizedBox(width: 8.0),
          const _LyricsFontScaleButton(),
          NamidaIconButton(
            icon: Broken.additem,
            tooltip: () => lang.add,
            onPressed: onAddLRCPasteTap,
          ),
          NamidaIconButton(
            icon: Broken.document_download,
            tooltip: () => lang.addLrcFile,
            onPressed: onAddLRCFileTap,
          ),
        ],
      ),
      leftAction: NamidaButton(
        text: lang.search,
        onTap: onSearchTrigger,
      ),
      actions: [
        Obx(
          (context) {
            final selected = selectedLyrics.valueR;
            final inUse = inUseRx.valueR;
            final isEmbedding = isEmbeddingRx.valueR;
            final isSelectedInUse = selected != null && inUse != null && isLyricsInUse(selected, inUse);
            final isFileBeatenByEmbedded = selected?.file != null && inUse != null && inUse.isEmbedded;
            final canSave = selected != null && !isSelectedInUse && !isFileBeatenByEmbedded;
            return NamidaButton(
              text: canSave ? lang.save : lang.done,
              enabled: !isEmbedding,
              isLoading: isEmbedding,
              onTap: () async {
                if (canSave) {
                  await Lyrics.inst.saveLyricsByUser(lrcUtils, selected.lyrics, selected.synced);
                  final newInUse = await markRequiresUpdating();
                  final isStillEmbeddedPrioritized = selected.synced && newInUse.isEmbedded && settings.prioritizeEmbeddedLyrics.value;
                  if (isStillEmbeddedPrioritized) {
                    snackyy(
                      title: lang.note,
                      message: lang.embeddedLyricsArePrioritized(setting: lang.prioritizeEmbeddedLyrics),
                      icon: Broken.info_circle,
                      displayDuration: SnackDisplayDuration.veryLong,
                      button: SnackbarButton(
                        text: lang.disable,
                        function: () {
                          settings.prioritizeEmbeddedLyrics.save(false);
                          if (item == Player.inst.currentItem.value) Lyrics.inst.updateLyrics(item);
                        },
                      ),
                    );
                  }
                }
                updateLyricsIfRequired();

                NamidaNavigator.inst.closeDialog();
              },
            );
          },
        ),
      ],
      child: SizedBox(
        width: namida.width,
        height: namida.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: 8.0),
            Row(
              children: [
                Expanded(
                  child: CustomTagTextField(
                    borderRadius: 12.0,
                    controller: searchController,
                    hintText: initialSearchTextHint,
                    keyboardType: TextInputType.text, // no next line
                    labelText: '',
                    onFieldSubmitted: (value) {
                      onSearchTrigger(value);
                    },
                  ),
                ),
                NamidaIconButton(
                  icon: Broken.received,
                  iconSize: 22.0,
                  onPressed: () {
                    searchController.text = initialSearchTextHint;
                  },
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            Expanded(
              child: Obx(
                (context) {
                  if (fetchingFromInternet.valueR == true) {
                    return ThreeArchedCircle(
                      color: namida.theme.cardColor,
                      size: 58.0,
                    );
                  }
                  final availableLyricsValue = availableLyrics.valueR;
                  final fetchedLyricsValue = fetchedLyrics.valueR;
                  final hasEmbedded = availableLyricsValue.any((l) => l.isEmbedded);

                  Widget listItemBuilder(BuildContext context, LyricsModel l) {
                    final syncedText = l.synced ? lang.synced : lang.plain;
                    final cacheText = l.isEmbedded
                        ? ''
                        : l.file == null
                        ? l.provider?.toText() ?? ''
                        : l.isInCache
                        ? lang.cache
                        : lang.local;
                    return Obx(
                      (context) {
                        final inUse = inUseRx.valueR;
                        final isInUse = inUse != null && isLyricsInUse(l, inUse);
                        return NamidaInkWell(
                          borderRadius: 12.0,
                          animationDurationMS: 200,
                          onTap: () => onLyricsTap(l),
                          bgColor: namida.theme.cardColor.withOpacityExt(0.4),
                          decoration: BoxDecoration(
                            border: selectedLyrics.valueR == l
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
                                  Icon(
                                    l.isEmbedded
                                        ? Broken.document_code
                                        : l.file == null
                                        ? Broken.document_download
                                        : Broken.document,
                                    size: 22.0,
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cacheText != '' ? "$syncedText ($cacheText)" : syncedText,
                                          style: namida.textTheme.displayMedium,
                                        ),
                                        Row(
                                          children: [
                                            if (isInUse) ...[
                                              _LyricsInUseChip(colorScheme: colorScheme),
                                              const SizedBox(width: 2.0),
                                            ],
                                            Flexible(
                                              child: ObxO(
                                                rx: trackDurationMSRx,
                                                builder: (context, durMS) {
                                                  if (durMS == null || durMS == 0) return const SizedBox();
                                                  final lrcDuration = l.durationMS;
                                                  if (lrcDuration == null || lrcDuration == 0) return const SizedBox();
                                                  final diff = lrcDuration - durMS;
                                                  var label = diff.milliSecondsLabelWithCentiSeconds;
                                                  if (diff >= 0) label = '+$label';
                                                  return Text(
                                                    "${lang.duration}: $label",
                                                    style: theme.textTheme.displaySmall?.copyWith(fontSize: 11.0),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!l.isEmbedded)
                                    NamidaIconButton(
                                      verticalPadding: 3.0,
                                      horizontalPadding: 3.0,
                                      tooltip: () => lang.edit,
                                      icon: Broken.edit_2,
                                      iconSize: 20.0,
                                      onPressed: () => onEditLyricsTap(l),
                                    ),
                                  if (l.file != null && l.synced && !l.fromInternet)
                                    NamidaIconButton(
                                      verticalPadding: 3.0,
                                      horizontalPadding: 3.0,
                                      icon: Broken.timer_1,
                                      iconSize: 20.0,
                                      onPressed: () {
                                        showEditCachedSyncedTimeOffsetDialog(l);
                                      },
                                    ),
                                  NamidaPopupWrapper(
                                    childrenDefault: () => getLyricsMenuItems(l),
                                    child: const MoreIcon(
                                      padding: 3.0,
                                      iconSize: 20.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              SizedBox(
                                width: context.width,
                                child: Stack(
                                  children: [
                                    NamidaInkWell(
                                      width: context.width,
                                      borderRadius: 8.0,
                                      bgColor: namida.theme.cardColor,
                                      padding: const EdgeInsets.all(8.0),
                                      child: expandedLyrics.valueR == l
                                          ? Text(
                                              l.lyrics,
                                              style: namida.textTheme.displaySmall,
                                            )
                                          : Text(
                                              l.lyrics,
                                              maxLines: 12,
                                              overflow: TextOverflow.fade,
                                              style: namida.textTheme.displaySmall,
                                            ),
                                    ),
                                    Positioned(
                                      bottom: 4.0,
                                      right: 4.0,
                                      child: Container(
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              blurRadius: 4.0,
                                              color: namida.theme.scaffoldBackgroundColor,
                                            ),
                                          ],
                                        ),
                                        child: NamidaIconButton(
                                          padding: const EdgeInsets.all(4.0),
                                          icon: Broken.maximize_circle,
                                          iconSize: 16.0,
                                          onPressed: () {
                                            if (expandedLyrics.value == l) {
                                              expandedLyrics.value = null;
                                            } else {
                                              expandedLyrics.value = l;
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  return SmoothCustomScrollView(
                    slivers: [
                      if (hasEmbedded)
                        SliverToBoxAdapter(
                          child: _PrioritizeEmbeddedLyricsTile(
                            onChanged: onPrioritizeEmbeddedChanged,
                          ),
                        ),
                      SuperSliverList.builder(
                        itemCount: availableLyricsValue.length,
                        itemBuilder: (context, index) {
                          final l = availableLyricsValue[index];
                          return listItemBuilder(context, l);
                        },
                      ),
                      const SliverToBoxAdapter(
                        child: NamidaContainerDivider(
                          margin: EdgeInsets.symmetric(vertical: 4.0),
                        ),
                      ),
                      if (fetchedLyricsValue.isEmpty && fetchingFromInternet.valueR != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsetsGeometry.symmetric(vertical: 12.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const NoResultsWidget(),
                                const SizedBox(height: 8.0),
                                NamidaInkWell(
                                  borderRadius: 6.0,
                                  bgColor: context.theme.cardColor,
                                  onTap: onSearchExternallyTap,
                                  padding: EdgeInsetsGeometry.symmetric(horizontal: 8.0, vertical: 4.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${lang.search}: Google',
                                        style: context.textTheme.displayMedium,
                                      ),
                                      const SizedBox(width: 6.0),
                                      Icon(
                                        Broken.export_1,
                                        size: 14.0,
                                      ),
                                      const SizedBox(width: 2.0),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SuperSliverList.builder(
                          itemCount: fetchedLyricsValue.length,
                          itemBuilder: (context, index) {
                            final l = fetchedLyricsValue[index];
                            return listItemBuilder(context, l);
                          },
                        ),
                      if (fetchingFromInternet.valueR != null)
                        const SliverToBoxAdapter(
                          child: NamidaContainerDivider(
                            margin: EdgeInsets.symmetric(vertical: 4.0),
                          ),
                        ),
                      SliverPadding(padding: EdgeInsetsGeometry.only(top: 8.0)),
                      SliverToBoxAdapter(
                        child: CustomListTile(
                          icon: Broken.additem,
                          title: lang.add,
                          onTap: onAddLRCPasteTap,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: CustomListTile(
                          icon: Broken.document_download,
                          title: lang.addLrcFile,
                          onTap: onAddLRCFileTap,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LyricsFontScaleButton extends StatelessWidget {
  const _LyricsFontScaleButton();

  void _showPopup(BuildContext context) {
    final popup = NamidaPopupWrapper(
      children: () => const [
        _LyricsFontScaleStepper(isFullscreen: false),
        _LyricsFontScaleStepper(isFullscreen: true),
      ],
    );
    popup.showPopupMenu(context);
  }

  @override
  Widget build(BuildContext context) {
    return NamidaIconButton(
      icon: Broken.text,
      tooltip: () => lang.fontScale,
      onPressed: () => _showPopup(context),
    );
  }
}

class _LyricsFontScaleStepper extends StatelessWidget {
  final bool isFullscreen;

  const _LyricsFontScaleStepper({
    required this.isFullscreen,
  });

  static const _kStepPercent = 5;

  void _saveNextStep(int percent) {
    final nextPercent = (percent ~/ _kStepPercent + 1) * _kStepPercent;
    _savePercent(nextPercent);
  }

  void _savePreviousStep(int percent) {
    final previousPercent = ((percent + _kStepPercent - 1) ~/ _kStepPercent - 1) * _kStepPercent;
    _savePercent(previousPercent);
  }

  void _savePercent(int percent) {
    final scale = percent / 100;
    final clampedScale = scale.clampDouble(LyricsLRCParsedView.minFontScale, LyricsLRCParsedView.maxFontScale);
    if (isFullscreen) {
      settings.fontScaleLRCFull.save(clampedScale);
    } else {
      settings.fontScaleLRC.save(clampedScale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: Row(
        children: [
          NamidaTooltip(
            message: () => isFullscreen ? '${lang.fontScale} (${lang.fullscreen})' : lang.fontScale,
            child: Icon(
              isFullscreen ? Broken.maximize_3 : Broken.text,
              size: 20.0,
            ),
          ),
          const SizedBox(width: 10.0),
          const Spacer(),
          Obx(
            (context) {
              final fullscreenScale = isFullscreen ? settings.fontScaleLRCFull.valueR : null;
              final scale = fullscreenScale ?? settings.fontScaleLRC.valueR;
              final percent = (scale * 100).round();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NamidaIconButton(
                    horizontalPadding: 5.0,
                    verticalPadding: 5.0,
                    icon: Broken.minus_cirlce,
                    iconSize: 20.0,
                    onPressed: () => _savePreviousStep(percent),
                  ),
                  NamidaInkWell(
                    width: 44.0,
                    borderRadius: 6.0,
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    onTap: () => _savePercent(100),
                    child: Text(
                      '$percent%',
                      style: textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  NamidaIconButton(
                    horizontalPadding: 5.0,
                    verticalPadding: 5.0,
                    icon: Broken.add_circle,
                    iconSize: 20.0,
                    onPressed: () => _saveNextStep(percent),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PrioritizeEmbeddedLyricsTile extends StatelessWidget {
  final void Function(bool prioritize) onChanged;

  const _PrioritizeEmbeddedLyricsTile({
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.prioritizeEmbeddedLyrics,
      builder: (context, prioritize) => CustomSwitchListTile(
        icon: Broken.mobile_programming,
        title: lang.prioritizeEmbeddedLyrics,
        subtitle: lang.global,
        value: prioritize,
        onChanged: (isTrue) => onChanged(!isTrue),
      ),
    );
  }
}

class _LyricsInUseChip extends StatelessWidget {
  final Color colorScheme;

  const _LyricsInUseChip({
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.withOpacityExt(0.3),
        borderRadius: BorderRadius.circular(4.0.multipliedRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Broken.tick_circle,
              size: 10.0,
            ),
            const SizedBox(width: 2.0),
            Text(
              lang.active,
              style: textTheme.displaySmall?.copyWith(fontSize: 11.0, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
