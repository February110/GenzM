import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

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
}
