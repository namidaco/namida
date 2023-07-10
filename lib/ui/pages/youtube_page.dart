import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/youtube_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/packages/youtube_miniplayer.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class YoutubePage extends StatelessWidget {
  const YoutubePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Obx(
        () => AnimatedTheme(
          duration: const Duration(milliseconds: 400),
          data: AppThemes.inst.getAppTheme(CurrentColor.inst.color.value, !context.isDarkMode),
          child: Scaffold(
            backgroundColor: context.theme.scaffoldBackgroundColor,
            appBar: AppBar(
              leading: NamidaIconButton(
                icon: Broken.arrow_left_2,
                onPressed: () => NamidaNavigator.inst.popPage(),
              ),
              title: Text(Language.inst.YOUTUBE),
            ),
            body: Obx(
              () {
                VideoSearchList? searchList = YoutubeController.inst.currentSearchList.value;
                YoutubeController.inst.searchChannels;
                final List<Video?> l = [];
                if (searchList == null || searchList.isEmpty) {
                  l.addAll(List.filled(20, null));
                } else {
                  l.addAll(searchList);
                }
                return NamidaListView(
                  itemBuilder: (context, i) {
                    if (searchList == null) {
                      return YoutubeVideoCard(
                        index: i,
                        key: ValueKey(i),
                        video: null,
                        searchChannel: null,
                      );
                    }
                    final v = searchList[i];
                    final searchChannel = YoutubeController.inst.searchChannels.firstWhereOrNull((element) => element.id.value == v.channelId.value);
                    return YoutubeVideoCard(
                      index: i,
                      key: ValueKey(i),
                      video: v,
                      searchChannel: searchChannel,
                    );
                  },
                  itemCount: l.length,
                  itemExtents: null,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class YoutubeVideoCard extends StatelessWidget {
  final Video? video;
  final Channel? searchChannel;
  final int index;
  const YoutubeVideoCard({super.key, required this.video, required this.searchChannel, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: NamidaInkWell(
        bgColor: context.theme.cardColor,
        borderRadius: 12.0,
        onTap: () {},
        padding: const EdgeInsets.all(4.0).add(const EdgeInsets.symmetric(horizontal: 2.0)),
        child: Row(
          children: [
            video == null
                ? NamidaBasicShimmer(
                    index: index,
                    width: context.width * 0.36,
                    height: context.width * 0.36 * 9 / 16,
                  )
                : YoutubeThumbnail(
                    url: video!.thumbnails.mediumResUrl,
                    width: context.width * 0.36,
                  ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /// First Line

                  const SizedBox(height: 2.0),
                  video == null
                      ? NamidaBasicShimmer(
                          index: index,
                          width: context.width / 2,
                          height: 8.0,
                        )
                      : Text(
                          video!.title,
                          style: context.textTheme.displayMedium?.copyWith(fontSize: 13.0.multipliedFontScale),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                  /// Second Line
                  const SizedBox(height: 2.0),
                  video == null
                      ? NamidaBasicShimmer(
                          index: index,
                          width: context.width / 2,
                          height: 8.0,
                        )
                      : Text(
                          [
                            video!.engagement.viewCount.formatDecimal(),
                            if (video?.uploadDate != null) '${timeago.format(video!.uploadDate!, locale: 'en_short')} ${Language.inst.AGO}'
                          ].join(' - '),
                          style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w400),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                  /// Third Line
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      searchChannel == null
                          ? NamidaBasicShimmer(
                              index: index,
                              width: 22.0,
                              height: 22.0,
                            )
                          : YoutubeThumbnail(
                              url: searchChannel?.logoUrl ?? '',
                              width: 22.0,
                              isCircle: true,
                              errorWidget: (context, url, error) => ArtworkWidget(
                                track: null,
                                thumbnailSize: 22.0,
                                forceDummyArtwork: true,
                                borderRadius: 124.0.multipliedRadius,
                              ),
                            ),
                      const SizedBox(width: 6.0),
                      searchChannel == null
                          ? NamidaBasicShimmer(
                              index: index,
                              width: context.width / 3,
                              height: 6.0,
                            )
                          : Text(
                              searchChannel?.title ?? '',
                              style: context.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w400,
                                fontSize: 11.0.multipliedFontScale,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ],
                  ),
                  const SizedBox(height: 6.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NamidaBasicShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final int index;
  const NamidaBasicShimmer({super.key, required this.width, required this.height, required this.index, this.borderRadius = 12.0});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.theme.colorScheme.onBackground.withAlpha(10),
      highlightColor: context.theme.colorScheme.onBackground.withAlpha(60),
      direction: ShimmerDirection.ltr,
      period: Duration(milliseconds: 1400 + (20 * index)),
      child: Container(
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
