// by claude
part of 'sound_control_page.dart';

class _ConfigPresetsRow extends StatelessWidget {
  final _SoundControlMainSlidersColumnUpdateConfig config;
  final Future<void> Function(PlayerConfig config) onApply;

  const _ConfigPresetsRow({
    required this.config,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final presets = settings.equalizer.configPresets.valueR;
        if (presets.isEmpty) return const SizedBox();
        final current = config.getCurrentConfigR();
        final activePreset = presets.firstWhereEff((p) => p.config == current);
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: SmoothSingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10.0).add(const EdgeInsets.only(bottom: 8.0)),
            child: Row(
              children: presets
                  .map(
                    (preset) => _ConfigPresetChip(
                      preset: preset,
                      isActive: preset == activePreset,
                      config: config,
                      onTap: onApply,
                    ),
                  )
                  .toFixedList(),
            ),
          ),
        );
      },
    );
  }
}

class _ConfigPresetChip extends StatelessWidget {
  final PlayerConfigPreset preset;
  final bool isActive;
  final _SoundControlMainSlidersColumnUpdateConfig config;
  final Future<void> Function(PlayerConfig config) onTap;

  const _ConfigPresetChip({
    required this.preset,
    required this.isActive,
    required this.config,
    required this.onTap,
  });

  List<NamidaPopupItem> _getMenuItems() {
    final current = config.getCurrentConfig();
    final duplicate = settings.equalizer.findConfigPresetDuplicate(current, exceptName: preset.name);
    final duplicateText = duplicate == null ? '' : '${lang.alreadyExists}: ${duplicate.name}';
    return [
      NamidaPopupItem(
        icon: Broken.document_download,
        title: lang.save,
        subtitle: duplicateText,
        enabled: duplicate == null,
        onTap: () {
          final updated = preset.copyWith(config: current);
          settings.equalizer.putConfigPreset(updated);
        },
      ),
      NamidaPopupItem(
        icon: Broken.edit_2,
        title: lang.rename,
        onTap: () => _PresetNameSheet.show(
          initialName: preset.name,
          onName: (name) {
            final renamed = preset.copyWith(name: name);
            settings.equalizer.putConfigPreset(renamed, replacing: preset.name);
          },
        ),
      ),
      NamidaPopupItem(
        icon: Broken.trash,
        title: lang.delete,
        onTap: () => settings.equalizer.removeConfigPreset(preset.name),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final secondaryColor = theme.colorScheme.secondary;
    final itemsColor = secondaryColor.withOpacityExt(isActive ? 0.9 : 0.6);
    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: _getMenuItems,
      child: NamidaInkWell(
        animationDurationMS: 200,
        bgColor: secondaryColor.withOpacityExt(isActive ? 0.18 : 0.0),
        borderRadius: 8.0,
        onTap: () => onTap(preset.config),
        margin: const EdgeInsets.symmetric(horizontal: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          border: Border.all(
            color: secondaryColor.withOpacityExt(isActive ? 0.7 : 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Broken.layer,
              size: 14.0,
              color: itemsColor,
            ),
            const SizedBox(width: 6.0),
            Text(
              preset.name,
              style: theme.textTheme.displayMedium?.copyWith(color: itemsColor),
            ),
            AnimatedShow(
              isHorizontal: true,
              show: isActive,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8.0),
                child: NamidaCheckMark(
                  size: 14.0,
                  active: isActive,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class _ConfigPresetSaveSheet {
  static void show({required PlayerConfig config, required String? initialName}) {
    showNamidaBottomSheetWithTextField(
      title: lang.saveAsPreset,
      textfieldConfig: BottomSheetTextFieldConfig(
        initalControllerText: initialName,
        hintText: lang.name,
        labelText: lang.name,
        validator: (text) {
          final name = text?.trim();
          if (name == null || name.isEmpty) return lang.emptyValue;
          final duplicate = settings.equalizer.findConfigPresetDuplicate(config, exceptName: name);
          if (duplicate != null) return '${lang.alreadyExists}: ${duplicate.name}';
          return null;
        },
      ),
      buttonText: lang.save,
      onButtonTap: (text) {
        final name = text.trim();
        final preset = PlayerConfigPreset(name: name, config: config);
        settings.equalizer.putConfigPreset(preset);
        return true;
      },
    );
  }
}

class _ConfigPresetSaveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ConfigPresetSaveButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaIconButton(
      horizontalPadding: 8.0,
      tooltip: () => lang.saveAsPreset,
      icon: Broken.save_add,
      iconSize: 20.0,
      iconColor: context.defaultIconColor(),
      onPressed: onTap,
    );
  }
}

extension _ConfigPresetValues on _SoundControlMainSlidersColumnUpdateConfig {
  PlayerConfig getCurrentConfig() => PlayerConfig(
    skipSilence: skipSilenceEnabledRx.value,
    loudnessEnhancerEnabled: loudnessEnhancerEnabledRx.value,
    loudnessEnhancer: loudnessEnhancerRx.value,
    equalizerEnabled: equalizerEnabledRx.value,
    equalizer: equalizerRx.value,
    preset: presetRx.value,
    speed: speedRx.value,
    volume: volumeRx.value,
    pitch: pitchRx.value,
  );

  PlayerConfig getCurrentConfigR() => PlayerConfig(
    skipSilence: skipSilenceEnabledRx.valueR,
    loudnessEnhancerEnabled: loudnessEnhancerEnabledRx.valueR,
    loudnessEnhancer: loudnessEnhancerRx.valueR,
    equalizerEnabled: equalizerEnabledRx.valueR,
    equalizer: equalizerRx.valueR,
    preset: presetRx.valueR,
    speed: speedRx.valueR,
    volume: volumeRx.valueR,
    pitch: pitchRx.valueR,
  );
}
