import 'package:namida/core/enums.dart';

class NamidaRoute {
  final RouteType route;
  final String name;

  NamidaRoute(
    this.route,
    this.name,
  );

  @override
  String toString() => '(route: $route, name: $name)';

  @override
  bool operator ==(other) {
    if (other is! NamidaRoute) {
      return false;
    }
    return route == other.route && name == other.name;
  }

  @override
  int get hashCode => (route.toString() + name).hashCode;
}
