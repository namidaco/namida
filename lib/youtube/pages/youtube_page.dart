import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubePage extends StatefulWidget {
  const YoutubePage({super.key});

  @override
  State<YoutubePage> createState() => _YoutubePageState();
}

class _YoutubePageState extends State<YoutubePage> with AutomaticKeepAliveClientMixin<YoutubePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    YoutubeController.inst.prepareHomeFeed();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final thumbnailWidth = context.width * 0.36;
    final thumbnailHeight = thumbnailWidth * 9 / 16;
    final thumbnailItemExtent = thumbnailHeight + 8.0 * 2;
    return BackgroundWrapper(
      child: Obx(
        () {
          final homepageFeed = YoutubeController.inst.homepageFeed;
          final feed = homepageFeed.isEmpty ? List<YoutubeFeed?>.filled(10, null) : homepageFeed;

          if (feed.isNotEmpty && feed.first == null) {
            return ShimmerWrapper(
              transparent: false,
              shimmerEnabled: true,
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: feed.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  return YoutubeVideoCard(
                    isImageImportantInCache: false,
                    video: null,
                    playlistID: null,
                    thumbnailWidth: thumbnailWidth,
                    thumbnailHeight: thumbnailHeight,
                  );
                },
              ),
            );
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
              final feedItem = feed[i];
              return YoutubeVideoCard(
                key: ValueKey(i),
                isImageImportantInCache: false,
                video: feedItem is StreamInfoItem ? feedItem : null,
                playlistID: null,
                thumbnailWidth: thumbnailWidth,
                thumbnailHeight: thumbnailHeight,
              );
            },
            itemCount: feed.length,
            itemExtents: List.filled(feed.length, thumbnailItemExtent),
          );
        },
      ),
    );
  }
}
