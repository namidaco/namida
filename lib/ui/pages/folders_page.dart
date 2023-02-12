import 'package:file_manager/file_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/controller/folders_controller.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/pages/homepage.dart';
import 'package:namida/ui/widgets/track_tile.dart';

class FoldersPage extends StatelessWidget {
  final String? title;
  final List<Track>? tracks;
  FoldersPage({super.key, this.title, this.tracks});
  final ScrollController _scrollController = ScrollController();
  final FileManagerController controller = FileManagerController();
  @override
  Widget build(BuildContext context) {
    // context.theme;
    return Obx(
      () {
        print(Indexer.inst.groupedFoldersMap.keys);
        return CupertinoScrollbar(
            controller: _scrollController,
            child:
                // tracks != null
                //     ? ListView(
                //         children: tracks!.asMap().entries.map((e) => )
                //             .map((e) => FoldersTile(
                //                   title: e,
                //                 ))
                //             .toList(),
                //       ):
                ListView(
              children: Indexer.inst.groupedFoldersMap.entries
                  .map((e) => FoldersController.inst.displayTracks.value
                      ? FolderTracksPage(
                          title: e.key.formatPath,
                          tracks: e.value,
                        )
                      : FoldersTile(
                          title: e.key.formatPath,
                          tracks: e.value,
                        ))
                  .toList(),
            ));
      },
    );
  }
}

class FoldersTile extends StatelessWidget {
  final String title;
  final List<Track> tracks;
  const FoldersTile({super.key, required this.title, required this.tracks});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: ListTile(
        title: Text(title),
        onTap: () {
          Get.to(
              () => HomePage(
                    folderChild: FolderTracksPage(
                      title: title,
                      tracks: tracks,
                    ),
                  ),
              duration: Duration.zero,
              transition: Transition.noTransition);
          // FoldersController.inst.displayTracks.value = true;
        },
      ),
    );
  }
}

class FolderTracksPage extends StatelessWidget {
  final String title;
  final List<Track> tracks;
  const FolderTracksPage({super.key, required this.title, required this.tracks});

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: tracks
          .asMap()
          .entries
          .map((e) => TrackTile(
                track: e.value,
              ))
          .toList(),
    );
  }
}
