import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';

class SmallYTActionButton extends StatelessWidget {
  final String? title;
  final IconData icon;
  final void Function()? onPressed;
  final Widget? iconWidget;
  final Widget? titleWidget;

  const SmallYTActionButton({
    super.key,
    required this.title,
    required this.icon,
    this.onPressed,
    this.iconWidget,
    this.titleWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        iconWidget ??
            NamidaInkWell(
              borderRadius: 32.0,
              onTap: onPressed,
              padding: const EdgeInsets.all(6.0),
              child: Icon(icon),
            ),
        NamidaBasicShimmer(
          width: 24.0,
          height: 8.0,
          borderRadius: 4.0,
          fadeDurationMS: titleWidget == null ? 600 : 100,
          shimmerEnabled: title == null,
          child: titleWidget ??
              Text(
                title ?? '',
                style: context.textTheme.displaySmall,
              ),
        ),
      ],
    );
  }
}
