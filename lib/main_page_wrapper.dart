import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/miniplayer.dart';
import 'package:namida/ui/pages/main_page.dart';
import 'package:namida/ui/pages/onboarding.dart';
import 'package:namida/ui/pages/queues_page.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/selected_tracks_preview.dart';
import 'package:namida/ui/widgets/settings/customization_settings.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';
import 'package:namida/youtube/widgets/inner_drawer.dart';

class MainPageWrapper extends StatefulWidget {
  final bool shouldShowOnBoarding;
  final void Function(BuildContext context) onContextAvailable;

  const MainPageWrapper({super.key, required this.shouldShowOnBoarding, required this.onContextAvailable});

  @override
  State<MainPageWrapper> createState() => _MainPageWrapperState();
}

class _MainPageWrapperState extends State<MainPageWrapper> {
  @override
  void initState() {
    super.initState();
    widget.onContextAvailable(context);
    if (widget.shouldShowOnBoarding) {
      WidgetsBinding.instance.addPostFrameCallback(
        (timeStamp) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) {
            return FirstRunConfigureScreen(
              onContextAvailable: widget.onContextAvailable,
            );
          }));
        },
      );
    }
  }

  @override
  void didChangeDependencies() {
    widget.onContextAvailable(context);
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant MainPageWrapper oldWidget) {
    widget.onContextAvailable(context);
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return NamidaInnerDrawer(
      key: NamidaNavigator.inst.innerDrawerKey,
      borderRadius: 38.0.multipliedRadius,
      drawerChild: const NamidaDrawer(),
      child: const MainScreenStack(),
    );
  }
}

class MainScreenStack extends StatefulWidget {
  const MainScreenStack({super.key});

  @override
  State<MainScreenStack> createState() => _MainScreenStackState();
}

class _MainScreenStackState extends State<MainScreenStack> with SingleTickerProviderStateMixin {
  late AnimationController animation;
  @override
  void initState() {
    super.initState();
    animation = MiniPlayerController.inst.initialize(this);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        MainPage(animation: animation),
        MiniPlayerParent(animation: animation),
        SelectedTracksPreviewContainer(animation: animation),
      ],
    );
  }
}

class NamidaDrawer extends StatelessWidget {
  const NamidaDrawer({super.key});

  void toggleDrawer() => NamidaNavigator.inst.toggleDrawer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Obx(
              () => ListView(
                children: [
                  const NamidaLogoContainer(),
                  const NamidaContainerDivider(width: 42.0, margin: EdgeInsets.all(10.0)),
                  ...LibraryTab.values.map(
                    (e) => NamidaDrawerListTile(
                      enabled: settings.selectedLibraryTab.value == e,
                      title: e.toText(),
                      icon: e.toIcon(),
                      onTap: () async {
                        ScrollSearchController.inst.animatePageController(e);
                        await Future.delayed(const Duration(milliseconds: 100));
                        toggleDrawer();
                      },
                    ),
                  ),
                  NamidaDrawerListTile(
                    enabled: false,
                    title: lang.QUEUES,
                    icon: Broken.driver,
                    onTap: () {
                      NamidaNavigator.inst.navigateTo(const QueuesPage());
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
            title: lang.SLEEP_TIMER,
            icon: Broken.timer_1,
            onTap: () {
              toggleDrawer();
              final minutes = Player.inst.sleepAfterMin.obs;
              final tracks = Player.inst.sleepAfterTracks.obs;
              NamidaNavigator.inst.navigateDialog(
                onDisposing: () {
                  minutes.close();
                  tracks.close();
                },
                dialog: CustomBlurryDialog(
                  title: lang.SLEEP_AFTER,
                  icon: Broken.timer_1,
                  normalTitleStyle: true,
                  actions: [
                    const CancelButton(),
                    Obx(
                      () => Player.inst.enableSleepAfterMins || Player.inst.enableSleepAfterTracks
                          ? NamidaButton(
                              icon: Broken.timer_pause,
                              text: lang.STOP,
                              onPressed: () {
                                Player.inst.resetSleepAfterTimer();
                                NamidaNavigator.inst.closeDialog();
                              },
                            )
                          : NamidaButton(
                              icon: Broken.timer_start,
                              text: lang.START,
                              onPressed: () {
                                if (minutes.value > 0 || tracks.value > 0) {
                                  Player.inst.updateSleepTimerValues(
                                    enableSleepAfterMins: minutes.value > 0,
                                    enableSleepAfterTracks: tracks.value > 0,
                                    sleepAfterMin: minutes.value,
                                    sleepAfterTracks: tracks.value,
                                  );
                                }
                                NamidaNavigator.inst.closeDialog();
                              },
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
                            () => NamidaWheelSlider<int>(
                              totalCount: 180,
                              initValue: minutes.value,
                              itemSize: 6,
                              onValueChanged: (val) => minutes.value = val,
                              text: "${minutes.value}m",
                              topText: lang.MINUTES.capitalizeFirst,
                              textPadding: 8.0,
                            ),
                          ),
                          Text(
                            lang.OR,
                            style: context.textTheme.displayMedium,
                          ),
                          // tracks
                          Obx(
                            () => NamidaWheelSlider<int>(
                              totalCount: kMaximumSleepTimerTracks,
                              initValue: tracks.value,
                              itemSize: 6,
                              onValueChanged: (val) => tracks.value = val,
                              text: "${tracks.value} ${lang.TRACK}",
                              topText: lang.TRACKS,
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
                    NamidaNavigator.inst.navigateTo(
                      SettingsSubPage(
                        title: lang.CUSTOMIZATIONS,
                        child: const CustomizationSettings(),
                      ),
                    );

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
                    NamidaNavigator.inst.navigateTo(const SettingsPage());
                    toggleDrawer();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
        ],
      ),
    );
  }
}
