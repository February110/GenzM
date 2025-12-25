import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:5081/api';
    }
    return 'http://localhost:5081/api';
  }

  static String get apiOrigin {
    final uri = Uri.parse(apiBaseUrl);
    final port = (uri.hasPort && uri.port > 0) ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  static String resolveAssetUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    var normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('http')) return normalized;
    if (!normalized.startsWith('/')) normalized = '/$normalized';
    return '$apiOrigin$normalized';
  }

  static bool isSvgUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final parsedPath =
        Uri.tryParse(url.replaceAll('\\', '/'))?.path.toLowerCase() ??
        url.toLowerCase();
    return parsedPath.endsWith('.svg') || parsedPath.endsWith('/svg') || parsedPath.endsWith('svg');
  }

  static String get stunUrl =>
      dotenv.env['STUN_URL'] ?? 'stun:stun.l.google.com:19302';

  static String get turnUrl => dotenv.env['TURN_URL'] ?? '';

  static String get turnUsername => dotenv.env['TURN_USERNAME'] ?? '';

  static String get turnPassword => dotenv.env['TURN_PASSWORD'] ?? '';

  static List<Map<String, dynamic>> get iceServers {
    final servers = <Map<String, dynamic>>[];
    if (stunUrl.isNotEmpty) {
      servers.add({'urls': stunUrl});
    }
    if (turnUrl.isNotEmpty) {
      final server = <String, dynamic>{'urls': turnUrl};
      if (turnUsername.isNotEmpty) {
        server['username'] = turnUsername;
      }
      if (turnPassword.isNotEmpty) {
        server['credential'] = turnPassword;
      }
      servers.add(server);
    }
    return servers;
  }
}
