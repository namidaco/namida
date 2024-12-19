part of '../youtube_info_controller.dart';

class _MissingInfoController {
  _MissingInfoController();

  final _infoCache = <String, MissingVideoInfo?>{};

  Future<MissingVideoInfo?> fetchMissingInfo(String videoId) async {
    if (_infoCache[videoId] != null) return _infoCache[videoId]!;

    VideoController.inst.videosPriorityManager.setVideoPriority(videoId, CacheVideoPriority.VIP);
    return _infoCache[videoId] ??= await YoutiPie.missingInfo.fetchMissingInfo(videoId: videoId);
  }

  Future<MissingVideoInfo?> fetchMissingInfoCache(String videoId) async {
    if (_infoCache[videoId] != null) return _infoCache[videoId]!;

    final cache = YoutiPie.cacheBuilder.forMissingInfo(videoId: videoId);
    return _infoCache[videoId] ??= await cache.readAsync();
  }

  MissingVideoInfo? fetchMissingInfoCacheSync(String videoId) {
    if (_infoCache[videoId] != null) return _infoCache[videoId]!;

    final cache = YoutiPie.cacheBuilder.forMissingInfo(videoId: videoId);
    return _infoCache[videoId] ??= cache.read();
  }

  Future<File?> fetchMissingThumbnail(String videoId, {bool forceRequest = false}) async {
    VideoController.inst.videosPriorityManager.setVideoPriority(videoId, CacheVideoPriority.VIP);
    final thumbFile = ThumbnailManager.inst.imageUrlToCacheFile(id: videoId, url: null, type: ThumbnailType.video, isTemp: false);
    if (thumbFile == null) return null; // shouldn't happen
    if (forceRequest == false && await thumbFile.exists()) return thumbFile;

    final bytes = await YoutiPie.missingInfo.fetchMissingThumbnail(videoId: videoId);
    if (bytes != null && bytes.isNotEmpty) {
      await thumbFile.create(recursive: true);
      await thumbFile.writeAsBytes(bytes);
      return thumbFile;
    }
    return null;
  }
}
