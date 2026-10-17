part of 'yt_music_page.dart';

/// grids become real [SliverGrid]s, everything between them goes in one lazily built list.
class _MusicShelvesSliver extends StatelessWidget {
  final List<YoutiPieMusicShelf> shelves;

  const _MusicShelvesSliver({required this.shelves});

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[];
    int runStart = 0;
    void addRun(int end) {
      if (end <= runStart) return;
      final runShelves = shelves.sublist(runStart, end);
      slivers.add(
        _MusicShelvesList(
          shelves: runShelves,
        ),
      );
    }

    for (int i = 0; i < shelves.length; i++) {
      final shelf = shelves[i];
      if (shelf.layout != YoutiPieMusicShelfLayout.grid) continue;
      addRun(i);
      runStart = i + 1;
      if (shelf.hasHeader) {
        slivers.add(
          SliverToBoxAdapter(
            child: _MusicShelfHeader(
              shelf: shelf,
            ),
          ),
        );
      }
      slivers.add(
        _MusicShelfGrid(
          shelf: shelf,
        ),
      );
    }
    addRun(shelves.length);

    return SliverMainAxisGroup(
      slivers: slivers,
    );
  }
}

class _MusicShelvesList extends StatelessWidget {
  final List<YoutiPieMusicShelf> shelves;

  const _MusicShelvesList({required this.shelves});

  @override
  Widget build(BuildContext context) {
    final bodyExtents = shelves.map((e) => e.computeBodyExtent()).toFixedList();
    return SliverVariedExtentList.builder(
      itemCount: shelves.length,
      itemExtentBuilder: (index, _) => shelves[index].computeHeaderExtent() + bodyExtents[index] + _MusicDims.shelfBottomPadding,
      itemBuilder: (context, index) => _MusicShelfView(
        shelf: shelves[index],
        bodyExtent: bodyExtents[index],
      ),
    );
  }
}

class _MusicShelfView extends StatelessWidget {
  final YoutiPieMusicShelf shelf;
  final double bodyExtent;

  const _MusicShelfView({required this.shelf, required this.bodyExtent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _MusicDims.shelfBottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shelf.hasHeader)
            _MusicShelfHeader(
              shelf: shelf,
            ),
          SizedBox(
            height: bodyExtent,
            child: switch (shelf.layout) {
              YoutiPieMusicShelfLayout.carousel => _MusicShelfCarousel(
                shelf: shelf,
              ),
              YoutiPieMusicShelfLayout.rows => _MusicShelfRows(
                shelf: shelf,
              ),
              YoutiPieMusicShelfLayout.list || YoutiPieMusicShelfLayout.grid => _MusicShelfList(
                shelf: shelf,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _MusicShelfHeader extends StatelessWidget {
  final YoutiPieMusicShelf shelf;

  const _MusicShelfHeader({required this.shelf});

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final strapline = shelf.strapline;
    final avatarUrl = shelf.thumbnails.pick()?.url;
    final moreEndpoint = shelf.moreEndpoint;
    final headerExtent = shelf.computeHeaderExtent();
    return SizedBox(
      height: headerExtent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          children: [
            if (avatarUrl != null) ...[
              YoutubeThumbnail(
                key: Key(avatarUrl),
                type: ThumbnailType.channel,
                customUrl: avatarUrl,
                width: 28.0,
                isCircle: true,
                isImportantInCache: false,
              ),
              const SizedBox(width: 8.0),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (strapline != null)
                    Text(
                      strapline,
                      style: textTheme.displaySmall?.copyWith(fontSize: 10.0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    shelf.title,
                    style: textTheme.displayLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (moreEndpoint != null)
              NamidaInkWell(
                borderRadius: 10.0,
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                onTap: () => _MusicItemActions.openEndpoint(moreEndpoint, shelf.title),
                child: Text(
                  lang.more,
                  style: textTheme.displaySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MusicShelfCarousel extends StatelessWidget {
  final YoutiPieMusicShelf shelf;

  const _MusicShelfCarousel({required this.shelf});

  @override
  Widget build(BuildContext context) {
    final items = shelf.items;
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12.0 - _MusicDims.cardSpacing / 2),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final artSize = _MusicDims.cardArtSize(item, width: null);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: _MusicDims.cardSpacing / 2),
          child: _MusicCard(
            item: item,
            siblings: items,
            queueTitle: shelf.title,
            artWidth: artSize.width,
            artHeight: artSize.height,
          ),
        );
      },
    );
  }
}

class _MusicShelfRows extends StatelessWidget {
  final YoutiPieMusicShelf shelf;

  const _MusicShelfRows({required this.shelf});

  @override
  Widget build(BuildContext context) {
    final items = shelf.items;
    final rowsPerColumn = shelf.rowsPerColumn;
    final columnsCount = (items.length / rowsPerColumn).ceil();
    final firstItem = items.first;
    final isNavigation = firstItem is MusicNavigationItem;
    final rowsColumnWidth = (context.width * 0.86).withMaximum(_MusicDims.rowsColumnMaxWidth);
    final columnWidth = isNavigation
        ? _MusicDims.navButtonWidth
        : firstItem is ChannelInfoItem
        ? _MusicDims.artistsColumnWidth
        : rowsColumnWidth;
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      itemExtent: columnWidth,
      itemCount: columnsCount,
      itemBuilder: (context, columnIndex) {
        final start = columnIndex * rowsPerColumn;
        final end = (start + rowsPerColumn).withMaximum(items.length);
        return Column(
          children: [
            for (int i = start; i < end; i++)
              isNavigation
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: _MusicDims.navButtonSpacing / 2),
                      child: _MusicNavButton(
                        item: items[i] as MusicNavigationItem,
                      ),
                    )
                  : _MusicListRow(
                      item: items[i],
                      siblings: items,
                      queueTitle: shelf.title,
                    ),
          ],
        );
      },
    );
  }
}

class _MusicShelfList extends StatelessWidget {
  final YoutiPieMusicShelf shelf;

  const _MusicShelfList({required this.shelf});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: shelf.items
          .map(
            (item) => _MusicListRow(
              item: item,
              siblings: shelf.items,
              queueTitle: shelf.title,
            ),
          )
          .toFixedList(),
    );
  }
}

class _MusicShelfGrid extends StatelessWidget {
  final YoutiPieMusicShelf shelf;

  const _MusicShelfGrid({required this.shelf});

  @override
  Widget build(BuildContext context) {
    final items = shelf.items;
    const horizontalPadding = 12.0;
    if (items.first is MusicNavigationItem) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(horizontalPadding, 0.0, horizontalPadding, _MusicDims.shelfBottomPadding),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: _MusicDims.navButtonWidth * 1.2,
            mainAxisExtent: _MusicDims.navButtonHeight,
            mainAxisSpacing: _MusicDims.navButtonSpacing,
            crossAxisSpacing: _MusicDims.navButtonSpacing,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _MusicNavButton(
            item: items[index] as MusicNavigationItem,
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(horizontalPadding, 0.0, horizontalPadding, _MusicDims.shelfBottomPadding),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          const spacing = _MusicDims.cardSpacing;
          final width = constraints.crossAxisExtent;
          final fittingCount = ((width + spacing) / (_MusicDims.cardSize + spacing)).floor();
          final count = fittingCount.withMinimum(2);
          final cellWidth = (width - spacing * (count - 1)) / count;
          final artSize = _MusicDims.cardArtSize(items.first, width: cellWidth);
          final cellHeight = artSize.height + _MusicDims.cardTextHeight;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              mainAxisExtent: cellHeight,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _MusicCard(
              item: items[index],
              siblings: items,
              queueTitle: shelf.title,
              artWidth: artSize.width,
              artHeight: artSize.height,
            ),
          );
        },
      ),
    );
  }
}

class _MusicShelfDummy extends StatelessWidget {
  const _MusicShelfDummy();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 0.0, _MusicDims.shelfBottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NamidaDummyContainer(
            width: 140.0,
            height: 18.0,
            borderRadius: 6.0,
            shimmerEnabled: true,
            child: null,
          ),
          const SizedBox(height: 12.0),
          SizedBox(
            height: _MusicDims.cardSize,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(right: _MusicDims.cardSpacing),
                child: NamidaDummyContainer(
                  width: _MusicDims.cardSize,
                  height: _MusicDims.cardSize,
                  borderRadius: 10.0,
                  shimmerEnabled: true,
                  child: null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _MusicShelfExtents on YoutiPieMusicShelf {
  bool get hasHeader => title.isNotEmpty || strapline != null;

  double computeHeaderExtent() {
    if (!hasHeader) return 0.0;
    final straplineExtent = strapline == null ? 0.0 : _MusicDims.straplineHeight;
    return _MusicDims.headerHeight + straplineExtent;
  }

  double computeBodyExtent() {
    switch (layout) {
      case YoutiPieMusicShelfLayout.carousel:
        double maxArtHeight = 0.0;
        for (final item in items) {
          final artHeight = _MusicDims.cardArtSize(item, width: null).height;
          if (artHeight > maxArtHeight) maxArtHeight = artHeight;
        }
        return maxArtHeight + _MusicDims.cardTextHeight;
      case YoutiPieMusicShelfLayout.rows:
        final rowsCount = rowsPerColumn.withMaximum(items.length);
        final rowExtent = items.first is MusicNavigationItem ? _MusicDims.navButtonHeight + _MusicDims.navButtonSpacing : _MusicDims.rowHeight;
        return rowsCount * rowExtent;
      case YoutiPieMusicShelfLayout.list || YoutiPieMusicShelfLayout.grid:
        return items.length * _MusicDims.rowHeight;
    }
  }
}

class _MusicDims {
  static const cardSize = 136.0;
  static const videoCardHeight = 102.0;
  static const cardTextHeight = 52.0;
  static const cardSpacing = 10.0;
  static const rowHeight = 58.0;
  static const rowArtSize = 46.0;
  static const rowsColumnMaxWidth = 380.0;
  static const artistsColumnWidth = 240.0;
  static const navButtonWidth = 168.0;
  static const navButtonHeight = 44.0;
  static const navButtonSpacing = 8.0;
  static const navButtonRadius = 8.0;
  static const headerHeight = 44.0;
  static const straplineHeight = 14.0;
  static const shelfBottomPadding = 12.0;
  static const topResultArtSize = 84.0;

  /// [width] fits a grid cell.
  static Size cardArtSize(YoutubeFeed item, {required double? width}) {
    if (item is StreamInfoItem && item.hasWideThumbnails) {
      final artWidth = width ?? videoCardHeight * 16 / 9;
      return Size(artWidth, artWidth * 9 / 16);
    }
    final side = width ?? cardSize;
    return Size(side, side);
  }
}
