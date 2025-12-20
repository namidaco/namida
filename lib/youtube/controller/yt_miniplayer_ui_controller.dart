import 'package:flutter/material.dart';

import 'package:youtipie/core/enum.dart';

import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/youtube_miniplayer.dart';

class YoutubeMiniplayerUiController {
  static final inst = YoutubeMiniplayerUiController._();
  YoutubeMiniplayerUiController._();

  final currentCommentSort = CommentsSortType.top.obs;

  late final ytMiniplayerKey = GlobalKey<YoutubeMiniPlayerState>();

  void startDimTimer({Brightness? brightness}) {
    ytMiniplayerKey.currentState?.startDimTimer(brightness: brightness);
  }

  void cancelDimTimer() {
    ytMiniplayerKey.currentState?.cancelDimTimer();
  }

  void resetGlowUnderVideo() {
    ytMiniplayerKey.currentState?.resetGlowUnderVideo();
  }

  void ensureSegmentsVisible() async {
    if (NamidaNavigator.inst.isInFullScreen) {
      await NamidaNavigator.inst.exitFullScreen();
    }
    if (settings.enableLyrics.value) settings.save(enableLyrics: false);
    MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(true, dur: Duration.zero);
    final ytQueue = NamidaNavigator.inst.ytQueueSheetKey.currentState;
    if (ytQueue != null && ytQueue.isOpened) ytQueue.dismissSheet();
    ytMiniplayerKey.currentState?.openDescription();
  }
}
