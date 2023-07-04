import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
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
  final List<Track>? dummyTracks;
  final bool isMainStoragePath;
  final String? subtitle;

  const FolderTile({
    super.key,
    required this.folder,
    this.isMainStoragePath = false,
    this.dummyTracks,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final dirInside = folder.getDirectoriesInside();
    final tracks = dummyTracks ?? folder.tracks;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: NamidaInkWell(
        bgColor: context.theme.cardColor,
        onTap: () => NamidaOnTaps.inst.onFolderTap(folder, isMainStoragePath),
        child: SizedBox(
          height: SettingsController.inst.trackListTileHeight.value + 4.0 + 4.0,
          child: Row(
            children: [
              const SizedBox(width: 12.0),
              Stack(
                children: [
                  SizedBox(
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
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: ArtworkWidget(
                              blur: 0,
                              borderRadius: 6,
                              thumnailSize: (SettingsController.inst.trackThumbnailSizeinList.value / 2.6).clamp(0, SettingsController.inst.trackListTileHeight.value * 0.5),
                              path: tracks.firstOrNull?.pathToImage,
                              track: tracks.firstOrNull,
                              forceSquared: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12.0),
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
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: context.textTheme.displaySmall!,
                      ),
                    Text(
                      [
                        tracks.displayTrackKeyword,
                        if (dirInside.isNotEmpty) dirInside.length.displayFolderKeyword,
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
                    tracks,
                    folder.folderName,
                    [
                      tracks.displayTrackKeyword,
                      tracks.totalDurationFormatted,
                    ].join(' • '),
                    QueueSource.folder,
                    thirdLineText: tracks.totalSizeFormatted,
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
    );
  }
}
