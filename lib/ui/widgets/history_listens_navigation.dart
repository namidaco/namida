// by claude
import 'package:flutter/material.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class HistoryListensNavigationButtons extends StatefulWidget {
  final Rxn<HistoryListensNavigation> navigationRx;
  final void Function(int listen, List<int> listens) onListenTap;

  const HistoryListensNavigationButtons({
    super.key,
    required this.navigationRx,
    required this.onListenTap,
  });

  @override
  State<HistoryListensNavigationButtons> createState() => _HistoryListensNavigationButtonsState();
}

class _HistoryListensNavigationButtonsState extends State<HistoryListensNavigationButtons> {
  HistoryListensNavigation? _lastNavigation; // -- kept to animate hiding

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: widget.navigationRx,
      builder: (context, navigation) {
        if (navigation != null) _lastNavigation = navigation;
        final shownNavigation = _lastNavigation;
        return AnimatedShow(
          isHorizontal: true,
          show: navigation != null,
          duration: const Duration(milliseconds: 400),
          child: shownNavigation == null
              ? const SizedBox()
              : _ListensNavigationRow(
                  navigation: shownNavigation,
                  onListenTap: widget.onListenTap,
                  onClose: () => widget.navigationRx.value = null,
                ),
        );
      },
    );
  }
}

class _ListensNavigationRow extends StatelessWidget {
  final HistoryListensNavigation navigation;
  final void Function(int listen, List<int> listens) onListenTap;
  final void Function() onClose;

  const _ListensNavigationRow({
    required this.navigation,
    required this.onListenTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final listens = navigation.listens;
    void onTap(int listen) => onListenTap(listen, listens);
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: NamidaBlurryContainer(
        borderRadius: BorderRadius.circular(12.0.multipliedRadius),
        padding: const EdgeInsets.all(2.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ListenJumpButton(
              icon: Broken.arrow_up_2,
              listen: navigation.newerListen,
              onTap: onTap,
            ),
            Text(
              '${navigation.index + 1}/${listens.length}',
              style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            _ListenJumpButton(
              icon: Broken.arrow_bottom,
              listen: navigation.olderListen,
              onTap: onTap,
            ),
            NamidaIconButton(
              icon: Broken.close_circle,
              iconSize: 18.0,
              horizontalPadding: 6.0,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _ListenJumpButton extends StatelessWidget {
  final IconData icon;
  final int? listen;
  final void Function(int listen) onTap;

  const _ListenJumpButton({
    required this.icon,
    required this.listen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final listen = this.listen;
    return NamidaIconButton(
      icon: icon,
      iconSize: 20.0,
      horizontalPadding: 6.0,
      verticalPadding: 4.0,
      iconColor: listen == null ? context.theme.disabledColor : null,
      onPressed: listen == null ? null : () => onTap(listen),
    );
  }
}

/// [listens] are sorted oldest first, while history pages show the newest on top.
class HistoryListensNavigation {
  final List<int> listens;
  final int index;

  const HistoryListensNavigation._(this.listens, this.index);

  static HistoryListensNavigation? of(List<int>? listens, int? listen) {
    if (listens == null || listen == null) return null;
    final index = listens.indexOf(listen);
    if (index == -1) return null;
    return HistoryListensNavigation._(listens, index);
  }

  int? get newerListen => index + 1 < listens.length ? listens[index + 1] : null;
  int? get olderListen => index > 0 ? listens[index - 1] : null;
}
