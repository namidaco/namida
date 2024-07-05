library namidayoutubeinfo;

import 'dart:io';

import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/logs_controller.dart' as namidalogs;
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';

import 'package:youtipie/class/channels/channel_page_about.dart';
import 'package:youtipie/class/channels/channel_page_result.dart';
import 'package:youtipie/class/channels/channel_tab.dart';
import 'package:youtipie/class/channels/tabs/channel_tab_videos_result.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/related_videos_request_params.dart';
import 'package:youtipie/class/result_wrapper/comment_result.dart';
import 'package:youtipie/class/result_wrapper/related_videos_result.dart';
import 'package:youtipie/class/result_wrapper/search_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/class/videos/video_result.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/core/http.dart';
import 'package:youtipie/youtipie.dart' hide logger;

part 'info_controllers/yt_channel_info_controller.dart';
part 'info_controllers/yt_search_info_controller.dart';
part 'info_controllers/yt_various_utils.dart';
part 'info_controllers/yt_video_info_controller.dart';
part 'youtube_current_info.dart';

class YoutubeInfoController {
  const YoutubeInfoController._();

  static const video = _VideoInfoController();
  static const playlist = YoutiPie.playlist;
  static const comment = YoutiPie.comment;
  static const search = _SearchInfoController();
  static const feed = YoutiPie.feed;
  static const channel = _ChannelInfoController();

  static final memoryCache = YoutiPie.memoryCache;

  static void initialize() {
    YoutiPie.initialize(
      dataDirectory: AppDirs.YOUTIPIE_CACHE,
      sensitiveDataDirectory: AppDirs.YOUTIPIE_DATA,
      checkJSPlayer: true, // wont await.. are we cooked? properly
    );
    YoutiPie.setLogs(namidalogs.logger.logger);
  }

  static Future<bool> ensureJSPlayerInitialized() async {
    if (YoutiPie.cipher.isPrepared) return true;
    return YoutiPie.cipher.prepareJSPlayer(cacheDirectoryPath: AppDirs.YOUTIPIE_CACHE);
  }

  static final current = _YoutubeCurrentInfoController._();
  static final utils = _YoutubeInfoUtils._();
}
