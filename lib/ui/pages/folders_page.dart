import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
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
    // Folders.inst.stepOut();
    // if (SettingsController.inst.defaultFolderStartupLocation.value != kStoragePaths.first) {
    if (SettingsController.inst.enableFoldersHierarchy.value) {
      Folders.inst.stepIn();
    }
    if (!SettingsController.inst.enableFoldersHierarchy.value) {
      Folders.inst.currentTracks.clear();
    }
    // }

    return Obx(
      () => WillPopScope(
        onWillPop: () {
          if (!Folders.inst.isHome.value) {
            Folders.inst.stepOut();
            Folders.inst.isInside.value = false;
            return Future.value(false);
          }
          return Future.value(true);
        },
        child: SettingsController.inst.enableFoldersHierarchy.value
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
                        onPressed: () {
                          if (Folders.inst.isHome.value) {
                            SettingsController.inst.save(defaultFolderStartupLocation: kStoragePaths.first);
                          } else {
                            SettingsController.inst.save(defaultFolderStartupLocation: Folders.inst.currentPath.value);
                          }
                        },
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
                                .asMap()
                                .entries
                                .map(
                                  (e) => SliverToBoxAdapter(
                                    child: FolderTile(
                                      path: e.value,
                                      tracks: Folders.inst.foldersMap.entries.where((element) => element.key.startsWith(e.value)).expand((entry) => entry.value).toList(),
                                    ),
                                  ),
                                )
                                .toList()
                          ],
                          if (!Folders.inst.isHome.value) ...[
                            SliverList(
                              delegate: SliverChildListDelegate(
                                Folders.inst.currentFoldersMap.entries
                                    .map(
                                      (e) => FolderTile(
                                        path: e.key,
                                        tracks: Folders.inst.foldersMap.entries.where((element) => element.key.startsWith(e.key)).expand((entry) => entry.value).toList(),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            SliverAnimatedList(
                              key: UniqueKey(),
                              initialItemCount: Folders.inst.currentTracks.length,
                              itemBuilder: (context, i, animation) => TrackTile(
                                track: Folders.inst.currentTracks.elementAt(i),
                                queue: Folders.inst.currentTracks.toList(),
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
                      // Folders.inst.stepOut();
                      Folders.inst.isInside.value = false;
                      Folders.inst.currentTracks.clear();
                      Folders.inst.currentPath.value = '';
                    },
                  ),
                  Expanded(
                    child: CupertinoScrollbar(
                      controller: _scrollController,
                      child: ListView(
                        controller: _scrollController,
                        children: [
                          if (!Folders.inst.isInside.value)
                            ...Folders.inst.foldersMap.entries
                                .map((e) => FolderTile(
                                      path: e.key,
                                      tracks: Folders.inst.foldersMap.entries.where((element) => element.key.startsWith(e.key)).expand((entry) => entry.value).toList(),
                                      onTap: () {
                                        Folders.inst.currentTracks
                                            .assignAll(Folders.inst.foldersMap.entries.where((element) => element.key.startsWith(e.key)).expand((entry) => entry.value).toList());
                                        Folders.inst.isInside.value = true;
                                        Folders.inst.currentPath.value = e.key;
                                      },
                                    ))
                                .toList(),
                          ...Folders.inst.currentTracks
                              .asMap()
                              .entries
                              .map(
                                (e) => TrackTile(
                                  track: e.value,
                                  queue: Folders.inst.currentTracks.toList(),
                                ),
                              )
                              .toList(),
                          kBottomPaddingWidget,
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
