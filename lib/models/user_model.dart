class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.name,
    this.phone,
    this.avatar,
    this.isActive = true,
  });

  final String id;
  final String email;
  final String role;
  final String? name;
  final String? phone;
  final String? avatar;
  final bool isActive;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? json['role_name'] ?? '').toString(),
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      avatar: json['avatar']?.toString(),
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'role': role,
    if (name != null) 'name': name,
    if (phone != null) 'phone': phone,
    if (avatar != null) 'avatar': avatar,
    'is_active': isActive,
  };
}
