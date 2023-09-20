import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

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
