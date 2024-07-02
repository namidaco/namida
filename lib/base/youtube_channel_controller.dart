import 'package:flutter/material.dart';
import 'package:youtipie/class/channels/channel_page_result.dart';
import 'package:youtipie/class/channels/tabs/channel_tab_videos_result.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/youtube_streams_manager.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';

abstract class YoutubeChannelController<T extends StatefulWidget> extends State<T> with YoutubeStreamsManager {
  @override
  List<StreamInfoItem>? get streamsList => channelVideoTab?.items;

  @override
  ScrollController get scrollController => uploadsScrollController;

  @override
  Color? get sortChipBGColor => CurrentColor.inst.color;

  @override
  void onSortChanged(void Function() fn) => refreshState(fn);

  late final ScrollController uploadsScrollController = ScrollController();
  YoutubeSubscription? channel;
  YoutiPieChannelTabVideosResult? channelVideoTab;
  ({DateTime oldest, DateTime newest})? streamsPeakDates;

  bool isLoadingInitialStreams = true;
  final isLoadingMoreUploads = false.obs;
  final lastLoadingMoreWasEmpty = false.obs;

  @override
  void dispose() {
    uploadsScrollController.dispose();
    isLoadingMoreUploads.close();
    lastLoadingMoreWasEmpty.close();
    disposeResources();
    super.dispose();
  }

  /// TODO(youtipie): this is not really accurate
  void updatePeakDates(List<StreamInfoItem> streams) {
    int oldest = (streamsPeakDates?.oldest ?? DateTime.now()).millisecondsSinceEpoch;
    int newest = (streamsPeakDates?.newest ?? DateTime(0)).millisecondsSinceEpoch;
    streams.loop((e) {
      final d = e.publishedAt.date;
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

  Future<void> fetchChannelStreams(YoutiPieChannelPageResult channelPage, {bool forceRequest = false}) async {
    final tab = channelPage.tabs.getVideosTab();
    if (tab == null) return;
    final channelID = channelPage.id;
    final details = forceRequest ? ExecuteDetails.forceRequest() : null;
    final result = await YoutubeInfoController.channel.fetchChannelTab(channelId: channelID, tab: tab, details: details);
    if (result == null) return;

    final st = result.items;
    updatePeakDates(st);
    YoutubeSubscriptionsController.inst.refreshLastFetchedTime(channelID);
    refreshState(() {
      this.channelVideoTab = result;
      isLoadingInitialStreams = false;
      if (channelID == channel?.channelID) {
        trySortStreams();
      }
    });
  }

  Future<void> fetchStreamsNextPage() async {
    if (isLoadingMoreUploads.value) return;
    if (lastLoadingMoreWasEmpty.value) return;

    final result = this.channelVideoTab;
    if (result == null) return;

    isLoadingMoreUploads.value = true;
    final didFetch = await result.fetchNext();
    isLoadingMoreUploads.value = false;

    if (didFetch) {
      if (result.channelId == channel?.channelID) {
        refreshState(trySortStreams);
      }
    } else {
      if (ConnectivityController.inst.hasConnection) lastLoadingMoreWasEmpty.value = true;
      return;
    }
  }
}
