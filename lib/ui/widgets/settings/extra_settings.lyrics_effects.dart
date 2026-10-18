// by claude
part of 'extra_settings.dart';

class _LyricsEffectsTile extends StatelessWidget {
  const _LyricsEffectsTile();

  void _openDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.message_text,
        title: lang.lyrics,
        normalTitleStyle: true,
        horizontalInset: 32.0,
        actions: const [
          DoneButton(),
        ],
        child: const _LyricsEffectsOptions(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      icon: Broken.message_text,
      title: 'lyrics_animations'.toUpperCase(),
      onTap: _openDialog,
    );
  }
}

class _LyricsEffectsOptions extends StatelessWidget {
  const _LyricsEffectsOptions();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.width,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: context.height * 0.6),
        child: NamidaScrollbarWithController(
          child: (c) => SuperSmoothListView(
            controller: c,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: _LyricsEffectsView.values
                .map(
                  (e) => _LyricsEffectsViewTile(
                    view: e,
                  ),
                )
                .toFixedList(),
          ),
        ),
      ),
    );
  }
}

class _LyricsEffectsViewTile extends StatelessWidget {
  final _LyricsEffectsView view;

  const _LyricsEffectsViewTile({
    required this.view,
  });

  @override
  Widget build(BuildContext context) {
    final key = switch (view) {
      _LyricsEffectsView.simpleLine => settings.lyricsEffectsLine,
      _LyricsEffectsView.normal => settings.lyricsEffectsNormal,
      _LyricsEffectsView.expanded => settings.lyricsEffectsExpanded,
    };
    final available = view.isListView ? LyricsEffect.values : LyricsEffect.karaokeEffects;
    final defaults = key.fallback;
    return ObxO(
      rx: key,
      builder: (context, enabled) {
        final current = LyricsEffects.of(enabled);
        final currentPreset = _LyricsEffectsPreset.values.firstWhereEff((e) => LyricsEffects.of(e.resolve(available, defaults)) == current);

        void onPresetTap(_LyricsEffectsPreset preset) {
          if (preset == _LyricsEffectsPreset.defaults) return key.reset();
          final presetEffects = preset.resolve(available, defaults);
          key.replace(presetEffects);
        }

        void onEffectTap(LyricsEffect effect) {
          final willEnable = !current.contains(effect);
          final newEffects = available.where((e) => e == effect ? willEnable : current.contains(e)).toFixedList();
          key.replace(newEffects);
        }

        return NamidaExpansionTile(
          icon: view.toIcon(),
          titleText: view.toText(),
          subtitleText: currentPreset?.toText() ?? 'Custom',
          childrenPadding: const EdgeInsetsDirectional.only(end: 12.0, bottom: 8.0),
          children: [
            _LyricsEffectsCardsGrid(
              perRow: _LyricsEffectsPreset.values.length,
              children: _LyricsEffectsPreset.values
                  .map(
                    (e) => _LyricsEffectCard(
                      icon: e.toIcon(),
                      title: e.toText(),
                      active: e == currentPreset,
                      onTap: () => onPresetTap(e),
                    ),
                  )
                  .toFixedList(),
            ),
            const NamidaContainerDivider(
              margin: EdgeInsets.symmetric(vertical: 8.0),
            ),
            _LyricsEffectsCardsGrid(
              perRow: 3,
              children: available
                  .map(
                    (e) => _LyricsEffectCard(
                      icon: e.toIcon(),
                      title: e.toText(),
                      active: current.contains(e),
                      onTap: () => onEffectTap(e),
                    ),
                  )
                  .toFixedList(),
            ),
          ],
        );
      },
    );
  }
}

class _LyricsEffectsCardsGrid extends StatelessWidget {
  final int perRow;
  final List<Widget> children;

  const _LyricsEffectsCardsGrid({
    required this.perRow,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(
      width: 4.0,
      height: 4.0,
    );
    final rows = <Widget>[];
    for (int start = 0; start < children.length; start += perRow) {
      final cells = List<Widget>.generate(
        perRow,
        (i) {
          final index = start + i;
          return Expanded(
            child: index < children.length ? children[index] : const SizedBox(),
          );
        },
      );
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells.addSeparators(separator: gap).toFixedList(),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.addSeparators(separator: gap).toFixedList(),
    );
  }
}

class _LyricsEffectCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _LyricsEffectCard({
    required this.icon,
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tileOpacity = context.isDarkMode ? 0.02 : 0.08;
    final inactiveColor = NColors.custom((c) => Color.alphaBlend(c.onSurface.withOpacityExt(tileOpacity), c.cardTheme));
    final bgColor = active ? NColors.secondaryContainer : inactiveColor;
    return NamidaInkWell(
      borderRadius: 10.0,
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 10.0),
      animationDurationMS: 200,
      bgColor: bgColor,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20.0,
          ),
          const SizedBox(
            height: 4.0,
          ),
          NamidaText(
            title,
            style: const NText(.small, size: .s12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

enum _LyricsEffectsView {
  simpleLine(isListView: false),
  normal(isListView: true),
  expanded(isListView: true),
  ;

  final bool isListView;
  const _LyricsEffectsView({required this.isListView});

  String toText() => switch (this) {
    _LyricsEffectsView.simpleLine => 'Simple line',
    _LyricsEffectsView.normal => 'Normal view',
    _LyricsEffectsView.expanded => 'Expanded view',
  };

  IconData toIcon() => switch (this) {
    _LyricsEffectsView.simpleLine => Broken.text_block,
    _LyricsEffectsView.normal => Broken.message_text,
    _LyricsEffectsView.expanded => Broken.maximize_4,
  };
}

enum _LyricsEffectsPreset {
  off,
  calm,
  defaults,
  full,
  ;

  static const _calmEffects = {LyricsEffect.interludeDots, LyricsEffect.accentTint, LyricsEffect.feather};

  List<LyricsEffect> resolve(List<LyricsEffect> available, List<LyricsEffect> defaults) => switch (this) {
    _LyricsEffectsPreset.off => const [],
    _LyricsEffectsPreset.calm => available.where(_calmEffects.contains).toFixedList(),
    _LyricsEffectsPreset.defaults => defaults,
    _LyricsEffectsPreset.full => available,
  };

  String toText() => switch (this) {
    _LyricsEffectsPreset.off => 'Off',
    _LyricsEffectsPreset.calm => 'Calm',
    _LyricsEffectsPreset.defaults => 'Default',
    _LyricsEffectsPreset.full => 'Full',
  };

  IconData toIcon() => switch (this) {
    _LyricsEffectsPreset.off => Broken.slash,
    _LyricsEffectsPreset.calm => Broken.coffee,
    _LyricsEffectsPreset.defaults => Broken.refresh_2,
    _LyricsEffectsPreset.full => Broken.magic_star,
  };
}

extension _LyricsEffectUtils on LyricsEffect {
  String toText() => switch (this) {
    LyricsEffect.focalScale => 'Focal scale',
    LyricsEffect.depthBlur => 'Depth blur',
    LyricsEffect.springPop => 'Spring pop',
    LyricsEffect.interludeDots => 'Interlude dots',
    LyricsEffect.seekGlide => 'Seek glide',
    LyricsEffect.lineReveal => 'Line reveal',
    LyricsEffect.accentTint => 'Accent tint',
    LyricsEffect.glow => 'Glow',
    LyricsEffect.wordBump => 'Word bump',
    LyricsEffect.shimmer => 'Shimmer',
    LyricsEffect.feather => 'Soft edge',
    LyricsEffect.untimedLineSweep => 'Full line sweep',
  };

  IconData toIcon() => switch (this) {
    LyricsEffect.focalScale => Broken.size,
    LyricsEffect.depthBlur => Broken.blur,
    LyricsEffect.springPop => Broken.flash_1,
    LyricsEffect.interludeDots => Broken.more,
    LyricsEffect.seekGlide => Broken.scroll,
    LyricsEffect.lineReveal => Broken.eye,
    LyricsEffect.accentTint => Broken.colorfilter,
    LyricsEffect.glow => Broken.lamp_on,
    LyricsEffect.wordBump => Broken.text,
    LyricsEffect.shimmer => Broken.magic_star,
    LyricsEffect.feather => Broken.blend,
    LyricsEffect.untimedLineSweep => Broken.textalign_justifyleft,
  };
}
