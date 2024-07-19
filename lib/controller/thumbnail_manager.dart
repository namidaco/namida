// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:youtipie/class/thumbnail.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/http_manager.dart';
import 'package:namida/class/http_response_wrapper.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
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
    String? symlinkId,
    bool isTemp = false,
  }) {
    final dirPrefix = isTemp ? 'temp/' : '';

    if (id != null && id.isNotEmpty) {
      return File("${AppDirs.YT_THUMBNAILS}$dirPrefix${symlinkId ?? '$id.png'}");
    }
    String? finalUrl = url;
    final imageUrl = finalUrl?.split('i.ytimg.com/vi/');
    if (imageUrl != null && imageUrl.length > 1) {
      finalUrl = imageUrl.last.splitFirst('?').replaceAll('/', '_');
    } else {
      if (finalUrl != null) finalUrl = '${finalUrl.splitLast('/')}.png'; // we need the quality after the =
    }

    if (finalUrl != null) {
      return File("${AppDirs.YT_THUMBNAILS_CHANNELS}$dirPrefix${symlinkId ?? finalUrl}");
    }

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

  File? getYoutubeThumbnailFromCacheSync({String? id, String? customUrl, bool isTemp = false}) {
    if (id == null && customUrl == null) return null;
    final file = imageUrlToCacheFile(id: id, url: customUrl, isTemp: isTemp);
    if (file != null && file.existsSync()) return file;
    return null;
  }

  Future<File?> getYoutubeThumbnailAndCache({
    String? id,
    String? customUrl,
    bool isImportantInCache = true,
    String? symlinkId,
  }) async {
    if (id == null && customUrl == null) return null;

    final isTemp = isImportantInCache ? false : true;

    final file = imageUrlToCacheFile(id: id, url: customUrl, isTemp: isTemp);
    if (file == null) return null;
    if (file.existsSync()) return file;

    if (symlinkId != null) {
      try {
        final symlinkfile = imageUrlToCacheFile(id: id, url: customUrl, symlinkId: symlinkId, isTemp: isTemp);
        if (symlinkfile != null && symlinkfile.existsSync()) {
          final targetFilePath = Link.fromUri(symlinkfile.uri).targetSync();
          final targetFile = File(targetFilePath);
          if (targetFile.existsSync()) return targetFile;
        }
      } catch (_) {}
    }

    final itemId = file.path.getFilenameWOExt;
    final downloaded = await _getYoutubeThumbnail(
      itemId: itemId,
      urls: customUrl == null ? null : [customUrl],
      isVideo: id != null,
      isImportantInCache: isImportantInCache,
      destinationFile: file,
      symlinkId: symlinkId,
      isTemp: isTemp,
      forceRequest: false,
      lowerResYTID: false,
    );

    return downloaded;
  }

  Future<File?> getLowResYoutubeVideoThumbnail(String? videoId, {String? symlinkId, bool useHighQualityIfEnoughListens = true, VoidCallback? onNotFound}) async {
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
      urls: null,
      isVideo: true,
      isImportantInCache: false,
      destinationFile: file,
      symlinkId: symlinkId,
      isTemp: isTemp,
      forceRequest: false,
      lowerResYTID: lowerResYTID,
    );

    return downloaded;
  }

  void closeThumbnailClients(String itemId) {
    _thumbnailDownloader.stopDownload(id: itemId);
  }

  Future<File?> _getYoutubeThumbnail({
    required String itemId,
    required List<String>? urls,
    required bool isVideo,
    required bool lowerResYTID,
    required bool isTemp,
    required bool forceRequest,
    required bool isImportantInCache,
    required File destinationFile,
    required String? symlinkId,
  }) async {
    final activeRequest = _thumbnailDownloader.resultForId(itemId);
    if (activeRequest != null) return activeRequest;

    final links = <String>[];
    if (isVideo) {
      final yth = lowerResYTID ? YoutiPieVideoThumbnail.mixLow(itemId) : YoutiPieVideoThumbnail.mix(itemId);
      links.addAll(yth);
    }
    if (urls != null) links.addAll(urls);
    if (links.isEmpty) return null;

    return _thumbnailDownloader.download(
      urls: links,
      id: itemId,
      forceRequest: forceRequest,
      isImportantInCache: isImportantInCache,
      destinationFile: destinationFile,
      symlinkId: symlinkId,
      isTemp: isTemp,
    );
  }
}

class _YTThumbnailDownloadManager with PortsProvider<SendPort> {
  final _downloadCompleters = <String, Completer<File?>?>{}; // item id
  final _requestsCountForId = <String, int>{}; // item id
  final _shouldRetry = <String, bool>{}; // item id
  final _notFoundThumbnails = <String, bool?>{}; // item id

  Future<File?>? resultForId(String id) => _downloadCompleters[id]?.future;

  Future<File?> download({
    required List<String> urls,
    required String id,
    bool forceRequest = false,
    required bool isTemp,
    required bool isImportantInCache,
    required File destinationFile,
    required String? symlinkId,
  }) async {
    if (_notFoundThumbnails[id] == true) return null;

    _requestsCountForId.update(id, (value) => value++, ifAbsent: () => 1);

    if (forceRequest == false && _downloadCompleters[id] != null) {
      final res = await _downloadCompleters[id]!.future;
      _requestsCountForId.update(id, (value) => value--);
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
      'symlinkId': symlinkId,
    };
    if (!isInitialized) await initialize();
    await sendPort(p);
    final res = await _downloadCompleters[id]?.future;

    _requestsCountForId.update(id, (value) => value--);
    return res;
  }

  Future<void> stopDownload({required String? id}) async {
    if (id == null) return;
    final otherActiveRequests = _requestsCountForId[id];
    if (otherActiveRequests == null || otherActiveRequests <= 1) {
      // -- only close if active requests only 1
      _onFileFinish(id, null, null, true);
      final p = {'id': id, 'stop': true};
      await sendPort(p);
    }
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
        final symlinkId = p['symlinkId'] as String?;

        if (forceRequest == false && destinationFile.existsSync()) {
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
        bool? notfound;
        _YTThumbnailDownloadResult? downloadedRes;
        final destinationFileTemp = File("${destinationFile.path}.temp");
        destinationFileTemp.createSync(recursive: true);
        final fileStream = destinationFileTemp.openWrite(mode: FileMode.write);

        Future<void> diposeIdRequestResources() async {
          if (requesters[id] != null) {
            for (final r in requesters[id]!.values) {
              r.close();
            }
            requesters[id] = null;
          }
          try {
            await fileStream.flush();
            await fileStream.close(); // closing file.
          } catch (_) {}
          destinationFileTemp.delete().catchError((_) => File(''));
        }

        for (final url in urls) {
          final urlPath = url.substring(url.lastIndexOf('/') + 1);
          requesters[id]?[urlPath] = HttpClientWrapper();

          downloadedRes = await httpManager.executeQueued(() async {
            final requester = requesters[id]?[urlPath];

            if (requester == null || requester.isClosed) {
              // -- client closed, return true to break the loop
              final res = _YTThumbnailDownloadResult(
                url: url,
                urlPath: urlPath,
                itemId: id,
                file: destinationFile,
                isTempFile: isTemp,
                aborted: true,
                notfound: null,
              );
              return res;
            }

            try {
              final response = await requester.getUrl(Uri.parse(url));
              notfound = response.statusCode == 404;
              if (notfound == true) throw Exception('not found'); // as if request failed.

              File? newFile;
              final downloadStream = response.asBroadcastStream();
              await fileStream.addStream(downloadStream);
              newFile = destinationFileTemp.renameSync(destinationFile.path); // rename .temp
              if (symlinkId != null) {
                Link("${newFile.parent.path}/$symlinkId").create(newFile.path).catchError((_) => Link(''));
              }
              if (deleteOldExtracted) {
                File("${destinationFile.parent.path}/EXT_${destinationFile.path.getFilename}").delete().catchError((_) => File(''));
              }

              final res = _YTThumbnailDownloadResult(
                url: url,
                urlPath: urlPath,
                itemId: id,
                file: newFile,
                isTempFile: isTemp,
                aborted: false,
                notfound: false,
              );
              return res;
            } catch (_) {
              return null;
            }
          });

          if (downloadedRes != null) break; // break loop
        }

        diposeIdRequestResources();

        downloadedRes ??= _YTThumbnailDownloadResult(
          url: null,
          urlPath: null,
          itemId: id,
          file: null,
          isTempFile: isTemp,
          aborted: true,
          notfound: notfound,
        );

        sendPort.send(downloadedRes);
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
    _shouldRetry[itemId] = aborted;
    _downloadCompleters[itemId]?.completeIfWasnt(downloadedFile);
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
