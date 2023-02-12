import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.child, required this.title, required this.subtitle, this.icon, this.trailing});
  final Widget child;
  final Widget? trailing;
  final String title;
  final String subtitle;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: context.theme.cardColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20.0.multipliedRadius),
        boxShadow: [
          BoxShadow(color: context.theme.shadowColor.withAlpha(100), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
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
                  const SizedBox(
                    width: 16.0,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Get.textTheme.displayLarge?.copyWith(fontSize: 18.0),
                        ),
                        Text(subtitle, style: Get.textTheme.displaySmall),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              )),
          Container(padding: const EdgeInsets.all(4.0), child: child),
        ],
      ),
    );
  }
}
