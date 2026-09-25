/// Typed arguments shared by role routes. Keeping these objects independent
/// of Flutter widgets prevents route payloads from becoming dynamic maps.
class EntityRouteArgs {
  const EntityRouteArgs({required this.id});

  final String id;
}

class ScopedEntityRouteArgs extends EntityRouteArgs {
  const ScopedEntityRouteArgs({required super.id, this.branchId});

  final String? branchId;
}
