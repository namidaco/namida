import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/base/youtube_streams_manager.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';

abstract class YoutubeChannelController<T extends StatefulWidget> extends State<T> with YoutubeStreamsManager {
  @override
  List<StreamInfoItem> get streamsList => _streamsList;

  @override
  ScrollController get scrollController => uploadsScrollController;

  @override
  Color? get sortChipBGColor => CurrentColor.inst.color;

  @override
  void onSortChanged(void Function() fn) => setState(fn);

  late final ScrollController uploadsScrollController = ScrollController();
  YoutubeSubscription? channel;
  late final _streamsList = <StreamInfoItem>[];
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
}
