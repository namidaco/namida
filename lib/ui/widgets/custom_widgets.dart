import 'dart:ui';

import 'package:checkmark/checkmark.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_switch/flutter_switch.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/setting_dialog.dart';

class CustomSwitchListTile extends StatelessWidget {
  final bool value;
  final void Function(bool) onChanged;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? icon;
  final Color? passedColor;
  final int? rotateIcon;
  const CustomSwitchListTile({Key? key, required this.value, required this.onChanged, required this.title, this.subtitle, this.leading, this.icon, this.passedColor, this.rotateIcon}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        splashColor: Colors.transparent,
        highlightColor: Colors.white.withAlpha(10),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onTap: () {
          onChanged(value);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        horizontalTitleGap: 0.0,
        minVerticalPadding: 8.0,
        leading: icon != null
            ? SizedBox(
                height: double.infinity,
                child: rotateIcon != null
                    ? RotatedBox(
                        quarterTurns: rotateIcon!,
                        child: Icon(
                          icon,
                          color: passedColor ?? Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(100), context.theme.colorScheme.onBackground),
                        ),
                      )
                    : Icon(
                        icon,
                        color: passedColor ?? Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(100), context.theme.colorScheme.onBackground),
                      ),
              )
            : leading,
        title: Text(
          title,
          style: context.theme.textTheme.displayMedium,
          maxLines: subtitle != null ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: context.theme.textTheme.displaySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: IgnorePointer(
          child: FittedBox(
            child: Row(
              children: [
                const SizedBox(
                  width: 12.0,
                ),
                AnimatedContainer(
                  decoration: BoxDecoration(
                    color: passedColor ?? Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(180), context.theme.colorScheme.background),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: value
                        ? [
                            BoxShadow(
                              offset: const Offset(0, 2),
                              blurRadius: 8,
                              spreadRadius: 0,
                              color: passedColor ?? Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(180), context.theme.colorScheme.background),
                            ),
                          ]
                        : null,
                  ),
                  duration: const Duration(milliseconds: 400),
                  child: FlutterSwitch(
                    activeColor: Colors.transparent,
                    toggleColor: const Color.fromARGB(222, 255, 255, 255),
                    inactiveColor: context.theme.disabledColor,
                    duration: const Duration(milliseconds: 400),
                    borderRadius: 30.0,
                    padding: 4.0,
                    width: 40,
                    height: 21,
                    toggleSize: 14,
                    value: value,
                    onToggle: (value) {
                      onChanged(value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomListTile extends StatelessWidget {
  final void Function()? onTap;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;
  final Widget? leading;
  final Color? passedColor;
  final int? rotateIcon;
  const CustomListTile({
    Key? key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.leading,
    this.icon,
    this.passedColor,
    this.rotateIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: context.theme.copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.white.withAlpha(10),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0.multipliedRadius),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        horizontalTitleGap: 0.0,
        minVerticalPadding: 8.0,
        leading: icon != null
            ? Container(
                height: double.infinity,
                child: rotateIcon != null
                    ? RotatedBox(
                        quarterTurns: rotateIcon!,
                        child: Icon(
                          icon,
                          color: passedColor ?? Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(100), context.theme.colorScheme.onBackground),
                        ),
                      )
                    : Icon(
                        icon,
                        color: passedColor ?? Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(100), context.theme.colorScheme.onBackground),
                      ),
              )
            : leading,
        title: Text(
          title.overflow,
          style: context.theme.textTheme.displayMedium,
          maxLines: subtitle != null ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: context.theme.textTheme.displaySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: trailing != null
            ? FittedBox(
                child: AnimatedContainer(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  duration: const Duration(milliseconds: 400),
                  child: trailing,
                ),
              )
            : null,
      ),
    );
  }
}

class CustomBlurryDialog extends StatelessWidget {
  final Widget? child;
  final String? title;
  final IconData? icon;
  final List<Widget>? actions;
  final bool normalTitleStyle;
  final String? bodyText;
  final bool isWarning;
  const CustomBlurryDialog({super.key, this.child, this.title, this.actions, this.icon, this.normalTitleStyle = false, this.bodyText, this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 50, vertical: 32),
        clipBehavior: Clip.antiAlias,
        titlePadding: normalTitleStyle ? const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0) : EdgeInsets.zero,
        contentPadding: const EdgeInsets.all(14.0),
        title: normalTitleStyle
            ? Row(
                children: [
                  if (icon != null || isWarning) ...[
                    Icon(
                      isWarning ? Broken.warning_2 : icon,
                    ),
                    const SizedBox(
                      width: 10.0,
                    ),
                  ],
                  Text(
                    isWarning ? Language.inst.WARNING : title ?? '',
                    style: Get.textTheme.displayLarge,
                  ),
                ],
              )
            : Container(
                color: context.theme.cardColor,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                      ),
                      const SizedBox(
                        width: 10.0,
                      ),
                    ],
                    Text(
                      title ?? '',
                      style: context.theme.textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
        content: SingleChildScrollView(
            child: bodyText != null
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      bodyText!,
                      style: Get.textTheme.displayMedium,
                    ),
                  )
                : child),
        actions: actions,
      ),
    );
  }
}

class AddFolderButton extends StatelessWidget {
  final void Function()? onPressed;
  const AddFolderButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.all(
          context.theme.backgroundColor.withAlpha(200),
        ),
      ),
      icon: const Icon(
        Broken.folder_add,
        size: 18,
      ),
      label: Text(Language.inst.ADD),
      onPressed: onPressed,
    );
  }
}

class StatsContainer extends StatelessWidget {
  final Widget? child;
  final IconData? icon;
  final String? title;
  final String? value;
  final String? total;

  const StatsContainer({super.key, this.child, this.icon, this.title, this.value, this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: context.theme.cardTheme.color?.withAlpha(200),
        borderRadius: BorderRadius.circular(22.0.multipliedRadius),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 5.0),
      child: child ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(
                width: 8.0,
              ),
              Text(title ?? ''),
              const SizedBox(
                width: 8.0,
              ),
              Text(value ?? ''),
              if (total != null) Text(" ${Language.inst.OF} $total")
            ],
          ),
    );
  }
}

class SmallListTile extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool active;
  final bool displayAnimatedCheck;
  final void Function()? onTap;
  const SmallListTile({super.key, required this.title, this.onTap, this.trailing, this.active = false, this.icon, this.trailingIcon, this.displayAnimatedCheck = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon != null
          ? Icon(icon)
          : active
              ? const Icon(Broken.arrow_circle_right)
              : const Icon(
                  Broken.arrow_right_3,
                  size: 18.0,
                ),
      visualDensity: VisualDensity.compact,
      title: Text(title, style: context.textTheme.displayMedium),
      trailing: displayAnimatedCheck
          ? SizedBox(
              height: 18.0,
              width: 18.0,
              child: CheckMark(
                // curve: Curves.easeInOutExpo,
                strokeWidth: 2,
                activeColor: context.theme.listTileTheme.iconColor!,
                inactiveColor: context.theme.listTileTheme.iconColor!,
                duration: const Duration(milliseconds: 400),
                active: SettingsController.inst.artistSortReversed.value,
              ),
            )
          : trailingIcon != null
              ? Icon(trailingIcon)
              : trailing,
      onTap: onTap,
    );
  }
}

class CustomSortByExpansionTile extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const CustomSortByExpansionTile({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
        initiallyExpanded: true,
        // backgroundColor: context.theme.cardColor,
        trailing: const Icon(Broken.arrow_down_2),
        title: Row(
          children: [
            const Icon(Broken.sort),
            const SizedBox(
              width: 10.0,
            ),
            Text(title),
          ],
        ),
        children: children);
  }
}

class ListTileWithCheckMark extends StatelessWidget {
  final bool active;
  final void Function()? onTap;
  final String? title;
  final IconData? icon;
  const ListTileWithCheckMark({super.key, required this.active, this.onTap, this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0.multipliedRadius)),
      tileColor: Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(10), context.theme.cardTheme.color!),
      leading: Icon(icon ?? Broken.arrange_circle),
      title: Text(title ?? Language.inst.REVERSE_ORDER),
      trailing: SizedBox(
        height: 18.0,
        width: 18.0,
        child: CheckMark(
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

class CreatePlaylistButton extends StatelessWidget {
  const CreatePlaylistButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => showSettingDialogWithTextField(
        title: Language.inst.CREATE_NEW_PLAYLIST,
        addNewPlaylist: true,
      ),
      icon: const Icon(Broken.add),
      label: Text(Language.inst.CREATE),
    );
  }
}

class MoreIcon extends StatelessWidget {
  final void Function()? onPressed;
  final bool rotated;
  final double padding;
  const MoreIcon({super.key, this.onPressed, this.rotated = true, this.padding = 1.0});

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: rotated ? 1 : 0,
      child: Material(
        borderRadius: BorderRadius.circular(34.0.multipliedRadius),
        color: Colors.transparent,
        child: InkWell(
          highlightColor: const Color.fromARGB(60, 120, 120, 120),
          borderRadius: BorderRadius.circular(34.0.multipliedRadius),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: const Icon(
              Broken.more,
              size: 18.0,
            ),
          ),
        ),
      ),
    );
  }
}

class StackedIcon extends StatelessWidget {
  final IconData baseIcon;
  final IconData? secondaryIcon;
  final String? secondaryText;
  final Color? baseIconColor;
  final Color? secondaryIconColor;

  const StackedIcon({
    super.key,
    required this.baseIcon,
    this.secondaryIcon,
    this.baseIconColor,
    this.secondaryIconColor,
    this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Icon(
          baseIcon,
          color: baseIconColor,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(color: Get.theme.scaffoldBackgroundColor, spreadRadius: 1, blurRadius: 3.0),
              ],
            ),
            child: secondaryText != null ? Text(secondaryText!, style: context.textTheme.displaySmall) : Icon(secondaryIcon, size: 14, color: secondaryIconColor),
          ),
        )
      ],
    );
  }
}

class SmallIconButton extends StatelessWidget {
  final IconData icon;
  final void Function()? onTap;

  const SmallIconButton({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Icon(
        icon,
        size: 20.0,
      ),
    );
  }
}

class BlurryContainer extends StatelessWidget {
  final Container? container;
  final BorderRadius borderRadius;
  final Widget? child;
  final bool disableBlur;
  const BlurryContainer({super.key, this.container, this.child, this.borderRadius = BorderRadius.zero, this.disableBlur = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: disableBlur
          ? container ?? child
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: container ?? child,
            ),
    );
  }
}

class CancelButton extends StatelessWidget {
  const CancelButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Get.close(1),
      child: Text(Language.inst.CANCEL),
    );
  }
}
