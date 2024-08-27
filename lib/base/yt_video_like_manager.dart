import 'package:youtipie/class/videos/video_result.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

class YTVideoLikeParamters {
  final YoutiPieVideoPageResult? page;
  final bool isActive;
  final LikeAction action;
  final void Function() onStart;
  final void Function() onEnd;

  const YTVideoLikeParamters({
    required this.page,
    required this.isActive,
    required this.action,
    required this.onStart,
    required this.onEnd,
  });
}

class YtVideoLikeManager {
  late final currentVideoLikeStatus = Rxn<LikeStatus>();

  Future<bool> _confirmRemoveLike() async {
    bool confirmed = false;
    await NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: lang.CONFIRM,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.REMOVE.toUpperCase(),
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

  Future<bool> onLikeClicked(YTVideoLikeParamters parameters) async {
    if (parameters.isActive) {
      final confirmed = await _confirmRemoveLike();
      if (!confirmed) return parameters.isActive;
    }
    return _onChangeLikeStatus(parameters);
  }

  Future<bool> onDisLikeClicked(YTVideoLikeParamters parameters) async {
    return _onChangeLikeStatus(parameters);
  }

  Future<bool> _onChangeLikeStatus(YTVideoLikeParamters parameters) async {
    final page = parameters.page;
    if (page == null) return parameters.isActive;

    parameters.onStart();
    final res = await YoutiPie.videoAction.changeLikeStatus(
      videoPage: page,
      engagement: page.videoInfo?.engagement,
      action: parameters.action,
    );
    parameters.onEnd();

    if (res == true) {
      currentVideoLikeStatus.value = currentVideoLikeStatus.value = parameters.action.toExpectedStatus();
      return !parameters.isActive;
    }

    return parameters.isActive;
  }

  void _onPageChanged() {
    final page = YoutubeInfoController.current.currentVideoPage.value;
    currentVideoLikeStatus.value = page?.videoInfo?.engagement?.likeStatus;
  }

  void init() {
    _onPageChanged(); // fill initial values
    YoutubeInfoController.current.currentVideoPage.addListener(_onPageChanged);
  }

  void dispose() {
    YoutubeInfoController.current.currentVideoPage.removeListener(_onPageChanged);
    currentVideoLikeStatus.close();
  }
}
