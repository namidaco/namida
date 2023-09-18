import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:share_plus/share_plus.dart';

import 'package:namida/class/youtube_id.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/youtube_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/packages/youtube_miniplayer.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class YoutubePage extends StatelessWidget {
  const YoutubePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Obx(
        () {
          final searchList = YoutubeController.inst.homepageFeed;
          final List<YoutubeFeed?> l = [];
          if (searchList.isEmpty) {
            l.addAll(List.filled(20, null));
          } else {
            l.addAll(searchList);
          }
          return NamidaListView(
            // padding: const EdgeInsets.only(top: 32.0, bottom: kBottomPadding),
            header: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                lang.HOME,
                style: context.textTheme.displayLarge?.copyWith(fontSize: 38.0.multipliedFontScale),
              ),
            ),
            itemBuilder: (context, i) {
              final feedItem = l[i];
              return YoutubeVideoCard(
                key: ValueKey(i),
                video: feedItem is StreamInfoItem ? feedItem : null,
              );
            },
            itemCount: l.length,
            itemExtents: null,
          );
        },
      ),
    );
  }
}

class YoutubeSearchBar extends StatelessWidget {
  const YoutubeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    return Container(
      padding: const EdgeInsets.only(right: 12.0),
      height: 38.0,
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0.multipliedRadius),
          ),
          hintText: lang.SEARCH_YOUTUBE,
        ),
        onChanged: (value) {},
        onSubmitted: (value) {
          searchController.clear();
          NamidaNavigator.inst.navigateTo(YoutubeSearchResultsPage(searchText: value));
        },
      ),
    );
  }
}

class YoutubeSearchResultsPage extends StatefulWidget {
  final String searchText;
  const YoutubeSearchResultsPage({super.key, required this.searchText});

  @override
  State<YoutubeSearchResultsPage> createState() => _YoutubeSearchResultsPageState();
}

class _YoutubeSearchResultsPageState extends State<YoutubeSearchResultsPage> {
  final _searchResult = <dynamic>[];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _fetchSearch();
  }

  Future<void> _fetchSearch() async {
    _searchResult.clear();
    final result = await YoutubeController.inst.searchForItems(widget.searchText);
    _searchResult.addAll(result);
    _loading = false;
    if (mounted) setState(() {});
  }

  Future<void> _fetchSearchNextPage() async {
    if (_searchResult.isEmpty) return; // return if still fetching first results.
    final result = await YoutubeController.inst.searchNextPage();
    _searchResult.addAll(result);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    for (final s in _searchResult) {
      printy(s.runtimeType);
    }
    return BackgroundWrapper(
      child: _loading
          ? ThreeArchedCircle(
              color: CurrentColor.inst.color,
              size: context.width * 0.4,
            )
          : LazyLoadListView(
              onReachingEnd: () async => await _fetchSearchNextPage(),
              listview: (controller) {
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: kBottomPadding),
                  itemCount: _searchResult.length,
                  controller: controller,
                  itemBuilder: (context, index) {
                    final item = _searchResult[index];
                    switch (item.runtimeType) {
                      case StreamInfoItem:
                        return YoutubeVideoCard(video: item);
                      case YoutubePlaylist:
                        return YoutubePlaylistCard(playlist: item);
                      case YoutubeChannel:
                        return Text((item as YoutubeChannel).name ?? ''); // TODO: channel card
                    }
                    return const SizedBox();
                  },
                );
              },
            ),
    );
  }
}

class YoutubeVideoCard extends StatelessWidget {
  final StreamInfoItem? video;
  const YoutubeVideoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    final videoId = video?.id ?? '';
    return YoutubeCard(
      borderRadius: 12.0,
      videoId: video?.id,
      thumbnailUrl: null,
      shimmerEnabled: video == null,
      title: video?.name ?? '',
      subtitle: [
        video?.viewCount?.formatDecimalShort() ?? 0,
        if (video?.uploadDate != null) video?.uploadDate,
      ].join(' - '),
      thirdLineText: video?.uploaderName ?? '',
      onTap: () {
        if (video?.id != null) {
          Player.inst.playOrPause(
            0,
            [YoutubeID(id: videoId)],
            QueueSource.others,
          );
        }
      },
      channelThumbnailUrl: video?.uploaderAvatarUrl,
      displayChannelThumbnail: true,
      smallBoxText: video?.duration?.inSeconds.secondsLabel,
      smallBoxIcon: null,
      menuChildrenDefault: [
        (
          Broken.music_library_2,
          lang.ADD_TO_PLAYLIST,
          () {
            showAddToPlaylistSheet(ids: [videoId], idsNamesLookup: {videoId: video?.name});
          },
        ),
        (
          Broken.import,
          lang.DOWNLOAD,
          () {
            showDownloadVideoBottomSheet(
              videoId: videoId,
            );
          },
        ),
        (
          Broken.share,
          lang.SHARE,
          () {
            final url = video?.url;
            if (url != null) Share.share(url);
          },
        ),
        (
          Broken.next,
          lang.PLAY_NEXT,
          () {
            Player.inst.addToQueue([YoutubeID(id: videoId)], insertNext: true);
          },
        ),
        (
          Broken.play_cricle,
          lang.PLAY_LAST,
          () {
            Player.inst.addToQueue([YoutubeID(id: videoId)], insertNext: false);
          },
        ),
      ],
    );
  }
}

class YoutubePlaylistCard extends StatelessWidget {
  final YoutubePlaylist? playlist;
  const YoutubePlaylistCard({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return YoutubeCard(
      extractColor: true,
      borderRadius: 12.0,
      videoId: null,
      thumbnailUrl: playlist?.thumbnailUrl ?? '',
      shimmerEnabled: playlist == null,
      title: playlist?.name ?? '',
      subtitle: playlist?.uploaderName ?? '',
      thirdLineText: '',
      onTap: () {},
      displayChannelThumbnail: false,
      displaythirdLineText: false,
      smallBoxText: '+25',
    );
  }
}

class YoutubeCard extends StatelessWidget {
  final String? videoId;
  final String? thumbnailUrl;
  final void Function()? onTap;
  final double borderRadius;
  final bool shimmerEnabled;
  final String title;
  final String subtitle;
  final String thirdLineText;
  final String? channelThumbnailUrl;
  final bool displayChannelThumbnail;
  final bool displaythirdLineText;
  final List<Widget> onTopWidgets;
  final String? smallBoxText;
  final bool? checkmarkStatus;
  final double thumbnailWidthPercentage;
  final IconData? smallBoxIcon;
  final bool extractColor;
  final List<Widget> menuChildren;
  final List<(IconData, String, void Function())> menuChildrenDefault;

  const YoutubeCard({
    super.key,
    required this.videoId,
    required this.thumbnailUrl,
    this.onTap,
    this.borderRadius = 12.0,
    required this.shimmerEnabled,
    this.title = '',
    this.subtitle = '',
    required this.thirdLineText,
    this.channelThumbnailUrl,
    this.displayChannelThumbnail = true,
    this.displaythirdLineText = true,
    this.onTopWidgets = const <Widget>[],
    this.smallBoxText,
    this.checkmarkStatus,
    this.thumbnailWidthPercentage = 1.0,
    this.smallBoxIcon = Broken.play_cricle,
    this.extractColor = false,
    this.menuChildren = const [],
    this.menuChildrenDefault = const [],
  });

  @override
  Widget build(BuildContext context) {
    const verticalPadding = 8.0;
    final thumbnailWidth = thumbnailWidthPercentage * context.width * 0.36;
    final thumbnailHeight = thumbnailWidth * 9 / 16;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: verticalPadding * 0.5, horizontal: 8.0),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          NamidaInkWell(
            bgColor: context.theme.cardColor,
            borderRadius: 12.0,
            onTap: onTap,
            height: thumbnailHeight + verticalPadding,
            child: Row(
              children: [
                const SizedBox(width: 4.0),
                NamidaBasicShimmer(
                  width: thumbnailWidth,
                  height: thumbnailHeight,
                  shimmerEnabled: shimmerEnabled,
                  child: YoutubeThumbnail(
                    videoId: videoId,
                    channelUrl: thumbnailUrl,
                    width: thumbnailWidth,
                    height: thumbnailHeight,
                    borderRadius: 10.0,
                    onTopWidgets: onTopWidgets,
                    smallBoxText: smallBoxText,
                    smallBoxIcon: smallBoxIcon,
                    extractColor: extractColor,
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12.0),
                      NamidaBasicShimmer(
                        width: context.width,
                        height: 10.0,
                        borderRadius: 4.0,
                        shimmerEnabled: shimmerEnabled || title == '',
                        child: Text(
                          title,
                          style: context.textTheme.displayMedium?.copyWith(fontSize: 13.0.multipliedFontScale),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      NamidaBasicShimmer(
                        width: context.width,
                        height: 8.0,
                        borderRadius: 4.0,
                        shimmerEnabled: shimmerEnabled || subtitle == '',
                        child: Text(
                          subtitle,
                          style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w400),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      const Spacer(),
                      if (displayChannelThumbnail || displaythirdLineText)
                        Row(
                          children: [
                            if (displayChannelThumbnail) ...[
                              NamidaBasicShimmer(
                                width: 20.0,
                                height: 20.0,
                                shimmerEnabled: channelThumbnailUrl == null || !displayChannelThumbnail,
                                child: YoutubeThumbnail(
                                  channelUrl: channelThumbnailUrl ?? '',
                                  width: 20.0,
                                  isCircle: true,
                                ),
                              ),
                              const SizedBox(width: 6.0),
                            ],
                            NamidaBasicShimmer(
                              width: context.width * 0.2,
                              height: 8.0,
                              shimmerEnabled: thirdLineText == '' || !displaythirdLineText,
                              child: Text(
                                thirdLineText,
                                style: context.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 11.0.multipliedFontScale,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (checkmarkStatus != null) ...[
                              const Spacer(),
                              NamidaCheckMark(size: 12.0, active: checkmarkStatus!),
                            ],
                          ],
                        ),
                      const SizedBox(height: 12.0),
                    ],
                  ),
                ),
                const SizedBox(width: 24.0),
              ],
            ),
          ),
          if (menuChildren.isNotEmpty || menuChildrenDefault.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: NamidaPopupWrapper(
                children: menuChildren,
                childrenDefault: menuChildrenDefault,
                child: const MoreIcon(iconSize: 16.0),
              ),
            ),
        ],
      ),
    );
  }
}

class NamidaBasicShimmer extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Widget? child;
  final bool shimmerEnabled;
  final int fadeDurationMS;

  const NamidaBasicShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12.0,
    required this.child,
    required this.shimmerEnabled,
    this.fadeDurationMS = 600,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      fadeDurationMS: fadeDurationMS,
      shimmerEnabled: shimmerEnabled,
      transparent: false,
      child: child != null && !shimmerEnabled
          ? child!
          : Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.theme.colorScheme.background,
                borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
              ),
            ),
    );
  }
}
