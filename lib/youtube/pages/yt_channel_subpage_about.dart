part of 'yt_channel_subpage.dart';

class YTChannelSubpageAbout extends StatefulWidget {
  final ScrollController scrollController;
  final String channelId;
  final YoutiPieChannelPageResult? Function() channelInfo;
  final Future<void> Function(Future<ChannelPageAbout?> Function({YoutiPieItemsSort? sort, bool forceRequest}) fetch) tabFetcher;
  final bool Function() shouldForceRequest;
  final void Function() onSuccessFetch;

  const YTChannelSubpageAbout({
    super.key,
    required this.scrollController,
    required this.channelId,
    required this.channelInfo,
    required this.tabFetcher,
    required this.onSuccessFetch,
    required this.shouldForceRequest,
  });

  @override
  State<YTChannelSubpageAbout> createState() => _YTChannelSubpageAboutState();
}

class _YTChannelSubpageAboutState extends State<YTChannelSubpageAbout> {
  ChannelPageAbout? _aboutResult;
  bool _isLoadingInitial = false;

  Future<ChannelPageAbout?> fetchAboutAndUpdate({YoutiPieItemsSort? sort, bool? forceRequest}) async {
    forceRequest ??= widget.shouldForceRequest();

    if (forceRequest == false && _aboutResult != null) return null; // prevent calling widget.onSuccessFetch

    final channelInfo = widget.channelInfo();
    if (channelInfo == null) return null;

    final aboutResult = await YoutubeInfoController.channel.fetchChannelAbout(
      channel: channelInfo,
      details: forceRequest ? ExecuteDetails.forceRequest() : null,
    );

    if (aboutResult != null) widget.onSuccessFetch();

    refreshState(() {
      if (aboutResult != null) _aboutResult = aboutResult;
      _isLoadingInitial = false;
    });

    return aboutResult;
  }

  @override
  void initState() {
    final aboutResultCache = YoutubeInfoController.channel.fetchChannelAboutSync(widget.channelId);
    if (aboutResultCache != null) {
      _aboutResult = aboutResultCache;
    } else {
      _isLoadingInitial = true;
    }

    if (widget.shouldForceRequest()) widget.tabFetcher(fetchAboutAndUpdate);
    super.initState();
  }

  String _getWorkingUrl(ChannelAboutLink aboutLink) {
    String url = aboutLink.link ?? aboutLink.linkText;
    if (!url.startsWith('https://')) url = 'https://$url';
    return url;
  }

  void _copyUrlToClipboard(String url) {
    Clipboard.setData(ClipboardData(text: url));
    snackyy(
      title: lang.COPIED_TO_CLIPBOARD,
      message: url,
      leftBarIndicatorColor: context.theme.colorScheme.primary,
      top: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final aboutResult = _aboutResult;
    const dividerContainer = NamidaContainerDivider(
      margin: EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
    );
    return NamidaScrollbar(
      controller: widget.scrollController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: _isLoadingInitial
            ? ThreeArchedCircle(
                color: context.theme.colorScheme.secondaryContainer,
                size: 64.0,
              )
            : aboutResult == null
                ? Center(
                    child: Text(
                      lang.ERROR,
                      style: context.textTheme.displayLarge,
                    ),
                  )
                : ListView(
                    controller: widget.scrollController,
                    children: [
                      const SizedBox(height: 24.0),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: NamidaSelectableAutoLinkText(
                          text: aboutResult.description ?? '',
                          fontScale: 1.08,
                        ),
                      ),
                      dividerContainer,
                      ...aboutResult.aboutLinks.map(
                        (e) {
                          final iconUrl = e.icons.pick()?.url;
                          return NamidaInkWell(
                            onTap: () {
                              final url = _getWorkingUrl(e);
                              NamidaLinkUtils.openLinkPreferNamida(url);
                            },
                            onLongPress: () {
                              final url = _getWorkingUrl(e);
                              _copyUrlToClipboard(url);
                            },
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            bgColor: context.theme.colorScheme.secondaryContainer.withOpacity(0.01),
                            decoration: BoxDecoration(
                              border: Border.all(
                                width: 1.5,
                                color: context.theme.colorScheme.secondary.withOpacity(0.2),
                              ),
                            ),
                            borderRadius: 10.0,
                            child: Row(
                              children: [
                                const SizedBox(width: 12.0),
                                YoutubeThumbnail(
                                  key: ValueKey(iconUrl),
                                  width: 24.0,
                                  height: 24.0,
                                  isCircle: true,
                                  isImportantInCache: false,
                                  type: ThumbnailType.other,
                                  customUrl: iconUrl,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 0,
                                      spreadRadius: 1.5,
                                    )
                                  ],
                                ),
                                const SizedBox(width: 12.0),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.title,
                                        style: context.textTheme.displayMedium?.copyWith(
                                          fontSize: 15.0,
                                          color: Color.alphaBlend(
                                            context.theme.colorScheme.onSecondaryContainer.withOpacity(0.5),
                                            context.theme.colorScheme.onSurface.withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        e.linkText,
                                        style: context.textTheme.displaySmall?.copyWith(
                                          fontSize: 11.5,
                                          // color: context.theme.colorScheme.onSecondaryContainer.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12.0),
                              ],
                            ),
                          );
                        },
                      ),
                      dividerContainer,
                      NamidaInkWell(
                        bgColor: context.theme.cardColor.withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                        child: Column(
                          children: [
                            _SmolInfo(
                              title: aboutResult.canonicalChannelUrl?.splitLast('/'),
                              icon: Broken.link,
                              onTap: () {
                                final url = aboutResult.canonicalChannelUrl;
                                if (url == null) return;
                                _copyUrlToClipboard(url);
                              },
                            ),
                            _SmolInfo(
                              title: aboutResult.subscriberCount?.displaySubscribersKeywordShort ?? aboutResult.subscriberCountText, // short cuz its not acc
                              icon: Broken.profile_2user,
                            ),
                            _SmolInfo(
                              title: aboutResult.videoCount?.displayVideoKeyword ?? aboutResult.videoCountText,
                              icon: Broken.video,
                            ),
                            _SmolInfo(
                              title: aboutResult.viewCount?.displayViewsKeyword ?? aboutResult.viewCountText,
                              icon: Broken.activity,
                            ),
                            _SmolInfo(
                              title: aboutResult.joinedText,
                              icon: Broken.clock,
                            ),
                            _SmolInfo(
                              title: aboutResult.country,
                              icon: Broken.global,
                            ),
                          ],
                        ),
                      ),
                      kBottomPaddingWidget,
                    ],
                  ),
      ),
    );
  }
}

class _SmolInfo extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final VoidCallback? onTap;

  const _SmolInfo({
    required this.title,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (title == null) return const SizedBox();
    Widget child = Row(
      children: [
        const SizedBox(width: 12.0),
        Icon(
          icon,
          size: 20.0,
          color: context.theme.colorScheme.onSurface.withOpacity(0.7),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: Text(
            title!,
            style: context.textTheme.displayMedium?.copyWith(
              fontSize: 15.0,
              color: Color.alphaBlend(
                context.theme.colorScheme.onSecondaryContainer.withOpacity(0.3),
                context.theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12.0),
      ],
    );
    if (onTap != null) {
      child = TapDetector(
        onTap: onTap,
        child: child,
      );
    }
    child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: child,
    );

    return child;
  }
}
