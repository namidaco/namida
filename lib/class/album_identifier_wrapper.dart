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

  static String _normalize(String text) => text.isEmpty ? text : DownloadTaskFilename.cleanupFilename(text);

  static List<AlbumIdentifierWrapper> fromAlbums({
    required List<String> albums,
    required String albumArtist,
    required String year,
  }) {
    return albums
        .map(
          (a) => AlbumIdentifierWrapper(
            album: a,
            albumArtist: albumArtist,
            year: year,
          ),
        )
        .toList();
  }

  String resolved() => resolve(settings.albumIdentifiers.value);
  String resolve(List<AlbumIdentifier> identifiers) {
    final modified = modifyOnly(identifiers);
    return "${_normalize(modified.album)}${_normalize(modified.albumArtist)}${_normalize(modified.year)}";
  }

  AlbumIdentifierWrapper modifiedOnly() => modifyOnly(settings.albumIdentifiers.value);
  AlbumIdentifierWrapper modifyOnly(List<AlbumIdentifier> identifiers) {
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
