import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

Future<void> showVideoDownloadOptionsSheet({
  required BuildContext context,
  required String? videoTitle,
  required String? videoUploader,
  required Map<String, String?> tagMaps,
  required bool supportTagging,
  required void Function(String newGroupName) onDownloadGroupNameChanged,
  required bool showSpecificFileOptions,
}) async {
  final controllersMap = {for (final t in FFMPEGTagField.values) t: TextEditingController(text: tagMaps[t])};

  Widget getTextChip(String field) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: supportTagging ? 1.0 : 0.5,
      child: IgnorePointer(
        ignoring: !supportTagging,
        child: CustomTagTextField(
          controller: controllersMap[field]!,
          hintText: tagMaps[field] ?? '',
          labelText: field.ffmpegTagToText(),
          icon: field.ffmpegTagToIcon(),
          onChanged: (value) => tagMaps[field] = value,
        ),
      ),
    );
  }

  Widget getRow(List<String> fields) {
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

  await Future.delayed(Duration.zero); // delay bcz sometimes doesnt show
  // ignore: use_build_context_synchronously
  await showModalBottomSheet(
    isScrollControlled: true,
    context: context,
    builder: (context) {
      final bottomPadding = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
      return SizedBox(
        height: context.height * 0.65 + bottomPadding,
        width: context.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0).add(EdgeInsets.only(bottom: bottomPadding)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20.0),
              Row(
                children: [
                  const SizedBox(width: 12.0),
                  const Icon(Broken.edit),
                  const SizedBox(width: 8.0),
                  Text(
                    lang.EDIT_TAGS,
                    style: context.textTheme.displayLarge,
                  ),
                  const SizedBox(width: 12.0),
                ],
              ),
              const SizedBox(height: 12.0),
              Expanded(
                child: ListView(
                  children: [
                    if (showSpecificFileOptions) ...[
                      Obx(
                        () => CustomSwitchListTile(
                          icon: Broken.document_code,
                          visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                          title: lang.SET_FILE_LAST_MODIFIED_AS_VIDEO_UPLOAD_DATE,
                          value: settings.downloadFilesWriteUploadDate.value,
                          onChanged: (isTrue) => settings.save(downloadFilesWriteUploadDate: !isTrue),
                        ),
                      ),
                      Obx(
                        () => CustomSwitchListTile(
                          icon: Broken.tick_circle,
                          visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                          title: lang.KEEP_CACHED_VERSIONS,
                          value: settings.downloadFilesKeepCachedVersions.value,
                          onChanged: (isTrue) => settings.save(downloadFilesKeepCachedVersions: !isTrue),
                        ),
                      ),
                      YTDownloadOptionFolderListTile(
                        onDownloadGroupNameChanged: onDownloadGroupNameChanged,
                        visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                      ),
                    ],
                    const SizedBox(height: 6.0),
                    if (!supportTagging) ...[
                      const SizedBox(height: 12.0),
                      Row(
                        children: [
                          const SizedBox(width: 12.0),
                          Icon(
                            Broken.danger,
                            color: Colors.red.withOpacity(0.7),
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            lang.WEBM_NO_EDIT_TAGS_SUPPORT,
                            style: context.textTheme.displayLarge,
                          ),
                          const SizedBox(width: 12.0),
                        ],
                      ),
                      const SizedBox(height: 12.0),
                    ],
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
                    getTextChip(FFMPEGTagField.synopsis),
                    getTextChip(FFMPEGTagField.description),
                    getTextChip(FFMPEGTagField.lyrics),
                    NamidaExpansionTile(
                      icon: Broken.more_square,
                      titleText: lang.SHOW_MORE,
                      children: [
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
                    )
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
                  Expanded(
                    flex: 4,
                    child: InkWell(
                      onTap: () {
                        (String?, String?) artistAndTitle = (null, null);
                        if (tagMaps.isNotEmpty) {
                          artistAndTitle = (tagMaps[FFMPEGTagField.artist], tagMaps[FFMPEGTagField.title]);
                        }
                        if (videoTitle != null && artistAndTitle.$1 == null && artistAndTitle.$2 == null) {
                          artistAndTitle = videoTitle.splitArtistAndTitle();
                        }
                        if (artistAndTitle.$1 != null) controllersMap[FFMPEGTagField.artist]?.text = artistAndTitle.$1!;
                        if (artistAndTitle.$2 != null) controllersMap[FFMPEGTagField.title]?.text = artistAndTitle.$2!;
                        controllersMap[FFMPEGTagField.album]?.text = tagMaps[FFMPEGTagField.album] ?? videoUploader ?? '';
                      },
                      child: Text(
                        lang.AUTO_EXTRACT_TAGS_FROM_FILENAME,
                        style: Get.textTheme.displaySmall?.copyWith(
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.dashed,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: NamidaButton(
                      text: lang.DONE,
                      onPressed: Navigator.of(context).pop,
                    ),
                  ),
                ],
              )
            ],
          ),
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
  final VisualDensity? visualDensity;
  final double? maxTrailingWidth;

  const YTDownloadOptionFolderListTile({
    super.key,
    required this.onDownloadGroupNameChanged,
    this.onDownloadFolderAdded,
    this.initialFolder = '',
    this.playlistName = '',
    this.subtitle,
    this.trailingPadding = 0,
    this.visualDensity,
    this.maxTrailingWidth,
  });

  @override
  State<YTDownloadOptionFolderListTile> createState() => YTDownloadOptionFolderListTileState();
}

class YTDownloadOptionFolderListTileState extends State<YTDownloadOptionFolderListTile> {
  final groupName = ''.obs;
  final availableDirectoriesNames = <String, int>{};

  @override
  void initState() {
    // -- to put at first
    availableDirectoriesNames[widget.playlistName] = 0;
    availableDirectoriesNames[widget.initialFolder] = 0;
    availableDirectoriesNames[''] = 0;
    int rootFiles = 0;
    for (final d in Directory(AppDirs.YOUTUBE_DOWNLOADS).listSyncSafe()) {
      if (d is Directory) {
        availableDirectoriesNames[d.path.split(Platform.pathSeparator).last] = Directory(d.path).listSyncSafe().length;
      } else {
        rootFiles++;
      }
    }
    availableDirectoriesNames[''] = rootFiles;
    groupName.value = widget.initialFolder;
    super.initState();
  }

  @override
  void dispose() {
    groupName.close();
    super.dispose();
  }

  void onGroupNameChanged(String val) {
    groupName.value = val;
    widget.onDownloadGroupNameChanged(val);
  }

  void onFolderAdd(String name) {
    onGroupNameChanged(name);
    try {
      availableDirectoriesNames[name] = Directory("${AppDirs.YOUTUBE_DOWNLOADS}$name").listSyncSafe().length; // prolly 0 but eghh maybe edge cases
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
          title: lang.ADD_FOLDER,
          actions: [
            const CancelButton(),
            const SizedBox(width: 6.0),
            NamidaButton(
              text: lang.ADD,
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
            labelText: lang.FOLDER,
            validatorMode: AutovalidateMode.always,
            validator: (value) {
              if (value == null) return lang.PLEASE_ENTER_A_NAME;
              if (value.isEmpty) return lang.EMPTY_VALUE;
              if (availableDirectoriesNames.keys.any((element) => element == value)) {
                return lang.PLEASE_ENTER_A_DIFFERENT_NAME;
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
    return CustomListTile(
      icon: Broken.add_circle,
      leading: NamidaIconButton(
        icon: Broken.add_circle,
        iconColor: context.defaultIconColor(),
        horizontalPadding: 0.0,
        onPressed: _onFolderAddTap,
      ),
      visualDensity: widget.visualDensity,
      title: lang.FOLDER,
      subtitle: widget.subtitle?.call(groupName.value),
      trailing: NamidaPopupWrapper(
        childrenDefault: () => [
          NamidaPopupItem(
            icon: Broken.add,
            title: lang.ADD,
            onTap: _onFolderAddTap,
          ),
          ...availableDirectoriesNames.keys.map(
            (name) {
              final title = name == '' ? lang.DEFAULT : name;
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
          () {
            final title = groupName.value == '' ? lang.DEFAULT : groupName.value;
            final count = availableDirectoriesNames[groupName.value];
            final countText = count == null || count == 0 ? '' : " ($count)";
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    groupName.value == widget.playlistName
                        ? Broken.music_playlist
                        : groupName.value == ''
                            ? Broken.folder_2
                            : Broken.folder,
                    size: 18.0),
                const SizedBox(width: 6.0),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: 0, maxWidth: context.width * 0.34),
                  child: Text(
                    "$title$countText",
                    style: context.textTheme.displayMedium,
                  ),
                ),
                SizedBox(width: widget.trailingPadding),
              ],
            );
          },
        ),
      ),
    );
  }
}
