import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide ReorderableDragStartListener;
import 'package:get/get.dart';
import 'package:known_extents_list_view_builder/known_extents_sliver_reorderable_list.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/youtube_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/packages/inner_drawer.dart';
import 'package:namida/packages/miniplayer.dart';
import 'package:namida/ui/pages/homepage.dart';
import 'package:namida/ui/pages/queues_page.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/pages/youtube_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/selected_tracks_preview.dart';
import 'package:namida/ui/widgets/settings/customization_settings.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';

class MainPageWrapper extends StatelessWidget {
  final Widget? child;
  final Widget? title;
  final List<Widget>? actions;
  final List<Widget>? actionsToAdd;
  final Color? colorScheme;
  final bool getOffAll;
  MainPageWrapper({super.key, this.child, this.title, this.actions, this.actionsToAdd, this.colorScheme, this.getOffAll = false});

  final GlobalKey<InnerDrawerState> _innerDrawerKey = GlobalKey<InnerDrawerState>();
  void toggleDrawer() {
    if (child != null) Get.offAll(() => MainPageWrapper());

    ScrollSearchController.inst.isGlobalSearchMenuShown.value = false;
    _innerDrawerKey.currentState?.toggle();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        Get.focusScope?.unfocus();
        if (getOffAll) {
          Get.offAll(MainPageWrapper());
        }
        return Future.value(true);
      },
      child: Obx(
        () => AnimatedTheme(
          duration: const Duration(milliseconds: 500),
          data: AppThemes.inst.getAppTheme(colorScheme ?? CurrentColor.inst.color.value, !Get.isDarkMode),
          child: InnerDrawer(
            key: _innerDrawerKey,
            onTapClose: true,
            colorTransitionChild: Colors.black54,
            colorTransitionScaffold: Colors.black54,
            offset: const IDOffset.only(left: 0.0),
            proportionalChildArea: true,
            borderRadius: 32.0.multipliedRadius,
            leftAnimationType: InnerDrawerAnimation.quadratic,
            rightAnimationType: InnerDrawerAnimation.quadratic,
            backgroundDecoration: BoxDecoration(color: context.theme.scaffoldBackgroundColor),
            duration: const Duration(milliseconds: 400),
            tapScaffoldEnabled: false,
            velocity: 0.01,
            leftChild: Container(
              color: context.theme.scaffoldBackgroundColor,
              child: Column(
                children: [
                  Expanded(
                    child: Obx(
                      () => ListView(
                        children: [
                          const NamidaLogoContainer(),
                          const NamidaContainerDivider(width: 42.0, margin: EdgeInsets.all(10.0)),
                          ...kLibraryTabsStock
                              .asMap()
                              .entries
                              .map(
                                (e) => NamidaDrawerListTile(
                                  enabled: SettingsController.inst.selectedLibraryTab.value == e.value.toEnum,
                                  title: e.value.toEnum.toText,
                                  icon: e.value.toEnum.toIcon,
                                  onTap: () async {
                                    ScrollSearchController.inst.animatePageController(e.value.toEnum.toInt);
                                    await Future.delayed(const Duration(milliseconds: 100));
                                    toggleDrawer();
                                  },
                                ),
                              )
                              .toList(),
                          NamidaDrawerListTile(
                            enabled: false,
                            title: Language.inst.QUEUES,
                            icon: Broken.driver,
                            onTap: () {
                              Get.to(() => const QueuesPage());
                              toggleDrawer();
                            },
                          ),
                          NamidaDrawerListTile(
                            enabled: false,
                            title: Language.inst.YOUTUBE,
                            icon: Broken.video_square,
                            onTap: () {
                              YoutubeController.inst.prepareHomePage();
                              Get.to(() => const YoutubePage());
                              toggleDrawer();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Material(
                    borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                    child: ToggleThemeModeContainer(
                      width: Get.width / 2.3,
                      blurRadius: 3.0,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  NamidaDrawerListTile(
                    margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 12.0),
                    enabled: false,
                    title: Language.inst.SLEEP_TIMER,
                    icon: Broken.timer_1,
                    onTap: () {
                      toggleDrawer();
                      final RxInt minutes = Player.inst.sleepAfterMin.value.obs;
                      final RxInt tracks = Player.inst.sleepAfterTracks.value.obs;
                      Get.dialog(
                        CustomBlurryDialog(
                          title: Language.inst.SLEEP_AFTER,
                          icon: Broken.timer_1,
                          normalTitleStyle: true,
                          actions: [
                            const CancelButton(),
                            Obx(
                              () => Player.inst.enableSleepAfterMins.value || Player.inst.enableSleepAfterTracks.value
                                  ? ElevatedButton.icon(
                                      onPressed: () {
                                        Player.inst.resetSleepAfterTimer();
                                        Get.close(1);
                                      },
                                      icon: const Icon(Broken.timer_pause),
                                      label: Text(Language.inst.STOP),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: () {
                                        if (minutes.value > 0 || tracks.value > 0) {
                                          Player.inst.enableSleepAfterMins.value = minutes.value > 0;
                                          Player.inst.enableSleepAfterTracks.value = tracks.value > 0;
                                          Player.inst.sleepAfterMin.value = minutes.value;
                                          Player.inst.sleepAfterTracks.value = tracks.value;
                                        }
                                        Get.close(1);
                                      },
                                      icon: const Icon(Broken.timer_start),
                                      label: Text(Language.inst.START),
                                    ),
                            ),
                          ],
                          child: Column(
                            children: [
                              const SizedBox(
                                height: 32.0,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  // minutes
                                  Obx(
                                    () => NamidaWheelSlider(
                                      totalCount: 180,
                                      initValue: minutes.value,
                                      itemSize: 6,
                                      onValueChanged: (val) => minutes.value = val,
                                      text: "${minutes.value}m",
                                      topText: Language.inst.MINUTES.capitalizeFirst,
                                      textPadding: 8.0,
                                    ),
                                  ),
                                  Text(
                                    Language.inst.OR,
                                    style: context.textTheme.displayMedium,
                                  ),
                                  // tracks
                                  Obx(
                                    () => NamidaWheelSlider(
                                      totalCount: 40,
                                      initValue: tracks.value,
                                      itemSize: 6,
                                      onValueChanged: (val) => tracks.value = val,
                                      text: "${tracks.value} ${Language.inst.TRACK}",
                                      topText: Language.inst.TRACKS,
                                      textPadding: 8.0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: NamidaDrawerListTile(
                          margin: const EdgeInsets.symmetric(vertical: 5.0).add(const EdgeInsets.only(left: 12.0)),
                          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 6.0),
                          enabled: false,
                          isCentered: true,
                          iconSize: 24.0,
                          title: '',
                          icon: Broken.brush_1,
                          onTap: () {
                            Get.to(() => SettingsSubPage(
                                  title: Language.inst.CUSTOMIZATIONS,
                                  child: CustomizationSettings(),
                                ));
                            toggleDrawer();
                          },
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: NamidaDrawerListTile(
                          margin: const EdgeInsets.symmetric(vertical: 5.0).add(const EdgeInsets.only(right: 12.0)),
                          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 6.0),
                          enabled: false,
                          isCentered: true,
                          iconSize: 24.0,
                          title: '',
                          icon: Broken.setting,
                          onTap: () {
                            Get.to(() => const SettingsPage());
                            toggleDrawer();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                ],
              ),
            ),
            scaffold: Obx(
              () => AnimatedTheme(
                duration: const Duration(milliseconds: 500),
                data: AppThemes.inst.getAppTheme(colorScheme ?? CurrentColor.inst.color.value, !Get.isDarkMode),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    HomePage(
                      title: title,
                      actions: actions,
                      actionsToAdd: actionsToAdd,
                      onDrawerIconPressed: () => toggleDrawer(),
                      getOffAll: getOffAll,
                      child: child,
                    ),
                    const MiniPlayerParent(),
                    if (ScrollSearchController.inst.miniplayerHeightPercentage.value != 1.0)
                      Positioned(
                        bottom: 60 +
                            60.0 * ScrollSearchController.inst.miniplayerHeightPercentage.value +
                            (SettingsController.inst.enableBottomNavBar.value ? 0 : 32.0 * (1 - ScrollSearchController.inst.miniplayerHeightPercentageQueue.value)),
                        child: Opacity(
                          opacity: 1 - ScrollSearchController.inst.miniplayerHeightPercentage.value,
                          child: const SelectedTracksPreviewContainer(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScrollBehaviorModified extends ScrollBehavior {
  const ScrollBehaviorModified();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.android:
        return const BouncingScrollPhysics();
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics();
    }
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({Key? key, required this.child}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _KeepAliveWrapperState createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class CustomReorderableDelayedDragStartListener extends ReorderableDragStartListener {
  final Duration delay;

  const CustomReorderableDelayedDragStartListener({
    this.delay = const Duration(milliseconds: 20),
    Key? key,
    required Widget child,
    required int index,
    bool enabled = true,

    /// {@macro flutter.widgets.reorderable_list.onReorderStart}

    final void Function(PointerDownEvent event)? onDragStart,

    /// {@macro flutter.widgets.reorderable_list.onReorderEnd}
    final void Function(PointerUpEvent event)? onDragEnd,
  }) : super(
          key: key,
          child: child,
          index: index,
          onDragStart: onDragStart,
          onDragEnd: onDragEnd,
        );

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(delay: delay, debugOwner: this);
  }
}
