import 'package:flutter/material.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/pages/youtube_page.dart';
import 'package:namida/youtube/pages/yt_channels_page.dart';
import 'package:namida/youtube/pages/yt_downloads_page.dart';
import 'package:namida/youtube/youtube_playlists_view.dart';

class YouTubeHomeView extends StatelessWidget {
  const YouTubeHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: NamidaTabView(
        isScrollable: true,
        initialIndex: settings.ytInitialHomePage.value.index,
        tabs: YTHomePages.values.map((e) => e.toText()).toList(),
        onIndexChanged: (index) {
          settings.save(ytInitialHomePage: YTHomePages.values[index]);
        },
        children: [
          const YoutubePage(),
          const YoutubeChannelsPage(),
          YoutubePlaylistsView(bottomPadding: Dimensions.inst.globalBottomPaddingTotal, scrollable: false),
          const YTDownloadsPage(),
        ],
      ),
    );
  }
}
