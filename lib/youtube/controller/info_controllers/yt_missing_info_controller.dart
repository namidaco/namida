part of '../youtube_info_controller.dart';

class _MissingInfoController {
  _MissingInfoController();

  Future<MissingVideoInfo?> fetchMissingInfo(String videoId) {
    VideoController.inst.videosPriorityManager.setVideoPriority(videoId, CacheVideoPriority.VIP);
    return YoutiPie.missingInfo.fetchMissingInfo(videoId: videoId);
  }

  Future<MissingVideoInfo?> fetchMissingInfoCache(String videoId) {
    final cache = YoutiPie.cacheBuilder.forMissingInfo(videoId: videoId);
    return cache.readAsync();
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
