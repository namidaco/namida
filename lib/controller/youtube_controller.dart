// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:namida/class/video.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';

class YTThumbnail {
  final String id;
  const YTThumbnail(this.id);
  String get maxResUrl => ThumbnailSet(id).maxResUrl;
  String get highResUrl => ThumbnailSet(id).highResUrl;
}

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
  int? currentDownloadStartRange;

  YoutubeExplode? _ytexp;
  YoutubeExplode? _ytexpDownload;
  final _connectivity = Connectivity();

  YoutubeExplode _getNewYTCilent({Map<String, String> headers = const <String, String>{}, bool useRangeHeader = false}) {
    return YoutubeExplode(YoutubeHttpClient(_NamidaClient(headers: headers, useRangeHeader: useRangeHeader)));
  }

  Future<bool> _hasConnection() async {
    final connection = await _connectivity.checkConnectivity();
    if (connection == ConnectivityResult.none) {
      printy('Error Requesting: No Connection', isError: true);
      return false;
    }
    return true;
  }

  Future<void> _tryDownloading<T>(Future<T> Function(YoutubeExplode ytexp) fun) async {
    if (!await _hasConnection()) return;

    void assignClient() => _ytexpDownload = _getNewYTCilent(useRangeHeader: true);
    currentDownloadStartRange = null;
    try {
      if (_ytexpDownload == null) assignClient();
      await fun(_ytexpDownload!);
    } catch (e) {
      _ytexpDownload?.close();
      assignClient();
      await fun(_ytexpDownload!);
    }
  }

  Future<void> _tryRequest<T>(Future<T> Function(YoutubeExplode ytexp) fun) async {
    if (!await _hasConnection()) return;

    void assignClient() => _ytexp = _getNewYTCilent();
    try {
      if (_ytexp == null) assignClient();
      await fun(_ytexp!);
    } catch (e) {
      _ytexp?.close();
      assignClient();
      await fun(_ytexp!);
    }
  }

  Future<void> prepareHomePage() async {
    _tryRequest((ytexp) async {
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
    });
  }

  Future<NamidaVideo?> downloadYoutubeVideo({
    required String id,
    required void Function(List<VideoOnlyStreamInfo> availableStreams) onAvailableQualities,
    required void Function(VideoOnlyStreamInfo choosenStream) onChoosingQuality,
    required void Function(List<int> downloadedBytes) downloadingStream,
    required void Function(int initialFileSize) onInitialFileSize,
  }) async {
    if (id == '') return null;
    NamidaVideo? dv;
    try {
      _ytexpDownload?.close(); // closing to stop previous download processes.
      await _tryDownloading((ytexp) async {
        // --------- Getting Video to Download.
        final stClient = ytexp.videos.streamsClient;
        final manifest = await stClient.getManifest(id);
        final availableVideos = List<VideoOnlyStreamInfo>.from(manifest.videoOnly);
        availableVideos.sortByReverseAlt((e) => e.videoResolution, (e) => e.bitrate);
        onAvailableQualities(availableVideos);

        final preferredQualities = SettingsController.inst.youtubeVideoQualities.map((element) => element.settingLabeltoVideoLabel());
        VideoOnlyStreamInfo erabaretaStream = availableVideos.last; // worst quality
        for (int i = 0; i < availableVideos.length; i++) {
          final q = availableVideos[i];
          if (preferredQualities.contains(q.videoQualityLabel.split('p').first)) {
            erabaretaStream = q;
            break;
          }
        }
        onChoosingQuality(erabaretaStream);
        // ------------------------------------

        // --------- Downloading Choosen Video.
        String getVPath(bool isTemp) {
          final dir = isTemp ? k_DIR_VIDEOS_CACHE_TEMP : k_DIR_VIDEOS_CACHE;
          return "$dir${id}_${erabaretaStream.videoQualityLabel}.mp4";
        }

        final file = await File(getVPath(true)).create(); // retrieving the temp file (or creating a new one).
        final initialFileSizeOnDisk = await file.stat().then((value) => value.size); // fetching current size to be used as a range bytes for download request
        onInitialFileSize(initialFileSizeOnDisk);
        // only download if the download is incomplete, useful sometimes when file 'moving' fails.
        if (initialFileSizeOnDisk < erabaretaStream.size.totalBytes) {
          currentDownloadStartRange = initialFileSizeOnDisk;
          final downloadStream = ytexp.videos.streamsClient.get(erabaretaStream);

          final fileStream = file.openWrite(mode: FileMode.append);
          await for (final data in downloadStream) {
            fileStream.add(data);
            downloadingStream(data);
          }
          await fileStream.flush();
          await fileStream.close(); // closing file.
        }

        // ------------------------------------

        // -- ensuring the file is downloaded completely before moving.
        final fileStats = await file.stat();
        const allowance = 1024; // 1KB allowance
        if (fileStats.size >= erabaretaStream.size.totalBytes - allowance) {
          final newfile = await file.rename(getVPath(false));
          dv = NamidaVideo(
            path: newfile.path,
            ytID: id,
            height: erabaretaStream.videoResolution.height,
            width: erabaretaStream.videoResolution.width,
            sizeInBytes: erabaretaStream.size.totalBytes,
            frameratePrecise: erabaretaStream.framerate.framesPerSecond.toDouble(),
            creationTimeMS: 0, // TODO: get using metadata
            durationMS: 0, // TODO: get using metadata
            bitrate: erabaretaStream.bitrate.bitsPerSecond,
          );
        }
      });
    } catch (e) {
      printy('Error Downloading YT Video: $e', isError: true);
    }
    currentDownloadStartRange = null;
    return dv;
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
    YTLVideo? vid;
    await _tryRequest((ytexp) async {
      final videometafile = File('$k_DIR_YT_METADATA$id.txt');

      if (!forceReload && await videometafile.existsAndValid()) {
        final jsonResponse = await videometafile.readAsJson();
        if (jsonResponse != null) {
          final ytl = YTLVideo.fromJson(jsonResponse);
          currentYoutubeMetadata.value = ytl;
          vid = ytl;
        }
      } else {
        final video = await ytexp.videos.get(id);
        final channel = await ytexp.channels.get(video.channelId);
        final ytlvideo = YTLVideo(video: video, channel: channel);
        currentYoutubeMetadata.value = ytlvideo;
        final file = await videometafile.create();
        await file.writeAsJson(ytlvideo.toJson());
        vid = ytlvideo;
      }
    });
    return vid;
  }

  Future<void> updateCurrentComments(Video video, {bool forceReload = false, bool loadNext = false}) async {
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
        await _tryRequest((ytexp) async {
          _commentlistclient.value = await ytexp.videos.commentsClient.getComments(video);
          finalcomm.assignAll(_commentlistclient.value?.map((p0) => p0) ?? []);
        });
      }

      if (_commentlistclient.value != null) {
        newcomm = NamidaCommentsList(
          comments: finalcomm,
          totalLength: _commentlistclient.value?.totalLength ?? 0,
        );
        final file = await videocommentfile.create();
        await file.writeAsJson(newcomm.toJson());
      }
    }
    if (newcomm != null) {
      comments.value = newcomm;

      /// Comments Channels
      await _tryRequest((ytexp) async {
        await comments.value!.comments.loopFuture((ch, index) async {
          commentsChannels.add(await ytexp.channels.get(ch.channelId));
        });
      });
    }
  }

  void dispose({bool downloadClientOnly = false}) {
    _ytexpDownload?.close();
    _ytexpDownload = null;
    if (downloadClientOnly) return;
    _ytexp?.close();
    _ytexp = null;
  }
}

class _NamidaClient extends http.BaseClient {
  final Map<String, String> headers;
  final bool useRangeHeader;
  final _client = http.Client();

  _NamidaClient({
    // ignore: unused_element
    this.headers = const <String, String>{},
    this.useRangeHeader = false,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (YoutubeController.inst.sussyBaka.isNotEmpty) {
      request.headers.addAll({HttpHeaders.authorizationHeader: 'Bearer ${YoutubeController.inst.sussyBaka}'});
    }

    if (useRangeHeader) {
      final downloadStartRange = YoutubeController.inst.currentDownloadStartRange;
      if (downloadStartRange != null) {
        request.headers.addAll({'Range': 'bytes=$downloadStartRange-'});
      }
    }

    request.headers.addAll(headers);

    printy('_NamidaClient Header: ${request.headers}');
    return _client.send(request);
  }

  @override
  void close() => _client.close();
}
// set-cookie: GPS=1; Domain=.youtube.com; Expires=Fri, 07-Apr-2023 20:56:22 GMT; Path=/; Secure; HttpOnly,YSC=XHicZ70B0ko; Domain=.youtube.com; Path=/; Secure; HttpOnly; SameSite=none,VISITOR_INFO1_LIVE=1nIEHpLKuxA; Domain=.youtube.com; Expires=Wed, 04-Oct-2023 20:26:22 GMT; Path=/; Secure; HttpOnly; SameSite=none, cache-control: no-cache, no-store, max-age=0, must-revalidate, transfer-encoding: chunked, date: Fri, 07 Apr 2023 20:26:22 GMT, content-encoding: gzip, permissions-policy: ch-ua-arch=*, ch-ua-bitness=*, ch-ua-full-version=*, ch-ua-full-version-list=*, ch-ua-model=*, ch-ua-wow64=*, ch-ua-platform=*, ch-ua-platform-version=*, strict-transport-security: max-age=31536000, report-to: {"group":"youtube_main","max_age":2592000,"endpoints":[{"url":"https://csp.withgoogle.com/csp/report-to/youtube_main"}]}, origin-trial: AvC9UlR6RDk2crliDsFl66RWLnTbHrDbp+DiY6AYz/PNQ4G4tdUTjrHYr2sghbkhGQAVxb7jaPTHpEVBz0uzQwkAAAB4eyJvcmlnaW4iOiJodHRwczovL3lvdXR1YmUuY29tOjQ0MyIsImZlYXR1cmUiOiJXZWJWaWV3WFJlcXVlc3RlZ
// YSC; PREF; VISITOR_INFO; SID; HSID; SSID; APISID; SAPISID; LOGIN_INFO
