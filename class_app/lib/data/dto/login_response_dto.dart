class LoginResponseDto {
  const LoginResponseDto({
    required this.accessToken,
    required this.id,
    required this.fullName,
    required this.email,
    this.avatar,
    this.systemRole,
  });

  final String accessToken;
  final String id;
  final String fullName;
  final String email;
  final String? avatar;
  final String? systemRole;

  factory LoginResponseDto.fromJson(Map<String, dynamic> json) {
    return LoginResponseDto(
      accessToken: json['accessToken'] as String,
      id: json['id']?.toString() ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatar: json['avatar'] as String?,
      systemRole: json['systemRole'] as String?,
    );
  }
}
