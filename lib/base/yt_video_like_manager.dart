import 'dart:async';

import 'package:flutter/material.dart';

import 'package:youtipie/class/videos/video_result.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';

class YTVideoLikeParamters {
  final bool isActive;
  final LikeAction action;
  final void Function() onStart;
  final void Function() onEnd;

  const YTVideoLikeParamters({
    required this.isActive,
    required this.action,
    required this.onStart,
    required this.onEnd,
  });
}

class YtVideoLikeManager {
  final RxBaseCore<YoutiPieVideoPageResult?> pageRx;
  YtVideoLikeManager({
    required this.pageRx,
  });

  static final current = YtVideoLikeManager(pageRx: YoutubeInfoController.current.currentVideoPage)..init();

  static bool get preferLikeOverFavourite => settings.youtube.preferLikeButtonOverFavourite.value && YoutubeAccountController.current.activeAccountChannel.value != null;

  late final currentVideoLikeStatus = Rxn<LikeStatus>();

  Future<bool> _confirmSomething(String action) async {
    bool confirmed = false;
    await NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: "${lang.confirm}: $action?",
        actions: [
          const CancelButton(),
          NamidaButton(
            colorScheme: Colors.red,
            text: action.toUpperCase(),
            onTap: () async {
              confirmed = true;
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
      ),
    );
    return confirmed;
  }

  Future<bool> _confirmRemoveLike() async {
    return _confirmSomething(lang.remove);
  }

  Future<bool> _confirmDislike() async {
    return _confirmSomething(lang.dislike);
  }

  Future<bool> onLikeClicked(YTVideoLikeParamters parameters) async {
    if (parameters.isActive) {
      final confirmed = await _confirmRemoveLike();
      if (!confirmed) return parameters.isActive;
    }
    return _onChangeLikeStatus(parameters);
  }

  Future<bool> onDisLikeClicked(YTVideoLikeParamters parameters) async {
    if (!parameters.isActive) {
      final confirmed = await _confirmDislike();
      if (!confirmed) return parameters.isActive;
    }
    return _onChangeLikeStatus(parameters);
  }

  /// returns the new liked state, or null if failed.
  Future<bool?> toggleLikeWithoutConfirmation(String videoId) async {
    final p = pageRx.value;
    if (p == null || p.videoId != videoId) return null;

    final oldStatus = currentVideoLikeStatus.value;
    final isLiked = oldStatus == LikeStatus.liked;
    final action = isLiked ? LikeAction.removeLike : LikeAction.addLike;
    currentVideoLikeStatus.value = action.toExpectedStatus();
    final newIsLiked = await _onChangeLikeStatus(
      YTVideoLikeParamters(
        isActive: isLiked,
        action: action,
        onStart: () {},
        onEnd: () {},
      ),
    );
    if (newIsLiked == isLiked) {
      if (pageRx.value?.videoId == p.videoId) currentVideoLikeStatus.value = oldStatus;
      return null;
    }
    return newIsLiked;
  }

  Future<bool> _onChangeLikeStatus(YTVideoLikeParamters parameters) async {
    final p = pageRx.value;
    if (p == null) return parameters.isActive;

    parameters.onStart();
    final res = await YoutiPie.videoAction.changeLikeStatus(
      videoPage: p,
      engagement: p.videoInfo?.engagement,
      action: parameters.action,
    );
    parameters.onEnd();

    if (res == true) {
      if (settings.youtube.ryd.value.sendVotesEnabled) {
        unawaited(
          YoutubeInfoController.returnyoutubedislike
              .sendVoteAction(
                p.videoId,
                parameters.action,
              )
              .ignoreError(),
        );
      }

      if (settings.youtube.linkLikeButtonWithFavourites) {
        switch (parameters.action) {
          case LikeAction.addLike:
            YoutubePlaylistController.inst.setVideoFavourite(p.videoId, true);
          case LikeAction.removeLike || LikeAction.addDislike:
            YoutubePlaylistController.inst.setVideoFavourite(p.videoId, false);
          case LikeAction.removeDislike:
        }
      }

      final newExpectedStatus = parameters.action.toExpectedStatus();
      if (pageRx.value?.videoId == p.videoId) {
        currentVideoLikeStatus.value = newExpectedStatus;
      }
      if (!identical(this, current) && current.pageRx.value?.videoId == p.videoId) {
        current.currentVideoLikeStatus.value = newExpectedStatus;
      }
      return !parameters.isActive;
    }

    return parameters.isActive;
  }

  void _onPageChanged() {
    currentVideoLikeStatus.value = pageRx.value?.videoInfo?.engagement?.likeStatus;
  }

  void init() {
    currentVideoLikeStatus.reInit();
    _onPageChanged(); // fill initial values
    pageRx.addListener(_onPageChanged);
  }

  void dispose() {
    pageRx.removeListener(_onPageChanged);
    currentVideoLikeStatus.close();
  }
}
