// by claude
import 'package:flutter/material.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';

/// marks a greyed out option with what turned it off.
class DisabledByPill extends StatelessWidget {
  final IconData icon;
  final String title;

  const DisabledByPill({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textStyle = theme.textTheme.displaySmall?.copyWith(fontSize: 11.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacityExt(0.12),
        borderRadius: BorderRadius.circular(6.0.multipliedRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Broken.slash,
            size: 11.0,
          ),
          const SizedBox(width: 3.0),
          Icon(
            icon,
            size: 11.0,
          ),
          const SizedBox(width: 3.0),
          Flexible(
            child: Text(
              title,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
