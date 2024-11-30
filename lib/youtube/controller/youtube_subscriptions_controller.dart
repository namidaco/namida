import 'dart:io';

import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';

class YoutubeSubscriptionsController {
  static final YoutubeSubscriptionsController inst = YoutubeSubscriptionsController._internal();
  YoutubeSubscriptionsController._internal();

  Iterable<String> get subscribedChannels => _availableChannels.keys.where((key) => _availableChannels[key]?.subscribed == true);

  RxBaseCore<Map<String, YoutubeSubscription>> get availableChannels => _availableChannels;
  final _availableChannels = <String, YoutubeSubscription>{}.obs;

  void setChannel(String channelId, YoutubeSubscription channel) => _availableChannels[channelId] = channel;
  String? idOrUrlToChannelID(String? idOrURL) => idOrURL?.splitLast('/');

  Future<bool> toggleChannelSubscription(String channelIDOrURL) async {
    final channelID = channelIDOrURL.splitLast('/');
    final valInMap = _availableChannels.value[channelID];
    final wasSubscribed = valInMap?.subscribed == true;
    final newSubscribed = !wasSubscribed;

    _availableChannels.value[channelID] = YoutubeSubscription(
      title: valInMap?.title,
      channelID: channelID,
      subscribed: newSubscribed,
      lastFetched: valInMap?.lastFetched,
    );
    _availableChannels.refresh();

    await saveFile();
    return newSubscribed;
  }

  List<String> getGroupsForChannel(String channelId) {
    final sub = availableChannels.value[channelId] ??= YoutubeSubscription(channelID: channelId, subscribed: false);
    return sub.groups;
  }

  Future<void> sortByLastFetched() async {
    _availableChannels.sortBy((e) => e.value.lastFetched ?? DateTime(0));
    await saveFile();
  }

  Future<void> refreshLastFetchedTime(String channelID, {bool saveToStorage = true}) async {
    _availableChannels[channelID]?.lastFetched = DateTime.now();
    if (saveToStorage) await saveFile();
  }

  Future<void> loadSubscriptionsFileAsync() async {
    final file = File(AppPaths.YT_SUBSCRIPTIONS);
    if (!file.existsSync()) return;
    final res = await _parseSubscriptionsFile.thready(file);
    _availableChannels.value = res;
  }

  static Map<String, YoutubeSubscription> _parseSubscriptionsFile(File file) {
    final res = file.readAsJsonSync() as Map?;
    return (res?.cast<String, Map>())?.map(
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
