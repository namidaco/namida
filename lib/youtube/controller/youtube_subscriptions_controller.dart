import 'dart:io';

import 'package:get/get.dart';

import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';

class YoutubeSubscriptionsController {
  static final YoutubeSubscriptionsController inst = YoutubeSubscriptionsController._internal();
  YoutubeSubscriptionsController._internal();

  Iterable<String> get subscribedChannels => _availableChannels.keys.where((key) => _availableChannels[key]?.subscribed == true);
  final _availableChannels = <String, YoutubeSubscription>{}.obs;

  YoutubeSubscription? getChannel(String channelId) => _availableChannels[channelId];
  void setChannel(String channelId, YoutubeSubscription channel) => _availableChannels[channelId] = channel;
  String? idOrUrlToChannelID(String? idOrURL) => idOrURL?.split('/').last;

  /// Updates a channel subscription status, use null to toggle.
  Future<void> changeChannelStatus(String channelIDOrURL, {bool? subscribe}) async {
    final channelID = channelIDOrURL.split('/').last;
    final valInMap = _availableChannels[channelID];
    final newSubscribed = subscribe ?? !(valInMap?.subscribed ?? false);
    _availableChannels[channelID] = YoutubeSubscription(
      title: valInMap?.title,
      channelID: channelID,
      subscribed: newSubscribed,
      lastFetched: valInMap?.lastFetched,
    );
    await saveFile();
  }

  Future<void> sortByLastFetched() async {
    _availableChannels.sortBy((e) => e.value.lastFetched ?? DateTime(0));
    await saveFile();
  }

  Future<void> refreshLastFetchedTime(String channelID, {bool saveToStorage = true}) async {
    _availableChannels[channelID]?.lastFetched = DateTime.now();
    if (saveToStorage) await saveFile();
  }

  Future<void> loadSubscriptionsFile() async {
    final file = File(AppPaths.YT_SUBSCRIPTIONS);
    if (!await file.exists()) return;

    final res = await file.readAsJson() as Map?;

    _availableChannels.value = (res?.cast<String, Map>())?.map(
          (key, value) => MapEntry(
            key,
            YoutubeSubscription.fromJson(
              value.cast<String, dynamic>(),
            ),
          ),
        ) ??
        {};
  }

  Future<void> saveFile() async {
    final file = File(AppPaths.YT_SUBSCRIPTIONS);
    await file.writeAsJson(_availableChannels.map((key, value) => MapEntry(key, value.toJson())));
  }
}
