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
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
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

  lrcUtils.getItemDurationMS().then((value) {
    trackDurationMSRx.value = value;
  });

  final embedded = lrcUtils.embeddedLyrics;
  final cachedTxt = lrcUtils.cachedTxtFile;
  final cachedLRC = lrcUtils.cachedLRCFile;
  final localLRCFiles = lrcUtils.deviceLRCFiles;

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
  final int length = localLRCFiles.length;
  for (int i = 0; i < length; i++) {
    var localLRC = localLRCFiles[i];
    if (await localLRC.exists()) {
      availableLyrics.add(
        LyricsModel(
          lyrics: await localLRC.readLrcString(),
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
    if (item == Player.inst.currentItem.value) {
      Lyrics.inst.updateLyrics(item);
    }
  }

  void updateEditLyrics(LyricsModel l, LyricsModel newL) {
    final indexOfLrc = availableLyrics.value.indexOf(l);
    if (indexOfLrc >= 0) {
      availableLyrics[indexOfLrc] = newL;
      updateForCurrentTrack();
      return;
    }
    final indexOfLrc2 = fetchedLyrics.value.indexOf(l);
    if (indexOfLrc2 >= 0) {
      fetchedLyrics[indexOfLrc2] = newL;
      updateForCurrentTrack();
      return;
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
                await lrcUtils.saveLyricsToCache(lyricsString, true);
                final newLModel = LyricsModel(
                  lyrics: lyricsString,
                  synced: l.synced,
                  isInCache: l.isInCache,
                  fromInternet: l.fromInternet,
                  isEmbedded: l.isEmbedded,
                  file: l.file,
                );
                updateEditLyrics(l, newLModel);
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

  final initialSearchTextHint = lrcUtils.initialSearchTextHint;

  void onSearchExternallyTap() {
    final query = Uri.encodeComponent('$initialSearchTextHint lyrics');
    final url = "https://www.google.com/search?q=$query";
    NamidaLinkUtils.openLink(url, preferredMode: LaunchMode.externalApplication);
  }

  void onSearchTrigger([String? query]) async {
    fetchingFromInternet.value = true;
    fetchedLyrics.clear();
    final lyrics = await Lyrics.inst.searchLRCLyricsFromInternet(
      lrcUtils: lrcUtils,
      customQuery: query ?? searchController.text,
    );
    if (lyrics.isNotEmpty) fetchedLyrics.addAll(lyrics);
    fetchingFromInternet.value = false;
  }

  void onAddLRCFileTap() async {
    final picked = await NamidaFileBrowser.pickFile(
      note: lang.ADD_LRC_FILE,
      allowedExtensions: NamidaFileExtensionsWrapper.lrcOrTxt,
      initialDirectory: lrcUtils.pickFileInitialDirectory,
    );
    final path = picked?.path;
    if (path != null) {
      final text = await File(path).readLrcString();
      final synced = text.isValidLRC();
      final file = await lrcUtils.saveLyricsToCache(text, synced);
      final lrcModel = LyricsModel(
        lyrics: text,
        synced: synced,
        isInCache: false,
        fromInternet: false,
        file: file,
        isEmbedded: false,
      );
      availableLyrics.add(lrcModel);
      updateForCurrentTrack();
      // selectedLyrics.value = lrcModel;
    }
  }

  void onAddLRCPasteTap() async {
    final pasteTextController = TextEditingController();
    final clipboardTextRx = ''.obs;
    void savePastedLRC([String? text]) async {
      text ??= pasteTextController.text;
      final synced = text.isValidLRC();

      final file = await lrcUtils.saveLyricsToCache(text, synced);

      final lrcModel = LyricsModel(
        lyrics: text,
        synced: synced,
        isInCache: true,
        fromInternet: false,
        file: file,
        isEmbedded: false,
      );
      availableLyrics.add(lrcModel);
      updateForCurrentTrack();
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
        title: lang.ADD,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          const SizedBox(width: 6.0),
          NamidaButton(
            text: lang.ADD.toUpperCase(),
            onPressed: savePastedLRC,
          )
        ],
        trailingWidgets: [
          NamidaIconButton(
            icon: Broken.export_1,
            tooltip: () => '${lang.SEARCH}: Google',
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
                      title: lang.COPIED_TO_CLIPBOARD,
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
                    hintText: lang.LYRICS,
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

      final file = await lrcUtils.saveLyricsToCache(text, synced);

      final lrcModel = LyricsModel(
        lyrics: text,
        synced: synced,
        isInCache: l.isInCache,
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
        title: lang.EDIT,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          const SizedBox(width: 6.0),
          NamidaButton(
            text: lang.SAVE.toUpperCase(),
            onPressed: saveEditedLRC,
          )
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
                  hintText: lang.LYRICS,
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
      horizontalInset: 38.0,
      normalTitleStyle: true,
      title: lang.LYRICS,
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
              lang.LYRICS,
              style: theme.textTheme.displayLarge,
            ),
          ),
          const SizedBox(width: 8.0),
          NamidaIconButton(
            icon: Broken.additem,
            tooltip: () => lang.ADD,
            onPressed: onAddLRCPasteTap,
          ),
          NamidaIconButton(
            icon: Broken.document_download,
            tooltip: () => lang.ADD_LRC_FILE,
            onPressed: onAddLRCFileTap,
          ),
        ],
      ),
      actions: [
        NamidaButton(
          text: lang.SEARCH,
          onPressed: onSearchTrigger,
        ),
        const CancelButton(),
        const SizedBox(width: 6.0),
        Obx(
          (context) {
            final selected = selectedLyrics.valueR;
            final canAddToCache = selected != null && !selected.isInCache && !selected.isEmbedded /* && (selected.file != null || selected.fromInternet == true) */;
            return NamidaButton(
              text: canAddToCache ? lang.SAVE : lang.DONE,
              onPressed: () async {
                if (canAddToCache) {
                  final selected = selectedLyrics.value;
                  if (selected != null) {
                    await lrcUtils.saveLyricsToCache(selected.lyrics, selected.synced);
                    updateForCurrentTrack();
                  }
                }

                NamidaNavigator.inst.closeDialog();
              },
            );
          },
        )
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
                )
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

                  Widget listItemBuilder(BuildContext context, LyricsModel l, bool isTempFetched) {
                    final syncedText = l.synced ? lang.SYNCED : lang.PLAIN;
                    final cacheText = l.file == null
                        ? ''
                        : l.isInCache
                            ? lang.CACHE
                            : lang.LOCAL;
                    return Obx(
                      (context) => NamidaInkWell(
                        borderRadius: 12.0,
                        animationDurationMS: 200,
                        onTap: isTempFetched ? () => selectedLyrics.value = l : null,
                        bgColor: namida.theme.cardColor.withValues(alpha: 0.4),
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
                                  l.file == null ? Broken.document_download : Broken.document,
                                  size: 18.0,
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
                                      ObxO(
                                        rx: trackDurationMSRx,
                                        builder: (context, durMS) {
                                          if (durMS == null || durMS == 0) return const SizedBox();
                                          final lrcDuration = l.durationMS;
                                          if (lrcDuration == null || lrcDuration == 0) return const SizedBox();
                                          final diff = lrcDuration - durMS;
                                          var label = diff.milliSecondsLabelWithCentiSeconds;
                                          if (diff >= 0) label = '+$label';
                                          return Text(
                                            "${lang.DURATION}: $label",
                                            style: theme.textTheme.displaySmall?.copyWith(fontSize: 11.0),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                NamidaIconButton(
                                  verticalPadding: 3.0,
                                  horizontalPadding: 3.0,
                                  tooltip: () => lang.COPY,
                                  icon: Broken.copy,
                                  iconSize: 20.0,
                                  onPressed: () {
                                    final text = l.lyrics;
                                    NamidaUtils.copyToClipboard(
                                      content: text,
                                      message: text.replaceAll('\n', ' '),
                                      maxLinesMessage: 2,
                                      altDesign: true,
                                    );
                                  },
                                ),
                                NamidaIconButton(
                                  verticalPadding: 3.0,
                                  horizontalPadding: 3.0,
                                  tooltip: () => lang.EDIT,
                                  icon: Broken.edit_2,
                                  iconSize: 20.0,
                                  onPressed: () => onEditLyricsTap(l),
                                ),
                                if (l.file != null) ...[
                                  if (l.synced && !l.fromInternet)
                                    NamidaIconButton(
                                      verticalPadding: 3.0,
                                      horizontalPadding: 3.0,
                                      icon: Broken.timer_1,
                                      iconSize: 20.0,
                                      onPressed: () {
                                        showEditCachedSyncedTimeOffsetDialog(l);
                                      },
                                    ),
                                  NamidaIconButton(
                                    verticalPadding: 3.0,
                                    horizontalPadding: 3.0,
                                    icon: Broken.trash,
                                    iconSize: 20.0,
                                    onPressed: () {
                                      showDeleteLyricsDialog(l);
                                    },
                                  ),
                                  const SizedBox(width: 2.0),
                                ],
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
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SmoothCustomScrollView(
                    slivers: [
                      SuperSliverList.builder(
                        itemCount: availableLyricsValue.length,
                        itemBuilder: (context, index) {
                          final l = availableLyricsValue[index];
                          return listItemBuilder(context, l, false);
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
                                const Icon(
                                  Broken.emoji_sad,
                                  size: 48.0,
                                ),
                                const SizedBox(height: 6.0),
                                NamidaInkWell(
                                  borderRadius: 6.0,
                                  bgColor: context.theme.cardColor,
                                  onTap: onSearchExternallyTap,
                                  padding: EdgeInsetsGeometry.symmetric(horizontal: 8.0, vertical: 4.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${lang.SEARCH}: Google',
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
                            return listItemBuilder(context, l, true);
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
                          visualDensity: VisualDensity.compact,
                          icon: Broken.additem,
                          title: lang.ADD,
                          onTap: onAddLRCPasteTap,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: CustomListTile(
                          visualDensity: VisualDensity.compact,
                          icon: Broken.document_download,
                          title: lang.ADD_LRC_FILE,
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
