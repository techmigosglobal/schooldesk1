import 'dart:developer' as developer;

/// Opt-in VM timeline markers for profile runs against synthetic data.
/// Event arguments contain neither record identifiers nor request URLs.
abstract final class MobileLoadingTrace {
  static const enabled = bool.fromEnvironment('SCHOOLDESK_PROFILE_LOADING');

  static void mark(String name, {Map<String, Object>? arguments}) {
    if (enabled) developer.Timeline.instantSync(name, arguments: arguments);
  }
}
