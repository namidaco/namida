import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/pages/home_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/pages/youtube_feed_page.dart';
import 'package:namida/youtube/pages/youtube_notifications_page.dart';
import 'package:namida/youtube/pages/youtube_user_playlists_page.dart';
import 'package:namida/youtube/pages/yt_channels_page.dart';
import 'package:namida/youtube/pages/yt_downloads_page.dart';
import 'package:namida/youtube/youtube_playlists_view.dart';

class YouTubeHomeView extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_HOME;

  const YouTubeHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: NamidaTabView(
        isScrollable: false,
        initialIndex: settings.extra.ytInitialHomePage.value.index,
        tabWidgets: YTHomePages.values
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Tooltip(
                  message: e.toText(),
                  child: Icon(
                    e.toIcon(),
                    size: 20.0,
                  ),
                ),
              ),
            )
            .toList(),
        onIndexChanged: (index) {
          settings.extra.save(ytInitialHomePage: YTHomePages.values[index]);
        },
        children: const [
          _HomePage(),
          YoutubeNotificationsPage(),
          _ChannelsPage(),
          _PlaylistsPage(),
          YTDownloadsPage(),
        ],
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return SplitPage(
      initialIndex: settings.extra.ytHomePageIndex ?? settings.extra.getPreferredTabIndexIfLoggedInYT(),
      onIndexChanged: (index) => settings.extra.save(ytHomePageIndex: index),
      pages: [
        SplitPageInfo(
          title: lang.local,
          page: const YTHomePageLocal(),
        ),
        SplitPageInfo(
          title: lang.youtube,
          page: const YoutubeHomeFeedPage(),
        ),
      ],
    );
  }
}

class _ChannelsPage extends StatelessWidget {
  const _ChannelsPage();

  @override
  Widget build(BuildContext context) {
    return SplitPage(
      initialIndex: settings.extra.ytChannelsPageIndex ?? settings.extra.getPreferredTabIndexIfLoggedInYT(),
      onIndexChanged: (index) => settings.extra.save(ytChannelsPageIndex: index),
      pages: [
        SplitPageInfo(
          title: lang.local,
          page: const YoutubeChannelsPage(),
        ),
        SplitPageInfo(
          title: lang.youtube,
          page: const YoutubeChannelsHostedPage(),
        ),
      ],
    );
  }
}

class _PlaylistsPage extends StatelessWidget {
  const _PlaylistsPage();

  @override
  Widget build(BuildContext context) {
    return SplitPage(
      initialIndex: settings.extra.ytPlaylistsPageIndex ?? settings.extra.getPreferredTabIndexIfLoggedInYT(),
      onIndexChanged: (index) => settings.extra.save(ytPlaylistsPageIndex: index),
      pages: [
        SplitPageInfo(
          title: lang.local,
          page: const YoutubePlaylistsView(),
        ),
        SplitPageInfo(
          title: lang.youtube,
          page: const YoutubeUserPlaylistsPage(),
        ),
      ],
    );
  }
}
