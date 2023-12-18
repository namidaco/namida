import 'dart:io';

import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';

class YoutubeImportController {
  Future<int> importSubscriptions(String subscriptionsFilePath) async {
    final res = await _parseSubscriptions.thready(subscriptionsFilePath);
    res.loop((e, index) {
      final valInMap = YoutubeSubscriptionsController.inst.subscribedChannels[e.id];
      YoutubeSubscriptionsController.inst.subscribedChannels[e.id] = YoutubeSubscription(
        title: valInMap != null && valInMap.title == '' ? e.title : valInMap?.title,
        channelID: e.id,
        subscribed: true,
        lastFetched: valInMap?.lastFetched,
      );
    });
    YoutubeSubscriptionsController.inst.sortByLastFetched();
    await YoutubeSubscriptionsController.inst.saveFile();
    return res.length;
  }

  static List<({String id, String title})> _parseSubscriptions(String filePath) {
    final file = File(filePath);
    try {
      final lines = file.readAsLinesSync();
      lines.removeAt(0);
      final list = <({String id, String title})>[];
      lines.loop((e, _) {
        try {
          final parts = e.split(','); // id, url, name
          if (parts.length == 3) list.add((id: parts[0], title: parts[2]));
        } catch (_) {}
      });
      return list;
    } catch (e) {
      return [];
    }
  }
}
