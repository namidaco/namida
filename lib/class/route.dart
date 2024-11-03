import 'package:flutter/material.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/enums.dart';

class NamidaDummyPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.UNKNOWN;

  const NamidaDummyPage({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}

mixin NamidaRouteWidget on Widget implements NamidaRoute {
  @override
  String? get name => null;

  @override
  bool isSameRouteAs(NamidaRoute r) => this.name == r.name && this.route == r.route;
}

abstract class NamidaRoute {
  final RouteType route;
  final String? name;

  const NamidaRoute(
    this.route,
    this.name,
  );

  @override
  String toString() => '(route: $route, name: $name)';

  bool isSameRouteAs(NamidaRoute r);

  @override
  bool operator ==(covariant NamidaRoute other) {
    return route == other.route && name == other.name;
  }

  @override
  int get hashCode => "$route$name".hashCode;
}

extension NamidaRouteWidgetUtils on NamidaRouteWidget {
  Future<void> navigate() => NamidaNavigator.inst.navigateTo(this);
}
