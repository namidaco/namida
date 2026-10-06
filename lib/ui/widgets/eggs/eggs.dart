// all eggs ui by claude
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:namida/class/eggs_data.dart';
import 'package:namida/controller/eggs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/floating_image.dart';
import 'package:namida/ui/widgets/settings_card.dart';

part 'eggs.festival.dart';
part 'eggs.painters.dart';
part 'eggs.stage.dart';

const _kGoldenEggColor = Color(0xFFF2B233);

abstract class EggHunt {
  static void collect(NamidaEgg egg) {
    final isNew = EggsController.inst.collect(egg);
    if (isNew) _announce(egg);
  }

  static void countDismissal() {
    final isEarned = EggsController.inst.countDismissal();
    if (isEarned) _announce(NamidaEgg.tsundere, message: 'mou~ fine, take it');
  }

  static void onSettingsSearchSubmitted(String text) {
    if (!EggsController.inst.isSecretWord(text)) return;
    collect(NamidaEgg.secretWord);
  }

  static void announceFound(List<NamidaEgg> eggs) {
    if (eggs.isEmpty) return;
    final names = eggs.map((egg) => egg.toText()).join(', ');
    _announce(eggs.first, message: names);
  }

  static void _announce(NamidaEgg egg, {String? message}) {
    final collectedCount = settings.eggs.value.collectedCount();
    final title = message ?? egg.toText();
    VibratorController.medium();
    snackyy(
      iconWidget: _PoppingEgg(
        egg: egg,
      ),
      title: 'egg found!',
      message: '$title · $collectedCount/${NamidaEgg.values.length}',
      displayDuration: SnackDisplayDuration.long,
    );
  }
}

class UwuDialog extends StatefulWidget {
  final EggUnlockable unlockable;
  final List<NamidaEgg> newEggs;
  final void Function() onEnable;

  const UwuDialog({
    super.key,
    required this.unlockable,
    required this.newEggs,
    required this.onEnable,
  });

  @override
  State<UwuDialog> createState() => _UwuDialogState();
}

class _UwuDialogState extends State<UwuDialog> with TickerProviderStateMixin {
  static const _kCreepStare = Duration(seconds: 60);
  static final _kBeats = [
    (0.1, VibratorController.light),
    (0.19, VibratorController.light),
    (0.28, VibratorController.medium),
    (_Finale.crackBegin, VibratorController.high),
    for (final at in _Finale.fireworkStarts) (at, VibratorController.light),
  ];

  late final _finaleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final _blushController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _isCelebrating = false;
  int _beatsPlayed = 0;
  Timer? _creepTimer;

  @override
  void initState() {
    super.initState();
    _finaleController.addListener(_playBeats);
    final isCreepCollected = settings.eggs.value.isCollected(NamidaEgg.creep);
    if (!isCreepCollected) _creepTimer = Timer(_kCreepStare, () => EggHunt.collect(NamidaEgg.creep));
  }

  @override
  void dispose() {
    _creepTimer?.cancel();
    _finaleController.dispose();
    _blushController.dispose();
    super.dispose();
  }

  void _playBeats() {
    final t = _finaleController.value;
    while (_beatsPlayed < _kBeats.length) {
      final (at, vibrate) = _kBeats[_beatsPlayed];
      if (t < at) return;
      _beatsPlayed++;
      vibrate();
    }
  }

  void _blush() => _blushController.forward(from: 0.0);

  Future<void> _crackEgg() async {
    if (_isCelebrating) return;
    final hadEconomyEgg = settings.eggs.value.isCollected(NamidaEgg.economy);
    final didUnlock = EggsController.inst.unlock(widget.unlockable);
    if (!didUnlock) return;
    setState(() => _isCelebrating = true);
    await _finaleController.forward();
    if (!mounted) return;
    NamidaNavigator.inst.closeDialog();
    widget.onEnable();
    final hasEconomyEgg = settings.eggs.value.isCollected(NamidaEgg.economy);
    if (hasEconomyEgg && !hadEconomyEgg) EggHunt._announce(NamidaEgg.economy);
  }

  void _openNoSupportDialogs() {
    final onEnable = widget.onEnable;
    NamidaNavigator.inst.closeDialog();
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: '!!',
        bodyText: "EH? YOU DON'T WANT TO SUPPORT?",
        actions: [
          NamidaSupportButton(
            title: lang.yes,
            iconWidget: const _BeatingHeart(),
          ),
          NamidaButton(
            text: lang.no,
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  title: 'kechi',
                  bodyText: 'hidoii ಥ_ಥ here use it as much as u can, dw im not upset or anything ^^, or am i?',
                  actions: [
                    NamidaButton(
                      text: lang.unlock.toUpperCase(),
                      onTap: () {
                        NamidaNavigator.inst.closeDialog();
                        onEnable();
                      },
                    ),
                    NamidaButton(
                      text: lang.support.toUpperCase(),
                      onTap: () {
                        NamidaNavigator.inst.closeDialog();
                        NamidaLinkUtils.openLink(AppSocial.DONATE_BUY_ME_A_COFFEE);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomBlurryDialog(
          normalTitleStyle: true,
          contentPadding: const EdgeInsets.fromLTRB(28.0, 14.0, 24.0, 14.0),
          frame: const _FestiveFrame(),
          titleWidgetInPadding: _BlushingTitle(
            blush: _blushController,
          ),
          actions: [
            _CrackEggButton(
              price: widget.unlockable.price,
              onTap: _crackEgg,
            ),
            const NamidaSupportButton(
              iconWidget: _BeatingHeart(),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DoubleTapDetector(
                onDoubleTap: () => EggsController.inst.collect(NamidaEgg.ano),
                child: const Text(
                  'a- ano...',
                ),
              ),
              const Text(
                'this one is actually supposed to be for supporters, if you don\'t mind u can support namida and get the power to unleash this cool feature',
              ),
              TapDetector(
                onTap: _openNoSupportDialogs,
                child: const _Glittering(
                  child: Text(
                    'or you just wanna use it like that? mattaku',
                  ),
                ),
              ),
              const SizedBox(
                height: 12.0,
              ),
              _EggsStage(
                revealOnStart: widget.newEggs,
                onEggLanded: _blush,
              ),
            ],
          ),
        ),
        if (_isCelebrating)
          AbsorbPointer(
            child: _Festival(
              progress: _finaleController,
              unlockable: widget.unlockable,
            ),
          ),
      ],
    );
  }
}

class EggsSection extends StatefulWidget {
  const EggsSection({super.key});

  @override
  State<EggsSection> createState() => _EggsSectionState();
}

class _EggsSectionState extends State<EggsSection> with _AfterRouteSettled {
  @override
  void onRouteSettled() {
    final found = EggsController.inst.collectPending();
    EggHunt.announceFound(found);
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.eggs,
      builder: (context, data) {
        final collectedCount = data.collectedCount();
        return SettingsCard(
          icon: Broken.gift,
          title: 'Eggs',
          subtitle: '$collectedCount/${NamidaEgg.values.length} found',
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: _EggsStage(),
              ),
              for (final item in EggUnlockable.values)
                if (data.isUnlocked(item))
                  _UnlockedTile(
                    item: item,
                  ),
            ],
          ),
        );
      },
    );
  }
}

class DateEggAppBarIcon extends StatelessWidget {
  const DateEggAppBarIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: EggsController.inst.pendingDateEgg,
      builder: (context, egg) => AnimatedShow(
        show: egg != null,
        isHorizontal: true,
        curve: Curves.fastEaseInToSlowEaseOut,
        duration: const Duration(milliseconds: 400),
        child: egg == null
            ? const SizedBox()
            : NamidaAppBarIcon(
                icon: Broken.gift,
                tooltip: egg.toHint,
                onPressed: () => EggHunt.collect(egg),
                child: _PoppingEgg(
                  egg: egg,
                ),
              ),
      ),
    );
  }
}

class _CrackEggButton extends StatelessWidget {
  final int price;
  final void Function() onTap;

  const _CrackEggButton({required this.price, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.eggs,
      builder: (context, data) {
        final canCrack = data.balance() >= price;
        return NamidaButton(
          enabled: canCrack,
          iconWidget: _FloatingEgg(
            isActive: canCrack,
          ),
          text: 'crack $price eggs',
          onTap: onTap,
        );
      },
    );
  }
}

class _UnlockedTile extends StatelessWidget {
  final EggUnlockable item;

  const _UnlockedTile({required this.item});

  void _confirmSelling() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        icon: Broken.wallet_add,
        title: 'sell it back?',
        bodyText: '${item.toText()} gets locked again, and you get your ${item.price} eggs back',
        actions: [
          const CancelButton(),
          NamidaButton(
            text: 'SELL',
            onTap: () {
              NamidaNavigator.inst.closeDialog();
              EggsController.inst.relock(item);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      icon: item.toIcon(),
      title: item.toText(),
      trailing: NamidaIconButton(
        icon: Broken.wallet_add,
        tooltip: () => 'sell back for ${item.price} eggs',
        onPressed: _confirmSelling,
      ),
    );
  }
}

class _BlushingTitle extends StatelessWidget {
  final Animation<double> blush;

  const _BlushingTitle({required this.blush});

  static final _bump = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.14).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30.0,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.14, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
      weight: 70.0,
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final bump = blush.drive(_bump);
    return ScaleTransition(
      scale: bump,
      alignment: Alignment.centerLeft,
      child: CustomPaint(
        painter: _BlushPainter(
          blush: blush,
        ),
        child: Text(
          'uwu',
          style: context.textTheme.displayLarge,
        ),
      ),
    );
  }
}

/// holds [onRouteSettled] until the route finished animating in, so heavier work never lands on the transition.
mixin _AfterRouteSettled<T extends StatefulWidget> on State<T> {
  Animation<double>? _pendingRouteAnimation;
  bool _didCheckRoute = false;

  void onRouteSettled();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didCheckRoute) return;
    _didCheckRoute = true;
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation == null || routeAnimation.status == AnimationStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback(_onFirstFrameDone);
      return;
    }
    _pendingRouteAnimation = routeAnimation;
    routeAnimation.addStatusListener(_onRouteStatusChanged);
  }

  void _onFirstFrameDone(Duration _) {
    if (mounted) onRouteSettled();
  }

  void _onRouteStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _stopWaitingForRoute();
    onRouteSettled();
  }

  void _stopWaitingForRoute() {
    _pendingRouteAnimation?.removeStatusListener(_onRouteStatusChanged);
    _pendingRouteAnimation = null;
  }

  @override
  void dispose() {
    _stopWaitingForRoute();
    super.dispose();
  }
}

extension _NamidaEggText on NamidaEgg {
  String toText() => switch (this) {
    NamidaEgg.ano => 'Shy egg',
    NamidaEgg.loyal => 'Loyal listener',
    NamidaEgg.albumPurist => 'Album purist',
    NamidaEgg.obsessed => 'Obsessed',
    NamidaEgg.dizzy => 'Dizzy',
    NamidaEgg.secretWord => 'Secret word',
    NamidaEgg.tsundere => 'Tsundere',
    NamidaEgg.newYear => 'New year',
    NamidaEgg.birthday => 'Birthday',
    NamidaEgg.anniversary => 'Anniversary',
    NamidaEgg.economy => 'Economist',
    NamidaEgg.nightOwl => 'Night owl',
    NamidaEgg.veteran => 'Veteran',
    NamidaEgg.chipmunk => 'Chipmunk',
    NamidaEgg.broke => 'Broke',
    NamidaEgg.hoarder => 'Hoarder',
    NamidaEgg.tears => 'Tears',
    NamidaEgg.creep => 'Creep',
    NamidaEgg.lucky => 'Lucky',
    NamidaEgg.goodnight => 'Goodnight',
    NamidaEgg.twins => 'Twins',
    NamidaEgg.colorful => 'Colorful',
  };

  String toHint() => switch (this) {
    NamidaEgg.ano => 'she gets flustered easily, two headpats might help',
    NamidaEgg.loyal => 'listen, and listen, and listen... ten thousand times',
    NamidaEgg.albumPurist => 'some albums are meant to be heard front to back',
    NamidaEgg.obsessed => 'that one song... you know the one... 200 times (no judge)',
    NamidaEgg.dizzy => 'kurukuru.. kurukuru...',
    NamidaEgg.secretWord => 'the settings search knows a few cute words',
    NamidaEgg.tsundere => 'she says no, but maybe ask again... and again',
    NamidaEgg.newYear => 'spend new year\'s eve with namida, watch the top bar',
    NamidaEgg.birthday => 'namida was born on a cold january day',
    NamidaEgg.anniversary => 'namida grew up one october',
    NamidaEgg.economy => 'buy, sell, buy, sell... five trades and the market notices',
    NamidaEgg.nightOwl => '3am and still listening? go to sleep',
    NamidaEgg.veteran => 'a whole year of memories in your history',
    NamidaEgg.chipmunk => 'faster.. no, faster.. or squeakier',
    NamidaEgg.broke => 'spend every last egg',
    NamidaEgg.hoarder => 'save up five eggs without cracking any',
    NamidaEgg.tears => 'namida means tears, got a song about them?',
    NamidaEgg.creep => 'staring at the eggs for a whole minute... creepy',
    NamidaEgg.lucky => 'sometimes she just feels generous',
    NamidaEgg.goodnight => 'let the sleep timer tuck you in',
    NamidaEgg.twins => 'sync with another device',
    NamidaEgg.colorful => 'find every other egg',
  };
}

extension _NamidaEggLook on NamidaEgg {
  bool get isRainbow => this == NamidaEgg.colorful;

  bool get isShiny => worth > 1 || isRainbow;

  Color colorOf(ColorScheme colorScheme) => worth > 1 ? _kGoldenEggColor : colorScheme.primary;
}

extension _EggUnlockableText on EggUnlockable {
  String toText() => switch (this) {
    EggUnlockable.crossfade => lang.crossfade,
    EggUnlockable.partyMode => 'Party mode',
    EggUnlockable.starfield => EffectTheme.starfield.toText(),
    EggUnlockable.galaxy => EffectTheme.galaxy.toText(),
    EggUnlockable.aurora => EffectTheme.aurora.toText(),
    EggUnlockable.fireworks => EffectTheme.fireworks.toText(),
    EggUnlockable.deepOcean => EffectTheme.deepOcean.toText(),
    EggUnlockable.mirroredBars => MiniplayerVisualizer.mirroredBars.toText(),
    EggUnlockable.glow => MiniplayerVisualizer.glow.toText(),
    EggUnlockable.outline => MiniplayerVisualizer.outline.toText(),
    EggUnlockable.edgeLights => MiniplayerVisualizer.edgeLights.toText(),
    EggUnlockable.playerBackgroundImage => lang.playerBackground,
    EggUnlockable.appWallpaper => lang.wallpaper,
  };

  IconData toIcon() => switch (this) {
    EggUnlockable.crossfade => Broken.recovery_convert,
    EggUnlockable.partyMode => Broken.slider_horizontal_1,
    EggUnlockable.starfield => EffectTheme.starfield.toIcon(),
    EggUnlockable.galaxy => EffectTheme.galaxy.toIcon(),
    EggUnlockable.aurora => EffectTheme.aurora.toIcon(),
    EggUnlockable.fireworks => EffectTheme.fireworks.toIcon(),
    EggUnlockable.deepOcean => EffectTheme.deepOcean.toIcon(),
    EggUnlockable.mirroredBars => MiniplayerVisualizer.mirroredBars.toIcon(),
    EggUnlockable.glow => MiniplayerVisualizer.glow.toIcon(),
    EggUnlockable.outline => MiniplayerVisualizer.outline.toIcon(),
    EggUnlockable.edgeLights => MiniplayerVisualizer.edgeLights.toIcon(),
    EggUnlockable.playerBackgroundImage => PlayerBackground.image.toIcon(),
    EggUnlockable.appWallpaper => Broken.gallery,
  };
}
