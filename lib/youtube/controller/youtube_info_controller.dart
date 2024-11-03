import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:queue/queue.dart';
import 'package:youtipie/class/channels/channel_page_about.dart';
import 'package:youtipie/class/channels/channel_page_result.dart';
import 'package:youtipie/class/channels/channel_tab.dart';
import 'package:youtipie/class/channels/channel_tab_result.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/items_sort.dart';
import 'package:youtipie/class/related_videos_request_params.dart';
import 'package:youtipie/class/result_wrapper/comment_result.dart';
import 'package:youtipie/class/result_wrapper/history_result.dart';
import 'package:youtipie/class/result_wrapper/related_videos_result.dart';
import 'package:youtipie/class/result_wrapper/search_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/streams/video_stream_info.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/class/videos/video_result.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/core/http.dart';
import 'package:youtipie/youtipie.dart' hide logger;

import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';

part 'info_controllers/yt_channel_info_controller.dart';
part 'info_controllers/yt_history_linker.dart';
part 'info_controllers/yt_search_info_controller.dart';
part 'info_controllers/yt_various_utils.dart';
part 'info_controllers/yt_video_info_controller.dart';
part 'youtube_current_info.dart';

class YoutubeInfoController {
  const YoutubeInfoController._();

  static const video = _VideoInfoController();
  static const playlist = YoutiPie.playlist;
  static final history = _YoutubeHistoryLinker(() => YoutiPie.activeAccountDetails.value?.id);
  static const userplaylist = YoutiPie.userplaylist;
  static const comment = YoutiPie.comment;
  static const commentAction = YoutiPie.commentAction;
  static const notificationsAction = YoutiPie.notificationsAction;
  static const search = _SearchInfoController();
  static const feed = YoutiPie.feed;
  static const channel = _ChannelInfoController();

  static final memoryCache = YoutiPie.memoryCache;

  static void initialize() {
    YoutiPie.initialize(
      dataDirectory: AppDirs.YOUTIPIE_CACHE,
      sensitiveDataDirectory: AppDirs.YOUTIPIE_DATA,
      checkJSPlayer: false, // we properly check for jsplayer with each streams request if needed,
      checkHasConnectionCallback: () => ConnectivityController.inst.hasConnection,
    );
    history.init(AppDirs.YOUTIPIE_CACHE);
    YoutiPie.setLogs(_YTReportingLog());

    YoutubeAccountController.current.addOnAccountChanged(() {
      final currentId = Player.inst.currentVideo?.id;
      current.resetAll();
      if (currentId != null) {
        current.updateVideoPageCache(currentId);
        current.updateCurrentCommentsCache(currentId);
      }
    });
  }

  static final current = _YoutubeCurrentInfoController._();
  static final utils = _YoutubeInfoUtils._();
}

class _YTReportingLog extends Logger {
  static void _showError(String msg, {Object? exception}) {
    String title = lang.ERROR;
    if (exception != null) title += ': $exception';

    snackyy(
      message: msg,
      title: title,
      isError: true,
      displaySeconds: 3,
      top: false,
    );
  }

  @override
  void e(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _showError(message.toString(), exception: error);
    super.e(message, time: time, error: error, stackTrace: stackTrace);
  }
}
