// by claude
part of 'equalizer_page.dart';

/// tapping an effect toggles it, dragging across an enabled one sets its intensity.
class _SoundEffectsSection extends StatelessWidget {
  const _SoundEffectsSection();

  static const _kSpacing = 8.0;

  @override
  Widget build(BuildContext context) {
    return _ForcedOffEnabled(
      option: AudioOutputForcedOff.soundEffects,
      child: ObxO(
        rx: settings.equalizer.soundEffects,
        builder: (context, enabledEffects) {
          final enabledNames = enabledEffects.map((e) => e.toText()).joinText(separator: ', ');
          return NamidaExpansionTile(
            icon: Broken.magic_star,
            titleText: lang.soundEffects,
            subtitleText: enabledNames.nullifyEmpty(),
            initiallyExpanded: enabledEffects.isNotEmpty,
            childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 480.0 ? 3 : 2;
                  final itemWidth = (constraints.maxWidth - _kSpacing * (columns - 1)) / columns;
                  return ObxO(
                    rx: settings.equalizer.soundEffectIntensities,
                    builder: (context, intensities) => Wrap(
                      spacing: _kSpacing,
                      runSpacing: _kSpacing,
                      children: SoundEffectType.values
                          .map(
                            (type) => _SoundEffectCard(
                              type: type,
                              width: itemWidth,
                              isEnabled: enabledEffects.contains(type),
                              intensity: intensities[type] ?? type.defaultIntensity,
                            ),
                          )
                          .toFixedList(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// the filled part of the card is the intensity, like a slider.
class _SoundEffectCard extends StatelessWidget {
  final SoundEffectType type;
  final double width;
  final bool isEnabled;
  final double intensity;

  const _SoundEffectCard({
    required this.type,
    required this.width,
    required this.isEnabled,
    required this.intensity,
  });

  void _onDrag(Offset localPosition, bool isRtl) {
    final fraction = (localPosition.dx / width).withMinimum(0.0).withMaximum(1.0);
    final directionalFraction = isRtl ? 1.0 - fraction : fraction;
    final newIntensity = (directionalFraction * 100).roundToDouble() / 100;
    if (newIntensity == intensity) return;
    AudioOutputController.inst.setSoundEffectIntensity(type, newIntensity);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final color = theme.colorScheme.secondaryContainer;
    final fill = isEnabled ? intensity : 0.0;
    final fillColor = color.withOpacityExt(0.5);
    final baseColor = color.withOpacityExt(isEnabled ? 0.2 : 0.08);
    final percentage = (intensity * 100).round();
    return GestureDetector(
      onHorizontalDragStart: isEnabled ? (details) => _onDrag(details.localPosition, isRtl) : null,
      onHorizontalDragUpdate: isEnabled ? (details) => _onDrag(details.localPosition, isRtl) : null,
      child: NamidaInkWell(
        width: width,
        animationDurationMS: 120,
        borderRadius: 12.0,
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            stops: [fill, fill],
            colors: [fillColor, baseColor],
          ),
        ),
        onTap: () => AudioOutputController.inst.setSoundEffectEnabled(type, !isEnabled),
        child: Row(
          children: [
            Icon(
              type.toIcon(),
              size: 18.0,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                type.toText(),
                style: textTheme.displayMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isEnabled) ...[
              const SizedBox(width: 4.0),
              Text(
                '$percentage%',
                style: textTheme.displaySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
