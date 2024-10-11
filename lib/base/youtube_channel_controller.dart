import 'package:flutter/material.dart';

import 'package:youtipie/class/channels/channel_page_result.dart';
import 'package:youtipie/class/channels/channel_tab_result.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/youtube_streams_manager.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';

abstract class YoutubeChannelController<T extends StatefulWidget> extends State<T> with YoutubeStreamsManager<YoutiPieChannelTabResult> {
  /// Mainly used for initial fetching of cached info.
  String? get channelID;

  @override
  List<StreamInfoItem>? get streamsList => channelVideoTab?.items.cast();

  @override
  YoutiPieChannelTabResult? get listWrapper => channelVideoTab;

  @override
  Color? get sortChipBGColor => CurrentColor.inst.color;

  @override
  void onSortChanged(void Function() fn) => refreshState(fn);

  @override
  void onListChange(void Function() fn) => refreshState(fn);

  @override
  bool canRefreshList(YoutiPieChannelTabResult result) => result.channelId == channel?.channelID;

  YoutubeSubscription? channel;
  YoutiPieChannelTabResult? channelVideoTab;
  ({DateTime oldest, DateTime newest})? streamsPeakDates;

  bool isLoadingInitialStreams = true;

  @override
  void initState() {
    final channelID = this.channelID;
    if (channelID != null) {
      final cachedChannelInfoV = YoutubeInfoController.channel.fetchChannelInfoSync(channelID)?.tabs.getVideosTab();
      if (cachedChannelInfoV != null) {
        final tabResultCache = YoutubeInfoController.channel.fetchChannelTabSync(channelId: channelID, tab: cachedChannelInfoV);
        if (tabResultCache != null) {
          channelVideoTab = tabResultCache;
          isLoadingInitialStreams = false;
          final st = tabResultCache.items;
          updatePeakDates(st.cast());
        }
      }
    }

    super.initState();
  }

  @override
  void dispose() {
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
    YoutiPieChannelTabResult? newResult;
    final channelID = channelPage.id;

    if (tab != null) {
      final details = forceRequest ? ExecuteDetails.forceRequest() : null;
      newResult = await YoutubeInfoController.channel.fetchChannelTab(channelId: channelID, tab: tab, details: details);
      if (newResult != null) {
        // -- would have prevented re-assigning if first video was the same, it would help check any deleted videos too
        // -- but data like viewsCount will not be updated sadly.

        final st = newResult.items;
        updatePeakDates(st.cast());
        YoutubeSubscriptionsController.inst.refreshLastFetchedTime(channelID);
      }
    }

    if (channelID == channel?.channelID) {
      refreshState(() {
        isLoadingInitialStreams = false;
        if (newResult != null) {
          this.channelVideoTab = newResult;
          trySortStreams();
        }
      });
    }
  }
}
