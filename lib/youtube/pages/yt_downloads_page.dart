import 'package:flutter/material.dart';
import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/widgets/yt_download_task_item_card.dart';

final _isOnGoingSelected = Rxn<bool>();

class YTDownloadsPage extends StatelessWidget {
  const YTDownloadsPage({super.key});

  Widget _getFilterChip({
    required BuildContext context,
    required String title,
    required IconData icon,
    required void Function() onTap,
    required bool? isOnGoing,
  }) {
    return Obx(
      () {
        final enabled = isOnGoing == _isOnGoingSelected.value;
        final color = enabled ? Colors.white.withOpacity(0.7) : null;
        return NamidaInkWell(
          bgColor: enabled ? CurrentColor.inst.color : context.theme.cardColor,
          borderRadius: 6.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          animationDurationMS: 300,
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18.0, color: color),
              const SizedBox(width: 4.0),
              Text(
                title,
                style: context.textTheme.displayMedium?.copyWith(color: color),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateTempList(bool? forIsGoing) {
    final itemsList = YoutubeController.inst.youtubeDownloadTasksTempList;
    itemsList.clear();
    if (forIsGoing == null) return;

    // -- separate same functions bcz dont wanna check in each loop.
    // -- reverseLoop to insert newer first.
    if (forIsGoing) {
      YoutubeController.inst.youtubeDownloadTasksMap.keys.toList().reverseLoop((key, index) {
        final smallList = YoutubeController.inst.youtubeDownloadTasksMap[key]?.values.toList();
        smallList?.reverseLoop((v, index) {
          final match = YoutubeController.inst.downloadedFilesMap[key]?[v.filename] == null;
          if (match) itemsList.add((key, v));
        });
      });
    } else {
      YoutubeController.inst.youtubeDownloadTasksMap.keys.toList().reverseLoop((key, index) {
        final smallList = YoutubeController.inst.youtubeDownloadTasksMap[key]?.values.toList();
        smallList?.reverseLoop((v, index) {
          final match = YoutubeController.inst.downloadedFilesMap[key]?[v.filename] != null;
          if (match) itemsList.add((key, v));
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Wrap(
              children: [
                _getFilterChip(
                  context: context,
                  title: lang.ALL,
                  icon: Broken.task,
                  onTap: () {
                    _updateTempList(null);
                    _isOnGoingSelected.value = null;
                  },
                  isOnGoing: null,
                ),
                _getFilterChip(
                  context: context,
                  title: lang.ONGOING,
                  icon: Broken.import,
                  onTap: () {
                    _updateTempList(true);
                    _isOnGoingSelected.value = true;
                  },
                  isOnGoing: true,
                ),
                _getFilterChip(
                  context: context,
                  title: lang.FINISHED,
                  icon: Broken.tick_circle,
                  onTap: () {
                    _updateTempList(false);
                    _isOnGoingSelected.value = false;
                  },
                  isOnGoing: false,
                ),
              ],
            ),
          ),
          Obx(
            () => _isOnGoingSelected.value != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      children: [
                        const SizedBox(width: 24.0),
                        Text(
                          YoutubeController.inst.youtubeDownloadTasksTempList.length.displayVideoKeyword,
                          style: context.textTheme.displayMedium?.copyWith(fontSize: 20.0.multipliedFontScale),
                        ),
                        if (_isOnGoingSelected.value == true) ...[
                          const Spacer(),
                          NamidaIconButton(
                            icon: Broken.play,
                            iconSize: 24.0,
                            onPressed: () {
                              YoutubeController.inst.youtubeDownloadTasksTempList.loop((e, index) {
                                YoutubeController.inst.resumeDownloadTasks(groupName: e.$1);
                              });
                            },
                          ),
                          NamidaIconButton(
                            icon: Broken.pause,
                            iconSize: 24.0,
                            onPressed: () {
                              YoutubeController.inst.youtubeDownloadTasksTempList.loop((e, index) {
                                YoutubeController.inst.pauseDownloadTask(
                                  itemsConfig: [],
                                  groupName: e.$1,
                                  allInGroupName: true,
                                );
                              });
                            },
                          ),
                        ],
                        const SizedBox(width: 12.0),
                      ],
                    ),
                  )
                : const SizedBox(),
          ),
          Expanded(
            child: Obx(() {
              final keys = YoutubeController.inst.youtubeDownloadTasksMap.keys.toList();
              return CupertinoScrollbar(
                child: CustomScrollView(
                  slivers: [
                    _isOnGoingSelected.value == null
                        ? SliverList.builder(
                            itemCount: keys.length,
                            itemBuilder: (context, index) {
                              final groupName = keys[index];
                              final list = YoutubeController.inst.youtubeDownloadTasksMap[groupName]?.values.toList() ?? [];
                              return NamidaExpansionTile(
                                initiallyExpanded: true,
                                titleText: groupName,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton.filledTonal(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        YoutubeController.inst.resumeDownloadTasks(groupName: groupName);
                                      },
                                      icon: const Icon(Broken.play, size: 18.0),
                                    ),
                                    IconButton.filledTonal(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        YoutubeController.inst.pauseDownloadTask(
                                          itemsConfig: [],
                                          groupName: groupName,
                                          allInGroupName: true,
                                        );
                                      },
                                      icon: const Icon(Broken.pause, size: 18.0),
                                    ),
                                    const SizedBox(width: 4.0),
                                    const Icon(
                                      Broken.arrow_down_2,
                                      size: 20.0,
                                    ),
                                    const SizedBox(width: 4.0),
                                  ],
                                ),
                                leading: NamidaInkWell(
                                  borderRadius: 8.0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  bgColor: context.theme.cardColor,
                                  child: Text(
                                    "${list.length}",
                                    style: context.textTheme.displayLarge,
                                  ),
                                ),
                                children: list
                                    .asMap()
                                    .keys
                                    .map(
                                      (key) => YTDownloadTaskItemCard(videos: list, index: key, groupName: groupName),
                                    )
                                    .toList(),
                              );
                            },
                          )
                        : SliverList.builder(
                            itemCount: YoutubeController.inst.youtubeDownloadTasksTempList.length,
                            itemBuilder: (context, index) {
                              final groupNameAndItem = YoutubeController.inst.youtubeDownloadTasksTempList[index];
                              return YTDownloadTaskItemCard(
                                videos: YoutubeController.inst.youtubeDownloadTasksTempList.map((e) => e.$2).toList(),
                                index: index,
                                groupName: groupNameAndItem.$1,
                              );
                            },
                          ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: kBottomPadding)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
