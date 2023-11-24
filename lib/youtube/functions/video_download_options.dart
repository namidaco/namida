import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

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
  required String videoTitle,
  required VideoInfo videoInfo,
  required Map<String, String?> tagMaps,
  required bool supportTagging,
  required void Function(String newFolderPath) onDownloadGroupNameChanged,
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
      final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
      return SizedBox(
        height: context.height * 0.65 + bottomPadding,
        width: context.width,
        child: Padding(
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
                        final artistAndTitle = videoTitle.splitArtistAndTitle();
                        if (artistAndTitle.$1 != null) controllersMap[FFMPEGTagField.artist]?.text = artistAndTitle.$1!;
                        if (artistAndTitle.$2 != null) controllersMap[FFMPEGTagField.title]?.text = artistAndTitle.$2!;
                        controllersMap[FFMPEGTagField.album]?.text = videoInfo.uploaderName ?? '';
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
}

class YTDownloadOptionFolderListTile extends StatefulWidget {
  final void Function(String newFolderPath) onDownloadGroupNameChanged;
  final String initialFolder;
  final String Function(String value)? subtitle;
  final double trailingPadding;
  final VisualDensity? visualDensity;

  const YTDownloadOptionFolderListTile({
    super.key,
    required this.onDownloadGroupNameChanged,
    this.initialFolder = '',
    this.subtitle,
    this.trailingPadding = 0,
    this.visualDensity,
  });

  @override
  State<YTDownloadOptionFolderListTile> createState() => _YTDownloadOptionFolderListTileState();
}

class _YTDownloadOptionFolderListTileState extends State<YTDownloadOptionFolderListTile> {
  final groupName = ''.obs;
  final availableDirectoriesNames = <String, int>{};

  @override
  void initState() {
    availableDirectoriesNames[''] = 0; // to put at first
    int rootFiles = 0;
    for (final d in Directory(AppDirs.YOUTUBE_DOWNLOADS).listSync()) {
      if (d is Directory) {
        availableDirectoriesNames[d.path.split(Platform.pathSeparator).last] = Directory(d.path).listSync().length;
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

  void onFolderAddTap() async {
    final c = TextEditingController();
    final fk = GlobalKey<FormState>();
    await NamidaNavigator.inst.navigateDialog(
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
                  onGroupNameChanged(c.text);
                  availableDirectoriesNames[c.text] = Directory("${AppDirs.YOUTUBE_DOWNLOADS}${c.text}").listSync().length; // prolly 0 but eghh maybe edge cases
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
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      icon: Broken.add_circle,
      leading: NamidaIconButton(
        icon: Broken.add_circle,
        iconColor: context.defaultIconColor(),
        horizontalPadding: 0.0,
        onPressed: onFolderAddTap,
      ),
      visualDensity: widget.visualDensity,
      title: lang.FOLDER,
      subtitle: widget.subtitle?.call(groupName.value),
      trailingRaw: NamidaPopupWrapper(
        childrenDefault: [
          NamidaPopupItem(
            icon: Broken.add,
            title: lang.ADD,
            onTap: onFolderAddTap,
          ),
          ...availableDirectoriesNames.keys.map(
            (name) {
              final title = name == '' ? lang.DEFAULT : name;
              final icon = name == '' ? Broken.folder_2 : Broken.folder;
              final count = availableDirectoriesNames[name];
              final countText = count == null ? '' : " ($count)";
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
            final countText = count == null ? '' : " ($count)";
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(groupName.value == '' ? Broken.folder_2 : Broken.folder, size: 18.0),
                const SizedBox(width: 6.0),
                Text(
                  "$title$countText",
                  style: context.textTheme.displayMedium,
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
