import 'package:flutter/material.dart';

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
}

class NamidaRoute {
  final RouteType route;
  final String? name;

  const NamidaRoute(
    this.route,
    this.name,
  );

  @override
  String toString() => '(route: $route, name: $name)';

  @override
  bool operator ==(other) {
    if (other is NamidaRoute) {
      return route == other.route && name == other.name;
    }
    return false;
  }

  @override
  int get hashCode => "$route$name".hashCode;
}
