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
  List<StreamInfoItem>? get streamsList => channelVideoTab?.items.cast<StreamInfoItem>();

  @override
  YoutiPieChannelTabResult? get listWrapper => channelVideoTab;

  @override
  Color? get sortChipBGColor => CurrentColor.inst.color.withOpacityExt(0.5);

  @override
  YTStreamsNaturalOrder get streamsNaturalOrder {
    final sorts = channelVideoTab?.itemsSort;
    if (sorts == null || sorts.isEmpty) return YTStreamsNaturalOrder.newestFirst; // uploads are served newest first by default

    final current = channelVideoTab?.customSort ?? sorts.firstWhereEff((e) => e.initiallySelected);
    if (current == null) return YTStreamsNaturalOrder.newestFirst;

    // -- youtube orders the chips as [latest, popular, oldest], titles are localized so the index is what can be matched.
    final index = sorts.indexWhere((e) => e.token == current.token || e.title == current.title);
    return switch (index) {
      0 => YTStreamsNaturalOrder.newestFirst,
      2 => YTStreamsNaturalOrder.oldestFirst,
      _ => YTStreamsNaturalOrder.unknown,
    };
  }

  @override
  void onServerSortLoadingChange(bool isLoading) {
    refreshState(
      () {
        isLoadingInitialStreams = isLoading;
        if (isLoading) {
          streamsPeakDates = null; // the list is fully replaced, old peaks dont belong to it anymore
        } else {
          final items = channelVideoTab?.items;
          if (items != null) updatePeakDates(items.cast());
        }
      },
    );
  }

  @override
  void onSortChanged(void Function() fn) => refreshState(fn);

  @override
  void onListChange(void Function() fn) => refreshState(fn);

  @override
  bool canRefreshList(YoutiPieChannelTabResult result) => result.channelId == channel?.channelID;

  YoutubeSubscription? channel;
  YoutiPieChannelTabResult? channelVideoTab;
  ({DateTime oldest, DateTime newest, bool oldestIsApproximate})? streamsPeakDates;

  bool isLoadingInitialStreams = true;

  late final Future<void> cachedStreamsLoad;

  @override
  void initState() {
    super.initState();
    cachedStreamsLoad = _initValues();
  }

  @override
  void dispose() {
    isLoadingMoreUploads.close();
    disposeResources();
    super.dispose();
  }

  Future<void> _initValues() async {
    final channelID = this.channelID;
    if (channelID != null) {
      final cachedChannelInfo = await YoutubeInfoController.channel.fetchChannelInfoCache(channelID);
      final cachedChannelInfoV = cachedChannelInfo?.tabs.getVideosTab();
      if (cachedChannelInfoV != null) {
        final tabResultCache = await YoutubeInfoController.channel.fetchChannelTabCache(channelId: channelID, tab: cachedChannelInfoV);
        if (tabResultCache != null) {
          refreshState(
            () {
              channelVideoTab = tabResultCache;
              isLoadingInitialStreams = false;
              final st = tabResultCache.items;
              updatePeakDates(st.cast());
            },
          );
        }
      }
    }
  }

  /// Dates are parsed out of `x ago` texts, [oldestIsApproximate] tells if the oldest one is a guess.
  void updatePeakDates(List<StreamInfoItem> streams) {
    final current = streamsPeakDates;
    int? oldest = current?.oldest.millisecondsSinceEpoch;
    int? newest = current?.newest.millisecondsSinceEpoch;
    bool oldestIsApproximate = current?.oldestIsApproximate ?? false;

    for (final e in streams) {
      final publishedAt = e.publishedAt;
      final ms = publishedAt.date?.millisecondsSinceEpoch;
      if (ms == null) continue;
      if (oldest == null || ms < oldest) {
        oldest = ms;
        oldestIsApproximate = publishedAt.accurateDate == null;
      }
      if (newest == null || ms > newest) newest = ms;
    }

    if (oldest == null || newest == null) return;
    streamsPeakDates = (
      oldest: DateTime.fromMillisecondsSinceEpoch(oldest),
      newest: DateTime.fromMillisecondsSinceEpoch(newest),
      oldestIsApproximate: oldestIsApproximate,
    );
  }

  void onSuccessFetch() {}

  Future<void> fetchChannelStreams(YoutiPieChannelPageResult channelPage, {bool forceRequest = false}) async {
    final tab = channelPage.tabs.getVideosTab();
    YoutiPieChannelTabResult? newResult;
    final channelID = channelPage.id;

    if (tab != null) {
      final details = forceRequest ? ExecuteDetails.kForceRequest : null;
      final currentTab = channelVideoTab;
      final keepSort = currentTab?.channelId == channelID ? currentTab?.customSort : null; // keep the server sort the user picked
      newResult = await YoutubeInfoController.channel.fetchChannelTab(channelId: channelID, tab: tab, sort: keepSort, details: details);
      if (newResult != null) {
        // -- would have prevented re-assigning if first video was the same, it would help check any deleted videos too
        // -- but data like viewsCount will not be updated sadly.

        final st = newResult.items;
        updatePeakDates(st.cast());
        YoutubeSubscriptionsController.inst.refreshLastFetchedTime(channelID);
        onSuccessFetch();
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
