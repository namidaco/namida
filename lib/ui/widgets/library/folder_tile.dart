import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/general_popup_dialog.dart';

class FolderTile extends StatelessWidget {
  final Folder folder;
  final void Function()? onTap;
  final bool isMainStoragePath;
  const FolderTile({super.key, required this.folder, this.onTap, this.isMainStoragePath = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4.0),
      child: Material(
        color: context.theme.cardColor,
        child: InkWell(
          highlightColor: const Color.fromARGB(60, 0, 0, 0),
          onLongPress: () {},
          onTap: onTap ?? () => NamidaOnTaps.inst.onFolderOpen(folder, isMainStoragePath),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            height: SettingsController.inst.trackListTileHeight.value + 4.0 + 4.0,
            child: Row(
              children: [
                const SizedBox(
                  width: 12.0,
                ),
                Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 0.0,
                      ),
                      width: SettingsController.inst.trackThumbnailSizeinList.value,
                      height: SettingsController.inst.trackThumbnailSizeinList.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Broken.folder,
                            size: (SettingsController.inst.trackThumbnailSizeinList.value / 1.35).clamp(0, SettingsController.inst.trackListTileHeight.value),
                          ),
                          Positioned(
                            // top: 0,
                            // right: 0,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: ArtworkWidget(
                                blur: 0,
                                borderRadius: 6,
                                thumnailSize: (SettingsController.inst.trackThumbnailSizeinList.value / 2.6).clamp(0, SettingsController.inst.trackListTileHeight.value * 0.5),
                                path: folder.tracks.isNotEmpty ? folder.tracks.pathToImage : null,
                                forceSquared: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  width: 12.0,
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.folderName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: context.textTheme.displayMedium!,
                      ),
                      Text(
                        [
                          folder.tracks.displayTrackKeyword,
                          //TODO(MSOB7YY): fix
                          if (folder.path.getDirectoriesInside.isNotEmpty) folder.path.getDirectoriesInside.length.displayFolderKeyword,
                        ].join(' - '),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: context.textTheme.displaySmall!,
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 2.0,
                ),
                MoreIcon(
                  padding: 6.0,
                  onPressed: () {
                    showGeneralPopupDialog(
                      folder.tracks,
                      folder.folderName,
                      [
                        folder.tracks.displayTrackKeyword,
                        folder.tracks.totalDurationFormatted,
                      ].join(' • '),
                      QueueSource.folder,
                      thirdLineText: folder.tracks.map((e) => e.size).reduce((a, b) => a + b).fileSizeFormatted,
                    );
                  },
                ),
                const SizedBox(
                  width: 4.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
