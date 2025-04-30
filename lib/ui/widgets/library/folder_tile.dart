import 'package:flutter/material.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class FolderTile extends StatelessWidget {
  final Folder folder;
  final FoldersController controller;
  final List<Track> tracks;
  final bool isTracksRecursive;
  final int dirInsideCount;
  final String? subtitle;

  const FolderTile({
    super.key,
    required this.folder,
    required this.controller,
    required this.tracks,
    required this.isTracksRecursive,
    required this.dirInsideCount,
    this.subtitle,
  });

  static final _infoMap = <Folder, String>{};
  static String _getFolderExtraInfo(Folder folder) {
    final file = FileParts.join(folder.path, '.info.txt');
    if (file.existsSync()) {
      try {
        return file.readAsStringSync();
      } catch (_) {}
    }
    return '';
  }

  void _showFolderDialog({bool? preferRecursive}) {
    bool isRecursive = isTracksRecursive;
    List<Track> tracks = this.tracks;
    if (preferRecursive == false && isTracksRecursive) {
      final newDirectTracks = folder.tracks();
      if (newDirectTracks.isNotEmpty) {
        isRecursive = false;
        tracks = newDirectTracks;
      }
    } else if (preferRecursive == true && !isTracksRecursive) {
      final newRecursiveTracks = controller.getNodeTracks(folder, recursive: true);
      if (newRecursiveTracks.isNotEmpty) {
        isRecursive = true;
        tracks = newRecursiveTracks;
      }
    }
    NamidaDialogs.inst.showFolderDialog(
      folder: folder,
      controller: controller,
      tracks: tracks,
      isTracksRecursive: isRecursive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = (settings.trackThumbnailSizeinList.value / 1.35).clampDouble(0, settings.trackListTileHeight.value);
    final double thumbSize = (settings.trackThumbnailSizeinList.value / 2.6).clampDouble(0, settings.trackListTileHeight.value * 0.5);
    final extraInfo = _infoMap[folder] ??= _getFolderExtraInfo(folder);

    final subtitleTextStyle = context.textTheme.displaySmall?.copyWith(fontSize: 12.0);
    final subtitleFirstPart = tracks.isEmpty
        ? null
        : <Widget>[
            Icon(
              Broken.musicnote,
              size: 12.0,
            ),
            SizedBox(width: 4.0),
            Text(
              '${tracks.length}',
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: subtitleTextStyle,
            ),
          ];
    final subtitleSecondPart = dirInsideCount <= 0
        ? null
        : <Widget>[
            Icon(
              Broken.folder,
              size: 12.0,
            ),
            SizedBox(width: 4.0),
            Text(
              '$dirInsideCount',
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: subtitleTextStyle,
            ),
          ];
    final subtitleRowChildren = <Widget>[
      if (subtitleFirstPart != null) ...subtitleFirstPart,
      if (subtitleFirstPart != null && subtitleSecondPart != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            '•',
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: subtitleTextStyle,
          ),
        ),
      if (subtitleSecondPart != null) ...subtitleSecondPart,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.tileBottomMargin, right: Dimensions.tileBottomMargin, left: Dimensions.tileBottomMargin),
      child: NamidaInkWell(
        bgColor: context.theme.cardColor,
        borderRadius: 10.0,
        onTap: folder.navigate,
        onLongPress: () => _showFolderDialog(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimensions.tileVerticalPadding),
          child: Row(
            children: [
              const SizedBox(width: 12.0),
              Stack(
                children: [
                  SizedBox(
                    width: settings.trackThumbnailSizeinList.value.withMinimum(12.0),
                    height: (Dimensions.inst.trackTileItemExtent - Dimensions.totalVerticalDistance).withMinimum(12.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Broken.folder,
                          size: iconSize,
                        ),
                        Positioned(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: tracks.isEmpty && dirInsideCount > 0
                                ? Icon(
                                    Broken.folder_open,
                                    size: thumbSize,
                                  )
                                : ArtworkWidget(
                                    key: ValueKey(tracks.firstOrNull),
                                    track: tracks.firstOrNull,
                                    blur: 0,
                                    borderRadius: 6,
                                    thumbnailSize: thumbSize,
                                    path: tracks.firstOrNull?.pathToImage,
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
                    extraInfo.isNotEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                folder.folderName,
                                style: context.textTheme.displayMedium,
                              ),
                              Text(
                                ' - ($extraInfo)',
                                style: context.textTheme.displaySmall,
                              ),
                            ],
                          )
                        : Text(
                            folder.folderName,
                            style: context.textTheme.displayMedium,
                          ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: context.textTheme.displaySmall,
                      ),
                    if (subtitleRowChildren.isNotEmpty) ...[
                      SizedBox(height: 4.0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: subtitleRowChildren,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(
                width: 2.0,
              ),
              MoreIcon(
                padding: 6.0,
                onPressed: () => _showFolderDialog(preferRecursive: false),
                onLongPress: () => _showFolderDialog(),
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
