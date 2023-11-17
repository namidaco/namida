import 'package:flutter/material.dart';
import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:get/get.dart';

import 'package:namida/core/dimensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/widgets/yt_download_task_item_card.dart';

class YTDownloadsPage extends StatelessWidget {
  const YTDownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Obx(() {
        final keys = YoutubeController.inst.youtubeDownloadTasksMap.keys.toList();
        return CupertinoScrollbar(
          child: CustomScrollView(
            slivers: [
              SliverList.builder(
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
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: kBottomPadding)),
            ],
          ),
        );
      }),
    );
  }
}
