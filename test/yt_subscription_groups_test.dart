import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';

void main() {
  late Directory root;
  final controller = YoutubeSubscriptionsController.inst;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('namida_yt_groups_test');
    AppDirs.USER_DATA = '${p.join(root.path, 'user_data')}${Platform.pathSeparator}';
    AppDirs.INTERNAL_STORAGE = root.path;
    Directory(AppDirs.YOUTUBE_MAIN_DIRECTORY).createSync(recursive: true);
    File(AppPaths.YT_SUBSCRIPTIONS).writeAsJsonSync({
      'a': {'title': 'A', 'channelID': 'a', 'subscribed': true, 'groups': ['g1'], 'lastFetched': 1000},
      'b': {'title': 'B', 'channelID': 'b', 'subscribed': false, 'lastFetched': 2000},
    });
    File(AppPaths.YT_SUBSCRIPTIONS_GROUPS_ALL).writeAsJsonSync(['g1', 'g2']);
    await controller.loadSubscriptionsFileAsync();
  });

  tearDownAll(() => root.deleteSync(recursive: true));

  test('loads groups into memory', () {
    expect(controller.allGroups.value, ['g1', 'g2']);
  });

  test('favourite toggle keeps groups', () async {
    await controller.toggleChannelSubscription('a');
    expect(controller.availableChannels.value['a']?.subscribed, false);
    expect(controller.availableChannels.value['a']?.groups, ['g1']);
    await controller.toggleChannelSubscription('a');
    expect(controller.availableChannels.value['a']?.groups, ['g1']);
  });

  test('group toggle on an unknown channel adds it without favouriting', () {
    controller.toggleChannelGroup('c', 'g2', title: 'C');
    final sub = controller.availableChannels.value['c'];
    expect(sub?.subscribed, isNot(true));
    expect(sub?.groups, ['g2']);
    expect(sub?.title, 'C');

    controller.toggleChannelGroup('c', 'g1');
    expect(controller.availableChannels.value['c']?.groups, ['g2', 'g1']);

    controller.toggleChannelGroup('c', 'g2');
    expect(controller.availableChannels.value['c']?.groups, ['g1']);
    expect(controller.availableChannels.value['c']?.subscribed, isNot(true));
    expect(controller.availableChannels.value['c']?.title, 'C');
  });

  test('group toggle keeps the favourite state', () {
    controller.toggleChannelGroup('b', 'g2');
    expect(controller.availableChannels.value['b']?.subscribed, false);
    controller.toggleChannelGroup('a', 'g2');
    expect(controller.availableChannels.value['a']?.subscribed, true);
    controller.toggleChannelGroup('b', 'g2');
    controller.toggleChannelGroup('a', 'g2');
    expect(controller.availableChannels.value['b']?.groups, isEmpty);
    expect(controller.availableChannels.value['a']?.groups, ['g1']);
  });

  test('filter and counts include non favourites', () async {
    expect(controller.channelsInGroup('g1').toSet(), {'a', 'c'});
    expect(controller.getGroupsCounts(), {'g1': 2});

    await controller.toggleChannelSubscription('a');
    expect(controller.channelsInGroup('g1').toSet(), {'a', 'c'});
    expect(controller.getGroupsCounts(), {'g1': 2});
    await controller.toggleChannelSubscription('a');
  });

  test('create, rename and remove update channels and files', () async {
    await controller.createGroup('g3');
    await controller.createGroup('g3');
    expect(controller.allGroups.value, ['g1', 'g2', 'g3']);

    await controller.renameGroup('g1', 'g2');
    expect(controller.allGroups.value, ['g1', 'g2', 'g3']);

    await controller.renameGroup('g1', 'renamed');
    expect(controller.allGroups.value, ['renamed', 'g2', 'g3']);
    expect(controller.availableChannels.value['a']?.groups, ['renamed']);
    expect(controller.availableChannels.value['c']?.groups, ['renamed']);
    expect(File(AppPaths.YT_SUBSCRIPTIONS_GROUPS_ALL).readAsJsonSync(), ['renamed', 'g2', 'g3']);
    final savedSubs = File(AppPaths.YT_SUBSCRIPTIONS).readAsJsonSync() as Map;
    expect(savedSubs['a']['groups'], ['renamed']);

    await controller.removeGroup('renamed');
    expect(controller.allGroups.value, ['g2', 'g3']);
    expect(controller.availableChannels.value['a']?.groups, isEmpty);
    expect(controller.availableChannels.value['c']?.groups, isEmpty);
  });

  test('imported groups reach memory and file', () async {
    await controller.importGroups(['g3', 'g4', 'g4']);
    expect(controller.allGroups.value, ['g2', 'g3', 'g4']);
    expect(await controller.readAllGroups(), ['g2', 'g3', 'g4']);
    expect(File(AppPaths.YT_SUBSCRIPTIONS_GROUPS_ALL).readAsJsonSync(), ['g2', 'g3', 'g4']);
  });
}
