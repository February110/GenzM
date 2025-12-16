class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.token,
    this.avatar,
    this.systemRole,
  });

  final String id;
  final String email;
  final String? name;
  final String? token;
  final String? avatar;
  final String? systemRole;

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? token,
    String? avatar,
    String? systemRole,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      token: token ?? this.token,
      avatar: avatar ?? this.avatar,
      systemRole: systemRole ?? this.systemRole,
    );
  }
}
