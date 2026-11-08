part of '../youtube_info_controller.dart';

class _ChannelInfoController {
  const _ChannelInfoController();

  Future<YoutiPieChannelPageResult?> fetchChannelInfo({required String? channelId, String? handle, ExecuteDetails? details}) async {
    final res = await YoutiPie.channel.fetchChannelPage(channelId: channelId, handle: handle, details: details);
    YoutubeInfoController.memoryCache.channelThumbnails.add(res);
    return res;
  }

  Future<YoutiPieChannelPageResult?> fetchChannelInfoCache(String channelId) async {
    final res = await YoutiPie.cacheBuilder.forChannel(channelId: channelId).read();
    YoutubeInfoController.memoryCache.channelThumbnails.add(res);
    return res;
  }

  Future<ChannelPageAbout?> fetchChannelAbout({required YoutiPieChannelPageResult channel, ExecuteDetails? details}) async {
    final res = await YoutiPie.channel.fetchChannelAbout(channel: channel, details: details);
    return res;
  }

  Future<ChannelPageAbout?> fetchChannelAboutCache(String channelId) {
    return YoutiPie.cacheBuilder.forChannelAbout(channelId: channelId).read();
  }

  Future<YoutiPieChannelTabResult?> fetchChannelTab({required String channelId, required ChannelTab tab, YoutiPieItemsSort? sort, ExecuteDetails? details}) {
    return YoutiPie.channel.fetchChannelTab(channelId: channelId, tab: tab, sort: sort, details: details);
  }

  Future<YoutiPieChannelTabResult?> fetchChannelTabCache({required String channelId, required ChannelTab tab}) {
    return YoutiPie.cacheBuilder.forChannelTab(channelId: channelId, tab: tab).read();
  }
}
