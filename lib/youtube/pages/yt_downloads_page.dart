import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';
import 'package:namida/youtube/controller/parallel_downloads_controller.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_ongoing_finished_downloads.dart';
import 'package:namida/youtube/widgets/yt_download_task_item_card.dart';

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
        final enabled = isOnGoing == YTOnGoingFinishedDownloads.inst.isOnGoingSelected.value;
        final color = enabled ? Colors.white.withOpacity(0.7) : null;
        return NamidaInkWell(
          bgColor: enabled ? CurrentColor.inst.color : context.theme.cardColor,
          borderRadius: 6.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
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

  Future<bool> _confirmCancelDialog({
    required BuildContext context,
    String operationTitle = '',
    String confirmMessage = '',
    String groupTitle = '',
    required int itemsLength,
  }) async {
    bool confirmed = false;

    final groupTitleText = groupTitle == '' ? lang.DEFAULT : groupTitle;
    await NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.WARNING,
        normalTitleStyle: true,
        isWarning: true,
        actions: [
          const CancelButton(),
          const SizedBox(width: 4.0),
          NamidaButton(
            text: (confirmMessage != '' ? confirmMessage : lang.CONFIRM).toUpperCase(),
            onPressed: () {
              confirmed = true;
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12.0),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: "$operationTitle: ", style: context.textTheme.displayLarge),
                    TextSpan(
                      text: '$groupTitleText ($itemsLength)',
                      style: context.textTheme.displayMedium,
                    ),
                    TextSpan(text: " ?", style: context.textTheme.displayLarge),
                  ],
                ),
              ),
              const SizedBox(height: 12.0),
            ],
          ),
        ),
      ),
    );
    return confirmed;
  }

  void _showParallelDownloadsDialog() {
    final tempCount = YoutubeParallelDownloadsHandler.inst.maxParallelDownloadingItems.obs;
    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        tempCount.close();
      },
      dialog: CustomBlurryDialog(
        title: lang.CONFIGURE,
        normalTitleStyle: true,
        actions: [
          const CancelButton(),
          const SizedBox(width: 4.0),
          NamidaButton(
            text: lang.CONFIRM,
            onPressed: () {
              YoutubeParallelDownloadsHandler.inst.setMaxParalellDownloads(tempCount.value);
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12.0),
            CustomListTile(
              icon: Broken.flash,
              title: lang.PARALLEL_DOWNLOADS,
              trailing: Obx(
                () => NamidaWheelSlider<int>(
                  totalCount: 10,
                  initValue: tempCount.value,
                  onValueChanged: (val) => tempCount.value = val.withMinimum(1),
                  text: tempCount.value.toString(),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
          ],
        ),
      ),
    );
  }

  bool? get _isOnGoingSelected => YTOnGoingFinishedDownloads.inst.isOnGoingSelected.value;
  set _isOnGoingSelected(bool? val) => YTOnGoingFinishedDownloads.inst.isOnGoingSelected.value = val;
  void _updateTempList(bool? forIsGoing) => YTOnGoingFinishedDownloads.inst.updateTempList(forIsGoing);
  void _refreshTempList() => YTOnGoingFinishedDownloads.inst.refreshList();
  RxList<(String, YoutubeItemDownloadConfig)> get _downloadTasksTempList => YTOnGoingFinishedDownloads.inst.youtubeDownloadTasksTempList;

  @override
  Widget build(BuildContext context) {
    _refreshTempList(); // refresh for when coming back to page.

    return BackgroundWrapper(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    children: [
                      _getFilterChip(
                        context: context,
                        title: lang.ALL,
                        icon: Broken.task,
                        onTap: () {
                          _updateTempList(null);
                          _isOnGoingSelected = null;
                        },
                        isOnGoing: null,
                      ),
                      _getFilterChip(
                        context: context,
                        title: lang.ONGOING,
                        icon: Broken.import,
                        onTap: () {
                          _updateTempList(true);
                          _isOnGoingSelected = true;
                        },
                        isOnGoing: true,
                      ),
                      _getFilterChip(
                        context: context,
                        title: lang.FINISHED,
                        icon: Broken.tick_circle,
                        onTap: () {
                          _updateTempList(false);
                          _isOnGoingSelected = false;
                        },
                        isOnGoing: false,
                      ),
                    ],
                  ),
                ),
                // -- still some issues.
                // NamidaIconButton(
                //   icon: null,
                //   tooltip: lang.PARALLEL_DOWNLOADS,
                //   onPressed: _showParallelDownloadsDialog,
                //   child: Obx(
                //     () => StackedIcon(
                //       baseIcon: Broken.flash,
                //       secondaryText: YoutubeParallelDownloadsHandler.inst.maxParallelDownloadingItems.toString(),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
          Obx(
            () => _isOnGoingSelected != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      children: [
                        const SizedBox(width: 24.0),
                        Text(
                          _downloadTasksTempList.length.displayVideoKeyword,
                          style: context.textTheme.displayMedium?.copyWith(fontSize: 20.0.multipliedFontScale),
                        ),
                        if (_isOnGoingSelected == true) ...[
                          const Spacer(),
                          NamidaIconButton(
                            icon: Broken.play,
                            iconSize: 24.0,
                            onPressed: () {
                              _downloadTasksTempList.loop((e, index) {
                                YoutubeController.inst.resumeDownloadTasks(groupName: e.$1, itemsConfig: [e.$2]);
                              });
                            },
                          ),
                          NamidaIconButton(
                            icon: Broken.pause,
                            iconSize: 24.0,
                            onPressed: () {
                              _downloadTasksTempList.loop((e, index) {
                                YoutubeController.inst.pauseDownloadTask(
                                  itemsConfig: [e.$2],
                                  groupName: e.$1,
                                );
                              });
                            },
                          ),
                          NamidaIconButton(
                            icon: Broken.close_circle,
                            iconSize: 24.0,
                            onPressed: () async {
                              final confirmed = await _confirmCancelDialog(
                                context: context,
                                operationTitle: lang.CANCEL,
                                groupTitle: lang.ONGOING,
                                itemsLength: _downloadTasksTempList.length,
                              );
                              if (confirmed) {
                                _downloadTasksTempList.loop((e, index) {
                                  YoutubeController.inst.cancelDownloadTask(
                                    itemsConfig: [e.$2],
                                    groupName: e.$1,
                                  );
                                });
                              }
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
            child: NamidaScrollbar(
              child: Obx(
                () {
                  final keys = YoutubeController.inst.youtubeDownloadTasksMap.keys.toList();
                  keys.sortByReverse((e) => YoutubeController.inst.latestEditedGroupDownloadTask[e] ?? 0);
                  return CustomScrollView(
                    slivers: [
                      _isOnGoingSelected == null
                          ? SliverList.builder(
                              itemCount: keys.length,
                              itemBuilder: (context, index) {
                                final groupName = keys[index];
                                final list = YoutubeController.inst.youtubeDownloadTasksMap[groupName]?.values.toList() ?? [];
                                final lastEditedMSSE = YoutubeController.inst.latestEditedGroupDownloadTask[groupName] ?? 0;
                                final lastEditedAgo = lastEditedMSSE == 0 ? null : Jiffy.parseFromMillisecondsSinceEpoch(lastEditedMSSE).fromNow();

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
                                  child: NamidaExpansionTile(
                                    initiallyExpanded: true,
                                    titleText: groupName == '' ? lang.DEFAULT : groupName,
                                    subtitleText: lastEditedAgo,
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
                                        IconButton.filledTonal(
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () async {
                                            final confirmed = await _confirmCancelDialog(
                                              context: context,
                                              operationTitle: lang.CANCEL,
                                              confirmMessage: lang.REMOVE,
                                              groupTitle: groupName,
                                              itemsLength: list.length,
                                            );
                                            if (confirmed) {
                                              YoutubeController.inst.cancelDownloadTask(
                                                itemsConfig: [],
                                                groupName: groupName,
                                                allInGroupName: true,
                                              );
                                            }
                                          },
                                          icon: const Icon(Broken.close_circle, size: 18.0),
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
                                    children: List<YTDownloadTaskItemCard>.generate(
                                      list.length,
                                      (index) => YTDownloadTaskItemCard(videos: list, index: index, groupName: groupName),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Obx(
                              () => SliverList.builder(
                                itemCount: _downloadTasksTempList.length,
                                itemBuilder: (context, index) {
                                  final groupNameAndItem = _downloadTasksTempList[index];
                                  return YTDownloadTaskItemCard(
                                    videos: _downloadTasksTempList.map((e) => e.$2).toList(),
                                    index: index,
                                    groupName: groupNameAndItem.$1,
                                  );
                                },
                              ),
                            ),
                      kBottomPaddingWidgetSliver,
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
