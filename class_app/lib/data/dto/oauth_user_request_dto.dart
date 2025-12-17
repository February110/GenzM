class OAuthUserRequestDto {
  const OAuthUserRequestDto({
    required this.email,
    required this.fullName,
    required this.provider,
    this.avatar,
    this.providerId,
  });

  final String email;
  final String fullName;
  final String provider;
  final String? avatar;
  final String? providerId;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullName': fullName,
      'provider': provider,
      'providerId': providerId,
      'avatar': avatar,
    };
  }
}
