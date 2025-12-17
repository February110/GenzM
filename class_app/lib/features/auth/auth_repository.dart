abstract class AuthRepository {
  Future<String> login({required String email, required String password});
  Future<String> loginWithOAuth({
    required String email,
    required String fullName,
    required String provider,
    String? avatar,
    String? providerId,
  });
}
