part of 'effects.dart';

_EffectPreset? _presetOf(EffectTheme theme, _Layer layer) {
  final isOverlay = layer == _Layer.overlay;
  return switch (theme) {
    EffectTheme.auto || EffectTheme.none => null,
    EffectTheme.particles => isOverlay ? const _EffectPreset(_kParticlesOverlay) : const _EffectPreset(_kParticles),
    EffectTheme.fireflies => isOverlay ? const _EffectPreset(_kFirefliesOverlay) : const _EffectPreset(_kFireflies),
    EffectTheme.starfield => isOverlay ? const _EffectPreset(_kStarfieldOverlay) : const _EffectPreset(_kStarfield),
    EffectTheme.galaxy => isOverlay ? const _EffectPreset(_kGalaxyOverlay) : const _EffectPreset(_kGalaxy),
    EffectTheme.aurora => const _EffectPreset(_kAuroraStars, scenery: _Scenery.aurora),
    EffectTheme.deepOcean => isOverlay ? const _EffectPreset(_kDeepOceanOverlay) : const _EffectPreset(_kDeepOcean, scenery: _Scenery.deepWater),
    EffectTheme.rain => isOverlay ? const _EffectPreset(_kRainOverlay) : const _EffectPreset(_kRain),
    EffectTheme.sakura => isOverlay ? const _EffectPreset(_kSakuraOverlay) : const _EffectPreset(_kSakura),
    EffectTheme.fireworks => isOverlay ? const _EffectPreset(_kFireworksOverlay) : const _EffectPreset(_kFireworks),
    EffectTheme.halloween => isOverlay ? const _EffectPreset(_kHalloweenOverlay) : const _EffectPreset(_kHalloween),
    EffectTheme.christmas => isOverlay ? const _EffectPreset(_kChristmasOverlay) : const _EffectPreset(_kChristmas),
    EffectTheme.ramadan => isOverlay ? const _EffectPreset(_kRamadanOverlay) : const _EffectPreset(_kRamadan),
  };
}

const _kWholeField = Rect.fromLTRB(0.0, 0.0, 1.0, 1.0);

const _kParticles = [
  _Emitter(
    motion: _Motion.wander,
    sprites: [_Sprite.dot],
    count: 30,
    minSize: 4.0,
    maxSize: 9.0,
    minSpeed: 6.0,
    maxSpeed: 26.0,
    minAlpha: 0.12,
    maxAlpha: 0.42,
    audio: 0.35,
  ),
];

const _kParticlesOverlay = [
  _Emitter(
    motion: _Motion.wander,
    sprites: [_Sprite.dot],
    count: 20,
    minSize: 4.0,
    maxSize: 8.0,
    minSpeed: 6.0,
    maxSpeed: 26.0,
    minAlpha: 0.10,
    maxAlpha: 0.30,
    audio: 0.35,
  ),
];

const _kFireflyColors = [0xE8FF8A, 0xC6F56B, 0xFFF3A0];
const _kFireflyColorsLight = [0x7E9A12, 0x9AA81E];

const _kFireflies = [
  _Emitter(
    motion: _Motion.wander,
    sprites: [_Sprite.glow],
    count: 26,
    minSize: 9.0,
    maxSize: 18.0,
    minSpeed: 5.0,
    maxSpeed: 16.0,
    minAlpha: 0.45,
    maxAlpha: 0.95,
    minRate: 0.18,
    maxRate: 0.5,
    colors: _kFireflyColors,
    colorsLight: _kFireflyColorsLight,
    audio: 0.12,
    doesFlicker: true,
  ),
];

const _kFirefliesOverlay = [
  _Emitter(
    motion: _Motion.wander,
    sprites: [_Sprite.glow],
    count: 16,
    minSize: 9.0,
    maxSize: 16.0,
    minSpeed: 5.0,
    maxSpeed: 16.0,
    minAlpha: 0.35,
    maxAlpha: 0.8,
    minRate: 0.18,
    maxRate: 0.5,
    colors: _kFireflyColors,
    colorsLight: _kFireflyColorsLight,
    audio: 0.12,
    doesFlicker: true,
  ),
];

const _kSpaceStarColors = [0xFFFFFF, 0xDCE8FF, 0xFFF1D6];
const _kSpaceStarColorsLight = [0x4A5A8A, 0x6A5A9A, 0x5A6A7A];

const _kFarStars = _Emitter(
  motion: _Motion.wander,
  sprites: [_Sprite.dot],
  count: 70,
  minSize: 1.6,
  maxSize: 3.6,
  minSpeed: 1.0,
  maxSpeed: 4.0,
  minAlpha: 0.35,
  maxAlpha: 0.95,
  minRate: 0.1,
  maxRate: 0.45,
  colors: _kSpaceStarColors,
  colorsLight: _kSpaceStarColorsLight,
  doesFlicker: true,
);

const _kNearStars = _Emitter(
  motion: _Motion.twinkle,
  sprites: [_Sprite.sparkle],
  count: 9,
  minSize: 8.0,
  maxSize: 16.0,
  minAlpha: 0.4,
  maxAlpha: 0.95,
  minRate: 0.12,
  maxRate: 0.4,
  colors: _kSpaceStarColors,
  colorsLight: _kSpaceStarColorsLight,
  audio: 0.6,
);

const _kShootingStar = _Emitter(
  motion: _Motion.drift,
  sprites: [_Sprite.streak],
  count: 2,
  minSize: 70.0,
  maxSize: 110.0,
  minSpeed: 420.0,
  maxSpeed: 640.0,
  minAlpha: 0.6,
  maxAlpha: 0.95,
  colors: _kSpaceStarColors,
  colorsLight: _kSpaceStarColorsLight,
  slope: 0.45,
  pause: 9.0,
  isAligned: true,
  region: Rect.fromLTRB(0.0, 0.0, 1.0, 0.45),
);

const _kStarfield = [
  _kFarStars,
  _kNearStars,
  _kShootingStar,
];

const _kStarfieldOverlay = [
  _Emitter(
    motion: _Motion.wander,
    sprites: [_Sprite.dot],
    count: 40,
    minSize: 1.6,
    maxSize: 3.4,
    minSpeed: 1.0,
    maxSpeed: 4.0,
    minAlpha: 0.3,
    maxAlpha: 0.8,
    minRate: 0.1,
    maxRate: 0.45,
    colors: _kSpaceStarColors,
    colorsLight: _kSpaceStarColorsLight,
    doesFlicker: true,
  ),
  _kShootingStar,
];

const _kNebulaColors = [0x7B4DFF, 0x3D6BFF, 0xFF4DA6, 0x29C4D6];
const _kNebulaColorsLight = [0x8E6BE8, 0x6B8EE8, 0xE86BAE];

const _kNebula = _Emitter(
  motion: _Motion.wander,
  sprites: [_Sprite.glow],
  count: 5,
  minSize: 240.0,
  maxSize: 460.0,
  minSpeed: 2.0,
  maxSpeed: 6.0,
  minAlpha: 0.08,
  maxAlpha: 0.18,
  minRate: 0.03,
  maxRate: 0.07,
  colors: _kNebulaColors,
  colorsLight: _kNebulaColorsLight,
  audio: 0.04,
  doesFlicker: true,
);

const _kGalaxyStarColors = [0xFFFFFF, 0xBFD4FF, 0xFFD9F0, 0xC9B8FF];
const _kGalaxyStarColorsLight = [0x4A5A8A, 0x6A5A9A, 0x8A4A7A];
const _kGalaxyCoreColors = [0xFFE9C0];
const _kGalaxyCoreColorsLight = [0xC8962E];
const _kGalaxyTurnsPerSecond = 0.008;
const _kGalaxyDisc = Rect.fromLTRB(0.02, 0.36, 0.98, 0.36);
const _kGalaxyMiddle = Rect.fromLTRB(0.5, 0.36, 0.5, 0.36);

const _kGalaxyCore = _Emitter(
  motion: _Motion.twinkle,
  sprites: [_Sprite.glow],
  count: 1,
  minSize: 210.0,
  maxSize: 210.0,
  minAlpha: 0.9,
  maxAlpha: 0.9,
  minRate: 0.05,
  maxRate: 0.05,
  colors: _kGalaxyCoreColors,
  colorsLight: _kGalaxyCoreColorsLight,
  audio: 0.3,
  region: _kGalaxyMiddle,
);

const _kGalaxyHaze = _Emitter(
  motion: _Motion.orbit,
  sprites: [_Sprite.glow],
  count: 70,
  minSize: 30.0,
  maxSize: 76.0,
  minAlpha: 0.10,
  maxAlpha: 0.24,
  minRate: _kGalaxyTurnsPerSecond,
  maxRate: _kGalaxyTurnsPerSecond,
  colors: _kNebulaColors,
  colorsLight: _kNebulaColorsLight,
  audio: 1.0,
  region: _kGalaxyDisc,
);

const _kGalaxyStars = _Emitter(
  motion: _Motion.orbit,
  sprites: [_Sprite.dot],
  count: 280,
  minSize: 1.4,
  maxSize: 3.8,
  minAlpha: 0.45,
  maxAlpha: 1.0,
  minRate: _kGalaxyTurnsPerSecond,
  maxRate: _kGalaxyTurnsPerSecond,
  colors: _kGalaxyStarColors,
  colorsLight: _kGalaxyStarColorsLight,
  audio: 1.0,
  doesFlicker: true,
  region: _kGalaxyDisc,
);

const _kGalaxy = [
  _kNebula,
  _kFarStars,
  _kGalaxyHaze,
  _kGalaxyCore,
  _kGalaxyStars,
  _kShootingStar,
];

const _kGalaxyOverlay = [
  _Emitter(
    motion: _Motion.orbit,
    sprites: [_Sprite.glow],
    count: 36,
    minSize: 30.0,
    maxSize: 70.0,
    minAlpha: 0.06,
    maxAlpha: 0.14,
    minRate: _kGalaxyTurnsPerSecond,
    maxRate: _kGalaxyTurnsPerSecond,
    colors: _kNebulaColors,
    colorsLight: _kNebulaColorsLight,
    audio: 1.0,
    region: _kGalaxyDisc,
  ),
  _Emitter(
    motion: _Motion.twinkle,
    sprites: [_Sprite.glow],
    count: 1,
    minSize: 180.0,
    maxSize: 180.0,
    minAlpha: 0.55,
    maxAlpha: 0.55,
    minRate: 0.05,
    maxRate: 0.05,
    colors: _kGalaxyCoreColors,
    colorsLight: _kGalaxyCoreColorsLight,
    audio: 0.3,
    region: _kGalaxyMiddle,
  ),
  _Emitter(
    motion: _Motion.orbit,
    sprites: [_Sprite.dot],
    count: 150,
    minSize: 1.4,
    maxSize: 3.4,
    minAlpha: 0.35,
    maxAlpha: 0.85,
    minRate: _kGalaxyTurnsPerSecond,
    maxRate: _kGalaxyTurnsPerSecond,
    colors: _kGalaxyStarColors,
    colorsLight: _kGalaxyStarColorsLight,
    audio: 1.0,
    doesFlicker: true,
    region: _kGalaxyDisc,
  ),
  _kShootingStar,
];

const _kAuroraStars = [
  _Emitter(
    motion: _Motion.twinkle,
    sprites: [_Sprite.dot],
    count: 26,
    minSize: 1.8,
    maxSize: 3.6,
    minAlpha: 0.3,
    maxAlpha: 0.85,
    minRate: 0.12,
    maxRate: 0.4,
    colors: _kSpaceStarColors,
    colorsLight: _kSpaceStarColorsLight,
    region: Rect.fromLTRB(0.0, 0.0, 1.0, 0.55),
  ),
];

const _kBubbleColors = [0xD6F3FF, 0xA8E4FF];
const _kBubbleColorsLight = [0x2F7FA8, 0x3A93BF];
const _kSeaLifeShades = 0.35;

const _kJellyfish = _Emitter(
  motion: _Motion.rise,
  sprites: [_Sprite.jellyfish],
  count: 5,
  minSize: 40.0,
  maxSize: 84.0,
  minSpeed: 6.0,
  maxSpeed: 14.0,
  minAlpha: 0.5,
  maxAlpha: 0.85,
  sway: 14.0,
  minRate: 0.12,
  maxRate: 0.22,
  pulse: 0.07,
  shades: _kSeaLifeShades,
  audio: 0.4,
);

const _kMarineSnow = _Emitter(
  motion: _Motion.fall,
  sprites: [_Sprite.dot],
  count: 40,
  minSize: 1.4,
  maxSize: 3.0,
  minSpeed: 5.0,
  maxSpeed: 14.0,
  minAlpha: 0.15,
  maxAlpha: 0.45,
  sway: 6.0,
  minRate: 0.05,
  maxRate: 0.15,
  colors: _kBubbleColors,
  colorsLight: _kBubbleColorsLight,
);

const _kBubbles = _Emitter(
  motion: _Motion.rise,
  sprites: [_Sprite.bubble],
  count: 6,
  minSize: 6.0,
  maxSize: 20.0,
  minSpeed: 22.0,
  maxSpeed: 56.0,
  minAlpha: 0.3,
  maxAlpha: 0.75,
  sway: 12.0,
  minRate: 0.15,
  maxRate: 0.4,
  colors: _kBubbleColors,
  colorsLight: _kBubbleColorsLight,
  audio: 0.5,
);

const _kFish = _Emitter(
  motion: _Motion.drift,
  sprites: [_Sprite.fishRight, _Sprite.fishLeft],
  isFacing: true,
  count: 4,
  minSize: 14.0,
  maxSize: 30.0,
  minSpeed: 18.0,
  maxSpeed: 42.0,
  minAlpha: 0.45,
  maxAlpha: 0.75,
  sway: 10.0,
  shades: _kSeaLifeShades,
  audio: 0.3,
  pause: 5.0,
  region: Rect.fromLTRB(0.0, 0.2, 1.0, 0.9),
);

const _kDeepOcean = [
  _kMarineSnow,
  _Emitter(
    motion: _Motion.wander,
    sprites: [_Sprite.glow],
    count: 22,
    minSize: 4.0,
    maxSize: 9.0,
    minSpeed: 3.0,
    maxSpeed: 9.0,
    minAlpha: 0.3,
    maxAlpha: 0.8,
    minRate: 0.1,
    maxRate: 0.3,
    shades: _kSeaLifeShades,
    doesFlicker: true,
  ),
  _kFish,
  _kJellyfish,
  _kBubbles,
];

const _kDeepOceanOverlay = [
  _Emitter(
    motion: _Motion.fall,
    sprites: [_Sprite.dot],
    count: 24,
    minSize: 1.4,
    maxSize: 3.0,
    minSpeed: 5.0,
    maxSpeed: 14.0,
    minAlpha: 0.15,
    maxAlpha: 0.4,
    sway: 6.0,
    minRate: 0.05,
    maxRate: 0.15,
    colors: _kBubbleColors,
    colorsLight: _kBubbleColorsLight,
  ),
  _Emitter(
    motion: _Motion.rise,
    sprites: [_Sprite.jellyfish],
    count: 3,
    minSize: 40.0,
    maxSize: 72.0,
    minSpeed: 6.0,
    maxSpeed: 14.0,
    minAlpha: 0.35,
    maxAlpha: 0.6,
    sway: 14.0,
    minRate: 0.12,
    maxRate: 0.22,
    pulse: 0.07,
    shades: _kSeaLifeShades,
    audio: 0.4,
  ),
];

const _kRainColors = [0xCFE3FF, 0xA9C8F0];
const _kRainColorsLight = [0x4F6F9A, 0x5F7FAA];

const _kRain = [
  _Emitter(
    motion: _Motion.fall,
    sprites: [_Sprite.streak],
    count: 70,
    minSize: 16.0,
    maxSize: 34.0,
    minSpeed: 520.0,
    maxSpeed: 860.0,
    minAlpha: 0.18,
    maxAlpha: 0.5,
    colors: _kRainColors,
    colorsLight: _kRainColorsLight,
    audio: 0.5,
    wind: 90.0,
    isAligned: true,
  ),
];

const _kRainOverlay = [
  _Emitter(
    motion: _Motion.fall,
    sprites: [_Sprite.streak],
    count: 44,
    minSize: 16.0,
    maxSize: 30.0,
    minSpeed: 520.0,
    maxSpeed: 860.0,
    minAlpha: 0.14,
    maxAlpha: 0.38,
    colors: _kRainColors,
    colorsLight: _kRainColorsLight,
    audio: 0.5,
    wind: 90.0,
    isAligned: true,
  ),
];

const _kPetalColors = [0xFFC2D9, 0xFFA8C8, 0xFFD9E6];
const _kPetalColorsLight = [0xF08BB0, 0xE86A9A, 0xF4A3C0];

const _kSakura = [
  _Emitter(
    motion: _Motion.fall,
    sprites: [_Sprite.petal],
    count: 26,
    minSize: 9.0,
    maxSize: 17.0,
    minSpeed: 24.0,
    maxSpeed: 52.0,
    minAlpha: 0.5,
    maxAlpha: 0.95,
    sway: 30.0,
    minRate: 0.1,
    maxRate: 0.3,
    spin: 1.8,
    colors: _kPetalColors,
    colorsLight: _kPetalColorsLight,
    audio: 0.4,
    wind: 14.0,
  ),
];

const _kSakuraOverlay = [
  _Emitter(
    motion: _Motion.fall,
    sprites: [_Sprite.petal],
    count: 16,
    minSize: 9.0,
    maxSize: 16.0,
    minSpeed: 24.0,
    maxSpeed: 52.0,
    minAlpha: 0.4,
    maxAlpha: 0.8,
    sway: 30.0,
    minRate: 0.1,
    maxRate: 0.3,
    spin: 1.8,
    colors: _kPetalColors,
    colorsLight: _kPetalColorsLight,
    audio: 0.4,
    wind: 14.0,
  ),
];

const _kFireworkColors = [0xFF5A5A, 0xFFD24D, 0x5AD1FF, 0x8CFF7A, 0xFF7AE0, 0xFFFFFF];
const _kFireworkColorsLight = [0xE03A3A, 0xD89A1A, 0x2A8FD0, 0x3FAE3A, 0xD04AB0];

const _kFireworks = [
  _Emitter(
    motion: _Motion.burst,
    sprites: [_Sprite.glow],
    count: 150,
    burstSize: 30,
    minSize: 8.0,
    maxSize: 14.0,
    minSpeed: 70.0,
    maxSpeed: 150.0,
    minAlpha: 0.7,
    maxAlpha: 1.0,
    colors: _kFireworkColors,
    colorsLight: _kFireworkColorsLight,
    audio: 1.0,
    pause: 3.5,
    region: Rect.fromLTRB(0.12, 0.08, 0.88, 0.55),
  ),
];

const _kFireworksOverlay = [
  _Emitter(
    motion: _Motion.burst,
    sprites: [_Sprite.glow],
    count: 90,
    burstSize: 30,
    minSize: 8.0,
    maxSize: 13.0,
    minSpeed: 70.0,
    maxSpeed: 140.0,
    minAlpha: 0.55,
    maxAlpha: 0.85,
    colors: _kFireworkColors,
    colorsLight: _kFireworkColorsLight,
    audio: 1.0,
    pause: 5.0,
    region: Rect.fromLTRB(0.12, 0.08, 0.88, 0.55),
  ),
];

const _kSnowColors = [0xFFFFFF];
const _kSnowColorsLight = [0x7FA3C7, 0x94B4D4];
const _kGarlandColors = [0xFF4D4D, 0x4DDB6E, 0xFFD24D, 0x4DA6FF];

const _kSnowFar = _Emitter(
  motion: _Motion.fall,
  sprites: [_Sprite.glow],
  count: 36,
  minSize: 4.0,
  maxSize: 8.0,
  minSpeed: 16.0,
  maxSpeed: 34.0,
  minAlpha: 0.35,
  maxAlpha: 0.8,
  sway: 9.0,
  minRate: 0.10,
  maxRate: 0.30,
  colors: _kSnowColors,
  colorsLight: _kSnowColorsLight,
  audio: 0.5,
);

const _kSnowNear = _Emitter(
  motion: _Motion.fall,
  sprites: [_Sprite.flake],
  count: 12,
  minSize: 11.0,
  maxSize: 19.0,
  minSpeed: 28.0,
  maxSpeed: 52.0,
  minAlpha: 0.45,
  maxAlpha: 0.9,
  sway: 18.0,
  minRate: 0.08,
  maxRate: 0.22,
  spin: 0.7,
  colors: _kSnowColors,
  colorsLight: _kSnowColorsLight,
  audio: 0.5,
);

const _kSnowmen = _Emitter(
  motion: _Motion.twinkle,
  sprites: [_Sprite.snowman],
  count: 2,
  minSize: 44.0,
  maxSize: 60.0,
  minAlpha: 0.45,
  maxAlpha: 0.8,
  minRate: 0.04,
  maxRate: 0.07,
  audio: 0.4,
  doesRelocate: true,
  region: Rect.fromLTRB(0.08, 0.5, 0.92, 0.9),
);

const _kChristmas = [
  _kSnowmen,
  _kSnowFar,
  _kSnowNear,
  _Emitter(
    motion: _Motion.string,
    sprites: [_Sprite.bulb],
    count: 14,
    minSize: 15.0,
    maxSize: 15.0,
    minAlpha: 0.55,
    maxAlpha: 1.0,
    minRate: 0.25,
    maxRate: 0.6,
    colors: _kGarlandColors,
    audio: 1.0,
  ),
];

const _kChristmasOverlay = [
  _Emitter(
    motion: _Motion.twinkle,
    sprites: [_Sprite.snowman],
    count: 1,
    minSize: 44.0,
    maxSize: 56.0,
    minAlpha: 0.4,
    maxAlpha: 0.65,
    minRate: 0.04,
    maxRate: 0.07,
    audio: 0.4,
    doesRelocate: true,
    region: Rect.fromLTRB(0.08, 0.5, 0.92, 0.9),
  ),
  _Emitter(
    motion: _Motion.fall,
    sprites: [_Sprite.glow],
    count: 28,
    minSize: 4.0,
    maxSize: 8.0,
    minSpeed: 16.0,
    maxSpeed: 34.0,
    minAlpha: 0.3,
    maxAlpha: 0.7,
    sway: 9.0,
    minRate: 0.10,
    maxRate: 0.30,
    colors: _kSnowColors,
    colorsLight: _kSnowColorsLight,
    audio: 0.5,
  ),
  _Emitter(
    motion: _Motion.fall,
    sprites: [_Sprite.flake],
    count: 8,
    minSize: 11.0,
    maxSize: 17.0,
    minSpeed: 28.0,
    maxSpeed: 52.0,
    minAlpha: 0.4,
    maxAlpha: 0.8,
    sway: 18.0,
    minRate: 0.08,
    maxRate: 0.22,
    spin: 0.7,
    colors: _kSnowColors,
    colorsLight: _kSnowColorsLight,
    audio: 0.5,
  ),
];

const _kBatColors = [0xC3B1E1, 0xA996D0];
const _kBatColorsLight = [0x2B1B3D, 0x3A2752];
const _kGhostColors = [0xFFFFFF];
const _kGhostColorsLight = [0x7D6B99];
const _kLeafColors = [0xE8731A, 0xC0521B, 0xE0A030, 0x9A5522];
const _kSkullColors = [0xF2EEE3, 0xE3DCCB];
const _kSkullColorsLight = [0x4A4458, 0x5A5470];

const _kBats = _Emitter(
  motion: _Motion.drift,
  sprites: [_Sprite.batUp, _Sprite.batDown],
  isFlapping: true,
  count: 5,
  minSize: 26.0,
  maxSize: 44.0,
  minSpeed: 40.0,
  maxSpeed: 80.0,
  minAlpha: 0.3,
  maxAlpha: 0.6,
  sway: 14.0,
  minRate: 3.0,
  maxRate: 4.6,
  colors: _kBatColors,
  colorsLight: _kBatColorsLight,
  audio: 0.4,
  region: Rect.fromLTRB(0.0, 0.04, 1.0, 0.7),
);

const _kLeaves = _Emitter(
  motion: _Motion.fall,
  sprites: [_Sprite.leaf],
  count: 9,
  minSize: 11.0,
  maxSize: 17.0,
  minSpeed: 26.0,
  maxSpeed: 48.0,
  minAlpha: 0.5,
  maxAlpha: 0.85,
  sway: 26.0,
  minRate: 0.12,
  maxRate: 0.3,
  spin: 1.6,
  colors: _kLeafColors,
  audio: 0.4,
);

const _kPumpkins = _Emitter(
  motion: _Motion.twinkle,
  sprites: [_Sprite.pumpkin],
  count: 3,
  minSize: 38.0,
  maxSize: 56.0,
  minAlpha: 0.5,
  maxAlpha: 0.85,
  minRate: 0.05,
  maxRate: 0.09,
  audio: 0.5,
  doesRelocate: true,
  region: Rect.fromLTRB(0.06, 0.45, 0.94, 0.92),
);

const _kSkulls = _Emitter(
  motion: _Motion.twinkle,
  sprites: [_Sprite.skull],
  count: 2,
  minSize: 30.0,
  maxSize: 44.0,
  minAlpha: 0.08,
  maxAlpha: 0.16,
  minRate: 0.06,
  maxRate: 0.1,
  colors: _kSkullColors,
  colorsLight: _kSkullColorsLight,
  audio: 0.3,
  region: Rect.fromLTRB(0.06, 0.1, 0.94, 0.6),
);

const _kGhosts = _Emitter(
  motion: _Motion.twinkle,
  sprites: [_Sprite.ghost],
  count: 3,
  minSize: 36.0,
  maxSize: 56.0,
  minSpeed: 6.0,
  maxSpeed: 12.0,
  minAlpha: 0.3,
  maxAlpha: 0.5,
  sway: 14.0,
  minRate: 0.07,
  maxRate: 0.11,
  colors: _kGhostColors,
  colorsLight: _kGhostColorsLight,
  doesRelocate: true,
  region: Rect.fromLTRB(0.06, 0.12, 0.94, 0.88),
);

const _kHalloween = [
  _kPumpkins,
  _kSkulls,
  _kGhosts,
  _kLeaves,
  _kBats,
];

const _kHalloweenOverlay = [
  _Emitter(
    motion: _Motion.twinkle,
    sprites: [_Sprite.pumpkin],
    count: 1,
    minSize: 34.0,
    maxSize: 48.0,
    minAlpha: 0.35,
    maxAlpha: 0.6,
    minRate: 0.05,
    maxRate: 0.09,
    audio: 0.5,
    doesRelocate: true,
    region: Rect.fromLTRB(0.06, 0.45, 0.94, 0.92),
  ),
  _Emitter(
    motion: _Motion.twinkle,
    sprites: [_Sprite.skull],
    count: 1,
    minSize: 30.0,
    maxSize: 40.0,
    minAlpha: 0.06,
    maxAlpha: 0.12,
    minRate: 0.06,
    maxRate: 0.1,
    colors: _kSkullColors,
    colorsLight: _kSkullColorsLight,
    audio: 0.3,
    region: Rect.fromLTRB(0.06, 0.1, 0.94, 0.6),
  ),
  _Emitter(
    motion: _Motion.twinkle,
    sprites: [_Sprite.ghost],
    count: 2,
    minSize: 34.0,
    maxSize: 48.0,
    minSpeed: 6.0,
    maxSpeed: 12.0,
    minAlpha: 0.22,
    maxAlpha: 0.38,
    sway: 14.0,
    minRate: 0.07,
    maxRate: 0.11,
    colors: _kGhostColors,
    colorsLight: _kGhostColorsLight,
    doesRelocate: true,
    region: Rect.fromLTRB(0.06, 0.12, 0.94, 0.88),
  ),
  _Emitter(
    motion: _Motion.fall,
    sprites: [_Sprite.leaf],
    count: 7,
    minSize: 11.0,
    maxSize: 16.0,
    minSpeed: 26.0,
    maxSpeed: 48.0,
    minAlpha: 0.4,
    maxAlpha: 0.75,
    sway: 26.0,
    minRate: 0.12,
    maxRate: 0.3,
    spin: 1.6,
    colors: _kLeafColors,
    audio: 0.4,
  ),
  _Emitter(
    motion: _Motion.drift,
    sprites: [_Sprite.batUp, _Sprite.batDown],
    isFlapping: true,
    count: 3,
    minSize: 24.0,
    maxSize: 38.0,
    minSpeed: 40.0,
    maxSpeed: 80.0,
    minAlpha: 0.25,
    maxAlpha: 0.5,
    sway: 14.0,
    minRate: 3.0,
    maxRate: 4.6,
    colors: _kBatColors,
    colorsLight: _kBatColorsLight,
    audio: 0.4,
    region: Rect.fromLTRB(0.0, 0.04, 1.0, 0.7),
  ),
];

const _kStarColors = [0xFFE9A8, 0xFFFFFF, 0xFFD27A];
const _kStarColorsLight = [0xC8962E, 0xB07A1E];

const _kCrescent = _Emitter(
  motion: _Motion.twinkle,
  sprites: [_Sprite.crescent],
  count: 1,
  minSize: 88.0,
  maxSize: 88.0,
  minAlpha: 1.0,
  maxAlpha: 1.0,
  minRate: 0.04,
  maxRate: 0.04,
  region: Rect.fromLTRB(0.80, 0.14, 0.84, 0.17),
);

const _kSmallCrescents = _Emitter(
  motion: _Motion.twinkle,
  sprites: [_Sprite.crescent],
  count: 5,
  minSize: 16.0,
  maxSize: 30.0,
  minAlpha: 0.4,
  maxAlpha: 0.8,
  minRate: 0.08,
  maxRate: 0.2,
  audio: 0.4,
  region: Rect.fromLTRB(0.05, 0.22, 0.95, 0.62),
);

const _kRamadan = [
  _Emitter(
    motion: _Motion.twinkle,
    sprites: [_Sprite.sparkle],
    count: 22,
    minSize: 7.0,
    maxSize: 15.0,
    minAlpha: 0.3,
    maxAlpha: 0.9,
    minRate: 0.15,
    maxRate: 0.5,
    colors: _kStarColors,
    colorsLight: _kStarColorsLight,
    audio: 0.6,
    region: Rect.fromLTRB(0.02, 0.02, 0.98, 0.6),
  ),
  _kCrescent,
  _kSmallCrescents,
  _Emitter(
    motion: _Motion.hang,
    sprites: [_Sprite.lantern, _Sprite.lanternPanelled],
    count: 4,
    minSize: 96.0,
    maxSize: 136.0,
    minAlpha: 0.6,
    maxAlpha: 0.9,
    sway: 0.10,
    minRate: 0.12,
    maxRate: 0.2,
    audio: 0.5,
    region: Rect.fromLTRB(0.05, 0.0, 0.72, 0.2),
  ),
];

const _kRamadanOverlay = [
  _kCrescent,
  _kSmallCrescents,
  _Emitter(
    motion: _Motion.twinkle,
    sprites: [_Sprite.sparkle],
    count: 14,
    minSize: 7.0,
    maxSize: 13.0,
    minAlpha: 0.25,
    maxAlpha: 0.7,
    minRate: 0.15,
    maxRate: 0.5,
    colors: _kStarColors,
    colorsLight: _kStarColorsLight,
    audio: 0.6,
    region: Rect.fromLTRB(0.02, 0.02, 0.98, 0.5),
  ),
  _Emitter(
    motion: _Motion.hang,
    sprites: [_Sprite.lantern, _Sprite.lanternPanelled],
    count: 2,
    minSize: 76.0,
    maxSize: 96.0,
    minAlpha: 0.45,
    maxAlpha: 0.7,
    sway: 0.10,
    minRate: 0.12,
    maxRate: 0.2,
    audio: 0.5,
    region: Rect.fromLTRB(0.06, 0.0, 0.70, 0.16),
  ),
];

class _EffectPreset {
  final List<_Emitter> emitters;
  final _Scenery scenery;

  const _EffectPreset(this.emitters, {this.scenery = _Scenery.none});
}

enum _Scenery {
  none,
  aurora,
  deepWater,
}

enum _Motion {
  fall,
  rise,
  drift,
  wander,
  hang,
  twinkle,
  string,
  burst,
  orbit,
}

class _Emitter {
  final _Motion motion;

  final List<_Sprite> sprites;
  final bool isFlapping;

  /// the first sprite heads right, the second one left.
  final bool isFacing;

  /// turned to point where it is going.
  final bool isAligned;
  final bool doesFlicker;
  final int count;

  /// particles of one [_Motion.burst], [minSpeed] and [maxSpeed] are how far it reaches.
  final int burstSize;

  final double minSize;
  final double maxSize;

  final double minSpeed;
  final double maxSpeed;
  final double minAlpha;
  final double maxAlpha;

  /// radians for [_Motion.hang], logical pixels otherwise.
  final double sway;

  /// turns per second for [_Motion.orbit].
  final double minRate;
  final double maxRate;

  final double spin;

  /// how much of its size it swells and shrinks by.
  final double pulse;

  /// logical pixels per second, sideways.
  final double wind;

  /// how much it moves down for what it moves across.
  final double slope;

  /// seconds it stays away at most before showing up again.
  final double pause;

  /// `0xRRGGBB`, null follows the app color.
  final List<int>? colors;

  final List<int>? colorsLight;

  /// how far its shades go from the app color, 0 to 1.
  final double shades;

  final double audio;

  final bool doesRelocate;

  /// [_Motion.orbit] turns around its middle, as wide as it is. [_Motion.hang] is lowered by anything between its top and bottom.
  final Rect region;

  const _Emitter({
    required this.motion,
    required this.sprites,
    this.isFlapping = false,
    this.isFacing = false,
    this.isAligned = false,
    this.doesFlicker = false,
    required this.count,
    this.burstSize = 1,
    required this.minSize,
    required this.maxSize,
    this.minSpeed = 0.0,
    this.maxSpeed = 0.0,
    required this.minAlpha,
    required this.maxAlpha,
    this.sway = 0.0,
    this.minRate = 0.1,
    this.maxRate = 0.1,
    this.spin = 0.0,
    this.pulse = 0.0,
    this.wind = 0.0,
    this.slope = 0.0,
    this.pause = 0.0,
    this.colors,
    this.colorsLight,
    this.shades = 0.0,
    this.audio = 0.0,
    this.doesRelocate = false,
    this.region = _kWholeField,
  });
}
