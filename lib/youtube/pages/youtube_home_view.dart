import 'package:flutter/material.dart';

import 'package:namida/core/dimensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/pages/youtube_page.dart';
import 'package:namida/youtube/pages/yt_channels_page.dart';
import 'package:namida/youtube/pages/yt_downloads_page.dart';
import 'package:namida/youtube/youtube_playlists_view.dart';

class YouTubeHomeView extends StatelessWidget {
  const YouTubeHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = [lang.HOME, lang.CHANNELS, lang.PLAYLISTS, lang.DOWNLOADS];
    const initialIndex = 2;
    return BackgroundWrapper(
      child: NamidaTabView(
        isScrollable: true,
        initialIndex: initialIndex,
        tabs: tabs,
        onIndexChanged: (index) {},
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
