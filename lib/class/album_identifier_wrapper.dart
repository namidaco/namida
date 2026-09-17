part of 'track.dart';

class AlbumIdentifierWrapper {
  String get displayAlbumName => album.isEmpty ? UnknownTags.ALBUM : album;

  final String album, albumArtist, year, mbAlbumId, mbAlbumArtistId;

  int _modifiedStamp = -1;
  AlbumIdentifierWrapper? _modifiedCache;
  int _resolvedStamp = -1;
  String? _resolvedCache;

  AlbumIdentifierWrapper({
    required this.album,
    required this.albumArtist,
    required this.year,
    required this.mbAlbumId,
    required this.mbAlbumArtistId,
  });

  static String _normalize(String text, String parentDirPath) => text.isEmpty ? text : DownloadTaskFilename.cleanupFilename(text, parentDirPath: parentDirPath);

  static int identifiersStamp(List<AlbumIdentifier> identifiers) {
    int stamp = 0;
    for (int i = 0; i < identifiers.length; i++) {
      stamp |= 1 << identifiers[i].index;
    }
    return stamp;
  }

  static List<AlbumIdentifierWrapper> fromAlbums({
    required List<String> albums,
    required String albumArtist,
    required String year,
    required String mbAlbumId,
    required String mbAlbumArtistId,
  }) {
    return albums
        .map(
          (a) => AlbumIdentifierWrapper(
            album: a,
            albumArtist: albumArtist,
            year: year,
            mbAlbumId: mbAlbumId,
            mbAlbumArtistId: mbAlbumArtistId,
          ),
        )
        .toList();
  }

  String resolved() {
    final identifiers = settings.albumIdentifiers.value;
    final stamp = identifiersStamp(identifiers);
    if (stamp == _resolvedStamp) return _resolvedCache!;
    final res = resolve(identifiers, AppDirs.ARTWORKS);
    _resolvedCache = res;
    _resolvedStamp = stamp;
    return res;
  }

  String resolve(List<AlbumIdentifier> identifiers, String parentDirPath) {
    final modified = modifyOnly(identifiers);
    return "${_normalize(modified.album, parentDirPath)}${_normalize(modified.albumArtist, parentDirPath)}${_normalize(modified.year, parentDirPath)}${_normalize(modified.mbAlbumId, parentDirPath)}${_normalize(modified.mbAlbumArtistId, parentDirPath)}";
  }

  AlbumIdentifierWrapper modifiedOnly() {
    final identifiers = settings.albumIdentifiers.value;
    final stamp = identifiersStamp(identifiers);
    if (stamp == _modifiedStamp) return _modifiedCache!;
    final res = modifyOnly(identifiers);
    _modifiedCache = res;
    _modifiedStamp = stamp;
    return res;
  }

  AlbumIdentifierWrapper modifyOnly(List<AlbumIdentifier> identifiers) {
    final idWrapper = this;
    final n = identifiers.contains(AlbumIdentifier.albumName) ? idWrapper.album : '';
    final aa = identifiers.contains(AlbumIdentifier.albumArtist) ? idWrapper.albumArtist : '';
    final y = identifiers.contains(AlbumIdentifier.year) ? idWrapper.year : '';
    final mbaid = identifiers.contains(AlbumIdentifier.mbAlbumId) ? idWrapper.mbAlbumId : '';
    final mbaaid = identifiers.contains(AlbumIdentifier.mbAlbumArtistId) ? idWrapper.mbAlbumArtistId : '';
    if (n.length == album.length && aa.length == albumArtist.length && y.length == year.length && mbaid.length == mbAlbumId.length && mbaaid.length == mbAlbumArtistId.length) {
      return this;
    }
    return AlbumIdentifierWrapper(
      album: n,
      albumArtist: aa,
      year: y,
      mbAlbumId: mbaid,
      mbAlbumArtistId: mbaaid,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'album': album,
      'albumArtist': albumArtist,
      'year': year,
      if (mbAlbumId.isNotEmpty) 'mbAlbumId': mbAlbumId,
      if (mbAlbumArtistId.isNotEmpty) 'mbAlbumArtistId': mbAlbumArtistId,
    };
  }

  factory AlbumIdentifierWrapper.fromMap(Map<String, dynamic> map) {
    return AlbumIdentifierWrapper(
      album: map['album'] as String,
      albumArtist: map['albumArtist'] as String,
      year: map['year'] as String,
      mbAlbumId: map['mbAlbumId'] as String? ?? '',
      mbAlbumArtistId: map['mbAlbumArtistId'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AlbumIdentifierWrapper) return false;

    return other.album == album && other.albumArtist == albumArtist && other.year == year && other.mbAlbumId == mbAlbumId && other.mbAlbumArtistId == mbAlbumArtistId;
  }

  @override
  int get hashCode => Object.hash(album, albumArtist, year, mbAlbumId, mbAlbumArtistId);

  @override
  String toString() => 'AlbumIdentifierWrapper(album: $album, albumArtist:$albumArtist, year: $year, mbAlbumId: $mbAlbumId, mbAlbumArtistId: $mbAlbumArtistId)';
}
