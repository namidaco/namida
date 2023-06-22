import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/folder_tile.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class FoldersPage extends StatelessWidget {
  FoldersPage({super.key});

  final ScrollController _scrollController = Folders.inst.scrollController;
  Widget get iconWidget => Obx(
        () => SizedBox(
          height: double.infinity,
          child: Icon(
            Folders.inst.isHome.value ? Broken.home_2 : Broken.folder_2,
            size: 22.0,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final highlighedColor = context.theme.colorScheme.onBackground.withAlpha(40);
    return WillPopScope(
      onWillPop: () async {
        if (!Folders.inst.isHome.value) {
          Folders.inst.stepOut();
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          Obx(
            () => SettingsController.inst.enableFoldersHierarchy.value

                /// Folders in heirarchy
                ? Column(
                    children: [
                      ListTile(
                        leading: iconWidget,
                        title: Obx(
                          () => Text(
                            //todo .formatPath()
                            Folders.inst.currentFolder.value?.path ?? Language.inst.HOME,
                            style: context.textTheme.displaySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onTap: () => Folders.inst.stepOut(),
                        trailing: Obx(
                          () {
                            final pathOfDefault = Folders.inst.isHome.value ? '' : Folders.inst.currentFolder.value?.path;
                            return NamidaIconButton(
                              tooltip: Language.inst.SET_AS_DEFAULT,
                              icon: SettingsController.inst.defaultFolderStartupLocation.value == pathOfDefault ? Broken.archive_tick : Broken.save_2,
                              iconSize: 22.0,
                              onPressed: () => SettingsController.inst.save(
                                defaultFolderStartupLocation: Folders.inst.currentFolder.value?.path ?? '',
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: CupertinoScrollbar(
                          controller: _scrollController,
                          child: Obx(
                            () => CustomScrollView(
                              controller: _scrollController,
                              slivers: [
                                if (Folders.inst.isHome.value)
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, i) {
                                        final p = kStoragePaths.elementAt(i);
                                        return FolderTile(
                                          folder: Folder(p),
                                          isMainStoragePath: true,
                                          dummyTracks:
                                              Indexer.inst.mainMapFolders.entries.where((element) => element.key.path.startsWith(p)).expand((element) => element.value).toList(),
                                        );
                                      },
                                      childCount: kStoragePaths.length,
                                    ),
                                  ),
                                if (!Folders.inst.isHome.value) ...[
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, i) => FolderTile(
                                        folder: Folders.inst.currentFolderslist[i],
                                      ),
                                      childCount: Folders.inst.currentFolderslist.length,
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
                                          bgColor: i == Folders.inst.indexToScrollTo.value ? highlighedColor : null,
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
                      ),
                    ],
                  )

                /// All Folders
                : Column(
                    children: [
                      ListTile(
                        leading: iconWidget,
                        title: Obx(
                          () => Text(
                            Folders.inst.currentFolder.value?.path.formatPath() ?? Language.inst.HOME,
                            style: context.textTheme.displaySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onTap: () => Folders.inst.stepOut(),
                      ),
                      Expanded(
                        child: CupertinoScrollbar(
                          controller: _scrollController,
                          child: Obx(
                            () => CustomScrollView(
                              controller: _scrollController,
                              slivers: [
                                if (!Folders.inst.isInside.value)
                                  SliverFixedExtentList(
                                    itemExtent: trackTileItemExtent,
                                    delegate: SliverChildBuilderDelegate(
                                      (context, i) {
                                        final folder = Indexer.inst.mainMapFolders.keys.elementAt(i);
                                        return FolderTile(
                                          folder: folder,
                                          subtitle: folder.hasSimilarFolderNames ? folder.parentPath.formatPath() : null,
                                        );
                                      },
                                      childCount: Indexer.inst.mainMapFolders.length,
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
                                        bgColor: i == Folders.inst.indexToScrollTo.value ? highlighedColor : null,
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
                      ),
                    ],
                  ),
          ),
          Obx(
            () => Folders.inst.indexToScrollTo.value != null
                ? Positioned(
                    bottom: kBottomPadding,
                    right: 12.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.background,
                        shape: BoxShape.circle,
                      ),
                      child: NamidaIconButton(
                        padding: const EdgeInsets.all(7.0),
                        onPressed: () {
                          _scrollController.animateTo(trackTileItemExtent * (Folders.inst.indexToScrollTo.value! + Folders.inst.currentFolderslist.length - 2),
                              duration: const Duration(milliseconds: 400), curve: Curves.bounceInOut);
                        },
                        icon: Broken.arrow_circle_down,
                      ),
                    ),
                  )
                : const SizedBox(),
          )
        ],
      ),
    );
  }
}
