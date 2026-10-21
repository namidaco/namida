import 'package:flutter/material.dart';

import 'package:namida/class/sort_chain.dart';
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
import 'package:namida/core/ntheme.dart';
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
          final sorting = settings.mediaItemsTrackSorting.valueR[MediaType.track] ?? const SortChain<SortType>([]);
          final isReversed = sorting.reverse;
          final prefixFilters = SortOptionsCards.prefixFiltersOfTracks(sorting.types());
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
            active: mediaItemsTrackSorting[MediaType.track]?.firstType == e,
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
            final activeSortType = isAuto ? settings.mediaItemsTrackSorting.valueR[MediaType.track]?.firstType : tracksSortSearch;
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
        final sorting = settings.groupSortingOfR(MediaType.album);
        final isReversed = sorting.reverse;
        final prefixFilters = SortOptionsCards.prefixFiltersOfGroups(sorting.types());
        return SortOptionsCards(
          isReversed: isReversed,
          onReverseTap: () => SearchSortController.inst.sortMedia(MediaType.album, reverse: !isReversed),
          withSortKeyOptions: true,
          prefixFilters: prefixFilters,
        );
      },
    ),
    ...GroupSortType.forAlbums().map(
      (e) => Obx(
        (context) {
          final sorting = settings.groupSortingOfR(MediaType.album);
          return SmallListTile(
            borderRadius: 12.0,
            visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
            title: e.toText(),
            trailingIcon: e.toIcon(),
            active: sorting.firstType == e,
            onTap: () => SearchSortController.inst.sortMedia(MediaType.album, groupSorting: sorting.withSingle(e)),
          );
        },
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
          final sorting = settings.groupSortingOfR(MediaType.artist);
          final isReversed = sorting.reverse;
          final prefixFilters = SortOptionsCards.prefixFiltersOfGroups(sorting.types());
          return SortOptionsCards(
            isReversed: isReversed,
            onReverseTap: () => SearchSortController.inst.sortMedia(settings.activeArtistType.value, reverse: !isReversed),
            withSortKeyOptions: true,
            prefixFilters: prefixFilters,
          );
        },
      ),
      ...GroupSortType.forArtists(artistType).map(
        (e) => Obx(
          (context) {
            final sorting = settings.groupSortingOfR(MediaType.artist);
            return SmallListTile(
              borderRadius: 12.0,
              visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
              title: e.toText(),
              trailingIcon: e.toIcon(),
              active: sorting.firstType == e,
              onTap: () => SearchSortController.inst.sortMedia(MediaType.artist, groupSorting: sorting.withSingle(e)),
            );
          },
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
        final sorting = settings.groupSortingOfR(MediaType.genre);
        final isReversed = sorting.reverse;
        final prefixFilters = SortOptionsCards.prefixFiltersOfGroups(sorting.types());
        return SortOptionsCards(
          isReversed: isReversed,
          onReverseTap: () => SearchSortController.inst.sortMedia(settings.activeGenreType.value, reverse: !isReversed),
          withSortKeyOptions: true,
          prefixFilters: prefixFilters,
        );
      },
    ),
    ...GroupSortType.forGenres().map(
      (e) => Obx(
        (context) {
          final sorting = settings.groupSortingOfR(MediaType.genre);
          return SmallListTile(
            borderRadius: 12.0,
            visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
            title: e.toText(),
            trailingIcon: e.toIcon(),
            active: sorting.firstType == e,
            onTap: () => SearchSortController.inst.sortMedia(MediaType.genre, groupSorting: sorting.withSingle(e)),
          );
        },
      ),
    ),
  ];
}

class SortByMenuLanguages with SortByMenuBase {
  const SortByMenuLanguages();

  @override
  List<Widget> children(BuildContext context) => [
    _SortAdvancedHeader(
      onTap: () => NamidaOnTaps.inst.onGroupSortIconTap(MediaType.language),
    ),
    Obx(
      (context) {
        final sorting = settings.groupSortingOfR(MediaType.language);
        final isReversed = sorting.reverse;
        final prefixFilters = SortOptionsCards.prefixFiltersOfGroups(sorting.types());
        return SortOptionsCards(
          isReversed: isReversed,
          onReverseTap: () => SearchSortController.inst.sortMedia(MediaType.language, reverse: !isReversed),
          withSortKeyOptions: true,
          prefixFilters: prefixFilters,
        );
      },
    ),
    ...GroupSortType.forLanguages().map(
      (e) => Obx(
        (context) {
          final sorting = settings.groupSortingOfR(MediaType.language);
          return SmallListTile(
            borderRadius: 12.0,
            visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
            title: e.toText(),
            trailingIcon: e.toIcon(),
            active: sorting.firstType == e,
            onTap: () => SearchSortController.inst.sortMedia(MediaType.language, groupSorting: sorting.withSingle(e)),
          );
        },
      ),
    ),
  ];
}

class SortByMenuMoodsTags with SortByMenuBase {
  final MediaType type;

  const SortByMenuMoodsTags(this.type);

  @override
  List<Widget> children(BuildContext context) {
    final type = this.type;
    return [
      _SortAdvancedHeader(
        onTap: () => NamidaOnTaps.inst.onGroupSortIconTap(type),
      ),
      Obx(
        (context) {
          final sorting = settings.groupSortingOfR(type);
          final isReversed = sorting.reverse;
          final prefixFilters = SortOptionsCards.prefixFiltersOfGroups(sorting.types());
          return SortOptionsCards(
            isReversed: isReversed,
            onReverseTap: () => SearchSortController.inst.sortMedia(type, reverse: !isReversed),
            withSortKeyOptions: true,
            prefixFilters: prefixFilters,
          );
        },
      ),
      ...GroupSortType.forMoodsTags().map(
        (e) => Obx(
          (context) {
            final sorting = settings.groupSortingOfR(type);
            return SmallListTile(
              borderRadius: 12.0,
              visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
              title: e.toText(),
              trailingIcon: e.toIcon(),
              active: sorting.firstType == e,
              onTap: () => SearchSortController.inst.sortMedia(type, groupSorting: sorting.withSingle(e)),
            );
          },
        ),
      ),
    ];
  }
}

class SortByMenuPlaylist with SortByMenuBase {
  const SortByMenuPlaylist();

  @override
  List<Widget> children(BuildContext context) => [
    _SortAdvancedHeader(
      onTap: () => NamidaOnTaps.inst.onGroupSortIconTap(MediaType.playlist),
    ),
    Obx(
      (context) {
        final sorting = settings.groupSortingOfR(MediaType.playlist);
        final isReversed = sorting.reverse;
        return SortOptionsCards(
          isReversed: isReversed,
          onReverseTap: () => SearchSortController.inst.sortMedia(MediaType.playlist, reverse: !isReversed),
          withSortKeyOptions: true,
          prefixFilters: null,
        );
      },
    ),
    ...GroupSortType.forPlaylists().map(
      (e) => Obx(
        (context) {
          final sorting = settings.groupSortingOfR(MediaType.playlist);
          return SmallListTile(
            borderRadius: 12.0,
            visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
            title: e.toText(),
            trailingIcon: e.toIcon(),
            active: sorting.firstType == e,
            onTap: () => SearchSortController.inst.sortMedia(MediaType.playlist, groupSorting: sorting.withSingle(e)),
          );
        },
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
  final bool dense;

  const SortOptionsCards({
    super.key,
    required this.isReversed,
    required this.onReverseTap,
    required this.withSortKeyOptions,
    required this.prefixFilters,
    this.showTitles = false,
    this.dense = false,
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
          child: NamidaToggleCard(
            icon: Broken.arrange_circle,
            title: lang.reverseOrder,
            showTitle: showTitles,
            dense: dense,
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
              dense: dense,
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
              dense: dense,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NamidaInkWell(
          borderRadius: 10.0,
          margin: const EdgeInsets.symmetric(horizontal: 6.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          bgColor: const NColors(.secondaryContainer, opacity: 0.4),
          onTap: () {
            NamidaNavigator.inst.popMenu();
            onTap();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: NamidaText(
                  lang.advanced,
                  style: const NText(.medium, size: .s14),
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
              const Icon(
                Broken.sort,
                size: 20.0,
              ),
            ],
          ),
        ),
        const NamidaContainerDivider(
          margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
        ),
      ],
    );
  }
}

class _SortRomanizationCard extends StatelessWidget {
  final bool showTitle;
  final bool dense;

  const _SortRomanizationCard({
    required this.showTitle,
    required this.dense,
  });

  void _onTap() {
    final isEnabled = settings.romanizeSorting.value;
    Romanizer.inst.setSortingEnabled(!isEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.romanizeSorting,
      builder: (context, romanizeSorting) => NamidaToggleCard(
        icon: Broken.translate,
        title: lang.romanization,
        showTitle: showTitle,
        dense: dense,
        active: romanizeSorting,
        onTap: _onTap,
      ),
    );
  }
}

class _SortIgnorePrefixCard extends StatelessWidget {
  final Set<TrackSearchFilter> filters;
  final bool showTitle;
  final bool dense;

  const _SortIgnorePrefixCard({
    required this.filters,
    required this.showTitle,
    required this.dense,
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
        return NamidaToggleCard(
          icon: Broken.message_remove,
          title: lang.ignorePrefixes,
          showTitle: showTitle,
          dense: dense,
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
              bgColor: const NColors(.secondaryContainer, opacity: 0.4),
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
                    child: NamidaText(
                      lang.dictionary,
                      style: NText.medium,
                    ),
                  ),
                  const SizedBox(
                    width: 6.0,
                  ),
                  ObxO(
                    rx: Romanizer.inst.downloadProgress,
                    builder: (context, downloadProgress) {
                      final statusText = downloadProgress != null ? '${(downloadProgress * 100).round()}%' : lang.download;
                      return NamidaText(
                        statusText,
                        style: NText.small,
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
    SortType.favourite ||
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
    GroupSortType.shuffleDaily ||
    GroupSortType.custom => null,
  };
}
