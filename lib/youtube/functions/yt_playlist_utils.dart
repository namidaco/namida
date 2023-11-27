import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';

extension YoutubePlaylistShare on YoutubePlaylist {
  Future<void> shareVideos() async => await tracks.shareVideos();

  void promptDelete({required String name, Color? colorScheme}) {
    NamidaNavigator.inst.navigateDialog(
      colorScheme: colorScheme,
      dialogBuilder: (theme) => CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: "${lang.DELETE}: $name?",
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.DELETE.toUpperCase(),
            onPressed: () {
              NamidaNavigator.inst.closeDialog();
              YoutubePlaylistController.inst.removePlaylist(this);
            },
          ),
        ],
      ),
    );
  }

  Future<String> showRenamePlaylistSheet({
    required BuildContext context,
    required String playlistName,
  }) async {
    final controller = TextEditingController(text: playlistName);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final focusNode = FocusNode();
    focusNode.requestFocus();

    await Future.delayed(Duration.zero); // delay bcz sometimes doesnt show
    // ignore: use_build_context_synchronously
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0).add(EdgeInsets.only(bottom: 18.0 + bottomPadding)),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang.RENAME_PLAYLIST,
                  style: context.textTheme.displayLarge,
                ),
                const SizedBox(height: 18.0),
                CustomTagTextField(
                  focusNode: focusNode,
                  controller: controller,
                  hintText: playlistName,
                  labelText: lang.NAME,
                  validator: (value) => YoutubePlaylistController.inst.validatePlaylistName(value),
                ),
                const SizedBox(height: 18.0),
                Row(
                  children: [
                    SizedBox(width: context.width * 0.1),
                    CancelButton(onPressed: Navigator.of(context).pop),
                    SizedBox(width: context.width * 0.1),
                    Expanded(
                      child: NamidaInkWell(
                        borderRadius: 12.0,
                        padding: const EdgeInsets.all(12.0),
                        height: 48.0,
                        bgColor: CurrentColor.inst.color,
                        decoration: const BoxDecoration(),
                        child: Center(
                          child: Text(
                            lang.SAVE,
                            style: context.textTheme.displayMedium?.copyWith(color: Colors.white.withOpacity(0.9)),
                          ),
                        ),
                        onTap: () async {
                          if (formKey.currentState!.validate()) {
                            final didRename = await YoutubePlaylistController.inst.renamePlaylist(playlistName, controller.text);
                            if (didRename) {
                              Navigator.of(context).maybePop();
                            } else {
                              snackyy(title: lang.ERROR, message: lang.COULDNT_RENAME_PLAYLIST);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return controller.text;
  }
}
