import 'dart:async';

import 'package:youtipie/class/videos/video_result.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

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

  late final currentVideoLikeStatus = Rxn<LikeStatus>();

  Future<bool> _confirmSomething(String action) async {
    bool confirmed = false;
    await NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: lang.CONFIRM,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: action.toUpperCase(),
            onPressed: () async {
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
    return _confirmSomething(lang.REMOVE);
  }

  Future<bool> _confirmDislike() async {
    return _confirmSomething(lang.DISLIKE);
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

      final newExpectedStatus = parameters.action.toExpectedStatus();
      currentVideoLikeStatus.value = newExpectedStatus;
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
