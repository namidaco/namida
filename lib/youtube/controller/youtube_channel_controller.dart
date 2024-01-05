import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';

enum VideosSorting {
  date,
  views,
  duration,
}

mixin YoutubeChannelController<T extends StatefulWidget> on State<T> {
  late final ScrollController uploadsScrollController = ScrollController();
  YoutubeSubscription? channel;
  final streamsList = <StreamInfoItem>[];
  ({DateTime oldest, DateTime newest})? streamsPeakDates;

  late final _defaultSorting = VideosSorting.date;
  late final _defaultSortingByTop = true;
  late final sorting = _defaultSorting.obs;
  late final sortingByTop = _defaultSortingByTop.obs;

  bool isLoadingInitialStreams = true;
  final isLoadingMoreUploads = false.obs;
  final lastLoadingMoreWasEmpty = false.obs;

  late final sortWidget = SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Obx(
      () => Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ...VideosSorting.values.map(
            (e) {
              final details = sortToTextAndIcon(e);
              final enabled = sorting.value == e;
              final itemsColor = enabled ? Colors.white.withOpacity(0.8) : null;
              return NamidaInkWell(
                animationDurationMS: 200,
                borderRadius: 6.0,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                margin: const EdgeInsets.symmetric(horizontal: 3.0),
                bgColor: enabled ? CurrentColor.inst.color : context.theme.cardColor,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    enabled
                        ? Obx(
                            () => StackedIcon(
                              baseIcon: details.$2,
                              secondaryIcon: sortingByTop.value ? Broken.arrow_down_2 : Broken.arrow_up_3,
                              iconSize: 20.0,
                              secondaryIconSize: 10.0,
                              blurRadius: 4.0,
                              baseIconColor: itemsColor,
                              // secondaryIconColor: enabled ? context.theme.colorScheme.background : null,
                            ),
                          )
                        : Icon(
                            details.$2,
                            size: 20.0,
                            color: null,
                          ),
                    const SizedBox(width: 4.0),
                    Text(
                      details.$1,
                      style: context.textTheme.displayMedium?.copyWith(color: itemsColor),
                    ),
                  ],
                ),
                onTap: () => setState(
                  () => sortStreams(sort: e, sortingByTop: enabled ? !sortingByTop.value : null),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    uploadsScrollController.dispose();
    isLoadingMoreUploads.close();
    lastLoadingMoreWasEmpty.close();
    sorting.close();
    super.dispose();
  }

  void updatePeakDates(List<StreamInfoItem> streams) {
    int oldest = (streamsPeakDates?.oldest ?? DateTime.now()).millisecondsSinceEpoch;
    int newest = (streamsPeakDates?.newest ?? DateTime(0)).millisecondsSinceEpoch;
    streams.loop((e, _) {
      final d = e.date;
      if (d != null) {
        final ms = d.millisecondsSinceEpoch;
        if (ms < oldest) {
          oldest = ms;
        } else if (ms > newest) {
          newest = ms;
        }
      }
    });
    streamsPeakDates = (oldest: DateTime.fromMillisecondsSinceEpoch(oldest), newest: DateTime.fromMillisecondsSinceEpoch(newest));
  }

  Future<void> fetchChannelStreams(YoutubeSubscription sub) async {
    final st = await YoutubeController.inst.getChannelStreams(sub.channelID);
    updatePeakDates(st);
    YoutubeSubscriptionsController.inst.refreshLastFetchedTime(sub.channelID);
    setState(() {
      isLoadingInitialStreams = false;
      if (sub.channelID == channel?.channelID) {
        streamsList.addAll(st);
        trySortStreams();
      }
    });
  }

  Future<void> fetchStreamsNextPage(YoutubeSubscription? sub) async {
    if (isLoadingMoreUploads.value) return;
    if (lastLoadingMoreWasEmpty.value) return;

    isLoadingMoreUploads.value = true;
    final st = await YoutubeController.inst.getChannelStreamsNextPage();
    updatePeakDates(st);
    isLoadingMoreUploads.value = false;
    if (st.isEmpty) {
      if (ConnectivityController.inst.hasConnection) lastLoadingMoreWasEmpty.value = true;
      return;
    }
    if (sub?.channelID == channel?.channelID) {
      setState(() {
        streamsList.addAll(st);
        trySortStreams();
      });
    }
  }

  void trySortStreams() {
    if (sorting.value != _defaultSorting || sortingByTop.value != _defaultSortingByTop) {
      sortStreams(jumpToZero: false);
    }
  }

  void sortStreams({List<StreamInfoItem>? streams, VideosSorting? sort, bool? sortingByTop, bool jumpToZero = true}) {
    sort ??= sorting.value;
    streams ??= streamsList;
    sortingByTop ??= this.sortingByTop.value;
    switch (sort) {
      case VideosSorting.date:
        sortingByTop ? streams.sortByReverse((e) => e.date ?? DateTime(0)) : streams.sortBy((e) => e.date ?? DateTime(0));
        break;

      case VideosSorting.views:
        sortingByTop ? streams.sortByReverse((e) => e.viewCount ?? 0) : streams.sortBy((e) => e.viewCount ?? 0);
        break;

      case VideosSorting.duration:
        sortingByTop ? streams.sortByReverse((e) => e.duration ?? Duration.zero) : streams.sortBy((e) => e.duration ?? Duration.zero);
        break;

      default:
        null;
    }
    sorting.value = sort;
    this.sortingByTop.value = sortingByTop;

    if (jumpToZero && uploadsScrollController.hasClients) uploadsScrollController.jumpTo(0);
  }

  (String, IconData) sortToTextAndIcon(VideosSorting sort) {
    switch (sort) {
      case VideosSorting.date:
        return (lang.DATE, Broken.calendar);
      case VideosSorting.views:
        return (lang.VIEWS, Broken.eye);
      case VideosSorting.duration:
        return (lang.DURATION, Broken.timer_1);
    }
  }
}
