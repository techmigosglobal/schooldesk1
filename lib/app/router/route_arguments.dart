import 'package:flutter/widgets.dart';

/// Typed argument boundary for GoRouter screens.
///
/// GoRouter owns route state. Screens receive their declared argument type and
/// never read `ModalRoute.settings.arguments` directly.
class SchoolDeskRouteArguments extends InheritedWidget {
  const SchoolDeskRouteArguments({
    required this.value,
    required super.child,
    super.key,
  });

  final Object? value;

  static T? maybeOf<T>(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<SchoolDeskRouteArguments>();
    final value = scope?.value;
    return value is T ? value : null;
  }

  @override
  bool updateShouldNotify(SchoolDeskRouteArguments oldWidget) {
    return !identical(value, oldWidget.value);
  }
}
