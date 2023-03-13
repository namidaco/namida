import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/selected_tracks_row.dart';

class SelectedTracksPreviewContainer extends StatelessWidget {
  const SelectedTracksPreviewContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final SelectedTracksController stc = SelectedTracksController.inst;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: stc.selectedTracks.isNotEmpty
              ? Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => stc.isMenuMinimized.value = !stc.isMenuMinimized.value,
                          onTapDown: (value) => stc.isExpanded.value = true,
                          onTapUp: (value) => stc.isExpanded.value = false,
                          onTapCancel: () => stc.isExpanded.value = !stc.isExpanded.value,

                          // dragging upwards or downwards
                          onPanEnd: (details) {
                            if (details.velocity.pixelsPerSecond.dy < 0) {
                              stc.isMenuMinimized.value = false;
                            } else if (details.velocity.pixelsPerSecond.dy > 0) {
                              stc.isMenuMinimized.value = true;
                            }
                          },
                          child: AnimatedContainer(
                            clipBehavior: Clip.antiAlias,
                            duration: const Duration(seconds: 1),
                            curve: Curves.fastLinearToSlowEaseIn,
                            height: stc.isMenuMinimized.value
                                ? stc.isExpanded.value
                                    ? 80
                                    : 85
                                : stc.isExpanded.value
                                    ? 425
                                    : 430,
                            width: stc.isExpanded.value ? 375 : 380,
                            decoration: BoxDecoration(
                              color: context.theme.colorScheme.background,
                              borderRadius: const BorderRadius.all(Radius.circular(20)),
                              boxShadow: [
                                BoxShadow(
                                  color: context.theme.shadowColor,
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(15),
                            child: stc.isMenuMinimized.value
                                ? const FittedBox(child: SelectedTracksRow())
                                : Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      const FittedBox(child: SelectedTracksRow()),
                                      const SizedBox(
                                        height: 20,
                                      ),
                                      Expanded(
                                        child: Container(
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                                          child: ReorderableListView.builder(
                                            onReorder: (oldIndex, newIndex) => stc.reorderTracks(oldIndex, newIndex),
                                            physics: const BouncingScrollPhysics(),
                                            padding: EdgeInsets.zero,
                                            itemCount: stc.selectedTracks.length,
                                            itemBuilder: (context, i) {
                                              return Builder(
                                                key: ValueKey(stc.selectedTracks[i]),
                                                builder: (context) => Dismissible(
                                                  key: ValueKey(stc.selectedTracks[i]),
                                                  onDismissed: (direction) {
                                                    stc.removeTrack(i);
                                                  },
                                                  child: TrackTile(
                                                    index: i,
                                                    track: stc.selectedTracks[i],
                                                    displayRightDragHandler: true,
                                                    isInSelectedTracksPreview: true,
                                                    queue: SelectedTracksController.inst.selectedTracks.toList(),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
