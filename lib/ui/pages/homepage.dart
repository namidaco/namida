// ignore_for_file: no_leading_underscores_for_local_identifiers, prefer_const_constructors

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/class/playlist.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/ui/pages/playlists_page.dart';
import 'package:namida/ui/widgets/settings/filter_sort_menu.dart';
import 'package:searchbar_animation/searchbar_animation.dart';

import 'package:namida/main.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/pages/artists_page.dart';
import 'package:namida/ui/pages/folders_page.dart';
import 'package:namida/ui/pages/genres_page.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/pages/tracks_page.dart';
import 'package:namida/ui/widgets/selected_tracks_preview.dart';
import 'package:namida/ui/widgets/waveform.dart';

class HomePage extends StatelessWidget {
  final Widget? folderChild;
  HomePage({super.key, this.folderChild});

  final PageController _pageController = PageController(initialPage: SettingsController.inst.selectedLibraryTab.value.toInt);

  final TextEditingController searchTextEditingController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          titleSpacing: 0,
          automaticallyImplyLeading: false,
          // title: Obx(() => Text("${Indexer.inst.tracksInfoList.length} ${Language.inst.OF} ${Indexer.inst.allTracksPaths}")),
          title: SearchBarAnimation(
            isSearchBoxOnRightSide: true,
            textAlignToRight: false,
            textEditingController: searchTextEditingController,
            durationInMilliSeconds: 300,
            enableKeyboardFocus: true,
            isOriginalAnimation: false,
            onPressButton: (isOpen) {
              ScrollSearchController.inst.isGlobalSearchMenuShown.value = isOpen;
              Indexer.inst.globalSearchController.value.clear();
              Indexer.inst.searchAll('');
            },
            onChanged: (value) {
              Indexer.inst.searchAll(value);
            },
            searchBoxWidth: context.width / 1.2, searchBoxHeight: 180,
            buttonColour: Colors.transparent,
            buttonShadowColour: Colors.transparent,
            hintTextColour: context.theme.colorScheme.onSurface,
            searchBoxColour: context.theme.cardColor,
            enteredTextStyle: context.theme.textTheme.displayMedium,
            cursorColour: context.theme.colorScheme.onBackground,
            buttonBorderColour: Colors.black45,
            // hintText: refresh.isCompleted ? Language.instance.SEARCH_WELCOME : Language.instance.COLLECTION_INDEXING_HINT,
            buttonWidget: Icon(
              Broken.search_normal,
              color: context.theme.appBarTheme.actionsIconTheme?.color,
              size: 22.0,
            ),
            secondaryButtonWidget: Icon(
              Broken.search_status_1,
              color: context.theme.appBarTheme.actionsIconTheme?.color,
              size: 22.0,
            ),
            trailingWidget: GestureDetector(
              onTap: () {
                searchTextEditingController.clear();
                Indexer.inst.searchAll('');
              },
              child: Icon(
                Broken.close_circle,
                color: context.theme.appBarTheme.actionsIconTheme?.color,
                size: 22.0,
              ),
            ),
          ),
          actions: [
            IconButton(
              constraints: BoxConstraints(maxWidth: 60, minWidth: 56.0),
              onPressed: () => PlaylistController.inst.addNewPlaylist(
                'Auto Generated ${PlaylistController.inst.playlistList.length + 1}',
                tracks: [
                  Indexer.inst.tracksInfoList.toList()[Random().nextInt(Indexer.inst.tracksInfoList.length)],
                  Indexer.inst.tracksInfoList.toList()[Random().nextInt(Indexer.inst.tracksInfoList.length)],
                  Indexer.inst.tracksInfoList.toList()[Random().nextInt(Indexer.inst.tracksInfoList.length)],
                  Indexer.inst.tracksInfoList.toList()[Random().nextInt(Indexer.inst.tracksInfoList.length)],
                  Indexer.inst.tracksInfoList.toList()[Random().nextInt(Indexer.inst.tracksInfoList.length)],
                  Indexer.inst.tracksInfoList.toList()[Random().nextInt(Indexer.inst.tracksInfoList.length)],
                  Indexer.inst.tracksInfoList.toList()[Random().nextInt(Indexer.inst.tracksInfoList.length)],
                ],
              ),
              icon: const Icon(Broken.add),
            ),
            FilterSortByMenu(),
            IconButton(
              constraints: BoxConstraints(maxWidth: 60, minWidth: 56.0),
              onPressed: () => Get.to(() => SettingsPage()),
              icon: const Icon(Broken.setting_2),
            ),
          ],
        ),
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (page) {
                SettingsController.inst.save(selectedLibraryTab: page.toEnum);
              },
              children: [
                KeepAliveWrapper(
                  child: AlbumsPage(),
                ),
                KeepAliveWrapper(
                  child: TracksPage(),
                ),
                KeepAliveWrapper(
                  child: ArtistsPage(),
                ),
                KeepAliveWrapper(
                  child: GenresPage(),
                ),
                KeepAliveWrapper(
                  child: PlaylistsPage(),
                ),
                KeepAliveWrapper(
                  child: folderChild ?? FoldersPage(),
                ),
              ],
            ),
            Positioned(
              bottom: 0.0,
              child: SelectedTracksPreviewContainer(),
            ),
            // Positioned.fill(
            //   bottom: 0.0,
            //   child: Align(
            //     alignment: Alignment.bottomCenter,
            //     child: WaveformComponent(
            //       durationInMilliseconds: 2000,
            //       color: context.theme.colorScheme.onBackground.withAlpha(150),
            //       boxMaxWidth: Get.size.width - 66.0,
            //       boxMaxHeight: 65,
            //     ),
            //   ),
            // ),
            Obx(
              () => WaveformComponent(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
                waveDataList: WaveformController.inst.downscaleList(WaveformController.inst.curentWaveform.toList(), Get.width.toInt() ~/ 3.5),
                // durationInMilliseconds: 2000,
                color: context.theme.colorScheme.onBackground.withAlpha(150),
                // boxMaxWidth: Get.size.width - 66.0,
                padding: EdgeInsets.all(14), heightMultiplier: 1.2,
                boxMaxHeight: 65,
              ),
            ),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 400),
                child: ScrollSearchController.inst.isGlobalSearchMenuShown.value
                    ? Container(
                        color: Colors.brown,
                        child: ListView(
                          children: [
                            Text(Indexer.inst.trackSearchList.length.toString()),
                            Text(Indexer.inst.albumSearchList.length.toString()),
                            Text(Indexer.inst.artistSearchList.length.toString()),
                            Text(Indexer.inst.genreSearchList.length.toString()),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
        /*    bottomNavigationBar: AnimatedBottomNavigationBar(
            // backgroundColor: Color.alphaBlend(context.theme.scaffoldBackgroundColor.withAlpha(240), context.theme.colorScheme.onBackground),
            backgroundColor: Colors.transparent,
            icons: [
              Broken.music_dashboard,
              Broken.music_circle,
              Broken.profile_2user,
              Broken.smileys,
            ],
            activeIndex: SettingsController.inst.selectedLibraryTab.value.toInt,
            gapLocation: GapLocation.center,
            notchSmoothness: NotchSmoothness.smoothEdge,
            blurEffect: false,
            leftCornerRadius: 32,
            rightCornerRadius: 32,
            onTap: (value) {
              SettingsController.inst.save(selectedLibraryTab: value.toEnum);
              _pageController.animateToPage(value, duration: Duration(milliseconds: 400), curve: Curves.easeInOutQuart);
            }, //other params
          ),
        ), */

        bottomNavigationBar: NavigationBar(
          animationDuration: Duration(seconds: 1),
          elevation: 22,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          height: 64.0,
          onDestinationSelected: (value) {
            SettingsController.inst.save(selectedLibraryTab: value.toEnum);
            _pageController.animateToPage(value, duration: Duration(milliseconds: 400), curve: Curves.easeInOutQuart);
          },
          selectedIndex: SettingsController.inst.selectedLibraryTab.value.toInt,
          destinations: <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Broken.music_dashboard),
              label: Language.inst.ALBUMS,
            ),
            NavigationDestination(
              icon: Icon(Broken.music_circle),
              label: Language.inst.TRACKS,
            ),
            NavigationDestination(
              icon: Icon(Broken.profile_2user),
              label: Language.inst.ARTISTS,
            ),
            NavigationDestination(
              icon: Icon(Broken.smileys),
              label: Language.inst.GENRES,
            ),
            NavigationDestination(
              icon: Icon(Broken.music_library_2),
              label: Language.inst.GENRES,
            ),
            NavigationDestination(
              icon: Icon(Broken.folder),
              label: Language.inst.GENRES,
            ),
          ],
        ),
      ),
    );
  }
}
