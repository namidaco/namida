import 'dart:async';

import 'package:flutter/material.dart';

import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/core/enum.dart';

import 'package:namida/core/utils.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

mixin YTCardLikeStatusMixin<T extends StatefulWidget> on State<T> {
  RxBaseCore<LikeStatus?> get likeStatusRx => _likeStatusRx;

  bool get canFetchLikeStatus => true;
  String get cardVideoId;

  final _likeStatusRx = Rxn<LikeStatus>(LikeStatus.unknown);

  Timer? _timer;

  @override
  void dispose() {
    _likeStatusRx.close();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> tryFetchLikeStatus() async {
    if (canFetchLikeStatus) {
      final videoId = cardVideoId;
      final likeStatus = await _fetchLikeStatusForVideoCardForce(videoId);
      if (videoId == cardVideoId) _likeStatusRx.value = likeStatus;
    }
  }

  void resetLikeStatus() {
    _timer?.cancel();
    _likeStatusRx.value = LikeStatus.unknown;
  }

  Future<LikeStatus?> _fetchLikeStatusForVideoCardForce(
    String videoId, {
    Duration delay = const Duration(milliseconds: 700),
    ExecuteDetails? details,
  }) async {
    final c = Completer<LikeStatus?>();
    _timer?.cancel();
    _timer = Timer(
      delay,
      () {
        if (this.mounted) {
          c.complete(YoutubeInfoController.video.fetchLikeStatusForVideoCardInstant(videoId, details: details));
        } else {
          c.complete(null);
        }
      },
    );
    return c.future;
  }
}
