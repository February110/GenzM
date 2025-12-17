import 'package:flutter_dotenv/flutter_dotenv.dart';

class OAuthConfig {
  static String get googleClientId {
    final env = dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
    if (env.isNotEmpty) return env;
    return const String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '');
  }

  static String get facebookClientId {
    final env = dotenv.env['FACEBOOK_CLIENT_ID'] ?? '';
    if (env.isNotEmpty) return env;
    return const String.fromEnvironment('FACEBOOK_CLIENT_ID', defaultValue: '');
  }
}
