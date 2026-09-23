import 'package:flutter/material.dart';

import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class LibraryTabVariantsPopup extends StatelessWidget {
  final LibraryTab tab;
  final List<LibraryTab> variants;
  final bool openOnTap;
  final VoidCallback? onSelected;
  final Widget child;

  const LibraryTabVariantsPopup({
    super.key,
    required this.tab,
    required this.variants,
    required this.openOnTap,
    this.onSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      openOnTap: openOnTap,
      childrenDefault: () => variants.map(
        (variant) => NamidaPopupItem(
          icon: variant.toIcon(),
          title: variant.toVariantText(),
          selected: variant == tab,
          onTap: () {
            ScrollSearchController.inst.animatePageController(variant);
            onSelected?.call();
          },
        ),
      ),
      child: child,
    );
  }
}

class LibraryTabVariantChip extends StatelessWidget {
  final LibraryTab tab;

  const LibraryTabVariantChip({super.key, required this.tab});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.libraryTabs,
      builder: (context, libraryTabs) {
        final variants = libraryTabs.enabledVariantsOf(tab.group).toList();
        if (variants.length < 2) return const SizedBox();
        final theme = context.theme;
        return LibraryTabVariantsPopup(
          tab: tab,
          variants: variants,
          openOnTap: true,
          child: NamidaInkWell(
            borderRadius: 8.0,
            bgColor: theme.colorScheme.secondaryContainer.withOpacityExt(0.5),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tab.toIcon(),
                  size: 14.0,
                ),
                const SizedBox(width: 4.0),
                Text(
                  tab.toVariantText(),
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(width: 2.0),
                const Icon(
                  Broken.arrow_right_3,
                  size: 12.0,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
