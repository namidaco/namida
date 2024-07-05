import 'package:flutter/material.dart';
import 'package:youtipie/class/channels/channel_page_result.dart';
import 'package:youtipie/class/channels/tabs/channel_tab_videos_result.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/youtube_streams_manager.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';

abstract class YoutubeChannelController<T extends StatefulWidget> extends State<T> with YoutubeStreamsManager<YoutiPieChannelTabVideosResult> {
  @override
  List<StreamInfoItem>? get streamsList => channelVideoTab?.items;

  @override
  YoutiPieChannelTabVideosResult? get listWrapper => channelVideoTab;

  @override
  ScrollController get scrollController => uploadsScrollController;

  @override
  Color? get sortChipBGColor => CurrentColor.inst.color;

  @override
  void onSortChanged(void Function() fn) => refreshState(fn);

  @override
  void onListChange(void Function() fn) => refreshState(fn);

  @override
  bool canRefreshList(YoutiPieChannelTabVideosResult result) => result.channelId == channel?.channelID;

  late final ScrollController uploadsScrollController = ScrollController();
  YoutubeSubscription? channel;
  YoutiPieChannelTabVideosResult? channelVideoTab;
  ({DateTime oldest, DateTime newest})? streamsPeakDates;

  bool isLoadingInitialStreams = true;

  @override
  void dispose() {
    uploadsScrollController.dispose();
    isLoadingMoreUploads.close();
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
    YoutiPieChannelTabVideosResult? newResult;
    final channelID = channelPage.id;

    if (tab != null) {
      final details = forceRequest ? ExecuteDetails.forceRequest() : null;
      newResult = await YoutubeInfoController.channel.fetchChannelTab(channelId: channelID, tab: tab, details: details);
      if (newResult != null) {
        // -- would have prevented re-assigning if first video was the same, it would help check any deleted videos too
        // -- but data like viewsCount will not be updated sadly.

        final st = newResult.items;
        updatePeakDates(st);
        YoutubeSubscriptionsController.inst.refreshLastFetchedTime(channelID);
      }
    }

    refreshState(() {
      this.channelVideoTab = newResult;
      isLoadingInitialStreams = false;
      if (newResult != null && channelID == channel?.channelID) {
        trySortStreams();
      }
    });
  }
}
