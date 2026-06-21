/// Principal profile entity used by the domain layer.
class PrincipalProfile {
  final String id;
  final String name;
  final String username;
  final String email;
  final String roleName;

  const PrincipalProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.roleName,
  });

  PrincipalProfile copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? roleName,
  }) {
    return PrincipalProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      roleName: roleName ?? this.roleName,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PrincipalProfile &&
        other.id == id &&
        other.name == name &&
        other.username == username &&
        other.email == email &&
        other.roleName == roleName;
  }

  @override
  int get hashCode => Object.hash(id, name, username, email, roleName);
}
