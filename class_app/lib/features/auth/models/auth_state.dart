class AuthState {
  const AuthState({this.token, this.isLoading = false, this.errorMessage});

  final String? token;
  final bool isLoading;
  final String? errorMessage;

  AuthState copyWith({String? token, bool? isLoading, String? errorMessage}) {
    return AuthState(
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  factory AuthState.initial() => const AuthState();
}
