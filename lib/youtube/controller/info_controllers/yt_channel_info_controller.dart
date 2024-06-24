part of namidayoutubeinfo;

class _ChannelInfoController {
  const _ChannelInfoController();

  Future<YoutiPieChannelPageResult?> fetchChannelInfo({required String? channelId, String? handle, ExecuteDetails? details}) async {
    final res = await YoutiPie.channel.fetchChannelPage(channelId: channelId, handle: handle, details: details);
    return res;
  }

  YoutiPieChannelPageResult? fetchChannelInfoSync(String channelId) {
    final res = YoutiPie.cacheBuilder.forChannel(channelId: channelId);
    return res.read();
  }

  Future<ChannelPageAbout?> fetchChannelAbout({required YoutiPieChannelPageResult channel}) async {
    final res = await YoutiPie.channel.fetchChannelAbout(channel: channel);
    return res;
  }

  ChannelPageAbout? fetchChannelAboutSync(String channelId) {
    final res = YoutiPie.cacheBuilder.forChannelAbout(channelId: channelId);
    return res.read();
  }

  Future<YoutiPieChannelTabVideosResult?> fetchChannelTab({required String channelId, required ChannelTab tab, ExecuteDetails? details}) async {
    final res = await YoutiPie.channel.fetchChannelTab(channelId: channelId, tab: tab, details: details);
    if (res is YoutiPieChannelTabVideosResult) return res;
    return null;
  }

  YoutiPieChannelTabVideosResult? fetchChannelTabSync({required String channelId, required ChannelTab tab}) {
    final res = YoutiPie.cacheBuilder.forChannelTab(channelId: channelId, tab: tab);
    return res.read();
  }
}
