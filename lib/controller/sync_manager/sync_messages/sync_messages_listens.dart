part of '../sync_manager.dart';

class _SyncTable<T extends Object> {
  final values = <T>[];
  final _indices = <T, int>{};

  /// -1 if null.
  int add(T? value) {
    if (value == null) return -1;
    var index = _indices[value];
    if (index == null) {
      index = values.length;
      _indices[value] = index;
      values.add(value);
    }
    return index;
  }
}

/// columnar form of [TrackWithDate] items.
/// unique tracks & sources are sent once, rows only reference them by index.
class SyncTrackListens {
  final List<Track> _tracks;
  final List<QueueSourceBase?> _queueSources;
  final List<TrackSource?> _sources;

  final List _trackIndices;
  final List _dates;
  final List? _sourceIndices;
  final List? _queueSourceIndices;

  const SyncTrackListens._(
    this._tracks,
    this._queueSources,
    this._sources,
    this._trackIndices,
    this._dates,
    this._sourceIndices,
    this._queueSourceIndices,
  );

  int get length => _dates.length;

  factory SyncTrackListens.fromItems(Iterable<TrackWithDate> items) {
    final tracks = _SyncTable<Track>();
    final queueSources = _SyncTable<QueueSourceBase>();
    final sources = _SyncTable<TrackSource>();
    final trackIndices = <int>[];
    final dates = <int>[];
    final sourceIndices = <int>[];
    final queueSourceIndices = <int>[];
    for (final item in items) {
      trackIndices.add(tracks.add(item.track));
      dates.add(item.dateAdded);
      sourceIndices.add(sources.add(item.sourceNull));
      queueSourceIndices.add(queueSources.add(item.queueSource));
    }
    return SyncTrackListens._(
      tracks.values,
      queueSources.values,
      sources.values,
      trackIndices,
      dates,
      sources.values.isEmpty ? null : sourceIndices,
      queueSources.values.isEmpty ? null : queueSourceIndices,
    );
  }

  factory SyncTrackListens.fromMap(Map<String, dynamic> map) {
    final paths = map['t'] as List;
    final tracks = List<Track>.generate(paths.length, (i) => Track.fromJson(paths[i] as String, isVideo: false), growable: false);
    final videoIndices = map['v'] as List?;
    if (videoIndices != null) {
      for (final i in videoIndices) {
        tracks[i as int] = Track.fromJson(paths[i] as String, isVideo: true);
      }
    }
    return SyncTrackListens._(
      tracks,
      (map['qs'] as List?)?.map(QueueSource.fromJson).toFixedList() ?? const [],
      (map['s'] as List?)?.map((e) => TrackSource.values.getEnum(e as String)).toFixedList() ?? const [],
      map['ti'] as List,
      map['d'] as List,
      map['si'] as List?,
      map['qi'] as List?,
    );
  }

  Map<String, dynamic> toMap() {
    final tracks = _tracks;
    final length = tracks.length;
    final paths = List<String>.filled(length, '', growable: false);
    final videoIndices = <int>[];
    for (int i = 0; i < length; i++) {
      final track = tracks[i];
      paths[i] = track.path;
      if (track is Video) videoIndices.add(i);
    }
    final sourceIndices = _sourceIndices;
    final queueSourceIndices = _queueSourceIndices;
    return {
      't': paths,
      if (videoIndices.isNotEmpty) 'v': videoIndices,
      if (queueSourceIndices != null) 'qs': _queueSources.map((e) => e?.toJson()).toFixedList(),
      if (sourceIndices != null) 's': _sources.map((e) => e?.name).toFixedList(),
      'ti': _trackIndices,
      'd': _dates,
      'si': ?sourceIndices,
      'qi': ?queueSourceIndices,
    };
  }

  List<TrackWithDate> resolveItems(String senderDeviceId) {
    final tracks = _tracks;
    final resolved = List<Track>.generate(tracks.length, (i) => SyncPathResolver.resolveTrack(senderDeviceId, tracks[i]) ?? tracks[i], growable: false);
    final trackIndices = _trackIndices;
    final dates = _dates;
    final sources = _sources;
    final queueSources = _queueSources;
    final sourceIndices = _sourceIndices;
    final queueSourceIndices = _queueSourceIndices;
    return List<TrackWithDate>.generate(
      length,
      (i) {
        final sourceIndex = sourceIndices == null ? -1 : sourceIndices[i] as int;
        final queueSourceIndex = queueSourceIndices == null ? -1 : queueSourceIndices[i] as int;
        return TrackWithDate(
          dateAdded: dates[i] as int,
          track: resolved[trackIndices[i] as int],
          source: sourceIndex < 0 ? null : sources[sourceIndex],
          queueSource: queueSourceIndex < 0 ? null : queueSources[queueSourceIndex],
        );
      },
      growable: false,
    );
  }
}

class SyncYTListens {
  final List _ids;
  final List<QueueSourceBase?> _queueSources;
  final List<TrackSource?> _sources;
  final List<PlaylistID> _playlistIDs;

  final List _idIndices;
  final List _dates;
  final List? _sourceIndices;
  final List? _queueSourceIndices;
  final List? _playlistIDIndices;

  /// 1 if the item was watched on yt music.
  final List? _musicFlags;

  const SyncYTListens._(
    this._ids,
    this._queueSources,
    this._sources,
    this._playlistIDs,
    this._idIndices,
    this._dates,
    this._sourceIndices,
    this._queueSourceIndices,
    this._playlistIDIndices,
    this._musicFlags,
  );

  int get length => _dates.length;

  factory SyncYTListens.fromItems(Iterable<YoutubeID> items) {
    final ids = _SyncTable<String>();
    final queueSources = _SyncTable<QueueSourceBase>();
    final sources = _SyncTable<TrackSource>();
    final playlistIDs = _SyncTable<PlaylistID>();
    final idIndices = <int>[];
    final dates = <int>[];
    final sourceIndices = <int>[];
    final queueSourceIndices = <int>[];
    final playlistIDIndices = <int>[];
    List<int>? musicFlags;
    for (final item in items) {
      final watch = item.watch;
      idIndices.add(ids.add(item.id));
      dates.add(watch.dateMS);
      sourceIndices.add(sources.add(item.sourceNull));
      queueSourceIndices.add(queueSources.add(item.queueSource));
      playlistIDIndices.add(playlistIDs.add(item.playlistID));
      if (watch.isYTMusic) {
        (musicFlags ??= List<int>.filled(dates.length - 1, 0, growable: true)).add(1);
      } else {
        musicFlags?.add(0);
      }
    }
    return SyncYTListens._(
      ids.values,
      queueSources.values,
      sources.values,
      playlistIDs.values,
      idIndices,
      dates,
      sources.values.isEmpty ? null : sourceIndices,
      queueSources.values.isEmpty ? null : queueSourceIndices,
      playlistIDs.values.isEmpty ? null : playlistIDIndices,
      musicFlags,
    );
  }

  factory SyncYTListens.fromMap(Map<String, dynamic> map) {
    return SyncYTListens._(
      map['ids'] as List,
      (map['qs'] as List?)?.map(QueueSourceYoutubeID.fromJson).toFixedList() ?? const [],
      (map['s'] as List?)?.map((e) => TrackSource.values.getEnum(e as String)).toFixedList() ?? const [],
      (map['pl'] as List?)?.map((e) => PlaylistID(id: e as String)).toFixedList() ?? const [],
      map['ii'] as List,
      map['d'] as List,
      map['si'] as List?,
      map['qi'] as List?,
      map['pi'] as List?,
      map['m'] as List?,
    );
  }

  Map<String, dynamic> toMap() {
    final sourceIndices = _sourceIndices;
    final queueSourceIndices = _queueSourceIndices;
    final playlistIDIndices = _playlistIDIndices;
    return {
      'ids': _ids,
      if (queueSourceIndices != null) 'qs': _queueSources.map((e) => e?.toJson()).toFixedList(),
      if (sourceIndices != null) 's': _sources.map((e) => e?.name).toFixedList(),
      if (playlistIDIndices != null) 'pl': _playlistIDs.map((e) => e.id).toFixedList(),
      'ii': _idIndices,
      'd': _dates,
      'si': ?sourceIndices,
      'qi': ?queueSourceIndices,
      'pi': ?playlistIDIndices,
      'm': ?_musicFlags,
    };
  }

  List<YoutubeID> toItems() {
    final ids = _ids;
    final idIndices = _idIndices;
    final dates = _dates;
    final sources = _sources;
    final queueSources = _queueSources;
    final playlistIDs = _playlistIDs;
    final sourceIndices = _sourceIndices;
    final queueSourceIndices = _queueSourceIndices;
    final playlistIDIndices = _playlistIDIndices;
    final musicFlags = _musicFlags;
    return List<YoutubeID>.generate(
      length,
      (i) {
        final sourceIndex = sourceIndices == null ? -1 : sourceIndices[i] as int;
        final queueSourceIndex = queueSourceIndices == null ? -1 : queueSourceIndices[i] as int;
        final playlistIDIndex = playlistIDIndices == null ? -1 : playlistIDIndices[i] as int;
        return YoutubeID(
          id: ids[idIndices[i] as int] as String,
          watchNull: YTWatch(
            dateMSNull: dates[i] as int,
            isYTMusic: musicFlags != null && musicFlags[i] == 1,
          ),
          source: sourceIndex < 0 ? null : sources[sourceIndex],
          queueSource: queueSourceIndex < 0 ? null : queueSources[queueSourceIndex],
          playlistID: playlistIDIndex < 0 ? null : playlistIDs[playlistIDIndex],
        );
      },
      growable: false,
    );
  }
}
