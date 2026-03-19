import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/yt_utils.dart';

Future<void> showVideoDownloadOptionsSheet({
  required String? videoTitle,
  required String? videoUploader,
  required Map<String, String?> tagMaps,
  Map<FFMPEGTagField, String?>? tagMapsForFillingInfoOnly,
  required bool supportTagging,
  required void Function(String newGroupName) onDownloadGroupNameChanged,
  required void Function(String filename) onDownloadFilenameChanged,
  required bool showSpecificFileOptions,
  Widget Function(TextEditingController? Function() currentControllerFn, Function(String text) onChanged)? preWidget,
  required String? initialGroupName,
}) async {
  final controllersMap = {for (final t in FFMPEGTagField.values) t.tagKey: TextEditingController(text: tagMaps[t.tagKey] ?? tagMapsForFillingInfoOnly?[t])};
  String? currentActiveField;

  Widget getTextChip(FFMPEGTagField fieldKey) {
    final field = fieldKey.tagKey;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: supportTagging ? 1.0 : 0.5,
      child: IgnorePointer(
        ignoring: !supportTagging,
        child: CustomTagTextField(
          controller: controllersMap[field]!,
          hintText: tagMaps[field] ?? '',
          labelText: fieldKey.ffmpegTagToText(),
          icon: fieldKey.ffmpegTagToIcon(),
          onTap: () => currentActiveField = field,
          onChanged: (value) {
            currentActiveField = field;
            tagMaps[field] = value;
          },
        ),
      ),
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
      ].addSeparators(separator: const SizedBox(width: 8.0), skipFirst: 1).toList(),
    );
  }

  await NamidaNavigator.inst.showSheet(
    isScrollControlled: true,
    heightPercentage: 0.65,
    builder: (context, bottomPadding, maxWidth, maxHeight) {
      final textTheme = context.textTheme;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20.0),
            Row(
              children: [
                const SizedBox(width: 12.0),
                const Icon(Broken.edit),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    lang.editTags,
                    style: textTheme.displayLarge,
                  ),
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
                children:
                    [
                          if (showSpecificFileOptions) ...[
                            Obx(
                              (context) => CustomSwitchListTile(
                                icon: Broken.tick_circle,
                                visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                title: lang.keepCachedVersions,
                                value: settings.downloadFilesKeepCachedVersions.valueR,
                                onChanged: (isTrue) => settings.save(downloadFilesKeepCachedVersions: !isTrue),
                              ),
                            ),
                            Obx(
                              (context) => CustomSwitchListTile(
                                icon: Broken.document_code,
                                visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                title: lang.setFileLastModifiedAsVideoUploadDate,
                                value: settings.downloadFilesWriteUploadDate.valueR,
                                onChanged: (isTrue) => settings.save(downloadFilesWriteUploadDate: !isTrue),
                              ),
                            ),
                            Obx(
                              (context) => CustomSwitchListTile(
                                icon: Broken.music_library_2,
                                visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                                title: lang.addAudioToLocalLibrary,
                                value: settings.downloadAddAudioToLocalLibrary.valueR,
                                onChanged: (isTrue) => settings.save(downloadAddAudioToLocalLibrary: !isTrue),
                              ),
                            ),
                          ],
                          if (!supportTagging) ...[
                            const SizedBox(height: 12.0),
                            Row(
                              children: [
                                const SizedBox(width: 12.0),
                                Icon(
                                  Broken.danger,
                                  color: Colors.red.withOpacityExt(0.7),
                                ),
                                const SizedBox(width: 8.0),
                                Text(
                                  lang.webmNoEditTagsSupport,
                                  style: textTheme.displayLarge,
                                ),
                                const SizedBox(width: 12.0),
                              ],
                            ),
                            const SizedBox(height: 12.0),
                          ],
                          const NamidaContainerDivider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: YTDownloadOptionFolderListTile(
                              iconSize: 20.0,
                              initialFolder: initialGroupName ?? '',
                              playlistName: initialGroupName ?? '',
                              onDownloadGroupNameChanged: onDownloadGroupNameChanged,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Broken.document_code,
                                  size: 20.0,
                                ),
                                const SizedBox(width: 12.0),
                                Expanded(
                                  child: ObxO(
                                    rx: settings.youtube.downloadFilenameBuilder,
                                    builder: (context, value) {
                                      if (value.isEmpty) value = settings.youtube.defaultFilenameBuilder;
                                      return Text(
                                        value,
                                        style: textTheme.displaySmall,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6.0),
                                NamidaIconButton(
                                  tooltip: () => lang.output,
                                  icon: Broken.edit_2,
                                  iconSize: 20.0,
                                  onPressed: () {
                                    YTUtils.showFilenameBuilderOutputSheet(
                                      showEditTags: false,
                                      groupName: initialGroupName ?? '',
                                      onChanged: onDownloadFilenameChanged,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const NamidaContainerDivider(),
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
                            children:
                                [
                                      ...[
                                        FFMPEGTagField.albumArtist,
                                        FFMPEGTagField.composer,
                                        FFMPEGTagField.remixer,
                                        FFMPEGTagField.lyricist,
                                        FFMPEGTagField.language,
                                        FFMPEGTagField.recordLabel,
                                        FFMPEGTagField.country,
                                      ].map((e) => getTextChip(e)),
                                    ]
                                    .addSeparators(
                                      separator: const SizedBox(height: 12.0),
                                    )
                                    .toList(),
                          ),
                        ]
                        .addSeparators(
                          separator: const SizedBox(height: 12.0),
                        )
                        .toList(),
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
                        style: namida.textTheme.displaySmall?.copyWith(
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
                    onPressed: Navigator.of(context).pop,
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

class YTDownloadOptionFolderListTile extends StatefulWidget {
  final void Function(String newGroupName) onDownloadGroupNameChanged;
  final void Function(String newFolderName)? onDownloadFolderAdded;
  final String initialFolder;
  final String playlistName;
  final String Function(String value)? subtitle;
  final double trailingPadding;
  final double? maxTrailingWidth;
  final double? iconSize;

  const YTDownloadOptionFolderListTile({
    super.key,
    required this.onDownloadGroupNameChanged,
    this.onDownloadFolderAdded,
    this.initialFolder = '',
    this.playlistName = '',
    this.subtitle,
    this.trailingPadding = 0,
    this.maxTrailingWidth,
    this.iconSize,
  });

  @override
  State<YTDownloadOptionFolderListTile> createState() => YTDownloadOptionFolderListTileState();
}

class YTDownloadOptionFolderListTileState extends State<YTDownloadOptionFolderListTile> {
  final groupName = ''.obs;
  final availableDirectoriesNames = <String, int>{};

  @override
  void initState() {
    groupName.value = widget.initialFolder;

    // -- to put at first
    availableDirectoriesNames[widget.playlistName] = 0;
    availableDirectoriesNames[widget.initialFolder] = 0;

    initValues();

    super.initState();
  }

  @override
  void dispose() {
    groupName.close();
    super.dispose();
  }

  void initValues() async {
    availableDirectoriesNames[''] = 0;
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
      availableDirectoriesNames[subfolder] = 0;
    }
    availableDirectoriesNames[''] = rootFiles;
    refreshState();
  }

  void onGroupNameChanged(String val) {
    groupName.value = val;
    widget.onDownloadGroupNameChanged(val);
  }

  void onFolderAdd(String name) {
    onGroupNameChanged(name);
    try {
      availableDirectoriesNames[name] = 0;
    } catch (_) {}
    widget.onDownloadFolderAdded?.call(name);
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
            const SizedBox(width: 6.0),
            NamidaButton(
              text: lang.add,
              onPressed: () {
                if (fk.currentState?.validate() == true) {
                  onFolderAdd(c.text);
                  NamidaNavigator.inst.closeDialog();
                }
              },
            ),
          ],
          child: CustomTagTextField(
            controller: c,
            hintText: '',
            labelText: lang.folder,
            validatorMode: AutovalidateMode.always,
            validator: (value) {
              if (value == null) return lang.pleaseEnterAName;
              if (value.isEmpty) return lang.emptyValue;
              if (availableDirectoriesNames.keys.any((element) => element == value)) {
                return lang.pleaseEnterADifferentName;
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final subtitle = widget.subtitle?.call(groupName.value);
    return LayoutWidthProvider(
      builder: (context, maxWidth) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            NamidaIconButton(
              icon: Broken.add_circle,
              iconColor: context.defaultIconColor(),
              horizontalPadding: 0.0,
              iconSize: widget.iconSize,
              onPressed: _onFolderAddTap,
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.folder,
                    style: theme.textTheme.displayMedium,
                    maxLines: subtitle != null ? 4 : 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle?.isNotEmpty == true)
                    Text(
                      subtitle!,
                      style: theme.textTheme.displaySmall,
                      maxLines: 20,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            SizedBox(width: 6.0),
            NamidaPopupWrapper(
              childrenDefault: () => [
                NamidaPopupItem(
                  icon: Broken.add,
                  title: lang.add,
                  onTap: _onFolderAddTap,
                ),
                ...availableDirectoriesNames.keys.map(
                  (name) {
                    final title = name == '' ? lang.defaultLabel : name;
                    final icon = name == widget.playlistName
                        ? Broken.music_playlist
                        : name == ''
                        ? Broken.folder_2
                        : Broken.folder;
                    final count = availableDirectoriesNames[name];
                    final countText = count == null || count == 0 ? '' : " ($count)";
                    return NamidaPopupItem(
                      icon: icon,
                      title: "$title$countText",
                      onTap: () => onGroupNameChanged(name),
                    );
                  },
                ),
              ],
              child: Obx(
                (context) {
                  final groupName = this.groupName.valueR;
                  final title = groupName == '' ? lang.defaultLabel : groupName;
                  final count = availableDirectoriesNames[groupName];
                  final countText = count == null || count == 0 ? '' : " ($count)";
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        groupName == widget.playlistName
                            ? Broken.music_playlist
                            : groupName == ''
                            ? Broken.folder_2
                            : Broken.folder,
                        size: 18.0,
                      ),
                      const SizedBox(width: 6.0),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: 0, maxWidth: maxWidth * 0.34),
                          child: Text(
                            "$title$countText",
                            style: textTheme.displayMedium,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(width: widget.trailingPadding),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
