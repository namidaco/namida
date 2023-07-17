import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/dialogs/track_clear_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void showTrackAdvancedDialog({
  required List<Track> tracksPre,
  List<TrackWithDate> tracksWithDates = const <TrackWithDate>[],
  required Color colorScheme,
}) {
  final isSingle = tracksPre.length == 1;
  final tracks = tracksWithDates.isNotEmpty ? tracksWithDates.toTracks() : tracksPre;
  final canShowClearDialog = tracks.hasAnythingCached;

  final Map<TrackSource, int> sourcesMap = {};
  tracksWithDates.loop((e, index) {
    sourcesMap.update(e.source, (value) => value + 1, ifAbsent: () => 1);
  });

  final RxBool willUpdateArtwork = false.obs;

  NamidaNavigator.inst.navigateDialog(
    colorScheme: colorScheme,
    dialogBuilder: (theme) => CustomBlurryDialog(
      theme: theme,
      normalTitleStyle: true,
      title: Language.inst.ADVANCED,
      child: Column(
        children: [
          Opacity(
            opacity: canShowClearDialog ? 1.0 : 0.6,
            child: IgnorePointer(
              ignoring: !canShowClearDialog,
              child: CustomListTile(
                passedColor: colorScheme,
                title: Language.inst.CLEAR,
                subtitle: Language.inst.CHOOSE_WHAT_TO_CLEAR,
                icon: Broken.trash,
                onTap: () => showTrackClearDialog(tracks, colorScheme),
              ),
            ),
          ),
          if (sourcesMap.isNotEmpty)
            CustomListTile(
              passedColor: colorScheme,
              title: Language.inst.SOURCE,
              subtitle: isSingle ? sourcesMap.keys.first.convertToString : sourcesMap.entries.map((e) => '${e.key.convertToString}: ${e.value.formatDecimal()}').join('\n'),
              icon: Broken.attach_circle,
              onTap: () {},
            ),
          CustomListTile(
            passedColor: colorScheme,
            title: Language.inst.RE_INDEX,
            icon: Broken.direct_inbox,
            trailing: NamidaInkWell(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
              bgColor: theme.cardColor,
              onTap: () => willUpdateArtwork.value = !willUpdateArtwork.value,
              child: Obx(() => Text('${Language.inst.ARTWORK}  ${willUpdateArtwork.value ? '✓' : 'x'}')),
            ),
            onTap: () async {
              await Indexer.inst.updateTracks(
                tracks,
                updateArtwork: willUpdateArtwork.value,
              );
            },
          ),
          // todo: history replace with another track
          // todo: color palette change
        ],
      ),
    ),
  );
}
