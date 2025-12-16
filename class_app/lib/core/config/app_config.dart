import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AppConfig {
  /// Base URL mặc định. Có thể override bằng --dart-define=API_BASE_URL=...
  static String get apiBaseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;

    // Android emulator cần 10.0.2.2 để trỏ về host.
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:5081/api';
    }
    // Web/iOS/macOS/Windows dùng localhost.
    return 'http://localhost:5081/api';
  }

  /// Origin (không kèm `/api`) để load file tĩnh như banner, avatar.
  static String get apiOrigin {
    final uri = Uri.parse(apiBaseUrl);
    final port = (uri.hasPort && uri.port > 0) ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  /// Ghép URL tĩnh từ path trả về backend (vd: /images/banners/...) sang full URL.
  static String resolveAssetUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    var normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('http')) return normalized;
    if (!normalized.startsWith('/')) normalized = '/$normalized';
    return '$apiOrigin$normalized';
  }

  /// Nhận diện URL svg (kể cả dạng `/svg` có query) để render đúng widget.
  static bool isSvgUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final parsedPath =
        Uri.tryParse(url.replaceAll('\\', '/'))?.path.toLowerCase() ??
        url.toLowerCase();
    return parsedPath.endsWith('.svg') || parsedPath.endsWith('/svg') || parsedPath.endsWith('svg');
  }
}
