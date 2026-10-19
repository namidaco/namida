import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/widgets/yt_download_sponsorblock_tile.dart';

Future<void> showVideoDownloadOptionsSheet({
  required String? videoTitle,
  required String? videoUploader,
  required Map<String, String?> tagMaps,
  Map<FFMPEGTagField, String?>? tagMapsForFillingInfoOnly,
  required bool showSpecificFileOptions,
  Rxn<List<String>>? sponsorSegmentsCategories,
  Widget Function(TextEditingController? Function() currentControllerFn, Function(String text) onChanged)? preWidget,
}) async {
  final controllersMap = {for (final t in FFMPEGTagField.values) t.tagKey: TextEditingController(text: tagMaps[t.tagKey] ?? tagMapsForFillingInfoOnly?[t])};
  String? currentActiveField;

  Widget getTextChip(FFMPEGTagField fieldKey) {
    final field = fieldKey.tagKey;
    return CustomTagTextField(
      controller: controllersMap[field]!,
      hintText: tagMaps[field] ?? '',
      labelText: fieldKey.ffmpegTagToText(),
      icon: fieldKey.ffmpegTagToIcon(),
      onTap: () => currentActiveField = field,
      onChanged: (value) {
        currentActiveField = field;
        tagMaps[field] = value;
      },
    );
  }

  Widget getRow(List<FFMPEGTagField> fields) {
    return Row(
      children: [
        ...fields.map(
          (e) => Expanded(
            child: getTextChip(e),
          ),
        ),
      ].addSeparators(separator: const SizedBox(width: 8.0)).toFixedList(),
    );
  }

  void restoreDefaultTags(Map<FFMPEGTagField, String?> defaultTags) {
    tagMaps.clear();
    for (final t in FFMPEGTagField.values) {
      final defaultText = defaultTags[t] ?? '';
      controllersMap[t.tagKey]?.text = defaultText;
    }
  }

  await NamidaNavigator.inst.showSheet(
    isScrollControlled: true,
    heightPercentage: 0.65,
    builder: (context, bottomPadding, maxWidth, maxHeight) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28.0),
            Row(
              children: [
                const SizedBox(width: 12.0),
                const Icon(Broken.edit),
                const SizedBox(width: 8.0),
                Expanded(
                  child: NamidaText(
                    lang.editTags,
                    style: NText.large,
                  ),
                ),
                if (tagMapsForFillingInfoOnly != null)
                  NamidaIconButton(
                    tooltip: () => lang.restoreDefaults,
                    icon: Broken.refresh,
                    iconSize: 20.0,
                    onPressed: () => restoreDefaultTags(tagMapsForFillingInfoOnly),
                  ),
                const SizedBox(width: 12.0),
              ],
            ),
            const SizedBox(height: 12.0),
            if (preWidget != null)
              preWidget(
                () => controllersMap[currentActiveField],
                (text) {
                  if (currentActiveField != null) tagMaps[currentActiveField!] = text;
                },
              ),
            Expanded(
              child: SuperSmoothListView(
                children: [
                  if (showSpecificFileOptions) ...[
                    Obx(
                      (context) => CustomSwitchListTile(
                        icon: Broken.tick_circle,
                        title: lang.keepCachedVersions,
                        value: settings.downloadFilesKeepCachedVersions.valueR,
                        onChanged: (isTrue) => settings.downloadFilesKeepCachedVersions.save(!isTrue),
                      ),
                    ),
                    Obx(
                      (context) => CustomSwitchListTile(
                        icon: Broken.document_code,
                        title: lang.setFileLastModifiedAsVideoUploadDate,
                        value: settings.downloadFilesWriteUploadDate.valueR,
                        onChanged: (isTrue) => settings.downloadFilesWriteUploadDate.save(!isTrue),
                      ),
                    ),
                    Obx(
                      (context) => CustomSwitchListTile(
                        icon: Broken.music_library_2,
                        title: lang.addAudioToLocalLibrary,
                        value: settings.downloadAddAudioToLocalLibrary.valueR,
                        onChanged: (isTrue) => settings.downloadAddAudioToLocalLibrary.save(!isTrue),
                      ),
                    ),
                    Obx(
                      (context) => CustomSwitchListTile(
                        icon: Broken.crop,
                        title: lang.splitByChapters,
                        subtitle: lang.splitByChaptersSubtitle,
                        value: settings.youtube.splitDownloadsByChapters.valueR,
                        onChanged: (isTrue) => settings.youtube.splitDownloadsByChapters.save(!isTrue),
                      ),
                    ),
                    if (sponsorSegmentsCategories != null)
                      YTDownloadSponsorBlockTile(
                        categoriesOverride: sponsorSegmentsCategories,
                      ),
                    const SizedBox(height: 8.0),
                    const NamidaContainerDivider(),
                  ],
                  const SizedBox(height: 12.0),
                  ...[
                    getTextChip(FFMPEGTagField.title),
                    getRow([
                      FFMPEGTagField.artist,
                      FFMPEGTagField.album,
                    ]),
                    getRow([
                      FFMPEGTagField.genre,
                      FFMPEGTagField.year,
                    ]),
                    getRow([
                      FFMPEGTagField.trackNumber,
                      FFMPEGTagField.discNumber,
                    ]),
                    getTextChip(FFMPEGTagField.comment),
                    getTextChip(FFMPEGTagField.description),
                    getTextChip(FFMPEGTagField.synopsis),
                    getTextChip(FFMPEGTagField.lyrics),
                    NamidaExpansionTile(
                      icon: Broken.more_square,
                      titleText: lang.showMore,
                      showRail: false,
                      children:
                          [
                                ...[
                                  FFMPEGTagField.albumArtist,
                                  FFMPEGTagField.composer,
                                  FFMPEGTagField.remixer,
                                  FFMPEGTagField.lyricist,
                                  FFMPEGTagField.language,
                                  FFMPEGTagField.recordLabel,
                                  FFMPEGTagField.releaseType,
                                  FFMPEGTagField.country,
                                ].map((e) => getTextChip(e)),
                              ]
                              .addSeparators(
                                separator: const SizedBox(height: 12.0),
                              )
                              .toFixedList(),
                    ),
                  ].addSeparators(
                    separator: const SizedBox(height: 12.0),
                  ),
                ].toFixedList(),
              ),
            ),
            const SizedBox(height: 8.0),
            Row(
              children: [
                if (videoTitle != null)
                  Expanded(
                    flex: 4,
                    child: InkWell(
                      onTap: () {
                        (String?, String?) artistAndTitle = (null, null);
                        if (tagMaps.isNotEmpty) {
                          artistAndTitle = (tagMaps[FFMPEGTagField.artist.tagKey], tagMaps[FFMPEGTagField.title.tagKey]);
                        }
                        if (artistAndTitle.$1 == null && artistAndTitle.$2 == null) {
                          artistAndTitle = videoTitle.splitArtistAndTitle();
                        }
                        if (artistAndTitle.$1 != null) controllersMap[FFMPEGTagField.artist.tagKey]?.text = artistAndTitle.$1!;
                        if (artistAndTitle.$2 != null) controllersMap[FFMPEGTagField.title.tagKey]?.text = artistAndTitle.$2!;
                        controllersMap[FFMPEGTagField.album.tagKey]?.text = tagMaps[FFMPEGTagField.album.tagKey] ?? videoUploader ?? '';
                      },
                      child: Text(
                        lang.autoExtractTagsFromFilename,
                        style: NText.small
                            .of(context)
                            .copyWith(
                              decoration: TextDecoration.underline,
                              decorationStyle: TextDecorationStyle.dashed,
                            ),
                      ),
                    ),
                  ),
                Expanded(
                  flex: 5,
                  child: NamidaButton(
                    text: lang.done,
                    minHeight: NamidaButton.kDefaultMinHeight * 1.2,
                    onTap: Navigator.of(context).pop,
                  ),
                ),
              ],
            ),
            SizedBox(height: bottomPadding + 12.0),
          ],
        ),
      );
    },
  );
  for (final c in controllersMap.values) {
    c.dispose();
  }
}

class YTDownloadFolderPicker extends StatefulWidget {
  final String initialFolder;
  final String playlistName;
  final double maxTextWidth;
  final void Function(String newGroupName) onChanged;

  const YTDownloadFolderPicker({
    super.key,
    required this.initialFolder,
    required this.playlistName,
    required this.maxTextWidth,
    required this.onChanged,
  });

  @override
  State<YTDownloadFolderPicker> createState() => _YTDownloadFolderPickerState();
}

class _YTDownloadFolderPickerState extends State<YTDownloadFolderPicker> {
  final _groupName = ''.obs;
  final _availableDirectoriesNames = <String, int>{};

  @override
  void initState() {
    _groupName.value = widget.initialFolder;

    // -- to put at first
    _availableDirectoriesNames[widget.playlistName] = 0;
    _availableDirectoriesNames[widget.initialFolder] = 0;

    _initValues();

    super.initState();
  }

  @override
  void dispose() {
    _groupName.close();
    super.dispose();
  }

  void _initValues() async {
    _availableDirectoriesNames[''] = 0;
    int rootFiles = 0;
    final subfolders = <String>[];
    await for (final d in Directory(AppDirs.YOUTUBE_DOWNLOADS).list()) {
      if (d is Directory) {
        subfolders.add(d.path.splitLast(Platform.pathSeparator));
      } else {
        rootFiles++;
      }
    }
    subfolders.sort();
    for (final subfolder in subfolders) {
      _availableDirectoriesNames[subfolder] = 0;
    }
    _availableDirectoriesNames[''] = rootFiles;
    refreshState();
  }

  void _onGroupNameChanged(String val) {
    _groupName.value = val;
    widget.onChanged(val);
  }

  void _onFolderAdd(String name) {
    _availableDirectoriesNames[name] = 0;
    _onGroupNameChanged(name);
  }

  void _onFolderAddTap() async {
    final c = TextEditingController();
    final fk = GlobalKey<FormState>();
    await NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        c.dispose();
      },
      dialog: Form(
        key: fk,
        child: CustomBlurryDialog(
          title: lang.addFolder,
          actions: [
            const CancelButton(),
            NamidaButton(
              text: lang.add,
              onTap: () {
                if (fk.currentState?.validate() == true) {
                  _onFolderAdd(c.text);
                  NamidaNavigator.inst.closeDialog();
                }
              },
            ),
          ],
          child: CustomTagTextField(
            controller: c,
            autofocus: true,
            hintText: '',
            labelText: lang.folder,
            validatorMode: AutovalidateMode.always,
            validator: (value) {
              if (value == null) return lang.pleaseEnterAName;
              if (value.isEmpty) return lang.emptyValue;
              if (_availableDirectoriesNames.keys.any((element) => element == value)) {
                return lang.pleaseEnterADifferentName;
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  IconData _getFolderIcon(String name) {
    if (name == '') return Broken.folder_2;
    if (name == widget.playlistName) return Broken.music_playlist;
    return Broken.folder;
  }

  String _getFolderTitle(String name) {
    final title = name == '' ? lang.defaultLabel : name;
    final count = _availableDirectoriesNames[name];
    final countText = count == null || count == 0 ? '' : " ($count)";
    return "$title$countText";
  }

  List<NamidaPopupItem> _getPopupItems() => [
    NamidaPopupItem(
      icon: Broken.add,
      title: lang.add,
      onTap: _onFolderAddTap,
    ),
    ..._availableDirectoriesNames.keys.map(
      (name) => NamidaPopupItem(
        icon: _getFolderIcon(name),
        title: _getFolderTitle(name),
        selected: name == _groupName.value,
        onTap: () => _onGroupNameChanged(name),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      childrenDefault: _getPopupItems,
      child: NContainer(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: (colors) => BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(8.0.multipliedRadius),
        ),
        child: Obx(
          (context) {
            final groupName = _groupName.valueR;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getFolderIcon(groupName),
                  size: 16.0,
                ),
                const SizedBox(width: 6.0),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: widget.maxTextWidth),
                  child: NamidaText(
                    _getFolderTitle(groupName),
                    style: NText.medium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2.0),
                const Icon(
                  Broken.arrow_down_2,
                  size: 14.0,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
