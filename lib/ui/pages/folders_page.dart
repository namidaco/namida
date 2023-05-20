import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/folder_tile.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class FoldersPage extends StatelessWidget {
  FoldersPage({super.key});

  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => WillPopScope(
        onWillPop: () {
          if (!Folders.inst.isHome.value) {
            Folders.inst.stepOut();
            return Future.value(false);
          }
          return Future.value(true);
        },
        child: SettingsController.inst.enableFoldersHierarchy.value

            /// Folders in heirarchy
            ? Column(
                children: [
                  ListTile(
                    leading: const Icon(Broken.folder_2),
                    title: Text(
                      Folders.inst.isHome.value ? Language.inst.HOME : Folders.inst.currentPath.value,
                      style: context.textTheme.displaySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Folders.inst.stepOut(),
                    trailing: Tooltip(
                      message: Language.inst.SET_AS_DEFAULT,
                      child: NamidaIconButton(
                        icon: SettingsController.inst.defaultFolderStartupLocation.value == Folders.inst.currentPath.value ? Broken.archive_tick : Broken.save_2,
                        onPressed: () =>
                            SettingsController.inst.save(defaultFolderStartupLocation: Folders.inst.isHome.value ? kStoragePaths.first : Folders.inst.currentPath.value),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CupertinoScrollbar(
                      controller: _scrollController,
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          if (Folders.inst.isHome.value) ...[
                            ...kStoragePaths
                                .toList()
                                .map(
                                  (e) => SliverToBoxAdapter(
                                    child: FolderTile(
                                      folder: Folder(
                                        e,
                                        Folders.inst.folderslist.where((element) => element.path.startsWith(e)).expand((entry) => entry.tracks).toList(),
                                      ),
                                      isMainStoragePath: true,
                                    ),
                                  ),
                                )
                                .toList()
                          ],
                          if (!Folders.inst.isHome.value) ...[
                            SliverList(
                              delegate: SliverChildListDelegate(
                                Folders.inst.currentfolderslist.map((e) => FolderTile(folder: e)).toList(),
                              ),
                            ),
                            SliverFixedExtentList(
                              itemExtent: trackTileItemExtent,
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  return TrackTile(
                                    index: i,
                                    track: Folders.inst.currentTracks[i],
                                    queueSource: QueueSource.folder,
                                  );
                                },
                                childCount: Folders.inst.currentTracks.length,
                              ),
                            ),
                          ],
                          const SliverPadding(padding: EdgeInsets.only(bottom: kBottomPadding)),
                        ],
                      ),
                    ),
                  ),
                ],
              )

            /// All Folders
            : Column(
                children: [
                  ListTile(
                    leading: const Icon(Broken.folder_2),
                    title: Text(
                      Folders.inst.currentPath.value == '' ? Language.inst.HOME : Folders.inst.currentPath.value,
                      style: context.textTheme.displaySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Folders.inst.stepOut();
                      Folders.inst.currentPath.value = '';
                    },
                  ),
                  Expanded(
                    child: CupertinoScrollbar(
                      controller: _scrollController,
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          if (!Folders.inst.isInside.value)
                            SliverFixedExtentList(
                              itemExtent: trackTileItemExtent,
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final f = Folders.inst.folderslist[i];
                                  return FolderTile(
                                    folder: f,
                                    onTap: () {
                                      Folders.inst.stepIn(f);
                                      Folders.inst.isInside.value = true;
                                      Folders.inst.currentPath.value = f.folderName;
                                    },
                                  );
                                },
                                childCount: Folders.inst.folderslist.length,
                              ),
                            ),
                          SliverFixedExtentList(
                            itemExtent: trackTileItemExtent,
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final tr = Folders.inst.currentTracks[i];
                                return TrackTile(
                                  index: i,
                                  track: tr,
                                  queueSource: QueueSource.folder,
                                );
                              },
                              childCount: Folders.inst.currentTracks.length,
                            ),
                          ),
                          const SliverPadding(padding: EdgeInsets.only(bottom: kBottomPadding)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
