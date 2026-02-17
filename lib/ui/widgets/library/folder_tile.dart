import 'package:flutter/material.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class FolderTile extends StatefulWidget {
  final Folder folder;
  final FoldersController controller;
  final List<Track> tracks;
  final bool isTracksRecursive;
  final bool isHome;
  final int dirInsideCount;
  final String? subtitle;

  const FolderTile({
    super.key,
    required this.folder,
    required this.controller,
    required this.tracks,
    required this.isTracksRecursive,
    required this.isHome,
    required this.dirInsideCount,
    this.subtitle,
  });

  static final _infoMap = <Folder, String>{};
  static Future<String> _fetchFolderExtraInfo(Folder folder) async {
    final file = FileParts.join(folder.path, '.info.txt');
    if (await file.exists()) {
      try {
        return await file.readAsString();
      } catch (_) {}
    }
    return '';
  }

  @override
  State<FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<FolderTile> {
  String? _getFolderExtraInfo(Folder folder) {
    final valInMap = FolderTile._infoMap[folder];
    if (valInMap != null) return valInMap;
    FolderTile._fetchFolderExtraInfo(folder).then(
      (value) {
        FolderTile._infoMap[folder] = value;
        if (value.isNotEmpty) {
          refreshState();
        }
      },
    );
    return null;
  }

  void _showFolderDialog({bool? preferRecursive}) {
    bool isRecursive = widget.isTracksRecursive;
    List<Track> tracks = this.widget.tracks;
    if (preferRecursive == false && widget.isTracksRecursive) {
      final newDirectTracks = widget.controller.folderToTracks(widget.folder) ?? [];
      if (newDirectTracks.isNotEmpty) {
        isRecursive = false;
        tracks = newDirectTracks;
      }
    } else if (preferRecursive == true && !widget.isTracksRecursive) {
      final newRecursiveTracks = widget.controller.getNodeTracks(widget.folder, recursive: true);
      if (newRecursiveTracks.isNotEmpty) {
        isRecursive = true;
        tracks = newRecursiveTracks;
      }
    }
    NamidaDialogs.inst.showFolderDialog(
      folder: widget.folder,
      controller: widget.controller,
      tracks: tracks,
      isTracksRecursive: isRecursive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final double iconSize = (settings.trackThumbnailSizeinList.value * 0.85).clampDouble(0, settings.trackListTileHeight.value);
    final double thumbSize = iconSize * 0.7;
    final extraInfo = _getFolderExtraInfo(widget.folder);

    String folderTitle = widget.folder.folderName;
    Widget? trailingWidget;
    if (widget.isHome) {
      try {
        if (folderTitle.startsWith('http') || folderTitle.contains('namida_t')) {
          final server = DirectoryIndexServer.parseFromEncodedUrlPath(folderTitle);
          folderTitle = [
            server.source,
            [
              server.type.toText(),
              server.username,
            ].join(' - '),
          ].join('\n');
          final assetImagePath = server.type.toAssetImage();
          trailingWidget = assetImagePath == null
              ? null
              : Image.asset(
                  assetImagePath,
                  height: 20.0,
                );
        }
      } catch (_) {}
    }

    final subtitleTextStyle = textTheme.displaySmall?.copyWith(fontSize: 12.0);
    final subtitleFirstPart = widget.tracks.isEmpty
        ? null
        : <Widget>[
            Icon(
              Broken.musicnote,
              size: 12.0,
            ),
            SizedBox(width: 4.0),
            Text(
              '${widget.tracks.length}',
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: subtitleTextStyle,
            ),
          ];
    final subtitleSecondPart = widget.dirInsideCount <= 0
        ? null
        : <Widget>[
            Icon(
              Broken.folder,
              size: 12.0,
            ),
            SizedBox(width: 4.0),
            Text(
              '${widget.dirInsideCount}',
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

    final thumbnailCoverPath = Indexer.inst.getFallbackFolderArtworkPath(folder: widget.folder);

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.tileBottomMargin, right: Dimensions.tileBottomMargin, left: Dimensions.tileBottomMargin),
      child: NamidaInkWell(
        bgColor: theme.cardColor,
        borderRadius: 10.0,
        onTap: () => widget.controller.stepIn(widget.folder),
        onLongPress: _showFolderDialog,
        enableSecondaryTap: true,
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
                          child: thumbnailCoverPath != null
                              ? ArtworkWidget(
                                  key: ValueKey(thumbnailCoverPath),
                                  track: widget.tracks.firstOrNull, // fallback
                                  blur: 3.0,
                                  borderRadius: 6.0,
                                  thumbnailSize: thumbSize,
                                  path: thumbnailCoverPath,
                                  forceSquared: true,
                                )
                              : widget.tracks.isEmpty && widget.dirInsideCount > 0
                              ? Icon(
                                  Broken.folder_open,
                                  size: thumbSize * 0.75,
                                )
                              : ArtworkWidget(
                                  key: ValueKey(widget.tracks.firstOrNull),
                                  track: widget.tracks.firstOrNull,
                                  blur: 3.0,
                                  borderRadius: 6.0,
                                  thumbnailSize: thumbSize,
                                  path: widget.tracks.firstOrNull?.pathToImage,
                                  forceSquared: true,
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
                    extraInfo != null && extraInfo.isNotEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                folderTitle,
                                style: textTheme.displayMedium,
                              ),
                              Text(
                                ' - ($extraInfo)',
                                style: textTheme.displaySmall,
                              ),
                            ],
                          )
                        : Text(
                            folderTitle,
                            style: textTheme.displayMedium,
                          ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: textTheme.displaySmall,
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
              if (trailingWidget != null) ...[
                const SizedBox(width: 2.0),
                trailingWidget,
              ],
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
