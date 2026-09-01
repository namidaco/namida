import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/creative_animations.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/network_artwork.dart';

/// Artists laid out as a constellation, wired to the ones they actually relate to.
///
/// relations come from shared albums, features on the same track, and shared (non generic) genres.
class DiscoverPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_discover;

  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverNode {
  final String name;
  final List<Track> tracks;

  const _DiscoverNode({required this.name, required this.tracks});
}

class _DiscoverPageState extends State<DiscoverPage> {
  /// how many artists end up on screen at once, enough to feel dense without a thousand nodes.
  static const _nodesCount = 54;

  /// the pool the shuffle picks from, so re-rolling gives something new but still relevant.
  static const _poolCount = 180;

  /// tracks scanned per artist when collecting albums/genres, they saturate way before this.
  static const _maxTracksPerArtist = 80;

  /// a genre shared by more than this fraction of the nodes says nothing, so it's ignored.
  static const _genericGenreRatio = 0.4;

  static const _maxEdgesPerNode = 3;
  static const _tileExtent = 92.0;

  var _nodes = <_DiscoverNode>[];
  var _edges = <CAConstellationEdge>[];
  late MediaType _artistType;
  int _shuffleSeed = 0;

  @override
  void initState() {
    super.initState();
    _artistType = settings.activeArtistType.value;
    _build();
  }

  void _shuffle() {
    setState(() {
      _shuffleSeed++;
      _build();
    });
  }

  void _build() {
    final artistsMap = Indexer.inst.getArtistMapFor(_artistType).value;

    // -- biggest artists first, then a sample out of that pool so shuffling stays interesting.
    final pool = artistsMap.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    if (pool.length > _poolCount) pool.removeRange(_poolCount, pool.length);

    if (_shuffleSeed > 0 && pool.length > _nodesCount) pool.shuffle(math.Random(_shuffleSeed));

    final picked = pool.length > _nodesCount ? pool.sublist(0, _nodesCount) : pool;
    final nodes = picked.map((e) => _DiscoverNode(name: e.key, tracks: e.value)).toList();

    _nodes = nodes;
    _edges = const [];
    if (nodes.length < 2) return;

    final indexByName = <String, int>{};
    for (int i = 0; i < nodes.length; i++) {
      indexByName[nodes[i].name.toLowerCase()] = i;
    }

    final albumBuckets = <AlbumIdentifierWrapper, List<int>>{};
    final genreBuckets = <String, List<int>>{};
    final scores = <int, double>{}; // -- key is `a * nodes.length + b`, with a < b

    void addScore(int a, int b, double amount) {
      if (a == b) return;
      final key = a < b ? a * nodes.length + b : b * nodes.length + a;
      scores[key] = (scores[key] ?? 0) + amount;
    }

    for (int i = 0; i < nodes.length; i++) {
      final tracks = nodes[i].tracks;
      final scanCount = math.min(tracks.length, _maxTracksPerArtist);
      final albums = <AlbumIdentifierWrapper>{};
      final genres = <String>{};

      for (int t = 0; t < scanCount; t++) {
        final track = tracks[t];
        track.albumsIdentifiersModified.forEach(albums.add);
        for (final genre in track.genresList) {
          if (genre.isEmpty || genre == UnknownTags.GENRE) continue;
          genres.add(genre.toLowerCase());
        }
        // -- a feature on the same track is the strongest signal there is.
        for (final other in track.artistsList) {
          final otherIndex = indexByName[other.toLowerCase()];
          if (otherIndex != null) addScore(i, otherIndex, 4.0);
        }
      }

      for (final album in albums) {
        albumBuckets.putIfAbsent(album, () => []).add(i);
      }
      for (final genre in genres) {
        genreBuckets.putIfAbsent(genre, () => []).add(i);
      }
    }

    for (final bucket in albumBuckets.values) {
      if (bucket.length < 2 || bucket.length > 12) continue;
      for (int a = 0; a < bucket.length; a++) {
        for (int b = a + 1; b < bucket.length; b++) {
          addScore(bucket[a], bucket[b], 3.0);
        }
      }
    }

    final genericThreshold = (nodes.length * _genericGenreRatio).ceil();
    for (final bucket in genreBuckets.values) {
      if (bucket.length < 2 || bucket.length > genericThreshold) continue;
      for (int a = 0; a < bucket.length; a++) {
        for (int b = a + 1; b < bucket.length; b++) {
          addScore(bucket[a], bucket[b], 1.0);
        }
      }
    }

    if (scores.isEmpty) return;

    // -- keep only each node's strongest few links, otherwise dense libraries turn into a mesh.
    final perNode = List.generate(nodes.length, (_) => <MapEntry<int, double>>[], growable: false);
    scores.forEach((key, score) {
      final a = key ~/ nodes.length;
      final b = key % nodes.length;
      perNode[a].add(MapEntry(b, score));
      perNode[b].add(MapEntry(a, score));
    });

    double maxScore = 1.0;
    final kept = <int, double>{};
    for (int i = 0; i < nodes.length; i++) {
      final links = perNode[i]..sort((a, b) => b.value.compareTo(a.value));
      final take = math.min(links.length, _maxEdgesPerNode);
      for (int k = 0; k < take; k++) {
        final other = links[k].key;
        final score = links[k].value;
        if (score > maxScore) maxScore = score;
        kept[i < other ? i * nodes.length + other : other * nodes.length + i] = score;
      }
    }

    // -- lay related artists out next to each other, so links stay short & the clusters read.
    final order = _layoutOrder(nodes.length, perNode);
    final positionOf = List.filled(nodes.length, 0);
    for (int i = 0; i < order.length; i++) {
      positionOf[order[i]] = i;
    }

    _nodes = [for (final index in order) nodes[index]];
    _edges = [
      for (final entry in kept.entries)
        CAConstellationEdge(
          positionOf[entry.key ~/ nodes.length],
          positionOf[entry.key % nodes.length],
          weight: (entry.value / maxScore).clamp(0.15, 1.0),
        ),
    ];
  }

  /// breadth first from the most connected node, so neighbours end up adjacent in the grid.
  List<int> _layoutOrder(int count, List<List<MapEntry<int, double>>> links) {
    final visited = List.filled(count, false);
    final order = <int>[];

    final byDegree = List.generate(count, (i) => i, growable: false)..sort((a, b) => links[b].length.compareTo(links[a].length));

    for (final start in byDegree) {
      if (visited[start]) continue;
      final queue = <int>[start];
      visited[start] = true;
      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        order.add(current);
        final neighbours = links[current].toList()..sort((a, b) => b.value.compareTo(a.value));
        for (final n in neighbours) {
          if (visited[n.key]) continue;
          visited[n.key] = true;
          queue.add(n.key);
        }
      }
    }
    return order;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final nodes = _nodes;

    return BackgroundWrapper(
      child: NamidaScrollbarWithController(
        child: (sc) => SmoothCustomScrollView(
          controller: sc,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 14.0, 12.0, 6.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          kEnableFancyAnimations ? CAKineticTypeTextHover(text: lang.discover, style: textTheme.displayLarge) : Text(lang.discover, style: textTheme.displayLarge),
                          Text(
                            lang.countArtists(count: nodes.length),
                            style: textTheme.displaySmall,
                          ),
                        ],
                      ),
                    ),
                    NamidaIconButton(
                      icon: Broken.shuffle,
                      tooltip: () => lang.shuffle,
                      onPressed: _shuffle,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: nodes.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(lang.noTracksFound, style: textTheme.displayMedium),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: CAMagneticConstellationGrid(
                        key: ValueKey('${_artistType}_$_shuffleSeed'),
                        itemCount: nodes.length,
                        edges: _edges,
                        tileExtent: _tileExtent,
                        spacing: 8.0,
                        pullRadius: 100.0,
                        maxPull: 6.0,
                        itemBuilder: (context, index) => _ArtistNode(
                          node: nodes[index],
                          type: _artistType,
                          extent: _tileExtent,
                        ),
                      ),
                    ),
            ),
            kBottomPaddingWidgetSliver,
          ],
        ),
      ),
    );
  }
}

class _ArtistNode extends StatelessWidget {
  final _DiscoverNode node;
  final MediaType type;
  final double extent;

  const _ArtistNode({required this.node, required this.type, required this.extent});

  @override
  Widget build(BuildContext context) {
    final imageSize = extent * 0.7;
    return NamidaInkWell(
      onTap: () => NamidaOnTaps.inst.onArtistTap(node.name, type, node.tracks),
      onLongPress: () => NamidaDialogs.inst.showArtistDialog(node.name, type),
      enableSecondaryTap: true,
      borderRadius: 0.0,
      child: Column(
        children: [
          ContainerWithBorder(
            child: NetworkArtwork.orLocal(
              key: Key(node.tracks.pathToImage),
              info: NetworkArtworkInfo.artist(node.name),
              path: node.tracks.pathToImage,
              track: node.tracks.trackOfImage,
              thumbnailSize: imageSize,
              borderRadius: 0.0,
              forceSquared: true,
              blur: 6.0,
              disableBlurBgSizeShrink: true,
              isCircle: true,
              iconSize: 24.0,
            ),
          ),
          const SizedBox(height: 3.0),
          Expanded(
            child: Text(
              node.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: context.textTheme.displaySmall?.copyWith(fontSize: 10.0),
            ),
          ),
        ],
      ),
    );
  }
}
