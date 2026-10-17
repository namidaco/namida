import 'dart:async';
import 'dart:io';

import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

class YoutubeSubscriptionsController {
  static final YoutubeSubscriptionsController inst = YoutubeSubscriptionsController._internal();
  YoutubeSubscriptionsController._internal();

  Iterable<String> get subscribedChannels => _availableChannels.keys.where((key) => _availableChannels[key]?.subscribed == true);

  RxBaseCore<Map<String, YoutubeSubscription>> get availableChannels => _availableChannels;
  final _availableChannels = <String, YoutubeSubscription>{}.obs;

  void setChannel(String channelId, YoutubeSubscription channel) => _availableChannels[channelId] = channel;
  String? idOrUrlToChannelID(String? idOrURL) => idOrURL?.splitLast('/');

  /// [title] is kept for channels the map has no title for.
  Future<bool> toggleChannelSubscription(String channelIDOrURL, {String? title}) async {
    final channelID = channelIDOrURL.splitLast('/');
    final valInMap = _availableChannels.value[channelID];
    final wasSubscribed = valInMap?.subscribed == true;
    final newSubscribed = !wasSubscribed;
    final channelTitle = valInMap?.title.nullifyEmpty() ?? title;

    _availableChannels.value[channelID] = YoutubeSubscription(
      title: channelTitle,
      channelID: channelID,
      subscribed: newSubscribed,
      groups: valInMap?.groups ?? const [],
      lastFetched: valInMap?.lastFetched,
    );
    if (valInMap?.lastFetched == null) _sortByLastFetched();
    _availableChannels.refresh();

    await saveFile();
    return newSubscribed;
  }

  RxBaseCore<List<String>> get allGroups => _allGroups;
  final _allGroups = <String>[].obs;

  /// favourite or not, groups are their own lists.
  Iterable<String> channelsInGroup(String group) => _availableChannels.entries.where((e) => e.value.groups.contains(group)).map((e) => e.key);

  Map<String, List<YoutubeSubscription>> getGroupsChannels() {
    final groupsChannels = <String, List<YoutubeSubscription>>{};
    for (final sub in _availableChannels.values) {
      for (final group in sub.groups) {
        groupsChannels.addForce(group, sub);
      }
    }
    return groupsChannels;
  }

  /// channels saved before titles were kept get [title], not saved, call [saveFile] when done editing.
  bool fillMissingTitle(String channelID, String title) {
    final didFill = _fillMissingTitle(channelID, title);
    if (didFill) _availableChannels.refresh();
    return didFill;
  }

  bool _fillMissingTitle(String channelID, String title) {
    final sub = _availableChannels.value[channelID];
    if (sub == null || sub.title.isNotEmpty || title.isEmpty) return false;
    _availableChannels.value[channelID] = sub.copyWith(title: title);
    return true;
  }

  /// grouped channels saved before titles were kept, filled from the channel pages cache.
  Future<void> fillMissingGroupsTitlesFromCache() async {
    final untitledIDs = _availableChannels.value.values.where((e) => e.title.isEmpty && e.groups.isNotEmpty).map((e) => e.channelID).toFixedList();
    if (untitledIDs.isEmpty) return;
    final infos = await Future.wait(untitledIDs.map(YoutubeInfoController.channel.fetchChannelInfoCache));
    bool didFill = false;
    for (int i = 0; i < untitledIDs.length; i++) {
      final title = infos[i]?.title;
      if (title == null) continue;
      if (_fillMissingTitle(untitledIDs[i], title)) didFill = true;
    }
    if (!didFill) return;
    _availableChannels.refresh();
    await saveFile();
  }

  /// not saved, call [saveFile] when done editing. [title] is kept for channels the map has no title for.
  void toggleChannelGroup(String channelID, String group, {String? title}) {
    final valInMap = _availableChannels.value[channelID];
    final groups = valInMap?.groups ?? const <String>[];
    final wasInGroup = groups.contains(group);
    final newGroups = wasInGroup ? groups.where((g) => g != group).toFixedList() : [...groups, group];
    final channelTitle = valInMap?.title.nullifyEmpty() ?? title;
    _availableChannels.value[channelID] = YoutubeSubscription(
      title: channelTitle,
      channelID: channelID,
      subscribed: valInMap?.subscribed,
      groups: newGroups,
      lastFetched: valInMap?.lastFetched,
    );
    if (valInMap == null) _sortByLastFetched();
    _availableChannels.refresh();
  }

  Future<void> createGroup(String group) async {
    if (_allGroups.value.contains(group)) return;
    _allGroups.add(group);
    await _saveGroupsFile();
  }

  Future<void> renameGroup(String oldName, String newName) async {
    final groups = _allGroups.value;
    final index = groups.indexOf(oldName);
    if (index == -1 || groups.contains(newName)) return;
    groups[index] = newName;
    _allGroups.refresh();
    _availableChannels.value.updateAll((_, sub) {
      if (!sub.groups.contains(oldName)) return sub;
      final newGroups = sub.groups.map((g) => g == oldName ? newName : g).toFixedList();
      return sub.copyWith(groups: newGroups);
    });
    _availableChannels.refresh();
    await Future.wait([saveFile(), _saveGroupsFile()]);
  }

  Future<void> removeGroup(String group) async {
    final didRemove = _allGroups.remove(group);
    if (!didRemove) return;
    _availableChannels.value.updateAll((_, sub) {
      if (!sub.groups.contains(group)) return sub;
      final newGroups = sub.groups.where((g) => g != group).toFixedList();
      return sub.copyWith(groups: newGroups);
    });
    _availableChannels.refresh();
    await Future.wait([saveFile(), _saveGroupsFile()]);
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
    await Future.wait([
      _loadSubscriptionsFileAsync(),
      _loadGroupsFileAsync(),
    ]);
    _didLoadCompleter.completeIfWasnt();
  }

  Future<void> _loadGroupsFileAsync() async {
    final file = File(AppPaths.YT_SUBSCRIPTIONS_GROUPS_ALL);
    _allGroups.value = await readGroupsFile(file);
  }

  Future<void> _saveGroupsFile() async {
    await _didLoadCompleter.future;
    final file = File(AppPaths.YT_SUBSCRIPTIONS_GROUPS_ALL);
    await file.writeAsJson(_allGroups.value);
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

  Future<List<String>> readAllGroups() async {
    await _didLoadCompleter.future;
    return _allGroups.value;
  }

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
      _allGroups.refresh();
      await _saveGroupsFile();
    }
  }
}
