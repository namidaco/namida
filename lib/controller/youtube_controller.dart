// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:namida/class/video.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class YoutubeController {
  static YoutubeController get inst => _instance;
  static final YoutubeController _instance = YoutubeController._internal();
  YoutubeController._internal();

  final currentYoutubeMetadata = Rxn<YTLVideo>();
  final currentSearchList = Rxn<VideoSearchList>();
  final comments = Rxn<NamidaCommentsList>();
  final _commentlistclient = Rxn<CommentsList>();
  final RxList<Channel> commentsChannels = <Channel>[].obs;
  final RxList<Channel> searchChannels = <Channel>[].obs;

  String sussyBaka = '';
  Map<String, String> sussyBakaHeader = {};

  Future<void> prepareHomePage() async {
    final ytexp = YoutubeExplode(YoutubeHttpClient(NamidaClient()));
    currentSearchList.value = await ytexp.search.search('');

    /// Channels in search
    final search = currentSearchList.value;
    if (search == null) {
      return;
    }
    await search.loopFuture((ch, index) async {
      searchChannels.add(await ytexp.channels.get(ch.channelId));
    });

    searchChannels.refresh();
    ytexp.close();
  }

  Future<void> updateCurrentVideoMetadata(String id, {bool forceReload = false}) async {
    currentYoutubeMetadata.value = null;
    currentYoutubeMetadata.value = await loadYoutubeVideoMetadata(id, forceReload: forceReload);

    if (currentYoutubeMetadata.value != null) {
      await updateCurrentComments(currentYoutubeMetadata.value!.video, forceReload: forceReload);
    }
  }

  Future<YTLVideo?> loadYoutubeVideoMetadata(String id, {bool forceReload = false}) async {
    if (id == '') {
      return null;
    }
    final videometafile = File('$k_DIR_YT_METADATA$id.txt');
    YTLVideo? vid;
    if (!forceReload && await videometafile.existsAndValid()) {
      final jsonResponse = await videometafile.readAsJson();
      if (jsonResponse != null) {
        final ytl = YTLVideo.fromJson(jsonResponse);
        currentYoutubeMetadata.value = ytl;
        vid = ytl;
      }
    } else {
      final ytexp = YoutubeExplode(YoutubeHttpClient(NamidaClient()));
      final video = await ytexp.videos.get(id);
      final channel = await ytexp.channels.get(video.channelId);
      final ytlvideo = YTLVideo(video, channel);
      currentYoutubeMetadata.value = ytlvideo;
      final file = await videometafile.create();
      await file.writeAsJson(ytlvideo.toJson());
      vid = ytlvideo;
      ytexp.close();
    }
    return vid;
  }

  Future<void> updateCurrentComments(Video video, {bool forceReload = false, bool loadNext = false}) async {
    final ytexp = YoutubeExplode(YoutubeHttpClient(NamidaClient()));
    if (!loadNext) {
      comments.value = null;
    }
    final videocommentfile = File('$k_DIR_YT_METADATA_COMMENTS${video.id}.txt');

    NamidaCommentsList? newcomm;
    final finalcomm = _commentlistclient.value?.mapped((p0) => p0) ?? <Comment>[];

    /// Comments from cache
    if (!forceReload && await videocommentfile.existsAndValid()) {
      final jsonResponse = await videocommentfile.readAsJson();
      if (jsonResponse != null) {
        newcomm = NamidaCommentsList.fromJson(jsonResponse);
      }
    }

    /// comments from youtube
    else {
      if (loadNext) {
        final more = await _commentlistclient.value?.nextPage() ?? <Comment>[];
        finalcomm.addAll(more);
      } else {
        _commentlistclient.value = await ytexp.videos.commentsClient.getComments(video);
        finalcomm.assignAll(_commentlistclient.value?.map((p0) => p0) ?? []);
      }

      if (_commentlistclient.value != null) {
        newcomm = NamidaCommentsList(finalcomm, _commentlistclient.value?.totalLength ?? 0);
        final file = await videocommentfile.create();
        await file.writeAsJson(newcomm.toJson());
      }
    }
    if (newcomm != null) {
      comments.value = newcomm;

      /// Comments Channels
      await comments.value!.comments.loopFuture((ch, index) async {
        commentsChannels.add(await ytexp.channels.get(ch.channelId));
      });
    }
    ytexp.close();
  }
}

class NamidaClient extends http.BaseClient {
  final _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (YoutubeController.inst.sussyBakaHeader.isNotEmpty) {
      request.headers.addAll(YoutubeController.inst.sussyBakaHeader);
    }
    if (YoutubeController.inst.sussyBaka.isNotEmpty) {
      request.headers.addAll({'Authorization': 'Bearer ${YoutubeController.inst.sussyBaka}'});
    }

    // printInfo(info: 'ACCCCCCCCCC NamidaClient: ${YoutubeController.inst.sussyBaka}');
    printInfo(info: 'ACCCCCCCCCC Header NamidaClient: ${request.headers}');
    // printInfo(info: 'ACCCCCCCCCC NamidaClient: $request');
    return _client.send(request);
  }

  @override
  void close() => _client.close();
}
// set-cookie: GPS=1; Domain=.youtube.com; Expires=Fri, 07-Apr-2023 20:56:22 GMT; Path=/; Secure; HttpOnly,YSC=XHicZ70B0ko; Domain=.youtube.com; Path=/; Secure; HttpOnly; SameSite=none,VISITOR_INFO1_LIVE=1nIEHpLKuxA; Domain=.youtube.com; Expires=Wed, 04-Oct-2023 20:26:22 GMT; Path=/; Secure; HttpOnly; SameSite=none, cache-control: no-cache, no-store, max-age=0, must-revalidate, transfer-encoding: chunked, date: Fri, 07 Apr 2023 20:26:22 GMT, content-encoding: gzip, permissions-policy: ch-ua-arch=*, ch-ua-bitness=*, ch-ua-full-version=*, ch-ua-full-version-list=*, ch-ua-model=*, ch-ua-wow64=*, ch-ua-platform=*, ch-ua-platform-version=*, strict-transport-security: max-age=31536000, report-to: {"group":"youtube_main","max_age":2592000,"endpoints":[{"url":"https://csp.withgoogle.com/csp/report-to/youtube_main"}]}, origin-trial: AvC9UlR6RDk2crliDsFl66RWLnTbHrDbp+DiY6AYz/PNQ4G4tdUTjrHYr2sghbkhGQAVxb7jaPTHpEVBz0uzQwkAAAB4eyJvcmlnaW4iOiJodHRwczovL3lvdXR1YmUuY29tOjQ0MyIsImZlYXR1cmUiOiJXZWJWaWV3WFJlcXVlc3RlZ
// YSC; PREF; VISITOR_INFO; SID; HSID; SSID; APISID; SAPISID; LOGIN_INFO