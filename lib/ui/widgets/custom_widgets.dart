import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide ReorderableListView, ReorderCallback, SliverReorderableList, ReorderableDragStartListener, ReorderableDelayedDragStartListener, Tooltip;
import 'package:flutter/rendering.dart' as fr;
import 'package:flutter/services.dart';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:checkmark/checkmark.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:history_manager/history_manager.dart';
import 'package:like_button/like_button.dart';
import 'package:photo_view/photo_view.dart';
import 'package:playlist_manager/playlist_manager.dart';
import 'package:selectable_autolink_text/selectable_autolink_text.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/shortcut_data.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/version_wrapper.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/platform/shortcuts_manager/shortcuts_manager.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/shortcuts_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/controller/version_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/controller/window_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/scroll_physics_modified.dart';
import 'package:namida/ui/dialogs/setting_dialog_with_text_field.dart';
import 'package:namida/ui/pages/about_page.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_tooltip.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/popup_wrapper.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';

import 'custom_reorderable_list.dart';

export 'popup_wrapper.dart';

class NamidaReordererableListener extends StatelessWidget {
  final int index;
  final int durationMs;
  final Widget child;

  const NamidaReordererableListener({
    super.key,
    required this.index,
    this.durationMs = 50,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    return ReorderableDelayedDragStartListener(
      index: index,
      delay: isDesktop ? Duration.zero : Duration(milliseconds: durationMs),
      child: child,
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
  final Color? passedColor;

  const CustomSwitch({
    super.key,
    required this.active,
    this.height = 21.0,
    this.width = 40.0,
    this.circleColor,
    this.durationInMillisecond = 300,
    this.bgColor,
    this.shadowColor,
    this.passedColor,
  });

  @override
  Widget build(BuildContext context) {
    final finalColor = passedColor ?? CurrentColor.inst.color;
    final theme = context.theme;
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedDecoration(
        duration: Duration(milliseconds: durationInMillisecond),
        decoration: BoxDecoration(
          color: (active
              ? bgColor ?? Color.alphaBlend(finalColor.withAlpha(180), theme.colorScheme.surface).withAlpha(140)
              // : theme.scaffoldBackgroundColor.withAlpha(34)
              : Color.alphaBlend(theme.scaffoldBackgroundColor.withAlpha(60), theme.disabledColor)),
          borderRadius: BorderRadius.circular(30.0.multipliedRadius),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 2),
              blurRadius: active ? 8 : 2,
              spreadRadius: 0,
              color: (shadowColor ?? Color.alphaBlend(finalColor.withAlpha(180), theme.colorScheme.surface)).withValues(alpha: active ? 0.8 : 0.3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width / 10),
          child: AnimatedAlign(
            duration: Duration(milliseconds: durationInMillisecond),
            alignment: active ? Alignment.centerRight : Alignment.centerLeft,
            child: SizedBox(
              width: width / 3,
              height: height / 1.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: circleColor ?? Colors.white.withAlpha(222),
                  borderRadius: BorderRadius.circular(30.0.multipliedRadius),
                  // boxShadow: [
                  //   BoxShadow(color: Colors.black.withAlpha(100), spreadRadius: 1, blurRadius: 4, offset: Offset(0, 2)),
                  // ],
                ),
              ),
            ),
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
  final VisualDensity? visualDensity;
  final Color? bgColor;

  const CustomSwitchListTile({
    super.key,
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
    this.maxSubtitleLines = 8,
    this.visualDensity,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
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
      visualDensity: visualDensity,
      trailing: IgnorePointer(
        child: FittedBox(
          child: Row(
            children: [
              const SizedBox(
                width: 12.0,
              ),
              CustomSwitch(active: value, passedColor: passedColor),
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
  final Widget? trailingRaw;
  final String? trailingText;
  final IconData? icon;
  final Widget? leading;
  final Color? passedColor;
  final int? rotateIcon;
  final bool enabled;
  final bool largeTitle;
  final int maxSubtitleLines;
  final VisualDensity? visualDensity;
  final TextStyle? titleStyle;
  final double borderR;
  final Color? bgColor;
  final double verticalPadding;

  const CustomListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingRaw,
    this.trailingText,
    this.onTap,
    this.leading,
    this.icon,
    this.passedColor,
    this.rotateIcon,
    this.enabled = true,
    this.largeTitle = false,
    this.maxSubtitleLines = 8,
    this.visualDensity,
    this.titleStyle,
    this.borderR = 20.0,
    this.bgColor,
    this.verticalPadding = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final iconColor = context.defaultIconColor(passedColor);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: enabled ? 1.0 : 0.5,
      child: ListTile(
        enabled: enabled,
        tileColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderR.multipliedRadius),
        ),
        visualDensity: visualDensity,
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: verticalPadding),
        minVerticalPadding: 8.0,
        leading: icon != null
            ? SizedBox(
                height: double.infinity,
                child: rotateIcon != null
                    ? RotatedBox(
                        quarterTurns: rotateIcon!,
                        child: Icon(
                          icon,
                          color: iconColor,
                        ),
                      )
                    : Icon(
                        icon,
                        color: iconColor,
                      ),
              )
            : leading,
        title: Text(
          title,
          style: titleStyle ?? (largeTitle ? theme.textTheme.displayLarge : theme.textTheme.displayMedium),
          maxLines: subtitle != null ? 4 : 5,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle?.isNotEmpty == true
            ? Text(
                subtitle!,
                style: theme.textTheme.displaySmall,
                maxLines: maxSubtitleLines,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: trailingRaw ??
            (trailing == null && trailingText == null
                ? null
                : FittedBox(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: 0, maxWidth: Dimensions.inst.availableAppContentWidth * 0.3),
                      child: trailingText != null
                          ? Text(
                              trailingText!,
                              style: textTheme.displayMedium?.copyWith(color: theme.colorScheme.onSurface.withAlpha(200)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            )
                          : trailing,
                    ),
                  )),
      ),
    );
  }
}

/// Blurs a child, effective for performance
class NamidaBlur extends StatelessWidget {
  final double blur;
  final bool enabled;
  final TileMode? tileMode;
  final Widget child;

  const NamidaBlur({
    super.key,
    required this.blur,
    this.enabled = true,
    bool fixArtifacts = false,
    required this.child,
  }) : tileMode = fixArtifacts ? TileMode.decal : NamidaBlur.kDefaultTileMode;

  static const kDefaultTileMode = TileMode.clamp;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      enabled: enabled && blur > 0,
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: tileMode),
      child: child,
    );
  }
}

/// Blurs a background behind a child, demanding/expensive for performance.
class NamidaBgBlur extends StatelessWidget {
  final double blur;
  final bool enabled;
  final bool disableIfBlur0;
  final Widget child;

  const NamidaBgBlur({
    super.key,
    required this.blur,
    this.enabled = true,
    this.disableIfBlur0 = true,
    required this.child,
  });

  static final _groupKey = BackdropKey();

  @override
  Widget build(BuildContext context) {
    if (!enabled || (disableIfBlur0 && blur == 0)) return child;
    Widget blurredWidget = BackdropFilter(
      backdropGroupKey: _groupKey,
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: NamidaBlur.kDefaultTileMode),
      child: child,
    );
    final topArea = WindowController.instance?.windowTitleBarHeightIfActive;
    if (topArea != null) {
      // -- ensure window title bar is not blurred
      blurredWidget = ClipRect(
        child: blurredWidget,
      );
    }
    return blurredWidget;
  }
}

/// Same as [NamidaBgBlur] but with more configurations like clipping & decoration
class NamidaBgBlurClipped extends StatelessWidget {
  final double blur;
  final bool enabled;
  final Clip clipBehavior;
  final BoxShape shape;
  final BoxDecoration? decoration;
  final BorderRadiusGeometry? borderRadius;
  final Widget child;

  const NamidaBgBlurClipped({
    super.key,
    required this.blur,
    this.enabled = true,
    this.shape = BoxShape.rectangle,
    this.clipBehavior = Clip.antiAlias,
    this.decoration,
    this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = this.decoration;

    if (!enabled || blur == 0) {
      return decoration != null
          ? DecoratedBox(
              decoration: decoration,
              child: child,
            )
          : borderRadius != null && shape != BoxShape.rectangle
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    shape: decoration?.shape ?? BoxShape.rectangle,
                  ),
                )
              : child;
    }

    return ClipPath(
      clipBehavior: clipBehavior,
      clipper: DecorationClipper(
        decoration: BoxDecoration(
          borderRadius: decoration?.borderRadius ?? borderRadius,
          shape: decoration?.shape ?? shape,
        ),
      ),
      child: NamidaBgBlur(
        blur: blur,
        enabled: enabled,
        child: decoration != null
            ? DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: decoration.borderRadius,
                  shape: decoration.shape,
                  backgroundBlendMode: decoration.backgroundBlendMode,
                  border: decoration.border,
                  boxShadow: decoration.boxShadow,
                  color: decoration.color,
                  gradient: decoration.gradient,
                  image: decoration.image,
                ),
                child: child,
              )
            : child,
      ),
    );
  }
}

class DropShadow extends StatelessWidget {
  final Widget child;
  final Widget? bottomChild;
  final double blurRadius;
  final double bgSizePercentage;
  final double sizePercentage;
  final Offset offset;

  const DropShadow({
    required this.child,
    this.bottomChild,
    this.blurRadius = 10.0,
    this.offset = const Offset(0, 4),
    this.bgSizePercentage = defaultBgSizePercentage,
    this.sizePercentage = defaultSizePercentage,
    super.key,
  });

  static const defaultBgSizePercentage = 0.925;
  static const defaultSizePercentage = 0.95;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Transform.scale(
          scale: bgSizePercentage,
          child: Transform.translate(
            offset: offset,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blurRadius,
                sigmaY: blurRadius,
                tileMode: TileMode.decal,
              ),
              child: bottomChild ?? child,
            ),
          ),
        ),
        sizePercentage == 1.0
            ? child
            : Transform.scale(
                scale: sizePercentage,
                child: child,
              )
      ],
    );
  }
}

class CustomBlurryDialog extends StatelessWidget {
  final IconData? icon;
  final String? title;
  final Widget? titleWidget;
  final Widget? titleWidgetInPadding;
  final List<Widget>? trailingWidgets;
  final Widget? child;
  final List<Widget>? actions;
  final Widget? leftAction;
  final bool normalTitleStyle;
  final String? bodyText;
  final bool isWarning;
  final bool scrollable;
  final double horizontalInset;
  final double verticalInset;
  final EdgeInsetsGeometry contentPadding;
  final ThemeData? theme;

  const CustomBlurryDialog({
    super.key,
    this.child,
    this.trailingWidgets,
    this.title,
    this.titleWidget,
    this.titleWidgetInPadding,
    this.actions,
    this.icon,
    this.normalTitleStyle = false,
    this.bodyText,
    this.isWarning = false,
    this.horizontalInset = 50.0,
    this.verticalInset = 32.0,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.all(14.0),
    this.leftAction,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final ctxth = theme ?? context.theme;
    final vInsets = verticalInset;
    final double horizontalMargin = Dimensions.calculateDialogHorizontalMargin(context, horizontalInset);
    return Center(
      child: SingleChildScrollView(
        child: Dialog(
          backgroundColor: ctxth.dialogTheme.backgroundColor,
          surfaceTintColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: vInsets),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: kDialogMaxWidth),
            child: TapDetector(
              onTap: () {},
              child: Container(
                color: Colors.transparent,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// Title.
                    if (titleWidget != null) titleWidget!,
                    if (titleWidgetInPadding != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 28.0, left: 28.0, right: 24.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: titleWidgetInPadding,
                        ),
                      ),
                    if (titleWidget == null && titleWidgetInPadding == null)
                      normalTitleStyle
                          ? Padding(
                              padding: const EdgeInsets.only(top: 28.0, left: 28.0, right: 24.0),
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
                                      isWarning ? lang.WARNING : title ?? '',
                                      style: ctxth.textTheme.displayLarge,
                                    ),
                                  ),
                                  if (trailingWidgets != null) ...trailingWidgets!
                                ],
                              ),
                            )
                          : Container(
                              color: ctxth.cardTheme.color,
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
                                  Expanded(
                                    child: Text(
                                      title ?? '',
                                      style: ctxth.textTheme.displayMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                    /// Body.
                    Padding(
                      padding: contentPadding,
                      child: SizedBox(
                        width: context.width,
                        child: bodyText != null
                            ? Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  bodyText!,
                                  style: ctxth.textTheme.displayMedium,
                                ),
                              )
                            : child,
                      ),
                    ),

                    /// Actions.
                    if (actions != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: SizedBox(
                          width: context.width - horizontalInset,
                          child: Wrap(
                            runSpacing: 8.0,
                            alignment: leftAction == null ? WrapAlignment.end : WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (leftAction != null) ...[
                                const SizedBox(width: 6.0),
                                leftAction!,
                                const SizedBox(width: 6.0),
                              ],
                              ...actions!.addSeparators(separator: const SizedBox(width: 6.0))
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NamidaButtonText extends Text {
  const NamidaButtonText(
    super.data, {
    super.key,
    TextStyle? style,
    super.softWrap,
    super.overflow,
  }) : super(style: style ?? const TextStyle(fontSize: 15.0));
}

class NamidaButton extends StatelessWidget {
  final IconData? icon;
  final double? iconSize;
  final String? text;
  final Widget? textWidget;
  final ButtonStyle? style;

  /// will be used if the icon only is sent.
  final String Function()? tooltip;
  final void Function() onPressed;
  final bool? enabled;

  const NamidaButton({
    super.key,
    this.icon,
    this.iconSize,
    this.text,
    this.textWidget,
    this.style,
    this.tooltip,
    required this.onPressed,
    this.enabled,
  });

  Widget _getWidget(Widget child) {
    return enabled == null
        ? child
        : IgnorePointer(
            ignoring: !enabled!,
            child: AnimatedOpacity(
              opacity: enabled! ? 1.0 : 0.6,
              duration: const Duration(milliseconds: 250),
              child: child,
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    final onTap = onPressed;
    if (textWidget != null) {
      return _getWidget(
        ElevatedButton(
          style: style,
          onPressed: onTap,
          child: textWidget,
        ),
      );
    }

    final iconChild = Icon(icon, size: iconSize);
    final textChild = NamidaButtonText(
      text ?? '',
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );

    // -- icon X && text ✓
    if (icon == null && text != null) {
      return _getWidget(
        ElevatedButton(
          style: style,
          onPressed: onTap,
          child: textChild,
        ),
      );
    }
    // -- icon ✓ && text X
    if (icon != null && text == null) {
      return Tooltip(
        message: tooltip,
        child: _getWidget(
          ElevatedButton(
            style: style,
            onPressed: onTap,
            child: iconChild,
          ),
        ),
      );
    }
    // -- icon ✓ && text ✓
    if (icon != null && text != null) {
      return _getWidget(
        ElevatedButton.icon(
          style: style,
          onPressed: onTap,
          icon: iconChild,
          label: textChild,
        ),
      );
    }
    throw Exception('icon or text must be provided');
  }
}

class StatsContainer extends StatelessWidget {
  final Widget? child;
  final Widget? leading;
  final IconData? icon;
  final String? title;
  final String? value;
  final String? total;

  const StatsContainer({
    super.key,
    this.child,
    this.leading,
    this.icon,
    this.title,
    this.value,
    this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withAlpha(200),
        borderRadius: BorderRadius.circular(18.0.multipliedRadius),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 5.0),
      child: child ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading ??
                  Icon(
                    icon,
                    color: context.defaultIconColor(),
                  ),
              const SizedBox(width: 8.0),
              Text(title ?? ''),
              const SizedBox(width: 8.0),
              Text(value ?? ''),
              if (total != null) Text(" ${lang.OF} $total"),
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
  final double? iconSize;
  final void Function()? onTap;
  final EdgeInsetsGeometry? padding;
  final double? titleGap;
  final double borderRadius;
  final Widget? leading;
  final VisualDensity? visualDensity;

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
    this.iconSize,
    this.padding = const EdgeInsets.only(left: 16.0, right: 12.0),
    this.titleGap,
    this.borderRadius = 0.0,
    this.leading,
    this.visualDensity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final iconColor = color != null ? context.defaultIconColor(color, textTheme.displayMedium?.color) : null;
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
                ? Icon(icon, color: iconColor, size: iconSize)
                : active
                    ? const Icon(
                        Broken.arrow_circle_right,
                        size: 20.0,
                      )
                    : const Icon(
                        Broken.arrow_right_3,
                        size: 18.0,
                      ),
          ),
      visualDensity: visualDensity ?? (compact ? const VisualDensity(horizontal: -2.2, vertical: -2.2) : const VisualDensity(horizontal: -1.2, vertical: -1.2)),
      title: Text(
        title,
        style: textTheme.displayMedium?.copyWith(
          color: color != null
              ? Color.alphaBlend(
                  color!.withAlpha(40),
                  textTheme.displayMedium!.color!,
                )
              : null,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: textTheme.displaySmall?.copyWith(
                color: color != null
                    ? Color.alphaBlend(
                        color!.withAlpha(40),
                        textTheme.displayMedium!.color!,
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
                activeColor: color ?? theme.listTileTheme.iconColor!,
                inactiveColor: color ?? theme.listTileTheme.iconColor!,
                duration: const Duration(milliseconds: 400),
                active: settings.artistSortReversed.value,
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
  final RxBase<bool>? activeRx;
  final void Function()? onTap;
  final String? title;
  final String subtitle;
  final IconData? icon;
  final Color? tileColor;
  final Widget? titleWidget;
  final Widget? leading;
  final double? iconSize;
  final bool dense;
  final bool expanded;
  final double borderRadius;

  const ListTileWithCheckMark({
    super.key,
    this.active = false,
    this.activeRx,
    this.onTap,
    this.title,
    this.subtitle = '',
    this.icon = Broken.arrange_circle,
    this.tileColor,
    this.titleWidget,
    this.leading,
    this.iconSize,
    this.dense = false,
    this.expanded = true,
    this.borderRadius = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final tileAlpha = context.isDarkMode ? 5 : 20;
    final br = BorderRadius.circular(borderRadius.multipliedRadius);
    final titleWidgetFinal = Padding(
      padding: EdgeInsets.symmetric(horizontal: dense ? 10.0 : 14.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget ??
              Text(
                title ?? lang.REVERSE_ORDER,
                style: textTheme.displayMedium,
              ),
          if (subtitle != '')
            Text(
              subtitle,
              style: textTheme.displaySmall,
            )
        ],
      ),
    );
    return Material(
        borderRadius: br,
        color: tileColor ?? Color.alphaBlend(theme.colorScheme.onSurface.withAlpha(tileAlpha), theme.cardTheme.color!),
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (leading != null)
                  leading!
                else if (icon != null)
                  Icon(
                    icon,
                    size: iconSize,
                  ),
                expanded
                    ? Expanded(
                        child: titleWidgetFinal,
                      )
                    : Flexible(
                        child: titleWidgetFinal,
                      ),
                activeRx != null
                    ? ObxO(
                        rx: activeRx!,
                        builder: (context, active) => NamidaCheckMark(
                          size: 18.0,
                          active: active,
                        ),
                      )
                    : NamidaCheckMark(
                        size: 18.0,
                        active: active,
                      )
              ],
            ),
          ),
        ));
  }
}

class NamidaCheckMark extends StatelessWidget {
  final double size;
  final bool active;
  final Color? activeColor;
  final Color? inactiveColor;

  const NamidaCheckMark({
    super.key,
    required this.size,
    required this.active,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SizedBox(
      width: size,
      height: size,
      child: CheckMark(
        strokeWidth: 2,
        activeColor: activeColor ?? theme.listTileTheme.iconColor!,
        inactiveColor: inactiveColor ?? theme.listTileTheme.iconColor!,
        duration: const Duration(milliseconds: 400),
        active: active,
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
  final Widget? subtitle;
  final String? subtitleText;
  final Color? textColor;
  final Color? textColorScheme;
  final List<Widget> children;
  final EdgeInsetsGeometry? childrenPadding;
  final bool initiallyExpanded;
  final Widget? trailing;
  final ValueChanged? onExpansionChanged;
  final bool normalRightPadding;
  final Color? bgColor;
  final bool bigahh;
  final bool compact;
  final bool borderless;

  const NamidaExpansionTile({
    super.key,
    this.icon,
    this.iconColor,
    this.leading,
    this.trailingIcon = Broken.arrow_down_2,
    this.trailingIconSize = 20.0,
    required this.titleText,
    this.subtitle,
    this.subtitleText,
    this.textColor,
    this.textColorScheme,
    this.children = const <Widget>[],
    this.childrenPadding = EdgeInsets.zero,
    this.initiallyExpanded = false,
    this.trailing,
    this.onExpansionChanged,
    this.normalRightPadding = false,
    this.bgColor,
    this.bigahh = false,
    this.compact = true,
    this.borderless = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return ListTileTheme(
      dense: !bigahh,
      child: ExpansionTile(
        collapsedShape: borderless ? const Border() : null,
        shape: borderless ? const Border() : null,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.comfortable,
        controlAffinity: ListTileControlAffinity.trailing,
        collapsedBackgroundColor: bgColor,
        backgroundColor: bgColor,
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: onExpansionChanged,
        expandedAlignment: Alignment.centerLeft,
        tilePadding: EdgeInsets.only(left: 16.0, right: normalRightPadding ? 16.0 : 12.0),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titleText,
              style: textTheme.displayMedium?.copyWith(
                color: textColor ??
                    (textColorScheme == null
                        ? null
                        : Color.alphaBlend(
                            textColorScheme!.withAlpha(40),
                            textTheme.displayMedium!.color!,
                          )),
              ),
            ),
            if (subtitle != null)
              subtitle!
            else if (subtitleText != null)
              Text(
                subtitleText!,
                style: textTheme.displaySmall,
              ),
          ],
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
    return NamidaButton(
      icon: Broken.add,
      text: lang.CREATE,
      onPressed: () => showSettingDialogWithTextField(
        title: lang.CREATE_NEW_PLAYLIST,
        addNewPlaylist: true,
      ),
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
  final bool enableSecondaryTap;

  const MoreIcon({
    super.key,
    this.onPressed,
    this.rotated = true,
    this.padding = 1.0,
    this.iconColor,
    this.iconSize = 18.0,
    this.onLongPress,
    this.enableSecondaryTap = true,
  });

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: rotated ? 1 : 0,
      child: NamidaInkWell(
        borderRadius: 4.0,
        onTap: onPressed,
        onLongPress: onLongPress,
        enableSecondaryTap: enableSecondaryTap,
        padding: EdgeInsets.all(padding),
        child: Icon(
          Broken.more,
          size: iconSize,
          color: iconColor,
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
  final Color? shadowColor;
  final double? iconSize;
  final double? secondaryIconSize;
  final double blurRadius;
  final Widget? smallChild;
  final bool disableColor;
  final bool delightenColors;
  final double margin;

  const StackedIcon({
    super.key,
    required this.baseIcon,
    this.secondaryIcon,
    this.baseIconColor,
    this.secondaryIconColor,
    this.shadowColor,
    this.secondaryText,
    this.iconSize,
    this.secondaryIconSize = 14.0,
    this.blurRadius = 3.0,
    this.smallChild,
    this.disableColor = false,
    this.delightenColors = false,
    this.margin = -2.0,
  });
  Color? _getColory(BuildContext context, Color? c) {
    return disableColor
        ? null
        : delightenColors && c != null
            ? context.defaultIconColor(c)
            : c ?? context.defaultIconColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          baseIcon,
          color: _getColory(context, baseIconColor),
          size: iconSize,
        ),
        Positioned(
          bottom: margin,
          right: margin,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: shadowColor ?? theme.scaffoldBackgroundColor,
                  spreadRadius: 0,
                  blurRadius: blurRadius,
                ),
              ],
            ),
            child: smallChild ??
                (secondaryText != null
                    ? Text(
                        secondaryText!,
                        style: textTheme.displaySmall?.copyWith(color: _getColory(context, secondaryIconColor)),
                      )
                    : Icon(
                        secondaryIcon,
                        size: secondaryIconSize,
                        color: _getColory(context, secondaryIconColor),
                      )),
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

class CancelButton extends StatelessWidget {
  final void Function()? onPressed;
  const CancelButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed ?? () => NamidaNavigator.inst.closeDialog(),
      child: NamidaButtonText(lang.CANCEL),
    );
  }
}

class DoneButton extends StatelessWidget {
  final bool enabled;
  final void Function()? additional;
  const DoneButton({super.key, this.enabled = true, this.additional});

  @override
  Widget build(BuildContext context) {
    return NamidaButton(
      enabled: enabled,
      text: lang.DONE,
      onPressed: () {
        NamidaNavigator.inst.closeDialog();
        if (additional != null) additional!();
      },
    );
  }
}

class CollapsedSettingTileWidget extends StatelessWidget {
  final Color? bgColor;
  const CollapsedSettingTileWidget({super.key, this.bgColor});

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return ObxO(
      rx: settings.useSettingCollapsedTiles,
      builder: (context, useSettingCollapsedTiles) => CustomSwitchListTile(
        bgColor: bgColor,
        icon: Broken.archive,
        title: lang.USE_COLLAPSED_SETTING_TILES,
        value: useSettingCollapsedTiles,
        onChanged: (isTrue) async {
          settings.save(useSettingCollapsedTiles: !isTrue);
          await NamidaNavigator.inst.popPage();
          const SettingsPage().navigate();
        },
      ),
    );
  }
}

class AboutPageTileWidget extends StatelessWidget {
  const AboutPageTileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return CustomCollapsedListTile(
      title: lang.ABOUT,
      subtitle: null,
      icon: Broken.info_circle,
      page: null,
      rawPage: () => const AboutPage(),
    );
  }
}

class NamidaBlurryContainer extends StatelessWidget {
  final Widget child;
  final void Function()? onTap;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  const NamidaBlurryContainer({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.width,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final blurredAlphaLight = context.isDarkMode ? 60 : 140;
    final blurEnabled = settings.enableBlurEffect.value;

    Widget? finalChild = ColoredBox(
      color: theme.cardColor.withAlpha(blurEnabled ? blurredAlphaLight : 220),
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    if (blurEnabled) {
      finalChild = NamidaBgBlur(
        blur: 5.0,
        child: finalChild,
      );
    }

    final brr = borderRadius ?? BorderRadius.only(bottomLeft: Radius.circular(8.0.multipliedRadius));

    if (blurEnabled || brr != BorderRadius.zero) {
      finalChild = ClipPath(
        clipper: DecorationClipper(
          decoration: BoxDecoration(
            borderRadius: brr,
          ),
        ),
        child: finalChild,
      );
    }

    if (onTap != null) {
      finalChild = InkWell(
        onTap: onTap,
        child: finalChild,
      );
    }
    return finalChild;
  }
}

class ContainerWithBorder extends StatelessWidget {
  final Widget? child;
  final Color? borderColor;
  const ContainerWithBorder({super.key, this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: borderColor ?? theme.cardColor.withAlpha(160),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(60),
            blurRadius: 4,
            offset: const Offset(0, 2.0),
          )
        ],
      ),
      child: Padding(
        padding: EdgeInsetsGeometry.all(3.0),
        child: child,
      ),
    );
  }
}

class NamidaWheelSlider extends StatefulWidget {
  final double width;
  final double perspective;
  final int max;
  final int min;
  final int stepper;
  final int multiplier;
  final int initValue;
  final bool extraValue;
  final double itemSize;
  final double squeeze;
  final String? text;
  final String? topText;
  final double? textPadding;
  final double? topTextPadding;
  final void Function(int val) onValueChanged;

  const NamidaWheelSlider({
    super.key,
    this.width = 80,
    this.perspective = 0.01,
    required int initValue,
    this.extraValue = false,
    this.min = 0,
    required this.max,
    this.stepper = 1,
    this.multiplier = 1,
    required this.onValueChanged,
    this.text,
    this.topText,
    this.textPadding = 2.0,
    this.topTextPadding = 12.0,
  })  : itemSize = 8,
        squeeze = 1.8,
        initValue = initValue < min ? max + 1 : initValue - min,
        assert(min < max, 'min should be less than max');

  @override
  State<NamidaWheelSlider> createState() => _NamidaWheelSliderState();
}

class _NamidaWheelSliderState extends State<NamidaWheelSlider> {
  late final _controller = FixedExtentScrollController(initialItem: (widget.initValue / widget.stepper / widget.multiplier).round());

  static bool _isMultipleOfFive(int n) => n % 5 == 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final totalCount = ((widget.max - widget.min) / widget.stepper).round() + (widget.extraValue ? 1 : 0);

    return SizedBox(
      width: widget.width,
      child: Column(
        children: [
          if (widget.topText != null) ...[
            Text(
              widget.topText!,
              style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(
              height: widget.topTextPadding,
            ),
          ],
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 38.0,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: ListWheelScrollView.useDelegate(
                    controller: _controller,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: totalCount + 1,
                      builder: (context, index) {
                        final multipleOfFive = _isMultipleOfFive(index);
                        return Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: multipleOfFive ? 35.0 : 20.0,
                            height: 1.5,
                            child: SizedBox(
                              width: multipleOfFive ? 35.0 : 20.0,
                              height: 1.5,
                              child: ColoredBox(
                                color: theme.iconTheme.color!,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    onSelectedItemChanged: (val) {
                      int finalValue = (val * widget.stepper * widget.multiplier + widget.min);
                      if ((widget.extraValue && finalValue > widget.max)) finalValue = -1;
                      widget.onValueChanged(finalValue);
                      HapticFeedback.lightImpact();
                    },
                    perspective: widget.perspective,
                    squeeze: widget.squeeze,
                    useMagnifier: true,
                    itemExtent: widget.itemSize,
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: true,
                child: SizedBox(
                  height: 38.0,
                  width: 2.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4.0.multipliedRadius),
                      color: theme.listTileTheme.textColor!,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (widget.text != null) ...[
            SizedBox(
              height: widget.textPadding,
            ),
            FittedBox(
              child: Text(
                widget.text!,
                style: TextStyle(
                  color: textTheme.displaySmall?.color,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class NamidaLoadingController {
  final void Function() startLoading;
  final void Function() stopLoading;
  bool isLoading;

  NamidaLoadingController({
    required this.startLoading,
    required this.stopLoading,
    required this.isLoading,
  });
}

class NamidaLoadingSwitcher extends StatefulWidget {
  final Widget Function(NamidaLoadingController loadingController) builder;
  final double? size;
  final bool showLoading;

  const NamidaLoadingSwitcher({
    super.key,
    required this.builder,
    this.size,
    this.showLoading = true,
  });

  @override
  State<NamidaLoadingSwitcher> createState() => _NamidaLoadingSwitcherState();
}

class _NamidaLoadingSwitcherState extends State<NamidaLoadingSwitcher> {
  late final loadingController = NamidaLoadingController(
    startLoading: _startLoading,
    stopLoading: _stopLoading,
    isLoading: false,
  );

  void _startLoading() {
    if (mounted) setState(() => loadingController.isLoading = true);
  }

  void _stopLoading() {
    if (mounted) setState(() => loadingController.isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(loadingController);
    final isLoading = loadingController.isLoading;
    return Stack(
      fit: StackFit.loose,
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          opacity: isLoading ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: child,
        ),
        if (isLoading && widget.showLoading)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: isLoading ? 0.8 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: widget.size == null ? const CircularProgressIndicator(strokeWidth: 4.0) : const CircularProgressIndicator(strokeWidth: 2.0),
              ),
            ),
          ),
      ],
    );
  }
}

class NamidaRawLikeButton extends StatelessWidget {
  final double size;
  final Color? enabledColor;
  final Color? disabledColor;
  final bool? isLiked;
  final EdgeInsetsGeometry padding;
  final Future<bool> Function(bool isLiked)? onTap;
  final IconData likedIcon;
  final IconData normalIcon;

  const NamidaRawLikeButton({
    super.key,
    this.size = 24.0,
    this.enabledColor,
    this.disabledColor,
    required this.isLiked,
    required this.onTap,
    this.padding = EdgeInsets.zero,
    this.likedIcon = Broken.heart_filled,
    this.normalIcon = Broken.heart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: LikeButton(
        size: size,
        padding: padding,
        likeCountPadding: EdgeInsets.zero,
        bubblesColor: BubblesColor(
          dotPrimaryColor: theme.colorScheme.primary,
          dotSecondaryColor: theme.colorScheme.primaryContainer,
        ),
        circleColor: CircleColor(
          start: theme.colorScheme.tertiary,
          end: theme.colorScheme.tertiary,
        ),
        isLiked: isLiked,
        onTap: onTap,
        likeBuilder: (value) => value
            ? Icon(
                likedIcon,
                color: enabledColor ?? theme.colorScheme.primary,
                size: size,
              )
            : Icon(
                normalIcon,
                color: disabledColor ?? theme.colorScheme.secondary,
                size: size,
              ),
      ),
    );
  }
}

class NamidaLocalLikeButton extends StatelessWidget {
  final Track track;
  final double size;
  final Color? color;

  const NamidaLocalLikeButton({
    super.key,
    required this.track,
    this.size = 30.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ObxOClass(
      rx: PlaylistController.inst.favouritesPlaylist,
      builder: (context, favouritesPlaylist) => NamidaRawLikeButton(
        size: size,
        enabledColor: color,
        disabledColor: color,
        isLiked: favouritesPlaylist.isSubItemFavourite(track),
        onTap: (isLiked) async => PlaylistController.inst.favouriteButtonOnPressed(track),
      ),
    );
  }
}

class NamidaIconButton extends StatefulWidget {
  final EdgeInsetsGeometry? padding;
  final double horizontalPadding;
  final double verticalPadding;
  final double? iconSize;
  final IconData? icon;
  final Color? iconColor;
  final void Function()? onPressed;
  final void Function(LongPressStartDetails details)? onLongPressStart;
  final void Function()? onLongPressFinish;
  final void Function()? onLongPress;
  final String Function()? tooltip;
  final bool disableColor;
  final Widget? child;

  const NamidaIconButton({
    super.key,
    this.padding,
    this.horizontalPadding = 8.0,
    this.verticalPadding = 0.0,
    required this.icon,
    this.onPressed,
    this.onLongPressStart,
    this.onLongPressFinish,
    this.onLongPress,
    this.iconSize,
    this.iconColor,
    this.tooltip,
    this.disableColor = false,
    this.child,
  });

  @override
  State<NamidaIconButton> createState() => _NamidaIconButtonState();
}

class _NamidaIconButtonState extends State<NamidaIconButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return NamidaTooltip(
      message: widget.tooltip,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.translucent,
        cursor: widget.onPressed == null && widget.onLongPress == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (value) => setState(() => isPressed = true),
          onTapUp: (value) => setState(() => isPressed = false),
          onTapCancel: () => setState(() => isPressed = false),
          onTap: widget.onPressed,
          onLongPressStart: widget.onLongPressStart,
          onLongPressEnd: widget.onLongPressFinish == null ? null : (details) => widget.onLongPressFinish!(),
          onLongPressCancel: widget.onLongPressFinish,
          onLongPress: widget.onLongPress,
          onLongPressUp: widget.onLongPressFinish,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isPressed ? 0.5 : 1.0,
            child: Padding(
              padding: widget.padding ?? EdgeInsets.symmetric(horizontal: widget.horizontalPadding, vertical: widget.verticalPadding),
              child: widget.child ??
                  Icon(
                    widget.icon,
                    size: widget.iconSize,
                    color: widget.disableColor ? null : (widget.iconColor ?? context.theme.colorScheme.secondary),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class NamidaAppBarIcon extends StatelessWidget {
  final IconData icon;
  final Widget? child;
  final void Function()? onPressed;
  final String Function()? tooltip;

  const NamidaAppBarIcon({
    super.key,
    required this.icon,
    this.child,
    this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaIconButton(
      verticalPadding: 8.0,
      horizontalPadding: 6.0,
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      child: child,
    );
  }
}

class NamidaPartyContainer extends StatelessWidget {
  final double spreadRadiusMultiplier;
  final double? width;
  final double? height;
  const NamidaPartyContainer({
    super.key,
    this.spreadRadiusMultiplier = 1.0,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (!settings.enablePartyModeColorSwap.value) {
      return ObxO(
        rx: Player.inst.nowPlayingPosition,
        builder: (context, nowPlayingPosition) {
          final finalScale = WaveformController.inst.getCurrentAnimatingScale(nowPlayingPosition);
          return AnimatedSizedBox(
            duration: const Duration(milliseconds: 400),
            height: height ?? context.height,
            width: width ?? context.width,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: CurrentColor.inst.miniplayerColor.withAlpha(150),
                  spreadRadius: 150 * finalScale * spreadRadiusMultiplier,
                  blurRadius: 10 + (200 * finalScale),
                ),
              ],
            ),
          );
        },
      );
    } else {
      return ObxO(
        rx: Player.inst.nowPlayingPosition,
        builder: (context, nowPlayingPosition) {
          final finalScale = WaveformController.inst.getCurrentAnimatingScale(nowPlayingPosition);
          return height != null
              ? ObxO(
                  rx: CurrentColor.inst.paletteFirstHalf,
                  builder: (context, firstHalf) => Row(
                    children: [
                      ...firstHalf.map(
                        (e) => AnimatedSizedBox(
                          duration: const Duration(milliseconds: 400),
                          height: height,
                          width: width ?? Dimensions.inst.miniplayerMaxWidth / firstHalf.length,
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
                      ),
                    ],
                  ),
                )
              : ObxO(
                  rx: CurrentColor.inst.paletteSecondHalf,
                  builder: (context, secondHalf) => Column(
                    children: [
                      ...secondHalf.map(
                        (e) => AnimatedSizedBox(
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
                      ),
                    ],
                  ),
                );
        },
      );
    }
  }
}

class SubpageInfoContainer extends StatelessWidget {
  final double maxWidth;
  final String title;
  final String subtitle;
  final String thirdLineText;
  final double? height;
  final double topPadding;
  final double bottomPadding;
  final Widget Function(double size) imageBuilder;
  final Iterable<Selectable> Function() tracksFn;
  final QueueSource source;
  final String heroTag;

  const SubpageInfoContainer({
    super.key,
    required this.maxWidth,
    required this.title,
    required this.subtitle,
    this.thirdLineText = '',
    this.height,
    required this.imageBuilder,
    required this.tracksFn,
    this.topPadding = 16.0,
    this.bottomPadding = 16.0,
    required this.source,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    const textHeroEnabled = false;
    const pauseHero = 'kururing';
    final showSubpageInfoAtSide = Dimensions.inst.showSubpageInfoAtSideContext(context);

    return Container(
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 12.0, left: 12.0, right: 12.0, bottom: 4.0),
      margin: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      height: height,
      child: LayoutWidthHeightProvider(
        builder: (context, maxWidth, maxHeight) {
          maxWidth = maxWidth.withMaximum(this.maxWidth);

          double imageMaxWidth;
          double infoMaxWidth;

          if (showSubpageInfoAtSide) {
            imageMaxWidth = maxWidth;
            infoMaxWidth = maxWidth;
          } else {
            imageMaxWidth = (maxWidth * 0.4).withMaximum(maxHeight * 0.3);
            infoMaxWidth = maxWidth - imageMaxWidth;
          }

          final imageWidget = imageBuilder(imageMaxWidth);

          double getFontSize(double p, double min, double max) => ((infoMaxWidth * 0.2).withMaximum(maxHeight * 0.1) * p).clampDouble(min, max);

          final textAndButtonsWidget = Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 18.0,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 14.0),
                child: NamidaHero(
                  enabled: textHeroEnabled,
                  tag: '${pauseHero}line1_$heroTag',
                  child: showSubpageInfoAtSide
                      ? Text(
                          title,
                          style: textTheme.displayLarge?.copyWith(fontSize: getFontSize(0.5, 10.0, 32.0)),
                          softWrap: true,
                        )
                      : Text(
                          title,
                          style: textTheme.displayLarge?.copyWith(fontSize: getFontSize(0.4, 10.0, 32.0)),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
              const SizedBox(
                height: 2.0,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 14.0),
                child: NamidaHero(
                  enabled: textHeroEnabled,
                  tag: '${pauseHero}line2_$heroTag',
                  child: Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: textTheme.displayMedium?.copyWith(fontSize: getFontSize(0.28, 10.0, 24.0)),
                  ),
                ),
              ),
              if (thirdLineText != '') ...[
                const SizedBox(
                  height: 2.0,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 14.0),
                  child: NamidaHero(
                    enabled: textHeroEnabled,
                    tag: '${pauseHero}line3_$heroTag',
                    child: Text(
                      thirdLineText,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: textTheme.displaySmall?.copyWith(fontSize: getFontSize(0.25, 10.0, 22.0)),
                    ),
                  ),
                ),
              ],
              const SizedBox(
                height: 18.0,
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: infoMaxWidth * 0.85),
                child: FittedBox(
                  alignment: Alignment.topLeft,
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 6.0),
                      NamidaButton(
                        icon: Broken.shuffle,
                        onPressed: () => Player.inst.playOrPause(
                          0,
                          tracksFn(),
                          source,
                          shuffle: true,
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      ElevatedButton.icon(
                        onPressed: () => Player.inst.addToQueue(tracksFn()),
                        icon: const StackedIcon(
                          disableColor: true,
                          baseIcon: Broken.play,
                          secondaryIcon: Broken.add_circle,
                          secondaryIconSize: 13.0,
                        ),
                        label: Text(
                          lang.PLAY_LAST,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: getFontSize(0.3, 10.0, 20.0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6.0),
                    ],
                  ),
                ),
              )
            ],
          );

          return showSubpageInfoAtSide
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: FittedBox(
                        alignment: Alignment.topLeft,
                        fit: BoxFit.scaleDown,
                        child: imageWidget,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: textAndButtonsWidget,
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: imageMaxWidth),
                      child: FittedBox(
                        alignment: Alignment.topLeft,
                        fit: BoxFit.scaleDown,
                        child: imageWidget,
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: infoMaxWidth),
                      child: textAndButtonsWidget,
                    ),
                  ],
                );
        },
      ),
    );
  }
}

class AnimatingTile extends StatelessWidget {
  final int position;
  final Widget child;
  final bool shouldAnimate;
  final Duration duration;

  const AnimatingTile({
    super.key,
    required this.position,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.shouldAnimate = true,
  });

  @override
  Widget build(BuildContext context) {
    return shouldAnimate
        ? AnimationConfiguration.staggeredList(
            position: position,
            duration: duration,
            delay: const Duration(milliseconds: 50),
            child: SlideAnimation(
              verticalOffset: 25.0,
              child: FadeInAnimation(
                duration: duration,
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

  const AnimatingGrid({
    super.key,
    required this.position,
    required this.columnCount,
    required this.child,
    this.shouldAnimate = true,
  });

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
  final double? width;
  final double? height;
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
    this.width,
    this.height,
    this.margin = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.5),
    this.padding = const EdgeInsets.symmetric(vertical: 11.0, horizontal: 10.0),
    this.isCentered = false,
    this.iconSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return NamidaInkWell(
      animationDurationMS: 200,
      alignment: Alignment.center,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: enabled ? CurrentColor.inst.color : theme.cardColor,
        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: CurrentColor.inst.color.withAlpha(100),
                  spreadRadius: 0.2,
                  blurRadius: 8.0,
                  offset: const Offset(0.0, 4.0),
                ),
              ]
            : null,
      ),
      margin: margin,
      padding: padding,
      onTap: onTap,
      borderRadius: 8.0,
      child: Row(
        mainAxisAlignment: isCentered ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: enabled ? Colors.white.withAlpha(200) : null,
            size: iconSize,
          ),
          if (title != '') const SizedBox(width: 12.0),
          if (title != '')
            Expanded(
              child: Text(
                title,
                style: textTheme.displayMedium?.copyWith(
                  color: enabled ? Colors.white.withAlpha(200) : null,
                  fontSize: 15.0,
                ),
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
        ],
      ),
    );
  }
}

class SearchPageTitleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final Widget? subtitleWidget;
  final String? buttonText;
  final IconData? buttonIcon;
  final void Function()? onPressed;
  const SearchPageTitleRow({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.icon,
    this.trailing,
    this.subtitleWidget,
    this.buttonText,
    this.buttonIcon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Row(
      children: [
        const SizedBox(width: 16.0),
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.displayLarge?.copyWith(fontSize: 15.5),
                ),
                if (subtitleWidget != null) subtitleWidget!,
                if (subtitle != '')
                  Text(
                    subtitle,
                    style: textTheme.displaySmall,
                  ),
              ],
            ),
          ],
        ),
        const Spacer(),
        trailing ??
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: context.theme.listTileTheme.iconColor),
              icon: Icon(buttonIcon, size: 20.0),
              label: NamidaButtonText(buttonText ?? ''),
              onPressed: onPressed,
            ),
        const SizedBox(width: 8.0),
      ],
    );
  }
}

class NamidaLogoContainer extends StatelessWidget {
  final double? width, height;
  final double iconSize;
  final bool displayText;
  final bool lighterShadow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? afterTap;

  const NamidaLogoContainer({
    super.key,
    this.height = 54.0,
    this.width,
    this.iconSize = 40.0,
    this.displayText = true,
    this.lighterShadow = false,
    this.padding,
    this.margin,
    this.afterTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final bgColor = context.isDarkMode ? const Color(0xd2262729) : const Color(0xd83c3f46);
    return NamidaInkWell(
      onTap: () {
        if (NamidaNavigator.inst.currentRoute?.route != RouteType.PAGE_about) {
          const AboutPage().navigate();
        }
        afterTap?.call();
      },
      animationDurationMS: 300,
      alignment: Alignment.center,
      height: height,
      width: width,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 12.0).add(const EdgeInsets.only(top: 16.0, bottom: 8.0)),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
      bgColor: bgColor,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.0.multipliedRadius),
        boxShadow: [
          lighterShadow
              ? BoxShadow(
                  color: bgColor.withAlpha(context.isDarkMode ? 30 : 80),
                  spreadRadius: 0.1,
                  blurRadius: 6.0,
                  offset: const Offset(0.0, 2.0),
                )
              : BoxShadow(
                  color: bgColor.withAlpha(context.isDarkMode ? 40 : 100),
                  spreadRadius: 0.2,
                  blurRadius: 8.0,
                  offset: const Offset(0.0, 4.0),
                ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            NamidaAppIcons.monet.assetPath,
            width: iconSize,
            height: iconSize,
            cacheHeight: 240,
            cacheWidth: 240,
            alignment: Alignment.center,
          ),
          if (displayText) ...[
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                'Namida',
                style: textTheme.displayLarge?.copyWith(
                  color: Color.alphaBlend(bgColor.withAlpha(50), Colors.white),
                  fontSize: 17.5,
                ),
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NamidaContainerDivider extends StatelessWidget {
  final double? width;
  final double height;
  final Color? color;
  final Color? colorForce;
  final EdgeInsetsGeometry? margin;

  const NamidaContainerDivider({
    super.key,
    this.width,
    this.height = 2.0,
    this.color,
    this.margin,
    this.colorForce,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: colorForce ?? (color ?? context.theme.dividerColor).withAlpha(namida.isDarkMode ? 100 : 20),
        borderRadius: BorderRadius.circular(18.0.multipliedRadius),
      ),
    );
  }
}

class FadeDismissible extends StatefulWidget {
  final Widget child;
  final void Function(DismissDirection direction) onDismissed;
  final void Function(DragStartDetails details)? onDismissStart;
  final void Function(DragEndDetails details)? onDismissEnd;
  final void Function(DragEndDetails details)? onDismissCancel;
  final DismissDirection direction;
  final Duration dismissDuration;
  final Duration settleDuration;
  final double dismissThreshold;
  final double dismissRangeStart;
  final double dismissRangeEnd;
  final Curve dismissCurve;
  final Curve settleCurve;
  final bool Function()? draggable;
  final RxBase<bool>? draggableRx;
  final Widget? onTopWidget;
  final bool removeOnDismiss;
  final Widget Function()? leftWidget;
  final Widget Function()? rightWidget;

  /// value multiplied by the animation.
  /// 0.0 means top friction, 1.0 means normal friction & >1 means more lose friction
  final double friction;

  const FadeDismissible({
    required super.key,
    required this.child,
    required this.onDismissed,
    this.onDismissStart,
    this.onDismissEnd,
    this.onDismissCancel,
    this.direction = DismissDirection.horizontal,
    this.dismissDuration = const Duration(milliseconds: 300),
    this.settleDuration = const Duration(milliseconds: 300),
    this.dismissThreshold = 0.8,
    this.dismissRangeStart = 0.1,
    this.dismissRangeEnd = 0.9,
    this.dismissCurve = Curves.fastOutSlowIn,
    this.settleCurve = Curves.easeOutQuart,
    this.draggable,
    this.draggableRx,
    this.onTopWidget,
    this.removeOnDismiss = true,
    this.leftWidget,
    this.rightWidget,
    this.friction = 1.0,
  });

  static bool isDismissing = false;

  @override
  State<FadeDismissible> createState() => _FadeDismissibleState();
}

class _FadeDismissibleState extends State<FadeDismissible> with SingleTickerProviderStateMixin {
  double get progress => _animation.value.abs();

  late final _animation = AnimationController(
    vsync: this,
    lowerBound: -1,
    upperBound: 1,
    value: 0,
  );

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  double _dragged = 0;

  bool _draggable = true;
  bool _inDismissRange = true;
  bool? _canSwipeInternal; // calculate for direction once to allow swiping back.

  void calculateInDismissRange(double positionDx, double maxWidth) {
    final percentage = positionDx / maxWidth;
    _inDismissRange = percentage >= widget.dismissRangeStart && percentage <= widget.dismissRangeEnd;
  }

  Future<void> _animateDismiss(double to, {required bool faster}) async {
    await _animation.animateTo(to, duration: faster ? widget.dismissDuration * 0.5 : widget.dismissDuration, curve: faster ? Curves.linear : widget.dismissCurve);
  }

  Future<void> _dismissToRight(DragEndDetails d, {bool faster = false}) async {
    if (widget.removeOnDismiss) {
      await _animateDismiss(1, faster: faster);
      widget.onDismissed(DismissDirection.startToEnd);
      if (widget.onDismissEnd != null) widget.onDismissEnd!(d);
      _animation.animateTo(0, duration: Duration.zero); // fixes rendering issue
    } else {
      widget.onDismissed(DismissDirection.startToEnd);
      await _resetToMiddle(d);
    }
  }

  Future<void> _dismissToLeft(DragEndDetails d, {bool faster = false}) async {
    if (widget.removeOnDismiss) {
      await _animateDismiss(-1, faster: faster);
      widget.onDismissed(DismissDirection.endToStart);
      if (widget.onDismissEnd != null) widget.onDismissEnd!(d);
      _animation.animateTo(0, duration: Duration.zero); // fixes rendering issue
    } else {
      widget.onDismissed(DismissDirection.endToStart);
      await _resetToMiddle(d);
    }
  }

  Future<void> _resetToMiddle(DragEndDetails d) async {
    if (widget.onDismissCancel != null) widget.onDismissCancel!(d);
    await _animation.animateTo(0, duration: widget.settleDuration, curve: widget.settleCurve);
  }

  Widget buildChild(bool draggable, Widget child, double maxWidth, Animation<double> fadeAnimation) {
    return HorizontalDragDetector(
      onStart: !draggable
          ? null
          : (d) {
              if (PullToRefreshMixin.isPulling) return;
              FadeDismissible.isDismissing = true;
              if (widget.onDismissStart != null) widget.onDismissStart!(d);
              calculateInDismissRange(d.localPosition.dx, maxWidth);
              if (widget.draggable != null) _draggable = widget.draggable!();
            },
      onUpdate: !draggable
          ? null
          : (d) {
              if (!_draggable) return;
              if (!_inDismissRange) return;
              if (PullToRefreshMixin.isPulling) return;
              if (_canSwipeInternal == null) {
                bool canSwipe = true;
                if (d.delta.dx.isNegative) {
                  if (widget.direction == DismissDirection.startToEnd) canSwipe = false;
                } else {
                  if (widget.direction == DismissDirection.endToStart) canSwipe = false;
                }
                if (canSwipe != _canSwipeInternal) _canSwipeInternal = canSwipe;
              }
              if (_canSwipeInternal == false) return;

              _dragged += d.delta.dx;
              _animation.animateTo(_dragged / maxWidth, duration: Duration.zero);
            },
      onEnd: !draggable
          ? null
          : (d) {
              if (PullToRefreshMixin.isPulling) return;
              FadeDismissible.isDismissing = false;
              _canSwipeInternal = null;

              final velocity = d.velocity.pixelsPerSecond.dx;
              if (velocity > 800) {
                _dismissToRight(d, faster: true);
              } else if (velocity < -800) {
                _dismissToLeft(d, faster: true);
              } else if (progress > widget.dismissThreshold) {
                if (_animation.value < 0) {
                  _dismissToLeft(d);
                } else {
                  _dismissToRight(d);
                }
              } else {
                _resetToMiddle(d);
              }
              _dragged = 0;
            },
      onCancel: () {
        FadeDismissible.isDismissing = false;
      },
      child: AnimatedBuilder(
        animation: _animation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: child,
        ),
        builder: (context, child) {
          final p = _animation.value;
          // if (p == 0) return child!; // causes unecessary rebuilds
          return Transform.translate(
            offset: p == 0 ? Offset.zero : Offset(p * widget.friction * maxWidth, 0),
            child: child!,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = Dimensions.inst.availableAppContentWidth;
    final child = widget.onTopWidget != null
        ? Stack(
            children: [
              widget.child,
              widget.onTopWidget!,
            ],
          )
        : widget.child;

    final fadeAnimation = _animation.drive(
      widget.friction == 1.0
          ? Animatable.fromCallback((value) => 1 - value.abs())
          : Animatable.fromCallback(
              (value) => 1 - (value * widget.friction).abs().clampDouble(0, 1),
            ),
    );
    Widget dismissibleChild = widget.draggableRx != null
        ? ObxO(
            rx: widget.draggableRx!,
            builder: (context, value) => buildChild(value && widget.direction != DismissDirection.none, child, maxWidth, fadeAnimation),
          )
        : buildChild(_draggable && widget.direction != DismissDirection.none, child, maxWidth, fadeAnimation);

    if (widget.leftWidget != null || widget.rightWidget != null) {
      final reverseFadeAnimation = ReverseAnimation(fadeAnimation);
      Widget? leftWidget;
      Widget? rightWidget;
      dismissibleChild = Stack(
        alignment: AlignmentGeometry.center,
        children: [
          if (widget.leftWidget != null)
            Positioned(
              left: 0.0,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  final p = _animation.value;
                  if (p <= 0) return const SizedBox();
                  return leftWidget ??= FadeTransition(
                    opacity: reverseFadeAnimation,
                    child: widget.leftWidget!(),
                  );
                },
              ),
            ),
          if (widget.rightWidget != null)
            Positioned(
              right: 0.0,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  final p = _animation.value;
                  if (p >= 0) return const SizedBox();
                  return rightWidget ??= FadeTransition(
                    opacity: reverseFadeAnimation,
                    child: widget.rightWidget!(),
                  );
                },
              ),
            ),
          dismissibleChild,
        ],
      );
    }
    return dismissibleChild;
  }
}

class FadeIgnoreTransition extends StatefulWidget {
  /// Wether to completely replace the [child] with a [SizedBox], instead of just using [IgnorePointer].
  final bool completelyKillWhenPossible;
  final Animation<double> opacity;
  final Widget child;

  const FadeIgnoreTransition({
    super.key,
    this.completelyKillWhenPossible = false,
    required this.opacity,
    required this.child,
  });

  @override
  State<FadeIgnoreTransition> createState() => _FadeIgnoreTransitionState();
}

class _FadeIgnoreTransitionState extends State<FadeIgnoreTransition> {
  bool _ignoring = false;

  @override
  void initState() {
    super.initState();
    widget.opacity.addListener(_checkOpacity);
    _checkOpacity();
  }

  @override
  void dispose() {
    widget.opacity.removeListener(_checkOpacity);
    super.dispose();
  }

  void _checkOpacity() {
    final shouldIgnore = widget.opacity.value <= 0.01;
    if (_ignoring != shouldIgnore) {
      setState(() => _ignoring = shouldIgnore);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.completelyKillWhenPossible && _ignoring) return const SizedBox();
    return IgnorePointer(
      ignoring: _ignoring,
      child: FadeTransition(
        opacity: widget.opacity,
        child: widget.child,
      ),
    );
  }
}

class NamidaSelectableAutoLinkText extends StatelessWidget {
  final String text;
  final double fontScale;
  const NamidaSelectableAutoLinkText({super.key, required this.text, this.fontScale = 1.0});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return SelectableAutoLinkText(
      text,
      style: textTheme.displayMedium?.copyWith(
        fontSize: 13.5 * fontScale,
      ),
      linkStyle: textTheme.displayMedium?.copyWith(
        color: theme.colorScheme.primary.withAlpha(210),
        fontSize: 13.5 * fontScale,
      ),
      highlightedLinkStyle: TextStyle(
        color: theme.colorScheme.primary.withAlpha(220),
        backgroundColor: theme.colorScheme.onSurface.withAlpha(40),
        fontSize: 13.5 * fontScale,
      ),
      scrollPhysics: const NeverScrollableScrollPhysics(),
      onTap: (url) async => await NamidaLinkUtils.openLinkPreferNamida(url),
    );
  }
}

class DefaultPlaylistCard extends StatelessWidget {
  final Color colorScheme;
  final IconData icon;
  final String title;
  final String text;
  final double? width;
  final bool displayLoadingIndicator;
  final void Function()? onTap;

  const DefaultPlaylistCard({
    super.key,
    required this.colorScheme,
    required this.icon,
    required this.title,
    this.text = '',
    this.width,
    this.displayLoadingIndicator = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return NamidaInkWell(
      borderRadius: 12.0,
      bgColor: Color.alphaBlend(colorScheme.withAlpha(10), theme.cardColor),
      onTap: onTap,
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
              style: textTheme.displayMedium?.copyWith(color: Color.alphaBlend(colorScheme.withAlpha(10), textTheme.displayMedium!.color!)),
              softWrap: false,
              overflow: TextOverflow.fade,
            ),
          ),
          const SizedBox(width: 6.0),
          displayLoadingIndicator
              ? const LoadingIndicator()
              : Text(
                  text,
                  style: textTheme.displayMedium?.copyWith(color: Color.alphaBlend(colorScheme.withAlpha(30), textTheme.displayMedium!.color!)),
                ),
          const SizedBox(width: 2.0),
        ],
      ),
    );
  }
}

class NamidaCircularPercentage extends StatelessWidget {
  final double size;
  final double percentage;
  final String heroTag;

  const NamidaCircularPercentage({
    super.key,
    this.size = 48.0,
    required this.percentage,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Hero(
          tag: heroTag,
          child: SleekCircularSlider(
            appearance: CircularSliderAppearance(
              customWidths: CustomSliderWidths(
                trackWidth: size / 24,
                progressBarWidth: size / 12,
              ),
              customColors: CustomSliderColors(
                dotColor: Colors.transparent,
                trackColor: theme.cardTheme.color,
                dynamicGradient: true,
                progressBarColors: [
                  theme.colorScheme.primary.withAlpha(100),
                  Colors.transparent,
                  theme.colorScheme.secondary.withAlpha(100),
                  Colors.transparent,
                  theme.colorScheme.primary.withAlpha(100),
                ],
                hideShadow: true,
              ),
              size: size,
              spinnerMode: true,
            ),
          ),
        ),
        if (percentage.isFinite)
          Text(
            "${((percentage).clampDouble(0.01, 1.0) * 100).toStringAsFixed(0)}%",
            style: textTheme.displaySmall?.copyWith(fontSize: size / 3.2),
          )
      ],
    );
  }
}

class NamidaListView extends StatelessWidget {
  final Widget Function(Widget list)? listBuilder;
  final Widget Function(BuildContext context, int i) itemBuilder;
  final ReorderCallback? onReorder;
  final VoidCallback? onReorderCancel;
  final void Function(int index)? onReorderStart;
  final void Function(int index)? onReorderEnd;
  final Widget? header;
  final Widget? stickyHeader;
  final Widget Function(double maxWidth)? infoBox;
  final List<Widget>? widgetsInColumn;
  final double? listBottomPadding;
  final double? itemExtent;
  final fr.ItemExtentBuilder? itemExtentBuilder;
  final ScrollController? scrollController;
  final int itemCount;
  final ScrollPhysics? physics;
  final double scrollStep;
  final Map<String, int> scrollConfig;

  const NamidaListView({
    super.key,
    this.listBuilder,
    this.header,
    this.stickyHeader,
    this.infoBox,
    this.widgetsInColumn,
    this.listBottomPadding,
    this.onReorder,
    this.onReorderCancel,
    required this.itemBuilder,
    required this.itemCount,
    required this.itemExtent,
    this.itemExtentBuilder,
    this.scrollController,
    this.onReorderStart,
    this.onReorderEnd,
    this.physics,
    this.scrollStep = 0,
    this.scrollConfig = const {},
  });

  @override
  Widget build(BuildContext context) {
    final list = onReorder != null
        ? NamidaSliverReorderableList(
            itemExtent: itemExtent,
            itemExtentBuilder: itemExtentBuilder,
            itemBuilder: itemBuilder,
            itemCount: itemCount,
            onReorder: onReorder!,
            onReorderCancel: onReorderCancel,
            onReorderStart: onReorderStart,
            onReorderEnd: onReorderEnd,
          )
        : itemExtent != null
            ? SliverFixedExtentList.builder(
                itemExtent: itemExtent!,
                itemBuilder: itemBuilder,
                itemCount: itemCount,
              )
            : itemExtentBuilder != null
                ? SliverVariedExtentList.builder(
                    itemExtentBuilder: itemExtentBuilder!,
                    itemBuilder: itemBuilder,
                    itemCount: itemCount,
                  )
                : SuperSliverList.builder(
                    itemBuilder: itemBuilder,
                    itemCount: itemCount,
                  );
    return NamidaListViewRaw(
      scrollController: scrollController,
      scrollConfig: scrollConfig,
      scrollStep: scrollStep,
      header: header,
      stickyHeader: stickyHeader,
      infoBox: infoBox,
      slivers: [list],
      builder: listBuilder ??
          (list) => widgetsInColumn != null
              ? Column(
                  children: [
                    ...widgetsInColumn!,
                    Expanded(child: list),
                  ],
                )
              : list,
      listBottomPadding: listBottomPadding,
      physics: physics,
    );
  }
}

class NamidaListViewRaw extends StatefulWidget {
  final List<Widget> slivers;
  final Widget Function(Widget list)? builder;
  final Widget Function(double maxWidth)? infoBox;
  final Widget? header;
  final Widget? stickyHeader;
  final Widget? footer;

  /// defaults to [Dimensions.globalBottomPaddingTotal]
  final double? listBottomPadding;
  final ScrollController? scrollController;
  final ScrollPhysics? physics;
  final Map<String, int> scrollConfig;
  final double scrollStep;
  final Axis scrollDirection;
  final bool reverse;

  const NamidaListViewRaw({
    super.key,
    required this.slivers,
    this.builder,
    this.infoBox,
    this.header,
    this.stickyHeader,
    this.footer,
    this.listBottomPadding,
    this.scrollController,
    this.physics,
    this.scrollConfig = const {},
    this.scrollStep = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
  });

  @override
  State<NamidaListViewRaw> createState() => _NamidaListViewRawState();
}

class _NamidaListViewRawState extends State<NamidaListViewRaw> {
  ScrollController? _scrollController;

  @override
  void initState() {
    _scrollController = widget.scrollController ?? ScrollController();
    super.initState();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double? start = widget.header == null ? null : 0.0;
    double? end = widget.footer == null ? null : 0.0;
    if (widget.reverse) {
      (start, end) = (end, start);
    }

    final padding = EdgeInsets.only(bottom: this.widget.listBottomPadding ?? Dimensions.globalBottomPaddingTotal);
    final EdgeInsets startPadding, endPadding, listPadding;
    (startPadding, endPadding, listPadding) = switch (widget.scrollDirection) {
      Axis.horizontal || Axis.vertical when (start ?? end) == null => (EdgeInsets.zero, EdgeInsets.zero, padding),
      Axis.horizontal => (padding.copyWith(left: 0), padding.copyWith(right: 0), padding.copyWith(left: start, right: end)),
      Axis.vertical => (padding.copyWith(top: 0), padding.copyWith(bottom: 0), padding.copyWith(top: start, bottom: end)),
    };
    final (EdgeInsets headerPadding, EdgeInsets footerPadding) = widget.reverse ? (startPadding, endPadding) : (endPadding, startPadding);

    final showSubpageInfoAtSide = Dimensions.inst.showSubpageInfoAtSideContext(context);
    final displayHeaderAtTop = widget.header != null;
    final displayStickyHeaderAtTop = widget.stickyHeader != null;
    final displayInfoBoxAtTop = widget.infoBox != null && !showSubpageInfoAtSide;
    final displayInfoBoxAtSide = widget.infoBox != null && showSubpageInfoAtSide;
    Widget listW = ClipRect(
      child: CustomScrollView(
        scrollDirection: widget.scrollDirection,
        controller: _scrollController,
        physics: widget.physics,
        reverse: widget.reverse,
        slivers: <Widget>[
          if (displayInfoBoxAtTop)
            SliverPadding(
              padding: headerPadding,
              sliver: SliverToBoxAdapter(
                child: widget.infoBox?.call(Dimensions.inst.availableAppContentWidth),
              ),
            ),
          if (displayHeaderAtTop)
            SliverPadding(
              padding: displayInfoBoxAtTop ? EdgeInsets.zero : headerPadding,
              sliver: SliverToBoxAdapter(
                child: widget.header,
              ),
            ),
          if (displayStickyHeaderAtTop)
            SliverPadding(
              padding: displayInfoBoxAtTop ? EdgeInsets.zero : headerPadding,
              sliver: PinnedHeaderSliver(
                child: widget.stickyHeader,
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.only(top: listPadding.top),
          ),
          ...widget.slivers,
          SliverPadding(
            padding: EdgeInsets.only(bottom: listPadding.bottom),
          ),
          if (widget.footer != null)
            SliverPadding(
              padding: footerPadding,
              sliver: SliverToBoxAdapter(child: widget.footer),
            ),
        ],
      ),
    );
    if (displayInfoBoxAtSide) {
      listW = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Dimensions.inst.sideInfoMaxWidth),
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                child: widget.infoBox?.call(Dimensions.inst.sideInfoMaxWidth),
              ),
            ),
          ),
          Expanded(
            child: listW,
          ),
        ],
      );
    }
    return NamidaScrollbar(
      controller: _scrollController,
      scrollStep: widget.scrollStep,
      child: widget.builder?.call(listW) ?? listW,
    );
  }
}

class NamidaSliverReorderableList extends StatelessWidget {
  final Widget Function(BuildContext context, int i) itemBuilder;
  final ReorderCallback onReorder;
  final VoidCallback? onReorderCancel;
  final void Function(int index)? onReorderStart;
  final void Function(int index)? onReorderEnd;
  final double? itemExtent;
  final fr.ItemExtentBuilder? itemExtentBuilder;
  final int itemCount;

  const NamidaSliverReorderableList({
    super.key,
    required this.itemBuilder,
    required this.onReorder,
    this.onReorderCancel,
    this.onReorderStart,
    this.onReorderEnd,
    this.itemExtent,
    this.itemExtentBuilder,
    required this.itemCount,
  });

  Widget _reorderableItemBuilder(BuildContext context, int index) {
    final Widget item = itemBuilder(context, index);
    return ReorderableDelayedDragStartListener(
      delay: kLongPressTimeout,
      key: item.key!,
      index: index,
      child: item,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverReorderableList(
      itemExtent: itemExtent,
      itemExtentBuilder: itemExtentBuilder,
      itemBuilder: _reorderableItemBuilder,
      itemCount: itemCount,
      onReorder: onReorder,
      onReorderCancel: onReorderCancel,
      proxyDecorator: (child, index, animation) => child,
      onReorderStart: onReorderStart,
      onReorderEnd: onReorderEnd,
      autoScrollerVelocityScalar: 600,
    );
  }
}

class NamidaTracksList extends StatelessWidget {
  final List<Selectable>? queue;
  final int queueLength;
  final Widget Function(BuildContext context, int i)? itemBuilder;
  final fr.ItemExtentBuilder? itemExtentBuilder;
  final Widget? header;
  final Widget Function(double maxWidth)? infoBox;
  final Widget? footer;
  final List<Widget>? widgetsInColumn;
  final ScrollController? scrollController;
  final double? listBottomPadding;
  final bool Function()? isTrackSelectable;
  final void Function()? onTap;
  final ScrollPhysics? physics;
  final QueueSource queueSource;
  final bool displayTrackNumber;
  final bool shouldAnimate;
  final String Function(Selectable track)? thirdLineText;
  final Map<String, int> scrollConfig;

  const NamidaTracksList({
    super.key,
    this.queue,
    this.itemBuilder,
    this.itemExtentBuilder,
    this.header,
    required this.infoBox,
    this.footer,
    this.widgetsInColumn,
    this.scrollController,
    this.listBottomPadding,
    required this.queueLength,
    this.isTrackSelectable,
    this.onTap,
    this.physics,
    required this.queueSource,
    this.displayTrackNumber = false,
    this.shouldAnimate = true,
    this.thirdLineText,
    this.scrollConfig = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (itemBuilder != null) {
      return AnimationLimiter(
        child: NamidaListView(
          infoBox: infoBox,
          header: header,
          widgetsInColumn: widgetsInColumn,
          scrollController: scrollController,
          itemCount: queueLength,
          itemExtent: Dimensions.inst.trackTileItemExtent,
          itemExtentBuilder: itemExtentBuilder,
          listBottomPadding: listBottomPadding,
          physics: physics,
          scrollConfig: scrollConfig,
          itemBuilder: itemBuilder!,
        ),
      );
    } else if (queue != null) {
      final queue = this.queue!;
      final thirdLineText = this.thirdLineText;
      return AnimationLimiter(
        child: TrackTilePropertiesProvider(
          configs: TrackTilePropertiesConfigs(
            queueSource: queueSource,
            selectable: isTrackSelectable,
            displayTrackNumber: displayTrackNumber,
          ),
          builder: (properties) {
            return NamidaListView(
              infoBox: infoBox,
              header: header,
              widgetsInColumn: widgetsInColumn,
              scrollController: scrollController,
              itemCount: queueLength,
              itemExtent: Dimensions.inst.trackTileItemExtent,
              listBottomPadding: listBottomPadding,
              physics: physics,
              scrollConfig: scrollConfig,
              itemBuilder: (context, i) {
                final track = queue[i];
                return AnimatingTile(
                  key: ValueKey(i),
                  position: i,
                  shouldAnimate: shouldAnimate,
                  child: TrackTile(
                    properties: properties,
                    index: i,
                    trackOrTwd: track,
                    tracks: queue,
                    onTap: onTap,
                    thirdLineText: thirdLineText == null ? null : thirdLineText(track),
                  ),
                );
              },
            );
          },
        ),
      );
    } else {
      return const Text('PASS A QUEUE OR USE ITEM BUILDER');
    }
  }
}

class NamidaSupportButton extends StatelessWidget {
  final String? title;
  final bool closeDialog;
  const NamidaSupportButton({super.key, this.title, this.closeDialog = true});

  @override
  Widget build(BuildContext context) {
    return NamidaButton(
      icon: Broken.heart,
      text: title ?? lang.SUPPORT,
      onPressed: () {
        closeDialog.closeDialog();
        NamidaLinkUtils.openLink(AppSocial.DONATE_BUY_ME_A_COFFEE);
      },
    );
  }
}

class BackgroundWrapper extends StatelessWidget {
  final Widget child;
  const BackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: child,
    );
  }
}

class NamidaInkWell extends StatelessWidget {
  final Color? bgColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableSecondaryTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final BoxDecoration decoration;
  final Widget? child;
  final int animationDurationMS;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  /// Setting this to [true] will force the [borderRadius] to be [0.0].
  final bool transparentHighlight;
  const NamidaInkWell({
    super.key,
    this.bgColor,
    this.onTap,
    this.onLongPress,
    this.enableSecondaryTap = false,
    this.borderRadius = 12.0,
    this.padding = EdgeInsets.zero,
    this.decoration = const BoxDecoration(),
    this.child,
    this.transparentHighlight = false,
    this.animationDurationMS = 0,
    this.margin,
    this.width,
    this.height,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final borderR =
        decoration.borderRadius?.resolve(Directionality.of(context)) ?? (transparentHighlight || borderRadius == 0 ? null : BorderRadius.circular(borderRadius.multipliedRadius));
    final highlightColor = transparentHighlight ? Colors.transparent : Color.alphaBlend(theme.scaffoldBackgroundColor.withAlpha(20), theme.highlightColor);
    final bgColor = this.bgColor ?? decoration.color ?? Colors.transparent;
    final decorationFinal = BoxDecoration(
      color: bgColor,
      borderRadius: borderR,
      backgroundBlendMode: decoration.backgroundBlendMode,
      boxShadow: decoration.boxShadow,
      gradient: decoration.gradient,
      shape: decoration.shape,
      image: decoration.image,
    );

    final foregroundDecorationFinal = BoxDecoration(
      border: decoration.border,
      borderRadius: borderR,
    );
    final childFinal = Material(
      clipBehavior: Clip.none,
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: borderR,
        hoverColor: highlightColor,
        highlightColor: highlightColor,
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: enableSecondaryTap ? onLongPress ?? onTap : null,
        child: SizedBox(
          height: height,
          width: width,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
    return animationDurationMS > 0
        ? AnimatedContainer(
            alignment: alignment,
            margin: margin,
            duration: Duration(milliseconds: animationDurationMS),
            decoration: decorationFinal,
            foregroundDecoration: foregroundDecorationFinal,
            clipBehavior: Clip.none,
            child: childFinal,
          )
        : Container(
            alignment: alignment,
            margin: margin,
            decoration: decorationFinal,
            foregroundDecoration: foregroundDecorationFinal,
            clipBehavior: Clip.none,
            child: childFinal,
          );
  }
}

class NamidaInkWellButton extends StatelessWidget {
  final Color? bgColor;
  final VoidCallback? onTap;
  final double borderRadius;
  final int animationDurationMS;
  final IconData? icon;
  final double iconSize;
  final String text;
  final bool enabled;
  final bool showLoadingWhenDisabled;
  final bool disableWhenLoading;
  final double sizeMultiplier;
  final double paddingMultiplier;
  final Widget? leading;
  final Widget? trailing;
  final BoxDecoration decoration;

  const NamidaInkWellButton({
    super.key,
    this.bgColor,
    this.onTap,
    this.borderRadius = 10.0,
    this.animationDurationMS = 250,
    required this.icon,
    this.iconSize = 18.0,
    required this.text,
    this.enabled = true,
    this.showLoadingWhenDisabled = true,
    this.disableWhenLoading = true,
    this.sizeMultiplier = 1.0,
    this.paddingMultiplier = 1.0,
    this.leading,
    this.trailing,
    this.decoration = const BoxDecoration(),
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final itemsColor = theme.colorScheme.onSurface.withValues(alpha: 0.8);
    final textGood = text.isNotEmpty;
    return IgnorePointer(
      ignoring: !enabled && disableWhenLoading,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.6,
        duration: Duration(milliseconds: animationDurationMS),
        child: NamidaInkWell(
          animationDurationMS: animationDurationMS,
          borderRadius: borderRadius * sizeMultiplier,
          padding: EdgeInsets.symmetric(horizontal: 12.0 * sizeMultiplier * paddingMultiplier, vertical: 6.0 * sizeMultiplier * paddingMultiplier),
          bgColor: bgColor ?? theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
          decoration: decoration,
          onTap: onTap,
          enableSecondaryTap: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) leading!,
              if (!enabled && showLoadingWhenDisabled) ...[
                const LoadingIndicator(boxHeight: 18.0),
                SizedBox(width: 6.0 * sizeMultiplier),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  size: iconSize * sizeMultiplier,
                  color: itemsColor,
                ),
              ],
              if (textGood) ...[
                SizedBox(width: 6.0 * sizeMultiplier),
                Flexible(
                  child: Text(
                    text,
                    style: textTheme.displayMedium?.copyWith(
                      color: itemsColor,
                      fontSize: (15.0 * sizeMultiplier),
                    ),
                  ),
                ),
                if (textGood) const SizedBox(width: 4.0),
              ],
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryJumpToDayIcon<T extends ItemWithDate, E> extends StatelessWidget {
  final HistoryManager<T, E> controller;
  final ({double itemExtent, double dayHeaderExtent}) Function() itemExtentAndDayHeaderExtent;
  final bool considerInfoBoxPadding;

  const HistoryJumpToDayIcon({
    super.key,
    required this.controller,
    required this.itemExtentAndDayHeaderExtent,
    required this.considerInfoBoxPadding,
  });

  double get topPadding => considerInfoBoxPadding && !Dimensions.inst.showSubpageInfoAtSide ? 64.0 : 0.0;

  DateTime? getCurrentDateFromScrollPosition() {
    final currentScrolledDay = getCurrentDayFromScrollPosition();
    return currentScrolledDay == null ? null : DateTime(1970).add(Duration(days: currentScrolledDay));
  }

  int? getCurrentDayFromScrollPosition() {
    final info = itemExtentAndDayHeaderExtent();
    final topPadding = this.topPadding;
    final currentScrolledDay = controller.currentScrollPositionToDay(info.itemExtent, info.dayHeaderExtent, topPadding: topPadding);
    return currentScrolledDay;
  }

  void scrollToDate(DateTime dateToScrollTo) {
    final dayToScrollTo = dateToScrollTo.toDaysSince1970();
    final days = controller.historyDays.toList();
    days.removeWhere((element) => element <= dayToScrollTo);
    double totalScrollOffset = controller.daysToSectionExtent(days);
    controller.scrollController.jumpTo(totalScrollOffset + topPadding - 48.0);
  }

  @override
  Widget build(BuildContext context) {
    return NamidaAppBarIcon(
      icon: Broken.calendar,
      tooltip: () => lang.JUMP_TO_DAY,
      onPressed: () {
        final initialDate = getCurrentDateFromScrollPosition();
        showCalendarDialog(
          historyController: controller,
          title: lang.JUMP_TO_DAY,
          buttonText: lang.JUMP,
          calendarType: CalendarDatePicker2Type.single,
          useHistoryDates: true,
          initialDate: initialDate,
          onGenerate: (dates) {
            NamidaNavigator.inst.closeDialog();
            final dateToScrollTo = dates.firstOrNull;
            if (dateToScrollTo != null) scrollToDate(dateToScrollTo);
          },
        );
      },
    );
  }
}

class BetweenDatesTextButton extends StatefulWidget {
  final bool useHistoryDates;
  final void Function(List<DateTime> dates) onConfirm;
  final bool maxToday;
  final int tracksLength;

  const BetweenDatesTextButton({
    super.key,
    required this.useHistoryDates,
    required this.onConfirm,
    this.maxToday = false,
    this.tracksLength = 0,
  });

  @override
  State<BetweenDatesTextButton> createState() => _BetweenDatesTextButtonState();
}

class _BetweenDatesTextButtonState extends State<BetweenDatesTextButton> {
  DateTime? oldestDate;
  DateTime? newestDate;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final textWidget = Text(lang.BETWEEN_DATES);

    return TextButton.icon(
      onPressed: () {
        showCalendarDialog(
          useHistoryDates: widget.useHistoryDates,
          lastDate: widget.maxToday ? DateTime.now() : null,
          title: lang.BETWEEN_DATES,
          buttonText: lang.CONFIRM,
          onGenerate: (dates) {
            oldestDate = dates.firstOrNull;
            newestDate = dates.lastOrNull;
            widget.onConfirm(dates);
            setState(() {});
          },
        );
      },
      icon: const Icon(Broken.calendar_1),
      label: oldestDate == null || newestDate == null
          ? textWidget
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    textWidget,
                    const SizedBox(width: 6.0),
                    if (widget.tracksLength != 0)
                      NamidaButtonText(
                        "(${widget.tracksLength.displayTrackKeyword})",
                        style: textTheme.displaySmall,
                      ),
                  ],
                ),
                NamidaButtonText(
                  "${oldestDate?.millisecondsSinceEpoch.dateFormattedOriginal} → ${newestDate?.millisecondsSinceEpoch.dateFormattedOriginal}",
                  style: textTheme.displaySmall,
                ),
              ],
            ),
    );
  }
}

/// Obx((context) => showIf.value ? child : const SizedBox(context));
class ObxShow extends StatelessWidget {
  final RxBase<bool> showIf;
  final Widget child;

  const ObxShow({
    super.key,
    required this.showIf,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: showIf,
      builder: (context, show) => show ? child : const SizedBox(),
    );
  }
}

class NamidaHero extends StatelessWidget {
  final Object? tag;
  final Widget child;
  final bool enabled;

  const NamidaHero({
    super.key,
    required this.tag,
    required this.child,
    this.enabled = true,
  });

  static final fadeAnimation2Convert = Animatable.fromCallback((value) => (value * (1 / 0.2)).clampDouble(0, 1));
  static final fadeAnimation1Convert = Animatable.fromCallback((value) => 1.0 - (value * 12 - 11).clampDouble(0, 1));

  static Widget _customHeroFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final Hero toHero = toHeroContext.widget as Hero;
    final Hero fromHero = fromHeroContext.widget as Hero;

    final (Hero hero1, Hero hero2) = switch (flightDirection) {
      HeroFlightDirection.push => (fromHero, toHero),
      HeroFlightDirection.pop => (toHero, fromHero),
    };

    final MediaQueryData? toMediaQueryData = MediaQuery.maybeOf(toHeroContext);
    final MediaQueryData? fromMediaQueryData = MediaQuery.maybeOf(fromHeroContext);

    if (toMediaQueryData == null || fromMediaQueryData == null) {
      return toHero.child;
    }

    final EdgeInsets fromHeroPadding = fromMediaQueryData.padding;
    final EdgeInsets toHeroPadding = toMediaQueryData.padding;

    final fadeAnimation2 = animation.drive(fadeAnimation2Convert);
    final fadeAnimation1 = animation.drive(fadeAnimation1Convert);

    final stackChild = Stack(
      alignment: Alignment.center,
      fit: StackFit.passthrough,
      children: [
        FadeTransition(
          opacity: fadeAnimation2,
          child: hero2.child,
        ),
        FadeTransition(
          opacity: fadeAnimation1,
          child: hero1.child,
        ),
      ],
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return MediaQuery(
          data: toMediaQueryData.copyWith(
            padding: (flightDirection == HeroFlightDirection.push)
                ? EdgeInsetsTween(
                    begin: fromHeroPadding,
                    end: toHeroPadding,
                  ).evaluate(animation)
                : EdgeInsetsTween(
                    begin: toHeroPadding,
                    end: fromHeroPadding,
                  ).evaluate(animation),
          ),
          child: stackChild,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return enabled && tag != null
        ? Hero(
            tag: tag!,
            // -- quite expensive to animate 2 fade transitions.
            flightShuttleBuilder: settings.performanceMode.value == PerformanceMode.highPerformance ? null : _customHeroFlightShuttleBuilder,
            child: child,
          )
        : child;
  }
}

class NamidaTooltip extends StatelessWidget {
  final String Function()? message;
  final bool? preferBelow;
  final TooltipTriggerMode? triggerMode;
  final Widget child;

  const NamidaTooltip({
    super.key,
    required this.message,
    this.preferBelow,
    this.triggerMode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (message == null) return child;
    return Tooltip(
      message: message,
      preferBelow: preferBelow,
      triggerMode: triggerMode,
      child: child,
    );
  }
}

class NamidaAnimatedSwitcher extends StatelessWidget {
  final Widget firstChild;
  final Widget secondChild;
  final bool showFirst;
  final int durationMS;
  final int? reverseDurationMS;
  final Curve firstCurve;
  final Curve secondCurve;
  final Curve sizeCurve;
  final Curve? allCurves;
  const NamidaAnimatedSwitcher({
    super.key,
    required this.firstChild,
    required this.secondChild,
    required this.showFirst,
    this.durationMS = 400,
    this.reverseDurationMS,
    this.firstCurve = Curves.linear,
    this.secondCurve = Curves.linear,
    this.sizeCurve = Curves.linear,
    this.allCurves,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: firstChild,
      secondChild: secondChild,
      crossFadeState: showFirst ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: Duration(milliseconds: durationMS),
      reverseDuration: Duration(milliseconds: reverseDurationMS ?? durationMS),
      firstCurve: allCurves ?? firstCurve,
      secondCurve: allCurves ?? secondCurve,
      sizeCurve: allCurves ?? sizeCurve,
      layoutBuilder: (topChild, topChildKey, bottomChild, bottomChildKey) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              key: bottomChildKey,
              top: 0,
              child: bottomChild,
            ),
            Positioned(
              key: topChildKey,
              child: topChild,
            ),
          ],
        );
      },
    );
  }
}

class ShimmerWrapper extends StatelessWidget {
  final bool shimmerEnabled;
  final Widget child;
  final int fadeDurationMS;
  final int shimmerDelayMS;
  final int shimmerDurationMS;
  final bool transparent;

  const ShimmerWrapper({
    super.key,
    required this.shimmerEnabled,
    required this.child,
    this.fadeDurationMS = 600,
    this.shimmerDelayMS = 400,
    this.shimmerDurationMS = 700,
    this.transparent = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = transparent ? Colors.transparent : context.theme.cardColor.withAlpha(120);
    return AnimatedSwitcher(
      duration: fadeDurationMS.ms,
      child: shimmerEnabled
          ? Animate(
              onPlay: (controller) => controller.repeat(),
              effects: [
                ShimmerEffect(
                  delay: shimmerDelayMS.ms,
                  duration: shimmerDurationMS.ms,
                  colors: [
                    color,
                    const Color(0x80FFFFFF),
                    color,
                  ],
                ),
              ],
              child: child,
            )
          : child,
    );
  }
}

class LazyLoadListView extends StatefulWidget {
  final ScrollController? scrollController;
  final int extend;
  final FutureOr<bool> Function() onReachingEnd;
  final Widget Function(ScrollController controller) listview;
  final bool requiresNetwork;

  const LazyLoadListView({
    super.key,
    this.scrollController,
    this.extend = 400,
    required this.onReachingEnd,
    required this.listview,
    this.requiresNetwork = true,
  });

  @override
  State<LazyLoadListView> createState() => _LazyLoadListViewState();
}

class _LazyLoadListViewState extends State<LazyLoadListView> {
  late final ScrollController controller;
  bool _isExecuting = false;

  bool? _lastWasSuccess;
  bool _isInExtendRange = false; // prevent re-execution if latest failed & still in range.

  void _scrollListener() async {
    if (_isExecuting) return;

    if (controller.offset >= controller.position.maxScrollExtent - widget.extend) {
      if (!controller.position.outOfRange) {
        if (_lastWasSuccess == false && _isInExtendRange) return;
        _isInExtendRange = true;
        if (widget.requiresNetwork && !ConnectivityController.inst.hasConnection) return;
        _isExecuting = true;
        _lastWasSuccess = await widget.onReachingEnd();
        _isExecuting = false;
      }
    } else {
      _isInExtendRange = false;
    }
  }

  @override
  void initState() {
    super.initState();
    controller = (widget.scrollController ?? ScrollController())..addListener(_scrollListener);
  }

  @override
  void dispose() {
    controller.removeListener(_scrollListener);
    if (widget.scrollController == null) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.listview(controller);
  }
}

class NamidaAspectRatio extends StatelessWidget {
  final double? aspectRatio;
  final Widget child;

  const NamidaAspectRatio({
    super.key,
    required this.aspectRatio,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return aspectRatio == null
        ? child
        : AspectRatio(
            aspectRatio: aspectRatio!,
            child: child,
          );
  }
}

class NamidaTabView extends StatefulWidget {
  final int initialIndex;
  final List<String>? tabs;
  final List<Widget>? tabWidgets;
  final List<Widget> children;
  final void Function(int index) onIndexChanged;
  final bool isScrollable;
  final bool compact;
  final bool reportIndexChangedOnInit;

  const NamidaTabView({
    super.key,
    required this.children,
    required this.initialIndex,
    this.tabs,
    this.tabWidgets,
    required this.onIndexChanged,
    this.isScrollable = false,
    this.compact = false,
    this.reportIndexChangedOnInit = true,
  });

  @override
  State<NamidaTabView> createState() => NamidaTabViewState();
}

class NamidaTabViewState extends State<NamidaTabView> with SingleTickerProviderStateMixin {
  late TabController controller;

  void fn() => widget.onIndexChanged(controller.index);

  void animateToTab(int index) {
    controller.animateTo(index);
  }

  void jumpToTab(int index) {
    controller.animateTo(index, duration: Duration.zero);
  }

  @override
  void initState() {
    if (widget.reportIndexChangedOnInit) Timer(Duration.zero, () => widget.onIndexChanged(widget.initialIndex));
    controller = TabController(
      length: widget.children.length,
      vsync: this,
      animationDuration: const Duration(milliseconds: 400),
      initialIndex: widget.initialIndex,
    );
    controller.addListener(fn);
    super.initState();
  }

  @override
  void dispose() {
    controller.removeListener(fn);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsPadding = widget.compact ? const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0) : const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0);
    return Column(
      children: [
        TabBar(
          indicatorWeight: widget.compact ? 1.0 : 3.0,
          controller: controller,
          isScrollable: widget.isScrollable,
          tabs: widget.tabs
                  ?.map(
                    (e) => Padding(
                      padding: itemsPadding,
                      child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList() ??
              widget.tabWidgets ??
              widget.children
                  .map(
                    (e) => Padding(
                      padding: itemsPadding,
                      child: Text(e.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
          splashBorderRadius: BorderRadius.circular(12.0.multipliedRadius),
          indicatorSize: TabBarIndicatorSize.label,
        ),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: widget.children,
          ),
        ),
      ],
    );
  }
}

class ShaderFadingWidget extends StatelessWidget {
  final bool biggerValues;
  final Widget child;
  final Alignment begin;
  final Alignment end;
  const ShaderFadingWidget({
    super.key,
    this.biggerValues = false,
    required this.child,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final stops = biggerValues ? [0.07, 0.3, 0.6, 0.8, 1.0] : [0.0, 0.2, 0.8, 0.9, 1.0];
        return LinearGradient(
          begin: begin,
          end: end,
          tileMode: TileMode.clamp,
          stops: stops,
          colors: const [Colors.transparent, Colors.white, Colors.white, Colors.white, Colors.transparent],
        ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
      },
      child: child,
    );
  }
}

class NamidaOpacity extends StatelessWidget {
  final bool enabled;
  final double opacity;
  final Widget child;

  const NamidaOpacity({
    super.key,
    required this.opacity,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (opacity == 0) {
      return const SizedBox();
    } else if (!enabled || opacity == 1) {
      return child;
    }
    return Opacity(
      key: key,
      opacity: opacity,
      child: child,
    );
  }
}

class NamidaScrollbar extends StatelessWidget {
  final ScrollController? controller;
  final Widget child;
  final double scrollStep;
  final bool showOnStart;

  const NamidaScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.scrollStep = 0,
    this.showOnStart = false,
  });

  @override
  Widget build(BuildContext context) {
    if (controller == null) return child;
    return CupertinoScrollbar(
      controller: controller,
      showOnStart: showOnStart,
      scrollStep: scrollStep,
      thicknessWhileDragging: 9.0,
      onThumbLongPressStart: () => isScrollbarThumbDragging = true,
      onThumbLongPressEnd: () => isScrollbarThumbDragging = false,
      child: child,
    );
  }
}

class NamidaScrollbarWithController extends StatefulWidget {
  final bool showOnStart;
  final Widget Function(ScrollController sc) child;
  const NamidaScrollbarWithController({super.key, this.showOnStart = false, required this.child});

  @override
  State<NamidaScrollbarWithController> createState() => _NamidaScrollbarWithControllerState();
}

class _NamidaScrollbarWithControllerState extends State<NamidaScrollbarWithController> {
  late final ScrollController _sc;
  @override
  void initState() {
    _sc = ScrollController();
    super.initState();
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoScrollbar(
      controller: _sc,
      showOnStart: widget.showOnStart,
      thicknessWhileDragging: 9.0,
      onThumbLongPressStart: () => isScrollbarThumbDragging = true,
      onThumbLongPressEnd: () => isScrollbarThumbDragging = false,
      child: widget.child(_sc),
    );
  }
}

class NamidaAZScrollbar extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final Map<String, int> scrollConfig;
  final double? itemExtent;

  const NamidaAZScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.scrollConfig = const {},
    this.itemExtent,
  });

  @override
  State<NamidaAZScrollbar> createState() => _NamidaAZScrollbarState();
}

class _NamidaAZScrollbarState extends State<NamidaAZScrollbar> {
  ScrollController? controller;
  final stackKey = GlobalKey<State<StatefulWidget>>();
  final columnKey = GlobalKey<State<StatefulWidget>>();
  double stackHeight = 0;
  double columnHeight = 1;
  static const verticalPadding = 6.0;
  final characters = <String>[];
  final items = <Text>[];

  final _selectedChar = (0.0, '').obs;

  @override
  void initState() {
    controller = widget.controller;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final s = columnKey.currentContext?.size;
      if (s != null) stackHeight = s.height;
      final h = columnKey.currentContext?.size?.height;
      if (h != null) columnHeight = h;
    });
    stackHeight = stackHeight;

    for (final e in widget.scrollConfig.entries) {
      characters.add(e.key);
      items.add(Text(e.key));
    }

    super.initState();
  }

  @override
  void dispose() {
    _selectedChar.close();
    super.dispose();
  }

  void onScroll(double dy) {
    final controller = this.controller!;
    final columnHeight = columnKey.currentContext?.size?.height ?? 1;
    final p = (dy) / (columnHeight - verticalPadding * 2);
    final index = ((p * items.length).clampDouble(0, items.length - 1)).floor();
    final character = characters[index];
    _selectedChar.value = (p, character);
    if (controller.positions.isNotEmpty) {
      final p = controller.positions.last;
      final toOffset = (widget.scrollConfig[character] ?? 1) * (widget.itemExtent ?? 0);
      controller.jumpTo(toOffset.toDouble().clampDouble(0.0, p.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || widget.scrollConfig.isEmpty) {
      return NamidaScrollbar(
        controller: controller,
        child: widget.child,
      );
    }

    final theme = context.theme;
    final textTheme = theme.textTheme;
    return Stack(
      key: stackKey,
      alignment: Alignment.center,
      children: [
        widget.child,
        Obx(
          (context) => Positioned(
            right: 14.0,
            top: _selectedChar.valueR.$1 * columnHeight,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(shape: BoxShape.circle, color: theme.cardColor),
              child: Text(_selectedChar.valueR.$2),
            ),
          ),
        ),
        Positioned(
          right: 0,
          child: SizedBox(
            width: 14.0,
            height: stackHeight,
            child: FittedBox(
              child: DefaultTextStyle(
                style: textTheme.displaySmall!.copyWith(fontSize: stackHeight / widget.scrollConfig.length),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: verticalPadding),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                  ),
                  child: GestureDetector(
                    onVerticalDragDown: (details) => onScroll(details.localPosition.dy),
                    onVerticalDragUpdate: (details) => onScroll(details.localPosition.dy),
                    child: Text(
                      widget.scrollConfig.keys.join('\n'),
                      key: columnKey,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AnimatedEnabled extends StatelessWidget {
  final bool enabled;
  final double disabledOpacity;
  final int durationMS;
  final Widget child;

  const AnimatedEnabled({
    super.key,
    required this.enabled,
    this.disabledOpacity = 0.6,
    this.durationMS = 300,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : disabledOpacity,
        duration: Duration(milliseconds: durationMS),
        child: child,
      ),
    );
  }
}

class AnimatedShow extends StatelessWidget {
  final bool show;
  final bool isHorizontal;
  final Duration duration;
  final Curve curve;
  final Widget child;

  const AnimatedShow({
    super.key,
    required this.show,
    this.isHorizontal = false,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.fastEaseInToSlowEaseOut,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final factor = show ? 1.0 : 0.0;
    return IgnorePointer(
      ignoring: !show,
      child: AnimatedAlign(
        alignment: Alignment.center,
        heightFactor: isHorizontal ? null : factor,
        widthFactor: isHorizontal ? factor : null,
        duration: duration,
        curve: curve,
        child: AnimatedOpacity(
          opacity: factor,
          duration: duration,
          curve: curve,
          child: child,
        ),
      ),
    );
  }
}

class QueueUtilsRow extends StatelessWidget {
  final String Function(int number) itemsKeyword;
  final void Function() onAddItemsTap;
  final Widget Function(ButtonStyle buttonStyle) scrollQueueWidget;

  const QueueUtilsRow({
    super.key,
    required this.itemsKeyword,
    required this.onAddItemsTap,
    required this.scrollQueueWidget,
  });

  @override
  Widget build(BuildContext context) {
    const tileHeight = 48.0;
    const tileVPadding = 3.0;
    const buttonStyle = ButtonStyle(
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(width: 12.0),
        NamidaButton(
          style: buttonStyle,
          tooltip: () => lang.REMOVE_DUPLICATES,
          icon: Broken.broom,
          onPressed: () {
            final removed = Player.inst.removeDuplicatesFromQueue();
            snackyy(
              top: false,
              icon: Broken.filter_remove,
              message: "${lang.REMOVED} ${itemsKeyword(removed)}",
            );
          },
        ),
        const SizedBox(width: 6.0),
        NamidaButton(
          style: buttonStyle,
          tooltip: () => lang.NEW_TRACKS_ADD,
          icon: Broken.add_circle,
          onPressed: () => onAddItemsTap(),
        ),
        const SizedBox(width: 6.0),
        scrollQueueWidget(buttonStyle),
        const SizedBox(width: 6.0),
        GestureDetector(
          onLongPressStart: (details) async {
            Widget buildButton(String title, IconData icon, bool isShuffleAll) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: tileVPadding, horizontal: 8.0),
                child: ObxO(
                  rx: settings.player.shuffleAllTracks,
                  builder: (context, shuffleAllTracks) => SizedBox(
                    height: tileHeight,
                    child: ListTileWithCheckMark(
                      active: shuffleAllTracks == isShuffleAll,
                      leading: StackedIcon(
                        baseIcon: Broken.shuffle,
                        secondaryIcon: icon,
                        blurRadius: 8.0,
                      ),
                      title: title,
                      onTap: () => settings.player.save(shuffleAllTracks: isShuffleAll),
                    ),
                  ),
                ),
              );
            }

            final menu = NamidaPopupWrapper(
              children: () => [
                buildButton(lang.SHUFFLE_NEXT, Broken.forward, false),
                buildButton(lang.SHUFFLE_ALL, Broken.task, true),
              ],
            );
            menu.showPopupMenu(
              context,
            );
          },
          child: NamidaButton(
            style: buttonStyle,
            text: lang.SHUFFLE,
            icon: Broken.shuffle,
            onPressed: () => Player.inst.shuffleTracks(settings.player.shuffleAllTracks.value),
          ),
        ),
        const SizedBox(width: 12.0),
      ],
    );
  }
}

class RepeatModeIconButton extends StatelessWidget {
  final bool compact;
  final Color? color;
  final double iconSize;
  final VoidCallback? onPressed;
  final Widget Function(Widget child, String Function() tooltipCallback, void Function() onTap)? builder;

  const RepeatModeIconButton({
    super.key,
    this.compact = false,
    this.color,
    this.iconSize = 20.0,
    this.onPressed,
    this.builder,
  });

  void _switchMode() {
    final e = settings.player.repeatMode.value.nextElement(PlayerRepeatMode.values);
    settings.player.save(repeatMode: e);
  }

  String _buildTooltip() {
    final repeat = settings.player.repeatMode.value;
    return repeat.buildText();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final iconColor = color ?? theme.colorScheme.onSecondaryContainer;

    return ObxO(
      rx: settings.player.repeatMode,
      builder: (context, repeatMode) {
        final icon = repeatMode.toIcon();

        final child = Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor,
            ),
            if (repeatMode == PlayerRepeatMode.forNtimes)
              ObxO(
                rx: Player.inst.numberOfRepeats,
                builder: (context, numberOfRepeats) => Text(
                  '$numberOfRepeats',
                  style: textTheme.displaySmall?.copyWith(color: iconColor),
                ),
              ),
          ],
        );
        if (builder != null) {
          return builder!(
            child,
            _buildTooltip,
            () {
              onPressed?.call();
              _switchMode();
            },
          );
        }

        return compact
            ? NamidaIconButton(
                tooltip: _buildTooltip,
                icon: null,
                verticalPadding: 2.0,
                horizontalPadding: 4.0,
                padding: EdgeInsets.zero,
                iconSize: iconSize,
                onPressed: () {
                  onPressed?.call();
                  _switchMode();
                },
                child: child,
              )
            : NamidaTooltip(
                message: _buildTooltip,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
                  onPressed: () {
                    onPressed?.call();
                    _switchMode();
                  },
                  icon: child,
                ),
              );
      },
    );
  }
}

class SoundControlButton extends StatelessWidget {
  final bool compact;
  final Color? color;
  final double iconSize;
  final VoidCallback? onPressed;
  final Widget Function(Widget child, String Function() tooltipCallback, void Function() onTap)? builder;

  const SoundControlButton({
    super.key,
    this.compact = false,
    this.color,
    this.iconSize = 20.0,
    this.onPressed,
    this.builder,
  });

  void _onTap() {
    NamidaOnTaps.inst.openEqualizer();
  }

  String _buildTooltip() {
    return lang.EQUALIZER;
  }

  @override
  Widget build(BuildContext context) {
    final tooltip = lang.EQUALIZER;
    final iconColor = color ?? context.theme.colorScheme.onSecondaryContainer;
    final child = StreamBuilder<bool>(
      initialData: Player.inst.equalizer.enabled,
      stream: Player.inst.equalizer.enabledStream,
      builder: (context, snapshot) {
        return Obx(
          (context) {
            final isSoundModified = settings.player.speed.valueR != 1.0 || settings.player.pitch.valueR != 1.0;
            final enabled = isSoundModified || (snapshot.data ?? false);
            return enabled
                ? StackedIcon(
                    baseIcon: Broken.sound,
                    secondaryIcon: isSoundModified ? Broken.edit_2 : Broken.tick_circle,
                    iconSize: iconSize,
                    secondaryIconSize: iconSize * 0.5,
                    baseIconColor: iconColor,
                    secondaryIconColor: iconColor,
                    blurRadius: 12.0,
                  )
                : Icon(
                    Broken.sound,
                    size: iconSize,
                    color: iconColor,
                  );
          },
        );
      },
    );

    if (builder != null) {
      return builder!(child, _buildTooltip, _onTap);
    }

    return compact
        ? NamidaIconButton(
            tooltip: () => tooltip,
            icon: null,
            verticalPadding: 2.0,
            horizontalPadding: 4.0,
            padding: EdgeInsets.zero,
            iconSize: iconSize,
            onPressed: () {
              onPressed?.call();
              _onTap();
            },
            child: child,
          )
        : IconButton(
            visualDensity: VisualDensity.compact,
            style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
            tooltip: tooltip,
            onPressed: () {
              onPressed?.call();
              _onTap();
            },
            icon: child,
          );
  }
}

class TapDetector extends StatelessWidget {
  final VoidCallback? onTap;
  final void Function(TapGestureRecognizer instance)? initializer;
  final Widget? child;
  final HitTestBehavior? behavior;

  const TapDetector({
    super.key,
    required this.onTap,
    this.initializer,
    this.child,
    this.behavior,
  });

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{};
    gestures[TapGestureRecognizer] = GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
      () => TapGestureRecognizer(debugOwner: this),
      initializer ??
          (TapGestureRecognizer instance) {
            instance
              ..onTap = onTap
              ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
          },
    );

    return RawGestureDetector(
      behavior: behavior,
      gestures: gestures,
      child: child,
    );
  }
}

class DoubleTapDetector extends StatelessWidget {
  final VoidCallback? onDoubleTap;
  final void Function(DoubleTapGestureRecognizer instance)? initializer;
  final Widget? child;
  final HitTestBehavior? behavior;

  const DoubleTapDetector({
    super.key,
    required this.onDoubleTap,
    this.initializer,
    this.child,
    this.behavior,
  });

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{};
    gestures[DoubleTapGestureRecognizer] = GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
      () => DoubleTapGestureRecognizer(debugOwner: this),
      initializer ??
          (DoubleTapGestureRecognizer instance) {
            instance
              ..onDoubleTap = onDoubleTap
              ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
          },
    );

    return RawGestureDetector(
      behavior: behavior,
      gestures: gestures,
      child: child,
    );
  }
}

class LongPressDetector extends StatelessWidget {
  final VoidCallback? onLongPress;
  final Widget? child;
  final HitTestBehavior? behavior;
  final bool enableSecondaryTap;

  const LongPressDetector({
    super.key,
    required this.onLongPress,
    this.child,
    this.behavior,
    this.enableSecondaryTap = false,
  });

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{};
    gestures[LongPressGestureRecognizer] = GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
      () => LongPressGestureRecognizer(debugOwner: this),
      (LongPressGestureRecognizer instance) {
        instance
          ..onLongPress = onLongPress
          ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
      },
    );

    if (enableSecondaryTap) {
      gestures[TapGestureRecognizer] = GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(debugOwner: this),
        (TapGestureRecognizer instance) {
          instance
            ..onSecondaryTap = onLongPress
            ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
        },
      );
    }

    return RawGestureDetector(
      behavior: behavior,
      gestures: gestures,
      child: child,
    );
  }
}

class ScaleDetector extends StatelessWidget {
  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;
  final Widget? child;
  final HitTestBehavior? behavior;

  const ScaleDetector({
    super.key,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.child,
    this.behavior,
  });

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{};
    gestures[ScaleGestureRecognizer] = GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
      () => ScaleGestureRecognizer(debugOwner: this),
      (ScaleGestureRecognizer instance) {
        instance
          ..onStart = onScaleStart
          ..onUpdate = onScaleUpdate
          ..onEnd = onScaleEnd
          ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
      },
    );

    return RawGestureDetector(
      behavior: behavior,
      gestures: gestures,
      child: child,
    );
  }
}

class HorizontalDragDetector extends _LinearDragDetector<HorizontalDragGestureRecognizer> {
  @override
  HorizontalDragGestureRecognizer create() => HorizontalDragGestureRecognizer(debugOwner: this);

  const HorizontalDragDetector({
    super.key,
    super.initializer,
    super.child,
    super.behavior,
    super.onStart,
    super.onDown,
    super.onUpdate,
    super.onEnd,
    super.onCancel,
  });
}

class VerticalDragDetector extends _LinearDragDetector<VerticalDragGestureRecognizer> {
  @override
  VerticalDragGestureRecognizer create() => VerticalDragGestureRecognizer(debugOwner: this);

  const VerticalDragDetector({
    super.key,
    super.initializer,
    super.child,
    super.behavior,
    super.onStart,
    super.onDown,
    super.onUpdate,
    super.onEnd,
    super.onCancel,
  });
}

abstract class _LinearDragDetector<T extends DragGestureRecognizer> extends StatelessWidget {
  T create();

  final GestureDragStartCallback? onStart;
  final GestureDragDownCallback? onDown;
  final GestureDragUpdateCallback? onUpdate;
  final GestureDragEndCallback? onEnd;
  final GestureDragCancelCallback? onCancel;
  final void Function(T instance)? initializer;
  final Widget? child;
  final HitTestBehavior? behavior;

  const _LinearDragDetector({
    super.key,
    this.initializer,
    this.child,
    this.behavior,
    this.onStart,
    this.onDown,
    this.onUpdate,
    this.onEnd,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{};
    gestures[T] = GestureRecognizerFactoryWithHandlers<T>(
      create,
      initializer ??
          (instance) {
            instance
              ..onStart = onStart
              ..onDown = onDown
              ..onUpdate = onUpdate
              ..onEnd = onEnd
              ..onCancel = onCancel
              ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
          },
    );

    return RawGestureDetector(
      behavior: behavior,
      gestures: gestures,
      child: child,
    );
  }
}

class DecorationClipper extends CustomClipper<Path> {
  const DecorationClipper({
    this.textDirection = TextDirection.ltr,
    required this.decoration,
  });

  final TextDirection textDirection;
  final Decoration decoration;

  @override
  Path getClip(Size size) {
    return decoration.getClipPath(Offset.zero & size, textDirection);
  }

  @override
  bool shouldReclip(DecorationClipper oldClipper) {
    return oldClipper.decoration != decoration || oldClipper.textDirection != textDirection;
  }
}

class BorderRadiusClip extends StatelessWidget {
  final TextDirection textDirection;
  final BorderRadius borderRadius;
  final Clip clipBehavior;
  final Widget child;

  const BorderRadiusClip({
    super.key,
    this.textDirection = TextDirection.ltr,
    this.clipBehavior = Clip.antiAlias,
    required this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: DecorationClipper(
        textDirection: textDirection,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
        ),
      ),
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

class NamidaHistoryDayHeaderBox extends StatelessWidget {
  final double height;
  final String title;
  final Widget menu;
  final Color bgColor;
  final Color sideColor;
  final Color shadowColor;

  const NamidaHistoryDayHeaderBox({
    super.key,
    required this.height,
    required this.title,
    required this.menu,
    required this.sideColor,
    required this.bgColor,
    required this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          left: BorderSide(
            color: sideColor,
            width: 4.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2.0),
            blurRadius: 4.0,
            color: shadowColor,
          ),
        ],
      ),
      child: SizedBox(
        width: Dimensions.inst.availableAppContentWidth,
        height: height,
        child: Row(
          children: [
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                title,
                style: textTheme.displayMedium,
              ),
            ),
            const SizedBox(width: 4.0),
            menu,
            const SizedBox(width: 4.0),
          ],
        ),
      ),
    );
  }
}

class NamidaClearDialogExpansionTile<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<T> items;
  final ({String title, String? subtitle, String path}) Function(T item) itemBuilder;
  final int Function(T item) itemSize;
  final RxMap<File, int>? tempFilesSize;
  final Rx<bool>? tempFilesDelete;
  final RxMap<String, bool> pathsToDelete;
  final Rx<int> totalSizeToDelete;
  final Rx<bool> allSelected;

  const NamidaClearDialogExpansionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.itemBuilder,
    required this.itemSize,
    required this.tempFilesSize,
    required this.tempFilesDelete,
    required this.pathsToDelete,
    required this.totalSizeToDelete,
    required this.allSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tempFilesSize = this.tempFilesSize;
    final tempFilesDelete = this.tempFilesDelete;
    return NamidaExpansionTile(
      borderless: true,
      initiallyExpanded: true,
      titleText: title,
      subtitleText: subtitle,
      icon: icon,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(6.0.multipliedRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
              child: Text("${items.length}"),
            ),
          ),
          const SizedBox(width: 6.0),
          const Icon(Broken.arrow_down_2, size: 20.0),
        ],
      ),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      children: [
        ...items.map(
          (item) {
            final data = itemBuilder(item);
            return SmallListTile(
              borderRadius: 12.0,
              icon: Broken.arrow_right_3,
              iconSize: 20.0,
              color: theme.cardColor,
              visualDensity: const VisualDensity(horizontal: -3.0, vertical: -3.0),
              title: data.title,
              subtitle: data.subtitle,
              active: false,
              onTap: () {
                final wasTrue = pathsToDelete[data.path] == true;
                final willEnable = !wasTrue;
                pathsToDelete[data.path] = willEnable;
                if (willEnable) {
                  totalSizeToDelete.value += itemSize(item);
                } else {
                  totalSizeToDelete.value -= itemSize(item);
                }
                allSelected.value = false;
              },
              trailing: Obx(
                (context) => NamidaCheckMark(
                  size: 16.0,
                  active: pathsToDelete[data.path] == true,
                ),
              ),
            );
          },
        ),
        if (tempFilesSize != null && tempFilesDelete != null)
          Obx(
            (context) {
              final size = tempFilesSize.values.fold(0, (p, e) => p + e);
              if (size <= 0) return const SizedBox();
              return SmallListTile(
                borderRadius: 12.0,
                icon: Broken.broom,
                iconSize: 20.0,
                color: theme.cardColor,
                visualDensity: const VisualDensity(horizontal: -3.0, vertical: -3.0),
                title: lang.DELETE_TEMP_FILES,
                subtitle: size.fileSizeFormatted,
                active: false,
                onTap: () {
                  tempFilesDelete.value = !tempFilesDelete.value;
                  if (tempFilesDelete.value) {
                    totalSizeToDelete.value += size;
                  } else {
                    totalSizeToDelete.value -= size;
                  }
                },
                trailing: ObxO(
                  rx: tempFilesDelete,
                  builder: (context, deletetemp) => NamidaCheckMark(
                    size: 16.0,
                    active: deletetemp,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Returns [AnimatedTheme] or [Theme] based on [settings.animatedTheme].
class AnimatedThemeOrTheme extends StatelessWidget {
  final ThemeData data;
  final Widget child;
  final Duration duration;

  const AnimatedThemeOrTheme({
    super.key,
    required this.data,
    required this.child,
    this.duration = kThemeAnimationDuration,
  });

  @override
  Widget build(BuildContext context) {
    return settings.animatedTheme.value
        ? AnimatedTheme(
            data: data,
            duration: duration,
            child: child,
          )
        : Theme(
            data: data,
            child: child,
          );
  }
}

class EnableDisablePlaylistReordering extends StatelessWidget {
  final String playlistName;
  final PlaylistManager playlistManager;

  const EnableDisablePlaylistReordering({
    super.key,
    required this.playlistName,
    required this.playlistManager,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      key: UniqueKey(), // i have no f idea why this happens.. namida ghosts are here again
      rx: playlistManager.canReorderItems,
      builder: (context, reorderable) => NamidaAppBarIcon(
        tooltip: () => playlistManager.canReorderItems.value ? lang.DISABLE_REORDERING : lang.ENABLE_REORDERING,
        icon: reorderable ? Broken.forward_item : Broken.lock_1,
        onPressed: () {
          final playlist = playlistManager.getPlaylist(playlistName);
          if (playlist == null) return;
          if (playlist.sortsType?.isNotEmpty ?? false) {
            snackyy(
              isError: true,
              title: lang.WARNING,
              message: lang.THIS_PLAYLIST_HAS_ACTIVE_SORTERS_DISABLE_THEM_BEFORE_REORDERING,
            );
            return;
          }
          playlistManager.canReorderItems.value = !playlistManager.canReorderItems.value;
        },
      ),
    );
  }
}

class SetVideosPriorityChipController {
  // -- worst of my creations so far
  SetVideosPriorityChipController();

  NamidaPopupWrapper? Function()? _menuWrapperFn;
  BuildContext? _currentContext;

  void showMenu() {
    final menuWrapper = _menuWrapperFn?.call();
    if (menuWrapper != null) {
      menuWrapper.showPopupMenu(_currentContext!);
    }
  }
}

class SetVideosPriorityChip extends StatefulWidget {
  final SetVideosPriorityChipController? controller;
  final bool smaller;
  final int totalCount;
  final Iterable<String> videosId;
  final String Function(int count) countToText;
  final void Function(CacheVideoPriority? priority)? onInitialPriority;
  final void Function(CacheVideoPriority priority) onChanged;

  const SetVideosPriorityChip({
    super.key,
    this.controller,
    this.smaller = false,
    required this.totalCount,
    required this.videosId,
    required this.countToText,
    required this.onChanged,
    this.onInitialPriority,
  });

  @override
  State<SetVideosPriorityChip> createState() => _SetVideosPriorityChipState();
}

class _SetVideosPriorityChipState extends State<SetVideosPriorityChip> {
  CacheVideoPriority? cachePriority;

  @override
  void initState() {
    _initCachePriority();
    widget.controller?._menuWrapperFn = _getPopupWrapper;
    super.initState();
  }

  void _initCachePriority() async {
    if (widget.totalCount == 1) {
      final newCP = await VideoController.inst.videosPriorityManager.getVideoPriority(widget.videosId.first);
      refreshState(() => cachePriority = newCP);
      widget.onInitialPriority?.call(cachePriority);
    }
  }

  Future<bool> _confirmSetPriorityForAll(int count) async {
    bool confirmed = false;
    await NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: "${lang.UPDATE}: ${widget.countToText(count)}",
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.CONFIRM.toUpperCase(),
            onPressed: () async {
              confirmed = true;
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
      ),
    );
    return confirmed;
  }

  NamidaPopupWrapper? _getPopupWrapper() {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return cachePriority != null || widget.totalCount > 1
        ? NamidaPopupWrapper(
            childrenAfterChildrenDefault: false,
            children: () => [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Broken.info_circle,
                      size: 14.0,
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      lang.PRIORITY,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.displaySmall,
                    ),
                  ],
                ),
              ),
              const NamidaContainerDivider(),
            ],
            childrenDefault: () => CacheVideoPriority.values
                .map(
                  (e) => NamidaPopupItem(
                    icon: Broken.cpu,
                    title: e.toText(),
                    onTap: () async {
                      if (widget.totalCount == 1) {
                        VideoController.inst.videosPriorityManager.setVideoPriority(widget.videosId.first, e);
                        setState(() => cachePriority = e);
                        widget.onChanged(e);
                      } else {
                        final confirmed = await _confirmSetPriorityForAll(widget.totalCount);
                        if (confirmed) {
                          VideoController.inst.videosPriorityManager.setVideosPriority(widget.videosId, e);
                          if (mounted) setState(() => cachePriority = e);
                          widget.onChanged(e);
                        }
                      }
                    },
                  ),
                )
                .toList(),
            child: NamidaInkWell(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
              bgColor: theme.cardColor,
              child: Text(
                cachePriority?.toText() ?? '?',
                style: widget.smaller ? theme.textTheme.displaySmall : theme.textTheme.displayMedium,
              ),
            ),
          )
        : null;
  }

  @override
  Widget build(BuildContext context) {
    widget.controller?._currentContext = context;
    return _getPopupWrapper() ?? const SizedBox();
  }
}

class SwipeQueueAddTileInfo {
  final QueueSourceBase queueSource;
  final String? heroTag;
  final String? videoTitle;

  const SwipeQueueAddTileInfo({
    required this.queueSource,
    required this.heroTag,
    this.videoTitle,
  });

  Color? get getCurrentColor => queueSource == QueueSourceYoutubeID.playerQueue || queueSource == QueueSourceYoutubeID.playerQueue //
      ? CurrentColor.inst.miniplayerColor
      : CurrentColor.inst.color;

  void copyToClipboard(String text) {
    NamidaUtils.copyToClipboard(
      content: text,
      leftBarIndicatorColor: getCurrentColor,
    );
  }
}

class SwipeQueueAddTile<Q extends Playable> extends StatelessWidget {
  final Q item;
  final SwipeQueueAddTileInfo Function() infoCallback;
  final Object dismissibleKey;
  final bool allowSwipeLeft;
  final bool allowSwipeRight;
  final Widget child;

  const SwipeQueueAddTile({
    super.key,
    required this.item,
    required this.infoCallback,
    required this.dismissibleKey,
    required this.allowSwipeLeft,
    required this.allowSwipeRight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FadeDismissible(
      key: ValueKey(dismissibleKey),
      direction: allowSwipeLeft && allowSwipeRight
          ? DismissDirection.horizontal
          : allowSwipeLeft
              ? DismissDirection.endToStart
              : allowSwipeRight
                  ? DismissDirection.startToEnd
                  : DismissDirection.none,
      removeOnDismiss: false,
      dismissThreshold: 0.1,
      friction: 0.58,
      onDismissed: (direction) {
        final swipedLeft = direction == DismissDirection.endToStart;
        final action = swipedLeft ? settings.onTrackSwipeLeft.value : settings.onTrackSwipeRight.value;
        if (action == TrackExecuteActions.none) return;
        action.execute(
          item,
          info: infoCallback(),
        );
      },
      leftWidget: () => _SwipeQueueActionBox(
        isLeft: true,
        action: settings.onTrackSwipeRight.value,
      ),
      rightWidget: () => _SwipeQueueActionBox(
        isLeft: false,
        action: settings.onTrackSwipeLeft.value,
      ),
      child: child,
    );
  }
}

class _SwipeQueueActionBox extends StatelessWidget {
  final bool isLeft;
  final TrackExecuteActions action;
  const _SwipeQueueActionBox({required this.isLeft, required this.action});

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(8.0.multipliedRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? Radius.zero : radius,
          right: isLeft ? radius : Radius.zero,
        ),
        color: context.theme.cardColor,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.width * 0.25),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                action.toIcon(),
                size: 22.0,
              ),
              SizedBox(height: 4.0),
              Text(
                action.toText(),
                style: context.textTheme.displaySmall,
                softWrap: false,
                overflow: TextOverflow.fade,
              )
            ],
          ),
        ),
      ),
    );
  }
}

class LayoutWidthProvider extends StatelessWidget {
  final double? maxWidth;
  final Widget Function(BuildContext context, double maxWidth) builder;
  const LayoutWidthProvider({super.key, this.maxWidth, required this.builder});

  @override
  Widget build(BuildContext context) {
    if (maxWidth != null) {
      return builder(context, maxWidth!);
    }
    return LayoutBuilder(
      builder: (context, constraints) => builder(
        context,
        constraints.maxWidth.withMaximum(context.width),
      ),
    );
  }
}

class LayoutWidthHeightProvider extends StatelessWidget {
  final Widget Function(BuildContext context, double maxWidth, double maxHeight) builder;
  const LayoutWidthHeightProvider({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.withMaximum(context.width);
        final maxHeight = constraints.maxHeight.withMaximum(context.height);
        return builder(
          context,
          maxWidth,
          maxHeight,
        );
      },
    );
  }
}

class NamidaUpdateButton extends StatelessWidget {
  const NamidaUpdateButton({super.key});

  void onTap() {
    void popSheet(BuildContext context) => Navigator.pop(context);
    void onUpdateTap(BuildContext context) {
      popSheet(context);
      final latestVersion = VersionController.inst.latestVersion.value;
      final link = (latestVersion?.isBeta ?? false) ? AppSocial.GITHUB_RELEASES_BETA : AppSocial.GITHUB_RELEASES;
      NamidaLinkUtils.openLink(link);
    }

    String versionToDate(VersionWrapper? version) {
      String buildDateText = '';
      final buildDate = version?.buildDate;
      if (buildDate != null) {
        buildDateText = ' (${TimeAgoController.dateFromNow(buildDate, long: true)})';
      }
      return buildDateText;
    }

    final currentVersion = VersionWrapper.current;
    final currentVersionDateText = versionToDate(currentVersion);

    NamidaNavigator.inst.showSheet(
      builder: (context, bottomPadding, maxWidth, maxHeight) {
        final textTheme = context.textTheme;
        return SizedBox(
          height: maxHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 32.0),
                ObxO(
                  rx: VersionController.inst.latestVersion,
                  builder: (context, latestVersion) {
                    final buildDateText = versionToDate(latestVersion);

                    return RichText(
                      text: TextSpan(
                        text: latestVersion?.prettyVersion ?? '',
                        children: buildDateText.isEmpty
                            ? null
                            : [
                                TextSpan(
                                  text: buildDateText,
                                  style: textTheme.displayMedium,
                                ),
                              ],
                        style: textTheme.displayLarge,
                      ),
                    );
                  },
                ),
                if (currentVersion != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotatedBox(
                        quarterTurns: 2,
                        child: RichText(
                          text: TextSpan(
                            text: '⤵ ',
                            style: textTheme.displaySmall,
                          ),
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          text: currentVersion.prettyVersion,
                          style: textTheme.displaySmall?.copyWith(fontSize: 11.0),
                          children: currentVersionDateText.isEmpty
                              ? null
                              : [
                                  TextSpan(
                                    text: currentVersionDateText,
                                    style: textTheme.displaySmall?.copyWith(fontSize: 10.0),
                                  ),
                                ],
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 12.0),
                Expanded(
                  child: _NamidaVersionReleasesInfoList(
                    maxHeight: maxHeight,
                  ),
                ),
                SizedBox(height: 12.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextButton(
                        onPressed: () => popSheet(context),
                        child: NamidaButtonText(lang.CANCEL),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      flex: 2,
                      child: NamidaInkWell(
                        onTap: () => onUpdateTap(context),
                        borderRadius: 12.0,
                        padding: const EdgeInsets.all(12.0),
                        height: 48.0,
                        bgColor: CurrentColor.inst.color.withValues(alpha: 0.9),
                        child: Center(
                          child: Text(
                            lang.UPDATE.toUpperCase(),
                            style: textTheme.displayMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.0),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return NamidaAppBarIcon(
      icon: Broken.send_square,
      onPressed: onTap,
    );
  }
}

class _NamidaVersionReleasesInfoList extends StatefulWidget {
  final double maxHeight;
  const _NamidaVersionReleasesInfoList({required this.maxHeight});

  @override
  State<_NamidaVersionReleasesInfoList> createState() => _NamidaVersionReleasesInfoListState();
}

class _NamidaVersionReleasesInfoListState extends State<_NamidaVersionReleasesInfoList> {
  @override
  void initState() {
    VersionController.inst.fetchReleasesAfterCurrent();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return ObxO(
      rx: VersionController.inst.releasesAfterCurrent,
      builder: (context, releasesAfterCurrent) => releasesAfterCurrent == null
          ? ShimmerWrapper(
              shimmerEnabled: true,
              child: SuperListView.builder(
                padding: EdgeInsets.zero,
                itemCount: 3,
                itemBuilder: (context, index) {
                  return NamidaInkWell(
                    animationDurationMS: 200,
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    width: context.width,
                    height: widget.maxHeight * 0.5,
                    bgColor: theme.cardColor,
                  );
                },
              ),
            )
          : SuperListView.builder(
              padding: EdgeInsets.zero,
              itemCount: releasesAfterCurrent.length,
              itemBuilder: (context, index) {
                final info = releasesAfterCurrent[index];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index > 0)
                      Text(
                        info.version.prettyVersion,
                        style: textTheme.displayMedium,
                      ),
                    SizedBox(height: 4.0),
                    NamidaInkWell(
                      bgColor: theme.cardColor,
                      padding: EdgeInsets.all(8.0),
                      child: Markdown(
                        physics: const NeverScrollableScrollPhysics(),
                        data: info.body.replaceAll(RegExp(r'https:\/\/\S+'), ''),
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        styleSheet: MarkdownStyleSheet(
                          a: textTheme.displayLarge,
                          h1: textTheme.displayLarge,
                          h2: textTheme.displayMedium,
                          h3: textTheme.displayMedium,
                          h4: textTheme.displayMedium,
                          code: textTheme.displaySmall,
                          p: textTheme.displayMedium?.copyWith(fontSize: 14.0),
                          listBullet: textTheme.displayMedium,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.0),
                  ],
                );
              },
            ),
    );
  }
}

class ShortcutsInfoWidget extends StatefulWidget {
  final ShortcutsManager manager;
  const ShortcutsInfoWidget({super.key, required this.manager});

  @override
  State<ShortcutsInfoWidget> createState() => _ShortcutsInfoWidgetState();
}

class _ShortcutsInfoWidgetState extends State<ShortcutsInfoWidget> {
  final organizedMap = <String, List<ShortcutKeyActivator>>{};

  @override
  void initState() {
    for (final k in widget.manager.bindings.keys) {
      organizedMap.addForce(k.title, k);
    }

    super.initState();
  }

  void _onAddOrEditTap(String title, HotkeyAction action) {
    NamidaNavigator.inst.navigateDialog(
      dialog: _HotKeyRecorderDialog(
        title: title,
        initalHotKey: settings.shortcuts.shortcuts.value[action],
        onHotKeyRecorded: (data) {
          if (data != null) {
            // -- its not likely for already registered system hotkeys to be caught again here, but anyways
            for (final userKey in settings.shortcuts.shortcuts.value.values) {
              final keyAlrExists = userKey != null && data.isSimilarTo(userKey);
              if (keyAlrExists) {
                return '(${userKey.buildKeyLabel()})';
              }
            }

            final defaultKeys = ShortcutsController.instance?.bindings.keys;
            if (defaultKeys != null) {
              for (final defaultKey in defaultKeys) {
                final keyData = ShortcutKeyData.fromShortcutKeyActivator(defaultKey);
                final keyAlrExists = data.isSimilarTo(keyData);
                if (keyAlrExists) {
                  return '(${keyData.buildKeyLabel()}) => ${defaultKey.title}';
                }
              }
            }
          }

          ShortcutsController.instance?.setUserShortcut(action: action, data: data);
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return ObxO(
      rx: settings.shortcuts.shortcuts,
      builder: (context, userShortcuts) => SuperListView(
        shrinkWrap: true,
        children: organizedMap.entries
            .map(
              (e) {
                var shortcutsTexts = <String>[];
                String title = e.key;
                if (title == lang.LIBRARY_TABS) {
                  shortcutsTexts = ['Ctrl + 1..9'];
                } else {
                  shortcutsTexts = e.value.map((e) {
                    return ShortcutKeyData.fromShortcutKeyActivator(e).buildKeyLabel();
                  }).toList();
                }
                final action = e.value[0].action;
                final data = action == null ? null : userShortcuts[action];
                void addOrEditTapLocal() => action == null ? null : _onAddOrEditTap(title, action);
                return Wrap(
                  runSpacing: 2.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...shortcutsTexts.map(
                      (shortcut) => NamidaInkWell(
                        borderRadius: 4.0,
                        padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                        bgColor: theme.cardColor,
                        child: RichText(
                          text: TextSpan(
                            text: shortcut,
                            style: textTheme.displaySmall?.copyWith(fontSize: 13.0, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    if (data != null)
                      NamidaContainerDivider(
                        height: 16.0,
                        width: 2.0,
                        margin: EdgeInsets.symmetric(horizontal: 3.0),
                      ),
                    if (data != null)
                      NamidaInkWell(
                        borderRadius: 4.0,
                        padding: EdgeInsets.symmetric(vertical: 2.0),
                        bgColor: theme.cardColor,
                        onTap: addOrEditTapLocal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 4.0),
                            Icon(
                              Broken.cpu,
                              size: 14.0,
                            ),
                            SizedBox(width: 4.0),
                            RichText(
                              text: TextSpan(
                                text: data.buildKeyLabel(),
                                style: textTheme.displaySmall?.copyWith(fontSize: 13.0, fontWeight: FontWeight.w600),
                              ),
                            ),
                            SizedBox(width: 4.0),
                            if (action != null)
                              NamidaInkWell(
                                onTap: addOrEditTapLocal,
                                borderRadius: 4.0,
                                padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                bgColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                                child: Icon(
                                  Broken.edit_2,
                                  size: 13.0,
                                ),
                              ),
                            SizedBox(width: 2.0),
                          ],
                        ),
                      ),
                    if (action != null && data == null) ...[
                      SizedBox(width: 4.0),
                      NamidaInkWell(
                        onTap: addOrEditTapLocal,
                        borderRadius: 4.0,
                        padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                        bgColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                        child: Icon(
                          Broken.add_circle,
                          size: 14.0,
                        ),
                      ),
                    ],
                    SizedBox(width: 4.0),
                    RichText(
                      text: TextSpan(
                        text: title,
                        style: textTheme.displayMedium?.copyWith(fontSize: 13.0),
                      ),
                    ),
                  ],
                );
              },
            )
            .addSeparators(
              separator: const NamidaContainerDivider(
                margin: EdgeInsets.symmetric(vertical: 3.0),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HotKeyRecorderDialog extends StatefulWidget {
  final String? title;
  final ShortcutKeyData? initalHotKey;
  final String? Function(ShortcutKeyData? data) onHotKeyRecorded;

  const _HotKeyRecorderDialog({
    required this.title,
    this.initalHotKey,
    required this.onHotKeyRecorded,
  });

  @override
  State<_HotKeyRecorderDialog> createState() => _HotKeyRecorderDialogState();
}

class _HotKeyRecorderDialogState extends State<_HotKeyRecorderDialog> {
  ShortcutKeyData? _hotKey;
  String? _errorMsg;

  @override
  void initState() {
    _hotKey = widget.initalHotKey;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    super.initState();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent keyEvent) {
    if (keyEvent is! KeyDownEvent) return false;
    if (keyEvent.physicalKey == PhysicalKeyboardKey.enter || keyEvent.physicalKey == PhysicalKeyboardKey.numpadEnter) {
      _confirmHotkey();
      return true;
    }

    bool ctrl = false;
    bool shift = false;
    bool alt = false;
    bool meta = false;

    void investigateForModifiers(Set<PhysicalKeyboardKey> keys) {
      for (final k in keys) {
        if (k == PhysicalKeyboardKey.controlLeft || k == PhysicalKeyboardKey.controlRight) {
          ctrl = true;
          continue;
        }
        if (k == PhysicalKeyboardKey.shiftLeft || k == PhysicalKeyboardKey.shiftRight) {
          shift = true;
          continue;
        }
        if (k == PhysicalKeyboardKey.altLeft || k == PhysicalKeyboardKey.altRight) {
          alt = true;
          continue;
        }
        if (k == PhysicalKeyboardKey.metaLeft || k == PhysicalKeyboardKey.metaRight) {
          meta = true;
          continue;
        }
      }
    }

    investigateForModifiers({keyEvent.physicalKey});
    final isKeyModifier = ctrl || shift || alt || meta; // check after pressed key is investigated
    investigateForModifiers(HardwareKeyboard.instance.physicalKeysPressed);

    setState(() {
      _hotKey = ShortcutKeyData(
        key: isKeyModifier ? null : keyEvent.logicalKey,
        ctrl: ctrl,
        shift: shift,
        alt: alt,
        meta: meta,
      );
      _errorMsg = null;
    });

    return true;
  }

  void _confirmHotkey() {
    final error = widget.onHotKeyRecorded(_hotKey);
    if (error != null) {
      setState(() => _errorMsg = error);
    } else {
      NamidaNavigator.inst.closeDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyLabelNormalized = _hotKey?.buildKeyLabel() ?? '';
    final isKeyGood = keyLabelNormalized.isNotEmpty;
    final isEdit = widget.initalHotKey != null;
    return CustomBlurryDialog(
      icon: isEdit ? Broken.edit : Broken.add_circle,
      title: widget.title ?? (isEdit ? lang.EDIT : lang.ADD),
      normalTitleStyle: true,
      trailingWidgets: [
        if (isKeyGood)
          NamidaIconButton(
            icon: Broken.refresh,
            tooltip: () => lang.CLEAR,
            onPressed: () {
              setState(() {
                _hotKey = null;
                _errorMsg = null;
              });
            },
          ),
      ],
      actions: [
        const CancelButton(),
        NamidaButton(
          text: lang.SAVE,
          onPressed: () {
            _confirmHotkey();
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: NamidaInkWell(
              borderRadius: 8.0,
              bgColor: context.theme.cardColor,
              padding: EdgeInsetsGeometry.symmetric(
                horizontal: 12.0,
                vertical: 12.0,
              ),
              child: Text(
                isKeyGood ? keyLabelNormalized : '?',
                style: context.textTheme.displayMedium,
              ),
            ),
          ),
          if (_errorMsg != null) ...[
            SizedBox(height: 8.0),
            Text(
              _errorMsg!,
              style: context.textTheme.displayMedium?.copyWith(color: context.theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class NamidaArtworkExpandableToFullscreen extends StatelessWidget {
  final Widget artwork;
  final String? heroTag;
  final FutureOr<File?> Function() imageFile;
  final FutureOr<String?> Function(File imgFile) onSave;
  final Color? Function()? themeColor;

  const NamidaArtworkExpandableToFullscreen({
    super.key,
    required this.artwork,
    required this.heroTag,
    required this.imageFile,
    required this.onSave,
    required this.themeColor,
  });

  void openInFullscreen() async {
    final imgFile = await imageFile();
    if (imgFile == null) return;

    NamidaNavigator.inst.navigateDialog(
      scale: 1.0,
      blackBg: true,
      dialog: NamidaArtworkFullscreen(
        title: '',
        artwork: artwork,
        imgFile: imgFile,
        heroTag: heroTag,
        save: () async {
          final saveDirPath = await onSave(imgFile);
          NamidaOnTaps.inst.showSavedImageInSnack(saveDirPath, themeColor?.call());
        },
        close: NamidaNavigator.inst.closeDialog,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapDetector(
      onTap: openInFullscreen,
      child: artwork,
    );
  }
}

class NamidaArtworkFullscreen extends StatefulWidget {
  final String title;
  final Widget artwork;
  final File imgFile;
  final String? heroTag;
  final void Function() save;
  final void Function() close;

  const NamidaArtworkFullscreen({
    super.key,
    required this.title,
    required this.artwork,
    required this.imgFile,
    required this.heroTag,
    required this.save,
    required this.close,
  });

  @override
  State<NamidaArtworkFullscreen> createState() => _NamidaArtworkFullscreenState();
}

class _NamidaArtworkFullscreenState extends State<NamidaArtworkFullscreen> {
  bool _showTopBar = false;
  double _heighestTopPadding = 0;

  @override
  void initState() {
    NamidaNavigator.setSystemUIImmersiveMode(true);
    super.initState();
  }

  @override
  void dispose() {
    MiniPlayerController.inst.setImmersiveMode(null); // let that decide
    super.dispose();
  }

  void _toggleAppBars() {
    final newShow = !_showTopBar;
    if (newShow != _showTopBar) {
      setState(() => _showTopBar = newShow);
      NamidaNavigator.setSystemUIImmersiveMode(!newShow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final heroTag = widget.heroTag;
    final topPadding = context.padding.top;
    if (topPadding > _heighestTopPadding) _heighestTopPadding = topPadding;
    return Stack(
      alignment: AlignmentGeometry.center,
      children: [
        LongPressDetector(
          onLongPress: widget.save,
          child: PhotoView(
            heroAttributes: heroTag == null ? null : PhotoViewHeroAttributes(tag: heroTag),
            gaplessPlayback: true,
            onTapUp: (context, details, controllerValue) {
              _toggleAppBars();
            },
            tightMode: true,
            minScale: PhotoViewComputedScale.contained,
            loadingBuilder: (context, event) => widget.artwork,
            backgroundDecoration: const BoxDecoration(color: Colors.transparent),
            filterQuality: FilterQuality.high,
            imageProvider: FileImage(widget.imgFile),
          ),
        ),
        Positioned(
          top: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _showTopBar ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !_showTopBar,
              child: SizedBox(
                width: context.width,
                child: ColoredBox(
                  color: context.theme.scaffoldBackgroundColor,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 12.0 + _heighestTopPadding,
                      bottom: 12.0,
                      left: 8.0,
                      right: 8.0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: NamidaIconButton(
                            icon: Broken.arrow_left_2,
                            onPressed: widget.close,
                          ),
                        ),
                        Expanded(
                          child: widget.title.isEmpty
                              ? const SizedBox()
                              : Text(
                                  widget.title,
                                  style: context.textTheme.displayMedium,
                                ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: NamidaIconButton(
                            icon: Broken.gallery_import,
                            onPressed: widget.save,
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
      ],
    );
  }
}

class ObxPrefer<T> extends StatelessWidget {
  final RxBaseCore<T> rx;
  final Widget Function(BuildContext context, T? value) builder;
  final bool enabled;
  const ObxPrefer({required this.rx, required this.builder, required this.enabled, super.key});

  @override
  Widget build(BuildContext context) {
    return enabled ? ObxO(rx: rx, builder: builder) : builder(context, null);
  }
}
