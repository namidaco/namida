import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/settings/filter_sort_menu.dart';
import 'package:namida/ui/widgets/settings/reverse_order_container.dart';
import 'package:namida/ui/widgets/settings/sort_by_button.dart';

class ExpandableBoxForTracks extends StatefulWidget {
  ExpandableBoxForTracks({super.key});

  @override
  State<ExpandableBoxForTracks> createState() => _ExpandableBoxForTracksState();
}

class _ExpandableBoxForTracksState extends State<ExpandableBoxForTracks> {
  bool showSearchBox = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 24.0, right: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                Indexer.inst.trackSearchList.toList().displayTrackKeyword,
                style: Get.textTheme.displayMedium,
              ),
              const Spacer(),
              SortByMenuTracks(),
              IconButton(
                onPressed: () {
                  setState(() {
                    if (Indexer.inst.tracksSearchController.value.text == '') {
                      showSearchBox = !showSearchBox;
                    } else {
                      showSearchBox = true;
                    }
                  });
                },
                icon: const Icon(Broken.filter),
              ),
            ],
          ),
          AnimatedOpacity(
            opacity: showSearchBox ? 1 : 0,
            duration: Duration(milliseconds: 400),
            child: AnimatedSize(
              duration: Duration(milliseconds: 400),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 400),
                height: showSearchBox ? 58.0 : 0,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: Indexer.inst.tracksSearchController.value,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                          // constraints: const BoxConstraints(maxHeight: 46.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.0.multipliedRadius),
                          ),
                          hintText: Language.inst.FILTER_TRACKS,
                        ),
                        onChanged: (value) {
                          Indexer.inst.searchTracks(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    IconButton(
                      onPressed: () {
                        Indexer.inst.tracksSearchController.value.clear();
                        Indexer.inst.searchTracks('');
                        setState(() {
                          showSearchBox = false;
                        });
                      },
                      icon: const Icon(Broken.close_circle),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showSearchBox) const SizedBox(height: 8.0)
        ],
      ),
    );
  }
}

// class ExpandableBoxForAlbums extends StatefulWidget {
//   final String title;
//   final LibraryTab? tab;

//   const ExpandableBoxForAlbums({super.key, required this.title, this.tab});

//   @override
//   State<ExpandableBoxForAlbums> createState() => _ExpandableBoxForAlbumsState();
// }

// class _ExpandableBoxForAlbumsState extends State<ExpandableBoxForAlbums> {
//   bool showSearchBox = false;
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0.0),
//       child: Column(
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.start,
//             mainAxisSize: MainAxisSize.max,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               Text(
//                 widget.title,
//                 style: Get.textTheme.displayMedium,
//               ),
//               const Spacer(),
//               SortByMenuAlbums(),
//               IconButton(
//                 onPressed: () {
//                   setState(() {
//                     if (Indexer.inst.tracksSearchController.value.text == '') {
//                       showSearchBox = !showSearchBox;
//                     } else {
//                       showSearchBox = true;
//                     }
//                   });
//                 },
//                 icon: const Icon(Broken.filter),
//               ),
//             ],
//           ),
//           if (showSearchBox)
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: Indexer.inst.tracksSearchController.value,
//                     decoration: InputDecoration(
//                       contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
//                       // constraints: const BoxConstraints(maxHeight: 46.0),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(14.0.multipliedRadius),
//                       ),
//                       hintText: Language.inst.FILTER_TRACKS,
//                     ),
//                     onChanged: (value) {
//                       Indexer.inst.searchTracks(value);
//                     },
//                   ),
//                 ),
//                 const SizedBox(width: 12.0),
//                 IconButton(
//                   onPressed: () {
//                     Indexer.inst.tracksSearchController.value.clear();
//                     Indexer.inst.searchTracks('');
//                     setState(() {
//                       showSearchBox = false;
//                     });
//                   },
//                   icon: const Icon(Broken.close_circle),
//                 ),
//               ],
//             ),
//           if (showSearchBox) const SizedBox(height: 8.0)
//         ],
//       ),
//     );
//   }
// }
