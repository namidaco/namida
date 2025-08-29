// ignore_for_file: avoid_rx_value_getter_outside_obx

import 'package:flutter/material.dart';

import 'package:super_sliver_list/super_sliver_list.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/download_task_base.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';
import 'package:namida/youtube/controller/parallel_downloads_controller.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_ongoing_finished_downloads.dart';
import 'package:namida/youtube/widgets/yt_download_task_item_card.dart';

class YTDownloadsPage extends StatefulWidget {
  const YTDownloadsPage({super.key});

  @override
  State<YTDownloadsPage> createState() => _YTDownloadsPageState();
}

class _YTDownloadsPageState extends State<YTDownloadsPage> {
  final _hiddenGroupsMap = <DownloadTaskGroupName, bool>{}.obs;

  @override
  void dispose() {
    _hiddenGroupsMap.close();
    super.dispose();
  }

  Widget _getFilterChip({
    required BuildContext context,
    required String title,
    required IconData icon,
    required void Function() onTap,
    required bool? isOnGoing,
  }) {
    return Obx(
      (context) {
        final enabled = isOnGoing == YTOnGoingFinishedDownloads.inst.isOnGoingSelected.valueR;
        final color = enabled ? Colors.white.withValues(alpha: 0.7) : null;
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

  Future<({bool confirmed, bool delete})> _confirmCancelDialog({
    required BuildContext context,
    String operationTitle = '',
    String confirmMessage = '',
    String groupTitle = '',
    required int itemsLength,
  }) async {
    bool confirmed = false;
    bool delete = false;

    final groupTitleText = groupTitle == '' ? lang.DEFAULT : groupTitle;
    await NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.WARNING,
        normalTitleStyle: true,
        isWarning: true,
        actions: [
          NamidaButton(
            text: lang.DELETE.toUpperCase(),
            style: ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(Colors.red),
            ),
            onPressed: () {
              confirmed = true;
              delete = true;
              NamidaNavigator.inst.closeDialog();
            },
          ),
          const SizedBox(width: 4.0),
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
              Text.rich(
                TextSpan(
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
    return (confirmed: confirmed, delete: delete);
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
                (context) {
                  final temp = tempCount.valueR;
                  return NamidaWheelSlider(
                    max: 10,
                    initValue: temp,
                    onValueChanged: (val) => tempCount.value = val.withMinimum(1),
                    text: temp.toString(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12.0),
          ],
        ),
      ),
    );
  }

  bool? get _isOnGoingSelectedR => YTOnGoingFinishedDownloads.inst.isOnGoingSelected.valueR;
  set _isOnGoingSelected(bool? val) => YTOnGoingFinishedDownloads.inst.isOnGoingSelected.value = val;
  void _updateTempList(bool? forIsGoing) => YTOnGoingFinishedDownloads.inst.updateTempList(forIsGoing);
  RxList<(DownloadTaskGroupName, YoutubeItemDownloadConfig)> get _downloadTasksTempList => YTOnGoingFinishedDownloads.inst.youtubeDownloadTasksTempList;

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: ObxO(
        rx: YoutubeController.inst.isLoadingDownloadTasks,
        builder: (context, loadingAllTasks) => loadingAllTasks
            ? Center(
                child: ThreeArchedCircle(
                  color: context.theme.colorScheme.primary.withValues(alpha: 0.5),
                  size: 56.0,
                ),
              )
            : Column(
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
                        //     (context) => StackedIcon(
                        //       baseIcon: Broken.flash,
                        //       secondaryText: YoutubeParallelDownloadsHandler.inst.maxParallelDownloadingItems.toString(),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  Obx(
                    (context) => _isOnGoingSelectedR != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              children: [
                                const SizedBox(width: 24.0),
                                Text(
                                  _downloadTasksTempList.length.displayVideoKeyword,
                                  style: context.textTheme.displayMedium?.copyWith(fontSize: 20.0),
                                ),
                                if (_isOnGoingSelectedR == true) ...[
                                  const Spacer(),
                                  NamidaIconButton(
                                    icon: Broken.play,
                                    iconSize: 24.0,
                                    onPressed: () {
                                      _downloadTasksTempList.loop((e) {
                                        YoutubeController.inst.resumeDownloadTasks(groupName: e.$1, itemsConfig: [e.$2]);
                                      });
                                    },
                                  ),
                                  NamidaIconButton(
                                    icon: Broken.pause,
                                    iconSize: 24.0,
                                    onPressed: () {
                                      _downloadTasksTempList.loop((e) {
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
                                      final confirmation = await _confirmCancelDialog(
                                        context: context,
                                        operationTitle: lang.CANCEL,
                                        groupTitle: lang.ONGOING,
                                        itemsLength: _downloadTasksTempList.length,
                                      );
                                      if (confirmation.confirmed) {
                                        _downloadTasksTempList.loop((e) {
                                          YoutubeController.inst.cancelDownloadTask(
                                            itemsConfig: [e.$2],
                                            groupName: e.$1,
                                            delete: confirmation.delete,
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
                    child: NamidaScrollbarWithController(
                      child: (sc) => Obx(
                        (context) {
                          final keys = YoutubeController.inst.youtubeDownloadTasksMap.keys.toList();
                          keys.sortByReverse((e) => YoutubeController.inst.latestEditedGroupDownloadTask[e] ?? 0);
                          return CustomScrollView(
                            controller: sc,
                            slivers: [
                              if (_isOnGoingSelectedR == null)
                                ...keys.mapIndexed(
                                  (groupName, index) {
                                    final list = YoutubeController.inst.youtubeDownloadTasksMap[groupName]?.values.toList() ?? [];
                                    final lastEditedMSSE = YoutubeController.inst.latestEditedGroupDownloadTask[groupName] ?? 0;
                                    final lastEditedAgo = lastEditedMSSE == 0 ? null : TimeAgoController.dateMSSEFromNow(lastEditedMSSE);

                                    final headerWidget = LayoutWidthProvider(
                                      builder: (context, maxWidth) => NamidaInkWell(
                                        borderRadius: 0.0,
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        bgColor: context.theme.scaffoldBackgroundColor,
                                        onTap: () {
                                          _hiddenGroupsMap.value[groupName] = _hiddenGroupsMap.value[groupName] == true ? false : true;
                                          _hiddenGroupsMap.refresh();
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(width: 12.0),
                                            NamidaInkWell(
                                              width: maxWidth * 0.12,
                                              borderRadius: 8.0,
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                                              bgColor: context.theme.cardColor,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  "${list.length}",
                                                  style: context.textTheme.displayLarge,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12.0),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    groupName.groupName == '' ? lang.DEFAULT : groupName.groupName,
                                                    style: context.textTheme.displayMedium,
                                                  ),
                                                  if (lastEditedAgo != null)
                                                    Text(
                                                      lastEditedAgo,
                                                      style: context.textTheme.displaySmall,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: 4.0),
                                            IconButton.filledTonal(
                                              padding: EdgeInsets.zero,
                                              visualDensity: VisualDensity.compact,
                                              style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                              onPressed: () {
                                                YoutubeController.inst.resumeDownloadTasks(groupName: groupName);
                                              },
                                              icon: const Icon(Broken.play, size: 18.0),
                                            ),
                                            SizedBox(width: 4.0),
                                            IconButton.filledTonal(
                                              padding: EdgeInsets.zero,
                                              visualDensity: VisualDensity.compact,
                                              style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                              onPressed: () {
                                                YoutubeController.inst.pauseDownloadTask(
                                                  itemsConfig: [],
                                                  groupName: groupName,
                                                  allInGroupName: true,
                                                );
                                              },
                                              icon: const Icon(Broken.pause, size: 18.0),
                                            ),
                                            SizedBox(width: 4.0),
                                            IconButton.filledTonal(
                                              padding: EdgeInsets.zero,
                                              visualDensity: VisualDensity.compact,
                                              style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                              onPressed: () async {
                                                final confirmation = await _confirmCancelDialog(
                                                  context: context,
                                                  operationTitle: lang.CANCEL,
                                                  confirmMessage: lang.REMOVE,
                                                  groupTitle: groupName.groupName,
                                                  itemsLength: list.length,
                                                );
                                                if (confirmation.confirmed) {
                                                  YoutubeController.inst.cancelDownloadTask(
                                                    itemsConfig: [],
                                                    groupName: groupName,
                                                    allInGroupName: true,
                                                    delete: confirmation.delete,
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
                                            const SizedBox(width: 12.0),
                                          ],
                                        ),
                                      ),
                                    );

                                    final listSliver = ObxO(
                                      rx: _hiddenGroupsMap,
                                      builder: (context, hiddenGroups) => hiddenGroups[groupName] == true
                                          ? const SliverToBoxAdapter()
                                          : SliverPadding(
                                              padding: const EdgeInsets.only(bottom: 8.0, top: 2.0),
                                              sliver: SuperSliverList.builder(
                                                itemCount: list.length,
                                                itemBuilder: (context, index) {
                                                  return YTDownloadTaskItemCard(
                                                    videos: list,
                                                    index: index,
                                                    groupName: groupName,
                                                  );
                                                },
                                              ),
                                            ),
                                    );

                                    return SliverMainAxisGroup(
                                      slivers: [
                                        PinnedHeaderSliver(
                                          child: headerWidget,
                                        ),
                                        listSliver,
                                      ],
                                    );
                                  },
                                )
                              else
                                ObxO(
                                  rx: _downloadTasksTempList,
                                  builder: (context, downloadTasksTempList) {
                                    final videos = downloadTasksTempList.map((e) => e.$2).toList();
                                    return SuperSliverList.builder(
                                      itemCount: downloadTasksTempList.length,
                                      itemBuilder: (context, index) {
                                        final groupNameAndItem = downloadTasksTempList[index];
                                        return YTDownloadTaskItemCard(
                                          videos: videos,
                                          index: index,
                                          groupName: groupNameAndItem.$1,
                                        );
                                      },
                                    );
                                  },
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
      ),
    );
  }
}
