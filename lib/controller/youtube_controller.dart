// ignore_for_file: depend_on_referenced_packages

import 'dart:developer';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:dio/dio.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:newpipeextractor_dart/extractors/channels.dart';
import 'package:newpipeextractor_dart/extractors/comments.dart';
import 'package:newpipeextractor_dart/extractors/trending.dart';
import 'package:newpipeextractor_dart/extractors/videos.dart';
import 'package:newpipeextractor_dart/models/infoItems/yt_feed.dart';
import 'package:newpipeextractor_dart/models/videoInfo.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:newpipeextractor_dart/utils/httpClient.dart';
import 'package:newpipeextractor_dart/utils/thumbnails.dart';

import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';

class YTThumbnail {
  final String id;
  const YTThumbnail(this.id);
  String get maxResUrl => StreamThumbnail(id).maxresdefault;
  String get hqdefault => StreamThumbnail(id).hqdefault;
  String get mqdefault => StreamThumbnail(id).mqdefault;
  String get sddefault => StreamThumbnail(id).sddefault;
  String get lowres => StreamThumbnail(id).lowres;
  List<String> get allQualitiesByHighest => [maxResUrl, hqdefault, mqdefault, sddefault, lowres];
}

class DownloadProgress {
  final int progress;
  final int totalProgress;

  const DownloadProgress({
    required this.progress,
    required this.totalProgress,
  });
}

class YoutubeController {
  static YoutubeController get inst => _instance;
  static final YoutubeController _instance = YoutubeController._internal();
  YoutubeController._internal();

  final scrollController = ScrollController();

  final homepageFeed = <YoutubeFeed>[].obs;

  final currentYoutubeMetadata = Rxn<YTLVideo>();
  final currentRelatedVideos = <YoutubeFeed?>[].obs;
  final currentComments = <YoutubeComment?>[].obs;
  final currentTotalCommentsCount = Rxn<int>();
  final isLoadingComments = false.obs;

  /// {id: DownloadProgress()}
  final downloadsVideoProgressMap = <String, DownloadProgress>{}.obs;

  /// {id: DownloadProgress()}
  final downloadsAudioProgressMap = <String, DownloadProgress>{}.obs;

  final _downloadClientsMap = <String, Dio>{}; // {nameIdentifier: Dio()}

  String getYoutubeLink(String id) => id.toYTUrl();

  Future<void> prepareHomeFeed() async {
    homepageFeed.clear();
    final videos = await TrendingExtractor.getTrendingVideos();
    homepageFeed.addAll([
      ...videos,
    ]);
  }

  Future<void> fetchRelatedVideos(String id) async {
    currentRelatedVideos
      ..clear()
      ..addAll(List.filled(20, null));
    final items = await VideoExtractor.getRelatedStreams(id.toYTUrl());
    currentRelatedVideos
      ..clear()
      ..addAll([
        ...items,
      ]);
  }

  Future<void> _fetchComments(String id, {bool forceRequest = false}) async {
    currentTotalCommentsCount.value = null;
    currentComments.clear();

    currentComments.addAll(List.filled(20, null));

    // -- Fetching Comments.
    final fetchedComments = <YoutubeComment>[];
    final cachedFile = File("${AppDirs.YT_METADATA_COMMENTS}$id.txt");

    // fetching cache
    final userForceNewRequest = ConnectivityController.inst.hasConnection && settings.ytCommentsAlwaysLoadNew.value;
    if (!forceRequest && !userForceNewRequest && await cachedFile.exists()) {
      final res = await cachedFile.readAsJson();
      final commList = (res as List?)?.map((e) => YoutubeComment.fromMap(e));
      if (commList != null && commList.isNotEmpty) {
        fetchedComments.addAll(commList);
      }
      _isCurrentCommentsFromCache = true;
    }
    // fetching from yt, in case no comments were added, i.e: no cache.
    if (fetchedComments.isEmpty) {
      final comments = await CommentsExtractor.getComments(id.toYTUrl());
      fetchedComments.addAll(comments);
      _isCurrentCommentsFromCache = false;

      if (comments.isNotEmpty) _saveCommentsToStorage(cachedFile, comments);
    }
    // -- Fetching Comments End.

    currentComments.clear();
    currentComments.addAll(fetchedComments);
    currentTotalCommentsCount.value = fetchedComments.firstOrNull?.totalCommentsCount;
  }

  Future<void> _fetchNextComments(String id) async {
    if (_isCurrentCommentsFromCache) return;
    final comments = await CommentsExtractor.getNextComments();
    currentComments.addAll(comments);

    // -- saving to cache
    final cachedFile = File("${AppDirs.YT_METADATA_COMMENTS}$id.txt");
    _saveCommentsToStorage(cachedFile, currentComments);
  }

  Future<void> _saveCommentsToStorage(File file, Iterable<YoutubeComment?> commListy) async {
    await file.writeAsJson(commListy.map((e) => e?.toMap()).toList());
  }

  /// Used to keep track of current comments sources, mainly to
  /// prevent fetching next comments when cached version is loaded.
  bool get isCurrentCommentsFromCache => _isCurrentCommentsFromCache;
  bool _isCurrentCommentsFromCache = false;

  Future<void> updateCurrentComments(String id, {bool fetchNextOnly = false, bool forceRequest = false}) async {
    isLoadingComments.value = true;
    if (currentComments.isNotEmpty && fetchNextOnly && !forceRequest) {
      await _fetchNextComments(id);
    } else {
      await _fetchComments(id, forceRequest: forceRequest);
    }
    isLoadingComments.value = false;
  }

  Future<void> updateVideoDetails(String id) async {
    if (!settings.useYoutubeMiniplayer.value) return;

    if (scrollController.hasClients) scrollController.jumpTo(0);
    updateCurrentVideoMetadata(id);
    updateCurrentComments(id);
    fetchRelatedVideos(id);
  }

  Future<void> updateCurrentVideoMetadata(String id) async {
    currentYoutubeMetadata.value = null;
    final info = await _fetchVideoDetails(id);
    inspect(info);
    final channel = await _fetchChannelDetails(info?.uploaderUrl);
    inspect(channel);
    currentYoutubeMetadata.value = info == null ? null : YTLVideo(video: info, channel: channel);
  }

  Future<VideoInfo?> _fetchVideoDetails(String id) async {
    final cachedFile = File("${AppDirs.YT_METADATA}$id.txt");
    VideoInfo? vi;
    if (await cachedFile.exists()) {
      final res = await cachedFile.readAsJson();
      vi = VideoInfo.fromMap(res);
    } else {
      final info = await VideoExtractor.getInfo(id.toYTUrl());
      vi = info;
      if (info != null) cachedFile.writeAsJson(info.toMap());
    }
    return vi;
  }

  Future<YoutubeChannel> _fetchChannelDetails(String? channelUrl) async {
    final channelId = channelUrl?.split('/').last;
    final cachedFile = File("${AppDirs.YT_METADATA_CHANNELS}$channelId.txt");
    YoutubeChannel? vi;
    if (await cachedFile.exists()) {
      final res = await cachedFile.readAsJson();
      vi = YoutubeChannel.fromMap(res);
    } else {
      final info = await ChannelExtractor.channelInfo(channelUrl);
      vi = info;
      cachedFile.writeAsJson(info.toMap());
    }
    return vi;
  }

  Future<int?> getContentSize(String url) async => await ExtractorHttpClient.getContentLength(url);

  Future<List<VideoOnlyStream>> getAvailableVideoStreamsOnly(String id) async {
    final videos = await VideoExtractor.getVideoOnlyStreams(id.toYTUrl());
    videos.sortByReverseAlt(
      (e) => e.width ?? (int.tryParse(e.resolution?.split('p').firstOrNull ?? '') ?? 0),
      (e) => e.fps ?? 0,
    );
    return videos;
  }

  Future<YoutubeVideo> getAvailableStreams(String id) async {
    final url = id.toYTUrl();
    final video = await VideoExtractor.getStream(url);
    video.videoOnlyStreams?.sortByReverseAlt(
      (e) => e.width ?? (int.tryParse(e.resolution?.split('p').firstOrNull ?? '') ?? 0),
      (e) => e.fps ?? 0,
    );
    video.videoStreams?.sortByReverseAlt(
      (e) => e.width ?? (int.tryParse(e.resolution?.split('p').firstOrNull ?? '') ?? 0),
      (e) => e.fps ?? 0,
    );

    video.audioOnlyStreams?.sortByReverseAlt(
      (e) => e.bitrate ?? 0,
      (e) => e.sizeInBytes ?? 0,
    );
    return video;
  }

  Future<VideoInfo?> getVideoInfo(String id) async {
    return await VideoExtractor.getInfo(id.toYTUrl());
  }

  Future<File?> downloadYoutubeVideoRaw({
    required String id,
    required bool useCachedVersionsIfAvailable, // TODO: implement for audios too.
    required Directory saveDirectory,
    required String filename,
    required VideoStream? videoStream,
    required AudioOnlyStream? audioStream,
    required bool merge,
    required void Function(List<int> downloadedBytes) videoDownloadingStream,
    required void Function(List<int> downloadedBytes) audioDownloadingStream,
    required void Function(int initialFileSize) onInitialVideoFileSize,
    required void Function(int initialFileSize) onInitialAudioFileSize,
    required Future<void> Function(File videoFile) onVideoFileReady,
    required Future<void> Function(File audioFile) onAudioFileReady,
  }) async {
    if (id == '') return null;
    File? df;
    Future<bool> fileSizeQualified({
      required File file,
      required int targetSize,
      int allowanceBytes = 1024,
    }) async {
      final fileStats = await file.stat();
      final ok = fileStats.size >= targetSize - allowanceBytes;
      return ok;
    }

    File? videoFile;
    File? audioFile;

    try {
      // --------- Downloading Choosen Video.
      if (videoStream != null) {
        final filecache = VideoController.inst.videoInCacheRealCheck(id, videoStream);
        if (useCachedVersionsIfAvailable && filecache != null) {
          videoFile = filecache;
        } else {
          String getVPath(bool isTemp) {
            final prefix = isTemp ? '.tempv_' : '';
            return "${saveDirectory.path}/$prefix$filename";
          }

          if (videoStream.sizeInBytes == 0) {
            videoStream.sizeInBytes = await ExtractorHttpClient.getContentLength(videoStream.url ?? '');
          }
          int bytesLength = 0;

          final downloadedFile = await _checkFileAndDownload(
            url: videoStream.url ?? '',
            targetSize: videoStream.sizeInBytes ?? 0,
            filename: filename,
            destinationFilePath: getVPath(true),
            onInitialFileSize: (initialFileSize) {
              onInitialVideoFileSize(initialFileSize);
              bytesLength = initialFileSize;
            },
            downloadingStream: (downloadedBytes) {
              videoDownloadingStream(downloadedBytes);
              bytesLength += downloadedBytes.length;
              downloadsVideoProgressMap[id] = DownloadProgress(
                progress: bytesLength,
                totalProgress: videoStream.sizeInBytes ?? 0,
              );
            },
          );
          downloadsVideoProgressMap.remove(id);
          final qualified = await fileSizeQualified(file: downloadedFile, targetSize: videoStream.sizeInBytes ?? 0);
          if (qualified) {
            videoFile = downloadedFile;
            await onVideoFileReady(videoFile);
          }
        }
      }
      // -----------------------------------

      // --------- Downloading Choosen Audio.
      if (audioStream != null) {
        String getAPath(bool isTemp) {
          final prefix = isTemp ? '.tempa_' : '';
          return "${saveDirectory.path}/$prefix$filename";
        }

        int bytesLength = 0;

        final downloadedFile = await _checkFileAndDownload(
          url: audioStream.url ?? '',
          targetSize: audioStream.sizeInBytes ?? 0,
          filename: filename,
          destinationFilePath: getAPath(true),
          onInitialFileSize: (initialFileSize) {
            onInitialAudioFileSize(initialFileSize);
            bytesLength = initialFileSize;
          },
          downloadingStream: (downloadedBytes) {
            audioDownloadingStream(downloadedBytes);
            bytesLength += downloadedBytes.length;
            downloadsAudioProgressMap[id] = DownloadProgress(
              progress: bytesLength,
              totalProgress: audioStream.sizeInBytes ?? 0,
            );
          },
        );
        downloadsAudioProgressMap.remove(id);
        final qualified = await fileSizeQualified(file: downloadedFile, targetSize: audioStream.sizeInBytes ?? 0);

        if (qualified) {
          audioFile = downloadedFile;
          await onAudioFileReady(audioFile);
        }
      }
      // -----------------------------------

      // ----- merging if both video & audio were downloaded
      if (merge && videoFile != null && audioFile != null) {
        final output = "${saveDirectory.path}/$filename";
        final didMerge = await NamidaFFMPEG.inst.mergeAudioAndVideo(
          videoPath: videoFile.path,
          audioPath: audioFile.path,
          outputPath: output,
        );
        if (didMerge) Future.wait([videoFile.tryDeleting(), audioFile.tryDeleting()]); // deleting temp files since they got merged
        df = File(output);
      } else {
        // -- renaming files
        await Future.wait([
          if (videoFile != null && videoStream != null) videoFile.rename("${saveDirectory.path}/$filename"),
          if (audioFile != null && audioStream != null) audioFile.rename("${saveDirectory.path}/$filename"),
        ]);
        df = videoFile ?? audioFile;
      }
    } catch (e) {
      printy('Error Downloading YT Video: $e', isError: true);
    }

    return df;
  }

  /// the file returned may not be complete if the client was closed.
  Future<File> _checkFileAndDownload({
    required String url,
    required int targetSize,
    required String filename,
    required String destinationFilePath,
    required void Function(int initialFileSize) onInitialFileSize,
    required void Function(List<int> downloadedBytes) downloadingStream,
  }) async {
    int downloadStartRange = 0;

    final file = await File(destinationFilePath).create(); // retrieving the temp file (or creating a new one).
    final initialFileSizeOnDisk = await file.sizeInBytes(); // fetching current size to be used as a range bytes for download request
    onInitialFileSize(initialFileSizeOnDisk);
    // only download if the download is incomplete, useful sometimes when file 'moving' fails.
    if (initialFileSizeOnDisk < targetSize) {
      downloadStartRange = initialFileSizeOnDisk;

      _downloadClientsMap[filename] = Dio(BaseOptions(headers: {HttpHeaders.rangeHeader: 'bytes=$downloadStartRange-'}));
      final downloadStream = await _downloadClientsMap[filename]!
          .get<ResponseBody>(
            url,
            options: Options(responseType: ResponseType.stream),
          )
          .then((value) => value.data);

      if (downloadStream != null) {
        final fileStream = file.openWrite(mode: FileMode.append);
        await for (final data in downloadStream.stream) {
          fileStream.add(data);
          downloadingStream(data);
        }
        await fileStream.flush();
        await fileStream.close(); // closing file.
      }
    }
    _downloadClientsMap[filename]?.close();
    return File(destinationFilePath);
  }

  Dio? downloadClient;
  Future<NamidaVideo?> downloadYoutubeVideo({
    required String id,
    VideoStream? stream,
    required void Function(List<VideoOnlyStream> availableStreams) onAvailableQualities,
    required void Function(VideoOnlyStream choosenStream) onChoosingQuality,
    required void Function(List<int> downloadedBytes) downloadingStream,
    required void Function(int initialFileSize) onInitialFileSize,
  }) async {
    if (id == '') return null;
    NamidaVideo? dv;
    try {
      // --------- Getting Video to Download.
      late VideoOnlyStream erabaretaStream;
      if (stream != null) {
        erabaretaStream = stream;
      } else {
        final availableVideos = await getAvailableVideoStreamsOnly(id);

        availableVideos.sortByReverseAlt(
          (e) => e.width ?? (int.tryParse(e.resolution?.split('p').firstOrNull ?? '') ?? 0),
          (e) => e.fps ?? 0,
        );
        onAvailableQualities(availableVideos);

        erabaretaStream = availableVideos.last; // worst quality

        if (stream == null) {
          final preferredQualities = settings.youtubeVideoQualities.map((element) => element.settingLabeltoVideoLabel());
          for (int i = 0; i < availableVideos.length; i++) {
            final q = availableVideos[i];
            if (preferredQualities.contains(q.resolution?.split('p').first)) {
              erabaretaStream = q;
              break;
            }
          }
        }
      }

      onChoosingQuality(erabaretaStream);
      // ------------------------------------

      // --------- Downloading Choosen Video.
      String getVPath(bool isTemp) {
        final dir = isTemp ? AppDirs.VIDEOS_CACHE_TEMP : AppDirs.VIDEOS_CACHE;
        return "$dir${id}_${erabaretaStream.resolution}.${erabaretaStream.formatSuffix}";
      }

      final erabaretaStreamSizeInBytes = erabaretaStream.sizeInBytes ?? 0;
      int downloadStartRange = 0;

      final file = await File(getVPath(true)).create(); // retrieving the temp file (or creating a new one).
      final initialFileSizeOnDisk = await file.sizeInBytes(); // fetching current size to be used as a range bytes for download request
      onInitialFileSize(initialFileSizeOnDisk);
      // only download if the download is incomplete, useful sometimes when file 'moving' fails.
      if (initialFileSizeOnDisk < erabaretaStreamSizeInBytes) {
        downloadStartRange = initialFileSizeOnDisk;

        downloadClient = Dio(BaseOptions(headers: {HttpHeaders.rangeHeader: 'bytes=$downloadStartRange-'}));
        final downloadStream = await downloadClient!
            .get<ResponseBody>(
              erabaretaStream.url ?? '',
              options: Options(responseType: ResponseType.stream),
            )
            .then((value) => value.data);

        if (downloadStream != null) {
          final fileStream = file.openWrite(mode: FileMode.append);
          await for (final data in downloadStream.stream) {
            fileStream.add(data);
            downloadingStream(data);
          }
          await fileStream.flush();
          await fileStream.close(); // closing file.
        }
      }

      // ------------------------------------

      // -- ensuring the file is downloaded completely before moving.
      final fileStats = await file.stat();
      const allowance = 1024; // 1KB allowance
      if (fileStats.size >= erabaretaStreamSizeInBytes - allowance) {
        final newfile = await file.rename(getVPath(false));
        dv = NamidaVideo(
          path: newfile.path,
          ytID: id,
          nameInCache: newfile.path.getFilenameWOExt,
          height: erabaretaStream.height ?? 0,
          width: erabaretaStream.width ?? 0,
          sizeInBytes: erabaretaStreamSizeInBytes,
          frameratePrecise: erabaretaStream.fps?.toDouble() ?? 0.0,
          creationTimeMS: 0, // TODO: get using metadata
          durationMS: erabaretaStream.durationMS ?? 0,
          bitrate: erabaretaStream.bitrate ?? 0,
        );
      }
    } catch (e) {
      printy('Error Downloading YT Video: $e', isError: true);
    }

    return dv;
  }

  void dispose({bool closeCurrentDownloadClient = true, bool closeAllClients = false}) {
    if (closeCurrentDownloadClient) {
      downloadClient?.close();
      downloadClient = null;
    }

    if (closeAllClients) {
      for (final c in _downloadClientsMap.values) {
        c.close();
      }
    }
  }
}

extension _IDToUrlConvert on String {
  String toYTUrl() => 'https://www.youtube.com/watch?v=$this';
}
