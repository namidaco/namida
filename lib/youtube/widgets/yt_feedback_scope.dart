// by claude

import 'package:flutter/material.dart';

import 'package:youtipie/class/feedback_menu_action.dart';
import 'package:youtipie/class/map_serializable.dart';
import 'package:youtipie/class/result_wrapper/feedback_holder.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

/// Lets cards of a home feed offer youtube's `Not interested` & co under a `More` entry of their menu.
/// [builder] is rebuilt after an item is dropped or put back.
class YTFeedbackScope extends StatefulWidget {
  final YoutiPieFeedbackHolder list;
  final WidgetBuilder builder;

  const YTFeedbackScope({
    super.key,
    required this.list,
    required this.builder,
  });

  /// null outside a scope or when youtube offers nothing for [item].
  static NamidaPopupItem? moreMenuItemOf(BuildContext context, MapSerializable item, {required String itemTitle}) {
    final scopeState = context.getInheritedWidgetOfExactType<_YTFeedbackInherited>()?.scopeState;
    if (scopeState == null) return null;
    final list = scopeState.widget.list;
    final actions = list.feedbackActions[item.cacheKey];
    if (actions == null || actions.isEmpty) return null;
    return NamidaPopupItem(
      icon: Broken.more_square,
      title: lang.more,
      trailing: const Icon(Broken.arrow_right_3, size: 18.0),
      onTap: () => scopeState._showActionsMenu(context, list, item, actions, itemTitle),
    );
  }

  @override
  State<YTFeedbackScope> createState() => _YTFeedbackScopeState();
}

class _YTFeedbackScopeState extends State<YTFeedbackScope> {
  void _showActionsMenu(BuildContext cardContext, YoutiPieFeedbackHolder list, MapSerializable item, List<FeedbackMenuAction> actions, String itemTitle) {
    if (!cardContext.mounted) return;
    NamidaPopupWrapper(
      childrenDefault: () => actions.map(
        (action) => NamidaPopupItem(
          icon: action.type.toIcon(),
          title: action.text,
          onTap: () => _applyAction(list, item, action, itemTitle),
        ),
      ),
    ).showPopupMenu(cardContext);
  }

  Future<void> _applyAction(YoutiPieFeedbackHolder list, MapSerializable item, FeedbackMenuAction action, String itemTitle) async {
    final undo = await YoutubeInfoController.feedbackAction.sendFeedback(
      list: list,
      item: item,
      action: action,
    );
    if (undo == null) {
      snackyy(title: lang.error, message: lang.failed, isError: true);
      return;
    }
    refreshState();

    final undoButton = action.undoToken == null
        ? null
        : SnackbarButton(
            text: lang.undo,
            function: () => _undoAction(undo),
          );
    snackyy(
      icon: action.type.toIcon(),
      title: action.text,
      message: itemTitle,
      top: false,
      button: undoButton,
    );
  }

  Future<void> _undoAction(YoutiPieFeedbackUndo undo) async {
    final didUndo = await YoutubeInfoController.feedbackAction.undoFeedback(undo);
    if (didUndo == true) {
      refreshState();
    } else {
      snackyy(title: lang.error, message: lang.failed, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _YTFeedbackInherited(
      scopeState: this,
      child: widget.builder(context),
    );
  }
}

class _YTFeedbackInherited extends InheritedWidget {
  final _YTFeedbackScopeState scopeState;

  const _YTFeedbackInherited({
    required this.scopeState,
    required super.child,
  });

  @override
  bool updateShouldNotify(_YTFeedbackInherited oldWidget) => false;
}
