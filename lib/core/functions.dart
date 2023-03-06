import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/pages/subpages/album_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/artist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/genre_tracks_subpage.dart';

class NamidaOnTaps {
  static final NamidaOnTaps inst = NamidaOnTaps();

  Future<void> onArtistTap(String name) async {
    final tracks = Indexer.inst.artistSearchList[name]!.toList();
    final albums = name.artistAlbums;
    final color = await CurrentColor.inst.generateDelightnedColor(tracks[0].pathToImageComp);
    Get.to(
      () => ArtistTracksPage(
        name: name,
        colorScheme: color,
        tracks: tracks,
        albums: albums,
      ),
      preventDuplicates: false,
    );
  }

  Future<void> onAlbumTap(String name) async {
    final tracks = Indexer.inst.albumSearchList[name]!.toList();
    final color = await CurrentColor.inst.generateDelightnedColor(tracks[0].pathToImageComp);

    Get.to(
      () => AlbumTracksPage(
        name: name,
        colorScheme: color,
        tracks: tracks,
      ),
      preventDuplicates: false,
    );
  }

  Future<void> onGenreTap(String name) async {
    final tracks = Indexer.inst.groupedGenresMap[name]!.toList();

    Get.to(
      () => GenreTracksPage(
        name: name,
        tracks: tracks,
      ),
      preventDuplicates: false,
    );
  }
}
