// by claude
import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/track_advanced_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class IndexerDuplicateTracksSubpage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.SUBPAGE_INDEXER_DUPLICATE_TRACKS;

  const IndexerDuplicateTracksSubpage({super.key});

  @override
  State<IndexerDuplicateTracksSubpage> createState() => _IndexerDuplicateTracksSubpageState();
}

class _IndexerDuplicateTracksSubpageState extends State<IndexerDuplicateTracksSubpage> {
  late var _groups = Indexer.inst.getDuplicateGroups();
  bool _isUpdating = false;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = NamidaScrollController.create();
    Indexer.inst.duplicatedTracksLength.addListener(_refreshGroups);
  }

  @override
  void dispose() {
    Indexer.inst.duplicatedTracksLength.removeListener(_refreshGroups);
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshGroups() {
    refreshState(() => _groups = Indexer.inst.getDuplicateGroups());
  }

  Future<void> _useCopy(DuplicateTrackCopy copy) async {
    setState(() => _isUpdating = true);
    await Indexer.inst.useDuplicateCopy(copy.path);
    _isUpdating = false;
    _refreshGroups();
  }

  void _deleteAllCopies() {
    final paths = _groups.expand((e) => e.copies).map((e) => e.path);
    _deleteFiles(paths);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    if (groups.isEmpty) return const _NoExcludedTracks();

    final copiesCount = groups.fold(0, (count, e) => count + e.copies.length);
    return BackgroundWrapper(
      child: TrackTilePropertiesProvider(
        configs: TrackTilePropertiesConfigs(
          queueSource: QueueSource.others(null),
        ),
        builder: (properties) => AnimatedEnabled(
          enabled: !_isUpdating,
          child: NamidaScrollbar(
            controller: _scrollController,
            child: SuperSmoothListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(bottom: Dimensions.inst.globalBottomPaddingEffectiveR),
              itemCount: groups.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ExcludedTracksHeader(
                    icon: Broken.copy,
                    count: copiesCount,
                    onDeleteAll: _deleteAllCopies,
                  );
                }
                final group = groups[index - 1];
                return _DuplicateGroupCard(
                  group: group,
                  properties: properties,
                  onUseCopy: _useCopy,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class IndexerFilteredTracksSubpage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.SUBPAGE_INDEXER_FILTERED_TRACKS;

  const IndexerFilteredTracksSubpage({super.key});

  @override
  State<IndexerFilteredTracksSubpage> createState() => _IndexerFilteredTracksSubpageState();
}

class _IndexerFilteredTracksSubpageState extends State<IndexerFilteredTracksSubpage> {
  List<FilteredTrackFile>? _files;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = NamidaScrollController.create();
    Indexer.inst.filteredForSizeDurationTracks.addListener(_loadFiles);
    _loadFiles();
  }

  @override
  void dispose() {
    Indexer.inst.filteredForSizeDurationTracks.removeListener(_loadFiles);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    final files = await Indexer.inst.getFilteredFiles();
    refreshState(() => _files = files);
  }

  void _deleteAllFiles() {
    final paths = _files?.map((e) => e.path);
    if (paths == null) return;
    _deleteFiles(paths);
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    if (files == null) return const BackgroundWrapper(child: SizedBox());
    if (files.isEmpty) return const _NoExcludedTracks();

    final minDurationText = settings.indexMinDurationInSec.value.secondsLabel;
    final minSizeText = settings.indexMinFileSizeInB.value.fileSizeFormatted;
    final thresholdsText = '${lang.minFileDuration}: $minDurationText • ${lang.minFileSize}: $minSizeText';
    return BackgroundWrapper(
      child: NamidaScrollbar(
        controller: _scrollController,
        child: SuperSmoothListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(bottom: Dimensions.inst.globalBottomPaddingEffectiveR),
          itemCount: files.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _ExcludedTracksHeader(
                icon: Broken.filter_remove,
                count: files.length,
                subtitle: thresholdsText,
                onDeleteAll: _deleteAllFiles,
              );
            }
            final file = files[index - 1];
            final infoText = [
              file.size.fileSizeFormatted,
              if (file.durationMS > 0) file.durationMS.milliSecondsLabel,
            ].joinText();
            return _ExcludedFileTile(
              path: file.path,
              infoText: infoText,
              onDelete: () => _deleteFiles([file.path]),
            );
          },
        ),
      ),
    );
  }
}

class IndexerNoMediaFoldersSubpage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.SUBPAGE_INDEXER_NOMEDIA_FOLDERS;

  const IndexerNoMediaFoldersSubpage({super.key});

  @override
  State<IndexerNoMediaFoldersSubpage> createState() => _IndexerNoMediaFoldersSubpageState();
}

class _IndexerNoMediaFoldersSubpageState extends State<IndexerNoMediaFoldersSubpage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = NamidaScrollController.create();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Indexer.inst.tracksExcludedByNoMedia,
      builder: (context, filesCount) {
        final folders = Indexer.inst.excludedByNoMedia.entries.toList();
        if (folders.isEmpty) return const _NoExcludedTracks();
        folders.sortBy((e) => e.key);

        return BackgroundWrapper(
          child: NamidaScrollbar(
            controller: _scrollController,
            child: SuperSmoothListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(bottom: Dimensions.inst.globalBottomPaddingEffectiveR),
              itemCount: folders.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ExcludedTracksHeader(
                    icon: Broken.eye_slash,
                    count: filesCount,
                  );
                }
                final folder = folders[index - 1];
                return _NoMediaFolderTile(
                  folderPath: folder.key,
                  files: folder.value,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

void _deleteFiles(Iterable<String> paths) {
  final tracks = paths.map(Track.orVideo).toFixedList();
  showTrackDeletePermanentlyDialog(tracks, null);
}

class _NoExcludedTracks extends StatelessWidget {
  const _NoExcludedTracks();

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Broken.emoji_happy,
              size: 48.0,
            ),
            const SizedBox(height: 8.0),
            NamidaText(
              lang.noTracksFound,
              style: NText.large,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExcludedTracksHeader extends StatelessWidget {
  final IconData icon;
  final int count;
  final String? subtitle;
  final VoidCallback? onDeleteAll;

  const _ExcludedTracksHeader({
    required this.icon,
    required this.count,
    this.subtitle,
    this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final onDeleteAll = this.onDeleteAll;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20.0,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NamidaText(
                  count.displayTrackKeyword,
                  style: NText.medium,
                ),
                if (subtitle != null)
                  NamidaText(
                    subtitle,
                    style: NText.small,
                  ),
              ],
            ),
          ),
          if (onDeleteAll != null)
            NamidaIconButton(
              icon: Broken.trash,
              tooltip: () => lang.delete,
              onPressed: onDeleteAll,
            ),
        ],
      ),
    );
  }
}

class _DuplicateGroupCard extends StatelessWidget {
  final DuplicateTracksGroup group;
  final TrackTileProperties properties;
  final void Function(DuplicateTrackCopy copy) onUseCopy;

  const _DuplicateGroupCard({
    required this.group,
    required this.properties,
    required this.onUseCopy,
  });

  static String _qualityText({required String format, required int bitrate, required int sampleRate, required int size, required int durationMS}) {
    return [
      format.toUpperCase(),
      if (bitrate > 0) '$bitrate kb/s',
      if (sampleRate > 0) '${sampleRate}Hz',
      size.fileSizeFormatted,
      durationMS.milliSecondsLabel,
    ].joinText();
  }

  @override
  Widget build(BuildContext context) {
    final keptPath = group.keptPath;
    final keptTrackExt = Indexer.inst.allTracksMappedByPath[keptPath];
    final isKeptBest = group.bestPath == keptPath;
    final bestIcon = isKeptBest ? const _BestQualityIcon() : null;

    final Widget keptWidget;
    if (keptTrackExt == null) {
      keptWidget = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: NamidaText(
          keptPath.toDisplayPath(),
          style: NText.medium,
        ),
      );
    } else {
      final keptTrack = keptTrackExt.asTrack();
      final keptQualityText = _qualityText(
        format: keptTrackExt.format,
        bitrate: keptTrackExt.bitrate,
        sampleRate: keptTrackExt.sampleRate,
        size: keptTrackExt.size,
        durationMS: keptTrackExt.durationMS,
      );
      keptWidget = TrackTile(
        properties: properties,
        trackOrTwd: keptTrack,
        tracks: [keptTrack],
        index: 0,
        thirdLineText: keptQualityText,
        trailingWidget: bestIcon,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          keptWidget,
          ...group.copies.map(
            (copy) => _ExcludedFileTile(
              path: copy.path,
              infoText: _qualityText(
                format: copy.format,
                bitrate: copy.bitrate,
                sampleRate: copy.sampleRate,
                size: copy.size,
                durationMS: copy.durationMS,
              ),
              isBest: copy.path == group.bestPath,
              margin: const EdgeInsetsDirectional.only(start: 24.0, end: 4.0, top: 2.0),
              onSetAsDefault: () => onUseCopy(copy),
              onDelete: () => _deleteFiles([copy.path]),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMediaFolderTile extends StatelessWidget {
  final String folderPath;
  final List<String> files;

  const _NoMediaFolderTile({
    required this.folderPath,
    required this.files,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaExpansionTile(
      icon: Broken.folder,
      titleText: folderPath.toDisplayPath(),
      subtitleText: files.length.displayTrackKeyword,
      children: files
          .map(
            (path) => _ExcludedFileTile(
              path: path,
              showDirectory: path.getDirectoryPath != folderPath,
            ),
          )
          .toFixedList(),
    );
  }
}

class _ExcludedFileTile extends StatelessWidget {
  final String path;
  final String? infoText;
  final bool showDirectory;
  final bool isBest;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onSetAsDefault;
  final VoidCallback? onDelete;

  const _ExcludedFileTile({
    required this.path,
    this.infoText,
    this.showDirectory = true,
    this.isBest = false,
    this.margin = const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
    this.onSetAsDefault,
    this.onDelete,
  });

  Future<void> _play() async {
    final tracks = await Indexer.inst.convertPathsToExternalTracks([path]);
    if (tracks.isEmpty) return;
    await Player.inst.playOrPause(0, tracks, QueueSource.externalFile);
  }

  @override
  Widget build(BuildContext context) {
    final infoText = this.infoText;
    final onSetAsDefault = this.onSetAsDefault;
    final onDelete = this.onDelete;
    return NamidaInkWell(
      onTap: _play,
      margin: margin,
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          const SizedBox(width: 12.0),
          const Icon(
            Broken.musicnote,
            size: 18.0,
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NamidaText(
                  path.getFilename,
                  style: NText.medium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showDirectory)
                  NamidaText(
                    path.getDirectoryPath.toDisplayPath(),
                    style: NText.small,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (infoText != null)
                  NamidaText(
                    infoText,
                    style: NText.small,
                  ),
              ],
            ),
          ),
          NamidaPopupWrapper(
            childrenDefault: () => [
              NamidaPopupItem(
                icon: Broken.play,
                title: lang.play,
                onTap: _play,
              ),
              if (onSetAsDefault != null)
                NamidaPopupItem(
                  icon: Broken.arrow_swap,
                  title: lang.setAsDefault,
                  onTap: onSetAsDefault,
                ),
              if (onDelete != null)
                NamidaPopupItem(
                  icon: Broken.trash,
                  title: lang.delete,
                  onTap: onDelete,
                ),
            ],
          ),
          if (isBest) ...[
            const _BestQualityIcon(),
            const SizedBox(width: 10.0),
          ] else
            const SizedBox(width: 4.0),
        ],
      ),
    );
  }
}

class _BestQualityIcon extends StatelessWidget {
  const _BestQualityIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Broken.medal_star,
      size: 18.0,
    );
  }
}
