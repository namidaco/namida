// ignore_for_file: library_private_types_in_public_api, depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:newpipeextractor_dart/utils/httpClient.dart';
import 'package:queue/queue.dart';

import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';

class ThumbnailManager {
  static final ThumbnailManager inst = ThumbnailManager._internal();
  ThumbnailManager._internal();

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
  }) {
    String? finalUrl = url;
    final imageUrl = finalUrl?.split('i.ytimg.com/vi/');
    if (imageUrl != null && imageUrl.length > 1) {
      finalUrl = imageUrl.last.split('?').first.replaceAll('/', '_');
    } else {
      if (finalUrl != null) finalUrl = '${finalUrl.split('/').last.split('=').first}.png';
    }

    final file = id != null && id != ''
        ? File("${AppDirs.YT_THUMBNAILS}$id.png")
        : finalUrl == null
            ? null
            : File("${AppDirs.YT_THUMBNAILS_CHANNELS}$finalUrl");

    return file;
  }

  static Future<String?> _getChannelAvatarUrlIsolate(String channelId) async {
    final url = 'https://www.youtube.com/channel/$channelId?hl=en';
    final client = http.Client();
    final response = await client.get(Uri.parse(url), headers: ExtractorHttpClient.defaultHeaders);
    final raw = response.body;
    final s = parser.parse(raw).querySelector('meta[property="og:image"]')?.attributes['content'];
    client.close();
    return s;
  }

  File? getYoutubeThumbnailFromCacheSync({String? id, String? channelUrl}) {
    if (id == null && channelUrl == null) return null;

    final file = imageUrlToCacheFile(id: id, url: channelUrl);

    if (file != null && file.existsSync()) return file;
    return null;
  }

  Future<File?> _saveChannelThumbnailToStorage({
    required File file,
    required Uint8List? bytes,
  }) async {
    if (bytes != null) await file.writeAsBytes(bytes);
    return file;
  }

  Future<File?> saveThumbnailToStorage({
    required Uint8List? bytes,
    required String? videoPath,
    required bool isLocal,
    required String idOrFileNameWOExt,
    required bool isExtracted, // set to false if its a youtube thumbnail.
  }) async {
    if (bytes == null && videoPath == null) return null;

    final prefix = !isLocal && isExtracted ? 'EXT_' : '';
    final dir = isLocal ? AppDirs.THUMBNAILS : AppDirs.YT_THUMBNAILS;
    final file = File("$dir$prefix$idOrFileNameWOExt.png");
    if (bytes != null) {
      // if pure yt thumbnail delete the extracted version
      if (!isExtracted) {
        await File("${AppDirs.YT_THUMBNAILS}EXT_$idOrFileNameWOExt.png").deleteIfExists();
      }
      return await file.writeAsBytes(bytes);
    } else if (videoPath != null) {
      await NamidaFFMPEG.inst.extractVideoThumbnail(videoPath: videoPath, thumbnailSavePath: file.path);
      final fileExists = await file.exists();
      return fileExists ? file : null;
    }
    return null;
  }

  Future<File?> getYoutubeThumbnailAndCache({
    String? id,
    String? channelUrlOrID,
    bool isImportantInCache = true,
    FutureOr<void> Function()? beforeFetchingFromInternet,
    bool hqChannelImage = false,
  }) async {
    if (id == null && channelUrlOrID == null) return null;

    void trySavingLastAccessed(File? file) async {
      final time = isImportantInCache ? DateTime.now() : DateTime(1970);
      try {
        if (file != null && await file.exists()) await file.setLastAccessed(time);
      } catch (_) {}
    }

    final file = imageUrlToCacheFile(id: id, url: channelUrlOrID);
    if (file == null) return null;

    if (file.existsSync() == true) {
      _printie('Downloading Thumbnail Already Exists');
      trySavingLastAccessed(file);
      return file;
    }

    _printie('Downloading Thumbnail Started');
    await beforeFetchingFromInternet?.call();

    if (channelUrlOrID != null && hqChannelImage) {
      final res = await _getChannelAvatarUrlIsolate.thready(channelUrlOrID);
      if (res != null) channelUrlOrID = res;
    }

    final bytes = await getYoutubeThumbnailAsBytes(youtubeId: id, url: channelUrlOrID, keepInMemory: false);
    _printie('Downloading Thumbnail Finished with ${bytes?.length} bytes');

    final savedFile = (id != null
            ? saveThumbnailToStorage(
                videoPath: null,
                bytes: bytes,
                isLocal: false,
                idOrFileNameWOExt: id,
                isExtracted: false,
              )
            : _saveChannelThumbnailToStorage(
                file: file,
                bytes: bytes,
              ))
        .then((savedFile) {
      trySavingLastAccessed(savedFile);
    });

    return savedFile;
  }

  void closeThumbnailClients(List<String?> links) {
    links.loop((link, _) {
      _runningRequestsClients[link]?.close(force: true);
      _runningRequestsClients.remove(link);
    });
  }

  /// This prevents re-requesting the same url.
  static final _runningRequestsClients = <String, Dio>{};
  static final _runningRequestsMap = <String, Completer<Uint8List?>?>{};

  final _thumbQueue = Queue(parallel: 4);
  Future<Uint8List?> getYoutubeThumbnailAsBytes({
    String? youtubeId,
    String? url,
    bool lowerResYTID = false,
    required bool keepInMemory,
  }) async {
    if (youtubeId == null && url == null) return null;

    final links = url != null
        ? [url]
        : lowerResYTID
            ? [YTThumbnail(youtubeId!).mqdefault]
            : YTThumbnail(youtubeId!).allQualitiesByHighest;

    for (final link in links) {
      if (_runningRequestsMap[link] != null) {
        _printie('getYoutubeThumbnailAsBytes: Same link is being requested right now, ignoring');
        return await _runningRequestsMap[link]!.future; // return and not continue, cuz if requesting hq image, continue will make it request lower one
      }

      _runningRequestsClients[link] = Dio();
      (Uint8List, int)? requestRes;

      // _runningRequestsMap.optimizedAdd([MapEntry(link, Completer<Uint8List?>())], 600); // most images are <~20kb so =12MB
      _runningRequestsMap[link] ??= Completer<Uint8List?>(); // 600 - most images are <~20kb so =12MB

      await _thumbQueue.add(() async {
        try {
          final client = _runningRequestsClients[link];
          if (client != null) {
            final res = await client.get<Uint8List?>(
              link,
              options: Options(responseType: ResponseType.bytes, validateStatus: (status) => true),
            );
            requestRes = (res.data ?? Uint8List.fromList([]), res.statusCode ?? 404);
          }
        } catch (e) {
          _printie('getYoutubeThumbnailAsBytes: Error getting thumbnail at $link, trying again with lower quality.\n$e', isError: true);
        }
      });

      // -- validation --
      final req = requestRes;
      if (req != null) {
        final data = req.$1;
        if (data.isNotEmpty && req.$2 != 404) {
          _runningRequestsMap[link]?.completeIfWasnt(data);
          if (!keepInMemory) _runningRequestsMap.remove(link);
          closeThumbnailClients([link]);
          return data;
        } else {
          _runningRequestsMap[link]?.completeIfWasnt(null);
          _runningRequestsMap.remove(link); // removing since it failed
          closeThumbnailClients([link]);
          continue;
        }
      }
    }
    return null;
  }

  // static Future<(Uint8List, int)> _httpGetIsolate(String link) async {
  //   final requestRes = await http.get(Uri.parse(link));
  //   return (requestRes.bodyBytes, requestRes.statusCode);
  // }

  void _printie(
    dynamic message, {
    bool isError = false,
    bool dumpshit = false,
  }) {
    if (logsEnabled) printy(message, isError: isError, dumpshit: dumpshit);
  }

  bool logsEnabled = false;
}
