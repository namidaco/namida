import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

Future<void> showVideoDownloadOptionsSheet({
  required BuildContext context,
  required String videoTitle,
  required VideoInfo videoInfo,
  required Map<FFMPEGTagField, String?> tagMaps,
  required bool supportTagging,
}) async {
  final controllersMap = {for (final t in FFMPEGTagField.values) t: TextEditingController(text: tagMaps[t])};

  Widget getTextChip(FFMPEGTagField field) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: supportTagging ? 1.0 : 0.5,
      child: IgnorePointer(
        ignoring: !supportTagging,
        child: CustomTagTextField(
          controller: controllersMap[field]!,
          hintText: tagMaps[field] ?? '',
          labelText: field.toText(),
          icon: field.toIcon(),
          onChanged: (value) => tagMaps[field] = value,
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

  await Future.delayed(Duration.zero); // delay bcz sometimes doesnt show
  // ignore: use_build_context_synchronously
  await showModalBottomSheet(
    isScrollControlled: true,
    context: context,
    builder: (context) {
      final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
      return SizedBox(
        height: context.height * 0.6 + bottomPadding,
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
                        visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                        title: lang.SET_FILE_LAST_MODIFIED_AS_VIDEO_UPLOAD_DATE,
                        value: settings.downloadFilesWriteUploadDate.value,
                        onChanged: (isTrue) => settings.save(downloadFilesWriteUploadDate: !isTrue),
                      ),
                    ),
                    Obx(
                      () => CustomSwitchListTile(
                        visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
                        title: lang.KEEP_CACHED_VERSIONS,
                        value: settings.downloadFilesKeepCachedVersions.value,
                        onChanged: (isTrue) => settings.save(downloadFilesKeepCachedVersions: !isTrue),
                      ),
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
