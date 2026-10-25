import 'package:flutter/material.dart';

import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/youtube/pages/youtube_home_view.dart';

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

  Iterable<NamidaPopupItem> _getYTSectionItems() {
    final currentSection = settings.extra.ytInitialHomePage.value;
    return YTHomePages.values.map(
      (section) => NamidaPopupItem(
        icon: section.toIcon(),
        title: section.toText(),
        selected: section == currentSection,
        onTap: () {
          YouTubeHomeView.openSection(section);
          onSelected?.call();
        },
      ),
    );
  }

  Iterable<NamidaPopupItem> _getVariantItems() => _variantItemsOf(tab, variants, onSelected);

  static Iterable<NamidaPopupItem> _variantItemsOf(LibraryTab tab, List<LibraryTab> variants, VoidCallback? onSelected) {
    return variants.map(
      (variant) => NamidaPopupItem(
        icon: variant.toIcon(),
        title: variant.toVariantText(),
        selected: variant == tab,
        onTap: () {
          ScrollSearchController.inst.animatePageController(variant);
          onSelected?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      openOnTap: openOnTap,
      childrenDefault: tab.hasSectionsMenu ? _getYTSectionItems : _getVariantItems,
      child: child,
    );
  }
}

class LibraryTabVariantChip extends StatelessWidget {
  final LibraryTab tab;
  final List<LibraryTab> variants;
  final String label;
  final Iterable<NamidaPopupItem> Function()? extraItems;

  const LibraryTabVariantChip({
    super.key,
    required this.tab,
    required this.variants,
    required this.label,
    this.extraItems,
  });

  Iterable<NamidaPopupItem> _getItems() {
    final variantItems = LibraryTabVariantsPopup._variantItemsOf(tab, variants, null);
    final extraItems = this.extraItems;
    if (extraItems == null) return variantItems;
    final extraItemsList = extraItems();
    return variantItems.followedBy(extraItemsList);
  }

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      childrenDefault: _getItems,
      childBuilder: (openMenu) => ExpandableBoxChip(
        icon: tab.toIcon(),
        label: label,
        showArrow: true,
        onTap: openMenu,
      ),
    );
  }
}
