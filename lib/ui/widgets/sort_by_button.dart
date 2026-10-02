import 'package:flutter/material.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/romanizer/romanizer.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';

class SortByMenuTracks with SortByMenuBase {
  const SortByMenuTracks();

  @override
  List<Widget> children(BuildContext context) {
    return [
      _SortAdvancedHeader(
        onTap: () => NamidaOnTaps.inst.onSubPageTracksSortIconTap(MediaType.track),
      ),
      Obx(
        (context) {
          final sorts = settings.mediaItemsTrackSorting.valueR[MediaType.track] ?? const <SortType>[];
          final isReversed = settings.mediaItemsTrackSortingReverse.valueR[MediaType.track] == true;
          final prefixFilters = SortOptionsCards.prefixFiltersOfTracks(sorts);
          return SortOptionsCards(
            isReversed: isReversed,
            onReverseTap: () => SearchSortController.inst.sortMedia(MediaType.track, reverse: !isReversed),
            withSortKeyOptions: true,
            prefixFilters: prefixFilters,
          );
        },
      ),
      ...SortType.forTracks().map(
        (e) => ObxO(
          rx: settings.mediaItemsTrackSorting,
          builder: (context, mediaItemsTrackSorting) => SmallListTile(
            borderRadius: 12.0,
            visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
            title: e.toText(),
            trailingIcon: e.toIcon(),
            active: mediaItemsTrackSorting[MediaType.track]?.firstOrNull == e,
            onTap: () => SearchSortController.inst.sortMedia(MediaType.track, sortBy: e, forceSingleSorting: true),
          ),
        ),
      ),
    ];
  }
}

class SortByMenuTracksSearch extends StatelessWidget {
  const SortByMenuTracksSearch({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.height * 0.5,
      child: SmoothSingleChildScrollView(
        child: Obx(
          (context) {
            final tracksSortSearch = settings.tracksSortSearch.valueR;
            final reversed = settings.tracksSortSearchReversed.valueR;
            final isAuto = settings.tracksSortSearchIsAuto.valueR;
            final activeSortType = isAuto ? settings.mediaItemsTrackSorting.valueR[MediaType.track]?.firstOrNull : tracksSortSearch;
            final prefixFilters = SortOptionsCards.prefixFiltersOfTracks([?activeSortType]);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
                  child: ListTileWithCheckMark(
                    borderRadius: 10.0,
                    icon: Broken.medal_star,
                    title: lang.auto,
                    activeRx: settings.tracksSortSearchIsAuto,
                    onTap: () {
                      settings.tracksSortSearchIsAuto.save(!settings.tracksSortSearchIsAuto.value);
                      if (settings.tracksSortSearchIsAuto.value) {
                        SearchSortController.inst.searchTracks(ScrollSearchController.inst.searchTextEditingController.text, temp: true);
                      } else {
                        SearchSortController.inst.sortTracksSearch();
                      }
                    },
                  ),
                ),
                TapDetector(
                  onTap: isAuto ? () {} : null,
                  child: ColoredBox(
                    color: Colors.transparent,
                    child: IgnorePointer(
                      ignoring: isAuto,
                      child: AnimatedOpacity(
                        opacity: isAuto ? 0.6 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          children: [
                            SortOptionsCards(
                              isReversed: isAuto ? false : reversed,
                              onReverseTap: () => SearchSortController.inst.sortTracksSearch(reverse: !reversed),
                              withSortKeyOptions: true,
                              prefixFilters: prefixFilters,
                            ),
                            ...SortType.forTracks().map(
                              (e) => SmallListTile(
                                borderRadius: 12.0,
                                visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
                                title: e.toText(),
                                trailingIcon: e.toIcon(),
                                active: activeSortType == e,
                                onTap: () {
                                  SearchSortController.inst.sortTracksSearch(sortBy: e);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SortByMenuAlbums with SortByMenuBase {
  const SortByMenuAlbums();

  @override
  List<Widget> children(BuildContext context) => [
    _SortAdvancedHeader(
      onTap: () => NamidaOnTaps.inst.onGroupSortIconTap(MediaType.album),
    ),
    Obx(
      (context) {
        final isReversed = settings.albumSortReversed.valueR;
        final prefixFilters = SortOptionsCards.prefixFiltersOfGroups(settings.albumSorts.valueR);
        return SortOptionsCards(
          isReversed: isReversed,
          onReverseTap: () => SearchSortController.inst.sortMedia(MediaType.album, reverse: !isReversed),
          withSortKeyOptions: true,
          prefixFilters: prefixFilters,
        );
      },
    ),
    ...GroupSortType.forAlbums().map(
      (e) => ObxO(
        rx: settings.albumSorts,
        builder: (context, albumSorts) => SmallListTile(
          borderRadius: 12.0,
          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
          title: e.toText(),
          trailingIcon: e.toIcon(),
          active: albumSorts.first == e,
          onTap: () => SearchSortController.inst.sortMedia(MediaType.album, groupSorts: [e]),
        ),
      ),
    ),
  ];
}

class SortByMenuArtists with SortByMenuBase {
  const SortByMenuArtists();

  @override
  List<Widget> children(BuildContext context) {
    final artistType = settings.activeArtistType.value;
    return [
      _SortAdvancedHeader(
        onTap: () => NamidaOnTaps.inst.onGroupSortIconTap(settings.activeArtistType.value),
      ),
      Obx(
        (context) {
          final isReversed = settings.artistSortReversed.valueR;
          final prefixFilters = SortOptionsCards.prefixFiltersOfGroups(settings.artistSorts.valueR);
          return SortOptionsCards(
            isReversed: isReversed,
            onReverseTap: () => SearchSortController.inst.sortMedia(settings.activeArtistType.value, reverse: !isReversed),
            withSortKeyOptions: true,
            prefixFilters: prefixFilters,
          );
        },
      ),
      ...GroupSortType.forArtists(artistType).map(
        (e) => ObxO(
          rx: settings.artistSorts,
          builder: (context, artistSorts) => SmallListTile(
            borderRadius: 12.0,
            visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
            title: e.toText(),
            trailingIcon: e.toIcon(),
            active: artistSorts.first == e,
            onTap: () => SearchSortController.inst.sortMedia(MediaType.artist, groupSorts: [e]),
          ),
        ),
      ),
    ];
  }
}

class SortByMenuGenres with SortByMenuBase {
  const SortByMenuGenres();

  @override
  List<Widget> children(BuildContext context) => [
    _SortAdvancedHeader(
      onTap: () => NamidaOnTaps.inst.onGroupSortIconTap(settings.activeGenreType.value),
    ),
    Obx(
      (context) {
        final isReversed = settings.genreSortReversed.valueR;
        final prefixFilters = SortOptionsCards.prefixFiltersOfGroups(settings.genreSorts.valueR);
        return SortOptionsCards(
          isReversed: isReversed,
          onReverseTap: () => SearchSortController.inst.sortMedia(settings.activeGenreType.value, reverse: !isReversed),
          withSortKeyOptions: true,
          prefixFilters: prefixFilters,
        );
      },
    ),
    ...GroupSortType.forGenres().map(
      (e) => ObxO(
        rx: settings.genreSorts,
        builder: (context, genreSorts) => SmallListTile(
          borderRadius: 12.0,
          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
          title: e.toText(),
          trailingIcon: e.toIcon(),
          active: genreSorts.first == e,
          onTap: () => SearchSortController.inst.sortMedia(MediaType.genre, groupSorts: [e]),
        ),
      ),
    ),
  ];
}

class SortByMenuPlaylist with SortByMenuBase {
  const SortByMenuPlaylist();

  @override
  List<Widget> children(BuildContext context) => [
    _SortAdvancedHeader(
      onTap: () => NamidaOnTaps.inst.onGroupSortIconTap(MediaType.playlist),
    ),
    ObxO(
      rx: settings.playlistSortReversed,
      builder: (context, isReversed) => SortOptionsCards(
        isReversed: isReversed,
        onReverseTap: () => SearchSortController.inst.sortMedia(MediaType.playlist, reverse: !isReversed),
        withSortKeyOptions: true,
        prefixFilters: null,
      ),
    ),
    ...GroupSortType.forPlaylists().map(
      (e) => ObxO(
        rx: settings.playlistSorts,
        builder: (context, playlistSorts) => SmallListTile(
          borderRadius: 12.0,
          visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
          title: e.toText(),
          trailingIcon: e.toIcon(),
          active: playlistSorts.first == e,
          onTap: () => SearchSortController.inst.sortMedia(MediaType.playlist, groupSorts: [e]),
        ),
      ),
    ),
  ];
}

class SortOptionsCards extends StatelessWidget {
  final bool isReversed;
  final VoidCallback onReverseTap;
  final bool withSortKeyOptions;
  final Set<TrackSearchFilter>? prefixFilters;
  final bool showTitles;

  const SortOptionsCards({
    super.key,
    required this.isReversed,
    required this.onReverseTap,
    required this.withSortKeyOptions,
    required this.prefixFilters,
    this.showTitles = false,
  });

  static Set<TrackSearchFilter> prefixFiltersOfTracks(Iterable<SortType> sorts) => {for (final sort in sorts) ?sort.toIgnorePrefixFilter()};

  static Set<TrackSearchFilter> prefixFiltersOfGroups(Iterable<GroupSortType> sorts) => {for (final sort in sorts) ?sort.toIgnorePrefixFilter()};

  @override
  Widget build(BuildContext context) {
    final showRomanization = withSortKeyOptions && (settings.romanizeSorting.value || Romanizer.inst.hasRomanizableSortText);
    final prefixFilters = this.prefixFilters;
    final cardsRow = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _SortOptionCard(
            icon: Broken.arrange_circle,
            title: lang.reverseOrder,
            showTitle: showTitles,
            active: isReversed,
            onTap: onReverseTap,
          ),
        ),
        if (prefixFilters != null) ...[
          const SizedBox(
            width: 4.0,
          ),
          Expanded(
            child: _SortIgnorePrefixCard(
              filters: prefixFilters,
              showTitle: showTitles,
            ),
          ),
        ],
        if (showRomanization) ...[
          const SizedBox(
            width: 4.0,
          ),
          Expanded(
            child: _SortRomanizationCard(
              showTitle: showTitles,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicHeight(
            child: cardsRow,
          ),
          if (showRomanization) const _SortDictionaryTile(),
        ],
      ),
    );
  }
}

class _SortAdvancedHeader extends StatelessWidget {
  final VoidCallback onTap;

  const _SortAdvancedHeader({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NamidaInkWell(
          borderRadius: 10.0,
          margin: EdgeInsets.symmetric(horizontal: 6.0),
          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          bgColor: theme.colorScheme.secondaryContainer.withOpacityExt(0.4),
          onTap: () {
            NamidaNavigator.inst.popMenu();
            onTap();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  lang.advanced,
                  style: textTheme.displayMedium?.copyWith(fontSize: 14.0),
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
              Icon(
                Broken.sort,
                size: 20.0,
              ),
            ],
          ),
        ),
        NamidaContainerDivider(
          margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
        ),
      ],
    );
  }
}

class _SortOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool showTitle;
  final bool active;
  final bool halfActive;
  final VoidCallback? onTap;

  const _SortOptionCard({
    required this.icon,
    required this.title,
    required this.showTitle,
    required this.active,
    this.halfActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final tileAlpha = context.isDarkMode ? 5 : 20;
    final inactiveColor = Color.alphaBlend(theme.colorScheme.onSurface.withAlpha(tileAlpha), theme.cardTheme.color!);
    final activeColor = theme.colorScheme.secondaryContainer;
    final bgColor = active
        ? activeColor
        : halfActive
        ? Color.alphaBlend(activeColor.withOpacityExt(0.4), inactiveColor)
        : inactiveColor;
    final isEnabled = onTap != null;
    final card = NamidaInkWell(
      borderRadius: 10.0,
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 10.0),
      animationDurationMS: 200,
      bgColor: bgColor,
      onTap: onTap,
      child: showTitle
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22.0,
                ),
                const SizedBox(
                  height: 4.0,
                ),
                Text(
                  title,
                  style: textTheme.displaySmall?.copyWith(fontSize: 12.0),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          : Icon(
              icon,
              size: 20.0,
            ),
    );
    return AnimatedOpacity(
      opacity: isEnabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: NamidaTooltip(
        message: showTitle ? null : () => title,
        child: card,
      ),
    );
  }
}

class _SortRomanizationCard extends StatelessWidget {
  final bool showTitle;

  const _SortRomanizationCard({
    required this.showTitle,
  });

  void _onTap() {
    final isEnabled = settings.romanizeSorting.value;
    Romanizer.inst.setSortingEnabled(!isEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.romanizeSorting,
      builder: (context, romanizeSorting) => _SortOptionCard(
        icon: Broken.translate,
        title: lang.romanization,
        showTitle: showTitle,
        active: romanizeSorting,
        onTap: _onTap,
      ),
    );
  }
}

class _SortIgnorePrefixCard extends StatelessWidget {
  final Set<TrackSearchFilter> filters;
  final bool showTitle;

  const _SortIgnorePrefixCard({
    required this.filters,
    required this.showTitle,
  });

  void _onTap(bool isAllIgnored) {
    settings.ignoreCommonPrefixForTypes.update((list) {
      if (isAllIgnored) {
        list.removeWhere(filters.contains);
      } else {
        for (final filter in filters) {
          list.addNoDuplicates(filter);
        }
      }
    });
    Indexer.inst.resortAllAfterSortKeysChange();
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.ignoreCommonPrefixForTypes,
      builder: (context, ignoreCommonPrefixForTypes) {
        final ignoredCount = filters.where(ignoreCommonPrefixForTypes.contains).length;
        final isAllIgnored = filters.isNotEmpty && ignoredCount == filters.length;
        return _SortOptionCard(
          icon: Broken.message_remove,
          title: lang.ignorePrefixes,
          showTitle: showTitle,
          active: isAllIgnored,
          halfActive: ignoredCount > 0 && !isAllIgnored,
          onTap: filters.isEmpty ? null : () => _onTap(isAllIgnored),
        );
      },
    );
  }
}

class _SortDictionaryTile extends StatelessWidget {
  const _SortDictionaryTile();

  void _onTap() {
    if (Romanizer.inst.downloadProgress.value != null) {
      Romanizer.inst.cancelDownload();
    } else {
      Romanizer.inst.downloadDictionary();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return ObxO(
      rx: settings.romanizeSorting,
      builder: (context, romanizeSorting) {
        if (!romanizeSorting || !Romanizer.inst.sortingNeedsDictionary) return const SizedBox();
        return ObxO(
          rx: Romanizer.inst.isDictionaryInstalled,
          builder: (context, isDictionaryInstalled) {
            if (isDictionaryInstalled) return const SizedBox();
            return NamidaInkWell(
              borderRadius: 10.0,
              margin: const EdgeInsets.only(top: 4.0),
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              bgColor: theme.colorScheme.secondaryContainer.withOpacityExt(0.4),
              onTap: _onTap,
              child: Row(
                children: [
                  const Icon(
                    Broken.book,
                    size: 20.0,
                  ),
                  const SizedBox(
                    width: 12.0,
                  ),
                  Expanded(
                    child: Text(
                      lang.dictionary,
                      style: textTheme.displayMedium,
                    ),
                  ),
                  const SizedBox(
                    width: 6.0,
                  ),
                  ObxO(
                    rx: Romanizer.inst.downloadProgress,
                    builder: (context, downloadProgress) {
                      final statusText = downloadProgress != null ? '${(downloadProgress * 100).round()}%' : lang.download;
                      return Text(
                        statusText,
                        style: textTheme.displaySmall,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

extension _SortTypeIgnorePrefix on SortType {
  TrackSearchFilter? toIgnorePrefixFilter() => switch (this) {
    SortType.title || SortType.titleSort => TrackSearchFilter.title,
    SortType.album || SortType.albumSort => TrackSearchFilter.album,
    SortType.albumArtist || SortType.albumArtistSort => TrackSearchFilter.albumartist,
    SortType.artistsList || SortType.artistSort => TrackSearchFilter.artist,
    SortType.genresList => TrackSearchFilter.genre,
    SortType.composer || SortType.composerSort => TrackSearchFilter.composer,
    SortType.filename => TrackSearchFilter.filename,
    SortType.year ||
    SortType.dateAdded ||
    SortType.dateModified ||
    SortType.bitrate ||
    SortType.trackNo ||
    SortType.discNo ||
    SortType.path ||
    SortType.duration ||
    SortType.sampleRate ||
    SortType.bitDepth ||
    SortType.bpm ||
    SortType.size ||
    SortType.rating ||
    SortType.shuffle ||
    SortType.shuffleDaily ||
    SortType.mostPlayed ||
    SortType.latestPlayed ||
    SortType.firstListen => null,
  };
}

extension _GroupSortTypeIgnorePrefix on GroupSortType {
  TrackSearchFilter? toIgnorePrefixFilter() => switch (this) {
    GroupSortType.album || GroupSortType.albumSort => TrackSearchFilter.album,
    GroupSortType.albumArtist || GroupSortType.albumArtistSort => TrackSearchFilter.albumartist,
    GroupSortType.artistsList || GroupSortType.artistSort => TrackSearchFilter.artist,
    GroupSortType.genresList => TrackSearchFilter.genre,
    GroupSortType.composer || GroupSortType.composerSort => TrackSearchFilter.composer,
    GroupSortType.title ||
    GroupSortType.year ||
    GroupSortType.dateAdded ||
    GroupSortType.dateModified ||
    GroupSortType.label ||
    GroupSortType.releaseType ||
    GroupSortType.bpm ||
    GroupSortType.duration ||
    GroupSortType.numberOfTracks ||
    GroupSortType.playCount ||
    GroupSortType.latestPlayed ||
    GroupSortType.lastPlayed ||
    GroupSortType.firstListen ||
    GroupSortType.albumsCount ||
    GroupSortType.creationDate ||
    GroupSortType.modifiedDate ||
    GroupSortType.shuffle ||
    GroupSortType.custom => null,
  };
}
