import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:get/get.dart';
import 'package:namida/controller/now_playing_color.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/selected_tracks_row.dart';
import 'package:namida/ui/widgets/track_tile.dart';

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
                    color: passedColor ?? CurrentColor.inst.color.value,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: value ? [BoxShadow(offset: const Offset(0, 2), blurRadius: 8, spreadRadius: 0, color: passedColor ?? CurrentColor.inst.color.value)] : null,
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

// class AnimatingBackgroundModern extends StatefulWidget {
//   final Widget child;
//   final Color currentColor;
//   final List<Color> currentColorsList;

//   const AnimatingBackgroundModern({super.key, required this.child, required this.currentColor, required this.currentColorsList});
//   @override
//   _AnimatingBackgroundModernState createState() => _AnimatingBackgroundModernState();
// }

// class _AnimatingBackgroundModernState extends State<AnimatingBackgroundModern> with TickerProviderStateMixin {
//   late List<Color> colorList;
//   List<Alignment> alignmentList = [Alignment.topCenter, Alignment.bottomCenter];
//   int index = 0;
//   late Color bottomColor;
//   late Color topColor;

//   @override
//   void initState() {
//     super.initState();
//     setState(() {
//       bottomColor = widget.currentColor.withAlpha(20);
//       topColor = widget.currentColor.withAlpha(50);
//       // bottomColor = Colors.red;
//       // topColor = Colors.green;
//     });
//     () {
//       setState(
//         () {
//           bottomColor = const Color(0xff33267C);
//         },
//       );
//     };
//   }

//   @override
//   Widget build(BuildContext context) {
//     colorList = [
//       widget.currentColor.withAlpha(25),
//       widget.currentColor.withAlpha(50),
//       // Colors.red,
//       // Colors.green,
//       // Colors.blue,
//     ];
//     return AnimatedContainer(
//       duration: const Duration(seconds: 2),
//       onEnd: () {
//         setState(
//           () {
//             index = index + 1;
//             bottomColor = colorList[index % colorList.length];
//             topColor = colorList[(index + 1) % colorList.length];
//           },
//         );
//       },
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [bottomColor, topColor],
//         ),
//       ),
//       child: widget.child,
//     );
//   }
// }
class AnimatingBackgroundModern extends StatelessWidget {
  final Widget child;
  final Color currentColor;
  final List<Color> currentColorsList;
  final Duration duration;

  AnimatingBackgroundModern({
    super.key,
    required this.child,
    required this.currentColor,
    required this.currentColorsList,
    this.duration = const Duration(milliseconds: 0),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            currentColor.withAlpha(context.isDarkMode ? 0 : 25),
            currentColor.withAlpha(context.isDarkMode ? 55 : 110),
            // context.theme.appBarTheme.backgroundColor!,
            // context.theme.appBarTheme.backgroundColor!,
          ],
        ),
      ),
      child: child,
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
    return ElevatedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Broken.folder_add,
            size: 18,
          ),
          const SizedBox(width: 8.0),
          Text(Language.inst.ADD),
        ],
      ),
    );
  }
}
