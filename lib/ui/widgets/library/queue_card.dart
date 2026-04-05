import 'package:flutter/material.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class QueueCard extends StatelessWidget {
  final Queue? queue;
  final String hero;
  final bool fullInfo;
  final HomePageItems? homepageItem;
  final bool preferOpenOriginalSource;

  const QueueCard({
    super.key,
    required this.queue,
    this.hero = '',
    this.fullInfo = true,
    this.homepageItem,
    this.preferOpenOriginalSource = false,
  });

  bool _originalSourceOnTap() {
    final queue = this.queue;
    if (queue == null) return false;
    final sourceType = queue.source.s;
    if (sourceType is! QueueSourceEnum) return false;
    final nameOrPath = queue.source.title ?? '';
    bool handled = true;
    switch (sourceType) {
      case QueueSourceEnum.playlist:
        NamidaOnTaps.inst.onNormalPlaylistTap(nameOrPath, disableAnimation: true);
      case QueueSourceEnum.folder:
        var f = Folder.explicit(nameOrPath);
        var tracks = f.tracksDedicated();
        if (tracks.isEmpty) {
          f = VideoFolder.explicit(nameOrPath);
          tracks = f.tracksDedicated();
        }
        ScrollSearchController.inst.animatePageController(LibraryTab.folders);
        FoldersController.tracksAndVideos.stepIn(f);
      case QueueSourceEnum.folderMusic:
        final f = Folder.explicit(nameOrPath);
        ScrollSearchController.inst.animatePageController(LibraryTab.folders);
        FoldersController.tracks.stepIn(f);
      case QueueSourceEnum.folderVideos:
        final f = VideoFolder.explicit(nameOrPath);
        ScrollSearchController.inst.animatePageController(LibraryTab.folders);
        FoldersController.videos.stepIn(f);
      default:
        handled = false;
    }
    if (handled) VibratorController.medium();
    return handled;
  }

  bool _originalSourceOnLongPress() {
    final queue = this.queue;
    if (queue == null) return false;
    final sourceType = queue.source.s;
    if (sourceType is! QueueSourceEnum) return false;
    final nameOrPath = queue.source.title ?? '';
    bool handled = true;
    switch (sourceType) {
      case QueueSourceEnum.playlist:
        NamidaDialogs.inst.showPlaylistDialog(nameOrPath);
      case QueueSourceEnum.folder:
        var f = Folder.explicit(nameOrPath);
        var tracks = f.tracksDedicated();
        if (tracks.isEmpty) {
          f = VideoFolder.explicit(nameOrPath);
          tracks = f.tracksDedicated();
        }
        NamidaDialogs.inst.showFolderDialog(
          folder: f,
          controller: FoldersController.tracksAndVideos,
          tracks: tracks,
          isTracksRecursive: false,
        );
      case QueueSourceEnum.folderMusic:
        final f = Folder.explicit(nameOrPath);
        final tracks = f.tracksDedicated();
        NamidaDialogs.inst.showFolderDialog(
          folder: f,
          controller: FoldersController.tracks,
          tracks: tracks,
          isTracksRecursive: false,
        );
      case QueueSourceEnum.folderVideos:
        final f = VideoFolder.explicit(nameOrPath);
        final tracks = f.tracksDedicated();
        NamidaDialogs.inst.showFolderDialog(
          folder: f,
          controller: FoldersController.videos,
          tracks: tracks,
          isTracksRecursive: false,
        );
      default:
        handled = false;
    }
    if (handled) VibratorController.medium();
    return handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final queue = this.queue;
    final sourceText = queue?.toSourceText();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.gridHorizontalPadding),
      child: BorderRadiusClip(
        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacityExt(0.9),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withAlpha(50),
                blurRadius: 12,
                offset: const Offset(0, 2.0),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageSize = constraints.maxWidth;
              double remainingVerticalSpace;
              if (constraints.maxHeight.isInfinite || constraints.maxHeight.isNaN) {
                remainingVerticalSpace = 48.0;
              } else {
                remainingVerticalSpace = constraints.maxHeight - imageSize;
              }
              double getFontSize(double m) => (remainingVerticalSpace * m * 0.9).withMaximum(15.0);

              return NamidaInkWell(
                onTap: () {
                  if (queue == null) return;
                  if (preferOpenOriginalSource) {
                    if (_originalSourceOnTap()) return;
                  }
                  NamidaOnTaps.inst.onQueueTap(queue);
                },
                onLongPress: () {
                  if (queue == null) return;
                  if (preferOpenOriginalSource) {
                    if (_originalSourceOnLongPress()) return;
                  }
                  NamidaDialogs.inst.showQueueDialog(queue.date);
                },
                enableSecondaryTap: true,
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    MultiArtworks(
                      heroTag: hero,
                      borderRadius: 12.0,
                      thumbnailSize: imageSize,
                      artworkFile: null,
                      tracks: queue?.tracks.toImageTracks() ?? [],
                      reduceQuality: true,
                    ),
                    if (queue != null)
                      SizedBox(
                        width: imageSize,
                        height: remainingVerticalSpace,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              NamidaHero(
                                tag: 'line1_$hero',
                                child: Text(
                                  fullInfo
                                      ? [
                                          queue.source.toText(),
                                          ?sourceText,
                                        ].joinText(separator: ' - ')
                                      : sourceText ?? queue.source.toText(),
                                  style: textTheme.displayMedium?.copyWith(fontSize: getFontSize(0.28)),
                                  textAlign: TextAlign.start,
                                  softWrap: false,
                                  overflow: TextOverflow.fade,
                                ),
                              ),
                              if (fullInfo)
                                NamidaHero(
                                  tag: 'line2_$hero',
                                  child: Text(
                                    [
                                      queue.tracks.displayTrackKeyword,
                                      queue.tracks.totalDurationFormatted,
                                    ].joinText(separator: ' - '),
                                    style: textTheme.displaySmall?.copyWith(fontSize: getFontSize(0.23)),
                                    softWrap: false,
                                    overflow: TextOverflow.fade,
                                  ),
                                ),
                              NamidaHero(
                                tag: 'line3_$hero',
                                child: Text(
                                  fullInfo ? queue.date.dateAndClockFormattedOriginal : TimeAgoController.dateMSSEFromNow(queue.date),
                                  style: textTheme.displaySmall?.copyWith(fontSize: getFontSize(0.23)),
                                  softWrap: false,
                                  overflow: TextOverflow.fade,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
