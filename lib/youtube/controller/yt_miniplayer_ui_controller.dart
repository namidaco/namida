import 'package:flutter/material.dart';

import 'package:youtipie/core/enum.dart';

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

  void ensureSegmentsVisible() {
    ytMiniplayerKey.currentState?.openDescription();
  }
}
