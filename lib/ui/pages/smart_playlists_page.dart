import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/pages/subpages/smart_playlist_tracks_subpage.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class SmartPlaylistsPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_smartPlaylists;

  const SmartPlaylistsPage({super.key});

  static const _tileItemExtent = 68.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return BackgroundWrapper(
      child: NamidaScrollbarWithController(
        child: (sc) => AnimationLimiter(
          child: SmoothCustomScrollView(
            controller: sc,
            slivers: [
              const SliverPadding(padding: EdgeInsets.only(top: 6.0)),
              ObxO(
                rx: SmartPlaylistsController.inst.smartPlaylistsMap,
                builder: (context, smartPlaylistsMap) {
                  final smartPlaylists = smartPlaylistsMap.values.toFixedList();
                  return SliverFixedExtentList.builder(
                    itemCount: smartPlaylists.length,
                    itemExtent: _tileItemExtent,
                    itemBuilder: (context, i) {
                      final smplWrapper = smartPlaylists[i];
                      final imgFile = SmartPlaylistsController.inst.getArtworkFileForPlaylist(smplWrapper.value);
                      return AnimatingTile(
                        position: i,
                        allowTilting: true,
                        child: NamidaInkWell(
                          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          borderRadius: 12.0,
                          bgColor: context.theme.cardColor.withOpacityExt(0.6),
                          onTap: () {
                            SmartPlaylistTracksPage(
                              smartPlaylistWrapper: smplWrapper,
                            ).navigate();
                          },
                          onLongPress: () => NamidaDialogs.inst.showSmartPlaylistDialog(smplWrapper),
                          child: Row(
                            children: [
                              const SizedBox(width: 4.0),
                              ArtworkWidget(
                                key: ValueKey(imgFile),
                                track: null,
                                thumbnailSize: _tileItemExtent - 14.0,
                                path: imgFile.path,
                                forceSquared: true,
                                icon: Broken.magicpen,
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Text(
                                  smplWrapper.value.name,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.fade,
                                  style: textTheme.displayMedium,
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              MoreIcon(
                                iconSize: 20.0,
                                onPressed: () => NamidaDialogs.inst.showSmartPlaylistDialog(smplWrapper),
                              ),
                              const SizedBox(width: 8.0),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              kBottomPaddingWidgetSliver,
            ],
          ),
        ),
      ),
    );
  }
}
