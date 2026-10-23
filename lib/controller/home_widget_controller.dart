import 'package:namida/controller/platform/home_widgets/home_widgets.dart';
import 'package:namida/controller/player_controller.dart';

class HomeWidgetController {
  static final instance = HomeWidgets.platform();

  static const actionShuffle = 'namida_widget_shuffle';
  static const actionCycleRepeat = 'namida_widget_repeat';
  static const actionWidgetsEnabled = 'namida_widget_enabled';
  static const actionWidgetsDisabled = 'namida_widget_disabled';

  static Future<void> onPlayerReady() async {
    await instance?.onPlayerReady(_performMediaAction);
  }

  static Future<void> _performMediaAction(HomeWidgetMediaAction action) async {
    switch (action) {
      case HomeWidgetMediaAction.playPause:
        await Player.inst.togglePlayPause();
      case HomeWidgetMediaAction.next:
        await Player.inst.next();
      case HomeWidgetMediaAction.previous:
        await Player.inst.previous();
      case HomeWidgetMediaAction.favourite:
        Player.inst.toggleFavouriteForCurrentItem();
    }
  }
}
