import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/core/extensions.dart';

class SettingsCard extends StatelessWidget {
  final Widget child;
  final Widget? childRaw;
  final Widget? trailing;
  final String title;
  final String? subtitle;
  final IconData? icon;

  const SettingsCard({
    super.key,
    required this.child,
    this.childRaw,
    required this.title,
    required this.subtitle,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: context.theme.cardColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20.0.multipliedRadius),
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor.withAlpha(60),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            width: double.infinity,
            // margin: const EdgeInsets.all(12.0),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: context.theme.cardColor.withOpacity(0.6),
              // borderRadius: BorderRadius.circular(20.0.multipliedRadius),
            ),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.textTheme.displayLarge?.copyWith(fontSize: 18.0.multipliedFontScale),
                      ),
                      if (subtitle != null) Text(subtitle!, style: context.textTheme.displaySmall),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          childRaw ??
              Container(
                padding: const EdgeInsets.all(4.0),
                child: child,
              ),
        ],
      ),
    );
  }
}
