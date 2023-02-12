import 'package:checkmark/checkmark.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';

class ReverseOrderContainer extends StatelessWidget {
  final bool active;
  final void Function()? onTap;
  const ReverseOrderContainer({super.key, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0.multipliedRadius)),
      tileColor: Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(10), context.theme.cardTheme.color!),
      // tileColor: context.theme.cardTheme.color?.withAlpha(120),
      leading: const Icon(Broken.arrange_circle),
      title: Text(Language.inst.REVERSE_ORDER),
      trailing: SizedBox(
        height: 18.0,
        width: 18.0,
        child: CheckMark(
          // curve: Curves.easeInOutExpo,
          strokeWidth: 2,
          activeColor: context.theme.listTileTheme.iconColor!,
          inactiveColor: context.theme.listTileTheme.iconColor!,
          duration: const Duration(milliseconds: 400),
          active: active,
        ),
      ),
      visualDensity: VisualDensity.compact,
      onTap: onTap,
    );
  }
}

class ListTileWithCheckMark extends StatelessWidget {
  final bool active;
  final void Function()? onTap;
  final String title;
  final IconData? icon;
  const ListTileWithCheckMark({super.key, required this.active, this.onTap, required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0.multipliedRadius)),
      tileColor: Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(10), context.theme.cardTheme.color!),
      // tileColor: context.theme.cardTheme.color?.withAlpha(120),
      leading: Icon(icon ?? Broken.arrange_circle),
      title: Text(title),
      trailing: SizedBox(
        height: 18.0,
        width: 18.0,
        child: CheckMark(
          // curve: Curves.easeInOutExpo,
          strokeWidth: 2,
          activeColor: context.theme.listTileTheme.iconColor!,
          inactiveColor: context.theme.listTileTheme.iconColor!,
          duration: const Duration(milliseconds: 400),
          active: active,
        ),
      ),
      visualDensity: VisualDensity.compact,
      onTap: onTap,
    );
  }
}
