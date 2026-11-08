import 'package:flutter/material.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

/// `-` / percent / `+` in steps of 5%, tapping the percent resets.
class FontScaleStepper extends StatelessWidget {
  /// read inside an [Obx], so use `valueR`.
  final double Function() readScaleR;
  final void Function(double scale) onChanged;
  final VoidCallback onReset;
  final double minScale;
  final double maxScale;

  const FontScaleStepper({
    super.key,
    required this.readScaleR,
    required this.onChanged,
    required this.onReset,
    required this.minScale,
    required this.maxScale,
  });

  static const _kStepPercent = 5;

  void _saveNextStep(int percent) {
    final nextPercent = (percent ~/ _kStepPercent + 1) * _kStepPercent;
    _savePercent(nextPercent);
  }

  void _savePreviousStep(int percent) {
    final previousPercent = ((percent + _kStepPercent - 1) ~/ _kStepPercent - 1) * _kStepPercent;
    _savePercent(previousPercent);
  }

  void _savePercent(int percent) {
    final scale = percent / 100;
    final clampedScale = scale.clampDouble(minScale, maxScale);
    onChanged(clampedScale);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final scale = readScaleR();
        final percent = (scale * 100).round();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NamidaIconButton(
              horizontalPadding: 5.0,
              verticalPadding: 5.0,
              icon: Broken.minus_cirlce,
              iconSize: 20.0,
              onPressed: () => _savePreviousStep(percent),
            ),
            NamidaInkWell(
              width: 44.0,
              borderRadius: 6.0,
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              onTap: onReset,
              child: NamidaText(
                '$percent%',
                style: NText.medium,
                textAlign: TextAlign.center,
              ),
            ),
            NamidaIconButton(
              horizontalPadding: 5.0,
              verticalPadding: 5.0,
              icon: Broken.add_circle,
              iconSize: 20.0,
              onPressed: () => _saveNextStep(percent),
            ),
          ],
        );
      },
    );
  }
}
