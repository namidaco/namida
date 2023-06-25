import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:checkmark/checkmark.dart';
import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';
import 'package:known_extents_list_view_builder/known_extents_reorderable_list_view_builder.dart';
import 'package:like_button/like_button.dart';
import 'package:selectable_autolink_text/selectable_autolink_text.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wheel_slider/wheel_slider.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/dialogs/setting_dialog_with_text_field.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

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

class CustomSwitchListTile extends StatelessWidget {
  final bool value;
  final void Function(bool isTrue) onChanged;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? icon;
  final Color? passedColor;
  final int? rotateIcon;
  final bool enabled;
  final bool largeTitle;
  final int maxSubtitleLines;

  const CustomSwitchListTile({
    Key? key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.leading,
    this.icon,
    this.passedColor,
    this.rotateIcon,
    this.enabled = true,
    this.largeTitle = false,
    this.maxSubtitleLines = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      icon: icon,
      leading: leading,
      largeTitle: largeTitle,
      maxSubtitleLines: maxSubtitleLines,
      passedColor: passedColor,
      rotateIcon: rotateIcon,
      onTap: () => onChanged(value),
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
    this.maxSubtitleLines = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: context.theme.copyWith(
        splashColor: Colors.transparent,
        highlightColor: context.isDarkMode ? Colors.white.withAlpha(12) : Colors.black.withAlpha(40),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: enabled ? 1.0 : 0.5,
        child: ListTile(
          enabled: enabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0.multipliedRadius),
          ),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
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
            maxLines: subtitle != null ? 1 : 3,
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
                  style: context.textTheme.displayMedium?.copyWith(color: context.theme.colorScheme.onBackground.withAlpha(200)),
                )
              : trailing != null
                  ? FittedBox(
                      child: trailing!,
                    )
                  : null,
        ),
      ),
    );
  }
}

class NamidaBgBlur extends StatelessWidget {
  final double blur;
  final bool enabled;
  final BlendMode blendMode;
  final Widget child;
  const NamidaBgBlur({
    super.key,
    required this.blur,
    this.enabled = true,
    this.blendMode = BlendMode.srcOver,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      blendMode: blendMode,
      child: child,
    );
  }
}

class CustomBlurryDialog extends StatelessWidget {
  final IconData? icon;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? trailingWidgets;
  final Widget? child;
  final List<Widget>? actions;
  final Widget? leftAction;
  final bool normalTitleStyle;
  final String? bodyText;
  final bool isWarning;
  final bool enableBlur;
  final bool scrollable;
  final bool tapToDismiss;
  final EdgeInsets? insetPadding;
  final EdgeInsetsGeometry? contentPadding;
  final void Function()? onDismissing;
  const CustomBlurryDialog({
    super.key,
    this.child,
    this.trailingWidgets,
    this.title,
    this.actions,
    this.icon,
    this.normalTitleStyle = false,
    this.bodyText,
    this.isWarning = false,
    this.enableBlur = true,
    this.insetPadding,
    this.scrollable = true,
    this.tapToDismiss = true,
    this.contentPadding,
    this.onDismissing,
    this.leftAction,
    this.titleWidget,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // TODO: doesnt work, since [navigateToDialog] already has OnWillPop.
      onWillPop: () async {
        if (onDismissing != null) onDismissing!();
        return tapToDismiss;
      },
      child: NamidaBgBlur(
        blur: 5.0,
        enabled: enableBlur,
        child: Theme(
          data: AppThemes.inst.getAppTheme(CurrentColor.inst.color.value, !context.isDarkMode),
          child: GestureDetector(
            onTap: () {
              if (tapToDismiss) {
                NamidaNavigator.inst.closeDialog();
              }
              if (onDismissing != null) onDismissing!();
            },
            child: Container(
              color: Colors.black45,
              child: Center(
                child: SingleChildScrollView(
                  child: Dialog(
                    surfaceTintColor: Colors.transparent,
                    insetPadding: insetPadding ?? const EdgeInsets.symmetric(horizontal: 50, vertical: 32),
                    clipBehavior: Clip.antiAlias,
                    child: GestureDetector(
                      onTap: () {},
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          /// Title.
                          if (titleWidget != null) titleWidget!,
                          if (titleWidget == null)
                            normalTitleStyle
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0),
                                    child: Row(
                                      children: [
                                        if (icon != null || isWarning) ...[
                                          Icon(
                                            isWarning ? Broken.warning_2 : icon,
                                          ),
                                          const SizedBox(
                                            width: 10.0,
                                          ),
                                        ],
                                        Expanded(
                                          child: Text(
                                            isWarning ? Language.inst.WARNING : title ?? '',
                                            style: context.textTheme.displayLarge,
                                          ),
                                        ),
                                        if (trailingWidgets != null) ...trailingWidgets!
                                      ],
                                    ),
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

                          /// Body.
                          Padding(
                            padding: contentPadding ?? const EdgeInsets.all(14.0),
                            child: SizedBox(
                              width: context.width,
                              child: bodyText != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Text(
                                        bodyText!,
                                        style: context.textTheme.displayMedium,
                                      ),
                                    )
                                  : child,
                            ),
                          ),

                          /// Actions.
                          if (actions != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (leftAction != null) ...[
                                    const SizedBox(width: 6.0),
                                    leftAction!,
                                    const SizedBox(width: 6.0),
                                    const Spacer(),
                                  ],
                                  ...actions!.addSeparators(separator: const SizedBox(width: 6.0))
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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
  final EdgeInsetsGeometry? padding;
  final double? titleGap;
  final double borderRadius;
  final Widget? leading;
  const SmallListTile({
    super.key,
    required this.title,
    this.onTap,
    this.trailing,
    this.active = false,
    this.icon,
    this.trailingIcon,
    this.displayAnimatedCheck = false,
    this.compact = true,
    this.subtitle,
    this.color,
    this.padding,
    this.titleGap = 14.0,
    this.borderRadius = 0.0,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: padding,
      horizontalTitleGap: titleGap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
      ),
      leading: leading ??
          SizedBox(
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
      title: Text(
        title,
        style: context.textTheme.displayMedium?.copyWith(
          color: color != null
              ? Color.alphaBlend(
                  color!.withAlpha(40),
                  context.textTheme.displayMedium!.color!,
                )
              : null,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: context.textTheme.displaySmall?.copyWith(
                color: color != null
                    ? Color.alphaBlend(
                        color!.withAlpha(40),
                        context.textTheme.displayMedium!.color!,
                      )
                    : null,
              ),
            )
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
    return Material(
      borderRadius: BorderRadius.circular(16.0.multipliedRadius),
      color: tileColor ?? Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(10), context.theme.cardTheme.color!),
      child: ListTile(
        horizontalTitleGap: 10.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0.multipliedRadius)),
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
      ),
    );
  }
}

class NamidaExpansionTile extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final IconData? trailingIcon;
  final double trailingIconSize;
  final String titleText;
  final Color? textColor;
  final Color? textColorScheme;
  final List<Widget> children;
  final EdgeInsetsGeometry? childrenPadding;
  final bool initiallyExpanded;
  final Widget? trailing;

  const NamidaExpansionTile({
    super.key,
    this.icon,
    this.iconColor,
    this.leading,
    this.trailingIcon = Broken.arrow_down_2,
    this.trailingIconSize = 20.0,
    required this.titleText,
    this.textColor,
    this.textColorScheme,
    this.children = const <Widget>[],
    this.childrenPadding = EdgeInsets.zero,
    this.initiallyExpanded = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTileTheme(
      horizontalTitleGap: 14.0,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        expandedAlignment: Alignment.centerLeft,
        leading: leading ??
            Icon(
              icon,
              color: iconColor,
            ),
        trailing: trailing ??
            (trailingIcon == null
                ? null
                : IgnorePointer(
                    child: IconButton(
                      onPressed: () {},
                      icon: Icon(trailingIcon, size: trailingIconSize),
                    ),
                  )),
        title: Text(
          titleText,
          style: context.textTheme.displayMedium?.copyWith(
            color: textColor ??
                (textColorScheme == null
                    ? null
                    : Color.alphaBlend(
                        textColorScheme!.withAlpha(40),
                        context.textTheme.displayMedium!.color!,
                      )),
          ),
        ),
        childrenPadding: childrenPadding,
        children: children,
      ),
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
  final void Function()? onLongPress;
  final bool rotated;
  final double padding;
  final Color? iconColor;
  final double iconSize;
  const MoreIcon({super.key, this.onPressed, this.rotated = true, this.padding = 1.0, this.iconColor, this.iconSize = 18.0, this.onLongPress});

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
          onLongPress: onLongPress,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Icon(
              Broken.more,
              size: iconSize,
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
  final double? iconSize;
  final double blurRadius;
  final Widget? smallChild;

  const StackedIcon({
    super.key,
    required this.baseIcon,
    this.secondaryIcon,
    this.baseIconColor,
    this.secondaryIconColor,
    this.secondaryText,
    this.iconSize,
    this.blurRadius = 3.0,
    this.smallChild,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Icon(
          baseIcon,
          color: baseIconColor,
          size: iconSize,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(color: context.theme.scaffoldBackgroundColor, spreadRadius: 0, blurRadius: blurRadius),
              ],
            ),
            child: smallChild ??
                (secondaryText != null
                    ? Text(secondaryText!, style: context.textTheme.displaySmall?.copyWith(color: context.theme.listTileTheme.iconColor))
                    : Icon(secondaryIcon, size: 14, color: secondaryIconColor)),
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
    return NamidaIconButton(
      icon: icon,
      onPressed: onTap,
      iconSize: 20.0,
      horizontalPadding: 0,
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
    final Widget? finalChild = container ?? child;
    return ClipRRect(
      borderRadius: borderRadius,
      child: disableBlur || finalChild == null
          ? finalChild
          : NamidaBgBlur(
              blur: 5.0,
              child: finalChild,
            ),
    );
  }
}

class CancelButton extends StatelessWidget {
  const CancelButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => NamidaNavigator.inst.closeDialog(),
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
        onChanged: (isTrue) {
          SettingsController.inst.save(useSettingCollapsedTiles: !isTrue);
          NamidaNavigator.inst.popPage();
          NamidaNavigator.inst.navigateOff(const SettingsPage());
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
  final EdgeInsetsGeometry? padding;
  const NamidaBlurryContainer({super.key, required this.child, this.onTap, this.borderRadius, this.width, this.height, this.padding});

  @override
  Widget build(BuildContext context) {
    final blurredAlphaLight = context.isDarkMode ? 60 : 140;
    final con = BlurryContainer(
      disableBlur: !SettingsController.inst.enableBlurEffect.value,
      borderRadius: borderRadius ??
          BorderRadius.only(
            bottomLeft: Radius.circular(8.0.multipliedRadius),
          ),
      container: Container(
          width: width,
          height: height,
          padding: padding ?? EdgeInsets.symmetric(horizontal: 6.0.multipliedRadius, vertical: 2.0),
          decoration: BoxDecoration(
            color: context.theme.cardColor.withAlpha(SettingsController.inst.enableBlurEffect.value ? blurredAlphaLight : 220),
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
        color: borderColor ?? context.theme.cardColor.withAlpha(160),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor.withAlpha(60),
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

class NamidaWheelSlider extends StatelessWidget {
  final double width;
  final double perspective;
  final int totalCount;
  final int initValue;
  final double itemSize;
  final double squeeze;
  final bool isInfinite;
  final String? text;
  final String? topText;
  final double? textPadding;
  final double? topTextPadding;
  final dynamic Function(dynamic val) onValueChanged;
  const NamidaWheelSlider({
    super.key,
    this.width = 80,
    this.perspective = 0.01,
    required this.totalCount,
    required this.initValue,
    required this.itemSize,
    this.squeeze = 1.0,
    this.isInfinite = false,
    required this.onValueChanged,
    this.text,
    this.topText,
    this.textPadding = 2.0,
    this.topTextPadding = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          if (topText != null) ...[
            Text(
              topText!,
              style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: topTextPadding),
          ],
          WheelSlider(
            perspective: perspective,
            totalCount: totalCount,
            initValue: initValue,
            itemSize: itemSize,
            squeeze: squeeze,
            isInfinite: false,
            lineColor: Get.iconColor,
            pointerColor: context.theme.listTileTheme.textColor!,
            pointerHeight: 38.0,
            horizontalListHeight: 38.0,
            onValueChanged: onValueChanged,
            hapticFeedbackType: HapticFeedbackType.lightImpact,
          ),
          if (text != null) ...[
            SizedBox(height: textPadding),
            Text(text!, style: TextStyle(color: context.textTheme.displaySmall?.color)),
          ]
        ],
      ),
    );
  }
}

class NamidaLikeButton extends StatelessWidget {
  final Track track;
  final double size;
  final Color? color;
  final bool isDummy;
  const NamidaLikeButton({super.key, required this.track, this.size = 30.0, this.color, this.isDummy = false});

  @override
  Widget build(BuildContext context) {
    return LikeButton(
      size: size,
      bubblesColor: BubblesColor(
        dotPrimaryColor: context.theme.colorScheme.primary,
        dotSecondaryColor: context.theme.colorScheme.primaryContainer,
      ),
      circleColor: CircleColor(
        start: context.theme.colorScheme.tertiary,
        end: context.theme.colorScheme.tertiary,
      ),
      isLiked: track.isFavourite,
      onTap: (isLiked) async {
        if (!isDummy) PlaylistController.inst.favouriteButtonOnPressed(track);
        return !isLiked;
      },
      likeBuilder: (value) => value
          ? Icon(
              Broken.heart_tick,
              color: color ?? context.theme.colorScheme.primary,
              size: size,
            )
          : Icon(
              Broken.heart,
              color: color ?? context.theme.colorScheme.onSecondaryContainer,
              size: size,
            ),
    );
  }
}

class NamidaIconButton extends StatefulWidget {
  final EdgeInsetsGeometry? padding;
  final double horizontalPadding;
  final double verticalPadding;
  final double? iconSize;
  final IconData icon;
  final Color? iconColor;
  final void Function()? onPressed;
  final String? tooltip;
  const NamidaIconButton({
    super.key,
    this.padding,
    this.horizontalPadding = 10.0,
    this.verticalPadding = 0.0,
    required this.icon,
    required this.onPressed,
    this.iconSize,
    this.iconColor,
    this.tooltip,
  });

  @override
  State<NamidaIconButton> createState() => _NamidaIconButtonState();
}

class _NamidaIconButtonState extends State<NamidaIconButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip ?? '',
      child: GestureDetector(
        onTapDown: (value) => setState(() => isPressed = true),
        onTapUp: (value) => setState(() => isPressed = false),
        onTapCancel: () => setState(() => isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isPressed ? 0.5 : 1.0,
          child: Padding(
            padding: widget.padding ?? EdgeInsets.symmetric(horizontal: widget.horizontalPadding, vertical: widget.verticalPadding),
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: widget.iconColor ?? context.theme.colorScheme.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

class NamidaPartyContainer extends StatelessWidget {
  final double spreadRadiusMultiplier;
  final double? width;
  final double? height;
  final double opacity;
  const NamidaPartyContainer({
    super.key,
    this.spreadRadiusMultiplier = 1.0,
    this.width,
    this.height,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    if (!SettingsController.inst.enablePartyModeColorSwap.value) {
      return Obx(
        () {
          final finalScale = WaveformController.inst.getCurrentAnimatingScale(Player.inst.nowPlayingPosition.value);
          return Opacity(
            opacity: opacity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: height,
              width: width,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: CurrentColor.inst.color.value.withAlpha(150),
                    spreadRadius: 150 * finalScale * spreadRadiusMultiplier,
                    blurRadius: 10 + (200 * finalScale),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      return Opacity(
        opacity: opacity,
        child: Obx(
          () {
            final finalScale = WaveformController.inst.getCurrentAnimatingScale(Player.inst.nowPlayingPosition.value);
            final firstHalf = CurrentColor.inst.paletteFirstHalf;
            final secondHalf = CurrentColor.inst.paletteSecondHalf;
            return height != null
                ? Row(
                    children: firstHalf
                        .map(
                          (e) => AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: height,
                            width: width ?? context.width / firstHalf.length,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: e.withAlpha(150),
                                  spreadRadius: 150 * finalScale * spreadRadiusMultiplier,
                                  blurRadius: 10 + (200 * finalScale),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  )
                : Column(
                    children: secondHalf
                        .map(
                          (e) => AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: height ?? context.height / secondHalf.length,
                            width: width,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: e.withAlpha(150),
                                  spreadRadius: 140 * finalScale * spreadRadiusMultiplier,
                                  blurRadius: 10 + (200 * finalScale),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  );
          },
        ),
      );
    }
  }
}

class SubpagesTopContainer extends StatelessWidget {
  final String title;
  final String subtitle;
  final String thirdLineText;
  final double? height;
  final double verticalPadding;
  final Widget imageWidget;
  final List<Track> tracks;
  final QueueSource source;
  final String heroTag;
  const SubpagesTopContainer({
    super.key,
    required this.title,
    required this.subtitle,
    this.thirdLineText = '',
    this.height,
    required this.imageWidget,
    required this.tracks,
    this.verticalPadding = 16.0,
    required this.source,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    const pauseHero = 'kururing';
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12.0),
      margin: EdgeInsets.symmetric(vertical: verticalPadding),
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          imageWidget,
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  height: 18.0,
                ),
                Container(
                  padding: const EdgeInsets.only(left: 14.0),
                  child: Hero(
                    tag: '${pauseHero}line1_$heroTag',
                    child: Text(
                      title,
                      style: context.textTheme.displayLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 2.0,
                ),
                Container(
                  padding: const EdgeInsets.only(left: 14.0),
                  child: Hero(
                    tag: '${pauseHero}line2_$heroTag',
                    child: Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: context.textTheme.displayMedium?.copyWith(fontSize: 14.0.multipliedFontScale),
                    ),
                  ),
                ),
                if (thirdLineText != '') ...[
                  const SizedBox(
                    height: 2.0,
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 14.0),
                    child: Hero(
                      tag: '${pauseHero}line3_$heroTag',
                      child: Text(
                        thirdLineText,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: context.textTheme.displaySmall?.copyWith(fontSize: 14.0.multipliedFontScale),
                      ),
                    ),
                  ),
                ],
                const SizedBox(
                  height: 18.0,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: 6.0),
                    ElevatedButton(
                      onPressed: () => Player.inst.playOrPause(
                        0,
                        tracks,
                        source,
                        shuffle: true,
                      ),
                      style: ElevatedButton.styleFrom(
                        fixedSize: const Size(0.0, 0.0),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Broken.shuffle),
                    ),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Player.inst.addToQueue(tracks),
                        icon: const StackedIcon(baseIcon: Broken.play, secondaryIcon: Broken.add_circle),
                        label: FittedBox(child: Text(Language.inst.PLAY_LAST)),
                        style: ElevatedButton.styleFrom(
                          fixedSize: const Size(0.0, 0.0),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                  ],
                )
              ],
            ),
          ),
          // TODO: widget for most played music [CalendarSelectDay(), DateType(day, week, month, year, custom)]
        ],
      ),
    );
  }
}

class AnimatingTile extends StatelessWidget {
  final int position;
  final Widget child;
  final bool shouldAnimate;
  const AnimatingTile({super.key, required this.position, required this.child, this.shouldAnimate = true});

  @override
  Widget build(BuildContext context) {
    return shouldAnimate
        ? AnimationConfiguration.staggeredList(
            position: position,
            duration: const Duration(milliseconds: 400),
            child: SlideAnimation(
              verticalOffset: 25.0,
              child: FadeInAnimation(
                duration: const Duration(milliseconds: 400),
                child: child,
              ),
            ),
          )
        : child;
  }
}

class AnimatingGrid extends StatelessWidget {
  final int position;
  final int columnCount;
  final Widget child;
  final bool shouldAnimate;
  const AnimatingGrid({super.key, required this.position, required this.columnCount, required this.child, this.shouldAnimate = true});

  @override
  Widget build(BuildContext context) {
    return shouldAnimate
        ? AnimationConfiguration.staggeredGrid(
            columnCount: columnCount,
            position: position,
            duration: const Duration(milliseconds: 400),
            child: SlideAnimation(
              verticalOffset: 25.0,
              child: FadeInAnimation(
                duration: const Duration(milliseconds: 400),
                child: child,
              ),
            ),
          )
        : child;
  }
}

class NamidaDrawerListTile extends StatelessWidget {
  final void Function()? onTap;
  final bool enabled;
  final String title;
  final IconData? icon;
  final double width;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final bool isCentered;
  final double iconSize;
  const NamidaDrawerListTile({
    super.key,
    this.onTap,
    required this.enabled,
    required this.title,
    required this.icon,
    this.width = double.infinity,
    this.margin = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
    this.padding = const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
    this.isCentered = false,
    this.iconSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: enabled ? CurrentColor.inst.color.value : context.theme.cardColor,
        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
        child: InkWell(
          onTap: onTap,
          highlightColor: context.theme.scaffoldBackgroundColor.withAlpha(100),
          borderRadius: BorderRadius.circular(8.0.multipliedRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            alignment: Alignment.center,
            width: width,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0.multipliedRadius),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: CurrentColor.inst.color.value.withAlpha(100),
                        spreadRadius: 0.2,
                        blurRadius: 8.0,
                        offset: const Offset(0.0, 4.0),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: isCentered ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: enabled ? Colors.white.withAlpha(200) : null,
                  size: iconSize,
                ),
                if (title != '') ...[
                  const SizedBox(width: 12.0),
                  Text(
                    title,
                    style: context.textTheme.displayMedium?.copyWith(
                      color: enabled ? Colors.white.withAlpha(200) : null,
                      fontSize: context.width / 29,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SearchPageTitleRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final String? buttonText;
  final IconData? buttonIcon;
  final void Function()? onPressed;
  const SearchPageTitleRow({
    super.key,
    required this.title,
    required this.icon,
    this.trailing,
    this.buttonText,
    this.buttonIcon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 16.0),
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8.0),
            Text(
              title,
              style: context.textTheme.displayLarge?.copyWith(fontSize: 15.5.multipliedFontScale),
            ),
          ],
        ),
        const Spacer(),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: context.theme.listTileTheme.iconColor),
          icon: Icon(buttonIcon, size: 20.0),
          label: Text(buttonText ?? ''),
          onPressed: onPressed,
        ),
        const SizedBox(width: 16.0),
      ],
    );
  }
}

class NamidaLogoContainer extends StatelessWidget {
  const NamidaLogoContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0).add(const EdgeInsets.only(top: 16.0, bottom: 8.0)),
      child: Material(
        borderRadius: BorderRadius.circular(12.0.multipliedRadius),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            alignment: Alignment.center,
            width: double.infinity,
            height: 54.0,
            padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
            decoration: BoxDecoration(
              color: context.isDarkMode ? const Color(0xffb9a48b).withAlpha(200) : const Color(0xffdfc6a7).withAlpha(255),
              borderRadius: BorderRadius.circular(12.0.multipliedRadius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffdfc6a7).withAlpha(context.isDarkMode ? 40 : 100),
                  spreadRadius: 0.2,
                  blurRadius: 8.0,
                  offset: const Offset(0.0, 4.0),
                ),
              ],
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/namida_icon.png',
                  width: 40.0,
                  height: 40.0,
                  cacheHeight: 240,
                  cacheWidth: 240,
                ),
                const SizedBox(width: 8.0),
                Text(
                  'Namida',
                  style: context.textTheme.displayLarge?.copyWith(
                    color: Color.alphaBlend(const Color(0xffdfc6a7).withAlpha(90), Colors.white),
                    fontSize: context.width / 26,
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

class NamidaContainerDivider extends StatelessWidget {
  final double? width;
  final double height;
  final Color? color;
  final EdgeInsetsGeometry? margin;
  const NamidaContainerDivider({super.key, this.width, this.height = 2.0, this.color, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: (color ?? context.theme.dividerColor).withAlpha(Get.isDarkMode ? 100 : 20),
        borderRadius: BorderRadius.circular(18.0.multipliedRadius),
      ),
    );
  }
}

class FadeDismissible extends StatelessWidget {
  final Widget child;
  final void Function(DismissDirection)? onDismissed;
  final DismissDirection direction;

  FadeDismissible({
    super.key,
    required this.child,
    this.onDismissed,
    this.direction = DismissDirection.horizontal,
  });

  final RxDouble opacity = 1.0.obs;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      onDismissed: onDismissed,
      onUpdate: (details) {
        opacity.value = 1 - details.progress;
      },
      direction: direction,
      child: Obx(
        () => Opacity(
          opacity: opacity.value,
          child: child,
        ),
      ),
    );
  }
}

class NamidaSelectableAutoLinkText extends StatelessWidget {
  final String text;
  const NamidaSelectableAutoLinkText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return SelectableAutoLinkText(
      text,
      style: context.textTheme.displayMedium?.copyWith(fontSize: 13.5.multipliedFontScale),
      linkStyle: context.textTheme.displayMedium?.copyWith(
        color: context.theme.colorScheme.primary.withAlpha(210),
        fontSize: 13.5.multipliedFontScale,
      ),
      highlightedLinkStyle: TextStyle(
        color: context.theme.colorScheme.primary.withAlpha(220),
        backgroundColor: context.theme.colorScheme.onBackground.withAlpha(40),
        fontSize: 13.5.multipliedFontScale,
      ),
      onTap: (url) async {
        try {
          await launchUrlString(url, mode: LaunchMode.externalNonBrowserApplication);
        } catch (e) {
          await launchUrlString(url);
        }
      },
    );
  }
}

class DefaultPlaylistCard extends StatelessWidget {
  final Color colorScheme;
  final IconData icon;
  final String title;
  final String text;
  final Playlist? playlist;
  final double? width;
  final void Function()? onTap;

  const DefaultPlaylistCard({super.key, required this.colorScheme, required this.icon, required this.title, this.text = '', this.playlist, this.width, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Color.alphaBlend(colorScheme.withAlpha(10), context.theme.cardColor),
        borderRadius: BorderRadius.circular(12.0.multipliedRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: colorScheme.withAlpha(200),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    title.overflow,
                    style: context.textTheme.displayMedium?.copyWith(color: Color.alphaBlend(colorScheme.withAlpha(10), context.textTheme.displayMedium!.color!)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6.0),
                Text(
                  playlist?.tracks.length.toString() ?? text,
                  style: context.textTheme.displayMedium?.copyWith(color: Color.alphaBlend(colorScheme.withAlpha(30), context.textTheme.displayMedium!.color!)),
                ),
                const SizedBox(width: 2.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NamidaCircularPercentage extends StatelessWidget {
  final double size;
  final double percentage;
  const NamidaCircularPercentage({super.key, this.size = 48.0, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SleekCircularSlider(
          appearance: CircularSliderAppearance(
            customWidths: CustomSliderWidths(
              trackWidth: size / 24,
              progressBarWidth: size / 12,
            ),
            customColors: CustomSliderColors(
              dotColor: Colors.transparent,
              trackColor: context.theme.cardTheme.color,
              dynamicGradient: true,
              progressBarColors: [
                context.theme.colorScheme.primary.withAlpha(100),
                Colors.transparent,
                context.theme.colorScheme.secondary.withAlpha(100),
                Colors.transparent,
                context.theme.colorScheme.primary.withAlpha(100),
              ],
              hideShadow: true,
            ),
            size: size,
            spinnerMode: true,
          ),
        ),
        if (percentage.isFinite)
          Text(
            "${((percentage).clamp(0.01, 1) * 100).toStringAsFixed(0)}%",
            style: context.textTheme.displaySmall?.copyWith(fontSize: size / 3.2),
          )
      ],
    );
  }
}

// class NamidaListView extends StatelessWidget {
//   final Widget Function(BuildContext context, int i) itemBuilder;
//   final void Function(int oldIndex, int newIndex)? onReorder;
//   final void Function(int index)? onReorderStart;
//   final void Function(int index)? onReorderEnd;
//   final Widget? header;
//   final List<Widget>? widgetsInColumn;
//   final EdgeInsets? padding;
//   final List<double>? itemExtents;
//   final ScrollController? scrollController;
//   final int itemCount;
//   final List<Widget>? moreWidgets;
//   final bool buildDefaultDragHandles;
//   final ScrollPhysics? physics;

//   NamidaListView({
//     super.key,
//     this.header,
//     this.widgetsInColumn,
//     this.padding,
//     this.onReorder,
//     required this.itemBuilder,
//     required this.itemCount,
//     required this.itemExtents,
//     this.moreWidgets,
//     this.scrollController,
//     this.buildDefaultDragHandles = true,
//     this.onReorderStart,
//     this.onReorderEnd,
//     this.physics,
//   });

//   final ScrollController _scrollController = ScrollController();
//   @override
//   Widget build(BuildContext context) {
//     final double? itemExtent = (itemExtents != null && itemExtents!.isNotEmpty) ? itemExtents?.first : null;
//     final sc = scrollController ?? _scrollController;
//     return AnimationLimiter(
//       child: CupertinoScrollbar(
//         controller: sc,
//         child: CustomScrollView(
//           controller: sc,
//           slivers: [
//             SliverToBoxAdapter(child: header),
//             if (widgetsInColumn != null) ...widgetsInColumn!.map((e) => SliverToBoxAdapter(child: e)),
//             if (padding != null) SliverPadding(padding: EdgeInsets.only(top: padding!.top)),
//             onReorder == null
//                 ? itemExtent == null
//                     ? SliverList(
//                         delegate: SliverChildBuilderDelegate(
//                           itemBuilder,
//                           childCount: itemCount,
//                         ),
//                       )
//                     : SliverFixedExtentList(
//                         itemExtent: itemExtent,
//                         delegate: SliverChildBuilderDelegate(
//                           itemBuilder,
//                           childCount: itemCount,
//                         ),
//                       )
//                 : SliverReorderableList(
//                     itemBuilder: itemBuilder,
//                     itemCount: itemCount,
//                     onReorder: onReorder!,
//                     itemExtent: itemExtent,
//                     onReorderStart: onReorderStart,
//                     onReorderEnd: onReorderEnd,
//                     proxyDecorator: (child, index, animation) => child,
//                   ),
//             if (padding != null) SliverPadding(padding: EdgeInsets.only(bottom: padding!.bottom))
//           ],
//         ),
//       ),
//     );
//   }
// }

// class NamidaListView extends StatelessWidget {
//   final Widget Function(BuildContext context, int i) itemBuilder;
//   final void Function(int oldIndex, int newIndex)? onReorder;
//   final void Function(int index)? onReorderStart;
//   final void Function(int index)? onReorderEnd;
//   final Widget? header;
//   final List<Widget>? widgetsInColumn;
//   final EdgeInsets? padding;
//   final List<double>? itemExtents;
//   final ScrollController? scrollController;
//   final int itemCount;
//   final List<Widget>? moreWidgets;
//   final bool buildDefaultDragHandles;
//   final ScrollPhysics? physics;
//   final Key? pageKey;

//   NamidaListView({
//     super.key,
//     this.header,
//     this.widgetsInColumn,
//     this.padding,
//     this.onReorder,
//     required this.itemBuilder,
//     required this.itemCount,
//     required this.itemExtents,
//     this.moreWidgets,
//     this.scrollController,
//     this.buildDefaultDragHandles = true,
//     this.onReorderStart,
//     this.onReorderEnd,
//     this.physics,
//     this.pageKey,
//   });

//   final ScrollController _scrollController = ScrollController();
//   @override
//   Widget build(BuildContext context) {
//     final double? itemExtent = (itemExtents != null && itemExtents!.isNotEmpty) ? itemExtents?.first : null;
//     final sc = scrollController ?? _scrollController;
//     sc.offset;
//     // final h = sc.hasClients ? sc.position.maxScrollExtent : 1.0;
//     return AnimationLimiter(
//       child: DraggableScrollbar.arrows(
//         heightScrollThumb: (context.height / sc.position.maxScrollExtent).clamp(1, context.height) * 30,
//         controller: sc,
//         child: CustomScrollView(
//           physics: physics,
//           controller: sc,
//           slivers: [
//             SliverKnownExtentsReorderableList(
//               key: pageKey,
//               itemExtents: itemExtents!,
//               // scrollController: sc,
//               // padding: padding ?? const EdgeInsets.only(bottom: kBottomPadding),
//               itemBuilder: itemBuilder,
//               itemCount: itemCount,
//               onReorder: onReorder ?? (oldIndex, newIndex) {},
//               proxyDecorator: (child, index, animation) => child,
//               // header: header,
//               // buildDefaultDragHandles: buildDefaultDragHandles,

//               onReorderStart: onReorderStart,
//               onReorderEnd: onReorderEnd,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

class NamidaListView extends StatelessWidget {
  final Widget Function(BuildContext context, int i) itemBuilder;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final void Function(int index)? onReorderStart;
  final void Function(int index)? onReorderEnd;
  final Widget? header;
  final List<Widget>? widgetsInColumn;
  final EdgeInsets? padding;
  final List<double>? itemExtents;
  final ScrollController? scrollController;
  final int itemCount;
  final List<Widget>? moreWidgets;
  final bool buildDefaultDragHandles;
  final ScrollPhysics? physics;

  NamidaListView({
    super.key,
    this.header,
    this.widgetsInColumn,
    this.padding,
    this.onReorder,
    required this.itemBuilder,
    required this.itemCount,
    required this.itemExtents,
    this.moreWidgets,
    this.scrollController,
    this.buildDefaultDragHandles = true,
    this.onReorderStart,
    this.onReorderEnd,
    this.physics,
  });

  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    final double? itemExtent = (itemExtents != null && itemExtents!.isNotEmpty) ? itemExtents?.first : null;
    final sc = scrollController ?? _scrollController;
    return AnimationLimiter(
      child: CupertinoScrollbar(
        controller: sc,
        child: Column(
          children: [
            if (widgetsInColumn != null) ...widgetsInColumn!,
            Expanded(
              child: itemExtents != null && onReorder != null
                  ? KnownExtentsReorderableListView.builder(
                      itemExtents: itemExtents!,
                      scrollController: sc,
                      padding: padding ?? const EdgeInsets.only(bottom: kBottomPadding),
                      itemBuilder: itemBuilder,
                      itemCount: itemCount,
                      onReorder: onReorder ?? (oldIndex, newIndex) {},
                      proxyDecorator: (child, index, animation) => child,
                      header: header,
                      buildDefaultDragHandles: buildDefaultDragHandles,
                      physics: physics,
                      onReorderStart: onReorderStart,
                      onReorderEnd: onReorderEnd,
                    )
                  : ReorderableListView.builder(
                      itemExtent: itemExtent,
                      scrollController: sc,
                      padding: padding ?? const EdgeInsets.only(bottom: kBottomPadding),
                      itemBuilder: itemBuilder,
                      itemCount: itemCount,
                      onReorder: onReorder ?? (oldIndex, newIndex) {},
                      proxyDecorator: (child, index, animation) => child,
                      onReorderStart: onReorderStart,
                      onReorderEnd: onReorderEnd,
                      header: header,
                      buildDefaultDragHandles: onReorder != null,
                      physics: physics,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class NamidaTracksList extends StatelessWidget {
  final List<Track>? queue;
  final int queueLength;
  final Widget Function(BuildContext context, int i)? itemBuilder;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final Widget? header;
  final Widget? footer;
  final List<Widget>? widgetsInColumn;
  final EdgeInsetsGeometry? paddingAfterHeader;
  final ScrollController? scrollController;
  final EdgeInsets? padding;
  final bool? buildDefaultDragHandles;
  final ScrollPhysics? physics;
  final QueueSource queueSource;
  final bool displayIndex;
  final bool shouldAnimate;
  const NamidaTracksList({
    super.key,
    this.queue,
    this.itemBuilder,
    this.onReorder,
    this.header,
    this.footer,
    this.widgetsInColumn,
    this.paddingAfterHeader,
    this.scrollController,
    this.padding = const EdgeInsets.only(bottom: kBottomPadding),
    required this.queueLength,
    this.buildDefaultDragHandles,
    this.physics,
    required this.queueSource,
    this.displayIndex = false,
    this.shouldAnimate = true,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaListView(
      onReorder: onReorder,
      header: header,
      widgetsInColumn: widgetsInColumn,
      scrollController: scrollController,
      itemCount: queueLength,
      itemExtents: List<double>.generate(queueLength, (index) => trackTileItemExtent),
      padding: padding,
      buildDefaultDragHandles: buildDefaultDragHandles ?? onReorder != null,
      physics: physics,
      itemBuilder: itemBuilder ??
          (context, i) {
            if (queue != null) {
              final track = queue![i];
              return AnimatingTile(
                key: ValueKey(i),
                position: i,
                shouldAnimate: shouldAnimate,
                child: TrackTile(
                  index: i,
                  track: track,
                  draggableThumbnail: onReorder != null,
                  queueSource: queueSource,
                  displayIndex: displayIndex,
                ),
              );
            }
            return const Text('PASS A QUEUE OR USE ITEM BUILDER');
          },
    );
  }
}

class NamidaSupportButton extends StatelessWidget {
  final String? title;
  final VoidCallback? onPressed;
  const NamidaSupportButton({super.key, this.title, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        if (onPressed != null) onPressed!();

        launchUrlString(k_NAMIDA_SUPPORT_LINK);
      },
      icon: const Icon(Broken.heart),
      label: Text(title ?? Language.inst.SUPPORT),
    );
  }
}
