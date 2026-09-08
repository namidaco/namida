// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

import 'package:rhttp/rhttp.dart';
import 'package:youtipie/class/thumbnail.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/http_manager.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/download_task_base.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class ThumbnailManager {
  static final ThumbnailManager inst = ThumbnailManager._internal();
  ThumbnailManager._internal();

  final _thumbnailDownloader = _YTThumbnailDownloadManager();

  static Future<String> getPathToYTImage(String? id) async {
    String getPath(String prefix) => "${AppDirs.YT_THUMBNAILS}$prefix$id.png";

    final path = getPath('');
    if (await File(path).exists()) {
      return path;
    }

    return getPath('EXT_');
  }

  File? imageUrlToCacheFile({
    required String? id,
    required String? url,
    required ThumbnailType type,
    String? symlinkId,
    bool isTemp = false,
  }) {
    final dirPrefix = isTemp ? 'temp${Platform.pathSeparator}' : '';

    // for some weird reason, sometimes the supplied id is sus
    if (id != null && id.length != 11) {
      url = id;
      id = null;
    }

    final goodId = id != null && id.isNotEmpty;
    if (goodId || type == ThumbnailType.video) {
      final innerDirPath = AppDirs.YT_THUMBNAILS;
      String? filename;
      if (symlinkId != null) {
        filename = symlinkId;
      } else if (goodId) {
        filename = '$id.png';
      } else if (url != null && isTemp) {
        try {
          int? indexStart;
          final index1try = url.indexOf('/vi/shorts/');
          if (index1try > -1) {
            indexStart = index1try + 11; // '/vi/shorts/'.length
          } else {
            final index2try = url.indexOf('/vi/');
            if (index2try > -1) {
              indexStart = index2try + 4; // '/vi/'.length
            }
          }
          if (indexStart != null) {
            filename = url.substring(indexStart, indexStart + 11); // custom urls like dAdjsaB_GKL_hqdefault.jpg
          } else {
            // -- just a backup
            bool isFirstMatch = false;
            filename = url.splitLastM(
              '/',
              onMatch: (part) {
                if (isFirstMatch) return part;
                isFirstMatch = true;
                return null;
              },
            );
            if (filename != null) filename = DownloadTaskFilename.cleanupFilename(filename, parentDirPath: innerDirPath);
          }
        } catch (_) {}
      }
      if (filename == null || filename.isEmpty) return null;
      return File("$innerDirPath$dirPrefix$filename");
    }
    String? finalUrl = url;
    final imageUrl = finalUrl?.split(RegExp(r'i\.ytimg\.com/vi.*?/'));
    if (imageUrl != null && imageUrl.length > 1) {
      finalUrl = imageUrl.last.splitFirst('?').replaceAll('/', '_');
    } else {
      if (finalUrl != null) finalUrl = '${finalUrl.splitLast('/')}.png'; // we need the quality after the =
    }

    if (finalUrl != null) {
      final innerDirPath = AppDirs.YT_THUMBNAILS_CHANNELS;
      finalUrl = DownloadTaskFilename.cleanupFilename(finalUrl, parentDirPath: innerDirPath);
      return File("$innerDirPath$dirPrefix${symlinkId ?? finalUrl}");
    }

    return null;
  }

  Future<File?> extractVideoThumbnailAndSave({
    required String videoPath,
    required bool isLocal,
    required String idOrFileNameWithExt,
    required bool forceExtract,
    String? cacheDirPath,
  }) async {
    final prefix = !isLocal ? 'EXT_' : '';
    final dir = cacheDirPath ?? (isLocal ? AppDirs.THUMBNAILS : AppDirs.YT_THUMBNAILS);
    if (!idOrFileNameWithExt.endsWith('.png')) idOrFileNameWithExt = '$idOrFileNameWithExt.png';
    final file = File("$dir$prefix$idOrFileNameWithExt");
    if (forceExtract == false && await file.exists()) return file;
    await NamidaFFMPEG.inst.extractVideoThumbnail(videoPath: videoPath, thumbnailSavePath: file.path);
    final fileExists = await file.exists();
    return fileExists ? file : null;
  }

  Future<File?> getYoutubeThumbnailFromCache({
    String? id,
    String? customUrl,
    bool? isTemp = false,
    required ThumbnailType type,
  }) async {
    if (id == null && customUrl == null) return null;

    if (isTemp == null) {
      // -- check for both if temp == null
      final file1 = imageUrlToCacheFile(id: id, url: customUrl, isTemp: false, type: type);
      if (file1 != null && await file1.exists()) return file1;
      final file2 = imageUrlToCacheFile(id: id, url: customUrl, isTemp: true, type: type);
      if (file2 != null && await file2.exists()) return file2;
      return null;
    }

    final file = imageUrlToCacheFile(id: id, url: customUrl, isTemp: isTemp, type: type);
    if (file != null && await file.exists()) return file;
    return null;
  }

  Future<File?> getYoutubeThumbnailAndCache({
    String? id,
    String? customUrl,
    bool isImportantInCache = true,
    String? symlinkId,
    required ThumbnailType type,
  }) async {
    if (id == null && customUrl == null) return null;

    final isTemp = isImportantInCache ? false : true;

    final file = imageUrlToCacheFile(id: id, url: customUrl, isTemp: isTemp, type: type);
    if (file == null) return null;
    if (await file.exists()) return file;

    if (symlinkId != null) {
      try {
        final symlinkfile = imageUrlToCacheFile(id: id, url: customUrl, symlinkId: symlinkId, isTemp: isTemp, type: type);
        if (symlinkfile != null && await symlinkfile.exists()) {
          final targetFilePath = await Link.fromUri(symlinkfile.uri).target();
          final targetFile = File(targetFilePath);
          if (await targetFile.exists()) return targetFile;
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
      lowerResYTID: false,
    );

    if (downloaded != null) return downloaded;

    if (isTemp == false) {
      // return the low res if high res failed
      final filetemp = imageUrlToCacheFile(id: id, url: customUrl, isTemp: true, type: type);
      if (filetemp != null && await filetemp.exists()) return filetemp;
    }

    return null;
  }

  Future<File?> getLowResYoutubeVideoThumbnail(String? videoId, {String? symlinkId, bool useHighQualityIfEnoughListens = true, VoidCallback? onNotFound}) async {
    if (videoId == null) return null;

    bool isTemp = true;
    if (useHighQualityIfEnoughListens) {
      final listens = YoutubeHistoryController.inst.topTracksMapListens.value[videoId]?.length ?? 0;
      if (listens >= 10) isTemp = false; // fetch full res if listens >= 10
    }
    final bool lowerResYTID = isTemp;

    final file = imageUrlToCacheFile(id: videoId, url: null, isTemp: isTemp, type: ThumbnailType.video);
    if (file == null) return null;
    final downloaded = await _getYoutubeThumbnail(
      itemId: videoId,
      urls: null,
      isVideo: true,
      isImportantInCache: false,
      destinationFile: file,
      symlinkId: symlinkId,
      isTemp: isTemp,
      lowerResYTID: lowerResYTID,
    );

    return downloaded;
  }

  bool isThumbnailNotFound(String itemId) => _thumbnailDownloader.isNotFound(itemId);

  void closeThumbnailClients(String itemId, bool isTemp) {
    _thumbnailDownloader.stopDownload(id: itemId, isTemp: isTemp);
  }

  Future<File?> _getYoutubeThumbnail({
    required String itemId,
    required List<String>? urls,
    required bool isVideo,
    required bool lowerResYTID,
    required bool isTemp,
    required bool isImportantInCache,
    required File destinationFile,
    required String? symlinkId,
  }) async {
    final links = <String>[];
    if (urls != null) links.addAll(urls);
    if (isVideo) {
      final yth = lowerResYTID ? YoutiPieVideoThumbnail.mixLow(itemId) : YoutiPieVideoThumbnail.mix(itemId);
      links.addAll(yth);
    }
    if (links.isEmpty) return null;

    return _thumbnailDownloader.download(
      urls: links,
      id: itemId,
      isImportantInCache: isImportantInCache,
      destinationFile: destinationFile,
      symlinkId: symlinkId,
      isTemp: isTemp,
    );
  }
}

class _VideoIdAndTemp {
  final String videoId;
  final bool isTemp;

  const _VideoIdAndTemp({
    required this.videoId,
    required this.isTemp,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _VideoIdAndTemp) return false;
    return other.videoId == videoId && other.isTemp == isTemp;
  }

  @override
  int get hashCode => videoId.hashCode ^ isTemp.hashCode;
}

class _ActiveDownload {
  final int token;
  final Completer<File?> completer = Completer<File?>();
  int waiters = 1;

  _ActiveDownload(this.token);
}

class _YTThumbnailDownloadManager with PortsProvider<SendPort> {
  final _activeDownloads = <_VideoIdAndTemp, _ActiveDownload>{};
  final _notFoundThumbnails = <String>{}; // item id
  final _tokens = IsolateMessageTokenWrapper.create();

  bool isNotFound(String id) => _notFoundThumbnails.contains(id);

  Future<File?> download({
    required List<String> urls,
    required String id,
    required bool isTemp,
    required bool isImportantInCache,
    required File destinationFile,
    required String? symlinkId,
  }) async {
    if (_notFoundThumbnails.contains(id)) return null;

    final mapKey = _VideoIdAndTemp(videoId: id, isTemp: isTemp);
    var active = _activeDownloads[mapKey];
    if (active != null) {
      active.waiters++;
      final res = await active.completer.future;
      active.waiters--;
      return res;
    }

    active = _activeDownloads[mapKey] = _ActiveDownload(_tokens.getToken());
    final p = {
      'token': active.token,
      'urls': urls,
      'id': id,
      'isImportantInCache': isImportantInCache,
      'isTemp': isTemp,
      'destinationFile': destinationFile,
      'symlinkId': ?symlinkId,
    };
    try {
      if (!isInitialized) await initialize();
      await sendPort(p);
    } catch (_) {
      _onFileFinish(mapKey, active.token, null, false);
    }
    final res = await active.completer.future;
    active.waiters--;
    return res;
  }

  void stopDownload({required String id, required bool isTemp}) {
    final mapKey = _VideoIdAndTemp(videoId: id, isTemp: isTemp);
    final active = _activeDownloads[mapKey];
    if (active == null || active.waiters > 1) return;
    _onFileFinish(mapKey, active.token, null, false);
    sendPort({'id': id, 'isTemp': isTemp, 'token': active.token, 'stop': true});
  }

  static Future<void> _prepareDownloadResources(SendPort sendPort) async {
    await Rhttp.init();
    final httpManager = HttpMultiRequestManager.createSync();

    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    final activeRequests = <int, _IsolateThumbRequest>{}; // token

    const bool deleteOldExtracted = true;
    final sep = Platform.pathSeparator;

    void updateLastAccessed(File file) async {
      try {
        await file.setLastAccessed(DateTime.now());
      } catch (_) {}
    }

    Future<void> onThumbRequest(Map p) async {
      final token = p['token'] as int;

      if (p['stop'] == true) {
        activeRequests[token]?.cancel();
        return;
      }

      final id = p['id'] as String;
      final urls = p['urls'] as List<String>;
      final isImportantInCache = p['isImportantInCache'] as bool;
      final isTemp = p['isTemp'] as bool;
      final destinationFile = p['destinationFile'] as File;
      final symlinkId = p['symlinkId'] as String?;

      if (destinationFile.existsSync()) {
        if (isImportantInCache) updateLastAccessed(destinationFile);
        return sendPort.send(_YTThumbnailDownloadResult(itemId: id, isTemp: isTemp, token: token, file: destinationFile, notfound: false));
      }

      final request = _IsolateThumbRequest();
      activeRequests[token] = request;

      final tempFile = File("${destinationFile.path}.$token.temp");
      File? downloaded;
      int notFoundCount = 0;

      try {
        tempFile.createSync(recursive: true);
        for (final url in urls) {
          if (request.cancelled) break;
          downloaded = await httpManager.executeQueued((requester) async {
            if (request.cancelled) return null;
            IOSink? sink;
            try {
              final response = await requester.getStream(url, cancelToken: request.cancelToken);
              sink = tempFile.openWrite(mode: FileMode.writeOnly);
              await sink.addStream(response.body);
              await sink.close();
              sink = null;
              return tempFile.renameSync(destinationFile.path);
            } on RhttpStatusCodeException catch (e) {
              if (e.statusCode == 404) notFoundCount++;
            } catch (_) {}
            if (sink != null) {
              try {
                await sink.close();
              } catch (_) {}
            }
            return null;
          });
          if (downloaded != null) break;
        }
      } catch (_) {}

      activeRequests.remove(token);

      if (downloaded == null) {
        tempFile.delete().catchError((_) => File(''));
      } else {
        if (symlinkId != null) {
          Link("${downloaded.parent.path}$sep$symlinkId").create(downloaded.path).catchError((_) => Link(''));
        }
        if (deleteOldExtracted) {
          File("${destinationFile.parent.path}${sep}EXT_${destinationFile.path.getFilename}").delete().catchError((_) => File(''));
        }
      }

      sendPort.send(
        _YTThumbnailDownloadResult(
          itemId: id,
          isTemp: isTemp,
          token: token,
          file: downloaded,
          notfound: downloaded == null && urls.isNotEmpty && notFoundCount == urls.length,
        ),
      );
    }

    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) {
      if (PortsProvider.isDisposeMessage(p)) {
        for (final request in activeRequests.values) {
          request.cancel();
        }
        activeRequests.clear();
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
      final mapKey = _VideoIdAndTemp(videoId: result.itemId, isTemp: result.isTemp);
      _onFileFinish(mapKey, result.token, result.file, result.notfound);
    }
  }

  @override
  IsolateFunctionReturnBuild<SendPort> isolateFunction(SendPort port) {
    return IsolateFunctionReturnBuild(_prepareDownloadResources, port);
  }

  void _onFileFinish(_VideoIdAndTemp mapKey, int token, File? downloadedFile, bool notfound) {
    final active = _activeDownloads[mapKey];
    if (active == null || active.token != token) return;
    if (notfound) _notFoundThumbnails.add(mapKey.videoId);
    _activeDownloads.remove(mapKey);
    active.completer.completeIfWasnt(downloadedFile);
  }
}

class _IsolateThumbRequest {
  final cancelToken = CancelToken();
  bool cancelled = false;

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    cancelToken.cancel();
  }
}

class _YTThumbnailDownloadResult {
  final String itemId;
  final bool isTemp;
  final int token;
  final File? file;
  final bool notfound;

  const _YTThumbnailDownloadResult({
    required this.itemId,
    required this.isTemp,
    required this.token,
    required this.file,
    required this.notfound,
  });
}
