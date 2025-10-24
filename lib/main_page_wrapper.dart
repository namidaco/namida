import 'dart:io';

import 'package:flutter/material.dart';

import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:window_manager/window_manager.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/window_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/miniplayer.dart';
import 'package:namida/ui/pages/about_page.dart';
import 'package:namida/ui/pages/main_page.dart';
import 'package:namida/ui/pages/onboarding.dart';
import 'package:namida/ui/pages/queues_page.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/inner_drawer.dart';
import 'package:namida/ui/widgets/selected_tracks_preview.dart';
import 'package:namida/ui/widgets/settings/customization_settings.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';

class MainPageWrapper extends StatefulWidget {
  final bool shouldShowOnBoarding;

  const MainPageWrapper({super.key, required this.shouldShowOnBoarding});

  @override
  State<MainPageWrapper> createState() => _MainPageWrapperState();
}

class _MainPageWrapperState extends State<MainPageWrapper> {
  @override
  void initState() {
    super.initState();
    if (widget.shouldShowOnBoarding) {
      WidgetsBinding.instance.addPostFrameCallback(
        (timeStamp) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) {
            return const FirstRunConfigureScreen();
          }));
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget finalPageWrapper = NamidaInnerDrawer(
      key: NamidaNavigator.inst.innerDrawerKey,
      borderRadius: 42.0.multipliedRadius,
      drawerChild: const NamidaDrawer(),
      maxPercentage: 194.0 / context.width,
      initiallySwipeable: settings.swipeableDrawer.value,
      child: const MainScreenStack(),
    );

    if (WindowController.instance?.usingCustomWindowTitleBar == true) {
      finalPageWrapper = Column(
        children: [
          const NamidaDesktopAppBar(),
          Expanded(
            child: finalPageWrapper,
          ),
        ],
      );
    }

    return finalPageWrapper;
  }
}

class MainScreenStack extends StatefulWidget {
  const MainScreenStack({super.key});

  @override
  State<MainScreenStack> createState() => _MainScreenStackState();
}

class _MainScreenStackState extends State<MainScreenStack> with TickerProviderStateMixin {
  late AnimationController animation;

  @override
  void initState() {
    super.initState();
    animation = MiniPlayerController.inst.initialize(this);
    MiniPlayerController.inst.updateScreenValuesInitial();
    MiniPlayerController.inst.initializeSAnim(this);
    Player.inst.currentItem.addListener(_currentItemListener);
  }

  @override
  void dispose() {
    Player.inst.currentItem.removeListener(_currentItemListener);
    super.dispose();
  }

  // -- to fix black ui when nothing is playing
  bool? _isCurrentItemNull;
  void _currentItemListener() {
    final isItemNull = Player.inst.currentItem.value == null;
    if (isItemNull != _isCurrentItemNull) {
      _isCurrentItemNull = isItemNull;
      if (mounted) setState(() {}); // update mp values
    }
  }

  @override
  Widget build(BuildContext context) {
    MiniPlayerController.inst.updateScreenValues(context); // for updating after split screen & landscape values.

    final miniplayerMaxWidth = Dimensions.inst.miniplayerMaxWidth;
    final miniplayerIsWideScreen = Dimensions.inst.miniplayerIsWideScreen;

    final selectedTracksWidget = SelectedTracksPreviewContainer(
      animation: animation,
      isMiniplayerAlwaysVisible: miniplayerIsWideScreen,
    );

    // -- do not create MainPage twice as it will cause duplication issues
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Padding(
          padding: !miniplayerIsWideScreen ? EdgeInsets.zero : EdgeInsets.only(right: miniplayerMaxWidth),
          child: MediaQuery.removePadding(
            context: context,
            removeRight: miniplayerIsWideScreen,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                MainPage(
                  animation: animation,
                  isMiniplayerAlwaysVisible: miniplayerIsWideScreen,
                ),
                if (miniplayerIsWideScreen) selectedTracksWidget,
              ],
            ),
          ),
        ),
        RepaintBoundary(
          child: Padding(
            padding: !miniplayerIsWideScreen ? EdgeInsets.zero : EdgeInsets.only(left: Dimensions.inst.availableAppContentWidth),
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: miniplayerIsWideScreen,
              child: SafeArea(
                top: false,
                bottom: false,
                child: MiniPlayerParent(animation: animation),
              ),
            ),
          ),
        ),
        if (!miniplayerIsWideScreen) selectedTracksWidget,
      ],
    );
  }
}

class NamidaDrawer extends StatelessWidget {
  const NamidaDrawer({super.key});

  void toggleDrawer() => NamidaNavigator.inst.toggleDrawer();

  static void openSleepTimerDialog(BuildContext context) {
    final sleepConfig = Player.inst.sleepTimerConfig.value;
    final minutes = sleepConfig.sleepAfterMin.obs;
    final tracks = sleepConfig.sleepAfterItems.obs;
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
          ObxO(
            rx: Player.inst.sleepTimerConfig,
            builder: (context, currentConfig) {
              return currentConfig.enableSleepAfterMins || currentConfig.enableSleepAfterItems
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
                            enableSleepAfterItems: tracks.value > 0,
                            sleepAfterMin: minutes.value,
                            sleepAfterItems: tracks.value,
                          );
                        }
                        NamidaNavigator.inst.closeDialog();
                      },
                    );
            },
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
                  (context) => NamidaWheelSlider(
                    max: 180,
                    initValue: minutes.valueR,
                    onValueChanged: (val) => minutes.value = val,
                    text: "${minutes.valueR}m",
                    topText: lang.MINUTES.capitalizeFirst(),
                    textPadding: 8.0,
                  ),
                ),
                Text(
                  lang.OR,
                  style: context.textTheme.displayMedium,
                ),
                // tracks
                ObxO(
                  rx: tracks,
                  builder: (context, trs) => NamidaWheelSlider(
                    max: kMaximumSleepTimerTracks,
                    initValue: trs,
                    onValueChanged: (val) => tracks.value = val,
                    text: "$trs ${lang.TRACK}",
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
  }

  @override
  Widget build(BuildContext context) {
    final showLogoInDrawer = !(Platform.isWindows);
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SuperListView(
              children: [
                if (showLogoInDrawer)
                  NamidaLogoContainer(
                    afterTap: NamidaNavigator.inst.toggleDrawer,
                  ),
                const NamidaContainerDivider(width: 42.0, margin: EdgeInsets.all(10.0)),
                ...LibraryTab.values.map(
                  (e) => ObxO(
                    rx: settings.extra.selectedLibraryTab,
                    builder: (context, selectedLibraryTab) => NamidaDrawerListTile(
                      enabled: selectedLibraryTab == e,
                      title: e.toText(),
                      icon: e.toIcon(),
                      onTap: () async {
                        ScrollSearchController.inst.animatePageController(e);
                        toggleDrawer();
                      },
                    ),
                  ),
                ),
                NamidaDrawerListTile(
                  enabled: false,
                  title: lang.QUEUES,
                  icon: Broken.driver,
                  onTap: () {
                    const QueuesPage().navigate();
                    toggleDrawer();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),
          Material(
            borderRadius: BorderRadius.circular(12.0.multipliedRadius),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ToggleThemeModeContainer(
                  maxWidth: constraints.maxWidth - 12.0,
                  blurRadius: 3.0,
                );
              },
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
              openSleepTimerDialog(context);
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
                    SettingsSubPage(
                      title: lang.CUSTOMIZATIONS,
                      child: const CustomizationSettings(),
                    ).navigate();

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
                    const SettingsPage().navigate();
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

class NamidaDesktopAppBar extends StatefulWidget {
  const NamidaDesktopAppBar({super.key});

  @override
  State<NamidaDesktopAppBar> createState() => NamidaDesktopAppBarState();
}

class NamidaDesktopAppBarState extends State<NamidaDesktopAppBar> with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() {});
  }

  @override
  void onWindowUnmaximize() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Namida';
    final height = WindowController.instance?.windowTitleBarHeight;

    final appBarTheme = AppBarTheme.of(context);
    final theme = context.theme;
    final colorscheme = theme.colorScheme;
    final brightness = theme.brightness;
    // final backgroundColor = Color.alphaBlend(context.theme.scaffoldBackgroundColor, Colors.white.withValues(alpha: 0.25));
    final backgroundColor = appBarTheme.backgroundColor ?? colorscheme.surface;
    final surfaceTintColor = appBarTheme.surfaceTintColor ?? colorscheme.surfaceTint;
    final logoImg = context.isDarkMode ? NamidaAppIcons.monet : NamidaAppIcons.monet;
    final logoBgColor = context.isDarkMode ? const Color(0x40262729) : const Color(0x063c3f46);
    final logoTextColor = context.isDarkMode ? Color.alphaBlend(logoBgColor.withAlpha(100), Colors.white) : const Color.fromARGB(180, 44, 44, 44);
    return SizedBox(
      height: height,
      child: Material(
        shadowColor: Colors.transparent,
        type: MaterialType.canvas,
        color: backgroundColor,
        surfaceTintColor: surfaceTintColor,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: SizedBox(
                  height: double.infinity,
                  child: Row(
                    children: [
                      Flexible(
                        child: NamidaInkWell(
                          onTap: () {
                            if (NamidaNavigator.inst.currentRoute?.route != RouteType.PAGE_about) {
                              const AboutPage().navigate();
                            }
                          },
                          height: height,
                          animationDurationMS: 200,
                          decoration: BoxDecoration(
                            color: logoBgColor,
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(8.0),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 6.0),
                              Image.asset(
                                logoImg.assetPath,
                                width: 24.0,
                                height: 24.0,
                                cacheHeight: 240,
                                cacheWidth: 240,
                                alignment: Alignment.center,
                              ),
                              const SizedBox(width: 4.0),
                              Text(
                                title,
                                style: context.textTheme.displayMedium?.copyWith(
                                  color: logoTextColor,
                                  fontSize: 14.0,
                                ),
                                overflow: TextOverflow.fade,
                                softWrap: false,
                              ),
                              const SizedBox(width: 6.0),
                              const SizedBox(width: 4.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            WindowCaptionButton.minimize(
              brightness: brightness,
              onPressed: () async {
                bool isMinimized = await windowManager.isMinimized();
                if (isMinimized) {
                  windowManager.restore();
                } else {
                  windowManager.minimize();
                }
              },
            ),
            FutureBuilder<bool>(
              future: windowManager.isMaximized(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return WindowCaptionButton.unmaximize(
                    brightness: brightness,
                    onPressed: windowManager.unmaximize,
                  );
                }
                return WindowCaptionButton.maximize(
                  brightness: brightness,
                  onPressed: windowManager.maximize,
                );
              },
            ),
            WindowCaptionButton.close(
              brightness: brightness,
              onPressed: windowManager.close,
            ),
          ],
        ),
      ),
    );
  }
}
