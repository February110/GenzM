import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lưu access token toàn cục để interceptor tự động đính kèm.
final accessTokenProvider = StateProvider<String?>((_) => null);
