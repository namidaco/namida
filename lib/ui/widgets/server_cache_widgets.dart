import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/pages/youtube_home_view.dart';

class ServerCacheTrackIndicator extends StatelessWidget {
  final Track track;

  const ServerCacheTrackIndicator({
    super.key,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    final controller = ServerCacheController.inst;
    return ObxO(
      rx: controller.tasks,
      builder: (context, tasks) {
        final task = tasks[track.path];
        if (task != null) {
          return ColoredBox(
            color: const Color(0x5A000000),
            child: Center(
              child: _ServerCacheTaskRing(
                task: task,
                size: 22.0,
                color: Colors.white,
              ),
            ),
          );
        }
        return ObxO(
          rx: controller.keptPaths,
          builder: (context, keptPaths) => keptPaths.contains(track.path) ? const SizedBox() : const _NotCachedBadge(),
        );
      },
    );
  }
}

class _NotCachedBadge extends StatelessWidget {
  const _NotCachedBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.theme.cardColor.withAlpha(200),
          borderRadius: BorderRadius.only(topRight: Radius.circular(4.0.multipliedRadius)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(2.0),
          child: Icon(
            Broken.document_download,
            size: 12.0,
          ),
        ),
      ),
    );
  }
}

class _ServerCacheTaskRing extends StatelessWidget {
  final ServerCacheTask task;
  final double size;
  final Color? color;

  const _ServerCacheTaskRing({
    required this.task,
    required this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ObxO(
        rx: task.state,
        builder: (context, state) => switch (state) {
          ServerCacheTaskState.failed => Icon(
            Broken.danger,
            size: size,
            color: color,
          ),
          ServerCacheTaskState.queued => CircularProgressIndicator(
            value: 0.0,
            strokeWidth: 2.0,
            color: color,
            backgroundColor: color?.withAlpha(60),
          ),
          ServerCacheTaskState.downloading => ObxO(
            rx: task.downloadedBytes,
            builder: (context, downloaded) {
              final total = task.track.size;
              return CircularProgressIndicator(
                value: total > 0 ? (downloaded / total).clampDouble(0.0, 1.0) : null,
                strokeWidth: 2.0,
                color: color,
                backgroundColor: color?.withAlpha(60),
              );
            },
          ),
        },
      ),
    );
  }
}

class DownloadsAppBarIcon extends StatelessWidget {
  const DownloadsAppBarIcon({super.key});

  static void _openYoutubeDownloads() {
    final currentRouteType = NamidaNavigator.inst.currentRoute?.route;
    if (currentRouteType == RouteType.YOUTUBE_HOME && settings.extra.ytInitialHomePage.value == YTHomePages.downloads) {
      return;
    }
    settings.extra.save(ytInitialHomePage: YTHomePages.downloads);
    if (currentRouteType == RouteType.YOUTUBE_HOME) {
      NamidaNavigator.inst.navigateOffAll(const YouTubeHomeView()); // -- the tab view only reads its initial page once
    } else {
      ScrollSearchController.inst.animatePageController(LibraryTab.youtube);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: YoutubeController.inst.activeRawDownloadsCount,
      builder: (context, youtubeCount) => ObxO(
        rx: ServerCacheController.inst.tasks,
        builder: (context, serverTasks) {
          final count = youtubeCount + serverTasks.length;
          final theme = context.theme;
          return AnimatedShow(
            show: count > 0,
            isHorizontal: true,
            curve: Curves.fastEaseInToSlowEaseOut,
            duration: Duration(milliseconds: 400),
            child: NamidaAppBarIcon(
              icon: Broken.import,
              tooltip: () => lang.downloads,
              onPressed: serverTasks.isEmpty ? _openYoutubeDownloads : _ServerCacheQueueSheet.show,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Broken.import,
                    color: theme.colorScheme.secondary,
                  ),
                  Positioned(
                    top: -4.0,
                    right: -6.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                        child: Text(
                          count.formatDecimal(),
                          style: theme.textTheme.displaySmall?.copyWith(fontSize: 10.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ServerCacheQueueSheet extends StatelessWidget {
  const _ServerCacheQueueSheet();

  static void show() {
    NamidaNavigator.inst.showSheet(
      isScrollControlled: true,
      showDragHandle: true,
      heightPercentage: 0.7,
      builder: (context, bottomPadding, maxWidth, maxHeight) => const _ServerCacheQueueSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ServerCacheController.inst;
    final textTheme = context.textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Row(
            children: [
              const Icon(
                Broken.document_download,
              ),
              const SizedBox(
                width: 12.0,
              ),
              Expanded(
                child: ObxO(
                  rx: controller.tasks,
                  builder: (context, tasks) => Text(
                    '${lang.cache} (${tasks.length.formatDecimal()})',
                    style: textTheme.displayLarge,
                  ),
                ),
              ),
              ObxO(
                rx: controller.isPaused,
                builder: (context, isPaused) => NamidaIconButton(
                  icon: isPaused ? Broken.play : Broken.pause,
                  tooltip: () => isPaused ? lang.resume : lang.pause,
                  onPressed: isPaused ? controller.resume : controller.pause,
                ),
              ),
              NamidaIconButton(
                icon: Broken.close_circle,
                tooltip: () => lang.cancel,
                onPressed: () {
                  controller.cancelAll();
                  context.safePop();
                },
              ),
            ],
          ),
        ),
        const SizedBox(
          height: 8.0,
        ),
        ObxO(
          rx: YoutubeController.inst.activeRawDownloadsCount,
          builder: (context, youtubeCount) => youtubeCount > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: CustomListTile(
                    icon: Broken.video_square,
                    title: '${lang.youtube} - ${lang.downloads}',
                    trailingText: youtubeCount.formatDecimal(),
                    onTap: () {
                      context.safePop();
                      DownloadsAppBarIcon._openYoutubeDownloads();
                    },
                  ),
                )
              : const SizedBox(),
        ),
        Expanded(
          child: ObxO(
            rx: controller.tasks,
            builder: (context, tasks) {
              final tasksList = tasks.values.toList();
              return NamidaScrollbarWithController(
                child: (sc) => SuperSmoothListView.builder(
                  controller: sc,
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0),
                  itemCount: tasksList.length,
                  itemBuilder: (context, index) {
                    final task = tasksList[index];
                    return _ServerCacheTaskTile(
                      key: ValueKey(task),
                      task: task,
                    );
                  },
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: SizedBox(
            width: double.infinity,
            child: NamidaButton(
              minHeight: NamidaButton.kDefaultMinHeight * 1.25,
              text: lang.done,
              onTap: () => context.safePop(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ServerCacheTaskTile extends StatelessWidget {
  final ServerCacheTask task;

  const _ServerCacheTaskTile({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    final controller = ServerCacheController.inst;
    final textTheme = context.textTheme;
    final track = task.track;
    final totalSize = track.size;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          ArtworkWidget(
            key: Key(track.pathToImage),
            track: track,
            path: track.pathToImage,
            thumbnailSize: 42.0,
            forceSquared: true,
          ),
          const SizedBox(
            width: 12.0,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: textTheme.displayMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                ObxO(
                  rx: task.state,
                  builder: (context, state) => state == ServerCacheTaskState.failed
                      ? Text(
                          lang.failed,
                          style: textTheme.displaySmall,
                        )
                      : ObxO(
                          rx: task.downloadedBytes,
                          builder: (context, downloaded) => Text(
                            '${downloaded.fileSizeFormatted} / ${totalSize.fileSizeFormatted}',
                            style: textTheme.displaySmall,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 8.0,
          ),
          _ServerCacheTaskRing(
            task: task,
            size: 18.0,
            color: context.theme.colorScheme.secondary,
          ),
          ObxO(
            rx: task.state,
            builder: (context, state) => state == ServerCacheTaskState.failed
                ? NamidaIconButton(
                    icon: Broken.refresh,
                    tooltip: () => lang.resume,
                    onPressed: () => controller.retry(task),
                  )
                : const SizedBox(
                    width: 8.0,
                  ),
          ),
          NamidaIconButton(
            horizontalPadding: 0.0,
            icon: Broken.close_circle,
            tooltip: () => lang.cancel,
            onPressed: () => controller.cancel(task),
          ),
        ],
      ),
    );
  }
}
