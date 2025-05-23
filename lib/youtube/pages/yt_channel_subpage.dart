import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:jiffy/jiffy.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:youtipie/class/channels/channel_about_link.dart';
import 'package:youtipie/class/channels/channel_home_section.dart';
import 'package:youtipie/class/channels/channel_info.dart';
import 'package:youtipie/class/channels/channel_page_about.dart';
import 'package:youtipie/class/channels/channel_page_result.dart';
import 'package:youtipie/class/channels/channel_tab.dart';
import 'package:youtipie/class/channels/channel_tab_result.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/items_sort.dart';
import 'package:youtipie/class/publish_time.dart';
import 'package:youtipie/class/result_wrapper/list_wrapper_base.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_short.dart';
import 'package:youtipie/class/thumbnail.dart';
import 'package:youtipie/class/youtipie_feed/channel_info_item.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item.dart';
import 'package:youtipie/core/extensions.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/base/youtube_channel_controller.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/widgets/yt_channel_card.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_subscribe_buttons.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';
import 'package:namida/youtube/widgets/yt_videos_actions_bar.dart';

part 'yt_channel_subpage_about.dart';
part 'yt_channel_subpage_tab.dart';
part 'yt_channel_subpage_videos_tab.dart';

class YTChannelSubpage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_CHANNEL_SUBPAGE;

  final String channelID;
  final YoutubeSubscription? sub;
  final ChannelInfoItem? channel;
  const YTChannelSubpage({super.key, required this.channelID, this.sub, this.channel});

  @override
  State<YTChannelSubpage> createState() => _YTChannelSubpageState();
}

class _YTChannelSubpageState extends State<YTChannelSubpage> with TickerProviderStateMixin, PullToRefreshMixin {
  @override
  double get maxDistance => 64.0;

  late final YoutubeSubscription ch = YoutubeSubscriptionsController.inst.availableChannels.value[widget.channelID] ??
      YoutubeSubscription(
        channelID: widget.channelID.splitLast('/'),
        subscribed: false,
      );

  final _channelInfoSubButton = Rxn<YoutiPieChannelPageResult>(); // rx is accessed only in subscribe button. keep using setState().
  YoutiPieChannelPageResult? _channelInfo; // bcz accessing [_channelInfoSubButton] doesnt update widget tree
  YoutiPieFetchAllRes? _currentFetchAllRes;

  final _tabsGlobalKeys = <int, GlobalKey>{};
  final _tabLastFetched = <int, DateTime>{};

  final _aboutPageKey = GlobalKey<_YTChannelSubpageAboutState>();
  final _videosPageKey = GlobalKey<_YTChannelVideosTabState>();
  final _pagesKeys = <String, GlobalKey<_YTChannelSubpageTabState>>{};
  DateTime? _aboutPageLastFetched;

  late final _scrollAnimation = AnimationController(vsync: this, value: 1.0);

  late final _itemsScrollController = ScrollController();
  late final _scrollControllersOffsets = <int, double>{};
  int _tabIndex = 0;

  GlobalKey<_YTChannelSubpageTabState> _createPageKey<T>(ChannelTab tab) {
    return _pagesKeys[tab.title] ??= GlobalKey<_YTChannelSubpageTabState>(); // use cached state to avoid disposing
  }

  /// returns tab to be selected possible index.
  int? _setTabsData(YoutiPieChannelPageResult res) {
    _tabsGlobalKeys.clear();

    final length = res.tabs.length;
    int? initiallySelected;
    int? videoTabIndex;
    for (int i = 0; i < length; i++) {
      final tab = res.tabs[i];
      if (tab.initiallySelected) initiallySelected = i;

      if (videoTabIndex == null && tab.isVideosTab()) {
        videoTabIndex = i;
        _tabsGlobalKeys[i] = _videosPageKey;
      } else {
        _tabsGlobalKeys[i] = _createPageKey(tab);
      }
    }

    return initiallySelected ?? videoTabIndex;
  }

  bool _animatedFully = false;
  final _scrollThreshold = 100;
  double _latestAnimation = 1.0;
  void _scrollAnimationListener() {
    if (_isAboutTab()) return;

    final scroll = _itemsScrollController.positions.lastOrNull;
    if (scroll != null) {
      final isDownwards = scroll.userScrollDirection == ScrollDirection.reverse;
      double position = scroll.pixels;
      position += _scrollControllersOffsets[_tabIndex] ?? 0; // this also important to prevent jumping

      final p = (position - _scrollThreshold) / 100;
      final pc = (1 - p).clampDouble(0.0, 1.0);
      if (isDownwards && pc > 0 && pc > _latestAnimation) return; // prevent jumping from hidden to visible (after switching to new tab)

      if (!_animatedFully) {
        _latestAnimation = pc;
        _scrollAnimation.animateTo(pc, duration: Duration.zero);
      }

      if (pc == 0.0 || pc == 1.0) {
        _animatedFully = true;
      } else {
        _animatedFully = false;
      }
    }
  }

  bool _isAboutTab() {
    return _tabIndex == _tabsGlobalKeys.length - 1 + 1; // last tab
  }

  @override
  void initState() {
    super.initState();

    final channelInfoCache = YoutubeInfoController.channel.fetchChannelInfoSync(ch.channelID);
    if (channelInfoCache != null) {
      _channelInfoSubButton.value = channelInfoCache;
      _channelInfo = channelInfoCache;
      final tabToBeSelected = _setTabsData(channelInfoCache);
      if (tabToBeSelected != null) _tabIndex = tabToBeSelected;
      _fetchCurrentTab(channelInfoCache);
    } else {
      _tabsGlobalKeys[0] = _videosPageKey;
    }

    // -- always get new info.
    YoutubeInfoController.channel.fetchChannelInfo(channelId: ch.channelID, details: ExecuteDetails.forceRequest()).then(
      (value) {
        if (value != null) {
          _channelInfoSubButton.value = value;
          final tabToBeSelected = _setTabsData(value);
          refreshState(() {
            if (_tabIndex == 0 && tabToBeSelected != null) _tabIndex = tabToBeSelected; // only set if tab wasnt changed
            _channelInfo = value;
          });
          onRefresh(() => _fetchCurrentTab(value, forceRequest: true), forceProceed: true);
        }
      },
    );

    _itemsScrollController.addListener(_scrollAnimationListener);
  }

  @override
  void dispose() {
    _itemsScrollController.dispose();
    _scrollAnimation.dispose();
    _currentFetchAllRes?.cancel();
    _currentFetchAllRes = null;
    _tabLastFetched.clear();
    super.dispose();
  }

  Future<void> _fetchCurrentTab(YoutiPieChannelPageResult channelInfo, {bool? forceRequest}) async {
    if (_tabsGlobalKeys.isEmpty) return;
    final currentKeyState = _isAboutTab() ? _aboutPageKey : _tabsGlobalKeys[_tabIndex]?.currentState;
    forceRequest ??= _shouldForceRequestTab(_tabIndex);
    if (currentKeyState is _YTChannelVideosTabState) {
      await currentKeyState.fetchChannelStreams(channelInfo, forceRequest: forceRequest);
    } else if (currentKeyState is _YTChannelSubpageTabState) {
      await currentKeyState.fetchTabAndUpdate(forceRequest: forceRequest);
    } else if (currentKeyState is _YTChannelSubpageAboutState) {
      await currentKeyState.fetchAboutAndUpdate(forceRequest: forceRequest);
    }
  }

  bool _shouldForceRequestTab(int tabIndex) {
    return _didEnoughTimePass(_tabLastFetched[tabIndex]);
  }

  bool _didEnoughTimePass(DateTime? datetime) {
    final diff = datetime?.difference(DateTime.now());
    return diff == null ? true : diff.abs() > const Duration(seconds: 180);
  }

  File? _getThumbFileForCache(String url, {required bool temp}) {
    return ThumbnailManager.inst.imageUrlToCacheFile(id: null, url: url, isTemp: temp, type: ThumbnailType.channel);
  }

  void _onImageTap({
    required BuildContext context,
    required String channelID,
    required List<YoutiPieThumbnail> imagesList,
    required bool isPfp,
  }) {
    final files = <(String, File?)>[];
    imagesList.loop(
      (item) {
        File? cf = _getThumbFileForCache(item.url, temp: false);
        if (cf?.existsSync() == false) cf = _getThumbFileForCache(item.url, temp: true);
        files.add((item.url, cf));
      },
    );
    if (isPfp) {
      final cf = _getThumbFileForCache(channelID, temp: false);
      if (cf != null && cf.existsSync()) files.add((channelID, cf));
    }
    if (files.isEmpty) return;

    int fileIndex = 0;

    final pageController = PageController(initialPage: fileIndex);

    NamidaNavigator.inst.navigateDialog(
      scale: 1.0,
      blackBg: true,
      dialog: LongPressDetector(
        onLongPress: () async {
          final file = files[fileIndex].$2;
          if (file == null) return;
          final saveDirPath = await EditDeleteController.inst.saveImageToStorage(file);
          String title = lang.COPIED_ARTWORK;
          String subtitle = '${lang.SAVED_IN} $saveDirPath';
          // ignore: use_build_context_synchronously
          Color snackColor = context.theme.colorScheme.surface;

          if (saveDirPath == null) {
            title = lang.ERROR;
            subtitle = lang.COULDNT_SAVE_IMAGE;
            snackColor = Colors.red;
          }
          snackyy(
            title: title,
            message: subtitle,
            leftBarIndicatorColor: snackColor,
            altDesign: true,
            top: false,
          );
        },
        child: PhotoViewGallery.builder(
          pageController: pageController,
          onPageChanged: (index) => fileIndex = index,
          gaplessPlayback: true,
          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
          itemCount: files.length,
          builder: (context, index) {
            final fileWKey = files[index];
            final file = fileWKey.$2;
            return PhotoViewGalleryPageOptions(
              heroAttributes: PhotoViewHeroAttributes(tag: _getHeroTag(channelID, isPfp, fileWKey.$1)),
              tightMode: true,
              minScale: PhotoViewComputedScale.contained,
              filterQuality: FilterQuality.high,
              imageProvider: file != null ? FileImage(file) : NetworkImage(fileWKey.$1),
            );
          },
        ),
      ),
    );
  }

  String _getHeroTag(String channelID, bool isPfp, String? url) {
    return '${isPfp}_${channelID}_$url';
  }

  void _addNull<E>(List<E> list, E? item) {
    if (item != null) list.add(item);
  }

  @override
  Widget build(BuildContext context) {
    final showSubpageInfoAtSide = Dimensions.inst.showSubpageInfoAtSideContext(context);
    final maxWidth = Dimensions.inst.availableAppContentWidth;

    final channelInfo = _channelInfo;
    final channelID = channelInfo?.id ?? ch.channelID;

    final pfps = <YoutiPieThumbnail>[];
    final banners = <YoutiPieThumbnail>[];
    if (channelInfo != null) {
      _addNull(pfps, channelInfo.thumbnails.pick());
      _addNull(banners, channelInfo.banners.pick());
      _addNull(banners, channelInfo.tvbanners.pick());
      _addNull(banners, channelInfo.mobileBanners.pick());
    }

    final pfp = pfps.firstOrNull?.url ?? channelID; // channelID can be fetched from cache in some cases
    final banner = banners.firstOrNull;
    final bannerUrl = banner?.url;
    double bannerHeight;
    if (banner != null) {
      bannerHeight = banner.height / (banner.width / maxWidth);
    } else {
      bannerHeight = 69.0;
    }
    if (bannerHeight.isNaN || bannerHeight.isInfinite) bannerHeight = 69.0;
    bannerHeight = bannerHeight.withMaximum(context.height * 0.2);

    final subsCount = channelInfo?.subscribersCount;
    final subsCountText = channelInfo?.subscribersCountText;

    final bannerWidget = TapDetector(
      onTap: () => _onImageTap(
        context: context,
        channelID: channelID,
        imagesList: banners,
        isPfp: false,
      ),
      child: NamidaHero(
        tag: _getHeroTag(channelID, false, bannerUrl),
        child: YoutubeThumbnail(
          type: ThumbnailType.channel, // banner akshully
          key: Key('${channelID}_$bannerUrl'),
          width: maxWidth,
          height: bannerHeight,
          compressed: false,
          isImportantInCache: false,
          customUrl: bannerUrl,
          borderRadius: 0,
          disableBlurBgSizeShrink: true,
          displayFallbackIcon: false,
          fit: BoxFit.cover, // sadly BoxFit.contain won't look so good when shrinked (either by max height or dynamic height)
          alignment: Alignment.centerLeft,
        ),
      ),
    );

    final pfpImageWidth = (maxWidth * 0.18).withMaximum(context.height * 0.3).withMaximum(Dimensions.inst.sideInfoMaxWidth * 0.8);
    final pfpImageWidget = TapDetector(
      onTap: () => _onImageTap(
        context: context,
        channelID: channelID,
        imagesList: pfps,
        isPfp: true,
      ),
      child: NamidaHero(
        tag: _getHeroTag(channelID, true, pfp),
        child: YoutubeThumbnail(
          type: ThumbnailType.channel,
          key: Key('${channelID}_$pfp'),
          width: pfpImageWidth,
          isImportantInCache: true,
          customUrl: pfp,
          isCircle: true,
          compressed: false,
          fit: BoxFit.contain,
        ),
      ),
    );

    final txtInfoWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: showSubpageInfoAtSide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2.0),
          child: Text(
            channelInfo?.title ?? ch.title,
            style: context.textTheme.displayLarge,
          ),
        ),
        showSubpageInfoAtSide ? const SizedBox(height: 8.0) : const SizedBox(height: 4.0),
        Text(
          subsCountText ?? (subsCount == null ? '? ${lang.SUBSCRIBERS}' : subsCount.displaySubscribersKeywordShort),
          style: context.textTheme.displayMedium?.copyWith(
            fontSize: 12.0,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final subscribeButtonWidget = YTSubscribeButton(
      channelID: channelID,
      mainChannelInfo: _channelInfoSubButton,
    );

    final header = AnimatedBuilder(
      animation: _scrollAnimation,
      builder: (context, _) {
        final p = _scrollAnimation.value;
        return Stack(
          alignment: Alignment.topLeft,
          children: [
            if (bannerUrl != null)
              SizedBox(
                height: p * bannerHeight,
                child: bannerWidget,
              ),
            Padding(
              padding: (banners.isEmpty ? EdgeInsets.only(top: 4.0) : EdgeInsets.only(top: (p * bannerHeight * 0.95))),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: context.height * 0.15),
                child: Row(
                  children: [
                    const SizedBox(width: 12.0),
                    Transform.translate(
                      offset: banners.isEmpty ? const Offset(0, 0) : Offset(0, p * -bannerHeight * 0.1),
                      child: pfpImageWidget,
                    ),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: txtInfoWidget,
                    ),
                    const SizedBox(width: 4.0),
                    subscribeButtonWidget,
                    const SizedBox(width: 12.0),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    Widget finalChild = Listener(
      onPointerMove: (event) => _itemsScrollController.hasClients ? onPointerMove(_itemsScrollController, event) : null,
      onPointerUp: (_) => channelInfo == null ? null : onRefresh(() => _fetchCurrentTab(channelInfo, forceRequest: true)),
      onPointerCancel: (_) => onVerticalDragFinish(),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            children: [
              if (!showSubpageInfoAtSide) header,
              const SizedBox(height: 4.0),
              Expanded(
                child: NamidaTabView(
                  key: Key("${_tabIndex}_${_tabsGlobalKeys.length}"),
                  reportIndexChangedOnInit: false,
                  isScrollable: true,
                  compact: true,
                  tabs: [
                    if (channelInfo != null) ...channelInfo.tabs.map((e) => e.title) else lang.VIDEOS,
                    lang.ABOUT,
                  ],
                  initialIndex: _tabIndex,
                  onIndexChanged: (index) {
                    try {
                      _scrollControllersOffsets[_tabIndex] ??= _itemsScrollController.offset;
                    } catch (_) {}

                    _tabIndex = index;
                    if (channelInfo != null) _fetchCurrentTab(channelInfo);

                    if (_isAboutTab()) {
                      if (_scrollAnimation.value < 1.0) {
                        _scrollAnimation.animateTo(
                          1.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.fastEaseInToSlowEaseOut,
                        );
                      }
                    }
                  },
                  children: [
                    if (channelInfo != null)
                      ...channelInfo.tabs.mapIndexed((e, i) {
                        if (e.isVideosTab()) {
                          return YTChannelVideosTab(
                            key: _tabsGlobalKeys[i],
                            scrollController: _itemsScrollController,
                            channelInfo: _channelInfo,
                            localChannel: ch,
                          );
                        }
                        return YTChannelSubpageTab(
                          key: _tabsGlobalKeys[i],
                          scrollController: _itemsScrollController,
                          channelId: channelID,
                          tab: e,
                          tabFetcher: (fetch) => onRefresh(fetch, forceProceed: true),
                          onSuccessFetch: () => _tabLastFetched[i] = DateTime.now(),
                          shouldForceRequest: () => _shouldForceRequestTab(i),
                        );
                      })
                    else
                      YTChannelVideosTab(
                        scrollController: _itemsScrollController,
                        channelInfo: _channelInfo,
                        localChannel: ch,
                      ),
                    YTChannelSubpageAbout(
                      key: _aboutPageKey,
                      scrollController: _itemsScrollController,
                      channelId: channelID,
                      channelInfo: () => channelInfo,
                      tabFetcher: (fetch) => onRefresh(fetch, forceProceed: true),
                      onSuccessFetch: () => _aboutPageLastFetched = DateTime.now(),
                      shouldForceRequest: () => _didEnoughTimePass(_aboutPageLastFetched),
                    )
                  ],
                ),
              ),
            ],
          ),
          pullToRefreshWidget,
        ],
      ),
    );

    if (showSubpageInfoAtSide) {
      finalChild = Column(
        children: [
          bannerWidget,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: pfpImageWidth * 1.4,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: banners.isEmpty ? const Offset(0, 0) : Offset(0, -bannerHeight * 0.35),
                          child: pfpImageWidget,
                        ),
                        txtInfoWidget,
                        const SizedBox(height: 12.0),
                        subscribeButtonWidget,
                        const SizedBox(height: 6.0),
                      ],
                    ),
                  ),
                ),
                Expanded(child: finalChild),
              ],
            ),
          ),
        ],
      );
    }

    finalChild = BackgroundWrapper(
      child: finalChild,
    );

    return finalChild;
  }
}
