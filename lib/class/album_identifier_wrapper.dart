part of 'track.dart';

class AlbumIdentifierWrapper {
  final String album, albumArtist, year;

  const AlbumIdentifierWrapper({
    required this.album,
    required this.albumArtist,
    required this.year,
  });

  static String _normalize(String text) {
    return text.replaceAll('/', '_');
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
}
