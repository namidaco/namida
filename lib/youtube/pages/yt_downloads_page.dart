import 'package:flutter/material.dart';
import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:get/get.dart';

import 'package:namida/core/dimensions.dart';
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
