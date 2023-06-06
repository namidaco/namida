// import 'dart:io';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:searchbar_animation/searchbar_animation.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/main_page.dart';
import 'package:namida/ui/pages/search_page.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/stats.dart';

class HomePage extends StatelessWidget {
  final Widget? child;
  final Widget? title;
  final List<Widget>? actions;
  final List<Widget>? actionsToAdd;
  final void Function() onDrawerIconPressed;
  final bool isFromDrawer;
  final bool getOffAll;
  const HomePage({super.key, this.child, this.title, this.actions, this.actionsToAdd, required this.onDrawerIconPressed, this.isFromDrawer = false, this.getOffAll = false});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: PreferredSize(
            preferredSize: Size(0, 56.0 * (1 - ScrollSearchController.inst.miniplayerHeightPercentage.value * 0.3)),
            child: AppBar(
              leading: Hero(
                tag: 'BACKICON',
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: child != null
                      ? NamidaIconButton(
                          key: const ValueKey('arrowleft'),
                          icon: Broken.arrow_left_2,
                          onPressed: () {
                            if (getOffAll) {
                              Get.offAll(MainPageWrapper());
                            } else {
                              Get.back();
                            }
                            Get.focusScope?.unfocus();
                            ScrollSearchController.inst.clearGlobalSearchAndCloseThingys();
                          },
                        )
                      : NamidaIconButton(
                          key: const ValueKey('drawericon'),
                          icon: Broken.menu_1,
                          onPressed: onDrawerIconPressed,
                        ),
                ),
              ),
              titleSpacing: 0,
              automaticallyImplyLeading: false,
              title: title ??
                  SearchBarAnimation(
                    isSearchBoxOnRightSide: true,
                    textAlignToRight: false,
                    textEditingController: ScrollSearchController.inst.searchTextEditingController,
                    durationInMilliSeconds: 300,
                    enableKeyboardFocus: true,
                    isOriginalAnimation: false,
                    onPressButton: (isOpen) {
                      ScrollSearchController.inst.searchTextEditingController.clear();

                      ScrollSearchController.inst.isGlobalSearchMenuShown.value = isOpen;
                      Indexer.inst.searchAll('');
                    },
                    onChanged: (value) {
                      Indexer.inst.searchAll(value);
                      if (value != '') {
                        ScrollSearchController.inst.isGlobalSearchMenuShown.value = true;
                      }
                    },
                    hintText: Language.inst.SEARCH,
                    searchBoxWidth: context.width / 1.2,
                    buttonColour: Colors.transparent,
                    enableBoxShadow: false,
                    buttonShadowColour: Colors.transparent,
                    hintTextColour: context.theme.colorScheme.onSurface,
                    searchBoxColour: context.theme.cardColor.withAlpha(200),
                    enteredTextStyle: context.theme.textTheme.displayMedium,
                    cursorColour: context.theme.colorScheme.onBackground,
                    buttonBorderColour: Colors.black45,
                    buttonWidget: Hero(
                      tag: 'SEARCHOPEN',
                      child: IgnorePointer(
                        child: NamidaIconButton(
                          icon: Broken.search_normal,
                          onPressed: () {},
                        ),
                      ),
                    ),
                    secondaryButtonWidget: Hero(
                      tag: 'SEARCHCLOSE',
                      child: IgnorePointer(
                        child: NamidaIconButton(
                          icon: Broken.search_status_1,
                          onPressed: () {},
                        ),
                      ),
                    ),
                    trailingWidget: NamidaIconButton(
                      icon: Broken.close_circle,
                      padding: EdgeInsets.zero,
                      iconSize: 22,
                      onPressed: () {
                        ScrollSearchController.inst.searchTextEditingController.clear();
                        Indexer.inst.searchAll('');
                      },
                    ),
                  ),
              actions: actions ??
                  [
                    // Hero(
                    //   tag: 'dsfdfds',
                    //   child: NamidaIconButton(
                    //     padding: const EdgeInsets.only(right: 12.0, left: 10.0),
                    //     icon: Broken.ghost,
                    //     onPressed: () async {
                    //       GoogleSignIn googleSignIn = GoogleSignIn(
                    //         scopes: [
                    //           'email',
                    //           'https://www.googleapis.com/auth/youtube',
                    //           'https://www.googleapis.com/auth/youtube.readonly',
                    //           'https://www.googleapis.com/auth/youtube.force-ssl',
                    //         ],
                    //       );
                    //       await googleSignIn.signOut();
                    //       final acc = await googleSignIn.signIn();
                    //       final accessToken = await acc?.authentication.then((value) => value.accessToken);
                    //       final accHeaders = await acc?.authHeaders;
                    //       print('ACCCCCCCCCC ${acc?.displayName ?? 'NULLLLLLL'}');
                    //       print('ACCCCCCCCCC ${accessToken ?? 'NULLLLLLL'}');
                    //       YoutubeController.inst.sussyBaka = accessToken ?? '';
                    //       // final String url = 'https://www.googleapis.com/youtube/v3/channels?access_token=$accessToken&part=snippet&mine=true';
                    //       final String url = 'https://youtube.com/watch?v=o3DHvFyPYRE&bpctr=9999999999&hl=en&access_token=$accessToken';
                    //       http.Response response = await http.get(Uri.parse(url), headers: accHeaders);
                    //       // print('ACCCCCCCCCC ${response.body.replaceAll('\n', ' ')}');
                    //       print('ACCCCCCCCCC ${response.headers.toString()}');
                    //       final cookie = Cookie.fromSetCookieValue(response.headers['set-cookie'].toString());
                    //       print('ACCCCCCCCCC cookie: ${cookie.name}');
                    //       print('ACCCCCCCCCC cookie: ${cookie.value}');
                    //       print('ACCCCCCCCCC cookie: ${cookie.path}');
                    //       YoutubeController.inst.sussyBakaHeader = response.headers;
                    //     },
                    //   ),
                    // ),
                    Hero(
                      tag: 'STATICON',
                      child: NamidaIconButton(
                        padding: const EdgeInsets.only(right: 12.0, left: 10.0),
                        icon: Broken.chart_21,
                        onPressed: () {
                          ScrollSearchController.inst.clearGlobalSearchAndCloseThingys();
                          Get.to(() => SettingsSubPage(
                                title: Language.inst.STATS,
                                child: const StatsSection(),
                              ));
                        },
                      ),
                    ),
                    const ParsingJsonPercentage(size: 30.0),
                    Hero(
                      tag: 'SETTINGICON',
                      child: NamidaIconButton(
                        padding: const EdgeInsets.only(right: 12.0, left: 6.0),
                        icon: Broken.setting_2,
                        onPressed: () {
                          ScrollSearchController.inst.clearGlobalSearchAndCloseThingys();
                          Get.to(() => const SettingsPage());
                        },
                      ),
                    ),
                    if (actionsToAdd != null) ...actionsToAdd!,
                  ],
            ),
          ),
          body: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Transform.scale(
                scale: 1 - (ScrollSearchController.inst.miniplayerHeightPercentage.value * 0.05),
                child: child ?? SettingsController.inst.selectedLibraryTab.value.toWidget(),
              ),

              /// Search Box
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: ScrollSearchController.inst.isGlobalSearchMenuShown.value ? SearchPage() : null,
                ),
              ),

              /// Bottom Glow/Shadow
              Obx(
                () => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Player.inst.nowPlayingTrack.value == kDummyTrack
                      ? const SizedBox(key: Key('emptyglow'))
                      : Container(
                          key: const Key('actualglow'),
                          height: 28.0,
                          transform: Matrix4.translationValues(0, 8.0, 0),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: context.theme.scaffoldBackgroundColor,
                                spreadRadius: 4.0,
                                blurRadius: 8.0,
                              ),
                            ],
                          ),
                        ),
                ),
              )
            ],
          ),
          bottomNavigationBar: !SettingsController.inst.enableBottomNavBar.value
              ? null
              : Transform.translate(
                  offset: Offset(0, 64.0 * ScrollSearchController.inst.miniplayerHeightPercentage.value),
                  child: Hero(
                    tag: "NAVBAR",
                    child: NavigationBar(
                      animationDuration: const Duration(seconds: 1),
                      elevation: 22,
                      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
                      height: 64.0,
                      onDestinationSelected: (value) {
                        ScrollSearchController.inst.animatePageController(value, shouldGoBack: child != null);
                        SelectedTracksController.inst.updatePageTracks(value.toEnum());
                      },
                      selectedIndex: SettingsController.inst.selectedLibraryTab.value.toInt(),
                      destinations: SettingsController.inst.libraryTabs
                          .map(
                            (e) => NavigationDestination(
                              icon: Icon(e.toEnum().toIcon()),
                              label: e.toEnum().toText(),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
