import 'package:namida/controller/platform/home_widgets/home_widgets.dart';

class HomeWidgetController {
  static final instance = HomeWidgets.platform();

  static const actionShuffle = 'namida_widget_shuffle';
  static const actionCycleRepeat = 'namida_widget_repeat';
}
