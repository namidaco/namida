// ignore_for_file: library_private_types_in_public_api, depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:newpipeextractor_dart/utils/httpClient.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/http_manager.dart';
import 'package:namida/class/http_response_wrapper.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

class ThumbnailManager {
  static final ThumbnailManager inst = ThumbnailManager._internal();
  ThumbnailManager._internal();

  final _thumbnailDownloader = _YTThumbnailDownloadManager();

  static String getPathToYTImage(String? id) {
    String getPath(String prefix) => "${AppDirs.YT_THUMBNAILS}$prefix$id.png";

    final path = getPath('');
    if (File(path).existsSync()) {
      return path;
    }

    return getPath('EXT_');
  }

  File? imageUrlToCacheFile({
    required String? id,
    required String? url,
    bool isTemp = false,
  }) {
    String? finalUrl = url;
    final imageUrl = finalUrl?.split('i.ytimg.com/vi/');
    if (imageUrl != null && imageUrl.length > 1) {
      finalUrl = imageUrl.last.split('?').first.replaceAll('/', '_');
    } else {
      if (finalUrl != null) finalUrl = '${finalUrl.split('/').last.split('=').first}.png';
    }

    final dirPrefix = isTemp ? 'temp/' : '';

    final file = id != null && id != ''
        ? File("${AppDirs.YT_THUMBNAILS}$dirPrefix$id.png")
        : finalUrl == null
            ? null
            : File("${AppDirs.YT_THUMBNAILS_CHANNELS}$dirPrefix$finalUrl");

    return file;
  }

  static Future<String?> _getChannelAvatarUrlIsolate(String channelId) async {
    final url = 'https://www.youtube.com/channel/$channelId?hl=en';
    final client = http.Client();
    try {
      final response = await client.get(Uri.parse(url), headers: ExtractorHttpClient.defaultHeaders);
      final raw = response.body;
      final s = parser.parse(raw).querySelector('meta[property="og:image"]')?.attributes['content'];
      return s;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  File? getYoutubeThumbnailFromCacheSync({String? id, String? channelUrl, bool isTemp = false}) {
    if (id == null && channelUrl == null) return null;

    final file = imageUrlToCacheFile(id: id, url: channelUrl, isTemp: isTemp);

    if (file != null && file.existsSync()) return file;
    return null;
  }

  Future<File?> extractVideoThumbnailAndSave({
    required String? videoPath,
    required bool isLocal,
    required String idOrFileNameWOExt,
    required bool isExtracted, // set to false if its a youtube thumbnail.
  }) async {
    if (videoPath == null) return null;

    final prefix = !isLocal && isExtracted ? 'EXT_' : '';
    final dir = isLocal ? AppDirs.THUMBNAILS : AppDirs.YT_THUMBNAILS;
    final file = File("$dir$prefix$idOrFileNameWOExt.png");
    await NamidaFFMPEG.inst.extractVideoThumbnail(videoPath: videoPath, thumbnailSavePath: file.path);
    final fileExists = await file.exists();
    return fileExists ? file : null;
  }

  Future<File?> getYoutubeThumbnailAndCache({
    String? id,
    String? channelUrlOrID,
    bool isImportantInCache = true,
    bool hqChannelImage = false,
    VoidCallback? onNotFound,
  }) async {
    if (id == null && channelUrlOrID == null) return null;

    final isTemp = isImportantInCache ? false : true;

    final file = imageUrlToCacheFile(id: id, url: channelUrlOrID, isTemp: isTemp);
    if (file == null) return null;

    if (channelUrlOrID != null && hqChannelImage) {
      final res = await _getChannelAvatarUrlIsolate.thready(channelUrlOrID);
      if (res != null) channelUrlOrID = res;
    }

    final itemId = file.path.getFilenameWOExt;
    final downloaded = await _getYoutubeThumbnail(
      itemId: itemId,
      urls: channelUrlOrID == null ? null : [channelUrlOrID],
      isVideo: id != null,
      isImportantInCache: isImportantInCache,
      destinationFile: file,
      isTemp: isTemp,
      forceRequest: false,
      lowerResYTID: false,
      onNotFound: onNotFound,
    );

    return downloaded;
  }

  Future<File?> getLowResYoutubeVideoThumbnail(String? videoId, {bool useHighQualityIfEnoughListens = true, VoidCallback? onNotFound}) async {
    if (videoId == null) return null;

    bool isTemp = true;
    if (useHighQualityIfEnoughListens) {
      final listens = YoutubeHistoryController.inst.topTracksMapListens[videoId]?.length ?? 0;
      if (listens >= 10) isTemp = false; // fetch full res if listens >= 10
    }
    final bool lowerResYTID = isTemp;

    final file = imageUrlToCacheFile(id: videoId, url: null, isTemp: isTemp);
    if (file == null) return null;
    final downloaded = await _getYoutubeThumbnail(
      itemId: videoId,
      isVideo: true,
      isImportantInCache: false,
      destinationFile: file,
      isTemp: isTemp,
      forceRequest: false,
      lowerResYTID: lowerResYTID,
      onNotFound: onNotFound,
    );

    return downloaded;
  }

  void closeThumbnailClients(String itemId) {
    _thumbnailDownloader.stopDownload(id: itemId);
  }

  Future<File?> _getYoutubeThumbnail({
    required String itemId,
    List<String>? urls,
    required bool isVideo,
    required bool lowerResYTID,
    required bool isTemp,
    required bool forceRequest,
    required bool isImportantInCache,
    required File destinationFile,
    required VoidCallback? onNotFound,
  }) async {
    final links = <String>[];
    if (isVideo && (urls == null || urls.isEmpty)) {
      final yth = YTThumbnail(itemId);
      if (lowerResYTID) {
        links.addAll(yth.allQualitiesExceptHighest);
      } else {
        links.addAll(yth.allQualitiesByHighest);
      }
    }
    if (urls != null) links.addAll(urls);
    if (links.isEmpty) return null;

    final downloaded = await _thumbnailDownloader.download(
      urls: links,
      id: itemId,
      forceRequest: forceRequest,
      isImportantInCache: isImportantInCache,
      destinationFile: destinationFile,
      isTemp: isTemp,
      onNotFound: onNotFound,
    );
    return downloaded;
  }
}

class _YTThumbnailDownloadManager with PortsProvider<SendPort> {
  final _downloadCompleters = <String, Completer<File?>?>{}; // item id
  final _shouldRetry = <String, bool>{}; // item id
  final _notFoundThumbnails = <String, bool?>{}; // item id

  Future<File?> download({
    required List<String> urls,
    required String id,
    bool forceRequest = false,
    required bool isTemp,
    required bool isImportantInCache,
    required File destinationFile,
    required VoidCallback? onNotFound,
  }) async {
    if (_notFoundThumbnails[id] == true) {
      if (onNotFound != null) onNotFound();
      return null;
    }
    if (forceRequest == false && _downloadCompleters[id] != null) {
      final res = await _downloadCompleters[id]!.future;
      if (res != null || _shouldRetry[id] != true) {
        return res;
      }
    }
    _downloadCompleters[id]?.completeIfWasnt(null);
    _downloadCompleters[id] = Completer<File?>();

    final p = {
      'urls': urls,
      'id': id,
      'forceRequest': forceRequest,
      'isImportantInCache': isImportantInCache,
      'isTemp': isTemp,
      'destinationFile': destinationFile,
    };
    await initialize();
    await sendPort(p);
    final res = await _downloadCompleters[id]?.future;

    if (_notFoundThumbnails[id] == true) {
      if (onNotFound != null) onNotFound();
      return null;
    }
    return res;
  }

  Future<void> stopDownload({required String? id}) async {
    if (id == null) return;
    _onFileFinish(id, null, null, true);
    final p = {'id': id, 'stop': true};
    await sendPort(p);
  }

  static Future<void> _prepareDownloadResources(SendPort sendPort) async {
    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    final httpManager = HttpMultiRequestManager();
    final requesters = <String, Map<String, HttpClientWrapper>?>{}; // itemId: {urlPath: HttpClientWrapper}

    const bool deleteOldExtracted = true;

    void updateLastAccessed(File file) async {
      try {
        await file.setLastAccessed(DateTime.now());
      } catch (_) {}
    }

    Future<void> onThumbRequest(Map p) async {
      final stop = p['stop'] as bool?;
      final id = p['id'] as String;

      if (stop == true) {
        final requestersForId = requesters[id]?.values;
        if (requestersForId != null) {
          for (final requester in requestersForId) {
            requester.close();
          }
          requesters[id] = null;
        }
      } else {
        final urls = p['urls'] as List<String>;
        final forceRequest = p['forceRequest'] as bool? ?? false;
        final isImportantInCache = p['isImportantInCache'] as bool? ?? false;
        final isTemp = p['isTemp'] as bool? ?? false;
        final destinationFile = p['destinationFile'] as File;

        if (forceRequest == true && destinationFile.existsSync()) {
          final res = _YTThumbnailDownloadResult(
            url: null,
            urlPath: null,
            itemId: id,
            file: destinationFile,
            isTempFile: isTemp,
            aborted: false,
            notfound: false,
          );
          if (isImportantInCache) updateLastAccessed(destinationFile);
          return sendPort.send(res);
        }

        requesters[id] ??= {};
        for (final url in urls) {
          final urlPath = url.substring(url.lastIndexOf('/') + 1);
          requesters[id]?[urlPath] = HttpClientWrapper();

          final destinationFileTemp = File("${destinationFile.path}.temp");
          destinationFileTemp.createSync(recursive: true);
          final fileStream = destinationFileTemp.openWrite(mode: FileMode.write);
          final downloadedRes = await httpManager.executeQueued(() async {
            final requester = requesters[id]?[urlPath];

            Future<void> onDownloadFinish() async {
              try {
                requester?.close();
                requesters[id] = null;
              } catch (_) {}
              try {
                await fileStream.flush();
                await fileStream.close(); // closing file.
              } catch (_) {}
              destinationFileTemp.delete().catchError((_) => File(''));
            }

            if (requester == null || requester.isClosed) {
              // -- client closed, return true to break the loop
              onDownloadFinish();
              final res = _YTThumbnailDownloadResult(url: url, urlPath: urlPath, itemId: id, file: destinationFile, isTempFile: isTemp, aborted: true, notfound: null);
              return res;
            }

            try {
              final response = await requester.getUrl(Uri.parse(url));
              final bool notfound = response.statusCode == 404;
              File? newFile;
              if (!notfound) {
                final downloadStream = response.asBroadcastStream();
                await fileStream.addStream(downloadStream);
                newFile = destinationFileTemp.renameSync(destinationFile.path); // rename .temp
                if (deleteOldExtracted) {
                  File("${destinationFile.parent}/EXT_${destinationFile.path.getFilename}").delete().catchError((_) => File(''));
                }
              }

              final res = _YTThumbnailDownloadResult(url: url, urlPath: urlPath, itemId: id, file: newFile, isTempFile: isTemp, aborted: false, notfound: notfound);
              return res;
            } catch (_) {
              return null;
            } finally {
              onDownloadFinish();
            }
          });

          if (downloadedRes != null) {
            sendPort.send(downloadedRes); // break loop and return
            return;
          }
        }

        final res = _YTThumbnailDownloadResult(url: null, urlPath: null, itemId: id, file: null, isTempFile: isTemp, aborted: true, notfound: null);
        sendPort.send(res); // if nothing succeeded, return the latest failed res
      }
    }

    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) {
      if (PortsProvider.isDisposeMessage(p)) {
        for (final requestersMap in requesters.values) {
          final requestersToClose = requestersMap?.values;
          if (requestersToClose != null) {
            for (final requester in requestersToClose) {
              requester.close();
            }
          }
        }
        requesters.clear();
        httpManager.closeClients();
        recievePort.close();
        streamSub?.cancel();
        return;
      } else {
        onThumbRequest(p);
      }
    });

    sendPort.send(null); // prepared
  }

  @override
  void onResult(dynamic result) {
    if (result is _YTThumbnailDownloadResult) {
      _onFileFinish(result.itemId, result.file, result.notfound, result.aborted);
    }
  }

  @override
  IsolateFunctionReturnBuild<SendPort> isolateFunction(SendPort port) {
    return IsolateFunctionReturnBuild(_prepareDownloadResources, port);
  }

  void _onFileFinish(String itemId, File? downloadedFile, bool? notfound, bool aborted) {
    if (notfound != null) _notFoundThumbnails[itemId] = notfound;
    _downloadCompleters[itemId].completeIfWasnt(downloadedFile);
    _downloadCompleters[itemId] = null;
    _shouldRetry[itemId] = aborted;
  }
}

class _YTThumbnailDownloadResult {
  final String? url;
  final String? urlPath;
  final String itemId;
  final File? file;
  final bool isTempFile;
  final bool aborted;
  final bool? notfound;

  const _YTThumbnailDownloadResult({
    required this.url,
    required this.urlPath,
    required this.itemId,
    required this.file,
    required this.isTempFile,
    required this.aborted,
    required this.notfound,
  });
}
