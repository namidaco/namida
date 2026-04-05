// ignore_for_file: public_member_api_docs, sort_constructors_first
part of 'track.dart';

class AlbumIdentifierWrapper {
  String get displayAlbumName => album.isEmpty ? UnknownTags.ALBUM : album;

  final String album, albumArtist, year;

  const AlbumIdentifierWrapper({
    required this.album,
    required this.albumArtist,
    required this.year,
  });

  static String _normalize(String text) => DownloadTaskFilename.cleanupFilename(text);

  static List<AlbumIdentifierWrapper> fromAlbums({
    required List<String> albums,
    required String albumArtist,
    required String year,
  }) {
    return albums
        .map(
          (a) => AlbumIdentifierWrapper.normalize(
            album: a,
            albumArtist: albumArtist,
            year: year,
          ),
        )
        .toList();
  }

  factory AlbumIdentifierWrapper.normalize({
    required String album,
    required String albumArtist,
    required String year,
  }) {
    return AlbumIdentifierWrapper(
      album: _normalize(album),
      albumArtist: _normalize(albumArtist),
      year: _normalize(year),
    );
  }

  String resolved() => resolve(settings.albumIdentifiers.value);
  String resolve(List<AlbumIdentifier> identifiers) {
    final modified = modify(identifiers);
    return "${modified.album}${modified.albumArtist}${modified.year}";
  }

  AlbumIdentifierWrapper modified() => modify(settings.albumIdentifiers.value);
  AlbumIdentifierWrapper modify(List<AlbumIdentifier> identifiers) {
    final idWrapper = this;
    final n = identifiers.contains(AlbumIdentifier.albumName) ? idWrapper.album : '';
    final aa = identifiers.contains(AlbumIdentifier.albumArtist) ? idWrapper.albumArtist : '';
    final y = identifiers.contains(AlbumIdentifier.year) ? idWrapper.year : '';
    return AlbumIdentifierWrapper(
      album: n,
      albumArtist: aa,
      year: y,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'album': album,
      'albumArtist': albumArtist,
      'year': year,
    };
  }

  factory AlbumIdentifierWrapper.fromMap(Map<String, dynamic> map) {
    return AlbumIdentifierWrapper(
      album: map['album'] as String,
      albumArtist: map['albumArtist'] as String,
      year: map['year'] as String,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AlbumIdentifierWrapper) return false;

    return other.album == album && other.albumArtist == albumArtist && other.year == year;
  }

  @override
  int get hashCode => album.hashCode ^ albumArtist.hashCode ^ year.hashCode;

  @override
  String toString() => 'AlbumIdentifierWrapper(album: $album, albumArtist:$albumArtist, year: $year)';
}
