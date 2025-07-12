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
import 'package:youtipie/class/publish_time.dart';
import 'package:youtipie/class/related_videos_request_params.dart';
import 'package:youtipie/class/result_wrapper/comment_result.dart';
import 'package:youtipie/class/result_wrapper/history_result.dart';
import 'package:youtipie/class/result_wrapper/related_videos_result.dart';
import 'package:youtipie/class/result_wrapper/search_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/streams/video_stream_info.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/class/thumbnail.dart';
import 'package:youtipie/class/videos/missing_video_info.dart';
import 'package:youtipie/class/videos/video_result.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/core/http.dart';
import 'package:youtipie/youtipie.dart' hide logger;

import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

part 'info_controllers/yt_channel_info_controller.dart';
part 'info_controllers/yt_history_linker.dart';
part 'info_controllers/yt_missing_info_controller.dart';
part 'info_controllers/yt_search_info_controller.dart';
part 'info_controllers/yt_various_utils.dart';
part 'info_controllers/yt_video_info_controller.dart';
part 'youtube_current_info.dart';

class YoutubeInfoController {
  const YoutubeInfoController._();

  static const video = _VideoInfoController();
  static const playlist = YoutiPie.playlist;
  static var history = _YoutubeHistoryLinker(() => YoutiPie.activeAccountDetails.value?.id);
  static const userplaylist = YoutiPie.userplaylist;
  static const comment = YoutiPie.comment;
  static const commentAction = YoutiPie.commentAction;
  static const notificationsAction = YoutiPie.notificationsAction;
  static const search = _SearchInfoController();
  static const feed = YoutiPie.feed;
  static const channel = _ChannelInfoController();
  static final missingInfo = _MissingInfoController();
  static final potoken = YoutiPie.potoken;

  static final memoryCache = YoutiPie.memoryCache;

  static bool didInit = false;
  static Future<void> get waitForInit => _initCompleter.future;
  static final _initCompleter = Completer<void>();

  static Future<void> initialize(Completer<void> syncItemsCompleter) async {
    if (_initCompleter.isCompleted) {
      syncItemsCompleter.completeIfWasnt();
      return;
    }
    YoutiPie.setLogs(_YTReportingLog());
    try {
      final accountCompleter = Completer<void>();
      YoutiPie.initialize(
        dataDirectory: AppDirs.YOUTIPIE_CACHE,
        sensitiveDataDirectory: AppDirs.YOUTIPIE_DATA,
        checkJSPlayer: false, // we properly check for jsplayer with each streams request if needed,
        checkHasConnectionCallback: () => ConnectivityController.inst.hasConnection,
        syncItemsCompleter: syncItemsCompleter,
        accountCompleter: accountCompleter,
      );
      await accountCompleter.future;
      history.init(AppDirs.YOUTIPIE_CACHE);
    } catch (e, st) {
      syncItemsCompleter.completeErrorIfWasnt(e, st);
      logger.error('YoutiPie.initialize', e: e, st: st);
    }

    YoutubeAccountController.current.addOnAccountChanged(() {
      current.resetAll();
      history.dispose();
      history = _YoutubeHistoryLinker(() => YoutiPie.activeAccountDetails.value?.id);
      final currentId = Player.inst.currentVideo?.id;
      if (currentId != null) {
        current.updateVideoPageCache(currentId);
        current.updateCurrentCommentsCache(currentId);
      }
    });

    didInit = true;
    _initCompleter.complete();
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
      displayDuration: SnackDisplayDuration.long,
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
