import 'dart:async';

import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/items_cache.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

Future<void> showClearCacheDialog({List<Selectable> tracks = const [], List<String> videoIds = const [], Color? colorScheme}) async {
  final cache = await ItemsCache.collect(tracks: tracks.map((e) => e.track), videoIds: videoIds);
  final controller = _ClearCacheDialogController(cache);

  NamidaNavigator.inst.navigateDialog(
    colorScheme: colorScheme,
    onDisposing: controller.dispose,
    dialogBuilder: (theme) => CustomBlurryDialog(
      theme: theme,
      normalTitleStyle: true,
      icon: Broken.broom,
      title: lang.clear,
      trailingWidgets: [
        ObxO(
          rx: controller.isCleanRx,
          builder: (context, isClean) => isClean
              ? const SizedBox()
              : Obx(
                  (context) => NamidaIconButton(
                    icon: null,
                    onPressed: controller.toggleAll,
                    child: NamidaCheckMark(
                      size: 18.0,
                      active: controller.isAllSelectedR,
                    ),
                  ),
                ),
        ),
      ],
      actions: [
        ObxO(
          rx: controller.isCleanRx,
          builder: (context, isClean) => isClean
              ? const DoneButton()
              : _ClearCacheActions(
                  controller: controller,
                ),
        ),
      ],
      child: ObxO(
        rx: controller.isCleanRx,
        builder: (context, isClean) => isClean
            ? _ClearCacheCleanState(
                showText: controller.isNothingFound,
              )
            : _ClearCacheGroupsList(
                controller: controller,
              ),
      ),
    ),
  );
  controller.collectTempFiles();
}

class _ClearCacheDialogController {
  final ItemsCache cache;

  _ClearCacheDialogController(this.cache);

  late final groupsRx = cache.groups.obso;
  final selectedRx = <ItemCacheEntry>{}.obs;
  late final isCleanRx = isNothingFound.obso;

  bool get isNothingFound => cache.entries.isEmpty;
  bool get isAllSelectedR => selectedRx.valueR.length == cache.entries.length;

  bool _isDisposed = false;

  void collectTempFiles() async {
    final wasNothingFound = isNothingFound;
    final didAdd = await cache.collectTempFiles();
    if (!didAdd || _isDisposed) return;
    groupsRx.value = cache.groups;
    selectedRx.refresh();
    if (wasNothingFound) isCleanRx.value = false;
  }

  void toggle(ItemCacheEntry entry) {
    final selected = selectedRx.value;
    if (!selected.remove(entry)) selected.add(entry);
    selectedRx.refresh();
  }

  void toggleAll() {
    final selected = selectedRx.value;
    final allEntries = cache.entries;
    if (selected.length == allEntries.length) {
      selected.clear();
    } else {
      selected.addAll(allEntries);
    }
    selectedRx.refresh();
  }

  static const _kCleanStateCloseDelay = Duration(milliseconds: 300);
  Timer? _cleanStateCloseTimer;

  /// when nothing is left, the clean state shows shortly before closing.
  Future<void> deleteSelected() async {
    final selected = selectedRx.value;
    final isAllSelected = selected.length == cache.entries.length;
    await cache.deleteEntries(selected);
    if (isAllSelected) {
      isCleanRx.value = true;
      _cleanStateCloseTimer = Timer(_kCleanStateCloseDelay, NamidaNavigator.inst.closeDialog);
    } else {
      NamidaNavigator.inst.closeDialog();
    }
  }

  void dispose() {
    _isDisposed = true;
    _cleanStateCloseTimer?.cancel();
    groupsRx.close();
    selectedRx.close();
    isCleanRx.close();
  }
}

class _ClearCacheActions extends StatelessWidget {
  final _ClearCacheDialogController controller;

  const _ClearCacheActions({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CancelButton(),
        const SizedBox(width: 6.0),
        Obx(
          (context) {
            final selectedEntries = controller.selectedRx.valueR;
            final totalSize = selectedEntries.fold(0, (p, e) => p + e.size);
            return NamidaButton(
              enabled: selectedEntries.isNotEmpty,
              text: "${lang.delete} (${totalSize.fileSizeFormatted})",
              onTap: controller.deleteSelected,
            );
          },
        ),
      ],
    );
  }
}

class _ClearCacheGroupsList extends StatelessWidget {
  final _ClearCacheDialogController controller;

  const _ClearCacheGroupsList({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: namida.height * 0.6),
      child: SmoothSingleChildScrollView(
        child: ObxO(
          rx: controller.groupsRx,
          builder: (context, groups) => Column(
            children: groups
                .map(
                  (group) => _ClearCacheGroupTile(
                    key: ValueKey(group.type),
                    group: group,
                    controller: controller,
                  ),
                )
                .addSeparators(separator: const SizedBox(height: 4.0))
                .toFixedList(),
          ),
        ),
      ),
    );
  }
}

class _ClearCacheCleanState extends StatefulWidget {
  final bool showText;

  const _ClearCacheCleanState({
    required this.showText,
  });

  @override
  State<_ClearCacheCleanState> createState() => _ClearCacheCleanStateState();
}

class _ClearCacheCleanStateState extends State<_ClearCacheCleanState> with SingleTickerProviderStateMixin {
  static const _kIconSize = 56.0;
  static const _kWindUpTurns = 0.025;
  static const _kSwipeTurns = -0.055;
  static const _kWindUpOffset = -2.0;
  static const _kSwipeOffset = 6.0;
  static const _kHandlePivot = Alignment(-0.55, -0.8);
  static const _kFirstDustStart = 0.26;
  static const _kSecondDustStart = 0.66;

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final _turns = _strokesSequence(windUp: _kWindUpTurns, swipe: _kSwipeTurns).animate(_controller);
  late final _offsetX = _strokesSequence(windUp: _kWindUpOffset, swipe: _kSwipeOffset).animate(_controller);

  /// two strokes, each a slow wind up then a fast swipe to the right.
  static TweenSequence<double> _strokesSequence({required double windUp, required double swipe}) {
    return TweenSequence<double>([
      _strokeItem(0.0, windUp, Curves.easeOut, 1.0),
      _strokeItem(windUp, swipe, Curves.easeOutCubic, 1.2),
      _strokeItem(swipe, windUp, Curves.easeInOut, 1.3),
      _strokeItem(windUp, swipe, Curves.easeOutCubic, 1.2),
      _strokeItem(swipe, 0.0, Curves.easeOut, 1.5),
    ]);
  }

  static TweenSequenceItem<double> _strokeItem(double begin, double end, Curve curve, double weight) {
    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    return TweenSequenceItem(tween: tween, weight: weight);
  }

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = IconTheme.of(context).color ?? context.theme.colorScheme.onSurface;
    const icon = Icon(
      Broken.broom,
      size: _kIconSize,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: _kIconSize,
            child: AnimatedBuilder(
              animation: _controller,
              child: icon,
              builder: (context, child) {
                final progress = _controller.value;
                return CustomPaint(
                  foregroundPainter: _SweepDustPainter(
                    firstBurst: _SweepDustPainter.burstProgressOf(progress, _kFirstDustStart),
                    secondBurst: _SweepDustPainter.burstProgressOf(progress, _kSecondDustStart),
                    color: iconColor,
                  ),
                  child: Transform.translate(
                    offset: Offset(_offsetX.value, 0.0),
                    child: RotationTransition(
                      turns: _turns,
                      alignment: _kHandlePivot,
                      child: child,
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.showText) ...[
            const SizedBox(height: 16.0),
            NamidaText(
              lang.nothingIsCached,
              style: NText.medium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// by claude
class _SweepDustPainter extends CustomPainter {
  final double firstBurst;
  final double secondBurst;
  final Color color;

  const _SweepDustPainter({
    required this.firstBurst,
    required this.secondBurst,
    required this.color,
  });

  static const _kBurstLength = 0.3;
  static const _kMaxOpacity = 0.5;
  static const _kParticles = [
    (directionRadians: -0.15, distanceFactor: 0.5, radiusFactor: 0.035),
    (directionRadians: -0.55, distanceFactor: 0.38, radiusFactor: 0.028),
    (directionRadians: -0.95, distanceFactor: 0.26, radiusFactor: 0.022),
  ];

  static double burstProgressOf(double progress, double start) {
    final burstProgress = (progress - start) / _kBurstLength;
    return burstProgress.withMinimum(0.0).withMaximum(1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.95, size.height * 0.75);
    _paintBurst(canvas, size, origin, firstBurst);
    _paintBurst(canvas, size, origin, secondBurst);
  }

  void _paintBurst(Canvas canvas, Size size, Offset origin, double burstProgress) {
    if (burstProgress <= 0.0 || burstProgress >= 1.0) return;
    final travel = Curves.easeOutCubic.transform(burstProgress);
    final opacity = _kMaxOpacity * (1.0 - burstProgress);
    final paint = Paint()..color = color.withOpacityExt(opacity);
    final dimension = size.width;
    for (final particle in _kParticles) {
      final distance = particle.distanceFactor * dimension * travel;
      final offset = Offset.fromDirection(particle.directionRadians, distance);
      canvas.drawCircle(origin + offset, particle.radiusFactor * dimension, paint);
    }
  }

  @override
  bool shouldRepaint(_SweepDustPainter oldDelegate) {
    return firstBurst != oldDelegate.firstBurst || secondBurst != oldDelegate.secondBurst || color != oldDelegate.color;
  }
}

class _ClearCacheGroupTile extends StatelessWidget {
  final ItemCacheGroup group;
  final _ClearCacheDialogController controller;

  const _ClearCacheGroupTile({
    super.key,
    required this.group,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final type = group.type;
    return NamidaExpansionTile(
      initiallyExpanded: true,
      titleText: type.toText(),
      subtitleText: group.totalSize.fileSizeFormatted,
      icon: type.toIcon(),
      trailingBuilder: (iconWidget) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NDecoratedBox(
            decoration: (colors) => BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(6.0.multipliedRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
              child: Text("${group.totalMergedCount}"),
            ),
          ),
          const SizedBox(width: 6.0),
          iconWidget,
        ],
      ),
      childrenPadding: const EdgeInsetsDirectional.only(end: 8.0, top: 6.0),
      children: group.entries
          .map(
            (entry) => _ClearCacheEntryTile(
              entry: entry,
              controller: controller,
            ),
          )
          .toFixedList(),
    );
  }
}

class _ClearCacheEntryTile extends StatelessWidget {
  final ItemCacheEntry entry;
  final _ClearCacheDialogController controller;

  const _ClearCacheEntryTile({
    required this.entry,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final nColors = NColorsData.of(context);
    final mergedCount = entry.mergedCount;
    final title = mergedCount > 1 ? "${entry.title} ($mergedCount)" : entry.title;
    return Material(
      type: MaterialType.transparency,
      child: SmallListTile(
        borderRadius: 12.0,
        icon: entry.isTemp ? Broken.broom : Broken.arrow_right_3,
        iconSize: 20.0,
        color: nColors.card,
        visualDensity: const VisualDensity(horizontal: -3.0, vertical: -3.0),
        dense: true,
        title: title,
        subtitle: entry.size.fileSizeFormatted,
        active: false,
        onTap: () => controller.toggle(entry),
        trailing: Obx(
          (context) => NamidaCheckMark(
            size: 16.0,
            active: controller.selectedRx.valueR.contains(entry),
          ),
        ),
      ),
    );
  }
}

extension _ItemCacheTypeUtils on ItemCacheType {
  String toText() => switch (this) {
    ItemCacheType.video => lang.videoCache,
    ItemCacheType.audio => lang.audioCache,
    ItemCacheType.server => lang.serverCache,
    ItemCacheType.artwork => lang.artworks,
    ItemCacheType.lyrics => lang.lyrics,
    ItemCacheType.subtitles => lang.subtitles,
    ItemCacheType.waveform => lang.waveform,
  };

  IconData toIcon() => switch (this) {
    ItemCacheType.video => Broken.video,
    ItemCacheType.audio => Broken.musicnote,
    ItemCacheType.server => Broken.cloud,
    ItemCacheType.artwork => Broken.image,
    ItemCacheType.lyrics => Broken.document,
    ItemCacheType.subtitles => Broken.subtitle,
    ItemCacheType.waveform => Broken.sound,
  };
}
