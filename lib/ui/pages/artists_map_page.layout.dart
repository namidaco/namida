// thank you claude.. ts so complicated
part of 'artists_map_page.dart';

const _kMaxTracksPerArtist = 80;
const _kSliceBudgetMs = 6;

const _kFeatureScore = 4.0;
const _kAlbumScore = 3.0;
const _kGenreScore = 1.5;
const _kMaxAlbumLinkBucket = 12;
const _kMaxGenreLinkBucket = 24;
const _kGenericGenreRatio = 0.4;
const _kMaxLinksPerNode = 4;
const _kMinLinkWeight = 0.15;

const _kLocalSearchRadius = 2;
const _kRefinePasses = 8;
const _kLabelPasses = 8;
const _kMinClusterSize = 3;
const _kMaxCapitals = 24;
const _kPaletteSize = 16;
const _kEdgeBuckets = 4;
const _kWorldPaddingCells = 1;

const _kGraphClassRadii = [16.0, 21.0, 27.0, 34.0, 42.0];
const _kGraphInitialSpacing = 135.0;
const _kGraphLinkLength = 120.0;
const _kGraphLinkStrength = 8.0;
const _kGraphRepulsionReach = 2.0;
const _kGraphClearance = 26.0;
const _kGraphCollisionStrength = 2.0;
const _kGraphGravity = 0.03;
const _kGraphIterations = 80;
const _kGraphSettlePasses = 20;
const _kGraphFinalTemperature = 1.0;
const _kGraphBucketExtent = 160.0;
const _kGraphPadding = 80.0;

class _ArtistsMapInput {
  final int count;
  final Int32List trackCounts;
  final Int32List primaryGenres;
  final Int32List albumOffsets;
  final Int32List albumIds;
  final int albumsCount;
  final Int32List genreOffsets;
  final Int32List genreIds;
  final int genresCount;
  final Int32List featurePairs;

  const _ArtistsMapInput({
    required this.count,
    required this.trackCounts,
    required this.primaryGenres,
    required this.albumOffsets,
    required this.albumIds,
    required this.albumsCount,
    required this.genreOffsets,
    required this.genreIds,
    required this.genresCount,
    required this.featurePairs,
  });
}

class _ArtistsMapLayout {
  final double width;
  final double height;

  /// artwork center of each artist.
  final Float32List xs;
  final Float32List ys;

  final Uint8List sizeClasses;
  final Float32List classRadii;
  final double maxDotExtent;
  final _BucketIndex buckets;
  final _Adjacency links;
  final List<Float32List> edgeLines;

  /// artwork centers grouped by `colorSlot * classRadii.length + sizeClass`, the last color slot is for unclustered artists.
  final List<Float32List> dotPoints;

  /// biggest artist of each major cluster, biggest cluster first.
  final Int32List capitals;

  const _ArtistsMapLayout({
    required this.width,
    required this.height,
    required this.xs,
    required this.ys,
    required this.sizeClasses,
    required this.classRadii,
    required this.maxDotExtent,
    required this.buckets,
    required this.links,
    required this.edgeLines,
    required this.dotPoints,
    required this.capitals,
  });

  Offset anchorOf(int node) => Offset(xs[node], ys[node]);

  double ringRadiusOf(int node) => classRadii[sizeClasses[node]] + _kRingWidth;

  Rect tileRectOf(int node) {
    final x = xs[node];
    final y = ys[node];
    final ringRadius = ringRadiusOf(node);
    final halfWidth = math.max(ringRadius, _kTileMinWidth / 2);
    return Rect.fromLTRB(x - halfWidth, y - ringRadius, x + halfWidth, y + ringRadius + _kTileLabelExtent);
  }

  int nodeAt(Offset world) {
    final column = buckets.columnOf(world.dx);
    final row = buckets.rowOf(world.dy);
    int best = -1;
    double bestDistance = double.infinity;
    for (int r = math.max(0, row - 1); r <= math.min(buckets.rows - 1, row + 1); r++) {
      for (int c = math.max(0, column - 1); c <= math.min(buckets.columns - 1, column + 1); c++) {
        final bucket = r * buckets.columns + c;
        for (int k = buckets.offsets[bucket]; k < buckets.offsets[bucket + 1]; k++) {
          final node = buckets.nodes[k];
          if (!tileRectOf(node).contains(world)) continue;
          final distance = (anchorOf(node) - world).distanceSquared;
          if (distance < bestDistance) {
            bestDistance = distance;
            best = node;
          }
        }
      }
    }
    return best;
  }
}

/// row major buckets over the world, so a visible range maps to a few contiguous slices.
class _BucketIndex {
  final double extent;
  final int columns;
  final int rows;

  /// nodes of bucket `b` are `nodes[offsets[b]..offsets[b + 1]]`.
  final Int32List offsets;
  final Int32List nodes;

  const _BucketIndex._(this.extent, this.columns, this.rows, this.offsets, this.nodes);

  factory _BucketIndex.of(Float32List xs, Float32List ys, double width, double height, double extent) {
    final columns = math.max(1, (width / extent).ceil());
    final rows = math.max(1, (height / extent).ceil());
    final index = _BucketIndex._(extent, columns, rows, Int32List(columns * rows + 1), Int32List(xs.length));
    final bucketOf = Int32List(xs.length);
    final offsets = index.offsets;
    for (int node = 0; node < xs.length; node++) {
      final bucket = index.rowOf(ys[node]) * columns + index.columnOf(xs[node]);
      bucketOf[node] = bucket;
      offsets[bucket + 1]++;
    }
    for (int b = 0; b < columns * rows; b++) {
      offsets[b + 1] += offsets[b];
    }
    final cursor = Int32List.fromList(offsets);
    for (int node = 0; node < xs.length; node++) {
      index.nodes[cursor[bucketOf[node]]++] = node;
    }
    return index;
  }

  int columnOf(double x) => math.min(columns - 1, math.max(0, (x / extent).floor()));
  int rowOf(double y) => math.min(rows - 1, math.max(0, (y / extent).floor()));

  int countIn(int left, int top, int right, int bottom) {
    int count = 0;
    for (int row = top; row <= bottom; row++) {
      count += offsets[row * columns + right + 1] - offsets[row * columns + left];
    }
    return count;
  }
}

class _Adjacency {
  final Int32List offsets;
  final Int32List neighbours;
  final Float64List weights;

  const _Adjacency(this.offsets, this.neighbours, this.weights);

  factory _Adjacency.fromPairs(int count, Int32List a, Int32List b, Float64List w) {
    final offsets = Int32List(count + 1);
    for (int k = 0; k < a.length; k++) {
      offsets[a[k] + 1]++;
      offsets[b[k] + 1]++;
    }
    for (int i = 0; i < count; i++) {
      offsets[i + 1] += offsets[i];
    }
    final cursor = Int32List.fromList(offsets);
    final neighbours = Int32List(offsets[count]);
    final weights = Float64List(offsets[count]);
    for (int k = 0; k < a.length; k++) {
      final first = cursor[a[k]]++;
      neighbours[first] = b[k];
      weights[first] = w[k];
      final second = cursor[b[k]]++;
      neighbours[second] = a[k];
      weights[second] = w[k];
    }
    return _Adjacency(offsets, neighbours, weights);
  }

  int degreeOf(int node) => offsets[node + 1] - offsets[node];

  void sortByWeightDescending() {
    for (int node = 0; node < offsets.length - 1; node++) {
      final start = offsets[node];
      final end = offsets[node + 1];
      for (int i = start + 1; i < end; i++) {
        final neighbour = neighbours[i];
        final weight = weights[i];
        int j = i - 1;
        while (j >= start && weights[j] < weight) {
          neighbours[j + 1] = neighbours[j];
          weights[j + 1] = weights[j];
          j--;
        }
        neighbours[j + 1] = neighbour;
        weights[j + 1] = weight;
      }
    }
  }
}

/// runs on the main isolate since tracks info lives there, yields every few ms so frames keep flowing.
Future<_ArtistsMapInput?> _extractArtistsMapInput({
  required List<String> names,
  required List<List<Track>> tracksPerArtist,
  required bool Function() isCancelled,
}) async {
  final count = names.length;
  final indexByName = HashMap<String, int>();
  for (int i = 0; i < count; i++) {
    indexByName[names[i].toLowerCase()] = i;
  }

  final albumIdOf = HashMap<AlbumIdentifierWrapper, int>();
  final genreIdOf = HashMap<String, int>();
  final albumLastOwner = <int>[];
  final genreLastOwner = <int>[];
  final genreHits = <int>[];

  final trackCounts = Int32List(count);
  final primaryGenres = Int32List(count);
  final albumOffsets = Int32List(count + 1);
  final genreOffsets = Int32List(count + 1);
  final albumIds = <int>[];
  final genreIds = <int>[];
  final featurePairs = <int>[];

  final slice = Stopwatch()..start();
  for (int i = 0; i < count; i++) {
    if (slice.elapsedMilliseconds >= _kSliceBudgetMs) {
      await Future<void>.delayed(Duration.zero);
      if (isCancelled()) return null;
      slice.reset();
    }

    final tracks = tracksPerArtist[i];
    trackCounts[i] = tracks.length;
    albumOffsets[i] = albumIds.length;
    genreOffsets[i] = genreIds.length;

    int primaryGenre = -1;
    int primaryGenreHits = 0;
    final scanCount = math.min(tracks.length, _kMaxTracksPerArtist);
    for (int t = 0; t < scanCount; t++) {
      final track = tracks[t].toTrackExtOrNull();
      if (track == null) continue;

      for (final wrapper in track.albumsIdentifiersWrappers) {
        final album = wrapper.modifiedOnly();
        if (album.album.isEmpty) continue;
        var id = albumIdOf[album];
        if (id == null) {
          id = albumLastOwner.length;
          albumIdOf[album] = id;
          albumLastOwner.add(-1);
        }
        if (albumLastOwner[id] != i) {
          albumLastOwner[id] = i;
          albumIds.add(id);
        }
      }

      for (final genre in track.genresList) {
        if (genre.isEmpty || genre == UnknownTags.GENRE) continue;
        final key = genre.toLowerCase();
        var id = genreIdOf[key];
        if (id == null) {
          id = genreLastOwner.length;
          genreIdOf[key] = id;
          genreLastOwner.add(-1);
          genreHits.add(0);
        }
        if (genreLastOwner[id] != i) {
          genreLastOwner[id] = i;
          genreHits[id] = 0;
          genreIds.add(id);
        }
        final hits = ++genreHits[id];
        if (hits > primaryGenreHits) {
          primaryGenreHits = hits;
          primaryGenre = id;
        }
      }

      for (final artist in track.artistsList) {
        final other = indexByName[artist.toLowerCase()];
        if (other != null && other != i) {
          featurePairs
            ..add(i)
            ..add(other);
        }
      }
    }
    primaryGenres[i] = primaryGenre;
  }
  albumOffsets[count] = albumIds.length;
  genreOffsets[count] = genreIds.length;

  return _ArtistsMapInput(
    count: count,
    trackCounts: trackCounts,
    primaryGenres: primaryGenres,
    albumOffsets: albumOffsets,
    albumIds: Int32List.fromList(albumIds),
    albumsCount: albumLastOwner.length,
    genreOffsets: genreOffsets,
    genreIds: Int32List.fromList(genreIds),
    genresCount: genreLastOwner.length,
    featurePairs: Int32List.fromList(featurePairs),
  );
}

({_ArtistsMapLayout grid, _ArtistsMapLayout graph}) _computeArtistsMapLayouts(_ArtistsMapInput input) {
  final count = input.count;
  final links = _strongestLinks(count, _scoreRelations(input))..sortByWeightDescending();
  final labels = _propagateLabels(count, links);
  final order = _placementOrder(count, links, labels, input);

  final grid = _MapGrid(count);
  _GreedyPlacer(grid, input).placeAll(order.connected, order.isolated, links);
  _refinePlacement(grid, order.connected, links);

  final colors = _clusterColors(grid, labels, input);
  return (
    grid: _gridLayout(grid, links, colors.slots, colors.capitals),
    graph: _graphLayout(grid, links, colors.slots, colors.capitals, input.trackCounts),
  );
}

HashMap<int, double> _scoreRelations(_ArtistsMapInput input) {
  final count = input.count;
  final scores = HashMap<int, double>();

  void add(int a, int b, double amount) {
    if (a == b) return;
    final key = a < b ? a * count + b : b * count + a;
    scores[key] = (scores[key] ?? 0.0) + amount;
  }

  final features = input.featurePairs;
  for (int k = 0; k < features.length; k += 2) {
    add(features[k], features[k + 1], _kFeatureScore);
  }

  void addSharedBuckets(Int32List ownerOffsets, Int32List ids, int bucketsCount, int maxBucket, double Function(int size) scoreOf) {
    final buckets = _invertBuckets(ownerOffsets, ids, bucketsCount);
    final offsets = buckets.offsets;
    final members = buckets.members;
    for (int id = 0; id < bucketsCount; id++) {
      final start = offsets[id];
      final end = offsets[id + 1];
      final size = end - start;
      if (size < 2 || size > maxBucket) continue;
      final amount = scoreOf(size);
      for (int x = start; x < end; x++) {
        for (int y = x + 1; y < end; y++) {
          add(members[x], members[y], amount);
        }
      }
    }
  }

  addSharedBuckets(input.albumOffsets, input.albumIds, input.albumsCount, _kMaxAlbumLinkBucket, (_) => _kAlbumScore);

  // -- a genre most of the library shares says nothing, rarer ones say more.
  final genreBucketCap = math.min(_kMaxGenreLinkBucket, math.max(2, (count * _kGenericGenreRatio).floor()));
  addSharedBuckets(input.genreOffsets, input.genreIds, input.genresCount, genreBucketCap, (size) => _kGenreScore / math.sqrt(size));

  return scores;
}

({Int32List offsets, Int32List members}) _invertBuckets(Int32List ownerOffsets, Int32List ids, int bucketsCount) {
  final offsets = Int32List(bucketsCount + 1);
  for (int k = 0; k < ids.length; k++) {
    offsets[ids[k] + 1]++;
  }
  for (int id = 0; id < bucketsCount; id++) {
    offsets[id + 1] += offsets[id];
  }
  final cursor = Int32List.fromList(offsets);
  final members = Int32List(ids.length);
  for (int owner = 0; owner < ownerOffsets.length - 1; owner++) {
    for (int k = ownerOffsets[owner]; k < ownerOffsets[owner + 1]; k++) {
      members[cursor[ids[k]]++] = owner;
    }
  }
  return (offsets: offsets, members: members);
}

/// keeps each artist's strongest few relations only, otherwise dense libraries turn into a mesh.
_Adjacency _strongestLinks(int count, HashMap<int, double> scores) {
  final pairsA = Int32List(scores.length);
  final pairsB = Int32List(scores.length);
  final pairsW = Float64List(scores.length);
  int k = 0;
  scores.forEach((key, score) {
    pairsA[k] = key ~/ count;
    pairsB[k] = key % count;
    pairsW[k] = score;
    k++;
  });
  final all = _Adjacency.fromPairs(count, pairsA, pairsB, pairsW);

  final kept = HashMap<int, double>();
  final top = Int32List(_kMaxLinksPerNode);
  for (int node = 0; node < count; node++) {
    int taken = 0;
    for (int e = all.offsets[node]; e < all.offsets[node + 1]; e++) {
      final weight = all.weights[e];
      int position = taken;
      while (position > 0 && all.weights[top[position - 1]] < weight) {
        position--;
      }
      if (position >= _kMaxLinksPerNode) continue;
      for (int s = math.min(taken, _kMaxLinksPerNode - 1); s > position; s--) {
        top[s] = top[s - 1];
      }
      top[position] = e;
      if (taken < _kMaxLinksPerNode) taken++;
    }
    for (int s = 0; s < taken; s++) {
      final e = top[s];
      final other = all.neighbours[e];
      kept[node < other ? node * count + other : other * count + node] = all.weights[e];
    }
  }

  double maxScore = 0.0;
  for (final score in kept.values) {
    if (score > maxScore) maxScore = score;
  }

  final keptA = Int32List(kept.length);
  final keptB = Int32List(kept.length);
  final keptW = Float64List(kept.length);
  k = 0;
  kept.forEach((key, score) {
    keptA[k] = key ~/ count;
    keptB[k] = key % count;
    keptW[k] = (score / maxScore).clamp(_kMinLinkWeight, 1.0);
    k++;
  });
  return _Adjacency.fromPairs(count, keptA, keptB, keptW);
}

/// label propagation over the kept links, hubs are damped so one big artist doesn't swallow everything.
Int32List _propagateLabels(int count, _Adjacency links) {
  final labels = Int32List(count);
  final damping = Float64List(count);
  for (int node = 0; node < count; node++) {
    labels[node] = node;
    final degree = links.degreeOf(node);
    if (degree > 0) damping[node] = 1.0 / math.sqrt(degree);
  }

  final votes = HashMap<int, double>();
  for (int pass = 0; pass < _kLabelPasses; pass++) {
    bool changed = false;
    for (int node = 0; node < count; node++) {
      if (links.degreeOf(node) == 0) continue;
      votes.clear();
      for (int e = links.offsets[node]; e < links.offsets[node + 1]; e++) {
        final other = links.neighbours[e];
        final label = labels[other];
        votes[label] = (votes[label] ?? 0.0) + links.weights[e] * damping[other];
      }
      int best = labels[node];
      double bestVote = votes[best] ?? 0.0;
      votes.forEach((label, vote) {
        if (vote > bestVote + 1e-12) {
          bestVote = vote;
          best = label;
        }
      });
      if (best != labels[node]) {
        labels[node] = best;
        changed = true;
      }
    }
    if (!changed) break;
  }
  return labels;
}

/// connected groups biggest first, each walked breadth first while finishing the current cluster before stepping
/// into the next one, so clusters end up as patches instead of interleaving.
({Int32List connected, Int32List isolated}) _placementOrder(int count, _Adjacency links, Int32List labels, _ArtistsMapInput input) {
  final trackCounts = input.trackCounts;
  bool isBetterStart(int a, int b) {
    final degreeA = links.degreeOf(a);
    final degreeB = links.degreeOf(b);
    return degreeA > degreeB || (degreeA == degreeB && trackCounts[a] > trackCounts[b]);
  }

  final componentOf = Int32List(count)..fillRange(0, count, -1);
  final componentSizes = <int>[];
  final componentStarts = <int>[];
  final queue = Int32List(count);
  int connectedCount = 0;
  for (int node = 0; node < count; node++) {
    if (componentOf[node] != -1 || links.degreeOf(node) == 0) continue;
    final component = componentSizes.length;
    int head = 0;
    int tail = 0;
    queue[tail++] = node;
    componentOf[node] = component;
    int start = node;
    while (head < tail) {
      final current = queue[head++];
      if (isBetterStart(current, start)) start = current;
      for (int e = links.offsets[current]; e < links.offsets[current + 1]; e++) {
        final other = links.neighbours[e];
        if (componentOf[other] != -1) continue;
        componentOf[other] = component;
        queue[tail++] = other;
      }
    }
    componentSizes.add(tail);
    componentStarts.add(start);
    connectedCount += tail;
  }

  final components = List<int>.generate(componentSizes.length, (c) => c)..sort((a, b) => componentSizes[b].compareTo(componentSizes[a]));
  final connected = Int32List(connectedCount);
  final ordered = Uint8List(count);
  final queuedInCluster = Uint8List(count);
  final clusterQueue = <int>[];
  final otherClusters = <int>[];
  int length = 0;
  for (final component in components) {
    clusterQueue.clear();
    otherClusters
      ..clear()
      ..add(componentStarts[component]);
    int clusterHead = 0;
    int otherHead = 0;
    while (true) {
      int node = -1;
      if (clusterHead < clusterQueue.length) {
        node = clusterQueue[clusterHead++];
      } else {
        while (otherHead < otherClusters.length) {
          final candidate = otherClusters[otherHead++];
          if (ordered[candidate] == 0) {
            node = candidate;
            break;
          }
        }
        if (node == -1) break;
      }
      if (ordered[node] == 1) continue;
      ordered[node] = 1;
      connected[length++] = node;

      final label = labels[node];
      for (int e = links.offsets[node]; e < links.offsets[node + 1]; e++) {
        final other = links.neighbours[e];
        if (ordered[other] == 1) continue;
        if (labels[other] != label) {
          otherClusters.add(other);
        } else if (queuedInCluster[other] == 0) {
          queuedInCluster[other] = 1;
          clusterQueue.add(other);
        }
      }
    }
  }

  final primaryGenres = input.primaryGenres;
  final isolatedList = <int>[
    for (int node = 0; node < count; node++)
      if (links.degreeOf(node) == 0) node,
  ];
  isolatedList.sort((a, b) {
    final byGenre = primaryGenres[a].compareTo(primaryGenres[b]);
    return byGenre != 0 ? byGenre : trackCounts[b].compareTo(trackCounts[a]);
  });

  return (connected: connected, isolated: Int32List.fromList(isolatedList));
}

class _MapGrid {
  final int half;
  final int side;
  final Int32List cells;
  final Int32List xs;
  final Int32List ys;

  _MapGrid._(this.half, int count) : side = half * 2 + 1, cells = Int32List((half * 2 + 1) * (half * 2 + 1)), xs = Int32List(count), ys = Int32List(count) {
    cells.fillRange(0, cells.length, -1);
  }

  factory _MapGrid(int count) => _MapGrid._((math.sqrt(count) * 1.5).ceil() + 16, count);

  bool contains(int x, int y) => x >= -half && x <= half && y >= -half && y <= half;
  int indexOf(int x, int y) => (y + half) * side + (x + half);
  int nodeAt(int x, int y) => cells[indexOf(x, y)];

  void put(int node, int x, int y) {
    cells[indexOf(x, y)] = node;
    xs[node] = x;
    ys[node] = y;
  }

  void putAtIndex(int node, int index) {
    cells[index] = node;
    xs[node] = index % side - half;
    ys[node] = index ~/ side - half;
  }

  void clear(int x, int y) => cells[indexOf(x, y)] = -1;

  ({int minX, int minY, int maxX, int maxY}) placedBounds() {
    int minX = xs[0], maxX = xs[0], minY = ys[0], maxY = ys[0];
    for (int node = 1; node < xs.length; node++) {
      final x = xs[node];
      final y = ys[node];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }

  /// nearest free cell within [radius] rings of the target, `-1` when that area is packed.
  int nearestFreeAround(double targetX, double targetY, int radius) {
    final cx = targetX.round();
    final cy = targetY.round();
    int best = -1;
    double bestDistance = double.infinity;

    void consider(int x, int y) {
      if (!contains(x, y)) return;
      final index = indexOf(x, y);
      if (cells[index] != -1) return;
      final dx = x - targetX;
      final dy = y - targetY;
      final distance = dx * dx + dy * dy;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = index;
      }
    }

    for (int r = 0; r <= radius; r++) {
      final ringDistance = r - 0.5;
      if (ringDistance > 0 && ringDistance * ringDistance >= bestDistance) break;
      if (r == 0) {
        consider(cx, cy);
        continue;
      }
      for (int x = cx - r; x <= cx + r; x++) {
        consider(x, cy - r);
        consider(x, cy + r);
      }
      for (int y = cy - r + 1; y < cy + r; y++) {
        consider(cx - r, y);
        consider(cx + r, y);
      }
    }
    return best;
  }
}

/// places each artist on the free cell nearest to its already placed relations, or to its genre's area.
class _GreedyPlacer {
  final _MapGrid grid;
  final _ArtistsMapInput input;
  final Uint8List _placed;
  final Float64List _genreSumX;
  final Float64List _genreSumY;
  final Int32List _genreCount;

  /// free cells touching placed ones, the nearest gap is always one of them once a target's surroundings are packed.
  final _frontier = <int>[];
  final Int32List _frontierPosition;

  _GreedyPlacer(this.grid, this.input)
    : _placed = Uint8List(input.count),
      _genreSumX = Float64List(input.genresCount),
      _genreSumY = Float64List(input.genresCount),
      _genreCount = Int32List(input.genresCount),
      _frontierPosition = Int32List(grid.cells.length)..fillRange(0, grid.cells.length, -1);

  void placeAll(Int32List connected, Int32List isolated, _Adjacency links) {
    for (final node in connected) {
      double sumX = 0.0;
      double sumY = 0.0;
      double sumW = 0.0;
      for (int e = links.offsets[node]; e < links.offsets[node + 1]; e++) {
        final other = links.neighbours[e];
        if (_placed[other] == 0) continue;
        final w = links.weights[e];
        sumX += grid.xs[other] * w;
        sumY += grid.ys[other] * w;
        sumW += w;
      }
      if (sumW > 0) {
        _place(node, _nearestFree(sumX / sumW, sumY / sumW), claimsGenreArea: true);
      } else {
        _placeNearGenre(node, claimsGenreArea: true);
      }
    }
    // -- unrelated artists don't move their genre's area, otherwise they'd keep dragging it outwards into a crescent.
    for (final node in isolated) {
      _placeNearGenre(node, claimsGenreArea: false);
    }
  }

  void _placeNearGenre(int node, {required bool claimsGenreArea}) {
    final genre = input.primaryGenres[node];
    final hasGenre = genre >= 0 && _genreCount[genre] > 0;
    final targetX = hasGenre ? _genreSumX[genre] / _genreCount[genre] : 0.0;
    final targetY = hasGenre ? _genreSumY[genre] / _genreCount[genre] : 0.0;
    _place(node, _nearestFree(targetX, targetY), claimsGenreArea: claimsGenreArea);
  }

  void _place(int node, int index, {required bool claimsGenreArea}) {
    grid.putAtIndex(node, index);
    _placed[node] = 1;
    final genre = input.primaryGenres[node];
    if (claimsGenreArea && genre >= 0) {
      _genreSumX[genre] += grid.xs[node];
      _genreSumY[genre] += grid.ys[node];
      _genreCount[genre]++;
    }

    _removeFromFrontier(index);
    final side = grid.side;
    final x = index % side;
    final y = index ~/ side;
    for (int ny = math.max(0, y - 1); ny <= math.min(side - 1, y + 1); ny++) {
      for (int nx = math.max(0, x - 1); nx <= math.min(side - 1, x + 1); nx++) {
        final neighbour = ny * side + nx;
        if (grid.cells[neighbour] != -1 || _frontierPosition[neighbour] != -1) continue;
        _frontierPosition[neighbour] = _frontier.length;
        _frontier.add(neighbour);
      }
    }
  }

  void _removeFromFrontier(int index) {
    final position = _frontierPosition[index];
    if (position == -1) return;
    final last = _frontier.removeLast();
    if (last != index) {
      _frontier[position] = last;
      _frontierPosition[last] = position;
    }
    _frontierPosition[index] = -1;
  }

  int _nearestFree(double targetX, double targetY) {
    final local = grid.nearestFreeAround(targetX, targetY, _kLocalSearchRadius);
    if (local != -1) return local;

    final side = grid.side;
    final half = grid.half;
    int best = -1;
    double bestDistance = double.infinity;
    for (final index in _frontier) {
      final dx = index % side - half - targetX;
      final dy = index ~/ side - half - targetY;
      final distance = dx * dx + dy * dy;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = index;
      }
    }
    if (best == -1) throw StateError('artists map grid is full');
    return best;
  }
}

void _refinePlacement(_MapGrid grid, Int32List connected, _Adjacency links) {
  final xs = grid.xs;
  final ys = grid.ys;

  double costAt(int node, int x, int y, int ignored) {
    double cost = 0.0;
    for (int e = links.offsets[node]; e < links.offsets[node + 1]; e++) {
      final other = links.neighbours[e];
      if (other == ignored) continue;
      final dx = x - xs[other];
      final dy = y - ys[other];
      cost += links.weights[e] * (dx * dx + dy * dy);
    }
    return cost;
  }

  for (int pass = 0; pass < _kRefinePasses; pass++) {
    int moves = 0;
    for (final node in connected) {
      double sumX = 0.0;
      double sumY = 0.0;
      double sumW = 0.0;
      for (int e = links.offsets[node]; e < links.offsets[node + 1]; e++) {
        final other = links.neighbours[e];
        final w = links.weights[e];
        sumX += xs[other] * w;
        sumY += ys[other] * w;
        sumW += w;
      }
      final baseX = (sumX / sumW).round();
      final baseY = (sumY / sumW).round();
      final currentX = xs[node];
      final currentY = ys[node];

      double bestGain = 1e-9;
      int bestX = 0;
      int bestY = 0;
      bool found = false;
      for (int oy = -1; oy <= 1; oy++) {
        for (int ox = -1; ox <= 1; ox++) {
          final x = baseX + ox;
          final y = baseY + oy;
          if ((x == currentX && y == currentY) || !grid.contains(x, y)) continue;
          final occupant = grid.nodeAt(x, y);
          double gain = costAt(node, currentX, currentY, occupant) - costAt(node, x, y, occupant);
          if (occupant != -1) gain += costAt(occupant, x, y, node) - costAt(occupant, currentX, currentY, node);
          if (gain > bestGain) {
            bestGain = gain;
            bestX = x;
            bestY = y;
            found = true;
          }
        }
      }

      if (found) {
        final occupant = grid.nodeAt(bestX, bestY);
        grid.put(node, bestX, bestY);
        if (occupant != -1) {
          grid.put(occupant, currentX, currentY);
        } else {
          grid.clear(currentX, currentY);
        }
        moves++;
      }
    }
    if (moves == 0) break;
  }
}

/// clusters get palette slots greedily so touching clusters don't share a color whenever avoidable.
({Int32List slots, Int32List capitals}) _clusterColors(_MapGrid grid, Int32List labels, _ArtistsMapInput input) {
  final count = input.count;
  final trackCounts = input.trackCounts;

  final sizes = HashMap<int, int>();
  for (int node = 0; node < count; node++) {
    final label = labels[node];
    sizes[label] = (sizes[label] ?? 0) + 1;
  }
  final ranked = [
    for (final e in sizes.entries)
      if (e.value >= _kMinClusterSize) e.key,
  ]..sort((a, b) => sizes[b]!.compareTo(sizes[a]!));
  final rankOfLabel = HashMap<int, int>();
  for (int r = 0; r < ranked.length; r++) {
    rankOfLabel[ranked[r]] = r;
  }
  final rankOf = Int32List(count);
  for (int node = 0; node < count; node++) {
    rankOf[node] = rankOfLabel[labels[node]] ?? -1;
  }

  final touching = List<Set<int>>.generate(ranked.length, (_) => <int>{}, growable: false);
  for (int node = 0; node < count; node++) {
    final rank = rankOf[node];
    if (rank < 0) continue;
    final x = grid.xs[node];
    final y = grid.ys[node];

    void touch(int nx, int ny) {
      if (!grid.contains(nx, ny)) return;
      final other = grid.nodeAt(nx, ny);
      if (other < 0) return;
      final otherRank = rankOf[other];
      if (otherRank < 0 || otherRank == rank) return;
      touching[rank].add(otherRank);
      touching[otherRank].add(rank);
    }

    touch(x + 1, y);
    touch(x, y + 1);
    touch(x + 1, y + 1);
    touch(x + 1, y - 1);
  }

  final slotOfRank = Int32List(ranked.length);
  for (int rank = 0; rank < ranked.length; rank++) {
    int used = 0;
    for (final other in touching[rank]) {
      if (other < rank) used |= 1 << slotOfRank[other];
    }
    int slot = rank % _kPaletteSize;
    for (int k = 0; k < _kPaletteSize; k++) {
      final candidate = (rank + k) % _kPaletteSize;
      if (used & (1 << candidate) == 0) {
        slot = candidate;
        break;
      }
    }
    slotOfRank[rank] = slot;
  }

  final slots = Int32List(count);
  final capitals = Int32List(math.min(ranked.length, _kMaxCapitals))..fillRange(0, math.min(ranked.length, _kMaxCapitals), -1);
  for (int node = 0; node < count; node++) {
    final rank = rankOf[node];
    if (rank < 0) {
      slots[node] = _kPaletteSize;
      continue;
    }
    slots[node] = slotOfRank[rank];
    if (rank < capitals.length) {
      final capital = capitals[rank];
      if (capital == -1 || trackCounts[node] > trackCounts[capital]) capitals[rank] = node;
    }
  }
  return (slots: slots, capitals: capitals);
}

_ArtistsMapLayout _gridLayout(_MapGrid grid, _Adjacency links, Int32List slots, Int32List capitals) {
  final count = grid.xs.length;
  final bounds = grid.placedBounds();
  final columns = bounds.maxX - bounds.minX + 1 + _kWorldPaddingCells * 2;
  final rows = bounds.maxY - bounds.minY + 1 + _kWorldPaddingCells * 2;
  final xs = Float32List(count);
  final ys = Float32List(count);
  for (int node = 0; node < count; node++) {
    xs[node] = (grid.xs[node] - bounds.minX + _kWorldPaddingCells) * _kCellExtent + _kAnchor.dx;
    ys[node] = (grid.ys[node] - bounds.minY + _kWorldPaddingCells) * _kCellExtent + _kAnchor.dy;
  }
  return _finishLayout(
    xs: xs,
    ys: ys,
    width: columns * _kCellExtent,
    height: rows * _kCellExtent,
    sizeClasses: Uint8List(count),
    classRadii: Float32List.fromList(const [_kArtworkExtent / 2]),
    maxDotExtent: _kCellExtent * 0.95,
    bucketExtent: _kCellExtent,
    links: links,
    slots: slots,
    capitals: capitals,
  );
}

/// starts from the grid placement so clusters are already together, then lets it settle as a node graph.
_ArtistsMapLayout _graphLayout(_MapGrid grid, _Adjacency links, Int32List slots, Int32List capitals, Int32List trackCounts) {
  final count = grid.xs.length;
  int maxTracks = 1;
  for (final tracks in trackCounts) {
    if (tracks > maxTracks) maxTracks = tracks;
  }
  final lastClass = _kGraphClassRadii.length - 1;
  final logMaxTracks = math.log(1 + maxTracks);
  final sizeClasses = Uint8List(count);
  final ringRadii = Float64List(count);
  final xs = Float64List(count);
  final ys = Float64List(count);
  for (int node = 0; node < count; node++) {
    final sizeClass = (math.log(1 + trackCounts[node]) / logMaxTracks * lastClass).round();
    sizeClasses[node] = sizeClass;
    ringRadii[node] = _kGraphClassRadii[sizeClass] + _kRingWidth;
    xs[node] = grid.xs[node] * _kGraphInitialSpacing;
    ys[node] = grid.ys[node] * _kGraphInitialSpacing;
  }
  _relaxGraph(xs, ys, ringRadii, links);

  double minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (int node = 0; node < count; node++) {
    final ringRadius = ringRadii[node];
    final halfWidth = math.max(ringRadius, _kTileMinWidth / 2);
    minX = math.min(minX, xs[node] - halfWidth);
    maxX = math.max(maxX, xs[node] + halfWidth);
    minY = math.min(minY, ys[node] - ringRadius);
    maxY = math.max(maxY, ys[node] + ringRadius + _kTileLabelExtent);
  }
  final outX = Float32List(count);
  final outY = Float32List(count);
  for (int node = 0; node < count; node++) {
    outX[node] = xs[node] - minX + _kGraphPadding;
    outY[node] = ys[node] - minY + _kGraphPadding;
  }
  return _finishLayout(
    xs: outX,
    ys: outY,
    width: maxX - minX + _kGraphPadding * 2,
    height: maxY - minY + _kGraphPadding * 2,
    sizeClasses: sizeClasses,
    classRadii: Float32List.fromList(_kGraphClassRadii),
    maxDotExtent: _kGraphLinkLength * 0.9,
    bucketExtent: _kGraphBucketExtent,
    links: links,
    slots: slots,
    capitals: capitals,
  );
}

/// force directed: links pull, anything within reach pushes, then a settle pass so artworks (plus their label room)
/// never overlap. repulsion is local, the grid start already gives the global shape.
void _relaxGraph(Float64List xs, Float64List ys, Float64List ringRadii, _Adjacency links) {
  final count = xs.length;
  if (count < 2) return;
  const linkLength = _kGraphLinkLength;
  const reach = linkLength * _kGraphRepulsionReach;
  final dispX = Float64List(count);
  final dispY = Float64List(count);
  final proximity = _ProximityGrid(count);

  double temperature = linkLength;
  final cooling = math.pow(_kGraphFinalTemperature / linkLength, 1 / _kGraphIterations).toDouble();
  for (int iteration = 0; iteration < _kGraphIterations; iteration++) {
    dispX.fillRange(0, count, 0.0);
    dispY.fillRange(0, count, 0.0);
    proximity.rebuild(xs, ys, reach);
    final head = proximity.head;
    final next = proximity.next;
    final columns = proximity.columns;

    for (int i = 0; i < count; i++) {
      final xi = xs[i];
      final yi = ys[i];
      final radiusI = ringRadii[i];
      final cellX = proximity.cellX[i];
      final cellY = proximity.cellY[i];
      for (int row = math.max(0, cellY - 1); row <= math.min(proximity.rows - 1, cellY + 1); row++) {
        for (int column = math.max(0, cellX - 1); column <= math.min(columns - 1, cellX + 1); column++) {
          for (int j = head[row * columns + column]; j != -1; j = next[j]) {
            if (j <= i) continue;
            double dx = xi - xs[j];
            double dy = yi - ys[j];
            double distanceSq = dx * dx + dy * dy;
            if (distanceSq >= reach * reach) continue;
            if (distanceSq < 1e-6) {
              dx = 0.1;
              dy = 0.0;
              distanceSq = 0.01;
            }
            final distance = math.sqrt(distanceSq);
            double force = linkLength * linkLength / distance * (1.0 - distance / reach);
            final minDistance = radiusI + ringRadii[j] + _kGraphClearance;
            if (distance < minDistance) force += (minDistance - distance) * _kGraphCollisionStrength;
            final fx = dx / distance * force;
            final fy = dy / distance * force;
            dispX[i] += fx;
            dispY[i] += fy;
            dispX[j] -= fx;
            dispY[j] -= fy;
          }
        }
      }
    }

    for (int i = 0; i < count; i++) {
      for (int e = links.offsets[i]; e < links.offsets[i + 1]; e++) {
        final j = links.neighbours[e];
        if (j <= i) continue;
        final dx = xs[j] - xs[i];
        final dy = ys[j] - ys[i];
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance < 1e-3) continue;
        final force = distance * distance / linkLength * links.weights[e] * _kGraphLinkStrength;
        final fx = dx / distance * force;
        final fy = dy / distance * force;
        dispX[i] += fx;
        dispY[i] += fy;
        dispX[j] -= fx;
        dispY[j] -= fy;
      }
    }

    double sumX = 0.0;
    double sumY = 0.0;
    for (int i = 0; i < count; i++) {
      sumX += xs[i];
      sumY += ys[i];
    }
    final centerX = sumX / count;
    final centerY = sumY / count;
    for (int i = 0; i < count; i++) {
      final dx = dispX[i] + (centerX - xs[i]) * _kGraphGravity;
      final dy = dispY[i] + (centerY - ys[i]) * _kGraphGravity;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length < 1e-9) continue;
      final step = math.min(length, temperature);
      xs[i] += dx / length * step;
      ys[i] += dy / length * step;
    }
    temperature *= cooling;
  }

  double maxRingRadius = 0.0;
  for (final radius in ringRadii) {
    if (radius > maxRingRadius) maxRingRadius = radius;
  }
  final settleReach = maxRingRadius * 2 + _kGraphClearance;
  for (int pass = 0; pass < _kGraphSettlePasses; pass++) {
    proximity.rebuild(xs, ys, settleReach);
    final head = proximity.head;
    final next = proximity.next;
    final columns = proximity.columns;
    int overlaps = 0;
    for (int i = 0; i < count; i++) {
      final cellX = proximity.cellX[i];
      final cellY = proximity.cellY[i];
      for (int row = math.max(0, cellY - 1); row <= math.min(proximity.rows - 1, cellY + 1); row++) {
        for (int column = math.max(0, cellX - 1); column <= math.min(columns - 1, cellX + 1); column++) {
          for (int j = head[row * columns + column]; j != -1; j = next[j]) {
            if (j <= i) continue;
            double dx = xs[i] - xs[j];
            double dy = ys[i] - ys[j];
            final minDistance = ringRadii[i] + ringRadii[j] + _kGraphClearance;
            double distanceSq = dx * dx + dy * dy;
            if (distanceSq >= minDistance * minDistance) continue;
            if (distanceSq < 1e-6) {
              dx = 0.1;
              dy = 0.0;
              distanceSq = 0.01;
            }
            overlaps++;
            final distance = math.sqrt(distanceSq);
            final push = (minDistance - distance) / 2 / distance;
            xs[i] += dx * push;
            ys[i] += dy * push;
            xs[j] -= dx * push;
            ys[j] -= dy * push;
          }
        }
      }
    }
    if (overlaps == 0) break;
  }
}

class _ProximityGrid {
  final Int32List next;
  final Int32List cellX;
  final Int32List cellY;
  Int32List head = Int32List(0);
  int columns = 0;
  int rows = 0;

  _ProximityGrid(int count) : next = Int32List(count), cellX = Int32List(count), cellY = Int32List(count);

  void rebuild(Float64List xs, Float64List ys, double cellExtent) {
    double minX = xs[0], minY = ys[0], maxX = xs[0], maxY = ys[0];
    for (int i = 1; i < xs.length; i++) {
      final x = xs[i];
      final y = ys[i];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    columns = ((maxX - minX) / cellExtent).floor() + 1;
    rows = ((maxY - minY) / cellExtent).floor() + 1;
    if (head.length < columns * rows) head = Int32List(columns * rows);
    head.fillRange(0, columns * rows, -1);
    for (int i = 0; i < xs.length; i++) {
      final column = ((xs[i] - minX) / cellExtent).floor();
      final row = ((ys[i] - minY) / cellExtent).floor();
      cellX[i] = column;
      cellY[i] = row;
      final cell = row * columns + column;
      next[i] = head[cell];
      head[cell] = i;
    }
  }
}

_ArtistsMapLayout _finishLayout({
  required Float32List xs,
  required Float32List ys,
  required double width,
  required double height,
  required Uint8List sizeClasses,
  required Float32List classRadii,
  required double maxDotExtent,
  required double bucketExtent,
  required _Adjacency links,
  required Int32List slots,
  required Int32List capitals,
}) {
  final count = xs.length;

  int edgeBucketOf(double weight) => math.min(_kEdgeBuckets - 1, (weight * _kEdgeBuckets).floor());
  final edgeBucketSizes = Int32List(_kEdgeBuckets);
  for (int node = 0; node < count; node++) {
    for (int e = links.offsets[node]; e < links.offsets[node + 1]; e++) {
      if (links.neighbours[e] > node) edgeBucketSizes[edgeBucketOf(links.weights[e])]++;
    }
  }
  final edgeLines = List<Float32List>.generate(_kEdgeBuckets, (b) => Float32List(edgeBucketSizes[b] * 4), growable: false);
  final edgeCursor = Int32List(_kEdgeBuckets);
  for (int node = 0; node < count; node++) {
    for (int e = links.offsets[node]; e < links.offsets[node + 1]; e++) {
      final other = links.neighbours[e];
      if (other <= node) continue;
      final bucket = edgeBucketOf(links.weights[e]);
      final lines = edgeLines[bucket];
      final i = edgeCursor[bucket];
      lines[i] = xs[node];
      lines[i + 1] = ys[node];
      lines[i + 2] = xs[other];
      lines[i + 3] = ys[other];
      edgeCursor[bucket] = i + 4;
    }
  }

  final classCount = classRadii.length;
  final groupsCount = (_kPaletteSize + 1) * classCount;
  final groupSizes = Int32List(groupsCount);
  for (int node = 0; node < count; node++) {
    groupSizes[slots[node] * classCount + sizeClasses[node]]++;
  }
  final dotPoints = List<Float32List>.generate(groupsCount, (g) => Float32List(groupSizes[g] * 2), growable: false);
  final dotCursor = Int32List(groupsCount);
  for (int node = 0; node < count; node++) {
    final group = slots[node] * classCount + sizeClasses[node];
    final i = dotCursor[group];
    dotPoints[group][i] = xs[node];
    dotPoints[group][i + 1] = ys[node];
    dotCursor[group] = i + 2;
  }

  return _ArtistsMapLayout(
    width: width,
    height: height,
    xs: xs,
    ys: ys,
    sizeClasses: sizeClasses,
    classRadii: classRadii,
    maxDotExtent: maxDotExtent,
    buckets: _BucketIndex.of(xs, ys, width, height, bucketExtent),
    links: links,
    edgeLines: edgeLines,
    dotPoints: dotPoints,
    capitals: capitals,
  );
}
