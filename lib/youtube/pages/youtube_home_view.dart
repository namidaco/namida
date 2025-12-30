import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
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
          YoutubeHomeFeedPage(),
          YoutubeNotificationsPage(),
          _ChannelsPage(),
          _PlaylistsPage(),
          YTDownloadsPage(),
        ],
      ),
    );
  }
}

class _ChannelsPage extends StatelessWidget {
  const _ChannelsPage();

  @override
  Widget build(BuildContext context) {
    return _SplitPage(
      initialIndex: settings.extra.ytChannelsPageIndex ?? settings.extra.getPreferredTabIndexIfLoggedInYT(),
      onIndexChanged: (index) => settings.extra.save(ytChannelsPageIndex: index),
      pages: [
        (lang.LOCAL, const YoutubeChannelsPage()),
        (lang.YOUTUBE, const YoutubeChannelsHostedPage()),
      ],
    );
  }
}

class _PlaylistsPage extends StatelessWidget {
  const _PlaylistsPage();

  @override
  Widget build(BuildContext context) {
    return _SplitPage(
      initialIndex: settings.extra.ytPlaylistsPageIndex ?? settings.extra.getPreferredTabIndexIfLoggedInYT(),
      onIndexChanged: (index) => settings.extra.save(ytPlaylistsPageIndex: index),
      pages: [
        (lang.LOCAL, const YoutubePlaylistsView()),
        (lang.YOUTUBE, const YoutubeUserPlaylistsPage()),
      ],
    );
  }
}

class _SplitPage extends StatefulWidget {
  final int initialIndex;
  final void Function(int index) onIndexChanged;
  final List<(String, Widget)> pages;

  const _SplitPage({
    required this.initialIndex,
    required this.onIndexChanged,
    required this.pages,
  });

  @override
  State<_SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<_SplitPage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    _selectedIndex = widget.initialIndex.clampInt(0, widget.pages.length - 1);
    super.initState();
  }

  void _onButtonTap(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    widget.onIndexChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final pages = widget.pages;
    final selectedIndex = _selectedIndex;
    return Column(
      children: [
        const SizedBox(height: 8.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: pages
                .mapIndexed(
                  (e, i) {
                    final isSelected = i == selectedIndex;
                    return Expanded(
                      child: NamidaInkWell(
                        alignment: Alignment.center,
                        animationDurationMS: 200,
                        borderRadius: 8.0,
                        bgColor: theme.cardTheme.color,
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          border: isSelected
                              ? Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                                  width: 1.2,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                        ),
                        onTap: () => _onButtonTap(i),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.$1,
                                style: theme.textTheme.displayMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
                .addSeparators(
                  separator: SizedBox(width: 8.0),
                  skipFirst: 1,
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 6.0),
        NamidaContainerDivider(
          margin: const EdgeInsets.symmetric(horizontal: 18.0),
        ),
        Expanded(
          child: pages[_selectedIndex].$2,
        ),
      ],
    );
  }
}
