import 'package:schooldesk1/core/authorization/role_access_policy.dart';

enum RepositoryStateRequirement {
  loading,
  stale,
  offline,
  error,
  empty,
  retry,
}

class FeatureManifest {
  const FeatureManifest({
    required this.id,
    required this.route,
    required this.capability,
    this.offlineReadable = true,
    this.onlineOnlyMutation = false,
    this.stateRequirements = const {
      RepositoryStateRequirement.loading,
      RepositoryStateRequirement.stale,
      RepositoryStateRequirement.offline,
      RepositoryStateRequirement.error,
      RepositoryStateRequirement.empty,
      RepositoryStateRequirement.retry,
    },
  });

  final String id;
  final String route;
  final SchoolDeskCapability capability;
  final bool offlineReadable;
  final bool onlineOnlyMutation;
  final Set<RepositoryStateRequirement> stateRequirements;

  bool supports(RepositoryStateRequirement requirement) =>
      stateRequirements.contains(requirement);
}
