// by claude
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:youtipie/class/music/music_browse_endpoint.dart';
import 'package:youtipie/class/music/music_chip.dart';
import 'package:youtipie/class/music/music_form_option.dart';
import 'package:youtipie/class/music/music_shelf.dart';
import 'package:youtipie/class/music/music_top_result.dart';
import 'package:youtipie/class/result_wrapper/music_browse_result.dart';
import 'package:youtipie/class/result_wrapper/music_search_result.dart';
import 'package:youtipie/class/result_wrapper/playlist_result_base.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/youtipie_feed/channel_info_item.dart';
import 'package:youtipie/class/youtipie_feed/music_album_info_item.dart';
import 'package:youtipie/class/youtipie_feed/music_navigation_item.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item.dart';
import 'package:youtipie/class/youtipie_feed/yt_feed_base.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/functions/yt_playlist_utils.dart';
import 'package:namida/youtube/pages/youtube_main_page_fetcher_acc_base.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

part 'yt_music_page.cards.dart';
part 'yt_music_page.shelves.dart';

class YoutubeMusicHomePage extends StatefulWidget {
  const YoutubeMusicHomePage({super.key});

  @override
  State<YoutubeMusicHomePage> createState() => _YoutubeMusicHomePageState();
}

class _YoutubeMusicHomePageState extends State<YoutubeMusicHomePage> {
  YoutiPieMusicBrowseEndpoint _endpoint = YoutiPieMusicBrowseEndpoint.home;

  void _onChipTap(YoutiPieMusicChip chip) {
    final endpoint = chip.isSelected ? YoutiPieMusicBrowseEndpoint.home : chip.endpoint;
    setState(() => _endpoint = endpoint);
  }

  @override
  Widget build(BuildContext context) {
    return _MusicBrowseView(
      key: ValueKey(_endpoint),
      endpoint: _endpoint,
      title: lang.music,
      headerBuilder: (_, refreshIconWidget) => Row(
        children: [
          const Expanded(
            child: _MusicNavPills(),
          ),
          refreshIconWidget,
        ],
      ),
      onChipTap: _onChipTap,
      onFormOptionTap: null,
    );
  }
}

class YTMusicBrowseSubpage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_MUSIC_BROWSE_SUBPAGE;

  @override
  String? get name => title;

  final YoutiPieMusicBrowseEndpoint endpoint;
  final String title;

  const YTMusicBrowseSubpage({
    super.key,
    required this.endpoint,
    required this.title,
  });

  static void _openChip(YoutiPieMusicChip chip) {
    YTMusicBrowseSubpage(
      endpoint: chip.endpoint,
      title: chip.title,
    ).navigate();
  }

  static void _saveChartsCountry(YoutiPieMusicFormOption option) {
    settings.youtube.musicChartsCountry.save(option.value);
  }

  @override
  Widget build(BuildContext context) {
    final isCharts = endpoint.browseId == YoutiPieMusicBrowseEndpoint.charts.browseId;
    if (!isCharts) {
      return _MusicBrowseView(
        endpoint: endpoint,
        title: title,
        headerBuilder: null,
        onChipTap: _openChip,
        onFormOptionTap: null,
      );
    }
    return ObxO(
      rx: settings.youtube.musicChartsCountry,
      builder: (context, country) {
        final chartsEndpoint = endpoint.withFormValues([country]);
        return _MusicBrowseView(
          key: ValueKey(chartsEndpoint),
          endpoint: chartsEndpoint,
          title: title,
          headerBuilder: null,
          onChipTap: _openChip,
          onFormOptionTap: _saveChartsCountry,
        );
      },
    );
  }
}

class YTMusicSearchResultsSliver extends StatelessWidget {
  final YoutiPieMusicSearchResult result;

  const YTMusicSearchResultsSliver({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final items = result.items;
    final topResult = result.topResult;
    final itemsSliver = SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      sliver: SliverFixedExtentList.builder(
        itemExtent: _MusicDims.rowHeight,
        itemCount: items.length,
        itemBuilder: (context, index) => _MusicListRow(
          item: items[index],
          siblings: items,
          queueTitle: result.query,
        ),
      ),
    );
    if (topResult == null) return itemsSliver;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _MusicTopResultCard(
            topResult: topResult,
            queueTitle: result.query,
          ),
        ),
        itemsSliver,
      ],
    );
  }
}

class _MusicBrowseView extends StatelessWidget {
  final YoutiPieMusicBrowseEndpoint endpoint;
  final String title;
  final Widget Function(Rxn<YoutiPieMusicBrowseResult> resultRx, Widget refreshIconWidget)? headerBuilder;
  final void Function(YoutiPieMusicChip chip) onChipTap;
  final void Function(YoutiPieMusicFormOption option)? onFormOptionTap;

  const _MusicBrowseView({
    super.key,
    required this.endpoint,
    required this.title,
    required this.headerBuilder,
    required this.onChipTap,
    required this.onFormOptionTap,
  });

  @override
  Widget build(BuildContext context) {
    final onFormOptionTap = this.onFormOptionTap;
    final headerBuilder = this.headerBuilder;
    return YoutubeMainPageFetcherAccBase<YoutiPieMusicBrowseResult, YoutiPieMusicShelf>(
      operation: YoutiPieOperation.fetchMusicBrowse,
      transparentShimmer: true,
      title: title,
      headerBuilder:
          headerBuilder ??
          (resultRx, refreshIconWidget) => _MusicPageHeader(
            title: title,
            resultRx: resultRx,
            refreshIconWidget: refreshIconWidget,
          ),
      headerPadding: headerBuilder == null ? EdgeInsets.zero : null,
      cacheReader: YoutiPie.cacheBuilder.forMusicBrowse(endpoint: endpoint),
      networkFetcher: (details) => YoutubeInfoController.music.browse(endpoint, details: details),
      fetchTimeMapKey: ValueKey(endpoint),
      dummyCard: const _MusicShelfDummy(),
      itemExtent: null,
      itemBuilder: (shelf, index, result) => null,
      sliverListBuilder: (result, itemBuilder, dummyCard) => SliverMainAxisGroup(
        slivers: [
          if (onFormOptionTap != null && result.formOptions.isNotEmpty)
            SliverToBoxAdapter(
              child: _MusicFormOptionsChip(
                options: result.formOptions,
                onTap: onFormOptionTap,
              ),
            ),
          if (result.chips.isNotEmpty)
            SliverToBoxAdapter(
              child: _MusicChipsRow(
                chips: result.chips,
                onTap: onChipTap,
              ),
            ),
          _MusicShelvesSliver(
            shelves: result.items,
          ),
        ],
      ),
    );
  }
}

class _MusicNavPills extends StatelessWidget {
  const _MusicNavPills();

  @override
  Widget build(BuildContext context) {
    final pills = [
      (icon: Broken.discover, title: lang.explore, endpoint: YoutiPieMusicBrowseEndpoint.explore),
      (icon: Broken.ranking, title: lang.charts, endpoint: YoutiPieMusicBrowseEndpoint.charts),
      (icon: Broken.happyemoji, title: lang.moods, endpoint: YoutiPieMusicBrowseEndpoint.moodsAndGenres),
      (icon: Broken.magic_star, title: lang.newReleases, endpoint: YoutiPieMusicBrowseEndpoint.newReleases),
    ];
    return SizedBox(
      height: 36.0,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: pills
            .map(
              (pill) => NamidaInkWell(
                bgColor: NColors.card,
                borderRadius: 10.0,
                margin: const EdgeInsets.only(right: 6.0),
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                onTap: () => YTMusicBrowseSubpage(
                  endpoint: pill.endpoint,
                  title: pill.title,
                ).navigate(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pill.icon,
                      size: 16.0,
                    ),
                    const SizedBox(width: 6.0),
                    NamidaText(
                      pill.title,
                      style: NText.medium,
                    ),
                  ],
                ),
              ),
            )
            .toFixedList(),
      ),
    );
  }
}

class _MusicTopResultCard extends StatelessWidget {
  final YoutiPieMusicTopResult topResult;
  final String queueTitle;

  const _MusicTopResultCard({required this.topResult, required this.queueTitle});

  @override
  Widget build(BuildContext context) {
    final item = topResult.item;
    final items = topResult.items;
    final siblings = [item];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 8.0),
      child: NDecoratedBox(
        decoration: (colors) => BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            children: [
              NamidaPopupWrapper(
                openOnTap: false,
                childrenDefault: () => _MusicItemActions.menuItems(item, queueTitle),
                child: NamidaInkWell(
                  borderRadius: 10.0,
                  padding: const EdgeInsets.all(6.0),
                  onTap: () => _MusicItemActions.open(item, siblings, queueTitle),
                  child: Row(
                    children: [
                      _MusicItemArt(
                        item: item,
                        width: _MusicDims.topResultArtSize,
                        height: _MusicDims.topResultArtSize,
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NamidaText(
                              item.getMusicTitle(),
                              style: NText.large,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2.0),
                            NamidaText(
                              topResult.subtitle,
                              style: NText.small,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ...items.map(
                (e) => _MusicListRow(
                  item: e,
                  siblings: items,
                  queueTitle: queueTitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicFormOptionsChip extends StatelessWidget {
  final List<YoutiPieMusicFormOption> options;
  final void Function(YoutiPieMusicFormOption option) onTap;

  const _MusicFormOptionsChip({required this.options, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selectedTitle = options.firstWhereEff((e) => e.isSelected)?.title ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 8.0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: NamidaPopupWrapper(
          childrenDefault: () => options.map(
            (option) => NamidaPopupItem(
              icon: Broken.global,
              title: option.title,
              selected: option.isSelected,
              onTap: () => onTap(option),
            ),
          ),
          child: NamidaInkWell(
            bgColor: NColors.card,
            borderRadius: 10.0,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Broken.global,
                  size: 16.0,
                ),
                const SizedBox(width: 6.0),
                NamidaText(
                  selectedTitle,
                  style: NText.medium,
                ),
                const SizedBox(width: 4.0),
                const Icon(
                  Broken.arrow_down_2,
                  size: 14.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicChipsRow extends StatelessWidget {
  final List<YoutiPieMusicChip> chips;
  final void Function(YoutiPieMusicChip chip) onTap;

  const _MusicChipsRow({required this.chips, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const selectedColor = NColors.secondaryContainer;
    const bgColor = NColors(.card, opacity: 0.5);
    return SizedBox(
      height: 34.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final chip = chips[index];
          return NamidaInkWell(
            borderRadius: 10.0,
            bgColor: chip.isSelected ? selectedColor : bgColor,
            margin: const EdgeInsets.only(right: 6.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            alignment: Alignment.center,
            onTap: () => onTap(chip),
            child: NamidaText(
              chip.title,
              style: NText.medium,
            ),
          );
        },
      ),
    );
  }
}

class _MusicPageHeader extends StatelessWidget {
  final String title;
  final Rxn<YoutiPieMusicBrowseResult> resultRx;
  final Widget refreshIconWidget;

  const _MusicPageHeader({required this.title, required this.resultRx, required this.refreshIconWidget});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: resultRx,
      builder: (context, result) {
        final isChannel = result != null && (result.avatarThumbnails.isNotEmpty || result.bannerThumbnails.isNotEmpty || result.subtitle != null);
        if (isChannel) {
          return _MusicChannelHeader(
            title: title,
            result: result,
            refreshIconWidget: refreshIconWidget,
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: NamidaText(
                  title,
                  style: const NText(.large, size: .s28),
                ),
              ),
              const SizedBox(width: 12.0),
              refreshIconWidget,
            ],
          ),
        );
      },
    );
  }
}

class _MusicChannelHeader extends StatelessWidget {
  final String title;
  final YoutiPieMusicBrowseResult result;
  final Widget refreshIconWidget;

  const _MusicChannelHeader({required this.title, required this.result, required this.refreshIconWidget});

  static const _avatarSize = 86.0;

  @override
  Widget build(BuildContext context) {
    final channelTitle = result.title.isNotEmpty ? result.title : title;
    final avatarUrl = result.avatarThumbnails.pick()?.url;
    final subtitle = result.subtitle;
    final channelId = result.channelId;
    final songsPlaylistId = result.findSongsPlaylistId();
    final hasButtons = songsPlaylistId != null || channelId != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              YoutubeThumbnail(
                key: ValueKey(avatarUrl),
                type: ThumbnailType.channel,
                customUrl: avatarUrl,
                width: _avatarSize,
                isCircle: true,
                isImportantInCache: false,
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NamidaText(
                      channelTitle,
                      style: const NText(.large, size: .s22),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2.0),
                      Row(
                        children: [
                          const NIcon(
                            Broken.profile_2user,
                            size: 13.0,
                            color: NColors(.onSurface, opacity: 0.7),
                          ),
                          const SizedBox(width: 4.0),
                          Expanded(
                            child: NamidaText(
                              subtitle,
                              style: const NText(.small, size: .s12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              refreshIconWidget,
            ],
          ),
          if (hasButtons) ...[
            const SizedBox(height: 12.0),
            Row(
              spacing: 8.0,
              children: [
                if (songsPlaylistId != null) ...[
                  Expanded(
                    child: NamidaButton(
                      dense: true,
                      icon: Broken.shuffle,
                      text: lang.shuffle,
                      onTap: () => _MusicItemActions.playPlaylist(songsPlaylistId, channelTitle, shuffle: true),
                    ),
                  ),
                  Expanded(
                    child: NamidaButton(
                      dense: true,
                      icon: Broken.play,
                      text: lang.play,
                      onTap: () => _MusicItemActions.playPlaylist(songsPlaylistId, channelTitle, shuffle: false),
                    ),
                  ),
                ],
                if (channelId != null)
                  Expanded(
                    child: NamidaButton(
                      dense: true,
                      colors: .mid,
                      icon: Broken.user,
                      text: lang.channel,
                      onTap: () => YTChannelSubpage(
                        channelID: channelId,
                      ).navigate(),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
