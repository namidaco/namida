import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/playlists_page.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:palette_generator/palette_generator.dart';

showTrackDialog(Track track, [Widget? leading, Playlist? playlist]) async {
  final palette = await PaletteGenerator.fromImageProvider(FileImage(File(track.pathToImageComp)));
  final colorDelightened = getAlbumColorModifiedModern(palette.colors.toList());

  await Get.dialog(
    BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: Color.alphaBlend(colorDelightened.withAlpha(10), Get.theme.backgroundColor),
        child: SingleChildScrollView(
          child: Column(
            children: [
              InkWell(
                highlightColor: const Color.fromARGB(60, 0, 0, 0),
                splashColor: Colors.transparent,
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 16.0),
                      leading ?? ArtworkWidget(track: track, thumnailSize: 60),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.artistsList.take(5).join(', ').overflow,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Get.textTheme.displayLarge?.copyWith(
                                fontSize: 17,
                                color: Color.alphaBlend(colorDelightened.withAlpha(40), Get.textTheme.displayMedium!.color!),
                              ),
                            ),
                            const SizedBox(
                              height: 1.0,
                            ),
                            Text(
                              track.title.overflow,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Get.textTheme.displayMedium?.copyWith(
                                fontSize: 14,
                                color: Color.alphaBlend(colorDelightened.withAlpha(80), Get.textTheme.displayMedium!.color!),
                              ),
                            ),
                            const SizedBox(
                              height: 1.0,
                            ),
                            Text(
                              track.album.overflow,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Get.textTheme.displaySmall?.copyWith(
                                fontSize: 13,
                                color: Color.alphaBlend(colorDelightened.withAlpha(40), Get.textTheme.displayMedium!.color!),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 16.0,
                      ),
                      const Icon(
                        Broken.arrow_right_3,
                      ),
                      const SizedBox(
                        width: 16.0,
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                color: Get.theme.dividerColor.withAlpha(40),
                thickness: 1,
                height: 0,
              ),
              // const SizedBox(height: 4.0),
              Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  title: Text(Language.inst.ADD_TO_PLAYLIST),
                  onTap: () {
                    Get.close(1);
                    showAddToPlaylistDialog(track);
                  },
                  trailing: SizedBox(),
                )
              ]),
              // const SizedBox(height: 4.0),
              Divider(
                color: Get.theme.dividerColor.withAlpha(40),
                thickness: 1,
                height: 0,
              ),
              // Container(
              //   child: IntrinsicHeight(
              //     child: Row(
              //       children: [
              //         Expanded(
              //           child: trackListItems.elementAt(trackListItems.length - 2),
              //         ),
              //         VerticalDivider(
              //           color: Get.theme.dividerColor.withAlpha(40),
              //           thickness: 1,
              //           width: 0,
              //         ),
              //         Expanded(
              //           child: trackListItems.elementAt(trackListItems.length - 1),
              //         ),
              //       ],
              //     ),
              //   ),
              // )
            ],
          ),
        ),
      ),
    ),
  );
}

void showAddToPlaylistDialog(Track track) {
  Get.dialog(
    BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        // backgroundColor: Color.alphaBlend(NowPlayingColorPalette.instance.modernColor.withAlpha(20), Get.theme.brightness == Brightness.light ? Color.fromARGB(255, 234, 234, 234) : Color.fromARGB(255, 24, 24, 24)),
        insetPadding: EdgeInsets.all(30.0),
        // shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20.0.multipliedRadius))),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Broken.music_library_2,
                    size: 20.0,
                  ),
                  SizedBox(
                    width: 12.0,
                  ),
                  Text(
                    "${Language.inst.ADD_TO_PLAYLIST}",
                    style: Get.theme.textTheme.displayMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Expanded(
            //   child: ListView.builder(
            //     physics: BouncingScrollPhysics(),
            //     padding: EdgeInsets.zero,
            //     shrinkWrap: true,
            //     itemCount: PlaylistController.inst.playlistList.length,
            //     itemBuilder: (context, i) {
            //       return PlaylistsPage();
            //     },
            //   ),
            // ),
            Flexible(
              child: PlaylistsPage(
                tracksToAdd: [track],
                countPerRow: 1,
                displayTopRow: false,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 12.0,
                  ),
                  Expanded(
                    child: Text(
                      PlaylistController.inst.playlistList.length.toString(),
                      style: Get.theme.textTheme.displayMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // FittedBox(child: ImportPlaylistButton()),
                  SizedBox(
                    width: 8.0,
                  ),
                  FittedBox(child: CreatePlaylistButton()),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
