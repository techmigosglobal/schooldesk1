class _Unset {
  const _Unset();
}

const _unset = _Unset();

/// Setup step entity — domain object for school onboarding progress.
class SetupStep {
  final String label;
  final bool isComplete;
  final String? route;

  const SetupStep({required this.label, required this.isComplete, this.route});

  SetupStep copyWith({
    Object? label = _unset,
    Object? isComplete = _unset,
    Object? route = _unset,
  }) {
    return SetupStep(
      label: label is _Unset ? this.label : label as String,
      isComplete: isComplete is _Unset ? this.isComplete : isComplete as bool,
      route: route is _Unset ? this.route : route as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SetupStep &&
      other.label == label &&
      other.isComplete == isComplete &&
      other.route == route;

  @override
  int get hashCode => Object.hash(label, isComplete, route);
}
