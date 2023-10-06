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
    return BackgroundWrapper(
      child: Obx(
        () {
          final feed = YoutubeController.inst.homepageFeed;
          final List<YoutubeFeed?> l = [];
          if (feed.isEmpty) {
            l.addAll(List.filled(20, null));
          } else {
            l.addAll(feed);
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
                isImageImportantInCache: false,
                video: feedItem is StreamInfoItem ? feedItem : null,
                playlistID: null,
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
