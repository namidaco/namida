import 'dart:ui';

import 'package:checkmark/checkmark.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/widgets/dialogs/setting_dialog_with_text_field.dart';

class CustomSwitchListTile extends StatelessWidget {
  final bool value;
  final void Function(bool) onChanged;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? icon;
  final Color? passedColor;
  final int? rotateIcon;
  const CustomSwitchListTile(
      {Key? key, required this.value, required this.onChanged, required this.title, this.subtitle, this.leading, this.icon, this.passedColor, this.rotateIcon})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        splashColor: Colors.transparent,
        highlightColor: context.isDarkMode ? Colors.white.withAlpha(12) : Colors.black.withAlpha(40),
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
                CustomSwitch(active: value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomSwitch extends StatelessWidget {
  final bool active;
  final double height;
  final double width;
  final Color? circleColor;
  final Color? bgColor;
  final Color? shadowColor;
  final int durationInMillisecond;

  const CustomSwitch({
    super.key,
    required this.active,
    this.height = 21.0,
    this.width = 40.0,
    this.circleColor,
    this.durationInMillisecond = 400,
    this.bgColor,
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      width: width,
      height: height,
      duration: Duration(milliseconds: durationInMillisecond),
      padding: EdgeInsets.symmetric(horizontal: width / 10),
      decoration: BoxDecoration(
        color: (active
            ? bgColor ?? Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(180), context.theme.colorScheme.background).withAlpha(140)
            // : context.theme.scaffoldBackgroundColor.withAlpha(34)
            : Color.alphaBlend(context.theme.scaffoldBackgroundColor.withAlpha(60), context.theme.disabledColor)),
        borderRadius: BorderRadius.circular(30.0.multipliedRadius),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: active ? 8 : 2,
            spreadRadius: 0,
            color: (shadowColor ?? Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(180), context.theme.colorScheme.background)).withOpacity(active ? 0.8 : 0.3),
          ),
        ],
      ),
      child: AnimatedAlign(
        duration: Duration(milliseconds: durationInMillisecond),
        alignment: active ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: width / 3,
          height: height / 1.5,
          decoration: BoxDecoration(
            color: circleColor ?? Colors.white.withAlpha(222),
            borderRadius: BorderRadius.circular(30.0.multipliedRadius),
            // boxShadow: [
            //   BoxShadow(color: Colors.black.withAlpha(100), spreadRadius: 1, blurRadius: 4, offset: Offset(0, 2)),
            // ],
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
  final String? trailingText;
  final IconData? icon;
  final Widget? leading;
  final Color? passedColor;
  final int? rotateIcon;
  final bool enabled;
  final bool largeTitle;
  final int maxSubtitleLines;
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
    this.trailingText,
    this.enabled = true,
    this.largeTitle = false,
    this.maxSubtitleLines = 2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: context.theme.copyWith(
        splashColor: Colors.transparent,
        highlightColor: context.isDarkMode ? Colors.white.withAlpha(12) : Colors.black.withAlpha(40),
      ),
      child: ListTile(
        enabled: enabled,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0.multipliedRadius),
        ),
        onTap: onTap,
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
          style: largeTitle ? context.theme.textTheme.displayLarge : context.theme.textTheme.displayMedium,
          maxLines: subtitle != null ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: context.theme.textTheme.displaySmall,
                maxLines: maxSubtitleLines,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: trailingText != null
            ? Text(
                trailingText!,
                style: Get.textTheme.displayMedium?.copyWith(color: context.theme.colorScheme.onBackground.withAlpha(200)),
              )
            : (trailing != null
                ? FittedBox(
                    child: AnimatedContainer(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0),
                      duration: const Duration(milliseconds: 400),
                      child: trailing,
                    ),
                  )
                : null),
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
  final bool scrollable;
  final EdgeInsets? insetPadding;
  final EdgeInsetsGeometry? contentPadding;
  const CustomBlurryDialog({
    super.key,
    this.child,
    this.title,
    this.actions,
    this.icon,
    this.normalTitleStyle = false,
    this.bodyText,
    this.isWarning = false,
    this.insetPadding,
    this.scrollable = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        scrollable: scrollable,
        insetPadding: insetPadding ?? const EdgeInsets.symmetric(horizontal: 50, vertical: 32),
        clipBehavior: Clip.antiAlias,
        titlePadding: normalTitleStyle ? const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0) : EdgeInsets.zero,
        contentPadding: contentPadding ?? const EdgeInsets.all(14.0),
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
        content: SizedBox(
          width: Get.width,
          child: bodyText != null
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    bodyText!,
                    style: Get.textTheme.displayMedium,
                  ),
                )
              : child,
        ),
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
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool active;
  final bool displayAnimatedCheck;
  final bool compact;
  final Color? color;
  final void Function()? onTap;
  const SmallListTile(
      {super.key,
      required this.title,
      this.onTap,
      this.trailing,
      this.active = false,
      this.icon,
      this.trailingIcon,
      this.displayAnimatedCheck = false,
      this.compact = true,
      this.subtitle,
      this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(
        height: double.infinity,
        child: icon != null
            ? Icon(icon, color: color != null ? Color.alphaBlend(color!.withAlpha(120), context.textTheme.displayMedium!.color!) : null)
            : active
                ? const Icon(Broken.arrow_circle_right)
                : const Icon(
                    Broken.arrow_right_3,
                    size: 18.0,
                  ),
      ),
      visualDensity: compact ? VisualDensity.compact : null,
      title: Text(title,
          style: context.textTheme.displayMedium?.copyWith(
              color: color != null
                  ? Color.alphaBlend(
                      color!.withAlpha(40),
                      context.textTheme.displayMedium!.color!,
                    )
                  : null)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: context.textTheme.displaySmall?.copyWith(
                  color: color != null
                      ? Color.alphaBlend(
                          color!.withAlpha(40),
                          context.textTheme.displayMedium!.color!,
                        )
                      : null))
          : null,
      trailing: displayAnimatedCheck
          ? SizedBox(
              height: 18.0,
              width: 18.0,
              child: CheckMark(
                // curve: Curves.easeInOutExpo,
                strokeWidth: 2,
                activeColor: color ?? context.theme.listTileTheme.iconColor!,
                inactiveColor: color ?? context.theme.listTileTheme.iconColor!,
                duration: const Duration(milliseconds: 400),
                active: SettingsController.inst.artistSortReversed.value,
              ),
            )
          : trailingIcon != null
              ? Icon(trailingIcon, color: color)
              : trailing,
      onTap: onTap,
    );
  }
}

class ListTileWithCheckMark extends StatelessWidget {
  final bool active;
  final void Function()? onTap;
  final String? title;
  final IconData? icon;
  final Color? tileColor;
  const ListTileWithCheckMark({super.key, required this.active, this.onTap, this.title, this.icon, this.tileColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0.multipliedRadius)),
      tileColor: tileColor ?? Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(10), context.theme.cardTheme.color!),
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

class GeneratePlaylistButton extends StatelessWidget {
  const GeneratePlaylistButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => PlaylistController.inst.generateRandomPlaylist(),
      icon: const Icon(Broken.shuffle),
      label: Text(Language.inst.RANDOM),
    );
  }
}

class MoreIcon extends StatelessWidget {
  final void Function()? onPressed;
  final bool rotated;
  final double padding;
  final Color? iconColor;
  final double? iconSize;
  const MoreIcon({super.key, this.onPressed, this.rotated = true, this.padding = 1.0, this.iconColor, this.iconSize});

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
            child: Icon(
              Broken.more,
              size: iconSize ?? 18.0,
              color: iconColor,
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

class CollapsedSettingTileWidget extends StatelessWidget {
  const CollapsedSettingTileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => CustomSwitchListTile(
        icon: Broken.archive,
        title: Language.inst.USE_COLLAPSED_SETTING_TILES,
        value: SettingsController.inst.useSettingCollapsedTiles.value,
        onChanged: (p0) {
          SettingsController.inst.save(useSettingCollapsedTiles: !p0);
          Get.back();
          Get.to(() => const SettingsPage());
        },
      ),
    );
  }
}

class NamidaBlurryContainer extends StatelessWidget {
  final Widget child;
  final void Function()? onTap;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  const NamidaBlurryContainer({super.key, required this.child, this.onTap, this.borderRadius, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    final con = BlurryContainer(
      disableBlur: !SettingsController.inst.enableBlurEffect.value,
      borderRadius: borderRadius ??
          BorderRadius.only(
            bottomLeft: Radius.circular(8.0.multipliedRadius),
          ),
      container: Container(
          width: width,
          height: height,
          padding: EdgeInsets.symmetric(horizontal: 6.0.multipliedRadius, vertical: 2.0),
          decoration: BoxDecoration(
            color: context.theme.cardColor.withAlpha(SettingsController.inst.enableBlurEffect.value ? 60 : 220),
            borderRadius: borderRadius ??
                BorderRadius.only(
                  bottomLeft: Radius.circular(8.0.multipliedRadius),
                ),
          ),
          child: child),
    );
    return onTap != null
        ? InkWell(
            onTap: onTap,
            child: con,
          )
        : con;
  }
}

class ContainerWithBorder extends StatelessWidget {
  final Widget? child;
  final Color? borderColor;
  const ContainerWithBorder({super.key, this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: borderColor ?? context.theme.cardColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2.0),
          )
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
