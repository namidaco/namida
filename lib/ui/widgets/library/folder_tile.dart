import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/artwork.dart';

class FolderTile extends StatelessWidget {
  final String path;
  final List<Track> tracks;
  const FolderTile({super.key, required this.path, required this.tracks});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4.0),
      child: Material(
        color: context.theme.cardColor,
        child: InkWell(
          highlightColor: const Color.fromARGB(60, 0, 0, 0),
          onLongPress: () {},
          onTap: () {
            Folders.inst.stepIn(path);
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            height: SettingsController.inst.trackThumbnailSizeinList.value + 4.0 + 4.0,
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
                            size: SettingsController.inst.trackThumbnailSizeinList.value / 1.35,
                          ),
                          Positioned(
                            // top: 0,
                            // right: 0,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: ArtworkWidget(
                                blur: 0,
                                borderRadius: 6,
                                thumnailSize: SettingsController.inst.trackThumbnailSizeinList.value / 2.6,
                                track: tracks[0],
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
                        path.split('/').last,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: context.textTheme.displayMedium!,
                      ),
                      Text(
                        [
                          tracks.displayTrackKeyword,
                          path.getDirectoriesInside.length.displayFolderKeyword,
                        ].join(' & '),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: context.textTheme.displaySmall!,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6.0),
                SizedBox(
                  height: 36,
                  width: 36,
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {},
                      icon: const Icon(
                        Broken.more,
                        size: 20,
                      ),
                    ),
                  ),
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
