import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/video_controller.dart';
import 'package:namida/ui/widgets/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/edits_tags_dialog.dart';
import 'package:namida/ui/widgets/dialogs/track_clear_dialog.dart';

showTrackDialog(Track track, [Widget? leading, Playlist? playlist]) async {
  final colorDelightened = await generateDelightnedColor(track);

  await Get.dialog(
    BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: Color.alphaBlend(colorDelightened.withAlpha(10), Get.theme.backgroundColor),
        child: SingleChildScrollView(
          child: Column(
            children: [
              /// Top Widget
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
                color: Get.theme.dividerColor,
                thickness: 0.5,
                height: 0,
              ),

              /// List Items
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SmallListTile(
                    compact: false,
                    title: Language.inst.ADD_TO_PLAYLIST,
                    icon: Broken.music_library_2,
                    onTap: () {
                      Get.close(1);
                      showAddToPlaylistDialog([track]);
                    },
                  ),
                  SmallListTile(
                    compact: false,
                    title: Language.inst.EDIT_TAGS,
                    icon: Broken.edit,
                    onTap: () {
                      Get.close(1);
                      showEditTrackTagsDialog(track);
                    },
                  ),
                  SmallListTile(
                    compact: true,
                    title: Language.inst.CLEAR,
                    subtitle: Language.inst.CHOOSE_WHAT_TO_CLEAR,
                    icon: Broken.trash,
                    onTap: () {
                      showTrackClearDialog(track);
                    },
                  ),
                  SmallListTile(
                    compact: false,
                    title: Language.inst.SET_YOUTUBE_LINK,
                    icon: Broken.edit_2,
                    onTap: () async {
                      Get.close(1);

                      TextEditingController controller = TextEditingController();
                      final ytlink = VideoController.inst.extractYTLinkFromTrack(track);
                      controller.text = ytlink;
                      Get.dialog(
                        CustomBlurryDialog(
                          title: Language.inst.SET_YOUTUBE_LINK,
                          actions: [
                            const CancelButton(),
                            ElevatedButton(
                              onPressed: () async {
                                editTrackMetadata(track, insertComment: controller.text);
                                Get.close(1);
                              },
                              child: Text(Language.inst.SAVE),
                            ),
                          ],
                          child: CustomTagTextField(
                            controller: controller,
                            hintText: ytlink.overflow,
                          ),
                        ),
                      );
                    },
                  ),
                  Divider(
                    color: Get.theme.dividerColor,
                    thickness: 0.5,
                    height: 0,
                  ),

                  /// bottom 2 tiles
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: SmallListTile(
                            compact: false,
                            title: Language.inst.PLAY_NEXT,
                            icon: Broken.next,
                            onTap: () {
                              Get.close(1);
                              Player.inst.addToQueue([track], insertNext: true);
                            },
                          ),
                        ),
                        VerticalDivider(
                          color: Get.theme.dividerColor,
                          thickness: 0.5,
                          width: 0,
                        ),
                        Expanded(
                          child: SmallListTile(
                            compact: false,
                            title: Language.inst.PLAY_LAST,
                            icon: Broken.play_cricle,
                            onTap: () {
                              Get.close(1);
                              Player.inst.addToQueue([track]);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(
                color: Get.theme.dividerColor.withAlpha(40),
                thickness: 1,
                height: 0,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
