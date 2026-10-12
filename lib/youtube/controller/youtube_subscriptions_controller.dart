import 'dart:async';
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
    if (valInMap?.lastFetched == null) _sortByLastFetched();
    _availableChannels.refresh();

    await saveFile();
    return newSubscribed;
  }

  List<String> getGroupsForChannel(String channelId) {
    final sub = availableChannels.value[channelId] ??= YoutubeSubscription(channelID: channelId, subscribed: false);
    return sub.groups;
  }

  Future<void> sortByLastFetched() async {
    _sortByLastFetched();
    _availableChannels.refresh();
    await saveFile();
  }

  void _sortByLastFetched() => _availableChannels.value.sortBy((e) => e.value.lastFetched ?? DateTime(0));

  Future<void> refreshLastFetchedTime(String channelID, {bool saveToStorage = true}) async {
    _availableChannels[channelID]?.lastFetched = DateTime.now();
    if (saveToStorage) await saveFile();
  }

  final _didLoadCompleter = Completer();
  Future<void> loadSubscriptionsFileAsync() async {
    await _loadSubscriptionsFileAsync();
    _didLoadCompleter.completeIfWasnt();
  }

  Future<void> _loadSubscriptionsFileAsync() async {
    final file = File(AppPaths.YT_SUBSCRIPTIONS);
    if (!await file.exists()) return;
    final res = await readSubscriptionsFile(file);
    _availableChannels.value = res;
  }

  Future<Map<String, YoutubeSubscription>> readSubscriptionsFile(File file) => _parseSubscriptionsFile.thready(file);

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
    await _didLoadCompleter.future;
    final file = File(AppPaths.YT_SUBSCRIPTIONS);
    await file.writeAsJson(_availableChannels.map((key, value) => MapEntry(key, value.toJson())));
  }

  Iterable<YoutubeSubscription> buildSyncEntries() => _availableChannels.value.values;

  Future<void> import(Iterable<YoutubeSubscription> incomingChannels) async {
    await _didLoadCompleter.future;
    bool anyChanged = false;
    bool anyAdded = false;
    for (final incoming in incomingChannels) {
      final channelID = incoming.channelID;
      if (channelID.isEmpty) continue;

      final local = _availableChannels.value[channelID];
      if (local == null) {
        _availableChannels.value[channelID] = incoming;
        anyChanged = true;
        anyAdded = true;
        continue;
      }

      final subscribed = local.subscribed == true || incoming.subscribed == true;
      final groups = <String>[...local.groups];
      for (final g in incoming.groups) {
        if (!groups.contains(g)) groups.add(g);
      }

      final changed =
          subscribed != (local.subscribed == true) || //
          groups.length != local.groups.length ||
          (local.title.isEmpty && incoming.title.isNotEmpty);
      if (!changed) continue;

      _availableChannels.value[channelID] = YoutubeSubscription(
        title: local.title.isNotEmpty ? local.title : incoming.title,
        channelID: channelID,
        subscribed: subscribed ? true : local.subscribed,
        groups: groups,
        lastFetched: local.lastFetched,
      );
      anyChanged = true;
    }
    if (anyChanged) {
      if (anyAdded) _sortByLastFetched();
      _availableChannels.refresh();
      await saveFile();
    }
  }

  Future<List<String>> readAllGroups() => readGroupsFile(File(AppPaths.YT_SUBSCRIPTIONS_GROUPS_ALL));

  Future<List<String>> readGroupsFile(File file) async {
    try {
      final list = await file.readAsJson() as List?;
      if (list != null) return list.cast<String>();
    } catch (_) {}
    return [];
  }

  Future<void> importGroups(List<String> incoming) async {
    final current = await readAllGroups();
    bool changed = false;
    for (final group in incoming) {
      if (!current.contains(group)) {
        current.add(group);
        changed = true;
      }
    }
    if (changed) {
      await File(AppPaths.YT_SUBSCRIPTIONS_GROUPS_ALL).writeAsJson(current);
    }
  }
}
